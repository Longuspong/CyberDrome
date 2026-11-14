extends RefCounted

## Formationen, Sentinels und Gegner-DROMEs (data/formations.json,
## scripts/core/formations.gd, 14. Nov. 2026).
##
## Die Formationen sind Daten, die der Spieler aendern soll -- deshalb prueft
## diese Suite, dass jede Stufe jeder Formation in jeder Variante baubar ist,
## und dass die Regeln aus dem SPOT-Blatt Fragen gelten.

var t


func test_every_formation_builds_at_every_level_and_tier() -> void:
	var ids := {}
	for entry in Formations.all():
		var id := str(entry.get("id", ""))
		t.ok(id != "" and not ids.has(id), "Formation '%s' ist gesetzt und einmalig" % id)
		ids[id] = true
		t.ok(str(entry.get("name", "")) != "" and str(entry.get("idea", "")) != "",
			"%s hat Name und Grundgedanken" % id)
		for level in range(1, 13):
			for key in RunState.TIER_KEYS:
				var foes := Formations.build(entry, level, key, 1000 + level)
				var dromes := foes.filter(func(b): return not b.is_sentinel())
				t.ok(dromes.size() >= 1 and dromes.size() <= Formations.MAX_DROMES,
					"%s L%d %s: 1-2 DROMEs" % [id, level, key])
				t.ok(foes.size() >= 3, "%s L%d %s: mindestens drei Einheiten" % [id, level, key])
				for build in foes:
					t.ok(not build.equipment().is_empty(), "%s: %s hat eine Waffe" % [id, build.display_name])
					for slot in build.modules:
						for module_id in build.modules[slot]:
							t.ok(ModuleData.get_module(module_id) != null, "Modul %s gibt es" % module_id)


func test_sentinels_follow_the_rules() -> void:
	var sentinel := Formations.build_sentinel("neon_assault")
	t.ok(sentinel.is_sentinel(), "ein Sentinel")
	t.ok(sentinel.auto_only, "nur Auto-Angriff")
	t.equal(sentinel.sprite_scale, 0.6, "60 % groß")
	t.ok(sentinel.modules.is_empty(), "Basic ohne Modul")
	var stats := sentinel.stats()
	t.equal(int(stats["hp_max"]), 60, "Integrität laut Blatt")
	t.equal(int(stats["shield_max"]), 20, "Schild laut Blatt")
	t.equal(int(stats["power"]), 5, "eigene, schwächere Power")
	t.equal(sentinel.weapons()[0].id, &"eq_plasma_blade", "feste Waffe")
	var elite := Formations.build_sentinel("neon_assault", "elite")
	t.equal(int(elite.stats()["hp_max"]), 72, "Elite: Integrität x 1,2")
	var elite_modules := 0
	for slot in elite.modules:
		elite_modules += (elite.modules[slot] as Array).size()
	t.equal(elite_modules, 1, "Elite trägt ein festes Modul")
	var heavy := Formations.build_sentinel("mecha_assault", "heavy")
	t.equal(int(heavy.stats()["hp_max"]), 144, "Heavy: Integrität x 1,8")
	t.equal(int(heavy.stats()["def"]), 7, "Heavy: Rüstung + 2")


func test_sentinels_only_auto_attack_in_battle() -> void:
	var battle := BattleManager.new()
	var player := RunState.standard_squad()
	battle.setup(4242, player, [Formations.build_sentinel("neon_assault"),
		Formations.build_sentinel("neon_support")])
	for unit in battle.units:
		if unit.is_sentinel():
			t.equal(unit.passive(), "", "%s ohne Passive" % unit.display_name)
			for mount in unit.mounts:
				t.ok(mount["ability"] == null, "%s ohne Fähigkeit" % unit.display_name)
	battle.free()


func test_enemy_dromes_have_fixed_values() -> void:
	var vireo := Formations.build_drome("neon_vireo")
	var stats := vireo.stats()
	t.equal(int(stats["hp_max"]), 80, "Neon Vireo: Integrität 80")
	t.equal(int(stats["shield_max"]), 50, "Schild 50")
	t.equal(int(stats["spd"]), 12, "Speed 12")
	t.ok(not vireo.is_sentinel(), "ein DROME")
	var plain := Formations.build_drome("molok")
	t.ok(plain.stat_override.is_empty(), "Standard-Molok rechnet wie ein Spieler-DROME")


func test_variants_make_easy_easier_and_elite_harder() -> void:
	var entry := Formations.formation("neon_squad")
	var easy := DromeBuild.squad_power(Formations.build(entry, 5, "easy", 7))
	var normal := DromeBuild.squad_power(Formations.build(entry, 5, "normal", 7))
	var elite := DromeBuild.squad_power(Formations.build(entry, 5, "elite", 7))
	t.note("Neon-Squad L5: Leicht %d, Normal %d, Elite %d" % [easy, normal, elite])
	t.ok(easy < normal and normal < elite, "Leicht < Normal < Elite")


func test_enemy_dromes_get_more_modules_with_reinforcement() -> void:
	var entry := Formations.formation("neon_squad")
	var count := func(level: int) -> int:
		var total := 0
		for build in Formations.build(entry, level, "normal", 99):
			if build.is_sentinel():
				continue
			for slot in build.modules:
				total += (build.modules[slot] as Array).size()
		return total
	t.equal(count.call(1), 0, "Level 1: keine Module")
	t.ok(count.call(8) > count.call(2), "später mehr Module")
