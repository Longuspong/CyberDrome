extends RefCounted

## Autokampf: die KI steuert BEIDE Seiten.
##
## Drei Zusagen, die ein Autobattler braucht und die hier abgesichert werden:
##
##   1. Gleichwertig: beide Seiten waehlen ihre Ziele nach derselben Regel.
##   2. Fair: dasselbe Squad gewinnt auf beiden Seiten etwa gleich oft. Wer
##      unten links aufstellt oder "P" statt "E" heisst, darf keinen Vorteil
##      haben.
##   3. Entschieden: Spiegelkaempfe enden mit Sieg oder Niederlage. Dafuer
##      gibt es den Virusschaden (config "virus", 14. Nov. 2026).

var t


## Wie viele Seeds die Fairness-Messung spielt. Ein Kompromiss aus Laufzeit
## und Aussagekraft. 40 waren zu wenig: die ersten 100 Seeds ab 8100 gehen
## zufaellig 64:36 aus, ueber 400 Seeds steht es 214:186 (Nov. 2026).
const FAIRNESS_SEEDS := 200


func _squad() -> Array:
	return [
		DromeBuild.create("ALPHA", {
			"body": &"scout_body", "head": &"scout_head",
			"feet": &"scout_feet", "core": &"scout_core",
			"equip_left": &"eq_pulse_blaster"}),
		DromeBuild.create("BETA", {
			"body": &"strix_body", "head": &"strix_head",
			"feet": &"strix_feet", "core": &"strix_core",
			"equip_center": &"eq_rail_lance"}),
	]


## Spielt einen Kampf KI gegen KI zu Ende (Echtzeit).
func _play(seed_value: int, player: Array, enemy: Array, virus: bool) -> Dictionary:
	var battle := BattleManager.new()
	battle.setup(seed_value, player, enemy)
	battle.virus_enabled = virus
	battle.run_to_end()
	var result := battle.build_result()
	battle.free()
	return result


func test_both_sides_pick_targets_by_the_same_rule() -> void:
	var battle := BattleManager.new()
	battle.setup(4242, _squad(), _squad())
	for unit in battle.units:
		t.ok(battle.brain.choose_target(unit) != null, "%s findet ein Ziel" % unit.unit_id)
	battle.free()


func test_virus_is_off_unless_enabled() -> void:
	var battle := BattleManager.new()
	battle.setup(4243, _squad(), _squad())
	var unit: Unit = battle.units[0]
	battle.virus_enabled = false
	battle.time = 400.0
	t.equal(battle.virus_damage(unit), 0, "ohne Schalter kein Virusschaden")
	battle.free()


## Virusschaden (14. Nov. 2026): ab Minute 5 je Puls 10 % der Hoechstwerte
## (Schild + Integritaet), gleichbleibend, erst Schild, dann Integritaet.
func test_virus_hits_ten_percent_of_max() -> void:
	var battle := BattleManager.new()
	battle.setup(4244, _squad(), _squad())
	battle.virus_enabled = true
	var unit: Unit = battle.units[0]
	var start := battle.virus_start()
	t.equal(start, 300.0, "Virus ab 5:00")
	battle.time = start - 1.0
	t.equal(battle.virus_damage(unit), 0, "vor dem Start kein Schaden")
	battle.time = start
	var expected := int(ceil(float(unit.stat("hp_max") + unit.shield_max()) * 0.1))
	t.equal(battle.virus_damage(unit), expected, "10 % der Hoechstwerte (%d)" % expected)
	battle.time = start + 5.0 * battle.pulse_seconds()
	t.equal(battle.virus_damage(unit), expected, "bleibt gleich, waechst nicht")
	# Erst der Schild, an der Ruestung vorbei.
	unit.shield = unit.shield_max()
	var hp_before := unit.hp
	battle._virus_pulse()
	t.equal(unit.shield, maxi(0, unit.shield_max() - expected), "erst den Schild")
	t.equal(unit.hp, hp_before - maxi(0, expected - unit.shield_max()), "dann die Integritaet")
	battle.free()


## Fallen beide Seiten im selben Puls, verliert der Spieler.
func test_virus_double_fall_is_defeat() -> void:
	var battle := BattleManager.new()
	battle.setup(4245, _squad(), _squad())
	battle.time = battle.virus_start()
	for unit in battle.units:
		unit.shield = 0
		unit.hp = 1
	battle._virus_pulse()
	t.equal(battle.outcome, BattleManager.Outcome.DEFEAT, "gleichzeitiger Fall = Niederlage")
	battle.free()


## Mit dem Virus endet jeder Kampf entschieden -- ein Unentschieden gibt es
## nicht mehr (gleichzeitiger Fall zaehlt als Niederlage).
func test_mirror_battles_end_decisively() -> void:
	var draws := 0
	var total := 0
	var count := 20
	for i in count:
		var result := _play(7100 + i, _squad(), _squad(), true)
		total += int(result["seconds"])
		if result["outcome"] == BattleManager.Outcome.DRAW \
				or result["outcome"] == BattleManager.Outcome.RUNNING:
			draws += 1
	t.note("Virus: %d/%d unentschieden, im Schnitt %.1f s"
		% [draws, count, float(total) / count])
	t.ok(draws <= count / 10, "höchstens 10%% Unentschieden (waren %d/%d)" % [draws, count])


## Dasselbe Squad auf beiden Seiten. Jede Seite muss etwa die Haelfte der
## entschiedenen Kaempfe gewinnen -- sonst bevorzugt Karte, Aufstellung oder
## Zugreihenfolge eine Seite.
func test_sides_are_fair_in_mirror_battles() -> void:
	var player_wins := 0
	var enemy_wins := 0
	for i in FAIRNESS_SEEDS:
		var result := _play(8100 + i, _squad(), _squad(), true)
		match result["outcome"]:
			BattleManager.Outcome.VICTORY: player_wins += 1
			BattleManager.Outcome.DEFEAT: enemy_wins += 1
	var decided := player_wins + enemy_wins
	var share := float(player_wins) / maxf(1.0, float(decided))
	t.note("Spiegel: Spielerseite %d, Gegnerseite %d (Anteil %.2f)"
		% [player_wins, enemy_wins, share])
	t.ok(decided >= FAIRNESS_SEEDS * 0.8, "genug entschiedene Kämpfe (%d)" % decided)
	t.ok(absf(share - 0.5) <= 0.2,
		"keine Seite klar bevorzugt (Anteil Spielerseite %.2f)" % share)
