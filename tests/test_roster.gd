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
	# Vier Chassis + vier Kerne + sieben Ausruestungsteile (fuenf in den Kits:
	# Blaster, Hammer + Deflektor, Runenstab, Lanze; zwei frei: Drohnen-Pod,
	# Plasmaklinge) = 15 Instanzen. Die Gadgets sind seit 8. Nov. 2026 Module.
	t.equal(roster.all_instances().size(), 15, "15 Instanzen im Startbestand")
	for part_id in [&"eq_pulse_blaster", &"eq_hammer", &"eq_plasma_blade",
			&"eq_rune_staff", &"eq_rail_lance", &"eq_deflector", &"eq_drone_pod"]:
		t.equal(roster.total_count(part_id), 1,
			"genau eine %s im Bestand" % part_id)
	# Ein neuer Spielstand zieht mit jedem Standard-DROME einmal ins Gefecht.
	# Seit 16. Nov. 2026 ein Squad aus drei: der vierte bleibt im Hangar.
	t.equal(roster.squad_count(), 3, "drei DROMEs im Start-Squad")
	t.ok(not roster.entries[3].in_squad, "der vierte wartet im Hangar")


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
		t.ok(not seen.has(uid), "uid %s steckt in höchstens einem DROME" % uid)
		seen[uid] = true

	# Das freie Teil an einen DROME haengen -> es ist nicht mehr frei, und ein
	# zweiter DROME bekommt kein zweites Exemplar desselben Teils. Frei liegen
	# zum Start Drohnen-Pod und Plasmaklinge.
	t.equal(roster.free_count(&"eq_drone_pod"), 1,
		"der Drohnen-Pod liegt zunächst frei")
	var molok: RosterEntry = roster.entries[1]
	var molok_slot: String = roster.build_for(molok).equip_slots()[1]
	t.ok(roster.assign(molok, molok_slot, &"eq_drone_pod"), "erste Zuweisung greift")
	t.equal(roster.free_count(&"eq_drone_pod"), 0,
		"danach ist kein Drohnen-Pod mehr frei")

	var vireo: RosterEntry = roster.entries[0]
	var vireo_slot: String = roster.build_for(vireo).equip_slots()[0]
	t.ok(not roster.assign(vireo, vireo_slot, &"eq_drone_pod"),
		"ein zweiter DROME bekommt kein zweites Exemplar")
	t.ok(roster.instance_part_id(str(vireo.assignments.get(vireo_slot, ""))) != &"eq_drone_pod",
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
		"das Chassis ist die Identität und lässt sich nicht leeren")


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
	t.equal(roster.entries.size(), 3, "der aufgelöste DROME ist weg")
	t.ok(roster.instance(freed_chassis) != null,
		"seine Chassis-Instanz bleibt im Inventar")
	var made := roster.new_drome(&"scout_body")
	t.ok(made != null, "mit freiem Chassis entsteht ein neuer DROME")
	t.equal(roster.entries.size(), 4, "der Roster ist wieder bei vier")


## Verwerten statt Aufloesen (15. Nov. 2026): Chassis und Kern verschwinden,
## die Waffen kommen frei in den Hangar, dafuer gibt es einen Baukern.
func test_salvaging_a_drome_gives_a_kit_and_frees_the_weapons() -> void:
	var roster := _fresh()
	var molok: RosterEntry = roster.entries[1]
	var chassis := molok.chassis_uid()
	var weapons: Array = []
	for slot in molok.assignments:
		if str(slot).begins_with("equip_"):
			weapons.append(str(molok.assignments[slot]))
	var free_before := roster.free_count(&"eq_hammer")
	var got := roster.salvage(molok)
	t.equal(got.get("kits", 0), 1, "ein Baukern")
	t.equal(roster.kits(), 1, "liegt im Hangar")
	t.equal(roster.entries.size(), 3, "der DROME ist weg")
	t.ok(roster.instance(chassis) == null, "sein Chassis auch")
	for uid in weapons:
		t.ok(roster.instance(uid) != null, "die Waffe %s bleibt" % uid)
	t.equal(roster.free_count(&"eq_hammer"), free_before + 1, "und ist frei")
	var back := Roster.new()
	t.ok(back.load_dict(roster.to_dict()), "Spielstand lädt")
	t.equal(back.kits(), 1, "der Baukern übersteht das Speichern")


func test_the_last_drome_cannot_be_salvaged() -> void:
	var roster := _fresh()
	while roster.entries.size() > 1:
		roster.salvage(roster.entries[0])
	t.ok(roster.salvage_blocker(roster.entries[0]) != "", "der letzte bleibt")
	t.equal(roster.salvage(roster.entries[0]), {}, "und wird nicht verwertet")


## Drei Baukerne bauen einen Standard-DROME, ein Fraktionskern dazu einen
## Fraktions-DROME mit festen Werten.
func test_kits_build_standard_and_faction_dromes() -> void:
	var roster := _fresh()
	t.equal(roster.craft_drome(&"strix_body"), null, "ohne Baukerne nichts")
	roster.materials["baukern"] = 3
	var made := roster.craft_drome(&"strix_body")
	t.ok(made != null, "drei Baukerne: ein Strix")
	t.equal(roster.kits(), 0, "die Baukerne sind verbraucht")
	t.equal(roster.build_for(made).body().id, &"strix_body", "mit Strix-Chassis")
	roster.materials["baukern"] = 3
	t.equal(roster.craft_faction_drome("neon_vireo"), null, "ohne Neon-Kern kein Neon Vireo")
	roster.materials["kern:neon"] = 1
	var neon := roster.craft_faction_drome("neon_vireo")
	t.ok(neon != null, "Neon-Kern + drei Baukerne: Neon Vireo")
	t.equal(neon.variant, "neon_vireo", "als Fraktions-DROME")
	t.equal(int(roster.build_for(neon).stats()["hp_max"]), 80, "mit den festen Werten")
	t.equal(roster.faction_cores("neon"), 0, "der Kern ist verbraucht")
	var got := roster.salvage(neon)
	t.equal(got.get("faction", ""), "neon", "verwertet gibt er seinen Kern zurück")
	t.equal(roster.faction_cores("neon"), 1, "einen Neon-Kern")


## Hangar-Shop (15. Nov. 2026): Baukerne und Caches fuer Platzhaltercoin.
func test_the_shop_sells_kits_and_caches_for_coins() -> void:
	var roster := _fresh()
	var offers := Roster.shop_offers()
	var kit: Dictionary = offers.filter(func(o): return o["kind"] == "kit")[0]
	var cache: Dictionary = offers.filter(func(o): return o["kind"] == "cache")[0]
	t.ok(roster.offer_blocker(kit) != "", "ohne Coins kein Kauf")
	t.ok(not roster.buy_offer(kit), "und nichts passiert")
	roster.coins = int(kit["price"]) + int(cache["price"])
	t.ok(roster.buy_offer(kit), "Baukern gekauft")
	t.equal(roster.kits(), 1, "liegt im Hangar")
	t.ok(roster.buy_offer(cache), "Cache gekauft")
	t.equal(int(roster.caches.get(str(cache["cache"]), 0)), 1, "Cache im Hangar")
	t.equal(roster.coins, 0, "die Coins sind ausgegeben")


func test_derived_build_equals_a_direct_build() -> void:
	# Der abgeleitete Build (uid -> Instanz -> Typ) muss GENAU dem entsprechen,
	# den man direkt aus Typen baut -- sonst rechnete der Kampf mit anderen Werten
	# als die Werkstatt zeigt.
	var roster := _fresh()
	var vireo: RosterEntry = roster.entries[0]
	var derived := roster.build_for(vireo)

	# Vireos Standard-Kit: der Puls-Blaster in seinem einzigen Halter.
	var direct := DromeBuild.create(vireo.name, {
		"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core",
		"equip_left": &"eq_pulse_blaster",
	})
	t.equal(derived.slots, direct.slots, "dieselben Teile in denselben Slots")
	t.equal(derived.stats(), direct.stats(), "und damit dieselben Werte")


func test_roster_survives_saving_and_loading() -> void:
	var roster := _fresh()
	# Eine Aenderung, damit nicht nur der Startbestand geprueft wird.
	roster.entries[0].name = "Späher-Eins"
	roster.entries[2].in_squad = false

	var restored := Roster.new()
	t.ok(restored.load_dict(roster.to_dict()), "der v2-Stand lädt")
	t.equal(restored.entries.size(), roster.entries.size(), "gleiche DROME-Zahl")
	t.equal(restored.all_instances().size(), roster.all_instances().size(),
		"gleiche Instanzzahl")
	t.equal(restored.entries[0].name, "Späher-Eins", "Namen überstehen den Rundlauf")
	t.equal(restored.squad_count(), 2, "die Squad-Auswahl ebenso")
	# Ein alter Stand mit vier im Squad wird auf drei gekuerzt.
	for entry in roster.entries:
		entry.in_squad = true
	var old := Roster.new()
	old.load_dict(roster.to_dict())
	t.equal(old.squad_count(), 3, "alter Stand: vier im Squad -> drei")
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


func test_a_new_game_starts_with_everything_once() -> void:
	var roster := Roster.new()
	roster.seed_new_game()
	# 23. Nov. 2026 (Spieler): nur die vier CyberDrome-DROMEs, jede Waffe einmal.
	t.equal(roster.entries.size(), 4, "die vier CyberDrome-DROMEs")
	for entry in roster.entries:
		t.equal(entry.variant, "", "%s ist kein Fraktions-DROME" % entry.name)
	for part in PartDB.of_type(PartData.Type.EQUIPMENT):
		t.equal(roster.total_count(part.id), 1, "%s genau einmal" % part.display_name)
	for entry in roster.entries:
		t.ok(roster.build_for(entry).is_valid(), "%s ist kampfbereit" % entry.name)
	for e in Charger.element_ids():
		t.equal(roster.phases(e), 6, "6 %s-Phasen" % e)
	t.equal(roster.blanks(), 2, "2 Rohlinge")
	t.equal(int(roster.caches.get("city", 0)), 5, "5 Neon Caches")
	t.equal(roster.coins, 200, "200 Platzhaltercoin")


func test_variants_keep_the_chassis_name_with_a_faction_subtitle() -> void:
	# 21. Nov. 2026 (Spieler): Varianten heissen wie ihr Chassis, die Fraktion
	# steht darunter; neue DROMEs behalten ihren eigenen Namen.
	t.equal(Roster.faction_drome_name("mecha_molok"), "Molok", "Variante heisst Molok")
	t.equal(Roster.faction_drome_name("neon_vireo"), "Neon Vireo", "neuer DROME behaelt seinen Namen")
	t.equal(Roster.subtitle_for(""), "CyberDrome", "Standard-Untertitel")
	t.equal(Roster.subtitle_for("Mecha"), "Mega Mechas", "Fraktion als Untertitel")
	var roster := _fresh()
	var data := roster.to_dict()
	var entry: Dictionary = (data["roster"] as Array)[0]
	entry["variant"] = "mecha_molok"
	entry["name"] = "Mecha Molok"
	var loaded := Roster.new()
	loaded.load_dict(data)
	t.equal(loaded.entries[0].name, "Molok", "alter Name wird beim Laden umbenannt")
	t.equal(Roster.subtitle(loaded.entries[0]), "Mega Mechas", "mit Fraktion darunter")
