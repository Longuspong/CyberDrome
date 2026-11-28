class_name HangarScreen
extends Control

## Der Hangar: Squad und Umbau an EINER Stelle -- mobile first.
##
## Ersetzt Garage, Inventar und Werkstatt. Die drei Bildschirme zeigten
## dieselben Dinge (DROMEs, Teile, Halter) aus drei Blickwinkeln, und wer einen
## Blaster einbauen wollte, musste zwischen ihnen hin und her. Hier gibt es zwei
## Reiter:
##
##   Squad   oben der gewaehlte DROME als grosse Box mit Angaben, darunter
##           ALLE DROMEs als Kacheln (jeder nur einmal, der Squad zuerst, gruen
##           umrandet und mit ">>"). Plus/Minus oben rechts in der Kachel nimmt
##           in den Squad auf oder heraus (7. Nov. 2026, Wunsch des Spielers --
##           vorher stand der Squad doppelt da).
##   Umbau   oben FEST (scrollt nicht mit): die DROME-Auswahl und die Karte
##           des gewaehlten DROME -- sein Bild, darunter seine Halter als
##           Formen (Dreieck leicht, Viereck mittel, Fuenfeck schwer), rechts
##           die Werte. Darunter eine Leiste mit den Teilen, die frei sind
##           und in diesen DROME passen (nichts Ausgegrautes). Kacheln und
##           Halter: tippen waehlt, nochmal tippen oeffnet die Waffen-Karte (WeaponCard) mit Symbolen,
##           Vergleichsbalken und "Einbauen" bzw. "Ausbauen"; Doppeltipp baut
##           ein (Kachel) bzw. aus (Halter).
##
## Seit 20. Nov. 2026 (Uebergabe Ue1, Design-Canvas): der Reiter Squad ist
## raus -- der Squad wird vor jedem Einsatz gewaehlt (Einsatzvorbereitung).
## Statt dessen **Upgrade**: je Waffe ein Charger-Platz (dauerhaft), Charger
## aus dem Lager einsetzen oder tauschen. Der alte Squad-Code bleibt, bis der
## Assembler-Modus (DROME-Uebersicht) steht.
##
## Seit 22. Nov. 2026 (Design-Canvas "CyberDrome Bildschirme", Vorschlag "ein
## Verb je Tab", vom Spieler abgesegnet) ist dies der Tab **DROMEs**:
## ausruesten und aufwerten. Er zeigt nur die Liste; antippen oeffnet die
## Seite des DROME mit drei Reitern (Zurueck-Pfeil, Name und Schalter stehen
## fest oben, der Rest scrollt):
##
##   dromes     die Liste: Bild, Name, Rolle, Waffe und Charger, Hinweis
##   overview   Uebersicht: Bild, Kampfwert, Werte, Waffe; verwerten
##   drome_up   DROME: Level und Skilltree -- Platzhalter (SKILLBAUM_KONZEPT.md)
##   umbau      Waffe: oben fest Bild + Werte der Waffe (Vergleich beim Antippen
##              einer Waffe aus dem Inventar), Halter, Charger; darunter Level
##              der Waffe (Platzhalter) und Waffen bzw. Charger aus dem Inventar
##
## Neue DROMEs und Charger entstehen in der Fabrik, freie Teile liegen im
## Inventar.
##
## Regeln, Werte und Validierung kommen wie ueberall aus Roster, DromeBuild und
## PartData (SlotRules sagt sie in Worten). Der Hangar haelt nichts davon selbst.

const TILE_EDGE := 128.0
const TILE_COLUMNS := 3
const TILE_GAP := 10
const SLOT_EDGE := 60.0
const PART_EDGE := 92.0
## Kantenlaenge einer Teil-Kachel in der Leiste des Umbaus.
const STRIP_TILE := 104.0

## Welcher Reiter: "squad" oder "umbau". Ueberlebt einen Szenenwechsel ueber
## die Meta des GameState nicht -- muss es auch nicht: aus dem Kampf kommt man
## am besten im Squad an.
var _tab := "dromes"
## Reiter fuer den naechsten Aufbau (HangarScreen.open_tab, z. B. aus dem Shop).
static var _next_tab := ""
## Upgrade: gewaehlte Waffe (Exemplar-uid) und gewaehlter Charger im Lager.
static var _weapon_uid := ""
static var _charger_pick := ""
var _selected := -1
var _selected_slot := ""
## Squad-Reiter: die grosse Karte und die Kacheln (Index -> Tile), damit ein
## Antippen nur diese aendert statt den ganzen Bildschirm neu zu bauen.
var _primary: Control = null
var _squad_tiles: Dictionary = {}

var _content: VBoxContainer
## Ausruestung: die freie Waffe, die gerade zum Vergleich angetippt ist, und
## der Kasten mit den Waffen-Werten (wird beim Antippen allein neu gebaut).
var _compare_part: PartData = null
var _weapon_box: VBoxContainer
## Der feste Bereich ueber dem scrollbaren Inhalt (nur im Umbau gefuellt).
var _fixed: VBoxContainer
var _tab_slot: HBoxContainer


func _ready() -> void:
	if GameState.editing_index >= 0:
		_selected = GameState.editing_index
		_tab = "umbau"
		GameState.editing_index = -1
	elif GameState.roster.entries.size() > 0:
		_selected = _first_in_squad()
	if _next_tab != "":
		_tab = "umbau" if _next_tab in ["upgrade", "charger"] else _next_tab
		_next_tab = ""
	_content = UiKit.page(self, "DROMEs", "", UiKit.TAB_DROMES, true)
	_build_tabs()
	_refresh()


func _entries() -> Array:
	return GameState.roster.entries


func _first_in_squad() -> int:
	for i in _entries().size():
		if _entries()[i].in_squad:
			return i
	return 0 if not _entries().is_empty() else -1


func _squad_max() -> int:
	return RunState.squad_max()


# ---------------------------------------------------------------------------
# Rahmen
# ---------------------------------------------------------------------------

func _build_tabs() -> void:
	# Die Reiter stehen ueber dem scrollbaren Inhalt, damit sie beim Scrollen
	# erreichbar bleiben.
	var frame := _content.get_parent().get_parent().get_parent() as VBoxContainer
	# Die Reiter sitzen seit dem Entwurf vom 15. Nov. als Segmentknopf oben
	# rechts in der Kopfzeile (UiKit.header_slot).
	_tab_slot = UiKit.header_slot(self)
	# Darunter ein Bereich, der nicht mitscrollt: im Umbau stehen dort die
	# DROME-Auswahl und der DROME mit seinen Haltern. Wer ein Teil nach oben
	# auf einen Halter zieht, verschiebt so nicht mehr die ganze Seite.
	var fixed_holder := MarginContainer.new()
	for side in ["left", "right"]:
		fixed_holder.add_theme_constant_override("margin_" + side, UiKit.PAD)
	fixed_holder.add_theme_constant_override("margin_top", 8)
	_fixed = VBoxContainer.new()
	_fixed.add_theme_constant_override("separation", 8)
	fixed_holder.add_child(_fixed)
	frame.add_child(fixed_holder)
	frame.move_child(fixed_holder, 1)


func _switch(tab: String) -> void:
	_tab = tab
	_compare_part = null
	_charger_pick = ""
	Tile.clear_choice()
	_refresh()
	var scroller := _content.get_parent() as ScrollContainer
	if scroller != null:
		scroller.scroll_vertical = 0


## Die Reiter der DROME-Seite.
const DROME_PAGES := [["overview", "Übersicht"], ["drome_up", "DROME"], ["umbau", "Waffe"]]
## Waffe: was unten aus dem Inventar gezeigt wird ("waffen" / "charger").
static var _stock := "waffen"


func _refresh() -> void:
	if _tab not in ["dromes", "overview", "drome_up", "umbau", "squad"]:
		_tab = "umbau" if _tab in ["upgrade", "charger"] else "dromes"
	if _tab != "dromes" and _tab != "squad" and (_selected < 0 or _selected >= _entries().size()):
		_tab = "dromes"
	if _tab_slot != null:
		UiKit.clear(_tab_slot)
	UiKit.clear(_content)
	UiKit.clear(_fixed)
	var page := _tab in ["overview", "drome_up", "umbau"]
	(_fixed.get_parent() as Control).visible = page
	if page:
		_fixed.add_child(_page_bar())
	match _tab:
		"squad": _show_squad()
		"dromes": _show_dromes()
		"overview": _show_overview()
		"drome_up": _content.add_child(_level_card("drome", _entries()[_selected]))
		_: _show_umbau()


## Fest oben auf der DROME-Seite: Zurueck, Name, Schalter der drei Reiter.
func _page_bar() -> Control:
	var entry: RosterEntry = _entries()[_selected]
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	var back := Arcade.BackButton.new()
	back.tooltip_text = "Zurück zur Liste"
	back.pressed.connect(func():
		Accessibility.tap()
		_switch("dromes"))
	row.add_child(back)
	var name := Arcade.label(entry.name.to_upper(), 20, Arcade.WHITE, "display")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name)
	var power := Arcade.label(str(int(GameState.roster.build_for(entry).power_score())), 18, Arcade.YELLOW,
		"display")
	power.tooltip_text = "Kampfwert"
	power.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(power)
	var switch := UiKit.segmented(DROME_PAGES, _tab, func(id): _switch(id), true)
	switch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(switch)
	return column


## Oeffnet den Hangar beim naechsten Aufbau in diesem Reiter.
static func open_tab(tab: String) -> void:
	_next_tab = tab


func _changed() -> void:
	GameState.save_roster()
	GameState.refresh_squad()
	_refresh()


# ---------------------------------------------------------------------------
# Reiter "Squad"
# ---------------------------------------------------------------------------

func _show_squad() -> void:
	var count := GameState.roster.squad_count()
	if _selected < 0 or _selected >= _entries().size():
		_selected = _first_in_squad()
	# Entwurf 15. Nov. 2026: oben der gewaehlte DROME gross, darunter alle
	# DROMEs als Kacheln (3 Spalten). Tippen waehlt, nochmal tippen zeigt die
	# Karte, Doppeltipp oeffnet den Umbau.
	_primary = _primary_card(_selected)
	_content.add_child(_primary)
	_squad_tiles.clear()
	var head := HBoxContainer.new()
	var title := Arcade.label("ALLE DROMEs", 15, Arcade.CYAN, "bold", 0.2)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(Arcade.label("SQUAD", 12, Arcade.MUTED, "bold", 0.2))
	var number := Arcade.label(" %d/%d " % [count, _squad_max()], 18,
		Arcade.YELLOW if count > 0 else UiKit.BAD, "display")
	head.add_child(number)
	head.add_child(HangarPips.new(count, _squad_max(), Arcade.CYAN))
	_content.add_child(head)
	var grid := GridContainer.new()
	grid.columns = TILE_COLUMNS
	grid.add_theme_constant_override("h_separation", TILE_GAP)
	grid.add_theme_constant_override("v_separation", TILE_GAP)
	_content.add_child(grid)
	for index in _squad_first_order():
		var tile := _drome_tile(index)
		_squad_tiles[index] = tile
		grid.add_child(tile)


# ---------------------------------------------------------------------------
# Liste (22. Nov. 2026)
# ---------------------------------------------------------------------------

func _show_dromes() -> void:
	if _entries().is_empty():
		_content.add_child(UiKit.label("Noch kein DROME. Neue DROMEs entstehen in der Fabrik.",
			UiKit.BODY, UiKit.MUTED))
		return
	for index in _squad_first_order():
		_content.add_child(_drome_row(index))


## Eine Zeile der Liste: Bild, Name, Rolle, Waffe mit Charger, Hinweis.
func _drome_row(index: int) -> Control:
	var entry: RosterEntry = _entries()[index]
	var build := GameState.roster.build_for(entry)
	var todo := _todo(entry)
	var style := UiKit.card_style(false)
	if todo != "":
		style.border_color = Arcade.YELLOW
	var panel := _tappable(style, func():
		_selected = index
		_selected_slot = ""
		_switch("overview"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var stack := _tile_stack(build, 76.0, entry.in_squad)
	if todo != "":
		stack.add_child(_todo_badge(todo, 76.0))
	row.add_child(_quiet(stack))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var name := Arcade.label(entry.name.to_upper(), 17, Arcade.WHITE, "display")
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_quiet(name))
	column.add_child(_quiet(role_label(build, role_text(build), 13)))
	# Umbrechen statt die Seite breiter zu schieben (24. Nov. 2026: Molok mit
	# zwei Waffen samt Chargern schob die Tab-Leiste rechts aus dem Bild).
	var loadout := Arcade.label(_loadout_text(entry, build), 13, Arcade.MUTED)
	loadout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_quiet(loadout))
	return panel


## Gelbes Abzeichen unten rechts am Bild statt "WAFFENPLATZ FREI" /
## "CHARGER-PLATZ FREI" (28. Nov. 2026): Plus fuer den Halter, Charger-Symbol
## fuer den Charger; der Satz steht im Tooltip.
static func _todo_badge(todo: String, edge: float) -> Control:
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", Arcade.chamfer_box(Arcade.YELLOW, 4))
	badge.add_child(UiIcon.rect("plus" if todo == "WAFFENPLATZ FREI" else "charger", 14, Arcade.NIGHT))
	badge.size = Vector2(22, 22)
	badge.position = Vector2(edge - 22, edge - 22)
	badge.tooltip_text = "Waffenplatz frei" if todo == "WAFFENPLATZ FREI" else "Charger-Platz frei"
	return badge


## Waffe(n) mit Charger in Worten: "Neon-Blaster · Feuer 2".
func _loadout_text(entry: RosterEntry, build: DromeBuild) -> String:
	var parts: Array[String] = []
	for slot in build.equip_slots():
		var part := build.part_in(slot)
		if part == null:
			continue
		var uid := str(entry.assignments.get(slot, ""))
		var on := GameState.roster.charger_on(uid) if uid != "" else {}
		parts.append(part.display_name + (" · " + Charger.display_name(on.get("phases", []))
			if not on.is_empty() else ""))
	return ", ".join(parts) if not parts.is_empty() else "ohne Waffe"


## Was es bei diesem DROME zu tun gibt (gelb in der Liste), sonst "".
func _todo(entry: RosterEntry) -> String:
	var build := GameState.roster.build_for(entry)
	var free_charger := false
	for c in GameState.roster.chargers:
		free_charger = free_charger or str(c.get("on", "")) == ""
	for slot in build.equip_slots():
		var uid := str(entry.assignments.get(slot, ""))
		if uid == "":
			return "WAFFENPLATZ FREI"
		if free_charger and GameState.roster.charger_on(uid).is_empty():
			return "CHARGER-PLATZ FREI"
	return ""


# ---------------------------------------------------------------------------
# DROME-Seite: Uebersicht und Platzhalter (22. Nov. 2026)
# ---------------------------------------------------------------------------

func _show_overview() -> void:
	var entry: RosterEntry = _entries()[_selected]
	_content.add_child(_primary_card(_selected))
	# Umbenennen gibt es nicht (23. Nov. 2026, Spieler: nie gewollt, und das
	# Eingabefeld zerschoss im Browser die Anzeige).
	var scrap := UiKit.outline_button("VERWERTEN", Arcade.ROSE)
	scrap.tooltip_text = "Gibt Zutaten zurück; die Waffen kommen ins Inventar."
	scrap.pressed.connect(func(): _confirm_salvage(entry))
	_content.add_child(scrap)


## Level kaufen (24. Nov. 2026, SKILLBAUM_KONZEPT.md 5d): aktuelles Level, was das
## naechste kostet (habe/brauche) und "Aufsteigen". Skilltree-Knoten folgen.
func _level_card(kind: String, entry: RosterEntry, uid: String = "") -> Control:
	var bench := Workbench.new(GameState.roster)
	var inst := GameState.roster.instance(uid) if kind == "weapon" else null
	var level: int = inst.level if inst != null else entry.level
	var top := Leveling.weapon_max() if kind == "weapon" else Leveling.drome_max()
	var cost := bench.weapon_next_cost(uid) if kind == "weapon" else bench.drome_next_cost(entry)
	var card := Arcade.Card.new(Arcade.YELLOW, Color.TRANSPARENT, false)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var name := inst.part().display_name if inst != null and inst.part() != null else entry.name
	box.add_child(Arcade.label("%s · LEVEL %d / %d" % [name.to_upper(), level, top], 15, Arcade.YELLOW,
		"display"))
	box.add_child(HangarPips.new(level, top, Arcade.YELLOW))
	var effect := ("Jedes Level: Schaden +%d %%, dazu wächst der Bonus-Wert der Waffe." % int(roundf(
		float(Leveling.weapon_cfg().get("damage_per_level", 0.14)) * 100.0))) if kind == "weapon" \
		else ("Jedes Level: die zwei Hauptwerte des Chassis +%d %%, Integrität, Schild, Schildpuls "
		+ "und Rüstung sonst +%d %%.") % [int(roundf(float(Leveling.drome_cfg().get("main_per_level", 0.1)) * 100.0)),
		int(roundf(float(Leveling.drome_cfg().get("other_per_level", 0.04)) * 100.0))]
	var effect_label := UiKit.label(effect, UiKit.SMALL, UiKit.TEXT)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(effect_label)
	if cost.is_empty():
		box.add_child(UiKit.label("Höchstlevel erreicht.", UiKit.SMALL, UiKit.GOOD))
	else:
		box.add_child(Arcade.label("LEVEL %d KOSTET" % (level + 1), 12, Arcade.MUTED, "bold", 0.16))
		for key in cost:
			var have := bench.have(str(key))
			var line := "%s  %d / %d" % [Workbench.key_name(str(key)), mini(have, int(cost[key])), int(cost[key])]
			if have < int(cost[key]) and str(key) == "keynode":
				line += "  – selten nach einem Einsatz oder aus Caches"
			box.add_child(UiKit.label(line, UiKit.SMALL, UiKit.GOOD if have >= int(cost[key]) else UiKit.MAGENTA))
		var up := UiKit.button("Aufsteigen", true)
		up.disabled = not bench.can_pay(cost)
		up.pressed.connect(func():
			var why := bench.level_up_weapon(uid) if kind == "weapon" else bench.level_up_drome(entry)
			if why == "":
				Accessibility.vibrate(40, true)
				GameState.save_roster()
				GameState.refresh_squad()
			_refresh())
		box.add_child(up)
	return card


func _soon_card(kind: String) -> Control:
	var card := Arcade.Card.new(Arcade.EMPTY_LINE, Color.TRANSPARENT, true)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	# Seit 28. Nov. 2026 nur noch der Hinweis (vorher Erklaerung "kommt noch").
	box.add_child(UiKit.label("Erst eine Waffe einbauen." if kind == "weapon" else "Noch kein Level.",
		UiKit.SMALL, UiKit.MUTED))
	return card


## Rolle in Worten (Entwurf), aus der KI-Rolle des Chassis.
const ROLE_TEXT := {"vanguard": "Vorhut · Tank", "skirmisher": "Plänkler · Nahkampf",
	"controller": "Kontrolle · Fähigkeiten", "sniper": "Scharfschütze"}


static func role_text(build: DromeBuild) -> String:
	return ROLE_TEXT.get(role_key(build), "Allrounder")


static func role_key(build: DromeBuild) -> String:
	var body := build.body()
	return build.role_override if build.role_override != "" else (body.ai_role if body != null else "")


## Rolle als Symbol + Text (assets/ui_icons/role_*.svg, seit 15. Nov. 2026).
static func role_label(build: DromeBuild, value: String, size: int) -> Control:
	var icon := "role_" + role_key(build)
	if not UiIcon.exists(icon):
		return Arcade.label(value, size, Arcade.CYAN, "bold", 0.04)
	return UiIcon.text(icon, value, size, Arcade.CYAN, "bold", 0.04)


## "#01": der wievielte DROME mit diesem Chassis.
func _code(index: int) -> String:
	var body := GameState.roster.build_for(_entries()[index]).body()
	var n := 0
	for i in index + 1:
		var other := GameState.roster.build_for(_entries()[i]).body()
		if other != null and body != null and other.id == body.id:
			n += 1
	return "#%02d" % maxi(1, n)


## Indizes aller DROMEs, die im Squad zuerst.
func _squad_first_order() -> Array:
	var order: Array = []
	for i in _entries().size():
		if _entries()[i].in_squad:
			order.append(i)
	for i in _entries().size():
		if not _entries()[i].in_squad:
			order.append(i)
	return order


## Eine Kachel: das Bild des DROME, so wie er gerade gebaut ist. Im Squad:
## gruener Rand und ">>" oben links. Oben rechts Plus (in den Squad) oder
## Minus (heraus). Antippen zeigt ihn oben in der grossen Box.
func _drome_tile(index: int, squad_toggle: bool = true) -> Control:
	var entry: RosterEntry = _entries()[index]
	var tile := Tile.new("drome:%d" % index)
	tile.custom_minimum_size = Vector2(0, TILE_EDGE)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.selected = index == _selected
	tile.glow = entry.in_squad
	tile.accent = UiKit.GOOD if entry.in_squad and index != _selected else UiKit.ACCENT
	tile.tooltip_text = entry.name
	tile.managed = true
	# 15. Nov. 2026: tippen waehlt, nochmal tippen zeigt die Karte des
	# DROME (blaetterbar), Doppeltipp oeffnet den Umbau.
	tile.on_select = func(): _select_in_squad(index)
	tile.on_info = func(): InfoPopup.open_pages(self, _drome_pages(), _squad_first_order().find(index))
	tile.on_action = func():
		_selected = index
		_selected_slot = ""
		_switch("umbau")
	var stack := _tile_stack(GameState.roster.build_for(entry), TILE_EDGE - 30.0, entry.in_squad)
	tile.add_picture(stack)
	tile.add_caption(entry.name, UiKit.TEXT if entry.in_squad else UiKit.MUTED, 13)
	if not squad_toggle:
		return tile

	var full := GameState.roster.squad_count() >= _squad_max()
	var toggle := Button.new()
	UiIcon.on_button(toggle, "minus" if entry.in_squad else "plus", 18, UiKit.TEXT, "center")
	toggle.custom_minimum_size = Vector2(36, 36)
	toggle.disabled = not entry.in_squad and full
	toggle.tooltip_text = ("%s aus dem Squad" if entry.in_squad else "%s in den Squad") % entry.name
	if toggle.disabled:
		toggle.tooltip_text = "Squad voll (%d) – erst einen herausnehmen" % _squad_max()
	toggle.position = Vector2(stack.custom_minimum_size.x - 30.0, -4)
	toggle.size = toggle.custom_minimum_size
	toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle.pressed.connect(func():
		Accessibility.tap()
		entry.in_squad = not entry.in_squad
		_selected = index
		_changed())
	stack.add_child(toggle)
	# Erst im Baum steht das Theme mit icon_max_width fest. Davor rechnet der
	# Knopf mit dem vollen Symbolbild (96 px) und behielte diese Groesse --
	# der "-"-Kasten lag dann ueber halber Kachelbreite (16. Nov. 2026).
	toggle.set_deferred("size", toggle.custom_minimum_size)
	return tile


## Die Karten aller DROMEs zum Blaettern (Reihenfolge wie die Kacheln).
func _drome_pages() -> Array:
	var pages: Array = []
	for index in _squad_first_order():
		var at: int = index
		pages.append(func() -> Dictionary: return _drome_page(at))
	return pages


func _drome_page(index: int) -> Dictionary:
	var entry: RosterEntry = _entries()[index]
	var build := GameState.roster.build_for(entry)
	var box := _drome_info(entry, build)
	var full := GameState.roster.squad_count() >= _squad_max()
	var actions: Array = [{"text": "Umbau", "primary": true, "call": func():
		_selected = index
		_selected_slot = ""
		_switch("umbau")}]
	actions.append({"text": "Aus dem Squad" if entry.in_squad else "In den Squad",
		"disabled": not entry.in_squad and full, "why": "Squad voll", "call": func():
			entry.in_squad = not entry.in_squad
			_selected = index
			_changed()})
	actions.append({"text": "Verwerten", "call": func(): _confirm_salvage(entry)})
	return {"title": "", "picture": UiKit.drome_view(build, 72), "body": box,
		"actions": actions}


## Bild in der Mitte einer Kachel, Doppelpfeil oben links fuer Squad-Mitglieder.
## Ein schlichtes Control als Buehne, damit Ecken-Elemente darueber liegen.
func _tile_stack(build: DromeBuild, edge: float, in_squad: bool) -> Control:
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(edge, edge)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(center)
	var picture := UiKit.drome_view(build, edge)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(picture)
	if in_squad:
		var mark := UiIcon.rect("double_chevron_right", 16, UiKit.GOOD)
		mark.size = Vector2(16, 16)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.tooltip_text = "im Squad"
		stack.add_child(mark)
	return stack


## Antippen im Squad-Reiter (18. Nov. 2026, ruckelte vorher): nur die grosse
## Karte tauschen und die Markierung der Kacheln umsetzen.
func _select_in_squad(index: int) -> void:
	_selected = index
	if _tab not in ["squad", "dromes"] or _primary == null or not is_instance_valid(_primary) \
			or _primary.get_parent() == null or not _squad_tiles.has(index):
		_refresh()
		return
	var parent := _primary.get_parent()
	var at := _primary.get_index()
	var card := _primary_card(index)
	parent.remove_child(_primary)
	_primary.queue_free()
	parent.add_child(card)
	parent.move_child(card, at)
	_primary = card
	var entries := _entries()
	for i in _squad_tiles:
		var tile: Tile = _squad_tiles[i]
		var entry: RosterEntry = entries[i]
		tile.selected = i == index
		tile.accent = UiKit.GOOD if entry.in_squad and i != index else UiKit.ACCENT


## Die grosse Box (Entwurf): Bild, Etikett, Name, Rolle, Level, Kampfwert,
## Werte in zwei Spalten, Modulplaetze und die Waffe.
func _primary_card(index: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.card_style(index >= 0))
	if index < 0:
		var empty := UiKit.label("Noch kein DROME.",
			UiKit.BODY, UiKit.MUTED)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(empty)
		return panel
	var entry: RosterEntry = _entries()[index]
	var build := GameState.roster.build_for(entry)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", Arcade.chamfer_box(Arcade.DEEP, 12))
	frame.custom_minimum_size = Vector2(112, 124)
	var center := CenterContainer.new()
	frame.add_child(center)
	center.add_child(UiKit.drome_view(build, 100))
	frame.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.double_click:
			_selected_slot = ""
			_switch("umbau"))
	row.add_child(frame)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)
	var chip := _chip("IM SQUAD" if entry.in_squad else "RESERVE", entry.in_squad)
	var tilted := Arcade.tilt(chip, -2.0)
	tilted.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	info.add_child(tilted)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.add_child(Arcade.label(entry.name.to_upper(), 24, Arcade.WHITE, "display"))
	var code := Arcade.label(_code(index), 14, Arcade.MUTED, "bold")
	code.size_flags_vertical = Control.SIZE_SHRINK_END
	name_row.add_child(code)
	info.add_child(name_row)
	var sub := SquadPicker.subtitle_label(Roster.subtitle(entry), 11, 200.0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(sub)
	info.add_child(role_label(build, role_text(build), 15))
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 8)
	level_row.add_child(Arcade.label("LV %d" % entry.level, 14, Arcade.YELLOW, "display"))
	var top_level := Leveling.drome_table().size()
	level_row.add_child(HangarPips.new(entry.level, maxi(5, top_level), Arcade.YELLOW))
	info.add_child(level_row)
	var power_row := HBoxContainer.new()
	power_row.add_theme_constant_override("separation", 8)
	var power_label := Arcade.label("KAMPFWERT", 12, Arcade.MUTED, "bold", 0.2)
	power_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	power_row.add_child(power_label)
	power_row.add_child(Arcade.label(str(int(build.power_score())), 24, Arcade.YELLOW, "display"))
	info.add_child(power_row)

	column.add_child(stat_grid(build))
	column.add_child(Arcade.label("WAFFE" if build.equipment().size() <= 1 else "WAFFEN", 12,
		Arcade.CYAN, "bold", 0.2))
	for part in build.equipment():
		column.add_child(weapon_line(part, _weapon_level(entry, part)))
	if build.equipment().is_empty():
		column.add_child(Arcade.label("ohne Waffe", 14, Arcade.MUTED))
	return panel


## Level des Waffen-Exemplars, das ``part`` in diesem DROME ist (-1 = keins).
func _weapon_level(entry: RosterEntry, part: PartData) -> int:
	for slot in entry.assignments:
		var instance := GameState.roster.instance(str(entry.assignments[slot]))
		if instance != null and instance.part_id == part.id:
			return instance.level
	return -1


## Kleines Etikett (IM SQUAD cyan gefuellt, sonst Rahmen).
static func _chip(text: String, on: bool) -> Control:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Arcade.CYAN if on else Color(0, 0, 0, 0)
	box.border_color = Arcade.CYAN if on else Arcade.EMPTY_LINE
	box.set_border_width_all(1)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(Arcade.label(text, 11, Arcade.NIGHT if on else Arcade.MUTED, "bold", 0.14))
	return panel


## Die Werte in zwei Spalten (Entwurf): Name, schmaler Balken, Zahl.
static func stat_grid(build: DromeBuild, compare: Dictionary = {}) -> Control:
	var stats := build.stats()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	for key in ["spd", "hp_max", "shield_max", "shield_pulse", "def", "power", "efficiency"]:
		var value := float(stats.get(key, 0))
		grid.add_child(StatCell.new(str(StatBar.LABEL[key]).to_upper(), value,
			value / float(StatBar.SCALE[key]), float(compare.get(key, value)) - value))
	var slots := int(stats.get("module_slots", 0))
	var used := 0
	for slot in build.equip_slots():
		used += build.module_count(slot)
	var mod_row := HBoxContainer.new()
	mod_row.add_theme_constant_override("separation", 6)
	var mod_label := Arcade.label("MODULPLÄTZE", 11, Arcade.MUTED, "bold", 0.12)
	mod_label.custom_minimum_size = Vector2(92, 0)
	mod_row.add_child(mod_label)
	mod_row.add_child(HangarPips.new(used, maxi(slots, 1), Arcade.CYAN, true))
	mod_row.add_child(Arcade.label(str(slots), 14, Arcade.TEXT, "bold"))
	grid.add_child(mod_row)
	return grid


## Eine Waffen-Zeile: Halterform, Name, LV-Etikett, Faehigkeit in Kurzform.
static func weapon_line(part: PartData, level: int = -1) -> Control:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Arcade.DEEP
	box.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var shape := SlotShape.new(part.mount_class, null, 26.0)
	shape.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(shape)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.add_child(Arcade.label(part.display_name, 15, Arcade.WHITE, "bold"))
	if level >= 0:
		top.add_child(_chip("LV %d" % level, false))
	text.add_child(top)
	for item in part.actions:
		var action := item as ActionData
		if action.trigger_kind != "":
			var takt: String = action.trigger_text()
			var line := Arcade.label("%s: %s" % [takt.substr(0, 1).to_upper() + takt.substr(1),
				action.display_name], 13, Arcade.TEXT)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.add_child(line)
			break
	return panel


## Name, Kampfwert, Werte und Ausruestung -- fuer die grosse Box und die Angaben.
func _drome_info(entry: RosterEntry, build: DromeBuild) -> VBoxContainer:
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	info.add_child(UiKit.label(entry.name, UiKit.H2))
	# Level (seit 24. Nov. 2026 mit Fabrik-Waren gekauft, keine EP mehr).
	info.add_child(UiKit.label("Level %d / %d" % [entry.level, Leveling.drome_max()], UiKit.SMALL,
		UiKit.GOOD))
	info.add_child(UiKit.label("Kampfwert %d" % int(build.power_score()), UiKit.SMALL,
		UiKit.ACCENT))
	# Werte als Balken (10. Nov. 2026) -- zwischen DROMEs vergleichbar.
	var stats := build.stats()
	for key in ["hp_max", "shield_max", "spd", "def", "power", "efficiency"]:
		info.add_child(StatBar.make(key, float(stats.get(key, 0))))
	info.add_child(UiKit.label(_loadout(build), UiKit.SMALL, UiKit.MUTED))
	return info


## Verwerten mit Nachfrage: was es gibt und was verloren geht.
func _confirm_salvage(entry: RosterEntry) -> void:
	var roster := GameState.roster
	var blocker := roster.salvage_blocker(entry)
	var body := roster.instance(str(entry.assignments.get("body", "")))
	var yield_info := Workbench.salvage_yield(str(body.part_id) if body != null else "", entry.variant)
	var parts: Array = []
	for ware in yield_info["wares"]:
		parts.append("%d %s" % [int(yield_info["wares"][ware]), FactorySim.ware_name(str(ware))])
	if str(yield_info["special"]) != "":
		parts.append("das Spezialteil %s" % Workbench.special_name(str(yield_info["special"])))
	var gain := ", ".join(parts)
	InfoPopup.open(self, "%s verwerten?" % entry.name, {"picture":
		UiKit.drome_view(roster.build_for(entry), 64), "lines": [
			"Du bekommst %s." % gain,
			["Die Waffen kommen ins Inventar. Chassis und Level gehen verloren.",
				UiKit.MUTED, UiKit.SMALL]],
		"actions": [{"text": "Verwerten", "disabled": blocker != "", "why": blocker, "call": func():
			var got := roster.salvage(entry)
			if got.is_empty():
				return
			Accessibility.vibrate(60, true)
			_selected = _first_in_squad()
			_tab = "umbau"
			_changed()}, {"text": "Behalten", "primary": true}]})


# ---------------------------------------------------------------------------
# Reiter "Umbau"
# ---------------------------------------------------------------------------

func _show_umbau() -> void:
	_selected = clampi(_selected, 0, _entries().size() - 1)
	var entry: RosterEntry = _entries()[_selected]
	var build := GameState.roster.build_for(entry)
	# Ohne Kern-Halter (6g) ist der erste Ausruestungshalter vorgewaehlt.
	var equip := build.equip_slots()
	if not equip.is_empty() and _selected_slot not in equip:
		_selected_slot = equip[0]
	_weapon_uid = str(entry.assignments.get(_selected_slot, ""))

	# --- fest: Bild + Werte der Waffe --------------------------------------
	# (Spieler 22. Nov. 2026): oben links das Bild, rechts die Werte der Waffe
	# im gewaehlten Halter -- mit Vergleich, wenn unten eine Waffe angetippt
	# ist; darunter links die Halter, rechts der Charger. Ein Charger aus dem
	# Inventar laesst sich auf die Karte ziehen.
	var card := _DropCard.new(func(data): return data is Dictionary and data.has("charger") \
			and _weapon_uid != "",
		func(data): _mount(str(data["charger"])))
	card.add_theme_stylebox_override("panel", _head_style())
	_fixed.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	card.add_child(inner)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	inner.add_child(head)
	var portrait := UiKit.drome_view(build, 92)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(portrait)
	_weapon_box = VBoxContainer.new()
	_weapon_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_box.add_theme_constant_override("separation", 2)
	# Feste Hoehe (23. Nov. 2026, Spieler): beim Wechsel des Halters (Molok)
	# oder beim Vergleich darf die feste Karte nicht springen -- sonst
	# verschiebt sich alles darunter.
	_weapon_box.custom_minimum_size.y = WEAPON_BOX_HEIGHT
	head.add_child(_weapon_box)
	_fill_weapon_box(build)

	# --- scrollt: Halter und Charger, Level der Waffe, Inventar -------------
	# (Halter und Charger scrollen mit, sonst bleibt auf dem Handy unten kaum
	# Platz fuer das Inventar.)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	_content.add_child(foot)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 2)
	foot.add_child(left)
	left.add_child(Arcade.label("HALTER", 11, Arcade.CYAN, "bold", 0.2))
	left.add_child(_slots(entry, build))
	foot.add_child(_charger_box(entry))
	_content.add_child(_fold("LEVEL DER WAFFE", _weapon_level_open, func():
		_weapon_level_open = not _weapon_level_open
		_refresh()))
	if _weapon_level_open:
		_content.add_child(_level_card("weapon", entry, _weapon_uid) if _weapon_uid != ""
			else _soon_card("weapon"))
	var stock_head := HBoxContainer.new()
	var stock_title := Arcade.label("AUS DEM INVENTAR", 14, Arcade.CYAN, "bold", 0.16)
	stock_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stock_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stock_head.add_child(stock_title)
	stock_head.add_child(UiKit.segmented([["waffen", "Waffen"], ["charger", "Charger"]], _stock, func(id):
		_stock = id
		_compare_part = null
		_charger_pick = ""
		Tile.clear_choice()
		_refresh()))
	_content.add_child(stock_head)
	if _stock == "charger":
		_charger_stock()
	else:
		_parts_strip(entry, build)
	for line in build.validate():
		_content.add_child(UiKit.label("Achtung: " + line, UiKit.SMALL, UiKit.BAD))
	_action_box = VBoxContainer.new()
	_content.add_child(_action_box)
	_update_action()


## Hoehe des Werte-Kastens auf der Waffe-Seite: Platz fuer Titel, Name, drei
## Angriffs- und zwei Faehigkeits-Balken (gemessen: Hammer 231, Deflektor 222).
const WEAPON_BOX_HEIGHT := 236.0
## Klappt "Level der Waffe" auf (merkt sich den Zustand).
static var _weapon_level_open := false
## Der eine Hauptknopf der Waffen-Seite (einbauen / einsetzen / entfernen).
var _action_box: VBoxContainer


## Kopfzeile eines Bereichs zum Auf- und Zuklappen, mit Pfeil.
func _fold(title: String, open: bool, toggle: Callable) -> Control:
	var button := Button.new()
	button.flat = true
	button.text = title
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_override("font", Arcade.font("bold", 13, 0.14))
	button.add_theme_font_size_override("font_size", 13)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Arcade.CYAN)
	UiIcon.on_button(button, "chevron_up" if open else "chevron_down", 16, Arcade.CYAN, "right")
	button.pressed.connect(func():
		Accessibility.tap()
		toggle.call())
	return button


## Charger aus dem Inventar fuer die Waffe im gewaehlten Halter: antippen
## waehlt, Doppeltipp oder Ziehen auf die Karte setzt ein.
func _charger_stock() -> void:
	var roster := GameState.roster
	if _weapon_uid == "":
		_content.add_child(UiKit.label("Erst eine Waffe einbauen – der Charger sitzt in der Waffe.",
			UiKit.SMALL, UiKit.MUTED))
		return
	if roster.chargers.is_empty():
		_content.add_child(UiKit.label("Noch kein Charger – gebaut wird in der Fabrik.",
			UiKit.SMALL, UiKit.MUTED))
		return
	var names := {}
	for w in _weapons():
		names[str(w["uid"])] = (w["part"] as PartData).display_name
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", TILE_GAP)
	grid.add_theme_constant_override("v_separation", TILE_GAP)
	_content.add_child(grid)
	for c in roster.chargers:
		var cuid := str(c["uid"])
		var cphases: Array = c["phases"]
		var cdom := Charger.dominant(cphases)
		var on := str(c.get("on", ""))
		var tile := Tile.new("charger:" + cuid, ChargerHex.new(cphases, 72), Charger.display_name(cphases),
			Vector2(0, 118))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.accent = Charger.element_color(cdom) if cdom != "" else UiKit.ACCENT
		tile.glow = on == _weapon_uid
		tile.add_caption("FREI" if on == "" else ("HIER" if on == _weapon_uid
			else "IN %s" % str(names.get(on, "?")).to_upper()), UiKit.WARN if on == "" else UiKit.MUTED, 11)
		tile.on_select = func():
			_charger_pick = cuid
			_update_action()
		tile.on_action = func(): _mount(cuid)
		tile.on_drag = func():
			tile.set_drag_preview(ChargerHex.new(cphases, 72))
			return {"charger": cuid}
		grid.add_child(tile)


## Der Hauptknopf passt sich an: angetippte Waffe einbauen, gewaehlten
## Charger einsetzen oder den eingesetzten entfernen.
func _update_action() -> void:
	if _action_box == null or not is_instance_valid(_action_box):
		return
	for child in _action_box.get_children():
		child.queue_free()
	if _selected < 0 or _selected >= _entries().size():
		return
	var entry: RosterEntry = _entries()[_selected]
	var build := GameState.roster.build_for(entry)
	var mounted := GameState.roster.charger_on(_weapon_uid) if _weapon_uid != "" else {}
	var button: Button = null
	if _stock == "waffen" and _compare_part != null:
		var part := _compare_part
		button = UiKit.button("%s einbauen" % part.display_name, true)
		button.disabled = _target_slot(build, part) == ""
		button.pressed.connect(func(): _install_part(entry, build, part))
	elif _stock == "charger" and _charger_pick != "" and (mounted.is_empty()
			or str(mounted.get("uid", "")) != _charger_pick):
		var pick := _charger_pick
		button = UiKit.button("Charger einsetzen", true)
		button.pressed.connect(func(): _mount(pick))
	elif _stock == "charger" and not mounted.is_empty():
		button = UiKit.outline_button("CHARGER ENTFERNEN", Arcade.ROSE)
		button.pressed.connect(func():
			GameState.roster.unmount_charger(_weapon_uid)
			_charger_pick = ""
			_changed())
	if button != null:
		_action_box.add_child(button)


## Die Werte der Waffe im gewaehlten Halter. Ist unten eine freie Waffe
## angetippt (_compare_part), zeigen die Balken sie im Vergleich: laenger oder
## kuerzer als die eingebaute, dazu der Unterschied als Zahl.
func _fill_weapon_box(build: DromeBuild) -> void:
	if _weapon_box == null or not is_instance_valid(_weapon_box):
		return
	for child in _weapon_box.get_children():
		child.queue_free()
	var current := build.part_in(_selected_slot) if _selected_slot != "" else null
	var shown: PartData = _compare_part if _compare_part != null else current
	var other: PartData = current if _compare_part != null else null
	var title := "WAFFE"
	if _compare_part != null:
		title = "VERGLEICH" if current != null else "NEU"
	_weapon_box.add_child(Arcade.label(title, 11, Arcade.YELLOW if _compare_part != null else Arcade.CYAN,
		"bold", 0.2))
	if shown == null:
		_weapon_box.add_child(Arcade.label("Halter leer", 13, Arcade.MUTED))
		return
	var name := shown.display_name.to_upper()
	if other != null:
		name = "%s → %s" % [other.display_name.to_upper(), name]
	var name_label := Arcade.label(name, 13, Arcade.WHITE, "display")
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size.x = 60
	_weapon_box.add_child(name_label)
	var hint := UiKit.label("", UiKit.SMALL, UiKit.MUTED)
	var attack := WeaponCard._first_attack(shown)
	var other_attack := WeaponCard._first_attack(other) if other != null else null
	if attack != null:
		for row in WeaponCard.attack_bars(attack, other_attack, hint):
			_weapon_box.add_child(row)
	if attack != null and attack.support == "self":
		# Ohne Reichweite (wirkt auf sich selbst, z. B. Deflektor-Schild): sagen statt weglassen.
		_weapon_box.add_child(UiKit.label("Wirkt auf den DROME selbst", 13, UiKit.MUTED))
	var ability := _first_ability(shown)
	var other_ability := _first_ability(other) if other != null else null
	if ability != null:
		_weapon_box.add_child(Arcade.label("FÄHIGKEIT · " + ability.display_name.to_upper(), 10,
			Arcade.CYAN, "bold", 0.12))
		var rows := WeaponCard.ability_bars(ability, other_ability, hint)
		for row in rows:
			_weapon_box.add_child(row)
		if rows.is_empty():
			# Keine Balken (Schild, Bewegung ...): der Text der Faehigkeit.
			var text := UiKit.label(WeaponCard.short_text(ability), 13, UiKit.TEXT)
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.custom_minimum_size.x = 60
			_weapon_box.add_child(text)
	_weapon_box.add_child(hint)


## Die Faehigkeit einer Waffe (die erste Aktion, die kein Angriff ist).
static func _first_ability(part: PartData) -> ActionData:
	if part == null:
		return null
	for action in part.actions:
		if not action.is_attack():
			return action
	return null


## Antippen einer freien Waffe: nur den Werte-Kasten und den Knopf neu bauen.
func _set_compare(part: PartData) -> void:
	_compare_part = part
	if _selected >= 0 and _selected < _entries().size():
		_fill_weapon_box(GameState.roster.build_for(_entries()[_selected]))
	_update_action()


## Der Charger der Waffe im gewaehlten Halter; antippen fuehrt zu Waffen › Charger.
func _charger_box(entry: RosterEntry) -> Control:
	var uid := str(entry.assignments.get(_selected_slot, ""))
	var on := GameState.roster.charger_on(uid) if uid != "" else {}
	var panel := _tappable(UiKit.card_style(false), func():
		if uid == "":
			return
		_stock = "charger"
		_refresh())
	panel.custom_minimum_size = Vector2(132, 0)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	box.add_child(_quiet(Arcade.label("CHARGER", 11, Arcade.CYAN, "bold", 0.2)))
	if on.is_empty():
		box.add_child(_quiet(Arcade.label("keiner" if uid != "" else "--", 13, Arcade.MUTED)))
		return panel
	var phases: Array = on.get("phases", [])
	var hex := ChargerHex.new(phases, 52)
	hex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(hex)
	box.add_child(_quiet(Arcade.label(Charger.display_name(phases), 12, Arcade.WHITE, "bold")))
	return panel


# ---------------------------------------------------------------------------
# Reiter "Upgrade" (20. Nov. 2026): Charger in Waffen
# ---------------------------------------------------------------------------

## Alle Waffen-Exemplare: erst die verbauten (in Reihenfolge der DROMEs), dann
## die freien. Je {"uid", "part", "owner"}.
func _weapons() -> Array:
	var roster := GameState.roster
	var out: Array = []
	var seen := {}
	for entry in _entries():
		for slot in entry.assignments:
			if not str(slot).begins_with("equip_"):
				continue
			var uid := str(entry.assignments[slot])
			var inst := roster.instance(uid)
			if inst == null or inst.part() == null or seen.has(uid):
				continue
			seen[uid] = true
			out.append({"uid": uid, "part": inst.part(), "owner": entry.name, "level": inst.level})
	for inst in roster.all_instances():
		if seen.has(inst.uid) or inst.type() != PartData.Type.EQUIPMENT or inst.part() == null:
			continue
		var has_attack := false
		for action in inst.part().actions:
			has_attack = has_attack or action.is_attack()
		if has_attack:
			out.append({"uid": inst.uid, "part": inst.part(), "owner": "", "level": inst.level})
	return out


func _mount(charger_uid: String) -> void:
	if charger_uid == "":
		return
	if GameState.roster.mount_charger(charger_uid, _weapon_uid):
		Accessibility.vibrate(40, true)
		_charger_pick = charger_uid
		_changed()


## Die Karte des DROME im Umbau: etwas knapperer Innenabstand, damit oben
## nicht mehr Platz verloren geht als noetig.
func _head_style() -> StyleBoxFlat:
	var style := UiKit.card_style(false)
	style.set_content_margin_all(10)
	return style


## Die Halter als Formen: die Ausruestungshalter in ihrer Klassenform; darin
## die Waffe oder leer. Der
## gewaehlte Halter steht in einem hervorgehobenen Kasten; unter jedem Halter
## seine Klasse. Antippen waehlt den Halter, nochmal antippen oeffnet die
## Karte der Waffe darin (mit "Ausbauen"), Doppeltipp baut sie aus.
func _slots(entry: RosterEntry, build: DromeBuild) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var chassis := build.body()
	for slot in build.equip_slots():
		var part := build.part_in(slot)
		var kind := SlotRules.slot_class(chassis, slot)
		var chosen: bool = slot == _selected_slot
		var style := UiKit.card_style(chosen)
		style.set_content_margin_all(6)
		if chosen:
			style.bg_color = Color(UiKit.ACCENT, 0.18)
			style.set_border_width_all(3)
		else:
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = Color(0, 0, 0, 0)
		# Seit 15. Nov. 2026 (Wunsch des Spielers) wie eine Kachel: tippen
		# waehlt den Halter, nochmal tippen zeigt die Waffen-Karte,
		# Doppeltipp baut die Waffe aus.
		var select := func():
			_selected_slot = slot
			_refresh()
		var show := Callable()
		var take_out := Callable()
		if part != null:
			show = func(): _open_card(entry, build, part, slot)
			take_out = func():
				_selected_slot = slot
				GameState.roster.clear_slot(entry, slot)
				_changed()
		var holder := _tappable(style, func():
			Tile.click(get_tree(), "holder:%s:%s" % [entry.name, slot],
				slot == _selected_slot, select, show, take_out))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(box)
		var shape := SlotShape.new(kind, UiKit.part_texture(part), SLOT_EDGE)
		shape.reach = SlotRules.slot_reach(build.body(), slot)
		shape.highlight = chosen
		shape.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(shape)
		# Unter dem Halter steht nur sein Kuerzel (S/M/X, -F/-N; 27. Nov. 2026)
		# -- keine Richtung mehr (links, rechts): sie sagte nichts, was man nicht sieht.
		var weight := _quiet(UiKit.label(SlotRules.holder_code(build.body(), slot), UiKit.SMALL,
			_class_color(kind) if chosen else Color(_class_color(kind), 0.6)))
		weight.autowrap_mode = TextServer.AUTOWRAP_OFF
		weight.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(weight)
		row.add_child(holder)
	return row


## Eine Farbe je Klasse -- zusaetzlich zur Form, nie statt ihr.
func _class_color(kind: String) -> Color:
	match kind:
		"light": return UiKit.GOOD
		"medium": return UiKit.WARN
		"heavy": return UiKit.BAD
		_: return UiKit.ACCENT


## Die Halter dieses DROME, die ``part`` aufnehmen wuerden: frei im Hangar,
## passend zur Klasse, nicht schon dasselbe Teil darin, und der Aufbau bleibt
## gueltig.
func _slots_taking(build: DromeBuild, part: PartData) -> Array:
	var out: Array = []
	if part == null or GameState.roster.free_count(part.id) <= 0:
		return out
	for slot in build.equip_slots():
		if _part_fits(build, slot, part):
			out.append(slot)
	return out


## Der Halter, in den ein angetipptes Teil kaeme: der gewaehlte, wenn er es
## nimmt, sonst der erste, der es nimmt. "" = keiner.
func _target_slot(build: DromeBuild, part: PartData) -> String:
	var taking := _slots_taking(build, part)
	if taking.is_empty():
		return ""
	return _selected_slot if _selected_slot in taking else str(taking[0])


## Die Teile, die sich in diesen DROME einbauen lassen, als Leiste -- nur was
## frei ist UND passt, nichts Ausgegrautes (Wunsch des Spielers, 10. Nov.
## 2026). Die Leiste laeuft waagerecht: wischen blaettert.
func _parts_strip(entry: RosterEntry, build: DromeBuild) -> void:
	var parts: Array = []
	for part_id in GameState.roster.owned_part_ids(PartData.Type.EQUIPMENT):
		var part := PartDB.get_part(part_id)
		if part != null and not _slots_taking(build, part).is_empty():
			parts.append(part)
	if parts.is_empty():
		_content.add_child(UiKit.label("Keine freie Waffe im Inventar passt in diesen DROME.",
			UiKit.SMALL, UiKit.MUTED))
		return
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, STRIP_TILE + 8.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", TILE_GAP)
	scroll.add_child(row)
	var pages: Array = []
	for part in parts:
		pages.append(func() -> Dictionary: return _card_page(entry, build, part, ""))
	for k in parts.size():
		row.add_child(_part_tile(entry, build, parts[k], pages, k))
	_content.add_child(scroll)


## Passt ``part`` in diesen Halter? Klasse, nicht schon dasselbe Teil darin,
## frei im Hangar, und der Aufbau bleibt gueltig.
func _part_fits(build: DromeBuild, slot: String, part: PartData) -> bool:
	if part == null or not build.body().accepts(part, slot):
		return false
	var current := build.part_in(slot)
	if current != null and current.id == part.id:
		return false
	if GameState.roster.free_count(part.id) <= 0:
		return false
	var trial := build.clone()
	trial.slots[slot] = part.id
	return trial.is_valid()


## Baut ``part`` in den gewaehlten Halter ein (oder den ersten, der es
## nimmt). false = passt nirgends.
func _install_part(entry: RosterEntry, build: DromeBuild, part: PartData) -> bool:
	var slot := _target_slot(build, part)
	if slot == "" or not GameState.roster.assign(entry, slot, part.id):
		return false
	Accessibility.vibrate(20, true)
	_selected_slot = slot
	_changed()
	return true


## Eine Teil-Kachel: die Form mit dem Bild, darunter wie viele frei sind.
## Tippen waehlt, nochmal tippen zeigt die Waffen-Karte, Doppeltipp baut ein.
func _part_tile(entry: RosterEntry, build: DromeBuild, part: PartData, pages: Array = [],
		page: int = 0) -> Control:
	var shape := SlotShape.new(part.mount_class, UiKit.part_texture(part), PART_EDGE - 20.0)
	var tile := Tile.new("part:%s" % part.id, shape, part.display_name,
		Vector2(STRIP_TILE, STRIP_TILE))
	tile.tooltip_text = part.display_name
	# Seit 22. Nov. 2026: antippen zeigt oben im Werte-Kasten den Vergleich.
	tile.on_select = func(): _set_compare(part)
	# Seit 15. Nov. 2026 (Wunsch des Spielers): tippen waehlt, nochmal tippen
	# zeigt die Waffen-Karte (blaetterbar), Doppeltipp baut ein.
	tile.on_action = func():
		if not _install_part(entry, build, part):
			_open_card(entry, build, part, "")
	tile.on_info = func():
		if pages.is_empty():
			_open_card(entry, build, part, "")
		else:
			InfoPopup.open_pages(self, pages, page)
	return tile


## Die Waffen-Karte. ``installed_in``: der Halter, in dem sie steckt (dann
## "Ausbauen"); leer = eine Kachel aus dem Bestand (dann "Einbauen" in den
## gewaehlten Halter oder den ersten, der sie nimmt -- mit Vergleich gegen
## die Waffe, die dort steckt, und der Wertaenderung am DROME).
func _open_card(entry: RosterEntry, build: DromeBuild, part: PartData,
		installed_in: String) -> void:
	InfoPopup.open(self, "", _card_page(entry, build, part, installed_in))


func _card_page(entry: RosterEntry, build: DromeBuild, part: PartData,
		installed_in: String) -> Dictionary:
	if installed_in != "":
		return WeaponCard.page(part, Callable(), [{"text": "Ausbauen", "on": func():
			GameState.roster.clear_slot(entry, installed_in)
			_changed()}])
	var slot := _target_slot(build, part)
	var replaced := build.part_in(slot) if slot != "" else null
	var extra := func(box: VBoxContainer):
		box.add_child(HSeparator.new())
		if slot == "":
			box.add_child(UiKit.label("Passt gerade in keinen Halter.", UiKit.SMALL, UiKit.WARN))
			return
		var where := SlotRules.holder_label(build, slot)
		if replaced != null:
			box.add_child(UiKit.label("%s: ersetzt %s (zurück ins Inventar)"
				% [where, replaced.display_name], UiKit.SMALL, UiKit.WARN))
		else:
			box.add_child(UiKit.label("%s ist frei  ·  %d frei im Inventar"
				% [where, GameState.roster.free_count(part.id)], UiKit.SMALL, UiKit.MUTED))
		_delta_lines(build, slot, part, box)
	return WeaponCard.page(part, extra, [{"text": "Einbauen", "primary": true,
		"disabled": slot == "", "on": func():
			if GameState.roster.assign(entry, slot, part.id):
				Accessibility.vibrate(20, true)
				_selected_slot = slot
				_changed()}], replaced)


## Was sich am DROME aendern wuerde -- nur die Werte, die sich bewegen.
func _delta_lines(build: DromeBuild, slot: String, part: PartData, box: VBoxContainer) -> void:
	var trial := build.clone()
	trial.slots[slot] = part.id
	var before := build.stats()
	var after := trial.stats()
	# Vorher -> nachher als Vergleichsbalken: gruen dazu, rot weg.
	for key in ["hp_max", "shield_max", "shield_pulse", "spd", "def", "power", "efficiency"]:
		var a: int = before.get(key, 0)
		var b: int = after.get(key, 0)
		if a != b:
			box.add_child(StatBar.make(key, float(b), float(a)))
	var score_before := build.power_score()
	var score_after := trial.power_score()
	if not is_equal_approx(score_before, score_after):
		box.add_child(StatBar.make("power_score", score_after, score_before))
	for line in trial.validate():
		box.add_child(UiKit.label("danach: " + line, UiKit.SMALL, UiKit.BAD))


# ---------------------------------------------------------------------------
# Bausteine
# ---------------------------------------------------------------------------

## Ein antippbares Panel. Reagiert auf das LOSLASSEN, nicht auf das Druecken --
## sonst loeste jeder Wischer zum Scrollen die Karte aus, auf der er beginnt.
func _tappable(style: StyleBox, on_tap: Callable) -> PanelContainer:
	var panel := PanelContainer.new()
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	else:
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and not event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT \
				and panel.get_global_rect().has_point(event.global_position):
			on_tap.call())
	return panel


## Labels in antippbaren Karten duerfen den Tipp nicht schlucken.
func _quiet(control: Control) -> Control:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control


func _loadout(build: DromeBuild) -> String:
	var names: Array[String] = []
	for part in build.equipment():
		names.append(part.display_name)
	return ", ".join(names) if not names.is_empty() else "ohne Ausrüstung"


## Kaestchen-Reihe (Squad 4/4, Level, Modulplaetze); ``hollow``: freie Plaetze
## als Rahmen.
class HangarPips extends Control:
	var _have := 0
	var _max := 4
	var _color := Arcade.CYAN
	var _hollow := false

	func _init(have: int, most: int, color: Color, hollow: bool = false) -> void:
		_have = have
		_max = most
		_color = color
		_hollow = hollow
		custom_minimum_size = Vector2(most * 12, 14)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := (size.y - 9.0) * 0.5
		for i in _max:
			var r := Rect2(i * 12, y, 9, 9)
			if i < _have:
				draw_rect(r, _color)
			elif _hollow:
				draw_rect(r, Arcade.EMPTY_LINE, false, 1.5)
			else:
				draw_rect(r, Color("#3a1a6e"))


## Eine Wert-Zelle: NAME, Balken, Zahl (Entwurf Hangar). ``delta`` != 0
## haengt +n / -n an.
class StatCell extends HBoxContainer:
	func _init(title: String, value: float, fraction: float, delta: float = 0.0) -> void:
		add_theme_constant_override("separation", 6)
		var name := Arcade.label(title, 11, Arcade.MUTED, "bold", 0.06)
		name.custom_minimum_size = Vector2(84, 0)
		add_child(name)
		var bar := _Bar.new(fraction)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(bar)
		var shown := str(int(round(value)))
		var number := Arcade.label(shown, 14, Arcade.TEXT, "bold")
		number.custom_minimum_size = Vector2(28, 0)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(number)
		if absf(delta) >= 0.5:
			add_child(Arcade.label(("%+d" % int(round(-delta))), 12,
				UiKit.GOOD if delta < 0 else UiKit.BAD, "bold"))

	class _Bar extends Control:
		var _f := 0.0

		func _init(fraction: float) -> void:
			_f = clampf(fraction, 0.0, 1.0)
			custom_minimum_size = Vector2(24, 12)
			mouse_filter = Control.MOUSE_FILTER_IGNORE

		func _draw() -> void:
			var y := size.y * 0.5 - 3
			draw_rect(Rect2(0, y, size.x, 6), Color("#2a1650"))
			draw_rect(Rect2(0, y, size.x * _f, 6), Arcade.CYAN)


## Eine Karte, die Gezogenes annimmt (Upgrade: Charger auf die Waffe).
class _DropCard extends PanelContainer:
	var _accepts: Callable
	var _dropped: Callable

	func _init(accepts: Callable, dropped: Callable) -> void:
		_accepts = accepts
		_dropped = dropped

	func _can_drop_data(_at: Vector2, data) -> bool:
		return _accepts.call(data)

	func _drop_data(_at: Vector2, data) -> void:
		_dropped.call(data)
