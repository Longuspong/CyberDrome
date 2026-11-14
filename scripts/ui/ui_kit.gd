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
## Rundung der Ecken von Karten und Knoepfen. Seit dem Arcade-Glitch-Stil
## (14. Nov. 2026) abgeschraegt statt rund: siehe _corner().
const RADIUS := 12

# --- Farben ----------------------------------------------------------------

# Seit 14. Nov. 2026 die Farben des Arcade-Glitch-Stils (SPOT-Blatt Design).
const BG := Color("#0a0618")
const CARD := Color("#1b0b3a")
const CARD_LINE := Color("#4b3a82")
const ACCENT := Color("#2ee3eb")
## Hauptaktion: Arcade-Gelb, Schrift darauf Tiefviolett.
const PRIMARY := Color("#ffe14d")
const ON_PRIMARY := Color("#12082a")
const HEADING := Color("#2ee3eb")
const TEXT := Color("#e9dcff")
const MUTED := Color("#c3b3e6")
const GOOD := Color("#5cf2a2")
const BAD := Color("#ff5c7c")
const WARN := Color("#ffe14d")
const MAGENTA := Color("#ff2bd6")

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

	# Die Kulisse statt einer schwarzen Flaeche (Ambience); ohne eigene
	# Kulisse der Arcade-Hintergrund (Punktraster, blasse Sonne).
	if scenery == Ambience.Kind.PLAIN:
		root.add_child(Arcade.Backdrop.new(false))
	else:
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
	# Feine Scanlines ueber allem (Arcade-Stil), ohne Eingaben zu schlucken.
	root.add_child.call_deferred(Arcade.Scanlines.new(0.12))
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
	style.bg_color = Color(BG, 0.94)
	style.border_color = Color(ACCENT, 0.45)
	style.border_width_bottom = 2
	style.content_margin_left = PAD
	style.content_margin_right = PAD
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	bar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	bar.add_child(row)
	if back != "":
		var back_button := Arcade.BackButton.new()
		back_button.tooltip_text = "Zurück"
		back_button.pressed.connect(func(): root.get_tree().change_scene_to_file(back))
		row.add_child(back_button)
	if title != "":
		var tag := Arcade.tilt(Arcade.tag(title.to_upper(), 15, 0.0), -2.0)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tag)
	var push := Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	push.custom_minimum_size = Vector2(0, 44)
	row.add_child(push)
	return bar


## Die Leiste unten: drei Hauptseiten, die aktive hervorgehoben.
static func tab_bar(root: Control, active: int) -> Control:
	var bar := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(BG, 0.96)
	style.border_color = Color(MAGENTA, 0.55)
	style.border_width_top = 2
	bar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	bar.add_child(row)
	for index in TABS.size():
		var button := Button.new()
		button.text = str(TABS[index][0]).to_upper()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, TAB_HEIGHT)
		var on := index == active
		button.add_theme_font_override("font", Arcade.font("display" if on else "bold", SMALL, 0.08))
		button.add_theme_font_size_override("font_size", SMALL)
		# Die aktive Seite: gelber Balken oben und gelbe Schrift. Der Knopf
		# darf dafuer nicht "flat" sein -- flache Knoepfe zeichnen ihren Stil nicht.
		var mark := StyleBoxFlat.new()
		mark.bg_color = Color(PRIMARY, 0.08) if on else Color(0, 0, 0, 0)
		mark.border_color = PRIMARY if on else Color(0, 0, 0, 0)
		mark.border_width_top = 4
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, mark)
		var color := PRIMARY if on else MUTED
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, color)
		if not on:
			var scene: String = TABS[index][1]
			button.pressed.connect(func():
				Accessibility.tap()
				root.get_tree().change_scene_to_file(scene))
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


## Ueberschrift im Arcade-Stil: Chakra Petch fett, gesperrt, in Grossbuchstaben.
static func heading(text: String) -> Label:
	var result := label(text.to_upper(), H2 - 2, HEADING)
	result.add_theme_font_override("font", Arcade.font("bold", H2 - 2, 0.12))
	return result


## Ein grosser Knopf ueber die ganze Breite. ``primary`` = die Hauptaktion
## der Seite, farbig hervorgehoben.
static func button(text: String, primary: bool = false) -> Button:
	var result := Button.new()
	result.text = text.to_upper() if primary else text
	result.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var size := 19 if primary else BODY
	result.add_theme_font_override("font", Arcade.font("display" if primary else "bold", size,
		0.05 if primary else 0.02))
	result.add_theme_font_size_override("font_size", size)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		result.add_theme_stylebox_override(state, _button_style(state, primary))
	if primary:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
				"font_hover_pressed_color"]:
			result.add_theme_color_override(state, ON_PRIMARY)
		result.add_theme_color_override("font_disabled_color", Color(ON_PRIMARY, 0.6))
	result.pressed.connect(Accessibility.tap)
	return result


## Abgeschraegte Ecken oben links und unten rechts (Arcade-Formensprache).
static func _corner(style: StyleBoxFlat, cut: int = RADIUS) -> void:
	style.corner_detail = 1
	style.corner_radius_top_left = cut
	style.corner_radius_bottom_right = cut
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.anti_aliasing = true


static func _button_style(state: String, primary: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	_corner(style)
	style.set_content_margin_all(12)
	if primary:
		style.bg_color = PRIMARY if state != "pressed" else PRIMARY.darkened(0.18)
		if state == "hover":
			style.bg_color = PRIMARY.lightened(0.12)
		if state == "disabled":
			style.bg_color = Color(PRIMARY, 0.35)
		elif state != "focus":
			# Harter Versatzschatten in Magenta statt weichem Schein.
			style.shadow_color = Color(MAGENTA, 0.75)
			style.shadow_size = 0
			style.shadow_offset = Vector2(5, 5)
	else:
		style.bg_color = Color(CARD, 0.95) if state != "pressed" else Color(ACCENT, 0.22)
		style.border_color = CARD_LINE if state != "hover" else ACCENT
		if state == "disabled":
			style.bg_color = Color(CARD, 0.5)
			style.border_color = Color(CARD_LINE, 0.5)
		style.set_border_width_all(2)
	if state == "focus":
		style.draw_center = false
		style.shadow_size = 0
		style.shadow_offset = Vector2.ZERO
		style.border_color = Color("#fff3a8")
		style.set_border_width_all(3)
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
	style.bg_color = Color(CARD, 0.9)
	style.border_color = ACCENT if highlight else CARD_LINE
	style.set_border_width_all(2)
	_corner(style)
	style.set_content_margin_all(14)
	# Harter Versatzschatten (Arcade): hervorgehobene Karten in Magenta.
	style.shadow_color = Color(MAGENTA, 0.55) if highlight else Color(0, 0, 0, 0.45)
	style.shadow_size = 0
	style.shadow_offset = Vector2(5, 5)
	return style


## Das Theme fuer alles, was keinen eigenen Stil setzt (10. Nov. 2026): die
## Standard-Knoepfe (Reiter, Plus/Minus, Leiste im Kampf), Eingabefelder und
## Rollbalken sahen wie der graue Godot-Editor aus -- eckig, neben den
## runden Karten. Hier bekommen sie dieselben Formen und Farben.
## Accessibility haengt es an die Wurzel und setzt die Schriftgroesse.
static func theme(font_size: int) -> Theme:
	var result := Theme.new()
	result.default_font_size = font_size
	# Chakra Petch fuer allen Text (Arcade-Stil, 14. Nov. 2026).
	result.default_font = Arcade.font("medium")
	result.set_color("font_color", "Label", TEXT)
	result.set_font("font", "Button", Arcade.font("bold"))

	var states := {
		"normal": [Color(CARD, 0.95), CARD_LINE, 2],
		"hover": [Color(CARD.lightened(0.06), 0.96), ACCENT, 2],
		"pressed": [Color(ACCENT, 0.22), ACCENT, 2],
		"disabled": [Color(CARD, 0.5), Color(CARD_LINE, 0.5), 2],
	}
	for state in states:
		var box := StyleBoxFlat.new()
		box.bg_color = states[state][0]
		box.border_color = states[state][1]
		box.set_border_width_all(states[state][2])
		_corner(box, RADIUS - 4)
		box.set_content_margin_all(10)
		result.set_stylebox(state, "Button", box)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color("#fff3a8")
	focus.set_border_width_all(2)
	_corner(focus, RADIUS - 4)
	result.set_stylebox("focus", "Button", focus)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", Color.WHITE)
	result.set_color("font_pressed_color", "Button", Color.WHITE)
	result.set_color("font_focus_color", "Button", Color.WHITE)
	result.set_color("font_disabled_color", "Button", Color(MUTED, 0.6))

	for state in ["normal", "focus", "read_only"]:
		var field := StyleBoxFlat.new()
		field.bg_color = Color(BG, 0.95)
		field.border_color = ACCENT if state == "focus" else CARD_LINE
		field.set_border_width_all(2 if state == "focus" else 1)
		_corner(field, RADIUS - 6)
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
