class_name ModuleChip
extends Control

## Ein Modul als Kartusche (Entwurf "Zwischenstopp Neu", 18. Nov. 2026):
## abgeschraegt wie die Knoepfe (Ecke oben links und unten rechts), Rahmen in
## der Farbe der Klasse (rot Angriff, blau Abwehr, gelb Taktik, violett BIOS),
## oben rechts eine Klassen-Ecke mit dem Klassenzeichen -- damit man die
## Klasse nicht nur an der Farbe erkennt -- und in der Mitte gross das Symbol
## aus assets/modules/<id>.svg (ohne Symbol: zwei Buchstaben, Schnellfeuer =
## SF). Rezept-Module haben einen doppelten Rahmen. Ruhende Module (Bedingung
## passt nicht zur Waffe) sind abgeblendet.
##
## Die Kartusche ist ueberall gleich gross (52 px im Laden, im Lager und in
## der Waffe); andere Groessen nur fuer Popups und Vorschauen.

## Grund der Kartusche (vorher graublau, passte nicht zum Violett der Karten).
const FILL := Color("#1a0b36")

var module: ModuleData
var dim: bool = false:
	set(value):
		dim = value
		queue_redraw()
var edge: float = 52.0


func _init(which: ModuleData = null, size_edge: float = 52.0) -> void:
	module = which
	edge = size_edge
	custom_minimum_size = Vector2(size_edge, size_edge)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Umriss der Kartusche in ``r``: Ecke ``cut`` oben links und unten rechts ab.
static func outline(r: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		r.position + Vector2(cut, 0), Vector2(r.end.x, r.position.y),
		r.end - Vector2(0, cut), r.end - Vector2(cut, 0),
		Vector2(r.position.x, r.end.y), r.position + Vector2(0, cut)])


func _draw() -> void:
	if module == null:
		return
	var color := module.color()
	if dim:
		color = color.darkened(0.55)
	var side := minf(size.x, size.y)
	var body := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	var line := maxf(1.5, side / 26.0)
	var cut := side * 0.19
	var shape := outline(body.grow(-line * 0.5), cut)
	draw_colored_polygon(shape, FILL if not dim else FILL.darkened(0.3))
	var closed := shape.duplicate()
	closed.append(shape[0])
	draw_polyline(closed, color, line, true)
	if module.is_recipe() or module.is_bios_result:
		var inner := outline(body.grow(-side * 0.11), cut * 0.7)
		inner.append(inner[0])
		draw_polyline(inner, color, maxf(1.0, line * 0.7), true)

	# Klassen-Ecke oben rechts: Feld in der Klassenfarbe, darin das Zeichen.
	var tab := side * 0.29
	var corner := Rect2(Vector2(body.end.x - tab, body.position.y), Vector2(tab, tab))
	draw_rect(corner, color, true)
	var klass := UiIcon.texture("bios" if module.klass == "bios" else "class_" + module.klass)
	if klass != null:
		draw_texture_rect(klass, corner.grow(-tab * 0.18), false, UiKit.BG)

	# Symbol gross in der Mitte.
	var art := Rect2(body.get_center() - Vector2(side, side) * 0.31, Vector2(side, side) * 0.62)
	var picture := module.icon()
	if picture != null:
		draw_texture_rect(picture, art, false, Color(1, 1, 1, 0.4) if dim else Color.WHITE)
		return
	var font := get_theme_default_font()
	var font_size := int(maxf(11.0, side * 0.3))
	var text := module.short_name()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var base := Vector2(body.get_center().x - width * 0.5, body.get_center().y + font_size * 0.36)
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		Color(1, 1, 1, 0.5 if dim else 1.0))
