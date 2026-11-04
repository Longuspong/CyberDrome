extends Control

## Der Lauf-Bildschirm (Roguelike): zwischen den Kaempfen.
##
## Links steht der Squad, rechts das, was gerade zu entscheiden ist -- je nach
## Phase des Laufs:
##
##   * PREPARE: der naechste Kampf (Region, Mutator, Gegner) und "Kampf starten"
##   * REWARD:  drei Belohnungen; ein Teil fragt danach, WO es hin soll
##   * WON/LOST: das Ende mit Verlauf, "Neuer Lauf" oder zurueck ins Menue
##
## Die Regeln stehen in RunState, nicht hier. Dieser Bildschirm zeigt nur an
## und gibt Entscheidungen weiter.

const COLOR_HEADING := Color(0.62, 0.82, 0.96)
const COLOR_MUTED := Color(0.7, 0.75, 0.82)
const COLOR_GOOD := Color(0.46, 0.86, 0.52)
const COLOR_BAD := Color(1.0, 0.5, 0.46)
const COLOR_WARN := Color(1.0, 0.78, 0.4)

var _header_round: Label
var _lives_box: HBoxContainer
var _squad_list: VBoxContainer
var _side: VBoxContainer

## Gewaehlte Belohnung, deren Platz noch aussteht (-1 = keine).
var _pending_reward: int = -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Ein beendeter Lauf bleibt stehen, bis man "Neuer Lauf" waehlt -- sonst
	# saehe man das Ergebnis nie.
	if GameState.run == null:
		GameState.run = RunState.start(randi())
	_build_ui()
	_refresh()


func _run() -> RunState:
	return GameState.run


# ---------------------------------------------------------------------------
# Aufbau
# ---------------------------------------------------------------------------

## Mobile first: alles untereinander. Oben Runde und Leben, dann das, was
## gerade zu entscheiden ist (Kampf starten, Belohnung waehlen), darunter der
## Squad. Die Entscheidung steht oben, weil sie der Grund ist, hier zu sein.
func _build_ui() -> void:
	var content := UiKit.page(self, "Lauf", "res://scenes/main.tscn")

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UiKit.GAP)
	content.add_child(top)
	_header_round = UiKit.label("", UiKit.H2)
	_header_round.autowrap_mode = TextServer.AUTOWRAP_OFF
	_header_round.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_header_round)
	_lives_box = HBoxContainer.new()
	_lives_box.add_theme_constant_override("separation", 6)
	top.add_child(_lives_box)

	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", UiKit.GAP)
	content.add_child(_side)

	_squad_list = VBoxContainer.new()
	_squad_list.add_theme_constant_override("separation", 10)
	content.add_child(_squad_list)


func _refresh() -> void:
	var run := _run()
	_header_round.text = "Runde %d von %d" % [mini(run.round, RunState.rounds_total()),
		RunState.rounds_total()]
	_refresh_lives(run)
	_refresh_squad(run)
	for child in _side.get_children():
		child.queue_free()
	match run.phase:
		RunState.Phase.PREPARE: _show_prepare(run)
		RunState.Phase.REWARD:
			if _pending_reward >= 0:
				_show_placements(run, _pending_reward)
			else:
				_show_rewards(run)
		_: _show_end(run)


## Leben als Kaestchen UND als Zahl -- die Farbe allein darf die Information
## nicht tragen.
func _refresh_lives(run: RunState) -> void:
	for child in _lives_box.get_children():
		child.queue_free()
	var label := Label.new()
	label.text = "%d / %d" % [run.lives, RunState.max_lives()]
	label.add_theme_font_size_override("font_size", 20)
	label.tooltip_text = "Leben: so viele Niederlagen bleiben"
	_lives_box.add_child(label)
	for i in RunState.max_lives():
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(22, 22)
		# Sonst zieht die Kopfzeile die Kreise auf die Hoehe des Menue-Knopfs.
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(11)
		style.bg_color = COLOR_GOOD if i < run.lives else Color(0.2, 0.22, 0.28)
		style.border_color = Color(0.85, 0.88, 0.93)
		style.set_border_width_all(2)
		pip.add_theme_stylebox_override("panel", style)
		_lives_box.add_child(pip)


func _refresh_squad(run: RunState) -> void:
	for child in _squad_list.get_children():
		child.queue_free()
	var heading := Label.new()
	heading.text = "Dein Squad  ·  Staerke %d" % int(DromeBuild.squad_power(run.squad))
	heading.add_theme_font_size_override("font_size", 20)
	heading.modulate = COLOR_HEADING
	_squad_list.add_child(heading)
	for build in run.squad:
		_squad_list.add_child(_drome_card(build))


func _drome_card(build: DromeBuild) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	# Kleines Portraet: derselbe Zusammenbau wie im Kampf (DromeSprites), damit
	# man den Bot wiedererkennt.
	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(96, 96)
	var rig := Node2D.new()
	rig.scale = Vector2(0.75, 0.75)
	rig.position = Vector2(48, 92) - IsoView.SPRITE_ORIGIN * 0.75
	DromeSprites.assemble(rig, build, "south")
	portrait.add_child(rig)
	row.add_child(portrait)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var name := Label.new()
	name.text = "%s   ·   Staerke %d" % [build.display_name, int(build.power_score())]
	name.add_theme_font_size_override("font_size", 20)
	text.add_child(name)
	for slot in build.equip_slots():
		var part := build.part_in(slot)
		var line := Label.new()
		line.text = "%s: %s" % [build._slot_label(slot),
			part.display_name if part != null else "frei"]
		line.add_theme_font_size_override("font_size", 16)
		line.modulate = Color.WHITE if part != null else COLOR_MUTED
		text.add_child(line)
	return panel


# ---------------------------------------------------------------------------
# Phasen
# ---------------------------------------------------------------------------

func _show_prepare(run: RunState) -> void:
	var info := run.preview()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(true))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_side.add_child(panel)

	box.add_child(_label("Naechster Kampf", 22, COLOR_HEADING))
	box.add_child(_label("Region: %s" % info["region"], 18))
	box.add_child(_label("Mutator: %s" % info["mutator"], 18))
	if str(info["mutator_text"]) != "":
		box.add_child(_label(str(info["mutator_text"]), 16, COLOR_MUTED))
	box.add_child(_label("Gegner: %d DROMEs" % int(info["enemies"]), 18))

	var own := float(info["own_power"])
	var foe := float(info["enemy_power"])
	var ratio := own / maxf(1.0, foe)
	var verdict := "ueberlegen" if ratio >= 1.1 else ("ausgeglichen" if ratio >= 0.9 else "unterlegen")
	var color := COLOR_GOOD if ratio >= 1.1 else (COLOR_WARN if ratio >= 0.9 else COLOR_BAD)
	box.add_child(_label("Staerke: du %d  ·  Gegner %d  (%s)" % [int(own), int(foe), verdict],
		18, color))

	var start := _big_button("Kampf starten")
	start.pressed.connect(func():
		GameState.begin_run_battle()
		get_tree().change_scene_to_file("res://scenes/battle.tscn"))
	_side.add_child(start)
	start.grab_focus.call_deferred()

	var abandon := Button.new()
	abandon.text = "Lauf aufgeben"
	abandon.flat = true
	abandon.custom_minimum_size = Vector2(0, 44)
	abandon.pressed.connect(func():
		GameState.run = RunState.start(randi())
		_refresh())
	_side.add_child(abandon)


func _show_rewards(run: RunState) -> void:
	_side.add_child(_label("Sieg! Waehle eine Belohnung.", 22, COLOR_GOOD))
	for index in run.reward_options.size():
		var option: Dictionary = run.reward_options[index]
		var card := Button.new()
		card.text = "%s\n%s" % [option["title"], option["text"]]
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.custom_minimum_size = Vector2(0, 84)
		card.add_theme_font_size_override("font_size", 18)
		card.pressed.connect(func(): _pick_reward(index))
		_side.add_child(card)
		if index == 0:
			card.grab_focus.call_deferred()
	var skip := Button.new()
	skip.text = "Keine nehmen"
	skip.flat = true
	skip.custom_minimum_size = Vector2(0, 44)
	skip.pressed.connect(func():
		run.skip_reward()
		_refresh())
	_side.add_child(skip)


func _pick_reward(index: int) -> void:
	var run := _run()
	var option: Dictionary = run.reward_options[index]
	if option["kind"] == "part":
		_pending_reward = index
	else:
		run.choose_reward(index)
	_refresh()


## Wohin mit dem Teil? Eine Zeile je passendem Halter, mit Belegung. Was nicht
## geht, bleibt sichtbar und sagt warum -- wie in der Werkstatt.
func _show_placements(run: RunState, index: int) -> void:
	var option: Dictionary = run.reward_options[index]
	_side.add_child(_label("Wohin mit %s?" % option["title"], 22, COLOR_HEADING))
	var placements := run.placements_for(option["part_id"])
	if placements.is_empty():
		_side.add_child(_label("Kein Halter in deinem Squad nimmt dieses Teil.", 18, COLOR_BAD))
	for placement in placements:
		var build: DromeBuild = run.squad[int(placement["drome"])]
		var button := Button.new()
		var where := "%s  ·  %s" % [build.display_name, build._slot_label(placement["slot"])]
		var what := "frei" if placement["current"] == "" else "ersetzt %s" % placement["current"]
		button.text = "%s\n%s" % [where, what if placement["valid"] else "geht nicht: Aufbau waere ungueltig"]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 72)
		button.add_theme_font_size_override("font_size", 18)
		button.disabled = not placement["valid"]
		button.pressed.connect(func():
			if run.choose_reward(index, placement):
				_pending_reward = -1
				_refresh())
		_side.add_child(button)
	var back := Button.new()
	back.text = "< Andere Belohnung"
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(func():
		_pending_reward = -1
		_refresh())
	_side.add_child(back)


func _show_end(run: RunState) -> void:
	var won := run.phase == RunState.Phase.WON
	_side.add_child(_label("Lauf gewonnen!" if won else "Lauf verloren.", 30,
		COLOR_GOOD if won else COLOR_BAD))
	var wins := run.history.filter(func(h): return h["won"]).size()
	_side.add_child(_label("%d von %d Kaempfen gewonnen." % [wins, run.history.size()], 18))
	var line := ""
	for entry in run.history:
		line += ("S " if entry["won"] else "N ")
	_side.add_child(_label("Verlauf: %s (S = Sieg, N = Niederlage)" % line.strip_edges(), 16, COLOR_MUTED))

	var again := _big_button("Neuer Lauf")
	again.pressed.connect(func():
		GameState.run = RunState.start(randi())
		_refresh())
	_side.add_child(again)
	again.grab_focus.call_deferred()


# ---------------------------------------------------------------------------
# Bausteine
# ---------------------------------------------------------------------------

func _label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.modulate = color
	return label


func _big_button(text: String) -> Button:
	return UiKit.button(text, true)


func _panel_style(highlight: bool = false) -> StyleBoxFlat:
	return UiKit.card_style(highlight)
