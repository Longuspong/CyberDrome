extends RefCounted

## Barrierefreiheit: die automatische Skalierung (Accessibility.compute_scale).
##
## Die Zusagen: am Desktop aendert sich nichts, auf dem Handy wird die Schrift
## lesbar, und die logische Flaeche faellt nie unter MIN_LOGICAL -- sonst
## passen die Bildschirme nicht mehr hinein.

var t


func _logical(window: Vector2, factor: float) -> Vector2:
	var stretch := minf(window.x / 1600.0, window.y / 900.0)
	return window / (stretch * factor)


func test_desktop_stays_unscaled() -> void:
	t.equal(Accessibility.compute_scale(Vector2(1600, 900), 1.0, 1.0), 1.0,
		"1600x900 bei Pixeldichte 1: keine Vergroesserung")
	t.equal(Accessibility.compute_scale(Vector2(1920, 1080), 1.0, 1.0), 1.0,
		"Full HD bei Pixeldichte 1: keine Vergroesserung")


func test_a_phone_gets_readable_text() -> void:
	var window := Vector2(2400, 1080)
	var ratio := 2.625
	var factor: float = Accessibility.compute_scale(window, ratio, 1.0)
	var stretch := minf(window.x / 1600.0, window.y / 900.0)
	var css_per_design := stretch * factor / ratio
	t.ok(factor > 1.4, "Handy im Querformat wird vergroessert (%.2f)" % factor)
	t.ok(css_per_design >= 0.7,
		"ein Entwurfspixel misst mindestens 0,7 CSS-Pixel (%.2f)" % css_per_design)


func test_the_logical_area_never_gets_too_small() -> void:
	var cases := [
		[Vector2(2400, 1080), 2.625, 1.0],
		[Vector2(2400, 1080), 2.625, 1.4],
		[Vector2(1280, 720), 2.0, 1.4],
		[Vector2(1080, 2400), 2.625, 1.0],
	]
	for case in cases:
		var factor: float = Accessibility.compute_scale(case[0], case[1], case[2])
		var logical := _logical(case[0], factor)
		t.ok(logical.x >= Accessibility.MIN_LOGICAL.x - 0.5
			and logical.y >= Accessibility.MIN_LOGICAL.y - 0.5,
			"%s @%.2f x%.1f: logisch %s bleibt ueber dem Minimum"
				% [case[0], case[1], case[2], logical])


func test_small_option_can_shrink_on_desktop() -> void:
	var factor: float = Accessibility.compute_scale(Vector2(1600, 900), 1.0, 0.85)
	t.ok(factor < 1.0, "\"Klein\" verkleinert am Desktop (%.2f)" % factor)


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
