extends Control

## Die Bit-Auswahl vor dem Chaos-Virus (§Chaos).
##
## Hier -- und NUR hier -- startet der Chaos-Virus. Der Spieler hakt an, welche
## seiner DROMEs ("Bits") mitkommen. Der Gegner tritt immer in voller Staerke an
## (gemessen an ALLEN kampftauglichen eigenen DROMEs); wer mit weniger antritt,
## macht es sich schwerer -- und genau das hebt die Beute-Chance. Weniger
## eigene DROMEs, mehr ueberlassenes Feld, mehr Beute.
##
## Die Auswahl schreibt in dieselbe ``in_squad``-Schicht wie die Garage; der
## Kampf liest sie ueber GameState.squad. Reine Auswahl -- gebaut und aufgeloest
## wird woanders.

const COLOR_HEADING := Color(0.62, 0.82, 0.96)
const COLOR_MUTED := Color(0.6, 0.64, 0.7)
const COLOR_GOOD := Color(0.46, 0.86, 0.52)
const COLOR_BAD := Color(1.0, 0.46, 0.46)
const COLOR_WARN := Color(1.0, 0.72, 0.4)

var _cards: VBoxContainer
var _summary: RichTextLabel
var _start: Button
var _seed_field: LineEdit
var _auto_toggle: CheckButton

## Die kampftauglichen Eintraege dieses Aufrufs: {entry, build, power}.
var _eligible: Array = []
var _reference_power: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_gather()
	_build_ui()
	_refresh()


## Alle kampftauglichen DROMEs einsammeln und die Referenz-Staerke (Summe aller)
## festhalten. An ihr misst sich das Handicap, nicht am gewaehlten Squad.
func _gather() -> void:
	_eligible.clear()
	var all: Array = []
	for entry in GameState.roster.entries:
		var build := GameState.roster.build_for(entry)
		if build.is_valid():
			_eligible.append({"entry": entry, "build": build,
				"power": build.power_score()})
			all.append(build)
	_reference_power = DromeBuild.squad_power(all)


## Mobile first: Einleitung, die DROMEs zum Abhaken, die Zusammenfassung,
## Autokampf und der grosse Start-Knopf -- untereinander. Der Seed (ein
## Werkzeug fuers Playtesting) steht ganz unten.
func _build_ui() -> void:
	var content := UiKit.page(self, "Chaos-Virus", "res://scenes/main.tscn")

	content.add_child(UiKit.label("Hake ab, welche DROMEs mitkommen. Der Gegner tritt "
		+ "in voller Staerke an -- je weniger du mitnimmst, desto haerter, aber desto "
		+ "hoeher die Beute.", UiKit.SMALL, UiKit.MUTED))

	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 8)
	content.add_child(_cards)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.card_style())
	content.add_child(panel)
	_summary = RichTextLabel.new()
	_summary.bbcode_enabled = true
	_summary.fit_content = true
	_summary.add_theme_font_size_override("normal_font_size", UiKit.BODY)
	_summary.add_theme_font_size_override("bold_font_size", UiKit.BODY)
	panel.add_child(_summary)

	_auto_toggle = CheckButton.new()
	_auto_toggle.text = "Autokampf (KI steuert beide Seiten)"
	_auto_toggle.custom_minimum_size = Vector2(0, 48)
	_auto_toggle.add_theme_font_size_override("font_size", UiKit.BODY)
	_auto_toggle.button_pressed = GameState.auto_battle
	content.add_child(_auto_toggle)

	_start = UiKit.button("Chaos-Virus starten", true)
	_start.pressed.connect(_start_battle)
	content.add_child(_start)

	var seed_row := HBoxContainer.new()
	seed_row.add_child(UiKit.label("Seed", UiKit.SMALL, UiKit.MUTED))
	_seed_field = LineEdit.new()
	_seed_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_field.custom_minimum_size = Vector2(0, 44)
	_seed_field.placeholder_text = "leer = zufaellig"
	if GameState.battle_seed != 0:
		_seed_field.text = str(GameState.battle_seed)
	seed_row.add_child(_seed_field)
	content.add_child(seed_row)


func _refresh() -> void:
	for child in _cards.get_children():
		child.queue_free()

	if _eligible.is_empty():
		var empty := Label.new()
		empty.text = "Keine kampftauglichen DROMEs. Bau im Hangar welche zusammen."
		empty.modulate = COLOR_BAD
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_cards.add_child(empty)
	else:
		for item in _eligible:
			_cards.add_child(_drome_row(item))

	_refresh_summary()


func _drome_row(item: Dictionary) -> Control:
	var entry: RosterEntry = item["entry"]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(entry.in_squad))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var check := CheckBox.new()
	check.custom_minimum_size = Vector2(44, 44)
	check.button_pressed = entry.in_squad
	check.toggled.connect(func(pressed): _toggle(entry, pressed))
	row.add_child(check)
	# Die ganze Karte ist der Schalter -- das Kaestchen allein ist fuer den
	# Daumen zu klein.
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			check.button_pressed = not check.button_pressed)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var name_label := Label.new()
	name_label.text = entry.name
	name_label.add_theme_font_size_override("font_size", UiKit.BODY)
	text.add_child(name_label)
	var sub := Label.new()
	sub.text = _loadout_summary(item["build"])
	sub.add_theme_font_size_override("font_size", UiKit.SMALL)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.modulate = COLOR_MUTED
	text.add_child(sub)

	var power := Label.new()
	power.text = "Stärke %d" % int(round(item["power"]))
	power.add_theme_font_size_override("font_size", UiKit.SMALL)
	power.modulate = COLOR_HEADING
	row.add_child(power)
	return panel


func _loadout_summary(build: DromeBuild) -> String:
	var names: Array[String] = []
	for part in build.equipment():
		names.append(part.display_name)
	return ", ".join(names) if not names.is_empty() else "nur Rahmen"


func _toggle(entry: RosterEntry, pressed: bool) -> void:
	entry.in_squad = pressed
	GameState.save_roster()
	_refresh()


func _refresh_summary() -> void:
	var chosen: Array = []
	for item in _eligible:
		if item["entry"].in_squad:
			chosen.append(item["build"])
	var count := chosen.size()
	var enemy := _eligible.size()
	var mine := DromeBuild.squad_power(chosen)
	var handicap := 0.0
	if _reference_power > 0.0:
		handicap = clampf(1.0 - mine / _reference_power, 0.0, 1.0)
	var chance := ChaosLoot.drop_chance(handicap)

	var chance_color := "#75e58a" if handicap >= 0.5 else \
		("#f0b968" if handicap >= 0.2 else "#9aa0aa")
	_summary.text = "".join([
		"[b]Dein Einsatz[/b]\n",
		"Eigene DROMEs: [b]%d[/b] / %d\n" % [count, enemy],
		"Gegner: [b]%d[/b] in voller Staerke\n" % enemy,
		"Handicap: [b]%d %%[/b]\n\n" % int(round(handicap * 100.0)),
		"[b]Beute[/b]\n",
		"Chance auf ein Teil: [color=%s][b]%d %%[/b][/color]\n" % [
			chance_color, int(round(chance * 100.0))],
		"Aus der Ausruestung der besiegten Gegner.\n",
		"Pity: %d bis zum garantierten Drop." % maxi(0,
			int(Config.section("chaos").get("loot_pity_threshold", 4))
			- GameState.chaos_pity),
	])

	var ready := count >= 1
	_start.disabled = not ready
	_start.tooltip_text = "" if ready else "Mindestens ein DROME muss mitkommen."


func _start_battle() -> void:
	var count := 0
	for item in _eligible:
		if item["entry"].in_squad:
			count += 1
	if count < 1:
		return

	# Der Gegner tritt mit so vielen DROMEs an wie man selbst STELLEN KOENNTE
	# (alle kampftauglichen), skaliert auf deren volle Staerke -- unabhaengig
	# davon, wie wenige man tatsaechlich mitnimmt.
	GameState.configure_chaos_run(_eligible.size(), _reference_power)
	GameState.auto_battle = _auto_toggle.button_pressed
	GameState.save_roster()

	var text := _seed_field.text.strip_edges()
	GameState.battle_seed = int(text) if text.is_valid_int() else 0
	if GameState.battle_seed == 0:
		GameState.new_seed()
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


func _panel_style(highlight: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.17)
	style.border_color = COLOR_GOOD if highlight else Color(0.24, 0.28, 0.35)
	style.set_border_width_all(2 if highlight else 1)
	style.set_corner_radius_all(5)
	for side in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + side, 10)
	return style
