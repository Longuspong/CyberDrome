class_name StoryDialog
extends Control

## Story-Dialog (Entwurf 15. Nov. 2026, docs/design/einsatz_arcade Bilder 07/08):
## legt sich ueber den Bildschirm, der Hintergrund dunkelt ab. Unten ein
## Kasten mit dem Text, der Buchstabe fuer Buchstabe erscheint; darueber das
## Bild des Sprechers mit Namensschild -- links oder rechts, je Zeile.
##
##   Antippen       zeigt den Rest der Zeile, dann die naechste
##   UEBERSPRINGEN  beendet den Dialog sofort
##
## Noch ohne Story-Einsaetze: der Baustein ist da, angebunden wird er mit den
## Story-Leveln (STORY_LEITFADEN.md). Eine Zeile:
##   {"name": "Kage-9", "faction": "Neon Ninja's", "text": "...",
##    "side": "left"|"right", "color": Color, "look": "ninja"|"bot"|"sprout"}

signal finished

const CHARS_PER_SECOND := 42.0

var _lines: Array = []
var _index := 0
var _shown := 0.0
var _text: Label
var _more: Label
var _portrait: Control
var _name_box: VBoxContainer
var _progress: HBoxContainer
var _card: PanelContainer
var _box: VBoxContainer


## Spielt ``lines`` ueber ``host`` ab. Ohne Zeilen passiert nichts.
static func play(host: Control, lines: Array) -> StoryDialog:
	var dialog := StoryDialog.new()
	dialog._lines = lines
	host.add_child(dialog)
	return dialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _lines.is_empty():
		_finish.call_deferred()
		return
	var shade := ColorRect.new()
	shade.color = Color(Arcade.NIGHT, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, UiKit.PAD)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 36)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 0)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_box)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(top)
	var hint := Arcade.label("ANTIPPEN · WEITER", 12, Arcade.MUTED, "bold", 0.2)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(hint)
	var skip := UiKit.outline_button("Überspringen ⏩", Arcade.YELLOW)
	skip.custom_minimum_size = Vector2(0, 44)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip.add_theme_font_override("font", Arcade.font("bold", 13, 0.16))
	skip.add_theme_font_size_override("font_size", 13)
	skip.pressed.connect(_finish)
	top.add_child(skip)

	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	push.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(push)

	# Sprecher: Bild mit Namensschild, links oder rechts ueber dem Kasten.
	var speaker := HBoxContainer.new()
	speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(speaker)
	var speaker_col := VBoxContainer.new()
	speaker_col.add_theme_constant_override("separation", -10)
	speaker_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker.add_child(speaker_col)
	_portrait = Portrait.new()
	speaker_col.add_child(_portrait)
	_name_box = VBoxContainer.new()
	_name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker_col.add_child(_name_box)
	speaker.set_meta("col", speaker_col)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(0, 190)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(column)
	_text = UiKit.label("", 17, Arcade.WHITE)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_text)
	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bottom)
	_progress = HBoxContainer.new()
	_progress.add_theme_constant_override("separation", 4)
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_progress)
	_more = Arcade.label("▼", 14, Arcade.YELLOW, "bold")
	bottom.add_child(_more)
	_show_line()


func _line() -> Dictionary:
	return _lines[_index]


## Baut Sprecher, Farben und Fortschritt fuer die aktuelle Zeile.
func _show_line() -> void:
	var line := _line()
	var color: Color = line.get("color", Arcade.MAGENTA)
	var right := str(line.get("side", "left")) == "right"
	var speaker := _portrait.get_parent().get_parent() as HBoxContainer
	speaker.alignment = BoxContainer.ALIGNMENT_END if right else BoxContainer.ALIGNMENT_BEGIN
	(_portrait as Portrait).setup(color, str(line.get("look", "ninja")))
	for child in _name_box.get_children():
		child.queue_free()
	var plate := PanelContainer.new()
	var plate_box := StyleBoxFlat.new()
	plate_box.bg_color = Arcade.NIGHT
	plate_box.border_color = color
	plate_box.set_border_width_all(2)
	plate_box.set_content_margin_all(6)
	plate.add_theme_stylebox_override("panel", plate_box)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	plate.add_child(names)
	names.add_child(Arcade.label(str(line.get("name", "")).to_upper(), 17, color, "display"))
	names.add_child(Arcade.label(str(line.get("faction", "")).to_upper(), 10, Arcade.TEXT, "bold", 0.14))
	var tilted := Arcade.tilt(plate, -3.0 if not right else 3.0)
	tilted.size_flags_horizontal = Control.SIZE_SHRINK_END if right else Control.SIZE_SHRINK_BEGIN
	_name_box.add_child(tilted)
	var card_box := StyleBoxFlat.new()
	card_box.bg_color = Color(Arcade.VIOLET, 0.97)
	card_box.border_color = color
	card_box.set_border_width_all(2)
	card_box.set_content_margin_all(18)
	_card.add_theme_stylebox_override("panel", card_box)
	for child in _progress.get_children():
		child.queue_free()
	for k in _lines.size():
		var dash := ColorRect.new()
		dash.custom_minimum_size = Vector2(14, 3)
		dash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dash.color = color if k == _index else Color("#3a1a6e")
		_progress.add_child(dash)
	_shown = 0.0 if Arcade.moving() else 9999.0
	_render()


func _process(delta: float) -> void:
	if _lines.is_empty() or _text == null:
		return
	var full := str(_line().get("text", "")).length()
	if _shown < full:
		_shown += delta * CHARS_PER_SECOND
		_render()
	_more.visible = _shown >= full and fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.4


func _render() -> void:
	var text := str(_line().get("text", ""))
	_text.text = text.substr(0, int(_shown)) + ("_" if int(_shown) < text.length() else "")


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	accept_event()
	Accessibility.tap()
	var full := str(_line().get("text", "")).length()
	if _shown < full:
		_shown = full
		_render()
		return
	_index += 1
	if _index >= _lines.size():
		_finish()
	else:
		_show_line()


func _finish() -> void:
	if is_queued_for_deletion():
		return
	finished.emit()
	queue_free()


## Das Bild des Sprechers: ein gezeichneter Kopf mit Schultern in der Farbe
## der Fraktion ("ninja" Maske mit Augenschlitz, "sprout" runder Kopf mit
## Blatt, sonst ein Bot-Kopf).
class Portrait extends Control:
	var _color := Arcade.MAGENTA
	var _look := "ninja"

	func _init() -> void:
		custom_minimum_size = Vector2(170, 200)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(color: Color, look: String) -> void:
		_color = color
		_look = look
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var frame := Rect2(0, 0, w, h)
		draw_rect(frame, Color(Arcade.NIGHT, 0.95))
		draw_rect(frame, _color, false, 2.0)
		var c := Vector2(w * 0.5, h * 0.42)
		# Schultern
		var shoulders := PackedVector2Array()
		for i in 17:
			var a := PI + PI * float(i) / 16.0
			shoulders.append(Vector2(w * 0.5 + cos(a) * w * 0.42, h + sin(a) * h * 0.3))
		draw_colored_polygon(shoulders, Color(_color, 0.18))
		shoulders.append(shoulders[0])
		draw_polyline(shoulders, _color, 3.0, true)
		match _look:
			"sprout":
				draw_circle(c, w * 0.22, Color("#0f2a1c"))
				draw_arc(c, w * 0.22, 0, TAU, 32, _color, 3.0, true)
				draw_arc(c, w * 0.3, 0, TAU, 40, Color(Arcade.YELLOW, 0.8), 2.0, true)
				draw_circle(c + Vector2(-12, -2), 5, Arcade.YELLOW)
				draw_circle(c + Vector2(12, -2), 5, Arcade.YELLOW)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -w * 0.22),
					c + Vector2(-24, -w * 0.3), c + Vector2(-4, -w * 0.25)]), _color)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -w * 0.22),
					c + Vector2(24, -w * 0.3), c + Vector2(4, -w * 0.25)]), _color)
			"bot":
				var head := Rect2(c - Vector2(w * 0.22, w * 0.2), Vector2(w * 0.44, w * 0.4))
				draw_rect(head, Color(Arcade.NIGHT, 1.0))
				draw_rect(head, _color, false, 3.0)
				draw_rect(Rect2(c + Vector2(-w * 0.15, -6), Vector2(w * 0.3, 10)), Arcade.YELLOW)
			_:
				var mask := PackedVector2Array()
				for i in 25:
					var a := PI + PI * float(i) / 24.0
					mask.append(c + Vector2(cos(a) * w * 0.24, sin(a) * w * 0.3))
				mask.append(c + Vector2(w * 0.24, w * 0.22))
				mask.append(c + Vector2(-w * 0.24, w * 0.22))
				draw_colored_polygon(mask, Color(_color, 0.85))
				draw_rect(Rect2(c + Vector2(-w * 0.2, -8), Vector2(w * 0.4, 14)), Arcade.NIGHT)
				draw_rect(Rect2(c + Vector2(-w * 0.15, -4), Vector2(w * 0.1, 5)), Arcade.WHITE)
				draw_rect(Rect2(c + Vector2(w * 0.05, -4), Vector2(w * 0.1, 5)), Arcade.WHITE)
