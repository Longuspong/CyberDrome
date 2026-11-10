extends RefCounted

## Logik zu power_bench.gd (als RefCounted, damit sie nach den Autoloads
## kompiliert).


func run(count: int, out_path: String, seed_base: int = 77000) -> void:
	var rows: Array = []
	var decided := 0
	var right := 0
	var draws := 0
	# Trefferquote nach Abstand der Kampfwerte: [Kaempfe, richtig].
	var bands := {"unter 10 %": [0, 0], "10-25 %": [0, 0], "ueber 25 %": [0, 0]}
	for i in count:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_base + i
		var size_a := rng.randi_range(1, 4)
		var size_b := size_a
		if rng.randf() < 0.3:
			size_b = clampi(size_a + (1 if rng.randf() < 0.5 else -1), 1, 4)
		var fancy := rng.randf() < 0.5
		var side_a := _squad(rng, size_a, fancy)
		var side_b := _squad(rng, size_b, fancy)
		var outcome := _play(seed_base + i, side_a, side_b)
		var power_a := DromeBuild.squad_power(side_a)
		var power_b := DromeBuild.squad_power(side_b)
		rows.append({"a": side_a.map(_describe), "b": side_b.map(_describe),
			"power_a": power_a, "power_b": power_b, "result": outcome})
		if outcome == "draw":
			draws += 1
			continue
		decided += 1
		var hit: bool = (power_a >= power_b) == (outcome == "a")
		if hit:
			right += 1
		var gap := absf(power_a - power_b) / maxf(1.0, maxf(power_a, power_b))
		var band := "unter 10 %" if gap < 0.1 else ("10-25 %" if gap < 0.25 else "ueber 25 %")
		bands[band][0] += 1
		if hit:
			bands[band][1] += 1
	print("Kaempfe %d, entschieden %d, unentschieden %d" % [count, decided, draws])
	print("Der hoehere Kampfwert gewinnt: %d von %d (%.1f %%)"
		% [right, decided, 100.0 * float(right) / float(maxi(1, decided))])
	for band in bands:
		var entry: Array = bands[band]
		print("  Abstand %-11s %4d Kaempfe, richtig %5.1f %%" % [band, entry[0],
			100.0 * float(entry[1]) / float(maxi(1, entry[0]))])
	if out_path != "":
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(rows))
		print("Rohdaten: %s" % out_path)


func _squad(rng: RandomNumberGenerator, size: int, fancy: bool) -> Array:
	var generator := EnemyGenerator.new(rng.randi())
	var squad: Array = []
	for i in size:
		var build: DromeBuild = generator._random_build("D%d" % i)
		if fancy:
			build.drome_level = rng.randi_range(0, 3)
			for slot in build.equip_slots():
				var weapon: PartData = build.part_in(slot)
				if weapon == null:
					continue
				build.weapon_levels[slot] = rng.randi_range(0, 5)
				var pool := ModuleData.base_modules().filter(func(m): return m.fits(weapon))
				var picked: Array = []
				for _n in rng.randi_range(0, mini(2, ModuleData.slots_for(build, slot))):
					if pool.is_empty():
						break
					var index := rng.randi() % pool.size()
					picked.append(pool[index].id)
					pool.remove_at(index)
				if not picked.is_empty():
					build.modules[slot] = picked
		squad.append(build)
	return squad


func _play(seed_value: int, ours: Array, theirs: Array) -> String:
	var battle := BattleManager.new()
	battle.setup(seed_value, ours.map(func(b): return b.clone()), theirs.map(func(b): return b.clone()))
	var guard := 0
	while battle.outcome == BattleManager.Outcome.RUNNING and guard < 100000:
		battle.tick()
		guard += 1
	var result := "draw"
	if battle.outcome == BattleManager.Outcome.VICTORY:
		result = "a"
	elif battle.outcome == BattleManager.Outcome.DEFEAT:
		result = "b"
	battle.free()
	return result


## Alles, woraus sich ein Kampfwert rechnen laesst -- als schlichte Daten.
func _describe(build: DromeBuild) -> Dictionary:
	var stats := build.stats()
	var body := build.body()
	var weapons: Array = []
	for slot in build.equip_slots():
		var part := build.part_in(slot)
		if part == null:
			continue
		var fx := build.module_effects(slot)
		var level := build.weapon_level(slot)
		var entry := {"id": str(part.id), "category": part.category,
			"takt_count": float(fx.get("takt_count", 1.0)), "actions": []}
		for action in part.actions:
			var a: ActionData = Leveling.level_action(action, part, level).with_modules(fx)
			entry["actions"].append({
				"attack": a.is_attack(), "power": a.power, "shots": a.shots,
				"interval": a.interval, "range": a.range_tiles, "min_range": a.min_range,
				"aoe": a.aoe_radius, "targeting": a.targeting, "energy": a.energy_fraction,
				"heal": a.heal, "shield_gain": a.shield_gain, "support": a.support,
				"trigger": a.trigger_kind, "every": a.trigger_every,
				"status": str(a.status.get("id", "")), "status_s": float(a.status.get("seconds", 0.0)),
				"gather": a.gather, "push": a.push_tiles, "hp_scaling": a.hp_scaling,
				"moving_bonus": a.moving_bonus, "shield_mult": a.shield_mult,
				"is_move": a.is_move(),
			})
		weapons.append(entry)
	return {
		"body": str(body.id), "role": body.ai_role, "passive": body.passive,
		"hp": stats["hp_max"], "def": stats["def"], "shield": stats["shield_max"],
		"shield_pulse": stats["shield_pulse"], "spd": stats["spd"], "power": stats["power"],
		"thorns": int(stats.get("thorns", 0)), "weapons": weapons,
		"score": build.power_score(),
	}
