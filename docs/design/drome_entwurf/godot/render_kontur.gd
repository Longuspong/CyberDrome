## Blicktest Kontur je Teil + Neon-Leuchten am 3D-DROME (17. Nov. 2026):
## jeder Bausatz in vier Richtungen, dazu Vireo mit Neon-Blaster.
##   xvfb-run -a godot --path . --script res://docs/design/drome_entwurf/godot/render_main.gd -- \
##       res://docs/design/drome_entwurf/godot/render_kontur.gd /tmp/out/kontur -
extends RefCounted

const PX := 256

func _stock(chassis: PartData, neon: bool) -> DromeBuild:
	var assignment := {"body": chassis.id}
	for type in [PartData.Type.HEAD, PartData.Type.FEET, PartData.Type.CORE]:
		for part in PartDB.of_type(type):
			if part.set_id == chassis.set_id:
				assignment[part.slot_name()] = part.id
	for slot in chassis.equip_slots():
		for part in PartDB.equipment_for(chassis, slot):
			if neon and part.id != "eq_rune_staff":
				continue
			if neon or part.set_id == chassis.set_id:
				assignment[slot] = part.id
				break
	return DromeBuild.create(chassis.set_id.to_upper(), assignment)

func build(root: Window, _dir: String) -> Array:
	var bodies: Array = PartDB.of_type(PartData.Type.BODY)
	bodies.sort_custom(func(a, b): return str(a.id) < str(b.id))
	var builds := []
	for b in bodies:
		builds.append(_stock(b, false))
	builds.append(_stock(bodies[0] if bodies[0].id == "scout_body" else bodies.filter(
		func(x): return x.id == "scout_body")[0], true))
	var out := SubViewport.new()
	out.size = Vector2i(PX * 4, PX * builds.size())
	out.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new(); bg.color = Color("#0a0618"); bg.size = Vector2(out.size)
	out.add_child(bg)
	root.add_child(out)
	var facings := ["south", "east", "north", "west"]
	for r in builds.size():
		for c in 4:
			var rig := Node2D.new()
			rig.position = Vector2(c * PX, r * PX)
			rig.scale = Vector2(2, 2)
			out.add_child(rig)
			DromeSprites.assemble(rig, builds[r], facings[c], PX)
	return [out]
