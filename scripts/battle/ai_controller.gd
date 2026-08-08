class_name AIController
extends RefCounted

## Gegner-KI. Bewusst simpel, aber nicht dumm.
##
## Nutzenbasiert, ein Durchlauf pro Zug: jede Kombination aus (Zielfeld,
## Aktion, Ziel) bekommt einen Score, die beste wird ausgefuehrt, dann von
## vorn -- solange Budgets uebrig sind und der Score positiv ist.
##
## Die Gewichte stehen in data/config.json und nicht hier. Eine KI, deren
## Verhalten man nur durch Neukompilieren aendern kann, wird nicht getunt.
##
## ### Aggro ist ein Summand, kein Filter
##
## Die Aggro-Tabelle (scripts/battle/aggro_table.gd) ERSETZT die Zielwahl
## nicht, sie geht als weiterer Term in dieselbe Bewertung ein. Der Unterschied
## ist nicht kosmetisch: als Filter wuerde ein Gegner an einem sicheren Abschuss
## vorbeilaufen, weil ein anderer DROME weiter oben in der Tabelle steht. Das
## liest sich als Fehler, nicht als Aggro.
##
## Eingehaengt wird der ANTEIL am Tabellenmaximum (0..1), nicht der Rohwert.
## Der Rohwert waechst ueber das Gefecht unbegrenzt und liefe sonst gegen
## Schadenspunkte davon; der Anteil traegt dieselbe Rangfolge und skaliert mit
## jeder Balancing-Aenderung von selbst mit.
##
## Der EINZIGE harte Zwang ist die Provokation -- und die steht nicht hier,
## sondern in ActionResolver.target_blocker(), weil sie eine Regel ueber
## gueltige Ziele ist und fuer beide Seiten gelten muss.

var battle: BattleManager
var _weights: Dictionary = {}


func _init(manager: BattleManager) -> void:
	battle = manager
	_weights = Config.section("ai")


func _w(key: String, fallback: float) -> float:
	return float(_weights.get(key, fallback))


## EINEN Schritt planen und sofort ausfuehren. Gibt den ausgefuehrten Schritt
## zurueck, oder leer, wenn nichts mehr sinnvoll ist.
##
## Bewusst Schritt fuer Schritt und nicht ein Plan fuer den ganzen Zug: ein im
## Voraus geplanter zweiter Schritt geht davon aus, dass der DROME noch am
## Ausgangsfeld steht. Nach dem ersten Schritt stimmt das nicht mehr -- er
## liefe dann auf ein Feld, das er aus einer Lage berechnet hat, die es nicht
## mehr gibt. Und auf einer Drift-Zone landet er ohnehin woanders, als der
## Plan annahm.
func take_step() -> Dictionary:
	var best := _best_move()
	if not best.is_empty():
		if best["move_to"] != battle.active_unit.tile:
			battle.move_active_to(best["move_to"])
		# Das Ziel wird nach dem Laufen erneut gefragt: die Bewegung kann
		# durch Drift woanders geendet haben als geplant.
		if battle.resolver.target_blocker(battle.active_unit,
				best["target"].tile, best["action"]) == "":
			battle.use_action(best["target"].tile, best["action"])
			_remember_target(battle.active_unit, best)
			return best
		return {"kind": "move", "move_to": battle.active_unit.tile}

	var approach := _approach_step()
	if not approach.is_empty():
		battle.move_active_to(approach["move_to"])
		return approach
	return {}


## Spielt den kompletten Zug. Die Szene ruft stattdessen take_step() einzeln
## auf, um zwischen den Schritten eine Pause einzulegen.
func run_turn(max_steps: int = 6) -> Array:
	var done: Array = []
	for _i in max_steps:
		if battle.outcome != BattleManager.Outcome.RUNNING:
			break
		var step := take_step()
		if step.is_empty():
			break
		done.append(step)
	return done


# ---------------------------------------------------------------------------
# Bewertung
# ---------------------------------------------------------------------------

func _best_move() -> Dictionary:
	var unit := battle.active_unit
	var state := battle.turn_state
	if unit == null or state == null:
		return {}

	var best := {}
	var best_score := -INF

	# Kandidatenfelder: bleiben, wo man ist, plus alles Erreichbare.
	var positions := {unit.tile: true}
	if state.can_move():
		for landing in battle.reachable_for_active():
			positions[landing] = true

	for tile in positions:
		var position_score := _position_score(unit, tile)
		for action in unit.actions():
			if state.blocker_for(action) != "":
				continue
			for candidate in _targets_from(unit, tile, action):
				var value := _action_score(unit, action, candidate)
				# Der Stellungswert entscheidet, VON WO angegriffen wird --
				# nicht OB. Zaehlte er in dieselbe Schwelle, veto'te ein
				# bedrohtes Zielfeld jeden normalen Angriff: zwei Gegner in
				# Reichweite sind schon -16, und ein Treffer macht 12. Die KI
				# stuende dann bis zum Zyklus-Limit daneben und schoesse nie.
				if value <= 0.0:
					continue
				var score := value + position_score
				if score > best_score:
					best_score = score
					best = {
						"kind": "action",
						"move_to": tile,
						"action": action,
						"target": candidate,
						"score": score,
					}
	return best


## Wie gut ist es, hier zu stehen? Unabhaengig davon, was man von hier tut.
func _position_score(unit: Unit, tile: Vector2i) -> float:
	var score := 0.0
	var grid := battle.grid

	# Wer das Zielfeld beschiessen kann, macht es unattraktiv.
	for foe in battle.enemies_of(unit):
		if _can_strike(foe, tile):
			score -= _w("exposed_penalty", 8.0)

	# Nicht freiwillig auf Eis parken.
	if grid.terrain_class(tile) == Terrain.TClass.DRIFT \
			and not unit.stats.get("ignores_drift", false):
		score -= _w("drift_penalty", 15.0)

	# Angeschlagene Fernkaempfer ziehen sich in den Nebel zurueck: dort sind
	# sie auf Distanz weder angreifbar noch angriffsfaehig, und genau das ist
	# der Zyklus, den sie zum Durchatmen brauchen.
	if grid.terrain_class(tile) == Terrain.TClass.HAZE:
		if unit.hp_fraction() < _w("haze_hp_threshold", 0.5) and not _has_melee(unit):
			score += _w("haze_bonus", 12.0)
	return score


func _has_melee(unit: Unit) -> bool:
	for action in unit.actions():
		if action.is_attack() and action.range_tiles <= 1:
			return true
	return false


## Koennte dieser Gegner das Feld unter Beschuss nehmen? Grobe Abschaetzung
## ueber die Distanz -- eine vollstaendige Reichweitenrechnung fuer jeden
## Gegner auf jedem Feld waere fuer den Gewinn zu teuer.
##
## Hat mit der Aggro-Tabelle nichts zu tun: hier geht es um die Gefahr eines
## FELDES, dort um die Aufmerksamkeit gegenueber einer EINHEIT.
func _can_strike(foe: Unit, tile: Vector2i) -> bool:
	var reach := foe.stat("mov")
	for action in foe.actions():
		if action.is_attack():
			reach = maxi(reach, foe.stat("mov") + action.range_tiles)
	return Grid.distance(foe.tile, tile) <= reach


func _targets_from(unit: Unit, from_tile: Vector2i, action: ActionData) -> Array:
	# Die Reichweitenpruefung geht vom geplanten Feld aus, nicht vom
	# aktuellen. Sonst plant die KI Angriffe, die nach dem Laufen nicht mehr
	# gehen -- oder verwirft welche, die dann gerade gehen.
	var saved := unit.tile
	unit.tile = from_tile
	var out: Array = []
	var pool := battle.enemies_of(unit) if not action.is_heal() else battle.allies_of(unit)
	for other in pool:
		if battle.resolver.target_blocker(unit, other.tile, action) == "":
			out.append(other)
	unit.tile = saved
	return out


func _action_score(unit: Unit, action: ActionData, target: Unit) -> float:
	var score := 0.0
	if action.is_heal():
		if unit.hp_fraction() >= _w("heal_hp_threshold", 0.4) and target == unit:
			return 0.0
		var missing := target.stat("hp_max") - target.hp
		if missing <= 0:
			return 0.0
		score = float(mini(action.heal_amount(), missing))
		if target.hp_fraction() < _w("heal_hp_threshold", 0.4):
			score *= _w("heal_multiplier", 1.5)
		return score

	# Der Wert einer Provokation steckt nicht im Schaden -- meistens richtet
	# sie gar keinen an --, sondern in dem Angriff, den sie verhindert.
	if action.is_taunt():
		score += _taunt_score(unit, action, target)
		if action.power <= 0:
			return score

	var damage := battle.resolver.preview_damage(unit, target, action)
	score += float(damage) * _w("damage_weight", 1.0)
	if damage >= target.hp:
		score += _w("kill_bonus", 100.0)
	score += _aggro_score(unit, target)
	return score


## Der Aggro-Anteil der Bewertung. Zwei Summanden mit verschiedenen Aufgaben:
## der Anteil an der Tabelle sagt WEN dieser Gegner am liebsten haette, der
## Amtsinhaber-Bonus verhindert, dass die Zielwahl bei fast gleichauf liegenden
## Werten von Zug zu Zug flackert. Ohne den zweiten wirkt die Aggro fuer den
## Spieler wie Zufall und laesst sich nicht steuern.
func _aggro_score(unit: Unit, target: Unit) -> float:
	if unit.aggro == null or unit.aggro.is_empty():
		return 0.0
	var score := unit.aggro.share(target.unit_id) * _w("aggro_weight", 10.0)
	if unit.aggro.current_target == target.unit_id:
		score += _incumbent_bonus(unit)
	return score


## Was ist es wert, ein feindliches Ziel auf sich selbst umzulenken?
##
## Der Schaden taugt dafuer nicht als Mass: eine Provokation richtet keinen an,
## und `preview_damage` liefert dann die Mindestmenge 1. Damit waere die
## staerkste Aktion im Spiel die billigste der Bewertung -- die KI besaesse
## sie und benutzte sie nie.
##
## Gerechnet wird deshalb in LEBENSLEISTEN statt in Schadenspunkten. Nicht wie
## viel Schaden umgelenkt wird, entscheidet, sondern wie viel er dort und hier
## jeweils AUSMACHT: zwoelf Schaden auf einen angeschlagenen Techniker sind
## etwas anderes als zwoelf Schaden auf ein volles Molok-Chassis.
##
##     gewinn = anteil_beim_opfer - anteil_bei_mir     (je Zug, in Leisten)
##
## Daraus faellt das gewuenschte Verhalten heraus, ohne dass irgendwo "Tank"
## steht -- dieselbe Emergenz, auf der auch die Aggro selbst beruht:
##
##   * Ein dickes Chassis provoziert, weil sein eigener Anteil klein ist.
##   * Ein duenner Gegner laesst es bleiben: sein Anteil ist groesser als der
##     des Opfers, der Gewinn negativ. Er wuerde sich nur selbst verheizen.
##   * Wer ohnehin schon das Ziel ist, gewinnt nichts -- das Opfer ist dann er
##     selbst, und der Gewinn ist exakt null. Kein Sonderfall noetig.
##
## Die Obergrenze ist bewusst gesetzt: mehr als eine ganze Lebensleiste laesst
## sich nicht retten, egal wie lange die Sperre haelt. Zusammen mit
## ``rescue_bonus`` bleibt der beste denkbare Wert damit unter ``kill_bonus``
## -- ein sicherer Abschuss geht der Umlenkung vor, und das soll er auch.
func _taunt_score(unit: Unit, action: ActionData, target: Unit) -> float:
	# Eine Sperre, die schon steht, noch einmal zu setzen bringt nichts --
	# dieselbe Ueberlegung wie eine Heilung auf Vollleben. Ohne das erneuert
	# die KI sie jeden Zug und macht aus einer befristeten Zwangsmechanik eine
	# dauerhafte.
	if target.taunted_by() == unit.unit_id:
		return 0.0

	var victim := _most_endangered_by(target, unit)
	if victim.is_empty():
		return 0.0                      # das Ziel bedroht gerade niemanden

	var incoming := _best_damage(target, unit)
	var to_me := float(incoming) / maxf(1.0, float(unit.hp))
	var gain: float = float(victim["share"]) - to_me
	if gain <= 0.0:
		return 0.0

	var saved := minf(gain * float(action.taunt_turns), 1.0)
	var score := saved * _w("taunt_weight", 50.0)

	# Einen Abschuss zu verhindern ist mehr wert als Schaden zu verteilen --
	# aber nur, wenn der Treffer mich nicht seinerseits umlegt. Sonst tauscht
	# die KI einen Verlust gegen einen anderen.
	var doomed: Unit = victim["unit"]
	if doomed != unit and int(victim["damage"]) >= doomed.hp and incoming < unit.hp:
		score += _w("rescue_bonus", 45.0)
	return score


## Der staerkste Angriff, den ``attacker`` gegen ``victim`` fuehren koennte.
##
## Ohne Ruecksicht auf Reichweite, Budget und Energie -- eine Abschaetzung wie
## _can_strike() eine ist. Die genaue Rechnung fuer jede Einheit gegen jede
## andere waere fuer den Gewinn zu teuer, und die Zahl geht ohnehin nur als
## Verhaeltnis in die Bewertung ein.
func _best_damage(attacker: Unit, victim: Unit) -> int:
	var best := 0
	for action in attacker.actions():
		if action.is_attack():
			best = maxi(best, battle.resolver.preview_damage(attacker, victim, action))
	return best


## Wen auf der eigenen Seite bedroht ``threat`` am staerksten?
##
## Gemessen am ANTEIL der Lebensleiste, nicht am Schaden. Sonst waere immer der
## Dickste das vermeintliche Opfer, und die KI wuerde ausgerechnet den
## schuetzen, der es am wenigsten braucht.
##
## ``mover`` steht in seiner eigenen Liste mit drin. Das ist Absicht: ist er
## selbst das gefaehrdetste Ziel, hebt sich der Gewinn oben auf null auf.
func _most_endangered_by(threat: Unit, mover: Unit) -> Dictionary:
	var worst := {}
	for ally in battle.allies_of(mover):
		if not _can_strike(threat, ally.tile):
			continue
		var damage := _best_damage(threat, ally)
		if damage <= 0:
			continue
		var share := float(damage) / maxf(1.0, float(ally.hp))
		if worst.is_empty() or share > float(worst["share"]):
			worst = {"unit": ally, "damage": damage, "share": share}
	return worst


## Wie zaeh haelt dieser Gegner an seinem Ziel fest? Ein Wert pro Bauart reicht,
## um spuerbar unterschiedliches Verhalten zu erzeugen -- ohne eine Zeile
## KI-Code. Der Aufhaenger ist die Reichweite der eigenen Waffe: wer aus sieben
## Feldern schiesst, hat sich auf sein Ziel eingerichtet und laesst sich nicht
## von jedem Kratzer umlenken. Wer im Nahkampf steht, schon.
func _incumbent_bonus(unit: Unit) -> float:
	var longest := 0
	for action in unit.actions():
		if action.is_attack():
			longest = maxi(longest, action.range_tiles)
	if longest >= int(_w("ranged_from_range", 3.0)):
		return _w("incumbent_bonus_ranged", 12.0)
	return _w("incumbent_bonus_melee", 6.0)


## Wen dieser Gegner tatsaechlich angegriffen hat. Der Amtsinhaber ist damit
## bekannt -- er bekommt den Bonus oben und ist vom Verfall ausgenommen.
func _remember_target(unit: Unit, step: Dictionary) -> void:
	if unit == null or unit.aggro == null:
		return
	var action: ActionData = step["action"]
	if action.is_attack():
		unit.aggro.current_target = step["target"].unit_id


# ---------------------------------------------------------------------------
# Annaeherung
# ---------------------------------------------------------------------------

## Nichts Sinnvolles in Reichweite: in Richtung des naechsten Gegners laufen,
## so weit die Bewegungspunkte reichen.
func _approach_step() -> Dictionary:
	var unit := battle.active_unit
	var state := battle.turn_state
	if unit == null or state == null or not state.can_move():
		return {}

	var foes := battle.enemies_of(unit)
	if foes.is_empty():
		return {}
	var nearest: Unit = foes[0]
	for foe in foes:
		if Grid.distance(unit.tile, foe.tile) < Grid.distance(unit.tile, nearest.tile):
			nearest = foe

	var entry := battle.grid.path_towards(unit.move_profile(), nearest.tile,
		state.move_points)
	if entry.is_empty():
		return {}
	return {"kind": "move", "move_to": entry["tile"], "score": 0.0}


## Haelt den geplanten Zustand nach, damit der naechste Durchlauf nicht
## dieselbe Aktion nochmal vorschlaegt.
func _simulate(step: Dictionary) -> void:
	var state := battle.turn_state
	if state == null:
		return
	if step["kind"] == "action":
		state.consume(step["action"])
