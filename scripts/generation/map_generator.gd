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

## Die Formen eines Hindernisses (Versatz vom Ankerfeld): einzeln, kurze
## Mauer, Ecke.
const SHAPES := [
	[Vector2i(0, 0)],
	[Vector2i(0, 0), Vector2i(1, 0)],
	[Vector2i(0, 0), Vector2i(0, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
]


## Ein leeres Feld in der Groesse aus der Konfiguration.
static func generate(region: Terrain.Region) -> Grid:
	var grid := Grid.new(Config.get_int("grid_width", Grid.DEFAULT_SIZE),
		Config.get_int("grid_height", Grid.DEFAULT_SIZE))
	grid.region = region
	return grid


## Setzt die Hindernisse. Eigener Zufall aus ``seed_value`` -- der Zufall
## des Kampfes (Region, Gegner) bleibt dadurch unberuehrt, und die Vorschau
## im Lauf zeigt weiter denselben Kampf.
##
## Einstellungen in data/config.json -> "obstacles": wie viele Gruppen
## (je Seite), Abstand zu den Zonen. Jede Gruppe wird gespiegelt
## (x, y) -> (b - 1 - x, h - 1 - y), so wie die Gegnerzone die gedrehte
## Spielerzone ist. Eine Gruppe, die das Feld zerteilen wuerde, faellt weg.
static func place_obstacles(grid: Grid, seed_value: int) -> void:
	grid.obstacles.clear()
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
	for is_player in [true, false]:
		for tile in deployment_zone(grid, is_player):
			for dx in range(-margin, margin + 1):
				for dy in range(-margin, margin + 1):
					keep_free[tile + Vector2i(dx, dy)] = true

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
		for offset in shape:
			for tile in [anchor + offset, mirror(grid, anchor + offset)]:
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


## Das Gegenstueck eines Feldes, um die Feldmitte gedreht.
static func mirror(grid: Grid, tile: Vector2i) -> Vector2i:
	return Vector2i(grid.width - 1 - tile.x, grid.height - 1 - tile.y)


## Ob ein Feld an ein schon gesetztes Hindernis grenzt (auch schraeg) --
## Gruppen sollen frei stehen, sonst wachsen Mauern zusammen.
static func _touches(grid: Grid, tile: Vector2i) -> bool:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if grid.obstacles.has(tile + Vector2i(dx, dy)):
				return true
	return false


## Ob alle freien Felder zusammenhaengen (Schritte in vier Richtungen).
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
		for dir in Grid.directions():
			var next: Vector2i = tile + dir
			if grid.in_bounds(next) and not grid.obstacles.has(next) and not seen.has(next):
				seen[next] = true
				frontier.append(next)
	return seen.size() == free


## Die Aufstellungszone einer Seite: ein Streifen am Kartenrand (seit
## 10. Nov. 2026, Wunsch des Spielers -- vorher ein 3 x 5-Block, der 5 Felder
## von der Ecke eingerueckt mitten im Feld lag). Der Spieler steht an der
## Kante unten links, der Gegner an der Kante oben rechts; im Hochformat
## laeuft der Kampf damit schraeg ueber den Bildschirm statt quer.
##
## data/config.json -> "deployment": rows Reihen tief, columns Felder breit
## (mittig an der Kante), inset Felder Abstand zum Rand.
##
## Reihenfolge: die vorderste Reihe (dem Gegner am naechsten) zuerst, in
## jeder Reihe von der Mitte nach aussen. Die Gegnerzone ist Feld fuer Feld
## die um die Kartenmitte gedrehte Spielerzone -- gleiche Stelle in der
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
