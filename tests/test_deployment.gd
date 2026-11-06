extends RefCounted

## Aufstellung vor dem Kampf (Wunsch des Spielers, Nov. 2026): eine Zone von
## 3 x 5 Feldern unten links, darin zieht der Spieler seine DROMEs zurecht.
## Ohne sein Zutun stellt die Aufstellung nach Rolle auf: Molok vorn, Strix
## hinten.

var t


func _squad() -> Array:
	return [
		DromeBuild.create("Strix", {"body": &"strix_body", "head": &"strix_head",
			"feet": &"strix_feet", "core": &"strix_core", "equip_center": &"eq_rail_lance"}),
		DromeBuild.create("Vireo", {"body": &"scout_body", "head": &"scout_head",
			"feet": &"scout_feet", "core": &"scout_core", "equip_left": &"eq_pulse_blaster"}),
		DromeBuild.create("Molok", {"body": &"jugg_body", "head": &"jugg_head",
			"feet": &"jugg_feet", "core": &"jugg_core", "equip_left": &"eq_hammer"}),
	]


func _unit(battle: BattleManager, name: String, player: bool) -> Unit:
	for unit in battle.units:
		if unit.display_name == name and unit.is_player == player:
			return unit
	return null


func test_the_zone_is_three_by_five() -> void:
	var battle := BattleManager.new()
	battle.setup(321, _squad(), _squad())
	var zone := battle.deployment_tiles(true)
	t.equal(zone.size(), 15, "15 Felder")
	var xs := {}
	var ys := {}
	for tile in zone:
		xs[tile.x] = true
		ys[tile.y] = true
	t.equal(xs.size() * ys.size(), 15, "ein Rechteck 3 x 5")
	for unit in battle.units:
		t.ok(unit.tile in battle.deployment_tiles(unit.is_player),
			"%s steht in seiner Zone" % unit.display_name)
	battle.free()


func test_the_default_puts_the_tank_in_front_and_the_sniper_behind() -> void:
	var battle := BattleManager.new()
	battle.setup(322, _squad(), _squad())
	for side in [true, false]:
		var zone := battle.deployment_tiles(side)
		var molok := _unit(battle, "Molok", side)
		var strix := _unit(battle, "Strix", side)
		t.ok(zone.find(molok.tile) < zone.find(strix.tile),
			"der Molok steht weiter vorn als der Strix (%s)" % ("Spieler" if side else "Gegner"))
	battle.free()


func test_placing_moves_and_swaps_within_the_zone() -> void:
	var battle := BattleManager.new()
	battle.setup(323, _squad(), _squad())
	var zone := battle.deployment_tiles(true)
	var strix := _unit(battle, "Strix", true)
	var molok := _unit(battle, "Molok", true)
	var free_tile: Vector2i = Vector2i(-1, -1)
	for tile in zone:
		if not battle.grid.is_occupied(tile):
			free_tile = tile
			break
	t.ok(battle.place_unit(strix, free_tile), "auf ein freies Feld der Zone")
	t.equal(strix.tile, free_tile, "der Strix steht dort")
	t.equal(battle.grid.occupant(free_tile), strix.unit_id, "und das Gitter weiss es")

	var molok_tile := molok.tile
	t.ok(battle.place_unit(strix, molok_tile), "auf einen eigenen DROME: tauschen")
	t.equal(strix.tile, molok_tile, "der Strix steht auf dem Feld des Molok")
	t.equal(molok.tile, free_tile, "der Molok auf dem des Strix")

	t.ok(not battle.place_unit(strix, Vector2i(10, 10)), "ausserhalb der Zone nicht")
	var foe := _unit(battle, "Molok", false)
	t.ok(not battle.place_unit(strix, foe.tile), "und nicht in die gegnerische Zone")
	battle.free()


func test_a_formation_is_remembered_and_restored() -> void:
	var battle := BattleManager.new()
	battle.setup(324, _squad(), _squad())
	var zone := battle.deployment_tiles(true)
	var strix := _unit(battle, "Strix", true)
	battle.place_unit(strix, zone[zone.size() - 1])
	var saved := battle.formation(true)
	battle.free()

	var again := BattleManager.new()
	again.setup(325, _squad(), _squad())
	again.apply_formation(saved)
	t.equal(again.formation(true), saved, "die gemerkte Aufstellung kommt wieder")
	again.free()


func test_no_placing_once_the_fight_runs() -> void:
	var battle := BattleManager.new()
	battle.setup(326, _squad(), _squad())
	battle.tick()
	var zone := battle.deployment_tiles(true)
	var strix := _unit(battle, "Strix", true)
	var target: Vector2i = zone[zone.size() - 1] if zone[zone.size() - 1] != strix.tile else zone[0]
	t.ok(not battle.place_unit(strix, target), "nach dem Start wird nicht mehr umgestellt")
	battle.free()
