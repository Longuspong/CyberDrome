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
##   Umbau   oben die DROME-Auswahl (Squad zuerst, mit ">>"), darunter seine
##           Halter als Formen (Dreieck leicht, Viereck mittel, Fuenfeck
##           schwer) mit Klasse darunter; der gewaehlte steht im Kasten. Seine
##           Waffen als Kacheln, passende zuerst. Ein Bild antippen (im Halter
##           oder als Kachel) oeffnet die Waffen-Karte (WeaponCard) mit
##           Symbolen, Wertaenderung und "Einbauen" bzw. "Ausbauen".
##
## Regeln, Werte und Validierung kommen wie ueberall aus Roster, DromeBuild und
## PartData (SlotRules sagt sie in Worten). Der Hangar haelt nichts davon selbst.

const PORTRAIT := 150.0
const PRIMARY_EDGE := 140.0
const TILE_EDGE := 104.0
const TILE_COLUMNS := 3
const TILE_GAP := 10
const SLOT_EDGE := 64.0
const PART_EDGE := 72.0

## Welcher Reiter: "squad" oder "umbau". Ueberlebt einen Szenenwechsel ueber
## die Meta des GameState nicht -- muss es auch nicht: aus dem Kampf kommt man
## am besten im Squad an.
var _tab := "squad"
var _selected := -1
## Kurze Rueckmeldung oben (z. B. nach "Bester Aufbau"), einmal gezeigt.
var _notice := ""
var _selected_slot := ""

var _content: VBoxContainer
var _tab_squad: Button
var _tab_umbau: Button


func _ready() -> void:
	if GameState.editing_index >= 0:
		_selected = GameState.editing_index
		_tab = "umbau"
		GameState.editing_index = -1
	elif GameState.roster.entries.size() > 0:
		_selected = _first_in_squad()
	_content = UiKit.page(self, "Hangar", "", 1, true, Ambience.Kind.HANGAR)
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
	return Config.get_int("squad_size_max", 4)


# ---------------------------------------------------------------------------
# Rahmen
# ---------------------------------------------------------------------------

func _build_tabs() -> void:
	# Die Reiter stehen ueber dem scrollbaren Inhalt, damit sie beim Scrollen
	# erreichbar bleiben.
	var frame := _content.get_parent().get_parent().get_parent() as VBoxContainer
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	var holder := MarginContainer.new()
	for side in ["left", "right"]:
		holder.add_theme_constant_override("margin_" + side, UiKit.PAD)
	holder.add_theme_constant_override("margin_top", 8)
	holder.add_child(bar)
	frame.add_child(holder)
	frame.move_child(holder, 1)
	_tab_squad = _tab_button("Squad")
	_tab_squad.pressed.connect(func(): _switch("squad"))
	bar.add_child(_tab_squad)
	_tab_umbau = _tab_button("Umbau")
	_tab_umbau.pressed.connect(func(): _switch("umbau"))
	bar.add_child(_tab_umbau)


func _tab_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 48)
	button.add_theme_font_size_override("font_size", UiKit.BODY)
	return button


func _switch(tab: String) -> void:
	_tab = tab
	_refresh()
	var scroller := _content.get_parent() as ScrollContainer
	if scroller != null:
		scroller.scroll_vertical = 0


func _refresh() -> void:
	_tab_squad.button_pressed = _tab == "squad"
	_tab_umbau.button_pressed = _tab == "umbau"
	for child in _content.get_children():
		child.queue_free()
	if _notice != "":
		_content.add_child(UiKit.label(_notice, UiKit.SMALL, UiKit.GOOD))
		_notice = ""
	if _tab == "squad":
		_show_squad()
	else:
		_show_umbau()


func _changed() -> void:
	GameState.save_roster()
	GameState.refresh_squad()
	_refresh()


# ---------------------------------------------------------------------------
# Reiter "Squad"
# ---------------------------------------------------------------------------

func _show_squad() -> void:
	var count := GameState.roster.squad_count()
	_content.add_child(UiKit.label("Squad  %d / %d" % [count, _squad_max()], UiKit.H2,
		UiKit.GOOD if count > 0 else UiKit.BAD))
	if _selected < 0 or _selected >= _entries().size():
		_selected = _first_in_squad()
	_content.add_child(_primary_card(_selected))

	# Alle DROMEs genau einmal -- der Squad zuerst. Plus/Minus in der Kachel.
	var tiles: Array = []
	for index in _squad_first_order():
		tiles.append(_drome_tile(index))
	_add_tile_rows(_content, tiles)

	if count > 0:
		var best := UiKit.button("Bester Aufbau fuer den Squad")
		best.tooltip_text = "Verteilt die staerksten Waffen auf alle DROMEs im Squad"
		best.pressed.connect(func():
			_best_loadout(GameState.roster.entries.filter(func(e): return e.in_squad)))
		_content.add_child(best)

	_new_drome_section()


## "Bester Aufbau" (Roster.best_loadout) fuer ``targets``, mit kurzer
## Rueckmeldung, was sich geaendert hat.
func _best_loadout(targets: Array) -> void:
	var changed := GameState.roster.best_loadout(targets)
	if changed > 0:
		Accessibility.vibrate(30, true)
	_notice = "Bester Aufbau: %s" % ("%d Halter neu bestueckt" % changed if changed > 0
		else "schon optimal")
	_changed()


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


## Kacheln in Reihen zu TILE_COLUMNS; die letzte Reihe wird mit Luecken
## aufgefuellt, damit alle Kacheln gleich breit bleiben. Gibt die Reihen zurueck.
func _add_tile_rows(parent: Control, tiles: Array) -> Array:
	var rows: Array = []
	for start in range(0, tiles.size(), TILE_COLUMNS):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", TILE_GAP)
		for k in TILE_COLUMNS:
			if start + k < tiles.size():
				row.add_child(tiles[start + k])
			else:
				var gap := Control.new()
				gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(gap)
		parent.add_child(row)
		rows.append(row)
	return rows


func _tile_style(highlight: bool, in_squad: bool) -> StyleBoxFlat:
	var style := UiKit.card_style(highlight)
	if in_squad and not highlight:
		style.border_color = Color(UiKit.GOOD, 0.7)
	style.set_content_margin_all(6)
	return style


## Eine Kachel: das Bild des DROME, so wie er gerade gebaut ist. Im Squad:
## gruener Rand und ">>" oben links. Oben rechts Plus (in den Squad) oder
## Minus (heraus). Antippen zeigt ihn oben in der grossen Box.
func _drome_tile(index: int) -> Control:
	var entry: RosterEntry = _entries()[index]
	var panel := _tappable(_tile_style(index == _selected, entry.in_squad), func():
		_selected = index
		_refresh())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.tooltip_text = entry.name
	var stack := _tile_stack(GameState.roster.build_for(entry), TILE_EDGE, entry.in_squad)
	panel.add_child(stack)

	var full := GameState.roster.squad_count() >= _squad_max()
	var toggle := Button.new()
	toggle.text = "-" if entry.in_squad else "+"
	toggle.add_theme_font_size_override("font_size", 24)
	toggle.custom_minimum_size = Vector2(40, 40)
	toggle.disabled = not entry.in_squad and full
	toggle.tooltip_text = ("%s aus dem Squad" if entry.in_squad else "%s in den Squad") % entry.name
	if toggle.disabled:
		toggle.tooltip_text = "Squad voll (%d) -- erst einen herausnehmen" % _squad_max()
	toggle.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toggle.position = Vector2(-40, 0)
	toggle.pressed.connect(func():
		entry.in_squad = not entry.in_squad
		_selected = index
		_changed())
	stack.add_child(toggle)
	return panel


## Bild in der Mitte einer Kachel, ">>" oben links fuer Squad-Mitglieder.
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
		var mark := _quiet(UiKit.label(">>", UiKit.SMALL, UiKit.GOOD))
		mark.autowrap_mode = TextServer.AUTOWRAP_OFF
		mark.tooltip_text = "im Squad"
		stack.add_child(mark)
	return stack


## Die grosse Box: Bild und Angaben des gewaehlten DROME.
func _primary_card(index: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.card_style(index >= 0))
	if index < 0:
		var empty := UiKit.label("Noch kein DROME. Unten einen bauen.",
			UiKit.BODY, UiKit.MUTED)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(empty)
		return panel
	var entry: RosterEntry = _entries()[index]
	var build := GameState.roster.build_for(entry)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(UiKit.drome_view(build, PRIMARY_EDGE))
	var info := _drome_info(entry, build)
	row.add_child(info)
	info.add_child(UiKit.label("im Squad" if entry.in_squad else "nicht im Squad",
		UiKit.SMALL, UiKit.GOOD if entry.in_squad else UiKit.MUTED))
	return panel


## Name, Kampfwert, Werte und Ausruestung -- fuer die grosse Box und die Angaben.
func _drome_info(entry: RosterEntry, build: DromeBuild) -> VBoxContainer:
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	info.add_child(UiKit.label(entry.name, UiKit.H2))
	# Level und EP (Leveling): "Level 2 · EP 6/9".
	var step := Leveling.progress(entry.xp, Leveling.drome_table())
	info.add_child(UiKit.label("Level %d · %s" % [entry.level,
		"EP %d/%d" % [step[0], step[1]] if step[1] > 0 else "Hoechstlevel"], UiKit.SMALL, UiKit.GOOD))
	info.add_child(UiKit.label("Kampfwert %d" % int(build.power_score()), UiKit.SMALL,
		UiKit.ACCENT))
	# Werte als Balken (10. Nov. 2026) -- zwischen DROMEs vergleichbar.
	var stats := build.stats()
	for key in ["hp_max", "shield_max", "spd", "def", "power"]:
		info.add_child(StatBar.make(key, float(stats.get(key, 0))))
	info.add_child(UiKit.label(_loadout(build), UiKit.SMALL, UiKit.MUTED))
	return info


func _new_drome_section() -> void:
	var free := GameState.roster.free_chassis_types()
	_content.add_child(UiKit.heading("Neuen DROME bauen"))
	if free.is_empty():
		_content.add_child(UiKit.label("Kein freies Chassis. Loese einen DROME auf oder "
			+ "erbeute ein neues.", UiKit.SMALL, UiKit.MUTED))
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)
	for chassis_id in free:
		var body := PartDB.get_part(chassis_id)
		if body == null:
			continue
		var panel := _tappable(UiKit.card_style(), func():
			var entry := GameState.roster.new_drome(chassis_id)
			if entry == null:
				return
			_selected = _entries().size() - 1
			_tab = "umbau"
			_changed())
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(box)
		box.add_child(UiKit.chassis_view(body, 90))
		var label := _quiet(UiKit.label(body.display_name.replace(" Chassis", ""), UiKit.SMALL))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
		row.add_child(panel)


# ---------------------------------------------------------------------------
# Reiter "Umbau"
# ---------------------------------------------------------------------------

func _show_umbau() -> void:
	if _entries().is_empty():
		_content.add_child(UiKit.label("Noch kein DROME. Im Reiter Squad einen bauen.",
			UiKit.BODY, UiKit.MUTED))
		return
	_selected = clampi(_selected, 0, _entries().size() - 1)
	var entry: RosterEntry = _entries()[_selected]
	var build := GameState.roster.build_for(entry)

	_content.add_child(_picker())

	# Der gewaehlte DROME: Bild und die Werte, die beim Bauen zaehlen.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_content.add_child(head)
	head.add_child(UiKit.drome_view(build, PORTRAIT))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(info)
	var name_field := LineEdit.new()
	name_field.text = entry.name
	name_field.custom_minimum_size = Vector2(0, 44)
	name_field.add_theme_font_size_override("font_size", UiKit.BODY)
	name_field.text_submitted.connect(func(text):
		entry.name = text
		_changed())
	name_field.focus_exited.connect(func():
		if name_field.text != entry.name:
			entry.name = name_field.text
			GameState.save_roster())
	info.add_child(name_field)
	var stats := build.stats()
	for key in ["hp_max", "shield_max", "spd", "def", "power"]:
		info.add_child(StatBar.make(key, float(stats.get(key, 0))))
	info.add_child(StatBar.make("power_score", build.power_score()))

	# Ohne Kern-Halter (6g) ist der erste Ausruestungshalter vorgewaehlt.
	var equip := build.equip_slots()
	if not equip.is_empty() and _selected_slot not in equip:
		_selected_slot = equip[0]
	_content.add_child(_slots(entry, build))
	var best := UiKit.button("Bester Aufbau")
	best.tooltip_text = "Ruestet diesen DROME mit den staerksten freien Waffen aus"
	best.pressed.connect(func():
		_best_loadout([entry]))
	_content.add_child(best)
	_parts_for_slot(entry, build)

	var problems := build.validate()
	for line in problems:
		_content.add_child(UiKit.label("Achtung: " + line, UiKit.SMALL, UiKit.BAD))

	var scrap := UiKit.button("DROME aufloesen")
	scrap.tooltip_text = "Seine Teile kehren ins Inventar zurueck."
	scrap.add_theme_color_override("font_color", UiKit.BAD)
	scrap.pressed.connect(func():
		GameState.roster.disband(entry)
		_selected = _first_in_squad()
		_tab = "squad"
		_changed())
	_content.add_child(scrap)


## Die DROME-Auswahl oben: der Squad zuerst, dann der Rest.
func _picker() -> Control:
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 104)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	scroll.add_child(row)
	for index in _squad_first_order():
		var entry: RosterEntry = _entries()[index]
		var panel := _tappable(UiKit.card_style(index == _selected), func():
			_selected = index
			_selected_slot = ""
			_refresh())
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(box)
		box.add_child(_tile_stack(GameState.roster.build_for(entry), 56, entry.in_squad))
		var label := _quiet(UiKit.label(entry.name, UiKit.SMALL,
			Color.WHITE if entry.in_squad else UiKit.MUTED))
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
		row.add_child(panel)
	return scroll


## Die Halter als Formen: die Ausruestungshalter in ihrer Klassenform (den
## Kern-Halter gibt es seit 6g nicht mehr); darin die Waffe oder leer. Der
## gewaehlte Halter steht in einem hervorgehobenen Kasten; unter jedem Halter
## seine Klasse. Antippen waehlt den Halter; steckt eine Waffe darin, oeffnet
## sich ihre Karte mit "Ausbauen".
func _slots(entry: RosterEntry, build: DromeBuild) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var chassis := build.body()
	for slot in build.equip_slots():
		var part := build.part_in(slot)
		var kind := "core" if slot == "core" else SlotRules.slot_class(chassis, slot)
		var chosen: bool = slot == _selected_slot
		var style := UiKit.card_style(chosen)
		style.set_content_margin_all(6)
		if chosen:
			style.bg_color = Color(UiKit.ACCENT, 0.18)
			style.set_border_width_all(3)
		else:
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = Color(0, 0, 0, 0)
		var holder := _tappable(style, func():
			_selected_slot = slot
			_refresh()
			if part != null:
				_open_card(entry, build, part, slot))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(box)
		var shape := SlotShape.new(kind, UiKit.part_texture(part), SLOT_EDGE)
		shape.highlight = chosen
		shape.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(shape)
		var label := _quiet(UiKit.label(SlotRules.slot_label(slot), UiKit.SMALL,
			Color.WHITE if chosen else UiKit.MUTED))
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
		if kind == "core":
			row.add_child(holder)
			continue
		var weight := _quiet(UiKit.label(_class_name(kind), UiKit.SMALL,
			_class_color(kind) if chosen else Color(_class_color(kind), 0.6)))
		weight.autowrap_mode = TextServer.AUTOWRAP_OFF
		weight.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(weight)
		row.add_child(holder)
	return row


## "Kern", "leicht", "mittel", "schwer".
func _class_name(kind: String) -> String:
	return "Kern" if kind == "core" else SlotRules.class_label(kind)


## Eine Farbe je Klasse -- zusaetzlich zur Form, nie statt ihr.
func _class_color(kind: String) -> Color:
	match kind:
		"light": return UiKit.GOOD
		"medium": return UiKit.WARN
		"heavy": return UiKit.BAD
		_: return UiKit.ACCENT


## Die Teile fuer den gewaehlten Halter als Kacheln -- nur die Form mit Bild,
## passende zuerst, die uebrigen gedaempft. Eine Kachel angetippt zeigt
## daruber alle Angaben, die Wertaenderung und "Einbauen".
func _parts_for_slot(entry: RosterEntry, build: DromeBuild) -> void:
	var type := PartData.Type.CORE if _selected_slot == "core" else PartData.Type.EQUIPMENT
	var fits: Array = []
	var rest: Array = []
	for part_id in GameState.roster.owned_part_ids(type):
		var part := PartDB.get_part(part_id)
		if part == null:
			continue
		var verdict := _verdict(entry, build, part)
		(fits if verdict == "" else rest).append([part, verdict])
	var items := fits + rest
	if items.is_empty():
		_content.add_child(UiKit.label("Keine Teile fuer diesen Halter.", UiKit.SMALL,
			UiKit.MUTED))
		return
	if fits.is_empty():
		_content.add_child(UiKit.label("Nichts Passendes frei.", UiKit.SMALL, UiKit.MUTED))
	var tiles: Array = []
	for item in items:
		tiles.append(_part_tile(entry, build, item[0], item[1]))
	_add_tile_rows(_content, tiles)


## Leer = einbaubar; sonst der Grund.
func _verdict(entry: RosterEntry, build: DromeBuild, part: PartData) -> String:
	var current := build.part_in(_selected_slot)
	if current != null and current.id == part.id:
		return "steckt schon hier"
	if _selected_slot != "core" and not build.body().accepts(part, _selected_slot):
		var rule: Dictionary = build.body().slot_rules.get(_selected_slot, {})
		return SlotRules.rejection(part, rule, SlotRules.slot_class(build.body(), _selected_slot))
	if GameState.roster.free_count(part.id) <= 0:
		return "alle Exemplare verbaut"
	return ""


## Eine Teil-Kachel: nur die Form mit dem Bild. Gedaempft, wenn es hier nicht
## eingebaut werden kann. Antippen oeffnet die Waffen-Karte.
func _part_tile(entry: RosterEntry, build: DromeBuild, part: PartData,
		verdict: String) -> Control:
	var panel := _tappable(_tile_style(false, false), func():
		_open_card(entry, build, part, "", verdict))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.tooltip_text = part.display_name
	var kind := "core" if part.type == PartData.Type.CORE else part.mount_class
	var shape := SlotShape.new(kind, UiKit.part_texture(part), PART_EDGE)
	shape.dim = verdict != ""
	shape.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	shape.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(shape)
	if verdict != "":
		panel.modulate = Color(1, 1, 1, 0.55)
	return panel


## Die Waffen-Karte. ``installed_in``: der Halter, in dem sie steckt (dann
## "Ausbauen"); leer = eine Kachel aus dem Bestand (dann "Einbauen" in den
## gewaehlten Halter, mit Wertaenderung, oder der Grund, warum nicht).
func _open_card(entry: RosterEntry, build: DromeBuild, part: PartData,
		installed_in: String, verdict: String = "") -> void:
	if installed_in != "":
		WeaponCard.open(self, part, Callable(), [{"text": "Ausbauen", "on": func():
			GameState.roster.clear_slot(entry, installed_in)
			_changed()}])
		return
	var slot := _selected_slot
	var extra := func(box: VBoxContainer):
		box.add_child(UiKit.label("%d frei im Hangar" % GameState.roster.free_count(part.id),
			UiKit.SMALL, UiKit.MUTED))
		if verdict != "":
			box.add_child(UiKit.label("Halter %s: %s" % [SlotRules.slot_label(slot), verdict],
				UiKit.SMALL, UiKit.WARN))
			return
		var replaced := build.part_in(slot)
		if replaced != null:
			box.add_child(UiKit.label("ersetzt %s (zurueck in den Hangar)"
				% replaced.display_name, UiKit.SMALL, UiKit.WARN))
		_delta_lines(build, slot, part, box)
	WeaponCard.open(self, part, extra, [{"text": "Einbauen", "primary": true,
		"disabled": verdict != "", "on": func():
			if GameState.roster.assign(entry, slot, part.id):
				Accessibility.vibrate(20, true)
				_changed()}])


## Was sich am DROME aendern wuerde -- nur die Werte, die sich bewegen.
func _delta_lines(build: DromeBuild, slot: String, part: PartData, box: VBoxContainer) -> void:
	var trial := build.clone()
	trial.slots[slot] = part.id
	var before := build.stats()
	var after := trial.stats()
	# Vorher -> nachher als Vergleichsbalken: gruen dazu, rot weg.
	for key in ["hp_max", "shield_max", "shield_pulse", "spd", "def", "power"]:
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
	return ", ".join(names) if not names.is_empty() else "ohne Ausruestung"
