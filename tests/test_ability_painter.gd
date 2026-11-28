extends RefCounted

## Faehigkeiten lesbar (18. Nov. 2026): der Vortex zeigt seine Flaeche bis zum
## Einschlag, danach die Schockwelle; Verlangsamte bekommen ihr Zeichen.

var t


func _scout() -> Unit:
	var build := DromeBuild.create("X", {})
	build.apply_chassis(&"scout_body")
	return Unit.create(build, &"P0", true)


func test_ellipse_covers_the_radius() -> void:
	# Die Marke reicht ueber die Mitte des aeussersten Feldes hinaus.
	var center := Vector2i(4, 8)
	var axes := AbilityPainter.ellipse_axes(2)
	var side := IsoView.map_to_local(center + Vector2i(2, 0)) - IsoView.map_to_local(center)
	var down := IsoView.map_to_local(center + Vector2i(0, 2)) - IsoView.map_to_local(center)
	t.ok(axes.x > absf(side.x), "waagerecht: %s > %s" % [axes.x, side.x])
	t.ok(axes.y > absf(down.y), "senkrecht: %s > %s" % [axes.y, down.y])


func test_vortex_lives_until_the_shockwave_is_over() -> void:
	var painter := AbilityPainter.new()
	painter.add_vortex(Vector2.ZERO, 2, 0.6, Teams.color(true))
	t.ok(not painter.is_idle(), "Vortex angezeigt")
	painter._process(0.6)
	t.ok(not painter.is_idle(), "Schockwelle nach dem Einschlag")
	painter._process(AbilityPainter.SHOCK_TIME + 0.01)
	t.ok(painter.is_idle(), "danach verschwunden")
	painter.free()


func test_slowed_units_get_a_mark() -> void:
	var painter := AbilityPainter.new()
	var unit := _scout()
	unit.hp = 10
	painter.units = [unit]
	t.ok(painter.is_idle(), "ohne Status nichts zu zeigen")
	unit.apply_status(&"slow", 2.5, {"move_mult": 0.6})
	t.ok(not painter.is_idle(), "verlangsamt: Zeichen am DROME")
	unit.tick_statuses(3.0)
	t.ok(painter.is_idle(), "Status abgelaufen: Zeichen weg")
	unit.free()
	painter.free()


func test_runestaff_vortex_is_a_gathering_area() -> void:
	# BattleScreen zeigt die Marke fuer Faehigkeiten mit Sog und Flaeche.
	var vortex: ActionData = null
	for action in PartDB.get_part(&"eq_rune_staff").actions:
		if action.id == &"act_rune_vortex":
			vortex = action
	t.ok(vortex != null and vortex.gather and vortex.aoe_radius > 0 and vortex.delay > 0.0,
		"Vortex: Sog, Flaeche, Verzoegerung")


## Jede Faehigkeit der Waffen bekommt ihre Form (Leinwand "Faehigkeiten lesbar").
func test_every_ability_has_a_form() -> void:
	var expected := {&"act_rune_vortex": "vortex",
		&"act_rail_pierce": "lock", &"act_hammer_stun": "stun",
		&"act_plasma_rend": "slash",
		&"act_pulse_double": "double",
		&"act_deflector_charge": "shield", &"act_repair_release": "drones"}
	var seen := {}
	for part: PartData in PartDB.of_type(PartData.Type.EQUIPMENT):
		for action in part.actions:
			if expected.has(action.id):
				seen[action.id] = true
				t.equal(AbilityPainter.kind_for(action), expected[action.id], str(action.id))
			elif action.is_attack():
				t.equal(AbilityPainter.kind_for(action), "", "%s: Angriff ohne Form" % action.id)
	t.equal(seen.size(), expected.size(), "alle Faehigkeiten gefunden")


func test_every_form_runs_its_course() -> void:
	var painter := AbilityPainter.new()
	for kind in ["lock", "stun", "slash", "double", "shield"]:
		painter.add(kind, {"at": Vector2(100, 100), "color": Teams.color(false), "enemy": true,
			"radius": 1, "delay": 0.8, "from": Vector2(0, 200), "dir": Vector2.RIGHT,
			"targets": [Vector2(100, 100), Vector2(160, 90)]})
	t.ok(not painter.is_idle(), "Formen angezeigt")
	for i in 30:
		painter._process(0.05)
	t.ok(painter.is_idle(), "nach 1,5 s alle abgelaufen")
	painter.free()


func test_stun_and_vulnerable_show_marks() -> void:
	var painter := AbilityPainter.new()
	var unit := _scout()
	unit.hp = 10
	painter.units = [unit]
	unit.apply_status(&"stun", 1.0, {"stunned": true})
	t.ok(not painter.is_idle(), "betaeubt: Sterne")
	unit.tick_statuses(1.1)
	unit.apply_status(&"vulnerable", 5.0, {"damage_taken_mult": 1.5})
	t.ok(not painter.is_idle(), "verwundbar: Riss")
	unit.tick_statuses(5.1)
	t.ok(painter.is_idle(), "abgelaufen")
	unit.free()
	painter.free()
