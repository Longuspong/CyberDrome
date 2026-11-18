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
	t.ok(mesh != null and mesh.get_instance_shader_parameter("tint") == Color(2, 1, 1),
		"Farbstich je Einheit")
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
