extends RefCounted

## Logik zu elite_bench.gd (RefCounted, kompiliert nach den Autoloads).

const ROUNDS := [3, 5, 8]
const SQUADS := [["Vireo", "Molok", "Strix"], ["Vireo", "Molok", "Nimbus"],
	["Vireo", "Strix", "Nimbus"], ["Molok", "Strix", "Nimbus"]]

## Siege je Fusion (ueber alles), [siege, kaempfe].
var recipe_wins := {}
var seconds_sum := 0.0
var fights := 0


func run(count: int, drome_level: int, weapon_level: int) -> void:
	var stock := {}
	for b in RunState.standard_squad():
		b.drome_level = drome_level
		for slot in b.equip_slots():
			if weapon_level > 0:
				b.weapon_levels[slot] = weapon_level
		stock[b.display_name] = b
	print("Elite-Kaempfe: Squad (DROME Lv %d, Waffen Lv %d, je DROME 1 Fusion) gegen jede Elite-Formation, %d Laeufe je Feld"
		% [drome_level, weapon_level, count])
	var formations: Array = Formations.all()
	for round in ROUNDS:
		var state := RunState.start(1)
		state.round = round
		var lv := state.enemy_levels(2)
		print("\n== Runde %d (Reinforcement %d, Elite-Gegner DROME Lv %d / Waffen Lv %d) =="
			% [round, state.reinforcement(), lv["drome"], lv["weapon"]])
		var header := "%-28s" % "Formation (Gegner-DROMEs)"
		for squad in SQUADS:
			header += " %13s" % "/".join(squad.map(func(n): return n.substr(0, 1)))
		print(header)
		for entry in formations:
			var plan := Formations.composition(entry, state.reinforcement(), "elite")
			var variants := [["", entry]]
			if (plan["dromes"] as Array).has("neon_nimbus"):
				var swapped: Dictionary = entry.duplicate(true)
				for step in swapped["steps"]:
					step["dromes"] = (step.get("dromes", []) as Array).map(
						func(d): return "nimbus" if d == "neon_nimbus" else d)
				variants.append([" ->Supp", swapped])
			for v in variants:
				var label: String = "%s%s" % [entry["id"].replace("neon_", ""), v[0]]
				var names: Array = Formations.composition(v[1], state.reinforcement(), "elite")["dromes"]
				var line := "%-28s" % ("%s (%s)" % [label, ",".join(names.map(func(n): return n.replace("neon_", "N."))) ])
				for squad in SQUADS:
					var wins := 0
					for i in count:
						var seed_value := 7000 + i * 31 + round
						var foes: Array = Formations.build(v[1], state.reinforcement(), "elite", seed_value)
						state._apply_levels(foes.filter(func(b): return not b.is_sentinel()), 2)
						var ours := _squad(stock, squad, seed_value)
						var won := _play(seed_value, ours, foes, str(entry.get("map", "")))
						if won:
							wins += 1
						for b in ours:
							for slot in b.modules:
								for id in b.modules[slot]:
									var key := "%s:%s" % [b.display_name, id]
									var rec: Array = recipe_wins.get(key, [0, 0])
									rec[0] += 1 if won else 0
									rec[1] += 1
									recipe_wins[key] = rec
					line += " %8d/%-4d" % [wins, count]
				print(line)
	print("\nSiegquote je Fusion (alle Runden, alle Gegner):")
	var keys := recipe_wins.keys()
	keys.sort()
	for key in keys:
		var rec: Array = recipe_wins[key]
		print("  %-32s %5.1f %%  (%d)" % [key, 100.0 * rec[0] / maxf(1, rec[1]), rec[1]])
	print("\nKampfdauer im Schnitt %.1f s (%d Kaempfe)" % [seconds_sum / maxf(1, fights), fights])


## Ein Squad aus dem Bestand, je DROME eine passende Fusion (seed-fest gewuerfelt).
func _squad(stock: Dictionary, names: Array, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array = []
	for n in names:
		var b: DromeBuild = stock[n].clone()
		var slot: String = b.equip_slots()[0]
		var weapon := b.part_in(slot)
		var pool := ModuleData.recipes().filter(func(m): return not m.is_bios_result and m.fits(weapon))
		if not pool.is_empty():
			b.modules[slot] = [pool[rng.randi() % pool.size()].id]
		out.append(b)
	return out


func _play(seed_value: int, ours: Array, theirs: Array, map: String) -> bool:
	var battle := BattleManager.new()
	battle.setup(seed_value, ours.map(func(b): return b.clone()), theirs.map(func(b): return b.clone()),
		&"", map)
	var guard := 0
	while battle.outcome == BattleManager.Outcome.RUNNING and guard < 100000:
		battle.tick()
		guard += 1
	var won := battle.outcome == BattleManager.Outcome.VICTORY
	seconds_sum += battle.time
	fights += 1
	battle.free()
	return won
