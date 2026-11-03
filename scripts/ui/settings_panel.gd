class_name SettingsPanel
extends PanelContainer

## Einstellungen zur Barrierefreiheit: Anzeigegroesse, Bewegung, Vollbild.
##
## Ein eigenes Bauteil statt Code im Hauptmenue, damit es auch aus anderen
## Bildschirmen heraus geoeffnet werden kann. Die Werte selbst haelt das
## Autoload ``Accessibility`` -- das Panel zeigt sie nur an und schreibt sie
## zurueck.

signal closed


static func open(host: Node) -> SettingsPanel:
	var layer := CanvasLayer.new()
	layer.layer = 50
	host.add_child(layer)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)

	var panel := SettingsPanel.new()
	layer.add_child(panel)
	panel.closed.connect(func(): layer.queue_free())
	return panel


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(560, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.15)
	style.border_color = Color(0.62, 0.82, 0.96)
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	add_child(box)

	var title := Label.new()
	title.text = "Einstellungen"
	title.add_theme_font_size_override("font_size", 30)
	title.modulate = Color(0.62, 0.82, 0.96)
	box.add_child(title)

	# Anzeigegroesse
	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 16)
	var size_label := Label.new()
	size_label.text = "Anzeigegroesse"
	size_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_label.add_theme_font_size_override("font_size", 20)
	size_row.add_child(size_label)
	var sizes := OptionButton.new()
	sizes.custom_minimum_size = Vector2(220, 48)
	sizes.add_theme_font_size_override("font_size", 20)
	for option in Accessibility.SIZE_OPTIONS:
		sizes.add_item(option["label"])
	sizes.selected = Accessibility.size_option
	sizes.item_selected.connect(Accessibility.set_size_option)
	size_row.add_child(sizes)
	box.add_child(size_row)

	var hint := Label.new()
	hint.text = "\"Automatisch\" vergroessert auf Handys und kleinen Bildschirmen so weit, "\
		+ "dass Schrift ohne Zoom lesbar bleibt."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(500, 0)
	hint.modulate = Color(0.7, 0.75, 0.82)
	hint.add_theme_font_size_override("font_size", 16)
	box.add_child(hint)

	# Bewegung
	var motion := CheckButton.new()
	motion.text = "Animationen reduzieren"
	motion.add_theme_font_size_override("font_size", 20)
	motion.custom_minimum_size = Vector2(0, 48)
	motion.button_pressed = Accessibility.reduce_motion
	motion.toggled.connect(Accessibility.set_reduce_motion)
	box.add_child(motion)

	var motion_hint := Label.new()
	motion_hint.text = "Schaltet Kamerawackeln und die Kulissen-Animationen ab. "\
		+ "Folgt beim ersten Start der Systemeinstellung."
	motion_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	motion_hint.custom_minimum_size = Vector2(500, 0)
	motion_hint.modulate = Color(0.7, 0.75, 0.82)
	motion_hint.add_theme_font_size_override("font_size", 16)
	box.add_child(motion_hint)

	# Vollbild
	var fullscreen := Button.new()
	fullscreen.text = "Vollbild (Querformat)"
	fullscreen.custom_minimum_size = Vector2(0, 52)
	fullscreen.add_theme_font_size_override("font_size", 20)
	fullscreen.pressed.connect(Accessibility.enter_fullscreen)
	box.add_child(fullscreen)

	var close := Button.new()
	close.text = "Schliessen"
	close.custom_minimum_size = Vector2(0, 52)
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(func(): closed.emit())
	box.add_child(close)
	close.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
