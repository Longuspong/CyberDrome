extends Node

## Barrierefreiheit: Lesbarkeit, Bedienbarkeit, Bewegung -- an EINER Stelle.
##
## ### Warum eine automatische Skalierung
##
## Das Spiel ist auf einen Entwurfsraum von 1600x900 ausgelegt. Auf einem
## Handy (Querformat etwa 2400x1080 Bildpunkte bei Pixeldichte ~2,6) bleibt
## davon ein Massstab von ~0,46 CSS-Pixel je Entwurfspixel: eine 12er Schrift
## wird 5,5 Punkte hoch. Das ist nicht klein, das ist unlesbar.
##
## Deshalb rechnet ``_apply_scale()`` den ``content_scale_factor`` so aus, dass
## ein Entwurfspixel mindestens ``TARGET_CSS_PER_DESIGN`` CSS-Pixel gross wird
## -- aber nur so weit, dass die logische Flaeche nicht unter ``MIN_LOGICAL``
## faellt. Darunter wuerden die Bildschirme nicht mehr passen. Am Desktop mit
## Pixeldichte 1 kommt exakt 1,0 heraus: dort aendert sich nichts.
##
## ### Mindestgroessen
##
## Viele Bildschirme setzen Schriftgroessen von 11 oder 12 von Hand. Statt jede
## Stelle einzeln zu suchen, hebt ``_enforce_minimums()`` jede Schrift auf
## ``MIN_FONT`` und -- auf Touch-Geraeten -- jeden Knopf auf ``MIN_TOUCH``
## Entwurfspixel Hoehe an. Eine neue Stelle mit Mini-Schrift faellt damit gar
## nicht erst durch.
##
## ### Bewegung
##
## ``reduce_motion`` folgt beim ersten Start der Systemeinstellung
## (prefers-reduced-motion im Browser) und laesst sich im Menue umschalten.
## Kamerastoesse, Wackeln und Kulissen-Animationen fragen hier nach.

signal settings_changed

const SETTINGS_PATH := "user://settings.json"
const DESIGN_SIZE := Vector2(1600, 900)

## Wie viele CSS-Pixel ein Entwurfspixel mindestens messen soll. 0,8 macht aus
## der Grundschrift (16) knapp 13 CSS-Pixel -- die untere Grenze dessen, was
## auf einem Handy ohne Zoom lesbar ist.
const TARGET_CSS_PER_DESIGN := 0.8

## Kleiner darf die logische Flaeche nicht werden, sonst passen die
## Bildschirme nicht mehr hinein.
const MIN_LOGICAL := Vector2(960, 520)

const MIN_FONT := 14
const MIN_TOUCH := 40

## Anzeigegroesse: Faktor auf die automatische Skalierung.
const SIZE_OPTIONS := [
	{"label": "Automatisch", "factor": 1.0},
	{"label": "Klein", "factor": 0.85},
	{"label": "Gross", "factor": 1.2},
	{"label": "Sehr gross", "factor": 1.4},
]

var size_option: int = 0
var reduce_motion: bool = false

## Ob der Hochformat-Hinweis fuer diese Sitzung weggeklickt wurde.
var _portrait_dismissed := false
var _overlay: CanvasLayer
var _overlay_panel: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reduce_motion = _system_prefers_reduced_motion()
	_load()
	get_tree().root.size_changed.connect(_on_resized)
	get_tree().node_added.connect(_on_node_added)
	_build_overlay()
	_on_resized.call_deferred()


# ---------------------------------------------------------------------------
# Einstellungen
# ---------------------------------------------------------------------------

func set_size_option(index: int) -> void:
	size_option = clampi(index, 0, SIZE_OPTIONS.size() - 1)
	_apply_scale()
	_save()
	settings_changed.emit()


func set_reduce_motion(value: bool) -> void:
	reduce_motion = value
	_save()
	settings_changed.emit()


## Bewegungsdauer-Faktor fuer dekorative Animationen: 0 = aus.
func motion() -> float:
	return 0.0 if reduce_motion else 1.0


func _load() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	size_option = clampi(int(data.get("size_option", 0)), 0, SIZE_OPTIONS.size() - 1)
	reduce_motion = bool(data.get("reduce_motion", reduce_motion))


## Einstellungen werden IMMER gespeichert -- unabhaengig von save_enabled.
## Der Schalter gilt dem Spielstand (Roster, Inventar), nicht der Frage, ob
## jemand die Schrift jedes Mal neu vergroessern muss.
func _save() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"size_option": size_option,
		"reduce_motion": reduce_motion,
	}))


# ---------------------------------------------------------------------------
# Skalierung
# ---------------------------------------------------------------------------

func _on_resized() -> void:
	_apply_scale()
	_update_overlay()


## Der Faktor fuer ``content_scale_factor``. Eigene Funktion und ohne
## Seiteneffekt, damit sie sich ohne Fenster testen laesst.
static func compute_scale(window: Vector2, pixel_ratio: float, user_factor: float) -> float:
	if window.x <= 0.0 or window.y <= 0.0:
		return 1.0
	var stretch := minf(window.x / DESIGN_SIZE.x, window.y / DESIGN_SIZE.y)
	var css_per_design := stretch / maxf(pixel_ratio, 0.01)
	var wanted := TARGET_CSS_PER_DESIGN / maxf(css_per_design, 0.01)
	wanted = maxf(1.0, wanted) * user_factor
	var fits := minf(window.x / (stretch * MIN_LOGICAL.x),
		window.y / (stretch * MIN_LOGICAL.y))
	return clampf(wanted, minf(1.0, user_factor), maxf(1.0, fits))


func _apply_scale() -> void:
	var window := Vector2(DisplayServer.window_get_size())
	var factor := compute_scale(window, _pixel_ratio(),
		float(SIZE_OPTIONS[size_option]["factor"]))
	get_tree().root.content_scale_factor = factor


func _pixel_ratio() -> float:
	if OS.has_feature("web"):
		var ratio = JavaScriptBridge.eval("window.devicePixelRatio || 1", true)
		return float(ratio) if ratio != null else 1.0
	if OS.has_feature("mobile"):
		# Android meldet die Dichte in dpi; 160 dpi ist dort "1x".
		return maxf(1.0, float(DisplayServer.screen_get_dpi()) / 160.0)
	return maxf(1.0, DisplayServer.screen_get_scale())


func _system_prefers_reduced_motion() -> bool:
	if not OS.has_feature("web"):
		return false
	var result = JavaScriptBridge.eval(
		"window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches",
		true)
	return result == true


# ---------------------------------------------------------------------------
# Mindestgroessen
# ---------------------------------------------------------------------------

func _on_node_added(node: Node) -> void:
	if node is Control:
		# Aufgeschoben: viele Bildschirme setzen ihre Schriftgroesse erst NACH
		# add_child. Ein Frame spaeter steht sie fest.
		_enforce_minimums.call_deferred(node)


## Untypisiert, weil der Knoten bis zum aufgeschobenen Aufruf schon wieder
## freigegeben sein kann -- ein typisierter Parameter scheitert dann schon an
## der Uebergabe, bevor is_instance_valid() ueberhaupt fragen kann.
func _enforce_minimums(node) -> void:
	if not is_instance_valid(node) or not node is Control:
		return
	var control := node as Control
	if control is RichTextLabel:
		_raise_font(control, "normal_font_size")
		_raise_font(control, "bold_font_size")
	elif control is Label or control is Button or control is LineEdit:
		_raise_font(control, "font_size")
	if control is Button and DisplayServer.is_touchscreen_available():
		var minimum := control.custom_minimum_size
		if minimum.y < MIN_TOUCH:
			control.custom_minimum_size = Vector2(minimum.x, MIN_TOUCH)


func _raise_font(control: Control, key: String) -> void:
	if control.has_theme_font_size_override(key):
		if control.get_theme_font_size(key) < MIN_FONT:
			control.add_theme_font_size_override(key, MIN_FONT)


# ---------------------------------------------------------------------------
# Lange druecken = Erklaerung
# ---------------------------------------------------------------------------

## Auf Touch gibt es kein Hovern und damit keine Tooltips: alles, was in
## ``tooltip_text`` steht -- was ein Halter annimmt, was eine Aktion tut --,
## war auf dem Handy unerreichbar. Langes Druecken zeigt es jetzt an, fuer
## JEDES Control mit Tooltip, ohne dass ein Bildschirm davon wissen muss.
##
## Das Loslassen danach wird verschluckt: sonst loeste ein langes Druecken auf
## "×" (Halter leeren) nach dem Lesen der Erklaerung genau das aus, was man
## sich nur erklaeren lassen wollte.
const LONG_PRESS_SECONDS := 0.5
const LONG_PRESS_SLOP := 14.0

var _press_serial := 0
var _press_active := false
var _press_position := Vector2.ZERO
var _swallow_release := false
var _swallow_until_msec := 0
const SWALLOW_AFTER_MSEC := 400
var _tip_layer: CanvasLayer
var _tip_panel: PanelContainer
var _tip_label: Label


func _input(event: InputEvent) -> void:
	if not DisplayServer.is_touchscreen_available():
		return
	# Nach einer angezeigten Erklaerung: alle Klicks bis kurz nach dem Loslassen
	# verschlucken. EIN Loslassen reicht nicht -- der Browser schickt nach dem
	# Touch-Ende eigene Maus-Ereignisse hinterher, und eines davon loeste im
	# Test trotzdem "Halter leeren" aus.
	if _swallow_release or Time.get_ticks_msec() < _swallow_until_msec:
		if event is InputEventScreenTouch and not event.pressed:
			_swallow_release = false
			_swallow_until_msec = Time.get_ticks_msec() + SWALLOW_AFTER_MSEC
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
			return
	if event is InputEventScreenTouch:
		if event.pressed:
			_hide_tip()
			_press_active = true
			_press_position = event.position
			_press_serial += 1
			var serial := _press_serial
			get_tree().create_timer(LONG_PRESS_SECONDS).timeout.connect(func():
				if _press_active and serial == _press_serial:
					_show_tip_at(_press_position))
		else:
			_press_active = false
	elif event is InputEventScreenDrag:
		if event.position.distance_to(_press_position) > LONG_PRESS_SLOP:
			_press_active = false


## Der Text des Controls unter dem Finger -- oder seines naechsten Elternteils
## mit Tooltip (eine Aktionszeile traegt ihn am Container, nicht am Label).
static func tooltip_for(control: Control) -> String:
	var node: Node = control
	while node is Control:
		var text: String = (node as Control).tooltip_text
		if text.strip_edges() != "":
			return text
		node = node.get_parent()
	return ""


func _show_tip_at(at: Vector2) -> void:
	var control := get_viewport().gui_get_hovered_control()
	if control == null:
		return
	var text := tooltip_for(control)
	if text == "":
		return
	if _tip_layer == null:
		_tip_layer = CanvasLayer.new()
		_tip_layer.layer = 90
		add_child(_tip_layer)
		_tip_panel = PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.08, 0.12, 0.97)
		style.border_color = Color(0.62, 0.82, 0.96)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.set_content_margin_all(14)
		_tip_panel.add_theme_stylebox_override("panel", style)
		_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tip_label = Label.new()
		_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tip_label.custom_minimum_size = Vector2(420, 0)
		_tip_label.add_theme_font_size_override("font_size", 18)
		_tip_panel.add_child(_tip_label)
		_tip_layer.add_child(_tip_panel)
	_tip_label.text = text
	_tip_panel.reset_size()
	_tip_panel.visible = true
	_swallow_release = true
	await get_tree().process_frame
	var area := get_viewport().get_visible_rect().size
	var panel_size := _tip_panel.size
	# Ueber dem Finger, damit er den Text nicht verdeckt; wenn oben kein Platz
	# ist, darunter.
	var y := at.y - panel_size.y - 24.0
	if y < 8.0:
		y = at.y + 24.0
	_tip_panel.position = Vector2(
		clampf(at.x - panel_size.x * 0.5, 8.0, maxf(8.0, area.x - panel_size.x - 8.0)),
		clampf(y, 8.0, maxf(8.0, area.y - panel_size.y - 8.0)))


func _hide_tip() -> void:
	if _tip_panel != null:
		_tip_panel.visible = false


# ---------------------------------------------------------------------------
# Hochformat
# ---------------------------------------------------------------------------

## Im Hochformat passt keiner der Bildschirme: alle sind fuer das Querformat
## gebaut. Statt das Spiel verkleinert oben in die Ecke zu druecken, sagt ein
## Hinweis, was zu tun ist -- und bietet den Weg an, der auf dem Handy am
## besten funktioniert: Vollbild, ins Querformat gesperrt.
func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 100
	add_child(_overlay)

	_overlay_panel = ColorRect.new()
	(_overlay_panel as ColorRect).color = Color(0.04, 0.05, 0.09, 0.96)
	_overlay_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(_overlay_panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_overlay_panel.add_child(box)

	# Ein gezeichnetes Handy im Querformat statt eines Symbolzeichens: die
	# eingebaute Schrift kennt kein Dreh-Symbol und zeigte ein Kaestchen.
	var icon_holder := CenterContainer.new()
	icon_holder.custom_minimum_size = Vector2(0, 120)
	var phone := Panel.new()
	phone.custom_minimum_size = Vector2(170, 96)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.1, 0.13, 0.2)
	frame.border_color = Color(0.62, 0.82, 0.96)
	frame.set_border_width_all(6)
	frame.set_corner_radius_all(16)
	phone.add_theme_stylebox_override("panel", frame)
	icon_holder.add_child(phone)
	box.add_child(icon_holder)

	var text := Label.new()
	text.text = "Bitte das Geraet ins Querformat drehen."
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(700, 0)
	text.add_theme_font_size_override("font_size", 44)
	box.add_child(text)

	var fullscreen := Button.new()
	fullscreen.text = "Vollbild im Querformat"
	fullscreen.custom_minimum_size = Vector2(700, 110)
	fullscreen.add_theme_font_size_override("font_size", 40)
	fullscreen.pressed.connect(enter_fullscreen)
	box.add_child(fullscreen)

	var dismiss := Button.new()
	dismiss.text = "Trotzdem im Hochformat weiter"
	dismiss.flat = true
	dismiss.custom_minimum_size = Vector2(700, 90)
	dismiss.add_theme_font_size_override("font_size", 32)
	dismiss.pressed.connect(func():
		_portrait_dismissed = true
		_update_overlay())
	box.add_child(dismiss)
	_overlay.visible = false


func _update_overlay() -> void:
	if _overlay == null:
		return
	var window := DisplayServer.window_get_size()
	var portrait := window.y > window.x
	_overlay.visible = portrait and not _portrait_dismissed \
		and DisplayServer.is_touchscreen_available()


## Vollbild und -- wo der Browser es erlaubt -- Sperre aufs Querformat. Muss
## aus einer Nutzeraktion heraus laufen (Knopfdruck), sonst lehnt der Browser
## beides ab.
func enter_fullscreen() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			(function () {
				var el = document.documentElement;
				var go = el.requestFullscreen ? el.requestFullscreen() : Promise.resolve();
				go.then(function () {
					if (screen.orientation && screen.orientation.lock) {
						return screen.orientation.lock('landscape');
					}
				}).catch(function () {});
			})();
		""", true)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_portrait_dismissed = true
	_update_overlay.call_deferred()


func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
