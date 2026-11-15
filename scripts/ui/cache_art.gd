class_name CacheArt
extends Control

## Ein Lootcache als Zeichnung (Entwurf 15. Nov. 2026, docs/design/einsatz_arcade
## Bilder 17-22): je Fraktion eine eigene Kiste.
##
##     city    Neon Cache     Cyan/Magenta, Neon-Schriftzeichen
##     green   Solar Cache    gruene Kuppel mit Sonne und Blatt
##     plant7  Mecha Cache    graue Kiste, "F5", Warnstreifen
##     hip     Hipstar Cache  Terminal-Kiste "./open cache_07_"
##
## ``open`` hebt den Deckel ab (Wert 0..1, fuer die Oeffnen-Animation);
## ``locked`` zeichnet nur gestrichelte Umrisse (noch keiner / gesperrt).

const COLORS := {
	"city": [Color("#2ee3eb"), Color("#ff2bd6")],
	"green": [Color("#5cf2a2"), Color("#ffe14d")],
	"plant7": [Color("#9a93b8"), Color("#ff6a3d")],
	"hip": [Color("#ff8ce8"), Color("#2ee3eb")],
}

var kind: String = "city":
	set(value):
		kind = value
		queue_redraw()
var open: float = 0.0:
	set(value):
		open = value
		queue_redraw()
var locked: bool = false:
	set(value):
		locked = value
		queue_redraw()


func _init(cache_kind: String = "city", edge: float = 72.0) -> void:
	kind = cache_kind
	custom_minimum_size = Vector2(edge, edge * 0.8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func color(cache_kind: String) -> Color:
	return COLORS.get(cache_kind, COLORS["city"])[0]


func _draw() -> void:
	var s := minf(size.x, size.y / 0.8) / 100.0
	var o := Vector2((size.x - 100.0 * s) * 0.5, (size.y - 80.0 * s) * 0.5)
	var pair: Array = COLORS.get(kind, COLORS["city"])
	var line: Color = pair[0]
	var accent: Color = pair[1]
	if locked:
		line = Arcade.EMPTY_LINE
		accent = Arcade.EMPTY_LINE
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	var lift := open * 34.0
	var width := maxf(1.5, 3.0 * s)

	# Schatten
	if not locked:
		draw_set_transform(p.call(50, 76), 0.0, Vector2(1.0, 0.18))
		draw_circle(Vector2.ZERO, 40.0 * s, Color(accent, 0.25))
		draw_set_transform(Vector2.ZERO)

	match kind:
		"green":
			# Kuppel mit Blatt und Sonne
			var dome := PackedVector2Array()
			for i in 17:
				var a := PI + PI * float(i) / 16.0
				dome.append(p.call(50 + cos(a) * 40, 52 + sin(a) * 34 - lift))
			_shape(dome, Color("#0f2a1c") if not locked else Color.TRANSPARENT, line, width)
			var bowl := PackedVector2Array([p.call(10, 52), p.call(90, 52), p.call(80, 72), p.call(20, 72)])
			_shape(bowl, Color("#0f2a1c") if not locked else Color.TRANSPARENT, line, width)
			if not locked:
				draw_circle(p.call(50, 52), 9.0 * s, accent)
				for i in 8:
					var a := TAU * float(i) / 8.0
					draw_line(p.call(50 + cos(a) * 13, 52 + sin(a) * 13),
						p.call(50 + cos(a) * 18, 52 + sin(a) * 18), accent, width * 0.7)
				_shape(PackedVector2Array([p.call(50, 18 - lift), p.call(38, 8 - lift),
					p.call(50, 12 - lift)]), line, line, width * 0.5)
				_shape(PackedVector2Array([p.call(50, 18 - lift), p.call(62, 8 - lift),
					p.call(50, 12 - lift)]), line, line, width * 0.5)
		"plant7":
			var body := PackedVector2Array([p.call(12, 30), p.call(88, 30), p.call(88, 74), p.call(12, 74)])
			_shape(body, Color("#2a2540") if not locked else Color.TRANSPARENT, line, width)
			var lid := PackedVector2Array([p.call(8, 20 - lift), p.call(92, 20 - lift),
				p.call(92, 30 - lift), p.call(8, 30 - lift)])
			_shape(lid, Color("#3a3458") if not locked else Color.TRANSPARENT, line, width)
			if not locked:
				for i in 6:
					var x := 14.0 + i * 13.0
					_shape(PackedVector2Array([p.call(x, 72), p.call(x + 6, 62), p.call(x + 12, 62),
						p.call(x + 6, 72)]), Arcade.YELLOW, Arcade.YELLOW, 1.0)
				draw_rect(Rect2(p.call(40, 36), Vector2(20, 18) * s), Color(0, 0, 0, 0), false, width * 0.8)
				_text("F5", p.call(50, 49), 12.0 * s, accent)
		"hip":
			var body := PackedVector2Array([p.call(12, 26), p.call(88, 26), p.call(88, 72), p.call(12, 72)])
			_shape(body, Color("#1a0a33") if not locked else Color.TRANSPARENT, line, width)
			var lid := PackedVector2Array([p.call(10, 16 - lift), p.call(90, 16 - lift),
				p.call(90, 26 - lift), p.call(10, 26 - lift)])
			_shape(lid, Color("#2a1046") if not locked else Color.TRANSPARENT, line, width)
			if not locked:
				draw_rect(Rect2(p.call(22, 34), Vector2(56, 28) * s), accent, false, width * 0.7)
				_text("> ./open", p.call(50, 46), 8.0 * s, accent)
				_text("cache_07_", p.call(50, 57), 8.0 * s, accent)
		_:
			var body := PackedVector2Array([p.call(14, 30), p.call(86, 30), p.call(80, 74), p.call(20, 74)])
			_shape(body, Color("#1a0a33") if not locked else Color.TRANSPARENT, line, width)
			var lid := PackedVector2Array([p.call(8, 18 - lift), p.call(92, 18 - lift),
				p.call(88, 30 - lift), p.call(12, 30 - lift)])
			_shape(lid, Color("#2a1046") if not locked else Color.TRANSPARENT, line, width)
			if not locked:
				draw_rect(Rect2(p.call(34, 38), Vector2(32, 26) * s), accent, false, width * 0.8)
				# Neon-Zeichen: zwei Querstriche und Stiele
				draw_line(p.call(39, 44), p.call(61, 44), accent, width * 0.7)
				draw_line(p.call(41, 51), p.call(59, 51), accent, width * 0.7)
				draw_line(p.call(45, 44), p.call(43, 60), accent, width * 0.7)
				draw_line(p.call(55, 44), p.call(57, 60), accent, width * 0.7)
				draw_circle(p.call(50, 24 - lift), 3.5 * s, Arcade.YELLOW)


func _shape(points: PackedVector2Array, fill: Color, line: Color, width: float) -> void:
	if fill.a > 0.0:
		draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	if locked:
		for i in points.size():
			draw_dashed_line(closed[i], closed[i + 1], line, width * 0.7, 5.0)
	else:
		draw_polyline(closed, line, width, true)


func _text(text: String, center: Vector2, font_size: float, color: Color) -> void:
	var f := Arcade.font("bold")
	var px := maxi(6, int(round(font_size)))
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(f, center + Vector2(-w * 0.5, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
