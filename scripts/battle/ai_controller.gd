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

	# Wer das Zielfeld bedrohen kann, macht es unattraktiv.
	for foe in battle.enemies_of(unit):
		if _threatens(foe, tile):
			score -= _w("threatened_penalty", 8.0)

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
func _threatens(foe: Unit, tile: Vector2i) -> bool:
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

	var damage := battle.resolver.preview_damage(unit, target, action)
	score += float(damage) * _w("damage_weight", 1.0)
	if damage >= target.hp:
		score += _w("kill_bonus", 100.0)
	return score


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
