## Hexfeld-Optionen (v12) im Handy-Hochformat: je plan_*.json ein Bild,
## eine 3D-Szene mit Boden, Hindernissen und DROMEs, Iso-Kamera wie im Spiel.
extends RefCounted
var DIR := ""
const W := 540
const H := 960
const RIGHT := Vector3(0.70710678, 0, 0.70710678)
const UP := Vector3(0.5, 0.70710678, -0.5)
const BACK := Vector3(-0.5, 0.70710678, 0.5)
## Brett um 45 Grad gedreht: die Reihen laufen waagerecht ueber den Bildschirm.
const YAW_BOARD := 45.0

func _model(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DIR + "hex_%s.m3d" % name))

func _build(chassis: StringName, weapon: StringName) -> DromeBuild:
	var b := DromeBuild.create("X", {})
	b.apply_chassis(chassis)
	var slots := PartDB.get_part(chassis).equip_slots()
	if not slots.is_empty():
		b.slots[slots[0]] = weapon
	if slots.size() > 1:
		b.slots[slots[1]] = &"eq_hammer"
	return b

func _view(root: Window, plan_file: String) -> SubViewport:
	var DM = load("res://scripts/core/drome_model.gd")
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + plan_file))
	var basis: Basis = DM.facing_basis("south").rotated(Vector3.UP, deg_to_rad(YAW_BOARD))
	# Ausschnitt: alle Platten passen hinein (Hochformat), Mitte auf das Brett.
	var x0 := 1e9; var x1 := -1e9; var y0 := 1e9; var y1 := -1e9
	for cell in plan["tiles"]:
		var p: Vector3 = basis * Vector3(cell["fl"][0], cell["fl"][1], 0.0)
		x0 = minf(x0, p.dot(RIGHT)); x1 = maxf(x1, p.dot(RIGHT))
		y0 = minf(y0, p.dot(UP)); y1 = maxf(y1, p.dot(UP))
	var size := maxf((y1 - y0) + 120.0, ((x1 - x0) + 60.0) * float(H) / float(W))
	var px_per_design: float = float(H) / (size * 1.35)
	DM._edge = 0.45 * px_per_design
	var view := SubViewport.new()
	view.size = Vector2i(W, H)
	view.transparent_bg = true
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam: Camera3D = DM.make_camera()
	cam.size = size
	cam.far = 4000.0
	cam.position = RIGHT * (x0 + x1) * 0.5 + UP * ((y0 + y1) * 0.5 + 25.0) + BACK * 1500.0
	view.add_child(cam)
	var board := Node3D.new()
	board.basis = basis
	view.add_child(board)
	for list in ["tiles", "obstacles"]:
		for cell in plan[list]:
			var m := _model(cell["kind"])
			var inst := MeshInstance3D.new()
			inst.mesh = DM._mesh_for("hexfeld_%s_%d" % [cell["kind"], int(px_per_design * 100)], m, m["colors"])
			inst.position = Vector3(cell["fl"][0], cell["fl"][1], 0.0)
			board.add_child(inst)
	for d in plan["dromes"]:
		var node: Node3D = DM.build_node(_build(StringName(d["chassis"]), StringName(d["weapon"])),
			"south", int(px_per_design * 128))
		node.position = basis * Vector3(d["fl"][0], d["fl"][1], 0.0)
		var turn: Node3D = node.get_node("Ausrichtung")
		turn.basis = basis * Basis(Vector3(0, 0, 1), deg_to_rad(d["yaw"]))
		view.add_child(node)
	root.add_child(view)
	var out := SubViewport.new()
	out.size = Vector2i(W, H)
	out.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new(); bg.color = Color("#0a0618"); bg.size = Vector2(W, H)
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
	var outs := []
	for key in ["A", "B", "C"]:
		outs.append(_view(root, "plan_%s.json" % key))
	return outs
