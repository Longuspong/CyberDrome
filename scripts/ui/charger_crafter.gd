class_name ChargerCrafter
extends VBoxContainer

## Der Charger-Crafter im Shop-Reiter Bauen (Design-Canvas 20. Nov. 2026,
## Uebergabe Ue3, Skizze des Spielers): sechs Phasen-Felder ergeben ein grosses
## Hexagon, in der Mitte der Hammer zum Bauen. Darunter ein Sockel mit dem
## Rohling, die Belastung je Treffer, die Resonanz (Stufen zaehlen zusammen) und
## die Phasen im Lager.
##
## Bedienung: Phase aus dem Lager auf ein Feld ziehen. Ersatz: Phase antippen
## waehlt sie, dann ein freies Feld antippen -- oder doppelt tippen, dann kommt
## sie ins naechste freie Feld. Ein belegtes Feld antippen nimmt die Phase
## wieder heraus.

signal built(charger: Dictionary)

## Was gerade im Hexagon liegt (bleibt beim Neuaufbau des Bildschirms).
static var _slots: Array = ["", "", "", "", "", ""]
static var _picked := ""
static var _tap_ms := -10000
static var _tap_el := ""

## Lage der sechs Felder im Entwurfsraum 340 x 295, im Uhrzeigersinn ab oben links.
const SLOT_POS := [Vector2(80, 26), Vector2(180, 26), Vector2(230, 113),
	Vector2(180, 200), Vector2(80, 200), Vector2(30, 113)]
const STAGE := Vector2(340, 295)

var _stage: Control
var _readout: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_fit_slots()
	_rebuild()


## Mehr Phasen im Hexagon als im Lager (nach dem Bauen, nach dem Laden)?
## Dann fliegen die ueberzaehligen heraus.
func _fit_slots() -> void:
	var roster := GameState.roster
	var used := {}
	for i in _slots.size():
		var e := str(_slots[i])
		if e == "":
			continue
		used[e] = int(used.get(e, 0)) + 1
		if int(used[e]) > roster.phases(e):
			_slots[i] = ""
			used[e] = int(used[e]) - 1


func _rebuild() -> void:
	UiKit.clear(self)
	var roster := GameState.roster
	var head := HBoxContainer.new()
	var title := Arcade.label("CHARGER BAUEN", 15, Arcade.CYAN, "bold", 0.14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_chip("ROHLINGE %d" % roster.blanks(), "charger", Arcade.YELLOW))
	add_child(head)

	var holder := CenterContainer.new()
	add_child(holder)
	_stage = _Stage.new(self)
	holder.add_child(_stage)
	_add_slots()

	var sockel := Arcade.label("ROHLING · MK I  %d/6" % Charger.filled(_slots), 12, Arcade.MUTED, "bold", 0.14)
	sockel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sockel)

	_readout = VBoxContainer.new()
	add_child(_readout)
	_fill_readout()

	var inv_head := HBoxContainer.new()
	var inv_title := Arcade.label("ENERGY PHASES", 13, Arcade.CYAN, "bold", 0.14)
	inv_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_head.add_child(inv_title)
	inv_head.add_child(Arcade.label("Ziehen · Doppeltipp setzt ein", 12, Arcade.MUTED))
	add_child(inv_head)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	add_child(grid)
	for e in Charger.element_ids():
		var src := _Source.new(self, e)
		src.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(src)


func _chip(text: String, icon: String, color: Color) -> Control:
	var panel := PanelContainer.new()
	var box := Arcade.chamfer_box(Color(Arcade.VIOLET, 0.94), 8, Color("#6e5ab4"), 2)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(UiIcon.rect(icon, 16, color))
	row.add_child(Arcade.label(text, 13, color, "bold", 0.1))
	panel.add_child(row)
	return panel


func _add_slots() -> void:
	for i in 6:
		var slot := _Slot.new(self, i)
		_stage.add_child(slot)
	var core := _Core.new(self)
	_stage.add_child(core)


func _scale() -> float:
	return _stage.size.x / STAGE.x if _stage != null and _stage.size.x > 0 else 1.0


func free_count(element: String) -> int:
	var used := 0
	for e in _slots:
		if str(e) == element:
			used += 1
	return GameState.roster.phases(element) - used


func put(index: int, element: String) -> void:
	if index < 0 or index >= _slots.size() or free_count(element) <= 0:
		return
	_slots[index] = element
	Accessibility.vibrate(15)
	_rebuild()


func put_next(element: String) -> void:
	var i := _slots.find("")
	if i >= 0:
		put(i, element)


func take(index: int) -> void:
	if str(_slots[index]) == "":
		if _picked != "":
			put(index, _picked)
		return
	_slots[index] = ""
	_rebuild()


func pick(element: String) -> void:
	_picked = "" if _picked == element else element
	_rebuild()


func build() -> void:
	var roster := GameState.roster
	var why := roster.charger_blocker(_slots)
	if why != "":
		InfoPopup.open(get_tree().current_scene, "Noch nicht", {"lines": [why]})
		return
	var charger := roster.craft_charger(_slots)
	if charger.is_empty():
		return
	Accessibility.vibrate(80, true)
	_slots = ["", "", "", "", "", ""]
	_picked = ""
	GameState.save_roster()
	built.emit(charger)
	_rebuild()


func _fill_readout() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	_readout.add_child(grid)
	var left := UiKit.card(grid)
	left.get_parent().custom_minimum_size.x = 0
	left.get_parent().custom_minimum_size = Vector2(0, 130)
	left.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(Arcade.label("BELASTUNG", 11, Arcade.CYAN, "bold", 0.14))
	left.add_child(Arcade.label("je Treffer", 11, Arcade.MUTED))
	var loads := Charger.loads(_slots)
	if loads.is_empty():
		left.add_child(UiKit.label("Noch keine Phase im Hexagon.", 13, UiKit.MUTED))
	for e in Charger.element_ids():
		if not loads.has(e):
			continue
		var row := HBoxContainer.new()
		var name := Arcade.label(Charger.element_name(e).to_upper(), 12, Charger.element_color(e), "bold", 0.08)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		row.add_child(Arcade.label("+%d" % int(loads[e]), 12, Arcade.WHITE, "bold"))
		left.add_child(row)
		var bar := _Bar.new(float(loads[e]) / float(Charger.slots() * 20), Charger.element_color(e))
		left.add_child(bar)

	var dom := Charger.dominant(_slots)
	var dcol := Charger.element_color(dom) if dom != "" else Arcade.MUTED
	var right := UiKit.card(grid)
	right.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(Arcade.label("RESONANZ", 11, Arcade.CYAN, "bold", 0.14))
	right.add_child(Arcade.label("%s %d/6" % [Charger.element_name(dom).to_upper(), Charger.dominant_count(_slots)]
		if dom != "" else "kein Übergewicht", 11, dcol, "bold", 0.08))
	var n := Charger.dominant_count(_slots)
	for at in [2, 4, 6]:
		var on: bool = n >= at
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.modulate.a = 1.0 if on else 0.6
		var badge := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = dcol if on else Arcade.DEEP
		badge.add_theme_stylebox_override("panel", st)
		badge.custom_minimum_size = Vector2(20, 20)
		var num := Arcade.label(str(at), 12, Arcade.NIGHT if on else Arcade.EMPTY_NUM, "display")
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_child(num)
		row.add_child(badge)
		var text := UiKit.label(Charger.resonance_text(at), 12, UiKit.TEXT)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = 60
		row.add_child(text)
		right.add_child(row)


## Die Buehne: grosses Hexagon, Speichen, Platz fuer Felder und Kern.
class _Stage extends Control:
	var crafter

	func _init(owner_crafter) -> void:
		crafter = owner_crafter
		custom_minimum_size = Vector2(320, 278)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			for child in get_children():
				if child.has_method("place"):
					child.place()

	func _draw() -> void:
		var k := size.x / ChargerCrafter.STAGE.x
		var c := Vector2(170, 147.5) * k
		var outer := PhaseGem.hex(c, 336 * k, 291 * k)
		draw_colored_polygon(outer, Color(Arcade.VIOLET, 0.94))
		var closed := outer.duplicate()
		closed.append(outer[0])
		draw_polyline(closed, Color("#6e5ab4"), 2.0)
		var dom := Charger.dominant(ChargerCrafter._slots)
		var ring := PhaseGem.hex(c, 308 * k, 267 * k)
		ring.append(ring[0])
		var rc := Charger.element_color(dom) if dom != "" else Arcade.CYAN
		for i in 6:
			draw_dashed_line(ring[i], ring[i + 1], Color(rc, 0.7), 1.5, 6.0)
		for p in ChargerCrafter.SLOT_POS:
			draw_line(c, (p + Vector2(40, 34.5)) * k, Color("#3a1a6e"), 2.0)


## Ein Feld im Hexagon: Ziehziel, antippen nimmt heraus bzw. setzt die gewaehlte Phase.
class _Slot extends Control:
	var crafter
	var index := 0
	var gem: PhaseGem

	func _init(owner_crafter, i: int) -> void:
		crafter = owner_crafter
		index = i
		gem = PhaseGem.new(str(ChargerCrafter._slots[i]), 80)
		gem.set_anchors_preset(Control.PRESET_FULL_RECT)
		gem.highlight = str(ChargerCrafter._slots[i]) == "" and ChargerCrafter._picked != ""
		add_child(gem)
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = "Feld %d" % (i + 1)

	func _ready() -> void:
		place()

	func place() -> void:
		var parent := get_parent() as Control
		if parent == null:
			return
		var k := parent.size.x / ChargerCrafter.STAGE.x if parent.size.x > 0 else 320.0 / ChargerCrafter.STAGE.x
		position = ChargerCrafter.SLOT_POS[index] * k
		size = Vector2(80, 69) * k
		gem.size = size

	func _gui_input(event: InputEvent) -> void:
		if ChargerCrafter._is_tap(event):
			accept_event()
			crafter.take(index)

	func _can_drop_data(_at: Vector2, data) -> bool:
		return data is Dictionary and data.has("phase")

	func _drop_data(_at: Vector2, data) -> void:
		crafter.put(index, str(data["phase"]))


## Der Kern in der Mitte: der Hammer, gelb wenn gebaut werden kann.
class _Core extends Control:
	var crafter
	var ready_to_build := false

	func _init(owner_crafter) -> void:
		crafter = owner_crafter
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = "Bauen"
		ready_to_build = GameState.roster.charger_blocker(ChargerCrafter._slots) == ""
		var icon := UiIcon.rect("hammer", 30, Arcade.DEEP if ready_to_build else Arcade.MUTED)
		icon.set_anchors_preset(Control.PRESET_CENTER_TOP)
		icon.name = "Icon"
		add_child(icon)
		var label := Arcade.label("BAUEN", 15, Arcade.DEEP if ready_to_build else Arcade.MUTED, "display")
		label.name = "Label"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)

	func _ready() -> void:
		place()

	func place() -> void:
		var parent := get_parent() as Control
		if parent == null:
			return
		var k := parent.size.x / ChargerCrafter.STAGE.x if parent.size.x > 0 else 320.0 / ChargerCrafter.STAGE.x
		size = Vector2(100, 87) * k
		position = Vector2(170, 147.5) * k - size * 0.5
		var icon := get_node("Icon") as Control
		icon.position = Vector2((size.x - 30) * 0.5, size.y * 0.16)
		var label := get_node("Label") as Control
		label.position = Vector2(0, size.y * 0.56)
		label.size = Vector2(size.x, 20)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		if ready_to_build:
			draw_colored_polygon(PhaseGem.hex(c + Vector2(5, 5), size.x, size.y), Color(Arcade.MAGENTA, 0.75))
		draw_colored_polygon(PhaseGem.hex(c, size.x, size.y), Arcade.YELLOW if ready_to_build else Color("#3a1a6e"))

	func _gui_input(event: InputEvent) -> void:
		if ChargerCrafter._is_tap(event):
			accept_event()
			crafter.build()


## Eine Phase im Lager: ziehen, antippen waehlt, doppelt tippen setzt ein.
class _Source extends PanelContainer:
	var crafter
	var element := ""

	func _init(owner_crafter, e: String) -> void:
		crafter = owner_crafter
		element = e
		add_to_group(Tile.DRAG_GROUP)
		var count: int = crafter.free_count(e)
		var picked := ChargerCrafter._picked == e
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Arcade.VIOLET, 0.94)
		style.border_color = Arcade.CYAN if picked else Color("#6e5ab4")
		style.set_border_width_all(2)
		style.set_content_margin_all(4)
		add_theme_stylebox_override("panel", style)
		modulate.a = 1.0 if count > 0 else 0.4
		custom_minimum_size = Vector2(0, 86)
		tooltip_text = "%s, %d im Lager" % [Charger.element_name(e), count]
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		var gem := PhaseGem.new(e, 42)
		gem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(gem)
		var name := Arcade.label(Charger.element_name(e).to_upper(), 10, Charger.element_color(e), "bold", 0.08)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name)
		var n := Arcade.label("×%d" % count, 12, Arcade.WHITE, "display")
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(n)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _get_drag_data(_at: Vector2):
		if crafter.free_count(element) <= 0:
			return null
		var preview := PhaseGem.new(element, 64)
		set_drag_preview(preview)
		return {"phase": element}

	func _gui_input(event: InputEvent) -> void:
		if not ChargerCrafter._is_tap(event):
			return
		accept_event()
		var now := Time.get_ticks_msec()
		if ChargerCrafter._tap_el == element and now - ChargerCrafter._tap_ms < Tile.DOUBLE_MS:
			ChargerCrafter._tap_ms = -10000
			ChargerCrafter._picked = element
			crafter.put_next(element)
		else:
			ChargerCrafter._tap_ms = now
			ChargerCrafter._tap_el = element
			crafter.pick(element)


## Schmaler Wertbalken in einer Farbe.
class _Bar extends Control:
	var share := 0.0
	var color := Color.WHITE

	func _init(value: float, bar_color: Color) -> void:
		share = clampf(value, 0.0, 1.0)
		color = bar_color
		custom_minimum_size = Vector2(0, 6)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Arcade.DEEP)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * share, size.y)), color)


## Beruehrungen kommen als Maus an (emulate_mouse_from_touch) -- nur die
## zaehlen, sonst loeste ein Tipp doppelt aus.
static func _is_tap(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
