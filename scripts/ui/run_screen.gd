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
## Fester Platz am unteren Rand fuer die Hauptaktion der Phase.
var _footer: VBoxContainer

## Zwischenstopp: der angetippte Lagerplatz (-1 = keiner).
var _selected_storage: int = -1

## Zwischenstopp: Rezeptbuch offen (Popup)? Filter im Rezeptbuch.
var _recipes_open: bool = false
var _recipe_filter: String = "alle"
## Lagerplatz, der kurz aufleuchten soll (frisch gekauft); -1 = keiner.
var _flash_storage: int = -1

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

	# Die Hauptaktion steht fest am unteren Rand (10. Nov. 2026): "Kampf
	# starten" lag vorher unter der Gegnerliste, und man musste in jeder
	# Runde erst dorthin scrollen.
	var frame := _page_frame(content)
	if frame != null:
		var bar := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.09, 0.13, 0.96)
		style.border_color = UiKit.CARD_LINE
		style.border_width_top = 1
		style.set_content_margin_all(UiKit.PAD)
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		bar.add_theme_stylebox_override("panel", style)
		frame.add_child(bar)
		_footer = VBoxContainer.new()
		_footer.add_theme_constant_override("separation", 6)
		bar.add_child(_footer)


## Der Seitenrahmen von UiKit.page (die VBox ueber Kopfzeile und Inhalt).
func _page_frame(content: Control) -> VBoxContainer:
	var node: Node = content.get_parent()
	while node != null and node != self:
		if node is VBoxContainer and node.get_parent() == self:
			return node
		node = node.get_parent()
	return null


## Setzt die Hauptaktion in die Fusszeile (oder, ohne sie, unter den Inhalt).
func _main_action(button: Control) -> void:
	if _footer != null:
		_footer.add_child(button)
		(_footer.get_parent() as Control).visible = true
	else:
		_side.add_child(button)


func _refresh() -> void:
	# Jede Aenderung im Lauf geht gleich in den Spielstand (10. Nov. 2026).
	GameState.save_run()
	var run := _run()
	for child in _side.get_children():
		child.queue_free()
	if _footer != null:
		for child in _footer.get_children():
			child.queue_free()
		(_footer.get_parent() as Control).visible = false
	_lives_box.visible = run != null
	# Im Zwischenstopp steht der Squad mit seinen Haltern oben -- dort wird
	# eingebaut. Die Liste unten waere doppelt.
	_squad_list.visible = run != null and run.phase != RunState.Phase.STOP
	if run == null:
		_header_round.text = "Aufstellung"
		_show_setup()
		return
	if run.is_endless():
		_header_round.text = "Endlos  ·  Runde %d" % run.round
	else:
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
	heading.text = "Dein Lauf-Squad  ·  Kampfwert %d" % int(DromeBuild.squad_power(run.squad))
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
	var endless := GameState.next_run_mode == "endless"
	_header_round.text = "Endlos-Modus" if endless else "Neon City"
	_side.add_child(_label("Wer kommt mit? Vorgeschlagen ist dein Hangar-Squad. Im Lauf "
		+ "bleiben die Waffen, wie sie sind -- staerker wirst du mit Modulen aus dem Laden.",
		UiKit.SMALL, COLOR_MUTED))
	var picker := SquadPicker.new()
	_side.add_child(picker)
	picker.setup(RunState.squad_max())
	if endless:
		_side.add_child(_label("Kein Ende, ein Leben: die erste Niederlage beendet den Lauf und "
			+ "kostet die Beute. Nach jeder Runde kannst du aussteigen und sie behalten. "
			+ "Ab und zu taucht ein Chaos-Kampf auf -- Gegner unbekannt, bessere Beute.",
			UiKit.SMALL, COLOR_MUTED))
	else:
		_side.add_child(_label("%d Kaempfe, %d Leben. Die ersten %d sind Training gegen normale "
			% [RunState.rounds_total(), RunState.max_lives(),
				int(RunState.cfg().get("training_rounds", 0))]
			+ "DROMEs, danach kommen die Neon Ninja's. Vor jedem Kampf waehlst du: immer ein "
			+ "leichter Gegner, dazu zwei normale oder ein normaler und ein Elite.",
			UiKit.SMALL, COLOR_MUTED))
	var start := _big_button("Lauf starten")
	start.disabled = picker.chosen_count() < 1
	picker.changed.connect(func(): start.disabled = picker.chosen_count() < 1)
	start.pressed.connect(func():
		GameState.start_run(0, GameState.next_run_mode)
		_refresh())
	_main_action(start)


func _show_prepare(run: RunState) -> void:
	_side.add_child(_label("Waehle deinen Gegner", 22, COLOR_HEADING))
	# Die Knoten dieser Runde, darunter die Reihe, die danach kaeme.
	var map := MapView.new(run)
	map.picked.connect(func(index: int):
		if run.choose_node(index):
			Accessibility.vibrate(15, true)
		_refresh())
	_side.add_child(map)

	var info := run.preview()
	var chaos := bool(info.get("chaos", false))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(true))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_side.add_child(panel)

	# Wer: Stufe, Team und Gegnertyp -- der Typ sagt, was auf einen zukommt.
	var tier_color: Color = MapView.CHAOS_COLOR if chaos else MapView.COLOR.get(run.tier, Color.WHITE)
	if chaos:
		box.add_child(_label("CHAOS-Kampf", 20, tier_color))
		box.add_child(_label("Der Virus wuerfelt alles: DROMEs, Waffen, Module. Gegner erst im "
			+ "Kampf zu sehen.", 14, COLOR_MUTED))
	else:
		box.add_child(_label("%s  ·  %s" % [RunState.TIER_NAMES[run.tier], info["team"]], 20, tier_color))
		if str(info.get("type", "")) != "":
			box.add_child(_label("Gegnertyp: %s" % info["type"], 16, COLOR_WARN))
		if str(info.get("team_text", "")) != "":
			box.add_child(_label(str(info["team_text"]), 14))
		if str(info.get("type_hint", "")) != "":
			box.add_child(_label(str(info["type_hint"]), 14, COLOR_MUTED))
	var where := str(info["region"])
	if str(info.get("faction", "")) != "" and not chaos:
		where += "  ·  %s" % info["faction"]
	box.add_child(_label(where, 14, COLOR_MUTED))

	var own := float(info["own_power"])
	var foe := float(info["enemy_power"])
	var ratio := own / maxf(1.0, foe)
	var verdict := "ueberlegen" if ratio >= 1.1 else ("ausgeglichen" if ratio >= 0.9 else "unterlegen")
	var color := COLOR_GOOD if ratio >= 1.1 else (COLOR_WARN if ratio >= 0.9 else COLOR_BAD)
	if chaos:
		box.add_child(_label("Kampfwert: du %d  ·  Gegner ???" % int(own), 16, COLOR_WARN))
	else:
		box.add_child(_label("Kampfwert: du %d  ·  Gegner %d  (%s)" % [int(own), int(foe), verdict],
			16, color))
	box.add_child(_label("Beute: %s" % info["reward_text"], 14,
		COLOR_WARN if run.tier == RunState.Tier.ELITE or chaos else COLOR_MUTED))

	if not chaos:
		for build in info["enemy_builds"]:
			box.add_child(SquadPicker.drome_card(build))

	var start := _big_button("Kampf starten")
	start.pressed.connect(func():
		GameState.begin_run_battle()
		get_tree().change_scene_to_file("res://scenes/battle.tscn"))
	_main_action(start)
	start.grab_focus.call_deferred()

	var abandon := Button.new()
	abandon.text = "Aussteigen und Beute behalten" if run.is_endless() else "Lauf aufgeben"
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

## Nach jedem Kampf (seit 14. Nov. 2026 ohne langes Scrollen, Wunsch des
## Spielers): oben Credits und Chips (Beute, Erfahrung, Tasche), dann Laden,
## Lager und Squad als Kacheln. Einmal tippen waehlt oder handelt, doppelt
## tippen oder lange druecken erklaert (Tile, InfoPopup). Das Rezeptbuch
## ist ein Popup mit Raster.
##
## Bedienung: Modul im Lager antippen, dann einen leuchtenden Platz an einem
## Halter -- oder das Modul dorthin ziehen. Ein eingesetztes Modul antippen:
## Popup mit "Zurueck ins Lager".
func _show_stop(run: RunState) -> void:
	if _selected_storage >= run.storage.size():
		_selected_storage = -1
	_side.add_child(_stop_status(run))
	if not run.bios_offers.is_empty():
		_side.add_child(_bios_row(run))

	# --- Laden ---
	var reroll_block := run.reroll_blocker()
	var reroll := _small_button("↻  %d ¢" % run.reroll_price())
	reroll.tooltip_text = "Neu würfeln" + ("" if reroll_block == "" else ": " + reroll_block)
	reroll.disabled = reroll_block != ""
	reroll.pressed.connect(func():
		run.reroll_shop()
		_refresh())
	var target := ModuleData.get_module(run.target_recipe)
	_side.add_child(_section_head("Laden" + ("  ·  Ziel: %s" % target.display_name
		if target != null else ""), reroll))
	_side.add_child(_shop_row(run))

	# --- Lager ---
	var book := run.recipe_book()
	var ready := book.filter(func(entry): return entry["ready"]).size()
	var recipes := _small_button("Rezepte%s" % (("  ·  %d bereit" % ready) if ready > 0 else ""))
	if ready > 0:
		recipes.add_theme_color_override("font_color", COLOR_GOOD)
	recipes.pressed.connect(func(): _open_recipes(run))
	_side.add_child(_section_head("Lager  %d / %d" % [run.storage.size(), RunState.storage_size()],
		recipes))
	_side.add_child(_storage_grid(run))
	if run.is_bios_at(_selected_storage):
		_side.add_child(_label("BIOS: tippe einen leuchtenden Halter an.", UiKit.SMALL, COLOR_GOOD))
	elif run.is_module_at(_selected_storage):
		_side.add_child(_label("Leuchtenden Platz antippen  ·  Doppeltipp: Details",
			UiKit.SMALL, COLOR_GOOD))

	# --- Squad mit Haltern ---
	_side.add_child(_section_head("Squad  ·  Kampfwert %d" % int(DromeBuild.squad_power(run.squad))))
	var options: Array = []
	if run.is_bios_at(_selected_storage):
		options = run.bios_options(_selected_storage)
	elif run.is_module_at(_selected_storage):
		options = run.module_options(_selected_storage)
	for drome in run.squad.size():
		_side.add_child(_squad_row(run, drome, options))

	var go := _big_button("Weiter zum nächsten Kampf")
	go.pressed.connect(func():
		_selected_storage = -1
		InfoPopup.close_all(self)
		run.continue_run()
		_refresh())
	# Infinity-Einsatz: nach jedem Kampf aussteigen und die Beute behalten.
	if run.is_endless():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var out := UiKit.button("Aussteigen")
		out.size_flags_stretch_ratio = 0.5
		out.pressed.connect(func():
			_selected_storage = -1
			run.cash_out()
			_refresh())
		row.add_child(out)
		row.add_child(go)
		_main_action(row)
	else:
		_main_action(go)
	if _recipes_open:
		_open_recipes.call_deferred(run)


## Kopfzeile eines Abschnitts: Etikett links, optional ein kleiner Knopf rechts.
func _section_head(text: String, extra: Control = null) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := _label(text.to_upper(), 14, COLOR_HEADING)
	label.add_theme_font_override("font", Arcade.font("bold", 14, 0.14))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(label)
	if extra != null:
		row.add_child(extra)
	return row


func _small_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(Accessibility.tap)
	return button


## Credits, Ausgang des Kampfs und Chips fuer Beute, Erfahrung und Tasche --
## jeder Chip oeffnet sein Popup.
func _stop_status(run: RunState) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	var last: Dictionary = run.history[-1] if not run.history.is_empty() else {}
	var lost: bool = not last.is_empty() and not bool(last["won"])
	var credits := "¢ %d" % run.credits
	if not last.is_empty():
		credits += "   +%d" % int(last.get("credits", 0))
	flow.add_child(_chip(credits, COLOR_WARN, Callable(), "Credits: Währung des Ladens. "
		+ ("+%d für den Sieg." % int(last.get("credits", 0)) if not lost else "Trostgeld nach der Niederlage.")))
	if lost:
		flow.add_child(_chip("Niederlage  ·  −1 Leben", COLOR_BAD, Callable(), ""))
	if not run.last_loot.is_empty():
		flow.add_child(_chip("Beute ▸", COLOR_GOOD, func(): _loot_popup(run), ""))
	if not run.last_growth.is_empty():
		flow.add_child(_chip("Erfahrung ▸", COLOR_HEADING, func(): _growth_popup(run), ""))
	if not run.bag.is_empty():
		flow.add_child(_chip("Tasche %d ▸" % run.bag.size(), COLOR_MUTED, func(): _bag_popup(run), ""))
	return flow


## Kleiner Chip mit Rahmen in seiner Farbe. Mit ``on_tap`` ein Knopf.
func _chip(text: String, color: Color, on_tap: Callable, tip: String) -> Control:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(0, 38)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_font_override("font", Arcade.font("bold", 15, 0.04))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_disabled_color"]:
		button.add_theme_color_override(state, color)
	var box := Arcade.chamfer_box(Color(UiKit.BG, 0.85), 8, Color(color, 0.8), 2)
	box.content_margin_left = 12
	box.content_margin_right = 12
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, box)
	if on_tap.is_valid():
		button.pressed.connect(on_tap)
	else:
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.focus_mode = Control.FOCUS_NONE
	return button


## Die gewuerfelte Beute des letzten Siegs (6i): was es gab und wo es
## gelandet ist. Gewaehlt wird nichts -- es ist schon verteilt.
func _loot_popup(run: RunState) -> void:
	var lines: Array = []
	for item in run.last_loot:
		var where: String = {"lager": "  →  Lager", "squad": "  →  Squad",
			"tasche": "  →  Tasche (nach dem Einsatz in den Hangar)",
			"home": "  →  nach Hause"}.get(str(item.get("where", "")), "")
		lines.append(["%s%s%s" % ["[Selten] " if item.get("rare", false) else "", item["title"], where],
			COLOR_WARN if item.get("rare", false) else Color.WHITE])
		if str(item.get("text", "")) != "":
			lines.append([str(item["text"]), COLOR_MUTED, UiKit.SMALL])
	InfoPopup.open(self, "Beute", {"lines": lines})


## Erfahrung des letzten Kampfes (Leveling): je DROME und Waffe die neuen EP
## und was der Einsatz bisher gesammelt hat -- mit dem Level, das er danach
## haette. Gutgeschrieben wird erst am Ende, zuhause.
func _growth_popup(run: RunState) -> void:
	var lines: Array = [["Wird am Ende des Einsatzes zuhause gutgeschrieben.", COLOR_MUTED, UiKit.SMALL]]
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
		lines.append(["%s  +%d EP  ·  Lv %d%s" % [row["name"], int(row["gain"]), level,
			(" → %d" % after) if after > level else ""],
			COLOR_GOOD if after > level else (Color.WHITE if drome else COLOR_MUTED),
			UiKit.BODY - 1 if drome else UiKit.SMALL])
	InfoPopup.open(self, "Erfahrung", {"lines": lines})


## Die Tasche (6h): Beute-Waffen dieses Einsatzes. Sie werden im Einsatz nicht
## eingebaut und gehen am Ende in den Hangar.
func _bag_popup(run: RunState) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for id in run.bag:
		var part := PartDB.get_part(id)
		if part == null:
			continue
		flow.add_child(Tile.new("", SlotShape.new(part.mount_class, UiKit.part_texture(part), 44.0),
			part.display_name, Vector2(84, 80)))
	InfoPopup.open(self, "Tasche", {"body": flow, "lines": [["Beute-Waffen gehen nach dem "
		+ "Einsatz in den Hangar. Im Einsatz bleiben die Waffen fest.", COLOR_MUTED, UiKit.SMALL]]})


## Die BIOS-Wahl nach einem Elite-Sieg (MODULE_KONZEPT.md 6.2): drei Kacheln,
## Antippen zeigt das BIOS mit "Nehmen".
func _bios_row(run: RunState) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_section_head("Matrix-BIOS  ·  wähle eines"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var blocker := run.bios_blocker()
	for index in run.bios_offers.size():
		var item := ModuleData.get_module(run.bios_offers[index])
		if item == null:
			continue
		var tile := Tile.new("bios:%d" % index, ModuleChip.new(item, 44.0), item.display_name,
			Vector2(0, 84))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.accent = ModuleData.CLASS_COLOR["bios"]
		tile.glow = true
		tile.on_info = func():
			InfoPopup.open(self, item.display_name, {"subtitle": item.headline(),
				"subtitle_color": item.color(), "picture": ModuleChip.new(item, 52.0),
				"lines": item.effect_lines() + [["Die anderen verfallen, wenn du weitergehst.",
					COLOR_MUTED, UiKit.SMALL]],
				"actions": [{"text": "Nehmen", "primary": true, "disabled": blocker != "",
					"why": blocker, "call": func():
						if run.choose_bios(index):
							Accessibility.vibrate(30, true)
						_refresh()}]})
		row.add_child(tile)
	return box


## Der Laden (6i): drei Kacheln. Unten an jeder der Preis als Knopf -- er
## kauft sofort. Die Kachel selbst oeffnet das Popup mit allem Weiteren.
func _shop_row(run: RunState) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if run.shop_offers.is_empty():
		row.add_child(_label("Heute nichts im Angebot.", UiKit.SMALL, COLOR_MUTED))
		return row
	for index in run.shop_offers.size():
		var offer: Dictionary = run.shop_offers[index]
		var module := ModuleData.get_module(offer["module_id"])
		if module == null:
			continue
		var blocker := run.shop_blocker(index)
		var price := RunState.shop_price(module)
		var holder := VBoxContainer.new()
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_theme_constant_override("separation", 0)
		row.add_child(holder)
		var tile := Tile.new("shop:%d:%s" % [index, module.id], ModuleChip.new(module, 40.0),
			module.display_name, Vector2(0, 72))
		tile.accent = module.color()
		tile.dimmed = bool(offer["sold"])
		tile.glow = run.target_recipe != &"" and _recipe_wants(run, module)
		tile.on_info = func(): _module_popup(run, module, -1, index)
		holder.add_child(tile)
		var buy := Button.new()
		buy.text = "verkauft" if offer["sold"] else "%d ¢" % price
		buy.custom_minimum_size = Vector2(0, 40)
		buy.add_theme_font_override("font", Arcade.font("display", 15, 0.04))
		buy.add_theme_font_size_override("font_size", 15)
		buy.disabled = blocker != ""
		buy.tooltip_text = blocker
		var fill := UiKit.PRIMARY if blocker == "" else Color(UiKit.CARD_LINE, 0.6)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var box := Arcade.chamfer_box(fill.darkened(0.15) if state == "pressed" else fill, 8)
			box.content_margin_top = 4
			box.content_margin_bottom = 4
			buy.add_theme_stylebox_override(state, box)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			buy.add_theme_color_override(state, UiKit.ON_PRIMARY)
		buy.add_theme_color_override("font_disabled_color", Color(UiKit.TEXT, 0.6))
		buy.pressed.connect(func():
			if run.buy(index):
				Accessibility.vibrate(20, true)
				_selected_storage = -1
				_flash_storage = run.storage.size() - 1
			_refresh())
		holder.add_child(buy)
	return row


## Braucht das Zielrezept dieses Modul noch?
func _recipe_wants(run: RunState, module: ModuleData) -> bool:
	var target := ModuleData.get_module(run.target_recipe)
	return target != null and target.from.has(module.id)


## Popup zu einem Modul: Wirkung, Zutat fuer, und je nach Herkunft Kaufen
## (shop_index) oder Verkaufen (storage_index).
func _module_popup(run: RunState, module: ModuleData, storage_index: int = -1,
		shop_index: int = -1) -> void:
	var lines := _module_lines(module)
	var uses := _recipes_using(module)
	if not uses.is_empty():
		lines.append(["Zutat für: %s" % ", ".join(uses), COLOR_MUTED, UiKit.SMALL])
	var actions: Array = []
	if shop_index >= 0:
		var offer: Dictionary = run.shop_offers[shop_index]
		var blocker := run.shop_blocker(shop_index)
		actions.append({"text": "Verkauft" if offer["sold"] else "Kaufen  %d ¢" % RunState.shop_price(module),
			"primary": true, "disabled": blocker != "", "why": "" if offer["sold"] else blocker,
			"call": func():
				if run.buy(shop_index):
					Accessibility.vibrate(20, true)
					_selected_storage = -1
					_flash_storage = run.storage.size() - 1
				_refresh()})
	elif storage_index >= 0:
		lines.append([("BIOS" if module.is_bios_item() else "Module")
			+ " gibt es nur in diesem Einsatz.", COLOR_MUTED, UiKit.SMALL])
		actions.append({"text": "Verkaufen  +%d ¢" % ModuleData.sell_value(module), "call": func():
			run.sell(storage_index)
			_selected_storage = -1
			_refresh()})
		if run.is_module_at(storage_index) or run.is_bios_at(storage_index):
			actions.append({"text": "Einsetzen", "primary": true, "call": func():
				_selected_storage = storage_index
				_refresh()})
	InfoPopup.open(self, module.display_name, {"subtitle": module.headline(),
		"subtitle_color": module.color(), "picture": ModuleChip.new(module, 52.0),
		"lines": lines, "actions": actions})


## Wirkung eines Moduls als Zeilen; beim Rezept die Summe und darunter der
## eigene Effekt.
func _module_lines(module: ModuleData) -> Array:
	var out: Array = []
	if module.is_recipe():
		var own := module.bonus_lines()
		var summed := module.effect_lines(_without(module.effects, module.bonus))
		if not summed.is_empty():
			out.append("Summe: %s" % ", ".join(summed))
		if not own.is_empty():
			out.append(["Dazu: %s" % ", ".join(own), COLOR_GOOD])
	else:
		for line in module.effect_lines():
			out.append(line)
	return out


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


## Die Namen der Rezepte, in die dieses Modul als Zutat geht.
func _recipes_using(module: ModuleData) -> Array:
	var out: Array = []
	for recipe in ModuleData.recipes():
		if recipe.from.has(module.id):
			out.append(recipe.display_name)
	return out


## Das Lager als Raster aus festen Plaetzen: belegte als Kachel, freie
## gestrichelt -- so sieht man auf einen Blick, wie viel Platz bleibt.
func _storage_grid(run: RunState) -> Control:
	var grid := GridContainer.new()
	grid.columns = 4 if RunState.storage_size() <= 8 else 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for index in RunState.storage_size():
		if index < run.storage.size():
			grid.add_child(_storage_tile(run, index))
		else:
			var free := Tile.new("", null, "", Vector2(0, 64))
			free.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			free.empty = true
			free.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(free)
	_flash_storage = -1
	return grid


## Eine Lager-Kachel: einmal tippen waehlt zum Einsetzen, doppelt tippen
## oder lange druecken zeigt das Popup. Waagerecht ziehen setzt direkt ein.
func _storage_tile(run: RunState, index: int) -> Control:
	var id: StringName = run.storage[index]
	var module := ModuleData.get_module(id)
	var part := PartDB.get_part(id)
	var tile: Tile
	if module != null:
		tile = Tile.new("store:%d:%s" % [index, id], ModuleChip.new(module, 36.0),
			module.display_name, Vector2(0, 64))
		tile.accent = module.color()
		tile.on_tap = func():
			_selected_storage = -1 if _selected_storage == index else index
			_refresh()
		tile.on_info = func(): _module_popup(run, module, index)
	else:
		tile = Tile.new("store:%d:%s" % [index, id],
			SlotShape.new(part.mount_class if part != null else "light",
				UiKit.part_texture(part), 36.0),
			part.display_name if part != null else str(id), Vector2(0, 64))
		tile.on_info = func():
			if part != null:
				WeaponCard.open(self, part)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.selected = index == _selected_storage
	if index == _flash_storage:
		_flash(tile)
	# Ziehen auf einen Halter (Tippen bleibt); waagerecht startet den Zug.
	var start := {"at": Vector2.ZERO}
	tile.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			start["at"] = event.global_position)
	tile.set_drag_forwarding(func(_at):
		if not run.is_module_at(index) and not run.is_bios_at(index):
			return null
		var moved: Vector2 = tile.get_global_mouse_position() - start["at"]
		if absf(moved.y) > absf(moved.x):
			return null
		var preview := ModuleChip.new(ModuleData.get_module(run.storage[index]), 56.0)
		tile.set_drag_preview(preview)
		return {"kind": "storage", "index": index},
		Callable(), Callable())
	return tile


## Kurzes Aufleuchten (frisch gekauft, eingesetzt).
func _flash(control: Control) -> void:
	if Accessibility.motion() <= 0.0:
		return
	control.modulate = Color(2.2, 2.2, 1.4)
	var tween := control.create_tween()
	tween.tween_property(control, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_QUAD)


## Ein DROME im Zwischenstopp, kompakt in einer Zeile: Bild, Name und je
## Halter die Waffe plus seine Modulplaetze. Mit gewaehltem Lager-Modul
## leuchten die Plaetze, die es nehmen.
func _squad_row(run: RunState, drome: int, options: Array) -> Control:
	var build: DromeBuild = run.squad[drome]
	var panel := PanelContainer.new()
	var style := UiKit.card_style(false)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var face := VBoxContainer.new()
	face.add_theme_constant_override("separation", 0)
	face.custom_minimum_size = Vector2(64, 0)
	row.add_child(face)
	var view := UiKit.drome_view(build, 40)
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	face.add_child(view)
	var name := _flow_label(build.display_name, 12)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.add_child(name)
	var power := _flow_label("KW %d%s" % [int(build.power_score()), " · BIOS" if build.chassis_bios else ""],
		11, COLOR_MUTED)
	power.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.add_child(power)

	var holders := VBoxContainer.new()
	holders.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holders.add_theme_constant_override("separation", 4)
	row.add_child(holders)
	if build.equipment().is_empty():
		holders.add_child(_label("ohne Waffe -- kämpft nicht mit", UiKit.SMALL, COLOR_BAD))
	var bios := run.is_bios_at(_selected_storage)
	var picking := bios or run.is_module_at(_selected_storage)
	for slot in build.equip_slots():
		var choice: Dictionary = {}
		for entry in options:
			if int(entry["drome"]) == drome and entry["slot"] == slot:
				choice = entry
		var allowed := picking and bool(choice.get("allowed", false))
		holders.add_child(_holder_row(run, drome, slot, picking, allowed, bios,
			str(choice.get("detail", "kein Platz"))))
	return panel


## Ein Halter: Waffe als Form, dann die Modulplaetze. Leere Plaetze nehmen
## das gewaehlte Modul; ein Modul antippen zeigt es mit "Zurueck ins Lager".
func _holder_row(run: RunState, drome: int, slot: String, picking: bool, allowed: bool,
		bios: bool, detail: String) -> Control:
	var build: DromeBuild = run.squad[drome]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var part := build.part_in(slot)
	var weapon := Tile.new("weapon:%d:%s" % [drome, slot],
		SlotShape.new(SlotRules.slot_class(build.body(), slot), UiKit.part_texture(part), 34.0),
		"", Vector2(46, 46))
	weapon.tooltip_text = part.display_name if part != null else "leer"
	weapon.on_info = func():
		if part != null:
			WeaponCard.open(self, part)
	if picking:
		weapon.glow = allowed and bios
		weapon.dimmed = not allowed
		if bios and allowed:
			weapon.on_tap = func(): _install(run, drome, slot)
	row.add_child(weapon)

	var installed := build.modules_in(slot)
	var room := ModuleData.slots_for(build, slot)
	for position in maxi(room, installed.size()):
		var tile: Tile
		if position < installed.size():
			var module: ModuleData = installed[position]
			var resting := module.blocker(part)
			var chip := ModuleChip.new(module, 32.0)
			chip.dim = resting != ""
			tile = Tile.new("mod:%d:%s:%d" % [drome, slot, position], chip, "", Vector2(44, 46))
			tile.accent = module.color()
			tile.on_info = func(): _installed_popup(run, drome, slot, position, module, resting)
			if picking:
				tile.dimmed = true
		else:
			tile = Tile.new("free:%d:%s:%d" % [drome, slot, position], null, "", Vector2(44, 46))
			tile.empty = not (picking and allowed and not bios)
			if picking and allowed and not bios:
				tile.glow = true
				tile.accent = COLOR_GOOD
				tile.on_tap = func(): _install(run, drome, slot)
			elif picking and not bios:
				tile.on_tap = func():
					InfoPopup.open(self, "Geht nicht", {"lines": [detail]})
		row.add_child(tile)
	var name := _flow_label(part.display_name if part != null else "leer", 12, COLOR_MUTED)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name)
	# Ziehen (10. Nov. 2026): ein Modul oder BIOS aus dem Lager hierher.
	row.set_drag_forwarding(Callable(),
		func(_at, data): return _can_drop_storage(run, drome, slot, data),
		func(_at, data): _drop_storage(run, drome, slot, data))
	return row


func _install(run: RunState, drome: int, slot: String) -> void:
	var done := run.install_bios(_selected_storage, drome, slot) if run.is_bios_at(_selected_storage) \
		else run.install_module(_selected_storage, drome, slot)
	if done:
		Accessibility.vibrate(20, true)
		_selected_storage = -1
	_refresh()


func _installed_popup(run: RunState, drome: int, slot: String, position: int,
		module: ModuleData, resting: String) -> void:
	var lines := _module_lines(module)
	if resting != "":
		lines.append(["ruht: %s" % resting, COLOR_BAD])
	var full := run.storage_full()
	InfoPopup.open(self, module.display_name, {"subtitle": module.headline(),
		"subtitle_color": module.color(), "picture": ModuleChip.new(module, 52.0),
		"lines": lines, "actions": [{"text": "Zurück ins Lager", "disabled": full,
			"why": "Lager voll", "call": func():
				run.remove_module(drome, slot, position)
				_refresh()}]})


## Darf das gezogene Lager-Stueck in diesen Halter? Dieselben Regeln wie beim
## Antippen (module_options / bios_options).
func _can_drop_storage(run: RunState, drome: int, slot: String, data) -> bool:
	if not data is Dictionary or data.get("kind", "") != "storage":
		return false
	var index := int(data.get("index", -1))
	var options: Array = run.bios_options(index) if run.is_bios_at(index) \
		else run.module_options(index)
	for entry in options:
		if int(entry["drome"]) == drome and entry["slot"] == slot:
			return bool(entry.get("allowed", false))
	return false


func _drop_storage(run: RunState, drome: int, slot: String, data) -> void:
	var index := int(data.get("index", -1))
	var done := run.install_bios(index, drome, slot) if run.is_bios_at(index) \
		else run.install_module(index, drome, slot)
	if done:
		Accessibility.vibrate(20, true)
		_selected_storage = -1
	_refresh()


# ---------------------------------------------------------------------------
# Rezeptbuch (14. Nov. 2026 als Popup mit Raster)
# ---------------------------------------------------------------------------

## Das Rezeptbuch: oben ein Filter, darunter alle Rezepte als Kacheln.
## Leuchtend = bereit, zwei Punkte zeigen die Zutaten (gruen = im Lager),
## gelber Rahmen = Ziel. Antippen zeigt das Rezept mit Zusammenfuegen.
func _open_recipes(run: RunState) -> void:
	if run == null or run.phase != RunState.Phase.STOP:
		return
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	body.add_child(filters)
	var book := run.recipe_book()
	for spec in [["alle", "Alle"], ["bereit", "Bereit"], ["angefangen", "Angefangen"]]:
		var button := _small_button(spec[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_pressed = _recipe_filter == spec[0]
		if _recipe_filter == spec[0]:
			button.add_theme_stylebox_override("normal", UiKit.card_style(true))
			button.add_theme_stylebox_override("pressed", UiKit.card_style(true))
		var which: String = spec[0]
		button.pressed.connect(func():
			_recipe_filter = which
			_open_recipes(run))
		filters.add_child(button)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	var shown := 0
	for entry in book:
		var have: Array = entry["have"]
		if _recipe_filter == "bereit" and not entry["ready"]:
			continue
		if _recipe_filter == "angefangen" and not have.has(true):
			continue
		grid.add_child(_recipe_tile(run, entry))
		shown += 1
	if shown == 0:
		body.add_child(_label("Nichts in dieser Auswahl.", UiKit.SMALL, COLOR_MUTED))
	body.add_child(_label("Zwei Zutaten aus dem Lager ergeben ein neues Modul: die Summe ihrer "
		+ "Werte und ein eigener Effekt.", 13, COLOR_MUTED))
	_recipes_open = true
	var popup := InfoPopup.open(self, "Rezeptbuch", {"body": body})
	popup.closed.connect(func(): _recipes_open = false)


func _recipe_tile(run: RunState, entry: Dictionary) -> Control:
	var module: ModuleData = entry["module"]
	var tile := Tile.new("recipe:%s" % module.id, ModuleChip.new(module, 36.0),
		module.display_name, Vector2(0, 82))
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.accent = COLOR_GOOD if entry["ready"] else (UiKit.PRIMARY if run.target_recipe == module.id
		else module.color())
	tile.glow = entry["ready"] or run.target_recipe == module.id
	var dots := HBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 4)
	for have in entry["have"]:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.color = COLOR_GOOD if have else Color(UiKit.MUTED, 0.35)
		dots.add_child(dot)
	tile.add_extra(dots)
	if not entry["ready"] and not (entry["have"] as Array).has(true):
		tile.modulate = Color(1, 1, 1, 0.6)
	tile.on_info = func(): _recipe_popup(run, entry)
	return tile


func _recipe_popup(run: RunState, entry: Dictionary) -> void:
	var module: ModuleData = entry["module"]
	var parts := HFlowContainer.new()
	parts.add_theme_constant_override("h_separation", 8)
	parts.add_theme_constant_override("v_separation", 6)
	for i in module.from.size():
		var ingredient := ModuleData.get_module(module.from[i])
		var have: bool = entry["have"][i]
		var piece := HBoxContainer.new()
		piece.add_theme_constant_override("separation", 4)
		if ingredient != null:
			piece.add_child(ModuleChip.new(ingredient, 30.0))
		piece.add_child(_flow_label("%s%s" % [ingredient.display_name if ingredient != null
			else str(module.from[i]), "  ✓" if have else ""], 15, COLOR_GOOD if have else COLOR_MUTED))
		parts.add_child(piece)
	var lines: Array = [parts]
	lines.append_array(_module_lines(module))
	var actions: Array = [{"text": "Zusammenfügen", "primary": true, "disabled": not entry["ready"],
		"why": "Zutaten fehlen", "call": func():
			if run.craft(module.id):
				Accessibility.vibrate(40, true)
				_selected_storage = -1
				_flash_storage = -2
			_recipes_open = true
			_refresh()}]
	if not module.is_bios_result:
		var aimed := run.target_recipe == module.id
		actions.append({"text": "Ziel aufheben" if aimed else "Als Ziel", "call": func():
			run.set_target_recipe(module.id)
			_recipes_open = true
			_refresh()})
	actions.append({"text": "◂ Rezeptbuch", "call": func(): _open_recipes(run)})
	InfoPopup.open(self, module.display_name, {"subtitle": module.headline(),
		"subtitle_color": module.color(), "picture": ModuleChip.new(module, 52.0),
		"lines": lines, "actions": actions})


func _show_end(run: RunState) -> void:
	# Die Beute, die noch im Lauf war, geht jetzt nach Hause (7f).
	_delivered.append_array(GameState.deliver_run_home())
	var won := run.phase == RunState.Phase.WON
	var wins := run.wins()
	if run.is_endless():
		_side.add_child(_label("Ausgestiegen nach %d Siegen" % wins if won
			else "Gefallen in Runde %d" % run.round, 28, COLOR_GOOD if won else COLOR_BAD))
		_side.add_child(_label("Die Beute kommt mit nach Hause." if won
			else "Die Beute dieses Laufs ist verloren -- was zuhause liegt, ist sicher.", 16,
			COLOR_MUTED))
	else:
		_side.add_child(_label("Lauf gewonnen!" if won else "Lauf verloren.", 30,
			COLOR_GOOD if won else COLOR_BAD))
		if won and GameState.just_unlocked_endless:
			_side.add_child(_label("Neon City ist bezwungen -- der Endlos-Modus ist frei.", 18, COLOR_WARN))
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
	_main_action(again)
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
