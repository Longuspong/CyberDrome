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
		var inner := Rect2(Vector2.ZERO, size).grow(-size.x * 0.2)
		var tex_size := texture.get_size()
		var fit := minf(inner.size.x / tex_size.x, inner.size.y / tex_size.y)
		var draw_size := tex_size * fit
		draw_texture_rect(texture, Rect2(inner.get_center() - draw_size * 0.5, draw_size),
			false, Color(1, 1, 1, alpha))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(accent if highlight else LINE, alpha),
		3.0 if highlight else 2.0, true)


## Die Eckpunkte einer Form in einem Rechteck. Statisch, damit auch andere
## Zeichner (Kampf, Kulisse) dieselben Formen nehmen koennen.
static func polygon(kind: String, rect: Rect2) -> PackedVector2Array:
	var center := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.5
	var corners := 3
	match kind:
		"medium":
			# Ein Quadrat, auf der Kante stehend -- als Viereck erkennbar,
			# nicht als Raute.
			return PackedVector2Array([
				center + Vector2(-radius, -radius) * 0.82,
				center + Vector2(radius, -radius) * 0.82,
				center + Vector2(radius, radius) * 0.82,
				center + Vector2(-radius, radius) * 0.82,
			])
		"heavy":
			corners = 5
		"core":
			corners = 28
	var points := PackedVector2Array()
	# Spitze nach oben; das Dreieck sitzt etwas tiefer, damit es optisch mittig ist.
	var shift := Vector2(0, radius * 0.12) if corners == 3 else Vector2.ZERO
	for i in corners:
		var angle := -PI * 0.5 + TAU * float(i) / float(corners)
		points.append(center + shift + Vector2(cos(angle), sin(angle)) * radius)
	return points
