class_name Arcade
extends RefCounted

## Baukasten fuer den Arcade-Glitch-Stil (13. Nov. 2026, Entwuerfe in
## docs/design/, Werte im SPOT-Blatt Design): Synthwave-Hintergrund mit
## Sonne und Gitter, Glitch-Logo, Laufbaender, TAP-Knopf, Karten und Knoepfe
## mit abgeschraegten Ecken, Scanlines. Masse wie im Entwurf (450 x 800).
##
## Bisher nutzen ihn Titelbildschirm und Spielstand-Wahl; die uebrigen
## Bildschirme folgen, wenn es Entwuerfe dafuer gibt.

const NIGHT := Color("#0a0618")
const DEEP := Color("#12082a")
const VIOLET := Color("#1b0b3a")
const YELLOW := Color("#ffe14d")
const CYAN := Color("#2ee3eb")
const MAGENTA := Color("#ff2bd6")
const DOTS := Color("#ff3dbb")
const ORANGE := Color("#ff6a3d")
const ROSE := Color("#ff8ce8")
const WHITE := Color("#fff7fe")
const TEXT := Color("#e9dcff")
const MUTED := Color("#c3b3e6")
const EMPTY_LINE := Color("#6a5a96")
const EMPTY_NUM := Color("#8f80bd")

const DESIGN := Vector2(450, 800)

static var _fonts := {}


# --- Schriften ---------------------------------------------------------------

## Bungee (Logo, Knoepfe, Nummern) oder Chakra Petch ("medium"/"bold"), auf
## Wunsch mit Zeichenabstand in em wie im Entwurf (letter-spacing).
static func font(kind: String, size: int = 16, spacing_em: float = 0.0) -> Font:
	var files := {"display": "Bungee-Regular", "medium": "ChakraPetch-Medium",
		"bold": "ChakraPetch-Bold"}
	if not _fonts.has(kind):
		_fonts[kind] = load("res://assets/fonts/%s.ttf" % files[kind])
	if spacing_em == 0.0:
		return _fonts[kind]
	var key := "%s/%d/%.3f" % [kind, size, spacing_em]
	if not _fonts.has(key):
		var variation := FontVariation.new()
		variation.base_font = _fonts[kind]
		variation.spacing_glyph = int(round(size * spacing_em))
		_fonts[key] = variation
	return _fonts[key]


static func label(text: String, size: int, color: Color, kind: String = "medium",
		spacing_em: float = 0.0) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_override("font", font(kind, size, spacing_em))
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result


## Schraeges Etikett auf Gelb (PLAYER 1 · READY, SAVE SELECT).
static func tag(text: String, size: int, degrees: float) -> Control:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = YELLOW
	box.content_margin_left = 12 if size >= 14 else 10
	box.content_margin_right = box.content_margin_left
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(label(text, size, DEEP, "bold", 0.24))
	panel.rotation_degrees = degrees
	panel.resized.connect(func(): panel.pivot_offset = panel.size * 0.5)
	return panel


## Gedrehtes Element in einem Container: Container setzen die Drehung ihrer
## Kinder zurueck, deshalb steckt es in einer Huelle, die nur Platz haelt.
static func tilt(child: Control, degrees: float) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(child)
	var fit := func():
		var need := child.get_combined_minimum_size()
		holder.custom_minimum_size = need
		child.size = need
		child.position = (holder.size - need) * 0.5
		child.pivot_offset = need * 0.5
		child.rotation_degrees = degrees
	holder.resized.connect(fit)
	child.minimum_size_changed.connect(fit)
	fit.call()
	return holder


# --- Formen ------------------------------------------------------------------

## Kasten mit abgeschraegter Ecke oben links und unten rechts (clip-path im
## Entwurf): corner_detail 1 macht aus der Rundung eine gerade Kante.
static func chamfer_box(fill: Color, cut: int, line: Color = Color.TRANSPARENT,
		line_width: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.draw_center = fill.a > 0.0
	box.corner_detail = 1
	box.corner_radius_top_left = cut
	box.corner_radius_bottom_right = cut
	box.anti_aliasing = true
	if line_width > 0:
		box.border_color = line
		box.set_border_width_all(line_width)
	return box


## Grosser Knopf: gefuellt (Weiterspielen) oder mit gelbem Rahmen (Neues Spiel).
static func button(text: String, filled: bool) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(0, 54)
	result.focus_mode = Control.FOCUS_ALL
	result.add_theme_font_override("font", font("display", 19, 0.06))
	result.add_theme_font_size_override("font_size", 19)
	var fill := YELLOW if filled else Color.TRANSPARENT
	var text_color := DEEP if filled else YELLOW
	var line := 0 if filled else 2
	result.add_theme_stylebox_override("normal", chamfer_box(fill, 14, YELLOW, line))
	result.add_theme_stylebox_override("hover", chamfer_box(fill.lightened(0.15) if filled
		else Color(YELLOW, 0.1), 14, YELLOW, line))
	result.add_theme_stylebox_override("pressed", chamfer_box(YELLOW.darkened(0.15) if filled
		else Color(YELLOW, 0.2), 14, YELLOW, line))
	result.add_theme_stylebox_override("focus", chamfer_box(Color.TRANSPARENT, 14, Color("#fff3a8"), 3))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color"]:
		result.add_theme_color_override(state, text_color)
	return result


## Flacher Text-Knopf (LOESCHEN).
static func text_button(text: String, color: Color) -> Button:
	var result := Button.new()
	result.flat = true
	result.text = text
	result.custom_minimum_size = Vector2(0, 44)
	result.add_theme_font_override("font", font("bold", 15, 0.12))
	result.add_theme_font_size_override("font_size", 15)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color"]:
		result.add_theme_color_override(state, color)
	return result


## Wie die Dekoration laeuft: 0 bei "Bewegung reduzieren" (Optionen).
static func moving() -> bool:
	return Accessibility.motion() > 0.0


# --- Hintergrund -------------------------------------------------------------

## Punktraster, Synthwave-Sonne mit Schlitzen, Berge und Gitterboden.
## title = true: grosse Sonne mittig (Titel); false: kleine, blasse Sonne
## unten (Menues). Gezeichnet in Entwurfsmassen, hoch skaliert und mittig.
class Backdrop extends Control:
	var title := true
	var _time := 0.0

	func _init(is_title: bool = true) -> void:
		title = is_title
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _ready() -> void:
		set_process(title and Arcade.moving())
		resized.connect(queue_redraw)

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	## Entwurfs-Koordinate -> Bildschirm (gleichmaessig nach der Hoehe skaliert,
	## waagerecht mittig).
	func _p(x: float, y: float) -> Vector2:
		var s := size.y / Arcade.DESIGN.y
		return Vector2(size.x * 0.5 + (x - 225.0) * s, y * s)

	func _draw() -> void:
		var s := size.y / Arcade.DESIGN.y
		draw_rect(Rect2(Vector2.ZERO, size), Arcade.NIGHT)
		# Punktraster (14 px, r 1,6)
		var dot := Color(Arcade.DOTS, 0.35 if title else 0.22)
		var step := 14.0 * s
		var y := 7.0 * s
		while y < size.y:
			var x := fmod(size.x * 0.5 - 7.0 * s, step)
			while x < size.x:
				draw_circle(Vector2(x, y), 1.6 * s, dot)
				x += step
			y += step
		if title:
			_draw_title(s)
		else:
			_draw_menu(s)

	func _draw_title(s: float) -> void:
		var bob := -3.0 - 3.0 * cos(_time * TAU / 5.0) if _time > 0.0 else 0.0
		var cuts := [[304, 318], [324, 336], [342, 351], [357, 364], [370, 375]]
		_sun(Vector2(225, 300 + bob), 150.0, 1.0, 300.0 + bob, cuts, bob, s)
		var hills := PackedVector2Array()
		hills.append(Vector2(0, 420 * s))
		for point in [[0, 420], [70, 330], [120, 372], [190, 300], [250, 360], [310, 312],
				[380, 380], [450, 340], [450, 420]]:
			hills.append(_p(point[0], point[1]))
		hills.append(Vector2(size.x, 340 * s))
		hills.append(Vector2(size.x, 420 * s))
		draw_colored_polygon(hills, Color("#1b0b3a"))
		draw_rect(Rect2(0, 420 * s, size.x, size.y - 420 * s), Arcade.DEEP)
		_grid(420, [[420, 0.75], [436, 0.375], [462, 0.34], [502, 0.3], [562, 0.26], [650, 0.22]],
			[-500, -200, 80, 370, 650, 950], 0.3, 2.0, s)

	func _draw_menu(s: float) -> void:
		var top := size.y - 52.0 * s  # Horizont 52 px ueber dem unteren Rand
		var shift := top / s - 748.0
		_sun(Vector2(225, 760 + shift), 130.0, 0.35, 700.0 + shift,
			[[704 + shift, 716 + shift], [722 + shift, 731 + shift], [737 + shift, 743 + shift]], 0.0, s)
		draw_rect(Rect2(0, top, size.x, size.y - top), Arcade.DEEP)
		_grid(748 + shift, [[748 + shift, 0.45], [760 + shift, 0.3], [780 + shift, 0.25]],
			[-200, 100, 350, 650], 0.3, 1.5, s, 800 + shift)

	## Sonne als waagerechte Streifen: Verlauf gelb -> orange -> magenta,
	## unterhalb von solid_until nur in den Schlitzen (cuts) sichtbar.
	func _sun(center: Vector2, radius: float, alpha: float, solid_until: float,
			cuts: Array, _bob: float, s: float) -> void:
		var row := 1.0
		var y := center.y - radius
		while y < center.y + radius:
			var mid := y + row * 0.5
			var visible := mid < solid_until
			for cut in cuts:
				if mid >= cut[0] and mid < cut[1]:
					visible = true
			if visible:
				var dy := mid - center.y
				var half := sqrt(maxf(0.0, radius * radius - dy * dy))
				var t := (mid - (center.y - radius)) / (2.0 * radius)
				var color := Arcade.YELLOW.lerp(Arcade.ORANGE, t / 0.55) if t < 0.55 \
					else Arcade.ORANGE.lerp(Arcade.MAGENTA, (t - 0.55) / 0.45)
				color.a = alpha
				var a := _p(center.x - half, mid - row * 0.5)
				draw_rect(Rect2(a.x, a.y, half * 2.0 * s, row * s + 0.5), color)
			y += row

	func _grid(horizon: float, rows: Array, ends: Array, ray_alpha: float, width: float,
			s: float, bottom: float = 800.0) -> void:
		for line in rows:
			var yy: float = line[0] * s
			draw_line(Vector2(0, yy), Vector2(size.x, yy), Color(Arcade.CYAN, line[1]), width * s)
		for end_x in ends:
			draw_line(_p(225, horizon), _p(end_x, bottom), Color(Arcade.CYAN, ray_alpha), width * s)


## Feine dunkle Querlinien ueber allem (alle 3 px).
class Scanlines extends Control:
	var strength := 0.18

	func _init(alpha: float = 0.18) -> void:
		strength = alpha
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var y := 2.0
		var color := Color(0, 0, 0, strength)
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), color, 1.0)
			y += 3.0


## Das Logo dreifach: Cyan und Magenta versetzt (additiv), dazwischen weiss
## mit hartem Schatten. keys = [[Phase, Versatz Cyan, Versatz Magenta], ...]
## wie die Keyframes im Entwurf (steps: der Wert gilt bis zum naechsten).
## still = Versatz bei "Bewegung reduzieren".
class GlitchLogo extends Control:
	var _layers: Array[Label] = []
	var _period := 3.2
	var _keys: Array = []
	var _time := 0.0

	func _init(text: String, font_size: int, period: float, keys: Array, still: float) -> void:
		_period = period
		_keys = keys
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		for color in [Arcade.CYAN, Arcade.MAGENTA, Arcade.WHITE]:
			var layer := Arcade.label(text, font_size, color, "display")
			layer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			layer.add_theme_constant_override("line_spacing", -int(font_size * 0.2))
			if color != Arcade.WHITE:
				layer.material = add
			else:
				layer.add_theme_color_override("font_shadow_color", Arcade.DEEP)
				layer.add_theme_constant_override("shadow_offset_x", 0)
				layer.add_theme_constant_override("shadow_offset_y", 6)
			add_child(layer)
			_layers.append(layer)
		if Arcade.moving():
			_place(0.0)
		else:
			_shift(Vector2(-still, 0), Vector2(still, 0))

	func _ready() -> void:
		set_process(Arcade.moving())
		resized.connect(func(): pivot_offset = size * 0.5)

	func _get_minimum_size() -> Vector2:
		return _layers[2].get_combined_minimum_size() if _layers.size() == 3 else Vector2.ZERO

	func _process(delta: float) -> void:
		_time = fmod(_time + delta, _period)
		_place(_time / _period)

	func _place(phase: float) -> void:
		var current: Array = _keys[0]
		for key in _keys:
			if phase >= key[0]:
				current = key
		_shift(current[1], current[2])

	func _shift(a: Vector2, b: Vector2) -> void:
		var full := _layers[2].get_combined_minimum_size()
		_layers[0].position = a
		_layers[1].position = b
		_layers[2].position = Vector2.ZERO
		for layer in _layers:
			layer.size = full


## Schraeges Laufband (Text laeuft endlos durch, reverse = andersherum).
class Tape extends Control:
	var _text: Label
	var _seconds := 22.0
	var _reverse := false
	var _time := 0.0
	var _fill := Color.TRANSPARENT
	var _line := Color.TRANSPARENT

	func _init(text: String, font_size: int, spacing_em: float, color: Color, fill: Color,
			line: Color, band: float, degrees: float, seconds: float, reverse: bool) -> void:
		_seconds = seconds
		_reverse = reverse
		_fill = fill
		_line = line
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, band)
		rotation_degrees = degrees
		_text = Arcade.label((text + "   ").repeat(6), font_size, color, "bold", spacing_em)
		_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_text)

	func _ready() -> void:
		set_process(Arcade.moving())
		resized.connect(func():
			pivot_offset = size * 0.5
			_text.size.y = size.y
			queue_redraw())

	func _process(delta: float) -> void:
		_time = fmod(_time + delta, _seconds)
		var half := _text.get_combined_minimum_size().x * 0.5
		var t := _time / _seconds
		_text.position.x = -half * (1.0 - t) if _reverse else -half * t

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), _fill)
		draw_line(Vector2(0, 0.5), Vector2(size.x, 0.5), _line, 1.0)
		draw_line(Vector2(0, size.y - 0.5), Vector2(size.x, size.y - 0.5), _line, 1.0)


## Sechseckiger TAP-Knopf: pulsiert, gestrichelter Ring dreht sich.
class TapBadge extends Control:
	var _time := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(132, 132)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		set_process(Arcade.moving())

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		# Ring: Striche 14, Luecken 10 auf r 62, eine Umdrehung in 7 s
		var turn := _time * TAU / 7.0
		var circumference := TAU * 62.0
		var dash := 14.0 / circumference * TAU
		var gap := 10.0 / circumference * TAU
		var angle := turn
		while angle < turn + TAU - 0.001:
			draw_arc(c, 62.0, angle, angle + dash, 6, Arcade.CYAN, 3.0, true)
			angle += dash + gap
		# Sechseck 96 px, pulsiert 1 -> 1,08 (1,4 s)
		var pulse := 1.0 + 0.04 * (1.0 - cos(_time * TAU / 1.4))
		var half := 48.0 * pulse
		var points := PackedVector2Array()
		for p in [[0.25, 0.03], [0.75, 0.03], [1.0, 0.5], [0.75, 0.97], [0.25, 0.97], [0.0, 0.5]]:
			points.append(c + Vector2((p[0] - 0.5) * 2.0 * half, (p[1] - 0.5) * 2.0 * half))
		draw_colored_polygon(points, Arcade.YELLOW)
		var f := Arcade.font("display")
		var fs := int(round(26 * pulse))
		var w := f.get_string_size("TAP", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + Vector2(-w * 0.5, f.get_ascent(fs) * 0.5 - 2), "TAP",
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Arcade.DEEP)


## Karte (Spielstand): Violett, Rahmen, harter Versatzschatten 6 px rechts
## unten; leer mit gestricheltem Rahmen und ohne Schatten.
class Card extends PanelContainer:
	var line := Arcade.CYAN
	var shadow := Color.TRANSPARENT
	var dashed := false

	func _init(line_color: Color, shadow_color: Color, is_dashed: bool) -> void:
		line = line_color
		shadow = shadow_color
		dashed = is_dashed
		var box := StyleBoxFlat.new()
		box.bg_color = Arcade.VIOLET
		box.set_content_margin_all(14)
		if not dashed:
			box.border_color = line
			box.set_border_width_all(2)
		add_theme_stylebox_override("panel", box)

	func _draw() -> void:
		if shadow.a > 0.0:
			draw_rect(Rect2(size.x, 6, 6, size.y), shadow)
			draw_rect(Rect2(6, size.y, size.x - 6, 6), shadow)
		if dashed:
			var corners := [Vector2(1, 1), Vector2(size.x - 1, 1), Vector2(size.x - 1, size.y - 1),
				Vector2(1, size.y - 1)]
			for i in 4:
				draw_dashed_line(corners[i], corners[(i + 1) % 4], line, 2.0, 6.0)


## Zurueck-Pfeil (44 x 44, gelb).
class BackButton extends Button:
	func _init() -> void:
		flat = true
		custom_minimum_size = Vector2(44, 44)
		tooltip_text = "Zurück zum Titel"
		add_theme_stylebox_override("focus", Arcade.chamfer_box(Color.TRANSPARENT, 0, Arcade.YELLOW, 3))

	func _draw() -> void:
		var o := (size - Vector2(24, 24)) * 0.5
		draw_polyline(PackedVector2Array([o + Vector2(15, 4), o + Vector2(7, 12), o + Vector2(15, 20)]),
			Arcade.YELLOW, 2.6)
