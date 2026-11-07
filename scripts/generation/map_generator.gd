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


## Spieler unten links, Gegner oben rechts.
static func deployment_zone(grid: Grid, is_player: bool) -> Array[Vector2i]:
	var deploy := Config.section("deployment")
	var rows := int(deploy.get("rows", 2))
	var columns := int(deploy.get("columns", 6))
	# Abstand der Zonen von den Ecken (Nov. 2026). Im Autobattler ist
	# Anlaufzeit Zeit ohne Inhalt: in der Ecke standen sich die Squads rund
	# 22 Felder entfernt gegenueber, und langsame DROMEs kamen erst an, als
	# der Kampf halb vorbei war. Mit 5 Feldern Einzug sind es etwa 8 bis 12.
	var inset := clampi(int(deploy.get("inset", 0)), 0,
		maxi(0, mini(grid.width - columns, grid.height - rows) / 2))
	var tiles: Array[Vector2i] = []
	for row in rows:
		for column in columns:
			if is_player:
				tiles.append(Vector2i(inset + column, grid.height - 1 - inset - row))
			else:
				tiles.append(Vector2i(grid.width - 1 - inset - column, inset + row))

	# Aufgestellt wird in dieser Reihenfolge -- deshalb steht sie hier und
	# nicht dem Zufall ueberlassen.
	#
	# Isometrisch ist x+y die Bildschirmtiefe: was hoehere Summe hat, liegt
	# weiter unten. Ohne diese Sortierung faengt jede Zone an ihrer Ecke an,
	# und beide Squads landen auf den beiden SEITLICHEN Spitzen der Raute --
	# auf gleicher Hoehe, links und rechts. Der Entwurf will "unten links"
	# gegen "oben rechts", und genau das faellt heraus, wenn der Spieler von
	# der tiefsten Kachel seiner Zone aus aufstellt und der Gegner von der
	# hoechsten seiner.
	tiles.sort_custom(func(a: Vector2i, b: Vector2i):
		var da := a.x + a.y
		var db := b.x + b.y
		if da != db:
			return da > db if is_player else da < db
		# Auch der Gleichstand wird gespiegelt: die Gegnerzone ist die um die
		# Kartenmitte gedrehte Spielerzone, also laeuft x dort andersherum.
		# Mit derselben Richtung stand der zweite Gegner eine Reihe weiter vorn
		# als sein Gegenstueck -- im Echtzeit-Kampf gewann die Spielerseite
		# dadurch 33 von 40 Spiegelkaempfen.
		return a.x < b.x if is_player else a.x > b.x)
	return tiles
