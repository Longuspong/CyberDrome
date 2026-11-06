extends RefCounted

## M2: Stat-Berechnung, Validierung, Kampfwert.

var t


## Der Standardaufbau eines Bausatzes: eigener Kopf, Kern, Antrieb, und die
## eigene Ausruestung in so vielen Slots, wie das Chassis Halter hat.
func _stock(set_id: String) -> DromeBuild:
	var chassis: PartData = null
	for part in PartDB.of_type(PartData.Type.BODY):
		if part.set_id == set_id:
			chassis = part
	var assignment := {"body": chassis.id}
	for type in [PartData.Type.HEAD, PartData.Type.FEET, PartData.Type.CORE]:
		for part in PartDB.of_type(type):
			if part.set_id == set_id:
				assignment[part.slot_name()] = part.id

	var pool: Array = []
	for part in PartDB.of_type(PartData.Type.EQUIPMENT):
		if part.set_id == set_id:
			pool.append(part)
	pool.sort_custom(func(a, b): return a.category == "weapon" and b.category != "weapon")
	for slot in chassis.equip_slots():
		for part in pool:
			if part.id in assignment.values():
				continue
			if chassis.accepts(part, slot):
				assignment[slot] = part.id
				break
	return DromeBuild.create(set_id.to_upper(), assignment)


func test_library_loaded() -> void:
	t.equal(PartDB.parts.size(), 28, "28 Bauteile erwartet")
	t.equal(PartDB.sets.size(), 4, "4 Bausaetze erwartet")
	for part in PartDB.parts.values():
		t.equal(part.views.size(), 4, "%s braucht vier Ansichten" % part.id)


func test_stock_builds_are_valid() -> void:
	for set_id in ["bot1", "bot2", "bot3", "bot4"]:
		var build := _stock(set_id)
		var problems := build.validate()
		t.ok(problems.is_empty(), "%s: %s" % [set_id, ", ".join(problems)])
		if problems.is_empty():
			var s := build.stats()
			t.note("%s  hp %3d  spd %2d  atk %d  def %d  kampfwert %.0f"
				% [set_id, s["hp_max"], s["spd"],
					s["atk"], s["def"], build.power_score()])


func test_stats_are_pure_sum() -> void:
	var build := _stock("bot1")
	var expected := 0
	for part in build.all_parts():
		expected += part.hp
	t.equal(build.stats()["hp_max"], expected, "hp ist die Summe der Teile")


func test_empty_build_reports_every_missing_slot() -> void:
	var build := DromeBuild.new()
	var problems := build.validate()
	t.ok(problems.has("Chassis fehlt"), "leerer Aufbau meldet fehlendes Chassis")
	t.ok(problems.has("Kern fehlt"), "leerer Aufbau meldet fehlenden Kern")
	t.ok(problems.has("Antrieb fehlt"), "leerer Aufbau meldet fehlenden Antrieb")
	t.ok(not build.is_valid(), "leerer Aufbau ist ungueltig")


func test_a_build_without_a_weapon_is_a_decision_not_an_error() -> void:
	# Frueher war "Keine Waffe bestueckt" ein struktureller Fehler. Das nahm dem
	# Slotmodell die Aussage, fuer die es da ist: welche Aktionen ein DROME hat,
	# sagt seine Ausruestung. Wer Deflektor und Drohnen-Pod traegt, hat eben
	# keinen Angriff -- eine Entscheidung mit Folgen, keine Panne. Beide Gadgets
	# sind rein passiv (Panzerung bzw. Selbstheilung), der Techniker also ganz
	# ohne aktive Aktion -- und trotzdem gueltig.
	var techniker := DromeBuild.create("TECHNIKER", {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": &"eq_deflector", "equip_right": &"eq_drone_pod"})
	t.ok(techniker.weapons().is_empty(), "der Techniker traegt keine Waffe")
	t.ok(techniker.is_valid(),
		"und ist trotzdem baubar: %s" % ", ".join(techniker.validate()))
	t.ok(techniker.actions_of(ActionData.Category.ATTACK).is_empty(),
		"die Folge steht in der Aktionsliste: kein Angriff")
	t.ok(techniker.actions().is_empty(),
		"beide Gadgets sind passiv -- gar keine Aktion, und das ist gueltig")


func test_the_payload_slows_you_down() -> void:
	# Masse bremst: die Belagerungskanone zahlt in Gewicht und Tempo.
	var step := Config.get_int("spd_weight_step", 4)
	var bare := DromeBuild.create("NACKT", {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core"})
	var armed := bare.clone()
	armed.slots["equip_left"] = &"eq_siege_cannon"

	var cannon := PartDB.get_part(&"eq_siege_cannon")

	t.equal(bare.payload_slowdown(), 0, "ohne Zuladung bremst nichts")
	t.equal(armed.payload_slowdown(), cannon.weight / step,
		"mit Kanone kostet die Zuladung Tempo")
	t.equal(armed.stats()["spd"], bare.stats()["spd"] - armed.payload_slowdown(),
		"und der Abzug steht in den Stats, nicht nur in der Rechnung")


func test_the_same_weapon_slows_every_chassis_equally() -> void:
	# Gerechnet wird auf der Ausruestung, nicht auf dem Gesamtgewicht. Deshalb
	# bremst dieselbe Waffe ueberall gleich viel -- ein Aufbau kann sich seinem
	# Tempoverlust nicht durch ein groesseres Chassis entziehen.
	var molok := DromeBuild.create("MOLOK", {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": &"eq_rune_staff"})
	var vireo := DromeBuild.create("VIREO", {
		"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core",
		"equip_left": &"eq_rune_staff"})
	t.equal(molok.payload_slowdown(), vireo.payload_slowdown(),
		"derselbe Runenstab, derselbe Abzug")

	var heavy := molok.clone()
	heavy.slots["equip_left"] = &"eq_siege_cannon"
	t.ok(heavy.payload_slowdown() > molok.payload_slowdown(),
		"die schwerere Waffe bremst staerker (%d gegen %d)"
		% [heavy.payload_slowdown(), molok.payload_slowdown()])


func test_the_molok_has_two_holders() -> void:
	# Seit Nov. 2026: ein Platz je DROME, der Molok zwei -- links alles bis
	# schwer, rechts nur Schild oder Gadget.
	var molok := DromeBuild.create("MOLOK", {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": &"eq_siege_cannon", "equip_right": &"eq_deflector"})
	t.ok(molok.is_valid(), "Kanone und Deflektor sind baubar: %s"
		% ", ".join(molok.validate()))

	var two_guns := molok.clone()
	two_guns.slots["equip_right"] = &"eq_rail_lance"
	t.ok(not two_guns.is_valid(), "eine zweite Waffe rechts nicht")

	var shoulder := molok.clone()
	shoulder.slots["equip_shoulder"] = &"eq_drone_pod"
	t.ok(not shoulder.is_valid(), "die Schulter ist kein Halter mehr")
	t.equal(shoulder.equipment().size(), 2, "und was dort steckt, zaehlt nicht")


func test_apply_chassis_sets_the_whole_frame() -> void:
	# Ein Chassis-Pick setzt Koerper, Kopf und Fuesse gemeinsam aus einem Set
	# (GAME_DESIGN §9), seit 6g auch den Kern (nur noch Optik). Die Ausruestung
	# bleibt unberuehrt -- sie ist eine eigene Entscheidung.
	var build := DromeBuild.create("WECHSEL", {
		"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"mage_core",
		"equip_left": &"eq_pulse_blaster",
	})
	build.apply_chassis(&"jugg_body")
	t.equal(build.slots["body"], &"jugg_body", "Koerper gewechselt")
	t.equal(build.slots["head"], &"jugg_head", "der Kopf zieht mit")
	t.equal(build.slots["feet"], &"jugg_feet", "die Fuesse ziehen mit")
	t.equal(build.slots["core"], &"jugg_core", "der Kern zieht mit -- er gehoert zum Rahmen")
	t.equal(build.slots["equip_left"], &"eq_pulse_blaster", "die Ausruestung bleibt")

	var frame_sets := {}
	for slot in ["body", "head", "feet"]:
		frame_sets[PartDB.get_part(build.slots[slot]).set_id] = true
	t.equal(frame_sets.size(), 1, "der Rahmen ist danach eine stimmige Huelle")


func test_the_vireo_has_one_holder() -> void:
	var vireo := DromeBuild.create("VIREO", {
		"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core",
		"equip_left": &"eq_pulse_blaster", "equip_right": &"eq_pulse_blaster",
	})
	t.ok(not vireo.is_valid(), "ein zweiter Blaster am rechten Anker ist ungueltig")
	t.equal(vireo.weapons().size(), 1, "und nur einer schiesst")
	t.ok(", ".join(vireo.validate()).contains("Halter"),
		"die Meldung sagt warum: %s" % ", ".join(vireo.validate()))


func test_weight_no_longer_vetoes_a_build_only_slows_it() -> void:
	# Eine schwere Huelle mit schwerer Waffe riss frueher die Traglast. Jetzt ist
	# Gewicht ein Tempo-Preis, kein Verbot: die Validierung nennt keine Traglast
	# mehr. (Der Molok ist die schwere Huelle -- fremde Sockel zu mischen geht
	# seit der Huellen-Regel ohnehin nicht mehr.)
	var build := DromeBuild.create("SCHWER", {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": &"eq_siege_cannon",
	})
	t.ok(build.is_valid(), "der schwere Aufbau ist baubar: %s"
		% ", ".join(build.validate()))
	for line in build.validate():
		t.ok(not line.begins_with("Traglast"),
			"keine Traglast-Grenze mehr in der Validierung: %s" % line)


func test_the_frame_is_one_hull() -> void:
	# Kopf, Koerper und Fuesse bilden gemeinsam die Huelle und muessen aus einem
	# Set stammen (GAME_DESIGN §9). Kein Strix-Kopf auf Molok-Beinen. Der Kern
	# bleibt frei -- er ist die Stil-Achse, kein Rahmen.
	var mixed := DromeBuild.create("MISCHMASCH", {
		"body": &"jugg_body", "head": &"scout_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": &"eq_siege_cannon",
	})
	var named := false
	for line in mixed.validate():
		if line.begins_with("Rahmen ist keine Huelle"):
			named = true
	t.ok(named, "gemischter Rahmen wird beim Namen genannt: %s"
		% ", ".join(mixed.validate()))
	t.ok(not mixed.is_valid(), "und ist damit ungueltig")

	# Fremder KERN in derselben Huelle ist dagegen voellig in Ordnung.
	var foreign_core := DromeBuild.create("FREMDKERN", {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"scout_core",
		"equip_left": &"eq_siege_cannon",
	})
	t.ok(foreign_core.is_valid(),
		"ein universeller Kern in einer stimmigen Huelle ist baubar: %s"
		% ", ".join(foreign_core.validate()))


func test_slot_rules_are_enforced() -> void:
	var jugg := PartDB.get_part(&"jugg_body")
	var cannon := PartDB.get_part(&"eq_siege_cannon")
	var pod := PartDB.get_part(&"eq_drone_pod")
	t.ok(jugg.accepts(cannon, "equip_left"), "schwere Kanone passt an den linken Arm")
	t.ok(not jugg.accepts(cannon, "equip_right"), "rechts nur Schild oder Gadget")
	t.ok(jugg.accepts(pod, "equip_right"), "der Drohnen-Pod passt rechts")
	t.ok(not jugg.accepts(pod, "equip_shoulder"), "die Schulter ist reine Optik")

	var scout := PartDB.get_part(&"scout_body")
	t.ok(not scout.accepts(cannon, "equip_left"),
		"ein Sprinter traegt keine Belagerungskanone")
	t.ok(not scout.accepts(PartDB.get_part(&"eq_deflector"), "equip_left"),
		"und keinen Schild")


func test_equip_slots_come_from_anchors() -> void:
	t.equal(PartDB.get_part(&"scout_body").equip_slots().size(), 1, "Vireo: 1 Platz")
	t.equal(PartDB.get_part(&"jugg_body").equip_slots().size(), 2, "Molok: 2 Plaetze")
	t.equal(PartDB.get_part(&"mage_body").equip_slots().size(), 1, "Nimbus: 1 Platz")
	t.equal(PartDB.get_part(&"strix_body").equip_slots().size(), 1, "Strix: 1 Platz")


func test_chassis_swap_drops_equipment_that_no_longer_fits() -> void:
	# Molok mit Kanone -> auf den Vireo gewechselt. Der Vireo nimmt nur bis
	# medium, die Kanone faellt ab. Die Vorschau muss das zeigen, sonst
	# verspricht sie Werte fuer einen Aufbau, den es nicht geben kann.
	var build := DromeBuild.create("WECHSEL", {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": &"eq_siege_cannon",
	})
	var before: int = build.stats()["weight"]
	var delta := build.preview_delta("body", &"scout_body")
	t.ok(delta.has("weight"), "Chassiswechsel aendert das Gewicht")
	t.ok(delta["weight"]["after"] < before,
		"die nicht mehr passende Kanone faellt aus der Rechnung")


func test_power_score_rewards_the_obviously_stronger_build() -> void:
	var heavy := _stock("bot2")
	var light := _stock("bot1")
	t.ok(heavy.power_score() > light.power_score(),
		"der Molok ist staerker als der Vireo (%.0f vs %.0f)"
		% [heavy.power_score(), light.power_score()])


func test_loadout_survives_a_round_trip() -> void:
	var build := _stock("bot3")
	var restored := DromeBuild.from_loadout(build.to_loadout())
	t.equal(restored.slots, build.slots, "Slots ueberstehen Speichern und Laden")
	t.equal(restored.stats(), build.stats(), "Stats ueberstehen Speichern und Laden")


# ---------------------------------------------------------------------------
# Aktionen: einmal je Wirkung, getrennt nach Budget
# ---------------------------------------------------------------------------

func test_the_same_part_twice_grants_one_action() -> void:
	# Zwei Orbit-Fokusse am Molok. Die Stats summieren sich, die Aktionsliste
	# nicht: ein zweiter Eintrag verspraeche eine Wahl, die es nicht gibt.
	var build := DromeBuild.create("DOPPELT", {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": &"eq_siege_cannon", "equip_right": &"eq_orbit_focus",
	})
	var single: int = build.stats()["atk"]
	var actions_before := build.actions().size()

	build.slots["equip_left"] = &"eq_orbit_focus"
	t.equal(build.stats()["atk"], single + 1,
		"zwei Fokusse geben weiterhin zweimal ATK")
	t.equal(build.actions().size(), 1,
		"aber nur EINEN Orbit-Sog (vorher waren es %d Eintraege)" % actions_before)


func test_actions_are_split_by_budget() -> void:
	var build := DromeBuild.create("GEMISCHT", {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": &"eq_siege_cannon", "equip_right": &"eq_orbit_focus",
	})
	var attacks := build.actions_of(ActionData.Category.ATTACK)
	var abilities := build.actions_of(ActionData.Category.ABILITY)
	# Die Kanone traegt zwei Aktionen: Belagerungsschlag (Angriff) UND
	# Sperrfeuer (Faehigkeit). Dazu der Orbit-Sog aus dem Fokus. Also ein
	# Angriff, zwei Faehigkeiten.
	t.equal(attacks.size(), 1, "nur der Belagerungsschlag ist ein Angriff")
	t.equal(abilities.size(), 2, "Sperrfeuer und Orbit-Sog sind Faehigkeiten")
	t.equal(build.attack_budget(), 1, "eine Waffe -- ein Angriffs-Aktionspunkt")
	t.equal(attacks.size() + abilities.size(), build.actions().size(),
		"jede Aktion gehoert zu genau einem Budget")


func test_every_weapon_has_exactly_one_attack() -> void:
	# Eine Waffe schiesst in ihrem Takt und traegt dazu eine eigene
	# Faehigkeit. Genau EIN Angriff: er ist der Takt, an dem die Faehigkeit
	# zaehlt.
	for part in PartDB.of_type(PartData.Type.EQUIPMENT):
		if part.category != "weapon":
			continue
		var attacks: Array = part.actions.filter(func(a): return a.is_attack())
		t.equal(attacks.size(), 1,
			"%s ist eine Waffe mit genau einem Angriff" % part.id)


func test_every_action_names_its_source_part() -> void:
	for part in PartDB.parts.values():
		for action in part.actions:
			t.equal(action.source_part_name, part.display_name,
				"%s nennt sein Bauteil" % action.id)
			var described := "\n".join(action.description_lines())
			t.ok(described.contains("Reichweite"),
				"%s beschreibt seine Reichweite" % action.id)


# ---------------------------------------------------------------------------
# Wohin ein Klick in der Bibliothek einraeumt
# ---------------------------------------------------------------------------

func test_a_part_finds_its_own_slot() -> void:
	# Die Werkstatt zeigt links ALLE Teile. Damit muss der Klick selbst
	# entscheiden, wohin -- sonst waere die Liste nur ein Katalog zum Ansehen.
	var build := _stock("bot2")          # Molok: drei Anker
	var head := PartDB.get_part(&"strix_head")
	t.equal(build.slot_for(head), "head", "ein Kopf geht in den Kopfslot")

	var chassis := PartDB.get_part(&"scout_body")
	t.equal(build.slot_for(chassis), "body", "ein Chassis in den Chassisslot")

	# Ausruestung: angewaehlter Halter zuerst, wenn er sie nimmt.
	var shield := PartDB.get_part(&"eq_deflector")
	t.equal(build.slot_for(shield, "equip_right"), "equip_right",
		"der angewaehlte Halter gewinnt")

	# Rechts nimmt der Molok nur Schild oder Gadget. Eine Kanone landet deshalb
	# NICHT dort, auch wenn der rechte Halter angewaehlt ist.
	var cannon := PartDB.get_part(&"eq_siege_cannon")
	var target := build.slot_for(cannon, "equip_right")
	t.equal(target, "equip_left", "die Kanone landet links")


func test_a_part_that_fits_nowhere_says_so() -> void:
	# Der Vireo nimmt an beiden Armen nur bis mittel -- die Belagerungskanone
	# ist schwer und passt an ihm nirgendwohin. Die Bibliothek zeigt sie
	# trotzdem, ausgegraut und mit Grund; dafuer muss "nirgendwo" eine Antwort
	# sein und kein Zufallsslot.
	var build := _stock("bot1")
	var cannon := PartDB.get_part(&"eq_siege_cannon")
	t.equal(build.slot_for(cannon), "",
		"was in keinen Halter darf, bekommt keinen zugewiesen")


func test_the_first_free_holder_wins_before_an_occupied_one() -> void:
	var build := DromeBuild.create("HALBVOLL", {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": &"eq_siege_cannon",
	})
	var shield := PartDB.get_part(&"eq_deflector")
	t.equal(build.slot_for(shield), "equip_right",
		"der freie Halter wird vor dem belegten genommen")
	build.slots["equip_right"] = shield.id
	t.equal(build.slot_for(shield), "equip_left",
		"ist alles belegt, wird der erste passende ersetzt")


# ---------------------------------------------------------------------------
# Keine Bau-Budgets: nur die strukturelle Untergrenze gilt
# ---------------------------------------------------------------------------

## Ein Molok mit beiden Plaetzen belegt -- frueher (mit drei) der Grenzfall,
## an dem Traglast und Energie zugleich rissen.
func _overloaded_molok() -> DromeBuild:
	return DromeBuild.create("VOLLBESTUECKT", {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": &"eq_siege_cannon", "equip_right": &"eq_drone_pod",
	})


func test_no_build_budget_gates_a_full_loadout() -> void:
	# Es gibt keine Traglast- und keine Energie-Grenze mehr. Ein vollbestueckter
	# Molok ist baubar; was ihn bremst, ist Tempo und Mana im Kampf, kein Riegel
	# in der Werkstatt.
	var build := _overloaded_molok()
	t.ok(build.is_valid(), "beide Plaetze voll ist baubar: %s"
		% ", ".join(build.validate()))


func test_the_structural_floor_still_holds() -> void:
	# Was ein DROME sein MUSS, gilt weiter: ohne Sockel kein Kampf. Das ist die
	# einzige verbliebene Grenze -- und die eigentliche Obergrenze der Masse,
	# denn Zuladung zieht SPD, und unter spd 1 ist ein Aufbau ungueltig.
	var crippled := DromeBuild.create("OHNE", {"body": &"jugg_body"})
	t.ok(not crippled.is_valid(),
		"fehlende Sockel bleiben ein Fehler: %s"
		% ", ".join(crippled.validate()))


func test_generated_enemies_are_valid() -> void:
	# Gegner laufen jetzt durch dieselben Regeln wie der Spieler -- es gibt keine
	# strengere Variante mehr, weil es keine abschaltbaren Budgets mehr gibt.
	var squad := EnemyGenerator.new(4711).generate(3, 600.0)
	for build in squad:
		t.ok(build.is_valid(),
			"Gegner %s ist gueltig: %s"
			% [build.display_name, ", ".join(build.validate())])
		t.ok(not build.weapons().is_empty(),
			"Gegner %s traegt eine Waffe" % build.display_name)
		# Der Rahmen ist eine Huelle -- Kopf, Koerper, Fuesse aus einem Set.
		var sets := {}
		for slot in ["body", "head", "feet"]:
			sets[build.part_in(slot).set_id] = true
		t.equal(sets.size(), 1,
			"Gegner %s hat einen stimmigen Rahmen" % build.display_name)
