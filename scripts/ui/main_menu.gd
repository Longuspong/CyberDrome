extends Control

## Das Hauptmenue -- der Einstieg in alle Bildschirme.
##
## Das Layout folgt der Handskizze: MENU oben links, Inventar oben rechts, die
## Drome-Garage rechts, unten die drei Modi (Gamemode 1/2 ausgegraut, Chaos-
## Virus aktiv). In der Mitte laeuft eine reine Kulisse -- zufaellige Bots, die
## einander bearbeiten (MenuArena) --, damit im Menue etwas los ist.
##
## Der Einstieg kennt nur Szenen und den GameState. Ob der Chaos-Virus startbar
## ist, sagt der Squad im Roster; alles Weitere liegt hinter den jeweiligen
## Bildschirmen.

const COLOR_HEADING := Color(0.62, 0.82, 0.96)
const COLOR_MUTED := Color(0.58, 0.63, 0.7)
const COLOR_BAD := Color(1.0, 0.46, 0.46)
const COLOR_GOOD := Color(0.46, 0.86, 0.52)

var _status: Label
var _chaos: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_backdrop()
	_build_ui()
	_refresh_status()


# ---------------------------------------------------------------------------
# Kulisse
# ---------------------------------------------------------------------------

## Hintergrund, Arena und ein dunkler Schleier -- alle auf einer eigenen Ebene
## HINTER der Bedienung (CanvasLayer -1). So kann die Arena nie ueber einen
## Knopf geraten, egal welche Zeichentiefe ihre Bots gerade haben.
func _build_backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)

	var size := get_viewport().get_visible_rect().size

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)

	var arena := MenuArena.new()
	arena.position = Vector2(size.x * 0.5, size.y * 0.46)
	layer.add_child(arena)
	arena.start()

	# Ein Schleier daempft die Kulisse, damit die Schrift darueber ruhig bleibt.
	var scrim := ColorRect.new()
	scrim.color = Color(0.05, 0.06, 0.09, 0.55)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(scrim)


# ---------------------------------------------------------------------------
# Bedienung
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# MENU -- oben links.
	var title := _boxed_label("MENU", 44)
	_place(title, Vector2(0, 0), Vector2(40, 32), Vector2(240, 84))
	add_child(title)

	# Inventar -- oben rechts.
	var inventory := _boxed_button("Inventar", 22)
	inventory.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/inventory.tscn"))
	_place(inventory, Vector2(1, 0), Vector2(-280, 32), Vector2(240, 84))
	add_child(inventory)

	# Drome-Garage -- rechts, mittig.
	var garage := _boxed_button("Drome\nGarage", 26)
	garage.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/garage.tscn"))
	_place(garage, Vector2(1, 0.5), Vector2(-280, -90), Vector2(240, 180))
	add_child(garage)

	# Untere Leiste: die drei Modi.
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 18)
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	_place(modes, Vector2(0.5, 1), Vector2(-585, -128), Vector2(1170, 96))
	add_child(modes)

	modes.add_child(_mode_button("Gamemode 1",
		"Noch nicht verfuegbar.", true, Callable()))
	modes.add_child(_mode_button("Gamemode 2",
		"Noch nicht verfuegbar.", true, Callable()))
	_chaos = _mode_button("Chaos-Virus", "", false, _start_chaos)
	modes.add_child(_chaos)

	# Squad-Status -- eine Zeile ueber den Modi, sagt warum der Chaos-Virus
	# gegebenenfalls gesperrt ist.
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 14)
	_place(_status, Vector2(0.5, 1), Vector2(-400, -168), Vector2(800, 28))
	add_child(_status)


func _start_chaos() -> void:
	# Der Chaos-Virus startet ueber die Bit-Auswahl -- NICHT mehr direkt aus der
	# Garage. Dort waehlt man, wie viele eigene DROMEs mitkommen (weniger = mehr
	# Beute), und von dort geht es ins Gefecht.
	get_tree().change_scene_to_file("res://scenes/chaos_select.tscn")


func _refresh_status() -> void:
	# Startbar ist der Chaos-Virus, sobald es ueberhaupt einen kampftauglichen
	# DROME gibt -- WIE viele mitkommen, entscheidet die Bit-Auswahl.
	var ready := not GameState.battle_ready_builds().is_empty()
	if ready:
		_status.text = "Bereit -- im Chaos-Virus waehlst du, wie viele DROMEs mitkommen."
		_status.modulate = COLOR_GOOD
	else:
		_status.text = "Keine kampftauglichen DROMEs. In der Garage welche zusammenstellen."
		_status.modulate = COLOR_BAD
	_chaos.disabled = not ready
	_chaos.tooltip_text = "" if ready else "Kein kampftauglicher DROME vorhanden."


# ---------------------------------------------------------------------------
# Bausteine
# ---------------------------------------------------------------------------

## Ein Modus-Knopf im Stil der Skizze. Ausgegraute Modi bleiben sichtbar, damit
## man sieht, dass da noch mehr kommt -- ``disabled`` sperrt sie.
func _mode_button(text: String, tip: String, disabled: bool, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(360, 78)
	button.add_theme_font_size_override("font_size", 24)
	if on_press.is_valid():
		button.pressed.connect(on_press)
	return button


func _boxed_label(text: String, font_size: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box_style())
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = COLOR_HEADING
	panel.add_child(label)
	return panel


func _boxed_button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_stylebox_override("normal", _box_style())
	button.add_theme_stylebox_override("hover", _box_style(true))
	button.add_theme_stylebox_override("pressed", _box_style(true))
	return button


func _box_style(highlight: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.16, 0.9)
	style.border_color = COLOR_HEADING if highlight else Color(0.85, 0.88, 0.93)
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	for side in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + side, 10)
	return style


## Verankert ein Control an einem Bezugspunkt (anchor in 0..1) mit einem Versatz
## und einer festen Groesse. So haengen die Ecken-Elemente an den Ecken, auch
## wenn das Fenster groesser wird als die 1600x900 der Vorlage.
func _place(ctrl: Control, anchor: Vector2, offset: Vector2, size: Vector2) -> void:
	ctrl.anchor_left = anchor.x
	ctrl.anchor_right = anchor.x
	ctrl.anchor_top = anchor.y
	ctrl.anchor_bottom = anchor.y
	ctrl.offset_left = offset.x
	ctrl.offset_top = offset.y
	ctrl.offset_right = offset.x + size.x
	ctrl.offset_bottom = offset.y + size.y
