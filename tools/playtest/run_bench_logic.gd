extends RefCounted

## Logik zu run_bench.gd (als RefCounted, damit sie nach den Autoloads
## kompiliert). Seit 10. Nov. 2026 gegen die handverlesenen Teams der Reihe
## (RunState.row): je Runde und Stufe der erste Knoten dieser Stufe.

const ROUNDS := [1, 3, 5, 8]


func run(count: int, drome_level: int = 0, weapon_level: int = 0) -> void:
	print("Siege des Standard-Squads (DROME Lv %d, Waffen Lv %d) gegen die Lauf-Gegner (%d Laeufe je Feld)"
		% [drome_level, weapon_level, count])
	print("Runde  Stufe    Gegner-Lv  Module/Gegner  mit Modulen  ohne")
	for round in ROUNDS:
		for which in 3:
			var with_mods := 0
			var without := 0
			var mods := 0
			var played := 0
			for i in count:
				var state := RunState.start(9000 + i)
				for own in state.squad:
					own.drome_level = drome_level
					for slot in own.equip_slots():
						if weapon_level > 0:
							own.weapon_levels[slot] = weapon_level
				state.round = round
				state._pick_default_node()
				# Elite steht nicht in jeder Reihe -- dann zaehlt der Lauf nicht mit.
				if not state.choose_tier(which):
					continue
				played += 1
				var foes: Array = state.enemies()
				mods = state.enemy_module_count(which)
				var bare: Array = foes.map(func(b):
					var c: DromeBuild = b.clone()
					c.modules = {}
					return c)
				var seed_value := state.battle_seed()
				if _play(seed_value, state.squad, foes):
					with_mods += 1
				if _play(seed_value, state.squad, bare):
					without += 1
			print("%5d  %-7s  %9s  %13d  %5d/%d    %d/%d" % [round, RunState.TIER_NAMES[which], _lv(round, which), mods,
				with_mods, played, without, played])


func _lv(round: int, which: int) -> String:
	var state := RunState.start(1)
	state.round = round
	var lv := state.enemy_levels(which)
	return "%d/%d" % [lv["drome"], lv["weapon"]]


func _play(seed_value: int, ours: Array, theirs: Array) -> bool:
	var battle := BattleManager.new()
	battle.setup(seed_value, ours.map(func(b): return b.clone()), theirs.map(func(b): return b.clone()))
	var guard := 0
	while battle.outcome == BattleManager.Outcome.RUNNING and guard < 100000:
		battle.tick()
		guard += 1
	var won := battle.outcome == BattleManager.Outcome.VICTORY
	battle.free()
	return won
