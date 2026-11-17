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
var _title_holder: HBoxContainer
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
## Waffe "drome:slot", deren Feld kurz aufleuchten soll (frisch eingesetzt).
var _flash_holder: String = ""
## Hoehe der Lager-Kacheln (zwei Reihen, ohne Namen).
const STORE_EDGE := 52.0
## Module sind im Lager und im Waffenhalter gleich gross (Wunsch des Spielers,
## 17. Nov. 2026; mehr passt nicht, sonst sprengen drei Plaetze die Kachel).
const MODULE_EDGE := 30.0
## Zwischenstopp: die Waffenfelder und Lager-Kacheln des aktuellen Aufbaus
## (fuer Leuchten und Ziehen ohne Neuaufbau), die Hinweiszeile.
var _holders: Array = []
var _stores: Array = []
var _hint: Label
## Laufender Zug aus dem Lager (-1 = keiner), ob er abgelegt wurde, das Ziel
## unter dem Finger und das Hinweis-Schild.
var _drag_index: int = -1
var _dropped: bool = false
## Wird gerade ein Modul aus einem Halter gezogen: {drome, slot, position, chip}.
var _holder_drag: Dictionary = {}
var _hover_key: String = ""
var _pointer := Vector2.ZERO
var _tip: PanelContainer
var _tip_label: Label
## Die Rezepte, die das Rezeptbuch gerade zeigt (Reihenfolge zum Blaettern).
var _recipe_shown: Array = []

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
	var content := UiKit.page(self, "", "res://scenes/main.tscn", -1, true)

	# Kopf (Entwurf 15. Nov. 2026): Glitch-Titel "NEON CITY · KAMPF 3/8" in
	# der Kopfzeile, darunter die Leiste Leben, Credits, Caches, Verstaerkung.
	_title_holder = HBoxContainer.new()
	var row: HBoxContainer = get_meta("header_row") if has_meta("header_row") else null
	if row != null:
		row.add_child(_title_holder)
		row.move_child(_title_holder, 1)
	else:
		content.add_child(_title_holder)
	_header_round = Label.new()
	_header_round.visible = false
	content.add_child(_header_round)
	_lives_box = HBoxContainer.new()
	_lives_box.add_theme_constant_override("separation", 6)
	content.add_child(_lives_box)

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
	_holders.clear()
	_stores.clear()
	_hint = null
	UiKit.clear(_side)
	if _footer != null:
		UiKit.clear(_footer)
		(_footer.get_parent() as Control).visible = false
	_lives_box.visible = run != null
	# Im Zwischenstopp steht der Squad mit seinen Haltern oben -- dort wird
	# eingebaut. Die Liste unten waere doppelt.
	_squad_list.visible = run != null and run.phase == RunState.Phase.PREPARE
	if run == null:
		_header_round.text = "Aufstellung"
		_set_title("Infinity-Einsatz" if GameState.next_run_mode == "endless" else "Neon City")
		_show_setup()
		return
	if run.is_endless():
		_header_round.text = "Infinity · Kampf %d" % run.round
	else:
		_header_round.text = "%s · Kampf %d/%d" % [_region_name(run), mini(run.round, RunState.rounds_total()),
			RunState.rounds_total()]
	if run.phase == RunState.Phase.STOP:
		# Eine Zeile statt Titel und Leiste (16. Nov. 2026).
		_set_title("")
		_title_holder.add_child(_stop_hud(run))
	elif run.phase == RunState.Phase.PREPARE:
		_set_title(_header_round.text)
	else:
		_set_title("")
	_lives_box.visible = run.phase == RunState.Phase.PREPARE
	_refresh_lives(run)
	_refresh_squad(run)
	match run.phase:
		RunState.Phase.PREPARE: _show_prepare(run)
		RunState.Phase.STOP: _show_stop(run)
		_: _show_end(run)


## Der Glitch-Titel in der Kopfzeile (leer = keiner).
func _set_title(text: String) -> void:
	UiKit.clear(_title_holder)
	if text == "":
		return
	var logo := Arcade.GlitchLogo.new(text.to_upper(), 17, 4.0, [
		[0.0, Vector2(-1.5, 0), Vector2(1.5, 0)],
		[0.92, Vector2(-4, 1), Vector2(4, -1)],
		[0.94, Vector2(3, -1), Vector2(-3, 1)]], 1.5)
	var tilted := Arcade.tilt(logo, -2.0)
	tilted.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title_holder.add_child(tilted)


func _region_name(run: RunState) -> String:
	var region := TerrainDB.get_region(run.region_id)
	return region.display_name if region != null else "Neon City"


## Die Leiste unter dem Titel (Entwurf): LEBEN als Herzen, CREDITS,
## CACHES dieses Einsatzes und die VERSTAERKUNG. Herzen UND Zahl im Tooltip --
## die Farbe allein traegt die Information nicht.
func _refresh_lives(run: RunState) -> void:
	UiKit.clear(_lives_box)
	_lives_box.add_theme_constant_override("separation", 4)
	var hearts := Hearts.new(run.lives, run.lives_max())
	hearts.tooltip_text = "Leben: %d von %d" % [run.lives, run.lives_max()]
	_lives_box.add_child(_hud_cell("Leben", hearts))
	var credits := UiIcon.text("credits", "%d" % run.credits, 16, Arcade.CYAN, "display")
	if run.phase == RunState.Phase.STOP and not run.history.is_empty():
		var gain := int(run.history[-1].get("credits", 0))
		if gain > 0:
			credits.add_child(Arcade.label("+%d" % gain, 13, COLOR_GOOD, "bold"))
	_lives_box.add_child(_hud_cell("Credits", credits))
	var caches := 0
	for key in run.run_caches:
		caches += int(run.run_caches[key])
	_lives_box.add_child(_hud_cell("Caches", UiIcon.text("cache", "%d" % caches, 16, Arcade.YELLOW, "display")))
	if not run.is_chaos():
		var level := run.reinforcement()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(Bars.new(level))
		row.add_child(Arcade.label(str(level), 16, Arcade.ORANGE, "display"))
		var cell := _hud_cell("Verstärkung", row)
		cell.tooltip_text = "Verstärkung (Reinforcement): steigt nach jedem Kampf, nach Elite " \
			+ "schneller. Je höher, desto mehr und stärkere Gegner."
		_lives_box.add_child(cell)


func _hud_cell(title: String, value: Control) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	box.add_child(Arcade.label(title.to_upper(), 11, Arcade.MUTED, "bold", 0.16))
	box.add_child(value)
	return box


## Herzen fuer die Leben: voll magenta, verloren als Umriss.
class Hearts extends Control:
	var _have := 3
	var _max := 3

	func _init(have: int, most: int) -> void:
		_have = have
		_max = maxi(most, have)
		custom_minimum_size = Vector2(_max * 22, 20)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		for i in _max:
			var c := Vector2(10 + i * 22, 10)
			var pts := PackedVector2Array()
			for k in 24:
				var t := TAU * float(k) / 24.0
				pts.append(c + Vector2(16 * pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2 * t)
					- 2 * cos(3 * t) - cos(4 * t))) * 0.55)
			if i < _have:
				draw_colored_polygon(pts, Arcade.MAGENTA)
			else:
				pts.append(pts[0])
				draw_polyline(pts, Arcade.EMPTY_LINE, 1.5, true)


## Signalbalken fuer die Verstaerkung (1-5 Balken steigend).
class Bars extends Control:
	var _level := 0

	func _init(level: int) -> void:
		_level = level
		custom_minimum_size = Vector2(30, 18)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		for i in 5:
			var h := 4.0 + i * 3.0
			draw_rect(Rect2(i * 6, size.y - h, 4, h), Arcade.ORANGE if i < _level else Color("#3a1a6e"))


func _refresh_squad(run: RunState) -> void:
	UiKit.clear(_squad_list)
	var heading := Label.new()
	heading.text = "Dein Einsatz-Squad  ·  Kampfwert %d" % int(DromeBuild.squad_power(run.squad))
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
	_header_round.text = "Infinity-Einsatz" if endless else "Neon City"
	_side.add_child(_label("Wer kommt mit? Vorgeschlagen ist dein Hangar-Squad. Im Einsatz "
		+ "bleiben die Waffen, wie sie sind -- stärker wirst du mit Modulen aus dem Laden.",
		UiKit.SMALL, COLOR_MUTED))
	var picker := SquadPicker.new()
	_side.add_child(picker)
	picker.setup(RunState.squad_max())
	if endless:
		_side.add_child(_label("Kein Ende, ein Leben: die erste Niederlage beendet den Einsatz und "
			+ "kostet die Beute. Nach jedem Kampf kannst du aussteigen und sie behalten. "
			+ "Ab und zu taucht ein Chaos-Kampf auf -- Gegner unbekannt, bessere Beute.",
			UiKit.SMALL, COLOR_MUTED))
	else:
		_side.add_child(_label("%d Kämpfe, %d Leben. Die ersten %d sind Training gegen normale "
			% [RunState.rounds_total(), RunState.max_lives(),
				int(RunState.cfg().get("training_rounds", 0))]
			+ "DROMEs, danach kommen die Neon Ninja's. Vor jedem Kampf wählst du: immer ein "
			+ "leichter Gegner, dazu zwei normale oder ein normaler und ein Elite.",
			UiKit.SMALL, COLOR_MUTED))
	var start := _big_button("Einsatz starten")
	start.disabled = picker.chosen_count() < 1
	picker.changed.connect(func(): start.disabled = picker.chosen_count() < 1)
	start.pressed.connect(func():
		GameState.start_run(0, GameState.next_run_mode)
		_refresh())
	_main_action(start)


func _show_prepare(run: RunState) -> void:
	# Die Kampfkarte mit festen Wegen (14. Nov. 2026).
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

	var tier_color: Color = MapView.CHAOS_COLOR if chaos else MapView.COLOR.get(run.tier, Color.WHITE)
	var panel_style := _panel_style(true)
	panel_style.border_color = tier_color
	panel.add_theme_stylebox_override("panel", panel_style)
	var foes: Array = info["enemy_builds"]
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	box.add_child(chips)
	chips.add_child(_tier_chip("Chaos" if chaos else RunState.TIER_NAMES[run.tier], tier_color))
	if run.is_training() and not chaos:
		chips.add_child(_tier_chip("Training", Arcade.CYAN))
	chips.add_child(Arcade.label("KAMPF %d · %d GEGEN %s" % [run.round, run.squad.size(),
		"?" if chaos else str(foes.size())], 12, Arcade.MUTED, "bold", 0.14))
	if chaos:
		box.add_child(Arcade.label("CHAOS-KAMPF", 20, Arcade.WHITE, "display"))
		box.add_child(_label("Der Virus würfelt alles: DROMEs, Waffen, Module. Gegner erst im "
			+ "Kampf zu sehen.", 13, COLOR_MUTED))
	else:
		box.add_child(Arcade.label(str(info["team"]).to_upper(), 20, Arcade.WHITE, "display"))
		var leader := ""
		for foe in foes:
			if not foe.is_sentinel():
				leader = foe.display_name
				break
		if leader != "":
			box.add_child(_label("Anführer: %s" % leader.to_upper(), 14, Arcade.TEXT))
		if str(info.get("team_text", "")) != "":
			box.add_child(_label(str(info["team_text"]), 13, COLOR_MUTED))
		# Die Einheiten der Formation als Kacheln -- antippen zeigt die Werte.
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		box.add_child(flow)
		for k in foes.size():
			flow.add_child(_enemy_tile(foes[k], k))

	var own := float(info["own_power"])
	var foe := float(info["enemy_power"])
	var ratio := own / maxf(1.0, foe)
	var verdict := "überlegen" if ratio >= 1.1 else ("ausgeglichen" if ratio >= 0.9 else "unterlegen")
	var color := COLOR_GOOD if ratio >= 1.1 else (COLOR_WARN if ratio >= 0.9 else COLOR_BAD)
	var line := HBoxContainer.new()
	box.add_child(line)
	if chaos:
		line.add_child(_flow_label("Kampfwert: du %d  ·  Gegner ???" % int(own), 14, COLOR_WARN))
	else:
		line.add_child(_flow_label("Kampfwert: du %d · Gegner %d · %s" % [int(own), int(foe), verdict],
			14, color))
	var loot := PanelContainer.new()
	var loot_box := StyleBoxFlat.new()
	loot_box.bg_color = Arcade.DEEP
	loot_box.set_content_margin_all(8)
	loot.add_theme_stylebox_override("panel", loot_box)
	var loot_row := HBoxContainer.new()
	loot_row.add_theme_constant_override("separation", 8)
	loot.add_child(loot_row)
	loot_row.add_child(Arcade.label("BEUTE", 12, Arcade.YELLOW, "bold", 0.16))
	var loot_text := _label(str(info["reward_text"]), 14, Arcade.TEXT)
	loot_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loot_row.add_child(loot_text)
	box.add_child(loot)

	var start := _big_button("Kampf starten")
	UiIcon.on_button(start, "play", 18, UiKit.ON_PRIMARY, "right")
	start.pressed.connect(func():
		GameState.begin_run_battle()
		Fader.go("res://scenes/battle.tscn"))
	_main_action(start)
	start.grab_focus.call_deferred()

	var abandon := Button.new()
	abandon.text = "Aussteigen und Beute behalten" if run.is_endless() else "Einsatz aufgeben"
	abandon.flat = true
	abandon.custom_minimum_size = Vector2(0, 40)
	abandon.add_theme_color_override("font_color", COLOR_MUTED)
	abandon.pressed.connect(func():
		InfoPopup.open(self, "Einsatz aufgeben?", {"lines": ["Module und Credits verfallen. "
			+ "Erfahrung und Beute in der Tasche nimmst du mit."],
			"actions": [{"text": "Aufgeben", "call": func():
				run.abandon()
				GameState.deliver_run_home()
				GameState.run = null
				_refresh()}, {"text": "Weiterkämpfen", "primary": true}]}))
	_side.add_child(abandon)


## Eine Gegner-Kachel: DROMEs gross, Sentinels klein mit Rang-Kuerzel.
## Antippen zeigt Werte, Waffe und Module.
func _enemy_tile(build: DromeBuild, index: int) -> Control:
	var sentinel := build.is_sentinel()
	var edge := 40.0 if sentinel else 52.0
	var tile := Tile.new("foe:%d:%s" % [index, build.display_name], UiKit.drome_view(build, edge),
		"", Vector2(68 if sentinel else 76, 66 if sentinel else 74))
	tile.accent = UiKit.BAD
	tile.glow = not sentinel
	var tag: String = {"elite": "E", "heavy": "H", "heavy_elite": "HE"}.get(build.rank, "")
	var short: String = ({"assault": "Assault", "sniper": "Sniper", "support": "Support"}.get(build.archetype, "")
		if sentinel else build.display_name.split(" ")[-1])
	tile.add_caption("%s%s" % [short, (" " + tag) if tag != "" else ""],
		COLOR_WARN if tag != "" else UiKit.TEXT, 10 if sentinel else 11)
	var pages := _enemy_pages(GameState.run)
	tile.on_info = func(): InfoPopup.open_pages(self, pages, index)
	return tile


func _enemy_pages(run: RunState) -> Array:
	var pages: Array = []
	for build in run.enemies():
		pages.append(func() -> Dictionary: return _enemy_page(build))
	return pages


func _enemy_page(build: DromeBuild) -> Dictionary:
	var stats := build.stats()
	var lines: Array = []
	if build.is_sentinel():
		lines.append(["Sentinel · %s · %s" % [
			{"assault": "Assault", "sniper": "Sniper", "support": "Support"}.get(build.archetype, ""),
			{"basic": "Basic", "elite": "Elite", "heavy": "Heavy", "heavy_elite": "Heavy Elite"}.get(build.rank, "")],
			COLOR_MUTED, UiKit.SMALL])
		lines.append(["Nur Auto-Angriff, keine Passive.", COLOR_MUTED, UiKit.SMALL])
	lines.append("Integrität %d  ·  Schild %d  ·  Rüstung %d" % [int(stats["hp_max"]),
		int(stats["shield_max"]), int(stats["def"])])
	lines.append("Speed %d  ·  Power %d  ·  Kampfwert %d" % [int(stats["spd"]), int(stats["power"]),
		int(build.power_score())])
	for part in build.equipment():
		lines.append(["Waffe: %s" % part.display_name, COLOR_HEADING])
	var names: Array = []
	for slot in build.modules:
		for module_id in build.modules[slot]:
			var module := ModuleData.get_module(module_id)
			if module != null:
				names.append(module.display_name)
	if not names.is_empty():
		lines.append(["Module: %s" % ", ".join(names), COLOR_GOOD])
	return {"title": build.display_name, "picture": UiKit.drome_view(build, 64), "lines": lines}


## "+10 Credits fuer den Sieg  ·  jetzt 24"
func _credit_line(run: RunState) -> String:
	if run.history.is_empty():
		return "Credits: %d" % run.credits
	var last: Dictionary = run.history[-1]
	return "+%d Credits %s  ·  jetzt %d" % [int(last.get("credits", 0)),
		"für den Sieg" if last["won"] else "Trostgeld", run.credits]


# ---------------------------------------------------------------------------
# Zwischenstopp (NEUANFANG 7d)
# ---------------------------------------------------------------------------

## Der Zwischenstopp (Entwurf des Spielers, 16. Nov. 2026): oben eine Zeile
## mit Zurueck, Leben, Credits und dem Beute-Knopf; darunter der Laden (drei
## Module), das Lager in zwei Reihen und unten die drei DROMEs als Kaesten --
## oben der Kopf, darunter je Waffe ihre Modulplaetze (Molok: zwei Waffen
## nebeneinander, jede mit ihren Plaetzen).
##
## Bedienung: ein Modul aus dem Lager auf eine Waffe ziehen (die passenden
## leuchten, der Platz zeigt das Modul schon, bevor man loslaesst) oder auf
## ein anderes Modul (ein Hinweis nennt das Rezept, Loslassen fuegt es
## zusammen). Tippen geht weiter: Modul waehlen, dann die Waffe antippen.
## Waffe ohne Auswahl antippen: Waffe und Module, dort "Zurueck ins Lager".
func _show_stop(run: RunState) -> void:
	if _selected_storage >= run.storage.size():
		_selected_storage = -1
	if not run.bios_offers.is_empty():
		_side.add_child(_bios_row(run))
	_side.add_child(_shop_row(run))

	# --- Lager ---
	var book := run.recipe_book()
	var ready := book.filter(func(entry): return entry["ready"]).size()
	var recipes: Button = null
	if run.is_endless():
		recipes = _small_button("Rezepte%s" % (("  ·  %d bereit" % ready) if ready > 0 else ""))
		if ready > 0:
			recipes.add_theme_color_override("font_color", COLOR_GOOD)
		recipes.pressed.connect(func(): _open_recipes(run))
	_side.add_child(_section_head("Lager  %d / %d" % [run.storage.size(), RunState.storage_size()],
		recipes))
	_side.add_child(_storage_grid(run))
	_hint = _label("", UiKit.SMALL, COLOR_MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint.clip_text = true
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_side.add_child(_hint)

	# --- Die DROMEs ---
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for drome in run.squad.size():
		row.add_child(_drome_box(run, drome))
	_side.add_child(row)
	_mark_targets(run, _selected_storage)

	var go := _big_button("Zur Karte")
	UiIcon.on_button(go, "play", 18, UiKit.ON_PRIMARY, "right")
	go.pressed.connect(func():
		_selected_storage = -1
		InfoPopup.close_all(self)
		run.continue_run()
		_refresh())
	# Infinity-Einsatz: nach jedem Kampf aussteigen und die Beute behalten.
	if run.is_endless():
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 8)
		var out := UiKit.button("Aussteigen")
		out.size_flags_stretch_ratio = 0.5
		out.pressed.connect(func():
			_selected_storage = -1
			run.cash_out()
			_refresh())
		actions.add_child(out)
		actions.add_child(go)
		_main_action(actions)
	else:
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 10)
		var book_button := UiKit.outline_button("Rezepte%s" % ((" · %d" % ready) if ready > 0 else ""),
			COLOR_GOOD if ready > 0 else Arcade.CYAN)
		UiIcon.on_button(book_button, "recipe", 18, COLOR_GOOD if ready > 0 else Arcade.CYAN)
		book_button.size_flags_stretch_ratio = 0.7
		book_button.pressed.connect(func(): _open_recipes(run))
		actions.add_child(book_button)
		actions.add_child(go)
		_main_action(actions)
	if _recipes_open:
		_open_recipes.call_deferred(run)


## Die Zeile in der Kopfzeile neben dem Zurueck-Pfeil: Leben, Credits (mit
## dem Zuwachs des letzten Siegs) und der Beute-Knopf.
func _stop_hud(run: RunState) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hearts := Hearts.new(run.lives, run.lives_max())
	hearts.tooltip_text = "Leben: %d von %d" % [run.lives, run.lives_max()]
	hearts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hearts)
	var credits := UiIcon.text("credits", "%d" % run.credits, 18, Arcade.CYAN, "display")
	credits.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not run.history.is_empty():
		var gain := int(run.history[-1].get("credits", 0))
		if gain > 0:
			credits.add_child(Arcade.label("+%d" % gain, 13, COLOR_GOOD, "bold"))
	row.add_child(credits)
	var loot := Button.new()
	loot.tooltip_text = "Beute dieses Einsatzes"
	loot.custom_minimum_size = Vector2(48, 40)
	loot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiIcon.on_button(loot, "cache", 22, UiKit.MAGENTA, "center")
	var box := Arcade.chamfer_box(Color(UiKit.BG, 0.85), 8, Color(UiKit.MAGENTA, 0.85), 2)
	for state in ["normal", "hover", "pressed", "focus"]:
		loot.add_theme_stylebox_override(state, box)
	loot.pressed.connect(func():
		Accessibility.tap()
		InfoPopup.open_pages(self, _loot_pages(run), 0))
	row.add_child(loot)
	return row


## Die Seiten des Beute-Popups: was der letzte Kampf brachte, was der Einsatz
## gesammelt hat, Erfahrung und Tasche.
func _loot_pages(run: RunState) -> Array:
	var pages: Array = [func() -> Dictionary: return _loot_page(run),
		func() -> Dictionary: return _caches_page(run)]
	if not run.last_growth.is_empty():
		pages.append(func() -> Dictionary: return _growth_page(run))
	if not run.bag.is_empty():
		pages.append(func() -> Dictionary: return _bag_page(run))
	return pages


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


## Stufen-Etikett (LEICHT / NORMAL / ELITE) in der Farbe der Stufe.
func _tier_chip(text: String, color: Color) -> Control:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(Arcade.label(text.to_upper(), 11, Arcade.NIGHT, "bold", 0.14))
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return panel


## Kleiner Chip mit Rahmen in seiner Farbe. Mit ``on_tap`` ein Knopf.
## ``icon``: UI-Symbol vor dem Text, mit ``after`` dahinter (Pfeil "mehr").
func _chip(text: String, color: Color, on_tap: Callable, tip: String, icon: String = "",
		after: bool = false) -> Control:
	var button := Button.new()
	button.text = text
	if icon != "":
		UiIcon.on_button(button, icon, 16, color, "right" if after else "left")
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
func _loot_page(run: RunState) -> Dictionary:
	var lines: Array = []
	var last: Dictionary = run.history[-1] if not run.history.is_empty() else {}
	if not last.is_empty() and not bool(last["won"]):
		lines.append(["Niederlage  ·  −1 Leben", COLOR_BAD])
	if not last.is_empty():
		lines.append(UiIcon.text("credits", "+%d Credits" % int(last.get("credits", 0)), UiKit.BODY - 1,
			Arcade.CYAN))
	for item in run.last_loot:
		var where: String = {"lager": "  →  Lager", "squad": "  →  Squad",
			"tasche": "  →  Tasche (nach dem Einsatz in den Hangar)",
			"home": "  →  nach Hause", "caches": "  →  Einsatz-Beute",
			"coins": "  →  Einsatz-Beute"}.get(str(item.get("where", "")), "")
		lines.append(["%s%s%s" % ["[Selten] " if item.get("rare", false) else "", item["title"], where],
			COLOR_WARN if item.get("rare", false) else Color.WHITE])
		if str(item.get("text", "")) != "":
			lines.append([str(item["text"]), COLOR_MUTED, UiKit.SMALL])
	if run.last_loot.is_empty():
		lines.append(["Diesmal keine Teile.", COLOR_MUTED, UiKit.SMALL])
	return {"title": "Beute", "lines": lines}


## Was der Einsatz bisher an Caches und Platzhaltercoin gesammelt hat.
func _caches_page(run: RunState) -> Dictionary:
	var lines: Array = [["Geht am Ende des Einsatzes in den Hangar -- auch wenn er scheitert.",
		COLOR_MUTED, UiKit.SMALL]]
	for key in run.run_caches:
		lines.append(UiIcon.text("cache", "%d× %s" % [int(run.run_caches[key]),
			RunState.cache_name(StringName(key))], UiKit.BODY - 1, UiKit.MAGENTA))
	lines.append(UiIcon.text("coin", "%d %s" % [run.run_coins, RunState.coin_name()], UiKit.BODY - 1,
		COLOR_WARN))
	lines.append(["Caches öffnen kommt mit dem Hangar-Shop.", COLOR_MUTED, UiKit.SMALL])
	return {"title": "Einsatz-Beute", "lines": lines}


## Erfahrung des letzten Kampfes (Leveling): je DROME und Waffe die neuen EP
## und was der Einsatz bisher gesammelt hat -- mit dem Level, das er danach
## haette. Gutgeschrieben wird erst am Ende, zuhause.
func _growth_page(run: RunState) -> Dictionary:
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
	return {"title": "Erfahrung", "lines": lines}


## Die Tasche (6h): Beute-Waffen dieses Einsatzes. Sie werden im Einsatz nicht
## eingebaut und gehen am Ende in den Hangar.
func _bag_page(run: RunState) -> Dictionary:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for id in run.bag:
		var part := PartDB.get_part(id)
		if part == null:
			continue
		flow.add_child(Tile.new("", SlotShape.new(part.mount_class, UiKit.part_texture(part), 44.0),
			part.display_name, Vector2(84, 80)))
	return {"title": "Tasche", "body": flow, "lines": [["Beute-Waffen gehen nach dem "
		+ "Einsatz in den Hangar. Im Einsatz bleiben die Waffen fest.", COLOR_MUTED, UiKit.SMALL]]}


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
		var pages := _bios_pages(run, blocker)
		tile.on_info = func(): InfoPopup.open_pages(self, pages, index)
		tile.on_action = func():
			if blocker == "" and run.choose_bios(index):
				Accessibility.vibrate(30, true)
			_refresh()
		# Ziehen (17. Nov. 2026): aufs Lager = nehmen, auf die passende Waffe =
		# nehmen und gleich einbauen.
		tile.on_drag = func() -> Variant: return _start_bios_drag(run, index, item, blocker)
		row.add_child(tile)
	return box


func _start_bios_drag(run: RunState, index: int, item: ModuleData, blocker: String) -> Variant:
	if blocker != "":
		return null
	InfoPopup.close_all(self)
	_dropped = false
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := PanelContainer.new()
	var box := Arcade.chamfer_box(Color(UiKit.CARD, 0.96), 10, ModuleData.CLASS_COLOR["bios"], 3)
	box.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", box)
	card.add_child(ModuleChip.new(item, 56.0))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = Vector2(-34, -104)
	holder.add_child(card)
	set_drag_preview(holder)
	Accessibility.vibrate(12)
	return {"kind": "bios_offer", "index": index}


## Passt das angebotene BIOS ``offer`` in diesen DROME (Chassis, noch keins)?
func _offer_fits(run: RunState, offer: int, drome: int) -> bool:
	if run.bios_blocker() != "" or offer < 0 or offer >= run.bios_offers.size():
		return false
	var item := ModuleData.get_module(run.bios_offers[offer])
	var build: DromeBuild = run.squad[drome]
	return item != null and item.bios_kind == "chassis" and build.body() != null \
		and build.body().id == item.bios_chassis and not build.chassis_bios


## Ein gezogenes BIOS-Angebot ablegen: nehmen, und auf einer Waffe gleich
## einbauen (passt es doch nicht, liegt es im Lager).
func _drop_offer(run: RunState, data: Dictionary, drome: int = -1, slot: String = "") -> void:
	if run.choose_bios(int(data["index"])):
		Accessibility.vibrate(30, true)
		var at := run.storage.size() - 1
		if drome >= 0 and run.install_bios(at, drome, slot):
			_flash_holder = "%d:%s" % [drome, slot]
		else:
			_flash_storage = at
	_refresh()


func _bios_pages(run: RunState, blocker: String) -> Array:
	var pages: Array = []
	for index in run.bios_offers.size():
		var item := ModuleData.get_module(run.bios_offers[index])
		if item == null:
			continue
		var at: int = index
		pages.append(func() -> Dictionary:
			return {"title": item.display_name, "subtitle": item.headline(),
				"subtitle_color": item.color(), "picture": ModuleChip.new(item, 52.0),
				"lines": item.effect_lines() + [["Die anderen verfallen, wenn du weitergehst.  ·  "
					+ "Doppeltipp auf die Kachel: nehmen.", COLOR_MUTED, UiKit.SMALL]],
				"actions": [{"text": "Nehmen", "primary": true, "disabled": blocker != "",
					"why": blocker, "call": func():
						if run.choose_bios(at):
							Accessibility.vibrate(30, true)
						_refresh()}]})
	return pages


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
		var tile := Tile.new("shop:%d:%s" % [index, module.id], ModuleChip.new(module, 32.0),
			module.display_name, Vector2(0, 62))
		tile.accent = module.color()
		tile.dimmed = bool(offer["sold"])
		tile.glow = run.target_recipe != &"" and _recipe_wants(run, module)
		var pages := _shop_pages(run)
		var page := index
		tile.on_info = func(): InfoPopup.open_pages(self, pages, page)
		tile.on_action = func(): _buy(run, page)
		holder.add_child(tile)
		var buy := _price_button(price, bool(offer["sold"]), blocker)
		buy.pressed.connect(func(): _buy(run, index))
		holder.add_child(buy)
	# Neu wuerfeln als schmale Spalte rechts -- der Laden bleibt die drei Module.
	var reroll_block := run.reroll_blocker()
	var reroll := Button.new()
	reroll.text = "%d" % run.reroll_price()
	UiIcon.on_button(reroll, "reroll", 20, Arcade.WHITE, "top")
	reroll.tooltip_text = "Neu würfeln (%d Credits)" % run.reroll_price() \
		+ ("" if reroll_block == "" else ": " + reroll_block)
	reroll.disabled = reroll_block != ""
	reroll.custom_minimum_size = Vector2(46, 0)
	reroll.add_theme_font_override("font", Arcade.font("display", 14))
	reroll.add_theme_font_size_override("font_size", 14)
	var reroll_box := Arcade.chamfer_box(Color(UiKit.BG, 0.85), 8, Color(UiKit.CARD_LINE, 0.9), 2)
	reroll_box.set_content_margin_all(4)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		reroll.add_theme_stylebox_override(state, reroll_box)
	reroll.pressed.connect(func():
		run.reroll_shop()
		_refresh())
	row.add_child(reroll)
	return row


## Preis-Knopf im Laden (16. Nov. 2026, vorher schlecht lesbar: weisses
## Symbol ganz links auf Gelb, Zahl allein in der Mitte). Jetzt stehen Symbol
## und Zahl zusammen in der Mitte, dunkel auf Gelb und gross; ohne genug
## Credits grau mit der Zahl in Rot, verkauft als "VERKAUFT".
func _price_button(price: int, sold: bool, blocker: String) -> Button:
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(0, 40)
	buy.disabled = sold or blocker != ""
	buy.tooltip_text = blocker
	var fill := UiKit.PRIMARY if not buy.disabled else Color("#241640")
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := Arcade.chamfer_box(fill.darkened(0.15) if state == "pressed" else fill, 8,
			Color(UiKit.CARD_LINE, 0.9) if buy.disabled else Color.TRANSPARENT, 1 if buy.disabled else 0)
		box.set_content_margin_all(2)
		buy.add_theme_stylebox_override(state, box)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	buy.add_child(row)
	if sold:
		row.add_child(Arcade.label("VERKAUFT", 13, COLOR_MUTED, "bold", 0.12))
		return buy
	var ink := UiKit.ON_PRIMARY if not buy.disabled \
		else (COLOR_BAD if blocker == "zu wenig Credits" else COLOR_MUTED)
	row.add_child(UiIcon.rect("credits", 18, ink))
	var number := Arcade.label(str(price), 20, ink, "display")
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(number)
	return buy


func _buy(run: RunState, index: int) -> void:
	if run.buy(index):
		Accessibility.vibrate(20, true)
		_selected_storage = -1
		_flash_storage = run.storage.size() - 1
	_refresh()


## Seiten zum Blaettern: alle Angebote des Ladens.
func _shop_pages(run: RunState) -> Array:
	var pages: Array = []
	for index in run.shop_offers.size():
		var module := ModuleData.get_module(run.shop_offers[index]["module_id"])
		if module == null:
			continue
		var at: int = index
		pages.append(func() -> Dictionary: return _module_page(run, module, -1, at))
	return pages


## Seiten zum Blaettern: alles im Lager.
func _storage_pages(run: RunState) -> Array:
	var pages: Array = []
	for index in run.storage.size():
		var at: int = index
		pages.append(func() -> Dictionary:
			var module := ModuleData.get_module(run.storage[at])
			if module != null:
				return _module_page(run, module, at)
			var part := PartDB.get_part(run.storage[at])
			return WeaponCard.page(part) if part != null else {"title": str(run.storage[at])})
	return pages


## Braucht das Zielrezept dieses Modul noch?
func _recipe_wants(run: RunState, module: ModuleData) -> bool:
	var target := ModuleData.get_module(run.target_recipe)
	return target != null and target.from.has(module.id)


## Popup zu einem Modul: Wirkung, Zutat fuer, und je nach Herkunft Kaufen
## (shop_index) oder Verkaufen (storage_index).
func _module_page(run: RunState, module: ModuleData, storage_index: int = -1,
		shop_index: int = -1) -> Dictionary:
	var lines := _module_lines(module)
	var uses := _recipes_using(module)
	if not uses.is_empty():
		lines.append(["Zutat für: %s" % ", ".join(uses), COLOR_MUTED, UiKit.SMALL])
	var actions: Array = []
	if shop_index >= 0:
		var offer: Dictionary = run.shop_offers[shop_index]
		var blocker := run.shop_blocker(shop_index)
		actions.append({"text": "Verkauft" if offer["sold"] else "Kaufen  %d" % RunState.shop_price(module),
			"icon": "" if offer["sold"] else "credits",
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
		actions.append({"text": "Verkaufen  +%d" % ModuleData.sell_value(module), "icon": "credits",
			"call": func():
			run.sell(storage_index)
			_selected_storage = -1
			_refresh()})
		if run.is_module_at(storage_index) or run.is_bios_at(storage_index):
			actions.append({"text": "Auswählen", "primary": true, "call": func():
				InfoPopup.close_all(self)
				_selected_storage = storage_index
				_refresh()})
	return {"title": module.display_name, "subtitle": module.headline(),
		"subtitle_color": module.color(), "picture": ModuleChip.new(module, 52.0),
		"lines": lines, "actions": actions}


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


func _storage_grid(run: RunState) -> Control:
	var grid := GridContainer.new()
	# Zwei Reihen (Wunsch des Spielers, 16. Nov. 2026).
	grid.columns = maxi(1, ceili(RunState.storage_size() / 2.0))
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for index in RunState.storage_size():
		if index < run.storage.size():
			grid.add_child(_storage_tile(run, index))
		else:
			var free := Tile.new("", null, "", Vector2(0, STORE_EDGE))
			free.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			free.empty = true
			free.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(free)
	# Das ganze Lager nimmt ein Modul zurueck, das aus einem Halter gezogen wird.
	grid.mouse_filter = Control.MOUSE_FILTER_STOP
	grid.set_drag_forwarding(Callable(),
		func(_at: Vector2, data: Variant) -> bool:
			if data is Dictionary and data.get("kind") == "bios_offer":
				return run.bios_blocker() == ""
			return data is Dictionary and data.get("kind") == "holder" and _can_return(run),
		func(_at: Vector2, data: Variant) -> void:
			_dropped = true
			if data.get("kind") == "bios_offer":
				_drop_offer(run, data)
			else:
				_return_module(run, data))
	_flash_storage = -1
	return grid


## Eine Lager-Kachel: tippen waehlt (die passenden Waffen leuchten), nochmal
## tippen oder lange druecken zeigt das Popup. Ziehen: auf eine Waffe oder
## auf ein anderes Modul (Rezept).
func _storage_tile(run: RunState, index: int) -> Control:
	var id: StringName = run.storage[index]
	var module := ModuleData.get_module(id)
	var part := PartDB.get_part(id)
	var tile: Tile
	if module != null:
		tile = Tile.new("store:%d:%s" % [index, id], ModuleChip.new(module, MODULE_EDGE), "",
			Vector2(0, STORE_EDGE))
		tile.accent = module.color()
		tile.on_select = func():
			_selected_storage = index
			_refresh()
		tile.on_drag = func() -> Variant: return _start_drag(run, index)
		tile.can_drop = func(data) -> bool:
			if data is Dictionary and data.get("kind") == "holder":
				return _can_return(run)
			if data is Dictionary and data.get("kind") == "bios_offer":
				return run.bios_blocker() == ""
			return data is Dictionary and run.pair_result(int(data.get("index", -1)), index) != null
		tile.on_drop = func(data):
			_dropped = true
			if data.get("kind") == "holder":
				_return_module(run, data)
			elif data.get("kind") == "bios_offer":
				_drop_offer(run, data)
			else:
				_craft_pair(run, int(data["index"]), index)
	else:
		tile = Tile.new("store:%d:%s" % [index, id],
			SlotShape.new(part.mount_class if part != null else "light",
				UiKit.part_texture(part), 36.0), "", Vector2(0, STORE_EDGE))
	var pages := _storage_pages(run)
	tile.on_info = func(): InfoPopup.open_pages(self, pages, index)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.managed = module != null
	tile.selected = index == _selected_storage
	_stores.append({"tile": tile, "index": index, "accent": tile.accent})
	if index == _flash_storage:
		_flash(tile)
	return tile


## Kurzes Aufleuchten (frisch gekauft, eingesetzt).
func _flash(control: Control) -> void:
	if Accessibility.motion() <= 0.0:
		return
	control.modulate = Color(2.2, 2.2, 1.4)
	var tween := control.create_tween()
	tween.tween_property(control, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_QUAD)


## Ein DROME-Kasten: oben der Kopf mit Name, darunter je Waffe ein Feld mit
## der Waffe und ihren Modulplaetzen. Ein DROME mit zwei Waffen (Molok) wird
## breiter, die Felder stehen nebeneinander -- welcher Platz zu welcher Waffe
## gehoert, zeigt der Rahmen.
func _drome_box(run: RunState, drome: int) -> Control:
	var build: DromeBuild = run.squad[drome]
	var slots := build.equip_slots()
	var panel := PanelContainer.new()
	var style := UiKit.card_style(false)
	style.set_content_margin_all(5)
	style.shadow_offset = Vector2(4, 4)
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0 if slots.size() <= 1 else 1.5
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var head := TextureRect.new()
	head.texture = UiKit.portrait_texture(build)
	head.custom_minimum_size = Vector2(44, 44)
	head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(head)
	var name := Arcade.label(build.display_name.to_upper(), 12, UiKit.TEXT, "bold", 0.06)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(name)

	var holders := HBoxContainer.new()
	holders.add_theme_constant_override("separation", 4)
	holders.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(holders)
	if slots.is_empty():
		holders.add_child(_label("ohne Waffe", UiKit.SMALL, COLOR_BAD))
	for slot in slots:
		holders.add_child(_holder_tile(run, drome, slot))
	return panel


## Ein Waffenfeld: die Waffe als Halterform, darunter ihre Modulplaetze.
## Ziel fuer gezogene Module; antippen setzt das gewaehlte Modul ein oder
## zeigt Waffe und Module.
func _holder_tile(run: RunState, drome: int, slot: String) -> Tile:
	var build: DromeBuild = run.squad[drome]
	var part := build.part_in(slot)
	var tile := Tile.new("holder:%d:%s" % [drome, slot], null, "", Vector2(0, 0))
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile.managed = true
	tile.accent = COLOR_GOOD
	tile.tooltip_text = part.display_name if part != null else "leer"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var shape := SlotShape.new(SlotRules.slot_class(build.body(), slot), UiKit.part_texture(part), 40.0)
	shape.reach = SlotRules.slot_reach(build.body(), slot)
	shape.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(shape)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	box.add_child(row)
	var layout := build.module_layout(slot)
	var room := ModuleData.slots_for(build, slot)
	var first_free: FreeSlot = null
	# Freie Kaestchen mit ihrem Platz: gezogen wird auf das unter dem Finger.
	var frees: Array = []
	# Eingesetzte Module mit Platz: sie lassen sich wieder herausziehen.
	var placed: Array = []
	for position in maxi(room, layout.size()):
		var module: ModuleData = layout[position] if position < layout.size() else null
		if module != null:
			var chip := ModuleChip.new(module, MODULE_EDGE)
			chip.dim = module.blocker(part) != ""
			chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(chip)
			placed.append([chip, position, module])
		elif position < room:
			var free := FreeSlot.new()
			row.add_child(free)
			frees.append([free, position])
			if first_free == null:
				first_free = free
	tile.add_extra(box)
	tile.on_select = func(): _tap_holder(run, drome, slot)
	tile.on_drag = func() -> Variant: return _start_holder_drag(run, drome, slot, placed)
	tile.can_drop = func(data) -> bool:
		if not (data is Dictionary) or data.get("kind") == "holder":
			return false
		if data.get("kind") == "bios_offer":
			return _offer_fits(run, int(data["index"]), drome)
		return _holder_allows(run, int(data.get("index", -1)), drome, slot)
	tile.on_drop = func(data):
		_dropped = true
		if data.get("kind") == "bios_offer":
			_drop_offer(run, data, drome, slot)
			return
		_install_at(run, int(data["index"]), drome, slot, _free_under(frees, _pointer)[1])
	_holders.append({"tile": tile, "drome": drome, "slot": slot, "free": first_free,
		"frees": frees, "allowed": false, "detail": ""})
	if _flash_holder == "%d:%s" % [drome, slot]:
		_flash_holder = ""
		_flash(tile)
	return tile


## Antippen eines Waffenfelds.
func _tap_holder(run: RunState, drome: int, slot: String) -> void:
	if run.is_bios_at(_selected_storage) or run.is_module_at(_selected_storage):
		for h in _holders:
			if h["drome"] == drome and h["slot"] == slot:
				if h["allowed"]:
					_install_at(run, _selected_storage, drome, slot)
				else:
					InfoPopup.open(self, "Passt hier nicht", {"lines": [str(h["detail"])]})
				return
		return
	var pages := _holder_pages(run, drome, slot)
	if not pages.is_empty():
		InfoPopup.open_pages(self, pages, 0)


## Nimmt diese Waffe das Modul aus Lagerplatz ``index``?
func _holder_allows(run: RunState, index: int, drome: int, slot: String) -> bool:
	return bool(_option_for(run, index, drome, slot).get("allowed", false))


func _option_for(run: RunState, index: int, drome: int, slot: String) -> Dictionary:
	var options: Array = run.bios_options(index) if run.is_bios_at(index) \
		else (run.module_options(index) if run.is_module_at(index) else [])
	for entry in options:
		if int(entry["drome"]) == drome and str(entry["slot"]) == slot:
			return entry
	return {}


## Freier Modulplatz: gestricheltes Kaestchen. Beim Ziehen ueber seine Waffe
## zeigt er das Modul schon blass an (``show_ghost``) -- hier rastet es ein.
class FreeSlot extends Control:
	var _ghost: Control

	func _init() -> void:
		custom_minimum_size = Vector2(MODULE_EDGE, MODULE_EDGE)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func show_ghost(module: ModuleData) -> void:
		hide_ghost()
		if module == null:
			return
		_ghost = ModuleChip.new(module, MODULE_EDGE)
		_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ghost.modulate = Color(1, 1, 1, 0.75)
		add_child(_ghost)
		queue_redraw()

	func hide_ghost() -> void:
		if _ghost != null:
			_ghost.queue_free()
			_ghost = null
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		var color := Color(Arcade.YELLOW, 0.95) if _ghost != null else Color(Arcade.EMPTY_LINE, 0.8)
		var width := 2.0 if _ghost != null else 1.0
		var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in 4:
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[(i + 1) % 4]
			draw_dashed_line(a, b, color, width, 3.0)


## Das freie Kaestchen unter ``at`` als [FreeSlot, Platz]; liegt der Finger
## auf keinem, das erste freie (bzw. [null, -1] ohne freie).
static func _free_under(frees: Array, at: Vector2) -> Array:
	if frees.is_empty():
		return [null, -1]
	var nearest: Array = frees[0]
	var best := INF
	for entry in frees:
		var rect := (entry[0] as Control).get_global_rect()
		if rect.grow(4.0).has_point(at):
			return entry
		# Daneben: das naechste Kaestchen in der Zeile, wenn der Finger in
		# ihrer Hoehe liegt -- sonst bleibt es beim ersten freien.
		if at.y >= rect.position.y - 12.0 and at.y <= rect.end.y + 12.0:
			var d := absf(rect.get_center().x - at.x)
			if d < best:
				best = d
				nearest = entry
	return nearest


## Setzt Lagerplatz ``index`` in diese Waffe (auf Platz ``position``, wenn
## frei; -1 = erster freier).
func _install_at(run: RunState, index: int, drome: int, slot: String, position: int = -1) -> void:
	var done := run.install_bios(index, drome, slot) if run.is_bios_at(index) \
		else run.install_module(index, drome, slot, position)
	if done:
		Accessibility.vibrate(25, true)
		_selected_storage = -1
		_flash_holder = "%d:%s" % [drome, slot]
	_refresh()


## Leuchten je nach Modul in der Hand (gewaehlt oder gezogen): passende
## Waffen gruen, die anderen blass; im Lager leuchten die Module, mit denen
## es ein Rezept ergibt. ``index`` -1 = nichts in der Hand.
func _mark_targets(run: RunState, index: int) -> void:
	var holding := index >= 0 and (run.is_module_at(index) or run.is_bios_at(index))
	for h in _holders:
		var tile: Tile = h["tile"]
		var option := _option_for(run, index, int(h["drome"]), str(h["slot"])) if holding else {}
		h["allowed"] = bool(option.get("allowed", false))
		h["detail"] = str(option.get("detail", "kein Platz"))
		tile.glow = holding and h["allowed"]
		tile.dimmed = holding and not h["allowed"]
		tile.selected = false
	for s in _stores:
		var tile: Tile = s["tile"]
		var other := int(s["index"])
		var pair := run.pair_result(index, other) if holding and other != index else null
		tile.glow = pair != null
		tile.accent = COLOR_GOOD if pair != null else s["accent"]
	if _hint != null:
		if holding:
			var module := ModuleData.get_module(run.storage[index])
			_hint.text = "%s: auf %s ziehen" % [module.display_name if module != null else "Modul",
				"Waffe oder Modul" if _stores.any(func(s): return s["tile"].glow) else "eine Waffe"]
			_hint.add_theme_color_override("font_color", COLOR_GOOD)
		else:
			_hint.text = "Modul auf eine Waffe ziehen  ·  auf ein Modul = Rezept"
			_hint.add_theme_color_override("font_color", COLOR_MUTED)


## Beginn eines Zugs aus dem Lager: grosse Vorschau ueber dem Finger, damit
## man das Modul sieht und nicht der Finger es verdeckt.
func _start_drag(run: RunState, index: int) -> Variant:
	if index >= run.storage.size():
		return null
	var module := ModuleData.get_module(run.storage[index])
	if module == null:
		return null
	InfoPopup.close_all(self)
	_drag_index = index
	_dropped = false
	_hover_key = ""
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := PanelContainer.new()
	var box := Arcade.chamfer_box(Color(UiKit.CARD, 0.96), 10, Arcade.YELLOW, 3)
	box.set_content_margin_all(6)
	box.shadow_color = Color(UiKit.MAGENTA, 0.8)
	box.shadow_size = 1
	box.shadow_offset = Vector2(5, 5)
	card.add_theme_stylebox_override("panel", box)
	card.add_child(ModuleChip.new(module, 56.0))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Mittig ueber dem Finger, ein Stueck hoeher -- sonst liegt er darauf.
	card.position = Vector2(-34, -104)
	holder.add_child(card)
	set_drag_preview(holder)
	for s in _stores:
		if int(s["index"]) == index:
			s["tile"].dimmed = true
	_mark_targets(run, index)
	Accessibility.vibrate(12)
	return {"kind": "store", "index": index}


## Waehrend des Zugs: das Ziel unter dem Finger hervorheben -- eine passende
## Waffe zeigt das Modul im freien Platz, ein Modul im Lager nennt das
## Rezept, eine unpassende Waffe den Grund.
func _process(_delta: float) -> void:
	if _drag_index < 0:
		return
	if not get_viewport().gui_is_dragging():
		_end_drag()
		return
	var run := _run()
	if run == null or run.phase != RunState.Phase.STOP:
		return
	var at := _pointer
	var key := ""
	var target: Dictionary = {}
	for h in _holders:
		if (h["tile"] as Control).get_global_rect().has_point(at):
			# Der Platz gehoert zum Schluessel: wandert der Finger ueber ein
			# anderes freies Kaestchen, wandert die Vorschau mit.
			key = "h:%d:%s:%d" % [h["drome"], h["slot"], int(_free_under(h["frees"], at)[1])]
			target = h
	if key == "":
		for s in _stores:
			if int(s["index"]) != _drag_index and (s["tile"] as Control).get_global_rect().has_point(at):
				key = "s:%d" % s["index"]
				target = s
	if key == _hover_key:
		return
	_clear_hover()
	_hover_key = key
	if target.is_empty():
		return
	var tile: Tile = target["tile"]
	if target.has("slot"):
		if target["allowed"]:
			tile.selected = true
			var spot: Variant = _free_under(target["frees"], at)[0]
			if spot != null:
				(spot as FreeSlot).show_ghost(ModuleData.get_module(run.storage[_drag_index]))
			Accessibility.vibrate(8)
		else:
			_show_tip(tile, str(target["detail"]), COLOR_BAD)
	else:
		var result := run.pair_result(_drag_index, int(target["index"]))
		if result != null:
			tile.selected = true
			_show_tip(tile, "Rezept: %s" % result.display_name, COLOR_GOOD)
			Accessibility.vibrate(8)
		else:
			_show_tip(tile, "ergibt kein Rezept", COLOR_MUTED)


func _clear_hover() -> void:
	for h in _holders:
		(h["tile"] as Tile).selected = false
		for entry in h["frees"]:
			(entry[0] as FreeSlot).hide_ghost()
	for s in _stores:
		(s["tile"] as Tile).selected = int(s["index"]) == _selected_storage and _drag_index < 0
	if _tip != null:
		_tip.visible = false


## Wo der Finger (die Maus) gerade ist -- aus den Ereignissen selbst, nicht
## aus der Mausposition, die auf dem Touchscreen hinterherhinkt.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventScreenDrag \
			or event is InputEventMouseButton or event is InputEventScreenTouch:
		_pointer = event.position


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _drag_index >= 0:
		_end_drag()
	if what == NOTIFICATION_DRAG_END and not _holder_drag.is_empty():
		_holder_drag = {}
		if _tip != null:
			_tip.visible = false
		if not _dropped:
			_refresh()
		_dropped = false


## Ein eingesetztes Modul greifen (17. Nov. 2026): das Modul, das dem Finger
## am naechsten liegt, laesst sich ins Lager zurueckziehen.
func _start_holder_drag(run: RunState, drome: int, slot: String, placed: Array) -> Variant:
	if placed.is_empty() or run.phase != RunState.Phase.STOP:
		return null
	var best: Array = []
	var gap := INF
	for entry in placed:
		var d := (entry[0] as Control).get_global_rect().get_center().distance_to(_pointer)
		if d < gap:
			gap = d
			best = entry
	if best.is_empty() or gap > MODULE_EDGE * 1.6:
		return null
	InfoPopup.close_all(self)
	var chip: Control = best[0]
	var module: ModuleData = best[2]
	_dropped = false
	_holder_drag = {"drome": drome, "slot": slot, "position": int(best[1]), "chip": chip}
	chip.modulate = Color(1, 1, 1, 0.25)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := PanelContainer.new()
	var box := Arcade.chamfer_box(Color(UiKit.CARD, 0.96), 10, Arcade.CYAN, 3)
	box.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", box)
	card.add_child(ModuleChip.new(module, 56.0))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = Vector2(-34, -104)
	holder.add_child(card)
	set_drag_preview(holder)
	if run.storage_full():
		_show_tip(chip, "Lager voll", COLOR_BAD)
	Accessibility.vibrate(12)
	return {"kind": "holder", "drome": drome, "slot": slot, "position": int(best[1])}


func _can_return(run: RunState) -> bool:
	return run.phase == RunState.Phase.STOP and not run.storage_full()


## Ein aus dem Halter gezogenes Modul zurueck ins Lager.
func _return_module(run: RunState, data: Dictionary) -> void:
	if run.remove_module(int(data["drome"]), str(data["slot"]), int(data["position"])):
		Accessibility.vibrate(25, true)
		_flash_storage = run.storage.size() - 1
	_holder_drag = {}
	_refresh()


func _end_drag() -> void:
	if _drag_index < 0:
		return
	_drag_index = -1
	_hover_key = ""
	if _tip != null:
		_tip.visible = false
	# Ohne Ablage: alles wieder wie vorher.
	if not _dropped:
		_refresh()
	_dropped = false


## Kleines Hinweis-Schild ueber ``anchor`` (Rezept, Grund).
func _show_tip(anchor: Control, text: String, color: Color) -> void:
	if _tip == null:
		var layer := CanvasLayer.new()
		layer.layer = 95
		add_child(layer)
		_tip = PanelContainer.new()
		_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_tip)
		_tip_label = Arcade.label("", 14, Color.WHITE, "bold", 0.04)
		_tip.add_child(_tip_label)
	var box := Arcade.chamfer_box(Color(UiKit.BG, 0.96), 8, color, 2)
	box.set_content_margin_all(8)
	_tip.add_theme_stylebox_override("panel", box)
	_tip_label.text = text
	_tip_label.add_theme_color_override("font_color", color.lightened(0.3))
	_tip.reset_size()
	# Ueber der Zug-Vorschau (die liegt ueber dem Finger), sonst verdeckt
	# sie das Schild.
	var area := get_viewport_rect().size
	var tip_size := _tip.get_combined_minimum_size()
	var top := _pointer.y - 112.0 - tip_size.y if _drag_index >= 0 \
		else anchor.get_global_rect().position.y - tip_size.y - 8.0
	_tip.position = Vector2(clampf(_pointer.x - tip_size.x * 0.5, 8.0, area.x - tip_size.x - 8.0),
		maxf(8.0, top))
	_tip.visible = true


## Zieht man ein Modul auf ein anderes: Rezept zusammenfuegen.
func _craft_pair(run: RunState, a: int, b: int) -> void:
	var result := run.pair_result(a, b)
	if result != null and run.craft(result.id):
		Accessibility.vibrate(30, true)
		_selected_storage = -1
		_flash_storage = run.storage.find(result.id)
	_refresh()


## Waffe und Module einer Waffe zum Blaettern (Tipp auf das Waffenfeld).
func _holder_pages(run: RunState, drome: int, slot: String) -> Array:
	var build: DromeBuild = run.squad[drome]
	var pages: Array = []
	var part: PartData = build.part_in(slot)
	if part != null:
		pages.append(func() -> Dictionary: return WeaponCard.page(part))
	pages.append_array(_installed_pages(run, drome, slot))
	return pages


## Seiten der Module eines Halters (mit "Zurueck ins Lager").
func _installed_pages(run: RunState, drome: int, slot: String) -> Array:
	var build: DromeBuild = run.squad[drome]
	var weapon := build.part_in(slot)
	var pages: Array = []
	var layout := build.module_layout(slot)
	for position in layout.size():
		var module: ModuleData = layout[position]
		if module == null:
			continue
		var at: int = position
		pages.append(func() -> Dictionary:
			var lines := _module_lines(module)
			var resting := module.blocker(weapon)
			if resting != "":
				lines.append(["ruht: %s" % resting, COLOR_BAD])
			return {"title": module.display_name, "subtitle": module.headline(),
				"subtitle_color": module.color(), "picture": ModuleChip.new(module, 52.0),
				"lines": lines, "actions": [{"text": "Zurück ins Lager", "disabled": run.storage_full(),
					"why": "Lager voll", "call": func():
						run.remove_module(drome, slot, at)
						_refresh()}]})
	return pages


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
	_recipe_shown.clear()
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
		_recipe_shown.append((entry["module"] as ModuleData).id)
		grid.add_child(_recipe_tile(run, entry))
		shown += 1
	if shown == 0:
		body.add_child(_label("Nichts in dieser Auswahl.", UiKit.SMALL, COLOR_MUTED))
	body.add_child(_label("Tippen wählt, nochmal tippen zeigt das Rezept, Doppeltipp fügt zusammen. "
		+ "Zwei Zutaten aus dem Lager ergeben ein neues Modul: die Summe ihrer Werte und ein "
		+ "eigener Effekt.", 13, COLOR_MUTED))
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
	tile.on_info = func(): InfoPopup.open_pages(self, _recipe_pages(run), _recipe_shown.find(module.id))
	# Doppeltipp: zusammenfuegen, wenn alle Zutaten da sind.
	tile.on_action = func():
		if entry["ready"] and run.craft(module.id):
			Accessibility.vibrate(40, true)
			_selected_storage = -1
			_flash_storage = run.storage.size() - 1
			_recipes_open = true
			_refresh()
	return tile


## Seiten: die Rezepte, die gerade im Raster stehen (nach Filter).
func _recipe_pages(run: RunState) -> Array:
	var pages: Array = []
	var book := run.recipe_book()
	for module_id in _recipe_shown:
		for entry in book:
			if (entry["module"] as ModuleData).id == module_id:
				pages.append(func() -> Dictionary: return _recipe_page(run, entry))
				break
	return pages


func _recipe_page(run: RunState, entry: Dictionary) -> Dictionary:
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
		piece.add_child(_flow_label(ingredient.display_name if ingredient != null
			else str(module.from[i]), 15, COLOR_GOOD if have else COLOR_MUTED))
		if have:
			piece.add_child(UiIcon.rect("check", 16, COLOR_GOOD))
		parts.add_child(piece)
	var lines: Array = [parts]
	lines.append_array(_module_lines(module))
	var actions: Array = [{"text": "Zusammenfügen", "primary": true, "disabled": not entry["ready"],
		"why": "Zutaten fehlen", "call": func():
			if run.craft(module.id):
				Accessibility.vibrate(40, true)
				_selected_storage = -1
				_flash_storage = run.storage.size() - 1
			_recipes_open = true
			_refresh()}]
	if not module.is_bios_result:
		var aimed := run.target_recipe == module.id
		actions.append({"text": "Ziel aufheben" if aimed else "Als Ziel", "call": func():
			run.set_target_recipe(module.id)
			_recipes_open = true
			_refresh()})
	actions.append({"text": "Rezeptbuch", "icon": "caret_left", "call": func(): _open_recipes(run)})
	return {"title": module.display_name, "subtitle": module.headline(),
		"subtitle_color": module.color(), "picture": ModuleChip.new(module, 52.0),
		"lines": lines, "actions": actions}


func _show_end(run: RunState) -> void:
	# Die Beute, die noch im Lauf war, geht jetzt nach Hause (7f).
	_delivered.append_array(GameState.deliver_run_home())
	var won := run.phase == RunState.Phase.WON
	var wins := run.wins()
	var losses := run.history.size() - wins
	# Entwurf 15. Nov. 2026: Etikett, grosser Glitch-Schriftzug, Zahlen.
	var tag := Arcade.tilt(Arcade.tag("%s · %s" % [_region_name(run).to_upper(),
		str(run.faction().get("name", "")).to_upper()], 12, 0.0), 2.0)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_side.add_child(tag)
	var title := ""
	if run.is_endless():
		title = "Ausgestiegen" if won else "Gefallen"
	else:
		title = "Einsatz\nabgeschlossen" if won else "Einsatz\ngescheitert"
	var logo := Arcade.GlitchLogo.new(title.to_upper(), 28, 3.6, [
		[0.0, Vector2(-2, 0), Vector2(2, 0)],
		[0.9, Vector2(-6, 2), Vector2(6, -2)],
		[0.93, Vector2(4, -1), Vector2(-4, 1)]], 2.0)
	var big := Arcade.tilt(logo, -3.0)
	big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_side.add_child(big)
	var summary := _label("%d Kämpfe · %d Siege · %d Niederlagen · Leben %d/%d" % [run.history.size(),
		wins, losses, maxi(run.lives, 0), run.lives_max()], 15, Arcade.TEXT)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_side.add_child(summary)
	if not run.is_endless():
		if won and GameState.just_unlocked_endless:
			_side.add_child(_bonus_banner("Neon City bezwungen", "Infinity-Einsatz freigeschaltet"))
	else:
		_side.add_child(_label("Die Beute kommt mit nach Hause." if won
			else "Die Beute dieses Einsatzes ist verloren -- was zuhause liegt, ist sicher.", 14,
			COLOR_MUTED))

	# Verlauf als Kette: je Kampf ein Kaestchen in der Farbe der Stufe,
	# Haken = Sieg, Kreuz = Niederlage.
	var chart := UiKit.card(_side, false)
	var chart_head := HBoxContainer.new()
	chart.add_child(chart_head)
	var chart_title := Arcade.label("VERLAUF", 14, Arcade.CYAN, "bold", 0.2)
	chart_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_head.add_child(chart_title)
	for k in 3:
		chart_head.add_child(UiIcon.text(str(MapView.ICON[k]), RunState.TIER_NAMES[k].to_upper() + " ", 10,
			MapView.COLOR[k], "bold", 0.08))
	chart.add_child(RunChart.new(run))
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 12)
	legend.add_child(UiIcon.text("check", "Sieg", 13, COLOR_MUTED))
	legend.add_child(UiIcon.text("cross", "Niederlage · −1 Leben", 13, COLOR_MUTED))
	chart.add_child(legend)

	# Was bleibt: Caches, Coins, Teile, Erfahrung.
	var keep := UiKit.card(_side, true)
	keep.add_child(Arcade.label("WAS BLEIBT", 14, Arcade.CYAN, "bold", 0.2))
	var wallet := HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 8)
	keep.add_child(wallet)
	var caches := 0
	var coins := 0
	for item in _delivered:
		match str(item.get("kind", "")):
			"cache": caches += int(item.get("amount", 1))
			"coins": coins += int(item.get("amount", 0))
	wallet.add_child(_keep_cell(RunState.cache_name(run.region_id), "× %d" % caches, Arcade.MAGENTA))
	wallet.add_child(_keep_cell(RunState.coin_name(), "+%d" % coins, Arcade.YELLOW))
	var parts: Array = _delivered.filter(func(item): return item.get("kind", "") == "part") \
		.map(func(item): return str(item["title"]))
	if not parts.is_empty():
		keep.add_child(_label("Teile in den Hangar: %s" % ", ".join(parts), 13, COLOR_GOOD))
	# Die EP des Laufs, jetzt zuhause gutgeschrieben (Leveling).
	var drome_rows: Array = run.final_growth.filter(func(row): return row["kind"] == "drome")
	if not drome_rows.is_empty():
		var rule := ColorRect.new()
		rule.color = Color("#3a1a6e")
		rule.custom_minimum_size = Vector2(0, 1)
		keep.add_child(rule)
		keep.add_child(Arcade.label("DROMEs", 12, Arcade.MUTED, "bold", 0.2))
		for row in drome_rows:
			keep.add_child(_growth_line(row))
	for row in run.final_growth:
		if row["kind"] != "drome" and bool(row["up"]):
			keep.add_child(_label("%s · Level %d · Aufstieg!" % [row["name"], int(row["level"])], 13,
				COLOR_GOOD))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	var hangar := UiKit.outline_button("Zum Hangar")
	hangar.size_flags_stretch_ratio = 0.8
	hangar.pressed.connect(func():
		GameState.deliver_run_home()
		_delivered.clear()
		GameState.run = null
		Fader.go("res://scenes/hangar.tscn"))
	buttons.add_child(hangar)
	var again := _big_button("Neuer Einsatz")
	UiIcon.on_button(again, "play", 18, UiKit.ON_PRIMARY, "right")
	again.pressed.connect(func():
		GameState.deliver_run_home()
		_delivered.clear()
		GameState.run = null
		_refresh())
	buttons.add_child(again)
	_main_action(buttons)
	again.grab_focus.call_deferred()


func _bonus_banner(title: String, text: String) -> Control:
	var panel := PanelContainer.new()
	var box := Arcade.chamfer_box(Arcade.YELLOW, 10)
	box.set_content_margin_all(12)
	box.shadow_color = Arcade.MAGENTA
	box.shadow_size = 1
	box.shadow_offset = Vector2(6, 6)
	panel.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	column.add_child(Arcade.label(title.to_upper(), 16, Arcade.DEEP, "display"))
	column.add_child(Arcade.label(text, 14, Arcade.DEEP, "bold"))
	return Arcade.tilt(panel, -2.0)


func _keep_cell(title: String, value: String, color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Arcade.DEEP
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	column.add_child(Arcade.label(title.to_upper(), 11, Arcade.MUTED, "bold", 0.14))
	column.add_child(Arcade.label(value, 20, color, "display"))
	return panel


## Eine DROME-Zeile im Abschluss: Name, Level (bei Aufstieg "LV 1 → 2 ▲"),
## darunter der EP-Balken.
func _growth_line(row: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var top := HBoxContainer.new()
	box.add_child(top)
	var name := Arcade.label(str(row["name"]).to_upper(), 14, Arcade.WHITE, "display")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	var level := int(row["level"])
	var up := bool(row["up"])
	top.add_child(UiIcon.text("level_up" if up else "xp", ("LV %d → %d" % [level - 1, level]) if up
		else ("LV %d · +%d EP" % [level, int(row["gain"])]), 12,
		Arcade.YELLOW if up else Arcade.MUTED, "bold", 0.08))
	return box


## Der Verlauf des Einsatzes als Kette (Entwurf): Kaestchen je Kampf, hoch
## nach Stufe versetzt, mit Haken oder Kreuz; offene Kaempfe als Punkte.
class RunChart extends Control:
	var _run: RunState

	func _init(run: RunState) -> void:
		_run = run
		custom_minimum_size = Vector2(0, 120)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var total := maxi(RunState.rounds_total(), _run.history.size()) if not _run.is_endless() \
			else maxi(_run.history.size(), 1)
		var step := size.x / float(total)
		var font := Arcade.font("bold")
		var last := Vector2.ZERO
		for i in total:
			var x := step * (i + 0.5)
			var label := "K%d" % (i + 1)
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(font, Vector2(x - w * 0.5, size.y - 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
				Arcade.MUTED)
			if i >= _run.history.size():
				draw_rect(Rect2(x - 3, 40, 6, 6), Color("#3a1a6e"))
				continue
			var entry: Dictionary = _run.history[i]
			var tier := int(entry.get("tier", 1))
			var y := 74.0 - tier * 26.0
			var center := Vector2(x, y)
			if i > 0:
				draw_line(last, center, Arcade.CYAN, 2.0)
			last = center
			var color: Color = MapView.COLOR.get(tier, Color.WHITE)
			var r := Rect2(center - Vector2(10, 10), Vector2(20, 20))
			draw_rect(r, Arcade.NIGHT)
			draw_rect(r, color, false, 2.0)
			if bool(entry["won"]):
				draw_polyline(PackedVector2Array([center + Vector2(-5, 0), center + Vector2(-1, 4),
					center + Vector2(6, -4)]), color, 2.0)
			else:
				draw_line(center + Vector2(-5, -5), center + Vector2(5, 5), Arcade.MAGENTA, 2.0)
				draw_line(center + Vector2(5, -5), center + Vector2(-5, 5), Arcade.MAGENTA, 2.0)


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
