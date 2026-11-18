## Blicktest Zerfallen in 3D (17. Nov. 2026): je Bausatz eine Kampfeinheit,
## die sofort zerfaellt. render_main.gd speichert ein Bild nach 10 Bildern;
## ``Engine.time_scale`` waehlt den Zeitpunkt (Argument 3, Standard 3.0).
##   xvfb-run -a godot --path . --script res://docs/design/drome_entwurf/godot/render_main.gd -- \
##       res://docs/design/drome_entwurf/godot/render_zerfall.gd /tmp/out/zerfall -
extends RefCounted

const PX := 256

func build(root: Window, _dir: String) -> Array:
	var args := OS.get_cmdline_user_args()
	Engine.time_scale = float(args[3]) if args.size() > 3 else 3.0
	var bodies: Array = PartDB.of_type(PartData.Type.BODY)
	bodies.sort_custom(func(a, b): return str(a.id) < str(b.id))
	var out := SubViewport.new()
	out.size = Vector2i(PX * bodies.size(), PX)
	out.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new(); bg.color = Color("#0a0618"); bg.size = Vector2(out.size)
	out.add_child(bg)
	root.add_child(out)
	for i in bodies.size():
		var chassis: PartData = bodies[i]
		var assignment := {"body": chassis.id}
		for type in [PartData.Type.HEAD, PartData.Type.FEET, PartData.Type.CORE]:
			for part in PartDB.of_type(type):
				if part.set_id == chassis.set_id:
					assignment[part.slot_name()] = part.id
		for slot in chassis.equip_slots():
			for part in PartDB.equipment_for(chassis, slot):
				if part.set_id == chassis.set_id:
					assignment[slot] = part.id
					break
		var unit := Unit.create(DromeBuild.create(chassis.set_id.to_upper(), assignment),
			StringName("u%d" % i), true)
		unit.position = Vector2(i * PX, 0)
		unit.scale = Vector2(2, 2)
		out.add_child(unit)
		unit.play_death()
	return [out]
