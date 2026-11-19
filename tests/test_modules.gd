extends RefCounted

## Module und Rezepte (MODULE_KONZEPT.md): Katalog, Wirkung im Kampf, Lager.

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
	# Gestellte Lagen: ein grosses, leeres Hexfeld (20 x 20), damit die Felder
	# der Tests unabhaengig von der Spielfeldgroesse gueltig sind.
	battle.grid.width = 20
	battle.grid.height = 20
	battle.grid.obstacles.clear()
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
	t.equal(ModuleData.base_modules().size(), 9, "9 Grundmodule")
	t.equal(ModuleData.recipes().size(), 18, "18 Rezepte")
	for recipe in ModuleData.recipes():
		for ingredient in recipe.from:
			var part := ModuleData.get_module(ingredient)
			t.ok(part != null and not part.is_recipe(),
				"%s: Zutat %s ist ein Grundmodul" % [recipe.display_name, ingredient])


func test_every_recipe_is_a_pair_and_every_base_module_is_in_four() -> void:
	var degree := {}
	var pairs := {}
	for recipe in ModuleData.recipes():
		t.equal(recipe.from.size(), 2, "%s hat genau zwei Zutaten" % recipe.display_name)
		t.ok(recipe.from[0] != recipe.from[1], "%s: zwei verschiedene" % recipe.display_name)
		var sorted_ids: Array = recipe.from.map(func(x): return str(x))
		sorted_ids.sort()
		var key := ",".join(sorted_ids)
		t.ok(not pairs.has(key), "%s: kein anderes Rezept mit denselben Zutaten" % recipe.display_name)
		pairs[key] = true
		for ingredient in recipe.from:
			degree[ingredient] = int(degree.get(ingredient, 0)) + 1
	for module in ModuleData.base_modules():
		t.equal(int(degree.get(module.id, 0)), 4, "%s steckt in 4 Rezepten" % module.display_name)
		t.equal(module.condition, "", "%s wirkt auf jede Waffe" % module.display_name)


func test_every_module_has_its_own_symbol() -> void:
	var seen := {}
	for module in ModuleData.base_modules() + ModuleData.recipes():
		var icon: Texture2D = module.icon()
		t.ok(icon != null, "%s hat ein Symbol (assets/modules/%s.svg)" % [module.display_name, module.id])
		if icon != null:
			t.ok(icon.get_width() >= 128, "%s ist fein gerastert (%d px)" % [module.display_name, icon.get_width()])
		t.ok(not seen.has(module.short_name()), "%s: Kürzel %s ist eindeutig" % [module.display_name, module.short_name()])
		seen[module.short_name()] = true


func test_a_recipe_sums_its_ingredients_and_adds_its_own_effect() -> void:
	var gun := ModuleData.get_module(&"mod_gunslinger")
	t.ok(gun != null and gun.is_recipe(), "Gunslinger ist ein Rezept")
	t.ok(is_equal_approx(float(gun.effects["attack_speed"]), 0.08), "Schnellfeuer steckt drin")
	t.ok(is_equal_approx(float(gun.effects["ricochet_chance"]), 0.2), "Doppellauf steckt drin")
	t.equal(int(gun.effects["field_shot_every"]), 6, "dazu jeder 6. Angriff quer übers Feld")


func test_conditions_decide_whether_a_module_works() -> void:
	var gun := ModuleData.get_module(&"mod_gunslinger")
	t.ok(gun.fits(PartDB.get_part(&"eq_pulse_blaster")), "Gunslinger am Blaster")
	t.ok(not gun.fits(PartDB.get_part(&"eq_plasma_blade")), "nicht an der Klinge")
	var whirl := ModuleData.get_module(&"mod_whirlwind")
	t.ok(whirl.fits(PartDB.get_part(&"eq_hammer")), "Rundumschlag am Hammer")
	t.ok(not whirl.fits(PartDB.get_part(&"eq_rail_lance")), "nicht an der Lanze")
	t.ok(ModuleData.get_module(&"mod_heavy_edge").fits(PartDB.get_part(&"eq_rail_lance")),
		"Wuchtkante seit dem Neuentwurf auch an der Lanze")
	t.ok(ModuleData.get_module(&"mod_armor_plate").fits(PartDB.get_part(&"eq_rail_lance")),
		"ohne Bedingung passt es überall")


func test_the_molok_has_fewer_module_slots() -> void:
	t.equal(ModuleData.slots_for(_vireo()), 3, "drei je Halter")
	t.equal(ModuleData.slots_for(_molok()), 2, "Molok zwei")


# ---------------------------------------------------------------------------
# Wirkung
# ---------------------------------------------------------------------------

func test_attack_modules_change_a_copy_of_the_weapon() -> void:
	var build := _with(_vireo(), "equip_left", [&"mod_heavy_edge", &"mod_rapid_fire"])
	var unit := Unit.create(build, &"V", true)
	unit.init_realtime(0.0)
	var attack: ActionData = unit.mounts[0]["attack"]
	var original: ActionData = PartDB.get_part(&"eq_pulse_blaster").actions[0]
	t.equal(attack.power, int(round(original.power * 1.12)), "12 % mehr Schaden")
	t.ok(is_equal_approx(attack.interval, original.interval / 1.08), "8 % schneller")
	t.equal(original.power, 10, "das Teil in der PartDB bleibt unverändert")


func test_a_resting_module_does_nothing() -> void:
	var build := _with(_vireo(&"eq_plasma_blade"), "equip_left", [&"mod_gunslinger"])
	var unit := Unit.create(build, &"V", true)
	unit.init_realtime(0.0)
	var original: ActionData = PartDB.get_part(&"eq_plasma_blade").actions[0]
	t.ok(is_equal_approx((unit.mounts[0]["attack"] as ActionData).interval, original.interval),
		"die Klinge wird nicht schneller")
	t.ok(build.active_modules("equip_left").is_empty(), "das Modul ruht")


## Wie oft kommt die Faehigkeit in ``attacks`` Waffeneinsaetzen?
func _abilities_in(unit: Unit, attacks: int) -> int:
	var mount: Dictionary = unit.mounts[0]
	var count := 0
	for _i in attacks:
		if unit.takt_due(mount):
			count += 1
			mount["count"] = maxf(0.0, float(mount["count"]) + unit.takt_step(mount)
				- float(unit.takt_every(mount["ability"])))
		else:
			mount["count"] = float(mount["count"]) + unit.takt_step(mount)
	return count


func test_the_takt_chip_counts_each_attack_as_one_and_a_quarter() -> void:
	var plain := Unit.create(_vireo(), &"V", true)
	plain.init_realtime(0.0)
	t.equal(_abilities_in(plain, 12), 4, "ohne: jeder 3. Einsatz")
	var chip := Unit.create(_with(_vireo(), "equip_left", [&"mod_takt_chip"]), &"V", true)
	chip.init_realtime(0.0)
	t.equal(_abilities_in(chip, 12), 5, "mit Taktchip: 12 / 2,4 = 5")
	t.equal(chip.takt_bars()[0]["segments"], 3, "die Takt-Leiste behält ihre Abschnitte")
	var recipe := ModuleData.get_module(&"mod_takt_chip")
	t.equal(recipe.from, [&"mod_rapid_fire", &"mod_amplifier"], "aus Schnellfeuer und Verstärker")
	t.ok(not recipe.effects.has("takt_time"), "kein Zeit-Takt mehr (9. Nov. 2026)")


func test_the_amplifier_strengthens_the_ability() -> void:
	var unit := Unit.create(_with(_vireo(), "equip_left", [&"mod_amplifier"]), &"V", true)
	unit.init_realtime(0.0)
	var ability: ActionData = unit.mounts[0]["ability"]
	var original: ActionData = PartDB.get_part(&"eq_pulse_blaster").actions[1]
	t.equal(ability.power, int(round(original.power * 1.2)), "Fähigkeit +20 %")
	var pod := Unit.create(_with(_vireo(&"eq_drone_pod"), "equip_left", [&"mod_amplifier"]), &"V", true)
	pod.init_realtime(0.0)
	var field: ActionData = pod.mounts[0]["ability"]
	t.equal(field.shield_gain, 18, "Schildgabe 15 -> 18")


func test_retaliation_charges_the_next_strike() -> void:
	var brawler := _with(_molok(), "equip_left", [&"mod_brawler"])
	var battle := _battle([brawler], [_vireo(&"eq_plasma_blade")], [Vector2i(10, 10), Vector2i(10, 9)])
	var molok: Unit = battle.units[0]
	var blade: Unit = battle.units[1]
	battle.resolver.execute(blade, molok.tile, blade.mounts[0]["attack"])
	t.equal(molok.retaliation_stacks, 2, "ein Nahkampftreffer zählt doppelt")
	var before := blade.hp + blade.shield
	var hammer: ActionData = molok.mounts[0]["attack"]
	battle.brain._attack_modules(molok, molok.mounts[0], hammer, blade)
	t.ok(blade.hp + blade.shield < before, "der nächste Angriff entlädt die Vergeltung")
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


func test_the_shackle_pulls_three_foes_next_to_the_bearer_and_stuns_them() -> void:
	var chained := _with(_molok(), "equip_left", [&"mod_shackle"])
	t.equal(ModuleData.get_module(&"mod_shackle").from,
		[&"mod_armor_plate", &"mod_bait"], "Panzerplatte und Ködersender")
	var battle := _battle([chained], [_vireo(), _vireo(), _vireo(), _vireo()],
		[Vector2i(10, 10), Vector2i(10, 13), Vector2i(13, 10), Vector2i(7, 10), Vector2i(16, 16)])
	var molok: Unit = battle.units[0]
	battle.brain._shackle(molok, molok.mounts[0])
	for i in [1, 2, 3]:
		var foe: Unit = battle.units[i]
		t.ok(Grid.distance(foe.tile, molok.tile) <= 1, "Gegner %d steht jetzt daneben (%s)" % [i, foe.tile])
		t.ok(foe.is_stunned(), "und ist betäubt")
	var far: Unit = battle.units[4]
	t.equal(far.tile, Vector2i(16, 16), "wer weiter weg steht, bleibt")
	t.ok(not far.is_stunned(), "und ist nicht betäubt")
	battle.free()


func test_defense_modules_raise_the_bearers_stats() -> void:
	var plain := _vireo().stats()
	var armored := _with(_vireo(), "equip_left", [&"mod_armor_plate", &"mod_capacitor"]).stats()
	t.equal(armored["def"], plain["def"] + 3, "+3 Panzerung")
	t.ok(armored["shield_max"] >= plain["shield_max"] + 10, "+10 Schild")


func test_spikes_hurt_every_attacker_and_melee_more() -> void:
	var spiky := _with(_molok(), "equip_left", [&"mod_spike_grid"])
	var battle := _battle([spiky], [_vireo(), _vireo(&"eq_plasma_blade")],
		[Vector2i(10, 10), Vector2i(10, 7), Vector2i(10, 9)])
	var molok: Unit = battle.units[0]
	var gunner: Unit = battle.units[1]
	var blade: Unit = battle.units[2]
	var gun_before := gunner.hp + gunner.shield
	battle.resolver.execute(gunner, molok.tile, gunner.mounts[0]["attack"])
	var far_loss := gun_before - (gunner.hp + gunner.shield)
	t.ok(far_loss > 0, "der Fernkämpfer nimmt Schaden (%d)" % far_loss)
	var blade_before := blade.hp + blade.shield
	battle.resolver.execute(blade, molok.tile, blade.mounts[0]["attack"])
	var near_loss := blade_before - (blade.hp + blade.shield)
	t.ok(near_loss > far_loss, "im Nahkampf mehr (%d gegen %d)" % [near_loss, far_loss])
	battle.free()


func test_splinter_spikes_go_past_the_shield() -> void:
	var spiky := _with(_molok(), "equip_left", [&"mod_splinter"])
	var battle := _battle([spiky], [_vireo(&"eq_plasma_blade")], [Vector2i(10, 10), Vector2i(10, 9)])
	var molok: Unit = battle.units[0]
	var blade: Unit = battle.units[1]
	var shield_before := blade.shield
	var hp_before := blade.hp
	battle.resolver.execute(blade, molok.tile, blade.mounts[0]["attack"])
	t.equal(blade.shield, shield_before, "der Schild bleibt")
	t.ok(blade.hp < hp_before, "die Integrität sinkt")
	battle.free()


func test_the_beacon_marks_and_marked_foes_take_more() -> void:
	var beacon := _with(_vireo(), "equip_left", [&"mod_beacon"])
	var battle := _battle([beacon], [_molok(), _molok()],
		[Vector2i(10, 12), Vector2i(10, 10), Vector2i(4, 4)])
	var bearer: Unit = battle.units[0]
	var foe: Unit = battle.units[1]
	var other: Unit = battle.units[2]
	battle.brain._after_ability(bearer, bearer.mounts[0]["ability"],
		{"tile": foe.tile, "target": foe}, bearer.mounts[0]["fx"])
	t.ok(ActionResolver.is_marked(foe), "das Ziel ist markiert")
	t.ok(foe.damage_taken_mult() > 1.05, "und nimmt mehr Schaden")
	t.ok(not ActionResolver.is_marked(other), "der andere nicht")
	foe.tick_statuses(4.1)
	t.ok(not ActionResolver.is_marked(foe), "nach 4 s vorbei")
	battle.free()


func test_the_beacon_on_a_shield_gift_marks_the_nearest_foe() -> void:
	var pod := _with(_vireo(&"eq_drone_pod"), "equip_left", [&"mod_beacon"])
	var battle := _battle([pod, _vireo()], [_molok()],
		[Vector2i(10, 12), Vector2i(10, 13), Vector2i(10, 10)])
	var bearer: Unit = battle.units[0]
	var ally: Unit = battle.units[1]
	var foe: Unit = battle.units[2]
	battle.brain._after_ability(bearer, bearer.mounts[0]["ability"],
		{"tile": ally.tile, "target": ally}, bearer.mounts[0]["fx"])
	t.ok(ActionResolver.is_marked(foe), "Ersatzregel: der nächste Gegner in Rw 3")
	t.ok(not ActionResolver.is_marked(ally), "nicht der Verbündete")
	battle.free()


func test_the_seeker_hits_marked_foes_harder() -> void:
	var seeker := _with(_vireo(), "equip_left", [&"mod_seeker"])
	var battle := _battle([seeker], [_molok(), _molok()],
		[Vector2i(10, 12), Vector2i(10, 10), Vector2i(12, 10)])
	var bearer: Unit = battle.units[0]
	var plain: Unit = battle.units[1]
	var marked: Unit = battle.units[2]
	plain.shield = 0
	marked.shield = 0
	battle.resolver.mark(marked, 4.0)
	var attack: ActionData = bearer.mounts[0]["attack"]
	var a := battle.resolver.apply_damage(bearer, plain, 20, attack)
	var b := battle.resolver.apply_damage(bearer, marked, 20, attack)
	t.ok(b > a, "markiert mehr (%d gegen %d)" % [b, a])
	battle.free()


func test_the_brand_marks_whoever_hits_the_bearer() -> void:
	var brand := _with(_molok(), "equip_left", [&"mod_brand"])
	var battle := _battle([brand], [_vireo()], [Vector2i(10, 10), Vector2i(10, 7)])
	var molok: Unit = battle.units[0]
	var gunner: Unit = battle.units[1]
	battle.resolver.execute(gunner, molok.tile, gunner.mounts[0]["attack"])
	t.ok(ActionResolver.is_marked(gunner), "der Angreifer ist markiert")
	battle.free()


func test_the_ram_adds_part_of_the_armor() -> void:
	var ram := Unit.create(_with(_molok(), "equip_left", [&"mod_ram"]), &"M", true)
	ram.init_realtime(0.0)
	var edge := Unit.create(_with(_molok(), "equip_left", [&"mod_heavy_edge", &"mod_armor_plate"]), &"M", true)
	edge.init_realtime(0.0)
	var a := ram.raw_damage(ram.mounts[0]["attack"])
	var b := edge.raw_damage(edge.mounts[0]["attack"])
	t.ok(a > b, "Rammbock trifft härter als seine Zutaten (%d gegen %d)" % [a, b])


func test_overvolt_turns_kinetic_into_energy_while_the_shield_holds() -> void:
	var volt := _with(_vireo(&"eq_plasma_blade"), "equip_left", [&"mod_overvolt"])
	var battle := _battle([volt], [_molok()], [Vector2i(10, 10), Vector2i(10, 9)])
	var bearer: Unit = battle.units[0]
	var foe: Unit = battle.units[1]
	var attack: ActionData = bearer.mounts[0]["attack"]
	foe.shield = 100
	battle.resolver.apply_damage(bearer, foe, 20, attack)
	var with_shield := 100 - foe.shield
	bearer.shield = 0
	foe.shield = 100
	battle.resolver.apply_damage(bearer, foe, 20, attack)
	var without := 100 - foe.shield
	t.ok(with_shield > without, "mit eigenem Schild mehr am Gegnerschild (%d gegen %d)" % [with_shield, without])
	battle.free()


func test_overload_strengthens_the_next_attacks() -> void:
	var unit := Unit.create(_with(_vireo(), "equip_left", [&"mod_overload"]), &"V", true)
	var battle := _battle([unit.build], [_molok()], [Vector2i(10, 12), Vector2i(10, 10)])
	var bearer: Unit = battle.units[0]
	var foe: Unit = battle.units[1]
	var mount: Dictionary = bearer.mounts[0]
	mount["count"] = 2.0
	t.ok(battle.brain._fire(bearer, mount, foe), "die Fähigkeit geht los")
	t.equal(int(mount.get("overload", 0)), 3, "drei Angriffe aufgeladen")
	battle.brain._fire(bearer, mount, foe)
	t.equal(int(mount.get("overload", 0)), 2, "einer verbraucht")
	t.ok((mount["overload_attack"] as ActionData).power > (mount["attack"] as ActionData).power,
		"der aufgeladene Angriff ist stärker")
	battle.free()


func test_the_fork_repeats_the_ability_on_a_second_foe() -> void:
	var fork := _with(_vireo(&"eq_plasma_blade"), "equip_left", [&"mod_fork"])
	var battle := _battle([fork], [_molok(), _molok(), _molok()],
		[Vector2i(10, 11), Vector2i(10, 10), Vector2i(11, 10), Vector2i(17, 17)])
	var bearer: Unit = battle.units[0]
	var first: Unit = battle.units[1]
	var second: Unit = battle.units[2]
	var far: Unit = battle.units[3]
	var second_before := second.hp + second.shield
	var far_before := far.hp + far.shield
	battle.brain._after_ability(bearer, bearer.mounts[0]["ability"],
		{"tile": first.tile, "target": first}, bearer.mounts[0]["fx"])
	t.ok(second.hp + second.shield < second_before, "der Nachbar des Ziels bekommt die Gabelung")
	t.equal(far.hp + far.shield, far_before, "wer weit weg steht, nicht")
	battle.free()


func test_the_guard_pulse_gives_armor_around_the_bearer() -> void:
	var guard := _with(_molok(), "equip_left", [&"mod_guard_pulse"])
	var battle := _battle([guard, _vireo(), _vireo()], [_molok()],
		[Vector2i(10, 10), Vector2i(10, 11), Vector2i(2, 2), Vector2i(10, 7)])
	var molok: Unit = battle.units[0]
	var near: Unit = battle.units[1]
	var far: Unit = battle.units[2]
	var before := near.def()
	battle.brain._after_ability(molok, molok.mounts[0]["ability"], {"tile": molok.tile, "target": null},
		molok.mounts[0]["fx"])
	t.equal(near.def(), before + 3, "der Nachbar +3 Panzerung")
	t.equal(far.def(), far.stats["def"], "wer weit weg steht, nicht")
	battle.free()


func test_the_discharge_hits_foes_when_the_shield_breaks() -> void:
	var spark := _with(_molok(), "equip_left", [&"mod_discharge"])
	var battle := _battle([spark], [_vireo(), _vireo()],
		[Vector2i(10, 10), Vector2i(10, 9), Vector2i(17, 17)])
	var molok: Unit = battle.units[0]
	var near: Unit = battle.units[1]
	var far: Unit = battle.units[2]
	molok.shield = 1
	var near_before := near.hp + near.shield
	battle.resolver.apply_damage(far, molok, 30, far.mounts[0]["attack"])
	t.ok(near.hp + near.shield < near_before, "der Nachbar nimmt Schaden")
	t.ok(near.is_stunned(), "und ist kurz betäubt")
	t.ok(molok.burst_cooldown > 0.0, "dann Pause")
	battle.free()


func test_the_chain_reaction_jumps_to_marked_foes() -> void:
	var chain := _with(_vireo(), "equip_left", [&"mod_chain_reaction"])
	var battle := _battle([chain], [_molok(), _molok()],
		[Vector2i(10, 13), Vector2i(10, 10), Vector2i(11, 10)])
	var bearer: Unit = battle.units[0]
	var target: Unit = battle.units[1]
	var marked: Unit = battle.units[2]
	battle.resolver.mark(marked, 10.0)
	t.equal(battle.brain._chain_next(bearer, target), marked, "springt auf den Markierten")
	battle.resolver.mark(marked, 0.0)
	marked.statuses.erase(&"mark")
	t.equal(battle.brain._chain_next(bearer, target), target, "ohne Markierung bleibt es beim Ziel")
	battle.free()


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
	t.ok(is_equal_approx(ability.taunt_seconds, 2.0), "die Fähigkeit lockt 2 s")
	var twice := Unit.create(_with(_vireo(), "equip_left", [&"mod_bait", &"mod_bait"]), &"V", true)
	twice.init_realtime(0.0)
	t.ok(is_equal_approx((twice.mounts[0]["ability"] as ActionData).taunt_seconds, 3.0),
		"ein zweites Exemplar +1 s")
	battle.brain._after_ability(bearer, ability, {"tile": foe.tile, "target": foe})
	t.equal(battle.brain.lured_by(foe), bearer, "der Gegner greift den Träger an")
	foe.tick_statuses(ability.taunt_seconds + 0.1)
	t.equal(battle.brain.lured_by(foe), null, "danach nicht mehr")
	battle.free()


func test_a_battle_with_every_module_runs_to_the_end() -> void:
	# Alle 18 Rezepte, verteilt auf zwei gleiche Squads.
	var ids: Array = ModuleData.recipes().map(func(m): return m.id)
	for side_seed in [919, 920]:
		var gun := _with(_vireo(), "equip_left", ids.slice(0, 3))
		var blade := _with(_vireo(&"eq_plasma_blade"), "equip_left", ids.slice(3, 6))
		var pod := _with(_vireo(&"eq_drone_pod"), "equip_left", ids.slice(6, 9))
		var tank := _with(_molok(), "equip_left", ids.slice(9, 11))
		tank.modules["equip_right"] = ids.slice(11, 13)
		var foe_a := _with(_vireo(&"eq_neon_blaster"), "equip_left", ids.slice(13, 16))
		var foe_b := _with(_molok(), "equip_left", ids.slice(16, 18))
		var battle := BattleManager.new()
		battle.setup(side_seed, [gun, blade, pod, tank], [foe_a, foe_b, _vireo(), _molok()])
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
	t.equal(run.storage, [&"mod_armor_plate"], "zurück im Lager")
	t.ok(not build.modules.has(spot["slot"]), "der Halter ist leer")


## Seit 17. Nov. 2026: ein Modul landet auf dem Platz, auf den es gezogen
## wird; freie Plaetze dazwischen bleiben frei, Herausnehmen schiebt nichts.
func test_a_module_lands_on_the_slot_it_is_dropped_on() -> void:
	var run := _stop_run()
	var drome := -1
	var slot := ""
	for i in run.squad.size():
		for s in run.squad[i].equip_slots():
			if drome < 0 and ModuleData.slots_for(run.squad[i], s) >= 3:
				drome = i
				slot = s
	t.ok(drome >= 0, "ein Halter mit drei Modulplaetzen")
	var build: DromeBuild = run.squad[drome]
	run.storage.append(&"mod_armor_plate")
	run.storage.append(&"mod_capacitor")
	run.storage.append(&"mod_spike_grid")
	t.ok(run.install_module(0, drome, slot, 2), "auf den dritten Platz")
	t.equal(build.module_count(slot), 1, "ein Modul gezaehlt")
	var layout := build.module_layout(slot)
	t.ok(layout.size() == 3 and layout[0] == null and layout[1] == null
		and layout[2].id == &"mod_armor_plate", "Plaetze 1 und 2 bleiben frei")
	t.ok(run.install_module(0, drome, slot, 2), "belegter Platz: weicht aus")
	t.equal(build.module_layout(slot)[0].id, &"mod_capacitor", "auf den ersten freien")
	t.ok(run.install_module(0, drome, slot), "ohne Platz: erster freier")
	t.equal(build.module_layout(slot)[1].id, &"mod_spike_grid", "Platz 2")
	t.ok(run.remove_module(drome, slot, 1), "mittleres heraus")
	t.equal(build.module_layout(slot)[2].id, &"mod_armor_plate", "das dritte rutscht nicht nach")
	t.equal(build.module_count(slot), 2, "zwei gezaehlt")
	t.ok(not run.remove_module(drome, slot, 1), "ein freier Platz gibt nichts her")
	t.ok(run.remove_module(drome, slot, 2), "drittes heraus")
	t.equal(build.module_layout(slot).size(), 1, "freie Plaetze am Ende fallen weg")
	t.ok(run.remove_module(drome, slot, 0), "erstes heraus")
	t.ok(not build.modules.has(slot), "der Halter ist leer")


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
	run.storage.append_array([&"mod_takt_chip", &"mod_takt_chip", &"mod_bulwark"])
	t.ok(run.install_module(0, drome, slot), "erster Taktchip")
	var spot: Dictionary = run.module_options(0).filter(
		func(e): return e["drome"] == drome and e["slot"] == slot)[0]
	t.ok(not spot["allowed"], "zweiter Taktchip wird angeboten, aber gesperrt")
	t.ok(String(spot["detail"]).contains("einmal je Halter"), "mit Grund")
	t.ok(not run.install_module(0, drome, slot), "zweiter Taktchip passt nicht")
	t.ok(run.install_module(1, drome, slot), "ein anderes Rezept schon")


func test_recipes_combine_in_the_storage() -> void:
	var run := _stop_run()
	run.storage.append_array([&"mod_rapid_fire", &"mod_bait"])
	var book := run.recipe_book()
	var gun: Dictionary = book.filter(func(e): return e["module"].id == &"mod_gunslinger")[0]
	t.ok(not gun["ready"], "Doppellauf fehlt noch")
	t.ok(not run.craft(&"mod_gunslinger"), "ohne alle Zutaten geht es nicht")
	run.storage.append(&"mod_twin_barrel")
	t.ok(run.craft(&"mod_gunslinger"), "zusammengefuegt")
	t.equal(run.storage, [&"mod_bait", &"mod_gunslinger"], "Zutaten weg, Ergebnis im Lager")


## Modul auf Modul ziehen (16. Nov. 2026): pair_result nennt das Rezept.
func test_dragging_one_module_onto_another_names_the_recipe() -> void:
	var run := _stop_run()
	run.storage.append_array([&"mod_rapid_fire", &"mod_bait", &"mod_twin_barrel"])
	var gun := run.pair_result(0, 2)
	t.ok(gun != null and gun.id == &"mod_gunslinger", "Schnellfeuer + Doppellauf = Gunslinger")
	t.ok(run.pair_result(2, 0) == gun, "in beide Richtungen")
	t.ok(run.pair_result(0, 1) == null, "Schnellfeuer + Köder ergibt nichts")
	t.ok(run.pair_result(0, 0) == null, "nicht mit sich selbst")
	t.ok(run.pair_result(0, 9) == null, "leerer Platz ergibt nichts")


func test_modules_sell_but_never_go_home() -> void:
	var run := _stop_run()
	run.storage.append(&"mod_bait")
	var before := run.credits
	t.ok(run.sell(0) > 0, "verkaufen bringt Credits")
	t.ok(run.credits > before, "die Credits steigen")
	run.storage.append(&"mod_bait")
	run.squad[0].modules[run.squad[0].equip_slots()[0]] = [&"mod_capacitor"]
	run.abandon()
	for item in run.home_queue:
		t.ok(not ModuleData.is_module(item.get("part_id", "")), "kein Modul geht nach Hause")


func test_the_shop_sells_modules_into_the_storage() -> void:
	var run := RunState.start(12)
	run.record_result(BattleManager.Outcome.VICTORY, [&"eq_deflector", &"eq_rune_staff"])
	t.equal(run.phase, RunState.Phase.STOP, "Zwischenstopp")
	run.storage.clear()
	t.equal(run.shop_offers.size(), int(ModuleData.data()["shop"]["offers"]), "der Laden bietet an")
	var first: StringName = run.shop_offers[0]["module_id"]
	t.ok(not ModuleData.get_module(first).is_recipe(), "nur Grundmodule")
	t.equal(run.shop_offers.size(), 3, "drei Angebote")
	t.ok(run.shop_offers[0]["module_id"] != run.shop_offers[1]["module_id"], "keines doppelt")
	var price := RunState.shop_price(ModuleData.get_module(first))
	run.credits = price - 1
	t.equal(run.shop_blocker(0), "zu wenig Credits", "zu teuer")
	t.ok(not run.buy(0), "nicht kaufbar")
	run.credits = price
	t.ok(run.buy(0), "gekauft")
	t.equal(run.credits, 0, "Credits abgezogen")
	t.equal(run.storage, [first], "liegt im Lager")
	t.ok(not run.buy(0), "nur einmal")
	run.continue_run()
	t.equal(run.shop_offers.size(), 0, "der Laden schließt mit dem Stopp")


func test_the_shop_is_full_storage_aware_and_seeded() -> void:
	var run := _stop_run()
	run.shop_offers = run.roll_shop()
	t.equal(run.roll_shop(), run.shop_offers, "derselbe Seed, derselbe Laden")
	run.credits = 99
	for _i in RunState.storage_size():
		run.storage.append(&"mod_capacitor")
	t.equal(run.shop_blocker(0), "Lager voll", "voll")
	t.ok(not run.buy(0), "kein Kauf bei vollem Lager")


func test_the_shop_favours_missing_recipe_parts() -> void:
	# Mitleid: Schnellfeuer liegt im Lager -> Doppellauf (Gunslinger) und
	# Kondensator (Ueberspannung) kommen oefter als ohne.
	var run := _stop_run()
	run.storage.append(&"mod_rapid_fire")
	t.ok(run.recipe_missing().has(&"mod_twin_barrel"), "Doppellauf fehlt dem Gunslinger")
	t.ok(not run.recipe_missing().has(&"mod_rapid_fire"), "was da ist, fehlt nicht")
	var with_hits := 0
	var without_hits := 0
	var bare := _stop_run()
	for seed_value in 300:
		run.run_seed = seed_value
		bare.run_seed = seed_value
		for offer in run.roll_shop():
			if offer["module_id"] in [&"mod_capacitor", &"mod_twin_barrel"]:
				with_hits += 1
		for offer in bare.roll_shop():
			if offer["module_id"] in [&"mod_capacitor", &"mod_twin_barrel"]:
				without_hits += 1
	t.ok(with_hits > without_hits * 1.3, "angefangenes Rezept zieht (%d gegen %d)" % [with_hits, without_hits])


func test_the_shop_can_be_rerolled_for_rising_credits() -> void:
	var run := _stop_run()
	run.shop_offers = run.roll_shop()
	run.credits = 5
	t.equal(run.reroll_price(), 2, "erster Wurf 2 Credits")
	t.ok(run.reroll_shop(), "neu gewürfelt")
	t.equal(run.credits, 3, "bezahlt")
	t.equal(run.reroll_price(), 3, "der nächste kostet mehr")
	t.ok(run.reroll_shop(), "noch einmal")
	t.equal(run.credits, 0, "bezahlt")
	t.equal(run.reroll_blocker(), "zu wenig Credits", "dann ist Schluss")
	t.ok(not run.reroll_shop(), "ohne Credits nicht")
	run.continue_run()
	t.equal(run.rerolls, 0, "im nächsten Zwischenstopp wieder günstig")


func test_a_target_recipe_steers_the_shop() -> void:
	# Ziel Gunslinger: Schnellfeuer und Doppellauf kommen deutlich oefter.
	var run := _stop_run()
	run.set_target_recipe(&"mod_gunslinger")
	t.equal(run.target_recipe, &"mod_gunslinger", "Ziel gesetzt")
	t.equal(run.target_missing(), [&"mod_rapid_fire", &"mod_twin_barrel"], "beide Zutaten fehlen")
	var bare := _stop_run()
	var hits := 0
	var bare_hits := 0
	for seed_value in 300:
		run.run_seed = seed_value
		bare.run_seed = seed_value
		for offer in run.roll_shop():
			if offer["module_id"] in [&"mod_rapid_fire", &"mod_twin_barrel"]:
				hits += 1
		for offer in bare.roll_shop():
			if offer["module_id"] in [&"mod_rapid_fire", &"mod_twin_barrel"]:
				bare_hits += 1
	t.ok(hits > bare_hits * 1.5, "Ziel zieht (%d gegen %d)" % [hits, bare_hits])
	run.set_target_recipe(&"mod_gunslinger")
	t.equal(run.target_recipe, &"", "noch einmal: Ziel weg")


func test_late_shops_sometimes_offer_a_recipe() -> void:
	var found := false
	for seed_value in 60:
		var run := RunState.start(500 + seed_value)
		run.phase = RunState.Phase.STOP
		run.round = 6
		for offer in run.roll_shop():
			if ModuleData.get_module(offer["module_id"]).is_recipe():
				found = true
		run.round = 2
		for offer in run.roll_shop():
			t.ok(not ModuleData.get_module(offer["module_id"]).is_recipe(), "früh nur Grundmodule")
	t.ok(found, "ab Runde 5 gelegentlich ein fertiges Rezept")


# ---------------------------------------------------------------------------
# Matrix-BIOS (MODULE_KONZEPT.md 6)
# ---------------------------------------------------------------------------

func test_the_bios_catalog() -> void:
	var recipe := ModuleData.bios_items().filter(func(i): return i.bios_kind == "recipe")
	t.equal(recipe.size(), ModuleData.bios_items().size(), "nur Rezept-BIOS (Chassis-BIOS seit 18. Nov. 2026 weg)")
	t.ok(recipe.size() >= 6, "6-8 Rezept-BIOS für den Anfang (%d)" % recipe.size())
	for item in recipe:
		var base := ModuleData.get_module(item.bios_recipe)
		var result := ModuleData.get_module(item.bios_result)
		t.ok(base != null and base.is_recipe(), "%s: Grundrezept existiert" % item.display_name)
		t.ok(result != null and result.is_bios_result, "%s: Ergebnis existiert" % item.display_name)
		if base == null or result == null:
			continue
		for key in base.effects:
			t.ok(result.effects.has(key), "%s behält %s" % [result.display_name, key])
		t.ok(not result.bonus.is_empty(), "%s bringt eine eigene Regel" % result.display_name)
	var revolver := ModuleData.get_module(&"mod_revolver")
	t.equal(int(revolver.effects["field_shot_every"]), 3, "Revolverheld: jeder 3. statt 5.")


func _elite_win(seed_value: int, last: bool = false) -> RunState:
	var run := RunState.start(seed_value)
	if last:
		run.round = RunState.rounds_total()
	# Die Stufe direkt: Elite steht nicht in jeder Reihe zur Wahl.
	run.tier = RunState.Tier.ELITE
	run.record_result(BattleManager.Outcome.VICTORY, [&"eq_hammer"])
	return run


func test_elite_wins_offer_a_bios_but_never_after_the_last_fight() -> void:
	var seen := false
	for seed_value in 30:
		var run := _elite_win(6000 + seed_value)
		var kinds: Array = run.last_loot.map(func(i): return i["kind"])
		t.ok(not kinds.has("part"), "Elite gibt kein Teil mehr, solange ein Kampf folgt")
		if kinds.has("bios"):
			seen = true
			t.equal(run.bios_offers.size(), 3, "drei zur Wahl")
		var final := _elite_win(6000 + seed_value, true)
		t.ok(not final.last_loot.map(func(i): return i["kind"]).has("bios"), "nach dem letzten Kampf kein BIOS")
		t.ok(final.bios_offers.is_empty(), "und keine Wahl")
	t.ok(seen, "Elite bringt ein BIOS zur Wahl")


func test_bios_offers_are_always_there() -> void:
	var run := RunState.start(61)
	run.phase = RunState.Phase.STOP
	for seed_value in 20:
		run.run_seed = seed_value
		var offers := run.roll_bios_offers()
		t.equal(offers.size(), 3, "immer drei zur Wahl, auch ohne Rezept im Lauf")
		for id in offers:
			t.equal(ModuleData.get_module(id).bios_kind, "recipe", "nur Rezept-BIOS (%s)" % id)
	run.storage.append(&"mod_brand")
	for seed_value in 10:
		run.run_seed = seed_value
		t.ok(run.roll_bios_offers().has(&"bios_hunt"), "ein Rezept im Lauf kommt zuerst")


## Seit 18. Nov. 2026: ein BIOS wertet ein Rezept in einer Waffe auf -- an
## seinem Platz, beim Molok nur in einer der zwei Waffen. Kein Extraplatz.
func test_a_recipe_bios_upgrades_a_recipe_in_its_weapon() -> void:
	var run := _stop_run()
	var drome := -1
	for i in run.squad.size():
		if run.squad[i].body().id == &"jugg_body":
			drome = i
	var build: DromeBuild = run.squad[drome]
	var left: String = build.equip_slots()[0]
	var right: String = build.equip_slots()[1]
	build.modules[right] = [&"mod_armor_plate", &"mod_brand"]
	run.bios_offers = [&"bios_hunt", &"bios_revolver", &"bios_phase"]
	t.ok(run.choose_bios(0), "gewaehlt")
	t.equal(run.storage, [&"bios_hunt"], "liegt im Lager")
	t.ok(run.bios_offers.is_empty(), "die anderen verfallen")
	t.ok(not run.install_module(0, drome, left), "ein BIOS steckt nicht wie ein Modul")
	t.ok(not run.install_bios(0, drome, left), "nicht in die Waffe ohne Brandmarke")
	t.ok(run.install_bios(0, drome, right), "wertet die Brandmarke auf")
	t.equal(build.modules[right], [&"mod_armor_plate", &"mod_hunt"], "an ihrem Platz")
	t.ok(run.storage.is_empty(), "das BIOS ist verbraucht")
	t.equal(ModuleData.slots_for(build, right), 2, "kein Extraplatz")
	build.modules[left] = [&"mod_brand"]
	run.storage.append(&"bios_hunt")
	t.ok(not run.install_bios(0, drome, left), "nur ein BIOS-Rezept je DROME")


# ---------------------------------------------------------------------------
# Ziehen im Zwischenstopp (19. Nov. 2026): Schrott, Kaufen in die Waffe,
# Tauschen auf belegtem Platz
# ---------------------------------------------------------------------------

func test_an_installed_module_can_be_sold() -> void:
	var run := _stop_run()
	var slot: String = run.squad[0].equip_slots()[0]
	run.squad[0].modules[slot] = [&"mod_rapid_fire", &"mod_beacon"]
	var before := run.credits
	t.equal(run.sell_installed(0, slot, 1), 2, "Grundmodul bringt 2")
	t.equal(run.credits, before + 2, "Credits gutgeschrieben")
	t.equal(run.squad[0].modules[slot], [&"mod_rapid_fire"], "Platz frei")
	t.equal(run.sell_installed(0, slot, 1), 0, "leerer Platz: nichts")


func test_dropping_on_a_taken_place_swaps() -> void:
	var run := _stop_run()
	var slot: String = run.squad[0].equip_slots()[0]
	run.squad[0].modules[slot] = [&"mod_rapid_fire", &"mod_beacon"]
	# Paare ohne gemeinsames Rezept -- sonst wird zusammengefuegt.
	run.storage.append_array([&"mod_spike_grid", &"mod_armor_plate"])
	t.equal(run.place_from_storage(1, 0, slot, 0), "", "auf belegten Platz")
	t.equal(run.squad[0].modules[slot], [&"mod_armor_plate", &"mod_beacon"], "getauscht")
	t.equal(run.storage, [&"mod_spike_grid", &"mod_rapid_fire"], "das alte nimmt den Lagerplatz")
	t.equal(run.place_from_storage(0, 0, slot, -1), "", "freier Platz")
	t.equal(run.squad[0].modules[slot], [&"mod_armor_plate", &"mod_beacon", &"mod_spike_grid"], "eingesetzt")


func test_a_swap_that_breaks_a_rule_changes_nothing() -> void:
	var run := _stop_run()
	var slot: String = run.squad[0].equip_slots()[0]
	run.squad[0].modules[slot] = [&"mod_takt_chip", &"mod_beacon"]
	run.storage.append(&"mod_metronome")
	var why := run.place_from_storage(0, 0, slot, 1, false)
	t.ok(why != "", "Taktgeber neben Taktchip geht nicht (%s)" % why)
	t.equal(run.place_from_storage(0, 0, slot, 1), why, "auch nicht ernsthaft")
	t.equal(run.squad[0].modules[slot], [&"mod_takt_chip", &"mod_beacon"], "Waffe unverändert")
	t.equal(run.storage, [&"mod_metronome"], "Lager unverändert")
	t.equal(run.place_from_storage(0, 0, slot, 0, false), "", "auf den Taktchip getauscht geht")


func test_installed_modules_move_and_swap_between_weapons() -> void:
	var run := _stop_run()
	var a: String = run.squad[0].equip_slots()[0]
	var b: String = run.squad[1].equip_slots()[0]
	run.squad[0].modules[a] = [&"mod_rapid_fire"]
	run.squad[1].modules[b] = [&"mod_bait"]
	t.equal(run.move_installed(0, a, 0, 1, b, 0), "", "auf belegten Platz: tauschen")
	t.equal(run.squad[0].modules[a], [&"mod_bait"], "hin")
	t.equal(run.squad[1].modules[b], [&"mod_rapid_fire"], "und her")
	t.equal(run.move_installed(0, a, 0, 1, b, -1), "", "auf freien Platz: umsetzen")
	t.ok(not run.squad[0].modules.has(a), "die alte Waffe ist leer")
	t.equal(run.squad[1].modules[b], [&"mod_rapid_fire", &"mod_bait"], "beide in der neuen")
	t.ok(run.storage.is_empty(), "das Lager bleibt aus dem Spiel")


func test_buying_straight_into_a_weapon() -> void:
	var run := _stop_run()
	var slot: String = run.squad[0].equip_slots()[0]
	run.shop_offers = [{"module_id": &"mod_bait", "sold": false},
		{"module_id": &"mod_twin_barrel", "sold": false}]
	run.credits = 20
	t.equal(run.buy_into(0, 0, slot, -1), "", "gekauft und eingesetzt")
	t.equal(run.squad[0].modules[slot], [&"mod_bait"], "steckt in der Waffe")
	t.equal(run.credits, 20 - RunState.shop_price(ModuleData.get_module(&"mod_bait")), "bezahlt")
	t.ok(run.shop_offers[0]["sold"], "verkauft")
	t.ok(run.storage.is_empty(), "das Lager bleibt leer")
	t.equal(run.buy_into(0, 0, slot, -1), "verkauft", "nur einmal")
	while not run.storage_full():
		run.storage.append(&"mod_rapid_fire")
	t.ok(run.buy_into(1, 0, slot, 0, false) != "", "tauschen bei vollem Lager geht nicht")
	t.equal(run.buy_into(1, 0, slot, 1), "", "auf freien Platz auch bei vollem Lager")
	run.credits = 0
	run.shop_offers.append({"module_id": &"mod_amplifier", "sold": false})
	t.equal(run.buy_into(2, 0, slot, 2), "zu wenig Credits", "ohne Credits nicht")


## Ablegen auf ein Modul, mit dem es ein Rezept ergibt: zusammenfuegen statt
## tauschen (19. Nov. 2026) -- aus dem Lager, aus einer Waffe, aus dem Laden.
func test_dropping_on_a_partner_fuses_in_place() -> void:
	var run := _stop_run()
	var a: String = run.squad[0].equip_slots()[0]
	var b: String = run.squad[1].equip_slots()[0]
	run.squad[0].modules[a] = [&"mod_rapid_fire"]
	run.storage.append(&"mod_twin_barrel")
	t.equal(run.place_from_storage(0, 0, a, 0), "", "aus dem Lager")
	t.equal(run.squad[0].modules[a], [&"mod_gunslinger"], "Gunslinger an seinem Platz")
	t.ok(run.storage.is_empty(), "die Zutat ist verbraucht")
	run.squad[1].modules[b] = [&"mod_bait"]
	run.squad[0].modules[a] = [&"mod_gunslinger", &"mod_beacon"]
	t.equal(run.move_installed(0, a, 1, 1, b, 0), "", "aus einer Waffe")
	t.equal(run.squad[1].modules[b], [&"mod_orbit"], "Orbit-Fokus")
	t.equal(run.squad[0].modules[a], [&"mod_gunslinger"], "der alte Platz ist frei")
	run.credits = 30
	run.shop_offers = [{"module_id": &"mod_amplifier", "sold": false},
		{"module_id": &"mod_capacitor", "sold": false}]
	run.squad[1].modules[b] = [&"mod_heavy_edge"]
	t.equal(run.buy_into(0, 1, b, 0), "", "aus dem Laden in die Waffe")
	t.equal(run.squad[1].modules[b], [&"mod_overload"], "Überladung")
	t.equal(run.credits, 24, "bezahlt")
	run.storage.append(&"mod_armor_plate")
	t.equal(run.buy_onto_storage(1, 0, false), "", "aus dem Laden aufs Lager-Modul (Probe)")
	t.equal(run.storage, [&"mod_armor_plate"], "Probe ändert nichts")
	t.equal(run.buy_onto_storage(1, 0), "", "gekauft und zusammengefügt")
	t.equal(run.storage, [&"mod_bulwark"], "Bollwerk")
	t.equal(run.buy_onto_storage(0, 0), "verkauft", "nur einmal")


func test_a_recipe_bios_fuses_from_recipe_or_ingredients() -> void:
	var run := _stop_run()
	run.storage.append_array([&"bios_metronome", &"mod_takt_chip"])
	var entry: Array = run.recipe_book().filter(func(e): return e["module"].id == &"mod_metronome")
	t.equal(entry.size(), 1, "der Taktgeber steht im Rezeptbuch")
	t.ok(entry[0]["ready"], "Rezept + BIOS reicht")
	t.ok(run.craft(&"mod_metronome"), "verschmolzen")
	t.equal(run.storage, [&"mod_metronome"], "BIOS und Rezept sind weg")
	var raw := _stop_run()
	raw.storage.append_array([&"mod_rapid_fire", &"bios_metronome", &"mod_amplifier"])
	t.ok(raw.craft(&"mod_metronome"), "Zutat + Zutat + BIOS geht auch")
	t.equal(raw.storage, [&"mod_metronome"], "alles verbraucht")
	var none := _stop_run()
	none.storage.append(&"mod_takt_chip")
	t.ok(none.recipe_book().filter(func(e): return e["module"].id == &"mod_metronome").is_empty(),
		"ohne BIOS kein Eintrag")


func test_only_one_bios_recipe_per_drome() -> void:
	var run := _stop_run()
	var slot: String = run.squad[0].equip_slots()[0]
	run.storage.append_array([&"mod_metronome", &"mod_phase"])
	t.ok(run.install_module(0, 0, slot), "erstes BIOS-Rezept")
	t.ok(not run.install_module(0, 0, slot), "ein zweites nicht")
	t.ok(run.install_module(0, 1, run.squad[1].equip_slots()[0]), "in einem anderen DROME schon")


func test_a_held_recipe_bios_pulls_its_ingredients_in_the_shop() -> void:
	var run := _stop_run()
	run.storage.append(&"bios_revolver")
	t.equal(run._bios_missing(), [&"mod_rapid_fire", &"mod_twin_barrel"], "Gunslinger fehlt ganz")


func test_phase_break_hits_unshielded_foes_harder() -> void:
	var phase := _with(_vireo(), "equip_left", [&"mod_phase"])
	# Weit auseinander: die Praesenz des einen Molok faengt sonst mit ab.
	var battle := _battle([phase], [_molok(), _molok()],
		[Vector2i(10, 12), Vector2i(2, 2), Vector2i(12, 10)])
	var bearer: Unit = battle.units[0]
	var shielded: Unit = battle.units[1]
	var bare: Unit = battle.units[2]
	bare.shield = 0
	var attack: ActionData = bearer.mounts[0]["attack"]
	shielded.shield = 0
	var plain := battle.resolver.resolve_damage(shielded, 20, 0.0)["hp"] as int
	var hit := battle.resolver.apply_damage(bearer, bare, 20, attack)
	t.ok(hit > plain, "ohne Schild mehr (%d gegen %d)" % [hit, plain])
	battle.free()


# ---------------------------------------------------------------------------
# Neue Waffen (9. Nov. 2026)
# ---------------------------------------------------------------------------

func test_the_new_weapons_exist_with_their_classes() -> void:
	for entry in [[&"eq_bulwark_ram", "medium"], [&"eq_mortar", "heavy"], [&"eq_boomerang", "light"]]:
		var part := PartDB.get_part(entry[0])
		t.ok(part != null, "%s ist geladen" % entry[0])
		if part != null:
			t.equal(part.mount_class, entry[1], "%s ist %s" % [part.display_name, entry[1]])
			t.equal(part.actions.size(), 2, "%s: Angriff und Fähigkeit" % part.display_name)


func test_the_bulwark_ram_scales_with_integrity() -> void:
	var ram := DromeBuild.create("Molok", {"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core", "equip_left": &"eq_bulwark_ram"})
	var unit := Unit.create(ram, &"M", true)
	unit.init_realtime(0.0)
	var slam: ActionData = unit.mounts[0]["ability"]
	t.ok(slam.hp_scaling > 0.0, "der Rammstoß skaliert mit der Integrität")
	t.equal(slam.push_tiles, 1, "und stößt zurück")
	var plain := slam.copy()
	plain.hp_scaling = 0.0
	t.ok(unit.raw_damage(slam) >= unit.raw_damage(plain) + int(unit.stat("hp_max") * 0.08) - 1,
		"+8 %% der max. Integrität (%d gegen %d)" % [unit.raw_damage(slam), unit.raw_damage(plain)])
	unit.free()


func test_the_mortar_cannot_hit_close_targets() -> void:
	var strix := DromeBuild.create("Strix", {"body": &"strix_body", "head": &"strix_head",
		"feet": &"strix_feet", "core": &"strix_core", "equip_center": &"eq_mortar"})
	var battle := _battle([strix], [_molok(), _molok()],
		[Vector2i(10, 10), Vector2i(10, 9), Vector2i(10, 6)])
	var mortar: Unit = battle.units[0]
	var attack: ActionData = mortar.mounts[0]["attack"]
	t.equal(battle.resolver.target_blocker(mortar, battle.units[1].tile, attack), "Zu nah", "direkt daneben nicht")
	t.equal(battle.resolver.target_blocker(mortar, battle.units[2].tile, attack), "", "auf Abstand schon")
	t.ok(attack.aoe_radius >= 1 and attack.delay > 0.0, "Fläche mit Verzögerung")
	battle.free()


func test_the_boomerang_hits_harder_on_the_move() -> void:
	var unit := Unit.create(_vireo(&"eq_boomerang"), &"V", true)
	unit.init_realtime(0.0)
	var attack: ActionData = unit.mounts[0]["attack"]
	t.equal(attack.shots, 2, "hin und zurück: zwei Treffer")
	unit.still_time = 0.2
	var moving := unit.raw_damage(attack)
	unit.still_time = 5.0
	var standing := unit.raw_damage(attack)
	t.ok(moving > standing, "in Bewegung mehr (%d gegen %d)" % [moving, standing])
	unit.free()


func test_a_battle_with_the_new_weapons_runs_to_the_end() -> void:
	var ram := DromeBuild.create("Molok", {"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core", "equip_left": &"eq_bulwark_ram"})
	var strix := DromeBuild.create("Strix", {"body": &"strix_body", "head": &"strix_head",
		"feet": &"strix_feet", "core": &"strix_core", "equip_center": &"eq_mortar"})
	var battle := BattleManager.new()
	battle.setup(4242, [ram, strix, _vireo(&"eq_boomerang")], [_molok(), _vireo(), _vireo()])
	var outcome := battle.run_to_end()
	t.ok(outcome != BattleManager.Outcome.RUNNING, "der Kampf endet (%s)" % BattleManager.outcome_label(outcome))
	battle.free()


func test_the_orbit_focus_roots_the_target_of_the_ability() -> void:
	var orbit := _with(_vireo(), "equip_left", [&"mod_orbit"])
	var battle := _battle([orbit], [_vireo(), _vireo()],
		[Vector2i(10, 13), Vector2i(10, 10), Vector2i(11, 10)])
	var bearer: Unit = battle.units[0]
	var foe: Unit = battle.units[1]
	var other: Unit = battle.units[2]
	battle.brain._after_ability(bearer, bearer.mounts[0]["ability"],
		{"tile": foe.tile, "target": foe}, bearer.mounts[0]["fx"])
	t.ok(foe.is_rooted(), "das Ziel ist gewurzelt")
	t.ok(not other.is_rooted(), "der Nachbar nicht")
	t.ok(not foe.is_stunned(), "greift aber weiter an")
	foe.target_id = bearer.unit_id
	var before := foe.tile
	foe.step_left = 0.0
	battle.brain.update(foe, 0.05)
	t.equal(foe.tile, before, "und läuft nicht")
	foe.tick_statuses(2.1)
	t.ok(not foe.is_rooted(), "nach 2 s vorbei")
	battle.free()


func test_the_gravity_bios_roots_a_second_foe() -> void:
	var gravity := _with(_vireo(), "equip_left", [&"mod_gravity"])
	var battle := _battle([gravity], [_vireo(), _vireo()],
		[Vector2i(10, 13), Vector2i(10, 10), Vector2i(11, 10)])
	var bearer: Unit = battle.units[0]
	var foe: Unit = battle.units[1]
	var other: Unit = battle.units[2]
	battle.brain._after_ability(bearer, bearer.mounts[0]["ability"],
		{"tile": foe.tile, "target": foe}, bearer.mounts[0]["fx"])
	t.ok(foe.is_rooted() and other.is_rooted(), "beide gewurzelt")
	battle.free()