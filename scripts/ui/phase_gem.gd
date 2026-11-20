class_name PhaseGem
extends Control

## Eine Energy Phase als geschliffener Hex-Kristall (Design-Canvas 20. Nov.
## 2026, Blatt "Energy Phases"): Rand in der Farbe des Elements, dunkler Grund
## mit heller Facette, Symbol aus assets/ui_icons/phase_<element>.svg.
## ``element`` "" zeichnet ein leeres, gestricheltes Feld mit Plus.

var element: String = "":
	set(value):
		element = value
		_sync_icon()
		queue_redraw()
## Hervorgehoben (gewaehlt, Ziehziel): heller Rand.
var highlight: bool = false:
	set(value):
		highlight = value
		queue_redraw()

var _icon: TextureRect


func _init(phase: String = "", edge: float = 80.0) -> void:
	custom_minimum_size = Vector2(edge, edge * 0.866)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	element = phase


func _ready() -> void:
	_sync_icon()


func _sync_icon() -> void:
	if not is_inside_tree() and _icon == null and element == "":
		return
	if _icon == null:
		_icon = TextureRect.new()
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon.set_anchors_preset(Control.PRESET_CENTER)
		add_child(_icon)
	_icon.visible = element != ""
	if element != "":
		_icon.texture = UiIcon.texture("phase_" + element)
		_icon.modulate = Charger.element_color(element)
	_place_icon()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place_icon()


func _place_icon() -> void:
	if _icon == null:
		return
	var edge := minf(size.x, size.y / 0.866) * 0.44
	if edge <= 0.0:
		edge = custom_minimum_size.x * 0.44
	_icon.size = Vector2(edge, edge)
	_icon.position = (size - _icon.size) * 0.5 if size != Vector2.ZERO \
		else (custom_minimum_size - _icon.size) * 0.5


static func hex(center: Vector2, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(-w * 0.25, -h * 0.5), center + Vector2(w * 0.25, -h * 0.5),
		center + Vector2(w * 0.5, 0), center + Vector2(w * 0.25, h * 0.5),
		center + Vector2(-w * 0.25, h * 0.5), center + Vector2(-w * 0.5, 0)])


func _draw() -> void:
	var w := minf(size.x, size.y / 0.866)
	var h := w * 0.866
	var c := size * 0.5
	if element == "":
		var pts := hex(c, w - 3.0, h - 3.0)
		draw_colored_polygon(pts, Color(Arcade.NIGHT, 0.6))
		pts.append(pts[0])
		var line := Arcade.CYAN if highlight else Arcade.EMPTY_LINE
		for i in 6:
			draw_dashed_line(pts[i], pts[i + 1], line, 2.0, 5.0)
		var plus := w * 0.1
		draw_line(c - Vector2(plus, 0), c + Vector2(plus, 0), Color("#8f80bd"), 2.0)
		draw_line(c - Vector2(0, plus), c + Vector2(0, plus), Color("#8f80bd"), 2.0)
		return
	var col := Charger.element_color(element)
	# harter Schatten
	draw_colored_polygon(hex(c + Vector2(3, 3), w, h), Color("#2a0f55"))
	draw_colored_polygon(hex(c, w, h), Color.WHITE if highlight else col)
	var inner := hex(c, w - 6.0, h - 6.0)
	draw_colored_polygon(inner, col.darkened(0.86))
	# Facette oben
	draw_colored_polygon(PackedVector2Array([inner[0], inner[1], inner[2], inner[5]]), Color(col, 0.14))
	draw_line(c + Vector2(-w * 0.22, -h * 0.38), c + Vector2(w * 0.02, -h * 0.38), Color(col, 0.55), 2.0)
