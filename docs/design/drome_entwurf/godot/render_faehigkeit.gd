## Blicktest Faehigkeiten lesbar (18. Nov. 2026): Arena wie render_arena.gd,
## dazu ein Vortex auf die Gegnerreihe und zwei verlangsamte Gegner.
##   xvfb-run -a godot --fixed-fps 60 --path . --script res://docs/design/drome_entwurf/godot/render_main.gd -- \
##       res://docs/design/drome_entwurf/godot/render_faehigkeit.gd /tmp/out/vortex city ZEIT
## ZEIT = Alter des Vortex beim Bild in Sekunden (0,6 = Einschlag).
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
	var age := float(args[3]) if args.size() > 3 else 0.3
	painter.add_vortex(IsoView.map_to_local(Vector2i(3, 3)), 2, 0.6, Teams.color(true))
	painter._marks[0]["age"] = age - 8.0 / 60.0   # bis zum Bild laufen noch ~8 Bilder
	for cam in world.get_children():
		if cam is Camera2D:
			cam.zoom = Vector2(1.8, 1.8)
			cam.position = IsoView.map_to_local(Vector2i(4, 3)) + Vector2(0, -20)
	return views
