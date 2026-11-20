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
## Seit 20. Nov. 2026 (Design-Canvas, Einsatzvorbereitung): Kacheln im Raster
## 2 x n -- Rollensechseck, Name, Rolle und Level, Waffe; antippen nimmt mit,
## nochmal tippen laesst zuhause. Gewaehlte tragen DABEI, wer gut gegen die
## erwarteten Gegner passt (``counter_roles``), traegt KONTER.

signal changed

## Die waehlbaren DROMEs: {entry: RosterEntry, build: DromeBuild}.
var _items: Array = []
var _max_count: int = 4
## Rollen, die gegen die erwarteten Gegner gut passen (EnemyIntel.counter_roles).
var counter_roles: Array = []


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


## Alle waehlbaren Aufbauten.
func all_builds() -> Array:
	return _items.map(func(item): return item["build"])


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
	add_child(UiKit.label("Antippen nimmt mit · nochmal tippen lässt zuhause", 13, UiKit.MUTED))
	# Platz fuer die schraegen DABEI-Etiketten ueber der ersten Reihe.
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	add_child(gap)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 22)
	add_child(grid)
	for item in _items:
		var chosen: bool = item["entry"].in_squad
		grid.add_child(_tile(item, chosen, chosen or count < _max_count))


## Eine Kachel: Rollensechseck, Name, Rolle und Level, Waffe; DABEI / KONTER.
func _tile(item: Dictionary, chosen: bool, enabled: bool) -> Control:
	var entry: RosterEntry = item["entry"]
	var build: DromeBuild = item["build"]
	var role := HangarScreen.role_key(build)
	var panel := _TapPanel.new(func(): _set_chosen(entry, not chosen))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := UiKit.card_style(chosen)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(0, 92)
	panel.modulate.a = 1.0 if enabled else 0.5
	panel.tooltip_text = ("%s zuhause lassen" if chosen else "%s mitnehmen") % entry.name \
		if enabled else "Squad ist voll (%d)" % _max_count
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var hex := _RoleHex.new(role, Arcade.CYAN if chosen else Color("#6e5ab4"))
	hex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hex)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var name := Arcade.label(entry.name.to_upper(), 15, Arcade.WHITE, "display")
	name.clip_text = true
	text.add_child(name)
	var role_line := Arcade.label("%s · LV %d" % [HangarScreen.role_text(build).get_slice(" · ", 0).to_upper(),
		entry.level], 10, Arcade.CYAN, "bold")
	role_line.clip_text = true
	text.add_child(role_line)
	var weapons := Arcade.label(loadout_text(build).get_slice("\n", 0), 11, Arcade.MUTED)
	weapons.clip_text = true
	text.add_child(weapons)
	if chosen:
		var tag := Arcade.tilt(Arcade.tag("DABEI", 10, 0.0), 3.0)
		tag.position = Vector2(0, -10)
		panel.add_overlay(tag, Vector2(1, 0))
	elif role in counter_roles:
		var hint := HBoxContainer.new()
		hint.add_theme_constant_override("separation", 3)
		hint.add_child(UiIcon.rect("check", 12, UiKit.GOOD))
		hint.add_child(Arcade.label("KONTER", 10, UiKit.GOOD, "bold", 0.08))
		panel.add_overlay(hint, Vector2(1, 1))
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

	## Legt ``child`` in eine Ecke (anchor 0/1 je Achse) ueber die Kachel.
	func add_overlay(child: Control, corner: Vector2) -> void:
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(holder)
		holder.add_child(child)
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		child.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT if corner == Vector2(1, 1)
			else Control.PRESET_TOP_RIGHT)
		child.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		child.grow_vertical = Control.GROW_DIRECTION_BEGIN if corner.y > 0.5 else Control.GROW_DIRECTION_END
		if corner.y < 0.5:
			child.position.y -= 22

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			_on_tap.call()


## Rollensymbol im Sechseck (Farbe: gewaehlt Cyan, sonst Violett).
class _RoleHex extends Control:
	var tint := Color.WHITE

	func _init(role: String, color: Color) -> void:
		tint = color
		custom_minimum_size = Vector2(38, 33)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := UiIcon.rect("role_" + (role if role != "" else "skirmisher"), 18, Arcade.NIGHT)
		icon.position = Vector2(10, 7.5)
		add_child(icon)

	func _draw() -> void:
		draw_colored_polygon(PhaseGem.hex(size * 0.5, size.x, size.y), tint)
