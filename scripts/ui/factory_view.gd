class_name FactoryView
extends VBoxContainer

## Reiter "Platine" im Fabrik-Tab (23. Nov. 2026, docs/FACTORY_KONZEPT.md
## Abschnitt 11). Die Logik steckt in ``FactorySim``
## (``GameState.roster.factory_sim()``); hier nur Anzeige und Bedienung.
## Symbole sind Platzhalter -- die Grafik kommt aus Claude Design.
##
## Live laeuft alle ``FactorySim.live_seconds()`` ein Takt, aber nur, solange
## der Reiter offen ist.
##
## Bedienung (28. Nov. 2026, Entwurf des Spielers): die Platine fuellt den
## Bildschirm, unten rechts ein Plus. Plus rollt nach links drei Modi aus:
##   * Verschieben: Gebaeude ziehen oder antippen und Zielfeld tippen; auf
##     ein belegtes Feld wird getauscht, wenn beide Arten dort passen.
##   * Abreissen: Tipp auf ein Gebaeude reisst es ohne Rueckfrage ab (es geht
##     zurueck in den Besitz, der Puffer ins Lager).
##   * Bauen: Kategorien (Foerdern, Verarbeiten, Strom, Logistik); eine
##     Kategorie schiebt ihre Gebaeude nach Tiers geordnet hoch (unten Tier 1).
##     Gebaeude waehlen (oder aufs Feld ziehen), Feld tippen = Vorschau mit
##     kuenftigen Leiterbahnen: gruener Haken = aus dem Besitz setzen,
##     Einkaufswagen = kaufen und setzen, rot = was fehlt. Nochmal tippen
##     bestaetigt.
## Ohne Modus: Gebaeude antippen = Details; die Basis (frueher
## Netzanschluss) zeigt Lager und das Aufruesten = naechstes Tier. Gesperrte
## Felder: einmal tippen = Vorschau mit Preis, nochmal = kaufen.

const GROUPS := [["foerderer", "Fördern", "material"], ["verarbeitung", "Verarbeiten", "recipe"],
	["strom", "Strom", "power"], ["logistik", "Logistik", "adjacent"]]
## Modi von links nach rechts (das Plus steht ganz rechts).
const MODES := [["move", "Verschieben", "location"], ["remove", "Abreißen", "hammer"],
	["build", "Bauen", "kit"]]
const BTN := 52.0
const GAP := 6.0
const GREEN := Color("#5cf2a2")

var _sim: FactorySim
var _board: Board
var _head: Label
## Kopf als Symbole (28. Nov. 2026): "T1", Strom, Takt.
var _tier_label: Label
var _power_label: Label
var _tick_label: Label
var _stage: Control
var _hint: Label
var _plus: Button
var _mode_buttons: Dictionary = {}
var _cat_buttons: Dictionary = {}
var _tray: PanelContainer
var _timer: Timer
## Ziel der Zeilen von ``_row``/``_title`` (ein Popup).
var _box: VBoxContainer

## Gewaehltes Feld (Rahmen + Reichweite), "" = keins.
var selected := ""
## Plus ausgeklappt, Modus ("", "build", "remove", "move"), Kategorie im Baumodus.
var menu_open := false
var mode := ""
var category := ""
## Gewaehlte Gebaeudeart im Baumodus.
var armed := ""
## Vorschau: {"k", "type"} fuers Bauen oder {"chunk": id} fuer Feldgruppen.
var pending: Dictionary = {}
## Leiterbahnen der Bau-Vorschau ([{path, ware}]).
var preview: Array = []
## Verschieben: das gewaehlte Gebaeude.
var move_from := ""
## Waren, die dem Werkbank-Ziel fehlen ({ware: menge}) -- die Platine hebt ihre
## Hersteller hervor.
var goal_wares: Dictionary = {}


func _ready() -> void:
	_sim = GameState.roster.factory_sim()
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 14)
	add_child(stats)
	_tier_label = Arcade.label("", 14, UiKit.MUTED, "bold", 0.1)
	_tier_label.tooltip_text = "Tier"
	_tier_label.mouse_filter = Control.MOUSE_FILTER_PASS
	stats.add_child(_tier_label)
	var power := UiIcon.text("energy", "", 14, UiKit.MUTED, "bold")
	power.tooltip_text = "Strom: gebraucht / vorhanden"
	power.mouse_filter = Control.MOUSE_FILTER_PASS
	_power_label = power.get_child(1)
	stats.add_child(power)
	var tick := UiIcon.text("reroll", "", 14, UiKit.MUTED, "bold")
	tick.tooltip_text = "Takte"
	tick.mouse_filter = Control.MOUSE_FILTER_PASS
	_tick_label = tick.get_child(1)
	stats.add_child(tick)
	_head = UiKit.label("", UiKit.SMALL, UiKit.MUTED)
	add_child(_head)
	# Hinweiszeile: fest zwei Zeilen hoch, damit die Platine nicht springt.
	_hint = UiKit.label("", UiKit.SMALL, UiKit.MUTED)
	_hint.custom_minimum_size = Vector2(0, 38)
	_hint.max_lines_visible = 2
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(_hint)
	_stage = Control.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.custom_minimum_size = Vector2(0, 380)
	_stage.clip_contents = true
	add_child(_stage)
	_board = Board.new(self)
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(_board)
	_tray = PanelContainer.new()
	# Ohne Kasten (Wunsch des Spielers): nur die Gebaeude selbst verdecken die Platine.
	_tray.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray.visible = false
	_stage.add_child(_tray)
	for m in MODES:
		var button := _round_button(str(m[2]), UiKit.BAD if m[0] == "remove" else Arcade.YELLOW)
		button.tooltip_text = str(m[1])
		var id := str(m[0])
		button.pressed.connect(func(): _choose_mode(id))
		button.visible = false
		_stage.add_child(button)
		_mode_buttons[id] = button
	for g in GROUPS:
		var button := _round_button(str(g[2]), UiKit.ACCENT)
		button.tooltip_text = str(g[1])
		var id := str(g[0])
		button.pressed.connect(func(): _choose_category(id))
		button.visible = false
		_stage.add_child(button)
		_cat_buttons[id] = button
	_plus = _round_button("plus", UiKit.ON_PRIMARY)
	_plus.tooltip_text = "Bauen, Verschieben, Abreißen"
	_plus.pressed.connect(_toggle_menu)
	_stage.add_child(_plus)
	_stage.resized.connect(func(): _layout(false))
	_timer = Timer.new()
	_timer.wait_time = FactorySim.live_seconds()
	_timer.timeout.connect(_live_tick)
	add_child(_timer)
	_timer.start()
	# Einmal rechnen, damit Status und Strom gleich stehen.
	if _sim.info.is_empty():
		_live_tick()
	else:
		refresh()
	_restyle_controls()
	_say("")
	_layout.call_deferred(false)


func _exit_tree() -> void:
	GameState.save_roster()


func _live_tick() -> void:
	_sim.tick()
	GameState.save_roster()
	refresh()


## Nach jedem Takt und jeder Handlung: Kopfzeile und Platine.
func refresh() -> void:
	_tier_label.text = "T%d" % _sim.tier()
	_power_label.text = "%s/%s" % [FactorySim.num(float(_sim.power["used"])),
		FactorySim.num(float(_sim.power["supply"]))]
	_tick_label.text = str(_sim.tick_count())
	_head.text = ""
	goal_wares = {}
	if _sim.goal() != "":
		var bench := Workbench.new(GameState.roster)
		goal_wares = bench.raw_shortfall(_sim.goal())
		var parts: Array = []
		for ware in goal_wares:
			parts.append("%d %s" % [int(goal_wares[ware]), FactorySim.ware_name(str(ware))])
		_head.text = "ZIEL %s: %s" % [bench.name_of(_sim.goal()).to_upper(),
			"fehlt " + ", ".join(parts) if not parts.is_empty() else "alles da – Werkbank"]
	_head.visible = _head.text != ""
	_board.queue_redraw()


func _say(text: String, color: Color = UiKit.WARN) -> void:
	_hint.text = text
	_hint.modulate = color


# ---------------------------------------------------------------- Knoepfe

func _round_button(icon: String, color: Color) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(BTN, BTN)
	button.size = Vector2(BTN, BTN)
	button.focus_mode = Control.FOCUS_NONE
	UiIcon.on_button(button, icon, 26, color, "center")
	return button


func _button_style(button: Button, line: Color, filled: bool) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(line, 0.9) if filled else Color(UiKit.BG, 0.92)
		box.border_color = line
		box.set_border_width_all(2)
		box.corner_radius_top_left = 10
		box.corner_radius_bottom_right = 10
		box.shadow_size = 1
		box.shadow_offset = Vector2(3, 3)
		box.shadow_color = Color(UiKit.MAGENTA, 0.6) if filled else Color(0, 0, 0, 0.4)
		box.draw_center = state != "focus" or filled
		button.add_theme_stylebox_override(state, box)


func _restyle_controls() -> void:
	_button_style(_plus, Arcade.YELLOW, true)
	UiIcon.on_button(_plus, "close" if menu_open else "plus", 26, UiKit.ON_PRIMARY, "center")
	for id in _mode_buttons:
		var color := UiKit.BAD if id == "remove" else Arcade.YELLOW
		_button_style(_mode_buttons[id], color, mode == id)
		UiIcon.on_button(_mode_buttons[id], str(_mode_icon(id)), 26,
			UiKit.ON_PRIMARY if mode == id else color, "center")
	for id in _cat_buttons:
		_button_style(_cat_buttons[id], UiKit.ACCENT, category == id)
		UiIcon.on_button(_cat_buttons[id], _group(id)[2], 26,
			UiKit.ON_PRIMARY if category == id else UiKit.ACCENT, "center")


func _mode_icon(id: String) -> String:
	for m in MODES:
		if m[0] == id:
			return str(m[2])
	return "unknown"


func _group(id: String) -> Array:
	for g in GROUPS:
		if g[0] == id:
			return g
	return ["", "", "unknown"]


## Unten verdeckter Platz (Knopfleiste, ggf. Bauleiste) -- die Platine
## rueckt darueber.
func bottom_reserve() -> float:
	var r := BTN + 10.0
	if _tray != null and _tray.visible:
		r += _tray.get_combined_minimum_size().y + 6.0
	return r


## Rechts das Plus, links daneben die sichtbaren Knoepfe; was neu dazukommt,
## rollt vom Plus aus nach links.
func _layout(animate: bool = true) -> void:
	if _stage == null or _plus == null:
		return
	var w := _stage.size.x
	var h := _stage.size.y
	var y := h - BTN - 4.0
	_plus.position = Vector2(w - BTN, y)
	var row: Array = []    # von rechts nach links
	if menu_open:
		if mode == "build":
			row.append(_mode_buttons["build"])
			for i in range(GROUPS.size() - 1, -1, -1):
				row.append(_cat_buttons[GROUPS[i][0]])
		else:
			for i in range(MODES.size() - 1, -1, -1):
				row.append(_mode_buttons[MODES[i][0]])
	var all: Array = _mode_buttons.values() + _cat_buttons.values()
	var moving := animate and Accessibility.motion() > 0.0
	for button in all:
		var b: Button = button
		var at := row.find(b)
		if at < 0:
			if b.visible and moving:
				var tween := b.create_tween().set_parallel()
				tween.tween_property(b, "position", _plus.position, 0.12)
				tween.tween_property(b, "modulate:a", 0.0, 0.12)
				tween.chain().tween_callback(func(): b.visible = false)
			else:
				b.visible = false
			continue
		var target := Vector2(w - BTN - (at + 1) * (BTN + GAP), y)
		if not b.visible and moving:
			b.position = _plus.position
			b.modulate.a = 0.0
			b.visible = true
			var tween := b.create_tween().set_parallel()
			tween.tween_property(b, "position", target, 0.18 + 0.03 * at).set_trans(Tween.TRANS_BACK) \
				.set_ease(Tween.EASE_OUT)
			tween.tween_property(b, "modulate:a", 1.0, 0.12)
		else:
			b.visible = true
			b.modulate.a = 1.0
			b.position = target
	# Die Gebaeude der Kategorie schieben sich ueber der Leiste hoch.
	var show_tray := menu_open and mode == "build" and category != ""
	if show_tray:
		# Ueber dem Knopf der Kategorie, am Rand gehalten.
		var tsize := _tray.get_combined_minimum_size()
		_tray.size = tsize
		var under: Button = _cat_buttons[category]
		var cat_x := w - BTN - (row.find(under) + 1) * (BTN + GAP) + BTN / 2.0
		var tx := clampf(cat_x - tsize.x / 2.0, 0.0, maxf(0.0, w - tsize.x))
		var th := tsize.y
		var target_y := y - th - 6.0
		if not _tray.visible and moving:
			_tray.position = Vector2(tx, h)
			_tray.visible = true
			_tray.create_tween().tween_property(_tray, "position:y", target_y, 0.2) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			_tray.visible = true
			_tray.position = Vector2(tx, target_y)
	else:
		_tray.visible = false


# ---------------------------------------------------------------- Modi

func _toggle_menu() -> void:
	Accessibility.tap()
	menu_open = not menu_open
	if not menu_open:
		_leave_mode()
	else:
		_say("")
	_restyle_controls()
	_layout()
	refresh()


func _leave_mode() -> void:
	mode = ""
	category = ""
	armed = ""
	pending = {}
	preview = []
	move_from = ""
	_say("")


func _choose_mode(id: String) -> void:
	Accessibility.tap()
	var was := mode
	_leave_mode()
	if was != id:
		mode = id
	else:
		_say("")
	_restyle_controls()
	_layout()
	refresh()


func _choose_category(id: String) -> void:
	Accessibility.tap()
	category = "" if category == id else id
	armed = ""
	pending = {}
	preview = []
	if category != "":
		_build_tray()
		_tray.visible = false    # damit es neu hochfaehrt
	_say("")
	_restyle_controls()
	_layout()
	refresh()


## Arten der Kategorie nach Tier ({tier: [type]}).
static func types_by_tier(group: String) -> Dictionary:
	var out := {}
	for type in FactorySim.defs():
		var d := FactorySim.def(type)
		if str(d.get("gruppe", "")) != group:
			continue
		var t := int(d.get("tier", 1))
		if not out.has(t):
			out[t] = []
		out[t].append(type)
	return out


## "bereit" = freies Exemplar im Besitz, "kaufen" = Tier frei, aber keins
## uebrig, "gesperrt" = erst ab hoeherem Tier.
func type_state(type: String) -> String:
	var d := FactorySim.def(type)
	if int(d.get("tier", 1)) > _sim.tier():
		return "gesperrt"
	return "bereit" if _sim.owned(type) > _sim.placed(type) else "kaufen"


func _build_tray() -> void:
	UiKit.clear(_tray)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	_tray.add_child(rows)
	var tiers := types_by_tier(category)
	var keys := tiers.keys()
	keys.sort()
	keys.reverse()    # oben das hoechste Tier, unten Tier 1
	for t in keys:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		rows.add_child(line)
		for type in tiers[t]:
			line.add_child(_item_button(str(type)))


func _item_button(type: String) -> ItemButton:
	var d := FactorySim.def(type)
	var state := type_state(type)
	var col := Color(str(d["farbe"]))
	var button := ItemButton.new(self, type)
	var sub := "%d frei" % (_sim.owned(type) - _sim.placed(type))
	if state == "kaufen":
		sub = "kaufen"
	elif state == "gesperrt":
		sub = "Tier %d" % int(d["tier"])
	button.text = "%s\n%s" % [str(d["kurz"]), sub]
	button.tooltip_text = str(d["name"])
	button.custom_minimum_size = Vector2(68, 60)
	button.add_theme_font_override("font", Arcade.font("display", 14, 0.04))
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", col if state == "bereit" else UiKit.MUTED)
	_button_style(button, col if state == "bereit" else UiKit.CARD_LINE, false)
	if armed == type:
		_button_style(button, Arcade.YELLOW, false)
		button.add_theme_color_override("font_color", Arcade.YELLOW)
	# Grau ueber die Farben, nicht ueber Transparenz -- ohne Kasten dahinter
	# bliebe die Schrift sonst schlecht lesbar.
	if state == "gesperrt":
		button.modulate = Color(0.55, 0.55, 0.6, 1.0)
	button.pressed.connect(func(): _arm(type))
	return button


## Gebaeude im Baumodus waehlen; nochmal tippen = Details.
func _arm(type: String) -> void:
	Accessibility.tap()
	if armed == type:
		_open_type_details(type)
		return
	armed = type
	pending = {}
	preview = []
	var d := FactorySim.def(type)
	match type_state(type):
		"bereit":
			_say("%s · %d frei" % [str(d["name"]), _sim.owned(type) - _sim.placed(type)], Arcade.YELLOW)
		"kaufen":
			_say("%s · %s" % [str(d["name"]), FactorySim.amounts_text(d.get("preis", {}))], Arcade.YELLOW)
		_:
			armed = ""
			_say("")
			_open_type_details.call_deferred(type)
	_build_tray()
	_layout(false)
	refresh()


# ---------------------------------------------------------------- Tippen

## Ein Tipp auf die Platine.
func tapped(k: String) -> void:
	if k not in FactorySim.cells():
		selected = ""
		pending = {}
		preview = []
		move_from = ""
		refresh()
		return
	if not _sim.unlocked(k):
		_tap_locked(k)
	else:
		match mode:
			"build": _tap_build(k)
			"remove": _tap_remove(k)
			"move": _tap_move(k)
			_: _tap_look(k)
	refresh()


func _tap_look(k: String) -> void:
	pending = {}
	preview = []
	selected = k
	if k == FactorySim.net_cell():
		_say("")
		_open_basis()
	elif not _sim.building_at(k).is_empty():
		_say("")
		_open_building_details(k)
	else:
		var src := FactorySim.source_at(k)
		_say("%s · %s" % [FactorySim.source_name(src), FactorySim.ware_name(FactorySim.source_ware(src))]
			if src != "" else "", UiKit.MUTED)


func _tap_locked(k: String) -> void:
	var c := FactorySim.chunk_of(k)
	if c.is_empty():
		return
	var id := str(c["id"])
	var price: Dictionary = c.get("preis", {})
	preview = []
	if int(c.get("tier", 1)) > _sim.tier():
		pending = {}
		_say("Felder %s erst ab Tier %d." % [str(c["name"]), int(c["tier"])], UiKit.MUTED)
		return
	if str(pending.get("chunk", "")) == id:
		var gap := _sim.missing(price)
		if not gap.is_empty():
			_say("Felder %s: fehlt %s." % [str(c["name"]), FactorySim.amounts_text(gap)], UiKit.BAD)
			return
		var why := _sim.buy_chunk(id)
		pending = {}
		_say(why if why != "" else "Felder %s gekauft." % str(c["name"]), UiKit.BAD if why != "" else GREEN)
		if why == "":
			GameState.save_roster()
		return
	pending = {"chunk": id}
	selected = ""
	var gap := _sim.missing(price)
	if gap.is_empty():
		_say("Felder %s · %s" % [str(c["name"]), FactorySim.amounts_text(price)], GREEN)
	else:
		_say("Felder %s · %s · fehlt %s" % [str(c["name"]), FactorySim.amounts_text(price),
			FactorySim.amounts_text(gap)], UiKit.BAD)


func _tap_build(k: String) -> void:
	if armed == "":
		_say("")
		return
	if str(pending.get("k", "")) == k and str(pending.get("type", "")) == armed:
		_confirm_build()
		return
	show_build_preview(k, armed)


## Vorschau einer Art auf einem Feld (auch beim Ziehen aus der Leiste).
func show_build_preview(k: String, type: String) -> void:
	var why := _sim.fits(k, type)
	if why == "" and not _sim.building_at(k).is_empty():
		why = "Hier steht schon etwas."
	if why != "":
		pending = {}
		preview = []
		_say(why, UiKit.MUTED)
		return
	pending = {"k": k, "type": type}
	preview = _sim.preview_traces(k, type)
	selected = ""
	var d := FactorySim.def(type)
	var links := _preview_text()
	match pending_state():
		"own":
			_say("%s%s" % [str(d["name"]), links], GREEN)
		"buy":
			_say("%s · %s%s" % [str(d["name"]), FactorySim.amounts_text(d.get("preis", {})), links], GREEN)
		_:
			_say("%s · fehlt %s%s" % [str(d["name"]), FactorySim.amounts_text(pending_missing()), links], UiKit.BAD)


func _preview_text() -> String:
	var parts: Array = []
	for tr in preview:
		var path: Array = tr["path"]
		var from := _sim.building_at(str(path[0]))
		var name := str(FactorySim.def(str(from["t"]))["name"]) if not from.is_empty() \
			else str(FactorySim.def(str(pending.get("type", "")))["name"])
		parts.append("%s %s" % [FactorySim.ware_name(str(tr["ware"])),
			"von " + name if str(path[0]) != str(pending.get("k", "")) else "an " + _name_at(str(path[path.size() - 1]))])
	if parts.is_empty():
		return " · keine Verbindung"
	return " · " + ", ".join(parts)


func _name_at(k: String) -> String:
	var b := _sim.building_at(k)
	return str(FactorySim.def(str(b["t"]))["name"]) if not b.is_empty() else "?"


## "own" = aus dem Besitz, "buy" = kaufen und setzen, "poor" = zu wenig im Lager.
func pending_state() -> String:
	var type := str(pending.get("type", ""))
	if type == "":
		return ""
	if _sim.owned(type) > _sim.placed(type):
		return "own"
	return "buy" if pending_missing().is_empty() else "poor"


func pending_missing() -> Dictionary:
	if pending.has("chunk"):
		var c := {}
		for entry in FactorySim.chunks():
			if str(entry["id"]) == str(pending["chunk"]):
				c = entry
		return _sim.missing(c.get("preis", {}))
	var type := str(pending.get("type", ""))
	return _sim.missing(FactorySim.def(type).get("preis", {})) if type != "" else {}


func _confirm_build() -> void:
	var k := str(pending["k"])
	var type := str(pending["type"])
	var name := str(FactorySim.def(type)["name"])
	var why := ""
	match pending_state():
		"own": why = _sim.place(k, type)
		"buy": why = _sim.buy_and_place(k, type)
		_:
			_say("%s: fehlt %s." % [name, FactorySim.amounts_text(pending_missing())], UiKit.BAD)
			return
	if why != "":
		_say(why, UiKit.BAD)
		return
	Accessibility.vibrate(20)
	pending = {}
	preview = []
	selected = k
	GameState.save_roster()
	_say("%s gebaut" % name, GREEN)
	_build_tray()
	_layout(false)


func _tap_remove(k: String) -> void:
	var b := _sim.building_at(k)
	if b.is_empty():
		_say("Die Basis bleibt stehen." if k == FactorySim.net_cell() else "", UiKit.MUTED)
		return
	var name := str(FactorySim.def(str(b["t"]))["name"])
	_sim.remove(k)
	Accessibility.vibrate(15)
	selected = ""
	GameState.save_roster()
	_say("%s abgerissen" % name, UiKit.BAD)


func _tap_move(k: String) -> void:
	if move_from == "":
		if _sim.building_at(k).is_empty():
			_say("")
			return
		move_from = k
		selected = k
		_say(_name_at(k), Arcade.YELLOW)
		return
	if k == move_from:
		move_from = ""
		selected = ""
		_say("")
		return
	move_to(move_from, k)


## Verschieben bzw. tauschen (Tippen oder Ziehen).
func move_to(from: String, to: String) -> void:
	var name := _name_at(from)
	var swap := not _sim.building_at(to).is_empty()
	var other := _name_at(to) if swap else ""
	var why := _sim.move(from, to)
	if why != "":
		_say(why, UiKit.BAD)
		return
	Accessibility.vibrate(15)
	move_from = ""
	selected = to
	GameState.save_roster()
	_say(("%s und %s getauscht." % [name, other]) if swap else "%s verschoben." % name, GREEN)


## Darf ``from`` auf ``to`` (frei oder tauschbar)? Fuer die Markierung.
func move_target_ok(from: String, to: String) -> bool:
	var a := _sim.building_at(from)
	if a.is_empty() or from == to or _sim.fits(to, str(a["t"])) != "":
		return false
	var b := _sim.building_at(to)
	return b.is_empty() or _sim.fits(from, str(b["t"])) == ""


## Aus der Leiste aufs Feld gezogen: Bau-Vorschau (bestaetigt wird per Tipp).
func drop_type(k: String, type: String) -> void:
	if type_state(type) == "gesperrt":
		return
	armed = type
	show_build_preview(k, type)
	_build_tray()
	_layout(false)
	refresh()


# ---------------------------------------------------------------- Popups

func _open_type_details(type: String) -> void:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	_box = body
	_tool_info(type)
	InfoPopup.open(self, "", {"sheet": true, "body": body})


func _open_building_details(k: String) -> void:
	var b := _sim.building_at(k)
	if b.is_empty():
		return
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	_box = body
	_building_info(k, b)
	InfoPopup.open(self, "", {"sheet": true, "body": body})


## Die Basis (frueher Netzanschluss): Strom, Lager und Aufruesten = naechstes Tier.
func _open_basis() -> void:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	_box = body
	var netz: Dictionary = FactorySim.data().get("netz", {})
	var si: Dictionary = _sim.source_info.get(FactorySim.net_cell(), {})
	_row("Strom %s/%d · Reichweite %d" % [FactorySim.num(float(si.get("used", 0.0))), int(netz.get("strom", 4)),
		int(netz.get("reichweite", 2))], UiKit.MUTED)
	_store_into(body)
	var actions: Array = []
	var goal := _sim.next_tier_goal()
	if goal.is_empty():
		body.add_child(Arcade.label("ALLE TIERS FREI", 14, Arcade.CYAN, "bold", 0.2))
	else:
		body.add_child(Arcade.label("TIER %d" % int(goal["tier"]), 14, Arcade.CYAN, "bold", 0.2))
		if str(goal.get("weg", "fabrik")) == "fabrik":
			var cost: Dictionary = goal.get("kosten", {})
			for ware in cost:
				var have := _sim.have(str(ware))
				_row("%s  %d / %d" % [FactorySim.ware_name(str(ware)), mini(have, int(cost[ware])), int(cost[ware])],
					UiKit.GOOD if have >= int(cost[ware]) else UiKit.TEXT, 14)
			# Gelb erst, wenn es geht; die Voraussetzungen stehen darueber.
			var ready := _sim.can_pay(cost)
			actions.append({"text": "Aufrüsten", "primary": ready, "disabled": not ready,
				"call": func():
					var why := _sim.unlock_tier()
					_say(why if why != "" else "Basis aufgerüstet: Tier %d!" % _sim.tier(),
						UiKit.BAD if why != "" else GREEN)
					GameState.save_roster()
					refresh()})
	InfoPopup.open(self, "Basis · Tier %d" % _sim.tier(), {"sheet": true, "body": body, "actions": actions})


func _store_into(box: VBoxContainer) -> void:
	box.add_child(Arcade.label("LAGER", 14, Arcade.CYAN, "bold", 0.2))
	var mission := FactorySim.ticks_per_battle() * RunState.rounds_total()
	var proj := _sim.projection(mission)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	var note := UiKit.label("", 13, UiKit.MUTED)
	note.visible = false
	for ware in FactorySim.wares():
		var n := _sim.have(str(ware))
		var line := "%s  %d" % [FactorySim.ware_name(str(ware)), n]
		if int(proj.get(ware, 0)) > 0:
			line += " (+%d)" % int(proj[ware])
		var label := UiKit.label(line, 14, FactorySim.ware_color(str(ware)) if n > 0 else UiKit.MUTED)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(label)
		# Die Zahl in Klammern erklaert sich erst auf Tipp (Wunsch des Spielers).
		if int(proj.get(ware, 0)) > 0:
			var amount := int(proj[ware])
			var name := FactorySim.ware_name(str(ware))
			label.mouse_filter = Control.MOUSE_FILTER_STOP
			label.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					note.text = "+%d %s je Einsatz (Hochrechnung)" % [amount, name]
					note.visible = true)
	box.add_child(note)


# ---------------------------------------------------------------- Info-Zeilen

func _row(text: String, color: Color = UiKit.TEXT, size: int = UiKit.SMALL) -> Label:
	var label := UiKit.label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(label)
	return label


func _title(code: String, name: String, color: Color) -> void:
	_box.add_child(Arcade.label(("%s  %s" % [code, name]).strip_edges().to_upper(), 16, color, "bold", 0.1))


func _building_info(k: String, b: Dictionary) -> void:
	var type := str(b["t"])
	var d := FactorySim.def(type)
	var inf := _sim.info_of(k)
	var res := _sim.resonance(k)
	_title(str(d["kurz"]), "%s · Tier %d" % [str(d["name"]), int(d.get("tier", 1))], Color(str(d["farbe"])))
	_row(FactorySim.recipe_text(type))
	var status := _sim.status_text(k)
	if res > 0.0:
		status += " · Resonanz +%d %%" % int(roundf(res * 100.0))
	if d.has("liefert") and not d.has("brennstoff") and not d.get("batterie", false) and _sim.shaded(k):
		status += " · Schatten: nur 0,5 Strom"
	_row(status, _status_color(str(inf.get("status", "ok"))))
	var factor := int(FactorySim.setting("eingang_mal_rezept", 10))
	for ware in d.get("ein", {}):
		var per := 1.0 if d.has("brennstoff") else float(d["ein"][ware]) * float(d.get("rate", 1)) * (1.0 + res)
		_row("%s: braucht %s/Takt · kommt %s/Takt · Puffer %d/%d" % [FactorySim.ware_name(str(ware)),
			FactorySim.num(per), FactorySim.num(_sim.avg_in(k, str(ware))), int(b["in"].get(ware, 0)),
			int(d["ein"][ware]) * factor], UiKit.MUTED)
	if d.has("aus"):
		var per_tick := _sim.avg_out(k)
		var mission := FactorySim.ticks_per_battle() * RunState.rounds_total()
		_row("Ausstoß: %s Durchläufe/Takt (max %s) · ≈ %d je Einsatz" % [FactorySim.num(per_tick),
			FactorySim.num(float(d.get("rate", 1)) * (1.0 + res)), int(roundf(per_tick * mission))], UiKit.MUTED)
		var outs: Array = []
		for ware in d["aus"]:
			outs.append("%s %d/%d" % [FactorySim.ware_name(str(ware)), int(b["out"].get(ware, 0)),
				int(FactorySim.setting("ausgang", 10))])
		_row("Ausgang: " + " · ".join(outs), UiKit.MUTED)
		var up := _sim.avg_up(k)
		if not up.is_empty():
			var ups: Array = []
			for ware in up:
				ups.append("+%s %s" % [FactorySim.num(float(up[ware])), FactorySim.ware_name(str(ware))])
			_row("Per Uplink ins Lager: %s je Takt" % ", ".join(ups), UiKit.WARN)
	if float(d.get("strom", 0)) > 0.0:
		_row("Strom: bekommt %s von %s" % [FactorySim.num(float(inf.get("got", 0.0))),
			FactorySim.num(float(inf.get("need", 0.0)))] if float(inf.get("need", 0.0)) > 0.0
			else "Strom: braucht %d (gerade nichts zu tun)" % int(d["strom"]), UiKit.MUTED)
	if d.has("liefert"):
		var si: Dictionary = _sim.source_info.get(k, {})
		_row("Abgabe: %s von %s Strom · Reichweite %d (gelb markiert)" % [
			FactorySim.num(float(si.get("used", 0.0))), FactorySim.num(float(si.get("cap", 0.0))),
			int(d.get("reichweite", 0))], UiKit.MUTED)
	if d.get("batterie", false):
		_row("Ladung: %s / %d" % [FactorySim.num(float(b["charge"])), int(d.get("speicher", 20))], UiKit.MUTED)
	if d.has("brennstoff"):
		_row("Brenner: " + ("gezündet" if b["on"] else "aus, zündet bei %d %s" % [
			int(FactorySim.setting("zuenden_bei", 5)), FactorySim.ware_name(str(d["brennstoff"]))]), UiKit.MUTED)


func _tool_info(type: String) -> void:
	var d := FactorySim.def(type)
	_title(str(d["kurz"]), "%s · Tier %d" % [str(d["name"]), int(d.get("tier", 1))], Color(str(d["farbe"])))
	var power := ""
	if float(d.get("strom", 0)) > 0.0:
		power = " · braucht %d Strom" % int(d["strom"])
	_row(FactorySim.recipe_text(type) + power)
	_row(str(d.get("text", "Holt seine Zutaten bei den Nachbarn ab.")), UiKit.MUTED)
	_row("Besitz %d · gebaut %d · Preis je Stück %s" % [_sim.owned(type), _sim.placed(type),
		FactorySim.amounts_text(d.get("preis", {}))], UiKit.MUTED)
	if int(d.get("tier", 1)) > _sim.tier():
		_row("Erst ab Tier %d." % int(d["tier"]), UiKit.WARN)


static func _status_color(status: String) -> Color:
	match status:
		"anlauf": return Color("#9d84ff")
		"wait": return UiKit.MAGENTA
		"strom": return Color("#ff6a3d")
		"uplink": return UiKit.WARN
		"relay": return Color("#9d84ff")
	return UiKit.ACCENT




# ---------------------------------------------------------------- Leiste

## Ein Gebaeude in der Bauleiste: tippen waehlt, ziehen legt es aufs Feld.
class ItemButton extends Button:
	var view: FactoryView
	var type: String

	func _init(owner_view: FactoryView, item_type: String) -> void:
		view = owner_view
		type = item_type
		focus_mode = Control.FOCUS_NONE

	func _get_drag_data(_at: Vector2) -> Variant:
		if view.type_state(type) == "gesperrt":
			return null
		var ghost := Label.new()
		ghost.text = str(FactorySim.def(type)["kurz"])
		ghost.add_theme_font_override("font", Arcade.font("display", 20, 0.04))
		ghost.add_theme_font_size_override("font_size", 20)
		ghost.modulate = Color(Color(str(FactorySim.def(type)["farbe"])), 0.8)
		set_drag_preview(ghost)
		return {"factory_type": type}


# ---------------------------------------------------------------- Platine

class Board extends Control:
	const SLOP := 12.0
	var view: FactoryView
	var _size := 30.0
	var _pulse := 0.0
	## Ziehen im Verschiebe-Modus: Startfeld, Fingerlage, ob schon gezogen wird.
	var _press_cell := ""
	var _press_at := Vector2.ZERO
	var _dragging := false
	var _finger := Vector2.ZERO
	## Zuletzt beim Ziehen aus der Leiste angezeigtes Feld.
	var _hover := ""

	func _init(owner_view: FactoryView) -> void:
		view = owner_view
		mouse_filter = Control.MOUSE_FILTER_STOP

	## Platz fuer die Platine: ganze Breite, unten Knopfleiste und Bauleiste frei.
	func _free_height() -> float:
		return size.y - view.bottom_reserve()

	func _origin() -> Vector2:
		return Vector2(size.x / 2.0, _free_height() / 2.0)

	func _process(delta: float) -> void:
		_pulse += delta
		var fit := maxf(12.0, minf(size.x / 11.2, (_free_height() - 8.0) / (7.0 * sqrt(3.0) + 0.6)))
		if absf(fit - _size) > 0.1:
			_size = fit
			queue_redraw()
		if view._sim.engpass != "" or view.mode != "" or not view.pending.is_empty():
			queue_redraw()

	func center(k: String) -> Vector2:
		var p := FactorySim.unkey(k)
		return _origin() + Vector2(_size * 1.5 * p.x, _size * sqrt(3.0) * (p.y + p.x / 2.0))

	func key_at(pos: Vector2) -> String:
		var v := pos - _origin()
		var q := (2.0 / 3.0 * v.x) / _size
		var r := (-1.0 / 3.0 * v.x + sqrt(3.0) / 3.0 * v.y) / _size
		var s := -q - r
		var rq := roundf(q)
		var rr := roundf(r)
		var rs := roundf(s)
		var dq := absf(rq - q)
		var dr := absf(rr - r)
		var ds := absf(rs - s)
		if dq > dr and dq > ds:
			rq = -rr - rs
		elif dr > ds:
			rr = -rq - rs
		return FactorySim.key(int(rq), int(rr))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_cell = key_at(event.position)
				_press_at = event.position
				_dragging = false
			else:
				var cell := key_at(event.position)
				if _dragging:
					_dragging = false
					view.move_from = ""
					if cell != _press_cell and cell in FactorySim.cells():
						view.move_to(_press_cell, cell)
					view.refresh()
				elif _press_cell != "":
					view.tapped(cell)
				_press_cell = ""
			accept_event()
		elif event is InputEventMouseMotion and _press_cell != "":
			_finger = event.position
			if not _dragging and view.mode == "move" and event.position.distance_to(_press_at) > SLOP \
					and not view._sim.building_at(_press_cell).is_empty():
				_dragging = true
				view.move_from = _press_cell
				view.selected = _press_cell
			if _dragging:
				queue_redraw()

	func _can_drop_data(at: Vector2, data: Variant) -> bool:
		if not (data is Dictionary and (data as Dictionary).has("factory_type")):
			return false
		var cell := key_at(at)
		if cell != _hover and cell in FactorySim.cells():
			_hover = cell
			view.show_build_preview(cell, str(data["factory_type"]))
			view.refresh()
		return true

	func _drop_data(at: Vector2, data: Variant) -> void:
		_hover = ""
		view.drop_type(key_at(at), str(data["factory_type"]))

	func _hex(c: Vector2, radius: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 7:
			var a := PI / 3.0 * i
			pts.append(c + Vector2(cos(a), sin(a)) * radius)
		return pts

	func _icon(name: String, c: Vector2, edge: float, color: Color) -> void:
		var tex := UiIcon.texture(name)
		if tex != null:
			draw_texture_rect(tex, Rect2(c - Vector2(edge, edge) / 2.0, Vector2(edge, edge)), false, color)

	func _draw() -> void:
		var sim := view._sim
		var pa := 0.5 + 0.5 * sin(_pulse * 5.5)
		var font := Arcade.font("display")
		var small := Arcade.font("bold")
		var sel := view.selected
		var reach := sim.range_of(sel) if sel != "" else -1
		var pend_chunk := str(view.pending.get("chunk", ""))
		var armed := view.armed if view.mode == "build" else ""
		for k in FactorySim.cells():
			var c := center(k)
			var hex := _hex(c, _size * 0.94)
			var src := FactorySim.source_at(k)
			if not sim.unlocked(k):
				# Gesperrt: dunkel, gestrichelt; in der Kauf-Vorschau gruen bzw. rot.
				draw_colored_polygon(hex, Color(0.03, 0.01, 0.07, 0.85))
				var chunk_id := str(FactorySim.chunk_of(k).get("id", ""))
				if chunk_id == pend_chunk and pend_chunk != "":
					var ok := view.pending_missing().is_empty()
					draw_colored_polygon(_hex(c, _size * 0.86), Color(FactoryView.GREEN if ok else UiKit.BAD, 0.22))
					_icon("bag", c, _size * 0.7, Color(FactoryView.GREEN if ok else UiKit.BAD, 0.9))
				for i in 6:
					var a := hex[i]
					var b := hex[i + 1]
					draw_line(a, a.lerp(b, 0.45), Color("#9a86c4", 0.35), 1.0)
				if src != "":
					draw_circle(c, _size * 0.17, Color(FactorySim.ware_color(FactorySim.source_ware(src)), 0.45))
				continue
			var b := sim.building_at(k)
			draw_colored_polygon(hex, Color("#160a30") if not b.is_empty() else Color("#1b0b3a"))
			draw_polyline(hex, Color("#2ee3eb", 0.25), 1.0)
			if reach >= 0 and k != sel and FactorySim.distance(sel, k) <= reach:
				draw_colored_polygon(hex, Color("#ffe14d", 0.10))
			if src != "" and b.is_empty():
				var col := FactorySim.ware_color(FactorySim.source_ware(src))
				draw_circle(c, _size * 0.42, Color(col, 0.16))
				draw_arc(c, _size * 0.42, 0, TAU, 24, Color(col, 0.8), 2.0)
				draw_string(font, c + Vector2(-_size, _size * 0.14), src, HORIZONTAL_ALIGNMENT_CENTER,
					_size * 2.0, int(_size * 0.38), col)
			# Moegliche Ziele des Modus pulsieren gelb.
			var target := false
			if armed != "" and b.is_empty() and sim.fits(k, armed) == "":
				target = true
			elif view.mode == "move" and view.move_from != "" and view.move_target_ok(view.move_from, k):
				target = true
			if target:
				draw_polyline(_hex(c, _size * 0.8), Color("#ffe14d", 0.3 + 0.45 * pa), 1.5)
			if sel == k and b.is_empty() and k != FactorySim.net_cell():
				draw_polyline(_hex(c, _size * 0.96), Color("#ffe14d"), 2.5)
		_draw_basis(font, small, sel)
		# Leiterbahnen: gedimmt, wenn der Abnehmer gerade nichts holt (Stau).
		for tr in sim.traces():
			var path: Array = tr["path"]
			var pts := PackedVector2Array()
			for k in path:
				pts.append(center(str(k)))
			var target_info := sim.info_of(str(path[path.size() - 1]))
			var hist: Array = target_info.get("in_h", [])
			var got := float((hist.back() as Dictionary).get(tr["ware"], 0)) if not hist.is_empty() else 0.0
			draw_polyline(pts, Color(FactorySim.ware_color(str(tr["ware"])), 0.45 if got > 0.0 else 0.15), 3.0)
		for k in sim.buildings():
			_draw_building(k, font, small, sel, pa)
		_draw_pending(font, small, pa)
		if _dragging and _press_cell != "":
			var b := sim.building_at(_press_cell)
			if not b.is_empty():
				var d := FactorySim.def(str(b["t"]))
				var col := Color(str(d["farbe"]))
				draw_colored_polygon(_hex(_finger, _size * 0.78), Color("#0f0724", 0.8))
				draw_polyline(_hex(_finger, _size * 0.78), col, 2.0)
				draw_string(font, _finger + Vector2(-_size, _size * 0.06), str(d["kurz"]),
					HORIZONTAL_ALIGNMENT_CENTER, _size * 2.0, int(_size * 0.32), col)

	func _draw_basis(font: Font, small: Font, sel: String) -> void:
		var sim := view._sim
		var nc := center(FactorySim.net_cell())
		draw_colored_polygon(_hex(nc, _size * 0.86), Color("#241046"))
		draw_polyline(_hex(nc, _size * 0.86), Color("#ffe14d"), 2.5)
		draw_polyline(_hex(nc, _size * 0.7), Color("#ffe14d", 0.4), 1.0)
		if sel == FactorySim.net_cell():
			draw_polyline(_hex(nc, _size * 0.98), Color("#fff7fe"), 2.5)
		draw_string(font, nc + Vector2(-_size, -_size * 0.02), "BASIS", HORIZONTAL_ALIGNMENT_CENTER,
			_size * 2.0, int(_size * 0.24), Color("#ffe14d"))
		var si: Dictionary = sim.source_info.get(FactorySim.net_cell(), {})
		draw_string(small, nc + Vector2(-_size, _size * 0.34), "T%d · %s/%d" % [sim.tier(),
			FactorySim.num(float(si.get("used", 0.0))), int((FactorySim.data().get("netz", {}) as Dictionary).get("strom", 4))],
			HORIZONTAL_ALIGNMENT_CENTER, _size * 2.0, int(_size * 0.2), Color("#ffe14d"))

	func _draw_building(k: String, font: Font, small: Font, sel: String, pa: float) -> void:
		var sim := view._sim
		var b := sim.building_at(k)
		var d := FactorySim.def(str(b["t"]))
		var inf := sim.info_of(k)
		var c := center(k)
		if _dragging and k == _press_cell:
			draw_polyline(_hex(c, _size * 0.78), Color(str(d["farbe"]), 0.35), 1.5)
			return
		var col := Color(str(d["farbe"]))
		var hex := _hex(c, _size * 0.78)
		draw_colored_polygon(hex, Color("#0f0724"))
		var line_col := col
		if d.get("relais", false) and not b["rel_on"]:
			line_col = Color(col, 0.4)
		draw_polyline(hex, line_col, 2.0)
		if view.mode == "remove":
			draw_polyline(_hex(c, _size * 0.9), Color(UiKit.BAD, 0.35 + 0.5 * pa), 2.5)
		# Werkbank-Ziel: Hersteller fehlender Waren gelb markiert.
		for ware in d.get("aus", {}):
			if view.goal_wares.has(ware):
				draw_circle(c + Vector2(_size * 0.5, -_size * 0.5), _size * 0.12, Color("#ffe14d"))
				break
		if sim.engpass == k:
			draw_polyline(_hex(c, _size * 0.9), Color("#ff2bd6", 0.4 + 0.6 * pa), 3.0)
		if sel == k or view.move_from == k:
			draw_polyline(_hex(c, _size * 0.96), Color("#ffe14d"), 2.5)
		draw_string(font, c + Vector2(-_size, _size * 0.06), str(d["kurz"]), HORIZONTAL_ALIGNMENT_CENTER,
			_size * 2.0, int(_size * 0.32), col)
		# Balken: Fortschritt bzw. Ladung/Brennstoff, Farbe nach Status.
		var p := 0.0
		var status := str(inf.get("status", "ok"))
		if d.get("batterie", false):
			p = float(b["charge"]) / float(d.get("speicher", 20))
		elif d.has("brennstoff"):
			p = float(b["in"].get(d["brennstoff"], 0)) / 10.0
		elif not d.get("relais", false) and not d.has("liefert"):
			p = float(b["prog"]) - floorf(float(b["prog"]))
			if status == "anlauf":
				p = 1.0
				for ware in d.get("ein", {}):
					p = minf(p, float(b["in"].get(ware, 0)) / (float(d["ein"][ware]) * float(FactorySim.setting("anlauf", 3))))
		var bar_w := _size * 0.72
		var y := c.y + _size * 0.36
		draw_line(Vector2(c.x - bar_w / 2, y), Vector2(c.x + bar_w / 2, y), Color(1, 1, 1, 0.12), 3.0)
		if p > 0.0:
			draw_line(Vector2(c.x - bar_w / 2, y), Vector2(c.x - bar_w / 2 + bar_w * minf(1.0, p), y),
				FactoryView._status_color(status) if status != "ok" else col, 3.0)
		var res := sim.resonance(k)
		if res > 0.0:
			draw_string(small, c + Vector2(-_size, -_size * 0.42), "+%d%%" % int(roundf(res * 100.0)),
				HORIZONTAL_ALIGNMENT_CENTER, _size * 2.0, int(_size * 0.22), Color("#6dffa8"))
		if float(inf.get("need", 0.0)) > 0.0 and float(inf.get("eff", 1.0)) < 1.0:
			draw_string(small, c + Vector2(-_size * 1.34, -_size * 0.42), "%d%%" % int(roundf(float(inf["eff"]) * 100.0)),
				HORIZONTAL_ALIGNMENT_CENTER, _size * 2.0, int(_size * 0.22), Color("#ff6a3d"))

	## Bau-Vorschau: kuenftige Leiterbahnen, durchsichtiges Gebaeude auf gruenem
	## Haken (aus dem Besitz) bzw. Einkaufswagen (kaufen); rot mit dem, was fehlt.
	func _draw_pending(font: Font, small: Font, pa: float) -> void:
		var k := str(view.pending.get("k", ""))
		if k == "":
			return
		var type := str(view.pending["type"])
		var d := FactorySim.def(type)
		var c := center(k)
		for tr in view.preview:
			var pts := PackedVector2Array()
			for cell in tr["path"]:
				pts.append(center(str(cell)))
			var col := FactorySim.ware_color(str(tr["ware"]))
			for i in pts.size() - 1:
				draw_dashed_line(pts[i], pts[i + 1], Color(col, 0.6 + 0.4 * pa), 3.0, 6.0)
		var state := view.pending_state()
		var tint := FactoryView.GREEN if state != "poor" else UiKit.BAD
		draw_colored_polygon(_hex(c, _size * 0.9), Color(tint, 0.24 + 0.12 * pa))
		_icon("check" if state == "own" else "bag", c, _size * 1.0, Color(tint, 0.6))
		var col := Color(str(d["farbe"]))
		draw_polyline(_hex(c, _size * 0.78), Color(col, 0.6), 2.0)
		draw_string(font, c + Vector2(-_size, _size * 0.06), str(d["kurz"]), HORIZONTAL_ALIGNMENT_CENTER,
			_size * 2.0, int(_size * 0.32), Color(col, 0.7))
		if state == "poor":
			# Was fehlt, als Punkt in der Warenfarbe mit Menge unter dem Feld.
			var gap := view.pending_missing()
			var y := c.y + _size * 1.12
			var x := c.x - (gap.size() - 1) * _size * 0.55
			for ware in gap:
				var wc := FactorySim.ware_color(str(ware))
				draw_circle(Vector2(x - _size * 0.22, y - _size * 0.07), _size * 0.1, wc)
				draw_string(small, Vector2(x - _size * 0.08, y), "-%d" % int(gap[ware]), HORIZONTAL_ALIGNMENT_LEFT,
					-1, int(_size * 0.26), UiKit.BAD)
				x += _size * 1.1
