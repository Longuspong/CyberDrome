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
	# Flache Sechsecke (18. Nov. 2026): Richtung i zeigt im Bild auf
	# 30 + i * 60 Grad -- Darstellung und Logik passen.
	for start in [Vector2i(4, 8), Vector2i(5, 7)]:
		var center := IsoView.map_to_local(start)
		for dir in 6:
			var d := IsoView.map_to_local(Grid.neighbor(start, dir)) - center
			d.y /= IsoView.DEPTH_SQUASH
			var angle := rad_to_deg(atan2(-d.y, d.x))
			var want := 30.0 + dir * 60.0
			t.ok(absf(angle_difference(deg_to_rad(angle), deg_to_rad(want))) < 0.01,
				"%s Richtung %d auf %d Grad (%.1f)" % [start, dir, int(want), angle])
			t.equal(Grid.direction_toward(start, Grid.neighbor(start, dir)), dir,
				"direction_toward erkennt Richtung %d" % dir)
		t.equal(IsoView.local_to_map(center + Vector2(3, -2)), start, "Klick trifft das Feld")


func test_lines_on_the_hex_field() -> void:
	# Flache Sechsecke: die Spalte ist eine gerade Linie -- geradeaus nach
	# oben und unten (darum geht es: DROMEs laufen gerade aufeinander zu).
	t.equal(Grid.line_direction(Vector2i(4, 8), Vector2i(4, 5)), 1, "geradeaus hoch")
	t.equal(Grid.line_direction(Vector2i(4, 8), Vector2i(4, 11)), 4, "geradeaus runter")
	var far := Grid.neighbor(Grid.neighbor(Vector2i(4, 8), 0), 0)
	t.equal(Grid.line_direction(Vector2i(4, 8), far), 0, "schraeg hoch rechts")
	t.equal(Grid.line_direction(Vector2i(4, 8), Vector2i(6, 8)), -1, "zwei Spalten quer ist keine Linie")
	t.equal(Grid.distance(Vector2i(4, 2), Vector2i(4, 12)), 10, "eine Spalte: Abstand = Reihen")


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
	# Seit 18. Nov. 2026: ohne Angabe die Standardkarte (config.json -> maps).
	var spec := MapGenerator.map_spec("")
	t.equal(grid.width, int(spec["width"]), "Breite der Standardkarte")
	t.equal(grid.height, int(spec["height"]), "Höhe der Standardkarte")
	t.equal([grid.width, grid.height], [9, 15], "Standard ist 9 x 15")
	t.equal(grid.region, region, "die Region hängt am Gitter (Optik)")
	var free := 0
	for tile in grid.all_tiles():
		if grid.can_stand_on(tile):
			free += 1
	# Flache Sechsecke: ungerade Spalten haben eine Reihe weniger.
	t.equal(free, grid.width * grid.height - grid.width / 2, "jedes Feld ist betretbar")


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
		t.ok(tile.y >= grid.height - 1 - (tile.x & 1) - 2, "Spielerzone in den unteren drei Reihen (%s)" % tile)
	for i in player.size():
		t.equal(enemy[i], MapGenerator.mirror(grid, player[i]), "Gegnerzone gespiegelt (%d)" % i)

	var player_pos := IsoView.map_to_local(player_first)
	var enemy_pos := IsoView.map_to_local(enemy_first)
	t.ok(absf(player_pos.x - enemy_pos.x) < 1.0, "beide mittig")
	t.ok(player_pos.y > enemy_pos.y, "Spieler unten, Gegner oben")


## Alle Karten aus config.json -> maps.
func _map_ids() -> Array:
	var out: Array = []
	for key in Config.section("maps"):
		if Config.section("maps")[key] is Dictionary:
			out.append(str(key))
	return out


func test_every_map_is_mirrored_connected_and_keeps_the_zones() -> void:
	# Karten je Formation (18. Nov. 2026): feste Formen, an der Mittelreihe
	# gespiegelt -- beide Seiten haben dieselben Bedingungen.
	t.ok(_map_ids().size() >= 5, "mindestens fünf Karten (%s)" % [_map_ids()])
	for map_id in _map_ids():
		var grid := MapGenerator.generate(TerrainDB.get_region(&"city"), map_id)
		MapGenerator.place_obstacles(grid, 42)
		t.equal(grid.map_id, map_id, "%s: Karte gewählt" % map_id)
		t.equal(grid.height % 2, 1, "%s: ungerade Reihenzahl (exakte Spiegelung)" % map_id)
		for tile in grid.holes:
			t.ok(grid.holes.has(MapGenerator.mirror(grid, tile)), "%s: Loch %s gespiegelt" % [map_id, tile])
			t.ok(not grid.in_bounds(tile), "%s: Loch %s gehört nicht zum Feld" % [map_id, tile])
		for tile in grid.obstacles:
			t.ok(grid.obstacles.has(MapGenerator.mirror(grid, tile)), "%s: Block %s gespiegelt" % [map_id, tile])
		for is_player in [true, false]:
			for tile in MapGenerator.deployment_zone(grid, is_player):
				t.ok(grid.can_stand_on(tile), "%s: Zone frei bei %s" % [map_id, tile])
		t.ok(MapGenerator._connected(grid), "%s: alle freien Felder hängen zusammen" % map_id)


func test_map_shapes_do_what_they_promise() -> void:
	var region := TerrainDB.get_region(&"city")
	var belly := MapGenerator.generate(region, "bauch")
	t.ok(not belly.holes.is_empty(), "Bauch: die Ecken fehlen")
	var mid := belly.height / 2
	var wide := 0
	for x in belly.width:
		if belly.in_bounds(Vector2i(x, mid)):
			wide += 1
	t.equal(wide, belly.width, "Bauch: in der Mitte die volle Breite")
	var lanes := MapGenerator.generate(region, "gassen")
	t.ok(lanes.obstacles.size() >= 7, "Zwei Gassen: eine Mauer in der Mitte (%d Felder)" % lanes.obstacles.size())
	t.ok(lanes.is_blocked(Vector2i(lanes.width / 2, lanes.height / 2)), "Zwei Gassen: die Mitte ist gesperrt")
	t.equal(MapGenerator.generate(region, "gibt_es_nicht").map_id, "standard",
		"unbekannte Karte: die Standardkarte")


func test_random_obstacles_are_off_and_every_formation_has_a_map() -> void:
	# 18. Nov. 2026 (Spieler): keine zufaelligen Hindernisse mehr.
	var grid := MapGenerator.generate(TerrainDB.get_region(&"city"))
	MapGenerator.place_obstacles(grid, 2026)
	t.ok(grid.obstacles.is_empty(), "Standardkarte ohne zufällige Hindernisse")
	for entry in Formations.all():
		var map_id := str(entry.get("map", ""))
		t.ok(map_id == "" or map_id in _map_ids(), "%s: Karte %s gibt es" % [entry.get("id"), map_id])
	for entry in Formations.of_region(&"city"):
		t.ok(str(entry.get("map", "")) != "", "%s hat eine eigene Karte" % entry.get("id"))
