## Blicktest Beine im Wechsel (18. Nov. 2026): Vireo, Molok, Strix und Nimbus
## von schraeg vorn beim Laufen, vier Zeitpunkte eines Schrittzyklus (je ein Bild).
##   xvfb-run -a godot --path . --script res://docs/design/drome_entwurf/godot/render_main.gd -- \
##       res://docs/design/drome_entwurf/godot/render_laufen.gd /tmp/out/laufen [deg300]
extends RefCounted

const W := 680
const H := 260
const STEPS := 4

func _build(chassis: StringName, weapon: StringName) -> DromeBuild:
	var b := DromeBuild.create("X", {})
	b.apply_chassis(chassis)
	var slots := PartDB.get_part(chassis).equip_slots()
	if not slots.is_empty():
		b.slots[slots[0]] = weapon
	if slots.size() > 1:
		b.slots[slots[1]] = &"eq_hammer"
	return b

func build(root: Window, facing_arg: String) -> Array:
	var facing := facing_arg if facing_arg != "-" else "deg300"
	var views: Array = []
	for step in STEPS:
		var view := SubViewport.new()
		view.size = Vector2i(W, H)
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var bg := ColorRect.new(); bg.color = Color("#14102a"); bg.size = Vector2(W, H) * 4
		bg.position = -Vector2(W, H) * 1.5
		bg.z_index = -4000
		view.add_child(bg)
		var world := Node2D.new()
		view.add_child(world)
		var arena := Arena3D.new()
		world.add_child(arena)
		var cam := Camera2D.new()
		cam.zoom = Vector2(1.5, 1.5)
		cam.position = IsoView.map_to_local(Vector2i(4, 9)) + Vector2(0, -24)
		world.add_child(cam)
		cam.make_current()
		var squad := [[&"scout_body", &"eq_plasma_blade"], [&"jugg_body", &"eq_hammer"],
			[&"strix_body", &"eq_rail_lance"], [&"mage_body", &"eq_rune_staff"]]
		for i in squad.size():
			var unit := Unit.create(_build(squad[i][0], squad[i][1]), StringName("u%d" % i), true)
			unit.arena = arena
			unit.place_at(Vector2i(1 + i * 2, 9))
			unit.facing = facing
			world.add_child(unit)
			unit._glide_total = 1000.0
			unit._glide_from = unit.position
			unit._glide_to = unit.position
		root.add_child(view)
		# Zeitpunkt im Schrittzyklus: Phase so setzen, dass nach den ~8 Bildern
		# bis zur Aufnahme step/STEPS eines Zyklus erreicht ist.
		for unit in arena._anim:
			arena._anim[unit]["phase"] = TAU * step / STEPS / Arena3D.WALK_SPEED
		views.append(view)
	return views
