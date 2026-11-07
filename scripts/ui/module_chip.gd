class_name ModuleChip
extends Control

## Ein Modul als kleiner Chip: Gehaeuse mit Beinchen, zwei Buchstaben in der
## Mitte (Schnellfeuer = SF), Rand in der Farbe der Klasse (rot Angriff, blau
## Abwehr, gelb Taktik). Die Klasse steht zusaetzlich als Zeichen oben im
## Chip -- Spitze (Angriff), Bogen (Abwehr), Punkt (Taktik) --, damit man sie
## nicht nur an der Farbe erkennt. Rezept-Module haben einen doppelten Rand.
## Ruhende Module (Bedingung passt nicht zur Waffe) sind abgeblendet.

var module: ModuleData
var dim: bool = false:
	set(value):
		dim = value
		queue_redraw()
var edge: float = 48.0


func _init(which: ModuleData = null, size_edge: float = 48.0) -> void:
	module = which
	edge = size_edge
	custom_minimum_size = Vector2(size_edge, size_edge)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if module == null:
		return
	var color := module.color()
	if dim:
		color = color.darkened(0.55)
	var side := minf(size.x, size.y)
	var origin := (size - Vector2(side, side)) * 0.5
	var inset := side * 0.16
	var body := Rect2(origin + Vector2(inset, inset), Vector2(side - 2.0 * inset, side - 2.0 * inset))
	# Beinchen links und rechts
	var pins := 3
	for i in pins:
		var y := body.position.y + body.size.y * (float(i) + 0.5) / float(pins)
		draw_line(Vector2(origin.x + inset * 0.25, y), Vector2(body.position.x, y), color, 2.0)
		draw_line(Vector2(body.end.x, y), Vector2(origin.x + side - inset * 0.25, y), color, 2.0)
	var fill := Color(0.08, 0.1, 0.14) if not dim else Color(0.06, 0.07, 0.09)
	draw_rect(body, fill, true)
	draw_rect(body, color, false, 2.0)
	if module.is_recipe():
		draw_rect(body.grow(-4.0), color, false, 1.5)
	# Klassenzeichen oben
	var mark := Vector2(body.get_center().x, body.position.y + body.size.y * 0.22)
	var m := body.size.x * 0.12
	match module.klass:
		"attack":
			draw_polyline(PackedVector2Array([mark + Vector2(-m, m * 0.6), mark + Vector2(0, -m * 0.4),
				mark + Vector2(m, m * 0.6)]), color, 2.0, true)
		"defense":
			draw_arc(mark + Vector2(0, m * 0.6), m, PI, TAU, 10, color, 2.0, true)
		_:
			draw_circle(mark, m * 0.45, color)
	var font := get_theme_default_font()
	var font_size := int(maxf(11.0, side * 0.26))
	var text := module.short_name()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var base := Vector2(body.get_center().x - width * 0.5,
		body.position.y + body.size.y * 0.78)
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		Color(1, 1, 1, 0.5 if dim else 1.0))
