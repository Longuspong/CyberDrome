extends RefCounted

## Siehe map_bench.gd. Seit den Karten je Formation (18. Nov. 2026) misst die
## Bank die echten Karten aus config.json -> maps (Groesse und Form ueber
## MapGenerator, wie im Spiel). Zeile "je Formation" = jede Formation auf ihrer
## eigenen Karte, so wie sie im Einsatz kaempft.

const OWN := "je Formation"


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
	for map_id in map_ids():
		if only != "" and not str(map_id).contains(only):
			continue
		var wins := 0
		var played := 0
		var secs := 0.0
		var first := 0.0
		var walk := 0.0
		var alive := 0.0
		var per_form: Array = []
		var tiles: Array = []
		for f in forms.size():
			var won_here := 0
			var used: String = str(forms[f].get("map", "")) if map_id == OWN else str(map_id)
			for i in count:
				var seed_value := 7100 + f * 97 + i
				var foes: Array = Formations.build(forms[f], level, "normal", seed_value)
				var r := _play(seed_value, squad, foes, used)
				if not tiles.has(int(r["tiles"])):
					tiles.append(int(r["tiles"]))
				played += 1
				secs += float(r["seconds"])
				first += float(r["first"])
				walk += float(r["walk"])
				alive += float(r["alive"])
				if r["won"]:
					wins += 1
					won_here += 1
			per_form.append(won_here)
		var label: String = OWN if map_id == OWN else "%s %s" % [map_id, _size(str(map_id))]
		var line := "%-24s %4d%% %5.1fs %5.1fs %5.0f%% %6s  " % [label, roundi(100.0 * wins / played),
			secs / played, first / played, 100.0 * walk / maxf(0.01, alive),
			str(tiles[0]) if tiles.size() == 1 else "div."]
		for n in per_form:
			line += "%4d%% " % roundi(100.0 * n / count)
		print(line)


## Die Karten aus config.json -> maps, vorneweg "je Formation".
static func map_ids() -> Array:
	var out: Array = [OWN]
	var maps: Dictionary = Config.section("maps")
	for key in maps:
		if not str(key).begins_with("_") and key != "default" and maps[key] is Dictionary:
			out.append(str(key))
	return out


static func _size(map_id: String) -> String:
	var spec := MapGenerator.map_spec(map_id)
	return "%dx%d" % [int(spec.get("width", 0)), int(spec.get("height", 0))]


func _play(seed_value: int, ours: Array, theirs: Array, map_id: String) -> Dictionary:
	var battle := BattleManager.new()
	battle.setup(seed_value, ours.map(func(b): return b.clone()), theirs.map(func(b): return b.clone()),
		&"city", map_id)
	var grid := battle.grid
	var free := 0
	for tile in grid.all_tiles():
		if not grid.obstacles.has(tile):
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
