class_name CacheOpener
extends Control

## Der Bildschirm "Cache oeffnen" (Entwurf 15. Nov. 2026, Bilder 18-22): die
## Kiste der Fraktion gross vor Lichtstrahlen, Glitch-Name, TAP-Knopf.
##
## Seit 20. Nov. 2026 echt (CHARGER_KONZEPT.md 5): vier Wuerfe nach der Tabelle
## (Roster.open_cache), alles wird gutgeschrieben. Je Wurf fliegt ein
## Energieball in der Farbe des Gegenstands aus der Oeffnung in sein Feld.
##
## Seit 21. Nov. 2026 (Wunsch des Spielers, Design-Canvas "Cache oeffnen ·
## Glitch-Animation") ist der Neon Cache wieder die Zeichnung wie die anderen
## (der 3D-Shader passte nicht zum Stil und ruckelte), und das Oeffnen ist eine
## kurze Abfolge im Glitch-Stil:
##
##   1 Ruhe         Kiste schwebt, Strahlen drehen langsam, TAP pulsiert
##   2 Anspannen    0,00-0,45 s  Wackeln immer schneller, Kiste blaeht sich auf
##   3 Glitch-Riss  0,45-0,80 s  Cyan/Magenta springen heraus, Streifen rutschen
##   4 Knall        0,80-1,10 s  Blitz, Deckel springt ab, Sechseck-Ring, Funken
##   5 Beute        ab 1,10 s    Energiebaelle fliegen in ihre Felder
##
## Gegen das Ruckeln wird nichts je Bild neu gezeichnet: Grund und Strahlen
## stehen fest, bewegt werden nur Lage, Drehung, Groesse und Deckkraft fertiger
## Bilder. Mit "Bewegung reduzieren" oeffnet die Kiste sofort.

signal finished

const WIND_UP := 0.45
const GLITCH_AT := [0.45, 0.57, 0.69]
const BANG := 0.8
const LOOT := 1.1
const RAY_SPEED := 0.12

var _kind := "city"
var _art: CacheArt
var _ghosts: Array[CacheArt] = []
var _slices: Array[Control] = []
var _rig: Control
var _rays: _Rays
var _flash: ColorRect
var _results: Array = []
var _cards: Array = []
var _time := 0.0
var _opened := false
var _tap_box: Control
var _rng := RandomNumberGenerator.new()


## Legt den Bildschirm ueber ``host`` (ganze Flaeche) und gibt ihn zurueck.
static func show_over(host: Control, cache_kind: String) -> CacheOpener:
	var opener := CacheOpener.new()
	opener._kind = cache_kind
	host.add_child(opener)
	return opener


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	set_process(Arcade.moving())
	_rng.seed = 5011

	# Strahlen: einmal gezeichnet, nur die Drehung aendert sich.
	_rays = _Rays.new(CacheArt.color(_kind))
	add_child(_rays)
	resized.connect(_place_rays)
	_place_rays.call_deferred()

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

	# Die Buehne: ein fester Platz, darin der Aufbau (_rig), der wackelt,
	# springt und sich aufblaeht -- der Container bleibt still.
	var stage := CenterContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(stage)
	var place := Control.new()
	place.custom_minimum_size = Vector2(230, 196)
	place.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(place)
	_rig = Control.new()
	_rig.size = place.custom_minimum_size
	_rig.pivot_offset = _rig.size * 0.5
	_rig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place.add_child(_rig)
	for tint in [Arcade.CYAN, Arcade.MAGENTA]:
		var ghost := CacheArt.new(_kind, 230.0)
		ghost.size = _rig.size
		ghost.flat = Color(tint, 0.75)
		ghost.visible = false
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		ghost.material = add
		_rig.add_child(ghost)
		_ghosts.append(ghost)
	_art = CacheArt.new(_kind, 230.0)
	_art.size = _rig.size
	_rig.add_child(_art)
	# Zwei Streifen, die beim Riss die Kiste zerschneiden.
	for tint in [Arcade.CYAN, Arcade.MAGENTA]:
		var slice := _Slice.new(tint)
		slice.visible = false
		_rig.add_child(slice)
		_slices.append(slice)

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

	_flash = ColorRect.new()
	_flash.color = Arcade.WHITE
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)


## "Neon Ninja's · Neon City" aus regions.json; Hipstar gibt es noch nicht.
func _origin() -> String:
	if _kind == "hip":
		return "Hipstar Hackers · Dachterrassen"
	var region := TerrainDB.get_region(StringName(_kind))
	if region == null:
		return ""
	return "%s · %s" % [str(region.faction.get("name", "")), region.display_name]


func _place_rays() -> void:
	if _rays != null:
		_rays.position = Vector2(size.x * 0.5, size.y * 0.36)
		_rays.reach = size.length()


## Je Bild nur Lagen: Strahlen drehen, die Kiste schwebt in Ruhe.
func _process(delta: float) -> void:
	_time += delta
	_rays.rotation = _time * RAY_SPEED
	if not _opened:
		_rig.position.y = -4.0 * sin(_time * TAU / 2.6)


## Grund und Punktraster -- einmal gezeichnet (gekachelte Textur).
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Arcade.NIGHT)
	Arcade.draw_dots(self, Rect2(Vector2.ZERO, size), 14.0, 1.2, Color(Arcade.DOTS, 0.12))


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if pressed and not _opened:
		accept_event()
		_open()


func _open() -> void:
	_opened = true
	_tap_box.visible = false
	_results = GameState.roster.open_cache(_kind)
	GameState.save_roster()
	if not (Arcade.moving() and is_inside_tree()):
		Accessibility.vibrate(80, true)
		_art.open = 1.0
		_show_results()
		return
	Accessibility.vibrate(30)
	_rig.position = Vector2.ZERO
	var seq := create_tween()
	# 2 Anspannen
	seq.tween_method(_wind_up, 0.0, 1.0, WIND_UP)
	# 3 Glitch-Riss: drei harte Spruenge
	for i in GLITCH_AT.size():
		var at: float = GLITCH_AT[i]
		var next: float = GLITCH_AT[i + 1] if i + 1 < GLITCH_AT.size() else BANG
		seq.tween_callback(_glitch_jump.bind(i))
		seq.tween_interval(next - at)
	# 4 Knall
	seq.tween_callback(_bang)
	seq.tween_interval(LOOT - BANG)
	# 5 Beute
	seq.tween_callback(_show_results)


## Wackeln, das immer schneller und groesser wird; die Kiste blaeht sich auf.
func _wind_up(t: float) -> void:
	var swing := sin(t * t * 46.0)
	_rig.rotation = deg_to_rad(swing * (1.5 + 4.5 * t))
	_rig.position = Vector2(swing * 4.0 * t, 0.0)
	_rig.scale = Vector2.ONE * (1.0 + 0.08 * t)
	_rays.modulate.a = 1.0 + 0.8 * t


## Ein Glitch-Sprung: Farbkanaele versetzt, Streifen an neuer Stelle, die Kiste
## ruckt seitlich. Bleibt stehen bis zum naechsten Sprung (kein Flimmern).
func _glitch_jump(index: int) -> void:
	Accessibility.vibrate(20)
	var push := 6.0 + 3.0 * float(index)
	var side := -1.0 if index % 2 == 0 else 1.0
	_rig.rotation = 0.0
	_rig.scale = Vector2.ONE * (1.08 + 0.02 * float(index))
	_rig.position = Vector2(side * _rng.randf_range(3.0, 7.0), 0.0)
	_ghosts[0].visible = true
	_ghosts[1].visible = true
	_ghosts[0].position = Vector2(-push * side, _rng.randf_range(-3.0, 3.0))
	_ghosts[1].position = Vector2(push * side, _rng.randf_range(-3.0, 3.0))
	for i in _slices.size():
		var slice := _slices[i]
		slice.visible = true
		slice.size = Vector2(_rig.size.x + 60.0, _rng.randf_range(8.0, 16.0))
		slice.position = Vector2(-30.0 + _rng.randf_range(-24.0, 24.0),
			_rng.randf_range(0.25, 0.75) * _rig.size.y)


## Blitz, Deckel ab, Sechseck-Ring, Funken, Stoss.
func _bang() -> void:
	Accessibility.vibrate(80, true)
	for ghost in _ghosts:
		ghost.visible = false
	for slice in _slices:
		slice.visible = false
	_rig.rotation = 0.0
	_rig.position = Vector2.ZERO
	_rig.scale = Vector2.ONE * 1.18
	var color := CacheArt.color(_kind)
	var fx := create_tween().set_parallel(true)
	fx.tween_property(_rig, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fx.tween_property(_art, "open", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash.modulate.a = 0.6
	fx.tween_property(_flash, "modulate:a", 0.0, 0.2)
	_rays.modulate.a = 2.4
	fx.tween_property(_rays, "modulate:a", 1.6, 0.6)
	# Ring: einmal gezeichnet, waechst ueber die Groesse.
	var center := _rig.get_global_rect().get_center() - global_position
	for i in 2:
		var ring := _Ring.new(color if i == 0 else Arcade.WHITE, 5.0 - 2.0 * float(i))
		ring.position = center
		ring.scale = Vector2.ONE * 0.4
		add_child(ring)
		var grow := create_tween().set_parallel(true)
		grow.tween_property(ring, "scale", Vector2.ONE * (2.4 - 0.6 * float(i)), 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		grow.tween_property(ring, "modulate:a", 0.0, 0.45)
		grow.chain().tween_callback(ring.queue_free)
	# Pixel-Funken
	var tints := [color, Arcade.YELLOW, Arcade.CYAN, Arcade.MAGENTA, Arcade.WHITE]
	for i in 16:
		var spark := ColorRect.new()
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.color = tints[i % tints.size()]
		spark.size = Vector2.ONE * _rng.randf_range(4.0, 8.0)
		spark.position = center - spark.size * 0.5
		add_child(spark)
		var a := TAU * float(i) / 16.0 + _rng.randf_range(-0.2, 0.2)
		var to := center + Vector2(cos(a), sin(a) * 0.8) * _rng.randf_range(110.0, 190.0)
		var fly := create_tween().set_parallel(true)
		fly.tween_property(spark, "position", to, 0.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		fly.tween_property(spark, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly.chain().tween_callback(spark.queue_free)
	# Kurzer Stoss der ganzen Buehne
	var shake := create_tween()
	for k in 5:
		var strength := 7.0 * (1.0 - float(k) / 5.0)
		shake.tween_property(_rig, "position",
			Vector2(_rng.randf_range(-strength, strength), _rng.randf_range(-strength, strength)), 0.04)
	shake.tween_property(_rig, "position", Vector2.ZERO, 0.05)


func _show_results() -> void:
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
		tween.tween_interval(0.1 + 0.3 * i)
		tween.tween_method(func(t: float):
			ball.position = from.lerp(mid, t).lerp(mid.lerp(to, t), t), 0.0, 1.0, 0.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(func():
			Accessibility.vibrate(20)
			card.reveal())
		tween.tween_property(ball, "burst", 1.0, 0.25)
		tween.tween_callback(ball.queue_free)


func _close() -> void:
	finished.emit()
	queue_free()


## Zwoelf Lichtstrahlen um den eigenen Ursprung -- einmal gezeichnet, gedreht
## wird der Knoten.
class _Rays extends Control:
	var tint := Color.WHITE
	var reach := 1200.0:
		set(value):
			reach = value
			queue_redraw()

	func _init(color: Color) -> void:
		tint = color
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in 12:
			var a := TAU * float(i) / 12.0
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO,
				Vector2(cos(a - 0.09), sin(a - 0.09)) * reach,
				Vector2(cos(a + 0.09), sin(a + 0.09)) * reach]), Color(tint, 0.07))


## Ein Riss-Streifen: Nachtschwarz mit farbiger Kante.
class _Slice extends Control:
	var tint := Color.WHITE

	func _init(color: Color) -> void:
		tint = color
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Arcade.NIGHT)
		draw_rect(Rect2(0, 0, size.x, 2.0), tint)


## Sechseck-Ring (flach, wie Feld und Kiste) um den eigenen Ursprung, Radius 100.
class _Ring extends Control:
	var tint := Color.WHITE
	var width := 4.0

	func _init(color: Color, line: float) -> void:
		tint = color
		width = line
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var points := PackedVector2Array()
		for i in 7:
			var a := TAU * float(i) / 6.0
			points.append(Vector2(cos(a) * 100.0, sin(a) * 78.0))
		draw_polyline(points, tint, width)


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
		return ""

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
			# Glitch-Aufploppen: kurz ueberhell und seitlich versetzt.
			modulate = Color(1.9, 1.9, 1.9)
			create_tween().tween_property(self, "modulate", Color.WHITE, 0.22)
			_content.position.x = 6.0
			create_tween().tween_property(_content, "position:x", 0.0, 0.12) \
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
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
