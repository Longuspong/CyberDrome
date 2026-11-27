## Hexboden-Entwurf (v10): ganzes Feld und Nahansicht, eine 3D-Szene mit DROMEs.
extends RefCounted
var DIR := ""
const UP := Vector3(0.5, 0.70710678, -0.5)
const BACK := Vector3(-0.5, 0.70710678, 0.5)

func _model(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DIR + "hex_%s.m3d" % name))

func _stock(chassis: StringName, weapon: StringName) -> DromeBuild:
	var b := DromeBuild.create("X", {})
	b.apply_chassis(chassis)
	var c := PartDB.get_part(chassis)
	var slots := c.equip_slots()
	if not slots.is_empty():
		b.slots[slots[0]] = weapon
	if slots.size() > 1:
		b.slots[slots[1]] = &"eq_hammer"
	return b

func _view(root: Window, px: int, cam_size: float, yaw_board: float) -> SubViewport:
	var DM = load("res://scripts/core/drome_model.gd")
	var px_per_design: float = float(px) / (cam_size * 1.35)
	DM._edge = 0.45 * px_per_design
	var view := SubViewport.new()
	view.size = Vector2i(px, px)
	view.transparent_bg = true
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam: Camera3D = DM.make_camera()
	cam.size = cam_size
	cam.position = UP * 20.0 + BACK * 1200.0
	cam.far = 3000.0
	view.add_child(cam)
	var basis: Basis = DM.facing_basis("south").rotated(Vector3.UP, deg_to_rad(yaw_board))
	var board := Node3D.new()
	board.basis = basis
	view.add_child(board)
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "plan.json"))
	for list in ["tiles", "obstacles"]:
		for cell in plan[list]:
			var m := _model(cell["kind"])
			var inst := MeshInstance3D.new()
			inst.mesh = DM._mesh_for("hex_%s_%d" % [cell["kind"], px], m, m["colors"])
			inst.position = Vector3(cell["fl"][0], cell["fl"][1], 0.0)
			board.add_child(inst)
	# DROMEs: Spieler unten (r = 4), Gegner oben (r = -4); Blick in Hex-Richtungen
	var R := 22.0
	var dromes := [
		[&"scout_body", &"eq_pulse_blaster", -1, 4, 180.0],
		[&"jugg_body", &"eq_deflector", 0, 4, 180.0],
		[&"mage_body", &"eq_rune_staff", 1, 4, 240.0],
		[&"strix_body", &"eq_rail_lance", -1, -4, 0.0],
		[&"jugg_body", &"eq_hammer", 1, -4, 0.0],
		[&"scout_body", &"eq_plasma_blade", 3, -4, 60.0],
	]
	for d in dromes:
		var node: Node3D = DM.build_node(_stock(d[0], d[1]), "south", 256)
		var q: int = d[2]
		var r: int = d[3]
		var local := Vector3(1.5 * R * r, sqrt(3.0) * R * (q + r / 2.0), 0.0)
		node.position = basis * local
		var turn: Node3D = node.get_node("Ausrichtung")
		turn.basis = basis * Basis(Vector3(0, 0, 1), deg_to_rad(d[4]))
		view.add_child(node)
	root.add_child(view)
	var out := SubViewport.new()
	out.size = Vector2i(px, px)
	out.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new(); bg.color = Color("#0a0618"); bg.size = Vector2(px, px)
	out.add_child(bg)
	var s := Sprite2D.new()
	s.texture = view.get_texture()
	s.centered = false
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/drome_outline.gdshader")
	mat.set_shader_parameter("line_color", Color("#05020a"))
	mat.set_shader_parameter("rim_color", Color("#2ee3eb"))
	mat.set_shader_parameter("line_px", 0.45 * px_per_design)
	mat.set_shader_parameter("rim_px", 1.6 * px_per_design)
	s.material = mat
	out.add_child(s)
	root.add_child(out)
	return out

func build(root: Window, model_dir: String) -> Array:
	DIR = model_dir.trim_suffix("/") + "/"
	return [_view(root, 1400, 450.0, 0.0), _view(root, 1400, 170.0, 0.0)]
