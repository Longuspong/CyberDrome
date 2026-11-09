extends Control

## Der Lauf-Bildschirm (Roguelike): zwischen den Kaempfen.
##
## Oben steht, was gerade zu entscheiden ist, darunter der Lauf-Squad -- je
## nach Phase des Laufs:
##
##   * kein Lauf: Aufstellung -- wer kommt mit (SquadPicker), "Lauf starten"
##   * PREPARE: drei Gegner zur Wahl (Leicht/Normal/Elite) mit Region
##     und den gegnerischen DROMEs; "Kampf starten"
##   * STOP:    Zwischenstopp -- gewuerfelte Beute (6i), Laden, Lager,
##     Credits, Ausruesten (NEUANFANG 7d),
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
	if str(info.get("faction", "")) != "":
		box.add_child(_label("Gegner: %s  ·  Profil %s" % [info["faction"], info["profile"]],
			16, COLOR_WARN))
		if str(info.get("faction_text", "")) != "":
			box.add_child(_flow_label(str(info["faction_text"]), 14, COLOR_MUTED))

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
	if not run.last_loot.is_empty():
		_side.add_child(_loot_section(run))
	if not run.bios_offers.is_empty():
		_side.add_child(_bios_section(run))
	if not run.last_growth.is_empty():
		_side.add_child(_growth_section(run))
	_side.add_child(_shop_section(run))

	# --- Lager ---
	_side.add_child(_label("Lager  %d / %d" % [run.storage.size(), RunState.storage_size()],
		18, COLOR_HEADING))
	if run.storage.is_empty():
		_side.add_child(_label("Leer. Module aus dem Laden landen hier.",
			16, COLOR_MUTED))
	else:
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		_side.add_child(grid)
		for index in run.storage.size():
			grid.add_child(_storage_tile(run, index))
	if run.is_module_at(_selected_storage):
		_side.add_child(_module_card(run, _selected_storage))
	_side.add_child(_recipe_section(run))
	if not run.bag.is_empty():
		_side.add_child(_bag_section(run))

	# --- Squad mit Haltern ---
	_side.add_child(_label("Dein Lauf-Squad  ·  Staerke %d"
		% int(DromeBuild.squad_power(run.squad)), 18, COLOR_HEADING))
	var module_mode := run.is_module_at(_selected_storage)
	if run.is_bios_at(_selected_storage):
		_side.add_child(_label("Chassis-BIOS: tippe einen Halter des passenden DROME an. Rezept-BIOS: im Rezeptbuch verschmelzen.",
			16, COLOR_MUTED))
	elif module_mode:
		_side.add_child(_label("Tippe einen Halter an, um das Modul einzusetzen.", 16, COLOR_MUTED))
	else:
		_side.add_child(_label("Modul im Halter antippen: zurueck ins Lager. Die Waffen bleiben im Lauf, wie sie sind.",
			16, COLOR_MUTED))
	var options: Array = []
	if run.is_bios_at(_selected_storage):
		options = run.bios_options(_selected_storage)
	elif module_mode:
		options = run.module_options(_selected_storage)
	for drome in run.squad.size():
		_side.add_child(_stop_drome_card(run, drome, options))

	var go := _big_button("Weiter zum naechsten Kampf")
	go.pressed.connect(func():
		_selected_storage = -1
		run.continue_run()
		_refresh())
	_side.add_child(go)


## Die gewuerfelte Beute des letzten Siegs (6i): was es gab und wo es
## gelandet ist. Gewaehlt wird nichts -- es ist schon verteilt.
func _loot_section(run: RunState) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(true))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(_label("Beute", 18, COLOR_GOOD))
	for item in run.last_loot:
		var where: String = {"lager": "  ->  Lager", "squad": "  ->  Lauf-Squad",
			"tasche": "  ->  Tasche (nach dem Lauf in den Hangar)",
			"home": "  ->  nach Hause (kein Platz)"}.get(str(item.get("where", "")), "")
		box.add_child(_label("%s%s%s" % ["[Selten] " if item.get("rare", false) else "",
			item["title"], where], 18, COLOR_WARN if item.get("rare", false) else Color.WHITE))
		box.add_child(_label(str(item.get("text", "")), 16, COLOR_MUTED))
	return panel


## Die BIOS-Wahl nach einem Elite-Sieg (MODULE_KONZEPT.md 6.2): eines von
## drei kommt ins Lager, die anderen verfallen beim Weitergehen.
func _bios_section(run: RunState) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(true))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(_label("Matrix-BIOS -- waehle eines", 18, ModuleData.CLASS_COLOR["bios"]))
	box.add_child(_label("Die anderen verfallen, wenn du weitergehst.", 14, COLOR_MUTED))
	var blocker := run.bios_blocker()
	for index in run.bios_offers.size():
		var item := ModuleData.get_module(run.bios_offers[index])
		if item == null:
			continue
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		box.add_child(head)
		head.add_child(ModuleChip.new(item, 44.0))
		var title := VBoxContainer.new()
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		title.add_child(_label(item.display_name, 18))
		title.add_child(_label(item.headline(), 14, item.color()))
		for line in item.effect_lines():
			box.add_child(_flow_label(line, 16))
		var take := UiKit.button("Nehmen" if blocker == "" else blocker)
		take.disabled = blocker != ""
		take.pressed.connect(func():
			run.choose_bios(index)
			_refresh())
		box.add_child(take)
	return panel


## Erfahrung des letzten Kampfes (Leveling): je DROME und Waffe die neuen EP
## und was der Lauf bisher gesammelt hat -- mit dem Level, das er nach dem
## Lauf haette. Gutgeschrieben wird erst am Ende, zuhause.
func _growth_section(run: RunState) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(false))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	box.add_child(_label("Erfahrung", 18, COLOR_HEADING))
	box.add_child(_label("Wird am Ende des Laufs zuhause gutgeschrieben.", 14, COLOR_MUTED))
	for row in run.last_growth:
		var drome: bool = row["kind"] == "drome"
		var have := 0
		var level := 0
		var total := int((run.pending_xp["dromes" if drome else "weapons"] as Dictionary).get(row["uid"], 0))
		if drome:
			var entry := GameState.roster.entry_by_chassis(str(row["uid"]))
			if entry != null:
				have = entry.xp
				level = entry.level
		else:
			var owned := GameState.roster.instance(str(row["uid"]))
			if owned != null:
				have = owned.xp
				level = owned.level
		var after := Leveling.drome_level_for(have + total) if drome \
			else Leveling.weapon_level_for(have + total)
		var text := "%s  +%d EP  (Lauf %d)  ·  Lv %d%s" % [row["name"], int(row["gain"]), total,
			level, (" -> %d" % after) if after > level else ""]
		box.add_child(_label(text, 16 if drome else 14,
			COLOR_GOOD if after > level else (Color.WHITE if drome else COLOR_MUTED)))
	return panel


## Der Laden (6i): wenige Grundmodule fuer Credits, gekauft wird ins Lager.
## Je Angebot Chip, Name, Wirkung, wofuer es Zutat ist, und der Kaufknopf --
## gesperrt mit Grund (zu wenig Credits, Lager voll, verkauft).
func _shop_section(run: RunState) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_label("Laden", 18, COLOR_HEADING))
	var target := ModuleData.get_module(run.target_recipe)
	if target != null:
		box.add_child(_label("Ziel: %s -- seine fehlenden Zutaten kommen oefter." % target.display_name,
			16, COLOR_GOOD))
	var reroll_block := run.reroll_blocker()
	var reroll := UiKit.button("Neu wuerfeln  %d Credits%s" % [run.reroll_price(),
		"" if reroll_block == "" else " -- " + reroll_block])
	reroll.disabled = reroll_block != ""
	reroll.pressed.connect(func():
		run.reroll_shop()
		_refresh())
	if run.shop_offers.is_empty():
		box.add_child(_label("Heute nichts im Angebot.", 16, COLOR_MUTED))
		box.add_child(reroll)
		return box
	for index in run.shop_offers.size():
		var offer: Dictionary = run.shop_offers[index]
		var module := ModuleData.get_module(offer["module_id"])
		if module == null:
			continue
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _panel_style(false))
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
		_add_module_lines(inner, module)
		var uses := _recipes_using(module)
		if not uses.is_empty():
			inner.add_child(_label("Zutat fuer: %s" % ", ".join(uses), 16, COLOR_MUTED))
		var blocker := run.shop_blocker(index)
		var price := RunState.shop_price(module)
		var buy := UiKit.button("Verkauft" if offer["sold"]
			else ("Kaufen  %d Credits" % price if blocker == ""
			else "%d Credits -- %s" % [price, blocker]))
		buy.disabled = blocker != ""
		buy.pressed.connect(func():
			if run.buy(index):
				_selected_storage = -1
			_refresh())
		inner.add_child(buy)
		box.add_child(panel)
	box.add_child(reroll)
	return box


## Die Tasche (6h): Beute-Waffen dieses Laufs. Sie werden im Lauf nicht
## eingebaut und gehen am Ende in den Hangar.
func _bag_section(run: RunState) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(_label("Tasche  %d" % run.bag.size(), 18, COLOR_HEADING))
	box.add_child(_label("Beute-Waffen gehen nach dem Lauf in den Hangar. Im Lauf bleiben die Waffen fest.",
		16, COLOR_MUTED))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	box.add_child(flow)
	for id in run.bag:
		var part := PartDB.get_part(id)
		if part == null:
			continue
		var tile := VBoxContainer.new()
		var shape := SlotShape.new(part.mount_class, UiKit.part_texture(part), 48.0)
		shape.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tile.add_child(shape)
		tile.add_child(_tile_name(part.display_name))
		flow.add_child(tile)
	return box


## Die Namen der Rezepte, in die dieses Modul als Zutat geht.
func _recipes_using(module: ModuleData) -> Array:
	var out: Array = []
	for recipe in ModuleData.recipes():
		if recipe.from.has(module.id):
			out.append(recipe.display_name)
	return out


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
	box.add_child(_label("BIOS gibt es nur in diesem Lauf." if module.is_bios_item()
		else "Module gibt es nur in diesem Lauf.", 16, COLOR_MUTED))
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
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		inner.add_child(row)
		var make := UiKit.button("Zusammenfuegen" if entry["ready"] else "Zutaten fehlen")
		make.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		make.disabled = not entry["ready"]
		make.pressed.connect(func():
			if run.craft(module.id):
				_selected_storage = -1
			_refresh())
		row.add_child(make)
		if not module.is_bios_result:
			var aimed := run.target_recipe == module.id
			var aim := UiKit.button("Ziel aufheben" if aimed else "Als Ziel")
			aim.tooltip_text = "Der Laden bietet die fehlenden Zutaten oefter an"
			aim.pressed.connect(func():
				run.set_target_recipe(module.id)
				_refresh())
			row.add_child(aim)
		box.add_child(panel)
	return box


## Ein DROME im Zwischenstopp: Bild, Name, und je Halter ein Knopf. Mit
## ausgewaehltem Modul heisst er "hier einsetzen" (oder sagt, warum nicht);
## ohne Auswahl zeigt er nur die Waffe -- sie ist im Lauf fest.
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
	title.add_child(_label("%s  ·  %d%s" % [build.display_name, int(build.power_score()),
		"  ·  BIOS" if build.chassis_bios else ""], 18))
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
			button.disabled = not allowed
			if allowed:
				button.add_theme_stylebox_override("normal", UiKit.card_style(true))
			var bios := run.is_bios_at(_selected_storage)
			button.text = "%s\n%s" % [line, ("BIOS hier einbauen -- %s" if bios else "Modul hier einsetzen -- %s")
				% choice.get("detail", "") if allowed else "geht nicht: %s" % choice.get("detail", "kein Platz")]
			button.pressed.connect(func():
				var done := run.install_bios(_selected_storage, drome, slot) if bios \
					else run.install_module(_selected_storage, drome, slot)
				if done:
					_selected_storage = -1
				_refresh())
		else:
			button.text = line
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
	var room := ModuleData.slots_for(build, slot)
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

	# Die EP des Laufs, jetzt zuhause gutgeschrieben (Leveling).
	for row in run.final_growth:
		var up: bool = row["up"]
		_side.add_child(_label("%s  +%d EP  ·  Level %d%s" % [row["name"], int(row["gain"]),
			int(row["level"]), "  ·  Aufstieg!" if up else ""],
			16 if row["kind"] == "drome" else 14, COLOR_GOOD if up else COLOR_MUTED))

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
