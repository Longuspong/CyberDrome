class_name AIController
extends RefCounted

## Die KI im Echtzeit-Kampf. Steuert jeden DROME, auf beiden Seiten.
##
## Je Simulationsschritt fragt der BattleManager update() fuer jeden lebenden
## DROME. Der tut dann eins von drei Dingen -- schiessen, eine Faehigkeit
## ausloesen oder einen Schritt laufen:
##
##   * ZIEL: nach einer SICHTBAREN Regel je Rolle (choose_target, Nov. 2026 --
##     die versteckte Aggro-Tabelle ist raus). Wer in den Lockradius eines
##     Gegners geraet (Molok-Praesenz, Koedersender), greift den an. Das Ziel
##     wird GEHALTEN: neu gewaehlt nur, wenn es faellt, laenger als
##     ``realtime.retarget_after`` Sekunden nicht angreifbar ist, ein sicherer
##     Abschuss in Reichweite steht oder ein Locken einsetzt.
##   * WAFFEN: jede laedt fuer sich (``interval``). Ist sie geladen und ein
##     Gegner in Reichweite, schiesst sie -- auf das Ziel, sonst auf den besten
##     erreichbaren. Jeder N-te Angriff ist die Faehigkeit der Waffe.
##   * GADGETS: nach Zeit (Orbit-Sog) oder Ereignis (Boost, wenn ein Gegner
##     danebensteht).
##   * BEWEGUNG nach der Rolle des CHASSIS (``PartData.ai_role``), nicht nach
##     der Waffe -- ein Molok mit Kanone bleibt Frontlinie:
##       vanguard    rueckt vor, weicht nie aus
##       skirmisher  mit Fernwaffe kiten, mit Nahkampfwaffe am Ziel bleiben
##       sniper      haelt Abstand, weicht nur aus, wenn jemand danebensteht
##       controller  wartet hinter der Frontlinie, bis die im Kampf ist
##     Ohne Rolle wie frueher nach Waffenreichweite.
##
## Die Gewichte stehen in data/config.json ("ai", "realtime").
##
var battle: BattleManager
var _weights: Dictionary = {}
var _realtime: Dictionary = {}


func _init(manager: BattleManager) -> void:
	battle = manager
	_weights = Config.section("ai")
	_realtime = Config.section("realtime")


func _w(key: String, fallback: float) -> float:
	return float(_weights.get(key, fallback))


# ---------------------------------------------------------------------------
# Ein Schritt
# ---------------------------------------------------------------------------

## Ein Simulationsschritt fuer ``unit``.
func update(unit: Unit, dt: float) -> void:
	for mount in unit.mounts:
		mount["ready"] = float(mount["ready"]) - dt
	for gadget in unit.gadgets:
		gadget["ready"] = float(gadget["ready"]) - dt
	unit.think_left -= dt

	if unit.step_left > 0.0:
		unit.step_left -= dt
		if unit.step_left > 0.0:
			return
	# Betaeubt: weder laufen noch schiessen, die Waffen laden aber weiter.
	if unit.is_stunned():
		return

	var target := _current_target(unit)
	if target != null and not _can_shoot(unit, unit.tile, target):
		unit.target_blocked += dt
	elif target != null:
		unit.target_blocked = 0.0
	if target == null or unit.target_blocked > float(_realtime.get("retarget_after", 2.0)):
		_retarget(unit, choose_target(unit))
		target = _current_target(unit)
	elif unit.think_left <= 0.0:
		unit.think_left = float(_realtime.get("think_interval", 0.5))
		var lure := lured_by(unit)
		var kill := _sure_kill(unit) if lure == null else null
		if lure != null and lure != target:
			_retarget(unit, lure)
			target = lure
		elif kill != null and kill != target:
			_retarget(unit, kill)
			target = kill
	if target == null:
		return

	if _use_gadgets(unit, target):
		return
	var fired := false
	for mount in unit.mounts:
		if float(mount["ready"]) > 0.0:
			continue
		if _fire(unit, mount, target):
			mount["ready"] = (mount["attack"] as ActionData).interval
			fired = true
			if battle.outcome != BattleManager.Outcome.RUNNING:
				return
	if fired:
		return
	var next := next_step(unit, target)
	if next != unit.tile:
		_walk(unit, next)


func _retarget(unit: Unit, target: Unit) -> void:
	unit.target_id = target.unit_id if target != null else null
	unit.target_blocked = 0.0
	unit.think_left = float(_realtime.get("think_interval", 0.5))


## Ein Gegner in Reichweite, den ein einziger Treffer umlegt -- der einzige
## Grund, ein erreichbares Ziel vorzeitig aufzugeben.
func _sure_kill(unit: Unit) -> Unit:
	var best: Unit = null
	var best_hp := 1 << 30
	for foe in battle.enemies_of(unit):
		if foe.shield > 0 or foe.hp >= best_hp:
			continue
		for mount in unit.mounts:
			var attack: ActionData = mount["attack"]
			if battle.resolver.target_blocker(unit, foe.tile, attack) != "":
				continue
			if battle.resolver.preview_damage(unit, foe, attack) >= foe.hp:
				best = foe
				best_hp = foe.hp
				break
	return best


func _current_target(unit: Unit) -> Unit:
	var target := battle.resolver.unit_by_id(unit.target_id)
	if target == null or not target.is_alive():
		return null
	return target


# ---------------------------------------------------------------------------
# Zielwahl
# ---------------------------------------------------------------------------

## Wen soll ``unit`` gerade angreifen? Eine Regel je Rolle, die man beim
## Zuschauen versteht:
##
##   vanguard, skirmisher   den naechsten Gegner
##   controller             den, um den die meisten Gegner stehen (Vortex)
##   sniper                 in Reichweite den, der am meisten Schaden macht
##   hunter                 den verwundbarsten (wenig Integritaet, verwundbar
##                          oder betaeubt) -- fuer die geplante Jaegerklasse
##
## Gleichstand: wen Verbuendete schon angreifen (Fokus), dann wer weniger
## aushaelt, dann die Reihenfolge der Einheiten -- deterministisch.
## Vor allem anderen gilt das Locken: steht ``unit`` im Lockradius eines
## Gegners, greift es ihn an.
func choose_target(unit: Unit) -> Unit:
	var lure := lured_by(unit)
	if lure != null:
		return lure
	var foes := battle.enemies_of(unit)
	if foes.is_empty():
		return null
	var role := unit.ai_role()
	var best: Unit = null
	var best_key: Array = []
	for foe in foes:
		var key := _target_key(unit, foe, role, foes)
		if best == null or _key_less(key, best_key):
			best = foe
			best_key = key
	return best


## Sortierschluessel der Zielwahl: kleiner ist besser.
func _target_key(unit: Unit, foe: Unit, role: String, foes: Array) -> Array:
	var gap := Grid.distance(unit.tile, foe.tile)
	var toughness := foe.hp + foe.shield
	var focus := -_focused_by(unit, foe)
	match role:
		"controller":
			var crowd := 0
			for other in foes:
				if Grid.distance(other.tile, foe.tile) <= 2:
					crowd += 1
			return [-crowd, gap, focus, toughness]
		"sniper":
			var in_reach := 0 if _can_shoot(unit, unit.tile, foe) else 1
			return [in_reach, -foe.damage_dealt if in_reach == 0 else gap, focus, toughness]
		"hunter":
			var exposed := 0 if (foe.statuses.has(&"vulnerable") or foe.is_stunned()) else 1
			var share := int(round(100.0 * float(toughness)
				/ maxf(1.0, float(foe.stat("hp_max") + foe.shield_max()))))
			return [exposed, share, gap, focus]
	return [gap, focus, toughness]


func _key_less(a: Array, b: Array) -> bool:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return a[i] < b[i]
	return false


## Wer lockt ``unit`` gerade? Der naechste lebende Gegner, in dessen Lockradius
## (Molok-Praesenz, Koedersender) ``unit`` steht -- sonst null.
func lured_by(unit: Unit) -> Unit:
	var best: Unit = null
	var best_gap := 1 << 30
	for foe in battle.enemies_of(unit):
		var radius: int = foe.lure_radius()
		if radius <= 0:
			continue
		var gap := Grid.distance(unit.tile, foe.tile)
		if gap <= radius and gap < best_gap:
			best = foe
			best_gap = gap
	return best


## Wie viele Verbuendete greifen ``foe`` gerade an? Grundlage des Fokus:
## ein Team, das sich auf ein Ziel einigt, statt sich in Zweikaempfe zu
## verteilen.
func _focused_by(unit: Unit, foe: Unit) -> int:
	var count := 0
	for ally in battle.allies_of(unit):
		if ally != unit and ally.target_id == foe.unit_id:
			count += 1
	return count


# ---------------------------------------------------------------------------
# Schiessen
# ---------------------------------------------------------------------------

## Eine geladene Waffe abfeuern. Gibt true zurueck, wenn geschossen wurde.
##
## Ist ihr N-ter Angriff faellig, IST dieser Angriff die Faehigkeit der Waffe.
## Findet die Faehigkeit kein Ziel (andere Reichweite), schiesst die Waffe
## normal, und die Faehigkeit bleibt faellig -- sie kommt beim naechsten Mal.
func _fire(unit: Unit, mount: Dictionary, target: Unit) -> bool:
	var attack: ActionData = mount["attack"]
	var ability = mount["ability"]
	if ability != null and int(mount["count"]) + 1 >= trigger_every(unit, ability):
		var aim := _support_aim(unit, ability) if (ability as ActionData).support != "" \
			else _aim(unit, ability, target)
		if not aim.is_empty():
			_execute(unit, aim["tile"], ability, aim["target"])
			_echo(unit, ability, aim)
			mount["count"] = 0
			return true
	var shot := {}
	if attack.heal > 0:
		shot = _support_aim(unit, attack)
	if shot.is_empty():
		shot = _aim(unit, attack, target)
	if shot.is_empty():
		return false
	_execute(unit, shot["tile"], attack, shot["target"])
	if ability != null:
		mount["count"] = mini(int(mount["count"]) + 1,
			trigger_every(unit, ability) - 1)
	return true


## Wen unterstuetzt ``action``? "self": den Traeger. "ally" (und Angriffe mit
## ``heal``): den Verbuendeten mit dem geringsten Anteil Integritaet in
## Reichweite -- nur wenn er verletzt ist (heal) bzw. Schild brauchen kann
## (shield_gain). Leer, wenn niemand Hilfe braucht.
func _support_aim(unit: Unit, action: ActionData) -> Dictionary:
	if action.support == "self":
		return {"tile": unit.tile, "target": unit}
	var best: Unit = null
	var best_share := 2.0
	for ally in battle.allies_of(unit):
		if not ally.is_alive() or Grid.distance(unit.tile, ally.tile) > action.range_tiles:
			continue
		var hp_max := maxi(1, ally.stat("hp_max"))
		var share := float(ally.hp) / float(hp_max)
		var needs: bool = (action.heal > 0 and ally.hp < hp_max) \
			or (action.shield_gain > 0 and ally.shield < ally.shield_max() + action.shield_gain)
		if not needs:
			continue
		if share < best_share:
			best_share = share
			best = ally
	if best == null:
		return {}
	return {"tile": best.tile, "target": best}


## Der verletzte Verbuendete, zu dem ein Heiler hin muss: der mit dem
## geringsten Anteil Integritaet, der ausser Reichweite der Heilung steht.
## Null, wenn der DROME nicht heilt oder alle Verletzten erreichbar sind.
func _patient_out_of_reach(unit: Unit) -> Unit:
	var reach := 0
	for mount in unit.mounts:
		if (mount["attack"] as ActionData).heal > 0:
			reach = maxi(reach, (mount["attack"] as ActionData).range_tiles)
	if reach <= 0:
		return null
	var best: Unit = null
	var best_share := 1.0
	for ally in battle.allies_of(unit):
		if ally == unit or not ally.is_alive():
			continue
		var share := float(ally.hp) / float(maxi(1, ally.stat("hp_max")))
		if share < best_share:
			best_share = share
			best = ally
	if best != null and Grid.distance(unit.tile, best.tile) <= reach:
		return null
	return best


## Der Takt einer Faehigkeit (wie viele Angriffe bis zu ihr) an diesem DROME.
## Mit der Passive Echo (Nimbus) laenger: die normalen Angriffe dazwischen
## mal ``passives.echo.slower`` (gerundet) -- Blaster jeder 3. -> jeder 4.
func trigger_every(unit: Unit, ability: ActionData) -> int:
	var every := int(ability.trigger_every)
	if ability.trigger_kind != "attacks" or unit.passive() != "echo":
		return every
	return int(round(float(every - 1) * unit.echo_slower())) + 1


## Der Takt einer Zeit-Faehigkeit in Sekunden -- mit Echo ebenso laenger
## (Runenstab: 3 s -> 4,5 s).
func _time_after_ability(unit: Unit, ability: ActionData) -> float:
	return float(ability.trigger_every) * unit.echo_slower()


## Passive Echo (Nimbus, 7. Nov. 2026): die Faehigkeit wirkt gleich noch
## einmal -- aufs selbe Ziel, ist es gefallen, aufs naechstbeste.
func _echo(unit: Unit, ability: ActionData, aim: Dictionary) -> void:
	if unit.passive() != "echo" or battle.outcome != BattleManager.Outcome.RUNNING:
		return
	var again := aim
	var target: Unit = aim.get("target")
	if target == null or not target.is_alive():
		again = _aim(unit, ability, null)
	if not again.is_empty():
		_execute(unit, again["tile"], ability, again["target"])


## Worauf zielt ``action``? Das Ziel, wenn es geht; sonst der am besten
## bewertete andere Gegner in Reichweite. Leer, wenn niemand erreichbar ist.
func _aim(unit: Unit, action: ActionData, target: Unit) -> Dictionary:
	if target != null and battle.resolver.target_blocker(unit, target.tile, action) == "" \
			and _action_score(unit, action, target) > 0.0:
		return {"tile": target.tile, "target": target}
	var best := {}
	var best_score := 0.0
	for other in battle.enemies_of(unit):
		if battle.resolver.target_blocker(unit, other.tile, action) != "":
			continue
		var score := _action_score(unit, action, other)
		if score > best_score:
			best_score = score
			best = {"tile": other.tile, "target": other}
	return best


func _execute(unit: Unit, tile: Vector2i, action: ActionData, target: Unit) -> void:
	if tile != unit.tile:
		unit.set_facing(Unit.facing_for(tile - unit.tile))
	if battle.resolver.execute(unit, tile, action):
		EventBus.action_used.emit(unit, tile, action)
		battle._check_victory()


# ---------------------------------------------------------------------------
# Gadgets
# ---------------------------------------------------------------------------

## Zeit- und Ereignis-Faehigkeiten. Gibt true zurueck, wenn eine ausgeloest
## hat -- dann ist der Augenblick verbraucht.
func _use_gadgets(unit: Unit, target: Unit) -> bool:
	for gadget in unit.gadgets:
		if float(gadget["ready"]) > 0.0:
			continue
		var ability: ActionData = gadget["ability"]
		match ability.trigger_kind:
			"time":
				var aim := _aim(unit, ability, target)
				if aim.is_empty():
					continue
				_execute(unit, aim["tile"], ability, aim["target"])
				_echo(unit, ability, aim)
				gadget["ready"] = _time_after_ability(unit, ability)
				return true
			"adjacent":
				if not _enemy_adjacent(unit):
					continue
				var landing := _escape_landing(unit, ability, target)
				if landing == unit.tile:
					continue
				_execute(unit, landing, ability, null)
				gadget["ready"] = ability.trigger_every
				return true
	return false


func _enemy_adjacent(unit: Unit) -> bool:
	for foe in battle.enemies_of(unit):
		if Grid.distance(unit.tile, foe.tile) <= 1:
			return true
	return false


## Wohin der Boost springt: weg vom naechsten Gegner, moeglichst so, dass das
## Ziel in Reichweite bleibt.
func _escape_landing(unit: Unit, ability: ActionData, target: Unit) -> Vector2i:
	var best := unit.tile
	var best_score := _safety(unit, unit.tile, target)
	for landing in battle.resolver.dash_landings(unit, ability):
		var score := _safety(unit, landing, target)
		if score > best_score:
			best_score = score
			best = landing
	return best


## Wie sicher ist ein Feld? Abstand zum naechsten Gegner, plus ein Bonus, wenn
## das Ziel von dort in Reichweite bleibt.
func _safety(unit: Unit, tile: Vector2i, target: Unit) -> float:
	var nearest := 99
	for foe in battle.enemies_of(unit):
		nearest = mini(nearest, Grid.distance(tile, foe.tile))
	var score := float(nearest)
	if target != null and Grid.distance(tile, target.tile) <= unit.attack_range():
		score += 1.5
	return score


# ---------------------------------------------------------------------------
# Bewegung nach Rolle
# ---------------------------------------------------------------------------

## Wohin geht der naechste Schritt? Das eigene Feld = stehen bleiben.
func next_step(unit: Unit, target: Unit) -> Vector2i:
	if target == null or unit.mounts.is_empty():
		return unit.tile
	# Heiler (Drohnen-Pod): erst zum Verletzten, der ausser Reichweite steht.
	var patient := _patient_out_of_reach(unit)
	if patient != null:
		return _approach(unit, patient)
	var ranged := unit.attack_range() >= int(_w("ranged_from_range", 3.0))
	var shooting := _can_shoot_anyone(unit, unit.tile)
	match unit.ai_role():
		"vanguard":
			# Frontlinie: nie zurueck. Wer schon trifft, bleibt stehen.
			if _can_shoot(unit, unit.tile, target) or shooting:
				return unit.tile
			return _approach(unit, target)
		"sniper":
			# Haelt seine Stellung und weicht nur aus, wenn jemand direkt
			# danebensteht -- kein Dauerweglaufen.
			if shooting:
				return _kite_step(unit, target, 1)
			return _approach(unit, target)
		"controller":
			# Wartet hinter der Frontlinie, bis die im Kampf ist. Wer selbst
			# bedraengt wird, wartet natuerlich nicht.
			if not shooting and not _frontline_engaged(unit) \
					and _nearest_foe(unit, unit.tile) > int(_realtime.get("kite_distance", 2)):
				return unit.tile
		"skirmisher":
			pass
	if ranged and shooting:
		return _kite_step(unit, target)
	if _can_shoot(unit, unit.tile, target):
		return unit.tile
	if shooting and not ranged:
		# Nahkaempfer mit einem anderen Gegner vor der Nase: der wird bedient,
		# statt sich an ihm vorbei zum Ziel zu draengen.
		return unit.tile
	return _approach(unit, target)


func _can_shoot(unit: Unit, from_tile: Vector2i, target: Unit) -> bool:
	var saved := unit.tile
	unit.tile = from_tile
	var ok := false
	for mount in unit.mounts:
		if battle.resolver.target_blocker(unit, target.tile, mount["attack"]) == "":
			ok = true
			break
	unit.tile = saved
	return ok


func _can_shoot_anyone(unit: Unit, from_tile: Vector2i) -> bool:
	for foe in battle.enemies_of(unit):
		if _can_shoot(unit, from_tile, foe):
			return true
	return false


## Fernkaempfer in Reichweite: stehen bleiben -- ausser ein Gegner kommt
## naeher als ``realtime.kite_distance``. Dann ein Feld zurueck, sofern von
## dort noch jemand zu treffen ist.
func _kite_step(unit: Unit, target: Unit, limit: int = -1) -> Vector2i:
	if limit < 0:
		limit = int(_realtime.get("kite_distance", 2))
	var here := _nearest_foe(unit, unit.tile)
	if here > limit:
		return unit.tile
	var best: Array[Vector2i] = [unit.tile]
	var best_gap := here
	for dir in Grid.directions():
		var tile: Vector2i = unit.tile + dir
		if not battle.grid.can_stand_on(tile, unit.unit_id):
			continue
		var gap := _nearest_foe(unit, tile)
		if gap < best_gap or not _can_shoot_anyone(unit, tile):
			continue
		if gap > best_gap:
			best_gap = gap
			best = [tile]
		elif gap > here:
			best.append(tile)
	return best[battle.rng.randi() % best.size()]


## Ist die eigene Frontlinie im Kampf? Ja, sobald ein Verbuendeter mit Rolle
## vanguard oder skirmisher jemanden trifft -- oder es keine solche Frontlinie
## (mehr) gibt, dann wartet niemand.
func _frontline_engaged(unit: Unit) -> bool:
	var has_front := false
	for ally in battle.allies_of(unit):
		if ally == unit or not ally.ai_role() in ["vanguard", "skirmisher"]:
			continue
		has_front = true
		if _can_shoot_anyone(ally, ally.tile):
			return true
	return not has_front


func _nearest_foe(unit: Unit, tile: Vector2i) -> int:
	var nearest := 99
	for foe in battle.enemies_of(unit):
		nearest = mini(nearest, Grid.distance(tile, foe.tile))
	return nearest


## Der erste Schritt auf dem kuerzesten Weg zu einem Feld, von dem aus das
## Ziel zu treffen ist.
##
## Gerechnet wird vom ZIELBEREICH aus (alle Felder, von denen aus geschossen
## werden kann), nicht vom DROME aus. Das ist kein Selbstzweck: vom DROME aus
## gesucht, entschied bei gleich langen Wegen die feste Reihenfolge der
## Richtungen, welcher Weg genommen wird -- und die bevorzugte die Seite, die
## zufaellig in die erste Richtung lief (Spiegelkaempfe 38 zu 2). So hat jedes
## Nachbarfeld eine Entfernung zum Ziel, und unter gleich guten entscheidet
## der Zufall am Seed.
func _approach(unit: Unit, target: Unit) -> Vector2i:
	var grid := battle.grid
	var reach := unit.attack_range()
	var frontier: Array[Vector2i] = []
	var dist := {}
	for x in range(target.tile.x - reach, target.tile.x + reach + 1):
		for y in range(target.tile.y - reach, target.tile.y + reach + 1):
			var tile := Vector2i(x, y)
			if not grid.in_bounds(tile) or Grid.distance(tile, target.tile) > reach:
				continue
			if not grid.can_stand_on(tile, unit.unit_id):
				continue
			if _can_shoot(unit, tile, target):
				dist[tile] = 0
				frontier.append(tile)
	if dist.has(unit.tile):
		return unit.tile

	# Rueckwaerts suchen (Breitensuche, jeder Schritt kostet 1). Besetzte
	# Felder sperren; das eigene Feld ist der Startpunkt.
	while not frontier.is_empty():
		var tile: Vector2i = frontier.pop_front()
		var here: int = dist[tile]
		for dir in Grid.directions():
			var prev: Vector2i = tile + dir
			if dist.has(prev):
				continue
			if prev != unit.tile and not grid.can_stand_on(prev, unit.unit_id):
				continue
			dist[prev] = here + 1
			if prev != unit.tile:
				frontier.append(prev)

	var best: Array[Vector2i] = []
	var best_cost := 1 << 30
	for dir in Grid.directions():
		var nxt: Vector2i = unit.tile + dir
		if not dist.has(nxt) or not grid.can_stand_on(nxt, unit.unit_id):
			continue
		var cost: int = int(dist[nxt])
		if cost < best_cost:
			best_cost = cost
			best = [nxt]
		elif cost == best_cost:
			best.append(nxt)
	if best.is_empty():
		return unit.tile
	return best[battle.rng.randi() % best.size()]


## Einen Schritt beginnen. Das Feld gilt sofort (es ist damit belegt), die
## Figur gleitet in der Schrittzeit hinterher.
func _walk(unit: Unit, next: Vector2i) -> void:
	unit.set_facing(Unit.facing_for(next - unit.tile))
	# Die Schrittzeit steht VOR dem Versetzen fest: move_unit meldet den
	# Schritt (unit_moved), und die Szene liest daran ab, wie lange die Figur
	# gleitet.
	unit.step_left = 1.0 / unit.move_speed()
	battle.resolver.move_unit(unit, next)


# ---------------------------------------------------------------------------
# Bewertung
# ---------------------------------------------------------------------------

func _action_score(unit: Unit, action: ActionData, target: Unit) -> float:
	var score := 0.0
	# Eine Aktion OHNE Wirkungsmenge (Ziehen) wird ueber ihre Wirkung auf den
	# Abstand bewertet, nicht ueber Schaden.
	if action.power <= 0:
		return score + _shove_score(unit, action, target)

	var damage := battle.resolver.preview_damage(unit, target, action)
	score += float(damage) * _w("damage_weight", 1.0)
	# Schildschaden zaehlt mit -- sonst bewertet ein voller Schild jeden
	# Einzeltreffer mit 0, und die KI greift abgeschirmte Ziele nie an.
	score += float(_shield_damage(unit, target, action)) \
		* _w("shield_damage_weight", 0.7)
	if damage >= target.hp:
		score += _w("kill_bonus", 100.0)
	return score


## Wie viel Schild diese Aktion abtraegt. Dieselbe Rechnung wie der echte
## Treffer (ActionResolver.resolve_damage), nur ohne ihn auszufuehren.
func _shield_damage(unit: Unit, target: Unit, action: ActionData) -> int:
	if target.shield <= 0 or action.power <= 0:
		return 0
	var outcome := battle.resolver.resolve_damage(target,
		action.power + unit.atk(), action.energy_fraction, action.shield_mult)
	return maxi(0, target.shield - int(outcome["shield_after"]))


## Was ist es wert, ein Ziel zu verschieben (Orbit-Sog)?
##
## Gerechnet in REICHWEITEN: wer weiter schiesst als sein Ziel, will Abstand
## (Heranziehen negativ), wer kuerzer schiesst, will ihn schliessen (positiv),
## bei gleicher Reichweite gewinnt keiner etwas.
func _shove_score(unit: Unit, action: ActionData, target: Unit) -> float:
	if action.push_tiles == 0:
		return 0.0
	var before := Grid.distance(unit.tile, target.tile)
	var after := maxi(0, before + action.push_tiles)
	if after == before:
		return 0.0

	var wanted := signi(_longest_attack_range(target) - _longest_attack_range(unit))
	if wanted == 0:
		return 0.0
	return float(before - after) * float(wanted) * _w("shove_weight", 4.0)


## Die groesste Angriffsreichweite dieses Aufbaus. Null, wenn er keine Waffe
## traegt -- was die Validierung eigentlich ausschliesst, aber die Bewertung
## soll daran nicht haengen.
func _longest_attack_range(unit: Unit) -> int:
	var longest := 0
	for action in unit.actions():
		if action.is_attack():
			longest = maxi(longest, action.range_tiles)
	return longest
