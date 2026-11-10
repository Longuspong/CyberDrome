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


func test_an_elite_win_guarantees_something_rare() -> void:
	for seed_value in 20:
		var run := _run_with_tier(RunState.Tier.ELITE, 1800 + seed_value * 301)
		run.record_result(BattleManager.Outcome.VICTORY, [&"eq_pulse_blaster", &"eq_rune_staff"])
		t.equal(run.last_loot.size(), 1, "eine Beute, kein Notstrom bei Elite")
		var item: Dictionary = run.last_loot[0]
		t.ok(item.get("rare", false), "%s ist selten" % item["title"])
		t.ok(item["kind"] in ["bios", "drome"], "BIOS-Wahl oder DROME, keine Credits")
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
			t.equal(loaded.run_seed, run.run_seed, "run_seed uebersteht JSON (%d)" % seed_value)
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
	for index in early.available_nodes():
		for build in early.enemies(index):
			t.ok(build.modules.is_empty(), "Runde 1: noch keine Module")
	var run := _run_with_tier(RunState.Tier.ELITE, 42, RunState.rounds_total())
	var count := run.enemy_module_count(RunState.Tier.ELITE)
	t.ok(count >= 2, "spaet und Elite: mehrere Module (%d)" % count)
	var recipes := 0
	for build in run.enemies():
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
	t.ok(late["drome"] > 0 and late["weapon"] > late["drome"], "spaet Elite: DROME und Waffen gelevelt")
	for build in run.enemies():
		t.equal(build.drome_level, late["drome"], "%s traegt das DROME-Level" % build.display_name)
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


func test_the_mega_mechas_bring_more_moloks_than_the_ninjas() -> void:
	var mechas: Dictionary = _faction_counts(&"plant7")
	var ninjas: Dictionary = _faction_counts(&"city")
	# Handverlesene Teams (data/encounters.json): die Festung bringt schwere
	# Rahmen (Molok + Strix), die Kaempfer Vireos mit Klingen.
	var heavy := func(counts: Dictionary) -> int:
		return int(counts.get(&"jugg_body", 0)) + int(counts.get(&"strix_body", 0))
	var mech_heavy: int = heavy.call(mechas["bodies"])
	var ninja_heavy: int = heavy.call(ninjas["bodies"])
	var ninja_vireos := int(ninjas["bodies"].get(&"scout_body", 0))
	t.note("Chassis Mega Mechas %s, Neon Ninja's %s" % [mechas["bodies"], ninjas["bodies"]])
	t.ok(mech_heavy > ninja_heavy * 1.3, "Festung: deutlich mehr schwere Rahmen (%d gegen %d)" % [mech_heavy, ninja_heavy])
	t.ok(ninja_vireos > int(mechas["bodies"].get(&"scout_body", 0)), "Kaempfer: mehr Vireos")
	var blades := int(ninjas["weapons"].get(&"eq_plasma_blade", 0)) \
		+ int(ninjas["weapons"].get(&"eq_boomerang", 0))
	var guns := int(ninjas["weapons"].get(&"eq_pulse_blaster", 0)) \
		+ int(ninjas["weapons"].get(&"eq_neon_blaster", 0))
	t.ok(blades > guns, "die Neon Ninja's kaempfen eher nah (%d gegen %d)" % [blades, guns])


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
	run.squad[1].chassis_bios = true
	run.set_target_recipe(&"mod_gunslinger")
	run.credits = 17
	var back := _through_json(run)
	t.ok(back != null, "der Lauf laesst sich laden")
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
	t.ok(back.squad[1].chassis_bios, "Chassis-BIOS")
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

func test_every_row_has_an_easy_fight_and_two_harder_ones() -> void:
	var elite_rows := 0
	var normal_rows := 0
	for seed_value in 40:
		var run := RunState.start(8800 + seed_value)
		for round_value in range(1, RunState.rounds_total() + 1):
			var nodes := run.row(round_value)
			t.equal(nodes.size(), 3, "drei Knoten je Reihe")
			t.equal(int(nodes[0]["tier"]), RunState.Tier.EASY, "immer ein Leichter")
			t.equal(int(nodes[1]["tier"]), RunState.Tier.NORMAL, "immer ein Normaler")
			t.ok(not nodes.any(func(n): return n["chaos"]), "kein Chaos im Story-Lauf")
			var teams: Array = nodes.map(func(n): return str(n["team"]))
			for team_id in teams:
				t.ok(not Encounters.team(team_id).is_empty(), "Team '%s' gibt es" % team_id)
			if int(nodes[2]["tier"]) == RunState.Tier.ELITE:
				elite_rows += 1
				t.ok(not run.is_training(round_value), "kein Elite im Training")
			else:
				normal_rows += 1
				t.equal(int(nodes[2]["tier"]), RunState.Tier.NORMAL, "sonst ein zweiter Normaler")
				t.ok(teams[1] != teams[2], "zwei verschiedene Teams")
				t.ok(Encounters.team(teams[1])["type"] != Encounters.team(teams[2])["type"]
					or run.is_training(round_value), "mit verschiedenen Gegnertypen")
	t.ok(elite_rows > 0 and normal_rows > 0, "beide Formen kommen vor (%d Elite, %d Normal)"
		% [elite_rows, normal_rows])


func test_the_first_rounds_are_training_against_plain_dromes() -> void:
	var run := RunState.start(8901)
	var training := int(RunState.cfg().get("training_rounds", 0))
	t.ok(training >= 1, "es gibt Trainingsrunden")
	for round_value in range(1, training + 1):
		for info in run.row(round_value):
			t.equal(str(Encounters.team(str(info["team"]))["type"]), "training",
				"Runde %d: ein Trainingsteam" % round_value)
	for info in run.row(training + 1):
		t.ok(str(Encounters.team(str(info["team"]))["type"]) != "training",
			"danach die Fraktion")
	t.equal(run.preview()["faction"], "", "im Training nennt die Vorschau keine Fraktion")
	for build in run.enemies():
		t.ok(build.modules.is_empty(), "Trainingsgegner tragen keine Module")


func test_the_same_seed_draws_the_same_rows() -> void:
	var a := RunState.start(77)
	var b := RunState.start(77)
	for round_value in range(1, RunState.rounds_total() + 1):
		t.equal(a.row(round_value), b.row(round_value), "gleicher Seed, gleiche Reihe %d" % round_value)


func test_every_node_of_the_row_can_be_chosen() -> void:
	var run := RunState.start(9901)
	run.round = 4
	run._pick_default_node()
	t.equal(run.tier, RunState.Tier.NORMAL, "vorgewaehlt ist ein Normaler")
	for index in run.available_nodes():
		t.ok(run.choose_node(index), "Knoten %d laesst sich waehlen" % index)
		t.equal(run.tier, int(run.row()[index]["tier"]), "und setzt die Stufe")
		t.ok(not run.enemies().is_empty(), "mit Gegnern")
	t.ok(not run.choose_node(run.row().size()), "ausserhalb der Reihe nicht")
	t.ok(run.choose_tier(RunState.Tier.EASY), "Leicht gibt es immer")


func test_choosing_elites_brings_more_elites() -> void:
	# Wer Elite waehlt, bekommt in den Reihen danach oefter welche angeboten.
	var none := 0
	var many := 0
	for seed_value in 300:
		var run := RunState.start(20000 + seed_value)
		if int(run.row(5, 0)[2]["tier"]) == RunState.Tier.ELITE:
			none += 1
		if int(run.row(5, 3)[2]["tier"]) == RunState.Tier.ELITE:
			many += 1
	t.ok(many > none * 1.4, "nach drei Elite deutlich oefter (%d gegen %d von 300)" % [many, none])
	# Und der Verlauf zaehlt wirklich mit.
	var run := _run_with_tier(RunState.Tier.ELITE, 20500)
	t.equal(run.elites_chosen(), 0, "noch kein Elite gewaehlt")
	run.record_result(BattleManager.Outcome.VICTORY, [])
	run.continue_run()
	t.equal(run.elites_chosen(), 1, "ein Elite gewaehlt")
	t.equal(run.row(), run.row(run.round, 1), "die Reihe rechnet mit ihm")


func test_the_preview_names_team_and_type() -> void:
	var run := RunState.start(9950)
	run.round = 4
	run._pick_default_node()
	var info := run.preview()
	t.ok(str(info["team"]) != "", "das Team hat einen Namen")
	t.ok(str(info["type"]) != "", "und einen Gegnertyp")
	t.ok(str(info["type_hint"]) != "", "mit Hinweis")
	t.ok(not run.next_row().is_empty(), "die Vorausschau zeigt die naechste Reihe")
	run.round = RunState.rounds_total()
	t.ok(run.next_row().is_empty(), "nach dem letzten Kampf kommt nichts mehr")


func test_the_chosen_node_survives_saving() -> void:
	var run := RunState.start(4545)
	run.choose_node(run.available_nodes()[-1])
	run.record_result(BattleManager.Outcome.VICTORY, [])
	run.continue_run()
	run.choose_node(0)
	var back := _through_json(run)
	t.equal(back.node, run.node, "gewaehlter Knoten")
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
	t.equal(run.phase, RunState.Phase.PREPARE, "naechste Runde")
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
	t.equal(run.phase, RunState.Phase.WON, "zaehlt als gewonnenes Ende")
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
	t.ok(run.enemy_levels(RunState.Tier.ELITE)["drome"] <= Leveling.drome_max(), "nie ueber das Hoechstlevel")
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
		for i in nodes.size():
			if nodes[i]["chaos"] and found == null:
				t.equal(nodes.size(), 4, "der Chaos-Knoten kommt obendrauf")
				run.choose_node(i)
				found = run
	t.ok(found != null, "Chaos-Kaempfe kommen vor")
	if found == null:
		return
	t.ok(found.is_chaos(), "Chaos-Kampf erkannt")
	t.ok(found.preview()["chaos"], "die Vorschau weiss es")
	var normal := int(RunState.tier_cfg(RunState.Tier.NORMAL).get("credits", 10))
	t.ok(found.battle_credits(true) > normal, "mehr Credits")
	var foes := found.enemies()
	t.ok(not foes.is_empty(), "gewuerfelte Gegner")
	for build in foes:
		t.ok(build.is_valid() and not build.weapons().is_empty(), "%s ist kampftauglich" % build.display_name)
	t.equal(found.enemies().map(func(b): return b.to_save()),
		_through_json(found).enemies().map(func(b): return b.to_save()), "dieselben nach dem Laden")
