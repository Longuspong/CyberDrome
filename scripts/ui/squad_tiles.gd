class_name SquadTiles
extends HBoxContainer

## Die DROME-Kacheln unter der Zugreihenfolge: eine Kachel je eigenem DROME.
##
## Kopf, Name, Tempo und die genauen Zahlen fuer Integritaet und Schild -- das,
## was ueber der Figur keinen Platz mehr hat. Ueber der Figur steht nur noch
## der eine Lebensbalken (BattleView.UnitBadgePainter); im Nahkampf schoben
## sich vorher drei Badges mit Namen und Zahlen uebereinander.
##
## Darunter je Waffe der Zaehler bis zur Faehigkeit ("Streusalve 2/3") --
## damit man sieht, wann sie kommt. Eine zerstoerte Kachel wird abgedunkelt.
## Die Kacheln teilen sich die Breite: im Hochformat (ca. 400 Pixel) passen
## vier nebeneinander, mehr hat ein Squad nicht.

## Antippen einer Kachel: die Kamera faehrt zu diesem DROME.
signal tile_pressed(unit)

const HEAD_EDGE := 34.0
const BAR_HEIGHT := 5.0

var _tiles: Dictionary = {}       # unit_id -> { root, style, hp_bar, sh_bar, hp_label, sh_label, spd }


## Einmal beim Aufbau: legt die Kacheln fuer ``units`` an.
func setup(units: Array) -> void:
	add_theme_constant_override("separation", 4)
	for child in get_children():
		child.queue_free()
	_tiles.clear()
	for unit in units:
		_add_tile(unit)


func _add_tile(unit: Unit) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiKit.CARD, 0.92)
	style.border_color = UiKit.CARD_LINE
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 3
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton and event.pressed) \
				or (event is InputEventScreenTouch and event.pressed):
			tile_pressed.emit(unit))
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 3)
	head_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head_row)
	var head := TextureRect.new()
	head.texture = UiKit.part_texture(unit.build.part_in("head") if unit.build else null)
	head.custom_minimum_size = Vector2(HEAD_EDGE, HEAD_EDGE)
	head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_row.add_child(head)

	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override("separation", -2)
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_row.add_child(name_box)
	var name_label := _small(unit.display_name, 13, Color.WHITE)
	name_label.clip_text = true
	name_box.add_child(name_label)
	var spd := _small("", 12, UiKit.WARN)
	name_box.add_child(spd)

	var hp_bar := _bar(box, Teams.hp_color(true))
	var hp_label := _small("", 12, Color(0.86, 0.95, 0.88))
	box.add_child(hp_label)
	var sh_bar := _bar(box, Teams.shield_color(true))
	var sh_label := _small("", 12, Color(0.80, 0.88, 1.0))
	box.add_child(sh_label)

	var skills := _small("", 11, Color(1.0, 0.86, 0.4))
	box.add_child(skills)

	_tiles[unit.unit_id] = {"root": panel, "style": style, "hp_bar": hp_bar,
		"sh_bar": sh_bar, "hp_label": hp_label, "sh_label": sh_label, "spd": spd,
		"skills": skills}


func _small(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.modulate = color
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _bar(parent: Control, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.03, 0.04, 0.06)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


## Nach jeder Aenderung: Zahlen, Balken, Faehigkeits-Zaehler, zerstoerte
## Kacheln.
func refresh(units: Array) -> void:
	for unit in units:
		if not _tiles.has(unit.unit_id):
			continue
		var tile: Dictionary = _tiles[unit.unit_id]
		var hp_max: int = maxi(1, unit.stat("hp_max"))
		var sh_max: int = unit.shield_max()
		var hp_bar: ProgressBar = tile["hp_bar"]
		hp_bar.max_value = hp_max
		hp_bar.value = maxi(0, unit.hp)
		var sh_bar: ProgressBar = tile["sh_bar"]
		sh_bar.max_value = maxi(1, sh_max)
		sh_bar.value = maxi(0, unit.shield)
		(tile["hp_label"] as Label).text = "HP %d/%d" % [maxi(0, unit.hp), hp_max]
		(tile["sh_label"] as Label).text = "Schild %d/%d" % [maxi(0, unit.shield), sh_max]
		(tile["spd"] as Label).text = "SPD %d" % unit.spd()
		(tile["skills"] as Label).text = skill_line(unit)
		(tile["root"] as Control).modulate = Color.WHITE if unit.is_alive() \
			else Color(0.45, 0.45, 0.5, 0.8)


## "Streusalve 2/3": je Waffe mit Faehigkeit, der wievielte Schuss als
## naechstes kommt. Bei 3/3 ist der naechste Schuss die Faehigkeit. Kurz
## gehalten -- die Kachel ist schmal.
static func skill_line(unit: Unit) -> String:
	var parts: Array[String] = []
	for mount in unit.mounts:
		var ability = mount.get("ability")
		if ability == null:
			continue
		parts.append("%s %d/%d" % [_short((ability as ActionData).display_name),
			int(mount["count"]) + 1, int((ability as ActionData).trigger_every)])
	return "  ".join(parts)


static func _short(name: String) -> String:
	return name if name.length() <= 9 else name.substr(0, 8) + "."
