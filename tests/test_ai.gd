extends RefCounted

## Die KI im Echtzeit-Kampf: Ziel halten, Verhalten je DROME, Fokus.
##
## Wunsch des Spielers (Nov. 2026): wer ein Ziel hat, greift es erst einmal
## an; ein Molok rennt nie weg; ein Strix laeuft nicht dauernd davon; der
## Nimbus wartet hinter der Frontlinie; das Team kaempft gemeinsam.

var t


func _vireo() -> DromeBuild:
	return DromeBuild.create("Vireo", {"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core", "equip_left": &"eq_pulse_blaster"})


func _molok() -> DromeBuild:
	return DromeBuild.create("Molok", {"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core", "equip_left": &"eq_siege_cannon"})


func _nimbus() -> DromeBuild:
	return DromeBuild.create("Nimbus", {"body": &"mage_body", "head": &"mage_head",
		"feet": &"mage_drive", "core": &"mage_core", "equip_left": &"eq_rune_staff"})


func _strix() -> DromeBuild:
	return DromeBuild.create("Strix", {"body": &"strix_body", "head": &"strix_head",
		"feet": &"strix_feet", "core": &"strix_core", "equip_center": &"eq_rail_lance"})


## Ein Kampf mit festen Seiten; danach stehen alle DROMEs dort, wo ``tiles``
## sie hinsetzt (in der Reihenfolge Spieler, dann Gegner).
func _battle(players: Array, enemies: Array, tiles: Array) -> BattleManager:
	var battle := BattleManager.new()
	battle.setup(4711, players, enemies)
	for i in battle.units.size():
		var unit: Unit = battle.units[i]
		battle.grid.clear_occupant(unit.tile)
	for i in battle.units.size():
		var unit: Unit = battle.units[i]
		unit.place_at(tiles[i])
		battle.grid.set_occupant(tiles[i], unit.unit_id)
	return battle


func test_every_chassis_names_its_role() -> void:
	t.equal(Unit.create(_vireo(), &"A", true).ai_role(), "skirmisher", "Vireo ist wendig")
	t.equal(Unit.create(_molok(), &"B", true).ai_role(), "vanguard", "Molok ist Frontlinie")
	t.equal(Unit.create(_nimbus(), &"C", true).ai_role(), "controller", "Nimbus ist Kontrolle")
	t.equal(Unit.create(_strix(), &"D", true).ai_role(), "sniper", "Strix ist Scharfschuetze")


func test_a_molok_with_a_cannon_never_backs_off() -> void:
	# Frueher hing die Rolle an der Waffenreichweite: mit der Kanone (Rw 6)
	# galt der Molok als Fernkaempfer und wich jedem aus, der naeher kam.
	var battle := _battle([_molok()], [_nimbus()], [Vector2i(10, 10), Vector2i(10, 9)])
	var molok: Unit = battle.units[0]
	var foe: Unit = battle.units[1]
	t.equal(battle.brain.next_step(molok, foe), molok.tile,
		"der Molok bleibt stehen, auch wenn der Gegner direkt danebensteht")
	battle.free()


func test_a_strix_holds_and_only_steps_away_from_contact() -> void:
	var battle := _battle([_strix()], [_vireo()], [Vector2i(10, 10), Vector2i(10, 8)])
	var strix: Unit = battle.units[0]
	var foe: Unit = battle.units[1]
	t.equal(battle.brain.next_step(strix, foe), strix.tile,
		"zwei Felder Abstand: der Strix haelt seine Stellung")
	battle.free()

	battle = _battle([_strix()], [_vireo()], [Vector2i(10, 10), Vector2i(10, 9)])
	strix = battle.units[0]
	foe = battle.units[1]
	var step := battle.brain.next_step(strix, foe)
	t.ok(Grid.distance(step, foe.tile) > 1,
		"steht jemand direkt daneben, geht er einen Schritt weg (%s)" % step)
	battle.free()


func test_a_controller_waits_until_the_frontline_fights() -> void:
	var tiles := [Vector2i(10, 15), Vector2i(12, 15), Vector2i(10, 4)]
	var battle := _battle([_nimbus(), _molok()], [_vireo()], tiles)
	var nimbus: Unit = battle.units[0]
	var foe: Unit = battle.units[2]
	t.equal(battle.brain.next_step(nimbus, foe), nimbus.tile,
		"solange der Molok niemanden trifft, wartet der Nimbus")

	# Molok in Reichweite seiner Kanone: jetzt ist die Frontlinie im Kampf.
	var molok: Unit = battle.units[1]
	battle.grid.clear_occupant(molok.tile)
	molok.place_at(Vector2i(12, 8))
	battle.grid.set_occupant(molok.tile, molok.unit_id)
	t.ok(battle.brain.next_step(nimbus, foe) != nimbus.tile,
		"sobald die Frontlinie trifft, rueckt der Nimbus nach")
	battle.free()


func test_a_chosen_target_is_kept() -> void:
	# Zwei Gegner in Reichweite. Das Ziel bleibt, auch wenn der andere fuer
	# einen Augenblick attraktiver aussieht -- frueher wurde alle 0,5 s neu
	# gewaehlt, und ein DROME wechselte rund elfmal pro Minute.
	var tiles := [Vector2i(10, 10), Vector2i(10, 8), Vector2i(12, 10)]
	var battle := _battle([_vireo()], [_molok(), _strix()], tiles)
	var vireo: Unit = battle.units[0]
	var held: Unit = battle.units[1]
	var other: Unit = battle.units[2]
	vireo.target_id = held.unit_id
	other.shield = 0
	other.hp = other.stat("hp_max") / 2       # angeschlagen, aber kein Abschuss
	for i in 40:                                # zwei Sekunden
		for mount in vireo.mounts:
			mount["ready"] = 99.0                 # nicht schiessen, nur denken
		battle.brain.update(vireo, battle.step_seconds())
	t.equal(vireo.target_id, held.unit_id, "das Ziel wird gehalten")
	battle.free()


func test_a_sure_kill_in_range_takes_over() -> void:
	var tiles := [Vector2i(10, 10), Vector2i(10, 8), Vector2i(12, 10)]
	var battle := _battle([_vireo()], [_molok(), _strix()], tiles)
	var vireo: Unit = battle.units[0]
	var held: Unit = battle.units[1]
	var weak: Unit = battle.units[2]
	vireo.target_id = held.unit_id
	weak.shield = 0
	weak.hp = 1
	vireo.think_left = 0.0
	for mount in vireo.mounts:
		mount["ready"] = 99.0
	battle.brain.update(vireo, battle.step_seconds())
	t.equal(vireo.target_id, weak.unit_id, "ein sicherer Abschuss in Reichweite geht vor")
	battle.free()


func test_an_unreachable_target_is_given_up_after_a_while() -> void:
	var tiles := [Vector2i(2, 18), Vector2i(18, 1), Vector2i(4, 14)]
	var battle := _battle([_vireo()], [_molok(), _strix()], tiles)
	var vireo: Unit = battle.units[0]
	var far: Unit = battle.units[1]
	var near: Unit = battle.units[2]
	vireo.target_id = far.unit_id
	var limit := float(Config.section("realtime").get("retarget_after", 2.0))
	var steps := int(ceil((limit + 0.2) / battle.step_seconds()))
	for i in steps:
		vireo.step_left = 0.0
		vireo.tile = Vector2i(2, 18)              # nicht von der Stelle
		for mount in vireo.mounts:
			mount["ready"] = 99.0
		battle.brain.update(vireo, battle.step_seconds())
	t.equal(vireo.target_id, near.unit_id,
		"nach %.1f s ausser Reichweite nimmt er den erreichbaren Gegner" % limit)
	battle.free()


func test_allies_prefer_a_shared_target() -> void:
	# Zwei gleich gute Gegner: wer schon von einem Verbuendeten angegriffen
	# wird, bekommt den Fokus-Bonus.
	var tiles := [Vector2i(11, 12), Vector2i(11, 13), Vector2i(9, 9), Vector2i(13, 9)]
	var battle := _battle([_vireo(), _vireo()], [_vireo(), _vireo()], tiles)
	var a: Unit = battle.units[0]
	var b: Unit = battle.units[1]
	var left: Unit = battle.units[2]
	var right: Unit = battle.units[3]
	b.target_id = left.unit_id
	var picked := battle.brain.choose_target(a)
	t.equal(picked, left, "der Gegner, den der Verbuendete schon angreift, wird gewaehlt")
	b.target_id = right.unit_id
	t.equal(battle.brain.choose_target(a), right, "und umgekehrt")
	battle.free()
