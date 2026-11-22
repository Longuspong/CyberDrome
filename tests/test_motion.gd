extends RefCounted

## Kampfbild "mehr 3D", Paket 1 und 2 (21. Nov. 2026): Bewegung ueber eine
## Feder (Kurven, Durchlaufen), weiches Drehen, Koerpersprache, lockere
## Aufstellung, vorgetaeuschtes Licht, Teilchen. Alles nur Bild -- die Felder
## der Logik bleiben unberuehrt.

var t


func _build(chassis: StringName, weapon: StringName) -> DromeBuild:
	var build := DromeBuild.create("X", {})
	build.apply_chassis(chassis)
	var slots := PartDB.get_part(chassis).equip_slots()
	if not slots.is_empty():
		build.slots[slots[0]] = weapon
	return build


## Einen Schritt so ausloesen wie BattleManager + BattleScreen.
func _step(unit: Unit, tile: Vector2i, seconds: float) -> void:
	unit.place_at(tile)
	unit.animate_last_move(seconds)


func _run(unit: Unit, seconds: float, dt: float = 1.0 / 60.0) -> float:
	var slowest := INF
	var time := 0.0
	while time < seconds - 0.0001:
		unit._process(dt)
		slowest = minf(slowest, unit.visual_velocity().length())
		time += dt
	return slowest


func test_feld_gilt_sofort_bild_laeuft_nach() -> void:
	var unit := Unit.create(_build(&"scout_body", &"eq_neon_blaster"), &"P0", true)
	unit.place_at(Vector2i(4, 10))
	var start := unit.position
	_step(unit, Vector2i(4, 9), 0.5)
	t.ok(unit.tile == Vector2i(4, 9), "das Feld gilt sofort")
	t.ok(unit.position.is_equal_approx(start), "die Figur steht noch, wo sie war")
	_run(unit, 1.5)
	var goal := IsoView.sprite_position(Vector2i(4, 9)) + unit.stand_offset()
	t.ok(unit.position.distance_to(goal) < 0.01, "am Ende genau auf dem Feld (mit Versatz)")
	t.ok(unit.visual_velocity() == Vector2.ZERO, "und steht still")
	unit.free()


func test_durchlaufen_ohne_absetzen() -> void:
	# Drei Schritte hintereinander: zwischen den Feldern faellt das Tempo der
	# Figur nicht auf null (vorher: Halt an jeder Feldmitte je Richtungswechsel).
	var unit := Unit.create(_build(&"scout_body", &"eq_neon_blaster"), &"P0", true)
	unit.place_at(Vector2i(4, 10))
	var path := [Vector2i(4, 9), Vector2i(5, 8), Vector2i(5, 7)]
	var slowest := INF
	for i in path.size():
		_step(unit, path[i], 0.5)
		var low := _run(unit, 0.5)
		if i > 0:
			slowest = minf(slowest, low)
	t.ok(slowest > 30.0, "laeuft ueber die Feldmitten durch (langsamstes Tempo %.1f px/s)" % slowest)
	_run(unit, 1.5)
	t.ok(unit.position.distance_to(IsoView.sprite_position(Vector2i(5, 7)) + unit.stand_offset()) < 0.01,
		"bremst erst am Ziel und steht dann genau dort")
	unit.free()


func test_kurve_schneidet_ecken_nur_leicht() -> void:
	var unit := Unit.create(_build(&"jugg_body", &"eq_hammer"), &"E0", false)
	unit.place_at(Vector2i(4, 10))
	var corner := IsoView.sprite_position(Vector2i(4, 9)) + unit.stand_offset()
	var nearest := INF
	_step(unit, Vector2i(4, 9), 0.6)
	for i in 36:
		unit._process(1.0 / 60.0)
		nearest = minf(nearest, unit.position.distance_to(corner))
	_step(unit, Vector2i(5, 8), 0.6)
	for i in 90:
		unit._process(1.0 / 60.0)
		nearest = minf(nearest, unit.position.distance_to(corner))
	t.ok(nearest > 0.5, "die Ecke wird geschnitten (%.1f px)" % nearest)
	t.ok(nearest < IsoView.TILE_W * 0.35, "aber nur leicht (%.1f px)" % nearest)
	unit.free()


func test_stoss_rutscht_weiter_gerade() -> void:
	var unit := Unit.create(_build(&"scout_body", &"eq_neon_blaster"), &"P0", true)
	unit.place_at(Vector2i(4, 10))
	unit.place_at(Vector2i(4, 7))
	unit.animate_last_move(0.2, true)
	_run(unit, 0.25)
	t.ok(unit.position.distance_to(IsoView.sprite_position(Vector2i(4, 7)) + unit.stand_offset()) < 0.01,
		"Sog und Stoss: in der Rutschzeit am Ziel")
	unit.free()


func test_gehaltene_figur_bleibt_am_finger() -> void:
	var unit := Unit.create(_build(&"scout_body", &"eq_neon_blaster"), &"P0", true)
	unit.place_at(Vector2i(4, 10))
	unit.held = true
	unit.position = Vector2(300, 300)
	unit.nudge = Vector2(5, 0)
	_run(unit, 0.3)
	t.ok(unit.position == Vector2(300, 300), "die Feder zieht nicht am Finger")
	unit.free()


func test_versatz_fest_und_klein() -> void:
	var a := Unit.create(_build(&"scout_body", &"eq_neon_blaster"), &"P0", true)
	var b := Unit.create(_build(&"scout_body", &"eq_neon_blaster"), &"P1", true)
	t.ok(a.stand_offset() == a.stand_offset(), "gleicher Versatz bei jedem Aufruf")
	t.ok(a.stand_offset() != b.stand_offset(), "je Figur ein anderer")
	t.ok(a.stand_offset().length() <= IsoView.TILE_W * 0.1, "bleibt im Feld")
	a.free()
	b.free()


func test_zielen_auf_dem_boden_gemessen() -> void:
	# Nachbarfeld schraeg oben rechts: Hexrichtung 30 Grad auf dem Boden --
	# genau wie facing_toward, sonst zielte die Waffe daneben.
	var from := Vector2i(4, 8)
	var to := Grid.neighbor(from, 0)
	t.ok(Unit.facing_at(from, to) == Unit.facing_toward(from, to),
		"facing_at %s = facing_toward %s" % [Unit.facing_at(from, to), Unit.facing_toward(from, to)])


func test_drehen_statt_springen() -> void:
	var calm := Accessibility.reduce_motion
	Accessibility.reduce_motion = false
	var arena := Arena3D.new()
	var unit := Unit.create(_build(&"scout_body", &"eq_neon_blaster"), &"P0", true)
	unit.arena = arena
	unit.place_at(Vector2i(4, 10))
	unit._build_sprites()
	var node := arena.model_of(unit)
	unit.set_facing("deg90")
	arena._animate(unit, node, 0.05)
	unit.set_facing("deg270")
	arena._animate(unit, node, 1.0 / 60.0)
	var yaw: float = arena._anim[unit]["yaw"]
	t.ok(absf(wrapf(yaw - 90.0, -180.0, 180.0)) > 1.0 and absf(wrapf(yaw - 270.0, -180.0, 180.0)) > 20.0,
		"nach einem Bild: mitten in der Drehung (%.0f Grad)" % yaw)
	for i in 20:
		arena._animate(unit, node, 1.0 / 60.0)
	yaw = arena._anim[unit]["yaw"]
	t.ok(absf(wrapf(yaw - 270.0, -180.0, 180.0)) < 3.0, "halbe Drehung nach 0,35 s angekommen (%.0f Grad)" % yaw)
	# Eine Hexrichtung weiter (60 Grad): in rund 0,15 s.
	unit.set_facing("deg330")
	for i in 9:
		arena._animate(unit, node, 1.0 / 60.0)
	yaw = arena._anim[unit]["yaw"]
	t.ok(absf(wrapf(yaw - 330.0, -180.0, 180.0)) < 4.0, "60 Grad in 0,15 s (%.0f Grad)" % yaw)
	unit.free()
	arena.free()
	Accessibility.reduce_motion = calm


func test_lehnt_beim_anlaufen_nach_vorn() -> void:
	var calm := Accessibility.reduce_motion
	Accessibility.reduce_motion = false
	var arena := Arena3D.new()
	var unit := Unit.create(_build(&"scout_body", &"eq_neon_blaster"), &"P0", true)
	unit.arena = arena
	unit.place_at(Vector2i(4, 10))
	unit._build_sprites()
	var node := arena.model_of(unit)
	unit._vel = Vector2(90, 0)
	unit._acc = Vector2(300, 0)
	for i in 20:
		arena._animate(unit, node, 1.0 / 60.0)
	var lean: Vector2 = arena._anim[unit]["lean"]
	t.ok(lean.x > 0.05, "lehnt nach vorn (%.2f rad)" % lean.x)
	unit._acc = Vector2(-1500, 0)
	for i in 20:
		arena._animate(unit, node, 1.0 / 60.0)
	lean = arena._anim[unit]["lean"]
	t.ok(lean.x < 0.0, "beim Bremsen kurz zurueck (%.2f rad)" % lean.x)
	unit.free()
	arena.free()
	Accessibility.reduce_motion = calm


func test_laterne_toent_die_figur() -> void:
	var arena := Arena3D.new()
	var unit := Unit.create(_build(&"scout_body", &"eq_neon_blaster"), &"P0", true)
	unit.arena = arena
	unit.place_at(Vector2i(4, 10))
	unit._build_sprites()
	arena.light_spots = [[unit.visual_anchor() + Vector2(20, 0), Color(0.2, 0.9, 1.0), 90.0]]
	arena._apply_light(unit, arena.model_of(unit), arena._anim[unit])
	var mats: Array = arena._anim[unit].get("face_mats", [])
	t.ok(not mats.is_empty(), "Flaechen gesammelt")
	if not mats.is_empty():
		var glow: Vector3 = (mats[0] as ShaderMaterial).get_shader_parameter("glow_in")
		t.ok(glow.z > glow.x and glow.z > 0.05, "cyanes Licht auf der Figur (%s)" % glow)
	unit.free()
	arena.free()


func test_funken_fallen_zu_boden() -> void:
	var calm := Accessibility.reduce_motion
	Accessibility.reduce_motion = false
	var fx := ParticleFx.new()
	fx.hit(Vector2(100, 100), 24.0, Color.WHITE, 0.0, true)
	t.ok(fx.count() > 5, "Funken und Rauch entstehen (%d)" % fx.count())
	var landed := false
	var below := false
	for i in 40:
		fx.step(1.0 / 60.0)
		for part in fx._parts:
			if part["kind"] == "spark" and part["rest"]:
				landed = true
			if (part["p"] as Vector3).z < 0.0:
				below = true
	t.ok(landed and not below, "Funken landen auf dem Boden, nicht darunter")
	for i in 120:
		fx.step(1.0 / 60.0)
	t.ok(fx.count() == 0, "nach kurzer Zeit alles verschwunden")
	for i in 200:
		fx.debris(Vector2.ZERO, [Color.RED])
	t.ok(fx.count() <= ParticleFx.limit(), "Obergrenze haelt (%d)" % fx.count())
	Accessibility.reduce_motion = true
	var quiet := ParticleFx.new()
	quiet.hit(Vector2.ZERO, 10.0, Color.WHITE, 0.0, true)
	t.ok(quiet.count() == 0, "Bewegung reduzieren: keine Teilchen")
	fx.free()
	quiet.free()
	Accessibility.reduce_motion = calm


# ---------------------------------------------------------------------------
# Paket 3 (ohne Hoehenstufen)
# ---------------------------------------------------------------------------

func test_bodenmarke_sind_genau_die_felder() -> void:
	var painter := AbilityPainter.new()
	var at := IsoView.map_to_local(Vector2i(4, 8))
	t.ok(painter.area_tiles(at, 0).size() == 1, "Radius 0: ein Feld")
	t.ok(painter.area_tiles(at, 1).size() == 7, "Radius 1: Feld und sechs Nachbarn")
	t.ok(painter.area_tiles(at, 2).size() == 19, "Radius 2: 19 Felder")
	for tile in painter.area_tiles(at, 2):
		t.ok(Grid.distance(Vector2i(4, 8), tile) <= 2, "%s liegt im Radius" % tile)
	painter.free()


func test_szenen_kamera_bleibt_nahe_der_iso_richtung() -> void:
	for kind in Cinema.SHOTS:
		var shot: Dictionary = Cinema.SHOTS[kind]
		for k in [0.0, 0.5, 1.0]:
			var p := Cinema.camera_place(shot, Vector3.ZERO, k)
			t.ok(p.y > 10.0, "%s %.1f: Kamera ueber dem Boden" % [kind, k])
			var flat := Vector2(p.x, p.z).normalized()
			var iso := Vector2(-1.0, 1.0).normalized()
			t.ok(rad_to_deg(acos(clampf(flat.dot(iso), -1.0, 1.0))) <= Cinema.ORBIT_MAX + 0.5,
				"%s %.1f: hoechstens %d Grad seitlich" % [kind, k, int(Cinema.ORBIT_MAX)])


func test_echtes_licht_waehlt_blitze_und_naechste_laternen() -> void:
	var arena := Arena3D.new()
	for i in 12:
		arena.light_spots.append([Vector2(i * 100.0, 0.0), Color(0.2, 0.9, 1.0), 90.0])
	arena.light_spots.append([Vector2(5.0, 5.0), Color.RED, 70.0])
	var lights := arena.real_lights()
	t.ok(lights.size() == Arena3D.REAL_LIGHTS, "hoechstens acht Lichter (%d)" % lights.size())
	var first: Vector4 = lights[0][0]
	t.ok(Vector2(first.x, first.z).distance_to(Vector2(Arena3D.ground(Vector2.ZERO).x,
		Arena3D.ground(Vector2.ZERO).z)) < 0.01, "die naechste Laterne zuerst")
	arena._flashes.append({"unit": null, "at": Vector2(300, 0), "foot": Vector2(300, 0), "t": 0.0})
	lights = arena.real_lights()
	t.ok(lights.size() == Arena3D.REAL_LIGHTS, "mit Blitz weiter acht")
	t.ok((lights[0][1] as Vector4).x > 1.0, "der Blitz kommt zuerst und ist hell")
	arena.free()
