class_name MapGenerator
extends RefCounted

## Erzeugt eine Kampfkarte aus einem Seed.
##
## Der Generator verteilt KLASSEN, nie Typen. Erst am Ende bekommt das Gitter
## seine Region -- damit ist eine neue Region ein Datensatz plus fuenf Tiles
## und kein Codeeingriff.
##
## Derselbe Seed ergibt exakt dieselbe Karte. Das ist im Playtesting Gold
## wert: ein Fehler laesst sich melden, indem man eine Zahl weitergibt.

var rng := RandomNumberGenerator.new()
var _config: Dictionary = {}

## Wird nach generate() gefuellt: warum wurde wie oft neu gewuerfelt?
var attempts_used: int = 0


func _init(battle_seed: int = 0) -> void:
	rng.seed = battle_seed
	_config = Config.section("map")


## Erzeugt ein Gitter. ``mutator`` skaliert die Mengen (Schrottfeld,
## Oelhavarie, Planiert ...) und ist ansonsten fuer den Generator bedeutungslos.
func generate(region: Terrain.Region, mutator: Dictionary = {}) -> Grid:
	var width := Config.get_int("grid_width", Grid.DEFAULT_SIZE)
	var height := Config.get_int("grid_height", Grid.DEFAULT_SIZE)
	var max_attempts := int(_config.get("max_attempts", 20))

	var fallback: Grid = null
	for attempt in max_attempts:
		attempts_used = attempt + 1
		var grid := _build_once(width, height, region, mutator)
		if _is_playable(grid):
			return grid
		if fallback == null:
			fallback = grid

	# Alle Versuche verworfen. Lieber eine Karte ohne Hindernisse als gar
	# keine -- und eine laute Meldung, weil das nicht passieren sollte.
	push_warning("MapGenerator: %d Versuche ohne durchquerbare Karte. "
		% max_attempts + "Fallback auf eine Karte ohne STEP und BLOCK.")
	var plain := Grid.new(width, height)
	plain.region = region
	return plain


func _build_once(width: int, height: int, region: Terrain.Region,
		mutator: Dictionary) -> Grid:
	var grid := Grid.new(width, height)
	grid.region = region
	grid.fill(Terrain.TClass.NORMAL)

	var reserved := _deployment_tiles(grid)

	_place_blocks(grid, reserved, float(mutator.get("block_scale", 1.0)))
	_place_steps(grid, reserved, float(mutator.get("step_scale", 1.0)))
	_place_drift(grid, reserved, region, float(mutator.get("drift_scale", 1.0)))
	_place_haze(grid, reserved, float(mutator.get("haze_scale", 1.0)))
	return grid


# ---------------------------------------------------------------------------
# Aufstellungszonen
# ---------------------------------------------------------------------------

## Spieler unten links, Gegner oben rechts. Hier wird nichts platziert --
## eine Startaufstellung im Betonpfeiler waere kein Zufall, sondern ein Fehler.
static func deployment_zone(grid: Grid, is_player: bool) -> Array[Vector2i]:
	var deploy := Config.section("deployment")
	var rows := int(deploy.get("rows", 2))
	var columns := int(deploy.get("columns", 6))
	var tiles: Array[Vector2i] = []
	for row in rows:
		for column in columns:
			if is_player:
				tiles.append(Vector2i(column, grid.height - 1 - row))
			else:
				tiles.append(Vector2i(grid.width - 1 - column, row))

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
		return a.x < b.x)
	return tiles


func _deployment_tiles(grid: Grid) -> Dictionary:
	var reserved := {}
	for tile in deployment_zone(grid, true):
		reserved[tile] = true
	for tile in deployment_zone(grid, false):
		reserved[tile] = true
	return reserved


# ---------------------------------------------------------------------------
# Die vier Verteilungen
# ---------------------------------------------------------------------------

func _place_blocks(grid: Grid, reserved: Dictionary, scale: float) -> void:
	var amount := _scaled(Config.range_of(_config, "block_tiles", Vector2i(8, 14)), scale)
	if amount <= 0:
		return
	var clump := Config.range_of(_config, "block_clump", Vector2i(1, 3))
	var placed := 0
	var guard := 0
	while placed < amount and guard < amount * 20:
		guard += 1
		var origin := _random_free_tile(grid, reserved)
		if origin.x < 0:
			continue
		var size := rng.randi_range(clump.x, clump.y)
		for tile in _grow_clump(grid, reserved, origin, size):
			grid.set_terrain_class(tile, Terrain.TClass.BLOCK)
			placed += 1


## Stufen bilden Ketten, bevorzugt quer zur Verbindungslinie der beiden
## Aufstellungszonen -- so entstehen die Laufkorridore, fuer die die Klasse da
## ist. Eine Stufenkette formt Laufwege, ohne Schusslinien zu schliessen.
func _place_steps(grid: Grid, reserved: Dictionary, scale: float) -> void:
	var chains := _scaled(Config.range_of(_config, "step_chains", Vector2i(2, 4)), scale)
	if chains <= 0:
		return
	var length_range := Config.range_of(_config, "step_chain_length", Vector2i(3, 6))
	for _i in chains:
		var origin := _random_free_tile(grid, reserved)
		if origin.x < 0:
			continue
		# Die Zonen liegen unten-links und oben-rechts, die Verbindungslinie
		# also auf der Gegendiagonalen. Quer dazu heisst: nach unten-rechts.
		var dir := Vector2i(1, 1) if rng.randf() < 0.5 else Vector2i(1, -1)
		if Grid.ALLOW_DIAGONALS == false:
			# Ohne Diagonalen wird die Kette als Treppe gelegt.
			dir = Vector2i(1, 0) if rng.randf() < 0.5 else Vector2i(0, 1)
		var length := rng.randi_range(length_range.x, length_range.y)
		var cur := origin
		for _step in length:
			if not grid.in_bounds(cur) or reserved.has(cur):
				break
			if grid.terrain_class(cur) == Terrain.TClass.NORMAL:
				grid.set_terrain_class(cur, Terrain.TClass.STEP)
			cur += dir
			# Leichter Versatz, damit keine perfekten Linien entstehen.
			if rng.randf() < 0.3:
				cur += Vector2i(0, 1) if dir.x != 0 else Vector2i(1, 0)


## Drift: Flecken, oder in einer Region mit gerichteter Drift gerade Schienen
## mit einheitlicher flow_direction. Beide Varianten laufen durch denselben
## Code im Grid -- der Unterschied ist ein Vector2i.
func _place_drift(grid: Grid, reserved: Dictionary, region: Terrain.Region,
		scale: float) -> void:
	var directed := region != null and region.drift_is_directed()
	if directed:
		var rails := _scaled(Config.range_of(_config, "drift_rails", Vector2i(1, 2)), scale)
		var length_range := Config.range_of(_config, "drift_rail_length", Vector2i(5, 8))
		for _i in rails:
			var origin := _random_free_tile(grid, reserved)
			if origin.x < 0:
				continue
			var dir: Vector2i = Grid.directions()[rng.randi() % Grid.directions().size()]
			var length := rng.randi_range(length_range.x, length_range.y)
			var cur := origin
			for _step in length:
				if not grid.in_bounds(cur) or reserved.has(cur):
					break
				if grid.terrain_class(cur) == Terrain.TClass.NORMAL:
					grid.set_terrain_class(cur, Terrain.TClass.DRIFT)
					grid.set_flow_direction(cur, dir)
				cur += dir
		return

	var patches := _scaled(Config.range_of(_config, "drift_patches", Vector2i(1, 3)), scale)
	var size_range := Config.range_of(_config, "drift_patch_size", Vector2i(4, 9))
	for _i in patches:
		var origin := _random_free_tile(grid, reserved)
		if origin.x < 0:
			continue
		var size := rng.randi_range(size_range.x, size_range.y)
		for tile in _grow_clump(grid, reserved, origin, size):
			grid.set_terrain_class(tile, Terrain.TClass.DRIFT)


## Haze bevorzugt die Kartenmitte zwischen den Aufstellungszonen. Dort tut es
## am meisten: es gibt Nahkaempfern einen Weg durch das offene Feld, ohne den
## ganzen Zyklus lang beschossen zu werden.
func _place_haze(grid: Grid, reserved: Dictionary, scale: float) -> void:
	var patches := _scaled(Config.range_of(_config, "haze_patches", Vector2i(2, 3)), scale)
	var size_range := Config.range_of(_config, "haze_patch_size", Vector2i(4, 8))
	for _i in patches:
		var origin := _random_center_tile(grid, reserved)
		if origin.x < 0:
			continue
		var size := rng.randi_range(size_range.x, size_range.y)
		for tile in _grow_clump(grid, reserved, origin, size):
			grid.set_terrain_class(tile, Terrain.TClass.HAZE)


# ---------------------------------------------------------------------------
# Hilfen
# ---------------------------------------------------------------------------

func _scaled(range_value: Vector2i, scale: float) -> int:
	if scale <= 0.0:
		return 0
	return int(round(rng.randi_range(range_value.x, range_value.y) * scale))


## Waechst einen zusammenhaengenden Klumpen aus freien NORMAL-Feldern.
func _grow_clump(grid: Grid, reserved: Dictionary, origin: Vector2i,
		size: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var frontier: Array[Vector2i] = [origin]
	var seen := {origin: true}
	while not frontier.is_empty() and tiles.size() < size:
		var index := rng.randi() % frontier.size()
		var cur: Vector2i = frontier[index]
		frontier.remove_at(index)
		if not grid.in_bounds(cur) or reserved.has(cur):
			continue
		if grid.terrain_class(cur) != Terrain.TClass.NORMAL:
			continue
		tiles.append(cur)
		for dir in Grid.directions():
			var nxt: Vector2i = cur + dir
			if not seen.has(nxt):
				seen[nxt] = true
				frontier.append(nxt)
	return tiles


func _random_free_tile(grid: Grid, reserved: Dictionary) -> Vector2i:
	for _try in 60:
		var tile := Vector2i(rng.randi_range(0, grid.width - 1),
			rng.randi_range(0, grid.height - 1))
		if reserved.has(tile):
			continue
		if grid.terrain_class(tile) == Terrain.TClass.NORMAL:
			return tile
	return Vector2i(-1, -1)


func _random_center_tile(grid: Grid, reserved: Dictionary) -> Vector2i:
	var margin_x := grid.width / 5
	var margin_y := grid.height / 5
	for _try in 60:
		var tile := Vector2i(
			rng.randi_range(margin_x, grid.width - 1 - margin_x),
			rng.randi_range(margin_y, grid.height - 1 - margin_y))
		if reserved.has(tile):
			continue
		if grid.terrain_class(tile) == Terrain.TClass.NORMAL:
			return tile
	return _random_free_tile(grid, reserved)


# ---------------------------------------------------------------------------
# Validierung
# ---------------------------------------------------------------------------

## Eine Karte ist spielbar, wenn ein DROME OHNE jedes Traversierungsflag von
## jeder Aufstellungszone zur anderen kommt -- und beide Zonen ueberhaupt
## freie Startfelder haben.
##
## Ohne diesen Schritt generiert man frueher oder spaeter eine Karte, auf der
## ein Rad-Antrieb den Gegner nie erreicht.
func _is_playable(grid: Grid) -> bool:
	var plain := MoveProfile.plain()
	var player := _standable(grid, deployment_zone(grid, true), plain)
	var enemy := _standable(grid, deployment_zone(grid, false), plain)
	if player.is_empty() or enemy.is_empty():
		return false
	# Eine Verbindung genuegt: die Zonen sind in sich zusammenhaengend, weil
	# in ihnen nichts platziert wird.
	return grid.has_plain_path(player[0], enemy[0])


func _standable(grid: Grid, tiles: Array[Vector2i],
		profile: MoveProfile) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tile in tiles:
		if grid.can_stand_on(tile, profile):
			result.append(tile)
	return result
