class_name AIController
extends RefCounted

## Die KI im Echtzeit-Kampf. Steuert jeden DROME, auf beiden Seiten.
##
## Je Simulationsschritt fragt der BattleManager update() fuer jeden lebenden
## DROME. Der tut dann eins von drei Dingen -- schiessen, eine Faehigkeit
## ausloesen oder einen Schritt laufen:
##
##   * ZIEL: alle ``realtime.think_interval`` Sekunden neu gewaehlt, nach
##     derselben Bewertung wie frueher (Schaden, Schild, Abschuss, Aggro,
##     Amtsinhaber). Eine Provokation erzwingt das Ziel.
##   * WAFFEN: jede laedt fuer sich (``interval``). Ist sie geladen und ein
##     Gegner in Reichweite, schiesst sie -- auf das Ziel, sonst auf den besten
##     erreichbaren. Jeder N-te Angriff ist die Faehigkeit der Waffe.
##   * GADGETS: nach Zeit (Orbit-Sog) oder Ereignis (Boost, wenn ein Gegner
##     danebensteht).
##   * BEWEGUNG nach Rolle: Nahkaempfer ruecken bis zum Kontakt vor,
##     Fernkaempfer laufen nur, bis sie schiessen koennen, und weichen aus,
##     wenn ihnen jemand zu nahe kommt.
##
## Die Gewichte stehen in data/config.json ("ai", "realtime").
##
## ### Aggro ist ein Summand, kein Filter
##
## Die Aggro-Tabelle (scripts/battle/aggro_table.gd) ERSETZT die Zielwahl
## nicht, sie geht als weiterer Term in dieselbe Bewertung ein. Als Filter
## wuerde ein DROME an einem sicheren Abschuss vorbeilaufen, weil ein anderer
## weiter oben in der Tabelle steht.

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

	var target := _current_target(unit)
	if unit.think_left <= 0.0 or target == null:
		unit.think_left = float(_realtime.get("think_interval", 0.5))
		target = choose_target(unit)
		unit.target_id = target.unit_id if target != null else null
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


func _current_target(unit: Unit) -> Unit:
	if unit.is_taunted():
		var forcer := battle.resolver.unit_by_id(unit.taunted_by())
		if forcer != null and forcer.is_alive():
			return forcer
	var target := battle.resolver.unit_by_id(unit.target_id)
	if target == null or not target.is_alive():
		return null
	return target


# ---------------------------------------------------------------------------
# Zielwahl
# ---------------------------------------------------------------------------

## Wen soll ``unit`` gerade angreifen? Der Gegner mit der besten Bewertung
## fuer die staerkste eigene Waffe -- abzueglich des Weges, den es bis dahin
## noch ist. Eine Provokation erzwingt das Ziel.
func choose_target(unit: Unit) -> Unit:
	if unit.is_taunted():
		var forcer := battle.resolver.unit_by_id(unit.taunted_by())
		if forcer != null and forcer.is_alive():
			return forcer
	var reach := unit.attack_range()
	var best: Unit = null
	var best_score := -INF
	for foe in battle.enemies_of(unit):
		var score := -INF
		for mount in unit.mounts:
			score = maxf(score, _action_score(unit, mount["attack"], foe))
		if unit.mounts.is_empty():
			score = 0.0
		var gap := maxi(0, Grid.distance(unit.tile, foe.tile) - reach)
		score -= float(gap) * _w("approach_penalty", 2.0)
		if score > best_score:
			best_score = score
			best = foe
	return best


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
	if ability != null and int(mount["count"]) + 1 >= int((ability as ActionData).trigger_every):
		var aim := _aim(unit, ability, target)
		if not aim.is_empty():
			_execute(unit, aim["tile"], ability, aim["target"])
			mount["count"] = 0
			return true
	var shot := _aim(unit, attack, target)
	if shot.is_empty():
		return false
	_execute(unit, shot["tile"], attack, shot["target"])
	if ability != null:
		mount["count"] = mini(int(mount["count"]) + 1,
			int((ability as ActionData).trigger_every) - 1)
	return true


## Worauf zielt ``action``? Das Ziel, wenn es geht; sonst der am besten
## bewertete andere Gegner in Reichweite. Leer, wenn niemand erreichbar ist.
func _aim(unit: Unit, action: ActionData, target: Unit) -> Dictionary:
	if target != null and battle.resolver.target_blocker(unit, target.tile, action) == "" \
			and _action_score(unit, action, target) > 0.0:
		return {"tile": target.tile, "target": target}
	if unit.is_taunted() and action.is_attack():
		return {}
	var best := {}
	var best_score := 0.0
	var pool := battle.allies_of(unit) if action.is_heal() else battle.enemies_of(unit)
	for other in pool:
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
		if action.is_attack() and target != null and unit.aggro != null:
			unit.aggro.current_target = target.unit_id
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
				gadget["ready"] = ability.trigger_every
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
	var ranged := unit.attack_range() >= int(_w("ranged_from_range", 3.0))
	var shooting := _can_shoot_anyone(unit, unit.tile)
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
func _kite_step(unit: Unit, target: Unit) -> Vector2i:
	var limit := int(_realtime.get("kite_distance", 2))
	var here := _nearest_foe(unit, unit.tile)
	if here > limit:
		return unit.tile
	var profile := unit.move_profile()
	var best: Array[Vector2i] = [unit.tile]
	var best_gap := here
	for dir in Grid.directions():
		var tile: Vector2i = unit.tile + dir
		if not battle.grid.can_stand_on(tile, profile):
			continue
		if battle.grid.terrain_class(tile) == Terrain.TClass.DRIFT \
				and not unit.stats.get("ignores_drift", false):
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
	var profile := unit.move_profile()
	var reach := unit.attack_range()
	var frontier: Array[Vector2i] = []
	var dist := {}
	for x in range(target.tile.x - reach, target.tile.x + reach + 1):
		for y in range(target.tile.y - reach, target.tile.y + reach + 1):
			var tile := Vector2i(x, y)
			if not grid.in_bounds(tile) or Grid.distance(tile, target.tile) > reach:
				continue
			if tile != unit.tile and not grid.can_stand_on(tile, profile):
				continue
			if _can_shoot(unit, tile, target):
				dist[tile] = 0
				frontier.append(tile)
	if frontier.is_empty():
		# Kein Feld, von dem aus es geht (alles verbaut): so nah wie moeglich.
		for dir in Grid.directions():
			var tile: Vector2i = target.tile + dir
			if grid.in_bounds(tile) and (tile == unit.tile or grid.can_stand_on(tile, profile)):
				dist[tile] = 0
				frontier.append(tile)
	if dist.has(unit.tile):
		return unit.tile

	# Rueckwaerts suchen: wer von ``tile`` nach ``nxt`` will, zahlt die Kosten
	# von ``nxt``. Kosten sind klein (1 oder 2), eine einfache Warteschlange
	# mit Nachbesserung genuegt.
	while not frontier.is_empty():
		var tile: Vector2i = frontier.pop_front()
		var here: int = dist[tile]
		for dir in Grid.directions():
			var prev: Vector2i = tile + dir
			if not grid.in_bounds(prev) or not grid.can_traverse(prev, profile):
				if prev != unit.tile:
					continue
			var cost: int = here + grid.terrain_cost(tile, profile)
			if dist.has(prev) and int(dist[prev]) <= cost:
				continue
			dist[prev] = cost
			if prev != unit.tile:
				frontier.append(prev)

	var best: Array[Vector2i] = []
	var best_cost := 1 << 30
	for dir in Grid.directions():
		var nxt: Vector2i = unit.tile + dir
		if not dist.has(nxt) or not grid.can_stand_on(nxt, profile):
			continue
		var cost: int = int(dist[nxt]) + grid.terrain_cost(nxt, profile)
		if cost < best_cost:
			best_cost = cost
			best = [nxt]
		elif cost == best_cost:
			best.append(nxt)
	if best.is_empty():
		return unit.tile
	return best[battle.rng.randi() % best.size()]


## Einen Schritt beginnen. Das Feld gilt sofort (es ist damit belegt), die
## Figur gleitet in der Schrittzeit hinterher. Rutscht der DROME auf Oel weiter,
## dauert es entsprechend laenger.
func _walk(unit: Unit, next: Vector2i) -> void:
	var dir := next - unit.tile
	var profile := unit.move_profile()
	var cost := battle.grid.terrain_cost(next, profile)
	unit.set_facing(Unit.facing_for(dir))
	var start := unit.tile
	# Die Schrittzeit steht VOR dem Versetzen fest: move_unit meldet den Zug
	# (unit_moved), und die Szene liest daran ab, wie lange die Figur gleitet.
	var landing := battle.grid.simulate_drift(next, dir, profile)
	var extra := maxi(0, Grid.distance(start, landing) - 1)
	unit.step_left = (float(cost) + float(extra) * 0.5) / unit.move_speed()
	battle.resolver.move_unit(unit, next, dir)


# ---------------------------------------------------------------------------
# Bewertung
# ---------------------------------------------------------------------------

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

	# Dieselbe Falle an einer anderen Aktion: eine Aktion OHNE Wirkungsmenge
	# darf nicht ueber preview_damage() bewertet werden. Die liefert die
	# Mindestmenge 1 und macht aus "richtet nichts an" ein "richtet ein
	# bisschen was an" -- genug, damit die KI sie zieht, weil das
	# Faehigkeitsbudget eines Angriffs-Aufbaus ohnehin frei ist.
	if action.power <= 0:
		return score + _shove_score(unit, action, target)

	var damage := battle.resolver.preview_damage(unit, target, action)
	score += float(damage) * _w("damage_weight", 1.0)
	# Schildschaden zaehlt mit. Frueher ging nur der Integritaetsschaden ein --
	# und ein voller Energieschild (32 Punkte beim Deflektor) schluckt jeden
	# einzelnen Treffer. Die Bewertung war dann 0, die KI griff abgeschirmte
	# Ziele NIE an, und Spiegelkaempfe liefen bis zum Zyklus-Limit, ohne dass
	# ein Punkt Schaden fiel. Den Schild abzuraeumen ist aber genau das, was
	# den naechsten Treffer (auch den des Verbuendeten) durchlaesst.
	score += float(_shield_damage(unit, target, action)) \
		* _w("shield_damage_weight", 0.7)
	if damage >= target.hp:
		score += _w("kill_bonus", 100.0)
	score += _aggro_score(unit, target)
	return score


## Wie viel Schild diese Aktion abtraegt. Dieselbe Rechnung wie der echte
## Treffer (ActionResolver.resolve_damage), nur ohne ihn auszufuehren.
func _shield_damage(unit: Unit, target: Unit, action: ActionData) -> int:
	if target.shield <= 0 or action.power <= 0:
		return 0
	var outcome := battle.resolver.resolve_damage(target,
		action.power + unit.atk(), action.energy_fraction)
	return maxi(0, target.shield - int(outcome["shield_after"]))


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


## Was ist es wert, ein Ziel zu verschieben?
##
## Der Orbit-Sog hat Staerke 0 und ``push_tiles`` -2. Ueber den Schaden bewertet
## kam er auf die Mindestmenge 1 und wurde damit JEDEN Zug gezogen -- das
## Faehigkeitsbudget ist bei einem Angriffs-Aufbau ohnehin frei. Ein Strix mit
## Reichweite sieben hat sich so Zug um Zug seinen eigenen Vorteil weggezogen
## und den Gegner ins Handgemenge geholt.
##
## Gerechnet wird deshalb in REICHWEITEN statt in Feldern -- dieselbe
## Ueberlegung wie bei der Provokation (GAME_DESIGN 6g), nur auf eine andere
## Groesse angewandt. Nicht wie weit jemand geschoben wird, entscheidet,
## sondern auf welche Seite des Reichweitenvergleichs er dabei geraet:
##
##   * Wer weiter schiesst als sein Ziel, will Abstand. Heranziehen ist fuer
##     ihn negativ, und eine negative Bewertung faellt in _best_move() heraus.
##   * Wer kuerzer schiesst, will den Abstand schliessen. Fuer ihn ist
##     derselbe Zug positiv.
##   * Bei gleicher Reichweite gewinnt keiner etwas: 0, die Aktion bleibt
##     ungenutzt.
##
## Kein Sonderfall fuer "Nahkaempfer" noetig -- das faellt aus dem Vergleich
## heraus, so wie das Tanken aus den Lebensleisten faellt.
##
## Der Landepunkt ist geschaetzt (``before + push_tiles``, an der Kartenkante
## abgeschnitten) und beruecksichtigt weder Hindernisse noch Drift. Das ist
## dieselbe Groessenordnung von Naeherung wie in _can_strike() und
## _best_damage(): die Zahl geht nur als Vorzeichen und grobes Mass ein, und
## die genaue Rechnung waere fuer den Gewinn zu teuer.
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
	if _longest_attack_range(unit) >= int(_w("ranged_from_range", 3.0)):
		return _w("incumbent_bonus_ranged", 12.0)
	return _w("incumbent_bonus_melee", 6.0)


