extends RefCounted

## Statuseffekte, Effizienz und Kabelbrand (20. Nov. 2026,
## docs/MODULE_AMP_FUSION.md 5).

var t


func _vireo(weapon: StringName = &"eq_boomerang") -> DromeBuild:
	return DromeBuild.create("Vireo", {"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core", "equip_left": weapon})


func _molok() -> DromeBuild:
	return DromeBuild.create("Molok", {"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core", "equip_left": &"eq_hammer"})


func _battle() -> BattleManager:
	var battle := BattleManager.new()
	battle.setup(4711, [_vireo()], [_molok()])
	return battle


func _rule(key: String) -> int:
	return int((Config.section("statuses").get("cable_fire", {}) as Dictionary).get(key, 0))


func test_efficiency_is_a_chassis_stat() -> void:
	var battle := _battle()
	var vireo: Unit = battle.units[0]
	t.equal(vireo.efficiency(), 10, "Vireo: Effizienz 10")
	t.ok(is_equal_approx(vireo.efficiency_factor(), 1.0), "entspricht 100 %")
	t.equal(int(_molok().stats()["efficiency"]), 14, "Molok: Effizienz 14")
	var nimbus := DromeBuild.create("Nimbus", {"body": &"mage_body", "head": &"mage_head",
		"feet": &"mage_drive", "core": &"mage_core", "equip_left": &"eq_rune_staff"})
	t.equal(int(nimbus.stats()["efficiency"]), 12, "Nimbus: Effizienz 12 (Allrounder)")
	var neon := DromeBuild.new()
	neon.stat_override = {"power": 14, "efficiency": 7}
	t.equal(int(neon.stats()["efficiency"]), 7, "feste Werte (Neon Nimbus) gehen vor")
	var bare := DromeBuild.new()
	t.equal(int(bare.stats()["efficiency"]), 10, "ohne Wert: Grundwert 10")
	battle.free()


func test_efficiency_stretches_the_duration() -> void:
	var battle := _battle()
	var vireo: Unit = battle.units[0]
	var molok: Unit = battle.units[1]
	molok.apply_status(&"slow", 2.5, {"move_mult": 0.6}, vireo)
	t.ok(is_equal_approx(float(molok.statuses[&"slow"]["seconds_left"]), 2.5), "Effizienz 10: 2,5 s")
	vireo.stats["efficiency"] = 12
	molok.apply_status(&"slow", 2.5, {"move_mult": 0.6}, vireo)
	t.ok(is_equal_approx(float(molok.statuses[&"slow"]["seconds_left"]), 3.0), "Effizienz 12: 20 % länger")
	molok.apply_status(&"stun", 1.0, {"stunned": true})
	t.ok(is_equal_approx(float(molok.statuses[&"stun"]["seconds_left"]), 1.0), "ohne Auslöser unverändert")
	battle.free()


func test_cyberspeed_lasts_longer_with_efficiency() -> void:
	var battle := _battle()
	var vireo: Unit = battle.units[0]
	vireo.stats["efficiency"] = 15
	vireo.on_attack()
	var seconds := float((Config.section("passives").get("cyberspeed", {}) as Dictionary).get("seconds", 3.0))
	t.ok(is_equal_approx(vireo.cyberspeed_left, seconds * 1.5), "Cyberspeed hält 50 % länger")
	battle.free()


func test_the_whirl_throw_sets_cable_fire() -> void:
	var battle := _battle()
	var vireo: Unit = battle.units[0]
	var molok: Unit = battle.units[1]
	var whirl: ActionData = vireo.mounts[0]["ability"]
	t.equal(str(whirl.status.get("id", "")), "cable_fire", "Wirbelwurf trägt Kabelbrand")
	battle.resolver.apply_action_status(vireo, molok, whirl)
	t.equal(molok.cable_fire_stacks(), 1, "ein Stapel je getroffenem Gegner")
	t.ok(molok.status_names().has("cable_fire"), "sichtbar als Zustand")
	t.ok(whirl.status_text().begins_with("Kabelbrand"), "Klartext: %s" % whirl.status_text())
	battle.free()


func test_efficiency_adds_fractional_stacks() -> void:
	var battle := _battle()
	var vireo: Unit = battle.units[0]
	var molok: Unit = battle.units[1]
	vireo.stats["efficiency"] = 15
	molok.add_cable_fire(1.0, vireo)
	t.equal(molok.cable_fire_stacks(), 1, "1,5 Stapel: einer zählt")
	molok.add_cable_fire(1.0, vireo)
	t.equal(molok.cable_fire_stacks(), 3, "zweimal 1,5 = 3")
	battle.free()


func test_a_pulse_burns_at_most_ten_stacks_and_keeps_the_rest() -> void:
	var battle := _battle()
	var vireo: Unit = battle.units[0]
	var molok: Unit = battle.units[1]
	var cap := _rule("max_per_pulse")
	molok.add_cable_fire(float(cap + 3), vireo)
	var hp := molok.hp
	var shield := molok.shield
	var dealt := battle.resolver.burn_cable_fire(molok)
	t.equal(molok.cable_fire_stacks(), 3, "%d verbraucht, 3 bleiben liegen" % cap)
	t.ok(dealt > 0 and dealt <= cap * (_rule("kinetic") + _rule("energy")),
		"Schaden %d (höchstens %d)" % [dealt, cap * (_rule("kinetic") + _rule("energy"))])
	t.equal(dealt, (hp - molok.hp) + (shield - molok.shield), "Schaden landet auf Schild und Integrität")
	battle.resolver.burn_cable_fire(molok)
	t.equal(molok.cable_fire_stacks(), 0, "der nächste Puls verbraucht den Rest")
	t.equal(battle.resolver.burn_cable_fire(molok), 0, "ohne Stapel kein Schaden")
	battle.free()


func test_cable_fire_ignores_power() -> void:
	var battle := _battle()
	var vireo: Unit = battle.units[0]
	var molok: Unit = battle.units[1]
	molok.shield = 0
	molok.add_cable_fire(1.0, vireo)
	var first := battle.resolver.burn_cable_fire(molok)
	vireo.stats["power"] = int(vireo.stats["power"]) * 3
	molok.add_cable_fire(1.0, vireo)
	t.equal(battle.resolver.burn_cable_fire(molok), first, "dreifache Power, gleicher Brandschaden")
	battle.free()


func test_a_battle_with_cable_fire_still_ends() -> void:
	var battle := BattleManager.new()
	battle.setup(5003, [_vireo(), _vireo()], [_molok()])
	battle.run_to_end()
	t.ok(battle.outcome != BattleManager.Outcome.RUNNING, "Kampf endet")
	battle.free()


func test_efficiency_also_raises_the_strength() -> void:
	var battle := _battle()
	var vireo: Unit = battle.units[0]
	var molok: Unit = battle.units[1]
	vireo.stats["efficiency"] = 12
	molok.apply_status(&"slow", 2.5, {"move_mult": 0.6}, vireo)
	t.ok(is_equal_approx(float(molok.statuses[&"slow"]["move_mult"]), 0.52), "40 % -> 48 % langsamer")
	vireo.stats["efficiency"] = 40
	molok.apply_status(&"slow", 2.5, {"move_mult": 0.6}, vireo)
	t.ok(is_equal_approx(float(molok.statuses[&"slow"]["move_mult"]), 0.3), "höchstens 70 % langsamer")
	molok.apply_status(&"slow", 2.5, {"move_mult": 0.6})
	t.ok(is_equal_approx(float(molok.statuses[&"slow"]["move_mult"]), 0.6), "ohne Auslöser unverändert")
	battle.free()


func _nimbus() -> DromeBuild:
	return DromeBuild.create("Nimbus", {"body": &"mage_body", "head": &"mage_head",
		"feet": &"mage_drive", "core": &"mage_core", "equip_left": &"eq_rune_staff"})


## Vortex wie ein schwarzes Loch (24. Nov. 2026, Vorgabe des Spielers): der
## Naechste kommt aufs Zielfeld, die anderen so weit es in ihrer Richtung
## geht; bis zur Schockwelle festgehalten (kein Laufen, kein Schiessen),
## danach frei und verlangsamt.
func test_the_vortex_pulls_like_a_black_hole() -> void:
	var battle := BattleManager.new()
	battle.setup(4711, [_nimbus()], [_molok(), _molok()])
	var nimbus: Unit = battle.units[0]
	var a: Unit = battle.units[1]
	var b: Unit = battle.units[2]
	var center := Vector2i(4, 6)
	battle.resolver.move_unit(nimbus, Vector2i(4, 12))
	# Das Ziel ist schon ein Feld weiter, ein zweites steht zwei Felder weg.
	battle.resolver.move_unit(a, Grid.neighbor(center, 3))
	battle.resolver.move_unit(b, Grid.neighbor(Grid.neighbor(center, 0), 0))
	var vortex: ActionData = nimbus.mounts[0]["ability"]
	t.ok(vortex.gather and vortex.delay > 0.0, "Vortex zieht und schlaegt verzoegert ein")
	t.ok(battle.resolver.execute(nimbus, center, vortex, true), "Vortex geworfen")
	t.equal(a.tile, center, "der Naechste landet auf dem Zielfeld")
	t.equal(Grid.distance(b.tile, center), 1, "der Zweite direkt daneben (2 Felder gezogen)")
	t.ok(a.is_stunned() and b.is_stunned(), "beide festgehalten: kein Laufen, kein Schiessen")
	t.ok(not nimbus.is_stunned(), "der Werfer nicht")
	t.ok(not b.status_names().has("vortex_hold"), "kein eigenes Symbol")
	for i in int(ceil((vortex.delay + 0.05) / 0.05)):
		battle.resolver.advance(0.05)
	t.ok(not a.is_stunned() and not b.is_stunned(), "nach dem Einschlag wieder frei")
	t.ok(a.statuses.has(&"slow") and b.statuses.has(&"slow"), "und verlangsamt")
	battle.free()


## Bugfix 24. Nov. 2026: ein Treffer auf den Schild meldet sich eigens.
func test_a_shield_hit_is_reported() -> void:
	var battle := _battle()
	var vireo: Unit = battle.units[0]
	var molok: Unit = battle.units[1]
	molok.shield = 50
	var seen := []
	var hook := func(unit, amount, _source): seen.append([unit, amount])
	EventBus.shield_damaged.connect(hook)
	battle.resolver.apply_damage(vireo, molok, 10, vireo.mounts[0]["attack"])
	EventBus.shield_damaged.disconnect(hook)
	t.equal(seen.size(), 1, "eine Meldung")
	t.ok(not seen.is_empty() and seen[0][0] == molok and int(seen[0][1]) > 0, "mit dem geschluckten Schaden")
	battle.free()
