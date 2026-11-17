## Shogun-Entwurf (v8/v9): gross, rundum in 45-Grad-Schritten, Spielgroesse.
extends RefCounted
var DIR := ""
const UP := Vector3(0.5, 0.70710678, -0.5)
const BACK := Vector3(-0.5, 0.70710678, 0.5)
const RIGHT := Vector3(0.70710678, 0, 0.70710678)
var SHIFT := 0.0

func _model(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DIR + "shogun_%s.m3d" % name))

## Eine fertige Bildflaeche (2D mit Hintergrund und Kontur) je Ansicht.
func _view(root: Window, px: int, angle_deg: float, zoom: float) -> SubViewport:
	var DM = load("res://scripts/core/drome_model.gd")
	DM._edge = DM.edge_px(px) / zoom
	var view := SubViewport.new()
	view.size = Vector2i(px, px)
	view.transparent_bg = true
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam: Camera3D = DM.make_camera()
	cam.size *= zoom
	cam.position = UP * (0.70710678 * 44.0 * 1.25) + BACK * 400.0 + RIGHT * SHIFT
	view.add_child(cam)
	var turn := Node3D.new()
	turn.basis = DM.facing_basis("south").rotated(Vector3.UP, deg_to_rad(angle_deg)) \
		.scaled(Vector3.ONE * 1.25)
	view.add_child(turn)
	for file in DirAccess.get_files_at(DIR):
		if not file.ends_with(".m3d"):
			continue
		var name := file.trim_prefix("shogun_").trim_suffix(".m3d")
		var m := _model(name)
		var inst := MeshInstance3D.new()
		inst.mesh = DM._mesh_for("shogun_%s_%d" % [name, px], m, m["colors"])
		turn.add_child(inst)
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
	mat.set_shader_parameter("rim_color", Color("#ff2a55"))
	mat.set_shader_parameter("line_px", 0.45 * px / 128.0 / zoom)
	mat.set_shader_parameter("rim_px", 1.6 * px / 128.0 / zoom)
	s.material = mat
	out.add_child(s)
	root.add_child(out)
	return out

func build(root: Window, model_dir: String) -> Array:
	DIR = model_dir.trim_suffix("/") + "/"
	var outs := []
	outs.append(_view(root, 1100, 0.0, 1.45))       # gross, Blickwinkel wie im Bild
	for i in 8:
		outs.append(_view(root, 420, i * 45.0, 1.6))   # rundum in 45-Grad-Schritten
	outs.append(_view(root, 128, 0.0, 1.45))           # Spielgroesse
	return outs
