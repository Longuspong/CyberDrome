class_name Grid
extends RefCounted

## Das Kampfgitter. Reine Logik -- keine Godot-Knoten, keine Bildschirm-
## koordinaten. Isometrisch ist ausschliesslich die DARSTELLUNG.
##
## Seit dem Umbau zum Autobattler (Nov. 2026) gibt es kein Gelaende mit
## Regeln mehr (keine Stufen, keine Sichtlinie). Seit 7. Nov. 2026 wieder:
## **Hindernisse**, die nur Laufwege sperren -- Schuesse gehen darueber
## (Entscheidung des Spielers). Das Gitter fuehrt, wer wo steht (zwei DROMEs
## teilen sich nie ein Feld) und welche Felder gesperrt sind.

## Hexfeld (seit 17. Nov. 2026, Entscheidung des Spielers): 9 Spalten x 17
## Reihen, hochkant. Ein Feld ist ``Vector2i(spalte, reihe)``; ungerade Reihen
## liegen ein halbes Feld weiter rechts ("odd-r"). Reihe 0 ist oben (Gegner),
## die letzte Reihe unten (Spieler). Abstand und Nachbarn rechnen ueber
## axiale Koordinaten -- jeder Schritt in eine der sechs Richtungen kostet 1.
const DEFAULT_WIDTH := 9
const DEFAULT_HEIGHT := 17
const DEFAULT_SIZE := DEFAULT_WIDTH     # alter Name, nur noch fuer die Breite

## Die sechs Richtungen, axial (dq, dr), im Bild gegen den Uhrzeigersinn ab
## rechts: O, NO, NW, W, SW, SO. Richtung i zeigt im Bild auf i * 60 Grad.
const AXIAL_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
## Hoehe einer Reihe in Feldbreiten (Mitte zu Mitte): sqrt(3) / 2.
const ROW_STEP := 0.8660254

var width: int = DEFAULT_WIDTH
var height: int = DEFAULT_HEIGHT

## Nur fuer die Optik (Bodenkachel, Kulisse).
var region: Terrain.Region = null

var _occupants: Dictionary = {}     ## Vector2i -> unit_id (Variant)

## Gesperrte Felder: Vector2i -> Art des Hindernisses (String, nur Optik).
## Wer hier steht, ist niemand; betreten kann es keiner.
var obstacles: Dictionary = {}


func _init(w: int = DEFAULT_WIDTH, h: int = DEFAULT_HEIGHT) -> void:
	width = w
	height = h


## Feld -> axial (q, r).
static func to_axial(tile: Vector2i) -> Vector2i:
	return Vector2i(tile.x - ((tile.y - (tile.y & 1)) >> 1), tile.y)


## Axial (q, r) -> Feld.
static func from_axial(a: Vector2i) -> Vector2i:
	return Vector2i(a.x + ((a.y - (a.y & 1)) >> 1), a.y)


## Die EINZIGE Distanzfunktion des Projekts (Hexschritte) -- Reichweite und
## Bewegung rechnen beide hiermit.
static func distance(a: Vector2i, b: Vector2i) -> int:
	var d := to_axial(b) - to_axial(a)
	return maxi(maxi(absi(d.x), absi(d.y)), absi(d.x + d.y))


## Das Nachbarfeld in Richtung ``dir`` (0..5, siehe AXIAL_DIRS).
static func neighbor(tile: Vector2i, dir: int) -> Vector2i:
	return from_axial(to_axial(tile) + AXIAL_DIRS[posmod(dir, 6)])


## Alle sechs Nachbarfelder (auch ausserhalb des Feldes), Reihenfolge wie
## AXIAL_DIRS.
static func neighbors(tile: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dir in 6:
		out.append(neighbor(tile, dir))
	return out


## Die Feldmitte in der Ebene, in Feldbreiten: x nach rechts, y nach UNTEN
## (wie die Reihen). Fuer Richtungen und Darstellung, nicht fuer Abstaende.
static func plane(tile: Vector2i) -> Vector2:
	return Vector2(float(tile.x) + 0.5 * float(tile.y & 1), float(tile.y) * ROW_STEP)


## Die Richtung (0..5), die am besten von ``from`` nach ``to`` zeigt;
## -1 bei gleichem Feld.
static func direction_toward(from: Vector2i, to: Vector2i) -> int:
	if from == to:
		return -1
	var d := plane(to) - plane(from)
	# Bild-y zeigt nach unten, die Richtungen zaehlen gegen den Uhrzeigersinn.
	var angle := atan2(-d.y, d.x)
	return posmod(int(round(angle / (PI / 3.0))), 6)


## Liegt ``to`` auf einer geraden Hexlinie von ``from``? Dann die Richtung
## (0..5), sonst -1.
static func line_direction(from: Vector2i, to: Vector2i) -> int:
	var d := to_axial(to) - to_axial(from)
	if d == Vector2i.ZERO:
		return -1
	var n := distance(from, to)
	for dir in 6:
		if AXIAL_DIRS[dir] * n == d:
			return dir
	return -1


## Blickwinkel im Bild (Grad, 0 = rechts, gegen den Uhrzeigersinn) einer
## Richtung -- fuer die Blickrichtung der DROMEs ("deg<winkel>").
static func direction_angle(dir: int) -> float:
	return float(posmod(dir, 6)) * 60.0


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


## Darf ``unit_id`` hier stehen? Im Feld, kein Hindernis und nicht von
## jemand anderem belegt.
func can_stand_on(tile: Vector2i, unit_id = null) -> bool:
	return in_bounds(tile) and not obstacles.has(tile) and not is_occupied(tile, unit_id)


func is_blocked(tile: Vector2i) -> bool:
	return obstacles.has(tile)


func duplicate_grid() -> Grid:
	var copy := Grid.new(width, height)
	copy._occupants = _occupants.duplicate()
	copy.obstacles = obstacles.duplicate()
	copy.region = region
	return copy
