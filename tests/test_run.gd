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
	var run := RunState.start(18)
	run.choose_tier(RunState.Tier.ELITE)
	run.record_result(BattleManager.Outcome.VICTORY, [&"eq_pulse_blaster", &"eq_rune_staff"])
	t.ok(not run.reward_options.is_empty(), "es gibt Belohnungen")
	for option in run.reward_options:
		t.ok(option.get("rare", false), "%s ist selten" % option["title"])
		if option["kind"] == "part":
			t.ok(PartDB.get_part(option["part_id"]).mount_class != "light",
				"%s ist mittel oder schwer" % option["title"])


func test_loot_can_be_sent_home() -> void:
	var run := RunState.start(19)
	run.record_result(BattleManager.Outcome.VICTORY, [&"eq_deflector", &"eq_rune_staff"])
	var index := -1
	for i in run.reward_options.size():
		if run.reward_options[i]["kind"] == "part":
			index = i
			break
	t.ok(index >= 0, "es gibt ein Teil zur Wahl")
	if index < 0:
		return
	var part_id: StringName = run.reward_options[index]["part_id"]
	var before: Array = run.squad.map(func(b): return b.slots.duplicate())
	t.ok(run.choose_reward(index, RunState.home_placement()), "nach Hause geht immer")
	t.equal(run.home_queue.size(), 1, "die Beute wartet auf die Heimreise")
	t.equal(run.home_queue[0]["part_id"], part_id, "das richtige Teil")
	t.equal(run.squad.map(func(b): return b.slots), before, "der Lauf-Squad bleibt unveraendert")
	t.equal(run.round, 2, "weiter zur naechsten Runde")


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
		battle.setup(seed_value, RunState.standard_squad())
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
	run.squad[0].slots.erase("equip_right")
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
	var spots: Array = run.placements_for(part_id).filter(
		func(p): return p["valid"] and not p.get("home", false))
	t.ok(not spots.is_empty(), "%s passt in einen Halter" % part_id)
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
