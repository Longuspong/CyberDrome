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


func test_every_drome_starts_with_efficiency_ten() -> void:
	var battle := _battle()
	for unit in battle.units:
		t.equal(unit.efficiency(), 10, "%s: Effizienz 10" % unit.display_name)
		t.ok(is_equal_approx(unit.efficiency_factor(), 1.0), "entspricht 100 %")
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


func test_the_vireo_sprint_uses_its_own_efficiency() -> void:
	var battle := _battle()
	var vireo: Unit = battle.units[0]
	var molok: Unit = battle.units[1]
	vireo.stats["efficiency"] = 15
	battle.resolver.apply_damage(vireo, molok, 5, vireo.mounts[0]["attack"])
	var rush := float((Config.section("passives").get("hit_rush", {}) as Dictionary).get("seconds", 2.0))
	t.ok(vireo.statuses.has(&"rush"), "Treffer löst den Sprint aus")
	t.ok(is_equal_approx(float(vireo.statuses[&"rush"]["seconds_left"]), rush * 1.5), "Sprint 50 % länger")
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
