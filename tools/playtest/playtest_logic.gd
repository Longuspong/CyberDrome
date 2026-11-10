extends RefCounted

## Siehe playtest.gd. Echtzeit: gespielt wird Schritt fuer Schritt, und je
## DROME wird mitgeschrieben, wie viel Zeit er laufend, schiessend oder
## untaetig verbringt.

var stats := {}          # name -> Dictionary
var _lines: Array[String] = []
var _detail := false
var _battle: BattleManager


## Spiegelkampf: der Squad gegen eine Kopie von sich selbst.
var mirror := false


func run(count: int, detail_seed: int) -> void:
	if GameState.roster.entries.is_empty():
		GameState.load_roster()
	var builds := GameState.battle_ready_builds()
	print("Squad: ", ", ".join(builds.map(func(b): return b.display_name)))
	var wins := 0
	var losses := 0
	var seconds := 0.0
	var first_contact := 0.0
	for i in count:
		var seed_value := 5000 + i
		_detail = seed_value == detail_seed
		var result := _play(seed_value, builds)
		seconds += float(result["seconds"])
		first_contact += float(result["first_contact"])
		match result["outcome"]:
			BattleManager.Outcome.VICTORY: wins += 1
			BattleManager.Outcome.DEFEAT: losses += 1
	print("\nKaempfe %d: Siege %d, Niederlagen %d, Dauer im Schnitt %.1f s, erster Treffer nach %.1f s"
		% [count, wins, losses, seconds / count, first_contact / count])
	_report()
	if not _lines.is_empty():
		print("\n--- Detail Seed %d ---" % detail_seed)
		for line in _lines:
			print(line)


func _entry(unit: Unit) -> Dictionary:
	var key := ("P " if unit.is_player else "E ") + unit.display_name
	if not stats.has(key):
		stats[key] = {"units": 0, "alive_s": 0.0, "idle_s": 0.0, "walk_s": 0.0,
			"moved": 0, "dmg": 0, "attacks": 0, "abilities": 0, "deaths": 0,
			"dist_sum": 0, "ability_names": {}, "first_shot": 0.0, "shots_any": 0}
	return stats[key]


func _play(seed_value: int, builds: Array) -> Dictionary:
	var battle := BattleManager.new()
	_battle = battle
	if mirror:
		battle.setup(seed_value, builds, builds.map(func(b): return b.clone()))
	else:
		battle.setup(seed_value, builds)
	for unit in battle.units:
		_entry(unit)["units"] += 1
	var acted := {}
	var first := {"t": -1.0}
	var on_damage := func(target, amount, source):
		if source != null and source is Unit and amount > 0:
			_entry(source)["dmg"] += amount
			if first["t"] < 0.0:
				first["t"] = battle.time
	var on_action := func(unit, tile, action):
		acted[unit.unit_id] = true
		var e := _entry(unit)
		e["dist_sum"] += Grid.distance(unit.tile, tile)
		if action.is_attack():
			e["attacks"] += 1
		else:
			e["abilities"] += 1
			e["ability_names"][action.display_name] = \
				int(e["ability_names"].get(action.display_name, 0)) + 1
		if _detail and _lines.size() < 160:
			_lines.append("%5.1fs %s %s -> %s (%s)" % [battle.time,
				"P" if unit.is_player else "E", unit.display_name, action.display_name, tile])
	var on_move := func(unit, from, to):
		_entry(unit)["moved"] += Grid.distance(from, to)
	EventBus.unit_damaged.connect(on_damage)
	EventBus.action_used.connect(on_action)
	EventBus.unit_moved.connect(on_move)
	if _detail:
		_lines.append("Region %s" % battle.region.display_name)
		for u in battle.units:
			_lines.append("  %s %s @%s HP %d SH %d SPD %d Tempo %.2f Felder/s Rw %d" % [
				"P" if u.is_player else "E", u.display_name, u.tile, u.hp,
				u.shield, u.spd(), u.move_speed(), u.attack_range()])
	var dt := battle.step_seconds()
	while battle.outcome == BattleManager.Outcome.RUNNING:
		acted.clear()
		battle.tick()
		for unit in battle.units:
			if not unit.is_alive():
				continue
			var e := _entry(unit)
			e["alive_s"] += dt
			if unit.step_left > 0.0:
				e["walk_s"] += dt
			elif not acted.has(unit.unit_id) and not _reloading_in_reach(battle, unit):
				e["idle_s"] += dt
	for unit in battle.units:
		if not unit.is_alive():
			_entry(unit)["deaths"] += 1
	EventBus.unit_damaged.disconnect(on_damage)
	EventBus.action_used.disconnect(on_action)
	EventBus.unit_moved.disconnect(on_move)
	var result := battle.build_result()
	result["first_contact"] = maxf(0.0, first["t"])
	if _detail:
		_lines.append("Ergebnis: %s nach %d s" % [
			BattleManager.outcome_label(result["outcome"]), result["seconds"]])
	battle.free()
	return result


## Steht er und laedt nach, waehrend ein Gegner in Reichweite ist? Das ist
## Kaempfen, nicht Herumstehen.
func _reloading_in_reach(battle: BattleManager, unit: Unit) -> bool:
	for foe in battle.enemies_of(unit):
		if Grid.distance(unit.tile, foe.tile) <= unit.attack_range():
			return true
	return false


func _report() -> void:
	print("\n%-22s %6s %6s %6s %6s %6s %6s %6s %5s  %s" % ["DROME", "Zeit s",
		"leer%", "Lauf%", "Felder", "Dmg/s", "Dist", "Faeh/m", "Tod%", "Faehigkeiten"])
	var keys := stats.keys()
	keys.sort()
	for key in keys:
		var e: Dictionary = stats[key]
		if not key.begins_with("P "):
			continue
		var t := maxf(0.1, float(e["alive_s"]))
		var acts := maxf(1.0, float(e["attacks"] + e["abilities"]))
		print("%-22s %6.0f %6.0f %6.0f %6d %6.1f %6.1f %6.1f %5.0f  %s" % [key,
			t, 100.0 * e["idle_s"] / t, 100.0 * e["walk_s"] / t, e["moved"],
			e["dmg"] / t, e["dist_sum"] / acts, 60.0 * e["abilities"] / t,
			100.0 * e["deaths"] / maxf(1.0, float(e["units"])), e["ability_names"]])
