extends Control

## Der Hangar: Squad und Umbau an EINER Stelle -- mobile first.
##
## Ersetzt Garage, Inventar und Werkstatt. Die drei Bildschirme zeigten
## dieselben Dinge (DROMEs, Teile, Halter) aus drei Blickwinkeln, und wer einen
## Blaster einbauen wollte, musste zwischen ihnen hin und her. Hier gibt es zwei
## Reiter:
##
##   Squad   oben der Squad (hoechstens vier): der Hauptgewaehlte als grosse
##           Box mit Angaben, die anderen als Kacheln (nur das Bild). Darunter
##           alle DROMEs als Kacheln, gruen umrandet wer im Squad ist. Antippen
##           zeigt die Angaben und "In den Squad".
##   Umbau   oben die DROME-Auswahl, darunter seine Halter als Formen
##           (Dreieck leicht, Viereck mittel, Fuenfeck schwer, Kreis Kern) mit
##           Klasse darunter; der gewaehlte steht im Kasten. Seine Teile als
##           Kacheln (nur die Form), passende zuerst. Eine Kachel angetippt
##           zeigt darueber alle Angaben, was sich aendert, und "Einbauen".
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
## Wer im Squad-Reiter gross oben steht (Index, -1 = keiner).
var _primary := -1
var _selected_slot := ""
## Ob die Info zum eingebauten Teil im gewaehlten Halter aufgeklappt ist.
var _slot_details: bool = false
var _preview_part: PartData = null

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
	_preview_part = null
	_refresh()
	var scroller := _content.get_parent() as ScrollContainer
	if scroller != null:
		scroller.scroll_vertical = 0


func _refresh() -> void:
	_tab_squad.button_pressed = _tab == "squad"
	_tab_umbau.button_pressed = _tab == "umbau"
	for child in _content.get_children():
		child.queue_free()
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

	# Der Hauptgewaehlte gross, die uebrigen Squad-Plaetze als Kacheln darunter.
	var primary := _primary_index()
	var others: Array = []
	for i in _entries().size():
		if _entries()[i].in_squad and i != primary:
			others.append(_drome_tile(i))
	while others.size() < _squad_max() - 1:
		others.append(_empty_tile())
	_add_tile_rows(_content, others)
	_content.add_child(_primary_card(primary))

	# Alle DROMEs als Kacheln -- nur das Bild. Die Angaben kommen erst beim
	# Antippen, direkt unter der Reihe der Kachel.
	var tiles: Array = []
	for i in _entries().size():
		tiles.append(_drome_tile(i))
	var rows := _add_tile_rows(_content, tiles)
	if _selected >= 0 and _selected < _entries().size() and not _entries()[_selected].in_squad:
		var row: Control = rows[_selected / TILE_COLUMNS]
		var details := _roster_details(_selected)
		_content.add_child(details)
		_content.move_child(details, row.get_index() + 1)

	_new_drome_section()


## Wer gross oben steht: der gewaehlte DROME, wenn er im Squad ist, sonst der
## zuletzt gross gezeigte, sonst der erste im Squad. -1 bei leerem Squad.
func _primary_index() -> int:
	for candidate in [_selected, _primary]:
		if candidate >= 0 and candidate < _entries().size() and _entries()[candidate].in_squad:
			_primary = candidate
			return candidate
	for i in _entries().size():
		if _entries()[i].in_squad:
			_primary = i
			return i
	_primary = -1
	return -1


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


## Eine Kachel: nur das Bild des DROME, so wie er gerade gebaut ist.
## Gruener Rand: im Squad. Antippen waehlt ihn (nochmal: abwaehlen).
func _drome_tile(index: int) -> Control:
	var entry: RosterEntry = _entries()[index]
	var panel := _tappable(_tile_style(index == _selected, entry.in_squad), func():
		_selected = -1 if index == _selected and not entry.in_squad else index
		_refresh())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.tooltip_text = entry.name
	var picture := UiKit.drome_view(GameState.roster.build_for(entry), TILE_EDGE)
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_child(picture)
	return panel


func _empty_tile() -> Control:
	var panel := PanelContainer.new()
	var style := _tile_style(false, false)
	style.bg_color = Color(0.07, 0.09, 0.13, 0.9)
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, TILE_EDGE + 12)
	var label := UiKit.label("frei", UiKit.SMALL, UiKit.MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


## Die grosse Box: Bild und Angaben des Hauptgewaehlten, dazu "Aus dem Squad".
func _primary_card(index: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.card_style(index >= 0))
	if index < 0:
		var empty := UiKit.label("Der Squad ist leer. Unten einen DROME antippen.",
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
	var out := UiKit.button("Aus dem Squad")
	out.add_theme_font_size_override("font_size", UiKit.SMALL)
	out.custom_minimum_size = Vector2(0, 44)
	out.pressed.connect(func():
		entry.in_squad = false
		if _selected == index:
			_selected = -1
		_changed())
	info.add_child(out)
	return panel


## Angaben zu einem DROME ausserhalb des Squads, mit "In den Squad".
func _roster_details(index: int) -> Control:
	var entry: RosterEntry = _entries()[index]
	var build := GameState.roster.build_for(entry)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.card_style(true))
	var info := _drome_info(entry, build)
	panel.add_child(info)
	if GameState.roster.squad_count() >= _squad_max():
		info.add_child(UiKit.label("Squad voll -- erst oben einen herausnehmen.",
			UiKit.SMALL, UiKit.WARN))
	else:
		var join := UiKit.button("In den Squad", true)
		join.pressed.connect(func():
			entry.in_squad = true
			_primary = index
			_changed())
		info.add_child(join)
	return panel


## Name, Kampfwert, Werte und Ausruestung -- fuer die grosse Box und die Angaben.
func _drome_info(entry: RosterEntry, build: DromeBuild) -> VBoxContainer:
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	info.add_child(UiKit.label(entry.name, UiKit.H2))
	info.add_child(UiKit.label("Kampfwert %d" % int(build.power_score()), UiKit.SMALL,
		UiKit.ACCENT))
	var stats := build.stats()
	info.add_child(UiKit.label("Integritaet %d · Schild %d · SPD %d" % [stats["hp_max"],
		stats.get("shield_max", 0), stats["spd"]], UiKit.SMALL, UiKit.MUTED))
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
	info.add_child(UiKit.row("Integritaet", str(stats["hp_max"])))
	info.add_child(UiKit.row("Schild", str(stats.get("shield_max", 0))))
	info.add_child(UiKit.row("SPD", str(stats["spd"])))
	info.add_child(UiKit.row("Kampfwert", str(int(build.power_score())), UiKit.ACCENT))

	# Ohne Kern-Halter (6g) ist der erste Ausruestungshalter vorgewaehlt.
	var equip := build.equip_slots()
	if not equip.is_empty() and _selected_slot not in equip:
		_selected_slot = equip[0]
	_content.add_child(_slots(build))
	_content.add_child(_slot_info(entry, build))
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
	var order: Array = []
	for i in _entries().size():
		if _entries()[i].in_squad:
			order.append(i)
	for i in _entries().size():
		if not _entries()[i].in_squad:
			order.append(i)
	for index in order:
		var entry: RosterEntry = _entries()[index]
		var panel := _tappable(UiKit.card_style(index == _selected), func():
			_selected = index
			_selected_slot = ""
			_preview_part = null
			_refresh())
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(box)
		box.add_child(UiKit.drome_view(GameState.roster.build_for(entry), 56))
		var label := _quiet(UiKit.label(entry.name, UiKit.SMALL,
			Color.WHITE if entry.in_squad else UiKit.MUTED))
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
		row.add_child(panel)
	return scroll


## Die Halter als Formen: die Ausruestungshalter in ihrer Klassenform (den
## Kern-Halter gibt es seit 6g nicht mehr); darin das Teil oder leer. Der gewaehlte Halter steht in
## einem hervorgehobenen Kasten; unter jedem Halter seine Klasse.
func _slots(build: DromeBuild) -> Control:
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
			_preview_part = null
			_slot_details = false
			_refresh())
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


## Was im gewaehlten Halter steckt, was er nimmt, und "Leeren".
func _slot_info(entry: RosterEntry, build: DromeBuild) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.card_style(true))
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	card.add_child(outer)
	var kind := "core" if _selected_slot == "core" \
		else SlotRules.slot_class(build.body(), _selected_slot)
	# Kopf: welcher Halter, gross -- und seine Klasse als Form und Wort.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	outer.add_child(head)
	var mark := SlotShape.new(kind, null, 36)
	mark.highlight = true
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(mark)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(UiKit.label("Halter " + SlotRules.slot_label(_selected_slot)
		if _selected_slot != "core" else "Kern-Halter", UiKit.H2))
	var takes := ""
	if _selected_slot == "core":
		takes = "nimmt einen Kern"
	else:
		var fit: String = {"light": "nur leichte Teile", "medium": "leichte und mittlere Teile",
			"heavy": "leichte, mittlere und schwere Teile"}.get(kind, "")
		takes = "%s  ·  nimmt %s" % [_class_name(kind).to_upper(), fit]
		var rule: Dictionary = build.body().slot_rules.get(_selected_slot, {})
		var only = rule.get("categories")
		if only is Array and not only.is_empty():
			var names: Array[String] = []
			for category in only:
				names.append(SlotRules.category_label(str(category)))
			takes += ", nur " + ", ".join(names)
	titles.add_child(UiKit.label(takes, UiKit.SMALL, _class_color(kind)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	outer.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var part := build.part_in(_selected_slot)
	text.add_child(UiKit.label("Darin: " + (part.display_name if part != null else "frei"),
		UiKit.BODY, Color.WHITE if part != null else UiKit.MUTED))
	if part != null:
		# Wie funktioniert das Teil? Aufklappbar, damit der Halter kurz bleibt.
		var more := UiKit.button("Weniger" if _slot_details else "Wie funktioniert das?")
		more.custom_minimum_size = Vector2(0, 40)
		more.add_theme_font_size_override("font_size", UiKit.SMALL)
		more.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		# Ohne Breite bricht ein Knopf mit Umbruch zeichenweise um.
		more.autowrap_mode = TextServer.AUTOWRAP_OFF
		more.pressed.connect(func():
			_slot_details = not _slot_details
			_refresh())
		text.add_child(more)
		if _slot_details:
			var details := VBoxContainer.new()
			details.add_theme_constant_override("separation", 2)
			outer.add_child(details)
			PartInfo.build(part, details)
		var clear := UiKit.button("Leeren")
		clear.size_flags_horizontal = Control.SIZE_SHRINK_END
		clear.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		clear.custom_minimum_size = Vector2(110, 48)
		clear.pressed.connect(func():
			GameState.roster.clear_slot(entry, _selected_slot)
			_preview_part = null
			_changed())
		row.add_child(clear)
	return card


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
	if _preview_part != null:
		for item in items:
			if item[0] == _preview_part:
				_content.add_child(_part_details(entry, build, item[0], item[1]))
	if fits.is_empty():
		_content.add_child(UiKit.label("Nichts Passendes frei.", UiKit.SMALL, UiKit.MUTED))
	var tiles: Array = []
	for item in items:
		tiles.append(_part_tile(item[0], item[1]))
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
## eingebaut werden kann. Nochmal antippen schliesst die Angaben.
func _part_tile(part: PartData, verdict: String) -> Control:
	var open := _preview_part == part
	var panel := _tappable(_tile_style(open, false), func():
		_preview_part = null if open else part
		_refresh())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.tooltip_text = part.display_name
	var kind := "core" if part.type == PartData.Type.CORE else part.mount_class
	var shape := SlotShape.new(kind, UiKit.part_texture(part), PART_EDGE)
	shape.dim = verdict != ""
	shape.highlight = open
	shape.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	shape.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(shape)
	if verdict != "":
		panel.modulate = Color(1, 1, 1, 0.55)
	return panel


## Alle Angaben zum angetippten Teil: Name, Klasse, Bestand, Grund, die ganze
## Erklaerung, die Wertaenderung und der Knopf.
func _part_details(entry: RosterEntry, build: DromeBuild, part: PartData,
		verdict: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.card_style(true))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var kind := "core" if part.type == PartData.Type.CORE else part.mount_class
	row.add_child(SlotShape.new(kind, UiKit.part_texture(part), PART_EDGE))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UiKit.label(part.display_name, UiKit.BODY))
	var sub := ""
	if part.type == PartData.Type.EQUIPMENT:
		sub = "%s · %s" % [SlotRules.class_label(part.mount_class),
			SlotRules.category_label(part.category)]
	else:
		sub = "Kern"
	sub += "  ·  %d frei" % GameState.roster.free_count(part.id)
	text.add_child(UiKit.label(sub, UiKit.SMALL, UiKit.MUTED))
	if verdict != "":
		text.add_child(UiKit.label(verdict, UiKit.SMALL, UiKit.WARN))
	_preview(entry, build, part, verdict, box)
	return panel


## Was sich aendern wuerde -- und der Knopf dazu.
func _preview(entry: RosterEntry, build: DromeBuild, part: PartData, verdict: String,
		box: VBoxContainer) -> void:
	var replaced := build.part_in(_selected_slot)
	if replaced != null and replaced.id != part.id:
		box.add_child(_quiet(UiKit.label("ersetzt %s (kommt zurueck ins Inventar)"
			% replaced.display_name, UiKit.SMALL, UiKit.WARN)))
	# Die ganze Erklaerung des Teils -- Rolle, Werte, Aktionen.
	PartInfo.build(part, box)
	box.add_child(_quiet(UiKit.label("Im Aufbau:", UiKit.SMALL, UiKit.HEADING)))
	var trial := build.clone()
	trial.slots[_selected_slot] = part.id
	var before := build.stats()
	var after := trial.stats()
	var any := false
	for key in [["hp_max", "Integritaet"], ["shield_max", "Schild"], ["spd", "SPD"],
			["atk", "ATK"], ["def", "DEF"]]:
		var a: int = before.get(key[0], 0)
		var b: int = after.get(key[0], 0)
		if a == b:
			continue
		any = true
		box.add_child(_quiet(UiKit.row(key[1], "%d -> %d  (%+d)" % [a, b, b - a],
			UiKit.GOOD if b > a else UiKit.BAD)))
	if not any:
		box.add_child(_quiet(UiKit.label("keine Wertaenderung", UiKit.SMALL, UiKit.MUTED)))
	for line in trial.validate():
		box.add_child(_quiet(UiKit.label("danach: " + line, UiKit.SMALL, UiKit.BAD)))
	if verdict == "":
		var install := UiKit.button("Einbauen in %s" % SlotRules.slot_label(_selected_slot), true)
		install.pressed.connect(func():
			if GameState.roster.assign(entry, _selected_slot, part.id):
				_preview_part = null
				_changed())
		box.add_child(install)


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
