## Blicktest Arena3D (18. Nov. 2026): Hexfeld einer Region mit Hindernissen
## in 3D und je drei DROMEs pro Seite, wie im Kampf (ohne Kampfbildschirm).
##   xvfb-run -a godot --path . --script res://docs/design/drome_entwurf/godot/render_main.gd -- \
##       res://docs/design/drome_entwurf/godot/render_arena.gd /tmp/out/arena city [angriff ZEITFAKTOR]
## Mit "angriff" greifen alle sofort an; das Bild entsteht nach 10 Bildern,
## ZEITFAKTOR (Engine.time_scale) waehlt den Zeitpunkt der Bewegung.
extends RefCounted

const W := 540
const H := 960

func _build(chassis: StringName, weapon: StringName) -> DromeBuild:
	var b := DromeBuild.create("X", {})
	b.apply_chassis(chassis)
	var slots := PartDB.get_part(chassis).equip_slots()
	if not slots.is_empty():
		b.slots[slots[0]] = weapon
	if slots.size() > 1:
		b.slots[slots[1]] = &"eq_hammer"
	return b

func build(root: Window, region_arg: String) -> Array:
	var region_id := region_arg if region_arg != "-" else "city"
	var view := SubViewport.new()
	view.size = Vector2i(W, H)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new(); bg.color = Color("#0a0618"); bg.size = Vector2(W, H) * 4
	bg.position = -Vector2(W, H) * 1.5
	bg.z_index = -4000         # unter dem Boden (z -60)
	view.add_child(bg)
	var world := Node2D.new()
	view.add_child(world)
	var grid := MapGenerator.generate(TerrainDB.get_region(StringName(region_id)))
	MapGenerator.place_obstacles(grid, 7)
	ArenaPainter.build(world, grid)
	var floor := ArenaFloor3D.new()
	floor.z_index = -70
	floor.build(grid)
	world.add_child(floor)
	var arena := Arena3D.new()
	world.add_child(arena)
	arena.build_obstacles(grid)
	arena.build_props(grid)
	var cam := Camera2D.new()
	cam.position = IsoView.grid_center(grid.width, grid.height) + Vector2(0, -20)
	cam.zoom = Vector2(0.95, 0.95)
	world.add_child(cam)
	cam.make_current()
	var squad := [
		[&"scout_body", &"eq_neon_blaster", Vector2i(2, 14), true],
		[&"jugg_body", &"eq_deflector", Vector2i(4, 15), true],
		[&"mage_body", &"eq_rune_staff", Vector2i(6, 14), true],
		[&"strix_body", &"eq_rail_lance", Vector2i(2, 2), false],
		[&"jugg_body", &"eq_bulwark_ram", Vector2i(4, 1), false],
		[&"scout_body", &"eq_plasma_blade", Vector2i(6, 2), false],
	]
	var units: Array = []
	for i in squad.size():
		var d: Array = squad[i]
		var unit := Unit.create(_build(d[0], d[1]), StringName("u%d" % i), d[3])
		unit.arena = arena
		unit.place_at(d[2])
		unit.facing = Unit.FACING_PLAYER if d[3] else Unit.FACING_ENEMY
		world.add_child(unit)
		units.append(unit)
	root.add_child(view)
	var args := OS.get_cmdline_user_args()
	if args.size() > 3 and args[3] == "angriff":
		Engine.time_scale = float(args[4]) if args.size() > 4 else 1.0
		cam.zoom = Vector2(2.6, 2.6)
		cam.position = IsoView.map_to_local(Vector2i(3, 2)) + Vector2(-30, -40)
		for unit in units:
			unit.play_attack(unit.tile + Vector2i(0, -1 if unit.is_player else 1))
	return [view]
