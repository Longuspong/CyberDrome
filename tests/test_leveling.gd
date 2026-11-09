extends RefCounted

## Level fuer DROMEs und Waffen (scripts/core/leveling.gd, 8. Nov. 2026).

var t


func _vireo(weapon: StringName = &"eq_pulse_blaster") -> DromeBuild:
	return DromeBuild.create("Vireo", {"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core", "equip_left": weapon})


func _molok() -> DromeBuild:
	return DromeBuild.create("Molok", {"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core", "equip_left": &"eq_hammer"})


func test_xp_tables_give_levels() -> void:
	t.equal(Leveling.drome_level_for(99), 0, "99 EP: Level 0")
	t.equal(Leveling.drome_level_for(100), 1, "100 EP: Level 1")
	t.equal(Leveling.drome_level_for(300), 2, "100 + 200 EP: Level 2")
	t.equal(Leveling.drome_table(), [100, 300, 600, 1000, 1500], "100, 200, 300 ... je Level")
	var costs: Array = Leveling.weapon_cfg()["xp_per_level"]
	t.ok(costs[4] < costs[5] and costs[7] < costs[8], "Waffen: 1-5 schnell, 6-8 mittel, 9-10 langsam")
	t.equal(Leveling.drome_level_for(99999), Leveling.drome_max(), "nie ueber das Hoechstlevel")
	t.equal(Leveling.weapon_level_for(99999), Leveling.weapon_max(), "Waffe hoechstens 10")


func test_a_level_ten_weapon_hits_seventy_percent_harder() -> void:
	var part := PartDB.get_part(&"eq_hammer")
	var attack: ActionData = part.actions[0]
	var stun: ActionData = part.actions[1]
	var top := Leveling.level_action(attack, part, 10)
	t.equal(top.power, int(round(attack.power * 1.7)), "Angriff +70 %")
	t.equal(Leveling.level_action(stun, part, 10).power, int(round(stun.power * 1.7)),
		"die Faehigkeit waechst mit (Anteil des Waffenschadens)")
	t.equal(attack.power, 16, "die PartDB bleibt unberuehrt")
	t.equal(Leveling.level_action(attack, part, 0), attack, "Level 0 aendert nichts")


func test_the_neon_blaster_grows_only_in_energy() -> void:
	var part := PartDB.get_part(&"eq_neon_blaster")
	var attack: ActionData = part.actions[0]
	var kinetic := attack.power * (1.0 - attack.energy_fraction)
	var top := Leveling.level_action(attack, part, 10)
	t.ok(abs(top.power * (1.0 - top.energy_fraction) - kinetic) < 0.6,
		"der kinetische Anteil bleibt (%0.1f)" % (top.power * (1.0 - top.energy_fraction)))
	t.ok(top.power > attack.power, "der Energieanteil waechst")


func test_the_weapon_bonus_grows_to_its_own_end_value() -> void:
	var build := _vireo()
	var base: int = build.stats()["spd"]
	build.weapon_levels["equip_left"] = 10
	t.equal(build.stats()["spd"], base + 1, "Blaster Speed 2 -> 3 auf Level 10, nicht doppelt")
	var molok := _molok()
	var hp: int = molok.stats()["hp_max"]
	molok.weapon_levels["equip_left"] = 10
	t.equal(molok.stats()["hp_max"], hp + 20, "Hammer Integritaet 20 -> 40")


func test_a_drome_level_raises_two_values_more_than_the_rest() -> void:
	var vireo := _vireo()
	var before := vireo.stats()
	vireo.drome_level = 5
	var after := vireo.stats()
	t.equal(after["hp_max"] - before["hp_max"], 40, "Integritaet ist Hauptwert: 80 -> 120 (+50 %)")
	t.equal(after["shield_max"] - before["shield_max"], 25, "Schild ist Hauptwert: 50 -> 75")
	t.equal(after["shield_pulse"], 6, "Schildpuls +20 %: 5 -> 6")
	t.equal(after["spd"], before["spd"], "Speed steigt nie")
	t.equal(after["power"], before["power"], "Power steigt nie")
	t.equal(after["module_slots"], 6, "Modulplaetze 3 -> 6 (Level 1, 3, 5)")
	var molok := _molok()
	molok.drome_level = 5
	t.equal(molok.stats()["module_slots"], 4, "Molok 2 -> 4 (Level 2, 4)")


func test_levels_reach_the_battle() -> void:
	var build := _vireo()
	build.weapon_levels["equip_left"] = 10
	var unit := Unit.create(build, &"P0", true)
	unit.init_realtime(0.0)
	var attack: ActionData = unit.mounts[0]["attack"]
	t.equal(attack.power, int(round(10 * 1.7)), "der Blaster schiesst auf Level 10 mit 17")
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
	t.equal(copy.weapon_levels, build.weapon_levels, "die Lauf-Kopie behaelt die Level")
	var saved := RosterEntry.from_dict(entry.to_dict())
	t.equal(saved.xp, entry.xp, "EP ueberstehen Speichern")
	var inst := PartInstance.from_dict(roster.instance(uid).to_dict())
	t.equal(inst.level, 3, "Waffenlevel uebersteht Speichern")


func test_run_xp_is_collected_and_credited_at_home_at_the_end() -> void:
	var saved_roster = GameState.roster
	var saved_run = GameState.run
	var roster := Roster.new()
	roster.seed_starter()
	GameState.roster = roster
	GameState.run = RunState.start(55, roster.squad_builds())
	var run: RunState = GameState.run
	var first: DromeBuild = run.squad[0]
	var slot: String = first.instance_uids.keys()[0]
	var fighters := [{"source_uid": first.source_uid,
		"weapons": {slot: {"damage": 200, "kills": 2}}}]
	run.choose_tier(RunState.Tier.ELITE)
	run.collect_xp(fighters, true)
	var entry := roster.entry_by_chassis(first.source_uid)
	var owned := roster.instance(str(first.instance_uids[slot]))
	t.equal(entry.xp, 0, "im Lauf noch nichts gutgeschrieben")
	t.equal(int(run.pending_xp["dromes"][first.source_uid]), Leveling.drome_win_xp("elite", 1),
		"der DROME sammelt EP fuer den Sieg")
	t.equal(int(run.pending_xp["weapons"][str(first.instance_uids[slot])]), 50 + 50,
		"die Waffe: 200 Schaden x 0,25 + 2 Abschuesse x 25")
	run.collect_xp(fighters, false)
	t.equal(int(run.pending_xp["dromes"][first.source_uid]), Leveling.drome_win_xp("elite", 1),
		"eine Niederlage gibt dem DROME nichts")
	t.equal(int(run.pending_xp["weapons"][str(first.instance_uids[slot])]), 200,
		"der Waffe schon (Schaden ist Schaden)")
	run.abandon()
	GameState.deliver_run_home()
	t.equal(entry.xp, Leveling.drome_win_xp("elite", 1), "am Ende zuhause gutgeschrieben")
	t.equal(owned.xp, 200, "die Waffe auch")
	t.equal(owned.level, 1, "200 EP: Waffenlevel 1")
	GameState.deliver_run_home()
	t.equal(owned.xp, 200, "nur einmal")
	GameState.roster = saved_roster
	GameState.run = saved_run
