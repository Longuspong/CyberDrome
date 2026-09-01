extends RefCounted

## §10g: Inventar, Instanzen und Roster.
##
## Getestet wird die Besitz-Schicht ohne laufende Szene -- genau wie DromeBuild.
## Die drei Aussagen, an denen §10g haengt: eine Instanz steckt in hoechstens
## einem DROME (Eindeutigkeit), der abgeleitete Build ist derselbe wie ein
## direkt gebauter, und ein Spielstand uebersteht Speichern und Laden.

var t


func _fresh() -> Roster:
	var roster := Roster.new()
	roster.seed_starter()
	return roster


func test_starter_stock_matches_the_design() -> void:
	var roster := _fresh()
	# Vier Standard-Chassis = vier DROMEs.
	t.equal(roster.entries.size(), 4, "vier Start-DROMEs")
	# Vier Chassis + vier Kerne + neun Ausruestungsteile (acht in den Kits, der
	# Koedersender frei) = 17 Instanzen.
	t.equal(roster.all_instances().size(), 17, "17 Instanzen im Startbestand")
	# Jede Standard-Ausruestung genau einmal -- inklusive des Hologramm-Boosts.
	for part_id in [&"eq_pulse_blaster", &"eq_holo_boost", &"eq_siege_cannon",
			&"eq_rune_staff", &"eq_rail_lance", &"eq_deflector", &"eq_drone_pod",
			&"eq_bait_beacon", &"eq_orbit_focus"]:
		t.equal(roster.total_count(part_id), 1,
			"genau eine %s im Bestand" % part_id)
	# Die ersten beiden ziehen ins Gefecht -- wie die alte Squad-Groesse 2.
	t.equal(roster.squad_count(), 2, "zwei DROMEs im Start-Squad")


func test_each_starter_drome_is_battle_ready() -> void:
	var roster := _fresh()
	for entry in roster.entries:
		var build := roster.build_for(entry)
		var problems: Array[String] = build.validate()
		t.ok(problems.is_empty(), "%s ist kampftauglich: %s"
			% [entry.name, ", ".join(problems)])


func test_a_part_cannot_be_in_two_dromes_at_once() -> void:
	# Die Grundregel der Eindeutigkeit: nach dem Startbestand ist jede der acht
	# Ausruestungsinstanzen entweder verbaut oder frei -- nie doppelt.
	var roster := _fresh()
	var used := roster.assigned_uids()
	var seen := {}
	for uid in used:
		t.ok(not seen.has(uid), "uid %s steckt in hoechstens einem DROME" % uid)
		seen[uid] = true

	# Das freie Teil an einen DROME haengen -> es ist nicht mehr frei, und ein
	# zweiter DROME bekommt kein zweites Exemplar desselben Teils. Frei ist zum
	# Start nur der Koedersender -- alle anderen Teile stecken in den Kits.
	t.equal(roster.free_count(&"eq_bait_beacon"), 1,
		"der Koedersender liegt zunaechst frei")
	var molok: RosterEntry = roster.entries[1]
	var molok_slot: String = roster.build_for(molok).equip_slots()[1]
	t.ok(roster.assign(molok, molok_slot, &"eq_bait_beacon"), "erste Zuweisung greift")
	t.equal(roster.free_count(&"eq_bait_beacon"), 0,
		"danach ist kein Koedersender mehr frei")

	var vireo: RosterEntry = roster.entries[0]
	var vireo_slot: String = roster.build_for(vireo).equip_slots()[1]
	t.ok(not roster.assign(vireo, vireo_slot, &"eq_bait_beacon"),
		"ein zweiter DROME bekommt kein zweites Exemplar")
	t.ok(roster.instance_part_id(str(vireo.assignments.get(vireo_slot, ""))) != &"eq_bait_beacon",
		"und der Slot bleibt leer statt still doppelt belegt")


func test_clearing_a_slot_frees_the_instance() -> void:
	var roster := _fresh()
	var vireo: RosterEntry = roster.entries[0]
	# Vireo traegt zum Start den Puls-Blaster. Frei sind 0.
	t.equal(roster.free_count(&"eq_pulse_blaster"), 0, "der Blaster ist verbaut")
	var slots := roster.build_for(vireo).equip_slots()
	# Den Blaster-Slot finden und leeren.
	for slot in slots:
		if roster.instance_part_id(str(vireo.assignments.get(slot, ""))) == &"eq_pulse_blaster":
			roster.clear_slot(vireo, slot)
	t.equal(roster.free_count(&"eq_pulse_blaster"), 1,
		"nach dem Leeren ist der Blaster wieder frei")


func test_chassis_cannot_be_cleared() -> void:
	var roster := _fresh()
	var vireo: RosterEntry = roster.entries[0]
	var before := vireo.chassis_uid()
	roster.clear_slot(vireo, "body")
	t.equal(vireo.chassis_uid(), before,
		"das Chassis ist die Identitaet und laesst sich nicht leeren")


func test_new_drome_needs_a_free_chassis() -> void:
	var roster := _fresh()
	# Alle vier Chassis sind zu Start verbaut -- kein neuer DROME moeglich.
	t.equal(roster.new_drome(&"scout_body"), null,
		"ohne freies Chassis entsteht kein DROME")
	t.ok(roster.free_chassis_types().is_empty(),
		"es gibt zu Start kein freies Chassis")

	# Ein DROME aufloesen gibt sein Chassis frei -- dann geht ein neuer.
	var freed_chassis: String = roster.entries[0].chassis_uid()
	roster.disband(roster.entries[0])
	t.equal(roster.entries.size(), 3, "der aufgeloeste DROME ist weg")
	t.ok(roster.instance(freed_chassis) != null,
		"seine Chassis-Instanz bleibt im Inventar")
	var made := roster.new_drome(&"scout_body")
	t.ok(made != null, "mit freiem Chassis entsteht ein neuer DROME")
	t.equal(roster.entries.size(), 4, "der Roster ist wieder bei vier")


func test_derived_build_equals_a_direct_build() -> void:
	# Der abgeleitete Build (uid -> Instanz -> Typ) muss GENAU dem entsprechen,
	# den man direkt aus Typen baut -- sonst rechnete der Kampf mit anderen Werten
	# als die Werkstatt zeigt.
	var roster := _fresh()
	var vireo: RosterEntry = roster.entries[0]
	var derived := roster.build_for(vireo)

	# Vireos Standard-Kit: Puls-Blaster (erster freier Slot) und Hologramm-Boost
	# (zweiter). Die Reihenfolge folgt aus _seed_equip -- erstes passendes freies
	# Anker, alphabetisch equip_left vor equip_right.
	var direct := DromeBuild.create(vireo.name, {
		"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core",
		"equip_left": &"eq_pulse_blaster",
		"equip_right": &"eq_holo_boost",
	})
	t.equal(derived.slots, direct.slots, "dieselben Teile in denselben Slots")
	t.equal(derived.stats(), direct.stats(), "und damit dieselben Werte")


func test_roster_survives_saving_and_loading() -> void:
	var roster := _fresh()
	# Eine Aenderung, damit nicht nur der Startbestand geprueft wird.
	roster.entries[0].name = "Spaeher-Eins"
	roster.entries[2].in_squad = true

	var restored := Roster.new()
	t.ok(restored.load_dict(roster.to_dict()), "der v2-Stand laedt")
	t.equal(restored.entries.size(), roster.entries.size(), "gleiche DROME-Zahl")
	t.equal(restored.all_instances().size(), roster.all_instances().size(),
		"gleiche Instanzzahl")
	t.equal(restored.entries[0].name, "Spaeher-Eins", "Namen ueberstehen den Rundlauf")
	t.equal(restored.squad_count(), 3, "die Squad-Auswahl ebenso")
	# Und die abgeleiteten Werte sind unveraendert.
	t.equal(restored.build_for(restored.entries[0]).stats(),
		roster.build_for(roster.entries[0]).stats(), "gleiche Werte nach dem Laden")


func test_next_uid_does_not_collide_after_loading() -> void:
	# Nach dem Laden darf add_instance keine uid vergeben, die schon existiert --
	# sonst ueberschriebe eine neue Beute ein altes Teil.
	var roster := _fresh()
	var restored := Roster.new()
	restored.load_dict(roster.to_dict())
	var fresh_uid := restored.add_instance(&"eq_deflector")
	t.equal(restored.total_count(&"eq_deflector"), 2,
		"die neue Instanz kommt hinzu, statt eine alte zu ersetzen")
	t.ok(restored.instance(fresh_uid) != null, "und sie ist auffindbar")


func test_migration_from_the_old_throwaway_squad() -> void:
	# Der alte Wegwerf-Squad (v1) muss beim Umstieg erhalten bleiben.
	var v1 := {
		"squad_size": 2,
		"squad": [
			{
				"name": "ALPHA",
				"slots": {
					"body": {"part_id": "scout_body"},
					"head": {"part_id": "scout_head"},
					"feet": {"part_id": "scout_feet"},
					"core": {"part_id": "scout_core"},
					"equip_left": {"part_id": "eq_pulse_blaster"},
				},
			},
		],
	}
	var roster := Roster.new()
	t.ok(roster.migrate_v1(v1), "der v1-Squad migriert")
	t.equal(roster.entries.size(), 1, "der eine Bot wird ein Roster-Eintrag")
	var build := roster.build_for(roster.entries[0])
	t.equal(build.display_name, "ALPHA", "der Name kommt mit")
	t.ok(build.validate().is_empty(), "und der DROME ist kampftauglich")
	t.ok(roster.entries[0].in_squad, "migrierte DROMEs ziehen ins Gefecht")
