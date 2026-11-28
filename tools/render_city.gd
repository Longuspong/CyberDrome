extends SceneTree

## Blicktest der Fabrikstadt (28. Nov. 2026): alle Gebaeude T1-T3 nebeneinander.
##     xvfb-run -a godot --path . --resolution 420x900 --script res://tools/render_city.gd -- <png>

var _frames := 0
var _out := "/tmp/city.png"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var city = load("res://scripts/ui/factory_city.gd")
	var root3 := Node3D.new()
	root3.scale = Vector3(1, city.Y_STRETCH, 1)
	var types := ["pmp", "sam", "scn", "smz", "rec", "pls", "vdi", "lot", "chp", "sol", "ofn", "gen", "bat", "rel", "basis"]
	for i in types.size():
		for tier in [1, 2, 3]:
			var at := Vector3((tier - 2) * 2.2, 0, i * 2.0 - 14.0)
			var lines: Array = ["logistik"] if types[i] == "basis" else load("res://scripts/core/factory_sim.gd").lines_of(types[i])
			root3.add_child(city.instance(city.tile_mesh("built", lines, tier), at))
			root3.add_child(city.instance(city.building_mesh(types[i], tier, i % 4 != 3), at))
	var vp := SubViewport.new()
	vp.size = Vector2i(400, 1600)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#0a0618")
	env.environment = e
	vp.add_child(env)
	vp.add_child(root3)
	var cam: Camera3D = city.make_camera(55.0, 400.0)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = 1600.0 / 55.0
	city.place_camera(cam, Vector3(0, 0, 0))
	vp.add_child(cam)
	root.add_child(vp)
	_vp = vp

var _vp: SubViewport

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 5:
		_vp.get_texture().get_image().save_png(_out)
		return true
	return false
