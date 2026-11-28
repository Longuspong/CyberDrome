class_name WorkbenchView
extends VBoxContainer

## Reiter "Werkbank" im Fabrik-Tab (24. Nov. 2026, docs/FACTORY_KONZEPT.md
## Abschnitt 13): ein Ort fuer alles, was aus dem Lager entsteht. Kategorien
## Charger und DROMEs; ein DROME zeigt seinen Bauplan als Baum (DROME <- Teile
## <- Ressourcen) mit habe/brauche, woher Fehlendes kommt und wie viele Kaempfe
## die Platine dafuer braucht. "Als Ziel merken" hebt es auf der Platine hervor.
## Logik in ``Workbench``; Optik bewusst schlicht (Design-Sitzung).

signal charger_built(charger: Dictionary)

static var category := "dromes"
static var selected := ""

var _bench: Workbench
var _sim: FactorySim
var _per_tick: Dictionary = {}
var _note: Label


func _ready() -> void:
	_bench = Workbench.new(GameState.roster)
	_sim = GameState.roster.factory_sim()
	_per_tick = _sim.estimate_per_tick()
	add_theme_constant_override("separation", UiKit.GAP)
	refresh()


func refresh() -> void:
	UiKit.clear(self)
	var switch := UiKit.segmented([["charger", "Charger"], ["dromes", "DROMEs"]], category, func(id):
		category = id
		selected = ""
		refresh())
	add_child(switch)
	_note = UiKit.label("", UiKit.SMALL, UiKit.WARN)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.visible = false
	add_child(_note)
	_goal_line()
	if category == "charger":
		_charger()
	else:
		_dromes()


func _say(text: String) -> void:
	_note.text = text
	_note.visible = text != ""


func _goal_line() -> void:
	var goal := _sim.goal()
	if goal == "":
		return
	var short := _bench.raw_shortfall(goal)
	var text := "ZIEL: %s" % _bench.name_of(goal).to_upper()
	if short.is_empty() and _bench.missing(goal).is_empty():
		text += " · bereit"
	elif not short.is_empty():
		var battles := Workbench.battles_for(short, _per_tick)
		text += " · " + ("≈ %d Kämpfe" % battles if battles >= 0 else _never_text(short))
	add_child(Arcade.label(text, 13, Arcade.YELLOW, "bold", 0.1))


# ---------------------------------------------------------------- Charger

func _charger() -> void:
	var card := UiKit.card(self)
	_product_rows(card, "rohling")
	var crafter := ChargerCrafter.new()
	crafter.built.connect(func(charger): charger_built.emit(charger))
	add_child(crafter)


# ---------------------------------------------------------------- DROMEs

func _dromes() -> void:
	var ids := _bench.products("dromes")
	if selected == "" or selected not in ids:
		selected = str(ids[0]) if not ids.is_empty() else ""
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	add_child(grid)
	for id in ids:
		var body := PartDB.get_part(StringName(Workbench.chassis_of(id)))
		if body == null:
			continue
		var tile := Tile.new("bench:" + id, UiKit.chassis_view(body, 56), _bench.name_of(id), Vector2(0, 100))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ready := _bench.can_craft(id)
		tile.glow = ready
		tile.selected = id == selected
		tile.accent = UiKit.GOOD if ready else UiKit.ACCENT
		tile.add_caption(_progress_text(id), UiKit.GOOD if ready else UiKit.MUTED, 11)
		var pick: String = id
		tile.on_select = func():
			selected = pick
			_say("")
			refresh()
		tile.on_info = tile.on_select
		tile.on_action = func(): _craft(pick)
		grid.add_child(tile)
	if selected != "":
		_detail(selected)


func _progress_text(id: String) -> String:
	if id.begins_with("free:"):
		return "freies Chassis"
	var need := _bench.needs(id)
	var total := 0
	var have := 0
	for key in need:
		total += int(need[key])
		have += mini(int(need[key]), _bench.have(str(key)))
	return "bereit" if have >= total else "%d/%d Teile" % [have, total]


func _detail(id: String) -> void:
	var card := UiKit.card(self, true)
	var head := Arcade.label(_bench.name_of(id).to_upper(), 16, Arcade.CYAN, "bold", 0.1)
	card.add_child(head)
	if id.begins_with("free:"):
		card.add_child(_wrap("Ein freies Chassis aus der Beute -- baut sich ohne Kosten.", UiKit.MUTED))
	else:
		if id.begins_with("faction:"):
			card.add_child(_wrap("Spezialteil %s statt Kern-Teil, aus dem %s." % [
				Workbench.special_name(id.substr(8)), Roster.core_name(Workbench.faction_of(id.substr(8)))],
				UiKit.MUTED))
		var need := _bench.needs(id)
		for key in need:
			_part_row(card, str(key), int(need[key]))
		var short := _bench.raw_shortfall(id)
		if not short.is_empty():
			var battles := Workbench.battles_for(short, _per_tick)
			card.add_child(_wrap("Mit deiner Platine: %s" % ("≈ %d Kämpfe" % battles if battles >= 0
				else _never_text(short)), UiKit.WARN))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var build := UiKit.button("DROME bauen", true)
	build.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build.disabled = not _bench.can_craft(id)
	build.pressed.connect(func(): _craft(id))
	row.add_child(build)
	if not id.begins_with("free:"):
		row.add_child(_goal_button(id))


## Eine Zeile je Teil: habe/brauche, Kosten, Herstellen-Knopf und was fehlt.
func _part_row(card: VBoxContainer, key: String, amount: int) -> void:
	var have := _bench.have(key)
	var done := have >= amount
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	card.add_child(line)
	var name := UiKit.label("%s  %d/%d" % [Workbench.key_name(key), mini(have, amount), amount], 15,
		UiKit.GOOD if done else UiKit.TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name)
	if not key.begins_with("teil:") and not key.begins_with("spezial:"):
		return
	if not done:
		var make := UiKit.outline_button("Herstellen")
		make.disabled = not _bench.can_craft(key)
		make.pressed.connect(func():
			var result := _bench.craft(key)
			if bool(result["ok"]):
				GameState.save_roster()
				_say("%s hergestellt." % Workbench.key_name(key))
			refresh())
		line.add_child(make)
		_cost_lines(card, key)


## Die Zutaten eines Teils oder Rohlings, Fehlendes mit Herkunft.
func _cost_lines(card: VBoxContainer, id: String) -> void:
	var need := _bench.needs(id)
	for key in need:
		var ware := str(key).substr(4) if str(key).begins_with("res:") else str(key)
		var have := _bench.have(str(key))
		var text := "  · %s %d/%d" % [Workbench.key_name(str(key)), mini(have, int(need[key])), int(need[key])]
		var color := UiKit.MUTED
		if have < int(need[key]):
			color = UiKit.MAGENTA
			var makers: Array = FactorySim.producers(ware)
			if str(key).begins_with("kern:"):
				text += " -- seltene Beute aus Caches des Gebiets"
			elif not makers.is_empty():
				var names: Array = makers.map(func(m): return str(m["name"]) + (
					" (ab Tier %d)" % int(m["tier"]) if int(m["tier"]) > _sim.tier() else ""))
				text += " -- " + ", ".join(names)
		card.add_child(UiKit.label(text, 13, color))


func _product_rows(card: VBoxContainer, id: String) -> void:
	card.add_child(Arcade.label(_bench.name_of(id).to_upper(), 14, Arcade.CYAN, "bold", 0.16))
	card.add_child(UiKit.label("Im Lager: %d" % _bench.have(id), 14, UiKit.TEXT))
	_cost_lines(card, id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var make := UiKit.button("Herstellen", true)
	make.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	make.disabled = not _bench.can_craft(id)
	make.pressed.connect(func(): _craft(id))
	row.add_child(make)
	row.add_child(_goal_button(id))


func _goal_button(id: String) -> Button:
	var aimed := _sim.goal() == id
	var button := UiKit.outline_button("Ziel aufheben" if aimed else "Als Ziel")
	button.pressed.connect(func():
		_sim.set_goal("" if aimed else id)
		GameState.save_roster()
		_say("" if aimed else "Gemerkt -- die Platine hebt hervor, was dafür fehlt.")
		refresh())
	return button


## Warum die Platine etwas nie liefert: welche Gebaeude fehlen bzw. erst ab
## welchem Tier es sie gibt.
func _never_text(short: Dictionary) -> String:
	var parts: Array = []
	for ware in short:
		if float(_per_tick.get(ware, 0.0)) > 0.0:
			continue
		var makers: Array = FactorySim.producers(str(ware))
		var best := 99
		var names: Array = []
		for m in makers:
			best = mini(best, int(m["tier"]))
			names.append(str(m["name"]))
		if best > _sim.tier():
			parts.append("%s ab Tier %d (%s)" % [FactorySim.ware_name(str(ware)), best, ", ".join(names)])
		else:
			parts.append("%s: baue %s" % [FactorySim.ware_name(str(ware)), " oder ".join(names)])
	return "noch nicht -- " + "; ".join(parts)


func _wrap(text: String, color: Color) -> Label:
	var label := UiKit.label(text, 14, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _craft(id: String) -> void:
	var result := _bench.craft(id)
	if not bool(result["ok"]):
		_say(str(result["why"]))
		return
	if _sim.goal() == id:
		_sim.set_goal("")
	Accessibility.vibrate(40, true)
	GameState.save_roster()
	var entry: RosterEntry = result["entry"]
	if entry != null:
		GameState.refresh_squad()
		# Gleich in die Ausruestung des neuen DROME -- er hat noch keine Waffe.
		GameState.editing_index = GameState.roster.entries.size() - 1
		Fader.go("res://scenes/hangar.tscn")
		return
	_say("%s hergestellt." % _bench.name_of(id))
	refresh()
