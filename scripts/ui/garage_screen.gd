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

const PREVIEW_SIZE := 120
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
var _new_button: Button
var _chassis_choices: VBoxContainer
## Die freien Chassis-Typen in der Reihenfolge des Menues -- damit die Auswahl
## den richtigen Typ trifft.
var _menu_chassis: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Zurueck aus der Werkstatt: keine Bearbeitung mehr offen.
	GameState.editing_index = -1
	_build_ui()
	_refresh_all()


## Mobile first: eine Liste ueber die volle Breite. Oben Squad-Stand und
## "Neuen DROME", darunter die DROMEs als Karten (Bild links, Text und
## Aktionen rechts), unten was frei im Inventar liegt.
func _build_ui() -> void:
	var content := UiKit.page(self, "Garage", "", 1)

	content.add_child(UiKit.label("Deine DROMEs. Anpassen baut sie um; der Haken "
		+ "entscheidet, wer im Chaos-Virus mitkommt.", UiKit.SMALL, UiKit.MUTED))

	_squad_label = UiKit.label("", UiKit.BODY)
	content.add_child(_squad_label)

	_new_button = UiKit.button("+ Neuen DROME aufbauen")
	_new_button.pressed.connect(_open_chassis_menu)
	content.add_child(_new_button)
	_chassis_choices = VBoxContainer.new()
	_chassis_choices.add_theme_constant_override("separation", 6)
	_chassis_choices.visible = false
	content.add_child(_chassis_choices)

	_cards = GridContainer.new()
	_cards.columns = 1
	_cards.add_theme_constant_override("v_separation", 10)
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_cards)

	var free_card := UiKit.card(content)
	free_card.add_child(UiKit.heading("Frei im Inventar"))
	_inventory_list = VBoxContainer.new()
	free_card.add_child(_inventory_list)


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


## Eine Karte je DROME: Bild links; rechts Name, Ausruestung, Squad-Haken und
## die zwei Aktionen. Fuer den Daumen gebaut: grosse Knoepfe, die ganze Breite.
func _drome_card(index: int) -> Control:
	var entry: RosterEntry = GameState.roster.entries[index]
	var build := GameState.roster.build_for(entry)
	var valid := build.is_valid()

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style(entry.in_squad))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	row.add_child(_drome_preview(build))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)

	box.add_child(UiKit.label(entry.name, UiKit.H2))
	box.add_child(UiKit.label(_loadout_summary(build), UiKit.SMALL, UiKit.MUTED))
	if not valid:
		box.add_child(UiKit.label("Achtung: " + build.validate()[0], UiKit.SMALL, UiKit.BAD))

	var squad_check := CheckBox.new()
	squad_check.text = "Im Squad"
	squad_check.custom_minimum_size = Vector2(0, 44)
	squad_check.add_theme_font_size_override("font_size", UiKit.BODY)
	squad_check.button_pressed = entry.in_squad
	squad_check.toggled.connect(func(pressed): _toggle_squad(entry, pressed))
	box.add_child(squad_check)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	var edit := UiKit.button("Anpassen", true)
	edit.add_theme_font_size_override("font_size", UiKit.BODY)
	edit.pressed.connect(func(): _edit_drome(index))
	actions.add_child(edit)
	var scrap := UiKit.button("Aufloesen")
	scrap.tooltip_text = "DROME aufloesen -- seine Teile kehren ins Inventar zurueck"
	scrap.pressed.connect(func(): _disband(entry))
	actions.add_child(scrap)
	box.add_child(actions)
	return panel


func _card_style(in_squad: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.17)
	style.border_color = COLOR_GOOD if in_squad else Color(0.24, 0.28, 0.35)
	style.set_border_width_all(2 if in_squad else 1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	return style


## Die Miniatur eines DROME -- dieselbe Zusammensetzung wie die grosse Vorschau
## und der Kampf (DromeSprites.assemble), damit die Karte den Bot zeigt, den man
## meint.
func _drome_preview(build: DromeBuild) -> Control:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(PREVIEW_SIZE, PREVIEW_SIZE)
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER

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
		_inventory_list.add_child(UiKit.label(group[1], UiKit.SMALL, UiKit.MUTED))
		for line in lines:
			_inventory_list.add_child(UiKit.label("  " + line, UiKit.BODY))

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


## Die freien Chassis als Knopfliste direkt unter "Neuen DROME" -- ein
## Popup-Menue am Zeiger ist auf dem Handy winzig und landet unter dem Daumen.
func _open_chassis_menu() -> void:
	if _chassis_choices.visible:
		_chassis_choices.visible = false
		return
	_menu_chassis = GameState.roster.free_chassis_types()
	if _menu_chassis.is_empty():
		return
	for child in _chassis_choices.get_children():
		child.queue_free()
	_chassis_choices.add_child(UiKit.label("Welches Chassis?", UiKit.SMALL, UiKit.MUTED))
	for i in _menu_chassis.size():
		var part := PartDB.get_part(_menu_chassis[i])
		var choice := UiKit.button(part.display_name if part != null else str(_menu_chassis[i]))
		var id := i
		choice.pressed.connect(func(): _on_chassis_chosen(id))
		_chassis_choices.add_child(choice)
	_chassis_choices.visible = true


func _on_chassis_chosen(id: int) -> void:
	if id < 0 or id >= _menu_chassis.size():
		return
	var entry := GameState.roster.new_drome(_menu_chassis[id])
	if entry == null:
		return
	GameState.editing_index = GameState.roster.entries.size() - 1
	GameState.save_roster()
	get_tree().change_scene_to_file("res://scenes/workshop.tscn")
