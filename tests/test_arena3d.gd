extends RefCounted

## Der Kampf als eine 3D-Szene (Arena3D, 18. Nov. 2026): Hindernisse und alle
## DROMEs in einer Welt, die Modelle folgen den Einheiten.

var t


func _build(chassis: StringName, weapon: StringName) -> DromeBuild:
	var build := DromeBuild.create("X", {})
	build.apply_chassis(chassis)
	var slots := PartDB.get_part(chassis).equip_slots()
	if not slots.is_empty():
		build.slots[slots[0]] = weapon
	return build


func test_ground_matches_the_iso_projection() -> void:
	# Ein Bodenpunkt der 3D-Welt muss mit der Iso-Kamera genau dort landen,
	# wo IsoView das Feld zeichnet -- sonst stuenden Modelle neben Ringen und
	# Balken.
	var right := Vector3(DromeModel.COS45, 0, DromeModel.COS45)
	var up := Vector3(0.5, DromeModel.COS45, -0.5)
	for tile in [Vector2i(0, 0), Vector2i(4, 8), Vector2i(8, 16), Vector2i(3, 5)]:
		var p := IsoView.map_to_local(tile)
		var g := Arena3D.ground(p)
		t.ok(absf(g.y) < 0.0001, "%s liegt auf dem Boden" % tile)
		var screen := Vector2(g.dot(right), -g.dot(up)) * DromeModel.SCALE
		t.ok(screen.distance_to(p) < 0.01, "%s: Projektion %s = IsoView %s" % [tile, screen, p])


func test_units_get_one_model_in_the_shared_scene() -> void:
	var arena := Arena3D.new()
	var a := Unit.create(_build(&"scout_body", &"eq_neon_blaster"), &"P0", true)
	var b := Unit.create(_build(&"jugg_body", &"eq_hammer"), &"E0", false)
	for unit in [a, b]:
		unit.arena = arena
		unit.place_at(Vector2i(4, 10) if unit == a else Vector2i(4, 4))
		unit._build_sprites()
	t.ok(arena.model_of(a) != null and arena.model_of(b) != null, "je Einheit ein Modell")
	t.ok(a.get_node_or_null("Rig/Ansicht3D") == null, "keine eigene 3D-Ansicht mehr")
	t.ok(arena.get_node_or_null("Neon3D") != null, "Neon-Blaster: Leuchtebene da")
	arena._sync_unit(a, arena.model_of(a))
	t.ok(arena.model_of(a).position.is_equal_approx(
		Arena3D.ground(IsoView.map_to_local(Vector2i(4, 10)))), "Modell steht auf dem Feld")
	a.set_facing("deg30")
	t.ok(arena.turn_of(a).basis.is_equal_approx(DromeModel.facing_basis("deg30")),
		"Drehen dreht nur das Modell")
	a._apply_tint(Color(2, 1, 1))
	var mesh: MeshInstance3D = null
	for child in arena.turn_of(a).get_children():
		if child is MeshInstance3D:
			mesh = child
			break
	var own := mesh.get_surface_override_material(0) as ShaderMaterial if mesh != null else null
	t.ok(own != null and own.get_shader_parameter("tint") == Color(2, 1, 1),
		"Farbstich je Einheit (eigene Materialkopie)")
	t.ok(mesh.mesh.surface_get_material(0).get_shader_parameter("tint") != Color(2, 1, 1),
		"das geteilte Material bleibt unberuehrt")
	for unit in [a, b]:
		unit.free()
	arena.free()


func test_obstacles_stand_in_the_scene() -> void:
	var arena := Arena3D.new()
	var grid := MapGenerator.generate(TerrainDB.get_region(&"city"))
	MapGenerator.place_obstacles(grid, 42)
	arena.build_obstacles(grid)
	var count := 0
	for child in arena.get_node("Bild3D/Szene").get_children():
		if child.has_meta("obstacle"):
			count += 1
	t.equal(count, grid.obstacles.size(), "jedes Hindernis als 3D-Modell")
	for kind_list in Config.section("obstacles").get("kinds", {}).values():
		for kind in kind_list:
			t.ok(FileAccess.file_exists(Arena3D.ARENA_DIR % kind), "Modell fuer %s" % kind)
	arena.free()


## Beine im Wechsel (18. Nov. 2026): beim Laufen schwingt das linke Bein
## gegen das rechte; im Stand stehen beide wie gebaut.
func test_legs_alternate_while_walking() -> void:
	var calm := Accessibility.reduce_motion
	Accessibility.reduce_motion = false
	var arena := Arena3D.new()
	var unit := Unit.create(_build(&"scout_body", &"eq_plasma_blade"), &"P0", true)
	unit.arena = arena
	unit.place_at(Vector2i(4, 10))
	unit._build_sprites()
	var node := arena.model_of(unit)
	var turn := arena.turn_of(unit)
	var left := turn.get_node_or_null("feet_leg_left_upper") as Node3D
	var right := turn.get_node_or_null("feet_leg_right_upper") as Node3D
	var shin := turn.get_node_or_null("feet_leg_left_lower") as Node3D
	t.ok(left != null and right != null and shin != null, "Beine als eigene Knoten")
	if left != null and right != null and shin != null:
		arena._animate(unit, node, 0.1)
		t.ok(left.transform.is_equal_approx(left.get_meta("base")), "im Stand: Bein ruht")
		unit._glide_total = 1.0
		arena._anim[unit]["phase"] = 0.0
		arena._anim[unit]["time"] = 0.0
		# Viertel Schrittzyklus: linkes Bein vorn, rechtes hinten.
		arena._animate(unit, node, PI / 2.0 / Arena3D.WALK_SPEED)
		var l_angle := left.transform.basis.get_euler().y
		var r_angle := right.transform.basis.get_euler().y
		t.ok(absf(l_angle) > 0.2 and is_equal_approx(l_angle, -r_angle),
			"Beine schwingen gegengleich (%.2f / %.2f)" % [l_angle, r_angle])
		t.ok(l_angle < 0.0, "linkes Bein vorn")
		# Ganzer Zyklus: das linke Bein schwingt mittig nach vorn, Knie gebeugt.
		arena._animate(unit, node, PI * 1.5 / Arena3D.WALK_SPEED)
		var knee := (shin.transform.basis.get_euler().y) - (left.transform.basis.get_euler().y)
		var r_shin := turn.get_node("feet_leg_right_lower") as Node3D
		var r_knee := r_shin.transform.basis.get_euler().y - right.transform.basis.get_euler().y
		t.ok(knee > 0.3 and absf(r_knee) < 0.01,
			"das vorschwingende Bein beugt das Knie (%.2f / %.2f)" % [knee, r_knee])
	unit.free()
	arena.free()
	Accessibility.reduce_motion = calm
