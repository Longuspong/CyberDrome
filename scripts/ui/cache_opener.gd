class_name CacheOpener
extends Control

## Der Bildschirm "Cache oeffnen" (Entwurf 15. Nov. 2026, Bilder 18-22): die
## Kiste der Fraktion gross vor Lichtstrahlen, Glitch-Name, TAP-Knopf.
## Antippen hebt den Deckel.
##
## Was ein Cache enthaelt, ist noch nicht entschieden (SPOT-Blatt Lootcaches,
## Wunsch des Spielers: erst nur die Optik). Deshalb ist das Oeffnen heute eine
## VORSCHAU: der Cache bleibt im Lager, es wird nichts gutgeschrieben.

signal finished

var _kind := "city"
var _art: CacheArt
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
	_art = CacheArt.new(_kind, 260.0)
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
	if Arcade.moving() and is_inside_tree():
		var tween := create_tween()
		tween.tween_property(_art, "open", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_art.open = 1.0
	_result = UiKit.card(_tap_box.get_parent() as Control, true)
	_result.add_child(Arcade.label("INHALT", 13, Arcade.CYAN, "bold", 0.2))
	_result.add_child(UiKit.label("Was ein Cache enthält (Waffen, Komponenten, ganze DROMEs, "
		+ "Coins), legst du im SPOT-Blatt Lootcaches fest. Bis dahin ist das hier eine Vorschau "
		+ "-- der Cache bleibt im Lager.", 14, UiKit.TEXT))
	var done := UiKit.button("Fertig", true)
	done.pressed.connect(_close)
	(_tap_box.get_parent() as Control).add_child(done)


func _close() -> void:
	finished.emit()
	queue_free()
