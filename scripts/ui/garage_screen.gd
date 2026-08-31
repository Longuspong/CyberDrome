extends Control

## Die Garage: das Botmenue und die Auswahl vor der Werkstatt (§10b/§10g).
##
## Hier stehen die BESESSENEN DROMEs -- nicht der freie Katalog. Die Garage ist
## damit genau das, was §10g fordert: "Das Auswahlmenue vor der Werkstatt IST die
## Roster-Liste." Von hier aus
##
##     * waehlt man den DROME, den man in der Werkstatt anpasst,
##     * hakt an, welche vier mitgenommen werden (den Rest laesst man zuhause),
##     * baut aus freier Chassis-Beute einen neuen DROME oder loest einen auf,
##     * und startet den Chaos-Virus mit dem gewaehlten Squad.
##
## Die Werte, die Grafik und die Validierung kommen wie ueberall aus dem
## abgeleiteten DromeBuild (Roster.build_for) -- die Garage haelt nichts davon
## selbst, sie zeigt nur den Besitz.

const PREVIEW_SIZE := 150
const PREVIEW_SCALE := 1.0
const GROUND_FRACTION := 0.72
const CARD_WIDTH := 250
const CARD_COLUMNS := 3

const COLOR_GOOD := Color(0.42, 0.85, 0.48)
const COLOR_BAD := Color(1.0, 0.42, 0.42)
const COLOR_HEADING := Color(0.6, 0.8, 0.95)
const COLOR_MUTED := Color(0.62, 0.66, 0.72)

var _cards: GridContainer
var _inventory_list: VBoxContainer
var _squad_label: Label
var _start_button: Button
var _new_button: Button
var _seed_field: LineEdit
var _chassis_menu: PopupMenu
## Die freien Chassis-Typen in der Reihenfolge des Menues -- damit die Auswahl
## den richtigen Typ trifft.
var _menu_chassis: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Zurueck aus der Werkstatt: keine Bearbeitung mehr offen.
	GameState.editing_index = -1
	_build_ui()
	_refresh_all()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	margin.add_child(columns)

	columns.add_child(_build_roster_column())
	columns.add_child(_build_side_column())

	_chassis_menu = PopupMenu.new()
	_chassis_menu.id_pressed.connect(_on_chassis_chosen)
	add_child(_chassis_menu)


func _build_roster_column() -> Control:
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = "GARAGE"
	title.add_theme_font_size_override("font_size", 26)
	title.modulate = COLOR_HEADING
	left.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Deine DROMEs. Waehle einen zum Anpassen, hake an, wer mitkommt."
	subtitle.modulate = COLOR_MUTED
	left.add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)

	_cards = GridContainer.new()
	_cards.columns = CARD_COLUMNS
	_cards.add_theme_constant_override("h_separation", 12)
	_cards.add_theme_constant_override("v_separation", 12)
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cards)
	return left


func _build_side_column() -> Control:
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	right.add_theme_constant_override("separation", 8)

	var back := Button.new()
	back.text = "< Hauptmenue"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	right.add_child(back)

	_squad_label = Label.new()
	_squad_label.add_theme_font_size_override("font_size", 14)
	right.add_child(_squad_label)

	_new_button = Button.new()
	_new_button.text = "+ Neuen DROME aufbauen"
	_new_button.custom_minimum_size = Vector2(0, 40)
	_new_button.pressed.connect(_open_chassis_menu)
	right.add_child(_new_button)

	right.add_child(_section_heading("Inventar — frei"))
	var inv_scroll := ScrollContainer.new()
	inv_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inv_scroll.custom_minimum_size = Vector2(300, 0)
	right.add_child(inv_scroll)
	_inventory_list = VBoxContainer.new()
	_inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_scroll.add_child(_inventory_list)

	var seed_row := HBoxContainer.new()
	var seed_label := Label.new()
	seed_label.text = "Seed: "
	seed_row.add_child(seed_label)
	_seed_field = LineEdit.new()
	_seed_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_field.placeholder_text = "leer = zufaellig"
	if GameState.battle_seed != 0:
		_seed_field.text = str(GameState.battle_seed)
	seed_row.add_child(_seed_field)
	right.add_child(seed_row)

	_start_button = Button.new()
	_start_button.text = "Chaos-Virus starten"
	_start_button.custom_minimum_size = Vector2(0, 48)
	_start_button.pressed.connect(_start_battle)
	right.add_child(_start_button)
	return right


func _section_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = COLOR_HEADING
	return label


# ---------------------------------------------------------------------------
# Anzeige
# ---------------------------------------------------------------------------

func _refresh_all() -> void:
	_refresh_cards()
	_refresh_inventory()
	_refresh_squad_state()


func _refresh_cards() -> void:
	for child in _cards.get_children():
		child.queue_free()
	for i in GameState.roster.entries.size():
		_cards.add_child(_drome_card(i))


## Eine Karte je DROME: Vorschau, Name, Squad-Haken und die zwei Aktionen.
func _drome_card(index: int) -> Control:
	var entry: RosterEntry = GameState.roster.entries[index]
	var build := GameState.roster.build_for(entry)
	var valid := build.is_valid()

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style(entry.in_squad))
	panel.custom_minimum_size = Vector2(CARD_WIDTH, 0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var name_label := Label.new()
	name_label.text = entry.name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(name_label)

	box.add_child(_drome_preview(build))

	# Was der DROME traegt -- eine knappe Zeile, damit man die Karten
	# auseinanderhaelt, ohne jede in die Werkstatt zu oeffnen.
	var loadout := Label.new()
	loadout.text = _loadout_summary(build)
	loadout.add_theme_font_size_override("font_size", 10)
	loadout.modulate = COLOR_MUTED
	loadout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loadout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loadout.custom_minimum_size = Vector2(0, 28)
	box.add_child(loadout)

	if not valid:
		var warn := Label.new()
		warn.text = "⚠ " + build.validate()[0]
		warn.add_theme_font_size_override("font_size", 10)
		warn.modulate = COLOR_BAD
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(warn)

	var squad_check := CheckBox.new()
	squad_check.text = "Im Squad"
	squad_check.button_pressed = entry.in_squad
	squad_check.toggled.connect(func(pressed): _toggle_squad(entry, pressed))
	box.add_child(squad_check)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	var edit := Button.new()
	edit.text = "Anpassen"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.pressed.connect(func(): _edit_drome(index))
	actions.add_child(edit)
	var scrap := Button.new()
	scrap.text = "Aufloesen"
	scrap.tooltip_text = "DROME aufloesen — seine Teile kehren ins Inventar zurueck"
	scrap.pressed.connect(func(): _disband(entry))
	actions.add_child(scrap)
	box.add_child(actions)
	return panel


func _card_style(in_squad: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.17)
	style.border_color = COLOR_GOOD if in_squad else Color(0.24, 0.28, 0.35)
	style.set_border_width_all(2 if in_squad else 1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


## Die Miniatur eines DROME -- dieselbe Zusammensetzung wie die grosse Vorschau
## und der Kampf (DromeSprites.assemble), damit die Karte den Bot zeigt, den man
## meint.
func _drome_preview(build: DromeBuild) -> Control:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(PREVIEW_SIZE, PREVIEW_SIZE)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var sub := SubViewport.new()
	sub.size = Vector2i(PREVIEW_SIZE, PREVIEW_SIZE)
	sub.transparent_bg = true
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(sub)

	var root := Node2D.new()
	root.position = Vector2(
		PREVIEW_SIZE * 0.5 - IsoView.SPRITE_ORIGIN.x * PREVIEW_SCALE,
		PREVIEW_SIZE * GROUND_FRACTION - IsoView.SPRITE_ORIGIN.y * PREVIEW_SCALE)
	root.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
	sub.add_child(root)

	DromeSprites.assemble(root, build, "south")
	return container


## Kern + Ausruestung in einer Zeile. Das Chassis steht nicht dabei -- es ist im
## Bild und ohnehin die Identitaet des DROME.
func _loadout_summary(build: DromeBuild) -> String:
	var names: Array[String] = []
	var core := build.part_in("core")
	if core != null:
		names.append(core.display_name)
	for part in build.equipment():
		names.append(part.display_name)
	return ", ".join(names) if not names.is_empty() else "nur Rahmen"


func _refresh_inventory() -> void:
	for child in _inventory_list.get_children():
		child.queue_free()

	var any := false
	for group in [[PartData.Type.BODY, "Chassis"], [PartData.Type.CORE, "Kern"],
			[PartData.Type.EQUIPMENT, "Ausruestung"]]:
		var lines: Array[String] = []
		for part_id in GameState.roster.owned_part_ids(group[0]):
			var free := GameState.roster.free_count(part_id)
			if free <= 0:
				continue
			var part := PartDB.get_part(part_id)
			var label := part.display_name if part != null else str(part_id)
			lines.append("%s ×%d" % [label, free] if free > 1 else label)
		if lines.is_empty():
			continue
		any = true
		var head := Label.new()
		head.text = group[1]
		head.add_theme_font_size_override("font_size", 11)
		head.modulate = COLOR_MUTED
		_inventory_list.add_child(head)
		for line in lines:
			var row := Label.new()
			row.text = "  " + line
			row.add_theme_font_size_override("font_size", 12)
			_inventory_list.add_child(row)

	if not any:
		var empty := Label.new()
		empty.text = "Alles verbaut."
		empty.modulate = COLOR_MUTED
		_inventory_list.add_child(empty)


func _refresh_squad_state() -> void:
	var count := GameState.roster.squad_count()
	var maximum := Config.get_int("squad_size_max", 4)
	_squad_label.text = "Squad: %d / %d" % [count, maximum]
	_squad_label.modulate = COLOR_GOOD if GameState.squad_is_valid() else COLOR_BAD

	_new_button.disabled = GameState.roster.free_chassis_types().is_empty()
	_new_button.tooltip_text = "" if not _new_button.disabled \
		else "Kein freies Chassis. Loese einen DROME auf oder erbeute ein neues."

	_start_button.disabled = not GameState.squad_is_valid()
	_start_button.text = "Chaos-Virus starten" if GameState.squad_is_valid() \
		else "Squad unvollstaendig"


# ---------------------------------------------------------------------------
# Aktionen
# ---------------------------------------------------------------------------

## Die Squad-Auswahl ist auf ``squad_size_max`` gedeckelt (§10b): man nimmt vier
## mit, nicht das ganze Roster. Ueber dem Deckel schnappt der Haken zurueck.
func _toggle_squad(entry: RosterEntry, pressed: bool) -> void:
	if pressed and GameState.roster.squad_count() >= Config.get_int("squad_size_max", 4):
		_refresh_all()
		return
	entry.in_squad = pressed
	GameState.save_roster()
	_refresh_all()


func _edit_drome(index: int) -> void:
	GameState.editing_index = index
	GameState.save_roster()
	get_tree().change_scene_to_file("res://scenes/workshop.tscn")


func _disband(entry: RosterEntry) -> void:
	GameState.roster.disband(entry)
	GameState.save_roster()
	_refresh_all()


func _open_chassis_menu() -> void:
	_menu_chassis = GameState.roster.free_chassis_types()
	if _menu_chassis.is_empty():
		return
	_chassis_menu.clear()
	for i in _menu_chassis.size():
		var part := PartDB.get_part(_menu_chassis[i])
		_chassis_menu.add_item(part.display_name if part != null
			else str(_menu_chassis[i]), i)
	_chassis_menu.position = get_viewport().get_mouse_position() \
		+ Vector2(get_window().position)
	_chassis_menu.reset_size()
	_chassis_menu.popup()


func _on_chassis_chosen(id: int) -> void:
	if id < 0 or id >= _menu_chassis.size():
		return
	var entry := GameState.roster.new_drome(_menu_chassis[id])
	if entry == null:
		return
	GameState.editing_index = GameState.roster.entries.size() - 1
	GameState.save_roster()
	get_tree().change_scene_to_file("res://scenes/workshop.tscn")


func _start_battle() -> void:
	if not GameState.squad_is_valid():
		return
	GameState.save_roster()
	var text := _seed_field.text.strip_edges()
	GameState.battle_seed = int(text) if text.is_valid_int() else 0
	if GameState.battle_seed == 0:
		GameState.new_seed()
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
