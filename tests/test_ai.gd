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
		"feet": &"jugg_feet", "core": &"jugg_core", "equip_left": &"eq_hammer"})


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
		"solange der Molok niemanden trifft, geht der Nimbus nicht vor ihn")

	# Molok am Gegner (Hammer, Reichweite 1): jetzt ist die Frontlinie im Kampf.
	var molok: Unit = battle.units[1]
	battle.grid.clear_occupant(molok.tile)
	molok.place_at(Vector2i(10, 5))
	battle.grid.set_occupant(molok.tile, molok.unit_id)
	t.ok(battle.brain.next_step(nimbus, foe) != nimbus.tile,
		"sobald die Frontlinie trifft, rueckt der Nimbus nach")
	battle.free()


func test_a_controller_follows_behind_the_frontline() -> void:
	# Molok schon weiter vorn, aber noch ohne Treffer: der Nimbus steht nicht
	# rum, sondern rueckt nach -- bleibt aber hinter ihm.
	var tiles := [Vector2i(10, 15), Vector2i(10, 10), Vector2i(10, 4)]
	var battle := _battle([_nimbus(), _molok()], [_vireo()], tiles)
	var nimbus: Unit = battle.units[0]
	var molok: Unit = battle.units[1]
	var foe: Unit = battle.units[2]
	var step := battle.brain.next_step(nimbus, foe)
	t.ok(step != nimbus.tile, "der Nimbus rueckt hinter dem Molok nach")
	t.ok(Grid.distance(step, foe.tile) > Grid.distance(molok.tile, foe.tile),
		"und bleibt dabei hinter der Frontlinie (%s)" % step)
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
	# Zwei Strix, damit kein Locken (Molok-Praesenz) dazwischenfunkt.
	var tiles := [Vector2i(10, 10), Vector2i(10, 8), Vector2i(12, 10)]
	var battle := _battle([_vireo()], [_strix(), _strix()], tiles)
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
# Nimbus: Runenstab, Vortex, Echo
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
	# Seit 9. Nov. 2026 (Vorgabe des Spielers): Takt immer ueber Angriffe.
	t.equal(vortex.trigger_kind, "attacks", "der Vortex kommt nach Angriffen")
	t.equal(int(vortex.trigger_every), 3, "jeder 3. Angriff")
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


func test_echo_lengthens_the_takt_and_casts_twice() -> void:
	# Echo (Nimbus, 7. Nov. 2026): Takt 50 % laenger, Faehigkeit wirkt zweimal.
	var battle := _battle([_nimbus(), _vireo()], [_vireo()],
		[Vector2i(4, 16), Vector2i(6, 16), Vector2i(10, 4)])
	var nimbus: Unit = battle.units[0]
	var vireo: Unit = battle.units[1]
	var vortex := _action(nimbus, &"act_rune_vortex")
	var scatter := _action(vireo, &"act_pulse_double")
	t.equal(nimbus.passive(), "echo", "der Nimbus hat Echo")
	t.equal(vortex.trigger_kind, "attacks", "der Vortex loest nach Angriffen aus")
	t.equal(vortex.range_tiles, 5, "mit Reichweite 5")
	t.equal(battle.brain.trigger_every(nimbus, vortex), 4, "mit Echo jeder 4. statt jeder 3. Angriff")
	t.equal(battle.brain.trigger_every(nimbus, scatter), 4,
		"Blaster am Nimbus: jeder 4. statt jeder 3. Angriff")
	t.equal(battle.brain.trigger_every(vireo, scatter), 3, "ohne Echo bleibt es beim 3.")
	battle.free()


func test_echo_casts_the_vortex_twice_in_a_row() -> void:
	# Im Kampf: der Vortex kommt paarweise, zwischen den Paaren 4,5 s.
	var times := []
	var clock := {"battle": null}
	var record := func(unit, _tile, action):
		if unit.display_name == "Nimbus" and unit.is_player and action.id == &"act_rune_vortex":
			times.append(clock["battle"].time)
	EventBus.action_used.connect(record)
	var battle := BattleManager.new()
	clock["battle"] = battle
	battle.setup(6060, [_nimbus(), _molok()], [_molok(), _molok()])
	battle.run_to_end(40.0)
	battle.free()
	EventBus.action_used.disconnect(record)
	t.ok(times.size() >= 4, "der Nimbus zaubert mehrmals (%d)" % times.size())
	if times.size() >= 4:
		t.ok(is_equal_approx(times[0], times[1]), "Echo: zweimal im selben Augenblick")
		t.ok(times[2] - times[1] >= 4.45, "dann der volle Takt (%.2f s)" % (times[2] - times[1]))


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


# ---------------------------------------------------------------------------
# Plasmaklinge und Neon-Blaster
# ---------------------------------------------------------------------------

func _blade_vireo() -> DromeBuild:
	return DromeBuild.create("Klinge", {"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core", "equip_left": &"eq_plasma_blade"})


func _neon_vireo() -> DromeBuild:
	return DromeBuild.create("Neon", {"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core", "equip_left": &"eq_neon_blaster"})


func test_the_blade_is_a_faster_harder_kinetic_melee_weapon() -> void:
	var blade := _action(Unit.create(_blade_vireo(), &"K", true), &"act_plasma_slash")
	var shot := _action(Unit.create(_vireo(), &"V", true), &"act_pulse")
	t.equal(blade.range_tiles, 1, "Nahkampf")
	t.ok(blade.power > shot.power, "etwas mehr Schaden als der Blaster")
	t.ok(blade.interval < shot.interval, "und schneller")
	t.equal(blade.energy_fraction, 0.0, "rein kinetisch")


func test_the_rend_makes_the_target_vulnerable() -> void:
	var battle := _battle([_blade_vireo()], [_molok()], [Vector2i(10, 11), Vector2i(10, 10)])
	var vireo: Unit = battle.units[0]
	var foe: Unit = battle.units[1]
	foe.shield = 0
	var slash := _action(vireo, &"act_plasma_slash")
	var before := battle.resolver.preview_damage(vireo, foe, slash)
	battle.resolver.execute(vireo, foe.tile, _action(vireo, &"act_plasma_rend"))
	t.ok(foe.statuses.has(&"vulnerable"), "das Ziel ist verwundbar")
	var after := battle.resolver.preview_damage(vireo, foe, slash)
	t.ok(after >= int(floor(before * 1.4)), "und nimmt rund 50 %% mehr Schaden (%d -> %d)" % [before, after])
	foe.tick_statuses(5.1)
	t.equal(battle.resolver.preview_damage(vireo, foe, slash), before, "nach 5 s ist es vorbei")
	battle.free()


func test_the_neon_breaker_hits_shields_twice_as_hard() -> void:
	var battle := _battle([_neon_vireo(), _vireo()], [_strix()],
		[Vector2i(10, 13), Vector2i(11, 13), Vector2i(10, 10)])
	var neon: Unit = battle.units[0]
	var foe: Unit = battle.units[2]
	var breaker := _action(neon, &"act_neon_breaker")
	var plain := ActionData.from_meta({"id": "t", "power": breaker.power,
		"energy_fraction": breaker.energy_fraction, "range_tiles": 3})
	var full := foe.shield
	var normal_hit := full - int(battle.resolver.resolve_damage(foe, plain.power, plain.energy_fraction)["shield_after"])
	var breaker_hit := full - int(battle.resolver.resolve_damage(foe, breaker.power,
		breaker.energy_fraction, breaker.shield_mult)["shield_after"])
	t.ok(breaker_hit >= normal_hit * 2 - 1, "der Schildbrecher traegt doppelt so viel Schild ab (%d gegen %d)"
		% [breaker_hit, normal_hit])
	battle.free()



# ---------------------------------------------------------------------------
# Molok: Tankwerte, Praesenz, Hammer
# ---------------------------------------------------------------------------

func _hammer_molok() -> DromeBuild:
	return DromeBuild.create("Molok", {"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core", "equip_left": &"eq_hammer",
		"equip_right": &"eq_deflector"})


func test_the_molok_is_a_tank_with_little_shield() -> void:
	var stats := _hammer_molok().stats()
	# 8. Nov. 2026: 250 Integritaet, 50 Schild, Ruestung 10 (+ Deflektor).
	t.equal(stats["hp_max"], 270, "250 Integritaet + 20 vom Hammer")
	t.ok(stats["def"] >= 10, "viel Ruestung (%d)" % stats["def"])
	t.ok(_hammer_molok().is_valid(), "Hammer und Deflektor sind baubar")


func test_the_hammer_stuns_and_a_stunned_drome_does_nothing() -> void:
	var battle := _battle([_hammer_molok()], [_vireo()], [Vector2i(10, 11), Vector2i(10, 10)])
	var molok: Unit = battle.units[0]
	var foe: Unit = battle.units[1]
	battle.resolver.execute(molok, foe.tile, _action(molok, &"act_hammer_stun"))
	t.ok(foe.is_stunned(), "der Betaeubungsschlag betaeubt")
	var tile := foe.tile
	for mount in foe.mounts:
		mount["ready"] = 0.0
	var shield_before := molok.shield
	var hp_before := molok.hp
	foe.target_id = molok.unit_id
	battle.brain.update(foe, battle.step_seconds())
	t.equal(foe.tile, tile, "betaeubt laeuft er nicht")
	t.equal(molok.hp + molok.shield, hp_before + shield_before, "und schiesst nicht")
	foe.tick_statuses(1.1)
	t.ok(not foe.is_stunned(), "nach einer Sekunde ist es vorbei")
	battle.free()


func test_presence_takes_a_share_of_the_damage_aimed_at_allies() -> void:
	var tiles := [Vector2i(10, 12), Vector2i(11, 12), Vector2i(10, 8)]
	var battle := _battle([_hammer_molok(), _strix()], [_vireo()], tiles)
	var molok: Unit = battle.units[0]
	var strix: Unit = battle.units[1]
	var foe: Unit = battle.units[2]
	strix.shield = 0
	molok.shield = 0
	battle.resolver.apply_damage(foe, strix, 40, _action(foe, &"act_pulse"))
	t.ok(molok.hp < molok.stat("hp_max"), "der Molok faengt einen Teil ab")
	t.ok(strix.stat("hp_max") - strix.hp < 40, "der Strix nimmt weniger als den vollen Treffer")
	battle.free()


func test_presence_lures_nearby_foes() -> void:
	# Der Vireo hat einen Strix als Ziel; kommt er dem Molok zu nahe, greift
	# er den Molok an.
	var tiles := [Vector2i(10, 12), Vector2i(4, 4), Vector2i(10, 10)]
	var battle := _battle([_hammer_molok(), _strix()], [_vireo()], tiles)
	var molok: Unit = battle.units[0]
	var foe: Unit = battle.units[2]
	t.equal(battle.brain.lured_by(foe), molok, "zwei Felder vom Molok: gelockt")
	t.equal(battle.brain.choose_target(foe), molok, "und waehlt ihn als Ziel")
	foe.target_id = battle.units[1].unit_id
	foe.think_left = 0.0
	for mount in foe.mounts:
		mount["ready"] = 99.0
	battle.brain.update(foe, battle.step_seconds())
	t.equal(foe.target_id, molok.unit_id, "ein laufendes Ziel wird fuer den Locker aufgegeben")
	battle.free()


func test_each_role_picks_by_its_own_rule() -> void:
	# Ein naher, voller Vireo und ein ferner, angeschlagener Vireo.
	var tiles := [Vector2i(10, 14), Vector2i(12, 14), Vector2i(10, 12), Vector2i(13, 9)]
	var battle := _battle([_vireo(), _strix()], [_vireo(), _vireo()], tiles)
	var skirmisher: Unit = battle.units[0]
	var sniper: Unit = battle.units[1]
	var near: Unit = battle.units[2]
	var far: Unit = battle.units[3]
	t.equal(battle.brain.choose_target(skirmisher), near, "der Vireo nimmt den naechsten")
	far.damage_dealt = 80
	t.equal(battle.brain.choose_target(sniper), far, "der Strix den mit dem meisten Schaden in Reichweite")
	battle.free()


func test_the_strix_steadies_after_standing_still() -> void:
	# Passive "steady" (8. Nov. 2026): 4 s ohne Feldwechsel -> +20 % Schaden
	# und Reichweite; ein Schritt setzt zurueck.
	var battle := _battle([_strix()], [_vireo()], [Vector2i(2, 2), Vector2i(17, 17)])
	var strix: Unit = battle.units[0]
	var lance: ActionData = strix.mounts[0]["base_attack"]
	var plain := strix.raw_damage(lance)
	for _i in 70:   # 3,5 s
		strix.track_stillness(0.05)
	t.ok(not strix.steady, "nach 3,5 s noch nicht angelegt")
	for _i in 12:
		strix.track_stillness(0.05)
	t.ok(strix.steady, "nach 4 s angelegt")
	t.equal(strix.raw_damage(lance), int(round(plain * 1.2)), "+20 % Schaden")
	t.equal((strix.mounts[0]["attack"] as ActionData).range_tiles,
		lance.range_tiles + 2, "Reichweite 8 -> 10")
	strix.place_at(Vector2i(3, 2))
	strix.track_stillness(0.05)
	t.ok(not strix.steady, "ein Schritt setzt zurueck")
	t.equal((strix.mounts[0]["attack"] as ActionData).range_tiles, lance.range_tiles,
		"Reichweite wieder normal")
	battle.free()
