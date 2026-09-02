extends RefCounted

## Das Beute-System des Chaos-Virus (§Chaos).
##
## Die reine Rechnung (ChaosLoot) laesst sich ohne Szene pruefen; die Vergabe
## (GameState.roll_chaos_loot) mutiert den globalen Besitz -- der Test sichert
## den Stand und stellt ihn danach wieder her, damit die Reihenfolge der Suiten
## egal bleibt.

var t


func _rng(seed_value: int = 12345) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# ---------------------------------------------------------------------------
# ChaosLoot -- die reine Rechnung
# ---------------------------------------------------------------------------

func test_drop_chance_rises_with_handicap_and_stays_bounded() -> void:
	var c := Config.section("chaos")
	var base := float(c.get("loot_base", 0.15))
	var cap := float(c.get("loot_cap", 0.9))
	t.ok(is_equal_approx(ChaosLoot.drop_chance(0.0), base),
		"ohne Handicap ist die Chance der Grundwert")
	t.ok(ChaosLoot.drop_chance(1.0) > ChaosLoot.drop_chance(0.0),
		"mehr Handicap = mehr Chance")
	t.ok(ChaosLoot.drop_chance(1.0) <= cap + 0.0001,
		"die Chance ueberschreitet den Deckel nie")
	t.ok(ChaosLoot.drop_chance(5.0) <= cap + 0.0001,
		"auch ein ueberzogenes Handicap bleibt unter dem Deckel")


func test_roll_count_is_always_zero_to_two() -> void:
	for seed_value in range(40):
		var n := ChaosLoot.roll_count(0.5, 0, _rng(seed_value))
		t.ok(n >= 0 and n <= 2, "Beute-Zahl bleibt in 0..2 (war %d)" % n)


func test_pity_guarantees_a_drop() -> void:
	var threshold := int(Config.section("chaos").get("loot_pity_threshold", 4))
	# Ein Zug VOR der Schwelle -> der naechste Sieg ist garantiert, egal wie der
	# Wuerfel faellt.
	for seed_value in range(20):
		var n := ChaosLoot.roll_count(0.0, threshold - 1, _rng(seed_value))
		t.ok(n >= 1, "an der Pity-Schwelle faellt mindestens ein Teil")


func test_pick_draws_from_the_pool_without_inventing_parts() -> void:
	var pool := [&"eq_pulse_blaster", &"eq_deflector", &"eq_orbit_focus"]
	t.ok(ChaosLoot.pick(pool, 0, _rng()).is_empty(), "ohne Ziehung keine Beute")
	t.ok(ChaosLoot.pick([], 2, _rng()).is_empty(), "leerer Pool -> leere Beute")
	var two := ChaosLoot.pick(pool, 2, _rng())
	t.equal(two.size(), 2, "zwei angefragt, zwei gezogen")
	for part_id in two:
		t.ok(part_id in pool, "%s stammt aus dem Gegner-Pool" % part_id)
	# Solange der Pool reicht, keine Wiederholung.
	t.ok(two[0] != two[1], "zwei verschiedene Teile bei ausreichendem Pool")


func test_pick_may_repeat_when_the_pool_is_smaller_than_the_draw() -> void:
	var pool := [&"eq_pulse_blaster"]
	var two := ChaosLoot.pick(pool, 2, _rng())
	t.equal(two.size(), 2, "auch ein Ein-Teil-Pool liefert die volle Zahl")
	t.equal(two[0], &"eq_pulse_blaster", "und zwar dasselbe Teil")


# ---------------------------------------------------------------------------
# GameState.roll_chaos_loot -- die Vergabe
# ---------------------------------------------------------------------------

func _with_fresh_state(body: Callable) -> void:
	# Stand sichern ...
	var saved_roster = GameState.roster
	var saved_pity = GameState.chaos_pity
	var saved_ref = GameState.chaos_reference_power
	var saved_squad = GameState.squad
	var saved_loot = GameState.last_loot
	# ... frischen Startbestand aufsetzen ...
	GameState.roster = Roster.new()
	GameState.roster.seed_starter()
	GameState.squad = []
	GameState.chaos_reference_power = 1.0    # Squad leer -> Handicap 1.0
	GameState.chaos_pity = 0
	GameState.last_loot = []
	body.call()
	# ... und alles zuruecklegen.
	GameState.roster = saved_roster
	GameState.chaos_pity = saved_pity
	GameState.chaos_reference_power = saved_ref
	GameState.squad = saved_squad
	GameState.last_loot = saved_loot


func test_a_drop_lands_in_the_inventory_and_clears_pity() -> void:
	_with_fresh_state(func():
		var threshold := int(Config.section("chaos").get("loot_pity_threshold", 4))
		GameState.chaos_pity = threshold - 1   # der naechste Sieg ist garantiert
		var before := GameState.roster.all_instances().size()
		var dropped := GameState.roll_chaos_loot([&"eq_pulse_blaster"], _rng())
		t.ok(dropped.size() >= 1, "der garantierte Sieg wirft Beute ab")
		t.equal(GameState.roster.all_instances().size(), before + dropped.size(),
			"jedes Beute-Teil ist eine neue Instanz im Inventar")
		t.equal(GameState.chaos_pity, 0, "ein Drop setzt den Pity-Zaehler zurueck")
		t.equal(GameState.last_loot, dropped, "die letzte Beute ist gemerkt"))


## Der Kampfaufbau muss den Gegner an den Chaos-Feldern ausrichten, nicht am
## (womoeglich winzigen) eigenen Squad -- sonst waere ein kleiner Squad keine
## Erschwernis. Und der Beute-Pool muss mit der Gegner-Ausruestung gefuellt sein.
func test_battle_setup_uses_the_chaos_fields_not_the_squad_size() -> void:
	var saved_count = GameState.chaos_enemy_count
	var saved_ref = GameState.chaos_reference_power
	GameState.chaos_enemy_count = 3
	GameState.chaos_reference_power = 600.0

	var player := DromeBuild.create("SOLO", {
		"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core",
		"equip_left": &"eq_pulse_blaster"})
	var bm := BattleManager.new()
	bm.setup(4242, [player])

	var enemies := bm.units.filter(func(u): return not u.is_player)
	t.equal(enemies.size(), 3,
		"der Gegner tritt mit der Chaos-Anzahl an, nicht mit der Squad-Groesse 1")
	t.ok(not bm.enemy_equipment.is_empty(),
		"der Beute-Pool ist mit der Ausruestung der Gegner gefuellt")

	for u in bm.units:
		u.free()
	bm.free()
	GameState.chaos_enemy_count = saved_count
	GameState.chaos_reference_power = saved_ref


func test_an_empty_pool_drops_nothing_and_raises_pity() -> void:
	_with_fresh_state(func():
		var threshold := int(Config.section("chaos").get("loot_pity_threshold", 4))
		GameState.chaos_pity = threshold - 1   # selbst der garantierte Sieg ...
		var before := GameState.roster.all_instances().size()
		var dropped := GameState.roll_chaos_loot([], _rng())
		t.ok(dropped.is_empty(), "aus dem Nichts faellt nichts -- leerer Gegner-Pool")
		t.equal(GameState.roster.all_instances().size(), before,
			"das Inventar bleibt unveraendert")
		t.equal(GameState.chaos_pity, threshold, "und der Pity-Zaehler waechst")
		t.ok(GameState.last_loot.is_empty(), "keine Beute gemerkt"))
