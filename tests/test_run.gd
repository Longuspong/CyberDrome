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
	t.equal(run.phase, RunState.Phase.STOP, "danach der Zwischenstopp")
	run.continue_run()
	t.equal(run.round, 2, "weiter zur naechsten Runde")


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


## Gewinnt einen Kampf und nimmt das erste Teil als Belohnung -- danach ist
## der Lauf im Zwischenstopp, das Teil im Lager.
func _win_a_part(run: RunState, pool: Array) -> StringName:
	run.record_result(BattleManager.Outcome.VICTORY, pool)
	for i in run.reward_options.size():
		if run.reward_options[i]["kind"] == "part":
			var id: StringName = run.reward_options[i]["part_id"]
			run.choose_reward(i)
			return id
	return &""


func test_a_part_reward_lands_in_the_storage() -> void:
	var run := RunState.start(12)
	var id := _win_a_part(run, [&"eq_deflector", &"eq_rune_staff", &"eq_holo_boost"])
	t.ok(id != &"", "es gab ein Teil zur Wahl")
	t.equal(run.phase, RunState.Phase.STOP, "Zwischenstopp nach der Belohnung")
	t.equal(run.storage, [id], "das Teil liegt im Lager")
	t.equal(run.credits, int(RunState.tier_cfg(RunState.Tier.NORMAL).get("credits", 0)),
		"Credits fuer den Sieg")
	t.equal(run.round, 1, "die Runde wechselt erst mit 'weiter'")
	run.continue_run()
	t.equal(run.round, 2, "danach geht es in die naechste Runde")
	t.equal(run.phase, RunState.Phase.PREPARE, "und zur Gegnerwahl")


func test_equipping_from_storage_swaps_with_the_old_weapon() -> void:
	var run := RunState.start(21)
	var id := _win_a_part(run, [&"eq_plasma_blade"])
	var spots: Array = run.equip_options(0).filter(func(o): return o["allowed"])
	t.ok(not spots.is_empty(), "%s passt irgendwo" % id)
	if spots.is_empty():
		return
	var spot: Dictionary = spots[0]
	var build: DromeBuild = run.squad[int(spot["drome"])]
	var old := build.part_in(spot["slot"])
	t.ok(run.equip_from_storage(0, int(spot["drome"]), spot["slot"]), "eingebaut")
	t.equal(build.slots.get(spot["slot"]), id, "steckt im Halter")
	if old != null:
		t.equal(run.storage, [old.id], "die alte Waffe liegt im Lager")
	else:
		t.ok(run.storage.is_empty(), "das Lager ist leer")


func test_options_name_the_reason_when_a_weapon_does_not_fit() -> void:
	var run := RunState.start(22)
	run.phase = RunState.Phase.STOP
	run.storage.append(&"eq_hammer")
	var refused: Array = run.equip_options(0).filter(func(o): return not o["allowed"])
	t.ok(not refused.is_empty(), "ein schwerer Hammer passt nicht ueberall")
	for option in refused:
		t.ok(str(option["detail"]) != "", "mit Grund: %s" % option["detail"])
		t.ok(not run.equip_from_storage(0, int(option["drome"]), option["slot"]),
			"und laesst sich dort nicht einbauen")


func test_unequip_sell_and_the_storage_limit() -> void:
	var run := RunState.start(23)
	run.phase = RunState.Phase.STOP
	var build: DromeBuild = run.squad[0]
	var slot: String = build.equip_slots()[0]
	var part := build.part_in(slot)
	t.ok(run.unequip(0, slot), "ausbauen ins Lager")
	t.equal(run.storage, [part.id], "liegt im Lager")
	t.equal(build.part_in(slot), null, "der Halter ist leer")
	var value := run.sell(0)
	t.equal(value, RunState.sell_value(part), "Verkaufspreis nach Klasse")
	t.equal(run.credits, value, "Credits gutgeschrieben")
	for _i in RunState.storage_size():
		run.storage.append(&"eq_pulse_blaster")
	t.ok(run.storage_full(), "Lager voll")
	var other: DromeBuild = run.squad[1]
	t.ok(not run.unequip(1, other.equip_slots()[0]), "volles Lager: nichts mehr ausbauen")


func test_loot_goes_home_at_the_end_without_doubling_the_start_gear() -> void:
	var run := RunState.start(24)
	var id := _win_a_part(run, [&"eq_plasma_blade"])
	run.phase = RunState.Phase.STOP
	# Mitgenommene Ausruestung aus- und wieder eingebaut: keine Beute.
	var slot: String = run.squad[0].equip_slots()[0]
	run.unequip(0, slot)
	run.equip_from_storage(run.storage.size() - 1, 0, slot)
	run.abandon()
	t.equal(run.phase, RunState.Phase.LOST, "aufgegeben")
	t.equal(run.home_queue.map(func(item): return item["part_id"]), [id],
		"nur die Beute geht nach Hause")
	t.ok(run.storage.is_empty(), "das Lager ist geleert")


func test_sending_start_gear_home_does_not_double_it() -> void:
	var run := RunState.start(25)
	run.phase = RunState.Phase.STOP
	var slot: String = run.squad[0].equip_slots()[0]
	run.unequip(0, slot)
	t.ok(run.send_home(0), "nach Hause")
	t.ok(run.home_queue.is_empty(), "die Waffe liegt zuhause schon -- nicht doppelt")
	run.abandon()
	t.ok(run.home_queue.is_empty(), "auch am Ende nicht")


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
