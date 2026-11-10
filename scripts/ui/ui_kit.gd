class_name UiKit
extends RefCounted

## Der gemeinsame Baukasten der Bildschirme -- mobile first.
##
## Entworfen fuer ein Handy im Hochformat (450x800 Entwurfspixel, siehe
## Accessibility). Jeder Bildschirm baut sich aus denselben Teilen: einem
## Seitenrahmen mit Kopfzeile, Karten, grossen Knoepfen und -- auf den
## Hauptseiten -- der Tab-Leiste unten. So sieht jede Seite gleich aus, und
## eine Groessenregel aendert man an EINER Stelle.
##
## Im Querformat bleibt die Inhaltsspalte zentriert und auf ``MAX_COLUMN``
## begrenzt: ein Handy-Layout auf 1400 Pixel Breite gezogen liest sich nicht.

# --- Masse -----------------------------------------------------------------

const H1 := 28
const H2 := 22
const BODY := 18
const SMALL := 16

const PAD := 16
const GAP := 12
const BUTTON_HEIGHT := 56
const TAB_HEIGHT := 64
const MAX_COLUMN := 640.0
## Rundung der Ecken von Karten und Knoepfen.
const RADIUS := 14

# --- Farben ----------------------------------------------------------------

const BG := Color(0.05, 0.06, 0.09)
const CARD := Color(0.1, 0.12, 0.17)
const CARD_LINE := Color(0.24, 0.28, 0.35)
const ACCENT := Color(0.38, 0.8, 0.98)
const HEADING := Color(0.62, 0.82, 0.96)
const MUTED := Color(0.68, 0.73, 0.8)
const GOOD := Color(0.46, 0.86, 0.52)
const BAD := Color(1.0, 0.5, 0.46)
const WARN := Color(1.0, 0.78, 0.4)

## Die Hauptseiten der Tab-Leiste: Titel und Szene.
const TABS := [
	["Spielen", "res://scenes/main.tscn"],
	["Hangar", "res://scenes/hangar.tscn"],
	["Optionen", "res://scenes/settings.tscn"],
]


## Baut den Rahmen einer Seite unter ``root`` und gibt die Inhaltsspalte
## zurueck (eine VBox in einem ScrollContainer).
##
##   title      Kopfzeile; leer = keine
##   back       Szene fuer den Zurueck-Pfeil; leer = keiner
##   tab        Index der aktiven Tab-Leisten-Seite; -1 = keine Tab-Leiste
##   scroll     false fuer Seiten, die ihren Platz selbst einteilen
##   scenery    die Kulisse dahinter (Ambience.Kind), darken dunkelt sie ab
static func page(root: Control, title: String, back: String = "", tab: int = -1,
		scroll: bool = true, scenery: int = Ambience.Kind.PLAIN,
		darken: float = 0.0) -> VBoxContainer:
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Die Kulisse statt einer schwarzen Flaeche (Ambience).
	root.add_child(Ambience.create(scenery, darken))

	var frame := VBoxContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("separation", 0)
	root.add_child(frame)

	if title != "" or back != "":
		frame.add_child(header(root, title, back))

	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(margin)
	_keep_column(root, margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", GAP)
	if scroll:
		var scroller := ScrollContainer.new()
		scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin.add_child(scroller)
		scroller.add_child(content)
	else:
		margin.add_child(content)

	if tab >= 0:
		frame.add_child(tab_bar(root, tab))
	return content


## Die sicheren Raender (Notch, Gestenleiste) in Viewport-Einheiten -- so
## weit das System sie meldet. Im Browser haelt die Seite selbst Abstand
## (ohne viewport-fit=cover), dort ist alles 0; fuer die spaetere App zaehlt es.
static func safe_insets(node: Node) -> Dictionary:
	var none := {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	if DisplayServer.get_name() == "headless" or OS.has_feature("web"):
		return none
	var window := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var screen := Vector2(DisplayServer.screen_get_size())
	if window.x <= 0.0 or safe.size.x <= 0.0 or window != screen:
		return none
	var scale := node.get_viewport().get_visible_rect().size / window
	return {"top": safe.position.y * scale.y,
		"bottom": (screen.y - safe.end.y) * scale.y,
		"left": safe.position.x * scale.x,
		"right": (screen.x - safe.end.x) * scale.x}


## Seitenraender, die im Querformat die Spalte zentrieren.
static func _keep_column(root: Control, margin: MarginContainer) -> void:
	var apply := func():
		var width := root.get_viewport_rect().size.x
		var side := maxf(PAD, (width - MAX_COLUMN) * 0.5)
		margin.add_theme_constant_override("margin_left", int(side))
		margin.add_theme_constant_override("margin_right", int(side))
		margin.add_theme_constant_override("margin_top", PAD)
		margin.add_theme_constant_override("margin_bottom", PAD)
		var insets := safe_insets(root)
		var frame := margin.get_parent() as Control
		if frame != null:
			frame.offset_top = insets["top"]
			frame.offset_bottom = -insets["bottom"]
	apply.call()
	root.get_viewport().size_changed.connect(apply)


static func header(root: Control, title: String, back: String = "") -> Control:
	var bar := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.13)
	style.border_color = CARD_LINE
	style.border_width_bottom = 1
	style.content_margin_left = PAD
	style.content_margin_right = PAD
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	bar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	bar.add_child(row)
	if back != "":
		var back_button := Button.new()
		back_button.text = "<"
		back_button.flat = true
		back_button.custom_minimum_size = Vector2(48, 48)
		back_button.add_theme_font_size_override("font_size", H1)
		back_button.pressed.connect(func(): root.get_tree().change_scene_to_file(back))
		row.add_child(back_button)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 48)
	label.add_theme_font_size_override("font_size", H2)
	label.modulate = HEADING
	row.add_child(label)
	return bar


## Die Leiste unten: drei Hauptseiten, die aktive hervorgehoben.
static func tab_bar(root: Control, active: int) -> Control:
	var bar := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.13)
	style.border_color = CARD_LINE
	style.border_width_top = 1
	bar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	bar.add_child(row)
	for index in TABS.size():
		var button := Button.new()
		button.text = TABS[index][0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, TAB_HEIGHT)
		button.add_theme_font_size_override("font_size", SMALL)
		# Die aktive Seite: Akzentfarbe und ein Strich oben. Der Knopf darf
		# dafuer nicht "flat" sein -- flache Knoepfe zeichnen ihren Stil nicht.
		var mark := StyleBoxFlat.new()
		mark.bg_color = Color(0.1, 0.14, 0.2) if index == active else Color(0, 0, 0, 0)
		mark.border_color = ACCENT if index == active else Color(0, 0, 0, 0)
		mark.border_width_top = 3
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, mark)
		if index == active:
			button.add_theme_color_override("font_color", ACCENT)
			button.add_theme_color_override("font_hover_color", ACCENT)
			button.add_theme_color_override("font_pressed_color", ACCENT)
			button.add_theme_color_override("font_focus_color", ACCENT)
		else:
			var scene: String = TABS[index][1]
			button.pressed.connect(func(): root.get_tree().change_scene_to_file(scene))
		row.add_child(button)
	return bar


# --- Bausteine -------------------------------------------------------------

static func label(text: String, size: int = BODY, color: Color = Color.WHITE) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", size)
	result.modulate = color
	return result


static func heading(text: String) -> Label:
	return label(text, H2, HEADING)


## Ein grosser Knopf ueber die ganze Breite. ``primary`` = die Hauptaktion
## der Seite, farbig hervorgehoben.
static func button(text: String, primary: bool = false) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", H2 if primary else BODY)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		result.add_theme_stylebox_override(state, _button_style(state, primary))
	if primary:
		result.add_theme_color_override("font_color", Color(0.03, 0.06, 0.1))
		result.add_theme_color_override("font_hover_color", Color(0.03, 0.06, 0.1))
		result.add_theme_color_override("font_pressed_color", Color(0.03, 0.06, 0.1))
		result.add_theme_color_override("font_focus_color", Color(0.03, 0.06, 0.1))
		result.add_theme_color_override("font_hover_pressed_color", Color(0.03, 0.06, 0.1))
	return result


static func _button_style(state: String, primary: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(RADIUS)
	style.set_content_margin_all(12)
	if primary:
		style.bg_color = ACCENT if state != "pressed" else ACCENT.darkened(0.2)
		if state == "disabled":
			style.bg_color = Color(0.2, 0.24, 0.3)
		elif state != "focus":
			# Die Hauptaktion leuchtet: ein weicher Schein in Akzentfarbe.
			style.shadow_color = Color(ACCENT, 0.3)
			style.shadow_size = 10
	else:
		style.bg_color = Color(0.13, 0.16, 0.22) if state != "pressed" else Color(0.18, 0.24, 0.32)
		style.border_color = CARD_LINE if state != "hover" else ACCENT
		style.set_border_width_all(1)
	if state == "focus":
		style.draw_center = false
		style.border_color = ACCENT
		style.set_border_width_all(2)
	return style


## Eine Karte: Panel mit Innenabstand, darin eine VBox, die zurueckkommt.
static func card(parent: Control, highlight: bool = false) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", card_style(highlight))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	return box


static func card_style(highlight: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	# Leicht durchscheinend: die Kulisse soll hinter den Karten zu ahnen
	# sein, ohne die Schrift zu stoeren.
	style.bg_color = Color(CARD, 0.92)
	style.border_color = ACCENT if highlight else CARD_LINE
	style.set_border_width_all(2 if highlight else 1)
	style.set_corner_radius_all(RADIUS)
	style.set_content_margin_all(14)
	# Ein weicher Schatten hebt die Karte von der Kulisse ab.
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	return style


## Das Theme fuer alles, was keinen eigenen Stil setzt (10. Nov. 2026): die
## Standard-Knoepfe (Reiter, Plus/Minus, Leiste im Kampf), Eingabefelder und
## Rollbalken sahen wie der graue Godot-Editor aus -- eckig, neben den
## runden Karten. Hier bekommen sie dieselben Formen und Farben.
## Accessibility haengt es an die Wurzel und setzt die Schriftgroesse.
static func theme(font_size: int) -> Theme:
	var result := Theme.new()
	result.default_font_size = font_size

	var states := {
		"normal": [Color(0.13, 0.16, 0.22, 0.96), CARD_LINE, 1],
		"hover": [Color(0.15, 0.19, 0.26, 0.96), Color(0.36, 0.42, 0.52), 1],
		"pressed": [Color(0.13, 0.24, 0.34, 0.98), ACCENT, 2],
		"disabled": [Color(0.1, 0.12, 0.16, 0.6), Color(CARD_LINE, 0.5), 1],
	}
	for state in states:
		var box := StyleBoxFlat.new()
		box.bg_color = states[state][0]
		box.border_color = states[state][1]
		box.set_border_width_all(states[state][2])
		box.set_corner_radius_all(RADIUS - 2)
		box.set_content_margin_all(10)
		result.set_stylebox(state, "Button", box)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(ACCENT, 0.7)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(RADIUS - 2)
	result.set_stylebox("focus", "Button", focus)
	result.set_color("font_color", "Button", Color(0.9, 0.93, 0.98))
	result.set_color("font_hover_color", "Button", Color.WHITE)
	result.set_color("font_pressed_color", "Button", Color.WHITE)
	result.set_color("font_focus_color", "Button", Color.WHITE)
	result.set_color("font_disabled_color", "Button", Color(0.55, 0.6, 0.68))

	for state in ["normal", "focus", "read_only"]:
		var field := StyleBoxFlat.new()
		field.bg_color = Color(0.06, 0.08, 0.12, 0.95)
		field.border_color = ACCENT if state == "focus" else CARD_LINE
		field.set_border_width_all(2 if state == "focus" else 1)
		field.set_corner_radius_all(RADIUS - 4)
		field.set_content_margin_all(10)
		result.set_stylebox(state, "LineEdit", field)

	# Schalter: ohne Kasten -- sonst saehe ein eingeschalteter aus wie ein
	# gedrueckter Knopf.
	for kind in ["CheckButton", "CheckBox"]:
		for state in ["normal", "hover", "pressed", "disabled", "hover_pressed", "focus"]:
			var plain := StyleBoxEmpty.new()
			plain.set_content_margin_all(6)
			result.set_stylebox(state, kind, plain)

	# Rollbalken: ein schmaler runder Strich statt einer grauen Leiste.
	for bar in ["VScrollBar", "HScrollBar"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color(0, 0, 0, 0)
		track.set_content_margin_all(3)
		result.set_stylebox("scroll", bar, track)
		result.set_stylebox("scroll_focus", bar, track)
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
			var grabber := StyleBoxFlat.new()
			grabber.bg_color = Color(1, 1, 1, 0.22 if state == "grabber" else 0.4)
			grabber.set_corner_radius_all(3)
			result.set_stylebox(state, bar, grabber)
	return result


## Eine Zeile "Name ........ Wert".
static func row(name: String, value: String, color: Color = Color.WHITE) -> HBoxContainer:
	var line := HBoxContainer.new()
	var left := label(name, BODY, MUTED)
	left.autowrap_mode = TextServer.AUTOWRAP_OFF
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(left)
	var right := label(value, BODY, color)
	right.autowrap_mode = TextServer.AUTOWRAP_OFF
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(right)
	return line


# --- Bilder ----------------------------------------------------------------

static var _crops: Dictionary = {}


## Das Bild eines Teils, auf seinen sichtbaren Inhalt zugeschnitten -- ein Kern
## belegt nur einen kleinen Teil seiner 128er Leinwand und waere sonst ein Punkt.
static func part_texture(part: PartData, facing: String = "south") -> Texture2D:
	if part == null:
		return null
	var path := str(part.view(facing).get("svg", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	if _crops.has(path):
		return _crops[path]
	var texture: Texture2D = load(path)
	var result: Texture2D = texture
	var image := texture.get_image()
	if image != null:
		if image.is_compressed():
			image.decompress()
		var used := image.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(used)
			result = atlas
	_crops[path] = result
	return result


## Ein DROME als Bild: der GANZE Bot (Koerper, Kopf, Fuesse, Kern, Ausruestung)
## ueber DromeSprites -- derselbe Zusammenbau wie im Kampf. ``edge`` ist die
## Kantenlaenge des Bildes.
static func drome_view(build: DromeBuild, edge: float, facing: String = "south") -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(edge, edge)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.clip_contents = true
	var rig := Node2D.new()
	var scale := edge / 112.0
	rig.scale = Vector2(scale, scale)
	rig.position = Vector2(edge * 0.5, edge * 0.92) - IsoView.SPRITE_ORIGIN * scale
	DromeSprites.assemble(rig, build, facing)
	holder.add_child(rig)
	return holder


## Ein Chassis als ganze Huelle (Koerper mit Kopf und Fuessen seines Sets) --
## nicht nur der Rumpf.
static func chassis_view(body: PartData, edge: float) -> Control:
	var build := DromeBuild.create(body.display_name, {})
	build.apply_chassis(body.id)
	return drome_view(build, edge)
