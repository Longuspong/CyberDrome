## Blicktest Faehigkeiten lesbar (18. Nov. 2026): Arena wie render_arena.gd,
## dazu ein Vortex auf die Gegnerreihe und zwei verlangsamte Gegner.
##   xvfb-run -a godot --fixed-fps 60 --path . --script res://docs/design/drome_entwurf/godot/render_main.gd -- \
##       res://docs/design/drome_entwurf/godot/render_faehigkeit.gd /tmp/out/vortex city ZEIT
## ZEIT = Alter des Vortex beim Bild in Sekunden (0,6 = Einschlag).
## Statt ZEIT "ansage" oder "wirkung": alle Formen gleichzeitig ueber das Feld
## verteilt, jede in dieser Phase (Gegner-Formen mit rotem Aussenrand).
extends RefCounted

func build(root: Window, region_arg: String) -> Array:
	var views: Array = load("res://docs/design/drome_entwurf/godot/render_arena.gd").new().build(root, region_arg)
	var view: SubViewport = views[0]
	var world: Node2D = view.get_child(1)
	var painter := AbilityPainter.new()
	world.add_child(painter)
	var units: Array = []
	for child in world.get_children():
		if child is Unit:
			units.append(child)
	painter.units = units
	for unit in units:
		if not unit.is_player and unit.tile.x >= 4:
			unit.apply_status(&"slow", 2.0, {})
	var args := OS.get_cmdline_user_args()
	if args.size() > 3 and args[3] in ["ansage", "wirkung"]:
		return _all(world, painter, units, args[3] == "wirkung", views)
	var age := float(args[3]) if args.size() > 3 else 0.3
	painter.add_vortex(IsoView.map_to_local(Vector2i(3, 3)), 2, 0.6, Teams.color(true))
	painter._marks[0]["age"] = age - 8.0 / 60.0   # bis zum Bild laufen noch ~8 Bilder
	for cam in world.get_children():
		if cam is Camera2D:
			cam.zoom = Vector2(1.8, 1.8)
			cam.position = IsoView.map_to_local(Vector2i(4, 3)) + Vector2(0, -20)
	return views


## Alle Formen auf einmal: je Form ein Feld, Alter nach Phase.
func _all(world: Node2D, painter: AbilityPainter, units: Array, effect: bool, views: Array) -> Array:
	var spots := {"vortex": Vector2i(2, 4), "barrage": Vector2i(6, 4), "lock": Vector2i(4, 7),
		"stun": Vector2i(1, 8), "push": Vector2i(7, 8), "slash": Vector2i(2, 11),
		"whirl": Vector2i(6, 11), "double": Vector2i(4, 13), "breaker": Vector2i(1, 15),
		"shield": Vector2i(7, 15)}
	for kind in spots:
		var tile: Vector2i = spots[kind]
		var enemy: bool = kind in ["barrage", "stun", "whirl"]
		var color := Teams.color(not enemy)
		var at := IsoView.map_to_local(tile)
		var data := {"at": at, "color": color, "enemy": enemy, "radius": 1 if kind == "whirl" else 2,
			"delay": 0.8, "from": IsoView.map_to_local(tile + Vector2i(-1, 3)), "dir": Vector2(0.8, -0.6).normalized(),
			"targets": [at, IsoView.map_to_local(tile + Vector2i(2, 0))]}
		if kind == "vortex":
			painter.add_vortex(at, 2, 0.6, color, false)
		else:
			painter.add(kind, data)
		var mark: Dictionary = painter._marks[-1]
		var life := painter._life(mark)
		var delay := float(mark.get("delay", 0.0)) if kind in ["vortex", "barrage"] else 0.0
		var age := (delay + 0.1) if effect and delay > 0.0 else (life * (0.6 if effect else 0.2))
		mark["age"] = age - 8.0 / 60.0
	var states := [&"slow", &"stun", &"vulnerable"]
	for i in units.size():
		units[i].apply_status(states[i % 3], 9.0, {})
	for cam in world.get_children():
		if cam is Camera2D:
			cam.zoom = Vector2(0.95, 0.95)
			cam.position = IsoView.grid_center(9, 17) + Vector2(0, -20)
	return views
