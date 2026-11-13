extends Control

## Titelbildschirm im Arcade-Glitch-Stil (13. Nov. 2026, Entwurf
## docs/design/titel_arcade): der erste Bildschirm des Spiels. Irgendwo
## tippen (oder eine Taste) fuehrt zur Spielstand-Wahl.
##
## Die Lagen kommen aus dem Entwurf (450 x 800) und wachsen mit der Hoehe
## mit, damit sie zur Sonne im Hintergrund passen (Arcade.Backdrop).

const NEXT := "res://scenes/saves.tscn"

var _tag: Control
var _logo: Control
var _tape_a: Control
var _tape_b: Control
var _tap: Control
var _hint: Label
var _leaving := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(Arcade.Backdrop.new(true))

	_tag = Arcade.tag("PLAYER 1 · READY", 14, -3.0)
	add_child(_tag)

	var logo := Arcade.GlitchLogo.new("CYBER\nDROME", 50, 3.2, [
		[0.0, Vector2.ZERO, Vector2.ZERO],
		[0.87, Vector2(-6, 2), Vector2(6, -2)],
		[0.89, Vector2(5, -2), Vector2(-5, 3)],
		[0.91, Vector2(-3, 0), Vector2(4, 0)]], 3.0)
	logo.rotation_degrees = -6.0
	_logo = logo
	add_child(_logo)

	_tape_a = Arcade.Tape.new("DEATH ROBOT ◆ OMNI MACHINE ◆ EXECUTOR ◆", 12, 0.3,
		Color(Arcade.YELLOW, 0.8), Color(Arcade.YELLOW, 0.1), Color(Arcade.YELLOW, 0.45),
		26.0, -4.0, 22.0, false)
	add_child(_tape_a)
	_tape_b = Arcade.Tape.new("AUTOBATTLER × NEON CITY ×", 11, 0.34,
		Color("#ff8ce8", 0.8), Color(Arcade.MAGENTA, 0.08), Color(Arcade.MAGENTA, 0.4),
		22.0, 2.0, 28.0, true)
	add_child(_tape_b)

	_tap = Arcade.TapBadge.new()
	add_child(_tap)
	_hint = Arcade.label("IRGENDWO TIPPEN", 18, Color("#f4ecff"), "bold", 0.22)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)

	add_child(Arcade.Scanlines.new(0.18))

	# Die ganze Flaeche ist der Knopf (auch fuer Vorleser); Tasten starten
	# ueber _unhandled_input, deshalb ohne vorab gesetzten Fokusrahmen.
	var start := Button.new()
	start.flat = true
	start.set_anchors_preset(Control.PRESET_FULL_RECT)
	start.tooltip_text = "Antippen zum Starten"
	start.add_theme_stylebox_override("focus", Arcade.chamfer_box(Color.TRANSPARENT, 0, Arcade.YELLOW, 4))
	start.pressed.connect(_start)
	add_child(start)

	resized.connect(_layout)
	_layout()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_start()


func _layout() -> void:
	var s := size.y / Arcade.DESIGN.y
	var mid := size.x * 0.5
	var tag_size := _tag.get_combined_minimum_size()
	_tag.size = tag_size
	_tag.position = Vector2(mid - tag_size.x * 0.5, 70.0 * s)
	var logo_size := _logo.get_combined_minimum_size()
	_logo.size = logo_size
	_logo.position = Vector2(mid - logo_size.x * 0.5, 168.0 * s)
	for pair in [[_tape_a, 470.0], [_tape_b, 512.0]]:
		var tape: Control = pair[0]
		tape.size = Vector2(size.x + 120.0, tape.custom_minimum_size.y)
		tape.position = Vector2(-60.0, pair[1] * s)
	var hint_size := _hint.get_combined_minimum_size()
	_hint.size = Vector2(size.x, hint_size.y)
	_hint.position = Vector2(0, size.y - 70.0 * s - hint_size.y)
	_tap.size = _tap.custom_minimum_size
	_tap.position = Vector2(mid - 66.0, _hint.position.y - 16.0 - 132.0)


func _start() -> void:
	if _leaving:
		return
	_leaving = true
	Accessibility.vibrate(20)
	get_tree().change_scene_to_file.call_deferred(NEXT)
