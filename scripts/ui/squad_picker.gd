class_name SquadPicker
extends VBoxContainer

## Wer kommt mit? Die Squad-Auswahl vor einem Lauf.
##
## Oben "Dabei" -- je DROME eine Karte mit Bild, Staerke und Ausruestung und
## einem Minus. Darunter "Bleibt zuhause" mit einem Plus. Vorgeschlagen ist der
## Hangar-Squad (``in_squad``); die Auswahl schreibt auch dorthin zurueck, damit
## sie beim naechsten Mal wieder vorgeschlagen wird.
##
## Kein Umbau: gebaut wird im Hangar. Hier wird nur gewaehlt.
##
## Seit 21. Nov. 2026 (Wunsch des Spielers): oben die Plaetze des Squads (FREI
## oder belegt, antippen nimmt heraus), darunter alle uebrigen DROMEs als
## Kacheln in zwei Reihen -- Name klein oben, der DROME von vorn --, bei mehr als
## sechs seitlich zu scrollen. Antippen setzt ihn auf den naechsten freien Platz.

signal changed

## Die waehlbaren DROMEs: {entry: RosterEntry, build: DromeBuild}.
var _items: Array = []
var _max_count: int = 4


## Sammelt alle kampftauglichen DROMEs des Rosters ein und zeigt sie.
func setup(max_count: int) -> void:
	_max_count = max_count
	_items.clear()
	for entry in GameState.roster.entries:
		var build := GameState.roster.build_for(entry)
		if build.is_valid():
			_items.append({"entry": entry, "build": build})
	# Mehr als erlaubt vorausgewaehlt (alter Stand)? Die ersten bleiben dabei.
	var kept := 0
	for item in _items:
		if item["entry"].in_squad:
			kept += 1
			if kept > _max_count:
				item["entry"].in_squad = false
	add_theme_constant_override("separation", 8)
	_rebuild()


func chosen_builds() -> Array:
	return _items.filter(func(item): return item["entry"].in_squad) \
		.map(func(item): return item["build"])


func chosen_count() -> int:
	return chosen_builds().size()


func _set_chosen(entry: RosterEntry, chosen: bool) -> void:
	if chosen and chosen_count() >= _max_count:
		return
	entry.in_squad = chosen
	GameState.save_roster()
	_rebuild.call_deferred()
	changed.emit()


func _rebuild() -> void:
	UiKit.clear(self)

	if _items.is_empty():
		add_child(UiKit.label("Keine kampftauglichen DROMEs. Bau im Hangar welche zusammen.",
			UiKit.BODY, UiKit.BAD))
		return

	var count := chosen_count()
	var power := DromeBuild.squad_power(chosen_builds())
	var head := HBoxContainer.new()
	var title := Arcade.label("DEIN SQUAD", 13, Arcade.CYAN, "bold", 0.14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(Arcade.label("KW %d  " % int(power), 12, Arcade.MUTED, "bold", 0.1))
	head.add_child(Arcade.label("%d/%d" % [count, _max_count], 18, Arcade.YELLOW, "display"))
	add_child(head)

	# Die Plaetze des Squads: belegt (antippen nimmt heraus) oder FREI.
	var slots := GridContainer.new()
	slots.columns = _max_count
	slots.add_theme_constant_override("h_separation", 8)
	add_child(slots)
	var chosen := _items.filter(func(item): return item["entry"].in_squad)
	for i in _max_count:
		if i < chosen.size():
			var item: Dictionary = chosen[i]
			var entry: RosterEntry = item["entry"]
			var slot := _TapPanel.new(func(): _set_chosen(entry, false))
			slot.tooltip_text = "%s zuhause lassen" % entry.name
			slot.add_theme_stylebox_override("panel", _box(true))
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot.add_child(_drome_box(item, 64))
			slots.add_child(slot)
		else:
			slots.add_child(_free_slot())

	# Darunter alle uebrigen DROMEs: Raster aus zwei Reihen, seitlich scrollbar.
	var rest := _items.filter(func(item): return not item["entry"].in_squad)
	if rest.is_empty():
		return
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 2 * TILE_H + 10)
	add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = maxi(3, int(ceil(float(rest.size()) / 2.0)))
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var full := count >= _max_count
	for item in rest:
		var entry: RosterEntry = item["entry"]
		var tile := _TapPanel.new(func(): _set_chosen(entry, true))
		tile.tooltip_text = "%s mitnehmen" % entry.name if not full else "Squad ist voll (%d)" % _max_count
		tile.add_theme_stylebox_override("panel", _box(false))
		tile.custom_minimum_size = Vector2(TILE_W, TILE_H)
		tile.modulate.a = 0.55 if full else 1.0
		tile.add_child(_drome_box(item, 84))
		grid.add_child(tile)


const TILE_W := 128.0
const TILE_H := 132.0


func _box(chosen: bool) -> StyleBoxFlat:
	var style := UiKit.card_style(chosen)
	style.set_content_margin_all(6)
	return style


## Name klein oben, darunter der DROME von vorn (schaut nach Suedwesten).
func _drome_box(item: Dictionary, edge: float) -> Control:
	var entry: RosterEntry = item["entry"]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label(entry.name, 10))
	box.add_child(subtitle_label(Roster.subtitle(entry), 9, edge + 20.0))
	var view := UiKit.drome_view(item["build"], edge, "south")
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(view)
	return box


## Ein DROME-Name in fester Hoehe fuer zwei Zeilen: lange Namen ("SOLAR
## NIMBUS") brechen um, statt abgeschnitten zu werden oder die Zeile zu
## verschieben; kurze stehen unten, damit die Bilder auf einer Linie bleiben.
static func name_label(text: String, size: int) -> Label:
	var name := Arcade.label(text.to_upper(), size, Arcade.WHITE, "display")
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.custom_minimum_size = Vector2(40, size * 2.4)
	name.max_lines_visible = 2
	return name


## Der Untertitel unter dem Namen (21. Nov. 2026): Fraktion oder "CyberDrome".
## Eine Zeile in fester Hoehe; Fraktionen in Magenta, Standard gedaempft.
static func subtitle_label(text: String, size: int, width: float = 0.0) -> Label:
	# Accessibility hebt jede Schrift auf mindestens 16 px -- die Breite muss
	# also fuer "NEON NINJA'S" reichen, sonst endet der Text mit "...".
	var sub := Arcade.label(text.to_upper(), size,
		Arcade.MUTED if text == "CyberDrome" else Arcade.MAGENTA, "bold")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.clip_text = true
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.custom_minimum_size = Vector2(maxf(width, 40.0), 0)
	return sub


func _free_slot() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Arcade.NIGHT, 0.6)
	style.border_color = Arcade.EMPTY_LINE
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 92)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var plus := UiIcon.rect("plus", 22, Arcade.EMPTY_NUM)
	plus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(plus)
	var label := Arcade.label("FREI", 12, Arcade.EMPTY_NUM, "bold", 0.14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	return panel


## Eine Karte: Bild, Name, Staerke, Ausruestung -- und rechts Plus oder Minus.
static func drome_card(build: DromeBuild, highlight: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.card_style(highlight))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	row.add_child(UiKit.drome_view(build, 72))

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	var name := UiKit.label("%s%s  ·  %d" % [build.display_name,
		"  Lv %d" % build.drome_level if build.drome_level > 0 else "", int(build.power_score())],
		UiKit.BODY)
	name.tooltip_text = "Name und Kampfwert"
	text.add_child(name)
	text.add_child(UiKit.label(loadout_text(build), UiKit.SMALL, UiKit.MUTED))
	return panel


static func loadout_text(build: DromeBuild) -> String:
	var names: Array[String] = []
	for part in build.equipment():
		names.append(part.display_name)
	var text := ", ".join(names) if not names.is_empty() else "ohne Ausrüstung"
	# Module (6i): bei Gegnern im Lauf sichtbar, damit man weiss, worauf man
	# sich einlaesst.
	var mods: Array[String] = []
	for slot in build.equip_slots():
		for module in build.modules_in(slot):
			mods.append(module.display_name)
	if not mods.is_empty():
		text += "\nModule: %s" % ", ".join(mods)
	return text


## Alte Listenkarte mit Plus/Minus (bis 20. Nov. 2026), bleibt fuer Aufrufer.
func _card(item: Dictionary, chosen: bool, enabled: bool) -> Control:
	var entry: RosterEntry = item["entry"]
	var panel := drome_card(item["build"], chosen)
	var row: HBoxContainer = panel.get_child(0)
	var toggle := Button.new()
	UiIcon.on_button(toggle, "minus" if chosen else "plus", 22, UiKit.TEXT, "center")
	toggle.custom_minimum_size = Vector2(52, 52)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.disabled = not enabled
	toggle.tooltip_text = ("%s zuhause lassen" if chosen else "%s mitnehmen") % entry.name
	if not enabled:
		toggle.tooltip_text = "Squad ist voll (%d)" % _max_count
	toggle.pressed.connect(func(): _set_chosen(entry, not chosen))
	row.add_child(toggle)
	return panel


## Eine Kachel, die auf Tippen reagiert; Ecken-Etiketten liegen darueber.
class _TapPanel extends PanelContainer:
	var _on_tap: Callable

	func _init(on_tap: Callable) -> void:
		_on_tap = on_tap
		mouse_filter = Control.MOUSE_FILTER_STOP

	var _down := Vector2(-9999, -9999)

	## Tippen = Loslassen ohne Wischen (sonst scrollt das Raster seitlich).
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_down = event.global_position
			elif _down.distance_to(event.global_position) < 14.0:
				_down = Vector2(-9999, -9999)
				_on_tap.call()
