extends RefCounted

## M2: Stat-Berechnung, Validierung, Kampfwert.

var t


## Der Standardaufbau eines Bausatzes: eigener Kopf, Kern, Antrieb, und die
## eigene Ausruestung in so vielen Slots, wie das Chassis Anker hat.
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
	t.equal(PartDB.parts.size(), 24, "24 Bauteile erwartet")
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
			t.note("%s  hp %3d  en %3d  spd %2d  mov %d  atk %d  def %d  kampfwert %.0f"
				% [set_id, s["hp_max"], s["en_max"], s["spd"], s["mov"],
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
	# sagt seine Ausruestung. Wer Deflektor und Reparaturdrohnen traegt, hat
	# eben keinen Angriff -- eine Entscheidung mit Folgen, keine Panne.
	var techniker := DromeBuild.create("TECHNIKER", {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": &"eq_deflector", "equip_shoulder": &"eq_drone_pod"})
	t.ok(techniker.weapons().is_empty(), "der Techniker traegt keine Waffe")
	t.ok(techniker.is_valid(),
		"und ist trotzdem baubar: %s" % ", ".join(techniker.validate()))
	t.ok(techniker.actions_of(ActionData.Category.ATTACK).is_empty(),
		"die Folge steht in der Aktionsliste: kein Angriff")
	t.ok(not techniker.actions_of(ActionData.Category.ABILITY).is_empty(),
		"seine Faehigkeit hat er")


func test_the_payload_slows_you_down() -> void:
	# Masse bremst, Strom kostet. Die Belagerungskanone zieht keinen Strom mehr
	# (power_draw 0, en_cost 0) -- bezahlt wird sie in Gewicht und Tempo.
	var step := Config.get_int("spd_weight_step", 4)
	var bare := DromeBuild.create("NACKT", {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core"})
	var armed := bare.clone()
	armed.slots["equip_left"] = &"eq_siege_cannon"

	var cannon := PartDB.get_part(&"eq_siege_cannon")
	t.equal(cannon.power_draw, 0, "die Kanone braucht keinen Bau-Strom")
	t.equal(cannon.action.en_cost, 0, "und keine Energie im Kampf")

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


func test_the_molok_can_finally_hold_two_heavy_arms() -> void:
	# Zwei schwere Waffen an zwei schweren Armen scheiterten an EINEM Punkt
	# Traglast (32/31). Der schwere Slot war damit eine Erlaubnis, die das
	# Budget wieder einkassierte.
	var molok := DromeBuild.create("MOLOK", {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": &"eq_siege_cannon", "equip_right": &"eq_rail_lance"})
	t.ok(molok.is_valid(), "zwei schwere Arme sind baubar: %s"
		% ", ".join(molok.validate()))

	# Der Schulterpod obendrauf bleibt ausserhalb -- die Traglast ist gelockert,
	# nicht abgeschafft.
	var overloaded := molok.clone()
	overloaded.slots["equip_shoulder"] = &"eq_orbit_focus"
	t.ok(not overloaded.is_valid(),
		"mit Schulterpod reisst sie wieder: %s" % ", ".join(overloaded.validate()))


func test_no_ability_costs_more_than_the_smallest_core_holds() -> void:
	# Die Energiekosten der Faehigkeiten sind bewusst hoch -- drei bis vier
	# Anwendungen je Gefecht. Waere eine davon teurer als der kleinste Tank im
	# Bestand, stuende sie in der Aktionsleiste und liesse sich nie ziehen.
	var smallest := 0
	for part in PartDB.of_type(PartData.Type.CORE):
		if smallest == 0 or part.en_max < smallest:
			smallest = part.en_max

	for part in PartDB.of_type(PartData.Type.EQUIPMENT):
		if part.action == null:
			continue
		t.ok(part.action.en_cost <= smallest,
			"%s kostet %d, kleinster Kern haelt %d"
			% [part.action.display_name, part.action.en_cost, smallest])


func test_overweight_is_named_not_just_rejected() -> void:
	# Der Vireo traegt 18. Kern und Antrieb des Molok wiegen allein schon mehr,
	# als bei ihm nach Kopf und Waffe uebrig bleibt.
	var build := DromeBuild.create("UEBERLADEN", {
		"body": &"scout_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": &"eq_pulse_blaster",
	})
	var problems := build.validate()
	var found := false
	for line in problems:
		if line.begins_with("Traglast ueberschritten"):
			found = true
	t.ok(found, "Traglast wird beim Namen genannt, nicht nur abgelehnt: %s"
		% ", ".join(problems))


func test_slot_rules_are_enforced() -> void:
	var jugg := PartDB.get_part(&"jugg_body")
	var cannon := PartDB.get_part(&"eq_siege_cannon")
	var pod := PartDB.get_part(&"eq_drone_pod")
	t.ok(jugg.accepts(cannon, "equip_left"),
		"schwere Kanone passt an den schweren Arm")
	t.ok(not jugg.accepts(cannon, "equip_shoulder"),
		"schwere Kanone passt nicht auf die Schulter (nur light + support)")
	t.ok(jugg.accepts(pod, "equip_shoulder"),
		"leichter Support-Pod passt auf die Schulter")

	var scout := PartDB.get_part(&"scout_body")
	t.ok(not scout.accepts(cannon, "equip_left"),
		"ein Sprinter traegt keine Belagerungskanone")


func test_equip_slots_come_from_anchors() -> void:
	t.equal(PartDB.get_part(&"scout_body").equip_slots().size(), 2, "Vireo: 2 Slots")
	t.equal(PartDB.get_part(&"jugg_body").equip_slots().size(), 3, "Molok: 3 Slots")
	t.equal(PartDB.get_part(&"strix_body").equip_slots().size(), 1, "Strix: 1 Slot")


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


func test_every_ranged_action_requires_line_of_sight() -> void:
	# Ohne diese Regel waere das gesamte Terrainsystem Dekoration -- dann
	# schoesse man quer durch Betonpfeiler.
	for part in PartDB.of_type(PartData.Type.EQUIPMENT):
		if part.action == null:
			continue
		if part.action.range_tiles > 1:
			t.ok(part.action.requires_line_of_sight,
				"%s hat Reichweite %d und braucht Sichtlinie"
				% [part.id, part.action.range_tiles])


# ---------------------------------------------------------------------------
# Aktionen: einmal je Wirkung, getrennt nach Budget
# ---------------------------------------------------------------------------

func test_the_same_part_twice_grants_one_action() -> void:
	# Zwei Orbit-Fokusse am Nimbus. Die Stats summieren sich, die Aktionsliste
	# nicht: das Budget des Zuges gibt den Orbit-Sog ohnehin nur einmal her,
	# und ein zweiter Eintrag verspraeche eine Wahl, die es nicht gibt.
	var build := DromeBuild.create("DOPPELT", {
		"body": &"mage_body", "head": &"mage_head",
		"feet": &"mage_drive", "core": &"mage_core",
		"equip_left": &"eq_rune_staff", "equip_right": &"eq_orbit_focus",
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
		"body": &"mage_body", "head": &"mage_head",
		"feet": &"mage_drive", "core": &"mage_core",
		"equip_left": &"eq_rune_staff", "equip_right": &"eq_orbit_focus",
	})
	var attacks := build.actions_of(ActionData.Category.ATTACK)
	var abilities := build.actions_of(ActionData.Category.ABILITY)
	t.equal(attacks.size(), 1, "der Runenstab ist ein Angriff")
	t.equal(abilities.size(), 1, "der Orbit-Sog ist eine Faehigkeit")
	t.equal(attacks.size() + abilities.size(), build.actions().size(),
		"jede Aktion gehoert zu genau einem Budget")


func test_weapons_are_plain_attacks() -> void:
	# Eine Waffe schiesst; sie ist keine Faehigkeit. Waere der Blaster als
	# Faehigkeit gefuehrt, naehme er dem Aufbau still seine Faehigkeitsaktion
	# weg -- und der Spieler saehe nur, dass etwas fehlt.
	for part in PartDB.of_type(PartData.Type.EQUIPMENT):
		if part.category != "weapon" or part.action == null:
			continue
		t.ok(part.action.is_attack(),
			"%s ist eine Waffe und damit ein normaler Angriff" % part.id)
		t.equal(str(part.action.damage_type), "normal",
			"%s richtet normalen Schaden an" % part.id)


func test_every_action_names_its_source_part() -> void:
	for part in PartDB.parts.values():
		if part.action == null:
			continue
		t.equal(part.action.source_part_name, part.display_name,
			"%s nennt sein Bauteil" % part.action.id)
		var described := "\n".join(part.action.description_lines())
		t.ok(described.contains("Reichweite"),
			"%s beschreibt seine Reichweite" % part.action.id)


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
	var blaster := PartDB.get_part(&"eq_pulse_blaster")
	t.equal(build.slot_for(blaster, "equip_right"), "equip_right",
		"der angewaehlte Halter gewinnt")

	# Die Schulter des Molok nimmt nur leichte Support-Module. Eine schwere
	# Kanone landet deshalb NICHT dort, auch wenn die Schulter angewaehlt ist.
	var cannon := PartDB.get_part(&"eq_siege_cannon")
	var target := build.slot_for(cannon, "equip_shoulder")
	t.ok(target != "equip_shoulder",
		"die Kanone landet nicht auf der Schulter, sondern in %s" % target)
	t.ok(PartDB.get_part(build.slots["body"]).accepts(cannon, target),
		"und der gewaehlte Halter nimmt sie wirklich")


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
		"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core",
		"equip_left": &"eq_pulse_blaster",
	})
	var shield := PartDB.get_part(&"eq_deflector")
	t.equal(build.slot_for(shield), "equip_right",
		"der freie Halter wird vor dem belegten genommen")
	build.slots["equip_right"] = shield.id
	t.equal(build.slot_for(shield), "equip_left",
		"ist alles belegt, wird der erste passende ersetzt")


# ---------------------------------------------------------------------------
# Playtest: die beiden Budgetgrenzen abschaltbar
# ---------------------------------------------------------------------------

## Ein Molok mit drei bestueckten Slots. Genau der Fall, an dem der Schalter
## haengt: der Fusionskern gibt nicht genug Energie fuer alle drei her.
## Der Aufbau, an dem die Traglast noch reisst: zwei schwere Arme UND der
## Schulterpod. Zwei schwere Arme allein gehen inzwischen (32 von 33) -- der
## dritte Anker ist die Grenze, nicht der zweite.
func _overloaded_molok() -> DromeBuild:
	return DromeBuild.create("VOLLBESTUECKT", {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": &"eq_siege_cannon", "equip_right": &"eq_rail_lance",
		"equip_shoulder": &"eq_drone_pod",
	})


func test_playtest_switch_lifts_only_the_two_budgets() -> void:
	var build := _overloaded_molok()
	t.ok(not build.budget_problems().is_empty(),
		"drei volle Slots sprengen Traglast oder Energie: %s"
		% ", ".join(build.validate()))
	t.ok(not build.is_valid(), "und sind damit normal ungueltig")

	DromeBuild.ignore_limits = true
	t.ok(build.is_valid(), "im Playtest ist derselbe Aufbau baubar")
	t.ok(not build.is_strictly_valid(),
		"die strengen Regeln sagen weiterhin nein")
	t.ok(not build.budget_problems().is_empty(),
		"und die Ueberschreitung wird weiterhin genannt, nicht verschwiegen")

	# Was ein DROME sein MUSS, bleibt auch im Playtest Pflicht.
	var crippled := DromeBuild.create("OHNE", {"body": &"jugg_body"})
	t.ok(not crippled.is_valid(),
		"fehlende Sockel bleiben auch im Playtest ein Fehler: %s"
		% ", ".join(crippled.blocking_problems()))
	DromeBuild.ignore_limits = false
	t.ok(not build.is_valid(), "ausgeschaltet gilt wieder die Grenze")


func test_enemies_stay_strict_while_the_player_playtests() -> void:
	# Sonst verschoebe der Schalter still den Massstab: der Spieler testet
	# einen ueberladenen Aufbau gegen ebenso ueberladene Gegner und lernt
	# nichts ueber sein Balancing.
	DromeBuild.ignore_limits = true
	var squad := EnemyGenerator.new(4711).generate(3, 600.0)
	for build in squad:
		t.ok(build.is_strictly_valid(),
			"Gegner %s haelt die vollen Regeln ein: %s"
			% [build.display_name, ", ".join(build.validate())])
	DromeBuild.ignore_limits = false
