extends Control

## Der Hangar: Squad und Umbau an EINER Stelle -- mobile first.
##
## Ersetzt Garage, Inventar und Werkstatt. Die drei Bildschirme zeigten
## dieselben Dinge (DROMEs, Teile, Halter) aus drei Blickwinkeln, und wer einen
## Blaster einbauen wollte, musste zwischen ihnen hin und her. Hier gibt es zwei
## Reiter:
##
##   Squad   oben das Karussell mit dem Squad (hoechstens vier), darunter alle
##           DROMEs -- ausgegraut, wer schon im Squad ist. Antippen holt einen
##           DROME in den Squad.
##   Umbau   oben die DROME-Auswahl, darunter seine Halter als Formen
##           (Dreieck leicht, Viereck mittel, Fuenfeck schwer, Kreis Kern) mit
##           dem, was drinsteckt, oder "frei". Ein Halter angetippt zeigt die
##           Teile, die hineinpassen -- jedes in seiner eigenen Form. Ein Teil
##           angetippt zeigt, was sich aendert, und "Einbauen".
##
## Regeln, Werte und Validierung kommen wie ueberall aus Roster, DromeBuild und
## PartData (SlotRules sagt sie in Worten). Der Hangar haelt nichts davon selbst.

const PORTRAIT := 150.0
const CAROUSEL_CARD := 190.0
const ROW_PORTRAIT := 72.0
const SLOT_EDGE := 64.0
const PART_EDGE := 56.0

## Welcher Reiter: "squad" oder "umbau". Ueberlebt einen Szenenwechsel ueber
## die Meta des GameState nicht -- muss es auch nicht: aus dem Kampf kommt man
## am besten im Squad an.
var _tab := "squad"
var _selected := -1
var _selected_slot := "core"
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
	_content = UiKit.page(self, "Hangar", "", 1)
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

	# Karussell: der Squad, waagrecht zum Wischen, freie Plaetze als Rahmen.
	var carousel := ScrollContainer.new()
	carousel.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	carousel.custom_minimum_size = Vector2(0, CAROUSEL_CARD + 70)
	_content.add_child(carousel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	carousel.add_child(row)
	var shown := 0
	for i in _entries().size():
		if _entries()[i].in_squad:
			row.add_child(_carousel_card(i))
			shown += 1
	for _i in maxi(0, _squad_max() - shown):
		row.add_child(_empty_card())

	if _selected >= 0 and _selected < _entries().size() and _entries()[_selected].in_squad:
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 8)
		var edit := UiKit.button("Umbauen", true)
		edit.pressed.connect(func(): _switch("umbau"))
		actions.add_child(edit)
		var out := UiKit.button("Aus dem Squad")
		var entry: RosterEntry = _entries()[_selected]
		out.pressed.connect(func():
			entry.in_squad = false
			_changed())
		actions.add_child(out)
		_content.add_child(actions)

	_content.add_child(UiKit.heading("Alle DROMEs"))
	_content.add_child(UiKit.label("Antippen holt einen DROME in den Squad. Ausgegraut: "
		+ "schon dabei.", UiKit.SMALL, UiKit.MUTED))
	for i in _entries().size():
		_content.add_child(_roster_row(i))

	_new_drome_section()


func _carousel_card(index: int) -> Control:
	var entry: RosterEntry = _entries()[index]
	var build := GameState.roster.build_for(entry)
	var panel := _tappable(UiKit.card_style(index == _selected), func():
		_selected = index
		_refresh())
	panel.custom_minimum_size = Vector2(CAROUSEL_CARD, 0)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var picture := UiKit.drome_view(build, CAROUSEL_CARD - 30)
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(picture)
	var name := UiKit.label(entry.name, UiKit.H2)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name)
	var power := UiKit.label("Kampfwert %d" % int(build.power_score()), UiKit.SMALL, UiKit.MUTED)
	power.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(power)
	return panel


func _empty_card() -> Control:
	var panel := PanelContainer.new()
	var style := UiKit.card_style()
	style.bg_color = Color(0.07, 0.09, 0.13)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(CAROUSEL_CARD, CAROUSEL_CARD + 50)
	var label := UiKit.label("frei\n\nunten einen DROME antippen", UiKit.SMALL, UiKit.MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


func _roster_row(index: int) -> Control:
	var entry: RosterEntry = _entries()[index]
	var build := GameState.roster.build_for(entry)
	var full := GameState.roster.squad_count() >= _squad_max()
	var panel := _tappable(UiKit.card_style(), func():
		if entry.in_squad:
			_selected = index
			_refresh()
			return
		if full:
			return
		entry.in_squad = true
		_selected = index
		_changed())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	row.add_child(UiKit.drome_view(build, ROW_PORTRAIT))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	text.add_child(_quiet(UiKit.label(entry.name, UiKit.BODY)))
	text.add_child(_quiet(UiKit.label(_loadout(build), UiKit.SMALL, UiKit.MUTED)))
	var state := "im Squad" if entry.in_squad else ("Squad voll" if full else "+ Squad")
	var tag := _quiet(UiKit.label(state, UiKit.SMALL,
		UiKit.MUTED if entry.in_squad or full else UiKit.ACCENT))
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tag)
	if entry.in_squad:
		panel.modulate = Color(1, 1, 1, 0.5)
	return panel


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
			_selected_slot = "core"
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


## Die Halter als Formen. Kern zuerst (Kreis), dann die Ausruestungshalter in
## ihrer Klassenform; darin das Teil oder leer.
func _slots(build: DromeBuild) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var chassis := build.body()
	var slots: Array = ["core"]
	slots.append_array(build.equip_slots())
	for slot in slots:
		var part := build.part_in(slot)
		var kind := "core" if slot == "core" else SlotRules.slot_class(chassis, slot)
		var holder := _tappable(null, func():
			_selected_slot = slot
			_preview_part = null
			_refresh())
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(box)
		var shape := SlotShape.new(kind, UiKit.part_texture(part), SLOT_EDGE)
		shape.highlight = slot == _selected_slot
		shape.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(shape)
		var label := _quiet(UiKit.label(SlotRules.slot_label(slot), UiKit.SMALL,
			Color.WHITE if slot == _selected_slot else UiKit.MUTED))
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
		row.add_child(holder)
	return row


## Was im gewaehlten Halter steckt, was er nimmt, und "Leeren".
func _slot_info(entry: RosterEntry, build: DromeBuild) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.card_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var part := build.part_in(_selected_slot)
	var title := SlotRules.slot_label(_selected_slot)
	if _selected_slot != "core":
		var limit := SlotRules.slot_class(build.body(), _selected_slot)
		title += "  ·  nimmt bis %s" % SlotRules.class_label(limit)
		var rule: Dictionary = build.body().slot_rules.get(_selected_slot, {})
		var only = rule.get("categories")
		if only is Array and not only.is_empty():
			var names: Array[String] = []
			for category in only:
				names.append(SlotRules.category_label(str(category)))
			title += ", nur " + ", ".join(names)
	text.add_child(UiKit.label(title, UiKit.SMALL, UiKit.MUTED))
	text.add_child(UiKit.label(part.display_name if part != null else "frei",
		UiKit.BODY, Color.WHITE if part != null else UiKit.MUTED))
	if part != null:
		var clear := UiKit.button("Leeren")
		clear.size_flags_horizontal = Control.SIZE_SHRINK_END
		clear.custom_minimum_size = Vector2(110, 48)
		clear.pressed.connect(func():
			GameState.roster.clear_slot(entry, _selected_slot)
			_preview_part = null
			_changed())
		row.add_child(clear)
	return card


## Die Teile fuer den gewaehlten Halter -- passende zuerst, dann die uebrigen
## gedaempft mit Grund. Eins angetippt klappt seine Vorschau auf.
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
	_content.add_child(UiKit.heading("Passt hier" if not fits.is_empty() else "Nichts Passendes frei"))
	for item in fits:
		_part_row(entry, build, item[0], "")
	if not rest.is_empty():
		_content.add_child(UiKit.label("Nicht verfuegbar", UiKit.SMALL, UiKit.MUTED))
		for item in rest:
			_part_row(entry, build, item[0], item[1])


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


func _part_row(entry: RosterEntry, build: DromeBuild, part: PartData, verdict: String) -> void:
	var open := _preview_part == part
	var panel := _tappable(UiKit.card_style(open), func():
		_preview_part = null if open else part
		_refresh())
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var kind := "core" if part.type == PartData.Type.CORE else part.mount_class
	var shape := SlotShape.new(kind, UiKit.part_texture(part), PART_EDGE)
	shape.dim = verdict != ""
	row.add_child(shape)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	text.add_child(_quiet(UiKit.label(part.display_name, UiKit.BODY,
		UiKit.MUTED if verdict != "" else Color.WHITE)))
	var sub := ""
	if part.type == PartData.Type.EQUIPMENT:
		sub = "%s · %s" % [SlotRules.class_label(part.mount_class),
			SlotRules.category_label(part.category)]
	else:
		sub = "Kern"
	sub += "  ·  %d frei" % GameState.roster.free_count(part.id)
	text.add_child(_quiet(UiKit.label(sub, UiKit.SMALL, UiKit.MUTED)))
	if verdict != "":
		text.add_child(_quiet(UiKit.label(verdict, UiKit.SMALL, UiKit.WARN)))
	_content.add_child(panel)

	if open:
		_preview(entry, build, part, verdict, box)


## Was sich aendern wuerde -- und der Knopf dazu.
func _preview(entry: RosterEntry, build: DromeBuild, part: PartData, verdict: String,
		box: VBoxContainer) -> void:
	var replaced := build.part_in(_selected_slot)
	if replaced != null and replaced.id != part.id:
		box.add_child(_quiet(UiKit.label("ersetzt %s (kommt zurueck ins Inventar)"
			% replaced.display_name, UiKit.SMALL, UiKit.WARN)))
	if part.actions.is_empty() and part.type == PartData.Type.EQUIPMENT:
		box.add_child(_quiet(UiKit.label("passiv -- keine eigene Aktion", UiKit.SMALL, UiKit.MUTED)))
	for action in part.actions:
		box.add_child(_quiet(UiKit.label("%s: %s" % [action.display_name, action.headline()],
			UiKit.SMALL)))
	var trial := build.clone()
	trial.slots[_selected_slot] = part.id
	var before := build.stats()
	var after := trial.stats()
	var any := false
	for key in [["hp_max", "Integritaet"], ["shield_max", "Schild"], ["spd", "SPD"],
			["mov", "MOV"], ["atk", "ATK"], ["def", "DEF"], ["en_max", "Energie"],
			["en_regen", "EN-Regen"]]:
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
