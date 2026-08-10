class_name Grid
extends RefCounted

## Das Kampfgitter. Reine Logik -- keine Godot-Knoten, keine Bildschirm-
## koordinaten, keine UI. Muss ohne laufende Szene testbar sein.
##
## Logisch ist das Gitter ein Quadrat. Isometrisch ist ausschliesslich die
## DARSTELLUNG; die Spiellogik rechnet nie in Bildschirmkoordinaten.

const DEFAULT_SIZE := 20

## Bewegung in vier Richtungen (N/O/S/W im Gitterraum = die vier Diagonalen
## auf dem Bildschirm). Ein Umschalten auf acht Richtungen ist eine Zeile --
## und zieht die Distanzmetrik automatisch mit.
const ALLOW_DIAGONALS := false

const DIRS_4: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]
const DIRS_8: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]

## Endlosschleifen-Bremse, keine Spielregel: gerichtete Drift-Felder, die im
## Kreis zeigen, waeren sonst eine Haengegarantie.
const DRIFT_MAX_STEPS := 8

## Kosten in Bewegungspunkten
const COST_NORMAL := 1
const COST_STEP := 2
const COST_STEP_REDUCED := 1

var width: int = DEFAULT_SIZE
var height: int = DEFAULT_SIZE

var region: Terrain.Region = null

var _classes: PackedInt32Array = PackedInt32Array()
var _flow: Dictionary = {}          ## Vector2i -> Vector2i, nur belegte Felder
var _occupants: Dictionary = {}     ## Vector2i -> unit_id (Variant)


func _init(w: int = DEFAULT_SIZE, h: int = DEFAULT_SIZE) -> void:
	resize(w, h)


func resize(w: int, h: int) -> void:
	width = w
	height = h
	_classes.resize(w * h)
	_classes.fill(Terrain.TClass.NORMAL)
	_flow.clear()
	_occupants.clear()


static func directions() -> Array[Vector2i]:
	return DIRS_8 if ALLOW_DIAGONALS else DIRS_4


## Die EINZIGE Distanzfunktion des Projekts. Manhattan bei vier Richtungen,
## Chebyshev bei acht -- nirgendwo sonst darf Distanz berechnet werden, sonst
## stimmen Reichweite und Bewegung irgendwann nicht mehr ueberein.
static func distance(a: Vector2i, b: Vector2i) -> int:
	var d := (b - a).abs()
	if ALLOW_DIAGONALS:
		return maxi(d.x, d.y)
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
# Terrain
# ---------------------------------------------------------------------------

func terrain_class(tile: Vector2i) -> Terrain.TClass:
	if not in_bounds(tile):
		return Terrain.TClass.BLOCK
	return _classes[tile.y * width + tile.x] as Terrain.TClass


func set_terrain_class(tile: Vector2i, terrain_class: Terrain.TClass) -> void:
	if not in_bounds(tile):
		return
	_classes[tile.y * width + tile.x] = terrain_class
	if terrain_class != Terrain.TClass.DRIFT:
		_flow.erase(tile)


func fill(terrain_class: Terrain.TClass) -> void:
	_classes.fill(terrain_class)
	_flow.clear()


## Nur DRIFT. ZERO bedeutet ungerichtet.
func flow_direction(tile: Vector2i) -> Vector2i:
	return _flow.get(tile, Vector2i.ZERO)


func set_flow_direction(tile: Vector2i, dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		_flow.erase(tile)
	else:
		_flow[tile] = dir


## Der konkrete Terraintyp dieses Feldes -- nur fuer Anzeige und Tooltip.
func terrain_type(tile: Vector2i) -> Terrain.TerrainType:
	if region == null:
		return null
	return region.type_for(terrain_class(tile))


func terrain_name(tile: Vector2i) -> String:
	var type := terrain_type(tile)
	if type != null:
		return type.display_name
	return Terrain.class_label(terrain_class(tile))


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


# ---------------------------------------------------------------------------
# Traversierung
# ---------------------------------------------------------------------------
# Grundregel: ein DROME kann weder durch andere DROMEs noch durch Terrain
# hindurch. Alles andere wird ueber die Flags des Antriebs freigeschaltet.
#
# can_traverse und can_stand_on sind ZWEI VERSCHIEDENE PRUEFUNGEN -- ersteres
# fuer den Schritt, letzteres fuer das Zielfeld. Genau diese Trennung ist die
# Stelle, an der solche Systeme ueblicherweise brechen: Traversierung erlaubt
# das Durchziehen, nicht das Landen.

## Darf die Einheit dieses Feld BETRETEN (durchqueren)?
func can_traverse(tile: Vector2i, profile: MoveProfile) -> bool:
	if not in_bounds(tile):
		return false
	match terrain_class(tile):
		Terrain.TClass.BLOCK:
			if not profile.can_pass_blocks:
				return false
		Terrain.TClass.STEP:
			if not profile.can_enter_steps:
				return false
	if is_occupied(tile, profile.unit_id) and not profile.can_pass_units:
		return false
	return true


## Darf die Einheit auf diesem Feld STEHEN BLEIBEN?
##
## Ein Zug darf niemals auf einem besetzten Feld oder auf BLOCK enden --
## unabhaengig von allen Flags. can_pass_units hilft hier ausdruecklich nicht.
func can_stand_on(tile: Vector2i, profile: MoveProfile) -> bool:
	if not in_bounds(tile):
		return false
	match terrain_class(tile):
		Terrain.TClass.BLOCK:
			return false
		Terrain.TClass.STEP:
			if not profile.can_enter_steps:
				return false
	return not is_occupied(tile, profile.unit_id)


## Bewegungskosten des Feldes. Traversierung veraendert sie nicht -- ein
## durchquertes Feld kostet genau einen Punkt wie jedes andere.
func terrain_cost(tile: Vector2i, profile: MoveProfile) -> int:
	if terrain_class(tile) == Terrain.TClass.STEP:
		return COST_STEP_REDUCED if profile.step_cost_reduced else COST_STEP
	return COST_NORMAL


# ---------------------------------------------------------------------------
# Sichtlinie
# ---------------------------------------------------------------------------

## Bresenham von Feldmitte zu Feldmitte. BLOCK und HAZE unterbrechen.
## DROMEs, Stufen und Drift-Zonen unterbrechen die Sichtlinie NIE.
##
## Ohne diese Regel waere das gesamte Terrainsystem fuer den Kampf reine
## Dekoration -- dann schoesse man quer durch Betonpfeiler.
func has_line_of_sight(from: Vector2i, to: Vector2i, ignore_haze: bool = false) -> bool:
	# Benachbarte Felder haben IMMER Sicht. Ohne diese Ausnahme koennten sich
	# zwei DROMEs im selben Nebelfeld Auge in Auge nicht angreifen -- was
	# niemand erwarten wuerde.
	if distance(from, to) <= 1:
		return true

	for tile in line(from, to):
		var terrain_class := terrain_class(tile)
		if terrain_class == Terrain.TClass.HAZE and not ignore_haze:
			# Gilt auch fuer das Feld des Schuetzen oder des Ziels selbst:
			# Haze versteckt dich, aber es blendet dich genauso.
			return false
		if terrain_class == Terrain.TClass.BLOCK and tile != from and tile != to:
			return false
	return true


## Warum ist die Sicht blockiert? Fuer den Tooltip an ungueltigen Zielen.
## Leerer String = freie Sicht.
func sight_blocker(from: Vector2i, to: Vector2i, ignore_haze: bool = false) -> String:
	if distance(from, to) <= 1:
		return ""
	for tile in line(from, to):
		var terrain_class := terrain_class(tile)
		if terrain_class == Terrain.TClass.HAZE and not ignore_haze:
			return terrain_name(tile)
		if terrain_class == Terrain.TClass.BLOCK and tile != from and tile != to:
			return terrain_name(tile)
	return ""


## Bresenham, beide Endpunkte eingeschlossen -- und RICHTUNGSUNABHAENGIG.
##
## Der nackte Bresenham ist es nicht: bei halben Schritten entscheidet das
## Vorzeichen der Fehlervariablen, welches der beiden gleich weit entfernten
## Felder genommen wird, und das Vorzeichen haengt daran, an welchem Ende man
## anfaengt. Bei 56 von 220 Richtungen im Umkreis von sieben Feldern laufen
## Hin- und Rueckweg deshalb ueber verschiedene Felder. Liegt auf genau einem
## davon ein Pfeiler oder eine Schwade, kann A auf B schiessen und B nicht auf
## A -- in einem Spiel, das jede Aktion vorher durchrechnen laesst, ist das
## nicht als Regel lesbar, sondern nur als Willkuer.
##
## Der Fix sitzt hier und nicht in den beiden Sicht-Funktionen, aus demselben
## Grund wie ueberall sonst im Projekt: es gibt genau eine Rasterung, und wer
## sie kuenftig aufruft, erbt die Symmetrie, ohne davon wissen zu muessen.
##
## Gerastert wird immer vom kanonisch kleineren Endpunkt aus; ist ``from``
## nicht dieser, wird die fertige Linie umgedreht. Die Reihenfolge bleibt
## dadurch die vom Schuetzen aus gesehene -- ``sight_blocker()`` nennt weiterhin
## das Hindernis, das dem Schuetzen am naechsten liegt.
func line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if to.x < from.x or (to.x == from.x and to.y < from.y):
		var flipped := line(to, from)
		flipped.reverse()
		return flipped

	var tiles: Array[Vector2i] = []
	var x0 := from.x
	var y0 := from.y
	var dx := absi(to.x - x0)
	var dy := -absi(to.y - y0)
	var sx := 1 if x0 < to.x else -1
	var sy := 1 if y0 < to.y else -1
	var err := dx + dy
	while true:
		tiles.append(Vector2i(x0, y0))
		if x0 == to.x and y0 == to.y:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return tiles


# ---------------------------------------------------------------------------
# DRIFT -- Gleitzonen
# ---------------------------------------------------------------------------

## Die EINE Implementierung des Gleitens. Rein: veraendert nichts am
## Spielzustand, gibt nur Zielfeld und Gleitpfad zurueck.
##
## Vorschau UND Ausfuehrung rufen exakt diese Funktion auf. Es darf keine
## zweite Implementierung geben, nicht mal eine "vereinfachte fuer die
## Vorschau" -- genau dort entsteht sonst der Bug, bei dem der DROME woanders
## landet, als die blaue Markierung versprochen hat. Dieser Bug zerstoert das
## Vertrauen in ein Taktikspiel schneller als jeder Absturz.
##
## Rueckgabe: { tile: Vector2i, path: Array[Vector2i] }
## ``path`` enthaelt die gerutschten Felder ohne das Einstiegsfeld.
func drift_result(entry_tile: Vector2i, entry_dir: Vector2i,
		profile: MoveProfile) -> Dictionary:
	var path: Array[Vector2i] = []
	if profile.ignores_drift:
		return {"tile": entry_tile, "path": path}

	var cur := entry_tile
	var dir := entry_dir
	var steps := 0
	var left_the_zone := false

	while terrain_class(cur) == Terrain.TClass.DRIFT and steps < DRIFT_MAX_STEPS:
		var flow := flow_direction(cur)
		if flow != Vector2i.ZERO:
			dir = flow
		if dir == Vector2i.ZERO:
			break                       # ungerichtet und ohne Laufrichtung
		var nxt := cur + dir
		# Gegen eine Wand oder eine Einheit gerutscht: man prallt ab und
		# bleibt liegen. can_pass_units hilft beim Gleiten ausdruecklich
		# nicht -- man rutscht nicht durch einen anderen DROME hindurch.
		if not can_stand_on(nxt, profile):
			return {"tile": cur, "path": path}
		cur = nxt
		path.append(cur)
		steps += 1
		if terrain_class(cur) != Terrain.TClass.DRIFT:
			left_the_zone = true
			break

	# drift_modifier greift nur, wenn die Zone regulaer verlassen wurde. Wer
	# gegen eine Wand rutscht, rutscht nicht noch weiter in sie hinein.
	if left_the_zone and profile.drift_modifier > 0:
		for _i in profile.drift_modifier:
			var nxt := cur + dir
			if not can_stand_on(nxt, profile):
				break
			cur = nxt
			path.append(cur)

	return {"tile": cur, "path": path}


## Bequemlichkeit: nur das Zielfeld.
func simulate_drift(entry_tile: Vector2i, entry_dir: Vector2i,
		profile: MoveProfile) -> Vector2i:
	return drift_result(entry_tile, entry_dir, profile)["tile"]


# ---------------------------------------------------------------------------
# Reichweite
# ---------------------------------------------------------------------------

## Alle Felder, auf denen die Einheit mit ``mp`` Bewegungspunkten zum Stehen
## kommen kann.
##
## Ohne Drift waere das ein simpler Flood-Fill ueber Feldkosten. Mit Drift ist
## das Gitter KEIN reines Kostengitter mehr: ein Drift-Feld wirkt wie ein
## Portal, das den DROME kostenlos an eine ganz andere Stelle versetzt. Ein
## normaler Flood-Fill produziert hier garantiert falsche Ergebnisse.
##
## Rueckgabe: landing_tile -> {
##     tile, mp_left, path, slide_from, slide_path
## }
## ``path``       die gelaufenen Felder bis einschliesslich Einstiegsfeld
## ``slide_from`` das betretene Feld, falls gerutscht wurde, sonst null
## ``slide_path`` die gerutschten Felder
func reachable_tiles(profile: MoveProfile, mp: int) -> Dictionary:
	var start := profile.tile
	var best := {}
	var start_entry := {
		"tile": start, "mp_left": mp, "path": [start] as Array[Vector2i],
		"slide_from": null, "slide_path": [] as Array[Vector2i],
	}
	best[start] = start_entry

	var queue: Array = [start_entry]
	while not queue.is_empty():
		var node: Dictionary = queue.pop_front()
		# Veraltete Warteschlangeneintraege ueberspringen: ein Feld kann
		# nachtraeglich auf einem besseren Weg erreicht worden sein.
		if best.has(node["tile"]) and best[node["tile"]]["mp_left"] > node["mp_left"]:
			continue

		for dir in directions():
			var step: Vector2i = node["tile"] + dir
			if not in_bounds(step):
				continue
			if not can_traverse(step, profile):
				continue
			var cost := terrain_cost(step, profile)
			if node["mp_left"] < cost:
				continue

			# Hier passiert es: das BETRETENE Feld ist nicht das ZIELFELD.
			var slide := drift_result(step, dir, profile)
			var landing: Vector2i = slide["tile"]
			if not can_stand_on(landing, profile):
				continue

			var mp_left: int = node["mp_left"] - cost
			# Schluessel ist das Landefeld, nie das betretene Feld: zwei
			# verschiedene Drift-Felder koennen auf demselben Feld enden.
			# Gewinnen soll der Weg mit den meisten Restpunkten.
			if best.has(landing) and best[landing]["mp_left"] >= mp_left:
				continue

			var walked: Array[Vector2i] = (node["path"] as Array[Vector2i]).duplicate()
			walked.append(step)
			var entry := {
				"tile": landing,
				"mp_left": mp_left,
				"path": walked,
				"slide_from": step if landing != step else null,
				"slide_path": slide["path"],
			}
			best[landing] = entry
			# Die Expansion geht vom LANDEFELD weiter, nicht vom betretenen.
			queue.push_back(entry)

	best.erase(start)
	return best


## Kuerzester Weg fuer die KI und fuer "lauf in Richtung X". Nutzt dieselbe
## Reichweitenberechnung, damit Vorschau und Ausfuehrung nicht auseinander-
## laufen koennen.
func path_towards(profile: MoveProfile, target: Vector2i, mp: int) -> Dictionary:
	var reachable := reachable_tiles(profile, mp)
	var best_tile := Vector2i(-1, -1)
	var best_distance := distance(profile.tile, target)
	var best_entry := {}
	for tile in reachable:
		var d := distance(tile, target)
		if d < best_distance or (d == best_distance and best_tile.x >= 0
				and reachable[tile]["mp_left"] > best_entry.get("mp_left", -1)):
			best_distance = d
			best_tile = tile
			best_entry = reachable[tile]
	return best_entry


# ---------------------------------------------------------------------------
# Erreichbarkeit fuer die Kartenvalidierung
# ---------------------------------------------------------------------------

## Existiert ein Weg von ``from`` nach ``to`` fuer eine Einheit OHNE jedes
## Traversierungsflag? Ohne diese Pruefung generiert der Kartengenerator
## frueher oder spaeter eine Karte, auf der ein Rad-Antrieb den Gegner nie
## erreicht.
##
## Bewusst ohne Bewegungspunkte und ohne Drift: gefragt ist, ob die Karte
## grundsaetzlich durchquerbar ist, nicht ob es in einem Zug geht.
func has_plain_path(from: Vector2i, to: Vector2i) -> bool:
	if not in_bounds(from) or not in_bounds(to):
		return false
	var plain := MoveProfile.plain()
	if not can_stand_on(from, plain) or not can_stand_on(to, plain):
		return false

	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == to:
			return true
		for dir in directions():
			var nxt: Vector2i = cur + dir
			if seen.has(nxt) or not in_bounds(nxt):
				continue
			if not can_stand_on(nxt, plain):
				continue
			seen[nxt] = true
			queue.append(nxt)
	return false


func count_class(terrain_class: Terrain.TClass) -> int:
	var total := 0
	for value in _classes:
		if value == terrain_class:
			total += 1
	return total


func duplicate_grid() -> Grid:
	var copy := Grid.new(width, height)
	copy._classes = _classes.duplicate()
	copy._flow = _flow.duplicate()
	copy._occupants = _occupants.duplicate()
	copy.region = region
	return copy
