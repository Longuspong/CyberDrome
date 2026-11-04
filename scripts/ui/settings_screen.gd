extends Control

## Optionen: Anzeigegroesse, Bewegung, Vollbild -- eine eigene Seite in der
## Tab-Leiste. Die Werte haelt das Autoload ``Accessibility``.

func _ready() -> void:
	var content := UiKit.page(self, "Optionen", "", 3)

	var display := UiKit.card(content)
	display.add_child(UiKit.heading("Anzeigegroesse"))
	display.add_child(UiKit.label("\"Automatisch\" passt die Groesse an den Bildschirm an. "
		+ "Groesser heisst: mehr Scrollen, aber leichter zu lesen.", UiKit.SMALL, UiKit.MUTED))
	var group := ButtonGroup.new()
	for index in Accessibility.SIZE_OPTIONS.size():
		var option := CheckBox.new()
		option.text = Accessibility.SIZE_OPTIONS[index]["label"]
		option.button_group = group
		option.custom_minimum_size = Vector2(0, 48)
		option.add_theme_font_size_override("font_size", UiKit.BODY)
		option.button_pressed = index == Accessibility.size_option
		option.pressed.connect(func(): Accessibility.set_size_option(index))
		display.add_child(option)

	var motion := UiKit.card(content)
	motion.add_child(UiKit.heading("Bewegung"))
	var toggle := CheckButton.new()
	toggle.text = "Animationen reduzieren"
	toggle.custom_minimum_size = Vector2(0, 48)
	toggle.add_theme_font_size_override("font_size", UiKit.BODY)
	toggle.button_pressed = Accessibility.reduce_motion
	toggle.toggled.connect(Accessibility.set_reduce_motion)
	motion.add_child(toggle)
	motion.add_child(UiKit.label("Schaltet Kamerawackeln, Kamerafahrten und die Kulissen-"
		+ "Animationen ab. Folgt beim ersten Start der Systemeinstellung.",
		UiKit.SMALL, UiKit.MUTED))

	var screen := UiKit.card(content)
	screen.add_child(UiKit.heading("Bildschirm"))
	var fullscreen := UiKit.button("Vollbild")
	fullscreen.pressed.connect(Accessibility.enter_fullscreen)
	screen.add_child(fullscreen)
	screen.add_child(UiKit.label("Blendet die Leisten des Browsers aus. Noch besser: "
		+ "\"Zum Startbildschirm hinzufuegen\" -- dann startet das Spiel wie eine App.",
		UiKit.SMALL, UiKit.MUTED))
