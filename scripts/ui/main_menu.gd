extends Control

## Hauptmenue: Werkstatt oder Chaos-Virus.
##
## Der Einstiegspunkt kennt nur zwei Szenen und den Seed. Alles andere haengt
## am GameState -- so kommt man aus dem Ergebnisbildschirm zurueck, ohne dass
## der Kampf die Werkstatt kennen muss oder umgekehrt.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.position = Vector2(140, 130)
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	var title := Label.new()
	title.text = "DROME"
	title.add_theme_font_size_override("font_size", 64)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Death Robot Omni Machine Entity"
	subtitle.modulate = Color(0.55, 0.75, 0.9)
	box.add_child(subtitle)

	box.add_child(_spacer(18))

	var squad_line := Label.new()
	squad_line.text = _squad_summary()
	box.add_child(squad_line)

	var problems := _squad_problems()
	if not problems.is_empty():
		var warn := Label.new()
		warn.text = "\n".join(problems)
		warn.modulate = Color(1.0, 0.42, 0.42)
		box.add_child(warn)

	box.add_child(_spacer(10))

	var workshop := Button.new()
	workshop.text = "Werkstatt"
	workshop.custom_minimum_size = Vector2(300, 54)
	workshop.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/workshop.tscn"))
	box.add_child(workshop)

	# --- Chaos-Virus mit Seed-Feld ---
	var seed_row := HBoxContainer.new()
	var seed_label := Label.new()
	seed_label.text = "Seed (leer = zufaellig): "
	seed_row.add_child(seed_label)
	var seed_field := LineEdit.new()
	seed_field.custom_minimum_size = Vector2(200, 0)
	seed_field.placeholder_text = "z.B. 20260806"
	if GameState.battle_seed != 0:
		seed_field.text = str(GameState.battle_seed)
	seed_row.add_child(seed_field)
	box.add_child(seed_row)

	var battle := Button.new()
	battle.text = "Chaos-Virus"
	battle.custom_minimum_size = Vector2(300, 54)
	battle.disabled = not problems.is_empty()
	battle.tooltip_text = "" if problems.is_empty() \
		else "Der Squad enthaelt ungueltige Aufbauten."
	battle.pressed.connect(func():
		var text := seed_field.text.strip_edges()
		GameState.battle_seed = int(text) if text.is_valid_int() else 0
		if GameState.battle_seed == 0:
			GameState.new_seed()
		get_tree().change_scene_to_file("res://scenes/battle.tscn"))
	box.add_child(battle)

	box.add_child(_spacer(10))

	var quit := Button.new()
	quit.text = "Beenden"
	quit.custom_minimum_size = Vector2(300, 40)
	quit.pressed.connect(func(): get_tree().quit())
	box.add_child(quit)

	var hint := Label.new()
	hint.text = "Die SVG-Werkstatt (python3 main.py) bleibt daneben bestehen:\n"\
		+ "dort werden Bauteile gezeichnet, Anker gesetzt und Paletten gepflegt."
	hint.modulate = Color(0.55, 0.6, 0.68)
	box.add_child(_spacer(16))
	box.add_child(hint)


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _squad_summary() -> String:
	if GameState.squad.is_empty():
		return "Kein Squad gespeichert. In der Werkstatt einen bauen."
	var names: Array[String] = []
	for build in GameState.squad:
		names.append(build.display_name)
	return "Squad (%d): %s" % [GameState.squad.size(), ", ".join(names)]


## Ungueltige Aufbauten koennen nicht in den Kampf. Die Meldung nennt die
## verletzte Regel, statt den Knopf nur auszugrauen.
func _squad_problems() -> Array[String]:
	var problems: Array[String] = []
	if GameState.squad.is_empty():
		problems.append("Squad ist leer.")
	for build in GameState.squad:
		for line in build.validate():
			problems.append("%s: %s" % [build.display_name, line])
	return problems
