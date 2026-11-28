extends RefCounted

## Charger, Energy Phases, Lootcache-Inhalt (20. Nov. 2026,
## docs/CHARGER_KONZEPT.md).

var t


func _vireo(chargers: Dictionary = {}) -> DromeBuild:
	var build := DromeBuild.create("Vireo", {"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core", "equip_left": &"eq_pulse_blaster"})
	build.chargers = chargers
	return build


func _molok() -> DromeBuild:
	return DromeBuild.create("Molok", {"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core", "equip_left": &"eq_hammer"})


func _battle(phases: Array) -> BattleManager:
	var battle := BattleManager.new()
	battle.setup(4711, [_vireo({"equip_left": Charger.normalized(phases)})], [_molok()])
	return battle


func test_dominant_and_resonance() -> void:
	t.equal(Charger.dominant(["fire", "fire", "cryo", "", "", ""]), "fire", "Feuer überwiegt")
	t.equal(Charger.dominant(["fire", "cryo", "", "", "", ""]), "", "Gleichstand: keins")
	t.equal(Charger.resonance(["fire", "fire", "fire", "cryo", "", ""]), 2, "drei gleiche: Stufe 2")
	t.equal(Charger.resonance(["fire", "fire", "fire", "fire", "cryo", "cryo"]), 4, "vier: Stufe 4")
	t.equal(Charger.active_resonances(["fire", "fire", "fire", "fire", "fire", "fire"]).size(), 3,
		"sechs: alle drei Stufen zählen zusammen")
	t.equal(int(Charger.loads(["fire", "fire", "cryo", "", "", ""])["fire"]), 40, "20 je Phase")
	t.equal(Charger.ability_load(["fire", "fire", "", "", "", ""]), 100, "Stufe 2: Fähigkeit 100")
	t.equal(Charger.ability_load(["fire", "fire", "fire", "fire", "fire", "fire"]), 200, "Stufe 6: 200")
	t.equal(Charger.display_name(["volt", "volt", "fire", "", "", ""]), "Voltcharger", "Name nach Element")


func test_craft_consumes_blank_and_phases() -> void:
	var roster := Roster.new()
	t.ok(roster.charger_blocker(["fire"]) != "", "ohne Rohling geht nichts")
	roster.add_blanks(1)
	roster.add_phases("fire", 2)
	t.ok(roster.charger_blocker(["fire", "fire", "fire"]) != "", "zu wenig Phasen")
	var c := roster.craft_charger(["fire", "fire", "", "", "", ""])
	t.ok(not c.is_empty(), "gebaut")
	t.equal(roster.blanks(), 0, "Rohling verbraucht")
	t.equal(roster.phases("fire"), 0, "Phasen verbraucht")
	t.equal(roster.chargers.size(), 1, "liegt im Lager")


func test_charger_follows_the_weapon_into_the_build() -> void:
	var roster := Roster.new()
	roster.seed_starter()
	roster.add_blanks(2)
	roster.add_phases("fire", 4)
	var c := roster.craft_charger(["fire", "fire", "fire", "fire", "", ""])
	var entry: RosterEntry = roster.entries[0]
	var weapon_uid := str(entry.assignments.get("equip_left", entry.assignments.get("equip_right", "")))
	t.ok(weapon_uid != "", "Start-DROME hat eine Waffe")
	t.ok(roster.mount_charger(str(c["uid"]), weapon_uid), "eingesetzt")
	var build := roster.build_for(entry)
	var found := false
	for slot in build.chargers:
		found = found or Charger.filled(build.chargers[slot]) == 4
	t.ok(found, "der Charger steckt im Build")
	var copy := Roster.new()
	copy.load_dict(roster.to_dict())
	t.equal(str(copy.charger_on(weapon_uid).get("uid", "")), str(c["uid"]), "bleibt nach dem Speichern")
	var saved := DromeBuild.from_save(build.to_save())
	t.equal(saved.chargers.size(), build.chargers.size(), "auch im Lauf-Spielstand")


func test_hits_build_fire_stacks() -> void:
	var battle := _battle(["fire", "fire", "fire", "fire", "fire", ""])
	var vireo: Unit = battle.units[0]
	var molok: Unit = battle.units[1]
	molok.stats["hp_max"] = 9999
	molok.hp = 9999
	var attack: ActionData = vireo.mounts[0]["attack"]
	t.ok(not attack.charger.is_empty(), "Angriff trägt den Charger")
	battle.resolver.apply_damage(vireo, molok, 1, attack)
	t.equal(molok.cable_fire_stacks(), 1, "5 Feuer-Phasen: 100 je Treffer = ein Stapel")
	battle.free()


func test_resonance_four_doubles_every_fifth_hit() -> void:
	var battle := _battle(["fire", "fire", "fire", "fire", "", ""])
	var vireo: Unit = battle.units[0]
	var molok: Unit = battle.units[1]
	molok.stats["hp_max"] = 9999
	molok.hp = 9999
	var attack: ActionData = vireo.mounts[0]["attack"]
	for i in 4:
		battle.resolver.apply_damage(vireo, molok, 1, attack)
	t.equal(molok.cable_fire_stacks(), 3, "4 x 80 = 320: drei Stapel")
	battle.resolver.apply_damage(vireo, molok, 1, attack)
	t.equal(molok.cable_fire_stacks(), 4, "5. Treffer doppelt: 480")
	battle.free()


func test_ability_sets_a_stack_of_the_dominant_element() -> void:
	var battle := _battle(["fire", "cryo", "fire", "", "", ""])
	var vireo: Unit = battle.units[0]
	var molok: Unit = battle.units[1]
	molok.stats["hp_max"] = 9999
	molok.hp = 9999
	var ability = vireo.mounts[0]["ability"]
	t.ok(ability != null, "Blaster hat eine Fähigkeit")
	battle.resolver.apply_damage(vireo, molok, 1, ability)
	# 40 + 100 (Stufe 2) = 140 -> 1 Stapel, dazu 1 Stapel direkt
	t.equal(molok.cable_fire_stacks(), 2, "Fähigkeit: Stapel direkt + 100 Belastung")
	t.ok(molok.element_load.has("cryo"), "Cryo wird gezählt")
	battle.free()


func test_open_cache_rolls_four_times() -> void:
	var roster := Roster.new()
	roster.caches["city"] = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var results := roster.open_cache("city", rng)
	t.equal(results.size(), 4, "vier Würfe")
	t.equal(int(roster.caches.get("city", 0)), 0, "Cache verbraucht")
	var phases := 0
	for id in Charger.element_ids():
		phases += roster.phases(id)
	var gained := phases + roster.blanks() + roster.faction_cores("neon")
	t.ok(gained > 0 or roster.coins > 0 or roster.entries.size() > 0, "Beute gutgeschrieben")
	t.equal(roster.open_cache("city", rng).size(), 0, "leeres Lager: nichts")


func test_resonance_six_upgrades_fifth_to_third() -> void:
	t.equal(Charger.double_every(["fire", "fire", "fire", "fire", "", ""]), [5], "Stufe 4: jeder 5.")
	t.equal(Charger.double_every(["fire", "fire", "fire", "fire", "fire", "fire"]), [3],
		"Stufe 6: jeder 3. statt jeder 5.")


## Bugfix 24. Nov. 2026: eine Salve (Doppelschuss = 2 x 3 Schuesse) zaehlt je
## Salve als EIN Treffer, und der Bonus der Faehigkeit kommt je Ziel nur
## einmal -- vorher legte jede Kugel ihn neu an (rund 14 Stapel statt 2).
func test_a_salvo_counts_as_one_hit_and_the_bonus_once() -> void:
	var battle := _battle(["fire", "fire", "", "", "", ""])
	var vireo: Unit = battle.units[0]
	var molok: Unit = battle.units[1]
	molok.stats["hp_max"] = 9999
	molok.hp = 9999
	battle.resolver.move_unit(molok, Grid.neighbor(vireo.tile, 1))
	var ability: ActionData = vireo.mounts[0]["ability"]
	t.equal(ability.salvo, 3, "Doppelschuss: Salven aus 3 Schuessen")
	t.ok(battle.resolver.execute(vireo, molok.tile, ability), "Doppelschuss ausgefuehrt")
	for i in 40:
		battle.resolver.advance(0.05)
	# 2 Salven x 40 + 100 (Stufe 2) = 180 -> 1 Stapel, dazu 1 Stapel direkt.
	t.equal(molok.cable_fire_stacks(), 2, "zwei Stapel je Doppelschuss")
	t.ok(is_equal_approx(float(molok.element_load.get("fire", 0.0)), 80.0), "Rest 80 Belastung")
	battle.free()


func test_the_guard_takes_no_element_load() -> void:
	var battle := _battle(["fire", "fire", "fire", "fire", "fire", ""])
	var vireo: Unit = battle.units[0]
	var molok: Unit = battle.units[1]
	molok.stats["hp_max"] = 9999
	molok.hp = 9999
	var attack: ActionData = vireo.mounts[0]["attack"]
	battle.resolver.apply_damage(vireo, molok, 10, attack, false, 0.0, false)
	t.equal(molok.cable_fire_stacks(), 0, "ohne Anteil keine Belastung")
	battle.free()
