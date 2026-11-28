extends RefCounted

## Nimbus als Supporter (Werkblatt 27. Nov. 2026, gebaut 28. Nov.): Repair-Kit,
## Cleancode mit Bug-Fix und Shieldgate, dazu die Fraktionsvarianten mit
## eigener Passive und Halterregel (Neon Nimbus, Neon Vireo).

var t


func _nimbus() -> DromeBuild:
	return DromeBuild.create("Nimbus", {"body": &"mage_body", "head": &"mage_head",
		"feet": &"mage_drive", "core": &"mage_core", "equip_left": &"eq_repair_kit"})


func _molok() -> DromeBuild:
	return DromeBuild.create("Molok", {"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core", "equip_left": &"eq_hammer"})


func _vireo() -> DromeBuild:
	return DromeBuild.create("Vireo", {"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core", "equip_left": &"eq_pulse_blaster"})


## Kampf mit festen Feldern (wie tests/test_ai.gd).
func _battle(players: Array, enemies: Array, tiles: Array) -> BattleManager:
	var battle := BattleManager.new()
	battle.setup(4242, players, enemies)
	battle.grid.width = 12
	battle.grid.height = 20
	battle.grid.obstacles.clear()
	for unit in battle.units:
		battle.grid.clear_occupant(unit.tile)
	for i in battle.units.size():
		var unit: Unit = battle.units[i]
		unit.place_at(tiles[i])
		battle.grid.set_occupant(tiles[i], unit.unit_id)
	return battle


func _action(unit: Unit, id: StringName) -> ActionData:
	for action in unit.actions():
		if action.id == id:
			return action
	return null


func _rule(key: String) -> float:
	return float((Config.section("passives").get("cleancode", {}) as Dictionary).get(key, 0))


func test_the_nimbus_is_a_supporter_with_the_repair_kit() -> void:
	var build := _nimbus()
	t.ok(build.is_valid(), "Repair-Kit passt in den Nimbus-Halter")
	var unit := Unit.create(build, &"N", true)
	t.equal(unit.passive(), "cleancode", "Passive Cleancode")
	t.equal(unit.ai_role(), "support", "Rolle Supporter")
	t.equal(int(build.stats()["spd"]), 8, "Speed 8")
	t.equal(int(build.stats()["shield_pulse"]), 5, "Schildpuls 5")
	unit.free()
	var roster := Roster.new()
	roster.seed_starter()
	var start := roster.build_for(roster.entries[3])
	t.ok(start.equipment().any(func(p): return p.id == &"eq_repair_kit"), "Start-Nimbus traegt das Repair-Kit")
	t.equal(roster.free_count(&"eq_rune_staff"), 1, "der Runenstab liegt frei im Lager")


func test_the_repair_wave_is_a_drone_swarm_with_cleancode() -> void:
	# Spieler 28. Nov. 2026: kein reines Heilwerkzeug -- das Kit schiesst,
	# speichert den Schaden und gibt ihn per Drohnenschwarm allen zurueck.
	var battle := _battle([_nimbus(), _molok()], [_vireo()],
		[Vector2i(4, 16), Vector2i(4, 14), Vector2i(4, 12)])
	var nimbus: Unit = battle.units[0]
	var molok: Unit = battle.units[1]
	var foe: Unit = battle.units[2]
	var bolt := _action(nimbus, &"act_repair_bolt")
	var wave := _action(nimbus, &"act_repair_release")
	t.ok(bolt != null and bolt.power > 0, "der Angriff macht Schaden")
	t.equal(AbilityPainter.kind_for(wave), "drones", "die Welle zeigt den Drohnenschwarm")
	battle.resolver.apply_damage(nimbus, foe, 30, bolt)
	t.ok(nimbus.store_shield > 0, "Schildschaden wird gespeichert (%d)" % nimbus.store_shield)
	molok.hp -= 80
	molok.shield = 0
	var hp_before := molok.hp
	var stored := nimbus.store_shield
	battle.resolver.execute(nimbus, nimbus.tile, wave)
	t.ok(molok.shield >= int(floor(stored * nimbus.efficiency_factor())),
		"Schild = Speicher mal Effizienz (%d)" % molok.shield)
	t.equal(nimbus.store_shield, 0, "der Speicher ist danach leer")
	t.ok(molok.bug_fix.size() == 1 and nimbus.bug_fix.size() == 1,
		"Cleancode: jeder, der etwas bekommt, erhaelt Bug-Fix (auch der Nimbus)")
	t.ok(molok.hp >= hp_before, "Integritaet sinkt nicht")
	battle.free()


func test_cleancode_gives_bug_fix_stacks() -> void:
	var battle := _battle([_nimbus(), _molok()], [_vireo()],
		[Vector2i(4, 16), Vector2i(4, 14), Vector2i(4, 4)])
	var nimbus: Unit = battle.units[0]
	var molok: Unit = battle.units[1]
	var armor := molok.def()
	for i in 4:
		molok.receive_care(nimbus)
		if i == 0:
			t.equal(molok.bug_fix.size(), 1, "ein Stapel Bug-Fix")
			t.equal(molok.def(), armor + int(_rule("def")), "+%d Ruestung" % int(_rule("def")))
			t.equal(molok.shieldgate(), int(_rule("shieldgate")), "+%d Shieldgate" % int(_rule("shieldgate")))
	t.equal(molok.bug_fix.size(), int(_rule("max_stacks")), "hoechstens %d Stapel" % int(_rule("max_stacks")))
	t.ok(molok.status_names().count("bug_fix") == molok.bug_fix.size(), "ein Symbol je Stapel")
	# Nur Cleancode gibt Bug-Fix -- ein anderer Helfer (Molok) nicht.
	t.ok(not nimbus.receive_care(molok), "ohne Cleancode kein Bug-Fix")
	# Dauer: stack_seconds mal Effizienz des Nimbus (12 = 120 %).
	var seconds := _rule("stack_seconds") * nimbus.efficiency_factor()
	molok.tick_statuses(seconds - 0.1)
	t.equal(molok.bug_fix.size(), int(_rule("max_stacks")), "kurz vor Ablauf noch alle")
	molok.tick_statuses(0.2)
	t.equal(molok.bug_fix.size(), 0, "nach %.1f s laufen sie ab" % seconds)
	t.equal(molok.def(), armor, "die Ruestung ist wieder normal")
	battle.free()


func test_shieldgate_softens_hits_on_the_shield() -> void:
	var battle := _battle([_nimbus(), _molok()], [_vireo()],
		[Vector2i(4, 16), Vector2i(4, 14), Vector2i(4, 4)])
	var molok: Unit = battle.units[1]
	molok.shield = 50
	var plain: Dictionary = battle.resolver.resolve_damage(molok, 30, 0.0)
	molok.bug_fix = [5.0, 5.0, 5.0]
	var gated: Dictionary = battle.resolver.resolve_damage(molok, 30, 0.0)
	t.ok(int(gated["shield_after"]) > int(plain["shield_after"]),
		"mit Shieldgate bleibt mehr Schild (%d statt %d)" % [gated["shield_after"], plain["shield_after"]])
	battle.free()


func test_neon_nimbus_keeps_the_old_nimbus() -> void:
	var build := Formations.build_drome("neon_nimbus")
	var unit := Unit.create(build, &"NN", false)
	t.equal(unit.passive(), "echo", "Neon Nimbus behaelt Echo")
	t.equal(unit.ai_role(), "controller", "und die Kontrolle")
	t.equal(int(build.stats()["power"]), 15, "Power 15")
	t.equal(int(build.stats()["efficiency"]), 5, "Effizienz 5 (kein CC-Meister)")
	t.ok(build.equipment().any(func(p): return p.id == &"eq_rune_staff"), "mit Runenstab")
	unit.free()
	t.equal(PartDB.get_part(&"mage_body").passive, "cleancode", "das Chassis selbst bleibt beim Nimbus")


func test_neon_vireo_has_a_medium_melee_holder() -> void:
	var build := Formations.build_drome("neon_vireo")
	var body := build.body()
	t.equal(SlotRules.holder_code(body, "equip_left"), "M-N", "Halter M-N")
	t.ok(body.accepts(PartDB.get_part(&"eq_plasma_blade"), "equip_left"), "Plasmaklinge passt")
	t.ok(not body.accepts(PartDB.get_part(&"eq_pulse_blaster"), "equip_left"), "Puls-Blaster (Fernkampf) nicht")
	t.ok(build.is_valid(), "Neon Vireo ist kampfbereit")
	t.equal(SlotRules.holder_code(PartDB.get_part(&"scout_body"), "equip_left"), "S",
		"der normale Vireo bleibt bei S")
	# Auch als eigener DROME im Hangar (Roster-Variante).
	var roster := Roster.new()
	roster.seed_starter()
	var entry := roster.craft_drome_free(&"scout_body", "Neon Vireo")
	entry.variant = "neon_vireo"
	var own := roster.build_for(entry)
	t.equal(SlotRules.holder_code(own.body(), "equip_left"), "M-N", "im Hangar ebenso M-N")
	t.ok(own.clone().body().accepts(PartDB.get_part(&"eq_hammer"), "equip_left"),
		"der Hammer (mittel, Nahkampf) passt, auch nach clone()")
