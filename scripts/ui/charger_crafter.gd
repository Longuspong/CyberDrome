class_name ChargerCrafter
extends VBoxContainer

## Der Charger-Crafter im Shop-Reiter Bauen (Design-Canvas 20. Nov. 2026,
## Uebergabe Ue3, Skizze des Spielers): sechs Phasen-Felder ergeben ein grosses
## Hexagon, in der Mitte der Hammer zum Bauen. Darunter ein Sockel mit dem
## Rohling, die Belastung je Treffer, die Resonanz (Stufen zaehlen zusammen) und
## die Phasen im Lager.
##
## Bedienung (21. Nov. 2026): Phase antippen setzt sie ins naechste freie Feld,
## ziehen legt sie auf ein bestimmtes Feld; ein belegtes Feld antippen nimmt
## sie wieder heraus. Alles hat feste Hoehen -- beim Tippen springt nichts. Die
## Auswertung (Belastung, Resonanz) erscheint erst mit der ersten Phase.

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
## Feste Hoehe der Auswertung unter den Phasen (leer, solange keine Phase drin ist).
const READOUT_H := 60.0

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
	# Fabrik (23. Nov. 2026): Rohlinge entstehen aus Lager-Ressourcen.
	var cost := FactorySim.craft_cost("rohling")
	if not cost.is_empty():
		var press := UiKit.outline_button("Rohling herstellen: " + FactorySim.amounts_text(cost))
		var sim := roster.factory_sim()
		press.disabled = not sim.can_pay(cost)
		press.pressed.connect(func():
			if sim.craft("rohling") == "":
				GameState.save_roster()
				_rebuild())
		add_child(press)

	var holder := CenterContainer.new()
	add_child(holder)
	_stage = _Stage.new(self)
	holder.add_child(_stage)
	_add_slots()

	# Sockel aus der Skizze: Trapez unter dem Hexagon, darauf der Rohling.
	var sockel_holder := CenterContainer.new()
	add_child(sockel_holder)
	sockel_holder.add_child(_Sockel.new("ROHLING · MK I", "%d/6" % Charger.filled(_slots)))

	# Gleich unter dem Hexagon die Phasen (was man zuerst braucht), darunter
	# die Auswertung -- in fester Hoehe, damit beim Tippen nichts springt.
	add_child(Arcade.label("ENERGY PHASES", 13, Arcade.CYAN, "bold", 0.14))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	add_child(grid)
	for e in Charger.element_ids():
		var src := _Source.new(self, e)
		src.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(src)

	_readout = VBoxContainer.new()
	_readout.custom_minimum_size = Vector2(0, READOUT_H)
	_readout.add_theme_constant_override("separation", 6)
	add_child(_readout)
	_fill_readout()


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


## Zwei feste Zeilen, erst sichtbar, wenn eine Phase im Hexagon liegt:
## Belastung je Treffer (je Element) und die Resonanz (2/4/6, die hoechste
## erreichte Stufe mit ihrem Effekt).
func _fill_readout() -> void:
	if Charger.filled(_slots) == 0:
		return
	var loads := Charger.loads(_slots)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 24)
	row.add_child(Arcade.label("BELASTUNG", 11, Arcade.CYAN, "bold", 0.14))
	for e in Charger.element_ids():
		if loads.has(e):
			row.add_child(Arcade.label("%s +%d" % [Charger.element_name(e).to_upper(), int(loads[e])], 12,
				Charger.element_color(e), "bold", 0.06))
	_readout.add_child(row)

	var dom := Charger.dominant(_slots)
	var dcol := Charger.element_color(dom) if dom != "" else Arcade.MUTED
	var n := Charger.dominant_count(_slots)
	var res := HBoxContainer.new()
	res.add_theme_constant_override("separation", 4)
	res.custom_minimum_size = Vector2(0, 26)
	res.add_child(Arcade.label("RESONANZ ", 11, Arcade.CYAN, "bold", 0.14))
	for at in [2, 4, 6]:
		var on: bool = n >= at
		var badge := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = dcol if on else Arcade.DEEP
		badge.add_theme_stylebox_override("panel", st)
		badge.custom_minimum_size = Vector2(22, 22)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var num := Arcade.label(str(at), 12, Arcade.NIGHT if on else Arcade.EMPTY_NUM, "display")
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_child(num)
		res.add_child(badge)
	_readout.add_child(res)
	res.add_child(Control.new())
	# Alle wirkenden Stufen (2 und 4 zusammen; 6 verbessert beide), eine Zeile.
	var parts: Array = []
	for r in Charger.active_resonances(_slots):
		var at := int(r.get("at", 0))
		if not Charger.upgraded(at, _slots):
			parts.append(Charger.resonance_text(at))
	var text := Arcade.label(" · ".join(parts) if not parts.is_empty() else "ab 2 gleichen Phasen", 12,
		Arcade.TEXT if not parts.is_empty() else Arcade.MUTED)
	text.clip_text = true
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.custom_minimum_size = Vector2(60, 18)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res.add_child(text)


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
		# Der gelbe Knopf pulsiert, solange gebaut werden kann (Entwurf, 1,4 s).
		if ready_to_build and Arcade.moving():
			var tween := create_tween().set_loops()
			tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.7).set_trans(Tween.TRANS_SINE)
			tween.tween_property(self, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)

	func place() -> void:
		var parent := get_parent() as Control
		if parent == null:
			return
		var k := parent.size.x / ChargerCrafter.STAGE.x if parent.size.x > 0 else 320.0 / ChargerCrafter.STAGE.x
		size = Vector2(100, 87) * k
		pivot_offset = size * 0.5
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
		# Antippen setzt die Phase ins naechste freie Feld (21. Nov. 2026).
		crafter.put_next(element)


## Der Sockel unter dem Hexagon: Trapez mit Kante oben, Name und Fuellstand.
class _Sockel extends Control:
	var title := ""
	var count := ""

	func _init(text: String, fill: String) -> void:
		title = text
		count = fill
		custom_minimum_size = Vector2(200, 28)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.1, 0), Vector2(w * 0.9, 0), Vector2(w, h), Vector2(0, h)]),
			Arcade.VIOLET)
		draw_line(Vector2(w * 0.1, 1), Vector2(w * 0.9, 1), Color("#6e5ab4"), 2.0)
		var font := Arcade.font("bold")
		var a := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var b := font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var x := (w - a - 8.0 - b) * 0.5
		draw_string(font, Vector2(x, h * 0.68), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Arcade.MUTED)
		draw_string(font, Vector2(x + a + 8.0, h * 0.68), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Arcade.YELLOW)


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
