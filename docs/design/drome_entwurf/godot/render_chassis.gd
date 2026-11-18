## Blicktest ein Chassis gross (18. Nov. 2026): ein DROME mit Standard-
## ausruestung (oder WAFFE) in sechs Richtungen.
##   xvfb-run -a godot --path . --script res://docs/design/drome_entwurf/godot/render_main.gd -- \
##       res://docs/design/drome_entwurf/godot/render_chassis.gd /tmp/out/strix strix_body [WAFFE]
extends RefCounted

const PX := 384

func build(root: Window, chassis_arg: String) -> Array:
	var chassis := StringName(chassis_arg)
	var args := OS.get_cmdline_user_args()
	var b := DromeBuild.create("X", {})
	b.apply_chassis(chassis)
	var slots := PartDB.get_part(chassis).equip_slots()
	if args.size() > 3:
		b.slots[slots[0]] = StringName(args[3])
	var facings := ["deg270", "deg330", "deg30", "deg90", "deg150", "deg210"]
	var out := SubViewport.new()
	out.size = Vector2i(PX * 3, PX * 2)
	out.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new(); bg.color = Color("#120d24"); bg.size = Vector2(out.size)
	out.add_child(bg)
	root.add_child(out)
	for i in facings.size():
		var rig := Node2D.new()
		rig.position = Vector2((i % 3) * PX, (i / 3) * PX)
		rig.scale = Vector2.ONE * PX / 128.0
		out.add_child(rig)
		DromeSprites.assemble(rig, b, facings[i], PX)
	return [out]
