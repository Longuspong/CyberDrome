extends RefCounted

## M4/M8/M9: der Kampf als Ganzes.
##
## Spielt vollstaendige Kaempfe ohne Szene und ohne Eingabe -- beide Seiten
## von der KI gesteuert. Was hier durchlaeuft, laeuft auch mit einem Spieler
## davor; was hier haengt oder abstuerzt, wuerde im Spiel genauso haengen,
## nur schwerer zu finden.

var t

## Sicherheitsnetz. Ein Kampf, der so viele Zuege braucht, ist kein Kampf mehr.
const MAX_TURNS := 400


func _squad() -> Array:
	return [
		DromeBuild.create("ALPHA", {
			"body": &"scout_body", "head": &"scout_head",
			"feet": &"scout_feet", "core": &"scout_core",
			"equip_left": &"eq_pulse_blaster", "equip_right": &"eq_deflector"}),
		DromeBuild.create("BETA", {
			"body": &"strix_body", "head": &"strix_head",
			"feet": &"strix_feet", "core": &"strix_core",
			"equip_center": &"eq_rail_lance"}),
	]


## Spielt einen Kampf zu Ende. Gibt die Zusammenfassung zurueck.
func _play(seed_value: int) -> Dictionary:
	var battle := BattleManager.new()
	battle.setup(seed_value, _squad())
	var controller := AIController.new(battle)

	var turns := 0
	while battle.outcome == BattleManager.Outcome.RUNNING and turns < MAX_TURNS:
		turns += 1
		var unit := battle.begin_next_turn()
		if unit == null:
			if battle.outcome != BattleManager.Outcome.RUNNING:
				break
			continue
		controller.run_turn()
		if battle.outcome == BattleManager.Outcome.RUNNING:
			battle.end_turn()

	var result := battle.build_result()
	result["turns"] = turns
	battle.free()
	return result


func test_a_battle_runs_to_a_conclusion() -> void:
	var outcomes := {}
	var total_turns := 0
	for i in 25:
		var result := _play(4000 + i)
		total_turns += result["turns"]
		t.ok(result["outcome"] != BattleManager.Outcome.RUNNING,
			"Kampf %d endet (nach %d Zuegen)" % [4000 + i, result["turns"]])
		var label := BattleManager.outcome_label(result["outcome"])
		outcomes[label] = outcomes.get(label, 0) + 1
	t.note("25 Kaempfe, im Schnitt %.0f Zuege: %s"
		% [float(total_turns) / 25.0, str(outcomes)])


func test_both_sides_can_win() -> void:
	# Eine KI, die nie gewinnt oder nie verliert, ist entweder kaputt oder
	# das Matching ist es.
	var seen := {}
	for i in 40:
		var result := _play(9000 + i)
		seen[BattleManager.outcome_label(result["outcome"])] = true
	t.ok(seen.size() > 1,
		"nicht jeder Kampf endet gleich: %s" % str(seen.keys()))


func test_damage_actually_happens() -> void:
	var result := _play(1234)
	var dealt := 0
	for row in result["units"]:
		dealt += row["dealt"]
	t.ok(dealt > 0, "im Kampf wurde Schaden verursacht (%d)" % dealt)


func test_same_seed_gives_the_same_battle() -> void:
	# Akzeptanzkriterium: denselben Seed zweimal spielen und exakt dasselbe
	# bekommen -- Karte, Region, Mutator, Gegner, Ausgang.
	var a := _play(20260806)
	var b := _play(20260806)
	t.equal(a["region"], b["region"], "dieselbe Region")
	t.equal(a["mutator"], b["mutator"], "derselbe Mutator")
	t.equal(a["cycles"], b["cycles"], "dieselbe Zyklenzahl")
	t.equal(BattleManager.outcome_label(a["outcome"]),
		BattleManager.outcome_label(b["outcome"]), "derselbe Ausgang")
	for i in a["units"].size():
		t.equal(a["units"][i]["name"], b["units"][i]["name"],
			"dieselben DROMEs in derselben Reihenfolge")
		t.equal(a["units"][i]["taken"], b["units"][i]["taken"],
			"derselbe erlittene Schaden bei %s" % a["units"][i]["name"])


func test_enemy_threat_matches_the_player_squad() -> void:
	var player := _squad()
	var target := DromeBuild.squad_threat(player)
	var tolerance := Config.get_float("threat_tolerance", 0.12)
	var misses := 0
	for i in 30:
		var generator := EnemyGenerator.new(7000 + i)
		generator.generate(player.size(), target)
		if absf(generator.achieved_threat - target) / target > tolerance:
			misses += 1
	t.ok(misses <= 3, "das Gegner-Matching trifft die Toleranz (%d von 30 daneben)"
		% misses)


func test_generated_enemies_are_always_valid() -> void:
	# Auch auf dem Strix, der genau einen Ausruestungsanker hat.
	for i in 40:
		for build in EnemyGenerator.new(8000 + i).generate(3, 600.0):
			var problems: Array[String] = build.validate()
			t.ok(problems.is_empty(), "%s ist baubar: %s"
				% [build.display_name, ", ".join(problems)])


func test_every_mutator_produces_a_playable_battle() -> void:
	# Planiert nimmt der Karte drei Klassen, Schrottfeld verdoppelt die
	# Blocks. Beides darf keine Karte erzeugen, die niemand durchqueren kann.
	var pool: Array = Config.get_value("mutators", [])
	for meta in pool:
		var mutator := Mutator.from_meta(meta)
		var grid := MapGenerator.new(31337).generate(
			TerrainDB.get_region(&"city"), mutator.map_scales())
		var plain := MoveProfile.plain()
		var start := Vector2i(-1, -1)
		var goal := Vector2i(-1, -1)
		for tile in MapGenerator.deployment_zone(grid, true):
			if grid.can_stand_on(tile, plain):
				start = tile
				break
		for tile in MapGenerator.deployment_zone(grid, false):
			if grid.can_stand_on(tile, plain):
				goal = tile
				break
		t.ok(start.x >= 0 and goal.x >= 0 and grid.has_plain_path(start, goal),
			"Mutator %s erzeugt eine durchquerbare Karte" % mutator.display_name)


func test_bloodletting_actually_bleeds() -> void:
	var mutator := Mutator.from_meta({"id": "bloodletting", "name": "Aderlass",
		"turn_damage": 3})
	t.equal(mutator.turn_damage(), 3, "Aderlass zieht 3 Integritaet ab")

	var overclock := Mutator.from_meta({"id": "overclock", "name": "Uebertaktung",
		"spd_bonus": 6})
	var unit := Unit.create(_squad()[0], &"T1", true)
	var before := unit.spd()
	overclock.apply_to(unit)
	t.equal(unit.spd(), before + 6, "Uebertaktung wirkt ueber den Statuseffekt")
	t.equal(unit.stats["spd"], before,
		"der Build bleibt unangetastet -- der Mutator haengt daneben")
	unit.free()
