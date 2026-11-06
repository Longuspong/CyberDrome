extends RefCounted

## Der Hologramm-Boost (Dash): die einzige BEWEGUNGS-Aktion im Bestand.
##
## Sie versetzt den eigenen DROME in gerader Linie und stoppt vor anderen
## DROMEs. Ausgefuehrt landet der DROME wirklich auf dem gewaehlten Feld.

var t


func _vireo() -> DromeBuild:
	return DromeBuild.create("VIREO", {
		"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core",
		"equip_left": &"eq_holo_boost",
	})


func _dash_action(unit: Unit) -> ActionData:
	for action in unit.actions():
		if action.is_move():
			return action
	return null


func test_the_kit_actually_grants_a_dash() -> void:
	var build := _vireo()
	t.ok(build.is_valid(), "das Vireo-Kit ist baubar: %s" % ", ".join(build.validate()))
	var unit := Unit.create(build, &"P0", true)
	var dash := _dash_action(unit)
	t.ok(dash != null, "der Hologramm-Boost bringt eine Bewegungs-Aktion mit")
	t.equal(dash.range_tiles, 3, "sie reicht drei Felder weit")
	t.ok(dash.category == ActionData.Category.ABILITY, "und ist eine Faehigkeit")
	unit.free()


func test_open_ground_offers_three_tiles_in_each_direction() -> void:
	var grid := Grid.new(12, 12)
	var unit := Unit.create(_vireo(), &"P0", true)
	unit.tile = Vector2i(5, 5)
	grid.set_occupant(unit.tile, unit.unit_id)
	var resolver := ActionResolver.new(grid, [unit])
	var dash := _dash_action(unit)

	var landings := resolver.dash_landings(unit, dash)
	# Vier Richtungen x drei Felder = zwoelf Landefelder auf freiem Feld.
	t.equal(landings.size(), 12, "freies Feld: zwoelf Landefelder")
	for tile in [Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5),
			Vector2i(5, 2), Vector2i(2, 5)]:
		t.ok(tile in landings, "%s ist erreichbar" % tile)
	# Nichts Diagonales, nichts jenseits von drei Feldern.
	t.ok(not (Vector2i(6, 6) in landings), "keine Diagonale")
	t.ok(not (Vector2i(9, 5) in landings), "nichts jenseits von drei Feldern")
	unit.free()


func test_another_drome_blocks_the_lane() -> void:
	var grid := Grid.new(12, 12)
	var unit := Unit.create(_vireo(), &"P0", true)
	var blocker := Unit.create(_vireo(), &"E0", false)
	unit.tile = Vector2i(5, 5)
	blocker.tile = Vector2i(6, 5)
	grid.set_occupant(unit.tile, unit.unit_id)
	grid.set_occupant(blocker.tile, blocker.unit_id)
	var resolver := ActionResolver.new(grid, [unit, blocker])
	var dash := _dash_action(unit)

	var landings := resolver.dash_landings(unit, dash)
	t.ok(not (Vector2i(6, 5) in landings), "nicht auf einen anderen DROME")
	t.ok(not (Vector2i(7, 5) in landings), "und nicht durch ihn hindurch")
	# Die anderen Richtungen bleiben frei.
	t.ok(Vector2i(4, 5) in landings, "die Gegenrichtung ist offen")
	unit.free()
	blocker.free()


func test_executing_the_dash_moves_the_drome() -> void:
	var grid := Grid.new(12, 12)
	var unit := Unit.create(_vireo(), &"P0", true)
	unit.tile = Vector2i(5, 5)
	grid.set_occupant(unit.tile, unit.unit_id)
	var resolver := ActionResolver.new(grid, [unit])
	var dash := _dash_action(unit)

	t.ok(resolver.execute(unit, Vector2i(8, 5), dash), "der Boost geht raus")
	t.equal(unit.tile, Vector2i(8, 5), "der DROME steht jetzt drei Felder weiter")
	t.equal(grid.occupant(Vector2i(8, 5)), unit.unit_id, "das Landefeld ist belegt")
	t.equal(grid.occupant(Vector2i(5, 5)), null, "das Startfeld ist frei")
	unit.free()


func test_target_blocker_names_the_reason() -> void:
	var grid := Grid.new(12, 12)
	var unit := Unit.create(_vireo(), &"P0", true)
	unit.tile = Vector2i(5, 5)
	grid.set_occupant(unit.tile, unit.unit_id)
	var resolver := ActionResolver.new(grid, [unit])
	var dash := _dash_action(unit)

	t.equal(resolver.target_blocker(unit, Vector2i(8, 5), dash), "",
		"ein gueltiges Landefeld hat keinen Grund")
	t.equal(resolver.target_blocker(unit, Vector2i(7, 7), dash), "Nur in gerader Linie",
		"eine Diagonale nennt den Grund")
	t.equal(resolver.target_blocker(unit, Vector2i(9, 5), dash), "Zu weit fuer den Boost",
		"jenseits der Reichweite ebenso")
	unit.free()


func test_the_boost_fires_when_an_enemy_stands_next_to_it() -> void:
	# Der Ausloeser "Gegner direkt daneben": im Kampf kommt er erst wieder vor,
	# wenn es Nahkampfwaffen gibt, deshalb hier gestellt.
	var battle := BattleManager.new()
	battle.setup(4711, [_vireo()], [_vireo()])
	var unit: Unit = battle.units[0]
	var foe: Unit = battle.units[1]
	for u in [unit, foe]:
		battle.grid.clear_occupant(u.tile)
	unit.place_at(Vector2i(10, 10))
	foe.place_at(Vector2i(10, 9))
	for u in [unit, foe]:
		battle.grid.set_occupant(u.tile, u.unit_id)
	var used := []
	var record := func(who, _tile, action): if who == unit: used.append(action.id)
	EventBus.action_used.connect(record)
	unit.target_id = foe.unit_id
	battle.brain.update(unit, battle.step_seconds())
	EventBus.action_used.disconnect(record)
	t.ok(&"act_holo_dash" in used, "der Boost springt weg (%s)" % str(used))
	t.ok(Grid.distance(unit.tile, foe.tile) > 1, "und danach steht niemand mehr daneben")
	battle.free()
