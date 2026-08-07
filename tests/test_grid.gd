extends RefCounted

## M1: Terrainklassen, Sichtlinie, Kartengenerator.

var t


func _open_grid(size: int = 10) -> Grid:
	return Grid.new(size, size)


# ---------------------------------------------------------------------------
# Sichtlinie
# ---------------------------------------------------------------------------

func test_block_breaks_sight_but_step_does_not() -> void:
	# Die zentrale Terrainaussage des MVP: eine Stufe ist eine Mauer fuer die
	# Fuesse, aber kein Hindernis fuer die Waffen. Ein Rad-Antrieb muss
	# aussenrum, waehrend die Railgun ungehindert darueber hinwegschiesst.
	var grid := _open_grid()
	var from := Vector2i(1, 5)
	var to := Vector2i(8, 5)

	grid.set_terrain_class(Vector2i(4, 5), Terrain.TClass.STEP)
	t.ok(grid.has_line_of_sight(from, to), "die Railgun schiesst ueber die Stufe")

	grid.set_terrain_class(Vector2i(4, 5), Terrain.TClass.BLOCK)
	t.ok(not grid.has_line_of_sight(from, to), "der Betonpfeiler nimmt die Sicht")


func test_haze_breaks_sight_but_not_movement() -> void:
	# Haze ist das exakte Spiegelbild von STEP.
	var grid := _open_grid()
	var from := Vector2i(1, 5)
	var to := Vector2i(8, 5)
	grid.set_terrain_class(Vector2i(4, 5), Terrain.TClass.HAZE)

	t.ok(not grid.has_line_of_sight(from, to), "Dampfschwaden nehmen die Sicht")

	var profile := MoveProfile.plain()
	t.ok(grid.can_traverse(Vector2i(4, 5), profile), "man laeuft ungehindert hindurch")
	t.ok(grid.can_stand_on(Vector2i(4, 5), profile), "und kann darin stehen bleiben")
	t.equal(grid.terrain_cost(Vector2i(4, 5), profile), 1,
		"Haze beeinflusst die Bewegungskosten ueberhaupt nicht")


func test_haze_blinds_from_the_own_tile_too() -> void:
	# Haze versteckt dich, aber es blendet dich genauso. Wer im Nebel steht,
	# ist auf Distanz weder angreifbar noch angriffsfaehig.
	var grid := _open_grid()
	grid.set_terrain_class(Vector2i(1, 5), Terrain.TClass.HAZE)
	t.ok(not grid.has_line_of_sight(Vector2i(1, 5), Vector2i(8, 5)),
		"aus dem eigenen Haze-Feld heraus sieht man auf Distanz nichts")

	var grid2 := _open_grid()
	grid2.set_terrain_class(Vector2i(8, 5), Terrain.TClass.HAZE)
	t.ok(not grid2.has_line_of_sight(Vector2i(1, 5), Vector2i(8, 5)),
		"und in ein Haze-Feld hinein ebensowenig")


func test_adjacent_tiles_always_have_sight() -> void:
	# Ohne diese Ausnahme koennten sich zwei DROMEs im selben Nebelfeld Auge
	# in Auge nicht angreifen, was niemand erwarten wuerde.
	var grid := _open_grid()
	grid.set_terrain_class(Vector2i(4, 5), Terrain.TClass.HAZE)
	grid.set_terrain_class(Vector2i(5, 5), Terrain.TClass.HAZE)
	t.ok(grid.has_line_of_sight(Vector2i(4, 5), Vector2i(5, 5)),
		"Nachbarfelder haben immer Sicht -- der Nahkaempfer trifft im Nebel")


func test_radar_sees_through_haze_but_not_through_concrete() -> void:
	# Das Gegenmittel kostet einen Sensorkopf, keinen Regelbruch: Haze ist
	# damit kein absoluter Konter gegen Fernkampf-Builds.
	var grid := _open_grid()
	grid.set_terrain_class(Vector2i(4, 5), Terrain.TClass.HAZE)
	t.ok(grid.has_line_of_sight(Vector2i(1, 5), Vector2i(8, 5), true),
		"mit Sensorik sieht man durch den Nebel")

	grid.set_terrain_class(Vector2i(6, 5), Terrain.TClass.BLOCK)
	t.ok(not grid.has_line_of_sight(Vector2i(1, 5), Vector2i(8, 5), true),
		"aber nicht durch den Betonpfeiler")


func test_units_never_break_sight() -> void:
	var grid := _open_grid()
	grid.set_occupant(Vector2i(4, 5), &"someone")
	t.ok(grid.has_line_of_sight(Vector2i(1, 5), Vector2i(8, 5)),
		"DROMEs unterbrechen die Sichtlinie nie")


func test_sight_blocker_names_the_reason() -> void:
	# Der Tooltip an einem grauen Ziel soll sagen, WARUM.
	var grid := _open_grid()
	grid.region = TerrainDB.get_region(&"city")
	grid.set_terrain_class(Vector2i(4, 5), Terrain.TClass.BLOCK)
	t.equal(grid.sight_blocker(Vector2i(1, 5), Vector2i(8, 5)), "Betonpfeiler",
		"der Grund wird beim Namen genannt")
	t.equal(grid.sight_blocker(Vector2i(1, 5), Vector2i(1, 6)), "",
		"freie Sicht liefert keinen Grund")


# ---------------------------------------------------------------------------
# Traversierung
# ---------------------------------------------------------------------------

func test_steps_need_the_flag_and_cost_double() -> void:
	var grid := _open_grid()
	var step := Vector2i(4, 4)
	grid.set_terrain_class(step, Terrain.TClass.STEP)

	var wheels := MoveProfile.plain()
	t.ok(not grid.can_traverse(step, wheels), "der Rad-Antrieb muss aussenrum")
	t.ok(not grid.can_stand_on(step, wheels), "und kann dort auch nicht stehen")

	var hover := MoveProfile.from_stats({"can_enter_steps": true})
	t.ok(grid.can_traverse(step, hover), "der Schweber kommt hinauf")
	t.equal(grid.terrain_cost(step, hover), 2, "eine Stufe kostet 2 MP")

	var spider := MoveProfile.from_stats({"can_enter_steps": true,
		"step_cost_reduced": true})
	t.equal(grid.terrain_cost(step, spider), 1, "Kletterbeine zahlen nur 1 MP")


func test_traversing_a_unit_never_means_landing_on_it() -> void:
	var grid := _open_grid()
	var busy := Vector2i(4, 4)
	grid.set_occupant(busy, &"other")
	var jumper := MoveProfile.from_stats({"can_pass_units": true}, &"hero")
	t.ok(grid.can_traverse(busy, jumper), "Sprung-Servos ziehen hindurch")
	t.ok(not grid.can_stand_on(busy, jumper),
		"aber der Zug darf niemals auf einem besetzten Feld enden")


func test_block_is_never_standable_even_with_the_flag() -> void:
	var grid := _open_grid()
	var wall := Vector2i(4, 4)
	grid.set_terrain_class(wall, Terrain.TClass.BLOCK)
	# can_pass_blocks ist Post-MVP und ueberall false -- aber selbst dann
	# bleibt das Landen verboten.
	var tunneler := MoveProfile.from_stats({"can_pass_blocks": true})
	t.ok(grid.can_traverse(wall, tunneler), "der Tunnelbauer zieht hindurch")
	t.ok(not grid.can_stand_on(wall, tunneler), "stehen bleibt er dort nie")


func test_no_part_enables_can_pass_blocks() -> void:
	# Das Flag existiert nur, damit Tunnelbauer spaeter eingehaengt werden
	# koennen, ohne die Pathfinding-Schicht anzufassen.
	for part in PartDB.parts.values():
		t.ok(not part.can_pass_blocks,
			"%s hat can_pass_blocks false (Post-MVP)" % part.id)


# ---------------------------------------------------------------------------
# Distanz
# ---------------------------------------------------------------------------

func test_distance_matches_the_movement_metric() -> void:
	# Manhattan bei vier Richtungen. Waeren beide nicht gekoppelt, stimmten
	# Reichweite und Bewegung irgendwann nicht mehr ueberein.
	t.equal(Grid.distance(Vector2i(0, 0), Vector2i(3, 4)),
		3 + 4 if not Grid.ALLOW_DIAGONALS else 4,
		"Distanzmetrik passt zur Zahl der Bewegungsrichtungen")
	t.equal(Grid.directions().size(), 8 if Grid.ALLOW_DIAGONALS else 4,
		"vier Bewegungsrichtungen")


# ---------------------------------------------------------------------------
# Kartengenerator
# ---------------------------------------------------------------------------

func test_hundred_generated_maps_are_all_traversable() -> void:
	# Das Fertig-Kriterium aus M1. Ohne diese Pruefung generiert man frueher
	# oder spaeter eine Karte, auf der ein Rad-Antrieb den Gegner nie erreicht.
	var region := TerrainDB.get_region(&"city")
	var failures := 0
	var retries := 0
	for i in 100:
		var generator := MapGenerator.new(1000 + i)
		var grid := generator.generate(region)
		retries += generator.attempts_used - 1

		var plain := MoveProfile.plain()
		var player := MapGenerator.deployment_zone(grid, true)
		var enemy := MapGenerator.deployment_zone(grid, false)
		var start := Vector2i(-1, -1)
		var goal := Vector2i(-1, -1)
		for tile in player:
			if grid.can_stand_on(tile, plain):
				start = tile
				break
		for tile in enemy:
			if grid.can_stand_on(tile, plain):
				goal = tile
				break
		if start.x < 0 or goal.x < 0 or not grid.has_plain_path(start, goal):
			failures += 1

	t.equal(failures, 0, "100 Karten sind ohne Traversierungs-Flags durchquerbar")
	t.note("100 Karten erzeugt, %d Neuwuerfe noetig" % retries)


func test_deployment_zones_stay_clear() -> void:
	var region := TerrainDB.get_region(&"green")
	for i in 25:
		var grid := MapGenerator.new(500 + i).generate(region)
		for is_player in [true, false]:
			for tile in MapGenerator.deployment_zone(grid, is_player):
				t.equal(grid.terrain_class(tile), Terrain.TClass.NORMAL,
					"Aufstellungsfeld %s bleibt frei" % tile)


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

	# Und auf dem Bildschirm heisst das: links unten gegen rechts oben.
	var player_pos := IsoView.map_to_local(player_first)
	var enemy_pos := IsoView.map_to_local(enemy_first)
	t.ok(player_pos.x < enemy_pos.x, "Spieler links, Gegner rechts")
	t.ok(player_pos.y > enemy_pos.y, "Spieler unten, Gegner oben")


func test_same_seed_gives_the_same_map() -> void:
	# Ein Akzeptanzkriterium: denselben Seed zweimal spielen und exakt
	# dieselbe Karte bekommen.
	var region := TerrainDB.get_region(&"city")
	var a := MapGenerator.new(777).generate(region)
	var b := MapGenerator.new(777).generate(region)
	var same := true
	for tile in a.all_tiles():
		if a.terrain_class(tile) != b.terrain_class(tile):
			same = false
		if a.flow_direction(tile) != b.flow_direction(tile):
			same = false
	t.ok(same, "derselbe Seed erzeugt exakt dieselbe Karte")

	var c := MapGenerator.new(778).generate(region)
	var different := false
	for tile in a.all_tiles():
		if a.terrain_class(tile) != c.terrain_class(tile):
			different = true
	t.ok(different, "ein anderer Seed erzeugt eine andere Karte")


func test_every_class_actually_appears() -> void:
	var region := TerrainDB.get_region(&"city")
	var seen := {}
	for i in 20:
		var grid := MapGenerator.new(300 + i).generate(region)
		for terrain_class in [Terrain.TClass.BLOCK, Terrain.TClass.STEP,
				Terrain.TClass.DRIFT, Terrain.TClass.HAZE]:
			if grid.count_class(terrain_class) > 0:
				seen[terrain_class] = true
	for terrain_class in [Terrain.TClass.BLOCK, Terrain.TClass.STEP,
			Terrain.TClass.DRIFT, Terrain.TClass.HAZE]:
		t.ok(seen.has(terrain_class),
			"%s kommt auf den Karten vor" % Terrain.class_label(terrain_class))


func test_plant7_uses_directed_drift() -> void:
	# Der einzige Punkt, an dem sich Regionen ueber Optik hinaus
	# unterscheiden duerfen -- und zwar ausschliesslich ueber flow_direction.
	var region := TerrainDB.get_region(&"plant7")
	t.ok(region.drift_is_directed(), "Anlage 7 hat gerichtete Drift")
	t.ok(not TerrainDB.get_region(&"city").drift_is_directed(),
		"Sektor City hat ungerichtete Drift")

	var found_flow := false
	for i in 20:
		var grid := MapGenerator.new(900 + i).generate(region)
		for tile in grid.all_tiles():
			if grid.terrain_class(tile) == Terrain.TClass.DRIFT \
					and grid.flow_direction(tile) != Vector2i.ZERO:
				found_flow = true
	t.ok(found_flow, "die Magnetschienen tragen eine Richtung")


func test_flattened_mutator_removes_the_soft_terrain() -> void:
	var region := TerrainDB.get_region(&"city")
	var mutator := {"step_scale": 0.0, "drift_scale": 0.0, "haze_scale": 0.0}
	for i in 10:
		var grid := MapGenerator.new(600 + i).generate(region, mutator)
		t.equal(grid.count_class(Terrain.TClass.STEP), 0, "Planiert: keine Stufen")
		t.equal(grid.count_class(Terrain.TClass.DRIFT), 0, "Planiert: keine Drift")
		t.equal(grid.count_class(Terrain.TClass.HAZE), 0, "Planiert: kein Haze")
		t.ok(grid.count_class(Terrain.TClass.BLOCK) > 0, "Planiert: aber Blocks")
