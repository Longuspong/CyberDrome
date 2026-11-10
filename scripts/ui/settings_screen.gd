extends Control

## Optionen: Anzeigegroesse, Bewegung, Vollbild -- eine eigene Seite in der
## Tab-Leiste. Die Werte haelt das Autoload ``Accessibility``.

func _ready() -> void:
	var content := UiKit.page(self, "Optionen", "", 2)

	var display := UiKit.card(content)
	display.add_child(UiKit.heading("Schriftgroesse"))
	display.add_child(UiKit.label("Vergroessert nur den Text -- das Layout bleibt, wie es ist.",
		UiKit.SMALL, UiKit.MUTED))
	# Drei Knoepfe nebeneinander, der gewaehlte farbig. Radio-Punkte waren
	# dunkel auf dunkel -- welcher nicht gewaehlt war, sah man kaum.
	var sizes := HBoxContainer.new()
	sizes.add_theme_constant_override("separation", 6)
	display.add_child(sizes)
	for index in Accessibility.SIZE_OPTIONS.size():
		var option := UiKit.button(Accessibility.SIZE_OPTIONS[index]["label"],
			index == Accessibility.size_option)
		option.add_theme_font_size_override("font_size", UiKit.BODY)
		option.pressed.connect(func():
			Accessibility.set_size_option(index)
			# Bestehende Knoten tragen ihre Groesse schon; neu aufbauen,
			# damit die Seite die neue Schrift sofort zeigt.
			get_tree().reload_current_scene.call_deferred())
		sizes.add_child(option)

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

	var haptic := CheckButton.new()
	haptic.text = "Vibration (Haptik)"
	haptic.custom_minimum_size = Vector2(0, 48)
	haptic.add_theme_font_size_override("font_size", UiKit.BODY)
	haptic.button_pressed = Accessibility.haptics
	haptic.toggled.connect(Accessibility.set_haptics)
	motion.add_child(haptic)
	motion.add_child(UiKit.label("Kurzes Vibrieren bei schweren Treffern, Abschuessen, "
		+ "Kampfende und beim Einbauen. Nur auf Geraeten, die es koennen.",
		UiKit.SMALL, UiKit.MUTED))

	# Spielstand (10. Nov. 2026): wird jetzt gespeichert -- hier zuruecksetzen.
	var save := UiKit.card(content)
	save.add_child(UiKit.heading("Spielstand"))
	save.add_child(UiKit.label("Hangar, Level und ein laufender Lauf werden automatisch "
		+ "gespeichert.", UiKit.SMALL, UiKit.MUTED))
	var reset := UiKit.button("Spielstand zuruecksetzen")
	reset.add_theme_color_override("font_color", UiKit.BAD)
	var armed := {"on": false}
	reset.pressed.connect(func():
		if not armed["on"]:
			armed["on"] = true
			reset.text = "Wirklich? Alles geht verloren -- nochmal tippen"
			return
		GameState.reset_progress()
		reset.text = "Zurueckgesetzt"
		reset.disabled = true)
	save.add_child(reset)

	var screen := UiKit.card(content)
	screen.add_child(UiKit.heading("Bildschirm"))
	var fullscreen := UiKit.button("Vollbild")
	fullscreen.pressed.connect(Accessibility.enter_fullscreen)
	screen.add_child(fullscreen)
	screen.add_child(UiKit.label("Blendet die Leisten des Browsers aus. Noch besser: "
		+ "\"Zum Startbildschirm hinzufuegen\" -- dann startet das Spiel wie eine App.",
		UiKit.SMALL, UiKit.MUTED))
