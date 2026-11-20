class_name CacheOpener
extends Control

## Der Bildschirm "Cache oeffnen" (Entwurf 15. Nov. 2026, Bilder 18-22): die
## Kiste der Fraktion gross vor Lichtstrahlen, Glitch-Name, TAP-Knopf.
## Antippen hebt den Deckel.
##
## Seit 20. Nov. 2026 echt (CHARGER_KONZEPT.md 5): vier Wuerfe nach der Tabelle
## (Roster.open_cache), alles wird gutgeschrieben. Design-Canvas "Cache oeffnen":
## je Wurf fliegt ein Energieball in der Farbe des Gegenstands aus der Oeffnung
## in sein Feld und platzt dort auf. Der Neon Cache ist eine echte 3D-Szene
## (Shader assets/shaders/neon_cache.gdshader); die anderen bleiben Zeichnung.

signal finished

var _kind := "city"
var _art: Control
var _neon: ColorRect
var _results: Array = []
var _cards: Array = []
var _time := 0.0
var _opened := false
var _tap_box: Control
var _result: Control


## Legt den Bildschirm ueber ``host`` (ganze Flaeche) und gibt ihn zurueck.
static func show_over(host: Control, cache_kind: String) -> CacheOpener:
	var opener := CacheOpener.new()
	opener._kind = cache_kind
	host.add_child(opener)
	return opener


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(Arcade.moving())

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, UiKit.PAD)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", UiKit.PAD)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)
	var back := Arcade.BackButton.new()
	back.tooltip_text = "Zurück"
	back.pressed.connect(_close)
	top.add_child(back)
	var push := Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(push)
	var count := int(GameState.roster.caches.get(_kind, 0))
	var short := RunState.cache_name(StringName(_kind)).get_slice(" ", 0).to_upper()
	var tag := Arcade.tilt(Arcade.tag("%s · %d IM LAGER" % [short, count], 12, 0.0), 2.0)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(tag)

	var stage := CenterContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(stage)
	if _kind == "city":
		_neon = ColorRect.new()
		_neon.custom_minimum_size = Vector2(300, 210)
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/shaders/neon_cache.gdshader")
		mat.set_shader_parameter("res", Vector2(300, 210))
		mat.set_shader_parameter("still", 0.0 if Arcade.moving() else 1.0)
		_neon.material = mat
		_neon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_art = _neon
	else:
		_art = CacheArt.new(_kind, 230.0)
	stage.add_child(_art)

	var name := Arcade.GlitchLogo.new(RunState.cache_name(StringName(_kind)).to_upper(), 30, 3.6, [
		[0.0, Vector2(-2, 0), Vector2(2, 0)],
		[0.9, Vector2(-5, 2), Vector2(5, -2)],
		[0.93, Vector2(4, -1), Vector2(-4, 1)]], 2.0)
	var title := Arcade.tilt(name, -2.0)
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(title)
	var sub := Arcade.label(_origin(), 14, Arcade.TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	_tap_box = VBoxContainer.new()
	(_tap_box as VBoxContainer).add_theme_constant_override("separation", 4)
	box.add_child(_tap_box)
	var badge := Arcade.TapBadge.new()
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tap_box.add_child(badge)
	var hint := Arcade.label("TIPPEN ZUM ÖFFNEN", 16, Arcade.WHITE, "bold", 0.2)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tap_box.add_child(hint)


## "Neon Ninja's · Neon City" aus regions.json; Hipstar gibt es noch nicht.
func _origin() -> String:
	if _kind == "hip":
		return "Hipstar Hackers · Dachterrassen"
	var region := TerrainDB.get_region(StringName(_kind))
	if region == null:
		return ""
	return "%s · %s" % [str(region.faction.get("name", "")), region.display_name]


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Dunkler Grund, Punktraster und Lichtstrahlen in der Farbe der Fraktion.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Arcade.NIGHT)
	var color := CacheArt.color(_kind)
	var center := Vector2(size.x * 0.5, size.y * 0.4)
	var turn := _time * 0.12
	for i in 12:
		var a := turn + TAU * float(i) / 12.0
		var spread := 0.09
		var far := size.length()
		draw_colored_polygon(PackedVector2Array([center,
			center + Vector2(cos(a - spread), sin(a - spread)) * far,
			center + Vector2(cos(a + spread), sin(a + spread)) * far]),
			Color(color, 0.07 + (0.06 if _opened else 0.0)))
	for y in range(7, int(size.y), 14):
		for x in range(7, int(size.x), 14):
			draw_circle(Vector2(x, y), 1.2, Color(Arcade.DOTS, 0.12))


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if pressed and not _opened:
		accept_event()
		_open()


func _open() -> void:
	_opened = true
	Accessibility.vibrate(80, true)
	_tap_box.visible = false
	_results = GameState.roster.open_cache(_kind)
	GameState.save_roster()
	if Arcade.moving() and is_inside_tree():
		var tween := create_tween()
		tween.tween_method(_set_open, 0.0, 1.0, 1.4 if _neon != null else 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_set_open(1.0)
	var holder := _tap_box.get_parent() as Control
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	holder.add_child(grid)
	if _results.is_empty():
		holder.add_child(UiKit.label("Kein Cache mehr im Lager.", 14, UiKit.MUTED))
	for i in _results.size():
		var card := _ResultCard.new(i + 1, _results[i])
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		_cards.append(card)
	var done := UiKit.button("Alles einsammeln", true)
	done.pressed.connect(_close)
	holder.add_child(done)
	# Die Baelle fliegen, sobald die Karten ihre Lage haben.
	_fly.call_deferred()


func _set_open(value: float) -> void:
	if _neon != null:
		(_neon.material as ShaderMaterial).set_shader_parameter("open", value)
	elif _art is CacheArt:
		(_art as CacheArt).open = value


func _fly() -> void:
	await get_tree().process_frame
	var from := _art.global_position + _art.size * Vector2(0.5, 0.45) - global_position
	for i in _cards.size():
		var card: _ResultCard = _cards[i]
		if not Arcade.moving():
			card.reveal()
			continue
		var ball := _Ball.new(card.color())
		add_child(ball)
		ball.position = from
		var to: Vector2 = card.icon_center() - global_position
		var mid := (from + to) * 0.5 + Vector2((to.x - from.x) * 0.3, -60)
		var tween := create_tween()
		tween.tween_interval(0.5 + 0.35 * i)
		tween.tween_method(func(t: float):
			ball.position = from.lerp(mid, t).lerp(mid.lerp(to, t), t), 0.0, 1.0, 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(func():
			Accessibility.vibrate(20)
			card.reveal())
		tween.tween_property(ball, "burst", 1.0, 0.25)
		tween.tween_callback(ball.queue_free)


func _close() -> void:
	finished.emit()
	queue_free()


## Ein Ergebnis: Feld mit Wurf-Nummer, Gegenstand erscheint mit Aufploppen.
class _ResultCard extends PanelContainer:
	var result: Dictionary
	var _icon_box: Control
	var _content: Control

	func _init(roll: int, item: Dictionary) -> void:
		result = item
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Arcade.VIOLET, 0.94)
		style.border_color = Color("#6e5ab4")
		style.set_border_width_all(2)
		style.set_content_margin_all(8)
		add_theme_stylebox_override("panel", style)
		custom_minimum_size = Vector2(0, 86)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		add_child(row)
		var num := Arcade.label(str(roll), 12, Arcade.MUTED, "display")
		num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(num)
		_icon_box = CenterContainer.new()
		_icon_box.custom_minimum_size = Vector2(56, 56)
		row.add_child(_icon_box)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var kind_label := Arcade.label(_kind_text(), 10, Arcade.MUTED, "bold", 0.12)
		kind_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		kind_label.custom_minimum_size.x = 40
		text.add_child(kind_label)
		var name := Arcade.label(_name(), 14, color(), "display")
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name.custom_minimum_size.x = 40
		text.add_child(name)
		_icon_box.add_child(_picture())
		_content = row
		_icon_box.modulate.a = 0.0
		text.modulate.a = 0.0

	func color() -> Color:
		match str(result.get("kind", "")):
			"phase": return Charger.element_color(str(result.get("element", "")))
			"blank": return Arcade.YELLOW
			"coins": return Arcade.WHITE
			"faction_drome", "faction_core": return Arcade.MAGENTA
		return Color("#5cf2a2")

	func _kind_text() -> String:
		match str(result.get("kind", "")):
			"phase": return "ENERGY PHASE"
			"blank": return "CHARGER"
			"coins": return "COIN"
			"faction_drome": return "FRAKTIONS-DROME"
			"faction_core": return "FRAKTIONSKERN"
		return Roster.kit_name().to_upper()

	func _name() -> String:
		match str(result.get("kind", "")):
			"phase": return Charger.element_name(str(result.get("element", ""))).to_upper()
			"blank": return "ROHLING"
			"coins": return "%d COIN" % int(result.get("amount", 0))
			"faction_drome": return str(result.get("name", "DROME")).to_upper()
			"faction_core": return Roster.core_name(str(result.get("faction", ""))).to_upper()
		return "+1"

	func _picture() -> Control:
		match str(result.get("kind", "")):
			"phase": return PhaseGem.new(str(result.get("element", "")), 52)
			"blank": return UiIcon.rect("charger", 44, Arcade.YELLOW)
			"coins": return UiIcon.rect("coin", 40, Arcade.YELLOW)
			"faction_drome", "faction_core": return UiIcon.rect("material", 40, Arcade.MAGENTA)
		return UiIcon.rect("kit", 40, Color("#5cf2a2"))

	func icon_center() -> Vector2:
		return _icon_box.global_position + _icon_box.size * 0.5

	func reveal() -> void:
		for child in _content.get_children():
			child.modulate.a = 1.0
		(get_theme_stylebox("panel") as StyleBoxFlat).border_color = color()
		if Arcade.moving() and is_inside_tree():
			_icon_box.pivot_offset = _icon_box.size * 0.5
			_icon_box.scale = Vector2(0.5, 0.5)
			create_tween().tween_property(_icon_box, "scale", Vector2.ONE, 0.25) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Ein Energieball: heller Kern, Ring in der Farbe, platzt mit ``burst``.
class _Ball extends Control:
	var tint := Color.WHITE
	var burst := 0.0:
		set(value):
			burst = value
			queue_redraw()

	func _init(color: Color) -> void:
		tint = color
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := 9.0 * (1.0 + burst * 2.0)
		var a := 1.0 - burst
		draw_circle(Vector2.ZERO, r * 2.2, Color(tint, 0.18 * a))
		draw_circle(Vector2.ZERO, r * 1.4, Color(tint, 0.45 * a))
		draw_circle(Vector2.ZERO, r, Color(Color.WHITE.lerp(tint, 0.3), a))
