extends RefCounted

## Barrierefreiheit: die Skalierung (Accessibility.compute_scale).
##
## Entwurfsraum ist ein Handy im Hochformat (450x800). Die Zusagen:
##   * im Hochformat misst ein Entwurfspixel von selbst ~0,9 CSS-Pixel,
##   * im Querformat wird so weit vergroessert, dass es mindestens so bleibt,
##   * die logische Flaeche faellt nie unter 360 (kurze) x 600 (lange Seite).

var t


func _stretch(window: Vector2) -> float:
	return minf(window.x / 450.0, window.y / 800.0)


func _logical(window: Vector2, factor: float) -> Vector2:
	return window / (_stretch(window) * factor)


func test_a_phone_in_portrait_needs_no_extra_scaling() -> void:
	var window := Vector2(1080, 2200)
	var factor: float = Accessibility.compute_scale(window, 2.625, 1.0)
	t.equal(factor, 1.0, "Hochformat: der Entwurfsraum passt von selbst")
	var css := _stretch(window) * factor / 2.625
	t.ok(css >= 0.85, "ein Entwurfspixel misst ~1 CSS-Pixel (%.2f)" % css)


func test_a_phone_in_landscape_stays_readable() -> void:
	var window := Vector2(2400, 1080)
	var factor: float = Accessibility.compute_scale(window, 2.625, 1.0)
	var css := _stretch(window) * factor / 2.625
	t.ok(factor > 1.4, "Querformat wird vergroessert (%.2f)" % factor)
	t.ok(css >= 0.85, "und bleibt lesbar (%.2f CSS-Pixel je Entwurfspixel)" % css)


func test_a_desktop_window_stays_unscaled() -> void:
	t.equal(Accessibility.compute_scale(Vector2(1600, 900), 1.0, 1.0), 1.0,
		"Desktop bei Pixeldichte 1: keine Vergroesserung")


func test_the_logical_area_never_gets_too_small() -> void:
	var cases := [
		[Vector2(1080, 2200), 2.625, 1.0],
		[Vector2(1080, 2200), 2.625, 1.4],
		[Vector2(2400, 1080), 2.625, 1.0],
		[Vector2(2400, 1080), 2.625, 1.4],
		[Vector2(1280, 720), 2.0, 1.4],
	]
	for case in cases:
		var factor: float = Accessibility.compute_scale(case[0], case[1], case[2])
		var logical := _logical(case[0], factor)
		var short_side := minf(logical.x, logical.y)
		var long_side := maxf(logical.x, logical.y)
		t.ok(short_side >= Accessibility.MIN_SHORT_SIDE - 0.5
			and long_side >= Accessibility.MIN_LONG_SIDE - 0.5,
			"%s @%.2f x%.1f: logisch %s bleibt ueber dem Minimum"
				% [case[0], case[1], case[2], logical])


func test_small_option_can_shrink() -> void:
	var factor: float = Accessibility.compute_scale(Vector2(1600, 900), 1.0, 0.85)
	t.ok(factor < 1.0, "\"Klein\" verkleinert (%.2f)" % factor)


## Langes Druecken sucht den Erklaertext auch am Elternteil: eine Aktionszeile
## traegt ihn am Container, getippt wird aber auf das Label darin.
func test_a_long_press_finds_the_tooltip_of_a_parent() -> void:
	var row := HBoxContainer.new()
	row.tooltip_text = "Puls-Salve: Reichweite 3"
	var label := Label.new()
	row.add_child(label)
	t.equal(Accessibility.tooltip_for(label), "Puls-Salve: Reichweite 3",
		"der Text des Containers wird gefunden")
	var lone := Label.new()
	t.equal(Accessibility.tooltip_for(lone), "", "ohne Tooltip: nichts")
	row.free()
	lone.free()
