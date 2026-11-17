extends Control

## Optionen: Anzeigegroesse, Bewegung, Vollbild. Seit 15. Nov. 2026 kein Tab
## mehr: das Zahnrad oben rechts oeffnet die Seite, der Pfeil fuehrt zurueck
## (UiKit.return_scene). Die Werte haelt das Autoload ``Accessibility``.
##
## Aufbau nach dem Entwurf vom 15. Nov. 2026 (docs/design/einsatz_arcade, Bild
## 06): Karten Anzeige, Bewegung, Bildschirm, Spielstand, Zum Testen; Schalter
## als Zeile mit Titel, Erklaerung und AN/AUS.

func _ready() -> void:
	var content := UiKit.page(self, "Optionen", UiKit.return_scene, -1)
	content.add_theme_constant_override("separation", 16)
	var slot := UiKit.header_slot(self)
	if slot != null:
		slot.add_child(Arcade.tilt(Arcade.tag("SETUP", 12, 0.0), 2.0))

	var display := _card(content, "Anzeige")
	display.add_child(Arcade.label("Schriftgröße", 15, Arcade.WHITE, "bold"))
	# Drei Knoepfe nebeneinander, der gewaehlte farbig. Radio-Punkte waren
	# dunkel auf dunkel -- welcher nicht gewaehlt war, sah man kaum.
	var sizes := HBoxContainer.new()
	sizes.add_theme_constant_override("separation", 6)
	display.add_child(sizes)
	for index in Accessibility.SIZE_OPTIONS.size():
		var on: bool = index == Accessibility.size_option
		var option := UiKit.outline_button("A\n" + str(Accessibility.SIZE_OPTIONS[index]["label"]),
			Arcade.CYAN if on else Arcade.MUTED)
		option.custom_minimum_size = Vector2(0, 64)
		option.add_theme_font_override("font", Arcade.font("bold", 12, 0.12))
		option.add_theme_font_size_override("font_size", 12 + index * 2)
		if on:
			var fill := StyleBoxFlat.new()
			fill.bg_color = Color(Arcade.CYAN, 0.16)
			fill.border_color = Arcade.CYAN
			fill.set_border_width_all(2)
			option.add_theme_stylebox_override("normal", fill)
		option.pressed.connect(func():
			Accessibility.set_size_option(index)
			# Bestehende Knoten tragen ihre Groesse schon; neu aufbauen,
			# damit die Seite die neue Schrift sofort zeigt.
			get_tree().reload_current_scene.call_deferred())
		sizes.add_child(option)
	var preview := PanelContainer.new()
	var preview_box := StyleBoxFlat.new()
	preview_box.bg_color = Arcade.DEEP
	preview_box.set_content_margin_all(12)
	preview.add_theme_stylebox_override("panel", preview_box)
	preview.add_child(UiKit.label("Vorschau: So groß stehen Texte im Spiel. Knöpfe und Layout "
		+ "bleiben gleich.", UiKit.SMALL, UiKit.TEXT))
	display.add_child(preview)

	var motion := _card(content, "Bewegung")
	motion.add_child(_switch("Bewegung reduzieren", "Kein Glitch, kein Flackern, keine Wackler, "
		+ "keine Kamerafahrten. Folgt beim ersten Start der Systemeinstellung.",
		Accessibility.reduce_motion, Accessibility.set_reduce_motion))
	motion.add_child(_rule())
	motion.add_child(_switch("Vibration", "Kurzes Rütteln bei schweren Treffern, Abschüssen, "
		+ "Kampfende, Caches und beim Einbauen. Nur auf Geräten, die es können.",
		Accessibility.haptics, Accessibility.set_haptics))

	var screen := _card(content, "Bildschirm")
	var full_row := HBoxContainer.new()
	full_row.add_theme_constant_override("separation", 10)
	screen.add_child(full_row)
	var full_text := VBoxContainer.new()
	full_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	full_text.add_theme_constant_override("separation", 2)
	full_row.add_child(full_text)
	full_text.add_child(Arcade.label("Vollbild", 15, Arcade.WHITE, "bold"))
	full_text.add_child(UiKit.label("Blendet die Leisten des Browsers aus. Noch besser: \"Zum "
		+ "Startbildschirm hinzufügen\" -- dann startet das Spiel wie eine App.", 13, UiKit.MUTED))
	var fullscreen := UiKit.outline_button("An", Arcade.CYAN)
	fullscreen.custom_minimum_size = Vector2(72, 44)
	fullscreen.size_flags_horizontal = Control.SIZE_SHRINK_END
	fullscreen.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fullscreen.pressed.connect(Accessibility.enter_fullscreen)
	full_row.add_child(fullscreen)

	# Spielstand (10. Nov. 2026): wird gespeichert -- hier wechseln oder zuruecksetzen.
	var save := _card(content, "Spielstand")
	var switch := Button.new()
	switch.custom_minimum_size = Vector2(0, 64)
	switch.add_theme_stylebox_override("normal", Arcade.chamfer_box(Arcade.DEEP, 8, Arcade.CYAN, 2))
	switch.add_theme_stylebox_override("hover", Arcade.chamfer_box(Color("#1d1040"), 8, Arcade.CYAN, 2))
	switch.add_theme_stylebox_override("pressed", Arcade.chamfer_box(Color(Arcade.CYAN, 0.2), 8, Arcade.CYAN, 2))
	switch.pressed.connect(func(): Fader.go("res://scenes/saves.tscn"))
	var switch_row := HBoxContainer.new()
	switch_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	switch_row.offset_left = 10
	switch_row.offset_right = -10
	switch_row.add_theme_constant_override("separation", 12)
	switch_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	switch.add_child(switch_row)
	var number := PanelContainer.new()
	number.add_theme_stylebox_override("panel", Arcade.chamfer_box(Arcade.CYAN, 6))
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	number.add_child(Arcade.label(" %02d " % maxi(GameState.slot, 0), 18, Arcade.NIGHT, "display"))
	switch_row.add_child(number)
	var switch_text := VBoxContainer.new()
	switch_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	switch_text.alignment = BoxContainer.ALIGNMENT_CENTER
	switch_text.add_theme_constant_override("separation", 0)
	switch_row.add_child(switch_text)
	switch_text.add_child(Arcade.label(("Slot %02d · Spielstand wechseln" % GameState.slot)
		if GameState.slot > 0 else "Spielstand wählen", 15, Arcade.WHITE, "bold"))
	switch_text.add_child(Arcade.label("Öffnet die Spielstand-Wahl", 13, Arcade.MUTED))
	var arrow := Arcade.label("›", 26, Arcade.CYAN, "bold")
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	switch_row.add_child(arrow)
	save.add_child(switch)
	save.add_child(UiKit.label("Hangar, Level und ein laufender Einsatz werden automatisch "
		+ "gespeichert." if GameState.slot > 0 else "Kein Spielstand gewählt -- nichts wird "
		+ "gespeichert.", 13, UiKit.MUTED))
	var reset := UiKit.outline_button("Spielstand zurücksetzen", UiKit.BAD)
	reset.custom_minimum_size = Vector2(0, 48)
	reset.add_theme_font_size_override("font_size", 13)
	var armed := {"on": false}
	reset.pressed.connect(func():
		if not armed["on"]:
			armed["on"] = true
			reset.text = "WIRKLICH? NOCHMAL TIPPEN"
			return
		GameState.reset_progress()
		reset.text = "ZURÜCKGESETZT"
		reset.disabled = true)
	save.add_child(reset)

	# Zum Testen: alles freischalten, ohne es erst zu erspielen.
	var test := _card(content, "Zum Testen", "Debug")
	test.add_child(UiKit.label("Nur für Testversionen. Schaltet den Infinity-Einsatz frei, ohne "
		+ "Neon City zu bezwingen.", 14, UiKit.TEXT))
	var unlocked := bool(GameState.progress.get("unlock_all", false))
	var unlock_row := HBoxContainer.new()
	unlock_row.add_theme_constant_override("separation", 8)
	test.add_child(unlock_row)
	var unlock := UiKit.outline_button("Freigeschaltet" if unlocked else "Infinity-Einsatz freischalten",
		UiKit.GOOD if unlocked else Arcade.YELLOW)
	unlock.custom_minimum_size = Vector2(0, 48)
	unlock.add_theme_font_size_override("font_size", 13)
	unlock.disabled = unlocked
	unlock.pressed.connect(func():
		GameState.progress["unlock_all"] = true
		GameState.save_progress()
		get_tree().reload_current_scene.call_deferred())
	unlock_row.add_child(unlock)
	if unlocked:
		var undo := UiKit.outline_button("Zurücksetzen", Arcade.MUTED)
		undo.custom_minimum_size = Vector2(0, 48)
		undo.size_flags_stretch_ratio = 0.6
		undo.add_theme_font_size_override("font_size", 13)
		undo.pressed.connect(func():
			GameState.progress["unlock_all"] = false
			GameState.save_progress()
			get_tree().reload_current_scene.call_deferred())
		unlock_row.add_child(undo)

	# Leistungstest: wie viele 3D-DROMEs schafft dieses Geraet (17. Nov. 2026)
	var bench := UiKit.outline_button("Leistungstest (3D-DROMEs)", Arcade.CYAN)
	bench.custom_minimum_size = Vector2(0, 48)
	bench.add_theme_font_size_override("font_size", 13)
	bench.pressed.connect(func():
		get_tree().change_scene_to_file.call_deferred("res://scenes/bench.tscn"))
	test.add_child(bench)

	var version := Arcade.label("CYBERDROME · Version %s" % str(ProjectSettings.get_setting(
		"application/config/version", "0.0.0")), 12, Arcade.MUTED, "bold", 0.16)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(version)


## Eine Karte mit Ueberschrift in Cyan (und optional einem Etikett rechts).
func _card(parent: Control, title: String, tag: String = "") -> VBoxContainer:
	var box := UiKit.card(parent)
	box.add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	box.add_child(head)
	var heading := UiIcon.text("caret_right", title.to_upper(), 14, Arcade.CYAN, "bold", 0.2)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	if tag != "":
		head.add_child(Arcade.tilt(Arcade.tag(tag.to_upper(), 11, 0.0), 2.0))
	return box


## Schalter-Zeile: Titel und Erklaerung links, Schalter und AN/AUS rechts.
func _switch(title: String, hint: String, on: bool, on_toggle: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	text.add_child(Arcade.label(title, 15, Arcade.WHITE, "bold"))
	text.add_child(UiKit.label(hint, 13, UiKit.MUTED))
	var toggle := CheckButton.new()
	toggle.button_pressed = on
	toggle.tooltip_text = title
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(toggle)
	var state := Arcade.label("AN" if on else "AUS", 12, Arcade.CYAN if on else Arcade.MUTED, "bold", 0.16)
	state.custom_minimum_size = Vector2(30, 0)
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(state)
	toggle.toggled.connect(func(value: bool):
		on_toggle.call(value)
		state.text = "AN" if value else "AUS"
		state.add_theme_color_override("font_color", Arcade.CYAN if value else Arcade.MUTED))
	return row


func _rule() -> Control:
	var line := ColorRect.new()
	line.color = Color("#3a1a6e")
	line.custom_minimum_size = Vector2(0, 1)
	return line
