extends RefCounted

## Autokampf: die KI steuert BEIDE Seiten.
##
## Drei Zusagen, die ein Autobattler braucht und die hier abgesichert werden:
##
##   1. Gleichwertig: beide Seiten haben dieselben Werkzeuge (Aggro-Tabelle).
##   2. Fair: dasselbe Squad gewinnt auf beiden Seiten etwa gleich oft. Wer
##      unten links aufstellt oder "P" statt "E" heisst, darf keinen Vorteil
##      haben.
##   3. Entschieden: Spiegelkaempfe enden mit Sieg oder Niederlage, nicht am
##      Zyklus-Limit. Dafuer gibt es die Overtime (config "overtime").

var t


## Wie viele Seeds die Fairness-Messung spielt. Ein Kompromiss aus Laufzeit
## und Aussagekraft -- bei 40 Kaempfen ist eine Abweichung von 50/50 um mehr
## als die Toleranz kein Rauschen mehr.
const FAIRNESS_SEEDS := 40


func _squad() -> Array:
	return [
		DromeBuild.create("ALPHA", {
			"body": &"scout_body", "head": &"scout_head",
			"feet": &"scout_feet", "core": &"scout_core",
			"equip_left": &"eq_pulse_blaster", "equip_right": &"eq_deflector"}),
		DromeBuild.create("BETA", {
			"body": &"strix_body", "head": &"strix_head",
			"feet": &"strix_feet", "core": &"strix_core",
			"equip_center": &"eq_rail_lance"}),
	]


## Spielt einen Kampf KI gegen KI zu Ende (Echtzeit).
func _play(seed_value: int, player: Array, enemy: Array, overtime: bool) -> Dictionary:
	var battle := BattleManager.new()
	battle.setup(seed_value, player, enemy)
	battle.overtime_enabled = overtime
	battle.run_to_end()
	var result := battle.build_result()
	battle.free()
	return result


func test_both_sides_keep_an_aggro_table() -> void:
	var battle := BattleManager.new()
	battle.setup(4242, _squad(), _squad())
	for unit in battle.units:
		t.ok(unit.aggro != null, "%s hat eine Aggro-Tabelle" % unit.unit_id)
	battle.free()


func test_overtime_is_off_unless_enabled() -> void:
	var battle := BattleManager.new()
	battle.setup(4243, _squad(), _squad())
	var unit: Unit = battle.units[0]
	battle.overtime_enabled = false
	battle.time = 400.0
	t.equal(battle.overtime_damage(unit), 0, "ohne Schalter kein Overtime-Schaden")
	battle.free()


func test_overtime_grows_with_each_cycle() -> void:
	var battle := BattleManager.new()
	battle.setup(4244, _squad(), _squad())
	battle.overtime_enabled = true
	var unit: Unit = battle.units[0]
	var start := float(Config.section("overtime").get("start_seconds", 60.0))

	battle.time = start - 1.0
	t.equal(battle.overtime_damage(unit), 0, "vor dem Start kein Schaden")
	battle.time = start
	var first := battle.overtime_damage(unit)
	battle.time = start + 3.0 * battle.pulse_seconds()
	var later := battle.overtime_damage(unit)
	t.ok(first > 0, "ab dem Start-Zyklus Schaden (%d)" % first)
	t.ok(later > first, "der Schaden waechst (%d -> %d)" % [first, later])
	battle.free()


## Ohne Overtime enden Spiegelkaempfe ueberwiegend unentschieden (gemessen:
## 3 von 4). Mit Overtime muss fast jeder entschieden werden -- und zwar,
## bevor das harte Zyklus-Limit greift.
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
	t.note("Overtime: %d/%d unentschieden, im Schnitt %.1f s"
		% [draws, count, float(total) / count])
	t.ok(draws <= count / 10, "hoechstens 10%% Unentschieden (waren %d/%d)" % [draws, count])


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
	t.ok(decided >= FAIRNESS_SEEDS * 0.8, "genug entschiedene Kaempfe (%d)" % decided)
	t.ok(absf(share - 0.5) <= 0.2,
		"keine Seite klar bevorzugt (Anteil Spielerseite %.2f)" % share)
