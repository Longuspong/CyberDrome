class_name SquadPicker
extends VBoxContainer

## Wer kommt mit? Die Squad-Auswahl vor einem Lauf und vor dem Chaos-Virus.
##
## Oben "Dabei" -- je DROME eine Karte mit Bild, Staerke und Ausruestung und
## einem Minus. Darunter "Bleibt zuhause" mit einem Plus. Vorgeschlagen ist der
## Hangar-Squad (``in_squad``); die Auswahl schreibt auch dorthin zurueck, damit
## sie beim naechsten Mal wieder vorgeschlagen wird.
##
## Kein Umbau: gebaut wird im Hangar. Hier wird nur gewaehlt.

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


## Alle waehlbaren Aufbauten -- fuer die Referenz-Staerke im Chaos-Virus.
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
	for child in get_children():
		child.queue_free()

	if _items.is_empty():
		add_child(UiKit.label("Keine kampftauglichen DROMEs. Bau im Hangar welche zusammen.",
			UiKit.BODY, UiKit.BAD))
		return

	var count := chosen_count()
	var power := DromeBuild.squad_power(chosen_builds())
	add_child(UiKit.label("Dabei  %d / %d   ·   Staerke %d" % [count, _max_count, int(power)],
		UiKit.H2, UiKit.HEADING))
	if count == 0:
		add_child(UiKit.label("Noch niemand -- tippe unten auf +.", UiKit.SMALL, UiKit.MUTED))
	for item in _items:
		if item["entry"].in_squad:
			add_child(_card(item, true, true))

	var rest := _items.filter(func(item): return not item["entry"].in_squad)
	if rest.is_empty():
		return
	add_child(UiKit.label("Bleibt zuhause", UiKit.BODY, UiKit.MUTED))
	for item in rest:
		add_child(_card(item, false, count < _max_count))


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
	var name := UiKit.label("%s  ·  %d" % [build.display_name, int(build.power_score())],
		UiKit.BODY)
	name.tooltip_text = "Name und Kampfwert"
	text.add_child(name)
	text.add_child(UiKit.label(loadout_text(build), UiKit.SMALL, UiKit.MUTED))
	return panel


static func loadout_text(build: DromeBuild) -> String:
	var names: Array[String] = []
	for part in build.equipment():
		names.append(part.display_name)
	return ", ".join(names) if not names.is_empty() else "ohne Ausruestung"


func _card(item: Dictionary, chosen: bool, enabled: bool) -> Control:
	var entry: RosterEntry = item["entry"]
	var panel := drome_card(item["build"], chosen)
	var row: HBoxContainer = panel.get_child(0)
	var toggle := Button.new()
	toggle.text = "-" if chosen else "+"
	toggle.custom_minimum_size = Vector2(52, 52)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.add_theme_font_size_override("font_size", 28)
	toggle.disabled = not enabled
	toggle.tooltip_text = ("%s zuhause lassen" if chosen else "%s mitnehmen") % entry.name
	if not enabled:
		toggle.tooltip_text = "Squad ist voll (%d)" % _max_count
	toggle.pressed.connect(func(): _set_chosen(entry, not chosen))
	row.add_child(toggle)
	return panel
