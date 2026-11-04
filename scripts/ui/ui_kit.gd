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
	["Garage", "res://scenes/garage.tscn"],
	["Inventar", "res://scenes/inventory.tscn"],
	["Optionen", "res://scenes/settings.tscn"],
]


## Baut den Rahmen einer Seite unter ``root`` und gibt die Inhaltsspalte
## zurueck (eine VBox in einem ScrollContainer).
##
##   title      Kopfzeile; leer = keine
##   back       Szene fuer den Zurueck-Pfeil; leer = keiner
##   tab        Index der aktiven Tab-Leisten-Seite; -1 = keine Tab-Leiste
##   scroll     false fuer Seiten, die ihren Platz selbst einteilen
static func page(root: Control, title: String, back: String = "", tab: int = -1,
		scroll: bool = true) -> VBoxContainer:
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

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


## Seitenraender, die im Querformat die Spalte zentrieren.
static func _keep_column(root: Control, margin: MarginContainer) -> void:
	var apply := func():
		var width := root.get_viewport_rect().size.x
		var side := maxf(PAD, (width - MAX_COLUMN) * 0.5)
		margin.add_theme_constant_override("margin_left", int(side))
		margin.add_theme_constant_override("margin_right", int(side))
		margin.add_theme_constant_override("margin_top", PAD)
		margin.add_theme_constant_override("margin_bottom", PAD)
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


## Die Leiste unten: vier Hauptseiten, die aktive hervorgehoben.
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
		button.flat = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, TAB_HEIGHT)
		button.add_theme_font_size_override("font_size", SMALL)
		if index == active:
			button.add_theme_color_override("font_color", ACCENT)
			button.add_theme_color_override("font_hover_color", ACCENT)
			var mark := StyleBoxFlat.new()
			mark.bg_color = Color(0.1, 0.14, 0.2)
			mark.border_color = ACCENT
			mark.border_width_top = 3
			button.add_theme_stylebox_override("normal", mark)
			button.add_theme_stylebox_override("hover", mark)
			button.add_theme_stylebox_override("pressed", mark)
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
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	if primary:
		style.bg_color = ACCENT if state != "pressed" else ACCENT.darkened(0.2)
		if state == "disabled":
			style.bg_color = Color(0.2, 0.24, 0.3)
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
	style.bg_color = CARD
	style.border_color = ACCENT if highlight else CARD_LINE
	style.set_border_width_all(2 if highlight else 1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	return style


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
