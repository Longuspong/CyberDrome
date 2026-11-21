class_name CacheArt
extends Control

## Ein Lootcache als Zeichnung. Seit 20. Nov. 2026 (Design-Canvas "Lootcaches
## Rework", vom Spieler abgesegnet) ein schwerer Hex-Container -- dieselbe Form
## wie Spielfeld und Charger --, den jede Fraktion auf ihre Art baut:
##
##     city    Neon Cache     dunkles Metall, rote/orange Leuchtstreifen, Schloss
##     green   Solar Cache    Holz und Rinde, Keimling auf dem Deckel, Pollen-Sonne
##     plant7  Mecha Cache    matt (kein Gluehen), Absperrband, rote Industriefarbe
##     hip     Hipstar Cache  Sticker und Pixel, Terminal vorn
##
## ``open`` hebt den Deckel ab (0..1, fuer die Oeffnen-Animation) und zeigt die
## leuchtende Oeffnung; ``locked`` zeichnet nur gestrichelte Umrisse, ``flat``
## nur den Umriss in einer Farbe. Seit 21. Nov. 2026 ist auch der Neon Cache
## wieder diese Zeichnung (der 3D-Shader passte nicht zum Stil).

## [Rahmen/Akzent, Deckel, Front, Seite, Kante, Fuge, Einlage]
const STYLE := {
	"city": [Color("#ff2a55"), Color("#2a2633"), Color("#423c52"), Color("#1a1820"),
		Color("#0a0618"), Color("#ff2a55"), Color("#423c52")],
	"green": [Color("#6fdc6a"), Color("#6b4e33"), Color("#8a6440"), Color("#4f3a26"),
		Color("#0f2a1c"), Color("#3f7a3a"), Color("#3f7a3a")],
	"plant7": [Color("#d4a017"), Color("#3a3a3d"), Color("#a3121c"), Color("#232325"),
		Color("#111113"), Color("#232325"), Color("#232325")],
	"hip": [Color("#3ad6e0"), Color("#3a1d5e"), Color("#2a1446"), Color("#1b0b3a"),
		Color("#0a0618"), Color("#ff2bd6"), Color("#3ad6e0")],
}

const RATIO := 0.85

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
## Nur der Umriss in einer Farbe (Glitch-Kanaele beim Oeffnen, CacheOpener).
var flat: Color = Color.TRANSPARENT:
	set(value):
		flat = value
		queue_redraw()

var _s := 1.0
var _o := Vector2.ZERO


func _init(cache_kind: String = "city", edge: float = 72.0) -> void:
	kind = cache_kind
	custom_minimum_size = Vector2(edge, edge * RATIO)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func color(cache_kind: String) -> Color:
	return (STYLE.get(cache_kind, STYLE["city"]) as Array)[0]


func _p(x: float, y: float) -> Vector2:
	return _o + Vector2(x, y) * _s


func _pts(coords: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, coords.size(), 2):
		out.append(_p(coords[i], coords[i + 1]))
	return out


func _draw() -> void:
	# Entwurfsraum 200 x 170.
	_s = minf(size.x / 200.0, size.y / 170.0)
	_o = Vector2((size.x - 200.0 * _s) * 0.5, (size.y - 170.0 * _s) * 0.5)
	var st: Array = STYLE.get(kind, STYLE["city"])
	var accent: Color = st[0]
	var w := maxf(1.2, 3.0 * _s)
	var lift := open * 52.0

	if flat.a > 0.0:
		draw_colored_polygon(_pts([20, 50, 60, 16, 140, 16, 180, 50, 180, 116, 140, 150,
			60, 150, 20, 116]), flat)
		return

	if locked:
		var dash := Arcade.EMPTY_LINE
		_dashed([20, 50, 60, 84, 140, 84, 180, 50, 140, 16, 60, 16], dash, w)
		_dashed([20, 50, 20, 116, 60, 150, 140, 150, 180, 116, 180, 50], dash, w)
		draw_line(_p(60, 84), _p(60, 150), dash, w * 0.7)
		draw_line(_p(140, 84), _p(140, 150), dash, w * 0.7)
		return

	# Schatten
	draw_colored_polygon(_pts([26, 130, 64, 162, 146, 162, 184, 130]), Color("#05000f"))
	# Seiten
	draw_colored_polygon(_pts([20, 50, 60, 84, 60, 150, 20, 116]), st[3])
	draw_colored_polygon(_pts([60, 84, 140, 84, 140, 150, 60, 150]), st[2])
	draw_colored_polygon(_pts([140, 84, 180, 50, 180, 116, 140, 150]), st[3])
	# Deckel-Fuge
	draw_polyline(_pts([20, 68, 60, 102, 140, 102, 180, 68]), st[5], w)
	_decor_body(accent)
	# Kanten
	for x in [60.0, 140.0]:
		draw_line(_p(x, 84), _p(x, 150), st[4], w)
	draw_line(_p(20, 50), _p(20, 116), st[4], w)
	draw_line(_p(180, 50), _p(180, 116), st[4], w)
	draw_polyline(_pts([20, 116, 60, 150, 140, 150, 180, 116]), st[4], w)

	if open > 0.01:
		# Oeffnung: dunkel, darin das Licht der Fraktion
		draw_colored_polygon(_pts([20, 50, 60, 16, 140, 16, 180, 50, 140, 84, 60, 84]), Color("#05000f"))
		draw_colored_polygon(_pts([44, 50, 72, 28, 128, 28, 156, 50, 128, 72, 72, 72]),
			Color(accent, 0.35 * open))
		draw_colored_polygon(_pts([70, 50, 86, 38, 114, 38, 130, 50, 114, 62, 86, 62]),
			Color(Color.WHITE.lerp(accent, 0.4), 0.5 * open))
		# Lichtsaeule
		draw_colored_polygon(_pts([72, 50, 86, 50 - 60 * open - lift, 114, 50 - 60 * open - lift, 128, 50]),
			Color(accent, 0.16 * open))
		draw_polyline(_close(_pts([20, 50, 60, 16, 140, 16, 180, 50, 140, 84, 60, 84])), accent, w)

	# Deckel (hebt sich mit ``open``)
	var lid_y := -lift
	draw_colored_polygon(_pts([20, 50 + lid_y, 60, 84 + lid_y, 60, 92 + lid_y, 20, 58 + lid_y]), st[3])
	draw_colored_polygon(_pts([60, 84 + lid_y, 140, 84 + lid_y, 140, 92 + lid_y, 60, 92 + lid_y]), st[2])
	draw_colored_polygon(_pts([140, 84 + lid_y, 180, 50 + lid_y, 180, 58 + lid_y, 140, 92 + lid_y]), st[3])
	var top := _pts([20, 50 + lid_y, 60, 16 + lid_y, 140, 16 + lid_y, 180, 50 + lid_y,
		140, 84 + lid_y, 60, 84 + lid_y])
	draw_colored_polygon(top, st[1])
	draw_polyline(_close(top), st[4], w)
	draw_polyline(_close(_pts([50, 50 + lid_y, 75, 30 + lid_y, 125, 30 + lid_y, 150, 50 + lid_y,
		125, 70 + lid_y, 75, 70 + lid_y])), st[6], w * 0.7)
	_decor_lid(accent, lid_y)


func _decor_body(accent: Color) -> void:
	var w := maxf(1.0, 3.0 * _s)
	match kind:
		"green":
			draw_arc(_p(100, 122), 14.0 * _s, 0.0, TAU, 24, Color("#fff27a"), w)
			draw_circle(_p(100, 122), 5.0 * _s, Color("#fff27a"))
			draw_polyline(_pts([24, 72, 30, 84, 30, 96, 26, 108]), Color("#ff6fae"), w)
			draw_polyline(_pts([176, 72, 170, 84, 170, 96, 174, 108]), Color("#ff6fae"), w)
		"plant7":
			draw_colored_polygon(_pts([60, 110, 140, 110, 140, 132, 60, 132]), Color("#d4a017"))
			for x in [66.0, 86.0, 106.0, 126.0]:
				draw_line(_p(x, 132), _p(x + 14, 110), Color("#232325"), 7.0 * _s)
			for pos in [[68, 96], [124, 96], [68, 142], [124, 142]]:
				draw_line(_p(pos[0], pos[1]), _p(pos[0] + 8, pos[1]), Color("#8a6a12"), 4.0 * _s)
		"hip":
			draw_rect(Rect2(_p(72, 108), Vector2(40, 24) * _s), Color("#3ad6e0"), false, w)
			draw_line(_p(78, 120), _p(86, 120), Color("#ff2bd6"), w)
			draw_line(_p(90, 120), _p(106, 120), Color("#ff2bd6"), w)
			draw_rect(Rect2(_p(118, 112), Vector2(8, 8) * _s), Color("#ff2bd6"))
			draw_rect(Rect2(_p(126, 120), Vector2(6, 6) * _s), Color("#3ad6e0"))
			draw_rect(Rect2(_p(150, 76), Vector2(10, 10) * _s), Color("#ff2bd6"))
			draw_rect(Rect2(_p(36, 92), Vector2(8, 8) * _s), Color("#3ad6e0"))
		_:
			draw_line(_p(68, 120), _p(132, 120), accent, 5.0 * _s)
			draw_line(_p(68, 130), _p(110, 130), Color("#ff9a3d"), w)
			draw_line(_p(28, 80), _p(28, 108), accent, w)
			draw_line(_p(172, 80), _p(172, 108), accent, w)


func _decor_lid(accent: Color, dy: float) -> void:
	var w := maxf(1.0, 3.0 * _s)
	match kind:
		"green":
			draw_colored_polygon(_pts([100, 46 + dy, 102, 30 + dy, 112, 22 + dy, 124, 16 + dy,
				120, 30 + dy, 110, 42 + dy]), Color("#3f7a3a"))
			draw_colored_polygon(_pts([100, 46 + dy, 96, 36 + dy, 88, 30 + dy, 78, 28 + dy,
				82, 38 + dy, 92, 45 + dy]), Color("#3f7a3a"))
		"plant7":
			draw_colored_polygon(_pts([84, 40 + dy, 116, 40 + dy, 120, 50 + dy, 116, 60 + dy,
				84, 60 + dy, 80, 50 + dy]), Color("#a3121c"))
		"hip":
			draw_line(_p(82, 50 + dy), _p(118, 50 + dy), Color("#3ad6e0"), w)
			draw_line(_p(100, 38 + dy), _p(100, 62 + dy), Color("#3ad6e0"), w)
			draw_line(_p(162, 20 + dy), _p(172, 14 + dy), Color("#ff2bd6"), w)
		_:
			draw_rect(Rect2(_p(88, 42 + dy), Vector2(24, 16) * _s), accent, false, w)
			draw_polyline(_pts([94, 42 + dy, 94, 36 + dy, 106, 36 + dy, 106, 42 + dy]), accent, w)


func _close(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out


func _dashed(coords: Array, line: Color, width: float) -> void:
	var pts := _close(_pts(coords))
	for i in pts.size() - 1:
		draw_dashed_line(pts[i], pts[i + 1], line, width * 0.7, 5.0)
