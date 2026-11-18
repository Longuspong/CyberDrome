class_name MapGenerator
extends RefCounted

## Erzeugt das Kampffeld: ein Gitter mit dem Boden der Region und ein paar
## Hindernissen.
##
## Seit dem Umbau zum Autobattler (Nov. 2026) gibt es kein Gelaende mit
## Sonderregeln mehr -- keine Stufen, Oelspuren oder Nebel. Seit 7. Nov. 2026
## (Wunsch des Spielers) wieder Hindernisse: sie sperren nur Laufwege,
## Schuesse gehen darueber. Verteilt werden sie punktsymmetrisch zur
## Feldmitte, damit beide Seiten dieselben Bedingungen haben, und nie in oder
## direkt an den Aufstellungszonen. Alles am Seed des Kampfes.

## Die Formen eines Hindernisses: Ankerfeld plus Nachbarn in diesen
## Hexrichtungen (Grid.AXIAL_DIRS) -- einzeln, kurze Mauer quer, kurze Mauer
## schraeg, Dreieck.
const SHAPES := [
	[],
	[0],
	[5],
	[0, 5],
]


## Das Feld einer Karte (18. Nov. 2026, Wunsch des Spielers: die Karte
## stuetzt den Gedanken der Formation). ``map_id`` ist ein Schluessel aus
## ``data/config.json`` -> ``maps`` (leer oder unbekannt: ``maps.default``).
## Jede Karte hat Breite, Hoehe und eine Form; die Form ist fest und an der
## Mittelreihe gespiegelt -- beide Seiten haben dieselben Bedingungen.
static func generate(region: Terrain.Region, map_id: String = "") -> Grid:
	var spec := map_spec(map_id)
	var grid := Grid.new(int(spec.get("width", Grid.DEFAULT_WIDTH)),
		int(spec.get("height", Grid.DEFAULT_HEIGHT)))
	grid.region = region
	grid.map_id = str(spec.get("id", ""))
	apply_shape(grid, str(spec.get("shape", "rect")))
	return grid


## Die Angaben einer Karte samt ihrer Id. Unbekannt oder leer: die Standardkarte.
static func map_spec(map_id: String) -> Dictionary:
	var maps := Config.section("maps")
	var key := map_id
	if key == "" or not maps.get(key) is Dictionary:
		key = str(maps.get("default", ""))
	var spec = maps.get(key)
	if not spec is Dictionary:
		return {"id": "", "width": Grid.DEFAULT_WIDTH, "height": Grid.DEFAULT_HEIGHT, "shape": "rect"}
	var out: Dictionary = (spec as Dictionary).duplicate()
	out["id"] = key
	return out


## Die Form einer Karte: Loecher (Felder ausserhalb) und feste Bloecke
## (Hindernisse, ueber die geschossen wird). Die Aufstellungszonen bleiben
## immer frei. Formen:
##   rect    Rechteck
##   belly   Bauch: an den Zonen schmal, in der Mitte die volle Breite --
##           Platz fuer Flanken
##   waist   Engpass: in der Mitte nur 5 Felder breit
##   lanes   Zwei Gassen: ein Block in der Mitte teilt das Feld
static func apply_shape(grid: Grid, shape: String) -> void:
	grid.holes.clear()
	if shape == "rect" or shape == "":
		return
	var zones := {}
	for tile in deployment_zone(grid, true) + deployment_zone(grid, false):
		zones[tile] = true
	var kinds: Array = Config.section("obstacles").get("kinds", {}).get(
		str(grid.region.id) if grid.region != null else "", ["block"])
	if kinds.is_empty():
		kinds = ["block"]
	for y in grid.height:
		for x in grid.width:
			var tile := Vector2i(x, y)
			if zones.has(tile):
				continue
			match _shape_cell(shape, tile, grid.width, grid.height):
				"hole":
					grid.holes[tile] = true
				"block":
					# Feste Optik je Feld (kein Zufall des Kampfes), gespiegelt gleich.
					var top := Vector2i(x, mini(y, grid.height - 1 - y))
					grid.obstacles[tile] = str(kinds[absi(hash(top)) % kinds.size()])


## Was ein Feld in einer Form ist: "" (Spielfeld), "hole" oder "block".
## Gerechnet wird nur fuer die obere Haelfte, die untere ist ihr Spiegelbild
## (bei ungerader Reihenzahl haben Reihe y und h - 1 - y denselben Versatz).
static func _shape_cell(shape: String, tile: Vector2i, w: int, h: int) -> String:
	var y := mini(tile.y, h - 1 - tile.y)
	var cx := (float(w) - 1.0) * 0.5
	var mid := (float(h) - 1.0) * 0.5
	var dx := absf(float(tile.x) + (0.5 if y % 2 == 1 else 0.0) - cx - 0.25)
	var dy := mid - float(y)
	var t := dy / mid                # 0 Mitte .. 1 Rand
	match shape:
		"waist":
			if dx > lerpf(2.6, float(w) * 0.5, clampf((t - 0.15) / 0.45, 0.0, 1.0)):
				return "hole"
		"belly":
			# Ab der Zone (7 breit) je Reihe ein halbes Feld breiter -- gerade
			# Hexkanten statt Treppen, bis zur vollen Breite.
			var half := minf(3.5 + maxf(0.0, float(y) - 2.0) * 0.5, float(w) * 0.5)
			if dx > half - 0.25 + 0.001:
				return "hole"
		"lanes":
			if dx <= 1.1 and dy <= 3.0:
				return "block"
	return ""


## Setzt die Hindernisse. Eigener Zufall aus ``seed_value`` -- der Zufall
## des Kampfes (Region, Gegner) bleibt dadurch unberuehrt, und die Vorschau
## im Lauf zeigt weiter denselben Kampf.
##
## Einstellungen in data/config.json -> "obstacles": wie viele Gruppen
## (je Seite), Abstand zu den Zonen. Jede Gruppe wird an der Mittelreihe
## gespiegelt (x, y) -> (x, h - 1 - y), so wie die Gegnerzone die
## gespiegelte Spielerzone ist. Eine Gruppe, die das Feld zerteilen wuerde, faellt weg.
static func place_obstacles(grid: Grid, seed_value: int) -> void:
	# Die festen Bloecke der Kartenform (apply_shape) bleiben stehen.
	var settings := Config.section("obstacles")
	if not bool(settings.get("enabled", true)):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x0B57AC1E
	var groups := rng.randi_range(int(settings.get("groups_min", 3)),
		int(settings.get("groups_max", 5)))
	var margin := int(settings.get("zone_margin", 1))
	var kinds: Array = settings.get("kinds", {}).get(
		grid.region.id if grid.region != null else "", ["block"])
	if kinds.is_empty():
		kinds = ["block"]

	# Gesperrt fuer Hindernisse: beide Zonen samt Rand.
	var keep_free := {}
	var zones: Array[Vector2i] = deployment_zone(grid, true) + deployment_zone(grid, false)
	for tile in grid.all_tiles():
		for zone_tile in zones:
			if Grid.distance(tile, zone_tile) <= margin:
				keep_free[tile] = true
				break

	var placed := 0
	var attempts := 0
	while placed < groups and attempts < groups * 30:
		attempts += 1
		var shape: Array = SHAPES[rng.randi() % SHAPES.size()]
		var anchor := Vector2i(rng.randi_range(1, grid.width - 2),
			rng.randi_range(1, grid.height - 2))
		var kind: String = str(kinds[rng.randi() % kinds.size()])
		var tiles: Array[Vector2i] = []
		var ok := true
		var shape_tiles: Array[Vector2i] = [anchor]
		for dir in shape:
			shape_tiles.append(Grid.neighbor(anchor, dir))
		for own in shape_tiles:
			for tile in [own, mirror(grid, own)]:
				if not grid.in_bounds(tile) or keep_free.has(tile) \
						or grid.obstacles.has(tile) or _touches(grid, tile) \
						or tile in tiles:
					ok = false
				tiles.append(tile)
		if not ok:
			continue
		for tile in tiles:
			grid.obstacles[tile] = kind
		if not _connected(grid):
			for tile in tiles:
				grid.obstacles.erase(tile)
			continue
		placed += 1


## Das Gegenstueck eines Feldes, an der Mittelreihe gespiegelt. Bei einer
## ungeraden Reihenzahl haben Reihe y und h - 1 - y denselben Versatz -- die
## Spiegelung ist damit auf dem Hexfeld exakt (eine Drehung um die Mitte
## waere es mit versetzten Reihen nicht).
static func mirror(grid: Grid, tile: Vector2i) -> Vector2i:
	return Vector2i(tile.x, grid.height - 1 - tile.y)


## Ob ein Feld an ein schon gesetztes Hindernis grenzt -- Gruppen sollen
## frei stehen, sonst wachsen Mauern zusammen.
static func _touches(grid: Grid, tile: Vector2i) -> bool:
	if grid.obstacles.has(tile):
		return true
	for next in Grid.neighbors(tile):
		if grid.obstacles.has(next):
			return true
	return false


## Ob alle freien Felder zusammenhaengen (Schritte in sechs Richtungen).
static func _connected(grid: Grid) -> bool:
	var start := Vector2i(-1, -1)
	var free := 0
	for tile in grid.all_tiles():
		if not grid.obstacles.has(tile):
			free += 1
			if start.x < 0:
				start = tile
	var seen := {start: true}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var tile: Vector2i = frontier.pop_back()
		for next in Grid.neighbors(tile):
			if grid.in_bounds(next) and not grid.obstacles.has(next) and not seen.has(next):
				seen[next] = true
				frontier.append(next)
	return seen.size() == free


## Die Aufstellungszone einer Seite: ein Streifen am Kartenrand (seit
## 10. Nov. 2026, Wunsch des Spielers -- vorher ein 3 x 5-Block, der 5 Felder
## von der Ecke eingerueckt mitten im Feld lag). Seit dem Hexfeld (17. Nov.
## 2026) steht der Spieler an der Kante unten, der Gegner oben; der Kampf
## laeuft im Hochformat von unten nach oben.
##
## data/config.json -> "deployment": rows Reihen tief, columns Felder breit
## (mittig an der Kante), inset Felder Abstand zum Rand.
##
## Reihenfolge: die vorderste Reihe (dem Gegner am naechsten) zuerst, in
## jeder Reihe von der Mitte nach aussen. Die Gegnerzone ist Feld fuer Feld
## die an der Mittelreihe gespiegelte Spielerzone -- gleiche Stelle in der
## Liste, gespiegeltes Feld. Daran haengt die Fairness im Spiegelkampf.
static func deployment_zone(grid: Grid, is_player: bool) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for row in deployment_rows(grid):
		var columns := range(deployment_columns(grid))
		var middle := (float(columns.size()) - 1.0) * 0.5
		columns.sort_custom(func(a: int, b: int):
			var da := absf(float(a) - middle)
			var db := absf(float(b) - middle)
			return da < db if not is_equal_approx(da, db) else a < b)
		for column in columns:
			tiles.append(deployment_tile(grid, is_player, row, column))
	return tiles


static func deployment_rows(grid: Grid) -> int:
	return clampi(int(Config.section("deployment").get("rows", 3)), 1, maxi(1, grid.height / 2 - 1))


static func deployment_columns(grid: Grid) -> int:
	return clampi(int(Config.section("deployment").get("columns", 8)), 1, grid.width)


## Das Feld an Reihe ``row`` (0 = vorn, am Gegner) und Spalte ``column``
## (0 = links aus Sicht des Spielers) der Zone einer Seite.
static func deployment_tile(grid: Grid, is_player: bool, row: int, column: int) -> Vector2i:
	var rows := deployment_rows(grid)
	var columns := deployment_columns(grid)
	var inset := clampi(int(Config.section("deployment").get("inset", 1)), 0,
		maxi(0, grid.height / 2 - rows))
	var left := (grid.width - columns) / 2
	var tile := Vector2i(left + column, grid.height - inset - rows + row)
	return tile if is_player else mirror(grid, tile)


## Die Standard-Aufstellung fuer ``roles`` (die Rollen der DROMEs in der
## Reihenfolge des Squads): wer vorn steht und wie weit die Figuren
## auseinander. Gibt je DROME {row, column} zurueck.
##
##   Reihe    Frontlinie vorn, Plaenkler in der Mitte, Wirker und
##            Scharfschuetze hinten.
##   Spalte   gleichmaessig ueber die Breite verteilt, jeder in einer eigenen
##            Spalte; die Mitte bekommt, wer weiter vorn steht.
##
## Vorher standen alle Schulter an Schulter auf den vordersten Feldern --
## vier Figuren uebereinander, die man mit dem Finger nicht auseinanderbekam.
const ROLE_ROW := {"vanguard": 0, "skirmisher": 1, "": 1, "controller": 2, "sniper": 2}

static func default_formation(grid: Grid, roles: Array) -> Array:
	var rows := deployment_rows(grid)
	var columns := deployment_columns(grid)
	var count := roles.size()
	var out: Array = []
	out.resize(count)
	# Wer weiter vorn steht, waehlt zuerst (stabil in Squad-Reihenfolge).
	var order := range(count)
	order.sort_custom(func(a: int, b: int):
		var ra: int = ROLE_ROW.get(roles[a], 1)
		var rb: int = ROLE_ROW.get(roles[b], 1)
		return ra < rb if ra != rb else a < b)
	# Die Spalten: gleichmaessig verteilt, die mittleren zuerst.
	var spread: Array = []
	for i in mini(count, columns):
		spread.append(clampi(int(floor((float(i) + 0.5) * float(columns) / float(mini(count, columns)))),
			0, columns - 1))
	var middle := (float(columns) - 1.0) * 0.5
	spread.sort_custom(func(a: int, b: int):
		var da := absf(float(a) - middle)
		var db := absf(float(b) - middle)
		return da < db if not is_equal_approx(da, db) else a < b)
	var taken := {}
	for n in order.size():
		var index: int = order[n]
		var row := mini(int(ROLE_ROW.get(roles[index], 1)), rows - 1)
		var column: int = spread[n % spread.size()] if not spread.is_empty() else 0
		# Mehr DROMEs als Spalten: das naechste freie Feld der Zone.
		var guard := 0
		while taken.has(Vector2i(row, column)) and guard < rows * columns:
			column = (column + 1) % columns
			if column == 0:
				row = (row + 1) % rows
			guard += 1
		taken[Vector2i(row, column)] = true
		out[index] = {"row": row, "column": column}
	return out
