class_name Grid
extends RefCounted

## Das Kampfgitter. Reine Logik -- keine Godot-Knoten, keine Bildschirm-
## koordinaten. Isometrisch ist ausschliesslich die DARSTELLUNG.
##
## Seit dem Umbau zum Autobattler (Nov. 2026) ist das Feld frei: kein
## Gelaende, keine Sichtlinie. Das Gitter fuehrt nur noch, wer wo steht --
## zwei DROMEs teilen sich nie ein Feld.

const DEFAULT_SIZE := 20

## Die vier Schrittrichtungen (im Bild die vier Diagonalen).
const DIRS_4: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]

var width: int = DEFAULT_SIZE
var height: int = DEFAULT_SIZE

## Nur fuer die Optik (Bodenkachel, Kulisse).
var region: Terrain.Region = null

var _occupants: Dictionary = {}     ## Vector2i -> unit_id (Variant)


func _init(w: int = DEFAULT_SIZE, h: int = DEFAULT_SIZE) -> void:
	width = w
	height = h


static func directions() -> Array[Vector2i]:
	return DIRS_4


## Die EINZIGE Distanzfunktion des Projekts (Manhattan) -- Reichweite und
## Bewegung rechnen beide hiermit.
static func distance(a: Vector2i, b: Vector2i) -> int:
	var d := (b - a).abs()
	return d.x + d.y


func in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < width and tile.y < height


func all_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y in height:
		for x in width:
			tiles.append(Vector2i(x, y))
	return tiles


# ---------------------------------------------------------------------------
# Belegung
# ---------------------------------------------------------------------------

func set_occupant(tile: Vector2i, unit_id) -> void:
	if unit_id == null:
		_occupants.erase(tile)
	else:
		_occupants[tile] = unit_id


func clear_occupant(tile: Vector2i) -> void:
	_occupants.erase(tile)


func occupant(tile: Vector2i):
	return _occupants.get(tile)


func is_occupied(tile: Vector2i, exclude_id = null) -> bool:
	var who = _occupants.get(tile)
	return who != null and who != exclude_id


func tile_of(unit_id) -> Vector2i:
	for tile in _occupants:
		if _occupants[tile] == unit_id:
			return tile
	return Vector2i(-1, -1)


## Darf ``unit_id`` hier stehen? Im Feld und nicht von jemand anderem belegt.
func can_stand_on(tile: Vector2i, unit_id = null) -> bool:
	return in_bounds(tile) and not is_occupied(tile, unit_id)


func duplicate_grid() -> Grid:
	var copy := Grid.new(width, height)
	copy._occupants = _occupants.duplicate()
	copy.region = region
	return copy
