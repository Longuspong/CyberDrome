extends Control

## Das Inventar: alle besessenen Teile in Kacheln, sortierbar nach Kategorie,
## mit Werten beim Ueberfahren.
##
## Quelle ist der Besitz (GameState.roster) -- dieselbe Schicht wie die Garage,
## nur hier vollstaendig statt nur die freien Teile. Ein Teil steht als EINE
## Kachel mit seiner Stueckzahl; die Werte kommen aus PartData, damit hier keine
## zweite Wahrheit ueber ein Bauteil entsteht.
##
## Reine Anzeige: das Inventar baut nichts um und schickt niemanden ins Gefecht.
## Der Umbau bleibt die Werkstatt, die Auswahl die Garage.

const COLOR_HEADING := Color(0.6, 0.8, 0.95)
const COLOR_MUTED := Color(0.62, 0.66, 0.72)
const COLOR_GOOD := Color(0.42, 0.85, 0.48)
const TILE := Vector2(150, 168)
const PREVIEW := 96

## Die Filter: Beschriftung -> Praedikat auf ein PartData. "Alle" hat keins.
var _filters: Array = []
var _active_filter: int = 0

var _grid: GridContainer
var _detail: VBoxContainer
var _tabs: HBoxContainer
var _empty_hint: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_filters = [
		{"label": "Alle", "match": func(_p): return true},
		{"label": "Chassis", "match": func(p): return p.type == PartData.Type.BODY},
		{"label": "Waffen", "match": func(p): return _is_equipment(p) and p.category == "weapon"},
		{"label": "Gadgets", "match": func(p): return _is_equipment(p) and p.category != "weapon"},
		{"label": "Kerne", "match": func(p): return p.type == PartData.Type.CORE},
	]
	_build_ui()
	_refresh()


static func _is_equipment(part: PartData) -> bool:
	return part.type == PartData.Type.EQUIPMENT


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# --- Kopfzeile: Zurueck, Titel, Tabs ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	root.add_child(header)

	var back := Button.new()
	back.text = "< Menue"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	header.add_child(back)

	var title := Label.new()
	title.text = "INVENTAR"
	title.add_theme_font_size_override("font_size", 26)
	title.modulate = COLOR_HEADING
	header.add_child(title)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.alignment = BoxContainer.ALIGNMENT_END
	header.add_child(_tabs)
	for i in _filters.size():
		var tab := Button.new()
		tab.text = _filters[i]["label"]
		tab.toggle_mode = true
		tab.pressed.connect(func(): _set_filter(i))
		_tabs.add_child(tab)

	# --- Hauptbereich: Kachelraster links, Werte rechts ---
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	_empty_hint = Label.new()
	_empty_hint.text = "Nichts in dieser Kategorie."
	_empty_hint.modulate = COLOR_MUTED
	_empty_hint.hide()
	_grid.add_child(_empty_hint)

	# Werte-Panel rechts
	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(280, 0)
	detail_panel.add_theme_stylebox_override("panel", _panel_style(false))
	body.add_child(detail_panel)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 4)
	detail_panel.add_child(_detail)
	_show_detail(null)


func _set_filter(index: int) -> void:
	_active_filter = index
	_refresh()


func _refresh() -> void:
	for i in _tabs.get_child_count():
		(_tabs.get_child(i) as Button).button_pressed = (i == _active_filter)

	for child in _grid.get_children():
		if child != _empty_hint:
			child.queue_free()

	var predicate: Callable = _filters[_active_filter]["match"]
	var any := false
	for part in _owned_parts():
		if not predicate.call(part):
			continue
		any = true
		_grid.add_child(_part_tile(part))
	_empty_hint.visible = not any


## Die besessenen Teil-TYPEN, sortiert -- Chassis, dann Kerne, dann Ausruestung,
## innerhalb nach Code. Jeder Typ EINMAL, mit seiner Stueckzahl.
func _owned_parts() -> Array:
	var order := [PartData.Type.BODY, PartData.Type.CORE, PartData.Type.EQUIPMENT]
	var out: Array = []
	for type in order:
		for part_id in GameState.roster.owned_part_ids(type):
			var part := PartDB.get_part(part_id)
			if part != null:
				out.append(part)
	return out


func _part_tile(part: PartData) -> Control:
	var count := GameState.roster.total_count(part.id)
	var free := GameState.roster.free_count(part.id)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = TILE
	panel.add_theme_stylebox_override("panel", _panel_style(false))
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var image := _part_image(part)
	box.add_child(image)

	var name_label := Label.new()
	name_label.text = part.display_name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)

	var meta := Label.new()
	meta.text = "×%d  ·  %d frei" % [count, free] if count > 1 else "%d frei" % free
	meta.add_theme_font_size_override("font_size", 10)
	meta.modulate = COLOR_MUTED
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(meta)

	# Werte beim Ueberfahren -- und ein hervorgehobener Rahmen, damit klar ist,
	# welche Kachel das Panel gerade zeigt.
	panel.mouse_entered.connect(func():
		panel.add_theme_stylebox_override("panel", _panel_style(true))
		_show_detail(part))
	panel.mouse_exited.connect(func():
		panel.add_theme_stylebox_override("panel", _panel_style(false)))
	return panel


## Das Teilbild als Textur aus der Suedansicht -- dieselbe Grafik wie im Kampf.
func _part_image(part: PartData) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(TILE.x - 20, PREVIEW)
	var view := part.view("south")
	var path := str(view.get("svg", ""))
	if path != "" and ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			var rect := TextureRect.new()
			rect.texture = tex
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			holder.add_child(rect)
	return holder


func _show_detail(part: PartData) -> void:
	for child in _detail.get_children():
		child.queue_free()

	if part == null:
		var hint := Label.new()
		hint.text = "Fahre ueber ein Teil,\num seine Werte zu sehen."
		hint.modulate = COLOR_MUTED
		_detail.add_child(hint)
		return

	var name_label := Label.new()
	name_label.text = part.display_name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.modulate = COLOR_HEADING
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(name_label)

	var kind := Label.new()
	kind.text = "%s  ·  %s" % [_type_label(part.type), part.code]
	kind.add_theme_font_size_override("font_size", 11)
	kind.modulate = COLOR_MUTED
	_detail.add_child(kind)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	_detail.add_child(spacer)

	for line in _stat_lines(part):
		var row := Label.new()
		row.text = line
		row.add_theme_font_size_override("font_size", 13)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(row)


## Die Werte eines Teils in Klartext -- je Typ das, was fuer den Bau zaehlt.
## Alle Zahlen kommen direkt aus PartData; die Aktionen aus ihrer eigenen
## Beschreibung (ActionData.description_lines), damit hier keine zweite Wahrheit
## ueber eine Aktion steht.
func _stat_lines(part: PartData) -> Array[String]:
	var lines: Array[String] = []
	match part.type:
		PartData.Type.BODY:
			_add(lines, "Integritaet", part.hp)
			_add(lines, "Energieschild", part.shield)
			_add(lines, "Panzerung", part.def)
			_add_signed(lines, "Tempo", part.spd)
			_add_signed(lines, "Move", part.mov)
			_add(lines, "Traglast", part.weight_capacity)
			lines.append("Ausruestungsslots: %d" % part.equip_slots().size())
		PartData.Type.CORE:
			_add(lines, "Energie", part.en_max)
			_add(lines, "Energie-Regen", part.en_regen)
			_add(lines, "Schildregen", part.shield_regen)
			if part.shield_bonus != 0.0:
				lines.append("Schildbonus: +%d%%" % int(round(part.shield_bonus * 100.0)))
			_add(lines, "Ausstoss", part.power_output)
			_add(lines, "Gewicht", part.weight)
			_add_signed(lines, "ATK", part.atk)
		_:
			lines.append("Bauart: %s  ·  %s" % [
				_mount_label(part.mount_class), _category_label(part.category)])
			_add(lines, "Gewicht", part.weight)
			_add(lines, "Energiebedarf", part.power_draw)
			_add(lines, "Panzerung", part.def)
			_add_signed(lines, "ATK", part.atk)
			_add(lines, "Energieschild", part.shield)
			if part.hp_regen_pct > 0:
				lines.append("Selbstreparatur: %d%% / Zug" % part.hp_regen_pct)
			if part.aggro_bonus > 0:
				lines.append("Aggro: +%d" % part.aggro_bonus)
			if part.actions.is_empty():
				lines.append("Passiv -- keine Aktion.")
			for action in part.actions:
				lines.append("")
				lines.append("• %s" % action.display_name)
				for detail in action.description_lines():
					lines.append("   %s" % detail)
	if lines.is_empty():
		lines.append("Keine besonderen Werte.")
	return lines


func _add(lines: Array[String], label: String, value: int) -> void:
	if value != 0:
		lines.append("%s: %d" % [label, value])


func _add_signed(lines: Array[String], label: String, value: int) -> void:
	if value != 0:
		lines.append("%s: %+d" % [label, value])


func _type_label(type: int) -> String:
	match type:
		PartData.Type.BODY: return "Chassis"
		PartData.Type.CORE: return "Kern"
		PartData.Type.FEET: return "Antrieb"
		PartData.Type.HEAD: return "Sensorik"
		_: return "Ausruestung"


func _category_label(category: String) -> String:
	match category:
		"weapon": return "Waffe"
		"shield": return "Schild"
		"support": return "Support"
		_: return category


func _mount_label(mount_class: String) -> String:
	match mount_class:
		"light": return "leicht"
		"medium": return "mittel"
		"heavy": return "schwer"
		_: return mount_class


func _panel_style(highlight: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.17)
	style.border_color = COLOR_HEADING if highlight else Color(0.24, 0.28, 0.35)
	style.set_border_width_all(2 if highlight else 1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
