class_name SquadTiles
extends GridContainer

## Die DROME-Kacheln oben im Kampf: eine Kachel je eigenem DROME.
##
## Seit 7. Nov. 2026 (mit dem Spieler abgesprochen) nur Symbol und Zahl, in
## Mindestschrift 16: Kopf, Herz mit Integritaet, Schild mit Schild, darunter
## je Faehigkeit eine kleine Takt-Leiste -- dieselbe wie ueber der Figur.
## Name und Tempo per langem Druck (tooltip_text). Vorher standen Name, SPD
## und "1/3 Doppelsc." in 11-13 px da und mussten gekuerzt werden.
##
## Hochformat: vier Kacheln nebeneinander. Querformat: eine Spalte am linken
## Rand (``set_vertical``), damit oben mehr Spielfeld frei bleibt.
## Eine zerstoerte Kachel wird abgedunkelt.

## Antippen einer Kachel: die Kamera faehrt zu diesem DROME.
signal tile_pressed(unit)

const HEAD_EDGE := 26.0
const ICON_EDGE := 16.0
const BAR_HEIGHT := 5.0
const FONT := 16

var _tiles: Dictionary = {}       # unit_id -> { root, hp_bar, sh_bar, hp_label, sh_label, takt }


## Einmal beim Aufbau: legt die Kacheln fuer ``units`` an.
func setup(units: Array) -> void:
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 4)
	columns = maxi(1, units.size())
	for child in get_children():
		child.queue_free()
	_tiles.clear()
	for unit in units:
		_add_tile(unit)


## Querformat: eine Spalte. Hochformat: alle nebeneinander.
func set_vertical(vertical: bool) -> void:
	columns = 1 if vertical else maxi(1, _tiles.size())


func _add_tile(unit: Unit) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.tooltip_text = "%s  ·  SPD %d" % [unit.display_name, unit.spd()]
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
	var hp_label := _value(head_row, "hp")

	var hp_bar := _bar(box, Teams.hp_color(true))
	var sh_row := HBoxContainer.new()
	sh_row.add_theme_constant_override("separation", 3)
	sh_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sh_row)
	var sh_label := _value(sh_row, "shield")
	var sh_bar := _bar(box, Teams.shield_color(true))

	var takt := TaktBars.new()
	box.add_child(takt)

	_tiles[unit.unit_id] = {"root": panel, "hp_bar": hp_bar, "sh_bar": sh_bar,
		"hp_label": hp_label, "sh_label": sh_label, "takt": takt}


## Symbol + Zahl, die Zahl schneidet ab statt die Kachel zu verbreitern.
func _value(row: HBoxContainer, kind: String) -> Label:
	var icon := StatIcon.new(kind, ICON_EDGE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", FONT)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
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


## Nach jeder Aenderung: Zahlen, Balken, Takt, zerstoerte Kacheln.
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
		(tile["hp_label"] as Label).text = str(maxi(0, unit.hp))
		(tile["sh_label"] as Label).text = str(maxi(0, unit.shield))
		(tile["takt"] as TaktBars).set_bars(unit.takt_bars() if unit.is_alive() else [])
		(tile["root"] as Control).modulate = Color.WHITE if unit.is_alive() \
			else Color(0.45, 0.45, 0.5, 0.8)


## Die kleinen Takt-Leisten in der Kachel -- dieselbe Darstellung wie unter
## dem Lebensbalken (Abschnitte je Angriff, Zeit in halben Sekunden).
class TaktBars extends Control:
	const ROW := 4.0
	const GAP := 2.0
	var bars: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_bars(value: Array) -> void:
		bars = value
		custom_minimum_size = Vector2(0, maxf(0.0, float(bars.size()) * (ROW + GAP) - GAP))
		queue_redraw()

	func _draw() -> void:
		var y := 0.0
		for bar in bars:
			var color := Color(1.0, 1.0, 0.85) if bar.get("ready", false) else Color(1.0, 0.82, 0.35)
			draw_rect(Rect2(0, y, size.x, ROW), Color(0.03, 0.04, 0.06))
			if bar["kind"] == "hits":
				var n: int = maxi(1, int(bar["segments"]))
				var piece := size.x / float(n)
				for i in n:
					if i < int(bar["filled"]):
						draw_rect(Rect2(piece * float(i), y, piece - 1.0, ROW), color)
			else:
				draw_rect(Rect2(0, y, size.x * float(bar["fill"]), ROW), color)
			y += ROW + GAP
