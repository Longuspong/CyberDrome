extends RefCounted

## Siehe map_bench.gd. Formen werden als gesperrte Felder ("void") auf das
## Rechteck gelegt -- fuer die Messung reicht das, Schuesse gehen ja ohnehin
## ueber Sperren hinweg.

## Name, Breite, Hoehe, Form.
const MAPS := [
	["7x13 Rechteck", 7, 13, "rect"],
	["9x13 Rechteck", 9, 13, "rect"],
	["9x15 Rechteck", 9, 15, "rect"],
	["9x17 Rechteck (heute)", 9, 17, "rect"],
	["11x17 Rechteck", 11, 17, "rect"],
	["9x21 Rechteck", 9, 21, "rect"],
	["11x21 Rechteck", 11, 21, "rect"],
	["9x17 Engpass", 9, 17, "waist"],
	["11x17 Bauch", 11, 17, "belly"],
	["11x17 Insel", 11, 17, "island"],
	["9x17 Zwei Gassen", 9, 17, "lanes"],
	["11x19 Ecken ab", 11, 19, "corners"],
]


func run(count: int, level: int, only: String) -> void:
	if GameState.roster.entries.is_empty():
		GameState.load_roster()
	var squad := GameState.battle_ready_builds()
	var forms: Array = Formations.of_region(&"city")
	print("Squad: %s  gegen %d Formationen (Neon City), Reinforcement %d, normal, %d Seeds je Formation"
		% [", ".join(squad.map(func(b): return b.display_name)), forms.size(), level, count])
	var header := "%-24s %5s %6s %6s %6s %6s  " % ["Karte", "Siege", "Dauer", "1.Tr.", "Lauf%", "Felder"]
	for entry in forms:
		header += "%5s " % str(entry.get("id", "?")).right(5)
	print(header)
	var cfg := Config.data()
	var old_w = cfg.get("grid_width")
	var old_h = cfg.get("grid_height")
	for map in MAPS:
		if only != "" and not str(map[0]).contains(only):
			continue
		cfg["grid_width"] = map[1]
		cfg["grid_height"] = map[2]
		var wins := 0
		var played := 0
		var secs := 0.0
		var first := 0.0
		var walk := 0.0
		var alive := 0.0
		var per_form: Array = []
		var tiles := 0
		for f in forms.size():
			var won_here := 0
			for i in count:
				var seed_value := 7100 + f * 97 + i
				var foes: Array = Formations.build(forms[f], level, "normal", seed_value)
				var r := _play(seed_value, squad, foes, str(map[3]))
				tiles = int(r["tiles"])
				played += 1
				secs += float(r["seconds"])
				first += float(r["first"])
				walk += float(r["walk"])
				alive += float(r["alive"])
				if r["won"]:
					wins += 1
					won_here += 1
			per_form.append(won_here)
		var line := "%-24s %4d%% %5.1fs %5.1fs %5.0f%% %6d  " % [map[0], roundi(100.0 * wins / played),
			secs / played, first / played, 100.0 * walk / maxf(0.01, alive), tiles]
		for n in per_form:
			line += "%4d%% " % roundi(100.0 * n / count)
		print(line)
	cfg["grid_width"] = old_w if old_w != null else Grid.DEFAULT_WIDTH
	cfg["grid_height"] = old_h if old_h != null else Grid.DEFAULT_HEIGHT
	if old_w == null:
		cfg.erase("grid_width")
	if old_h == null:
		cfg.erase("grid_height")


## Ob ein Feld in der Form liegt.
static func inside(shape: String, tile: Vector2i, w: int, h: int) -> bool:
	var cx := (float(w) - 1.0) * 0.5
	var mid := (float(h) - 1.0) * 0.5
	var dx := absf(float(tile.x) + (0.5 if tile.y % 2 == 1 else 0.0) - cx - 0.25)
	var dy := absf(float(tile.y) - mid)
	var t := dy / mid                # 0 Mitte .. 1 Rand
	match shape:
		"waist":
			# Engpass: in der Mitte nur 5 breit, zu den Zonen hin wieder voll.
			return dx <= lerpf(2.6, float(w) * 0.5, clampf((t - 0.15) / 0.45, 0.0, 1.0))
		"belly":
			# Bauch: an den Zonen 7 breit, in der Mitte die volle Breite.
			return dx <= lerpf(float(w) * 0.5, 3.6, clampf((t - 0.25) / 0.6, 0.0, 1.0))
		"island":
			# Insel: Bauch plus ein Block in der Mitte (Radius 1).
			if Grid.distance(tile, Vector2i(int(cx), int(mid))) <= 1:
				return false
			return dx <= lerpf(float(w) * 0.5, 3.6, clampf((t - 0.25) / 0.6, 0.0, 1.0))
		"lanes":
			# Zwei Gassen: ein langer Block in der Mitte, links und rechts frei.
			return not (dx <= 1.1 and dy <= 3.0)
		"corners":
			# Ecken ab: eine Art Sechseck, die Ecken je 2 Felder abgeschraegt.
			var edge := minf(dy - (mid - 3.0), 3.0)
			return edge <= 0.0 or dx <= float(w) * 0.5 - edge
	return true


func _play(seed_value: int, ours: Array, theirs: Array, shape: String) -> Dictionary:
	var battle := BattleManager.new()
	battle.setup(seed_value, ours.map(func(b): return b.clone()), theirs.map(func(b): return b.clone()))
	var grid := battle.grid
	var zones := {}
	for tile in MapGenerator.deployment_zone(grid, true) + MapGenerator.deployment_zone(grid, false):
		zones[tile] = true
	if shape != "rect":
		for tile in grid.all_tiles():
			if not zones.has(tile) and not inside(shape, tile, grid.width, grid.height) \
					and not grid.is_occupied(tile):
				grid.obstacles[tile] = "void"
		if not MapGenerator._connected(grid):
			for tile in grid.obstacles.keys():
				if grid.obstacles[tile] != "void":
					grid.obstacles.erase(tile)
	var free := 0
	for tile in grid.all_tiles():
		if grid.obstacles.get(tile, "") != "void":
			free += 1
	var first := {"t": -1.0}
	var on_damage := func(_target, amount, source):
		if source != null and amount > 0 and first["t"] < 0.0:
			first["t"] = battle.time
	EventBus.unit_damaged.connect(on_damage)
	var dt := battle.step_seconds()
	var walk := 0.0
	var alive := 0.0
	while battle.outcome == BattleManager.Outcome.RUNNING:
		battle.tick()
		for unit in battle.units:
			if unit.is_alive() and unit.is_player:
				alive += dt
				if unit.step_left > 0.0:
					walk += dt
	EventBus.unit_damaged.disconnect(on_damage)
	var out := {"won": battle.outcome == BattleManager.Outcome.VICTORY, "seconds": battle.time,
		"first": maxf(0.0, first["t"]), "walk": walk, "alive": alive, "tiles": free}
	battle.free()
	return out
