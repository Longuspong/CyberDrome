extends RefCounted

## Das Kampfgitter: Distanz, Belegung, Aufstellung, Regionen.
##
## Seit dem Umbau zum Autobattler (Nov. 2026) ist das Feld frei -- kein
## Gelaende, keine Sichtlinie. Uebrig bleibt, was Reichweite, Bewegung und
## Aufstellung brauchen.

var t


func test_distance_is_manhattan() -> void:
	# Reichweite und Bewegung rechnen beide mit dieser Distanz: vier
	# Schrittrichtungen, also Manhattan.
	t.equal(Grid.distance(Vector2i(0, 0), Vector2i(3, 4)), 7, "Manhattan-Distanz")
	t.equal(Grid.directions().size(), 4, "vier Schrittrichtungen")


func test_two_dromes_never_share_a_tile() -> void:
	var grid := Grid.new(6, 6)
	grid.set_occupant(Vector2i(2, 2), &"P0")
	t.ok(not grid.can_stand_on(Vector2i(2, 2), &"E0"), "belegtes Feld ist zu")
	t.ok(grid.can_stand_on(Vector2i(2, 2), &"P0"), "das eigene Feld bleibt stehbar")
	t.ok(not grid.can_stand_on(Vector2i(-1, 2)), "ausserhalb geht nichts")
	grid.clear_occupant(Vector2i(2, 2))
	t.ok(grid.can_stand_on(Vector2i(2, 2), &"E0"), "geraeumt ist es wieder frei")


func test_the_field_is_open_and_has_the_configured_size() -> void:
	var region := TerrainDB.get_region(&"city")
	var grid := MapGenerator.generate(region)
	t.equal(grid.width, Config.get_int("grid_width", 20), "Breite aus der Konfiguration")
	t.equal(grid.height, Config.get_int("grid_height", 20), "Hoehe aus der Konfiguration")
	t.equal(grid.region, region, "die Region haengt am Gitter (Optik)")
	var free := 0
	for tile in grid.all_tiles():
		if grid.can_stand_on(tile):
			free += 1
	t.equal(free, grid.width * grid.height, "jedes Feld ist betretbar")


func test_every_region_has_a_floor_tile() -> void:
	t.ok(TerrainDB.regions.size() >= 3, "drei Regionen geladen")
	for region in TerrainDB.regions.values():
		t.ok(ResourceLoader.exists(region.floor_texture),
			"%s hat eine Bodenkachel (%s)" % [region.display_name, region.floor_texture])
	t.ok(TerrainDB.missing_tiles.is_empty(), "keine Kachel fehlt")


func test_deployment_runs_bottom_left_against_top_right() -> void:
	# Isometrisch ist x+y die Bildschirmtiefe. Ohne die Sortierung in
	# deployment_zone() faengt jede Zone an ihrer Ecke an, und beide Squads
	# landen auf den seitlichen Spitzen der Raute -- auf gleicher Hoehe.
	var grid := Grid.new(20, 20)
	var player := MapGenerator.deployment_zone(grid, true)
	var enemy := MapGenerator.deployment_zone(grid, false)

	var player_first: Vector2i = player[0]
	var enemy_first: Vector2i = enemy[0]
	t.ok(player_first.x + player_first.y > enemy_first.x + enemy_first.y,
		"der Spieler stellt tiefer auf als der Gegner (%s vs %s)"
		% [player_first, enemy_first])

	var player_pos := IsoView.map_to_local(player_first)
	var enemy_pos := IsoView.map_to_local(enemy_first)
	t.ok(player_pos.x < enemy_pos.x, "Spieler links, Gegner rechts")
	t.ok(player_pos.y > enemy_pos.y, "Spieler unten, Gegner oben")


func _obstacle_grid(seed_value: int) -> Grid:
	var region: Terrain.Region = TerrainDB.regions.values()[seed_value % TerrainDB.regions.size()]
	var grid := MapGenerator.generate(region)
	MapGenerator.place_obstacles(grid, seed_value)
	return grid


func test_obstacles_are_mirrored_and_keep_the_zones_free() -> void:
	for seed_value in [1, 7, 42, 2026, 99999]:
		var grid := _obstacle_grid(seed_value)
		t.ok(not grid.obstacles.is_empty(), "Seed %d: es gibt Hindernisse" % seed_value)
		for tile in grid.obstacles:
			t.ok(grid.obstacles.has(MapGenerator.mirror(grid, tile)),
				"Seed %d: %s hat sein Gegenstueck" % [seed_value, tile])
		for is_player in [true, false]:
			for tile in MapGenerator.deployment_zone(grid, is_player):
				t.ok(not grid.is_blocked(tile), "Seed %d: Zone frei bei %s" % [seed_value, tile])


func test_obstacles_block_walking_and_keep_the_field_connected() -> void:
	var grid := _obstacle_grid(42)
	var tile: Vector2i = grid.obstacles.keys()[0]
	t.ok(not grid.can_stand_on(tile), "auf einem Hindernis steht niemand")
	t.ok(MapGenerator._connected(grid), "alle freien Felder haengen zusammen")
	var again := _obstacle_grid(42)
	t.equal(again.obstacles, grid.obstacles, "derselbe Seed, dieselben Hindernisse")
