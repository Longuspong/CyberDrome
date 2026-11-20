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
## Seit 20. Nov. 2026 (Amps, Design-Canvas): Fusion = Rahmen geteilt in die
## Farben ihrer zwei Amps, innen ein heller zweiter Rahmen; Hyperfusion =
## dreifacher Rahmen und Fusion-Core-Sechseck; BIOS-Fusion = violetter
## Matrix-Code laeuft auf der Flaeche herunter (steht bei "Bewegung reduzieren").
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
var _time := 0.0
const RAIN := "10B7F01SI0S1BF7"


func _init(which: ModuleData = null, size_edge: float = 52.0) -> void:
	module = which
	edge = size_edge
	custom_minimum_size = Vector2(size_edge, size_edge)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_process(module != null and module.is_bios_result and Arcade.moving())


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


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
	if module.is_bios_result:
		_draw_rain(body, side)
	var closed := shape.duplicate()
	closed.append(shape[0])
	var parts := module.from
	if module.is_recipe() and not module.is_hyper and parts.size() == 2 \
			and ModuleData.get_module(parts[0]) != null and ModuleData.get_module(parts[1]) != null:
		# Fusion: Rahmen geteilt in die Farben der zwei Amps (Diagonale).
		var a := ModuleData.get_module(parts[0]).color()
		var b := ModuleData.get_module(parts[1]).color()
		if dim:
			a = a.darkened(0.55)
			b = b.darkened(0.55)
		draw_polyline(PackedVector2Array([closed[4], closed[5], closed[0], closed[1]]), a, line, true)
		draw_polyline(PackedVector2Array([closed[1], closed[2], closed[3], closed[4]]), b, line, true)
	else:
		draw_polyline(closed, color, line, true)
	if module.is_recipe() or module.is_bios_result:
		var inner := outline(body.grow(-side * 0.11), cut * 0.7)
		inner.append(inner[0])
		var inner_color := Arcade.WHITE if module.is_recipe() and not module.is_hyper else color
		draw_polyline(inner, inner_color if not dim else inner_color.darkened(0.55), maxf(1.0, line * 0.7), true)
	if module.is_hyper:
		var third := outline(body.grow(-side * 0.2), cut * 0.45)
		third.append(third[0])
		draw_polyline(third, color, maxf(1.0, line * 0.7), true)
		var hex := PackedVector2Array()
		var c := body.position + Vector2(side * 0.2, side * 0.8)
		for i in 6:
			var ang := TAU * float(i) / 6.0
			hex.append(c + Vector2(cos(ang), sin(ang)) * side * 0.11)
		draw_colored_polygon(hex, Color("#ff2bd6"))

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


## BIOS-Fusion: Spalten violetter Zeichen laufen herunter (Design-Canvas Amps).
func _draw_rain(body: Rect2, side: float) -> void:
	var font := get_theme_default_font()
	var px := int(maxf(6.0, side * 0.14))
	var cols := 5
	var violet := Color("#c78cff")
	for col in cols:
		var x := body.position.x + side * 0.12 + float(col) * (side * 0.76 / float(cols - 1)) - px * 0.3
		var speed := 18.0 + float((col * 7) % 5) * 6.0
		var shift := fmod(_time * speed + float(col) * 11.0, float(px))
		for row in int(side / px) + 1:
			var y := body.position.y + float(row) * px + shift
			if y > body.end.y - 2.0 or y < body.position.y + px:
				continue
			var ch := RAIN[(row + col * 3 + int(_time * speed / px)) % RAIN.length()]
			draw_string(font, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px,
				Color(violet, 0.35 if col % 2 == 0 else 0.22))
