extends Control

## Der Lauf-Bildschirm (Roguelike): zwischen den Kaempfen.
##
## Oben steht, was gerade zu entscheiden ist, darunter der Lauf-Squad -- je
## nach Phase des Laufs:
##
##   * kein Lauf: Aufstellung -- wer kommt mit (SquadPicker), "Lauf starten"
##   * PREPARE: drei Gegner zur Wahl (Leicht/Normal/Elite) mit Region
##     und den gegnerischen DROMEs; "Kampf starten"
##   * REWARD:  Belohnungen; Beute wird eingebaut oder nach Hause geschickt
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
	# saehe man das Ergebnis nie. Ohne Lauf kommt die Aufstellung.
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
	var content := UiKit.page(self, "Lauf", "res://scenes/main.tscn", -1, true,
		Ambience.Kind.CITY, 0.35)

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
	for child in _side.get_children():
		child.queue_free()
	_lives_box.visible = run != null
	_squad_list.visible = run != null
	if run == null:
		_header_round.text = "Aufstellung"
		_show_setup()
		return
	_header_round.text = "Runde %d von %d" % [mini(run.round, RunState.rounds_total()),
		RunState.rounds_total()]
	_refresh_lives(run)
	_refresh_squad(run)
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
	heading.text = "Dein Lauf-Squad  ·  Staerke %d" % int(DromeBuild.squad_power(run.squad))
	heading.add_theme_font_size_override("font_size", 20)
	heading.modulate = COLOR_HEADING
	_squad_list.add_child(heading)
	for build in run.squad:
		_squad_list.add_child(_drome_card(build))


## Dieselbe Karte wie in der Aufstellung, plus die freien Halter -- dort
## passt Beute hinein.
func _drome_card(build: DromeBuild) -> Control:
	var panel := SquadPicker.drome_card(build)
	var free := build.equip_slots().filter(func(slot): return build.part_in(slot) == null)
	if not free.is_empty():
		var text: VBoxContainer = panel.get_child(0).get_child(1)
		text.add_child(UiKit.label("frei: %s" % ", ".join(free.map(
			func(slot): return build._slot_label(slot))), UiKit.SMALL, COLOR_WARN))
	return panel


# ---------------------------------------------------------------------------
# Phasen
# ---------------------------------------------------------------------------

## Vor dem Lauf: wer kommt mit? Vorgeschlagen ist der Hangar-Squad.
func _show_setup() -> void:
	_side.add_child(_label("Wer kommt mit? Vorgeschlagen ist dein Hangar-Squad. Im Lauf "
		+ "baust du nur mit Beute um -- nicht mit dem Inventar von zuhause. Beute, die "
		+ "du nicht einbaust, kannst du nach Hause schicken.", UiKit.SMALL, COLOR_MUTED))
	var picker := SquadPicker.new()
	_side.add_child(picker)
	picker.setup(RunState.squad_max())
	_side.add_child(_label("%d Kaempfe, %d Leben. Vor jedem Kampf waehlst du den Gegner: "
		% [RunState.rounds_total(), RunState.max_lives()]
		+ "Leicht, Normal oder Elite -- je haerter, desto besser die Beute.",
		UiKit.SMALL, COLOR_MUTED))
	var start := _big_button("Lauf starten")
	start.disabled = picker.chosen_count() < 1
	picker.changed.connect(func(): start.disabled = picker.chosen_count() < 1)
	start.pressed.connect(func():
		GameState.start_run()
		_refresh())
	_side.add_child(start)


func _show_prepare(run: RunState) -> void:
	_side.add_child(_label("Waehle deinen Gegner", 22, COLOR_HEADING))

	# Die drei Stufen als Reiter nebeneinander -- mit Staerke, damit man
	# vergleichen kann, ohne jede einzeln anzutippen.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	_side.add_child(tabs)
	for which in 3:
		var tab := Button.new()
		var foes := run.enemies(which)
		var foe_power := int(DromeBuild.squad_power(foes))
		tab.text = "%s\n%d  ·  %dx" % [RunState.TIER_NAMES[which], foe_power, foes.size()]
		tab.tooltip_text = "%s: %d Gegner, Staerke %d" % [RunState.TIER_NAMES[which],
			foes.size(), foe_power]
		tab.toggle_mode = true
		tab.button_pressed = which == run.tier
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size = Vector2(0, 64)
		tab.add_theme_font_size_override("font_size", 18)
		if which == run.tier:
			tab.add_theme_stylebox_override("normal", UiKit.card_style(true))
			tab.add_theme_stylebox_override("pressed", UiKit.card_style(true))
		tab.pressed.connect(func():
			run.choose_tier(which)
			_refresh())
		tabs.add_child(tab)

	var info := run.preview()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(true))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_side.add_child(panel)

	box.add_child(_label("Region: %s" % info["region"], 18))

	var own := float(info["own_power"])
	var foe := float(info["enemy_power"])
	var ratio := own / maxf(1.0, foe)
	var verdict := "ueberlegen" if ratio >= 1.1 else ("ausgeglichen" if ratio >= 0.9 else "unterlegen")
	var color := COLOR_GOOD if ratio >= 1.1 else (COLOR_WARN if ratio >= 0.9 else COLOR_BAD)
	box.add_child(_label("Staerke: du %d  ·  Gegner %d  (%s)" % [int(own), int(foe), verdict],
		18, color))
	box.add_child(_label("Beute: %s" % info["reward_text"], 16,
		COLOR_WARN if run.tier == RunState.Tier.ELITE else COLOR_MUTED))

	box.add_child(_label("Gegner: %d DROMEs" % int(info["enemies"]), 18, COLOR_HEADING))
	for build in info["enemy_builds"]:
		box.add_child(SquadPicker.drome_card(build))

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
		GameState.deliver_run_home()
		GameState.run = null
		_refresh())
	_side.add_child(abandon)


func _show_rewards(run: RunState) -> void:
	_side.add_child(_label("Sieg! Waehle eine Belohnung.", 22, COLOR_GOOD))
	for index in run.reward_options.size():
		var option: Dictionary = run.reward_options[index]
		var card := Button.new()
		card.text = "%s%s\n%s" % ["[Selten] " if option.get("rare", false) else "",
			option["title"], option["text"]]
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
	if option["kind"] == "part" or option["kind"] == "drome":
		_pending_reward = index
	else:
		run.choose_reward(index)
	_refresh()


## Wohin mit der Beute? Eine Zeile je passendem Halter, mit Belegung. Was
## nicht geht, bleibt sichtbar und sagt warum -- wie im Hangar. Zuletzt immer
## "Nach Hause schicken": dann landet die Beute im Inventar zuhause.
func _show_placements(run: RunState, index: int) -> void:
	var option: Dictionary = run.reward_options[index]
	_side.add_child(_label("Wohin mit %s?" % option["title"], 22, COLOR_HEADING))
	var placements: Array = []
	if option["kind"] == "part":
		placements = run.placements_for(option["part_id"])
		if placements.size() <= 1:
			_side.add_child(_label("Kein Halter in deinem Lauf-Squad nimmt dieses Teil.",
				18, COLOR_BAD))
	else:
		placements = [{"squad": true, "valid": run.has_room()}, RunState.home_placement()]
	for placement in placements:
		var button := Button.new()
		if placement.get("home", false):
			button.text = "Nach Hause schicken\nLandet im Inventar, nicht in diesem Lauf"
		elif placement.get("squad", false):
			button.text = "In den Lauf-Squad\n%s" % ("kaempft ab dem naechsten Kampf mit"
				if placement["valid"] else "geht nicht: Squad ist voll (%d)" % RunState.squad_max())
		else:
			var build: DromeBuild = run.squad[int(placement["drome"])]
			var where := "%s  ·  %s" % [build.display_name, build._slot_label(placement["slot"])]
			var what := "frei" if placement["current"] == "" else "ersetzt %s" % placement["current"]
			button.text = "%s\n%s" % [where, what if placement["valid"]
				else "geht nicht: Aufbau waere ungueltig"]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 72)
		button.add_theme_font_size_override("font_size", 18)
		button.disabled = not placement["valid"]
		var chosen: Dictionary = {} if placement.get("squad", false) else placement
		button.pressed.connect(func():
			if run.choose_reward(index, chosen):
				_pending_reward = -1
				GameState.deliver_run_home()
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
		line += "%s(%s) " % ["S" if entry["won"] else "N", "LNE"[int(entry.get("tier", 1))]]
	_side.add_child(_label("Verlauf: %s (S = Sieg, N = Niederlage; in Klammern die Stufe)" % line.strip_edges(), 16, COLOR_MUTED))

	var again := _big_button("Neuer Lauf")
	again.pressed.connect(func():
		GameState.deliver_run_home()
		GameState.run = null
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
