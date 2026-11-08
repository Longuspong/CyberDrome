extends RefCounted

## Module und Rezepte (NEUANFANG 6g): Katalog, Wirkung im Kampf, Lager.

var t


func _vireo(weapon: StringName = &"eq_pulse_blaster") -> DromeBuild:
	return DromeBuild.create("Vireo", {"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core", "equip_left": weapon})


func _molok() -> DromeBuild:
	return DromeBuild.create("Molok", {"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core", "equip_left": &"eq_hammer"})


func _with(build: DromeBuild, slot: String, ids: Array) -> DromeBuild:
	build.modules[slot] = ids.duplicate()
	return build


func _battle(players: Array, enemies: Array, tiles: Array) -> BattleManager:
	var battle := BattleManager.new()
	battle.setup(4711, players, enemies)
	for unit in battle.units:
		battle.grid.clear_occupant(unit.tile)
	for i in battle.units.size():
		var unit: Unit = battle.units[i]
		unit.place_at(tiles[i])
		battle.grid.set_occupant(tiles[i], unit.unit_id)
	return battle


func _stop_run() -> RunState:
	var run := RunState.start(77)
	run.phase = RunState.Phase.STOP
	return run


# ---------------------------------------------------------------------------
# Katalog
# ---------------------------------------------------------------------------

func test_the_catalog_has_three_classes_and_recipes() -> void:
	var classes := {}
	for module in ModuleData.base_modules():
		classes[module.klass] = true
		t.ok(not module.effect_lines().is_empty(), "%s sagt, was es tut" % module.display_name)
	t.equal(classes.keys().size(), 3, "Angriff, Abwehr, Taktik")
	t.ok(ModuleData.recipes().size() >= 1, "es gibt Rezepte")
	for recipe in ModuleData.recipes():
		for ingredient in recipe.from:
			t.ok(ModuleData.get_module(ingredient) != null,
				"%s: Zutat %s existiert" % [recipe.display_name, ingredient])


func test_every_module_has_its_own_symbol() -> void:
	var seen := {}
	for module in ModuleData.base_modules() + ModuleData.recipes():
		var icon: Texture2D = module.icon()
		t.ok(icon != null, "%s hat ein Symbol (assets/modules/%s.svg)" % [module.display_name, module.id])
		if icon != null:
			t.ok(icon.get_width() >= 128, "%s ist fein gerastert (%d px)" % [module.display_name, icon.get_width()])
		t.ok(not seen.has(module.short_name()), "%s: Kuerzel %s ist eindeutig" % [module.display_name, module.short_name()])
		seen[module.short_name()] = true


func test_a_recipe_sums_its_ingredients_and_adds_its_own_effect() -> void:
	var gun := ModuleData.get_module(&"mod_gunslinger")
	t.ok(gun != null and gun.is_recipe(), "Gunslinger ist ein Rezept")
	t.ok(is_equal_approx(float(gun.effects["attack_speed"]), 0.08), "Schnellfeuer steckt drin")
	t.equal(int(gun.effects["range"]), 1, "Langer Lauf steckt drin")
	t.ok(is_equal_approx(float(gun.effects["ricochet_chance"]), 0.2), "Doppellauf steckt drin")
	t.equal(int(gun.effects["field_shot_every"]), 5, "dazu jeder 5. Angriff quer uebers Feld")


func test_conditions_decide_whether_a_module_works() -> void:
	var barrel := ModuleData.get_module(&"mod_long_barrel")
	t.ok(barrel.fits(PartDB.get_part(&"eq_pulse_blaster")), "Langer Lauf am Blaster")
	t.ok(not barrel.fits(PartDB.get_part(&"eq_plasma_blade")), "nicht an der Klinge")
	var edge := ModuleData.get_module(&"mod_heavy_edge")
	t.ok(edge.fits(PartDB.get_part(&"eq_hammer")), "Wuchtkante am Hammer")
	t.ok(not edge.fits(PartDB.get_part(&"eq_rail_lance")), "nicht an der Lanze")
	t.ok(ModuleData.get_module(&"mod_armor_plate").fits(PartDB.get_part(&"eq_rail_lance")),
		"ohne Bedingung passt es ueberall")


func test_the_molok_has_fewer_module_slots() -> void:
	t.equal(ModuleData.slots_for(_vireo()), 3, "drei je Halter")
	t.equal(ModuleData.slots_for(_molok()), 2, "Molok zwei")


# ---------------------------------------------------------------------------
# Wirkung
# ---------------------------------------------------------------------------

func test_attack_modules_change_a_copy_of_the_weapon() -> void:
	var build := _with(_vireo(), "equip_left", [&"mod_long_barrel", &"mod_rapid_fire"])
	var unit := Unit.create(build, &"V", true)
	unit.init_realtime(0.0)
	var attack: ActionData = unit.mounts[0]["attack"]
	var original: ActionData = PartDB.get_part(&"eq_pulse_blaster").actions[0]
	t.equal(attack.range_tiles, original.range_tiles + 1, "eine Reichweite mehr")
	t.ok(is_equal_approx(attack.interval, original.interval / 1.08), "8 % schneller")
	t.equal(original.range_tiles, 3, "das Teil in der PartDB bleibt unveraendert")


func test_a_resting_module_does_nothing() -> void:
	var build := _with(_vireo(&"eq_plasma_blade"), "equip_left", [&"mod_long_barrel"])
	var unit := Unit.create(build, &"V", true)
	unit.init_realtime(0.0)
	t.equal((unit.mounts[0]["attack"] as ActionData).range_tiles, 1, "die Klinge bleibt Rw 1")
	t.ok(build.active_modules("equip_left").is_empty(), "das Modul ruht")


func test_the_takt_chip_brings_the_ability_one_attack_earlier() -> void:
	var build := _with(_vireo(), "equip_left", [&"mod_takt_chip"])
	var unit := Unit.create(build, &"V", true)
	unit.init_realtime(0.0)
	t.equal(unit.takt_every(unit.mounts[0]["ability"]), 2, "Doppelschuss jeder 2. statt 3.")
	t.equal(unit.takt_bars()[0]["segments"], 2, "die Takt-Leiste zeigt es")


func test_the_takt_chip_is_a_recipe_of_pointer_and_circuit() -> void:
	var chip := ModuleData.get_module(&"mod_takt_chip")
	t.ok(chip.is_recipe(), "Taktchip ist ein Rezept")
	t.equal(chip.from, [&"mod_pointer", &"mod_circuit"], "aus Zeiger und Schaltkreis")
	t.ok(is_equal_approx(float(chip.effects.get("takt_time", 0.0)), 0.2), "Zeit-Takt 20 % kuerzer")
	var metronome := ModuleData.get_module(&"mod_metronome")
	t.ok(metronome.parts().has(&"mod_takt_chip"), "der Taktgeber baut auf dem Taktchip auf")
	t.ok(metronome.effects.has("takt_cut"), "und uebernimmt seinen Takt")


func test_a_recipe_does_not_fit_next_to_a_recipe_containing_it() -> void:
	var run := _stop_run()
	var slot: String = run.squad[0].equip_slots()[0]
	run.storage.append_array([&"mod_metronome", &"mod_takt_chip"])
	t.ok(run.install_module(0, 0, slot), "Taktgeber eingesetzt")
	t.ok(not run.install_module(0, 0, slot), "Taktchip passt nicht daneben")


func test_retaliation_charges_the_next_strike() -> void:
	var brawler := _with(_molok(), "equip_left", [&"mod_brawler"])
	var battle := _battle([brawler], [_vireo(&"eq_plasma_blade")], [Vector2i(10, 10), Vector2i(10, 9)])
	var molok: Unit = battle.units[0]
	var blade: Unit = battle.units[1]
	battle.resolver.execute(blade, molok.tile, blade.mounts[0]["attack"])
	t.equal(molok.retaliation_stacks, 1, "ein Nahkampftreffer laedt auf")
	var before := blade.hp + blade.shield
	var hammer: ActionData = molok.mounts[0]["attack"]
	battle.brain._attack_modules(molok, molok.mounts[0], hammer, blade)
	t.ok(blade.hp + blade.shield < before, "der naechste Angriff entlaedt die Vergeltung")
	t.equal(molok.retaliation_stacks, 0, "danach leer")
	battle.free()


func test_whirlwind_hits_every_foe_next_to_the_bearer() -> void:
	var whirl := _with(_molok(), "equip_left", [&"mod_whirlwind"])
	var battle := _battle([whirl], [_vireo(), _vireo(), _vireo()],
		[Vector2i(10, 10), Vector2i(10, 9), Vector2i(11, 10), Vector2i(15, 15)])
	var molok: Unit = battle.units[0]
	var target: Unit = battle.units[1]
	var side: Unit = battle.units[2]
	var far: Unit = battle.units[3]
	var side_before := side.hp + side.shield
	var far_before := far.hp + far.shield
	battle.brain._attack_modules(molok, molok.mounts[0], molok.mounts[0]["attack"], target)
	t.ok(side.hp + side.shield < side_before, "der Nachbar wird mitgetroffen")
	t.equal(far.hp + far.shield, far_before, "wer weiter weg steht, nicht")
	battle.free()


func test_defense_modules_raise_the_bearers_stats() -> void:
	var plain := _vireo().stats()
	var armored := _with(_vireo(), "equip_left", [&"mod_armor_plate", &"mod_capacitor"]).stats()
	t.equal(armored["def"], plain["def"] + 3, "+3 Panzerung")
	t.ok(armored["shield_max"] >= plain["shield_max"] + 10, "+10 Schild")


func test_spikes_hurt_melee_attackers() -> void:
	var spiky := _with(_molok(), "equip_left", [&"mod_spike_grid"])
	var battle := _battle([spiky], [_vireo(&"eq_plasma_blade")], [Vector2i(10, 10), Vector2i(10, 9)])
	var molok: Unit = battle.units[0]
	var blade: Unit = battle.units[1]
	var before := blade.hp + blade.shield
	var slash: ActionData = blade.mounts[0]["attack"]
	battle.resolver.execute(blade, molok.tile, slash)
	t.ok(blade.hp + blade.shield < before, "der Angreifer nimmt Schaden (%d -> %d)"
		% [before, blade.hp + blade.shield])
	battle.free()


func test_the_bait_module_makes_the_target_attack_the_bearer() -> void:
	var bait := _with(_vireo(), "equip_left", [&"mod_bait"])
	var battle := _battle([bait, _vireo()], [_molok()],
		[Vector2i(10, 12), Vector2i(4, 4), Vector2i(10, 10)])
	var bearer: Unit = battle.units[0]
	var foe: Unit = battle.units[2]
	var ability: ActionData = bearer.mounts[0]["ability"]
	t.ok(ability.taunt_seconds > 0.0, "die Faehigkeit lockt")
	battle.brain._after_ability(bearer, ability, {"tile": foe.tile, "target": foe})
	t.equal(battle.brain.lured_by(foe), bearer, "der Gegner greift den Traeger an")
	foe.tick_statuses(ability.taunt_seconds + 0.1)
	t.equal(battle.brain.lured_by(foe), null, "danach nicht mehr")
	battle.free()


func test_a_battle_with_every_module_runs_to_the_end() -> void:
	var gun := _with(_vireo(), "equip_left", [&"mod_gunslinger", &"mod_metronome", &"mod_bait"])
	var tank := _with(_molok(), "equip_left", [&"mod_bulwark", &"mod_brawler"])
	tank.modules["equip_right"] = [&"mod_whirlwind"]
	var battle := BattleManager.new()
	battle.setup(919, [gun, tank], [_vireo(), _molok()])
	var outcome := battle.run_to_end()
	t.ok(outcome != BattleManager.Outcome.RUNNING, "der Kampf endet (%s)" % BattleManager.outcome_label(outcome))
	battle.free()


# ---------------------------------------------------------------------------
# Lager und Rezepte im Lauf
# ---------------------------------------------------------------------------

func test_a_module_goes_from_storage_into_a_holder_and_back() -> void:
	var run := _stop_run()
	run.storage.append(&"mod_armor_plate")
	var options := run.module_options(0)
	t.ok(not options.is_empty(), "es gibt Halter zur Wahl")
	var spot: Dictionary = options[0]
	t.ok(run.install_module(0, int(spot["drome"]), spot["slot"]), "eingesetzt")
	t.ok(run.storage.is_empty(), "das Lager ist leer")
	var build: DromeBuild = run.squad[int(spot["drome"])]
	t.equal(build.modules[spot["slot"]], [&"mod_armor_plate"], "steckt im Halter")
	t.ok(run.remove_module(int(spot["drome"]), spot["slot"], 0), "herausgenommen")
	t.equal(run.storage, [&"mod_armor_plate"], "zurueck im Lager")
	t.ok(not build.modules.has(spot["slot"]), "der Halter ist leer")


func test_a_holder_takes_only_as_many_modules_as_it_has_slots() -> void:
	var run := _stop_run()
	var drome := -1
	for i in run.squad.size():
		if run.squad[i].body().id == &"jugg_body":
			drome = i
	t.ok(drome >= 0, "der Molok ist im Standard-Squad")
	var slot: String = run.squad[drome].equip_slots()[0]
	for _i in 3:
		run.storage.append(&"mod_capacitor")
	t.ok(run.install_module(0, drome, slot), "erstes Modul")
	t.ok(run.install_module(0, drome, slot), "zweites Modul")
	t.ok(not run.install_module(0, drome, slot), "drittes passt beim Molok nicht")
	t.equal(run.storage.size(), 1, "es bleibt im Lager")


func test_a_recipe_fits_only_once_per_holder() -> void:
	var run := _stop_run()
	var drome := 0
	var slot: String = run.squad[drome].equip_slots()[0]
	run.storage.append_array([&"mod_metronome", &"mod_metronome", &"mod_bulwark"])
	t.ok(run.install_module(0, drome, slot), "erster Taktgeber")
	var spot: Dictionary = run.module_options(0).filter(
		func(e): return e["drome"] == drome and e["slot"] == slot)[0]
	t.ok(not spot["allowed"], "zweiter Taktgeber wird angeboten, aber gesperrt")
	t.ok(String(spot["detail"]).contains("einmal je Halter"), "mit Grund")
	t.ok(not run.install_module(0, drome, slot), "zweiter Taktgeber passt nicht")
	t.ok(run.install_module(1, drome, slot), "ein anderes Rezept schon")


func test_recipes_combine_in_the_storage() -> void:
	var run := _stop_run()
	run.storage.append_array([&"mod_rapid_fire", &"eq_hammer", &"mod_long_barrel"])
	var book := run.recipe_book()
	var gun: Dictionary = book.filter(func(e): return e["module"].id == &"mod_gunslinger")[0]
	t.ok(not gun["ready"], "Doppellauf fehlt noch")
	t.ok(not run.craft(&"mod_gunslinger"), "ohne alle Zutaten geht es nicht")
	run.storage.append(&"mod_twin_barrel")
	t.ok(run.craft(&"mod_gunslinger"), "zusammengefuegt")
	t.equal(run.storage, [&"eq_hammer", &"mod_gunslinger"], "Zutaten weg, Ergebnis im Lager")


func test_modules_sell_but_never_go_home() -> void:
	var run := _stop_run()
	run.storage.append(&"mod_bait")
	t.ok(not run.send_home(0), "Module koennen nicht nach Hause")
	var before := run.credits
	t.ok(run.sell(0) > 0, "verkaufen bringt Credits")
	t.ok(run.credits > before, "die Credits steigen")
	run.storage.append(&"mod_bait")
	run.squad[0].modules[run.squad[0].equip_slots()[0]] = [&"mod_capacitor"]
	run.abandon()
	for item in run.home_queue:
		t.ok(not ModuleData.is_module(item.get("part_id", "")), "kein Modul geht nach Hause")


func test_a_module_reward_lands_in_the_storage() -> void:
	var run := RunState.start(12)
	run.record_result(BattleManager.Outcome.VICTORY, [&"eq_deflector", &"eq_rune_staff"])
	var index := -1
	for i in run.reward_options.size():
		if run.reward_options[i]["kind"] == "module":
			index = i
	t.ok(index >= 0, "ein Modul steht zur Wahl")
	if index < 0:
		return
	var module_id: StringName = run.reward_options[index]["module_id"]
	t.ok(not run.choose_reward(index, RunState.home_placement()), "nicht nach Hause")
	t.ok(run.choose_reward(index), "genommen")
	t.equal(run.storage, [module_id], "liegt im Lager")
