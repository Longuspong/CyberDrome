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


# ---------------------------------------------------------------------------
# Nimbus: Runenstab, Vortex, Zauberwirker
# ---------------------------------------------------------------------------

func _action(unit: Unit, id: StringName) -> ActionData:
	for action in unit.actions():
		if action.id == id:
			return action
	return null


func test_the_rune_staff_hits_one_target_at_blaster_range() -> void:
	var unit := Unit.create(_nimbus(), &"N", true)
	var vireo := Unit.create(_vireo(), &"V", true)
	var staff := _action(unit, &"act_runestaff")
	var blaster := _action(vireo, &"act_pulse")
	t.equal(staff.range_tiles, blaster.range_tiles, "Runenstab reicht so weit wie der Blaster")
	t.equal(staff.aoe_radius, 0, "und trifft immer nur ein Ziel")
	var vortex := _action(unit, &"act_rune_vortex")
	t.equal(int(vortex.trigger_every), 5, "nach vier normalen Angriffen kommt der Vortex")
	unit.free()
	vireo.free()


func test_the_vortex_gathers_then_strikes_then_slows() -> void:
	# Ziel in der Mitte, zwei Gegner im Umkreis 2. Der Sog zieht sie heran,
	# der Schaden kommt erst nach der Verzoegerung, danach sind sie langsamer.
	var tiles := [Vector2i(10, 16), Vector2i(10, 12), Vector2i(12, 12), Vector2i(10, 10)]
	var battle := _battle([_nimbus()], [_vireo(), _vireo(), _vireo()], tiles)
	var nimbus: Unit = battle.units[0]
	var center: Unit = battle.units[1]
	var side: Unit = battle.units[2]
	var back: Unit = battle.units[3]
	for u in [center, side, back]:
		u.shield = 0
	nimbus.place_at(Vector2i(10, 15))
	battle.grid.clear_occupant(Vector2i(10, 16))
	battle.grid.set_occupant(nimbus.tile, nimbus.unit_id)
	var vortex := _action(nimbus, &"act_rune_vortex")
	var hp_before := side.hp
	var speed_before := side.move_speed()

	t.ok(battle.resolver.execute(nimbus, center.tile, vortex), "der Vortex geht raus")
	t.ok(Grid.distance(side.tile, center.tile) <= 1, "der seitliche Gegner wird herangezogen (%s)" % side.tile)
	t.ok(Grid.distance(back.tile, center.tile) <= 1, "der hintere ebenso (%s)" % back.tile)
	t.equal(side.hp, hp_before, "Schaden gibt es noch nicht -- erst die Schockwelle")

	var steps := int(ceil(vortex.delay / battle.step_seconds())) + 1
	for i in steps:
		battle.resolver.advance(battle.step_seconds())
	t.ok(side.hp < hp_before, "nach %.1f s schlaegt die Schockwelle zu" % vortex.delay)
	t.ok(center.hp < center.stat("hp_max"), "auch das Ziel in der Mitte")
	t.ok(side.move_speed() < speed_before, "und die Getroffenen sind verlangsamt")
	t.equal(nimbus.hp, nimbus.stat("hp_max"), "der Nimbus selbst bleibt heil")
	battle.free()


func test_the_spellcaster_halves_the_wait_after_an_ability() -> void:
	var battle := _battle([_nimbus(), _vireo()], [_vireo()],
		[Vector2i(4, 16), Vector2i(6, 16), Vector2i(10, 4)])
	var nimbus: Unit = battle.units[0]
	var vireo: Unit = battle.units[1]
	var vortex := _action(nimbus, &"act_rune_vortex")
	var scatter := _action(vireo, &"act_pulse_double")
	t.equal(nimbus.passive(), "spellcaster", "der Nimbus ist Zauberwirker")
	# Vortex: vier normale Angriffe, danach nur noch zwei.
	t.equal(int(vortex.trigger_every) - 1 - battle.brain._count_after_ability(nimbus, vortex), 2,
		"nach dem Vortex braucht er zwei statt vier Angriffe")
	# Blaster am Nimbus: zwei normale, danach einer (Doppelschuss, Schuss, Doppelschuss).
	t.equal(int(scatter.trigger_every) - 1 - battle.brain._count_after_ability(nimbus, scatter), 1,
		"mit dem Blaster: Doppelschuss, ein Schuss, Doppelschuss")
	t.equal(battle.brain._count_after_ability(vireo, scatter), 0,
		"ohne die Passive beginnt die Zaehlung von vorn")
	battle.free()


func test_a_nimbus_casts_more_often_than_its_staff_alone_would() -> void:
	# Im Kampf: nach dem ersten Vortex kommt jeder weitere nach zwei Angriffen.
	var seq := []
	var record := func(unit, _tile, action):
		if unit.display_name == "Nimbus" and unit.is_player:
			seq.append(action.id)
	EventBus.action_used.connect(record)
	var battle := BattleManager.new()
	battle.setup(6060, [_nimbus(), _molok()], [_molok(), _molok()])
	battle.run_to_end(40.0)
	battle.free()
	EventBus.action_used.disconnect(record)
	var first := seq.find(&"act_rune_vortex")
	t.ok(first == 4, "der erste Vortex nach vier Angriffen (Folge %s)" % str(seq.slice(0, 8)))
	if first >= 0 and seq.size() > first + 3:
		t.equal(seq[first + 3], &"act_rune_vortex", "der naechste schon nach zwei Angriffen")


# ---------------------------------------------------------------------------
# Vireo: Doppelschuss und Sprint
# ---------------------------------------------------------------------------

func test_the_double_shot_splits_over_two_foes() -> void:
	var tiles := [Vector2i(10, 12), Vector2i(10, 10), Vector2i(11, 10)]
	var battle := _battle([_vireo()], [_molok(), _molok()], tiles)
	var vireo: Unit = battle.units[0]
	var first: Unit = battle.units[1]
	var second: Unit = battle.units[2]
	var double := _action(vireo, &"act_pulse_double")
	var s1 := first.shield + first.hp
	var s2 := second.shield + second.hp
	t.ok(battle.resolver.execute(vireo, first.tile, double), "der Doppelschuss geht raus")
	t.ok(first.shield + first.hp < s1, "das Ziel wird getroffen")
	t.ok(second.shield + second.hp < s2, "und der zweite Gegner in Reichweite auch")
	battle.free()


func test_the_double_shot_hits_a_lone_foe_twice() -> void:
	var tiles := [Vector2i(10, 12), Vector2i(10, 10)]
	var battle := _battle([_vireo()], [_molok()], tiles)
	var vireo: Unit = battle.units[0]
	var foe: Unit = battle.units[1]
	var double := _action(vireo, &"act_pulse_double")
	var hits := []
	var record := func(target, _amount, source): if source == vireo: hits.append(target)
	EventBus.unit_damaged.connect(record)
	battle.resolver.execute(vireo, foe.tile, double)
	EventBus.unit_damaged.disconnect(record)
	t.equal(hits.size(), 2, "allein in Reichweite: zwei Treffer")
	battle.free()


func test_a_hit_makes_the_vireo_sprint() -> void:
	var tiles := [Vector2i(10, 12), Vector2i(10, 10)]
	var battle := _battle([_vireo()], [_molok()], tiles)
	var vireo: Unit = battle.units[0]
	var foe: Unit = battle.units[1]
	t.equal(vireo.passive(), "hit_rush", "der Vireo hat die Sprint-Passive")
	var before := vireo.move_speed()
	battle.resolver.execute(vireo, foe.tile, _action(vireo, &"act_pulse"))
	t.ok(vireo.move_speed() > before * 1.3, "nach dem Treffer laeuft er schneller (%.2f -> %.2f)"
		% [before, vireo.move_speed()])
	var seconds := float((Config.section("passives").get("hit_rush", {}) as Dictionary).get("seconds", 2.0))
	vireo.tick_statuses(seconds + 0.1)
	t.ok(is_equal_approx(vireo.move_speed(), before), "nach %.0f s ist es vorbei" % seconds)
	battle.free()
