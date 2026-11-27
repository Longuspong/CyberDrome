## Blicktest Waffenfarben (18. Nov. 2026): je Vorschlagssatz aus
## v13_waffenfarben.py eine Reihe mit allen Waffen, jede an ihrem Bausatz-
## Chassis, mit Glanzkante (Entwurfs-Shader) und Leuchten ("energie").
##   python3 docs/design/drome_entwurf/v13_waffenfarben.py /tmp/wf
##   xvfb-run -a godot --path . --script res://docs/design/drome_entwurf/godot/render_main.gd -- \
##       res://docs/design/drome_entwurf/godot/render_waffenfarben.gd /tmp/wf/bild /tmp/wf [FACING]
## Ein Bild je Satz (bild_0 = heute, bild_1 = A ...), Waffen in ORDER.
## Ordner "-" statt des Plans: eine Reihe so, wie das Spiel sie zeigt.
extends RefCounted

const PX := 384
const GLANZ := preload("res://docs/design/drome_entwurf/godot/drome_face_glanz.gdshader")
const ORDER := ["eq_pulse_blaster", "eq_plasma_blade", "eq_deflector", "eq_hammer",
	"eq_rune_staff", "eq_rail_lance"]
const CHASSIS := {"eq_pulse_blaster": &"scout_body", "eq_plasma_blade": &"scout_body",
	"eq_deflector": &"jugg_body", "eq_hammer": &"jugg_body",
	"eq_rune_staff": &"mage_body", "eq_rail_lance": &"strix_body"}

func _build(chassis: StringName, weapon: StringName) -> DromeBuild:
	var b := DromeBuild.create("X", {})
	b.apply_chassis(chassis)
	b.slots[PartDB.get_part(chassis).equip_slots()[0]] = weapon
	return b

## Glanzkante: Flaechen der Waffe (nicht Leuchtteile) mit dem Entwurfs-Shader.
func _shine(node: Node, slot: String, amount: float) -> void:
	if amount <= 0.0:
		return
	for inst in node.find_children(slot, "MeshInstance3D", true, false):
		var mesh: Mesh = inst.mesh
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i) as ShaderMaterial
			if mat == null or str(mesh.surface_get_name(i)) in ["glow", "accent"]:
				continue
			var copy := ShaderMaterial.new()
			copy.shader = GLANZ
			for p in ["c_top", "c_left", "c_right", "c_line", "edge_px"]:
				copy.set_shader_parameter(p, mat.get_shader_parameter(p))
			copy.set_shader_parameter("shine", amount)
			inst.set_surface_override_material(i, copy)

## Nur die Waffe zeigen, vergroessert und in die Bildmitte geschoben.
func _close_up(rig: Node, slot: String) -> void:
	var view := rig.get_node("Ansicht3D") as SubViewport
	var model := view.get_node("Drome") as Node3D
	var turn := model.get_node("Ausrichtung") as Node3D
	var weapon := turn.get_node_or_null(slot) as MeshInstance3D
	if weapon == null:
		return
	for child in turn.get_children():
		child.visible = child == weapon
	var center := turn.transform * (weapon.transform * weapon.get_aabb().get_center())
	var target := turn.transform * Vector3(0, 0, 40)
	var size := weapon.get_aabb().size.length()
	var s := clampf(78.0 / maxf(size, 1.0), 1.2, 3.2)
	model.scale = Vector3.ONE * s
	model.position = target - center * s
	DromeSprites.redraw(rig)

func build(root: Window, dir: String) -> Array:
	# Ordner "-": eine Reihe so, wie das Spiel die Waffen heute zeigt.
	var plan: Dictionary = {"spiel": {"weapons": {}}} if dir == "-" \
		else JSON.parse_string(FileAccess.get_file_as_string(dir + "/waffenfarben.json"))
	var args := OS.get_cmdline_user_args()
	var facing := args[3] if args.size() > 3 else "south"
	# "nah": nur die Waffe, gross (Farben beurteilen); sonst am ganzen DROME.
	var close := args.size() > 4 and args[4] == "nah"
	var keys: Array = plan.keys()
	keys.sort()
	var outs: Array = []
	for key in keys:
		var spec: Dictionary = plan[key]
		var out := SubViewport.new()
		out.size = Vector2i(PX * ORDER.size(), PX)
		out.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var bg := ColorRect.new(); bg.color = Color("#120d24"); bg.size = Vector2(out.size)
		out.add_child(bg)
		root.add_child(out)
		for i in ORDER.size():
			var pid: String = ORDER[i]
			var w: Dictionary = spec["weapons"].get(pid, {})
			var model := DromeModel.model_of(PartDB.get_part(StringName(pid)))
			if not w.is_empty():
				model["colors"] = w["colors"]
				model["neon"] = bool(w["energie"])
			var build := _build(CHASSIS[pid], StringName(pid))
			var rig := Node2D.new()
			rig.position = Vector2(i * PX, 0)
			rig.scale = Vector2.ONE * PX / 128.0
			out.add_child(rig)
			DromeSprites.assemble(rig, build, facing, PX)
			var slot := str(build.equip_slots()[0])
			_shine(rig, slot, float(w.get("glanz", 0.0)))
			if close:
				_close_up(rig, slot)
		outs.append(out)
	return outs
