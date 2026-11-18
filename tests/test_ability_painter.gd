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
