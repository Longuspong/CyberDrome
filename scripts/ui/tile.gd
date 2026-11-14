class_name Tile
extends PanelContainer

## Eine Kachel (14. Nov. 2026, Wunsch des Spielers): Bild und Kurzname statt
## langer Karten mit Erklaerung. Die Erklaerung kommt als Popup.
##
##   einmal tippen        on_tap (Auswahl, Handlung); ohne on_tap das Popup
##   doppelt tippen       on_info (Popup mit allem, was man wissen muss)
##   lange druecken       on_info
##
## Der Doppeltipp merkt sich die Kachel ueber ``key`` statisch: die meisten
## Bildschirme bauen sich nach dem ersten Tipp neu auf, die zweite Beruehrung
## trifft dann eine neue Kachel mit demselben Schluessel.

signal tapped
signal info

const DOUBLE_MS := 320
const LONG_PRESS := 0.45
const SLOP := 14.0

static var _last_key := ""
static var _last_ms := -10000

var key: String = ""
var on_tap: Callable
var on_info: Callable
var selected: bool = false:
	set(value):
		selected = value
		_restyle()
var glow: bool = false:
	set(value):
		glow = value
		_restyle()
var dimmed: bool = false:
	set(value):
		dimmed = value
		_restyle()
var accent: Color = UiKit.ACCENT:
	set(value):
		accent = value
		_restyle()
## Leerer Platz (gestrichelt, ohne Schatten).
var empty: bool = false:
	set(value):
		empty = value
		_restyle()

var _box: VBoxContainer
var _press_at := Vector2.ZERO
var _pressing := false
var _long_fired := false
var _press_serial := 0


func _init(tile_key: String = "", picture: Control = null, title: String = "",
		edge: Vector2 = Vector2(88, 88)) -> void:
	key = tile_key
	custom_minimum_size = edge
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 2)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	if picture != null:
		add_picture(picture)
	if title != "":
		add_caption(title)
	_restyle()


## Bild mittig in die Kachel.
func add_picture(picture: Control) -> void:
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_quiet(picture)
	_box.add_child(picture)


## Kurzname unter dem Bild (eine Zeile, gekuerzt).
func add_caption(text: String, color: Color = UiKit.TEXT, font_size: int = 12) -> Label:
	var name := Label.new()
	name.text = text
	name.add_theme_font_size_override("font_size", font_size)
	name.add_theme_color_override("font_color", color)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(name)
	return name


## Beliebiges Element unten in der Kachel (Preis, Punkte ...).
func add_extra(control: Control) -> void:
	_quiet(control)
	_box.add_child(control)


static func _quiet(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_quiet(child)


func _restyle() -> void:
	if _box == null:
		return
	var style := StyleBoxFlat.new()
	style.corner_detail = 1
	style.corner_radius_top_left = 10
	style.corner_radius_bottom_right = 10
	style.anti_aliasing = true
	style.set_content_margin_all(4)
	if empty:
		style.bg_color = Color(UiKit.BG, 0.55)
		style.border_color = Color(Arcade.EMPTY_LINE, 0.7)
		style.set_border_width_all(1)
	else:
		style.bg_color = Color(UiKit.CARD, 0.94)
		style.border_color = accent if (selected or glow) else UiKit.CARD_LINE
		style.set_border_width_all(3 if selected else 2)
		style.shadow_size = 0
		style.shadow_offset = Vector2(4, 4)
		style.shadow_color = Color(UiKit.MAGENTA, 0.7) if selected else (
			Color(accent, 0.35) if glow else Color(0, 0, 0, 0.4))
	add_theme_stylebox_override("panel", style)
	modulate = Color(1, 1, 1, 0.45) if dimmed else Color.WHITE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_long_fired = false
			_press_at = event.global_position
			_press_serial += 1
			var serial := _press_serial
			get_tree().create_timer(LONG_PRESS).timeout.connect(func():
				if is_instance_valid(self) and _pressing and serial == _press_serial \
						and not get_viewport().gui_is_dragging() \
						and not Accessibility.is_scrolling():
					_long_fired = true
					_pressing = false
					_fire_info())
			accept_event()
		elif _pressing:
			_pressing = false
			accept_event()
			if _long_fired or event.global_position.distance_to(_press_at) > SLOP:
				return
			_on_click()
	elif event is InputEventMouseMotion and _pressing:
		if event.global_position.distance_to(_press_at) > SLOP:
			_pressing = false
	elif event.is_action_pressed("ui_accept"):
		accept_event()
		_on_click()


func _on_click() -> void:
	var now := Time.get_ticks_msec()
	var double := key != "" and _last_key == key and now - _last_ms < DOUBLE_MS
	_last_key = "" if double else key
	_last_ms = now
	Accessibility.tap()
	if double and on_info.is_valid():
		_fire_info()
		return
	if on_tap.is_valid():
		on_tap.call()
		tapped.emit()
	elif on_info.is_valid():
		_fire_info()


func _fire_info() -> void:
	_last_key = ""
	Accessibility.vibrate(15)
	if on_info.is_valid():
		on_info.call()
	info.emit()
