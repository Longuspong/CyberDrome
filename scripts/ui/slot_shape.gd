class_name SlotShape
extends Control

## Ein Halter -- oder ein Ausruestungsteil -- als Form.
##
##     Dreieck  = leicht      Viereck = mittel      Fuenfeck = schwer
##     Kreis    = Kern
##
## Mehr Ecken heisst mehr Platz. Dieselben Formen tragen die Halter am DROME
## und die Teile im Inventar: ein Teil passt in jeden Halter mit mindestens so
## vielen Ecken (leicht in alles, schwer nur in schwer). Man sieht es, bevor
## man es liest -- und unabhaengig von Farbe.

const LINE := Color(0.8, 0.86, 0.94)
const FILL := Color(0.12, 0.15, 0.21)
const FILL_EMPTY := Color(0.07, 0.09, 0.13)

## "light", "medium", "heavy" oder "core".
var shape: String = "light":
	set(value):
		shape = value
		queue_redraw()
## Bild darin (Teil im Halter / Teil selbst). Leer = freier Halter.
var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
var highlight: bool = false:
	set(value):
		highlight = value
		queue_redraw()
var dim: bool = false:
	set(value):
		dim = value
		queue_redraw()
var accent: Color = Color(0.38, 0.8, 0.98)


func _init(kind: String = "light", picture: Texture2D = null, edge: float = 56.0) -> void:
	shape = kind
	texture = picture
	custom_minimum_size = Vector2(edge, edge)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var points := polygon(shape, Rect2(Vector2.ZERO, size).grow(-3.0))
	var alpha := 0.45 if dim else 1.0
	draw_colored_polygon(points, Color(FILL if texture != null else FILL_EMPTY, alpha))
	if texture != null:
		# Das Bild bleibt IN der Form (Wunsch des Spielers, 10. Nov. 2026):
		# vorher ragte ein Blaster ueber die Kanten seines Dreiecks.
		var tex_size := texture.get_size()
		var inner := inner_rect(points, tex_size.x / maxf(1.0, tex_size.y))
		draw_texture_rect(texture, inner, false, Color(1, 1, 1, alpha))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(accent if highlight else LINE, alpha),
		3.0 if highlight else 2.0, true)


## Wie viel Luft zwischen Bild und Rand der Form bleibt (Anteil des Bildes).
const PICTURE_MARGIN := 0.06


## Das groesste Rechteck mit dem Seitenverhaeltnis ``aspect`` (Breite/Hoehe),
## das ganz in der Form liegt -- waagerecht mittig, in der Hoehe dort, wo am
## meisten Platz ist (im Dreieck unten, im Fuenfeck knapp unter der Mitte).
## Danach um PICTURE_MARGIN verkleinert.
static func inner_rect(points: PackedVector2Array, aspect: float) -> Rect2:
	var top := INF
	var bottom := -INF
	var left := INF
	var right := -INF
	for point in points:
		top = minf(top, point.y)
		bottom = maxf(bottom, point.y)
		left = minf(left, point.x)
		right = maxf(right, point.x)
	var middle := (left + right) * 0.5
	aspect = maxf(0.05, aspect)
	var best := Rect2(Vector2(middle, (top + bottom) * 0.5), Vector2.ZERO)
	for step in 25:
		var center_y := lerpf(top, bottom, float(step) / 24.0)
		var low := 0.0
		var high := (right - left) * 0.5
		for _i in 14:
			var half_w := (low + high) * 0.5
			if _rect_inside(points, middle, center_y, half_w, half_w / aspect):
				low = half_w
			else:
				high = half_w
		if low * 2.0 > best.size.x:
			best = Rect2(middle - low, center_y - low / aspect, low * 2.0, low * 2.0 / aspect)
	# Um die Mitte verkleinern -- beide Seiten im selben Verhaeltnis, sonst
	# wuerde das Bild verzerrt.
	var shrunk := best.size * (1.0 - PICTURE_MARGIN)
	return Rect2(best.get_center() - shrunk * 0.5, shrunk)


static func _rect_inside(points: PackedVector2Array, cx: float, cy: float, half_w: float,
		half_h: float) -> bool:
	for corner in [Vector2(-half_w, -half_h), Vector2(half_w, -half_h),
			Vector2(half_w, half_h), Vector2(-half_w, half_h)]:
		if not Geometry2D.is_point_in_polygon(Vector2(cx, cy) + corner, points):
			return false
	return true


## Die Eckpunkte einer Form in einem Rechteck. Statisch, damit auch andere
## Zeichner (Kampf, Kulisse) dieselben Formen nehmen koennen. Jede Form fuellt
## ihr Rechteck aus (ein regelmaessiges Dreieck liesse oben und an den Seiten
## Platz liegen, den das Bild darin braucht).
static func polygon(kind: String, rect: Rect2) -> PackedVector2Array:
	var center := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.5
	var corners := 3
	match kind:
		"medium":
			# Ein Quadrat, auf der Kante stehend -- als Viereck erkennbar,
			# nicht als Raute.
			return PackedVector2Array([
				center + Vector2(-radius, -radius) * 0.9,
				center + Vector2(radius, -radius) * 0.9,
				center + Vector2(radius, radius) * 0.9,
				center + Vector2(-radius, radius) * 0.9,
			])
		"heavy":
			corners = 5
		"core":
			corners = 28
	var points := PackedVector2Array()
	for i in corners:
		var angle := -PI * 0.5 + TAU * float(i) / float(corners)
		points.append(Vector2(cos(angle), sin(angle)))
	# Auf das Rechteck strecken: Spitze oben, Grundlinie unten, volle Breite.
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point in points:
		low = low.min(point)
		high = high.max(point)
	var square := Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	for i in points.size():
		var unit := (points[i] - low) / (high - low)
		points[i] = square.position + unit * square.size
	return points
