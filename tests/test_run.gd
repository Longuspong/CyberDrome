extends RefCounted

## Der Lauf (Roguelike, scripts/core/run_state.gd).

var t


func test_a_run_starts_with_two_armed_dromes_and_free_holders() -> void:
	var run := RunState.start(11)
	t.equal(run.squad.size(), 2, "zwei Start-DROMEs")
	t.equal(run.lives, RunState.max_lives(), "volle Leben")
	for build in run.squad:
		t.ok(not build.weapons().is_empty(), "%s traegt eine Waffe" % build.display_name)
		var free: Array = build.equip_slots().filter(func(s): return build.part_in(s) == null)
		t.ok(not free.is_empty(), "%s hat einen freien Halter fuer Beute" % build.display_name)
		t.ok(build.is_valid(), "%s ist gueltig" % build.display_name)


func test_the_same_seed_gives_the_same_run() -> void:
	var a := RunState.start(4242)
	var b := RunState.start(4242)
	t.equal(a.battle_seed(), b.battle_seed(), "gleicher Kampf-Seed")
	t.equal(a.preview()["mutator"], b.preview()["mutator"], "gleicher Mutator")
	a.round = 2
	t.ok(a.battle_seed() != b.battle_seed(), "jede Runde hat einen eigenen Kampf")


## Die Vorschau darf keine Schaetzung sein: sie muss genau den Kampf zeigen,
## den setup() dann aufbaut.
func test_the_preview_matches_the_real_battle() -> void:
	for seed_value in [101, 202, 303, 404, 505]:
		var info := BattleManager.preview_conditions(seed_value)
		var battle := BattleManager.new()
		battle.setup(seed_value, RunState.starter_squad())
		t.equal(info["region"], battle.region.display_name, "Region stimmt (Seed %d)" % seed_value)
		t.equal(info["mutator"], battle.mutator.display_name, "Mutator stimmt (Seed %d)" % seed_value)
		battle.free()


func test_enemy_power_follows_a_fixed_rising_curve() -> void:
	var run := RunState.start(7)
	var first := run.enemy_power()
	run.round = 5
	var later := run.enemy_power()
	t.ok(later > first, "die Gegner werden staerker (%d -> %d)" % [int(first), int(later)])
	# Unabhaengig vom eigenen Squad: Beute darf den Gegner nicht mitziehen.
	run.squad[0].slots["equip_right"] = &"eq_pulse_blaster"
	t.equal(run.enemy_power(), later, "eigene Beute aendert die Gegnerstaerke nicht")


func test_a_loss_costs_a_life_and_the_run_goes_on() -> void:
	var run := RunState.start(8)
	run.record_result(BattleManager.Outcome.DEFEAT, [])
	t.equal(run.lives, RunState.max_lives() - 1, "ein Leben weniger")
	t.equal(run.round, 2, "weiter zur naechsten Runde")
	t.equal(run.phase, RunState.Phase.PREPARE, "keine Belohnung nach einer Niederlage")


func test_losing_all_lives_ends_the_run() -> void:
	var run := RunState.start(9)
	for _i in RunState.max_lives():
		run.record_result(BattleManager.Outcome.DEFEAT, [])
	t.equal(run.phase, RunState.Phase.LOST, "keine Leben mehr: verloren")
	t.ok(run.is_over(), "der Lauf ist vorbei")


func test_a_win_offers_rewards_from_the_enemy_pool() -> void:
	var run := RunState.start(10)
	var pool := [&"eq_deflector", &"eq_rune_staff", &"eq_drone_pod", &"eq_holo_boost"]
	run.record_result(BattleManager.Outcome.VICTORY, pool)
	t.equal(run.phase, RunState.Phase.REWARD, "nach dem Sieg wird gewaehlt")
	t.equal(run.reward_options.size(), int(RunState.cfg().get("reward_choices", 3)),
		"drei Belohnungen")
	for option in run.reward_options:
		if option["kind"] == "part":
			t.ok(pool.has(option["part_id"]), "%s kommt aus der Gegnerausruestung" % option["title"])


func test_a_part_reward_goes_where_the_player_puts_it() -> void:
	var run := RunState.start(12)
	run.record_result(BattleManager.Outcome.VICTORY, [&"eq_deflector", &"eq_rune_staff", &"eq_holo_boost"])
	var index := -1
	for i in run.reward_options.size():
		if run.reward_options[i]["kind"] == "part":
			index = i
			break
	t.ok(index >= 0, "es gibt ein Teil zur Wahl")
	if index < 0:
		return
	var part_id: StringName = run.reward_options[index]["part_id"]
	var spots: Array = run.placements_for(part_id).filter(func(p): return p["valid"] and p["current"] == "")
	t.ok(not spots.is_empty(), "%s passt in einen freien Halter" % part_id)
	if spots.is_empty():
		return
	var spot: Dictionary = spots[0]
	t.ok(run.choose_reward(index, spot), "die Wahl wird angenommen")
	var build: DromeBuild = run.squad[int(spot["drome"])]
	t.equal(build.slots.get(spot["slot"]), part_id, "das Teil steckt dort, wo es hin sollte")
	t.equal(run.round, 2, "danach geht es in die naechste Runde")


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
