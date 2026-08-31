extends Control

## Die Werkstatt in Godot -- der Loadout-Builder fuer GENAU EINEN DROME.
##
## Seit §10g ist die Werkstatt instanzbasiert: sie passt einen einzelnen
## Roster-Eintrag an, den die Garage ausgewaehlt hat. Sie baut Kern und
## Ausruestung aus dem eigenen INVENTAR ein -- nicht mehr aus einem freien
## Katalog. Eine Instanz steckt in hoechstens einem DROME; die Bibliothek bietet
## darum nur FREIE Exemplare an (plus das gerade verbaute).
##
## Das Chassis ist die Identitaet des DROME und wird hier NICHT getauscht: ein
## anderes Chassis ist ein anderer DROME (§10g). Wer das Chassis wechseln will,
## baut in der Garage einen neuen DROME aus freier Chassis-Beute.
##
## Validierung, Stats und Slotregeln kommen wie bisher aus DromeBuild und
## PartData -- also aus derselben Quelle, die auch der Kampf benutzt. Der Build
## selbst wird nach jeder Zuweisung aus dem Roster-Eintrag ABGELEITET
## (Roster.build_for): uid -> Instanz -> Typ -> Slot.
##
## Die SVG-Werkstatt (python3 main.py) bleibt daneben bestehen. Sie ist das
## Asset-Werkzeug -- Anker setzen, Teile importieren, Paletten pflegen.
##
## ### Der Aufbau des Bildschirms
##
##     links   das eigene Inventar an Kern und Ausruestung, nach Typ gruppiert
##     Mitte   der DROME, wie er gerade aussieht
##     rechts  wo was steckt, was es bewirkt, was er kann

const PREVIEW_SCALE := 2.4
const PREVIEW_SIZE := 520

## Kantenlaenge des Bildes in der Bibliothek und Hoehe der Namenszeile
## darueber. Die Spaltenzahl folgt daraus, nicht umgekehrt.
const TILE_SIZE := 108
const TILE_NAME_HEIGHT := 15
const TILE_COLUMNS := 3
const LIBRARY_WIDTH := 372

## Wo im Vorschaufeld der Bodenpunkt des DROME sitzt. Nicht 0.5 -- ein Bot
## ragt nach oben, nicht nach unten.
const GROUND_FRACTION := 0.72

## Kantenlaenge der Miniatur in der Slotliste rechts. Dort ist sie ein
## Merkzeichen neben dem Namen -- gewaehlt wird in der Bibliothek.
const THUMB_SIZE := 28
const DIRECTIONS := ["south", "west", "east", "north"]
const DIR_LABEL := {"south": "Sued", "west": "West", "east": "Ost", "north": "Nord"}

const SLOT_LABEL := {
	"body": "Chassis", "head": "Sensorik", "feet": "Antrieb", "core": "Kern",
	"equip_left": "Ausruestung links", "equip_right": "Ausruestung rechts",
	"equip_shoulder": "Schulterhalterung", "equip_center": "Zentralhalterung",
}

## Dieselben Halter kurz -- fuer die Halterliste, die neben dem Zeiger aufgeht
## und deshalb schmal bleiben muss.
const SLOT_SHORT := {
	"equip_left": "links", "equip_right": "rechts",
	"equip_shoulder": "Schulter", "equip_center": "Zentral",
}

## Die Bibliothek zeigt nur, was sich AN diesem DROME tauschen laesst: Kern und
## Ausruestung. Das Chassis steht nicht dabei -- es ist die feste Huelle dieses
## DROME (§9/§10g), sichtbar in der Vorschau und als Zeile im Aufbau rechts.
const LIBRARY_GROUPS := [
	[PartData.Type.CORE, "Kern"],
	[PartData.Type.EQUIPMENT, "Ausruestung"],
]

## Die Kampfwerte, gruppiert. Sieben Zahlen untereinander sind eine Liste;
## dieselben sieben in vier Gruppen sind eine Aussage darueber, was dieser
## DROME kann.
const STAT_GROUPS := [
	["Bestand", [["hp_max", "Integritaet"], ["def", "DEF"]]],
	["Angriff", [["atk", "ATK"]]],
	["Bewegung", [["mov", "MOV  Felder je Zug"], ["spd", "SPD  Zugtakt"]]],
	["Energie", [["en_max", "Energie"], ["en_regen", "EN-Regen je Zug"]]],
]

const FLAG_LABEL := {
	"can_pass_units": "zieht durch Einheiten",
	"can_enter_steps": "betritt Stufen",
	"ignores_drift": "immun gegen Drift",
	"step_cost_reduced": "Stufen kosten 1 MP",
	"grants_ignore_haze": "sieht durch Haze",
}

const COLOR_GOOD := Color(0.42, 0.85, 0.48)
const COLOR_BAD := Color(1.0, 0.42, 0.42)
const COLOR_WARN := Color(1.0, 0.72, 0.3)
const COLOR_HEADING := Color(0.6, 0.8, 0.95)
const COLOR_MUTED := Color(0.62, 0.66, 0.72)

## Der Roster-Eintrag, den diese Werkstatt anpasst -- gewaehlt in der Garage. Er
## ist eine Referenz in GameState.roster: was hier zugewiesen wird, steht damit
## sofort im Roster; ``_persist`` schreibt nur noch auf die Platte.
var _entry: RosterEntry
## Der aus Eintrag + Inventar abgeleitete, typ-basierte Aufbau -- fuer Stats,
## Vorschau und Validierung. Nach jeder Zuweisung neu abgeleitet (``_rebuild``).
var _build: DromeBuild
var _selected_slot: String = "core"
var _facing: String = "south"
var _filter: String = ""

## Aufbau, der beim Hovern ueber ein Bibliotheks-Teil entstuende. Nur Anzeige --
## er wird sowohl in den Zahlen als auch in der VORSCHAU gezeigt.
var _hover_build: DromeBuild = null
var _hover_part: PartData = null
var _hover_slot: String = ""

## Die offene Halterliste: auf welchem Teil sie steht.
var _pending_part: PartData = null

var _preview_root: Node2D
var _library: VBoxContainer
var _library_column: Control
var _slot_popup: PanelContainer
var _slot_popup_rows: VBoxContainer

## Ausgeschnittene Bauteilbilder, nach Asset-Pfad.
var _cropped: Dictionary = {}
var _slot_list: VBoxContainer
var _stat_list: VBoxContainer
var _action_list: VBoxContainer
var _problem_label: RichTextLabel
var _chassis_label: Label
var _weight_label: Label
var _power_label_total: Label
var _name_field: LineEdit
var _filter_field: LineEdit
var _delta_panel: PanelContainer
var _delta_rows: VBoxContainer
var _direction_buttons: Array[Button] = []


func _ready() -> void:
	_entry = GameState.editing_entry()
	if _entry == null:
		# Kein Eintrag gewaehlt (Direktstart der Szene) -- die Auswahl IST die
		# Garage, also dorthin. Deferred, weil ein Szenenwechsel mitten im
		# _ready den gerade betretenen Baum umbaut.
		get_tree().change_scene_to_file.call_deferred("res://scenes/garage.tscn")
		return
	_facing = _entry.direction
	_rebuild()
	_build_ui()
	_refresh_all()


## Leitet den typ-basierten Aufbau aus Eintrag + Inventar neu ab. Nach jeder
## Zuweisung noetig -- DromeBuild bleibt unberuehrt typ-basiert.
func _rebuild() -> void:
	_build = GameState.roster.build_for(_entry)


# ---------------------------------------------------------------------------
# Aufbau der Oberflaeche
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	margin.add_child(columns)

	columns.add_child(_build_library_column())
	columns.add_child(_build_preview_column())
	columns.add_child(_build_stats_column())

	_delta_panel = PanelContainer.new()
	_delta_panel.visible = false
	_delta_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_delta_panel.add_theme_stylebox_override("panel", _panel_style())
	_delta_rows = VBoxContainer.new()
	_delta_rows.add_theme_constant_override("separation", 1)
	_delta_panel.add_child(_delta_rows)
	add_child(_delta_panel)

	_slot_popup = PanelContainer.new()
	_slot_popup.visible = false
	_slot_popup.add_theme_stylebox_override("panel", _panel_style())
	_slot_popup_rows = VBoxContainer.new()
	_slot_popup_rows.add_theme_constant_override("separation", 2)
	_slot_popup.add_child(_slot_popup_rows)
	add_child(_slot_popup)

	_refresh_direction_buttons()


func _build_library_column() -> Control:
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(LIBRARY_WIDTH, 0)
	_library_column = left
	left.add_child(_heading("Inventar"))

	_filter_field = LineEdit.new()
	_filter_field.placeholder_text = "Filter: Code, Name, Tag"
	_filter_field.text_changed.connect(func(text):
		_filter = text.strip_edges().to_lower()
		_refresh_library())
	left.add_child(_filter_field)

	var hint := Label.new()
	hint.text = "Zeiger zeigt Werte und Aussehen · Klick baut ein\n"\
		+ "Nur FREIE Exemplare — was woanders steckt, ist gesperrt"
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = COLOR_MUTED
	left.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(LIBRARY_WIDTH, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_library = VBoxContainer.new()
	_library.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_library)
	return left


func _build_preview_column() -> Control:
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var top_row := HBoxContainer.new()
	center.add_child(top_row)
	var back := Button.new()
	back.text = "< Garage"
	back.pressed.connect(func(): _save_and_go("res://scenes/garage.tscn"))
	top_row.add_child(back)
	_name_field = LineEdit.new()
	_name_field.custom_minimum_size = Vector2(220, 0)
	_name_field.text_changed.connect(func(text):
		_entry.name = text
		_build.display_name = text)
	top_row.add_child(_name_field)
	for direction in DIRECTIONS:
		var button := Button.new()
		button.text = DIR_LABEL[direction]
		button.toggle_mode = true
		button.pressed.connect(func():
			_facing = direction
			_refresh_preview()
			_refresh_library()
			_refresh_slots()
			_refresh_direction_buttons())
		button.set_meta("direction", direction)
		_direction_buttons.append(button)
		top_row.add_child(button)

	var viewport := SubViewportContainer.new()
	viewport.custom_minimum_size = Vector2(PREVIEW_SIZE, PREVIEW_SIZE)
	viewport.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	viewport.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(viewport)

	var sub := SubViewport.new()
	sub.size = Vector2i(PREVIEW_SIZE, PREVIEW_SIZE)
	sub.transparent_bg = true
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.add_child(sub)

	_preview_root = Node2D.new()
	_preview_root.position = Vector2(
		PREVIEW_SIZE * 0.5 - IsoView.SPRITE_ORIGIN.x * PREVIEW_SCALE,
		PREVIEW_SIZE * GROUND_FRACTION - IsoView.SPRITE_ORIGIN.y * PREVIEW_SCALE)
	_preview_root.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
	sub.add_child(_preview_root)

	# Das feste Chassis dieses DROME -- keine Auswahl, eine Ansage. Wer es
	# wechseln will, baut in der Garage einen neuen DROME (§10g).
	_chassis_label = Label.new()
	_chassis_label.add_theme_font_size_override("font_size", 12)
	_chassis_label.modulate = COLOR_HEADING
	_chassis_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_chassis_label)
	return center


func _build_stats_column() -> Control:
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(360, 0)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(360, 0)
	right.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.custom_minimum_size = Vector2(340, 0)
	scroll.add_child(column)

	column.add_child(_heading("Aufbau"))
	_slot_list = VBoxContainer.new()
	_slot_list.add_theme_constant_override("separation", 3)
	column.add_child(_slot_list)

	var stats_head := HBoxContainer.new()
	var stats_title := _heading("Kampfwerte")
	stats_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_head.add_child(stats_title)
	_power_label_total = Label.new()
	_power_label_total.add_theme_font_size_override("font_size", 12)
	_power_label_total.modulate = COLOR_HEADING
	stats_head.add_child(_power_label_total)
	column.add_child(stats_head)

	_stat_list = VBoxContainer.new()
	column.add_child(_stat_list)

	_weight_label = Label.new()
	_weight_label.add_theme_font_size_override("font_size", 11)
	_weight_label.modulate = COLOR_MUTED
	column.add_child(_weight_label)

	column.add_child(_heading("Kann im Kampf"))
	_action_list = VBoxContainer.new()
	_action_list.add_theme_constant_override("separation", 2)
	column.add_child(_action_list)

	_problem_label = RichTextLabel.new()
	_problem_label.bbcode_enabled = true
	_problem_label.fit_content = true
	_problem_label.custom_minimum_size = Vector2(0, 76)
	column.add_child(_problem_label)

	var done := Button.new()
	done.text = "Fertig — zur Garage"
	done.custom_minimum_size = Vector2(0, 44)
	done.pressed.connect(func(): _save_and_go("res://scenes/garage.tscn"))
	right.add_child(done)
	return right


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = COLOR_HEADING
	return label


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.13, 0.97)
	style.border_color = Color(0.35, 0.55, 0.75, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


# ---------------------------------------------------------------------------
# Anzeige
# ---------------------------------------------------------------------------

func _refresh_all() -> void:
	_name_field.text = _entry.name
	_refresh_chassis_label()
	_refresh_library()
	_refresh_slots()
	_refresh_stats()
	_refresh_actions()
	_refresh_preview()


func _refresh_chassis_label() -> void:
	var chassis := _build.body()
	_chassis_label.text = "Chassis: %s" % (chassis.display_name if chassis != null
		else "— kein Rahmen —")


func _refresh_direction_buttons() -> void:
	for button in _direction_buttons:
		button.button_pressed = button.get_meta("direction") == _facing


## Welche Slots dieser Aufbau hat -- Chassis (fest), Kern und die equip_*-Anker.
func _slots() -> Array[String]:
	var slots: Array[String] = ["body", "core"]
	slots.append_array(_build.equip_slots())
	return slots


## Die Slotliste: was steckt wo, was nimmt der Slot an, und welcher ist
## angewaehlt. Die Chassis-Zeile ist fest -- sie laesst sich weder anwaehlen noch
## leeren, denn das Chassis ist die Identitaet des DROME (§10g).
func _refresh_slots() -> void:
	for child in _slot_list.get_children():
		child.queue_free()
	var chassis := _build.body()
	for slot in _slots():
		var part := _build.part_in(slot)
		var row := HBoxContainer.new()

		if slot == "body":
			var fixed := HBoxContainer.new()
			fixed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fixed.custom_minimum_size = Vector2(0, THUMB_SIZE + 4)
			if part != null:
				var thumb := TextureRect.new()
				thumb.texture = _part_texture(part)
				thumb.custom_minimum_size = Vector2(THUMB_SIZE, THUMB_SIZE)
				thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				fixed.add_child(thumb)
			var label := Label.new()
			label.text = " Chassis: %s (fest)" % (part.display_name if part != null
				else "—")
			label.add_theme_font_size_override("font_size", 12)
			label.modulate = COLOR_MUTED
			label.tooltip_text = "Das Chassis ist die Identitaet dieses DROME.\n"\
				+ "Ein anderes Chassis ist ein neuer DROME — in der Garage."
			fixed.add_child(label)
			row.add_child(fixed)
			_slot_list.add_child(row)
			continue

		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = slot == _selected_slot
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, THUMB_SIZE + 4)
		button.add_theme_font_size_override("font_size", 12)
		button.text = " %s: %s" % [SLOT_LABEL.get(slot, slot),
			part.display_name if part != null else "— leer —"]
		button.tooltip_text = _slot_tooltip(chassis, slot, part)
		if part != null:
			_set_thumbnail(button, part)
		else:
			button.modulate = COLOR_MUTED
		button.pressed.connect(func():
			_selected_slot = slot
			_refresh_slots()
			_refresh_library())
		row.add_child(button)

		if part != null:
			var clear := Button.new()
			clear.text = "×"
			clear.tooltip_text = "Slot leeren — das Teil kehrt ins Inventar zurueck"
			clear.pressed.connect(func():
				GameState.roster.clear_slot(_entry, slot)
				_after_change())
			row.add_child(clear)
		_slot_list.add_child(row)


## Was dieser Slot annimmt -- im Klartext und aus den Regeln des Chassis.
func _slot_tooltip(chassis: PartData, slot: String, part: PartData) -> String:
	var lines: Array[String] = [SLOT_LABEL.get(slot, slot)]
	if part != null:
		lines.append("%s  %s" % [part.code, part.display_name])
	else:
		lines.append("leer")
	if slot.begins_with("equip_") and chassis != null:
		var rule: Dictionary = chassis.slot_rules.get(slot, {})
		var limit: String = rule.get("max_class", "heavy")
		lines.append("")
		lines.append("nimmt: bis %s" % _class_label(limit))
		var categories = rule.get("categories")
		if categories is Array and not categories.is_empty():
			var names: Array[String] = []
			for entry in categories:
				names.append(_category_label(str(entry)))
			lines.append("nur %s" % ", ".join(names))
	return "\n".join(lines)


static func _class_label(mount_class: String) -> String:
	match mount_class:
		"light": return "leicht"
		"medium": return "mittel"
		_: return "schwer"


static func _category_label(category: String) -> String:
	match category:
		"weapon": return "Waffe"
		"shield": return "Schild"
		"support": return "Support"
		_: return category


## Die Bibliothek: das eigene INVENTAR an Kern und Ausruestung, nach Typ
## gruppiert -- nur Typen, von denen der Spieler mindestens ein Exemplar besitzt.
##
## Was fuer diesen DROME nicht verfuegbar ist, wird nicht weggelassen, sondern
## ausgegraut und begruendet: kein freies Exemplar (steckt woanders) oder keine
## passende Halterung an diesem Chassis. Wegzulassen liesse den Spieler raten.
func _refresh_library() -> void:
	_close_slot_popup()
	for child in _library.get_children():
		child.queue_free()

	for group in LIBRARY_GROUPS:
		var type: PartData.Type = group[0]
		var parts: Array = []
		for part_id in GameState.roster.owned_part_ids(type):
			var part := PartDB.get_part(part_id)
			if part != null and _matches_filter(part):
				parts.append(part)
		if parts.is_empty():
			continue
		var header := _heading(group[1])
		header.custom_minimum_size = Vector2(0, 22)
		_library.add_child(header)

		var grid := GridContainer.new()
		grid.columns = TILE_COLUMNS
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		_library.add_child(grid)
		for part in parts:
			grid.add_child(_library_tile(part))


func _matches_filter(part: PartData) -> bool:
	if _filter == "":
		return true
	var haystack := "%s %s %s" % [part.code, part.display_name,
		" ".join(part.tags)]
	return _filter in haystack.to_lower()


## Eine Kachel je besessenem Bauteiltyp: Name oben, darunter das Bauteil. Die
## Verfuegbarkeit (frei/verbaut) faerbt sie und entscheidet, ob der Klick greift.
func _library_tile(part: PartData) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE + TILE_NAME_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var slot := _target_slot_for(part)
	var free := GameState.roster.free_count(part.id)
	var here := GameState.roster.count_in_entry(_entry, part.id)
	var equipped := here > 0
	# Eine Ausruestung braucht eine passende Halterung; jedes Teil braucht ein
	# freies Exemplar zum Einbauen (es sei denn, es steckt schon hier).
	var no_mount: bool = part.type == PartData.Type.EQUIPMENT and slot == ""
	var sold_out: bool = free <= 0 and here <= 0
	var blocked: bool = no_mount or sold_out

	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, _tile_style(state, equipped))

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)

	var name_label := Label.new()
	name_label.text = part.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.custom_minimum_size = Vector2(0, TILE_NAME_HEIGHT)
	name_label.modulate = COLOR_MUTED if blocked else Color(0.82, 0.87, 0.94)
	box.add_child(name_label)

	var picture := TextureRect.new()
	picture.texture = _part_texture(part)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if blocked:
		picture.modulate = Color(0.5, 0.5, 0.56)
	box.add_child(picture)

	if equipped:
		var check := Label.new()
		check.text = "✓"
		check.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		check.position = Vector2(-17, -20)
		check.add_theme_font_size_override("font_size", 12)
		check.modulate = COLOR_GOOD
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(check)

	# Wie viele Exemplare frei sind -- die Zahl, an der die Eindeutigkeit haengt.
	# Nur zeigen, wenn der Spieler mehr als eins besitzt: bei Einzelstuecken
	# sagen ✓ und die Sperre schon alles.
	if GameState.roster.total_count(part.id) > 1:
		var badge := Label.new()
		badge.text = "%d frei" % free
		badge.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		badge.position = Vector2(4, -20)
		badge.add_theme_font_size_override("font_size", 10)
		badge.modulate = COLOR_GOOD if free > 0 else COLOR_MUTED
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(badge)

	if blocked:
		button.disabled = true
		button.mouse_filter = Control.MOUSE_FILTER_STOP
	elif part.type == PartData.Type.EQUIPMENT:
		button.pressed.connect(func(): _open_slot_popup(part, button))
	else:
		button.pressed.connect(func():
			_assign_core(part)
			_after_change())

	button.mouse_entered.connect(func(): _set_hover(part, button))
	button.mouse_exited.connect(func(): _clear_hover())
	return button


func _tile_style(state: String, equipped: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.19)
	style.border_color = Color(0.24, 0.28, 0.35)
	match state:
		"hover":
			style.bg_color = Color(0.18, 0.22, 0.29)
			style.border_color = Color(0.45, 0.65, 0.9)
		"pressed":
			style.bg_color = Color(0.22, 0.3, 0.4)
			style.border_color = Color(0.55, 0.75, 0.95)
		"disabled":
			style.bg_color = Color(0.1, 0.11, 0.14)
	if equipped:
		style.border_color = COLOR_GOOD
	style.set_border_width_all(2 if equipped else 1)
	style.set_corner_radius_all(3)
	return style


## Das Bauteilbild, auf seinen sichtbaren Inhalt zugeschnitten.
func _part_texture(part: PartData) -> Texture2D:
	var path: String = part.view(_facing).get("svg", "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	if _cropped.has(path):
		return _cropped[path]

	var texture: Texture2D = load(path)
	var result: Texture2D = texture
	var image: Image = texture.get_image()
	if image != null:
		if image.is_compressed():
			image.decompress()
		var used := image.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(used)
			result = atlas
	_cropped[path] = result
	return result


func _set_thumbnail(button: Button, part: PartData) -> void:
	button.icon = _part_texture(part)
	button.expand_icon = true


## In welchen Slot wuerde dieses Teil gehen? Die Regel steht in DromeBuild.
func _target_slot_for(part: PartData) -> String:
	return _build.slot_for(part, _selected_slot)


## Baut ein Teil PROBEHALBER in einen Aufbau ein -- typ-basiert, nur fuer die
## Hover-Vorschau. Die echte Zuweisung laeuft ueber den Roster (Instanzen).
func _apply_part(build: DromeBuild, part: PartData) -> void:
	if part.type == PartData.Type.BODY:
		build.apply_chassis(part.id)
		return
	var slot := build.slot_for(part, _selected_slot)
	if slot != "":
		build.slots[slot] = part.id


## Weist dem Kern-Slot eine freie Instanz dieses Typs zu (§10g).
func _assign_core(part: PartData) -> void:
	GameState.roster.assign(_entry, "core", part.id)


## Weist einem Halter eine freie Instanz dieser Ausruestung zu.
func _assign_equipment(slot: String, part: PartData) -> void:
	if GameState.roster.assign(_entry, slot, part.id):
		_selected_slot = slot


## Was das Teil selbst mitbringt -- seine eigenen Werte, nicht die des Aufbaus.
static func _part_spec_lines(part: PartData) -> Array[String]:
	var lines: Array[String] = []
	var values: Array[String] = []
	for key in ["hp", "en_max", "en_regen", "spd", "mov", "atk", "def"]:
		var value: int = part.get(key)
		if value != 0:
			values.append("%s %+d" % [key.to_upper(), value])
	if not values.is_empty():
		lines.append("  ".join(values))

	if part.weight != 0:
		lines.append("Gewicht %d" % part.weight)

	if part.type == PartData.Type.EQUIPMENT:
		lines.append("Klasse %s · %s" % [_class_label(part.mount_class),
			_category_label(part.category)])
	for flag in FLAG_LABEL:
		if part.get(flag):
			lines.append(FLAG_LABEL[flag])
	for action in part.actions:
		lines.append(action.display_name)
		lines.append_array(action.description_lines())
	return lines


# ---------------------------------------------------------------------------
# Die Halterliste der Ausruestung
# ---------------------------------------------------------------------------

## Welche Halter dieses Chassis fuer dieses Teil hat -- alle, auch die, die es
## nicht nehmen, mit dem Grund daneben.
static func slot_choices(build: DromeBuild, part: PartData) -> Array:
	var choices: Array = []
	if build == null or part == null or part.type != PartData.Type.EQUIPMENT:
		return choices
	var chassis := build.body()
	if chassis == null:
		return choices

	var number := 0
	for slot in build.equip_slots():
		number += 1
		var rule: Dictionary = chassis.slot_rules.get(slot, {})
		var limit: String = rule.get("max_class", PartData.MOUNT_CLASSES[-1])
		var occupant := build.part_in(slot)
		var allowed := chassis.accepts(part, slot)

		var detail := ""
		if not allowed:
			detail = _rejection(part, rule, limit)
		elif occupant == null:
			detail = "frei"
		elif occupant.id == part.id:
			detail = "steckt schon drin"
		else:
			detail = "ersetzt %s" % occupant.display_name

		choices.append({
			"slot": slot,
			"number": number,
			"label": "Slot %d · %s (%s)" % [number, SLOT_SHORT.get(slot, slot),
				_class_label(limit)],
			"detail": detail,
			"allowed": allowed,
		})
	return choices


static func _rejection(part: PartData, rule: Dictionary, limit: String) -> String:
	if PartData.MOUNT_CLASSES.find(part.mount_class) \
			> PartData.MOUNT_CLASSES.find(limit):
		return "nimmt nur bis %s" % _class_label(limit)
	var allowed = rule.get("categories")
	if allowed is Array and not allowed.is_empty() and part.category not in allowed:
		var names: Array[String] = []
		for entry in allowed:
			names.append(_category_label(str(entry)))
		return "nur %s" % ", ".join(names)
	return "passt nicht"


## Die Liste geht ueber der Kachel auf, die sie meint. Ein Halter ist nur dann
## klickbar, wenn er das Teil nimmt UND ein freies Exemplar da ist -- sonst nennt
## die Zeile den Grund (Eindeutigkeit, §10g).
func _open_slot_popup(part: PartData, anchor: Control) -> void:
	if _slot_popup.visible and _pending_part == part:
		_close_slot_popup()
		return

	_pending_part = part
	for child in _slot_popup_rows.get_children():
		child.queue_free()

	_slot_popup_rows.add_child(_delta_line(part.display_name, COLOR_HEADING, 12))

	var free := GameState.roster.free_count(part.id)
	var choices := slot_choices(_build, part)
	if choices.is_empty():
		_slot_popup_rows.add_child(_delta_line("Dieses Chassis hat keine "
			+ "Halterung.", COLOR_BAD))
	for choice in choices:
		var slot: String = choice["slot"]
		var occupant := _build.part_in(slot)
		var detail: String = choice["detail"]
		# Klickbar nur, wenn das Teil hier NEU landen kann: es passt, steckt nicht
		# schon hier, und es gibt ein freies Exemplar.
		var already_here: bool = occupant != null and occupant.id == part.id
		var can_place: bool = choice["allowed"] and not already_here and free > 0
		if choice["allowed"] and not already_here and free <= 0:
			detail = "kein freies Exemplar"

		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_size_override("font_size", 11)
		row.text = "%s   %s" % [choice["label"], detail]
		row.disabled = not can_place
		if not can_place:
			row.modulate = COLOR_MUTED
		else:
			row.pressed.connect(func():
				_assign_equipment(slot, part)
				_close_slot_popup()
				_after_change())
		_slot_popup_rows.add_child(row)

	_slot_popup.reset_size()
	_slot_popup.visible = true
	await get_tree().process_frame
	if not _slot_popup.visible or _pending_part != part:
		return
	var origin := anchor.get_global_rect()
	var column := _library_column.get_global_rect()
	_slot_popup.position = Vector2(
		clampf(origin.position.x + 12.0, 8.0,
			maxf(8.0, column.end.x - _slot_popup.size.x)),
		clampf(origin.position.y + 10.0, 8.0, size.y - _slot_popup.size.y - 8.0))


func _close_slot_popup() -> void:
	_slot_popup.visible = false
	_pending_part = null


func _input(event: InputEvent) -> void:
	if not _slot_popup.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if not _slot_popup.get_global_rect().has_point(event.global_position):
			_close_slot_popup()
	elif event.is_action_pressed("ui_cancel"):
		_close_slot_popup()


# ---------------------------------------------------------------------------
# Die Vorschau beim Hovern
# ---------------------------------------------------------------------------

func _set_hover(part: PartData, anchor: Control) -> void:
	if _slot_popup.visible and _pending_part != part:
		_close_slot_popup()
	var slot := _target_slot_for(part)
	var probe := _build.clone()
	if slot != "":
		_apply_part(probe, part)
		probe._drop_invalid_equipment()
	_hover_build = probe
	_hover_part = part
	_hover_slot = slot
	_refresh_stats()
	_refresh_preview()
	_show_delta(part, slot, anchor)


func _clear_hover() -> void:
	if _hover_build == null:
		return
	if _slot_popup.visible:
		return
	_hover_build = null
	_hover_part = null
	_hover_slot = ""
	_delta_panel.visible = false
	_refresh_stats()
	_refresh_preview()


func _show_delta(part: PartData, slot: String, anchor: Control) -> void:
	for child in _delta_rows.get_children():
		child.queue_free()

	_delta_rows.add_child(_delta_line("%s  %s" % [part.code, part.display_name],
		COLOR_HEADING, 12))

	for line in _part_spec_lines(part):
		_delta_rows.add_child(_delta_line(line, Color(0.78, 0.83, 0.9)))
	_delta_rows.add_child(_delta_line("", COLOR_MUTED, 4))

	# Die Verfuegbarkeit gehoert hierher -- sie ist die Kaufentscheidung: kann ich
	# das hier ueberhaupt einbauen, und wenn nein, warum nicht (§10g).
	var free := GameState.roster.free_count(part.id)
	var here := GameState.roster.count_in_entry(_entry, part.id)
	if slot == "":
		_delta_rows.add_child(_delta_line("passt in keine Halterung von %s"
			% [_build.body().display_name if _build.body() != null
				else "diesem Chassis"], COLOR_BAD))
	elif free <= 0 and here <= 0:
		_delta_rows.add_child(_delta_line("kein freies Exemplar — alle verbaut",
			COLOR_BAD))
	elif part.type == PartData.Type.EQUIPMENT:
		_delta_rows.add_child(_delta_line("Klick fragt nach dem Halter · %d frei"
			% free, COLOR_MUTED))
	else:
		_delta_rows.add_child(_delta_line("kommt in: %s · %d frei"
			% [SLOT_LABEL.get(slot, slot), free], COLOR_MUTED))
	var replaced := _build.part_in(slot) if slot != "" else null
	if replaced != null and replaced.id != part.id:
		_delta_rows.add_child(_delta_line("ersetzt: %s" % replaced.display_name,
			COLOR_MUTED))

	var before := _build.stats()
	var after := _hover_build.stats()
	var changed := false
	for row in _numeric_rows():
		var key: String = row[0]
		if after[key] == before[key]:
			continue
		changed = true
		var diff: int = after[key] - before[key]
		_delta_rows.add_child(_delta_line("%s  %d → %d  (%+d)"
			% [row[1], before[key], after[key], diff],
			COLOR_GOOD if diff > 0 else COLOR_BAD))
	if not changed:
		_delta_rows.add_child(_delta_line("keine Wertaenderung", COLOR_MUTED))

	if after["weight"] != before["weight"]:
		_delta_rows.add_child(_delta_line("Gewicht  %d → %d"
			% [before["weight"], after["weight"]], COLOR_MUTED))

	var problems := _hover_build.validate()
	if problems.is_empty():
		_delta_rows.add_child(_delta_line("Aufbau bliebe gueltig", COLOR_GOOD))
	else:
		for line in problems:
			_delta_rows.add_child(_delta_line("• %s" % line, COLOR_BAD))

	_delta_panel.visible = true
	await get_tree().process_frame
	if not _delta_panel.visible or _hover_part != part:
		return
	var origin := anchor.get_global_rect()
	var column := _library_column.get_global_rect()
	_delta_panel.position = Vector2(column.end.x + 8,
		clampf(origin.position.y, 8.0, size.y - _delta_panel.size.y - 8.0))


func _delta_line(text: String, color: Color, font_size: int = 11) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	return label


func _numeric_rows() -> Array:
	var rows: Array = []
	for group in STAT_GROUPS:
		for row in group[1]:
			rows.append([row[0], row[1].split("  ")[0]])
	return rows


# ---------------------------------------------------------------------------
# Werte, Aktionen, Probleme
# ---------------------------------------------------------------------------

func _refresh_stats() -> void:
	for child in _stat_list.get_children():
		child.queue_free()

	var base := _build.stats()
	var preview: Dictionary = _hover_build.stats() if _hover_build != null else {}

	for group in STAT_GROUPS:
		var title := Label.new()
		title.text = group[0]
		title.add_theme_font_size_override("font_size", 10)
		title.modulate = COLOR_MUTED
		_stat_list.add_child(title)

		for row in group[1]:
			var key: String = row[0]
			var line := HBoxContainer.new()
			var name_label := Label.new()
			name_label.text = row[1]
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.modulate = Color(0.75, 0.8, 0.88)
			line.add_child(name_label)

			var value_label := Label.new()
			value_label.text = str(base[key])
			line.add_child(value_label)

			if not preview.is_empty() and preview[key] != base[key]:
				var diff: int = preview[key] - base[key]
				var delta := Label.new()
				delta.text = "  %+d" % diff
				delta.modulate = COLOR_GOOD if diff > 0 else COLOR_BAD
				line.add_child(delta)
			_stat_list.add_child(line)

			if key == "spd":
				_add_payload_note()

	_weight_label.text = "Gewicht   %d" % base["weight"]

	var flags: Array[String] = []
	for flag in FLAG_LABEL:
		if base.get(flag, false):
			flags.append(FLAG_LABEL[flag])
	if base["drift_modifier"] != 0:
		flags.append("Gleitweite %+d" % base["drift_modifier"])

	_power_label_total.text = "Kampfwert %d" % int(round(_build.power_score()))

	var problems := _build.validate()
	var text := ""
	if not flags.is_empty():
		text += "[color=#8ab4d8]%s[/color]\n" % " · ".join(flags)
	if problems.is_empty():
		text += "[color=#6bd97a]Aufbau ist gueltig.[/color]"
	else:
		for line in problems:
			text += "[color=#ff6b6b]• %s[/color]\n" % line
	_problem_label.text = text


## Was dieser Aufbau im Kampf tun kann -- getrennt nach Angriff und Faehigkeit.
func _refresh_actions() -> void:
	for child in _action_list.get_children():
		child.queue_free()

	var any := false
	for category in [ActionData.Category.ATTACK, ActionData.Category.ABILITY]:
		for action in _build.actions_of(category):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			row.tooltip_text = "\n".join(action.description_lines())
			row.mouse_filter = Control.MOUSE_FILTER_STOP
			row.modulate = Color(0.85, 0.9, 0.95) if action.is_attack() \
				else Color(0.72, 0.85, 0.98)

			var icon := TextureRect.new()
			icon.texture = ActionIcons.texture_for(action)
			icon.custom_minimum_size = Vector2(16, 16)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon)

			var label := Label.new()
			label.text = "%s   %s" % [action.display_name, action.headline()]
			label.add_theme_font_size_override("font_size", 11)
			row.add_child(label)

			_action_list.add_child(row)
			any = true

	if not any:
		var none := Label.new()
		none.text = "Keine Aktion -- ohne Waffe geht nichts."
		none.add_theme_font_size_override("font_size", 11)
		none.modulate = COLOR_BAD
		_action_list.add_child(none)


## Woher der Tempoverlust kommt: "Zuladung 16  ->  -4 SPD".
func _add_payload_note() -> void:
	var slowdown := _build.payload_slowdown()
	if slowdown <= 0:
		return
	var payload := 0
	for part in _build.equipment():
		payload += part.weight

	var note := Label.new()
	note.text = "    Zuladung %d  ->  -%d SPD" % [payload, slowdown]
	note.add_theme_font_size_override("font_size", 10)
	note.modulate = COLOR_MUTED
	_stat_list.add_child(note)


func _refresh_preview() -> void:
	DromeSprites.assemble(_preview_root,
		_hover_build if _hover_build != null else _build, _facing)


func _after_change() -> void:
	_clear_hover()
	_rebuild()
	if _selected_slot not in _slots():
		_selected_slot = "core"
	_refresh_all()


# ---------------------------------------------------------------------------
# Uebergabe
# ---------------------------------------------------------------------------

## Der Eintrag ist eine Referenz im Roster -- die Zuweisungen stehen also schon
## drin. Zu sichern bleibt die Blickrichtung und der Gang auf die Platte.
func _persist() -> void:
	_entry.direction = _facing
	GameState.save_roster()


func _save_and_go(scene: String) -> void:
	_persist()
	get_tree().change_scene_to_file(scene)
