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
##   Umbau   oben FEST (scrollt nicht mit): die DROME-Auswahl und die Karte
##           des gewaehlten DROME -- sein Bild, darunter seine Halter als
##           Formen (Dreieck leicht, Viereck mittel, Fuenfeck schwer), rechts
##           die Werte. Darunter eine Leiste mit den Teilen, die frei sind
##           und in diesen DROME passen (nichts Ausgegrautes). Eine Kachel
##           nach oben auf einen Halter ziehen baut ein; antippen (Kachel
##           oder Halter) oeffnet die Waffen-Karte (WeaponCard) mit Symbolen,
##           Vergleichsbalken und "Einbauen" bzw. "Ausbauen".
##
## Regeln, Werte und Validierung kommen wie ueberall aus Roster, DromeBuild und
## PartData (SlotRules sagt sie in Worten). Der Hangar haelt nichts davon selbst.

const PORTRAIT := 124.0
const PRIMARY_EDGE := 140.0
const TILE_EDGE := 104.0
const TILE_COLUMNS := 3
const TILE_GAP := 10
const SLOT_EDGE := 60.0
const PART_EDGE := 92.0
## Kantenlaenge einer Teil-Kachel in der Leiste des Umbaus.
const STRIP_TILE := 104.0

## Welcher Reiter: "squad" oder "umbau". Ueberlebt einen Szenenwechsel ueber
## die Meta des GameState nicht -- muss es auch nicht: aus dem Kampf kommt man
## am besten im Squad an.
var _tab := "squad"
var _selected := -1
var _selected_slot := ""

var _content: VBoxContainer
## Der feste Bereich ueber dem scrollbaren Inhalt (nur im Umbau gefuellt).
var _fixed: VBoxContainer
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
	# Darunter ein Bereich, der nicht mitscrollt: im Umbau stehen dort die
	# DROME-Auswahl und der DROME mit seinen Haltern. Wer ein Teil nach oben
	# auf einen Halter zieht, verschiebt so nicht mehr die ganze Seite.
	var fixed_holder := MarginContainer.new()
	for side in ["left", "right"]:
		fixed_holder.add_theme_constant_override("margin_" + side, UiKit.PAD)
	fixed_holder.add_theme_constant_override("margin_top", 8)
	_fixed = VBoxContainer.new()
	_fixed.add_theme_constant_override("separation", 8)
	fixed_holder.add_child(_fixed)
	frame.add_child(fixed_holder)
	frame.move_child(fixed_holder, 2)
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
	for child in _fixed.get_children():
		child.queue_free()
	(_fixed.get_parent() as Control).visible = _tab == "umbau"
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

	_new_drome_section()


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
	# Ohne Kern-Halter (6g) ist der erste Ausruestungshalter vorgewaehlt.
	var equip := build.equip_slots()
	if not equip.is_empty() and _selected_slot not in equip:
		_selected_slot = equip[0]

	# --- fest: Auswahl und der DROME mit seinen Haltern --------------------
	_fixed.add_child(_picker())

	# Bild und Halter links, die Werte rechts -- in einer Karte, sonst laufen
	# die Streifen der Kulisse durch die Zahlen. Die Halter stehen direkt
	# unter dem Bild (10. Nov. 2026, Wunsch des Spielers): vorher lagen sie
	# zwischen DROME und Teilen und schoben die Teile nach unten.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var card := UiKit.card(_fixed)
	(card.get_parent() as PanelContainer).add_theme_stylebox_override("panel", _head_style())
	card.add_child(head)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	head.add_child(left)
	var portrait := UiKit.drome_view(build, PORTRAIT)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(portrait)
	left.add_child(_slots(entry, build))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	head.add_child(info)
	var name_field := LineEdit.new()
	name_field.text = entry.name
	name_field.custom_minimum_size = Vector2(0, 40)
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

	# --- darunter: was sich einbauen laesst --------------------------------
	_parts_strip(entry, build)

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


## Die Karte des DROME im Umbau: etwas knapperer Innenabstand, damit oben
## nicht mehr Platz verloren geht als noetig.
func _head_style() -> StyleBoxFlat:
	var style := UiKit.card_style(false)
	style.set_content_margin_all(10)
	return style


## Die DROME-Auswahl oben: der Squad zuerst, dann der Rest.
func _picker() -> Control:
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 96)
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
		# Ziehen (10. Nov. 2026): eine Teil-Kachel auf den Halter fallen lassen.
		holder.set_drag_forwarding(Callable(),
			func(_at, data): return _can_drop_part(entry, build, slot, data),
			func(_at, data): _drop_part(entry, slot, data))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(box)
		var shape := SlotShape.new(kind, UiKit.part_texture(part), SLOT_EDGE)
		shape.highlight = chosen
		shape.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(shape)
		# Unter dem Halter steht nur seine Klasse -- keine Richtung mehr
		# (links, rechts): sie sagte nichts, was man nicht sieht.
		if kind == "core":
			var label := _quiet(UiKit.label(SlotRules.slot_label(slot), UiKit.SMALL,
				Color.WHITE if chosen else UiKit.MUTED))
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(label)
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


## Die Halter dieses DROME, die ``part`` aufnehmen wuerden: frei im Hangar,
## passend zur Klasse, nicht schon dasselbe Teil darin, und der Aufbau bleibt
## gueltig.
func _slots_taking(build: DromeBuild, part: PartData) -> Array:
	var out: Array = []
	if part == null or GameState.roster.free_count(part.id) <= 0:
		return out
	for slot in build.equip_slots():
		if _can_drop_part(null, build, slot, {"kind": "part", "part_id": part.id}):
			out.append(slot)
	return out


## Der Halter, in den ein angetipptes Teil kaeme: der gewaehlte, wenn er es
## nimmt, sonst der erste, der es nimmt. "" = keiner.
func _target_slot(build: DromeBuild, part: PartData) -> String:
	var taking := _slots_taking(build, part)
	if taking.is_empty():
		return ""
	return _selected_slot if _selected_slot in taking else str(taking[0])


## Die Teile, die sich in diesen DROME einbauen lassen, als Leiste -- nur was
## frei ist UND passt, nichts Ausgegrautes (Wunsch des Spielers, 10. Nov.
## 2026). Die Leiste laeuft waagerecht: wischen blaettert, eine Kachel nach
## oben ziehen legt sie auf einen Halter.
func _parts_strip(entry: RosterEntry, build: DromeBuild) -> void:
	var parts: Array = []
	for part_id in GameState.roster.owned_part_ids(PartData.Type.EQUIPMENT):
		var part := PartDB.get_part(part_id)
		if part != null and not _slots_taking(build, part).is_empty():
			parts.append(part)
	if parts.is_empty():
		_content.add_child(UiKit.label("Kein freies Teil passt in diesen DROME.",
			UiKit.SMALL, UiKit.MUTED))
		return
	_content.add_child(UiKit.label("Frei und passend -- antippen oder hochziehen",
		UiKit.SMALL, UiKit.MUTED))
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, STRIP_TILE + 8.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", TILE_GAP)
	scroll.add_child(row)
	for part in parts:
		row.add_child(_part_tile(entry, build, part))
	_content.add_child(scroll)


## Darf ein gezogenes Teil auf diesen Halter? Dieselbe Pruefung wie beim
## Einbauen ueber die Karte.
func _can_drop_part(entry: RosterEntry, build: DromeBuild, slot: String, data) -> bool:
	if not data is Dictionary or data.get("kind", "") != "part":
		return false
	var part := PartDB.get_part(data.get("part_id", &""))
	if part == null or not build.body().accepts(part, slot):
		return false
	var current := build.part_in(slot)
	if current != null and current.id == part.id:
		return false
	if GameState.roster.free_count(part.id) <= 0:
		return false
	var trial := build.clone()
	trial.slots[slot] = part.id
	return trial.is_valid()


func _drop_part(entry: RosterEntry, slot: String, data) -> void:
	if GameState.roster.assign(entry, slot, StringName(data.get("part_id", ""))):
		Accessibility.vibrate(20, true)
		_selected_slot = slot
		_changed()


## Eine Teil-Kachel: die Form mit dem Bild, darunter wie viele frei sind.
## Antippen oeffnet die Waffen-Karte; nach oben (oder unten) ziehen nimmt das
## Teil mit auf einen Halter. Waagerecht blaettert die Leiste.
func _part_tile(entry: RosterEntry, build: DromeBuild, part: PartData) -> Control:
	var panel := _tappable(_tile_style(false, false), func():
		_open_card(entry, build, part, ""))
	panel.custom_minimum_size = Vector2(STRIP_TILE, STRIP_TILE)
	panel.tooltip_text = part.display_name
	var start := {"at": Vector2.ZERO}
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			start["at"] = event.global_position)
	panel.set_drag_forwarding(func(_at):
		var moved: Vector2 = panel.get_global_mouse_position() - start["at"]
		if absf(moved.x) > absf(moved.y):
			return null
		var preview := SlotShape.new(part.mount_class, UiKit.part_texture(part), PART_EDGE)
		preview.modulate = Color(1, 1, 1, 0.85)
		panel.set_drag_preview(preview)
		return {"kind": "part", "part_id": part.id},
		Callable(), Callable())
	var shape := SlotShape.new(part.mount_class, UiKit.part_texture(part), PART_EDGE)
	shape.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	shape.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(shape)
	return panel


## Die Waffen-Karte. ``installed_in``: der Halter, in dem sie steckt (dann
## "Ausbauen"); leer = eine Kachel aus dem Bestand (dann "Einbauen" in den
## gewaehlten Halter oder den ersten, der sie nimmt -- mit Vergleich gegen
## die Waffe, die dort steckt, und der Wertaenderung am DROME).
func _open_card(entry: RosterEntry, build: DromeBuild, part: PartData,
		installed_in: String) -> void:
	if installed_in != "":
		WeaponCard.open(self, part, Callable(), [{"text": "Ausbauen", "on": func():
			GameState.roster.clear_slot(entry, installed_in)
			_changed()}])
		return
	var slot := _target_slot(build, part)
	var replaced := build.part_in(slot) if slot != "" else null
	var extra := func(box: VBoxContainer):
		box.add_child(HSeparator.new())
		if slot == "":
			box.add_child(UiKit.label("Passt gerade in keinen Halter.", UiKit.SMALL, UiKit.WARN))
			return
		var where := SlotRules.holder_label(build, slot)
		if replaced != null:
			box.add_child(UiKit.label("%s: ersetzt %s (zurueck in den Hangar)"
				% [where, replaced.display_name], UiKit.SMALL, UiKit.WARN))
		else:
			box.add_child(UiKit.label("%s ist frei  ·  %d frei im Hangar"
				% [where, GameState.roster.free_count(part.id)], UiKit.SMALL, UiKit.MUTED))
		_delta_lines(build, slot, part, box)
	WeaponCard.open(self, part, extra, [{"text": "Einbauen", "primary": true,
		"disabled": slot == "", "on": func():
			if GameState.roster.assign(entry, slot, part.id):
				Accessibility.vibrate(20, true)
				_selected_slot = slot
				_changed()}], replaced)


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
