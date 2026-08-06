extends RefCounted

## M2: Stat-Berechnung, Validierung, Threat Score.

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
	t.equal(PartDB.parts.size(), 23, "23 Bauteile erwartet")
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
			t.note("%s  hp %3d  en %3d  spd %2d  mov %d  atk %d  def %d  threat %.0f"
				% [set_id, s["hp_max"], s["en_max"], s["spd"], s["mov"],
					s["atk"], s["def"], build.threat_score()])


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
	t.ok(problems.has("Keine Waffe bestueckt"), "leerer Aufbau meldet fehlende Waffe")
	t.ok(not build.is_valid(), "leerer Aufbau ist ungueltig")


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


func test_threat_score_rewards_the_obviously_stronger_build() -> void:
	var heavy := _stock("bot2")
	var light := _stock("bot1")
	t.ok(heavy.threat_score() > light.threat_score(),
		"der Molok ist bedrohlicher als der Vireo (%.0f vs %.0f)"
		% [heavy.threat_score(), light.threat_score()])


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
