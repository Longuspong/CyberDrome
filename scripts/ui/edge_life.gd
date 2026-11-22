class_name EdgeLife
extends Node2D

## Lebendige Raender (21. Nov. 2026, Kampfbild mehr 3D D12, Paket 2).
##
## Je Region etwas Bewegung am Rand, nie auf dem Spielfeld und nie heller als
## ein Treffer:
##   Neon City   feiner Regen ueber dem Bild (motion.rain), kleine Spritzer
##   Parkanlage  Grasbueschel am Rand, die sich im Wind wiegen
##   Factory 5   Dampfstoesse aus den Rosten (ParticleFx.steam)
## Das Flackern der Laternen steckt in ArenaPainter.Lights.
##
## Gezeichnet wird nur ein paar Mal pro Sekunde (Gras) bzw. jedes Bild (Regen,
## ein paar Dutzend Striche). Mit "Bewegung reduzieren" steht alles still bzw.
## faellt weg.

const GRASS_FRAME := 0.08
const RAIN_SPEED := Vector2(-60.0, 520.0)
const RAIN_LENGTH := 0.035
const STEAM_EVERY := Vector2(1.6, 3.4)

var grid: Grid
var region_id := "city"
var particles: ParticleFx
## Grasbueschel: [Bodenpunkt, Hoehe, Phase]
var _tufts: Array = []
## Dampfquellen: [Bodenpunkt, Sekunden bis zum naechsten Stoss]
var _vents: Array = []
var _rain: Rain
var _time := 0.0
var _since_draw := 0.0
var _rng := RandomNumberGenerator.new()


static func create(battle_grid: Grid, parts: ParticleFx) -> EdgeLife:
	var life := EdgeLife.new()
	life.name = "Rand"
	life.grid = battle_grid
	life.region_id = str(battle_grid.region.id) if battle_grid.region != null else "city"
	life.particles = parts
	return life


func _ready() -> void:
	z_index = -45
	_rng.seed = hash([grid.width, grid.height, region_id])
	match region_id:
		"green":
			_place_tufts()
		"plant7":
			_place_vents()
		_:
			if bool(Config.section("motion").get("rain", true)):
				_rain = Rain.new()
				_rain.name = "Regen"
				add_child(_rain)


## Gras auf den Randfeldern (ausserhalb des Spielfelds), fester Zufall.
func _place_tufts() -> void:
	var spots: Array = []
	for y in range(-1, grid.height + 1):
		spots.append(Vector2i(-1, y))
		spots.append(Vector2i(grid.width, y))
	for x in range(0, grid.width):
		spots.append(Vector2i(x, -1))
	for tile in spots:
		for i in 2:
			var jitter := Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-6.0, 6.0))
			_tufts.append([IsoView.map_to_local(tile) + jitter, _rng.randf_range(7.0, 12.0),
				_rng.randf() * TAU])


## Dampf an einigen Deko-Plaetzen am Rand.
func _place_vents() -> void:
	var spots := ArenaPainter.prop_spots(grid)
	for index in spots.size():
		if spots[index][1] == "deco" and index % 2 == 0:
			_vents.append([IsoView.map_to_local(spots[index][0]) + Vector2(0, 6),
				_rng.randf_range(0.3, STEAM_EVERY.y)])


func _process(delta: float) -> void:
	if Accessibility.reduce_motion:
		if _rain != null:
			_rain.visible = false
		return
	_time += delta
	for vent in _vents:
		vent[1] = float(vent[1]) - delta
		if float(vent[1]) <= 0.0:
			vent[1] = _rng.randf_range(STEAM_EVERY.x, STEAM_EVERY.y)
			if particles != null and is_instance_valid(particles):
				particles.steam(vent[0])
	if _tufts.is_empty():
		return
	_since_draw += delta
	if _since_draw >= GRASS_FRAME:
		_since_draw = 0.0
		queue_redraw()


func _draw() -> void:
	if _tufts.is_empty():
		return
	var dark := Color(0.16, 0.34, 0.18)
	var light := Color(0.36, 0.62, 0.3)
	for tuft in _tufts:
		var at: Vector2 = tuft[0]
		var height: float = tuft[1]
		var phase: float = tuft[2]
		var wind := 0.0 if Accessibility.reduce_motion else \
			sin(_time * 1.8 + phase + at.x * 0.01) * 0.6 + sin(_time * 3.3 + phase) * 0.25
		for blade in 4:
			var spread := (float(blade) - 1.5) * 3.0
			var top := at + Vector2(spread + wind * height * 0.45, -height * (0.8 + 0.1 * blade))
			var mid := at.lerp(top, 0.55) + Vector2(wind * 1.5, 0)
			var color := dark if blade % 2 == 0 else light
			draw_polyline(PackedVector2Array([at + Vector2(spread * 0.4, 0), mid, top]), color, 1.6, true)


## Regen ueber dem sichtbaren Ausschnitt: schraege Striche, die nach unten
## fallen und am Boden kurz aufspritzen. Ueber den DROMEs, unter den Zahlen.
class Rain extends Node2D:
	var _drops: Array = []
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		z_index = 4010
		z_as_relative = false
		_rng.seed = 911

	func _view_rect() -> Rect2:
		var cam := get_viewport().get_camera_2d()
		var size := get_viewport().get_visible_rect().size
		if cam == null:
			return Rect2(Vector2.ZERO, size)
		var zoom := cam.zoom.x
		var center := to_local(cam.get_screen_center_position())
		var half := size * 0.5 / zoom
		return Rect2(center - half, half * 2.0)

	func _process(delta: float) -> void:
		if not is_inside_tree():
			return
		var rect := _view_rect()
		var want := int(Config.section("motion").get("rain_drops", 70))
		while _drops.size() < want:
			_drops.append(_new_drop(rect, true))
		for i in _drops.size():
			var drop: Dictionary = _drops[i]
			drop["at"] = (drop["at"] as Vector2) + EdgeLife.RAIN_SPEED * delta
			if float(drop.get("splash", -1.0)) >= 0.0:
				drop["splash"] = float(drop["splash"]) + delta
				if float(drop["splash"]) > 0.25:
					_drops[i] = _new_drop(rect, false)
			elif (drop["at"] as Vector2).y >= float(drop["floor"]):
				drop["splash"] = 0.0
				drop["at"] = Vector2((drop["at"] as Vector2).x, float(drop["floor"]))
			elif not rect.grow(80.0).has_point(drop["at"]):
				_drops[i] = _new_drop(rect, false)
		queue_redraw()

	func _new_drop(rect: Rect2, anywhere: bool) -> Dictionary:
		var x := _rng.randf_range(rect.position.x, rect.end.x + 40.0)
		var y := _rng.randf_range(rect.position.y, rect.end.y) if anywhere \
			else rect.position.y - _rng.randf_range(0.0, 60.0)
		return {"at": Vector2(x, y), "floor": y + _rng.randf_range(120.0, 420.0),
			"alpha": _rng.randf_range(0.18, 0.38)}

	func _draw() -> void:
		var streak := EdgeLife.RAIN_SPEED * EdgeLife.RAIN_LENGTH
		for drop in _drops:
			var at: Vector2 = drop["at"]
			var alpha := float(drop["alpha"])
			if float(drop.get("splash", -1.0)) >= 0.0:
				var k := float(drop["splash"]) / 0.25
				var r := 2.0 + 5.0 * k
				draw_arc(at, r, PI, TAU, 8, Color(0.6, 0.9, 1.0, alpha * (1.0 - k)), 1.0, true)
			else:
				draw_line(at - streak, at, Color(0.62, 0.88, 1.0, alpha), 1.0, true)
