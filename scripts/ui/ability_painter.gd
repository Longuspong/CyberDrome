class_name AbilityPainter
extends Node2D

## Faehigkeiten lesbar machen (DROME_DESIGNREGELN Abschnitt 7, 18. Nov. 2026).
##
## Jede Faehigkeit beantwortet drei Fragen: **Wo?** (Marke am Boden in
## Iso-Perspektive), **Wer?** (Signalfarbe des Ausloesers) und **Was?** (eigene
## Form je Faehigkeit). Zuerst der Vortex des Runenstabs:
##
## 1. Waehrend der Verzoegerung (0,6 s) ein gestrichelter Iso-Ring ueber die
##    ganze Flaeche, Runen drehen sich nach innen, Sog-Pfeile zeigen zur Mitte.
## 2. Beim Einschlag eine Schockwelle von innen nach aussen.
## 3. Danach "verlangsamt" an jedem Getroffenen: ein Ring am Fuss und
##    Pfeile nach unten ueber dem Kopf, solange der Status laeuft.
##
## Die Bodenmarken liegen unter den DROMEs (eigener z_index), die Pfeile ueber
## dem Kopf in einer Ebene darueber (``_air``).

const SLOW_COLOR := Color(0.45, 0.7, 1.0)
const SHADE := Color(0.04, 0.02, 0.1)
const SHOCK_TIME := 0.35
## Die Bodenmarke reicht eine halbe Feldbreite ueber den Radius hinaus --
## die Felder am Rand gehoeren noch dazu.
const EDGE_MARGIN := 0.5
const RUNES := 6
const ARROWS := 6
## Pfeile ueber dem Kopf: Hoehe ueber dem Fusspunkt (Bildpunkte, 2D-Welt).
const HEAD_HEIGHT := 92.0

var pixel_scale: float = 1.0
## Einheiten, deren Statuseffekte als Marke gezeigt werden (BattleScreen).
var units: Array = []

var _marks: Array = []
var _air: Node2D
var _time := 0.0


func _init() -> void:
	z_index = -30                  # ueber Zone (-40), unter Ringen und DROMEs
	_air = Node2D.new()
	_air.name = "Ueberkopf"
	_air.z_as_relative = false
	_air.z_index = 4003            # ueber der 3D-Szene (4000), unter den Balken (4005)
	_air.draw.connect(_draw_air)
	add_child(_air)


## Vortex: ``center`` ist die Feldmitte des Ziels (2D-Welt), ``radius`` in
## Hexschritten, ``delay`` die Verzoegerung bis zum Einschlag.
func add_vortex(center: Vector2, radius: int, delay: float, color: Color) -> void:
	_marks.append({"kind": "vortex", "at": center, "radius": float(radius),
		"delay": maxf(0.05, delay), "age": 0.0, "color": color,
		"spin": fmod(absf(center.x * 0.13 + center.y * 0.29), TAU)})


func is_idle() -> bool:
	return _marks.is_empty() and not _any_status()


func _any_status() -> bool:
	for unit in units:
		if is_instance_valid(unit) and unit.is_alive() and unit.statuses.has(&"slow"):
			return true
	return false


func _process(delta: float) -> void:
	_time += delta
	for mark in _marks:
		mark["age"] = float(mark["age"]) + delta
	_marks = _marks.filter(func(m): return float(m["age"]) < float(m["delay"]) + SHOCK_TIME)
	queue_redraw()
	_air.queue_redraw()


## Halbachsen der Iso-Ellipse fuer ``radius`` Hexschritte.
static func ellipse_axes(radius: float) -> Vector2:
	var steps := radius + EDGE_MARGIN
	return Vector2(steps * IsoView.TILE_W, steps * IsoView.ROW_H)


func _draw() -> void:
	for mark in _marks:
		if mark["kind"] == "vortex":
			_draw_vortex(mark)
	for unit in units:
		if is_instance_valid(unit) and unit.is_alive() and unit.statuses.has(&"slow"):
			_draw_slow_ring(unit)


func _width(base: float) -> float:
	return base * maxf(1.0, pixel_scale * 0.7)


func _draw_vortex(mark: Dictionary) -> void:
	var at: Vector2 = mark["at"]
	var axes := ellipse_axes(float(mark["radius"]))
	var color: Color = mark["color"]
	var age: float = mark["age"]
	var delay: float = mark["delay"]
	if age < delay:
		var k := age / delay
		var fade_in := clampf(age / 0.12, 0.0, 1.0)
		# Wo: gestrichelter Ring, der sich langsam dreht, dazu eine zarte Flaeche.
		_fill_ellipse(at, axes, Color(color, 0.16 * fade_in))
		_dashed_ellipse(at, axes, Color(color.lightened(0.2), fade_in), _width(3.0),
			float(mark["spin"]) + age * 1.6, 18)
		# Was: Runen kreisen und wandern nach innen.
		for i in RUNES:
			var ang := float(mark["spin"]) + i * TAU / RUNES + age * 4.0
			var reach := lerpf(0.85, 0.2, ease(k, 1.6))
			var pos := at + Vector2(cos(ang) * axes.x, sin(ang) * axes.y) * reach
			_rune(pos, i, Color(color.lightened(0.45), fade_in), 6.0 * maxf(1.0, pixel_scale * 0.8))
		# Sog-Pfeile: von aussen zur Mitte, laufen in Wellen.
		for i in ARROWS:
			var ang := i * TAU / ARROWS + TAU / (ARROWS * 2.0)
			var dir := Vector2(cos(ang) * axes.x, sin(ang) * axes.y)
			var wave := fmod(age * 2.2 + float(i % 2) * 0.5, 1.0)
			var tail := at + dir * lerpf(0.95, 0.45, wave)
			var head := at + dir * lerpf(0.75, 0.25, wave)
			_arrow(tail, head, Color(color, 0.85 * fade_in * (1.0 - wave * 0.6)), _width(2.0))
		# Kern in der Mitte zieht sich zusammen.
		var core := lerpf(0.25, 0.08, k)
		_fill_ellipse(at, axes * core, Color(color.lightened(0.3), 0.35 * fade_in))
	else:
		# Einschlag: Schockwelle von innen nach aussen.
		var t := (age - delay) / SHOCK_TIME
		var fade := 1.0 - t
		_ellipse(at, axes * lerpf(0.15, 1.05, ease(t, 0.4)),
			Color(color.lightened(0.5), fade), _width(4.0))
		_ellipse(at, axes * lerpf(0.1, 0.8, ease(t, 0.4)),
			Color(1, 1, 1, fade * 0.7), _width(2.0))
		_fill_ellipse(at, axes * lerpf(0.2, 1.0, t), Color(color, 0.18 * fade))


## Ring am Fuss eines verlangsamten DROME: gestrichelt, dreht langsam.
func _draw_slow_ring(unit) -> void:
	var at: Vector2 = unit.visual_anchor()
	var axes := Vector2(26.0, 26.0 * IsoView.TILE_H / IsoView.TILE_W)
	var left := _slow_left(unit)
	var alpha := clampf(left / 0.4, 0.0, 1.0)
	_dashed_ellipse(at, axes, Color(SLOW_COLOR, 0.9 * alpha), _width(2.0), -_time * 1.2, 10)


func _slow_left(unit) -> float:
	var status: Dictionary = unit.statuses.get(&"slow", {})
	return float(status.get("seconds_left", 0.0))


## Pfeile nach unten ueber dem Kopf jedes Verlangsamten.
func _draw_air() -> void:
	for unit in units:
		if not (is_instance_valid(unit) and unit.is_alive() and unit.statuses.has(&"slow")):
			continue
		var alpha := clampf(_slow_left(unit) / 0.4, 0.0, 1.0)
		var top: Vector2 = unit.visual_anchor() + Vector2(0, -HEAD_HEIGHT * maxf(1.0, pixel_scale * 0.5))
		var size := 6.0 * maxf(1.0, pixel_scale * 0.8)
		var drift := fmod(_time * 1.5, 1.0) * size * 0.6
		for i in 2:
			var x := (float(i) - 0.5) * size * 1.6
			var tip := top + Vector2(x, size + drift)
			var points := PackedVector2Array([tip + Vector2(-size * 0.7, -size),
				tip, tip + Vector2(size * 0.7, -size)])
			_air.draw_polyline(points, Color(SHADE, alpha * 0.8), _width(4.0), true)
			_air.draw_polyline(points, Color(SLOW_COLOR, alpha), _width(2.2), true)


# ---------------------------------------------------------------------------
# Formen
# ---------------------------------------------------------------------------

func _ellipse_points(at: Vector2, axes: Vector2, from: float, to: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		var ang := lerpf(from, to, float(i) / float(steps))
		points.append(at + Vector2(cos(ang) * axes.x, sin(ang) * axes.y))
	return points


func _ellipse(at: Vector2, axes: Vector2, color: Color, width: float) -> void:
	draw_polyline(_ellipse_points(at, axes, 0.0, TAU, 40), color, width, true)


func _fill_ellipse(at: Vector2, axes: Vector2, color: Color) -> void:
	var points := _ellipse_points(at, axes, 0.0, TAU, 32)
	points.remove_at(points.size() - 1)
	draw_colored_polygon(points, color)


func _dashed_ellipse(at: Vector2, axes: Vector2, color: Color, width: float,
		offset: float, dashes: int) -> void:
	var step := TAU / float(dashes)
	for i in dashes:
		var from := offset + i * step
		var points := _ellipse_points(at, axes, from, from + step * 0.55, 5)
		# Dunkle Unterlage: lesbar auch auf hellen und bunten Boeden.
		draw_polyline(points, Color(SHADE, color.a * 0.6), width * 2.2, true)
		draw_polyline(points, color, width, true)


func _arrow(tail: Vector2, head: Vector2, color: Color, width: float) -> void:
	var dir := (head - tail).normalized()
	var side := dir.orthogonal()
	var size := 5.0 * maxf(1.0, pixel_scale * 0.8)
	var tip := PackedVector2Array([head - dir * size + side * size * 0.7, head,
		head - dir * size - side * size * 0.7])
	draw_line(tail, head, Color(SHADE, color.a * 0.6), width * 2.2, true)
	draw_polyline(tip, Color(SHADE, color.a * 0.6), width * 2.2, true)
	draw_line(tail, head, color, width, true)
	draw_polyline(tip, color, width, true)


## Eine Rune: drei einfache Zeichen im Wechsel (Raute, Dreieck, Kreuz).
func _rune(at: Vector2, index: int, color: Color, size: float) -> void:
	var w := _width(1.8)
	match index % 3:
		0:
			draw_polyline(PackedVector2Array([at + Vector2(0, -size), at + Vector2(size * 0.7, 0),
				at + Vector2(0, size), at + Vector2(-size * 0.7, 0), at + Vector2(0, -size)]),
				color, w, true)
		1:
			draw_polyline(PackedVector2Array([at + Vector2(0, -size), at + Vector2(size * 0.8, size * 0.6),
				at + Vector2(-size * 0.8, size * 0.6), at + Vector2(0, -size)]), color, w, true)
		_:
			draw_line(at + Vector2(-size * 0.7, -size * 0.7), at + Vector2(size * 0.7, size * 0.7), color, w, true)
			draw_line(at + Vector2(size * 0.7, -size * 0.7), at + Vector2(-size * 0.7, size * 0.7), color, w, true)
