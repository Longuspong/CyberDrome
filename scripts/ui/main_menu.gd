extends Node2D

## Einstiegspunkt und Szenenwechsel.
##
## Im MVP fuehrt er in den Chaos-Virus. Die Werkstatt ist ein eigenes Werkzeug
## (python3 main.py) und liefert ihren Squad ueber user://squad.json -- diese
## Szene laedt ihn und reicht ihn ueber GameState weiter, ohne die Kampfszene
## direkt zu kennen.

func _ready() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	var box := VBoxContainer.new()
	box.position = Vector2(120, 160)
	box.add_theme_constant_override("separation", 12)
	ui.add_child(box)

	var title := Label.new()
	title.text = "DROME"
	title.add_theme_font_size_override("font_size", 56)
	box.add_child(title)

	var squad_line := Label.new()
	var squad_text := "Kein Squad gespeichert -- der Kampf startet mit zwei Demo-DROMEs."
	if not GameState.squad.is_empty():
		var names: Array[String] = []
		for build in GameState.squad:
			names.append("%s%s" % [build.display_name,
				"" if build.is_valid() else " (ungueltig!)"])
		squad_text = "Squad: " + ", ".join(names)
	squad_line.text = squad_text
	box.add_child(squad_line)

	var problems := _squad_problems()
	if not problems.is_empty():
		var warn := Label.new()
		warn.text = "\n".join(problems)
		warn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
		box.add_child(warn)

	var seed_row := HBoxContainer.new()
	var seed_label := Label.new()
	seed_label.text = "Seed (leer = zufaellig): "
	seed_row.add_child(seed_label)
	var seed_field := LineEdit.new()
	seed_field.custom_minimum_size = Vector2(200, 0)
	seed_field.placeholder_text = "z.B. 20260806"
	seed_row.add_child(seed_field)
	box.add_child(seed_row)

	var start := Button.new()
	start.text = "Chaos-Virus starten"
	start.custom_minimum_size = Vector2(260, 48)
	start.disabled = not problems.is_empty()
	start.pressed.connect(func():
		var text := seed_field.text.strip_edges()
		GameState.battle_seed = int(text) if text.is_valid_int() else 0
		if GameState.battle_seed == 0:
			GameState.new_seed()
		get_tree().change_scene_to_file("res://scenes/battle.tscn"))
	box.add_child(start)


## Ungueltige Builds koennen nicht in den Kampf. Die Meldung nennt die
## verletzte Regel, statt den Knopf nur auszugrauen.
func _squad_problems() -> Array[String]:
	var problems: Array[String] = []
	for build in GameState.squad:
		for line in build.validate():
			problems.append("%s: %s" % [build.display_name, line])
	return problems
