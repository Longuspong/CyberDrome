class_name FactoryView
extends VBoxContainer

## Reiter "Linien" im Fabrik-Tab: die Platine (23. Nov. 2026,
## docs/FACTORY_KONZEPT.md Abschnitt 11). Die Logik steckt in ``FactorySim``
## (``GameState.roster.factory_sim()``); hier nur Anzeige und Bedienung --
## bewusst schlicht, die Optik kommt aus der Design-Sitzung (Abschnitt 12).
##
## Live laeuft alle ``FactorySim.live_seconds()`` ein Takt, aber nur, solange
## der Reiter offen ist. Tippen: Feld waehlen; mit gewaehltem Gebaeude unten
## baut ein Tipp auf ein freies, passendes Feld.

const GROUPS := [["foerderer", "Förderer"], ["verarbeitung", "Verarbeitung"], ["strom", "Strom"],
	["logistik", "Logistik"]]

var _sim: FactorySim
var _board: Board
var _head: Label
var _info: VBoxContainer
var _tools: VBoxContainer
var _store: VBoxContainer
var _goal: VBoxContainer
var _timer: Timer
var _note: Label

## Gewaehltes Feld ("" = keins), Bauwerkzeug (Gebaeudeart, "" = keins),
## angetippte gesperrte Feldgruppe (id, "" = keine).
var selected := ""
var tool := ""
var chunk := ""
## Waren, die dem Werkbank-Ziel fehlen ({ware: menge}) -- die Platine hebt ihre
## Hersteller hervor.
var goal_wares: Dictionary = {}


func _ready() -> void:
	_sim = GameState.roster.factory_sim()
	add_theme_constant_override("separation", UiKit.GAP)
	_head = UiKit.label("", UiKit.SMALL, UiKit.MUTED)
	add_child(_head)
	_board = Board.new(self)
	add_child(_board)
	_note = UiKit.label("", UiKit.SMALL, UiKit.WARN)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.visible = false
	add_child(_note)
	_info = UiKit.card(self)
	_tools = VBoxContainer.new()
	_tools.add_theme_constant_override("separation", 6)
	add_child(_tools)
	_store = UiKit.card(self)
	_goal = UiKit.card(self)
	_timer = Timer.new()
	_timer.wait_time = FactorySim.live_seconds()
	_timer.timeout.connect(_live_tick)
	add_child(_timer)
	_timer.start()
	# Einmal rechnen, damit Status und Strom gleich stehen (ohne Takt zu zaehlen
	# wuerde die Anzeige bis zum ersten Takt leer bleiben).
	if _sim.info.is_empty():
		_live_tick()
	else:
		refresh()


func _exit_tree() -> void:
	GameState.save_roster()


func _live_tick() -> void:
	_sim.tick()
	GameState.save_roster()
	refresh()


func refresh() -> void:
	_head.text = "TAKT %d · TIER %d · STROM %s/%s · alle %s s ein Takt, solange offen" % [
		_sim.tick_count(), _sim.tier(), FactorySim.num(float(_sim.power["used"])),
		FactorySim.num(float(_sim.power["supply"])), FactorySim.num(FactorySim.live_seconds())]
	goal_wares = {}
	if _sim.goal() != "":
		var bench := Workbench.new(GameState.roster)
		goal_wares = bench.raw_shortfall(_sim.goal())
		var parts: Array = []
		for ware in goal_wares:
			parts.append("%d %s" % [int(goal_wares[ware]), FactorySim.ware_name(str(ware))])
		_head.text += "\nZIEL %s: %s" % [bench.name_of(_sim.goal()).to_upper(),
			"fehlt " + ", ".join(parts) if not parts.is_empty() else "alles da – Werkbank"]
	_board.queue_redraw()
	_build_info()
	_build_tools()
	_build_store()
	_build_goal()


func _say(text: String) -> void:
	_note.text = text
	_note.visible = text != ""


## Ein Tipp auf die Platine.
func tapped(k: String) -> void:
	_say("")
	chunk = ""
	_show_type = ""
	if k not in FactorySim.cells():
		selected = ""
	elif not _sim.unlocked(k):
		selected = ""
		tool = ""
		chunk = str(FactorySim.chunk_of(k).get("id", ""))
	elif tool != "" and _sim.building_at(k).is_empty() and k != FactorySim.net_cell():
		var why := _sim.place(k, tool)
		if why != "":
			_say(why)
		else:
			selected = k
			if _sim.placed(tool) >= _sim.owned(tool):
				tool = ""
			GameState.save_roster()
	else:
		selected = k
	refresh()


# ---------------------------------------------------------------- Info

func _row(text: String, color: Color = UiKit.TEXT, size: int = UiKit.SMALL) -> Label:
	var label := UiKit.label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_child(label)
	return label


func _title(code: String, name: String, color: Color) -> void:
	_info.add_child(Arcade.label(("%s  %s" % [code, name]).strip_edges().to_upper(), 16, color, "bold", 0.1))


func _build_info() -> void:
	UiKit.clear(_info)
	if chunk != "":
		_chunk_info()
		return
	var b := _sim.building_at(selected)
	if not b.is_empty():
		_building_info(selected, b)
		return
	if selected == FactorySim.net_cell():
		var netz: Dictionary = FactorySim.data().get("netz", {})
		var si: Dictionary = _sim.source_info.get(selected, {})
		_title("NETZ", "Netzanschluss", UiKit.WARN)
		_row("Hier kommt der Strom der Platine an: %d Strom, Reichweite %d. Gebäude nah am Anschluss werden zuerst versorgt."
			% [int(netz.get("strom", 4)), int(netz.get("reichweite", 2))])
		_row("Gerade abgegeben: %s von %d." % [FactorySim.num(float(si.get("used", 0.0))),
			int(netz.get("strom", 4))], UiKit.MUTED)
		return
	if tool != "" or _show_type != "":
		_tool_info(tool if tool != "" else _show_type)
		return
	var src := FactorySim.source_at(selected)
	if selected != "" and src != "":
		_title(src, FactorySim.source_name(src), FactorySim.ware_color(FactorySim.source_ware(src)))
		_row("Hier kann ein Förderer %s holen." % FactorySim.ware_name(FactorySim.source_ware(src)))
		return
	_title("", "Platine", UiKit.HEADING)
	_row("Wähle unten ein Gebäude und tippe auf ein gelb markiertes Feld. Tippe Gebäude an, um Durchsatz, Puffer und Strom zu sehen. Gesperrte Felder lassen sich kaufen.")
	_row("Unterm Gebäude: cyan läuft, violett läuft an, magenta wartet, orange zu wenig Strom, gelb Überschuss ins Lager. Magenta blinkend = Engpass.",
		UiKit.MUTED)


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
	var remove := UiKit.outline_button("Abreißen (zurück in den Besitz)", UiKit.BAD)
	remove.pressed.connect(func():
		_sim.remove(k)
		selected = ""
		_say("%s zurück im Besitz, Pufferinhalt im Lager." % str(d["name"]))
		GameState.save_roster()
		refresh())
	_info.add_child(remove)


func _tool_info(type: String) -> void:
	var d := FactorySim.def(type)
	var locked := int(d.get("tier", 1)) > _sim.tier()
	_title(str(d["kurz"]), "%s · Tier %d" % [str(d["name"]), int(d.get("tier", 1))], Color(str(d["farbe"])))
	var power := ""
	if float(d.get("strom", 0)) > 0.0:
		power = " · braucht %d Strom" % int(d["strom"])
	_row(FactorySim.recipe_text(type) + power)
	_row(str(d.get("text", "Holt seine Zutaten bei den Nachbarn ab.")), UiKit.MUTED)
	var line := "Besitz %d · gebaut %d" % [_sim.owned(type), _sim.placed(type)]
	if tool == type and not locked:
		line += " · tippe ein gelb markiertes Feld"
	_row(line, UiKit.WARN if tool == type else UiKit.MUTED)
	var buy := UiKit.outline_button("Weiteres kaufen: " + FactorySim.amounts_text(d.get("preis", {})))
	buy.disabled = locked or not _sim.can_pay(d.get("preis", {}))
	buy.pressed.connect(func():
		var why := _sim.buy_building(type)
		_say(why if why != "" else "%s gekauft." % str(d["name"]))
		if why == "":
			tool = type
			selected = ""
			GameState.save_roster()
		refresh())
	_info.add_child(buy)


func _chunk_info() -> void:
	var c := {}
	for entry in FactorySim.chunks():
		if str(entry["id"]) == chunk:
			c = entry
	if c.is_empty():
		return
	var srcs: Array = []
	for k in c["felder"]:
		var src := FactorySim.source_at(str(k))
		if src != "":
			srcs.append(FactorySim.source_name(src))
	_title("", "Felder %s" % str(c["name"]), UiKit.WARN)
	_row("%d neue Felder%s." % [(c["felder"] as Array).size(),
		(" mit " + ", ".join(srcs)) if not srcs.is_empty() else ""])
	var locked := int(c.get("tier", 1)) > _sim.tier()
	_row("Kostet %s%s." % [FactorySim.amounts_text(c.get("preis", {})),
		(" · ab Tier %d" % int(c["tier"])) if locked else ""], UiKit.MUTED)
	var buy := UiKit.button("Felder kaufen", true)
	buy.disabled = locked or not _sim.can_pay(c.get("preis", {}))
	buy.pressed.connect(func():
		var why := _sim.buy_chunk(chunk)
		_say(why if why != "" else "Felder %s gekauft." % str(c["name"]))
		if why == "":
			chunk = ""
			GameState.save_roster()
		refresh())
	_info.add_child(buy)


static func _status_color(status: String) -> Color:
	match status:
		"anlauf": return Color("#9d84ff")
		"wait": return UiKit.MAGENTA
		"strom": return Color("#ff6a3d")
		"uplink": return UiKit.WARN
		"relay": return Color("#9d84ff")
	return UiKit.ACCENT


# ---------------------------------------------------------------- Gebaeude

func _build_tools() -> void:
	UiKit.clear(_tools)
	for group in GROUPS:
		var types: Array = []
		for type in FactorySim.defs():
			if str(FactorySim.def(type).get("gruppe", "")) == group[0]:
				types.append(type)
		if types.is_empty():
			continue
		_tools.add_child(Arcade.label(str(group[1]).to_upper(), 12, Arcade.MUTED, "bold", 0.16))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		_tools.add_child(flow)
		for type in types:
			flow.add_child(_tool_button(type))


func _tool_button(type: String) -> Button:
	var d := FactorySim.def(type)
	var locked := int(d.get("tier", 1)) > _sim.tier()
	var free := _sim.owned(type) - _sim.placed(type)
	var text := "%s  %s\n%s" % [str(d["kurz"]), str(d["name"]),
		("ab Tier %d" % int(d["tier"])) if locked else "%d/%d gebaut" % [_sim.placed(type), _sim.owned(type)]]
	var button := UiKit.outline_button(text, Color(str(d["farbe"])) if tool == type else UiKit.CARD_LINE)
	button.custom_minimum_size = Vector2(118, 52)
	button.add_theme_font_size_override("font_size", 13)
	if locked or free <= 0:
		button.modulate = Color(1, 1, 1, 0.55)
	button.pressed.connect(func():
		chunk = ""
		_say("")
		# Ohne freies Exemplar (oder gesperrt) zeigt der Knopf nur die Info mit Kaufen.
		tool = "" if tool == type or locked or free <= 0 else type
		_show_type = type
		selected = ""
		refresh())
	return button


## Gebaeudeart, deren Info gezeigt wird, ohne dass gebaut werden kann.
var _show_type := ""


# ---------------------------------------------------------------- Lager + Ziel

func _build_store() -> void:
	UiKit.clear(_store)
	_store.add_child(Arcade.label("LAGER", 14, Arcade.CYAN, "bold", 0.2))
	var mission := FactorySim.ticks_per_battle() * RunState.rounds_total()
	var proj := _sim.projection(mission)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 2)
	_store.add_child(grid)
	for ware in FactorySim.wares():
		var n := _sim.have(str(ware))
		var line := "%s  %d" % [FactorySim.ware_name(str(ware)), n]
		if int(proj.get(ware, 0)) > 0:
			line += "  (+%d je Einsatz)" % int(proj[ware])
		var label := UiKit.label(line, 14, FactorySim.ware_color(str(ware)) if n > 0 else UiKit.MUTED)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(label)
	var rohling := FactorySim.craft_cost("rohling")
	if not rohling.is_empty():
		_store.add_child(UiKit.label("Charger-Rohlinge entstehen im Reiter Charger (%s)."
			% FactorySim.amounts_text(rohling), 13, UiKit.MUTED))


func _build_goal() -> void:
	UiKit.clear(_goal)
	var goal := _sim.next_tier_goal()
	if goal.is_empty():
		_goal.add_child(Arcade.label("ALLE TIERS FREI", 14, Arcade.CYAN, "bold", 0.2))
		return
	_goal.add_child(Arcade.label(str(goal["titel"]).to_upper(), 14, Arcade.CYAN, "bold", 0.2))
	var text := UiKit.label(str(goal.get("text", "")), 14, UiKit.MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal.add_child(text)
	if str(goal.get("weg", "fabrik")) != "fabrik":
		return
	var cost: Dictionary = goal.get("kosten", {})
	for ware in cost:
		var have := _sim.have(str(ware))
		_goal.add_child(UiKit.label("%s  %d / %d" % [FactorySim.ware_name(str(ware)), mini(have, int(cost[ware])),
			int(cost[ware])], 14, UiKit.GOOD if have >= int(cost[ware]) else UiKit.TEXT))
	var unlock := UiKit.button("Freischalten", true)
	unlock.disabled = not _sim.can_pay(cost)
	unlock.pressed.connect(func():
		var why := _sim.unlock_tier()
		_say(why if why != "" else "Tier %d freigeschaltet!" % _sim.tier())
		GameState.save_roster()
		refresh())
	_goal.add_child(unlock)


# ---------------------------------------------------------------- Platine

class Board extends Control:
	var view: FactoryView
	var _size := 30.0
	var _pulse := 0.0

	func _init(owner_view: FactoryView) -> void:
		view = owner_view
		mouse_filter = Control.MOUSE_FILTER_STOP
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(0, 340)
		resized.connect(_fit)

	func _fit() -> void:
		_size = minf(size.x / 11.2, 40.0)
		var h := _size * sqrt(3.0) * 7.0 + _size * 0.6
		if absf(custom_minimum_size.y - h) > 1.0:
			custom_minimum_size = Vector2(0, h)

	func _process(delta: float) -> void:
		_pulse += delta
		if view._sim.engpass != "" or view.tool != "":
			queue_redraw()

	func center(k: String) -> Vector2:
		var p := FactorySim.unkey(k)
		return size / 2.0 + Vector2(_size * 1.5 * p.x, _size * sqrt(3.0) * (p.y + p.x / 2.0))

	func key_at(pos: Vector2) -> String:
		var v := pos - size / 2.0
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
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			view.tapped(key_at(event.position))
			accept_event()

	func _hex(c: Vector2, radius: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 7:
			var a := PI / 3.0 * i
			pts.append(c + Vector2(cos(a), sin(a)) * radius)
		return pts

	func _draw() -> void:
		var sim := view._sim
		var pa := 0.5 + 0.5 * sin(_pulse * 5.5)
		var font := Arcade.font("display")
		var small := Arcade.font("bold")
		var sel := view.selected
		var reach := sim.range_of(sel) if sel != "" else -1
		for k in FactorySim.cells():
			var c := center(k)
			var hex := _hex(c, _size * 0.94)
			var src := FactorySim.source_at(k)
			if not sim.unlocked(k):
				draw_colored_polygon(hex, Color(0.04, 0.02, 0.09, 0.75))
				var line := Color("#ffe14d", 0.8) if str(FactorySim.chunk_of(k).get("id", "")) == view.chunk \
					else Color("#9a86c4", 0.35)
				draw_polyline(hex, line, 1.0)
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
			if view.tool != "" and sim.can_place(k, view.tool) == "":
				draw_polyline(_hex(c, _size * 0.8), Color("#ffe14d", 0.35 + 0.4 * pa), 1.5)
		# Netzanschluss
		var nc := center(FactorySim.net_cell())
		draw_colored_polygon(_hex(nc, _size * 0.8), Color("#241046"))
		draw_polyline(_hex(nc, _size * 0.8), Color("#ffe14d"), 2.0)
		if sel == FactorySim.net_cell():
			draw_polyline(_hex(nc, _size * 0.96), Color("#fff7fe"), 2.5)
		draw_string(font, nc + Vector2(-_size, -_size * 0.0), "NETZ", HORIZONTAL_ALIGNMENT_CENTER,
			_size * 2.0, int(_size * 0.27), Color("#ffe14d"))
		var si: Dictionary = sim.source_info.get(FactorySim.net_cell(), {})
		draw_string(small, nc + Vector2(-_size, _size * 0.36), "%s/%d" % [
			FactorySim.num(float(si.get("used", 0.0))), int((FactorySim.data().get("netz", {}) as Dictionary).get("strom", 4))],
			HORIZONTAL_ALIGNMENT_CENTER, _size * 2.0, int(_size * 0.22), Color("#ffe14d"))
		# Leiterbahnen: gedimmt, wenn der Abnehmer gerade nichts holt (Stau).
		for tr in sim.traces():
			var path: Array = tr["path"]
			var pts := PackedVector2Array()
			for k in path:
				pts.append(center(str(k)))
			var target := sim.info_of(str(path[path.size() - 1]))
			var got := float(target.get("in_h", [{}]).back().get(tr["ware"], 0)) if not (target.get("in_h", []) as Array).is_empty() else 0.0
			draw_polyline(pts, Color(FactorySim.ware_color(str(tr["ware"])), 0.45 if got > 0.0 else 0.15), 3.0)
		# Gebaeude
		for k in sim.buildings():
			var b := sim.building_at(k)
			var d := FactorySim.def(str(b["t"]))
			var inf := sim.info_of(k)
			var c := center(k)
			var col := Color(str(d["farbe"]))
			var hex := _hex(c, _size * 0.78)
			draw_colored_polygon(hex, Color("#0f0724"))
			var line_col := col
			if d.get("relais", false) and not b["rel_on"]:
				line_col = Color(col, 0.4)
			draw_polyline(hex, line_col, 2.0)
			# Werkbank-Ziel: Hersteller fehlender Waren gelb markiert.
			for ware in d.get("aus", {}):
				if view.goal_wares.has(ware):
					draw_circle(c + Vector2(_size * 0.5, -_size * 0.5), _size * 0.12, Color("#ffe14d"))
					break
			if sim.engpass == k:
				draw_polyline(_hex(c, _size * 0.9), Color("#ff2bd6", 0.4 + 0.6 * pa), 3.0)
			if sel == k:
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
