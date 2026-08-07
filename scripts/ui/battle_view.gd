class_name BattleView
extends Node2D

## Zeichnet Gitter, Einheiten und Markierungen.
##
## Kennt die Regeln nicht -- es fragt den BattleManager und stellt dar, was er
## sagt. Umgekehrt kennt der Manager diese Klasse nicht.
##
## ### Warum kein TileMapLayer
##
## Der Entwurf nennt TileMapLayer im Modus Isometric. Zwei Gruende sprechen im
## Bestand dagegen:
##
## 1. Das Kachelverhaeltnis ist sqrt(2):1 und faellt aus der 45-Grad-Kamera des
##    Bauteil-Renderers. Es laesst sich nicht unabhaengig waehlen.
## 2. STEP und BLOCK sind hoch. Sie muessen sich mit den DROMEs sortieren --
##    ein Betonpfeiler verdeckt den Bot davor, aber nicht den dahinter. Eine
##    TileMap sortiert gegen Node2D-Einheiten nur ueber getrennte Ebenen je
##    Hoehe; Sprites in einer gemeinsamen Tiefenordnung tun es ohne Sonderfall.
##
## Die Umrechnung bleibt trotzdem an genau einer Stelle: IsoView.

## Abstand zwischen zwei Tiefenstufen. Gross genug, dass die Bauteile einer
## Einheit dazwischen passen, ohne in die naechste Reihe zu rutschen.
const DEPTH_STRIDE := 16
const UNIT_DEPTH_OFFSET := 8

const OVERLAY_TILE := "res://assets/terrain/overlay_tile.svg"
const OVERLAY_OUTLINE := "res://assets/terrain/overlay_outline.svg"
const OVERLAY_ARROW := "res://assets/terrain/overlay_drift_arrow.svg"

## Farben der Feldmarkierungen. Dieselbe Raute, vier Bedeutungen.
const COLOR_REACHABLE := Color(0.25, 0.55, 1.0, 0.38)
const COLOR_TARGET := Color(1.0, 0.25, 0.25, 0.42)
const COLOR_BLOCKED := Color(0.55, 0.55, 0.58, 0.38)
const COLOR_ACTIVE := Color(1.0, 0.85, 0.25, 0.85)
const COLOR_HAZE := Color(0.75, 0.82, 0.95, 0.30)

## Der gelaufene Teil des Weges und der gerutschte -- bewusst verschiedene
## Farben. Der Spieler muss VOR dem Klick sehen, dass er wegrutschen wird.
const COLOR_PATH := Color(0.45, 0.75, 1.0, 0.95)
const COLOR_SLIDE := Color(1.0, 0.65, 0.15, 0.95)

var grid: Grid

var _world: Node2D
var _overlays: Node2D
var _paths: Node2D
var _tile_sprites: Dictionary = {}
var _overlay_pool: Array[Sprite2D] = []

var _hover_tile: Vector2i = Vector2i(-1, -1)
var _preview_path: Array = []
var _preview_slide: Array = []


func _ready() -> void:
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)

	_overlays = Node2D.new()
	_overlays.name = "Overlays"
	add_child(_overlays)

	_paths = PathPainter.new()
	_paths.name = "Paths"
	add_child(_paths)


# ---------------------------------------------------------------------------
# Terrain
# ---------------------------------------------------------------------------

func build_terrain(battle_grid: Grid) -> void:
	grid = battle_grid
	for sprite in _tile_sprites.values():
		sprite.queue_free()
	_tile_sprites.clear()

	for tile in grid.all_tiles():
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.position = IsoView.sprite_position(tile)
		sprite.z_index = IsoView.depth(tile) * DEPTH_STRIDE

		var type := grid.terrain_type(tile)
		var path: String = type.texture_path if type != null else ""
		if path != "" and ResourceLoader.exists(path):
			sprite.texture = load(path)
		else:
			# Fehlendes Tile wird als Fehlmarkierung sichtbar, nicht ersetzt.
			sprite.texture = load(OVERLAY_TILE)
			sprite.modulate = Color.MAGENTA
		_world.add_child(sprite)
		_tile_sprites[tile] = sprite

		if grid.terrain_class(tile) == Terrain.TClass.DRIFT:
			_add_drift_marker(tile)
		elif grid.terrain_class(tile) == Terrain.TClass.HAZE:
			_add_haze_veil(tile)


## Gerichtete Drift bekommt einen Pfeil, ungerichtete traegt ihre Schliere
## schon im Tile. Unsichtbares Rutschen ist die schnellste Art, ein
## Taktikspiel unfair wirken zu lassen.
func _add_drift_marker(tile: Vector2i) -> void:
	var flow := grid.flow_direction(tile)
	if flow == Vector2i.ZERO:
		return
	var arrow := Sprite2D.new()
	arrow.texture = load(OVERLAY_ARROW)
	arrow.centered = false
	arrow.position = IsoView.sprite_position(tile)
	arrow.z_index = IsoView.depth(tile) * DEPTH_STRIDE + 1
	arrow.modulate = Color(0.6, 0.95, 1.0, 0.9)
	# Der Pfeil zeigt in Gitterrichtung +x. Die anderen drei ergeben sich
	# durch Drehung um Vielfache von 90 Grad um die Feldmitte.
	var turns := {Vector2i(1, 0): 0.0, Vector2i(0, 1): 90.0,
		Vector2i(-1, 0): 180.0, Vector2i(0, -1): 270.0}
	arrow.rotation_degrees = turns.get(flow, 0.0)
	arrow.offset = -IsoView.SPRITE_ORIGIN
	arrow.position += IsoView.SPRITE_ORIGIN
	_world.add_child(arrow)


## Haze-Felder werden halbtransparent ueberlagert. Kein Fog of War -- die
## Position bleibt sichtbar; lesbar sein muss nur "von hier aus nicht
## beschiessbar".
func _add_haze_veil(tile: Vector2i) -> void:
	var veil := Sprite2D.new()
	veil.texture = load(OVERLAY_TILE)
	veil.centered = false
	veil.position = IsoView.sprite_position(tile)
	veil.z_index = IsoView.depth(tile) * DEPTH_STRIDE + 12
	veil.modulate = COLOR_HAZE
	_world.add_child(veil)


# ---------------------------------------------------------------------------
# Einheiten
# ---------------------------------------------------------------------------

func attach_unit(unit: Unit) -> void:
	_world.add_child(unit)
	refresh_unit_depth(unit)
	unit.set_in_haze(grid.terrain_class(unit.tile) == Terrain.TClass.HAZE)


func refresh_unit_depth(unit: Unit) -> void:
	unit.z_index = IsoView.depth(unit.tile) * DEPTH_STRIDE + UNIT_DEPTH_OFFSET


func refresh_all_depths(units: Array) -> void:
	for unit in units:
		if unit.is_alive():
			refresh_unit_depth(unit)
		else:
			unit.visible = false


# ---------------------------------------------------------------------------
# Markierungen
# ---------------------------------------------------------------------------

func clear_overlays() -> void:
	for sprite in _overlay_pool:
		sprite.visible = false


func _overlay(index: int) -> Sprite2D:
	while _overlay_pool.size() <= index:
		var sprite := Sprite2D.new()
		sprite.texture = load(OVERLAY_TILE)
		sprite.centered = false
		sprite.visible = false
		_overlays.add_child(sprite)
		_overlay_pool.append(sprite)
	return _overlay_pool[index]


## Faerbt Felder ein. ``sets`` ist eine Liste aus { tiles, color }.
func paint(sets: Array) -> void:
	clear_overlays()
	var index := 0
	for entry in sets:
		for tile in entry["tiles"]:
			var sprite := _overlay(index)
			sprite.position = IsoView.sprite_position(tile)
			# Markierungen liegen ueber ihrem Feld, aber unter allem, was
			# davor steht -- sonst leuchtet die Raute durch den Betonpfeiler.
			sprite.z_index = IsoView.depth(tile) * DEPTH_STRIDE + 2
			sprite.modulate = entry["color"]
			sprite.texture = load(entry.get("texture", OVERLAY_TILE))
			sprite.visible = true
			index += 1


func set_path_preview(walked: Array, slide: Array) -> void:
	_preview_path = walked
	_preview_slide = slide
	_paths.walked = walked
	_paths.slide = slide
	_paths.queue_redraw()


func clear_path_preview() -> void:
	set_path_preview([], [])


func tile_at_screen(world_position: Vector2) -> Vector2i:
	return IsoView.local_to_map(world_position)


## Zeichnet die Pfadvorschau. Eigene Klasse, weil _draw() an einen Knoten
## gebunden ist und die Linien ueber allen Feldern liegen muessen.
class PathPainter extends Node2D:
	var walked: Array = []
	var slide: Array = []

	func _ready() -> void:
		z_index = 4000

	func _draw() -> void:
		if walked.size() >= 2:
			var points := PackedVector2Array()
			for tile in walked:
				points.append(IsoView.map_to_local(tile))
			draw_polyline(points, BattleView.COLOR_PATH, 3.0, true)

		if slide.is_empty():
			return
		# Der gerutschte Teil gestrichelt und in anderer Farbe.
		var from: Vector2i = walked[-1] if not walked.is_empty() else slide[0]
		var chain: Array = [from] + slide
		for i in range(chain.size() - 1):
			_dashed(IsoView.map_to_local(chain[i]),
				IsoView.map_to_local(chain[i + 1]))
		var last := IsoView.map_to_local(chain[-1])
		draw_circle(last, 7.0, BattleView.COLOR_SLIDE)

	func _dashed(a: Vector2, b: Vector2) -> void:
		var total := a.distance_to(b)
		var dir := (b - a).normalized()
		var travelled := 0.0
		while travelled < total:
			var seg := minf(6.0, total - travelled)
			draw_line(a + dir * travelled, a + dir * (travelled + seg),
				BattleView.COLOR_SLIDE, 3.0, true)
			travelled += 12.0
