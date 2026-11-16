class_name Tile
extends PanelContainer

## Eine Kachel (14. Nov. 2026, Wunsch des Spielers): Bild und Kurzname statt
## langer Karten mit Erklaerung. Die Erklaerung kommt als Popup.
##
## Bedienung seit 15. Nov. 2026 (Wunsch des Spielers):
##
##   tippen               waehlt die Kachel aus (sichtbar markiert, on_select)
##   tippen auf gewaehlte  on_info -- das Popup mit allen Details
##   doppelt tippen       on_action -- ausruesten, kaufen, einsetzen ...
##   lange druecken       on_info
##
## Ohne on_action oeffnet schon der Tipp auf die gewaehlte Kachel sofort das
## Popup; mit on_action wartet er DOUBLE_MS, ob ein zweiter Tipp folgt.
##
## Auswahl und Doppeltipp merken sich die Kachel ueber ``key`` statisch: die
## meisten Bildschirme bauen sich nach dem ersten Tipp neu auf, die zweite
## Beruehrung trifft dann eine neue Kachel mit demselben Schluessel. Wer die
## Auswahl selbst fuehrt (Lager: gewaehltes Modul), setzt ``managed`` und
## ``selected``; sonst merkt sich Tile die zuletzt gewaehlte Kachel selbst.

signal tapped
signal info

const DOUBLE_MS := 320
const LONG_PRESS := 0.45
const SLOP := 14.0

static var _last_key := ""
static var _last_ms := -10000
## Die selbst gefuehrte Auswahl (Kacheln ohne ``managed``).
static var _chosen_key := ""
## Laufendes verzoegertes Popup -- ein zweiter Tipp bricht es ab.
static var _info_serial := 0

const GROUP := "cyberdrome_tiles"
const DRAG_GROUP := "cyberdrome_drag_source"

var key: String = ""
## Alter Name fuer on_select (bleibt, damit bestehende Aufrufer laufen).
var on_tap: Callable
var on_select: Callable
var on_info: Callable
var on_action: Callable
## Ziehen und Ablegen (16. Nov. 2026, Zwischenstopp): ``on_drag`` liefert
## die Zugdaten (und setzt selbst die Vorschau), ``can_drop``(daten) -> bool
## und ``on_drop``(daten) machen die Kachel zum Ziel. Eine Kachel mit
## ``on_drag`` steht in der Gruppe DRAG_GROUP -- dort scrollt ein Wischer
## nicht (Accessibility), er zieht.
var on_drag: Callable
var can_drop: Callable
var on_drop: Callable
## Die Auswahl fuehrt der Bildschirm (``selected``), nicht Tile selbst.
var managed: bool = false
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


## Ist die Kachel gewaehlt -- vom Bildschirm gesetzt oder selbst gemerkt?
func is_chosen() -> bool:
	return selected if managed else (selected or (key != "" and key == _chosen_key))


func _enter_tree() -> void:
	add_to_group(GROUP)
	if on_drag.is_valid():
		add_to_group(DRAG_GROUP)


func _get_drag_data(_at: Vector2) -> Variant:
	if not on_drag.is_valid():
		return null
	# Ein laufender Zug ist kein langes Druecken und kein Tipp mehr.
	_pressing = false
	_long_fired = true
	_info_serial += 1
	return on_drag.call()


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return can_drop.is_valid() and bool(can_drop.call(data))


func _drop_data(_at: Vector2, data: Variant) -> void:
	if on_drop.is_valid():
		on_drop.call(data)


## Wird nach einer selbst gefuehrten Auswahl an alle Kacheln geschickt.
func refresh_choice() -> void:
	_restyle()


static func clear_choice() -> void:
	_chosen_key = ""


func _restyle() -> void:
	if _box == null:
		return
	var chosen := is_chosen()
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
		style.border_color = (UiKit.PRIMARY if chosen else (accent if glow else UiKit.CARD_LINE))
		style.set_border_width_all(3 if chosen else 2)
		style.shadow_size = 1
		style.shadow_offset = Vector2(4, 4)
		style.shadow_color = Color(UiKit.MAGENTA, 0.7) if chosen else (
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
	var select := func():
		if not managed:
			_chosen_key = key
			get_tree().call_group(GROUP, "refresh_choice")
		var picked := on_select if on_select.is_valid() else on_tap
		if picked.is_valid():
			picked.call()
		tapped.emit()
	Tile.click(get_tree(), key, is_chosen(), select, _fire_info, on_action)


## Die Tipp-Regel fuer alles, was wie eine Kachel bedient wird, aber anders
## aussieht (Halter im Umbau): ``chosen`` sagt, ob schon gewaehlt; sonst
## waehlt der Tipp (``select``). Auf gewaehlt: ``show`` (Details) -- mit
## ``action`` erst nach DOUBLE_MS, denn ein Doppeltipp loest ``action`` aus.
static func click(tree: SceneTree, tap_key: String, chosen: bool, select: Callable,
		show: Callable, action: Callable) -> void:
	var now := Time.get_ticks_msec()
	var double := tap_key != "" and _last_key == tap_key and now - _last_ms < DOUBLE_MS
	_last_key = "" if double else tap_key
	_last_ms = now
	Accessibility.tap()
	if double and action.is_valid():
		_info_serial += 1        # ein wartendes Popup faellt weg
		Accessibility.vibrate(20)
		action.call()
		return
	if not chosen:
		if select.is_valid():
			select.call()
		return
	# Schon gewaehlt: Details. Mit Doppeltipp-Handlung kurz warten.
	if not action.is_valid():
		_last_key = ""
		if show.is_valid():
			show.call()
		return
	_info_serial += 1
	var serial := _info_serial
	tree.create_timer(DOUBLE_MS / 1000.0).timeout.connect(func():
		if serial == _info_serial and show.is_valid():
			_last_key = ""
			show.call())


func _fire_info() -> void:
	_last_key = ""
	Accessibility.vibrate(15)
	if on_info.is_valid():
		on_info.call()
	info.emit()
