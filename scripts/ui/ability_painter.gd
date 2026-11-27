class_name AbilityPainter
extends Node2D

## Faehigkeiten lesbar machen (DROME_DESIGNREGELN Abschnitt 7, 18. Nov. 2026).
##
## Jede Faehigkeit beantwortet drei Fragen: **Wo?** (Marke am Boden in
## Iso-Perspektive), **Wer?** (Signalfarbe des Ausloesers) und **Was?** (eigene
## Form je Faehigkeit). Seit 18. Nov. 2026 alle Faehigkeiten (Formen nach der
## Leinwand "Faehigkeiten lesbar", Zuordnung in ``kind_for``); Gegner-
## Faehigkeiten bekommen einen roten Aussenrand. Am Beispiel Vortex:
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
const STUN_COLOR := Color(1.0, 0.88, 0.3)
const VULN_COLOR := Color(1.0, 0.37, 0.78)
const SHIELD_COLOR := Color(0.49, 0.98, 1.0)
const FIRE_COLOR := Color(1.0, 0.69, 0.34)
## Gegner-Faehigkeiten: durchgehender roter Aussenrand um die Bodenmarke --
## "das kommt auf MICH zu".
const ENEMY_RIM := Color(1.0, 0.23, 0.23)
const SHADE := Color(0.04, 0.02, 0.1)
const SHOCK_TIME := 0.35
## Die Bodenmarke reicht eine halbe Feldbreite ueber den Radius hinaus --
## die Felder am Rand gehoeren noch dazu.
const EDGE_MARGIN := 0.5
const RUNES := 6
const ARROWS := 6
## Ueber dem Kopf: Hoehe ueber dem Fusspunkt (Bildpunkte, 2D-Welt).
const HEAD_HEIGHT := 92.0
## Brusthoehe fuer Strahlen und Schilde.
const CHEST := 40.0
## Dauer der Formen ohne Verzoegerung (Sekunden).
const LIFE := {"lock": 0.35, "breaker": 0.4, "double": 0.25,
	"stun": 0.45, "push": 0.5, "slash": 0.35, "whirl": 0.8,
	"shield": 0.75}
## Fussring eines Zustands (Halbachse waagerecht).
const FOOT_RING := 26.0

var pixel_scale: float = 1.0
## Das Kampffeld -- fuer die Felder einer Flaechenmarke (Kampfbild mehr 3D B8,
## 21. Nov. 2026). Ohne Feld (Tests) zaehlen alle Felder im Radius.
var grid: Grid = null
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


## Welche Form eine Faehigkeit bekommt -- nach ihren Eigenschaften, damit
## auch Varianten (Module, Gegner) passen. "" = keine eigene Form.
static func kind_for(action: ActionData) -> String:
	if action == null or action.is_attack() or action.is_move():
		return ""
	if action.shield_gain > 0:
		return "shield"
	if action.gather and action.aoe_radius > 0:
		return "vortex"
	if action.aoe_radius > 0 and action.delay > 0.0:
		return "barrage"
	if action.aoe_radius > 0:
		return "whirl"
	if action.shots > 1:
		return "double"
	if action.shield_mult > 1.0:
		return "breaker"
	var status := str(action.status.get("id", ""))
	if status == "stun":
		return "stun"
	if status == "vulnerable":
		return "slash"
	if action.push_tiles > 0:
		return "push"
	if action.range_tiles >= 3:
		return "lock"
	return ""


## Vortex: ``center`` ist die Feldmitte des Ziels (2D-Welt), ``radius`` in
## Hexschritten, ``delay`` die Verzoegerung bis zum Einschlag.
func add_vortex(center: Vector2, radius: int, delay: float, color: Color, enemy: bool = false) -> void:
	_add({"kind": "vortex", "at": center, "radius": float(radius),
		"delay": maxf(0.05, delay), "color": color, "enemy": enemy})


## Eine Form allgemein. Felder je Art:
##   alle      at (Feldmitte des Ziels), color, enemy
##   barrage   radius, delay          whirl  radius
##   lock      from (Fusspunkt des Schuetzen)
##   push      dir (Einheitsvektor der Stossrichtung, 2D)
##   double    targets (Feldmitten, 1-2)
##   shield    from (Fusspunkt des Helfers, nur bei Verbuendetem)
func add(kind: String, data: Dictionary) -> void:
	var mark := data.duplicate()
	mark["kind"] = kind
	if kind == "barrage":
		mark["delay"] = maxf(0.05, float(mark.get("delay", 0.8)))
	_add(mark)


func _add(mark: Dictionary) -> void:
	var at: Vector2 = mark.get("at", Vector2.ZERO)
	# "wait": erst nach so vielen Sekunden sichtbar (Abfolge, z. B. erst der
	# Schuss, dann das zerspringende Schild).
	mark["age"] = -float(mark.get("wait", 0.0))
	mark["spin"] = fmod(absf(at.x * 0.13 + at.y * 0.29), TAU)
	if not mark.has("color"):
		mark["color"] = Color.WHITE
	_marks.append(mark)


func _life(mark: Dictionary) -> float:
	if str(mark["kind"]).ends_with("_cast"):
		return float(mark.get("time", 0.4))
	match str(mark["kind"]):
		"vortex":
			return float(mark["delay"]) + SHOCK_TIME
		"barrage":
			return float(mark["delay"]) + 0.45
	return float(LIFE.get(str(mark["kind"]), 0.5))


func is_idle() -> bool:
	return _marks.is_empty() and not _any_status()


func _any_status() -> bool:
	for unit in units:
		if _shows_status(unit):
			return true
	return false


func _shows_status(unit) -> bool:
	if not (is_instance_valid(unit) and unit.is_alive()):
		return false
	return unit.statuses.has(&"slow") or unit.statuses.has(&"stun") \
		or unit.statuses.has(&"vulnerable")


func _process(delta: float) -> void:
	_time += delta
	for mark in _marks:
		mark["age"] = float(mark["age"]) + delta
	_marks = _marks.filter(func(m): return float(m["age"]) < _life(m))
	queue_redraw()
	_air.queue_redraw()


## Halbachsen der Iso-Ellipse fuer ``radius`` Hexschritte.
static func ellipse_axes(radius: float) -> Vector2:
	var steps := radius + EDGE_MARGIN
	return Vector2(steps * IsoView.TILE_W, steps * IsoView.ROW_H)


static func foot_axes(scale: float = 1.0) -> Vector2:
	return Vector2(FOOT_RING, FOOT_RING * IsoView.TILE_H / IsoView.TILE_W) * scale


# ---------------------------------------------------------------------------
# Boden (unter den DROMEs)
# ---------------------------------------------------------------------------

## Ansage (18. Nov. 2026): laeuft waehrend der Ausholzeit einer Faehigkeit,
## ``time`` Sekunden lang. Arten: "<art>_cast" zu den Arten von kind_for;
## Nahkampf (stun, push, slash) teilt sich "melee_cast".
func add_cast(kind: String, data: Dictionary, seconds: float) -> void:
	var mark := data.duplicate()
	mark["time"] = maxf(0.05, seconds)
	mark["kind"] = ("melee" if kind in ["stun", "push", "slash"] else kind) + "_cast"
	_add(mark)


func _draw() -> void:
	for mark in _marks:
		if float(mark["age"]) < 0.0:
			continue
		match str(mark["kind"]):
			"vortex":
				_draw_vortex(mark)
			"barrage":
				_draw_barrage(mark)
			"whirl":
				_draw_whirl_ground(mark)
			"stun":
				_draw_stun_wave(mark)
			"push":
				_draw_push(mark)
			"lock_cast":
				_draw_lock_ground(mark)
			"double_cast":
				_draw_double_ground(mark)
			"shield_cast":
				_draw_shield_ground(mark)
			"melee_cast":
				_draw_melee_cast(mark)
			"whirl_cast":
				_draw_whirl_cast(mark)
	for unit in units:
		if not _shows_status(unit):
			continue
		var at: Vector2 = unit.visual_anchor()
		if unit.statuses.has(&"slow"):
			var alpha := clampf(_status_left(unit, &"slow") / 0.4, 0.0, 1.0)
			_dashed_ellipse(at, foot_axes(), Color(SLOW_COLOR, 0.9 * alpha), _width(2.0), -_time * 1.2, 10)
		if unit.statuses.has(&"vulnerable"):
			var alpha := clampf(_status_left(unit, &"vulnerable") / 0.4, 0.0, 1.0)
			_dashed_ellipse(at, foot_axes(1.18), Color(VULN_COLOR, 0.9 * alpha), _width(2.0), _time * 0.9, 12)


# ---------------------------------------------------------------------------
# Felder statt Ellipse (Kampfbild mehr 3D B8, 21. Nov. 2026)
# ---------------------------------------------------------------------------
# Die Marke liegt auf den Platten: genau die Felder, die die Logik trifft,
# leicht gefuellt, die Aussenkante leuchtet. Die Fuellung waechst mit der
# Ausholzeit. Ringe, Runen und Pfeile bleiben obendrauf ("Was?").

## Die Felder einer Marke: alle im Radius um das Feld unter ``at``.
func area_tiles(at: Vector2, radius: int) -> Array:
	var center := IsoView.local_to_map(at)
	var out: Array = []
	for dy in range(-radius - 1, radius + 2):
		for dx in range(-radius, radius + 1):
			var tile := center + Vector2i(dx, dy)
			if Grid.distance(center, tile) > radius:
				continue
			if grid != null and not grid.in_bounds(tile):
				continue
			out.append(tile)
	return out


func _cells_of(mark: Dictionary) -> Array:
	if not mark.has("cells"):
		mark["cells"] = area_tiles(mark["at"], int(mark.get("radius", 0)))
	return mark["cells"]


## Felder fuellen (``fill`` Deckkraft) und die Aussenkante leuchten lassen.
func _draw_cells(cells: Array, color: Color, fill: float, edge: float, enemy: bool = false) -> void:
	if cells.is_empty() or (fill <= 0.0 and edge <= 0.0):
		return
	var inside: Dictionary = {}
	for tile in cells:
		inside[tile] = true
	for tile in cells:
		var corners := IsoView.tile_corners(tile)
		if fill > 0.0:
			draw_colored_polygon(corners, Color(color, fill))
	var rim := ENEMY_RIM if enemy else color.lightened(0.25)
	for pass_width in [6.0, 2.2]:
		var alpha := edge * (0.28 if pass_width > 3.0 else 0.95)
		for tile in cells:
			var corners := IsoView.tile_corners(tile)
			for i in 6:
				if inside.has(Grid.neighbor(tile, IsoView.EDGE_DIR[i])):
					continue
				draw_line(corners[i], corners[(i + 1) % 6], Color(rim, alpha), _width(pass_width), true)


func _width(base: float) -> float:
	return base * maxf(1.0, pixel_scale * 0.7)


## Roter Aussenrand fuer Gegner-Faehigkeiten.
func _enemy_rim(mark: Dictionary, at: Vector2, axes: Vector2, alpha: float) -> void:
	if bool(mark.get("enemy", false)):
		_ellipse(at, axes * 1.04, Color(ENEMY_RIM, 0.9 * alpha), _width(4.5))


func _draw_vortex(mark: Dictionary) -> void:
	var at: Vector2 = mark["at"]
	var axes := ellipse_axes(float(mark["radius"]))
	var color: Color = mark["color"]
	var age: float = mark["age"]
	var delay: float = mark["delay"]
	if age < delay:
		var k := age / delay
		var fade_in := clampf(age / 0.12, 0.0, 1.0)
		# Wo: genau die Felder, Fuellung waechst bis zum Einschlag; darueber
		# der gestrichelte Ring, der sich langsam dreht.
		_draw_cells(_cells_of(mark), color, (0.08 + 0.2 * k) * fade_in, fade_in,
			bool(mark.get("enemy", false)))
		_enemy_rim(mark, at, axes, fade_in)
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
		_draw_cells(_cells_of(mark), color.lightened(0.3), 0.3 * fade, fade,
			bool(mark.get("enemy", false)))


## Drei Einschlagstellen im Ring -- fest je Ziel, damit nichts springt.
func _barrage_spots(mark: Dictionary, axes: Vector2) -> Array:
	var spots := []
	for i in 3:
		var ang := float(mark["spin"]) + i * TAU / 3.0
		var reach := 0.32 + 0.18 * float(i % 2)
		spots.append(Vector2(cos(ang) * axes.x, sin(ang) * axes.y) * reach)
	return spots


## Sperrfeuer: Ring mit drei Fadenkreuzen waehrend der Verzoegerung, dann
## drei Feuerringe und Stoss-Pfeile nach aussen.
func _draw_barrage(mark: Dictionary) -> void:
	var at: Vector2 = mark["at"]
	var axes := ellipse_axes(float(mark["radius"]))
	var color: Color = mark["color"]
	var age: float = mark["age"]
	var delay: float = mark["delay"]
	var spots := _barrage_spots(mark, axes)
	if age < delay:
		var fade_in := clampf(age / 0.12, 0.0, 1.0)
		var k := age / delay
		_draw_cells(_cells_of(mark), color, (0.06 + 0.18 * k) * fade_in, fade_in,
			bool(mark.get("enemy", false)))
		_dashed_ellipse(at, axes, Color(color.lightened(0.2), fade_in), _width(3.0),
			float(mark["spin"]), 16)
		for spot in spots:
			# Fadenkreuze ziehen sich bis zum Einschlag zusammen.
			_crosshair(at + spot, lerpf(1.6, 1.0, k), Color(color.lightened(0.35), fade_in))
	else:
		var t := (age - delay) / 0.45
		var fade := 1.0 - t
		_draw_cells(_cells_of(mark), FIRE_COLOR, 0.22 * fade, fade, bool(mark.get("enemy", false)))
		for spot in spots:
			var r := foot_axes(lerpf(0.5, 1.2, ease(t, 0.4)))
			_ellipse(at + spot, r, Color(FIRE_COLOR, fade), _width(3.5))
			_fill_ellipse(at + spot, r * 0.5, Color(1.0, 0.95, 0.75, 0.7 * fade))
		for i in 4:
			var ang := float(mark["spin"]) + PI / 4.0 + i * TAU / 4.0
			var dir := Vector2(cos(ang) * axes.x, sin(ang) * axes.y)
			_arrow(at + dir * lerpf(0.5, 0.75, t), at + dir * lerpf(0.75, 1.05, t),
				Color(color, fade), _width(3.0))


func _draw_whirl_ground(mark: Dictionary) -> void:
	var at: Vector2 = mark["at"]
	var axes := ellipse_axes(float(mark["radius"]))
	var color: Color = mark["color"]
	var t: float = float(mark["age"]) / _life(mark)
	var fade := 1.0 - maxf(0.0, t - 0.7) / 0.3
	_draw_cells(_cells_of(mark), color, 0.14 * fade, fade, bool(mark.get("enemy", false)))
	_dashed_ellipse(at, axes, Color(color.lightened(0.2), fade), _width(2.6), float(mark["spin"]), 14)
	# Kreisspur hinter dem Bumerang (zeichnet die Luftebene).
	var head := float(mark["spin"]) + minf(t / 0.7, 1.0) * TAU * 1.1
	draw_polyline(_ellipse_points(at, axes * 0.9, head - 2.4, head, 16),
		Color(color.lightened(0.4), 0.85 * fade), _width(4.0), true)


## Nahkampf, Ansage: gestrichelter Ring am Ziel, waehrend ausgeholt wird;
## beim Rammstoss dazu der Pfeil der Stossrichtung.
func _draw_melee_cast(mark: Dictionary) -> void:
	var t: float = float(mark["age"]) / _life(mark)
	var at: Vector2 = mark["at"]
	var color: Color = mark["color"]
	_draw_cells(_cells_of(mark), color, 0.05 + 0.22 * t, 0.4 + 0.6 * t, bool(mark.get("enemy", false)))
	_dashed_ellipse(at, foot_axes(lerpf(1.6, 1.15, ease(t, 0.5))), color, _width(2.8), _time * 2.5, 10)
	if mark.has("dir") and str(mark.get("ability", "")) == "push":
		var dir: Vector2 = mark["dir"]
		var step := dir * IsoView.TILE_W
		_arrow(at + step * 0.35, at + step * 0.85, Color(color, 0.6 + 0.4 * t), _width(2.4))


## Wirbelwurf, Ansage: Ring um das Ziel.
func _draw_whirl_cast(mark: Dictionary) -> void:
	var t: float = float(mark["age"]) / _life(mark)
	var at: Vector2 = mark["at"]
	var axes := ellipse_axes(float(mark.get("radius", 1)))
	if not mark.has("radius"):
		mark["radius"] = 1
	_draw_cells(_cells_of(mark), mark["color"], 0.04 + 0.2 * t, 0.5 + 0.5 * t, bool(mark.get("enemy", false)))
	_dashed_ellipse(at, axes, Color(mark["color"], 0.5 + 0.5 * t), _width(2.6), float(mark["spin"]) - _time, 14)


func _draw_stun_wave(mark: Dictionary) -> void:
	var at: Vector2 = mark["at"]
	var t: float = float(mark["age"]) / _life(mark)
	for i in 3:
		var k := clampf(t * 1.4 - i * 0.18, 0.0, 1.0)
		if k <= 0.0:
			continue
		_ellipse(at, foot_axes(lerpf(0.6, 2.2, ease(k, 0.5))),
			Color(mark["color"], (1.0 - k) * (1.0 - i * 0.25)), _width(3.0 - i * 0.6))


func _draw_push(mark: Dictionary) -> void:
	var at: Vector2 = mark["at"]
	var dir: Vector2 = mark.get("dir", Vector2.UP)
	var t: float = float(mark["age"]) / _life(mark)
	var fade := 1.0 - t
	var step := dir * IsoView.TILE_W
	_arrow(at - step * 0.15, at + step * lerpf(0.55, 0.95, ease(t, 0.4)),
		Color(mark["color"], fade), _width(4.0))
	# Staubspur hinter dem Gestossenen.
	for i in 3:
		var p := at + step * (0.2 + 0.25 * i) + Vector2(0, -2)
		draw_circle(p, (5.0 - i) * maxf(1.0, pixel_scale * 0.6), Color(0.56, 0.5, 0.74, 0.55 * fade * (1.0 - i * 0.25)))


func _draw_lock_ground(mark: Dictionary) -> void:
	# Rautenmarke am Fuss des Ziels ("Lock"), solange der Laser zielt.
	var t: float = float(mark["age"]) / _life(mark)
	if t > 0.6:
		return
	var at: Vector2 = mark["at"]
	var r := FOOT_RING * lerpf(1.3, 0.9, t / 0.6)
	var points := PackedVector2Array([at + Vector2(0, -r * 0.6), at + Vector2(r, 0),
		at + Vector2(0, r * 0.6), at + Vector2(-r, 0), at + Vector2(0, -r * 0.6)])
	draw_polyline(points, Color(SHADE, 0.6), _width(5.0), true)
	draw_polyline(points, Color(mark["color"]), _width(2.6), true)


func _draw_double_ground(mark: Dictionary) -> void:
	var t: float = float(mark["age"]) / _life(mark)
	var fade := 1.0 - maxf(0.0, t - 0.6) / 0.4
	for target in mark.get("targets", []):
		_ellipse(target, foot_axes(1.1), Color(SHADE, 0.6 * fade), _width(5.0))
		_ellipse(target, foot_axes(1.1), Color(mark["color"], fade), _width(2.6))


func _draw_shield_ground(mark: Dictionary) -> void:
	var t: float = float(mark["age"]) / _life(mark)
	var fade := 1.0 - maxf(0.0, t - 0.7) / 0.3
	_dashed_ellipse(mark["at"], foot_axes(1.2), Color(SHIELD_COLOR, fade), _width(2.6), _time * 2.0, 10)


func _status_left(unit, id: StringName) -> float:
	var status: Dictionary = unit.statuses.get(id, {})
	return float(status.get("seconds_left", 0.0))


# ---------------------------------------------------------------------------
# Ueber den DROMEs
# ---------------------------------------------------------------------------

func _draw_air() -> void:
	for mark in _marks:
		if float(mark["age"]) < 0.0:
			continue
		match str(mark["kind"]):
			"lock_cast":
				_air_laser(mark)
			"lock":
				_air_beam(mark)
			"vortex_cast":
				_air_vortex_cast(mark)
			"whirl_cast":
				_air_whirl_throw(mark)
			"barrage_cast":
				_air_shell(mark)
			"double_cast":
				_air_double(mark)
			"breaker_cast":
				_air_breaker_cast(mark)
			"shield_cast":
				_air_shield_link(mark)
			"slash":
				_air_slash(mark)
			"whirl":
				_air_whirl(mark)
			"double":
				pass                      # die Schuesse zeichnet EffectPainter
			"breaker":
				_air_breaker(mark)
			"shield":
				_air_shield(mark)
	for unit in units:
		if _shows_status(unit):
			_air_status(unit)


## Wo Schuss, Laser und Strahl beginnen: an der Muendung der Waffe, so wie
## sie gerade steht ("muzzle", Callable aus Arena3D.weapon_tip), sonst in
## Brusthoehe ueber dem Schuetzen.
func _muzzle(mark: Dictionary) -> Vector2:
	if mark.has("muzzle"):
		return (mark["muzzle"] as Callable).call()
	return mark.get("from", mark["at"]) + _lift(CHEST + 8.0)


func _lift(base: float) -> Vector2:
	return Vector2(0, -base * maxf(1.0, pixel_scale * 0.5))


## Zustaende ueber dem Kopf: verlangsamt (Pfeile nach unten), betaeubt
## (Sterne kreisen), verwundbar (gerissener Schild).
func _air_status(unit) -> void:
	var top: Vector2 = unit.visual_anchor() + _lift(HEAD_HEIGHT)
	var size := 6.0 * maxf(1.0, pixel_scale * 0.8)
	var slots := []
	for id in [&"slow", &"stun", &"vulnerable"]:
		if unit.statuses.has(id):
			slots.append(id)
	for i in slots.size():
		var id: StringName = slots[i]
		var at := top + Vector2((float(i) - (slots.size() - 1) * 0.5) * size * 4.2, 0)
		var alpha := clampf(_status_left(unit, id) / 0.4, 0.0, 1.0)
		match id:
			&"slow":
				var drift := fmod(_time * 1.5, 1.0) * size * 0.6
				for j in 2:
					var tip := at + Vector2((float(j) - 0.5) * size * 1.6, size + drift)
					_air_line(PackedVector2Array([tip + Vector2(-size * 0.7, -size), tip,
						tip + Vector2(size * 0.7, -size)]), Color(SLOW_COLOR, alpha), 2.2)
			&"stun":
				for j in 5:
					var ang := _time * 4.0 + j * TAU / 5.0
					var p := at + Vector2(cos(ang) * size * 2.4, sin(ang) * size * 0.8)
					_air_star(p, size * 0.8, Color(STUN_COLOR, alpha))
			&"vulnerable":
				var w := size * 1.3
				var shield := PackedVector2Array([at + Vector2(-w, -w), at + Vector2(w, -w),
					at + Vector2(w, w * 0.2), at + Vector2(0, w * 1.3), at + Vector2(-w, w * 0.2),
					at + Vector2(-w, -w)])
				_air_line(shield, Color(VULN_COLOR, alpha), 2.4)
				_air.draw_polyline(PackedVector2Array([at + Vector2(-w * 0.2, -w), at + Vector2(w * 0.2, -w * 0.3),
					at + Vector2(-w * 0.25, w * 0.2), at + Vector2(w * 0.1, w * 1.0)]),
					Color(SHADE, alpha), _width(2.6), true)


## Praezisionsschuss, Ansage: duenner Ziel-Laser, der sich festbeisst.
func _air_laser(mark: Dictionary) -> void:
	var t: float = float(mark["age"]) / _life(mark)
	var from := _muzzle(mark)
	var to: Vector2 = mark["at"] + _lift(CHEST)
	var color: Color = mark["color"]
	var length := from.distance_to(to)
	var dir := (to - from) / maxf(1.0, length)
	# Der Laser waechst zum Ziel, dann flimmert er bis zum Schuss.
	var reach := length * ease(clampf(t / 0.35, 0.0, 1.0), 0.5)
	var dash := 10.0 * maxf(1.0, pixel_scale * 0.6)
	var flicker := 0.7 + 0.3 * sin(_time * 40.0)
	var d := 0.0
	var bright := color.lightened(0.45)
	while d < reach:
		_air_line(PackedVector2Array([from + dir * d, from + dir * minf(d + dash * 0.6, reach)]),
			Color(bright, 0.95 * flicker), 2.4)
		d += dash
	if t > 0.35:
		# Der Laser beisst sich fest: Lichtpunkt und Zielkreuz am Ziel.
		var r := 9.0 * maxf(1.0, pixel_scale * 0.6)
		_air.draw_circle(to, r * 0.45, Color(bright, flicker))
		_air.draw_arc(to, r * lerpf(1.8, 1.0, ease((t - 0.35) / 0.65, 0.5)), 0.0, TAU, 20,
			Color(bright, 0.9), _width(2.0), true)


## Praezisionsschuss, Wirkung: dicker Strahl durch das Ziel, Trefferring.
func _air_beam(mark: Dictionary) -> void:
	var k: float = float(mark["age"]) / _life(mark)
	var from := _muzzle(mark)
	var to: Vector2 = mark["at"] + _lift(CHEST)
	var color: Color = mark["color"]
	var fade := 1.0 - k
	var end := from + (to - from) * lerpf(1.0, 1.35, ease(minf(1.0, k * 3.0), 0.4))
	_air.draw_line(from, end, Color(1, 1, 1, 0.25 * fade), _width(10.0), true)
	_air.draw_line(from, end, Color(color.lightened(0.3), fade), _width(4.0), true)
	_air.draw_arc(to, 14.0 * maxf(1.0, pixel_scale * 0.6) * (1.0 + k), 0.0, TAU, 20,
		Color(1, 1, 1, fade), _width(2.4), true)


## Runenstab, Ansage: der Stab leuchtet hochgehalten auf (erste 40 %), dann
## fliegt die Runenkugel im Bogen zum Ziel.
func _air_vortex_cast(mark: Dictionary) -> void:
	var t: float = float(mark["age"]) / _life(mark)
	var color: Color = mark["color"]
	var release := float(mark.get("release", 0.4))
	var top: Vector2 = mark.get("from", mark["at"]) + _lift(HEAD_HEIGHT + 4.0)
	if mark.has("tip"):
		# Die Kugel sitzt an der Stabspitze und loest sich in der Mitte des
		# Schwungs -- dort, wo die Spitze dann ist.
		if t < release or not mark.has("tip_at"):
			mark["tip_at"] = (mark["tip"] as Callable).call()
		top = mark["tip_at"]
	var to: Vector2 = mark["at"] + _lift(CHEST)
	var r := 6.0 * maxf(1.0, pixel_scale * 0.7)
	if t < release:
		var g := ease(minf(1.0, t / (release * 0.6)), 0.5)
		_air.draw_circle(top, r * 2.6 * g, Color(color, 0.25))
		_air.draw_circle(top, r * g, Color(color.lightened(0.5), 0.95))
		for i in 4:
			var ang := _time * 6.0 + i * TAU / 4.0
			_air.draw_circle(top + Vector2(cos(ang), sin(ang) * 0.6) * r * 2.2 * g, 1.6 * maxf(1.0, pixel_scale * 0.5),
				Color(color.lightened(0.6), 0.9))
		return
	var k := (t - release) / (1.0 - release)
	var mid := (top + to) * 0.5 + _lift(70.0)
	for j in 6:
		var u := clampf(k - j * 0.04, 0.0, 1.0)
		var p := top.lerp(mid, u).lerp(mid.lerp(to, u), u)
		_air.draw_circle(p, r * (1.0 - j * 0.14), Color(color.lightened(0.3 + j * 0.05), 0.9 - j * 0.14))
	var u0 := k
	var head := top.lerp(mid, u0).lerp(mid.lerp(to, u0), u0)
	_air.draw_circle(head, r * 1.8, Color(color, 0.25))
	_air.draw_circle(head, r * 0.5, Color(1, 1, 1, 0.95))


## Sperrfeuer, Ansage: die Granate steigt aus dem Moerser steil nach oben.
func _air_shell(mark: Dictionary) -> void:
	var t: float = float(mark["age"]) / _life(mark)
	var base: Vector2 = _muzzle(mark) if mark.has("muzzle") \
		else mark.get("from", mark["at"]) + _lift(HEAD_HEIGHT - 10.0)
	var p := base + Vector2(0, -260.0 * ease(t, 0.6))
	var r := 4.0 * maxf(1.0, pixel_scale * 0.6)
	_air.draw_line(base, p, Color(FIRE_COLOR, 0.45 * (1.0 - t)), _width(3.0), true)
	_air.draw_circle(p, r, Color(1.0, 0.95, 0.75))
	_air.draw_circle(base, r * 2.4 * (1.0 - t), Color(FIRE_COLOR, 0.6 * (1.0 - t)))


## Schildbrecher, Ansage: das Schild des Ziels leuchtet als Sechseck auf.
func _air_breaker_cast(mark: Dictionary) -> void:
	var t: float = float(mark["age"]) / _life(mark)
	var at: Vector2 = mark["at"] + _lift(CHEST)
	var r := 26.0 * maxf(1.0, pixel_scale * 0.6)
	var pulse := 0.6 + 0.4 * sin(_time * 18.0)
	_air_hex(at, r * lerpf(1.3, 1.0, ease(t, 0.4)), Color(SHIELD_COLOR, 0.9 * pulse), 2.6)


## Schildfeld, Ansage: gestrichelter Bogen zum Verbuendeten.
func _air_shield_link(mark: Dictionary) -> void:
	if not mark.has("from"):
		return
	var t: float = float(mark["age"]) / _life(mark)
	var a: Vector2 = mark["from"] + _lift(CHEST + 10.0)
	var b: Vector2 = mark["at"] + _lift(CHEST + 10.0)
	var mid := (a + b) * 0.5 + _lift(40.0)
	for i in 12:
		if i % 2 == 1:
			continue
		var u0 := float(i) / 12.0 * t
		var u1 := float(i + 1) / 12.0 * t
		var p0 := a.lerp(mid, u0).lerp(mid.lerp(b, u0), u0)
		var p1 := a.lerp(mid, u1).lerp(mid.lerp(b, u1), u1)
		_air_line(PackedVector2Array([p0, p1]), Color(SHIELD_COLOR, 0.9), 2.4)


func _air_slash(mark: Dictionary) -> void:
	var t: float = float(mark["age"]) / _life(mark)
	var at: Vector2 = mark["at"] + _lift(CHEST + 10.0)
	var size := 16.0 * maxf(1.0, pixel_scale * 0.7)
	for i in 3:
		var k := clampf(t * 2.2 - i * 0.3, 0.0, 1.0)
		if k <= 0.0:
			continue
		var off := Vector2((i - 1) * size * 0.55, 0)
		var a := at + off + Vector2(-size * 0.5, -size)
		var b := at + off + Vector2(size * 0.5, size)
		_air_line(PackedVector2Array([a, a.lerp(b, ease(k, 0.4))]),
			Color(VULN_COLOR, 1.0 - maxf(0.0, t - 0.6) / 0.4), 3.6)


## Der Bumerang selbst: zwei Fluegel, die sich drehen.
func _draw_boomerang(at: Vector2) -> void:
	var size := 13.0 * maxf(1.0, pixel_scale * 0.7)
	var turn := _time * 16.0
	# Wirbelspur: ein heller Kreisbogen um die Drehmitte.
	_air.draw_arc(at, size * 1.25, turn, turn + 2.2, 12, Color(1.0, 0.75, 0.2, 0.55), _width(2.4), true)
	var wing := PackedVector2Array()
	for p in [Vector2(-1.2, 0.2), Vector2(-0.15, -0.45), Vector2(0, -0.5), Vector2(1.2, 0.2),
			Vector2(0, -0.1)]:
		wing.append(at + p.rotated(turn) * size)
	_air.draw_colored_polygon(wing, Color(0.86, 0.9, 0.95))
	wing.append(wing[0])
	_air.draw_polyline(wing, Color(1.0, 0.69, 0.0), _width(2.4), true)
	_air.draw_polyline(wing, SHADE, _width(1.0), true)


## Wo der Bumerang in seine Kreisbahn um das Ziel einfaedelt.
func _orbit_point(mark: Dictionary, turns: float) -> Vector2:
	var axes := ellipse_axes(float(mark.get("radius", 1))) * 0.9
	var ang := float(mark["spin"]) + turns * TAU
	return mark["at"] + Vector2(cos(ang) * axes.x, sin(ang) * axes.y) + _lift(14.0)


## Wirbelwurf, Ansage: nach dem Loslassen fliegt der Bumerang zum Ziel.
func _air_whirl_throw(mark: Dictionary) -> void:
	var t: float = float(mark["age"]) / _life(mark)
	var release := float(mark.get("release", 0.5))
	if mark.has("tip") and (t < release or not mark.has("tip_at")):
		mark["tip_at"] = (mark["tip"] as Callable).call()
	if t < release:
		return
	var k := (t - release) / (1.0 - release)
	var start: Vector2 = mark.get("tip_at", mark.get("from", mark["at"]) + _lift(CHEST))
	var end := _orbit_point(mark, 0.0)
	var mid := (start + end) * 0.5 + _lift(30.0)
	_draw_boomerang(start.lerp(mid, k).lerp(mid.lerp(end, k), k))


## Wirbelwurf, Wirkung: der Bumerang kreist einmal um das Ziel und fliegt
## zurueck in die Hand.
func _air_whirl(mark: Dictionary) -> void:
	var t: float = float(mark["age"]) / _life(mark)
	if t < 0.7:
		_draw_boomerang(_orbit_point(mark, t / 0.7 * 1.1))
		return
	var k := (t - 0.7) / 0.3
	var start := _orbit_point(mark, 1.1)
	var hand: Vector2 = (mark["tip"] as Callable).call() if mark.has("tip") \
		else mark.get("from", mark["at"]) + _lift(CHEST)
	_draw_boomerang(start.lerp(hand, ease(k, 0.8)))


func _air_double(mark: Dictionary) -> void:
	var t: float = float(mark["age"]) / _life(mark)
	var fade := 1.0 - maxf(0.0, t - 0.6) / 0.4
	var targets: Array = mark.get("targets", [])
	for i in targets.size():
		_air_text(targets[i] + _lift(HEAD_HEIGHT - 6.0), str(i + 1), Color(mark["color"], fade), 16)


func _air_breaker(mark: Dictionary) -> void:
	var t: float = float(mark["age"]) / _life(mark)
	var at: Vector2 = mark["at"] + _lift(CHEST)
	var r := 26.0 * maxf(1.0, pixel_scale * 0.6)
	# Das Schild-Sechseck zerspringt: sechs Scherben fliegen nach aussen.
	var k := t
	for i in 6:
		var ang := deg_to_rad(60.0 * i + 30.0)
		var p := at + Vector2(cos(ang), sin(ang)) * r * lerpf(1.0, 1.9, ease(k, 0.4))
		var shard := PackedVector2Array([p, p + Vector2(cos(ang + 1.0), sin(ang + 1.0)) * r * 0.35,
			p + Vector2(cos(ang), sin(ang)) * r * 0.45])
		_air.draw_colored_polygon(shard, Color(SHIELD_COLOR, 1.0 - k))


func _air_shield(mark: Dictionary) -> void:
	var t: float = float(mark["age"]) / _life(mark)
	var fade := 1.0 - maxf(0.0, t - 0.7) / 0.3
	var at: Vector2 = mark["at"]
	var grow := ease(clampf(t / 0.35, 0.0, 1.0), 0.4)
	var rx := 34.0 * grow * maxf(1.0, pixel_scale * 0.5)
	if mark.has("from"):
		# Bogen vom Helfer zum Verbuendeten.
		var a: Vector2 = mark["from"] + _lift(CHEST + 10.0)
		var b: Vector2 = at + _lift(CHEST + 10.0)
		var mid := (a + b) * 0.5 + _lift(40.0)
		var arc := PackedVector2Array()
		for i in 13:
			var u := float(i) / 12.0
			arc.append(a.lerp(mid, u).lerp(mid.lerp(b, u), u))
		_air_line(arc, Color(SHIELD_COLOR, fade), 3.0)
	if rx < 2.0:
		return
	# Wabenkuppel ueber dem DROME.
	var dome := PackedVector2Array()
	for i in 17:
		var ang := PI + PI * float(i) / 16.0
		dome.append(at + Vector2(cos(ang) * rx, sin(ang) * rx * 1.8 + rx * 0.2))
	_air.draw_colored_polygon(dome, Color(SHIELD_COLOR, 0.14 * fade))
	_air_line(dome, Color(SHIELD_COLOR, 0.9 * fade), 2.4)
	for p in [Vector2(-0.45, -0.7), Vector2(0, -1.2), Vector2(0.45, -0.7), Vector2(-0.22, -1.45), Vector2(0.22, -1.45)]:
		_air_hex(at + p * rx, rx * 0.2, Color(SHIELD_COLOR, 0.75 * fade), 1.6)
	if t < 0.9:
		_air_text(at + _lift(HEAD_HEIGHT + 22.0) , "+", Color(SHIELD_COLOR, fade), 18)


func _air_line(points: PackedVector2Array, color: Color, width: float) -> void:
	_air.draw_polyline(points, Color(SHADE, color.a * 0.7), _width(width * 2.0), true)
	_air.draw_polyline(points, color, _width(width), true)


func _air_hex(at: Vector2, r: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in 7:
		var ang := deg_to_rad(60.0 * i + 30.0)
		points.append(at + Vector2(cos(ang), sin(ang)) * r)
	_air_line(points, color, width)


func _air_star(at: Vector2, r: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var ang := deg_to_rad(-90.0 + 36.0 * i)
		var rr := r if i % 2 == 0 else r * 0.45
		points.append(at + Vector2(cos(ang), sin(ang)) * rr)
	_air.draw_colored_polygon(points, color)
	points.append(points[0])
	_air.draw_polyline(points, Color(SHADE, color.a), _width(1.4), true)


func _air_text(at: Vector2, text: String, color: Color, size_base: int) -> void:
	var font := Arcade.font("display")
	var size := maxi(1, int(round(size_base * maxf(1.0, pixel_scale * 0.8))))
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var origin := at - Vector2(width * 0.5, 0)
	font.draw_string_outline(_air.get_canvas_item(), origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		size, maxi(2, int(round(4.0 * pixel_scale))), Color(SHADE, color.a))
	font.draw_string(_air.get_canvas_item(), origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Fadenkreuz am Boden (Iso-gestaucht).
func _crosshair(at: Vector2, scale: float, color: Color) -> void:
	var axes := foot_axes(0.55 * scale)
	_ellipse(at, axes, Color(SHADE, color.a * 0.6), _width(4.4))
	_ellipse(at, axes, color, _width(2.2))
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var a := at + Vector2(d.x * axes.x * 0.5, d.y * axes.y * 0.5)
		var b := at + Vector2(d.x * axes.x * 1.5, d.y * axes.y * 1.5)
		draw_line(a, b, Color(SHADE, color.a * 0.6), _width(4.4), true)
		draw_line(a, b, color, _width(2.2), true)


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
