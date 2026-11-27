extends RefCounted

## Der Zusammenbau eines DROME als Bild (DromeSprites, 3D-Modell per
## SubViewport). Die Sockel-Regel der frueheren 2D-Bilder entfiel am
## 20. Nov. 2026 mit den Richtungsbildern; im 3D-Modell setzt DromeModel die
## Teile ueber die 3D-Anker aus den .m3d.

var t

## Die vier Blickrichtungen der Iso-Kamera (die Teile liegen seit 20. Nov. 2026
## nur noch als Suedansicht-Symbol vor; gedreht wird das 3D-Modell).
const DIRECTIONS := ["south", "west", "east", "north"]


func _bodies() -> Array[PartData]:
	var bodies: Array[PartData] = []
	for part in PartDB.of_type(PartData.Type.BODY):
		bodies.append(part)
	bodies.sort_custom(func(a, b): return str(a.id) < str(b.id))
	return bodies


## Was in diesen Slot darf -- bevorzugt aus dem eigenen Bausatz, denn das ist
## der Fall, den der Spieler zu sehen bekommt.
func _equipment_for(chassis: PartData, slot: String) -> PartData:
	var fallback: PartData = null
	for part in PartDB.equipment_for(chassis, slot):
		if part.set_id == chassis.set_id:
			return part
		if fallback == null:
			fallback = part
	return fallback


## Der Standardaufbau eines Bausatzes -- Sockelteile aus demselben Satz, in
## jeden Ausruestungsslot das erste Teil, das dort hineindarf.
func _stock(chassis: PartData) -> DromeBuild:
	var assignment := {"body": chassis.id}
	for type in [PartData.Type.HEAD, PartData.Type.FEET, PartData.Type.CORE]:
		for part in PartDB.of_type(type):
			if part.set_id == chassis.set_id:
				assignment[part.slot_name()] = part.id
	for slot in chassis.equip_slots():
		var part := _equipment_for(chassis, slot)
		if part != null:
			assignment[slot] = part.id
	return DromeBuild.create(chassis.set_id.to_upper(), assignment)


# ---------------------------------------------------------------------------
# Der Zusammenbau
# ---------------------------------------------------------------------------

func test_assemble_builds_one_3d_view() -> void:
	# Seit 17. Nov. 2026 ein echtes 3D-Modell: EIN Sprite mit dem Bild einer
	# 3D-Ansicht statt eines Stapels flacher Teile.
	var root := Node2D.new()
	for chassis: PartData in _bodies():
		var sprites := DromeSprites.assemble(root, _stock(chassis), "south")
		t.equal(sprites.keys(), ["drome"], "%s: ein Bild je DROME" % chassis.id)
		var view := root.get_node_or_null("Ansicht3D") as SubViewport
		t.ok(view != null, "%s: 3D-Ansicht da" % chassis.id)
		if view == null:
			continue
		t.ok(sprites["drome"].texture is ViewportTexture, "%s: Bild aus der 3D-Ansicht" % chassis.id)
		t.ok(sprites["drome"].material is ShaderMaterial, "%s: mit Kontur" % chassis.id)
		var cam: Camera3D = null
		for child in view.get_children():
			if child is Camera3D:
				cam = child
		t.ok(cam != null and cam.projection == Camera3D.PROJECTION_ORTHOGONAL,
			"%s: Iso-Kamera" % chassis.id)
	root.free()


func test_every_part_has_a_3d_model() -> void:
	for type in [PartData.Type.BODY, PartData.Type.HEAD, PartData.Type.FEET,
			PartData.Type.CORE, PartData.Type.EQUIPMENT]:
		for part: PartData in PartDB.of_type(type):
			var model := DromeModel.model_of(part)
			t.ok(not model.is_empty(), "%s hat ein 3D-Modell" % part.id)
			if part.type != PartData.Type.HEAD:
				# Beine liegen als eigene Bloecke in den Varianten (18. Nov. 2026).
				var count: int = model.get("faces", []).size()
				for vname in DromeModel.LEG_BLOCKS:
					count += model.get("variants", {}).get(vname, {}).get("faces", []).size()
				t.ok(count > 0, "%s hat Flaechen" % part.id)


## Beine im Wechsel: wer Beine hat, bekommt je Seite Ober- und Unterschenkel
## als eigene Knoten; das Fahrwerk des Nimbus nicht.
func test_legs_are_own_blocks() -> void:
	for feet_id in [&"scout_feet", &"jugg_feet", &"strix_feet", &"mage_drive"]:
		var model := DromeModel.model_of(PartDB.get_part(feet_id))
		var variants: Dictionary = model.get("variants", {})
		var legged: bool = feet_id != &"mage_drive"
		for vname in DromeModel.LEG_BLOCKS:
			t.equal(variants.has(vname), legged, "%s: %s" % [feet_id, vname])
		if legged:
			var upper: Dictionary = variants["leg_left_upper"]
			t.ok(not upper["faces"].is_empty() and not variants["leg_left_lower"]["faces"].is_empty(),
				"%s: Ober- und Unterschenkel haben Flaechen" % feet_id)
			t.ok(upper["anchors"].has("knee"), "%s: Knie als Drehpunkt" % feet_id)
			t.ok(float(upper["anchors"]["mount"][1]) > 0.0
				and float(variants["leg_right_upper"]["anchors"]["mount"][1]) < 0.0,
				"%s: Huefte links/rechts gespiegelt" % feet_id)


## Die Kamera bildet exakt so ab wie ``to_screen`` im Generator: dieselbe
## Stelle im 128er Entwurfsraum wie vorher die SVG-Teile.
func test_camera_matches_the_svg_projection() -> void:
	var cam := DromeModel.make_camera()
	var inv := cam.transform.affine_inverse()
	var points := [Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(0, 10, 0),
		Vector3(0, 0, 50), Vector3(7, -12, 33)]
	for facing in DIRECTIONS:
		var basis := DromeModel.facing_basis(facing)
		var fl: Array = DromeModel.FACINGS[facing]
		for p: Vector3 in points:
			var local := inv * (basis * p)
			var got := Vector2(64.0 + local.x * DromeModel.SCALE, 64.0 - local.y * DromeModel.SCALE)
			var f: Vector2 = fl[0]
			var l: Vector2 = fl[1]
			var px := p.x * f.x + p.y * l.x
			var py := p.x * f.y + p.y * l.y
			var want := Vector2(64.0 + 0.70710678 * (px - py) * 1.35,
				96.0 - (0.5 * (px + py) + 0.70710678 * p.z) * 1.35)
			t.ok(got.distance_to(want) < 0.01, "%s %s: %s statt %s" % [facing, p, got, want])
	cam.free()


## Im Modell: Rahmenteile auf ihrem Sockel, der Arm an der Schulter, die
## Waffe mit dem Griff in der Hand (Schritt 4b).
func test_model_puts_arm_on_socket_and_weapon_in_hand() -> void:
	for chassis: PartData in _bodies():
		var build := _stock(chassis)
		var node := DromeModel.build_node(build, "south")
		var turn := node.get_node("Ausrichtung")
		var body_model := DromeModel.model_of(chassis)
		var anchors: Dictionary = body_model.get("anchors", {})
		var variants: Dictionary = body_model.get("variants", {})
		t.ok(turn.get_node_or_null("body") != null, "%s: Rumpf im Modell" % chassis.id)
		if turn.get_node_or_null("body") != null:
			t.equal(turn.get_node("body").position, Vector3.ZERO, "%s: Rumpf bleibt liegen" % chassis.id)
		for slot in chassis.equip_slots():
			var part := build.part_in(slot)
			var model := DromeModel.model_of(part)
			var arm: Dictionary = variants.get("arm_%s_%s" % [slot, model.get("pose", "")], {})
			if arm.is_empty():
				continue
			var arm_node := turn.get_node_or_null("%s_arm" % slot) as Node3D
			var weapon := turn.get_node_or_null(slot) as Node3D
			t.ok(arm_node != null and weapon != null, "%s/%s: Arm und Waffe da" % [chassis.id, slot])
			if arm_node == null or weapon == null:
				continue
			var socket := DromeModel._vec(anchors[slot])
			t.ok(arm_node.position.distance_to(
				socket - DromeModel._vec(arm["anchors"]["mount"])) < 0.001,
				"%s/%s: Arm am Sockel" % [chassis.id, slot])
			var hand := DromeModel._vec(arm["anchors"]["hand"])
			var grip := weapon.position + DromeModel._vec(
				_block_for(chassis, slot, model)["anchors"]["mount"])
			t.ok(grip.distance_to(hand) < 0.001, "%s/%s: Griff in der Hand" % [chassis.id, slot])
		node.free()


func _block_for(chassis: PartData, slot: String, model: Dictionary) -> Dictionary:
	if chassis.weapon_variant == "":
		return model
	var variants: Dictionary = model.get("variants", {})
	var name := chassis.weapon_variant + ("_right" if slot == "equip_right" else "")
	if not variants.has(name):
		name = chassis.weapon_variant
	return variants.get(name, model)


## Drehen baut nicht neu: dieselbe 3D-Ansicht, nur das Modell dreht sich.
func test_turning_reuses_the_3d_view() -> void:
	var root := Node2D.new()
	var build := _stock(PartDB.get_part(&"scout_body"))
	var first := DromeSprites.assemble(root, build, "south")
	var second := DromeSprites.assemble(root, build, "east")
	t.ok(first["drome"] == second["drome"], "Drehen behaelt das Bild")
	var turn := root.get_node("Ansicht3D/Drome/Ausrichtung") as Node3D
	t.ok(turn.basis.is_equal_approx(DromeModel.facing_basis("east")), "Modell schaut nach Osten")
	root.free()


func test_rim_per_part_and_neon_layer() -> void:
	# 17. Nov. 2026: Kontur je Teil (Signalebene) und Neon-Leuchten in 3D.
	var root := Node2D.new()
	var build := _stock(PartDB.get_part(&"scout_body"))
	var slot: String = PartDB.get_part(&"scout_body").equip_slots()[0]
	build.slots[slot] = &"eq_rune_staff"
	var sprites := DromeSprites.assemble(root, build, "south")
	var signal_view := root.get_node_or_null("Signal3D") as SubViewport
	t.ok(signal_view != null, "Signalebene da")
	t.ok(root.get_node_or_null("Neon3D") != null, "Leuchtebene da (Runenstab)")
	t.ok(sprites["drome"].get_node_or_null("Neon") is NeonGlow, "Leuchten liegt auf dem Bild")
	var view := root.get_node("Ansicht3D") as SubViewport
	t.ok(signal_view.world_3d == view.world_3d, "Signalebene sieht dieselbe 3D-Welt")
	var weapon := root.get_node_or_null("Ansicht3D/Drome/Ausrichtung/" + slot) as MeshInstance3D
	t.ok(weapon != null, "Waffe als eigener Block")
	if weapon != null:
		var sig := weapon.get_node("Signal") as MeshInstance3D
		var model := DromeModel.model_of(PartDB.get_part(&"eq_rune_staff"))
		t.ok(sig.layers == DromeModel.LAYER_SIGNAL, "Signal nur auf seiner Ebene")
		t.ok((sig.material_override as StandardMaterial3D).albedo_color.is_equal_approx(
			Color.html(model["colors"]["accent"])), "Waffe traegt ihre eigene Signalfarbe")
	# Ohne Neon-Teil keine Leuchtebene.
	DromeSprites.assemble(root, _stock(PartDB.get_part(&"jugg_body")), "south")
	t.ok(root.get_node_or_null("Neon3D") == null, "ohne Neon kein Leuchten")
	root.free()
