extends RefCounted

## Siehe playtest.gd.

var stats := {}          # name -> Dictionary
var _battle: BattleManager
var _detail := false
var _lines: Array[String] = []


func run(count: int, detail_seed: int) -> void:
	if GameState.roster.entries.is_empty():
		GameState.load_roster()
	var builds := GameState.battle_ready_builds()
	print("Squad: ", ", ".join(builds.map(func(b): return b.display_name)))
	var wins := 0
	var losses := 0
	var cycles := 0
	for i in count:
		var seed_value := 5000 + i
		_detail = seed_value == detail_seed
		GameState.configure_chaos_run(builds.size(), DromeBuild.squad_power(builds))
		var result := _play(seed_value, builds)
		cycles += int(result["cycles"])
		match result["outcome"]:
			BattleManager.Outcome.VICTORY: wins += 1
			BattleManager.Outcome.DEFEAT: losses += 1
	print("\nKaempfe %d: Siege %d, Niederlagen %d, Zyklen im Schnitt %.1f"
		% [count, wins, losses, float(cycles) / count])
	_report()
	if not _lines.is_empty():
		print("\n--- Detail Seed %d ---" % detail_seed)
		for line in _lines:
			print(line)


func _entry(unit: Unit) -> Dictionary:
	var key := ("P " if unit.is_player else "E ") + unit.display_name
	if not stats.has(key):
		stats[key] = {"units": 0, "turns": 0, "idle": 0, "attack_turns": 0,
			"moved": 0, "dmg": 0, "abilities": 0, "attacks": 0, "deaths": 0,
			"alive_cycles": 0, "no_target_turns": 0, "dist_sum": 0,
			"ability_names": {}}
	return stats[key]


func _play(seed_value: int, builds: Array) -> Dictionary:
	var battle := BattleManager.new()
	_battle = battle
	battle.setup(seed_value, builds)
	battle.overtime_enabled = true
	var controller := AIController.new(battle)
	for unit in battle.units:
		_entry(unit)["units"] += 1
	var on_damage := func(target, amount, source):
		if source != null and source is Unit and amount > 0:
			_entry(source)["dmg"] += amount
	EventBus.unit_damaged.connect(on_damage)
	if _detail:
		_lines.append("Region %s, Mutator %s" % [battle.region.display_name,
			battle.mutator.display_name])
		for u in battle.units:
			_lines.append("  %s %s @%s HP %d SH %d SPD %d MOV %d" % [
				"P" if u.is_player else "E", u.display_name, u.tile, u.hp,
				u.shield, u.spd(), u.stat("mov")])
	var turns := 0
	while battle.outcome == BattleManager.Outcome.RUNNING and turns < 600:
		turns += 1
		var unit := battle.begin_next_turn()
		if unit == null:
			continue
		var e := _entry(unit)
		e["turns"] += 1
		var start := unit.tile
		var steps: Array = controller.run_turn()
		var attacked := false
		var acted := false
		var desc: Array[String] = []
		for step in steps:
			if step.get("kind") == "action":
				acted = true
				var action: ActionData = step["action"]
				var target: Unit = step["target"]
				e["dist_sum"] += Grid.distance(unit.tile, target.tile)
				if action.is_attack():
					attacked = true
					e["attacks"] += 1
				else:
					e["abilities"] += 1
					e["ability_names"][action.display_name] = \
						int(e["ability_names"].get(action.display_name, 0)) + 1
				desc.append("%s->%s" % [action.display_name, target.display_name])
			else:
				desc.append("lauf %s" % step.get("move_to"))
		var moved := Grid.distance(start, unit.tile)
		e["moved"] += moved
		if attacked:
			e["attack_turns"] += 1
		if not acted:
			e["idle"] += 1
			var nearest := 99
			for foe in battle.enemies_of(unit):
				nearest = mini(nearest, Grid.distance(unit.tile, foe.tile))
			e["dist_sum"] += 0
			if _detail:
				desc.append("(naechster Gegner %d Felder)" % nearest)
		if _detail and turns <= 80:
			_lines.append("Z%d %s%s HP%d/%d SH%d EN%d %s->%s: %s" % [
				battle.tick_bus.cycle_count, "P " if unit.is_player else "E ",
				unit.display_name, unit.hp, unit.stat("hp_max"), unit.shield,
				unit.energy if "energy" in unit else -1, start, unit.tile,
				"; ".join(desc) if not desc.is_empty() else "nichts"])
		if battle.outcome == BattleManager.Outcome.RUNNING:
			battle.end_turn()
	for unit in battle.units:
		if not unit.is_alive():
			_entry(unit)["deaths"] += 1
	EventBus.unit_damaged.disconnect(on_damage)
	var result := battle.build_result()
	if _detail:
		_lines.append("Ergebnis: %s nach %d Zyklen" % [
			BattleManager.outcome_label(result["outcome"]), result["cycles"]])
	battle.free()
	return result


func _report() -> void:
	print("\n%-22s %5s %5s %6s %6s %6s %6s %6s %5s  %s" % ["DROME", "Zuege",
		"leer%", "Angr%", "Lauf/Z", "Dmg/Z", "Dist", "Faeh/Z", "Tod%", "Faehigkeiten"])
	var keys := stats.keys()
	keys.sort()
	for key in keys:
		var e: Dictionary = stats[key]
		var t := maxf(1.0, float(e["turns"]))
		var acts := maxf(1.0, float(e["attacks"] + e["abilities"]))
		print("%-22s %5d %5.0f %6.0f %6.1f %6.1f %6.1f %6.2f %5.0f  %s" % [key,
			e["turns"], 100.0 * e["idle"] / t, 100.0 * e["attack_turns"] / t,
			e["moved"] / t, e["dmg"] / t, e["dist_sum"] / acts, e["abilities"] / t,
			100.0 * e["deaths"] / maxf(1.0, float(e["units"])), e["ability_names"]])
