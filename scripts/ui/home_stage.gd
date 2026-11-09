class_name HomeStage
extends Control

## Die Buehne der Startseite (9. Nov. 2026, Wunsch des Spielers: keine
## zufaelligen DROMEs mehr, die einander bearbeiten).
##
## Das Tor der Arena von Neon City bei Nacht: ein Neonbogen mit dem Schriftzug
## ARENA, zwei Suchscheinwerfer, Regen, ein spiegelnder Boden mit Fluchtlinien.
## Davor auf einem leuchtenden Podest steht DEIN Squad -- ruhig, mit leichtem
## Atmen, wie vor dem Einmarsch. "Animationen reduzieren" friert alles ein.
##
## Gezeichnet statt Bilddatei, wie die Kulissen (Ambience): skaliert mit jeder
## Groesse und kostet keinen Speicher.

const CYAN := Color(0.18, 0.89, 0.92)
const PINK := Color(1.0, 0.17, 0.84)
const GOLD := Color(1.0, 0.78, 0.35)
## Bildwiederholung der Zeichnung -- reicht fuer Regen und Licht.
const FRAME_TIME := 1.0 / 30.0

var _time := 0.0
var _since_draw := 0.0
var _rain: Array = []
var _rigs: Array = []
var _squad: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(_layout)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2077
	for i in 70:
		_rain.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.6, 1.0)))


## Der Squad, der auf dem Podest steht (GameState.squad). Hoechstens vier.
func show_squad(builds: Array) -> void:
	_squad = builds.slice(0, 4)
	for rig in _rigs:
		rig.queue_free()
	_rigs.clear()
	for build in _squad:
		var rig := Node2D.new()
		DromeSprites.assemble(rig, build, "south")
		add_child(rig)
		_rigs.append(rig)
	_layout()


func _layout() -> void:
	var count := _rigs.size()
	if count == 0:
		return
	var floor_y := size.y * 0.86
	var spread := minf(size.x * 0.21, 96.0)
	var scale := clampf(size.y / 340.0, 0.7, 1.5)
	for i in count:
		var rig: Node2D = _rigs[i]
		# Mitte vorn, die anderen versetzt dahinter -- wie eine Aufstellung.
		var offset := float(i) - float(count - 1) * 0.5
		var back := absf(offset) * 0.05
		rig.scale = Vector2.ONE * scale * (1.0 - back)
		rig.position = Vector2(size.x * 0.5 + offset * spread, floor_y - back * size.y * 0.6) \
			- IsoView.SPRITE_ORIGIN * rig.scale.x
		rig.set_meta("home", rig.position)
		rig.z_index = 10 - int(absf(offset) * 2.0)
	queue_redraw()


func _process(delta: float) -> void:
	if Accessibility.reduce_motion:
		return
	_time += delta
	# Leichtes Atmen, je DROME versetzt.
	for i in _rigs.size():
		var rig: Node2D = _rigs[i]
		if rig.has_meta("home"):
			rig.position = (rig.get_meta("home") as Vector2) \
				+ Vector2(0, sin(_time * 1.6 + i * 1.3) * 1.6)
	_since_draw += delta
	if _since_draw >= FRAME_TIME:
		_since_draw = 0.0
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var w := size.x
	var h := size.y
	var horizon := h * 0.58
	_draw_floor(w, h, horizon)
	_draw_beams(w, h, horizon)
	_draw_gate(w, h, horizon)
	_draw_podium(w, h)
	_draw_rain(w, h)


## Spiegelnder Boden: dunkler Verlauf, Fluchtlinien zur Mitte, Querlinien,
## die langsam auf den Betrachter zulaufen.
func _draw_floor(w: float, h: float, horizon: float) -> void:
	# Eine Flaeche in Perspektive statt eines Kastens: hinten schmal, vorn
	# breiter als das Bild -- so gibt es keine sichtbaren Ecken.
	var far_half := w * 0.36
	var near_half := w * 0.75
	var steps := 12
	for i in steps:
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var y0 := horizon + (h - horizon) * t0
		var y1 := horizon + (h - horizon) * t1
		var h0 := lerpf(far_half, near_half, t0)
		var h1 := lerpf(far_half, near_half, t1)
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.5 - h0, y0), Vector2(w * 0.5 + h0, y0),
			Vector2(w * 0.5 + h1, y1 + 1.0), Vector2(w * 0.5 - h1, y1 + 1.0)]),
			Color(Color(0.05, 0.03, 0.1).lerp(Color(0.09, 0.04, 0.14), t0), 0.55 + 0.4 * t0))
	var center := Vector2(w * 0.5, horizon)
	for i in range(-6, 7):
		var f := float(i) / 6.0
		var top := Vector2(w * 0.5 + f * far_half, horizon)
		var bottom := Vector2(w * 0.5 + f * near_half, h)
		draw_line(top, bottom, Color(PINK, 0.14), 1.0, true)
	var shift := fmod(_time * 0.25, 1.0)
	for i in 8:
		var t := (float(i) + shift) / 8.0
		var tt := t * t
		var y := horizon + (h - horizon) * tt
		var half := lerpf(far_half, near_half, tt)
		draw_line(Vector2(w * 0.5 - half, y), Vector2(w * 0.5 + half, y), Color(CYAN, 0.08 + 0.18 * t), 1.0)
	# Spiegelung des Tors auf dem nassen Boden.
	draw_rect(Rect2(w * 0.25, horizon, w * 0.5, h * 0.05), Color(CYAN, 0.05))
	draw_line(Vector2(w * 0.5 - far_half, horizon), Vector2(w * 0.5 + far_half, horizon),
		Color(CYAN, 0.35), 1.5, true)


## Zwei Suchscheinwerfer, die langsam ueber den Himmel streichen.
func _draw_beams(w: float, h: float, horizon: float) -> void:
	for side: float in [-1.0, 1.0]:
		var base := Vector2(w * (0.5 + 0.42 * side), horizon)
		var swing := sin(_time * 0.35 + (0.0 if side < 0 else 2.1)) * 0.35
		var angle := -PI * 0.5 + side * -0.35 + swing
		var length := h * 0.9
		var dir := Vector2(cos(angle), sin(angle))
		var normal := dir.orthogonal()
		var tip := base + dir * length
		var spread := length * 0.12
		var color: Color = CYAN if side < 0 else PINK
		draw_colored_polygon(PackedVector2Array([base, tip + normal * spread, tip - normal * spread]),
			Color(color, 0.07))
		draw_colored_polygon(PackedVector2Array([base, tip + normal * spread * 0.4, tip - normal * spread * 0.4]),
			Color(color, 0.06))


## Das Tor: ein Neonbogen ueber der Arena, darin der Schriftzug ARENA, an den
## Saeulen Lauflichter.
func _draw_gate(w: float, h: float, horizon: float) -> void:
	var center := Vector2(w * 0.5, horizon)
	var radius := minf(w * 0.4, h * 0.5)
	var flicker := _flicker(3)
	# Saeulen.
	for side: float in [-1.0, 1.0]:
		var x := center.x + side * radius
		draw_rect(Rect2(x - 7, horizon - radius * 0.55, 14, radius * 0.55), Color(0.08, 0.06, 0.14))
		for j in 5:
			var lit := fmod(_time * 3.0 + j * 0.7, 3.5) < 1.0
			draw_rect(Rect2(x - 3, horizon - radius * 0.5 + j * radius * 0.1, 6, radius * 0.05),
				Color(GOLD if lit else Color(GOLD, 0.25), 0.9 if lit else 0.4))
	# Der Bogen: mehrere Striche fuer das Leuchten, innen hell.
	var arc_center := center + Vector2(0, -radius * 0.55)
	for k in 4:
		var width := 14.0 - k * 3.5
		var alpha := (0.08 + k * 0.12) * flicker
		draw_arc(arc_center, radius, PI, TAU, 48, Color(CYAN, alpha), width, true)
	draw_arc(arc_center, radius, PI, TAU, 48, Color(1, 1, 1, 0.7 * flicker), 1.5, true)
	draw_arc(arc_center, radius * 0.86, PI * 1.08, PI * 1.92, 40, Color(PINK, 0.55 * _flicker(7)), 2.5, true)
	# Schriftzug im Bogen.
	var font := ThemeDB.fallback_font
	var size_px := int(clampf(radius * 0.32, 18.0, 46.0))
	var text := "ARENA"
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var at := arc_center + Vector2(-text_w * 0.5, -radius * 0.42)
	var sign_alpha := _flicker(11)
	for offset in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		font.draw_string(get_canvas_item(), at + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			size_px, Color(PINK, 0.25 * sign_alpha))
	font.draw_string(get_canvas_item(), at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px,
		Color(1.0, 0.75, 0.95, sign_alpha))


## Das Podest unter dem Squad: eine flache Ellipse mit leuchtendem Rand und
## einem Lichtkegel von oben.
func _draw_podium(w: float, h: float) -> void:
	var center := Vector2(w * 0.5, h * 0.86)
	var rx := minf(w * 0.46, 230.0)
	var ry := rx * 0.2
	draw_colored_polygon(_ellipse(center + Vector2(0, 8), rx, ry), Color(0.04, 0.02, 0.08, 0.9))
	draw_colored_polygon(_ellipse(center, rx, ry), Color(0.1, 0.08, 0.2))
	var pulse := 0.6 + 0.4 * sin(_time * 1.2)
	draw_polyline(_ellipse(center, rx, ry, true), Color(CYAN, 0.35 + 0.3 * pulse), 3.0, true)
	draw_polyline(_ellipse(center, rx * 0.7, ry * 0.7, true), Color(PINK, 0.25), 1.5, true)
	# Lichtkegel von oben.
	draw_colored_polygon(PackedVector2Array([center + Vector2(-rx * 0.25, -h * 0.75),
		center + Vector2(rx * 0.25, -h * 0.75), center + Vector2(rx, 0), center + Vector2(-rx, 0)]),
		Color(0.7, 0.9, 1.0, 0.045))


func _draw_rain(w: float, h: float) -> void:
	var fall := Vector2(-0.18, 1.0).normalized()
	for drop: Vector3 in _rain:
		var y := fmod(drop.y + _time * 0.9 * drop.z, 1.0) * (h + 40.0) - 20.0
		var x := fmod(drop.x * (w + 60.0) + (y * 0.18), w + 60.0) - 30.0
		var len := 10.0 + 10.0 * drop.z
		draw_line(Vector2(x, y), Vector2(x, y) + fall * len, Color(0.7, 0.85, 1.0, 0.18 * drop.z), 1.0)


func _ellipse(center: Vector2, rx: float, ry: float, closed: bool = false) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 40
	for i in steps + (1 if closed else 0):
		var a := TAU * float(i) / float(steps)
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return points


## Neon flackert: meist an, selten kurz aus.
func _flicker(seed_value: int) -> float:
	if Accessibility.reduce_motion:
		return 1.0
	var phase := float(seed_value) * 0.77
	if fmod(_time * 0.8 + phase, 6.0) < 0.12:
		return 0.25
	return 0.85 + 0.15 * sin(_time * 2.0 + phase)
