extends RefCounted

## Der Lauf (Roguelike, scripts/core/run_state.gd).

var t


## Ein Lauf, dessen Reihe in ``round_value`` einen Knoten dieser Stufe hat --
## der Knoten ist gewaehlt. Elite gibt es nicht in jeder Reihe, deshalb wird
## ab ``base_seed`` gesucht.
func _run_with_tier(which: int, base_seed: int, round_value: int = 3, mode: String = "story") -> RunState:
	for offset in 300:
		var run := RunState.start(base_seed + offset, [], mode)
		run.round = round_value
		run._pick_default_node()
		if run.choose_tier(which):
			return run
	return null


func test_a_run_without_a_squad_starts_with_three_standard_dromes() -> void:
	var run := RunState.start(11)
	t.equal(run.squad.size(), 3, "drei Standard-DROMEs (Squad aus drei)")
	t.equal(run.lives, RunState.max_lives(), "volle Leben")
	for build in run.squad:
		t.ok(build.is_valid(), "%s ist gültig" % build.display_name)


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
	t.ok(run.battle_seed(0) != run.battle_seed(2), "jeder Knoten ist ein eigener Kampf")


## Was die Vorschau zeigt, ist genau das, wogegen gekaempft wird.
func test_the_previewed_enemies_are_the_battle_enemies() -> void:
	var run := _run_with_tier(RunState.Tier.ELITE, 17)
	var shown: Array = run.preview()["enemy_builds"]
	t.ok(not shown.is_empty(), "es werden Gegner gezeigt")
	var battle := BattleManager.new()
	battle.setup(run.battle_seed(), run.squad, run.enemies())
	var foes := battle.units.filter(func(u): return not u.is_player)
	t.equal(foes.size(), shown.size(), "gleich viele Gegner")
	for i in shown.size():
		t.equal(foes[i].build.slots, shown[i].slots, "Gegner %d wie gezeigt" % i)
	battle.free()


## Seit 18. Nov. 2026: fest eine BIOS-Wahl nach jedem gewonnenen Elite-Kampf,
## bis drei vergeben sind -- danach sicher ein Lootcache.
func test_an_elite_win_guarantees_something_rare() -> void:
	for seed_value in 20:
		var run := _run_with_tier(RunState.Tier.ELITE, 1800 + seed_value * 301)
		run.record_result(BattleManager.Outcome.VICTORY, [&"eq_pulse_blaster", &"eq_rune_staff"])
		var kinds: Array = run.last_loot.map(func(i): return i["kind"])
		t.ok(kinds.has("bios"), "Elite: fest eine BIOS-Wahl")
		t.equal(run.bios_offers.size(), 3, "drei zur Wahl")
		t.equal(run.bios_given, 1, "mitgezählt")
		t.ok(not kinds.has("life"), "kein Notstrom bei Elite")
		t.equal(kinds[-1], "cache", "Elite: der Cache ist sicher")


func test_after_three_bios_an_elite_win_gives_a_cache() -> void:
	for seed_value in 10:
		var run := _run_with_tier(RunState.Tier.ELITE, 2400 + seed_value * 53)
		run.bios_given = RunState.bios_elite_wins()
		run.record_result(BattleManager.Outcome.VICTORY, [&"eq_pulse_blaster"])
		var kinds: Array = run.last_loot.map(func(i): return i["kind"])
		t.ok(not kinds.has("bios"), "keine vierte BIOS-Wahl")
		t.ok(run.bios_offers.is_empty(), "und kein Angebot")
		t.equal(kinds[-1], "cache", "stattdessen sicher ein Cache")


## Seit 14. Nov. 2026 Lootcaches statt Teilen und Credits (SPOT-Blatt
## Einsatz): ein Cache der Fraktion oder Platzhaltercoin, sofort verbucht.
func test_loot_is_a_cache_or_coins() -> void:
	var kinds := {}
	for seed_value in 40:
		var run := RunState.start(3000 + seed_value)
		run.record_result(BattleManager.Outcome.VICTORY, [&"eq_deflector"])
		t.equal(run.phase, RunState.Phase.STOP, "gleich der Zwischenstopp")
		var item: Dictionary = run.last_loot.filter(func(i): return i["kind"] in ["cache", "coins"])[0]
		kinds[item["kind"]] = true
		var win := int(RunState.tier_cfg(run.history[-1]["tier"]).get("credits", 0))
		t.equal(run.credits, win, "Credits nur für den Sieg")
		t.ok(run.bag.is_empty(), "keine Teile mehr als Beute")
		if item["kind"] == "cache":
			t.equal(run.run_caches.get("city", 0), 1, "ein Neon Cache im Einsatz")
			t.equal(item["title"], "Neon Cache", "mit Namen")
		else:
			t.equal(run.run_coins, int(item["amount"]), "Platzhaltercoin verbucht")
	t.ok(kinds.has("cache") and kinds.has("coins"), "beides kommt vor")


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
	t.equal(full.squad.size(), 3, "voller Squad bleibt voll")
	t.equal(full.home_queue.size(), 1, "der DROME geht nach Hause")
	t.equal(full.last_loot[0]["where"], "home", "mit Ort")


func test_a_loss_still_pays_coins() -> void:
	var run := RunState.start(33)
	run.record_result(BattleManager.Outcome.DEFEAT, [])
	t.equal(run.run_coins, int(RunState.loot_cfg().get("loss_coins", 3)), "Trostpreis in Platzhaltercoin")


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
		for which in run.available_nodes():
			run.choose_node(which)
			var shown: Dictionary = run.preview()
			# Speichern/Laden: run_seed, Runde und Knoten als JSON hin und zurueck.
			var text := JSON.stringify({"run_seed": run.run_seed, "round": run.round,
				"node": run.node})
			var data: Dictionary = JSON.parse_string(text)
			var loaded := RunState.start(int(data["run_seed"]))
			loaded.round = int(data["round"])
			loaded.choose_node(int(data["node"]))
			t.equal(loaded.run_seed, run.run_seed, "run_seed übersteht JSON (%d)" % seed_value)
			t.equal(loaded.preview()["region"], shown["region"],
				"Region nach Laden wie gezeigt (%d, Knoten %d)" % [seed_value, which])

			GameState.begin_run_battle()
			t.equal(GameState.battle_seed, shown["seed"], "Kampf-Seed wie in der Vorschau")
			var battle := BattleManager.new()
			battle.setup(GameState.battle_seed, GameState.squad, GameState.enemy_override,
				GameState.battle_region)
			t.equal(battle.region.display_name, shown["region"],
				"Kampf in der gezeigten Region (%d, Knoten %d)" % [seed_value, which])
			battle.free()
			GameState.in_run_battle = false
			GameState.enemy_override = []
			GameState.battle_region = &""
			GameState.battle_seed = 0
	GameState.run = saved_run
	GameState.squad = saved_squad


## Der gemeldete Fehler: der Lauf spielt in Neon City, die Kaempfe aber in
## gewuerfelten Regionen -- je nach Stufe ein anderes Gebiet. Ein Lauf bleibt
## in seinem Gebiet (config run.region), in jeder Runde und jeder Stufe.
func test_every_battle_of_a_run_is_in_the_run_region() -> void:
	var saved_run = GameState.run
	var saved_squad = GameState.squad
	var home: Terrain.Region = TerrainDB.get_region(StringName(str(RunState.cfg().get("region", "city"))))
	t.ok(home != null, "das Gebiet des Laufs ist eine bekannte Region")
	for seed_value in [3, 77, 2812845978]:
		GameState.start_run(seed_value)
		var run: RunState = GameState.run
		t.equal(run.region_id, home.id, "der Lauf kennt sein Gebiet")
		for round_value in [1, 4, RunState.rounds_total()]:
			run.round = round_value
			for which in run.available_nodes():
				run.choose_node(which)
				t.equal(run.preview()["region"], home.display_name,
					"Vorschau im Gebiet (Seed %d, Runde %d, Knoten %d)" % [seed_value, round_value, which])
				GameState.begin_run_battle()
				var battle := BattleManager.new()
				battle.setup(GameState.battle_seed, GameState.squad, GameState.enemy_override,
					GameState.battle_region)
				t.equal(battle.region.id, home.id,
					"Kampf im Gebiet (Seed %d, Runde %d, Knoten %d)" % [seed_value, round_value, which])
				battle.free()
				GameState.finish_run_battle(BattleManager.Outcome.DEFEAT, [])
				run.lives = RunState.max_lives()
				run.phase = RunState.Phase.PREPARE
	t.equal(GameState.battle_region, &"", "nach dem Kampf keine feste Region mehr")
	GameState.run = saved_run
	GameState.squad = saved_squad


## Ohne Gebiet (Direktstart, Tests) wuerfelt der Kampf die Region aus dem Seed.
func test_without_a_region_the_battle_still_rolls_one() -> void:
	var seen := {}
	for seed_value in range(1, 40):
		var info := BattleManager.preview_conditions(seed_value)
		var battle := BattleManager.new()
		battle.setup(seed_value, RunState.standard_squad())
		t.equal(battle.region.display_name, info["region"], "Vorschau = Kampf (Seed %d)" % seed_value)
		seen[battle.region.id] = true
		battle.free()
	t.ok(seen.size() > 1, "verschiedene Regionen (%d)" % seen.size())


func test_enemy_power_follows_a_fixed_rising_curve() -> void:
	var run := RunState.start(7)
	var first := run.enemy_power()
	run.round = 5
	var later := run.enemy_power()
	t.ok(later > first, "die Gegner werden stärker (%d -> %d)" % [int(first), int(later)])
	# Unabhaengig vom eigenen Squad: Beute darf den Gegner nicht mitziehen.
	run.squad[0].slots.erase("equip_right")
	t.equal(run.enemy_power(), later, "eigene Beute ändert die Gegnerstärke nicht")


func test_a_loss_costs_a_life_and_the_run_goes_on() -> void:
	var run := RunState.start(8)
	run.record_result(BattleManager.Outcome.DEFEAT, [])
	t.equal(run.lives, RunState.max_lives() - 1, "ein Leben weniger")
	t.equal(run.phase, RunState.Phase.STOP, "keine Belohnung, aber ein Zwischenstopp")
	t.equal(run.credits, int(RunState.cfg().get("loss_credits", 0)), "Trostgeld")
	run.continue_run()
	t.equal(run.round, 2, "weiter zur nächsten Runde")
	t.equal(run.phase, RunState.Phase.PREPARE, "nächster Kampf")


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
func test_caches_go_home_even_when_the_mission_fails() -> void:
	var run := RunState.start(12)
	run.run_caches = {"city": 2}
	run.run_coins = 15
	run.phase = RunState.Phase.STOP
	run.abandon()
	t.equal(run.phase, RunState.Phase.LOST, "aufgegeben")
	t.equal(run.run_caches, {"city": 2}, "die Caches bleiben dem Einsatz")
	var back := _through_json(run)
	t.equal(back.run_caches, {"city": 2}, "und überstehen das Speichern")
	t.equal(back.run_coins, 15, "die Coins auch")


func test_a_won_mission_brings_the_completion_cache() -> void:
	var run := RunState.start(13)
	run.round = RunState.rounds_total()
	run._pick_default_node()
	run.record_result(BattleManager.Outcome.VICTORY, [])
	t.equal(run.phase, RunState.Phase.WON, "geschafft")
	var final := int(RunState.loot_cfg().get("final_caches", 2))
	var complete := int(RunState.loot_cfg().get("complete_caches", 1))
	t.equal(int(run.run_caches.get("city", 0)), final + complete,
		"letzter Kampf (Elite, sicher) und Abschluss-Cache")


func test_weapons_are_fixed_during_the_run() -> void:
	# MODULE_KONZEPT.md: im Lauf wird keine Waffe getauscht.
	var run := RunState.start(21)
	var before: Array = run.squad.map(func(b): return b.slots.duplicate())
	run.record_result(BattleManager.Outcome.VICTORY, [&"eq_plasma_blade"])
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


func test_nothing_extra_goes_home_without_loot() -> void:
	var run := RunState.start(24)
	run.phase = RunState.Phase.STOP
	run.abandon()
	t.equal(run.home_queue, [], "die Startausrüstung wird nicht verdoppelt")
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
	t.equal(weak.enemy_power(), full.enemy_power(), "gleiche Gegnerstärke")


func test_enemies_carry_fitting_modules_later_in_the_run() -> void:
	# 6i: Gegner tragen Module, handverlesen -- passend zur Waffe, keine doppelt.
	var early := RunState.start(41)
	for index in early.available_nodes():
		for build in early.enemies(index):
			t.ok(build.modules.is_empty(), "Runde 1: noch keine Module")
	var run := _run_with_tier(RunState.Tier.ELITE, 42, RunState.rounds_total())
	var count := run.enemy_module_count(RunState.Tier.ELITE)
	t.ok(count >= 2, "spät und Elite: mehrere Module (%d)" % count)
	var recipes := 0
	for build in run.enemies():
		var all: Array = []
		for slot in build.equip_slots():
			for module in build.modules_in(slot):
				all.append(module.id)
				t.ok(module.fits(build.part_in(slot)), "%s passt zur Waffe" % module.display_name)
				if module.is_recipe():
					recipes += 1
		t.ok(not all.is_empty(), "%s trägt Module" % build.display_name)
		t.ok(all.size() <= ModuleData.slots_for(build), "nicht mehr als Plätze")
		var unique := {}
		for id in all:
			unique[id] = true
		t.equal(unique.size(), all.size(), "keines doppelt")
	t.ok(recipes > 0, "spät gibt es Rezepte")
	t.equal(run.enemies(), run.enemies(), "Vorschau und Kampf sehen dieselben Module")


func test_easy_enemies_carry_fewer_modules() -> void:
	var run := RunState.start(43)
	run.round = 4
	t.ok(run.enemy_module_count(RunState.Tier.EASY) < run.enemy_module_count(RunState.Tier.ELITE),
		"Leicht weniger als Elite")


func test_enemies_level_up_with_round_and_tier() -> void:
	# Leitplanke 9. Nov. 2026: Gegner-Level nach Runde und Stufe (run.enemy_levels).
	var first := RunState.start(44)
	t.equal(first.enemy_levels(RunState.Tier.NORMAL), {"drome": 0, "weapon": 0}, "Runde 1 Normal: Level 0")
	var run := _run_with_tier(RunState.Tier.ELITE, 44, RunState.rounds_total())
	var late := run.enemy_levels(RunState.Tier.ELITE)
	t.ok(late["drome"] > 0 and late["weapon"] > late["drome"], "spät Elite: DROME und Waffen gelevelt")
	# Sentinels haben kein Level (SPOT-Blatt Fragen 5) -- nur die DROMEs.
	for build in run.enemies().filter(func(b): return not b.is_sentinel()):
		t.equal(build.drome_level, late["drome"], "%s trägt das DROME-Level" % build.display_name)
		for slot in build.equip_slots():
			if build.part_in(slot) != null:
				t.equal(build.weapon_level(slot), late["weapon"], "und das Waffenlevel")
	t.ok(run.enemy_levels(RunState.Tier.EASY)["weapon"] < late["weapon"], "Leicht darunter")


# ---------------------------------------------------------------------------
# Fraktionen und Profile (MODULE_KONZEPT.md 9, 9. Nov. 2026)
# ---------------------------------------------------------------------------

## Zaehlt Chassis und Waffen der Gegner ueber viele Runden eines Gebiets.
func _faction_counts(region: StringName) -> Dictionary:
	var bodies := {}
	var weapons := {}
	for seed_value in 25:
		var run := RunState.start(9100 + seed_value)
		# Nach dem Training (run.training_rounds) kommen die Teams der Fraktion.
		run.round = 3 + seed_value % 5
		run.set_region(region)
		for which in run.available_nodes():
			for build in run.enemies(which):
				var body: StringName = build.body().id
				bodies[body] = int(bodies.get(body, 0)) + 1
				for part in build.weapons():
					weapons[part.id] = int(weapons.get(part.id, 0)) + 1
	return {"bodies": bodies, "weapons": weapons}


func test_every_region_has_a_faction_with_a_profile() -> void:
	for id in [&"city", &"green", &"plant7"]:
		var run := RunState.start(1)
		run.round = 3
		run.set_region(id)
		var faction := run.faction()
		t.ok(str(faction.get("name", "")) != "", "%s hat eine Fraktion" % id)
		t.ok(str(faction.get("profile", "")) != "", "mit Profil")
		var info := run.preview()
		t.equal(info["faction"], faction["name"], "die Vorschau nennt sie")


## Formationen (14. Nov. 2026): in Neon City kommen Neon-Sentinels mit
## einem oder zwei DROMEs. Die anderen Fraktionen bekommen ihre Formationen
## noch (SPOT-Blatt Offene Punkte 30) und leihen sich bis dahin die von Neon.
func test_neon_city_brings_neon_squads() -> void:
	var counts: Dictionary = _faction_counts(&"city")
	t.note("Chassis Neon City %s" % [counts["bodies"]])
	var blades := int(counts["weapons"].get(&"eq_plasma_blade", 0))
	var guns := int(counts["weapons"].get(&"eq_pulse_blaster", 0)) \
		+ int(counts["weapons"].get(&"eq_neon_blaster", 0))
	t.ok(blades > guns, "die Neon Ninjas kämpfen eher nah (%d gegen %d)" % [blades, guns])
	for seed_value in 20:
		var run := RunState.start(9300 + seed_value)
		run.round = 2 + seed_value % 6
		run._pick_default_node()
		for which in run.available_nodes():
			var foes := run.enemies(which)
			var dromes := foes.filter(func(b): return not b.is_sentinel())
			var sentinels := foes.filter(func(b): return b.is_sentinel())
			t.ok(dromes.size() >= 1 and dromes.size() <= 2, "ein oder zwei DROMEs (%d)" % dromes.size())
			t.ok(sentinels.size() >= 2, "dazu Sentinels (%d)" % sentinels.size())
			for build in sentinels:
				t.equal(build.faction, "Neon", "%s gehört zu Neon" % build.display_name)


# ---------------------------------------------------------------------------
# Spielstand (10. Nov. 2026)
# ---------------------------------------------------------------------------

## Wie auf der Platte: einmal durch JSON und zurueck.
func _through_json(run: RunState) -> RunState:
	var text := JSON.stringify(run.to_dict())
	return RunState.from_dict(JSON.parse_string(text))


func test_a_run_survives_saving_and_loading() -> void:
	var run := RunState.start(5150)
	run.record_result(BattleManager.Outcome.VICTORY, [&"eq_hammer", &"eq_deflector"])
	run.storage.append_array([&"mod_rapid_fire", &"bios_metronome"])
	run.bag.append(&"eq_mortar")
	run.squad[0].modules[run.squad[0].equip_slots()[0]] = [&"mod_capacitor", &"mod_seeker"]
	run.bios_given = 2
	run.set_target_recipe(&"mod_gunslinger")
	run.credits = 17
	var back := _through_json(run)
	t.ok(back != null, "der Lauf lässt sich laden")
	if back == null:
		return
	t.equal(back.round, run.round, "Runde")
	t.equal(back.lives, run.lives, "Leben")
	t.equal(back.phase, run.phase, "Phase")
	t.equal(back.credits, 17, "Credits")
	t.equal(back.storage, run.storage, "Lager (als StringName)")
	t.equal(back.bag, run.bag, "Tasche")
	t.equal(back.target_recipe, &"mod_gunslinger", "Ziel-Rezept")
	t.equal(back.squad.size(), run.squad.size(), "Squad")
	t.equal(back.squad[0].modules, run.squad[0].modules, "Module im Halter")
	t.equal(back.bios_given, 2, "vergebene BIOS-Wahlen")
	t.equal(back.shop_offers, run.shop_offers, "Laden")
	for i in run.squad.size():
		t.equal(back.squad[i].slots, run.squad[i].slots, "%s: Waffen" % run.squad[i].display_name)
		t.equal(back.squad[i].drome_level, run.squad[i].drome_level, "Level")


func test_a_loaded_run_meets_the_same_enemies() -> void:
	var run := RunState.start(7331)
	run.record_result(BattleManager.Outcome.VICTORY, [])
	run.continue_run()
	var back := _through_json(run)
	var a: Array = run.enemies().map(func(b): return b.to_loadout())
	var b: Array = back.enemies().map(func(x): return x.to_loadout())
	t.equal(a, b, "dieselben Gegner nach dem Laden")
	t.equal(back.battle_seed(), run.battle_seed(), "derselbe Kampf-Seed")


func test_an_old_or_broken_save_is_refused() -> void:
	t.equal(RunState.from_dict({"version": 0}), null, "falsche Version")
	t.equal(RunState.from_dict({"version": RunState.SAVE_VERSION,
		"squad": [{"slots": {}}]}), null, "Squad ohne Chassis")


# ---------------------------------------------------------------------------
# Die Reihe der Runde (10. Nov. 2026, Regel des Spielers)
# ---------------------------------------------------------------------------

## Die Kampfkarte (14. Nov. 2026): feste Pfade wie bei FTL. Jede Reihe hat
## zwei oder drei Knoten, der letzte Kampf ist ein einzelner Elite-Knoten.
## Jeder Knoten der naechsten Reihe ist erreichbar, und anfangs gabelt sich
## der Weg oefter als spaeter.
func test_the_map_has_paths_and_ends_in_one_elite_fight() -> void:
	var early_forks := 0
	var late_forks := 0
	var tiers := {}
	for seed_value in 40:
		var run := RunState.start(8800 + seed_value)
		var last := RunState.rounds_total()
		for round_value in range(1, last + 1):
			var nodes := run.row(round_value)
			t.ok(not nodes.any(func(n): return n["chaos"]), "kein Chaos im Story-Einsatz")
			for info in nodes:
				t.ok(not Formations.formation(str(info["team"])).is_empty(),
					"Formation '%s' gibt es" % info["team"])
				tiers[int(info["tier"])] = true
			if round_value == last:
				t.equal(nodes.size(), 1, "der letzte Kampf ist ein Knoten")
				t.equal(int(nodes[0]["tier"]), RunState.Tier.ELITE, "und Elite")
				continue
			t.ok(nodes.size() >= 2 and nodes.size() <= 3, "zwei oder drei Knoten (%d)" % nodes.size())
			t.ok(not nodes.all(func(n): return int(n["tier"]) == RunState.Tier.ELITE),
				"nie nur Elite")
			var paths := run.links(round_value)
			t.equal(paths.size(), nodes.size(), "Wege von jedem Knoten")
			var reached := {}
			for targets in paths:
				t.ok(not (targets as Array).is_empty(), "jeder Knoten führt weiter")
				for j in targets:
					reached[j] = true
					if round_value <= 3:
						early_forks += 1 if (targets as Array).size() > 1 else 0
					elif round_value >= 5:
						late_forks += 1 if (targets as Array).size() > 1 else 0
			t.equal(reached.size(), run.row(round_value + 1).size(), "jeder Knoten erreichbar")
	t.ok(tiers.size() == 3, "Leicht, Normal und Elite kommen vor")
	t.ok(early_forks > late_forks, "anfangs mehr Gabelungen (%d gegen %d)" % [early_forks, late_forks])


## Der Weg zaehlt: nach einem Kampf stehen nur die Knoten zur Wahl, zu denen
## ein Weg fuehrt.
func test_only_linked_nodes_can_be_chosen() -> void:
	var run := RunState.start(4711)
	t.equal(run.available_nodes(), range(run.row().size()), "am Anfang alle")
	run.choose_node(0)
	run.record_result(BattleManager.Outcome.VICTORY, [])
	run.continue_run()
	var expected: Array = run.links(1)[0]
	t.equal(run.available_nodes(), expected, "danach nur die Wege vom gewählten Knoten")
	for i in run.row().size():
		t.equal(run.choose_node(i), expected.has(i), "Knoten %d wählbar: %s" % [i, expected.has(i)])
	t.ok(expected.has(run.node), "die Vorwahl liegt auf dem Weg")


func test_the_first_rounds_bring_introductions() -> void:
	var run := RunState.start(8901)
	var training := int(RunState.cfg().get("training_rounds", 0))
	t.ok(training >= 1, "es gibt Einführungskämpfe")
	for round_value in range(1, training + 1):
		for info in run.row(round_value):
			t.ok(bool(Formations.formation(str(info["team"])).get("intro", false)),
				"Kampf %d: eine Einführung" % round_value)
			t.ok(int(info["tier"]) != RunState.Tier.ELITE, "kein Elite in der Einführung")


func test_the_same_seed_draws_the_same_rows() -> void:
	var a := RunState.start(77)
	var b := RunState.start(77)
	for round_value in range(1, RunState.rounds_total() + 1):
		t.equal(a.row(round_value), b.row(round_value), "gleicher Seed, gleiche Reihe %d" % round_value)
		t.equal(a.links(round_value), b.links(round_value), "gleiche Wege %d" % round_value)


func test_every_open_node_can_be_chosen() -> void:
	var run := RunState.start(9901)
	run.round = 4
	run._pick_default_node()
	for index in run.available_nodes():
		t.ok(run.choose_node(index), "Knoten %d lässt sich wählen" % index)
		t.equal(run.tier, int(run.row()[index]["tier"]), "und setzt die Stufe")
		t.ok(not run.enemies().is_empty(), "mit Gegnern")
	t.ok(not run.choose_node(run.row().size()), "ausserhalb der Reihe nicht")


## Reinforcement-Level: steigt nach jedem Kampf, nach Elite schneller.
func test_reinforcement_rises_after_each_fight() -> void:
	var run := _run_with_tier(RunState.Tier.ELITE, 20500)
	var before := run.reinforcement()
	t.equal(before, run.round + run.elites_chosen(), "Kampf plus gewählte Elite")
	run.record_result(BattleManager.Outcome.VICTORY, [])
	run.continue_run()
	t.equal(run.elites_chosen(), 1, "ein Elite gewählt")
	t.equal(run.reinforcement(), before + 2, "ein Kampf mehr und ein Elite-Bonus")


func test_the_preview_names_the_formation() -> void:
	var run := RunState.start(9950)
	run.round = 4
	run._pick_default_node()
	var info := run.preview()
	t.ok(str(info["team"]) != "", "die Formation hat einen Namen")
	t.ok(str(info["team_text"]) != "", "und einen Grundgedanken")
	t.ok(int(info["reinforcement"]) >= 4, "mit Reinforcement-Level")
	t.ok(not run.next_row().is_empty(), "die Vorausschau zeigt die nächste Reihe")
	run.round = RunState.rounds_total()
	t.ok(run.next_row().is_empty(), "nach dem letzten Kampf kommt nichts mehr")


func test_the_chosen_node_survives_saving() -> void:
	var run := RunState.start(4545)
	run.choose_node(run.available_nodes()[-1])
	run.record_result(BattleManager.Outcome.VICTORY, [])
	run.continue_run()
	run.choose_node(run.available_nodes()[0])
	var back := _through_json(run)
	t.equal(back.node, run.node, "gewählter Knoten")
	t.equal(back.tier, run.tier, "seine Stufe")
	t.equal(back.row(), run.row(), "dieselbe Reihe")
	t.equal(back.mode, run.mode, "die Art des Laufs")


# ---------------------------------------------------------------------------
# Endlos-Modus (NEUANFANG 6h): kein Ende, eine Niederlage, Chaos-Kaempfe
# ---------------------------------------------------------------------------

func test_the_endless_run_never_ends_by_winning() -> void:
	var run := RunState.start(31000, [], "endless")
	t.ok(run.is_endless(), "Endlos-Lauf")
	t.equal(run.lives, 1, "ein Leben")
	run.round = RunState.rounds_total() + 5
	run._pick_default_node()
	t.ok(not run.is_last_round(), "es gibt keinen letzten Kampf")
	run.record_result(BattleManager.Outcome.VICTORY, [])
	t.equal(run.phase, RunState.Phase.STOP, "nach dem Sieg geht es weiter")
	run.continue_run()
	t.equal(run.phase, RunState.Phase.PREPARE, "nächste Runde")
	t.ok(not run.enemies().is_empty(), "mit Gegnern auch nach der Tabelle")


func test_losing_an_endless_run_costs_the_loot() -> void:
	var run := RunState.start(31001, [], "endless")
	run.bag.append(&"eq_mortar")
	run.home_queue.append({"kind": "part", "part_id": &"eq_hammer", "title": "Hammer", "text": ""})
	run.record_result(BattleManager.Outcome.DEFEAT, [])
	t.equal(run.phase, RunState.Phase.LOST, "die erste Niederlage beendet den Lauf")
	t.ok(run.bag.is_empty() and run.home_queue.is_empty(), "die Beute ist weg")


func test_cashing_out_of_an_endless_run_keeps_the_loot() -> void:
	var run := RunState.start(31002, [], "endless")
	run.record_result(BattleManager.Outcome.VICTORY, [])
	run.bag.append(&"eq_mortar")
	t.ok(run.cash_out(), "aussteigen geht")
	t.equal(run.phase, RunState.Phase.WON, "zählt als gewonnenes Ende")
	t.ok(run.home_queue.any(func(item): return item.get("part_id") == &"eq_mortar"),
		"die Beute geht nach Hause")
	var story := RunState.start(31003)
	t.ok(not story.cash_out(), "im Story-Lauf gibt es kein Aussteigen")


func test_endless_foes_keep_growing_after_the_tables_end() -> void:
	var run := RunState.start(31004, [], "endless")
	run.round = RunState.rounds_total()
	var at_end := run.enemy_levels(RunState.Tier.NORMAL)
	var mods_at_end := run.enemy_module_count(RunState.Tier.NORMAL)
	run.round = RunState.rounds_total() + 12
	var later := run.enemy_levels(RunState.Tier.NORMAL)
	t.ok(later["drome"] > at_end["drome"], "DROME-Level steigt weiter (%d -> %d)" % [at_end["drome"], later["drome"]])
	t.ok(later["weapon"] > at_end["weapon"], "Waffenlevel steigt weiter")
	t.ok(run.enemy_module_count(RunState.Tier.NORMAL) > mods_at_end, "mehr Module")
	run.round = 500
	t.ok(run.enemy_levels(RunState.Tier.ELITE)["drome"] <= Leveling.drome_max(), "nie über das Höchstlevel")
	var story := RunState.start(31004)
	story.round = RunState.rounds_total() + 12
	t.equal(story.enemy_levels(RunState.Tier.NORMAL), at_end, "der Story-Lauf bleibt bei der Tabelle")


func test_a_chaos_fight_only_shows_up_in_the_endless_run() -> void:
	var found: RunState = null
	for seed_value in 200:
		var run := RunState.start(12000 + seed_value, [], "endless")
		t.ok(not run.row(1).any(func(n): return n["chaos"]), "kein Chaos in Runde 1")
		run.round = 3
		run._pick_default_node()
		var nodes := run.row()
		for i in run.available_nodes():
			if nodes[i]["chaos"] and found == null:
				t.ok(nodes.size() >= 2, "der Chaos-Knoten ersetzt einen der Reihe")
				run.choose_node(i)
				found = run
	t.ok(found != null, "Chaos-Kämpfe kommen vor")
	if found == null:
		return
	t.ok(found.is_chaos(), "Chaos-Kampf erkannt")
	t.ok(found.preview()["chaos"], "die Vorschau weiß es")
	var normal := int(RunState.tier_cfg(RunState.Tier.NORMAL).get("credits", 10))
	t.ok(found.battle_credits(true) > normal, "mehr Credits")
	var foes := found.enemies()
	t.ok(not foes.is_empty(), "gewürfelte Gegner")
	for build in foes:
		t.ok(build.is_valid() and not build.weapons().is_empty(), "%s ist kampftauglich" % build.display_name)
	t.equal(found.enemies().map(func(b): return b.to_save()),
		_through_json(found).enemies().map(func(b): return b.to_save()), "dieselben nach dem Laden")


## Ein Infinity-Einsatz, der gerade vor einem Chaos-Kampf steht.
func _chaos_run(base_seed: int) -> RunState:
	for seed_value in 400:
		var run := RunState.start(base_seed + seed_value, [], "endless")
		run.round = 3
		run._pick_default_node()
		var nodes := run.row()
		for i in run.available_nodes():
			if nodes[i]["chaos"]:
				run.choose_node(i)
				return run
	return null


## Chaos-Beute (19. Nov. 2026): ein Wurf -- je etwa ein Drittel BIOS-Wahl,
## Cache und Credit-Booster, selten ein Fraktionskern.
func test_a_chaos_win_rolls_bios_cache_or_booster() -> void:
	var kinds := {}
	var base := 30000
	for n in 60:
		var run := _chaos_run(base)
		if run == null:
			break
		base = run.run_seed + 1
		run.record_result(BattleManager.Outcome.VICTORY, [])
		var rolled: Array = run.last_loot.map(func(i): return i["kind"]).filter(
			func(k): return k in ["bios", "cache", "booster", "faction_core", "coins"])
		t.equal(rolled.size(), 1, "genau ein Chaos-Wurf (%s)" % [rolled])
		t.ok(not rolled.has("coins"), "kein Platzhaltercoin im Chaos")
		for k in rolled:
			kinds[k] = int(kinds.get(k, 0)) + 1
	t.ok(kinds.has("bios") and kinds.has("cache") and kinds.has("booster"),
		"BIOS, Cache und Booster kommen vor (%s)" % [kinds])


func test_the_credit_booster_doubles_three_fights() -> void:
	var run := RunState.start(4242)
	run.credit_boost = 3
	var normal := run.battle_credits(true)
	run.record_result(BattleManager.Outcome.VICTORY, [])
	t.equal(run.history[-1]["credits"], normal * 2, "doppelte Credits")
	t.equal(run.credit_boost, 2, "einer verbraucht")
	t.equal(_through_json(run).credit_boost, 2, "bleibt im Spielstand")


func test_a_faction_core_goes_home() -> void:
	var run := RunState.start(4243)
	var item := {"kind": "faction_core", "faction": run.faction_core_key(), "title": "Kern"}
	run._apply_loot(item)
	t.equal(item["where"], "home", "nach Hause")
	t.equal(run.home_queue.size(), 1, "in der Liste")
	t.equal(run.faction_core_key(), "neon", "Neon City gibt Neon-Kerne")


func test_bios_offers_are_usable_or_close() -> void:
	var run := RunState.start(77)
	run.phase = RunState.Phase.STOP
	run.storage.append_array([&"mod_brand", &"mod_rapid_fire"])
	for seed_value in 10:
		run.run_seed = seed_value
		for id in run.roll_bios_offers():
			var state := run.bios_state(ModuleData.get_module(id))
			t.ok(int(state["rank"]) <= 2, "%s ist sofort oder bald nutzbar" % id)


func test_the_loot_text_follows_the_cache_rules() -> void:
	# Die Kampfkarte nennt die Beute aus run.loot (Caches seit 14. Nov. 2026),
	# nicht mehr den alten Text "Teil der Gegner".
	var run := RunState.start(4711, RunState.standard_squad())
	var easy := run.loot_text(RunState.Tier.EASY)
	var elite := run.loot_text(RunState.Tier.ELITE)
	t.ok(easy.contains(RunState.cache_name(run.region_id)), "Leicht nennt den Cache: %s" % easy)
	t.ok(easy.contains("%"), "Leicht nennt die Chance: %s" % easy)
	t.ok(elite.ends_with("sicher"), "Elite: Cache sicher (%s)" % elite)
	t.ok(not str(run.preview()["reward_text"]).contains("Teil"), "kein alter Beutetext mehr")
