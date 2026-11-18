extends RefCounted

## Das Kampfgitter: Distanz, Belegung, Aufstellung, Regionen.
##
## Seit dem Umbau zum Autobattler (Nov. 2026) ist das Feld frei -- kein
## Gelaende, keine Sichtlinie. Uebrig bleibt, was Reichweite, Bewegung und
## Aufstellung brauchen.

var t


func test_distance_counts_hex_steps() -> void:
	# Hexfeld (17. Nov. 2026): sechs Schrittrichtungen, jeder Schritt kostet 1.
	t.equal(Grid.distance(Vector2i(4, 8), Vector2i(4, 8)), 0, "gleiches Feld")
	t.equal(Grid.neighbors(Vector2i(4, 8)).size(), 6, "sechs Nachbarn")
	for start in [Vector2i(4, 8), Vector2i(4, 7)]:
		for next in Grid.neighbors(start):
			t.equal(Grid.distance(start, next), 1, "%s -> %s ist ein Schritt" % [start, next])
	# Gerade Reihe: drei Felder nach rechts = 3; zwei Reihen hoch = 2.
	t.equal(Grid.distance(Vector2i(1, 8), Vector2i(4, 8)), 3, "quer")
	t.equal(Grid.distance(Vector2i(4, 8), Vector2i(4, 6)), 2, "zwei Reihen")
	t.equal(Grid.distance(Vector2i(4, 16), Vector2i(4, 0)), 16, "unten nach oben")
	# Axial hin und zurueck.
	for tile in [Vector2i(0, 0), Vector2i(3, 5), Vector2i(8, 16), Vector2i(-1, -3)]:
		t.equal(Grid.from_axial(Grid.to_axial(tile)), tile, "axial %s" % tile)


func test_neighbors_lie_around_the_tile_on_screen() -> void:
	# Richtung i zeigt im Bild auf i * 60 Grad -- Darstellung und Logik passen.
	for start in [Vector2i(4, 8), Vector2i(4, 7)]:
		var center := IsoView.map_to_local(start)
		for dir in 6:
			var d := IsoView.map_to_local(Grid.neighbor(start, dir)) - center
			d.y /= IsoView.DEPTH_SQUASH
			var angle := rad_to_deg(atan2(-d.y, d.x))
			t.ok(absf(angle_difference(deg_to_rad(angle), deg_to_rad(dir * 60.0))) < 0.01,
				"%s Richtung %d auf %d Grad (%.1f)" % [start, dir, dir * 60, angle])
			t.equal(Grid.direction_toward(start, Grid.neighbor(start, dir)), dir,
				"direction_toward erkennt Richtung %d" % dir)
		t.equal(IsoView.local_to_map(center + Vector2(3, -2)), start, "Klick trifft das Feld")


func test_lines_on_the_hex_field() -> void:
	t.equal(Grid.line_direction(Vector2i(4, 8), Vector2i(7, 8)), 0, "nach rechts")
	t.equal(Grid.line_direction(Vector2i(4, 8), Vector2i(1, 8)), 3, "nach links")
	var far := Grid.neighbor(Grid.neighbor(Vector2i(4, 8), 1), 1)
	t.equal(Grid.line_direction(Vector2i(4, 8), far), 1, "schraeg hoch rechts")
	t.equal(Grid.line_direction(Vector2i(4, 8), Vector2i(4, 6)), -1, "zwei Reihen hoch ist keine Linie")


func test_two_dromes_never_share_a_tile() -> void:
	var grid := Grid.new(6, 6)
	grid.set_occupant(Vector2i(2, 2), &"P0")
	t.ok(not grid.can_stand_on(Vector2i(2, 2), &"E0"), "belegtes Feld ist zu")
	t.ok(grid.can_stand_on(Vector2i(2, 2), &"P0"), "das eigene Feld bleibt stehbar")
	t.ok(not grid.can_stand_on(Vector2i(-1, 2)), "ausserhalb geht nichts")
	grid.clear_occupant(Vector2i(2, 2))
	t.ok(grid.can_stand_on(Vector2i(2, 2), &"E0"), "geräumt ist es wieder frei")


func test_the_field_is_open_and_has_the_configured_size() -> void:
	var region := TerrainDB.get_region(&"city")
	var grid := MapGenerator.generate(region)
	t.equal(grid.width, Config.get_int("grid_width", 9), "Breite aus der Konfiguration")
	t.equal(grid.height, Config.get_int("grid_height", 17), "Höhe aus der Konfiguration")
	t.equal(grid.region, region, "die Region hängt am Gitter (Optik)")
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


func test_deployment_runs_bottom_against_top() -> void:
	# Hexfeld (17. Nov. 2026): Spieler unten, Gegner oben, beide mittig.
	var grid := MapGenerator.generate(TerrainDB.get_region(&"city"))
	var player := MapGenerator.deployment_zone(grid, true)
	var enemy := MapGenerator.deployment_zone(grid, false)

	var player_first: Vector2i = player[0]
	var enemy_first: Vector2i = enemy[0]
	t.ok(player_first.y > enemy_first.y,
		"der Spieler stellt tiefer auf als der Gegner (%s vs %s)"
		% [player_first, enemy_first])
	for tile in player:
		t.ok(tile.y >= grid.height - 3, "Spielerzone in den unteren drei Reihen (%s)" % tile)
	for i in player.size():
		t.equal(enemy[i], MapGenerator.mirror(grid, player[i]), "Gegnerzone gespiegelt (%d)" % i)

	var player_pos := IsoView.map_to_local(player_first)
	var enemy_pos := IsoView.map_to_local(enemy_first)
	t.ok(absf(player_pos.x - enemy_pos.x) < 1.0, "beide mittig")
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
				"Seed %d: %s hat sein Gegenstück" % [seed_value, tile])
		for is_player in [true, false]:
			for tile in MapGenerator.deployment_zone(grid, is_player):
				t.ok(not grid.is_blocked(tile), "Seed %d: Zone frei bei %s" % [seed_value, tile])


func test_obstacles_block_walking_and_keep_the_field_connected() -> void:
	var grid := _obstacle_grid(42)
	var tile: Vector2i = grid.obstacles.keys()[0]
	t.ok(not grid.can_stand_on(tile), "auf einem Hindernis steht niemand")
	t.ok(MapGenerator._connected(grid), "alle freien Felder hängen zusammen")
	var again := _obstacle_grid(42)
	t.equal(again.obstacles, grid.obstacles, "derselbe Seed, dieselben Hindernisse")
