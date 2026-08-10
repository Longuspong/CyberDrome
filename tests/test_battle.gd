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


## Zwei Molok-Aufbauten, die sich nur in der Waffe unterscheiden -- und beide
## tragen den Orbit-Sog auf der Schulter. Damit haengt der Unterschied im
## Verhalten allein an der Reichweite, so wie die Bewertung es behauptet.
func _with_orbit_pull(display_name: String, weapon: StringName) -> DromeBuild:
	return DromeBuild.create(display_name, {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": weapon, "equip_shoulder": &"eq_orbit_focus"})


func _pull_action(unit: Unit) -> ActionData:
	for action in unit.actions():
		if action.push_tiles != 0:
			return action
	return null


func test_the_ai_does_not_drag_its_target_into_its_own_face() -> void:
	# Der Orbit-Sog hat Staerke 0 und wurde ueber preview_damage() bewertet --
	# das liefert die Mindestmenge 1. Zusammen mit dem Faehigkeitsbudget, das
	# ein Angriffs-Aufbau ohnehin nicht braucht, hat die KI ihn jeden Zug
	# gezogen und sich als Fernkaempfer selbst den Abstand genommen.
	var battle := BattleManager.new()
	battle.setup(9210, [_with_orbit_pull("SCHUETZE", &"eq_rail_lance"),
		_with_orbit_pull("NAHKAMPF", &"eq_rune_staff")])
	var controller := AIController.new(battle)
	var sniper: Unit = battle.living(true)[0]
	var brawler: Unit = battle.living(true)[1]
	sniper.tile = Vector2i(4, 4)
	brawler.tile = Vector2i(4, 8)

	var pull := _pull_action(sniper)
	t.ok(pull != null and pull.power <= 0,
		"der Orbit-Sog zieht und richtet dabei keinen Schaden an")

	t.ok(controller._shove_score(sniper, pull, brawler) < 0.0,
		"wer weiter schiesst, will den Abstand behalten (%.1f)"
		% controller._shove_score(sniper, pull, brawler))
	t.ok(controller._action_score(sniper, pull, brawler) <= 0.0,
		"und zieht deshalb gar nicht -- _best_move() verwirft alles <= 0")

	t.ok(controller._shove_score(brawler, pull, sniper) > 0.0,
		"wer kuerzer schiesst, will ihn schliessen (%.1f)"
		% controller._shove_score(brawler, pull, sniper))
	battle.free()


func test_armour_can_never_swallow_a_whole_hit() -> void:
	# Der schwerste im Bestand baubare Aufbau gegen die schwaechste Waffe:
	# DEF 14 (Chassis 5 + Bunkerkopf 2 + Standbeine 2 + Deflektor 5) gegen den
	# Puls-Blaster mit Staerke 12. Ueber den flachen Abzug blieb davon die
	# Mindestmenge 1 -- 145 Integritaet bei 1 Schaden je Treffer sind 145
	# Treffer, und cycle_limit steht auf 30. Der Kampf konnte nicht enden.
	var bunker := DromeBuild.create("BUNKER", {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": &"eq_pulse_blaster", "equip_right": &"eq_deflector"})
	t.ok(bunker.is_valid(), "der Bunker ist baubar: %s" % ", ".join(bunker.validate()))
	t.equal(bunker.stats()["def"], 14, "und kommt auf DEF 14")

	var grid := Grid.new(10, 10)
	grid.fill(Terrain.TClass.NORMAL)
	var shooter := Unit.create(_squad()[0], &"P0", true)
	var wall := Unit.create(bunker, &"E0", false)
	shooter.tile = Vector2i(2, 2)
	wall.tile = Vector2i(4, 2)
	var resolver := ActionResolver.new(grid, [shooter, wall])

	var blaster: ActionData = null
	for action in shooter.actions():
		if action.is_attack():
			blaster = action
	var dealt := resolver.preview_damage(shooter, wall, blaster)

	t.ok(dealt >= int(ceil(blaster.power * 0.5)),
		"DEF nimmt hoechstens die Haelfte weg: %d von %d" % [dealt, blaster.power])
	var hits := int(ceil(float(wall.stat("hp_max")) / float(dealt)))
	t.ok(hits <= Config.get_int("cycle_limit", 30),
		"und der Bunker faellt innerhalb des Zyklus-Limits (%d Treffer)" % hits)
	t.equal(resolver.apply_damage(shooter, wall, blaster.power + shooter.atk(), blaster), dealt,
		"die Vorschau sagt genau das, was die Ausfuehrung tut")

	shooter.free()
	wall.free()


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


## Der Test, der oben FEHLT -- und zwar prinzipiell.
##
## test_same_seed_gives_the_same_battle() vergleicht zwei Laeufe DERSELBEN
## Engine. Genau daran ist ein Bruch vorbeigelaufen: unter Godot 4.7 zog
## derselbe Seed eine andere Region als unter 4.3, weil ``Array.sort()`` auf
## ``StringName`` nach interner Adresse sortiert und nicht alphabetisch. Beide
## Laeufe waren in sich einig, nur nicht miteinander -- gruener Test, kaputtes
## Versprechen.
##
## Deshalb wird hier nicht "zweimal dasselbe" geprueft, sondern der INHALT der
## Reihenfolge: die Auswahl muss der alphabetischen Folge der Region-IDs
## entsprechen. Das ist die einzige Formulierung, die eine Engine nicht
## unbemerkt umdeuten kann.
func test_region_choice_follows_the_alphabet_not_the_memory_layout() -> void:
	var ids: Array[String] = []
	for key in TerrainDB.regions:
		ids.append(str(key))
	ids.sort()
	t.ok(ids.size() >= 2, "es gibt mehr als eine Region, sonst prueft das nichts")

	var seen := {}
	for seed_value in range(40):
		# Denselben Wurf zweimal: einmal fuer den erwarteten Index, einmal fuer
		# die echte Auswahl. Beide starten bei demselben Seed.
		var counter := RandomNumberGenerator.new()
		counter.seed = seed_value
		var expected: String = ids[counter.randi() % ids.size()]

		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var region := TerrainDB.pick_region(rng)
		t.equal(str(region.id), expected,
			"Seed %d zieht die alphabetisch %d. Region" % [seed_value,
				ids.find(expected) + 1])
		seen[expected] = true
	t.equal(seen.size(), ids.size(),
		"und ueber 40 Seeds kommt jede Region auch wirklich vor")


func test_enemy_power_matches_the_player_squad() -> void:
	var player := _squad()
	var target := DromeBuild.squad_power(player)
	var tolerance := Config.get_float("power_tolerance", 0.12)
	var misses := 0
	for i in 30:
		var generator := EnemyGenerator.new(7000 + i)
		generator.generate(player.size(), target)
		if absf(generator.achieved_power - target) / target > tolerance:
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
