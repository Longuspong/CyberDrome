extends RefCounted

## Der Lauf (Roguelike, scripts/core/run_state.gd).

var t


func test_a_run_without_a_squad_starts_with_the_four_standard_dromes() -> void:
	var run := RunState.start(11)
	t.equal(run.squad.size(), 4, "vier Standard-DROMEs")
	t.equal(run.lives, RunState.max_lives(), "volle Leben")
	for build in run.squad:
		t.ok(build.is_valid(), "%s ist gueltig" % build.display_name)


## Der Fehler aus dem Spiel: der Lauf nahm fest Vireo + Nimbus statt des
## eigenen Squads.
func test_a_run_starts_with_the_chosen_squad_as_a_copy() -> void:
	var roster := Roster.new()
	roster.seed_starter()
	var molok := roster.build_for(roster.entries[1])
	var strix := roster.build_for(roster.entries[3])
	var run := RunState.start(15, [molok, strix])
	t.equal(run.squad.size(), 2, "genau die mitgenommenen DROMEs")
	t.equal(run.squad[0].display_name, molok.display_name, "der Molok ist dabei")
	t.equal(run.squad[1].slots, strix.slots, "mit seiner Ausstattung")
	run.squad[0].slots.erase("core")
	t.ok(molok.slots.has("core"), "der Lauf arbeitet auf einer Kopie")


func test_the_three_tiers_differ_in_strength() -> void:
	var run := RunState.start(16)
	var easy := run.enemy_power(RunState.Tier.EASY)
	var normal := run.enemy_power(RunState.Tier.NORMAL)
	var elite := run.enemy_power(RunState.Tier.ELITE)
	t.ok(easy < normal and normal < elite, "Leicht < Normal < Elite (%d/%d/%d)"
		% [int(easy), int(normal), int(elite)])
	t.ok(run.battle_seed(0) != run.battle_seed(2), "jede Stufe ist ein eigener Kampf")


## Was die Vorschau zeigt, ist genau das, wogegen gekaempft wird.
func test_the_previewed_enemies_are_the_battle_enemies() -> void:
	var run := RunState.start(17)
	run.choose_tier(RunState.Tier.ELITE)
	var shown: Array = run.preview()["enemy_builds"]
	t.ok(not shown.is_empty(), "es werden Gegner gezeigt")
	var battle := BattleManager.new()
	battle.setup(run.battle_seed(), run.squad, run.enemies())
	var foes := battle.units.filter(func(u): return not u.is_player)
	t.equal(foes.size(), shown.size(), "gleich viele Gegner")
	for i in shown.size():
		t.equal(foes[i].build.slots, shown[i].slots, "Gegner %d wie gezeigt" % i)
	battle.free()


func test_an_elite_win_guarantees_something_rare() -> void:
	for seed_value in 20:
		var run := RunState.start(1800 + seed_value)
		run.choose_tier(RunState.Tier.ELITE)
		run.record_result(BattleManager.Outcome.VICTORY, [&"eq_pulse_blaster", &"eq_rune_staff"])
		t.equal(run.last_loot.size(), 1, "eine Beute, kein Notstrom bei Elite")
		var item: Dictionary = run.last_loot[0]
		t.ok(item.get("rare", false), "%s ist selten" % item["title"])
		t.ok(item["kind"] in ["part", "drome"], "Teil oder DROME, keine Credits")
		if item["kind"] == "part":
			t.ok(PartDB.get_part(item["part_id"]).mount_class != "light",
				"%s ist mittel oder schwer" % item["title"])


func test_loot_is_rolled_without_a_choice() -> void:
	# 6i: nach dem Sieg wird gewuerfelt -- Credits oder ein Teil, sofort verteilt.
	var kinds := {}
	for seed_value in 40:
		var run := RunState.start(3000 + seed_value)
		run.record_result(BattleManager.Outcome.VICTORY, [&"eq_deflector"])
		t.equal(run.phase, RunState.Phase.STOP, "gleich der Zwischenstopp")
		t.ok(not run.last_loot.is_empty(), "es gibt Beute")
		var item: Dictionary = run.last_loot[0]
		kinds[item["kind"]] = true
		var win := int(RunState.tier_cfg(RunState.Tier.NORMAL).get("credits", 0))
		if item["kind"] == "part":
			t.equal(item["part_id"], &"eq_deflector", "das Teil kommt aus der Gegnerausruestung")
			t.equal(run.bag, [&"eq_deflector"], "und liegt in der Tasche")
			t.ok(run.storage.is_empty(), "nicht im Lager")
			t.equal(item["where"], "tasche", "mit Ort")
			t.equal(run.credits, win, "nur die Credits fuer den Sieg")
		elif item["kind"] == "credits":
			t.ok(run.bag.is_empty(), "kein Teil")
			t.equal(run.credits, win + int(item["amount"]), "Beute-Credits obendrauf")
	t.ok(kinds.has("part") and kinds.has("credits"), "beides kommt vor")


func test_a_new_drome_comes_in_the_drome_rounds() -> void:
	var run := RunState.start(31, RunState.standard_squad().slice(0, 2))
	run.round = int((RunState.cfg().get("new_drome_rounds", [2]) as Array)[0])
	run.record_result(BattleManager.Outcome.VICTORY, [])
	t.equal(run.last_loot[0]["kind"], "drome", "ein DROME")
	t.equal(run.squad.size(), 3, "kommt in den Lauf-Squad")
	t.equal(run.last_loot[0]["where"], "squad", "mit Ort")
	var full := RunState.start(32)
	full.round = run.round
	full.record_result(BattleManager.Outcome.VICTORY, [])
	t.equal(full.squad.size(), 4, "voller Squad bleibt voll")
	t.equal(full.home_queue.size(), 1, "der DROME geht nach Hause")
	t.equal(full.last_loot[0]["where"], "home", "mit Ort")


func test_loot_parts_need_no_storage_room() -> void:
	var run := RunState.start(33)
	for _i in RunState.storage_size():
		run.storage.append(&"mod_capacitor")
	var id := _win_a_part(run, [&"eq_deflector"])
	t.equal(id, &"eq_deflector", "ein Teil gewuerfelt")
	t.equal(run.storage.size(), RunState.storage_size(), "das Lager bleibt, wie es ist")
	t.equal(run.bag, [id], "das Teil liegt in der Tasche")


func test_the_same_run_rolls_the_same_loot() -> void:
	var a := RunState.start(4243)
	var b := RunState.start(4243)
	t.equal(a.roll_loot([&"eq_deflector", &"eq_hammer"]), b.roll_loot([&"eq_deflector", &"eq_hammer"]),
		"gleicher Seed, gleiche Beute")


func test_the_same_seed_gives_the_same_run() -> void:
	var a := RunState.start(4242)
	var b := RunState.start(4242)
	t.equal(a.battle_seed(), b.battle_seed(), "gleicher Kampf-Seed")
	t.equal(a.preview()["region"], b.preview()["region"], "gleiche Region")
	a.round = 2
	t.ok(a.battle_seed() != b.battle_seed(), "jede Runde hat einen eigenen Kampf")


## Die Vorschau darf keine Schaetzung sein: sie muss genau den Kampf zeigen,
## den setup() dann aufbaut.
func test_the_preview_matches_the_real_battle() -> void:
	for seed_value in [101, 202, 303, 404, 505]:
		var info := BattleManager.preview_conditions(seed_value)
		var battle := BattleManager.new()
		battle.setup(seed_value, RunState.standard_squad())
		t.equal(info["region"], battle.region.display_name, "Region stimmt (Seed %d)" % seed_value)
		battle.free()


## Der ganze Weg wie im Spiel: Lauf starten (GameState), Vorschau zeigen,
## "Kampf starten" (begin_run_battle) und setup() mit GameState.battle_seed.
## Dazu ein Speichern/Laden-Durchlauf: Laeufe werden derzeit nicht
## gespeichert, aber ein JSON-Speicherstand liest Zahlen als float zurueck.
## randi() liefert Seeds bis 2^32 -- weit unter 2^53, also verlustfrei;
## der Test haelt das fest, auch fuer die groessten Seeds.
func test_preview_region_survives_the_way_into_battle_and_a_save() -> void:
	var saved_run = GameState.run
	var saved_squad = GameState.squad
	for seed_value in [1, 2812845978, 4294967295, 2147483647, 93758548]:
		GameState.start_run(seed_value)
		var run: RunState = GameState.run
		for which in 3:
			run.choose_tier(which)
			var shown: Dictionary = run.preview()
			# Speichern/Laden: run_seed, Runde und Stufe als JSON hin und zurueck.
			var text := JSON.stringify({"run_seed": run.run_seed, "round": run.round,
				"tier": run.tier})
			var data: Dictionary = JSON.parse_string(text)
			var loaded := RunState.start(int(data["run_seed"]))
			loaded.round = int(data["round"])
			loaded.choose_tier(int(data["tier"]))
			t.equal(loaded.run_seed, run.run_seed, "run_seed uebersteht JSON (%d)" % seed_value)
			t.equal(loaded.preview()["region"], shown["region"],
				"Region nach Laden wie gezeigt (%d, Stufe %d)" % [seed_value, which])

			GameState.begin_run_battle()
			t.equal(GameState.battle_seed, shown["seed"], "Kampf-Seed wie in der Vorschau")
			var battle := BattleManager.new()
			battle.setup(GameState.battle_seed, GameState.squad, GameState.enemy_override)
			t.equal(battle.region.display_name, shown["region"],
				"Kampf in der gezeigten Region (%d, Stufe %d)" % [seed_value, which])
			battle.free()
			GameState.in_run_battle = false
			GameState.enemy_override = []
			GameState.battle_seed = 0
			GameState.clear_chaos_run()
	GameState.run = saved_run
	GameState.squad = saved_squad


func test_enemy_power_follows_a_fixed_rising_curve() -> void:
	var run := RunState.start(7)
	var first := run.enemy_power()
	run.round = 5
	var later := run.enemy_power()
	t.ok(later > first, "die Gegner werden staerker (%d -> %d)" % [int(first), int(later)])
	# Unabhaengig vom eigenen Squad: Beute darf den Gegner nicht mitziehen.
	run.squad[0].slots.erase("equip_right")
	t.equal(run.enemy_power(), later, "eigene Beute aendert die Gegnerstaerke nicht")


func test_a_loss_costs_a_life_and_the_run_goes_on() -> void:
	var run := RunState.start(8)
	run.record_result(BattleManager.Outcome.DEFEAT, [])
	t.equal(run.lives, RunState.max_lives() - 1, "ein Leben weniger")
	t.equal(run.phase, RunState.Phase.STOP, "keine Belohnung, aber ein Zwischenstopp")
	t.equal(run.credits, int(RunState.cfg().get("loss_credits", 0)), "Trostgeld")
	run.continue_run()
	t.equal(run.round, 2, "weiter zur naechsten Runde")
	t.equal(run.phase, RunState.Phase.PREPARE, "naechster Kampf")


func test_losing_all_lives_ends_the_run() -> void:
	var run := RunState.start(9)
	for _i in RunState.max_lives():
		run.record_result(BattleManager.Outcome.DEFEAT, [])
		run.continue_run()
	t.equal(run.phase, RunState.Phase.LOST, "keine Leben mehr: verloren")
	t.ok(run.is_over(), "der Lauf ist vorbei")


## Gewinnt einen Kampf, dessen Beute ein Teil ist -- sucht dafuer einen
## Lauf-Seed, bei dem ein Teil gewuerfelt wird. Danach ist der Lauf im
## Zwischenstopp.
func _win_a_part(run: RunState, pool: Array) -> StringName:
	var base := run.run_seed
	for offset in 200:
		run.run_seed = base + offset
		var loot := run.roll_loot(pool)
		if loot[0]["kind"] == "part":
			run.record_result(BattleManager.Outcome.VICTORY, pool)
			return run.last_loot[0]["part_id"]
	return &""


func test_a_part_reward_lands_in_the_storage() -> void:
	var run := RunState.start(12)
	var id := _win_a_part(run, [&"eq_deflector", &"eq_rune_staff", &"eq_neon_blaster"])
	t.ok(id != &"", "es gab ein Teil")
	t.equal(run.phase, RunState.Phase.STOP, "Zwischenstopp nach dem Sieg")
	t.equal(run.bag, [id], "das Teil liegt in der Tasche")
	t.equal(run.credits, int(RunState.tier_cfg(RunState.Tier.NORMAL).get("credits", 0)),
		"Credits fuer den Sieg")
	t.equal(run.round, 1, "die Runde wechselt erst mit 'weiter'")
	run.continue_run()
	t.equal(run.round, 2, "danach geht es in die naechste Runde")
	t.equal(run.phase, RunState.Phase.PREPARE, "und zur Gegnerwahl")


func test_weapons_are_fixed_during_the_run() -> void:
	# MODULE_KONZEPT.md: im Lauf wird keine Waffe getauscht.
	var run := RunState.start(21)
	var before: Array = run.squad.map(func(b): return b.slots.duplicate())
	_win_a_part(run, [&"eq_plasma_blade"])
	t.ok(not run.has_method("equip_from_storage"), "kein Einbauen im Lauf")
	t.ok(not run.has_method("unequip"), "kein Ausbauen im Lauf")
	t.equal(run.squad.map(func(b): return b.slots.duplicate()), before, "die Waffen bleiben")


func test_selling_a_module_from_the_storage() -> void:
	var run := RunState.start(23)
	run.phase = RunState.Phase.STOP
	run.storage.append(&"mod_capacitor")
	var value := run.sell(0)
	t.equal(value, ModuleData.sell_value(ModuleData.get_module(&"mod_capacitor")), "Verkaufspreis")
	t.equal(run.credits, value, "Credits gutgeschrieben")
	t.ok(run.storage.is_empty(), "das Lager ist leer")


func test_loot_goes_home_at_the_end_without_doubling_the_start_gear() -> void:
	var run := RunState.start(24)
	var id := _win_a_part(run, [&"eq_plasma_blade"])
	run.phase = RunState.Phase.STOP
	run.abandon()
	t.equal(run.phase, RunState.Phase.LOST, "aufgegeben")
	t.equal(run.home_queue.map(func(item): return item["part_id"]), [id],
		"nur die Beute geht nach Hause")
	t.ok(run.bag.is_empty(), "die Tasche ist geleert")


func test_winning_the_last_round_wins_the_run() -> void:
	var run := RunState.start(13)
	run.round = RunState.rounds_total()
	run.record_result(BattleManager.Outcome.VICTORY, [])
	t.equal(run.phase, RunState.Phase.WON, "letzte Runde gewonnen: Lauf gewonnen")


func test_a_new_drome_reward_comes_armed() -> void:
	var run := RunState.start(14)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for _i in 8:
		var option := run._drome_reward(rng)
		t.ok(StringName(option["weapon_id"]) != &"", "%s kommt mit Waffe" % option["title"])


func test_enemy_power_ignores_how_strong_the_chosen_squad_is() -> void:
	# 6g: die Gegner richten sich nach Region und Runde, nicht nach dem Aufbau.
	# Ein schwach bestueckter Squad trifft auf dieselben Gegner wie der volle.
	var full := RunState.start(11)
	var bare: Array = []
	for build in RunState.standard_squad():
		var copy: DromeBuild = build.clone()
		copy.slots.erase("equip_right")
		bare.append(copy)
	var weak := RunState.start(11, bare)
	t.equal(weak.enemy_power(), full.enemy_power(), "gleiche Gegnerstaerke")


func test_enemies_carry_fitting_modules_later_in_the_run() -> void:
	# 6i: Gegner tragen Module, handverlesen -- passend zur Waffe, keine doppelt.
	var early := RunState.start(41)
	for build in early.enemies(RunState.Tier.NORMAL):
		t.ok(build.modules.is_empty(), "Runde 1: noch keine Module")
	var run := RunState.start(42)
	run.round = RunState.rounds_total()
	var count := run.enemy_module_count(RunState.Tier.ELITE)
	t.ok(count >= 2, "spaet und Elite: mehrere Module (%d)" % count)
	var recipes := 0
	for build in run.enemies(RunState.Tier.ELITE):
		var all: Array = []
		for slot in build.equip_slots():
			for module in build.modules_in(slot):
				all.append(module.id)
				t.ok(module.fits(build.part_in(slot)), "%s passt zur Waffe" % module.display_name)
				if module.is_recipe():
					recipes += 1
		t.ok(not all.is_empty(), "%s traegt Module" % build.display_name)
		t.ok(all.size() <= ModuleData.slots_for(build), "nicht mehr als Plaetze")
		var unique := {}
		for id in all:
			unique[id] = true
		t.equal(unique.size(), all.size(), "keines doppelt")
	t.ok(recipes > 0, "spaet gibt es Rezepte")
	t.equal(run.enemies(RunState.Tier.ELITE), run.enemies(RunState.Tier.ELITE),
		"Vorschau und Kampf sehen dieselben Module")


func test_easy_enemies_carry_fewer_modules() -> void:
	var run := RunState.start(43)
	run.round = 4
	t.ok(run.enemy_module_count(RunState.Tier.EASY) < run.enemy_module_count(RunState.Tier.ELITE),
		"Leicht weniger als Elite")


func test_enemies_level_up_with_round_and_tier() -> void:
	# Leitplanke 9. Nov. 2026: Gegner-Level nach Runde und Stufe (run.enemy_levels).
	var run := RunState.start(44)
	t.equal(run.enemy_levels(RunState.Tier.NORMAL), {"drome": 0, "weapon": 0}, "Runde 1 Normal: Level 0")
	run.round = RunState.rounds_total()
	var late := run.enemy_levels(RunState.Tier.ELITE)
	t.ok(late["drome"] > 0 and late["weapon"] > late["drome"], "spaet Elite: DROME und Waffen gelevelt")
	for build in run.enemies(RunState.Tier.ELITE):
		t.equal(build.drome_level, late["drome"], "%s traegt das DROME-Level" % build.display_name)
		for slot in build.equip_slots():
			if build.part_in(slot) != null:
				t.equal(build.weapon_level(slot), late["weapon"], "und das Waffenlevel")
	t.ok(run.enemy_levels(RunState.Tier.EASY)["weapon"] < late["weapon"], "Leicht darunter")
