extends Control

## Die Werkstatt in Godot.
##
## Der Spieler baut hier seinen Squad und schickt ihn in den Chaos-Virus.
## Bewusst dieselben Regeln wie die SVG-Werkstatt -- aber sie sind nicht
## nachgebaut: Validierung, Stats und Slotregeln kommen aus DromeBuild und
## PartData, also aus derselben Quelle, die auch der Kampf benutzt. Was hier
## angezeigt wird, gilt im Kampf.
##
## Die SVG-Werkstatt (python3 main.py) bleibt daneben bestehen. Sie ist das
## Asset-Werkzeug -- Anker setzen, Teile importieren, Paletten pflegen --,
## diese Szene ist der Loadout-Builder.
##
## ### Der Aufbau des Bildschirms
##
##     links   die GANZE Bibliothek, nach Bauteiltyp gruppiert
##     Mitte   der DROME, wie er gerade aussieht
##     rechts  wo was steckt, was es bewirkt, was er kann
##
## Links stand frueher nur, was in den gerade angewaehlten Slot passt. Das
## machte die Bibliothek zu einem Dropdown mit Umweg: um zu sehen, welche
## Kerne es gibt, musste man erst den Kern-Slot anwaehlen -- und wer nicht
## wusste, dass es einen zweiten Kern gibt, kam nie auf die Idee. Jetzt steht
## alles da, und der Klick raeumt selbst in den passenden Slot ein.

const PREVIEW_SCALE := 2.4
const PREVIEW_SIZE := 520

## Wo im Vorschaufeld der Bodenpunkt des DROME sitzt. Nicht 0.5 -- ein Bot
## ragt nach oben, nicht nach unten.
const GROUND_FRACTION := 0.72

## Kantenlaenge der Miniatur in der Bibliothek.
const THUMB_SIZE := 40
const DIRECTIONS := ["south", "west", "east", "north"]
const DIR_LABEL := {"south": "Sued", "west": "West", "east": "Ost", "north": "Nord"}

const SLOT_LABEL := {
	"body": "Chassis", "head": "Sensorik", "feet": "Antrieb", "core": "Kern",
	"equip_left": "Ausruestung links", "equip_right": "Ausruestung rechts",
	"equip_shoulder": "Schulterhalterung", "equip_center": "Zentralhalterung",
}

## Die Bibliothek in der Reihenfolge, in der ein DROME entsteht: erst das
## Chassis (es bestimmt, wie viele Ausruestungsslots es ueberhaupt gibt), dann
## die drei anderen Sockel, zuletzt die Ausruestung.
const LIBRARY_GROUPS := [
	[PartData.Type.BODY, "Chassis"],
	[PartData.Type.HEAD, "Sensorik"],
	[PartData.Type.FEET, "Antrieb"],
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

var _squad: Array = []
var _active_index: int = 0
var _build: DromeBuild
var _selected_slot: String = "body"
var _facing: String = "south"
var _filter: String = ""

## Aufbau, der beim Hovern ueber ein Bibliotheks-Teil entstuende. Nur Anzeige --
## er wird sowohl in den Zahlen als auch in der VORSCHAU gezeigt: die Frage
## "wie sieht das aus" beantwortet kein Zahlenwert.
var _hover_build: DromeBuild = null
var _hover_part: PartData = null
var _hover_slot: String = ""

var _preview_root: Node2D
var _library: VBoxContainer
var _slot_list: VBoxContainer
var _stat_list: VBoxContainer
var _action_list: VBoxContainer
var _problem_label: RichTextLabel
var _squad_bar: HBoxContainer
var _start_button: Button
var _playtest_toggle: CheckBox
var _weight_bar: ProgressBar
var _weight_label: Label
var _power_bar: ProgressBar
var _power_label: Label
var _power_label_total: Label
var _name_field: LineEdit
var _filter_field: LineEdit
var _delta_panel: PanelContainer
var _delta_rows: VBoxContainer
var _direction_buttons: Array[Button] = []


func _ready() -> void:
	_load_squad()
	_build_ui()
	_refresh_all()


func _load_squad() -> void:
	_squad = GameState.squad.duplicate()
	var size := GameState.squad_size
	while _squad.size() < size:
		_squad.append(_starter_build(_squad.size()))
	_squad.resize(size)
	_build = _squad[0]


## Ein baubarer Ausgangspunkt, damit der Spieler nicht vor leeren Slots sitzt.
func _starter_build(index: int) -> DromeBuild:
	return DromeBuild.create("DROME-%d" % (index + 1), {
		"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core",
		"equip_left": &"eq_pulse_blaster",
	})


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

	# Das Deltafeld haengt NEBEN der Bibliothek und nicht in ihr: es soll ueber
	# der Vorschau liegen duerfen, ohne die Liste zu verschieben. Deshalb kein
	# Container-Kind, sondern ein freier Knoten mit eigener Position -- und als
	# letztes Kind, damit es ueber allem zeichnet.
	_delta_panel = PanelContainer.new()
	_delta_panel.visible = false
	_delta_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_delta_panel.add_theme_stylebox_override("panel", _panel_style())
	_delta_rows = VBoxContainer.new()
	_delta_rows.add_theme_constant_override("separation", 1)
	_delta_panel.add_child(_delta_rows)
	add_child(_delta_panel)

	_refresh_direction_buttons()


func _build_library_column() -> Control:
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	left.add_child(_heading("Bibliothek"))

	_filter_field = LineEdit.new()
	_filter_field.placeholder_text = "Filter: Code, Name, Tag"
	_filter_field.text_changed.connect(func(text):
		_filter = text.strip_edges().to_lower()
		_refresh_library())
	left.add_child(_filter_field)

	var hint := Label.new()
	hint.text = "Zeiger zeigt Wirkung und Aussehen · Klick baut ein"
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = COLOR_MUTED
	left.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(330, 0)
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
	back.text = "< Hauptmenue"
	back.pressed.connect(func(): _save_and_go("res://scenes/main.tscn"))
	top_row.add_child(back)
	_name_field = LineEdit.new()
	_name_field.custom_minimum_size = Vector2(220, 0)
	_name_field.text_changed.connect(func(text):
		_build.display_name = text
		_refresh_squad_bar())
	top_row.add_child(_name_field)
	for direction in DIRECTIONS:
		var button := Button.new()
		button.text = DIR_LABEL[direction]
		button.toggle_mode = true
		button.pressed.connect(func():
			_facing = direction
			_refresh_preview()
			# Die Miniaturen zeigen die Variante fuer diese Ansicht und
			# muessen deshalb mitwechseln.
			_refresh_library()
			_refresh_slots()
			_refresh_direction_buttons())
		button.set_meta("direction", direction)
		_direction_buttons.append(button)
		top_row.add_child(button)

	var viewport := SubViewportContainer.new()
	viewport.custom_minimum_size = Vector2(PREVIEW_SIZE, PREVIEW_SIZE)
	# NUR SHRINK_CENTER, nicht zusammen mit EXPAND_FILL: mit FILL waere der
	# Container so breit wie die Spalte, der SubViewport bliebe aber bei seiner
	# festen Groesse und wuerde an dessen linker Kante gezeichnet. Genau daher
	# stand der Bot links statt mittig.
	viewport.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	viewport.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(viewport)

	var sub := SubViewport.new()
	sub.size = Vector2i(PREVIEW_SIZE, PREVIEW_SIZE)
	sub.transparent_bg = true
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.add_child(sub)

	_preview_root = Node2D.new()
	# Die Bauteile zeichnen in einem 128x128-Raum mit der Bodenraute um
	# (64, 96). Ausgerichtet wird ueber genau diesen Punkt -- so bleibt der Bot
	# beim Richtungswechsel stehen, statt zu springen.
	#
	# Waagerecht mittig, senkrecht auf GROUND_FRACTION: ein DROME steht auf
	# seinem Bodenfeld und ragt nach oben. Legte man den Bodenpunkt in die
	# Mitte, waere die untere Haelfte leer und der Kopf am oberen Rand.
	_preview_root.position = Vector2(
		PREVIEW_SIZE * 0.5 - IsoView.SPRITE_ORIGIN.x * PREVIEW_SCALE,
		PREVIEW_SIZE * GROUND_FRACTION - IsoView.SPRITE_ORIGIN.y * PREVIEW_SCALE)
	_preview_root.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
	sub.add_child(_preview_root)

	_squad_bar = HBoxContainer.new()
	_squad_bar.add_theme_constant_override("separation", 8)
	center.add_child(_squad_bar)

	_playtest_toggle = CheckBox.new()
	_playtest_toggle.text = "Playtest: Traglast und Energie nicht erzwingen"
	_playtest_toggle.button_pressed = GameState.ignore_build_limits
	_playtest_toggle.tooltip_text = "Zum Ausprobieren: die beiden Budgetgrenzen "\
		+ "zaehlen dann nicht mehr als Fehler.\nAlles andere gilt weiter, und "\
		+ "die Gegner werden unveraendert streng gewuerfelt."
	_playtest_toggle.toggled.connect(func(pressed):
		GameState.ignore_build_limits = pressed
		_refresh_all())
	center.add_child(_playtest_toggle)
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

	# Kampfwert steht in der Ueberschriftzeile und nicht als eigener Absatz
	# weiter unten: die Spalte ist knapp, und die Zahl gehoert ohnehin zu den
	# Werten darunter.
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
	column.add_child(_weight_label)
	_weight_bar = ProgressBar.new()
	_weight_bar.custom_minimum_size = Vector2(0, 10)
	_weight_bar.show_percentage = false
	column.add_child(_weight_bar)

	_power_label = Label.new()
	column.add_child(_power_label)
	_power_bar = ProgressBar.new()
	_power_bar.custom_minimum_size = Vector2(0, 10)
	_power_bar.show_percentage = false
	column.add_child(_power_bar)

	column.add_child(_heading("Kann im Kampf"))
	_action_list = VBoxContainer.new()
	_action_list.add_theme_constant_override("separation", 2)
	column.add_child(_action_list)

	_problem_label = RichTextLabel.new()
	_problem_label.bbcode_enabled = true
	_problem_label.fit_content = true
	_problem_label.custom_minimum_size = Vector2(0, 76)
	column.add_child(_problem_label)

	_start_button = Button.new()
	_start_button.text = "Chaos-Virus starten"
	_start_button.custom_minimum_size = Vector2(0, 44)
	_start_button.pressed.connect(_start_battle)
	right.add_child(_start_button)
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
	_name_field.text = _build.display_name
	_refresh_library()
	_refresh_slots()
	_refresh_stats()
	_refresh_actions()
	_refresh_preview()
	_refresh_squad_bar()


func _refresh_direction_buttons() -> void:
	for button in _direction_buttons:
		button.button_pressed = button.get_meta("direction") == _facing


## Welche Slots dieser Aufbau hat -- die vier Sockel plus die equip_*-Anker
## seines Chassis. Genau wie im Kampf: die Slotzahl haengt am Chassis.
func _slots() -> Array[String]:
	var slots: Array[String] = ["body", "head", "feet", "core"]
	slots.append_array(_build.equip_slots())
	return slots


## Die Slotliste: was steckt wo, was nimmt der Slot an, und welcher ist
## angewaehlt.
##
## Mit Miniatur, weil "Ausruestung links: Orbit-Fokus" allein nicht sagt, ob
## das der leuchtende Ring oder der Stab ist. Der Aufbau ist eine Zeichnung,
## und eine Zeile Text ist die schlechtere Beschreibung davon.
func _refresh_slots() -> void:
	for child in _slot_list.get_children():
		child.queue_free()
	var chassis := _build.body()
	for slot in _slots():
		var part := _build.part_in(slot)
		var row := HBoxContainer.new()

		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = slot == _selected_slot
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 30)
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
			clear.tooltip_text = "Slot leeren"
			clear.pressed.connect(func():
				_build.slots.erase(slot)
				_after_change())
			row.add_child(clear)
		_slot_list.add_child(row)


## Was dieser Slot annimmt -- im Klartext und aus den Regeln des Chassis, nicht
## aus einer zweiten Liste hier.
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


func _class_label(mount_class: String) -> String:
	match mount_class:
		"light": return "leicht"
		"medium": return "mittel"
		_: return "schwer"


func _category_label(category: String) -> String:
	match category:
		"weapon": return "Waffe"
		"shield": return "Schild"
		"support": return "Support"
		_: return category


## Die Bibliothek: ALLE Teile, nach Bauteiltyp gruppiert.
##
## Was nicht passt, wird nicht weggelassen, sondern ausgegraut und begruendet.
## Wegzulassen liesse den Spieler raten, ob es das Teil nicht gibt oder ob es
## nur hier nicht hinein darf -- und die Frage "warum kann mein Strix die
## Belagerungskanone nicht" beantwortet nur die zweite Variante.
func _refresh_library() -> void:
	for child in _library.get_children():
		child.queue_free()

	for group in LIBRARY_GROUPS:
		var type: PartData.Type = group[0]
		var parts: Array = PartDB.of_type(type).filter(_matches_filter)
		if parts.is_empty():
			continue
		var header := _heading(group[1])
		header.custom_minimum_size = Vector2(0, 22)
		_library.add_child(header)
		for part in parts:
			_library.add_child(_library_row(part))


func _matches_filter(part: PartData) -> bool:
	if _filter == "":
		return true
	var haystack := "%s %s %s" % [part.code, part.display_name,
		" ".join(part.tags)]
	return _filter in haystack.to_lower()


func _library_row(part: PartData) -> Button:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, THUMB_SIZE + 6)
	button.toggle_mode = true

	var slot := _target_slot_for(part)
	var equipped: bool = slot != "" and _build.slots.get(slot, &"") == part.id
	# Ein Teil kann in mehreren Slots stecken (zwei Orbit-Fokusse). Angehakt
	# wird es dann trotzdem -- gefragt ist "ist das verbaut", nicht "wo".
	if not equipped:
		equipped = part.id in _build.slots.values()

	button.button_pressed = equipped
	button.text = "  %s  %s%s" % [part.code, part.display_name,
		"  ✓" if equipped else ""]
	button.tooltip_text = _part_tooltip(part)
	_set_thumbnail(button, part)

	if slot == "":
		# Kein Halter dieses Chassis nimmt das Teil. Anfassbar bleibt es
		# trotzdem: der Zeiger zeigt weiterhin Wirkung und Aussehen.
		button.disabled = true
		button.modulate = Color(0.55, 0.55, 0.6)
		button.tooltip_text = "%s\n\nPasst in keine Halterung von %s." % [
			button.tooltip_text,
			_build.body().display_name if _build.body() != null else "diesem Chassis"]
	else:
		button.pressed.connect(func():
			_selected_slot = slot
			_build.slots[slot] = part.id
			_after_change())

	button.mouse_entered.connect(func(): _set_hover(part, button))
	button.mouse_exited.connect(func(): _clear_hover())
	return button


func _set_thumbnail(button: Button, part: PartData) -> void:
	# Die Miniatur ist dasselbe Asset, aus dem gleich der Bot entsteht --
	# nicht ein zweites Vorschaubild, das irgendwann davon abweicht.
	# ``expand_icon`` skaliert die Textur auf die Knopfhoehe.
	var path: String = part.view(_facing).get("svg", "")
	if path != "" and ResourceLoader.exists(path):
		button.icon = load(path)
		button.expand_icon = true


## In welchen Slot wuerde dieses Teil gehen? Die Regel steht in DromeBuild --
## sie ist eine Aussage ueber den Aufbau, nicht ueber die Bedienung.
func _target_slot_for(part: PartData) -> String:
	return _build.slot_for(part, _selected_slot)


func _part_tooltip(part: PartData) -> String:
	var lines: Array[String] = [part.display_name, ""]
	for key in ["hp", "en_max", "en_regen", "spd", "mov", "atk", "def"]:
		var value: int = part.get(key)
		if value != 0:
			lines.append("%s %+d" % [key.to_upper(), value])
	if part.weight != 0:
		lines.append("Gewicht %d" % part.weight)
	if part.power_draw != 0:
		lines.append("Energiebedarf %d" % part.power_draw)
	if part.weight_capacity != 0:
		lines.append("Traglast %d" % part.weight_capacity)
	if part.power_output != 0:
		lines.append("Ausstoss %d" % part.power_output)
	if part.type == PartData.Type.EQUIPMENT:
		lines.append("Klasse: %s · %s" % [_class_label(part.mount_class),
			_category_label(part.category)])
	for flag in FLAG_LABEL:
		if part.get(flag):
			lines.append(FLAG_LABEL[flag])
	if part.action != null:
		lines.append("")
		lines.append(part.action.display_name)
		lines.append_array(part.action.description_lines())
	return "\n".join(lines)


# ---------------------------------------------------------------------------
# Die Vorschau beim Hovern
# ---------------------------------------------------------------------------

## Zeiger auf einem Bibliotheks-Teil: der Aufbau wird MIT diesem Teil gezeigt --
## in den Zahlen rechts, im Deltafeld direkt daneben und im Bild in der Mitte.
##
## Das Deltafeld ist der eigentliche Punkt: rechts stehen die Werte des
## Aufbaus, aber die Frage beim Bauen lautet nicht "wie viel habe ich", sondern
## "was aendert sich, wenn ich das nehme". Diese Antwort neben den Zeiger zu
## legen erspart den Kontrollblick nach rechts und zurueck.
func _set_hover(part: PartData, anchor: Control) -> void:
	var slot := _target_slot_for(part)
	var probe := _build.clone()
	if slot != "":
		probe.slots[slot] = part.id
		# Ein Chassiswechsel kann Ausruestungsslots wegnehmen. Was nicht mehr
		# passt, faellt ab -- sonst versprechen die Zahlen einen Aufbau, den es
		# so gar nicht geben kann.
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
	if slot == "":
		_delta_rows.add_child(_delta_line("passt in keine Halterung", COLOR_BAD))
	else:
		_delta_rows.add_child(_delta_line("kommt in: %s"
			% SLOT_LABEL.get(slot, slot), COLOR_MUTED))
		var replaced := _build.part_in(slot)
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

	# Traglast und Energie stehen immer da, auch unveraendert: sie sind die
	# beiden Grenzen, an denen ein Aufbau scheitert.
	_delta_rows.add_child(_delta_line("Gewicht  %d / %d → %d / %d"
		% [before["weight"], before["weight_capacity"],
			after["weight"], after["weight_capacity"]],
		COLOR_BAD if after["weight"] > after["weight_capacity"] else COLOR_MUTED))
	_delta_rows.add_child(_delta_line("Energie  %d / %d → %d / %d"
		% [before["power_draw"], before["power_output"],
			after["power_draw"], after["power_output"]],
		COLOR_BAD if after["power_draw"] > after["power_output"] else COLOR_MUTED))

	var problems := _hover_build.blocking_problems()
	if problems.is_empty():
		_delta_rows.add_child(_delta_line("Aufbau bliebe gueltig", COLOR_GOOD))
	else:
		for line in problems:
			_delta_rows.add_child(_delta_line("• %s" % line, COLOR_BAD))
	if GameState.ignore_build_limits and not _hover_build.budget_problems().is_empty():
		_delta_rows.add_child(_delta_line("Playtest: Grenze ueberschritten, "
			+ "aber erlaubt", COLOR_WARN))

	_delta_panel.visible = true
	# Erst nach dem Layout kennt das Feld seine Groesse.
	await get_tree().process_frame
	if not _delta_panel.visible or _hover_part != part:
		return
	var origin := anchor.get_global_rect()
	_delta_panel.position = Vector2(origin.end.x + 8,
		clampf(origin.position.y, 8.0, size.y - _delta_panel.size.y - 8.0))


func _delta_line(text: String, color: Color, font_size: int = 11) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	return label


## Alle Zahlenwerte, die im Deltafeld auftauchen duerfen -- die Kampfwerte aus
## STAT_GROUPS, in ihrer Reihenfolge.
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

	_meter(_weight_bar, _weight_label, "Gewicht / Traglast",
		base["weight"], base["weight_capacity"])
	_meter(_power_bar, _power_label, "Energiebedarf / Ausstoss",
		base["power_draw"], base["power_output"])

	var flags: Array[String] = []
	for flag in FLAG_LABEL:
		if base.get(flag, false):
			flags.append(FLAG_LABEL[flag])
	if base["drift_modifier"] != 0:
		flags.append("Gleitweite %+d" % base["drift_modifier"])

	_power_label_total.text = "Kampfwert %d" % int(round(_build.power_score()))

	var problems := _build.blocking_problems()
	var text := ""
	if not flags.is_empty():
		text += "[color=#8ab4d8]%s[/color]\n" % " · ".join(flags)
	# Im Playtest wird die ueberschrittene Grenze weiterhin GENANNT, nur nicht
	# mehr als Fehler gewertet -- und sie steht VOR dem Urteil, damit
	# "Aufbau ist gueltig" nicht ohne seine Einschraenkung dasteht. Ein Aufbau,
	# der stillschweigend ueber seiner Traglast liegt, waere im naechsten
	# Balancing-Durchgang nicht mehr erklaerbar.
	if GameState.ignore_build_limits:
		for line in _build.budget_problems():
			text += "[color=#ffb84d]• %s (Playtest: erlaubt)[/color]\n" % line
	if problems.is_empty():
		text += "[color=#6bd97a]Aufbau ist gueltig.[/color]"
	else:
		for line in problems:
			text += "[color=#ff6b6b]• %s[/color]\n" % line
	_problem_label.text = text

	_start_button.disabled = not _squad_is_ready()
	_start_button.text = "Chaos-Virus starten" if _squad_is_ready() \
		else "Squad unvollstaendig"


## Was dieser Aufbau im Kampf tun kann -- getrennt nach Angriff und Faehigkeit.
##
## Steht hier, weil es die Frage beantwortet, die die Werteliste nicht
## beantwortet: zwei Aufbauten mit identischen Zahlen koennen voellig
## verschiedene Dinge tun. Und weil hier sichtbar wird, dass zwei gleiche Teile
## EINE Aktion ergeben und nicht zwei -- dieselbe Liste, die auch der Kampf
## anzeigt (DromeBuild.actions()).
func _refresh_actions() -> void:
	for child in _action_list.get_children():
		child.queue_free()

	var any := false
	for category in [ActionData.Category.ATTACK, ActionData.Category.ABILITY]:
		for action in _build.actions_of(category):
			# Dasselbe Symbol wie im Kampf, hier aber NEBEN dem Namen und nicht
			# statt seiner: in der Werkstatt waehlt der Spieler Bauteile aus und
			# braucht ihre Namen. Das Symbol steht daneben, damit er es hier
			# lernt und im Kampf schon kennt.
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


## Ein Balken mit Klartext -- der Spieler soll sehen, um WIE VIEL er drueber
## ist, nicht nur dass er drueber ist.
func _meter(bar: ProgressBar, label: Label, title: String,
		value: int, limit: int) -> void:
	label.text = "%s   %d / %d" % [title, value, limit]
	bar.max_value = maxi(1, limit)
	bar.value = mini(value, bar.max_value)
	var over := value > limit
	# Im Playtest bleibt der Balken sichtbar ueber der Grenze, faerbt sich aber
	# nur warnend: die Zahl stimmt weiterhin, sie hindert nur nicht mehr.
	var color := COLOR_WARN if over and GameState.ignore_build_limits \
		else (COLOR_BAD if over else Color.WHITE)
	label.modulate = color
	bar.modulate = color if over else Color(0.35, 0.8, 0.95)


func _refresh_preview() -> void:
	DromeSprites.assemble(_preview_root,
		_hover_build if _hover_build != null else _build, _facing)


func _refresh_squad_bar() -> void:
	for child in _squad_bar.get_children():
		child.queue_free()
	for i in _squad.size():
		var build: DromeBuild = _squad[i]
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = i == _active_index
		var valid := build.is_valid()
		button.text = "%s%s" % [build.display_name, "" if valid else "  (!)"]
		button.modulate = Color.WHITE if valid else COLOR_BAD
		button.pressed.connect(func():
			_active_index = i
			_build = _squad[i]
			_clear_hover()
			_refresh_all())
		_squad_bar.add_child(button)

	var size_row := HBoxContainer.new()
	var minus := Button.new()
	minus.text = "−"
	minus.disabled = _squad.size() <= Config.get_int("squad_size_min", 1)
	minus.pressed.connect(func():
		_squad.resize(_squad.size() - 1)
		_active_index = mini(_active_index, _squad.size() - 1)
		_build = _squad[_active_index]
		_refresh_all())
	size_row.add_child(minus)
	var plus := Button.new()
	plus.text = "+"
	plus.disabled = _squad.size() >= Config.get_int("squad_size_max", 4)
	plus.pressed.connect(func():
		_squad.append(_starter_build(_squad.size()))
		_refresh_all())
	size_row.add_child(plus)
	_squad_bar.add_child(size_row)


func _squad_is_ready() -> bool:
	for build in _squad:
		if not build.is_valid():
			return false
	return not _squad.is_empty()


func _after_change() -> void:
	_clear_hover()
	# Slots koennen weggefallen sein (Chassiswechsel) -- und dann darf auch
	# die Auswahl nicht auf einem Slot stehen bleiben, den es nicht gibt.
	_build._drop_invalid_equipment()
	if _selected_slot not in _slots():
		_selected_slot = "body"
	_refresh_all()


# ---------------------------------------------------------------------------
# Uebergabe
# ---------------------------------------------------------------------------

func _persist() -> void:
	GameState.squad = _squad.duplicate()
	GameState.squad_size = _squad.size()
	GameState.save_squad()


func _save_and_go(scene: String) -> void:
	_persist()
	get_tree().change_scene_to_file(scene)


func _start_battle() -> void:
	if not _squad_is_ready():
		return
	_persist()
	if GameState.battle_seed == 0:
		GameState.new_seed()
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
