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

const PREVIEW_SCALE := 2.4
const DIRECTIONS := ["south", "west", "east", "north"]
const DIR_LABEL := {"south": "Sued", "west": "West", "east": "Ost", "north": "Nord"}

const SLOT_LABEL := {
	"body": "Chassis", "head": "Sensorik", "feet": "Antrieb", "core": "Kern",
	"equip_left": "Ausruestung links", "equip_right": "Ausruestung rechts",
	"equip_shoulder": "Schulterhalterung", "equip_center": "Zentralhalterung",
}

const STAT_ROWS := [
	["hp_max", "Integritaet"], ["en_max", "Energie"], ["en_regen", "EN-Regen"],
	["spd", "SPD"], ["mov", "MOV"], ["atk", "ATK"], ["def", "DEF"],
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

var _squad: Array = []
var _active_index: int = 0
var _build: DromeBuild
var _selected_slot: String = "body"
var _facing: String = "south"

## Aufbau, der beim Hovern ueber ein Bibliotheks-Teil entstuende. Nur Anzeige.
var _hover_build: DromeBuild = null
var _hover_slot: String = ""

var _preview_root: Node2D
var _library: VBoxContainer
var _slot_list: VBoxContainer
var _stat_list: VBoxContainer
var _problem_label: RichTextLabel
var _squad_bar: HBoxContainer
var _start_button: Button
var _weight_bar: ProgressBar
var _weight_label: Label
var _power_bar: ProgressBar
var _power_label: Label
var _name_field: LineEdit
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

	# --- links: Bibliothek ---------------------------------------------
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	columns.add_child(left)
	left.add_child(_heading("Bibliothek"))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(300, 0)
	left.add_child(scroll)
	_library = VBoxContainer.new()
	_library.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_library)

	# --- Mitte: Vorschau -----------------------------------------------
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(center)

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
			_refresh_direction_buttons())
		button.set_meta("direction", direction)
		_direction_buttons.append(button)
		top_row.add_child(button)

	var viewport := SubViewportContainer.new()
	viewport.custom_minimum_size = Vector2(520, 520)
	viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL | Control.SIZE_SHRINK_CENTER
	viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL | Control.SIZE_SHRINK_CENTER
	center.add_child(viewport)
	var sub := SubViewport.new()
	sub.size = Vector2i(520, 520)
	sub.transparent_bg = true
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.add_child(sub)
	_preview_root = Node2D.new()
	# Die Bauteile zeichnen in einem 128x128-Raum mit der Bodenraute um
	# (64, 96). Zentriert wird ueber genau diesen Punkt, damit der Bot beim
	# Richtungswechsel nicht springt.
	_preview_root.position = Vector2(sub.size) * 0.5 \
		- IsoView.SPRITE_ORIGIN * PREVIEW_SCALE
	_preview_root.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
	sub.add_child(_preview_root)

	_squad_bar = HBoxContainer.new()
	_squad_bar.add_theme_constant_override("separation", 8)
	center.add_child(_squad_bar)

	# --- rechts: Slots, Werte, Start -----------------------------------
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(330, 0)
	columns.add_child(right)

	right.add_child(_heading("Aufbau"))
	_slot_list = VBoxContainer.new()
	right.add_child(_slot_list)

	right.add_child(_heading("Kampfwerte"))
	_stat_list = VBoxContainer.new()
	right.add_child(_stat_list)

	_weight_label = Label.new()
	right.add_child(_weight_label)
	_weight_bar = ProgressBar.new()
	_weight_bar.custom_minimum_size = Vector2(0, 10)
	_weight_bar.show_percentage = false
	right.add_child(_weight_bar)

	_power_label = Label.new()
	right.add_child(_power_label)
	_power_bar = ProgressBar.new()
	_power_bar.custom_minimum_size = Vector2(0, 10)
	_power_bar.show_percentage = false
	right.add_child(_power_bar)

	_problem_label = RichTextLabel.new()
	_problem_label.bbcode_enabled = true
	_problem_label.fit_content = true
	_problem_label.custom_minimum_size = Vector2(0, 90)
	right.add_child(_problem_label)

	_start_button = Button.new()
	_start_button.text = "Chaos-Virus starten"
	_start_button.custom_minimum_size = Vector2(0, 44)
	_start_button.pressed.connect(_start_battle)
	right.add_child(_start_button)

	_refresh_direction_buttons()


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = Color(0.6, 0.8, 0.95)
	return label


# ---------------------------------------------------------------------------
# Anzeige
# ---------------------------------------------------------------------------

func _refresh_all() -> void:
	_name_field.text = _build.display_name
	_refresh_library()
	_refresh_slots()
	_refresh_stats()
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


func _refresh_slots() -> void:
	for child in _slot_list.get_children():
		child.queue_free()
	for slot in _slots():
		var part := _build.part_in(slot)
		var row := HBoxContainer.new()

		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = slot == _selected_slot
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s: %s" % [SLOT_LABEL.get(slot, slot),
			part.display_name if part != null else "— leer —"]
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


func _refresh_library() -> void:
	for child in _library.get_children():
		child.queue_free()

	for part in _candidates_for(_selected_slot):
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s  %s" % [part.code, part.display_name]
		button.tooltip_text = _part_tooltip(part)
		button.pressed.connect(func():
			_build.slots[_selected_slot] = part.id
			_after_change())
		# Delta beim Hovern: die Werte, wie sie MIT diesem Teil waeren.
		button.mouse_entered.connect(func(): _set_hover(part))
		button.mouse_exited.connect(func(): _clear_hover())
		_library.add_child(button)


## Was darf in diesen Slot? Fuer Ausruestung entscheidet die Slotregel des
## Chassis -- ein Sprinter traegt keine Belagerungskanone, und unpassende
## Teile tauchen hier gar nicht erst auf.
func _candidates_for(slot: String) -> Array:
	if slot.begins_with("equip_"):
		var chassis := _build.body()
		return PartDB.equipment_for(chassis, slot) if chassis != null else []
	match slot:
		"body": return PartDB.of_type(PartData.Type.BODY)
		"head": return PartDB.of_type(PartData.Type.HEAD)
		"feet": return PartDB.of_type(PartData.Type.FEET)
		"core": return PartDB.of_type(PartData.Type.CORE)
	return []


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
	for flag in FLAG_LABEL:
		if part.get(flag):
			lines.append(FLAG_LABEL[flag])
	if part.action != null:
		var action := part.action
		lines.append("")
		lines.append("%s: Reichweite %d, Kraft %d, EN %d"
			% [action.display_name, action.range_tiles, absi(action.power),
				action.en_cost])
		if action.requires_line_of_sight:
			lines.append("braucht Sichtlinie")
	return "\n".join(lines)


func _set_hover(part: PartData) -> void:
	var probe := _build.clone()
	probe.slots[_selected_slot] = part.id
	# Ein Chassiswechsel kann Ausruestungsslots wegnehmen. Was nicht mehr
	# passt, faellt ab -- sonst versprechen die Zahlen einen Aufbau, den es
	# so gar nicht geben kann.
	probe._drop_invalid_equipment()
	_hover_build = probe
	_hover_slot = _selected_slot
	_refresh_stats()


func _clear_hover() -> void:
	if _hover_build == null:
		return
	_hover_build = null
	_hover_slot = ""
	_refresh_stats()


func _refresh_stats() -> void:
	for child in _stat_list.get_children():
		child.queue_free()

	var base := _build.stats()
	var preview: Dictionary = _hover_build.stats() if _hover_build != null else {}

	for row in STAT_ROWS:
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

	var problems := _build.validate()
	var text := ""
	if not flags.is_empty():
		text += "[color=#8ab4d8]%s[/color]\n\n" % " · ".join(flags)
	text += "Threat Score %d\n\n" % int(round(_build.threat_score()))
	if problems.is_empty():
		text += "[color=#6bd97a]Aufbau ist gueltig.[/color]"
	else:
		for line in problems:
			text += "[color=#ff6b6b]• %s[/color]\n" % line
	_problem_label.text = text

	_start_button.disabled = not _squad_is_ready()
	_start_button.text = "Chaos-Virus starten" if _squad_is_ready() \
		else "Squad unvollstaendig"


## Ein Balken mit Klartext -- der Spieler soll sehen, um WIE VIEL er drueber
## ist, nicht nur dass er drueber ist.
func _meter(bar: ProgressBar, label: Label, title: String,
		value: int, limit: int) -> void:
	label.text = "%s   %d / %d" % [title, value, limit]
	bar.max_value = maxi(1, limit)
	bar.value = mini(value, bar.max_value)
	var over := value > limit
	label.modulate = COLOR_BAD if over else Color.WHITE
	bar.modulate = COLOR_BAD if over else Color(0.35, 0.8, 0.95)


func _refresh_preview() -> void:
	DromeSprites.assemble(_preview_root, _build, _facing)


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
