extends Control

## Der Lauf-Bildschirm (Roguelike): zwischen den Kaempfen.
##
## Oben steht, was gerade zu entscheiden ist, darunter der Lauf-Squad -- je
## nach Phase des Laufs:
##
##   * kein Lauf: Aufstellung -- wer kommt mit (SquadPicker), "Lauf starten"
##   * PREPARE: drei Gegner zur Wahl (Leicht/Normal/Elite) mit Region
##     und den gegnerischen DROMEs; "Kampf starten"
##   * REWARD:  Belohnungen; Waffen kommen ins Lager, ein DROME in den Squad
##     oder nach Hause
##   * STOP:    Zwischenstopp -- Lager, Credits, Ausruesten (NEUANFANG 7d),
##     Module in die Waffenhalter, Rezepte zusammenfuegen (6g)
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

## Zwischenstopp: der angetippte Lagerplatz (-1 = keiner).
var _selected_storage: int = -1

## Zwischenstopp: Rezeptbuch aufgeklappt?
var _recipes_open: bool = false

## Was am Ende des Laufs nach Hause ging -- fuer die Abschlussanzeige.
var _delivered: Array = []


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
	# Im Zwischenstopp steht der Squad mit seinen Haltern oben -- dort wird
	# eingebaut. Die Liste unten waere doppelt.
	_squad_list.visible = run != null and run.phase != RunState.Phase.STOP
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
		RunState.Phase.STOP: _show_stop(run)
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
		run.abandon()
		GameState.deliver_run_home()
		GameState.run = null
		_refresh())
	_side.add_child(abandon)


func _show_rewards(run: RunState) -> void:
	_side.add_child(_label("Sieg! Waehle eine Belohnung.", 22, COLOR_GOOD))
	_side.add_child(_label(_credit_line(run), 16, COLOR_WARN))
	_side.add_child(_label("Waffen und Module kommen ins Lager -- einbauen kannst du gleich danach.",
		16, COLOR_MUTED))
	for index in run.reward_options.size():
		var option: Dictionary = run.reward_options[index]
		var card := Button.new()
		card.text = "%s%s\n%s" % ["[Selten] " if option.get("rare", false) else "",
			option["title"], option["text"]]
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.custom_minimum_size = Vector2(0, 84)
		card.add_theme_font_size_override("font_size", 18)
		if option["kind"] == "module" and run.storage_full():
			card.disabled = true
			card.text += "\nLager voll -- Module koennen nicht nach Hause"
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
	if option["kind"] == "drome":
		_pending_reward = index
	else:
		# Waffen kommen ins Lager, eingebaut wird im Zwischenstopp.
		run.choose_reward(index)
		GameState.deliver_run_home()
	_refresh()


## Wohin mit dem neuen DROME? In den Lauf-Squad, wenn Platz ist, oder nach
## Hause in den Hangar.
func _show_placements(run: RunState, index: int) -> void:
	var option: Dictionary = run.reward_options[index]
	_side.add_child(_label("Wohin mit %s?" % option["title"], 22, COLOR_HEADING))
	var placements: Array = [{"squad": true, "valid": run.has_room()},
		RunState.home_placement()]
	for placement in placements:
		var button := Button.new()
		if placement.get("home", false):
			button.text = "Nach Hause schicken\nLandet im Hangar, nicht in diesem Lauf"
		else:
			button.text = "In den Lauf-Squad\n%s" % ("kaempft ab dem naechsten Kampf mit"
				if placement["valid"] else "geht nicht: Squad ist voll (%d)" % RunState.squad_max())
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


## "+10 Credits fuer den Sieg  ·  jetzt 24"
func _credit_line(run: RunState) -> String:
	if run.history.is_empty():
		return "Credits: %d" % run.credits
	var last: Dictionary = run.history[-1]
	return "+%d Credits %s  ·  jetzt %d" % [int(last.get("credits", 0)),
		"fuer den Sieg" if last["won"] else "Trostgeld", run.credits]


# ---------------------------------------------------------------------------
# Zwischenstopp (NEUANFANG 7d)
# ---------------------------------------------------------------------------

## Nach jedem Kampf: oben Credits, dann das Lager als Kacheln, darunter der
## Squad mit seinen Haltern. Bedienung wie besprochen: Waffe im Lager
## antippen, dann den Halter antippen. Ohne Auswahl baut ein Halter seine
## Waffe aus ins Lager. Umbauen kostet nichts.
func _show_stop(run: RunState) -> void:
	if _selected_storage >= run.storage.size():
		_selected_storage = -1
	var last: Dictionary = run.history[-1] if not run.history.is_empty() else {}
	_side.add_child(_label("Zwischenstopp", 22, COLOR_HEADING))
	if not last.is_empty() and not last["won"]:
		_side.add_child(_label("Niederlage -- ein Leben weniger.", 18, COLOR_BAD))
	_side.add_child(_label(_credit_line(run), 18, COLOR_WARN))

	# --- Lager ---
	_side.add_child(_label("Lager  %d / %d" % [run.storage.size(), RunState.storage_size()],
		18, COLOR_HEADING))
	if run.storage.is_empty():
		_side.add_child(_label("Leer. Beute landet hier; ausgebaute Waffen auch.",
			16, COLOR_MUTED))
	else:
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		_side.add_child(grid)
		for index in run.storage.size():
			grid.add_child(_storage_tile(run, index))
	if _selected_storage >= 0:
		_side.add_child(_module_card(run, _selected_storage) if run.is_module_at(_selected_storage)
			else _storage_card(run, _selected_storage))
	_side.add_child(_recipe_section(run))

	# --- Squad mit Haltern ---
	_side.add_child(_label("Dein Lauf-Squad  ·  Staerke %d"
		% int(DromeBuild.squad_power(run.squad)), 18, COLOR_HEADING))
	var module_mode := run.is_module_at(_selected_storage)
	if _selected_storage >= 0:
		_side.add_child(_label("Tippe einen Halter an, um das Modul einzusetzen." if module_mode
			else "Tippe einen Halter an, um die Waffe einzubauen.", 16, COLOR_MUTED))
	else:
		_side.add_child(_label("Modul im Halter antippen: zurueck ins Lager. Module bleiben im Halter, wenn du die Waffe tauschst.",
			16, COLOR_MUTED))
	var options: Array = []
	if module_mode:
		options = run.module_options(_selected_storage)
	elif _selected_storage >= 0:
		options = run.equip_options(_selected_storage)
	for drome in run.squad.size():
		_side.add_child(_stop_drome_card(run, drome, options))

	var go := _big_button("Weiter zum naechsten Kampf")
	go.pressed.connect(func():
		_selected_storage = -1
		run.continue_run()
		_refresh())
	_side.add_child(go)


## Eine Lager-Kachel: Bild in der Form ihrer Klasse, Name darunter.
func _storage_tile(run: RunState, index: int) -> Control:
	var part := PartDB.get_part(run.storage[index])
	var button := Button.new()
	button.toggle_mode = true
	button.button_pressed = index == _selected_storage
	button.custom_minimum_size = Vector2(0, 96)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = part.display_name if part != null else ""
	if index == _selected_storage:
		button.add_theme_stylebox_override("normal", UiKit.card_style(true))
		button.add_theme_stylebox_override("pressed", UiKit.card_style(true))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var module := ModuleData.get_module(run.storage[index])
	if module != null:
		button.tooltip_text = "%s (%s)" % [module.display_name, module.headline()]
		var chip := ModuleChip.new(module, 56.0)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(chip)
		box.add_child(_tile_name(module.display_name))
	elif part != null:
		var shape := SlotShape.new(part.mount_class, UiKit.part_texture(part), 56.0)
		shape.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(shape)
		var name := Label.new()
		name.text = part.display_name
		name.add_theme_font_size_override("font_size", 12)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.clip_text = true
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(name)
	button.pressed.connect(func():
		_selected_storage = -1 if _selected_storage == index else index
		_refresh())
	return button


func _tile_name(text: String) -> Label:
	var name := Label.new()
	name.text = text
	name.add_theme_font_size_override("font_size", 12)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return name


## Die Karte zum angetippten Lager-Modul: Klasse, Bedingung, Wirkung,
## Verkaufen. Nach Hause gibt es nicht -- Module verfallen am Ende.
func _module_card(run: RunState, index: int) -> Control:
	var module := ModuleData.get_module(run.storage[index])
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(true))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	head.add_child(ModuleChip.new(module, 56.0))
	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	title.add_child(_label(module.display_name, 20))
	title.add_child(_label(module.headline(), 16, module.color()))
	_add_module_lines(box, module)
	box.add_child(_label("Module gibt es nur in diesem Lauf.", 16, COLOR_MUTED))
	var sell := UiKit.button("Verkaufen  +%d" % ModuleData.sell_value(module))
	sell.pressed.connect(func():
		run.sell(index)
		_selected_storage = -1
		_refresh())
	box.add_child(sell)
	return panel


## Wirkung eines Moduls; beim Rezept die Summe und darunter der eigene Effekt.
func _add_module_lines(box: Control, module: ModuleData) -> void:
	if module.is_recipe():
		var own := module.bonus_lines()
		var summed := module.effect_lines(_without(module.effects, module.bonus))
		if not summed.is_empty():
			box.add_child(_label("Summe: %s" % ", ".join(summed), 16))
		if not own.is_empty():
			box.add_child(_label("Dazu: %s" % ", ".join(own), 16, COLOR_GOOD))
	else:
		box.add_child(_label(", ".join(module.effect_lines()), 16))


## Die Wirkungen ohne den eigenen Effekt eines Rezepts (Zahlen abgezogen).
func _without(effects: Dictionary, bonus: Dictionary) -> Dictionary:
	var out := {}
	for key in effects:
		var value = effects[key]
		if bonus.has(key):
			if value is bool:
				continue
			value = float(value) - float(bonus[key])
			if is_zero_approx(float(value)):
				continue
		out[key] = value
	return out


## Das Rezeptbuch (6g, 7e): aufklappbar, je Rezept die Zutaten -- gruen, was
## im Lager liegt -- und "Zusammenfuegen", sobald alle da sind.
func _recipe_section(run: RunState) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var book := run.recipe_book()
	var ready := book.filter(func(entry): return entry["ready"]).size()
	var toggle := UiKit.button("Rezeptbuch  %s%s" % ["(%d bereit)  " % ready if ready > 0 else "",
		"zuklappen" if _recipes_open else "aufklappen"])
	toggle.pressed.connect(func():
		_recipes_open = not _recipes_open
		_refresh())
	box.add_child(toggle)
	if not _recipes_open:
		return box
	box.add_child(_label("Zutaten aus dem Lager ergeben ein neues Modul: die Summe ihrer Werte und ein eigener Effekt.",
		16, COLOR_MUTED))
	for entry in book:
		var module: ModuleData = entry["module"]
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _panel_style(entry["ready"]))
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 4)
		panel.add_child(inner)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		inner.add_child(head)
		head.add_child(ModuleChip.new(module, 44.0))
		var title := VBoxContainer.new()
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		title.add_child(_label(module.display_name, 18))
		title.add_child(_label(module.headline(), 16, module.color()))
		var parts := HFlowContainer.new()
		parts.add_theme_constant_override("h_separation", 6)
		inner.add_child(parts)
		for i in module.from.size():
			var ingredient := ModuleData.get_module(module.from[i])
			var have: bool = entry["have"][i]
			parts.add_child(_flow_label("%s%s" % ["+ " if i > 0 else "",
				ingredient.display_name if ingredient != null else str(module.from[i])],
				16, COLOR_GOOD if have else COLOR_MUTED))
		_add_module_lines(inner, module)
		var make := UiKit.button("Zusammenfuegen" if entry["ready"] else "Zutaten fehlen")
		make.disabled = not entry["ready"]
		make.pressed.connect(func():
			if run.craft(module.id):
				_selected_storage = -1
			_refresh())
		inner.add_child(make)
		box.add_child(panel)
	return box


## Die Karte zur angetippten Lager-Waffe: was sie kann, Verkaufen, nach Hause.
func _storage_card(run: RunState, index: int) -> Control:
	var part := PartDB.get_part(run.storage[index])
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(true))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	# Dieselbe Darstellung wie die Waffen-Karte im Hangar: Symbole, Takt,
	# Faehigkeit; ein Symbol antippen schreibt den Klartext darunter.
	var hint := UiKit.label("Symbol antippen: Erklaerung", UiKit.SMALL, UiKit.MUTED)
	WeaponCard.fill(box, part, hint)
	box.add_child(hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var sell := UiKit.button("Verkaufen  +%d" % RunState.sell_value(part))
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell.pressed.connect(func():
		run.sell(index)
		_selected_storage = -1
		_refresh())
	row.add_child(sell)
	var home := UiKit.button("Nach Hause")
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.tooltip_text = "Sofort in den Hangar -- frei im Lager, fehlt aber im Lauf"
	home.pressed.connect(func():
		run.send_home(index)
		GameState.deliver_run_home()
		_selected_storage = -1
		_refresh())
	row.add_child(home)
	return panel


## Ein DROME im Zwischenstopp: Bild, Name, und je Halter ein Knopf. Mit
## ausgewaehlter Lager-Waffe heisst er "hier einbauen" (oder sagt, warum
## nicht); ohne Auswahl baut er die Waffe aus.
func _stop_drome_card(run: RunState, drome: int, options: Array) -> Control:
	var build: DromeBuild = run.squad[drome]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(false))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	head.add_child(UiKit.drome_view(build, 56))
	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	title.add_child(_label("%s  ·  %d" % [build.display_name, int(build.power_score())], 18))
	if build.equipment().is_empty():
		title.add_child(_label("ohne Waffe -- kaempft nicht mit", 16, COLOR_BAD))

	for slot in build.equip_slots():
		var part := build.part_in(slot)
		var limit := SlotRules.slot_class(build.body(), slot)
		var what := part.display_name if part != null else "leer"
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 56)
		button.add_theme_font_size_override("font_size", 16)
		var line := "Halter %s (%s): %s" % [SlotRules.slot_label(slot),
			SlotRules.class_label(limit), what]
		var module_mode := run.is_module_at(_selected_storage)
		if module_mode:
			var choice: Dictionary = {}
			for entry in options:
				if int(entry["drome"]) == drome and entry["slot"] == slot:
					choice = entry
			var allowed := bool(choice.get("allowed", false))
			button.text = "%s\n%s" % [line, ("Modul hier einsetzen -- %s" % choice.get("detail", ""))
				if allowed else "geht nicht: %s" % choice.get("detail", "kein Platz")]
			button.disabled = not allowed
			if allowed:
				button.add_theme_stylebox_override("normal", UiKit.card_style(true))
			button.pressed.connect(func():
				if run.install_module(_selected_storage, drome, slot):
					_selected_storage = -1
				_refresh())
		elif _selected_storage >= 0:
			var choice: Dictionary = {}
			for entry in options:
				if int(entry["drome"]) == drome and entry["slot"] == slot:
					choice = entry
			var allowed := bool(choice.get("allowed", false))
			button.text = "%s\n%s" % [line, ("Hier einbauen -- %s" % choice.get("detail", ""))
				if allowed else "geht nicht: %s" % choice.get("detail", "passt nicht")]
			button.disabled = not allowed
			if allowed:
				button.add_theme_stylebox_override("normal", UiKit.card_style(true))
			button.pressed.connect(func():
				if run.equip_from_storage(_selected_storage, drome, slot):
					_selected_storage = -1
				_refresh())
		elif part != null:
			button.text = "%s\n%s" % [line, "Ins Lager" if not run.storage_full()
				else "Lager voll -- erst verkaufen"]
			button.disabled = run.storage_full()
			button.pressed.connect(func():
				run.unequip(drome, slot)
				_refresh())
		else:
			button.text = "%s\nWaffe im Lager antippen, dann hier" % line
			button.disabled = true
		box.add_child(button)
		box.add_child(_module_row(run, drome, slot))
	return panel


## Die Module eines Halters als Chips mit Namen. Antippen nimmt eines zurueck
## ins Lager; ruhende (Bedingung passt nicht zur Waffe) sind abgeblendet.
func _module_row(run: RunState, drome: int, slot: String) -> Control:
	var build: DromeBuild = run.squad[drome]
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	var installed := build.modules_in(slot)
	var room := ModuleData.slots_for(build)
	row.add_child(_flow_label("Module %d/%d" % [installed.size(), room], 16, COLOR_MUTED))
	var weapon := build.part_in(slot)
	for position in installed.size():
		var module: ModuleData = installed[position]
		var resting := module.blocker(weapon)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 48)
		button.text = module.display_name
		button.icon = null
		button.add_theme_font_size_override("font_size", 14)
		button.tooltip_text = "%s\n%s%s\nAntippen: zurueck ins Lager" % [module.display_name,
			", ".join(module.effect_lines()), ("\nruht: " + resting) if resting != "" else ""]
		if resting != "":
			button.modulate = Color(1, 1, 1, 0.55)
		var chip := ModuleChip.new(module, 36.0)
		chip.dim = resting != ""
		var holder := HBoxContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		button.text = ""
		var name := _label(module.display_name + (" (ruht)" if resting != "" else ""), 14)
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name.autowrap_mode = TextServer.AUTOWRAP_OFF
		holder.add_child(chip)
		holder.add_child(name)
		button.add_child(holder)
		button.custom_minimum_size = Vector2(44.0 + name.get_minimum_size().x + 12.0, 48)
		button.disabled = run.storage_full()
		button.pressed.connect(func():
			run.remove_module(drome, slot, position)
			_refresh())
		row.add_child(button)
	return row


func _show_end(run: RunState) -> void:
	# Die Beute, die noch im Lauf war, geht jetzt nach Hause (7f).
	_delivered.append_array(GameState.deliver_run_home())
	var won := run.phase == RunState.Phase.WON
	_side.add_child(_label("Lauf gewonnen!" if won else "Lauf verloren.", 30,
		COLOR_GOOD if won else COLOR_BAD))
	var wins := run.history.filter(func(h): return h["won"]).size()
	_side.add_child(_label("%d von %d Kaempfen gewonnen." % [wins, run.history.size()], 18))
	var line := ""
	for entry in run.history:
		line += "%s(%s) " % ["S" if entry["won"] else "N", "LNE"[int(entry.get("tier", 1))]]
	_side.add_child(_label("Verlauf: %s (S = Sieg, N = Niederlage; in Klammern die Stufe)" % line.strip_edges(), 16, COLOR_MUTED))

	var parts: Array = _delivered.filter(func(item): return item.get("kind", "") == "part") \
		.map(func(item): return str(item["title"]))
	if not parts.is_empty():
		_side.add_child(_label("Nach Hause in den Hangar: %s" % ", ".join(parts),
			16, COLOR_GOOD))

	var again := _big_button("Neuer Lauf")
	again.pressed.connect(func():
		GameState.deliver_run_home()
		_delivered.clear()
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


## Fuer Fliessreihen (HFlowContainer): ohne Umbruch, sonst bekommt das Label
## keine Breite und bricht nach jedem Buchstaben um.
func _flow_label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var label := _label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


func _big_button(text: String) -> Button:
	return UiKit.button(text, true)


func _panel_style(highlight: bool = false) -> StyleBoxFlat:
	return UiKit.card_style(highlight)
