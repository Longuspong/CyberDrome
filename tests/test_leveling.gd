extends RefCounted

## Level fuer DROMEs und Waffen (scripts/core/leveling.gd, 8. Nov. 2026).

var t


func _vireo(weapon: StringName = &"eq_pulse_blaster") -> DromeBuild:
	return DromeBuild.create("Vireo", {"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core", "equip_left": weapon})


func _molok() -> DromeBuild:
	return DromeBuild.create("Molok", {"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core", "equip_left": &"eq_hammer"})


func test_levels_are_bought_not_earned() -> void:
	t.ok(not Leveling.xp_enabled(), "keine EP mehr (24. Nov. 2026)")
	t.equal(Leveling.drome_max(), 5, "DROMEs bis Level 5")
	t.equal(Leveling.weapon_max(), 5, "Waffen bis Level 5")
	var roster := Roster.new()
	roster.seed_starter()
	var bench := Workbench.new(roster)
	var entry: RosterEntry = roster.entries[0]
	t.ok(bench.level_up_drome(entry) != "", "ohne Waren kein Level")
	var cost := bench.drome_next_cost(entry)
	for key in cost:
		roster.materials[key] = int(cost[key])
	t.equal(bench.level_up_drome(entry), "", "Level 1 gekauft")
	t.equal(entry.level, 1, "jetzt Level 1")
	t.ok(roster.materials.keys().all(func(k): return not str(k).begins_with("res:")), "Waren verbraucht")
	entry.level = 4
	t.equal(int(bench.drome_next_cost(entry).get("keynode", 0)), 1, "Level 5 braucht einen Keynode-Chip")
	entry.level = 5
	t.ok(bench.drome_next_cost(entry).is_empty(), "über Level 5 nichts mehr")


func test_level_costs_grow_steeply() -> void:
	var l2 := Workbench.drome_level_cost("scout_body", 2)
	var l5 := Workbench.drome_level_cost("scout_body", 5)
	t.ok(l2.has("res:plasma") and not l2.has("res:platte"), "Level 1-2: Tier-1-Waren")
	t.ok(int(l5.get("res:platte", 0)) > 3 * int(Workbench.drome_level_cost("scout_body", 3).get("res:platte", 0)),
		"Level 5 deutlich teurer als Level 3")
	var weapon := Workbench.weapon_level_cost("heavy", 1)
	t.ok(weapon.has("res:legierung"), "schwere Waffe levelt mit Legierung")


func test_weapon_level_up() -> void:
	var roster := Roster.new()
	roster.seed_starter()
	var bench := Workbench.new(roster)
	var uid := ""
	for slot in roster.entries[0].assignments:
		if str(slot).begins_with("equip_"):
			uid = str(roster.entries[0].assignments[slot])
	var cost := bench.weapon_next_cost(uid)
	t.ok(not cost.is_empty(), "Waffe hat Level-Kosten")
	for key in cost:
		roster.materials[key] = int(cost[key])
	t.equal(bench.level_up_weapon(uid), "", "Waffenlevel gekauft")
	t.equal(roster.instance(uid).level, 1, "Waffe auf Level 1")


func test_a_top_level_weapon_hits_seventy_percent_harder() -> void:
	var part := PartDB.get_part(&"eq_hammer")
	var attack: ActionData = part.actions[0]
	var stun: ActionData = part.actions[1]
	var top := Leveling.level_action(attack, part, 10)
	t.equal(top.power, int(round(attack.power * 1.7)), "Angriff +70 %")
	t.equal(Leveling.level_action(stun, part, 10).power, int(round(stun.power * 1.7)),
		"die Fähigkeit wächst mit (Anteil des Waffenschadens)")
	t.equal(attack.power, 16, "die PartDB bleibt unberührt")
	t.equal(Leveling.level_action(attack, part, 0), attack, "Level 0 ändert nichts")


func test_the_neon_blaster_grows_only_in_energy() -> void:
	var part := PartDB.get_part(&"eq_neon_blaster")
	var attack: ActionData = part.actions[0]
	var kinetic := attack.power * (1.0 - attack.energy_fraction)
	var top := Leveling.level_action(attack, part, 10)
	t.ok(abs(top.power * (1.0 - top.energy_fraction) - kinetic) < 0.6,
		"der kinetische Anteil bleibt (%0.1f)" % (top.power * (1.0 - top.energy_fraction)))
	t.ok(top.power > attack.power, "der Energieanteil wächst")


func test_the_weapon_bonus_grows_to_its_own_end_value() -> void:
	var build := _vireo()
	var base: int = build.stats()["spd"]
	build.weapon_levels["equip_left"] = 10
	t.equal(build.stats()["spd"], base + 1, "Blaster Speed 2 -> 3 auf Level 10, nicht doppelt")
	var molok := _molok()
	var hp: int = molok.stats()["hp_max"]
	molok.weapon_levels["equip_left"] = 10
	t.equal(molok.stats()["hp_max"], hp + 20, "Hammer Integrität 20 -> 40")


func test_a_drome_level_raises_two_values_more_than_the_rest() -> void:
	var vireo := _vireo()
	var before := vireo.stats()
	vireo.drome_level = 5
	var after := vireo.stats()
	t.equal(after["hp_max"] - before["hp_max"], 40, "Integrität ist Hauptwert: 80 -> 120 (+50 %)")
	t.equal(after["shield_max"] - before["shield_max"], 25, "Schild ist Hauptwert: 50 -> 75")
	t.equal(after["shield_pulse"], 8, "Schildpuls +20 %: 7 -> 8")
	t.equal(after["spd"], before["spd"], "Speed steigt nie")
	t.equal(after["power"], before["power"], "Power steigt nie")
	t.equal(after["module_slots"], 3, "Modulplätze bleiben 3 (seit 18. Nov. 2026)")
	var molok := _molok()
	molok.drome_level = 5
	t.equal(molok.stats()["module_slots"], 2, "Molok bleibt bei 2 je Waffe")


func test_levels_reach_the_battle() -> void:
	var build := _vireo()
	build.weapon_levels["equip_left"] = 10
	var unit := Unit.create(build, &"P0", true)
	unit.init_realtime(0.0)
	var attack: ActionData = unit.mounts[0]["attack"]
	t.equal(attack.power, int(round(10 * 1.7)), "der Blaster schießt auf Level 10 mit 17")
	unit.free()


func test_the_roster_carries_levels_into_the_build() -> void:
	var roster := Roster.new()
	roster.seed_starter()
	var entry: RosterEntry = roster.entries[0]
	t.ok(entry.add_xp(300), "300 EP: Aufstieg")
	t.equal(entry.level, 2, "Level 2")
	var uid := str(entry.assignments.values().filter(
		func(u): return roster.instance(str(u)).part().type == PartData.Type.EQUIPMENT)[0])
	roster.instance(uid).add_xp(450)
	var build := roster.build_for(entry)
	t.equal(build.drome_level, 2, "das Level steckt im Aufbau")
	t.equal(build.source_uid, entry.chassis_uid(), "mit Herkunft")
	t.ok(build.weapon_levels.values().has(3), "die Waffe kommt auf Level 3")
	var copy := build.clone()
	t.equal(copy.weapon_levels, build.weapon_levels, "die Lauf-Kopie behält die Level")
	var saved := RosterEntry.from_dict(entry.to_dict())
	t.equal(saved.xp, entry.xp, "EP überstehen Speichern")
	var inst := PartInstance.from_dict(roster.instance(uid).to_dict())
	t.equal(inst.level, 3, "Waffenlevel übersteht Speichern")


func test_runs_give_no_xp_but_a_keynode_on_the_first_win() -> void:
	var saved_roster = GameState.roster
	var saved_run = GameState.run
	var saved_progress = GameState.progress
	var roster := Roster.new()
	roster.seed_starter()
	GameState.roster = roster
	GameState.progress = {}
	GameState.run = RunState.start(55, roster.squad_builds())
	var run: RunState = GameState.run
	var first: DromeBuild = run.squad[0]
	run.collect_xp([{"source_uid": first.source_uid, "weapons": {}}], true)
	t.ok(run.pending_xp["dromes"].is_empty(), "keine EP im Lauf")
	run.phase = RunState.Phase.WON
	var got := GameState.deliver_run_home()
	t.ok(got.any(func(i): return i.get("kind", "") == "keynode"), "erster gewonnener Einsatz: Keynode-Chip")
	t.equal(int(roster.materials.get("keynode", 0)), 1, "liegt im Lager")
	GameState.deliver_run_home()
	t.equal(int(roster.materials.get("keynode", 0)), 1, "nur einmal je Einsatz")
	GameState.roster = saved_roster
	GameState.run = saved_run
	GameState.progress = saved_progress
