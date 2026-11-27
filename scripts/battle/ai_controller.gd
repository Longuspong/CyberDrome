class_name AIController
extends RefCounted

## Die KI im Echtzeit-Kampf. Steuert jeden DROME, auf beiden Seiten.
##
## Je Simulationsschritt fragt der BattleManager update() fuer jeden lebenden
## DROME. Der tut dann eins von drei Dingen -- schiessen, eine Faehigkeit
## ausloesen oder einen Schritt laufen:
##
##   * ZIEL: nach einer SICHTBAREN Regel je Rolle (choose_target, Nov. 2026 --
##     die versteckte Aggro-Tabelle ist raus). Das Ziel wird GEHALTEN: neu
##     gewaehlt nur, wenn es faellt, laenger als ``realtime.retarget_after``
##     Sekunden nicht angreifbar ist oder ein sicherer Abschuss in Reichweite
##     steht.
##   * WAFFEN: jede laedt fuer sich (``interval``). Ist sie geladen und ein
##     Gegner in Reichweite, schiesst sie -- auf das Ziel, sonst auf den besten
##     erreichbaren. Jeder N-te Angriff ist die Faehigkeit der Waffe.
##   * GADGETS: nach Ereignis (Hologramm, wenn ein Gegner
##     danebensteht).
##   * BEWEGUNG nach der Rolle des CHASSIS (``PartData.ai_role``), nicht nach
##     der Waffe -- ein Molok bleibt mit jeder Waffe Frontlinie:
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


## Wie lange ein DROME nach einem Schuss zum Ziel schaut (Sekunden).
const AIM_HOLD := 0.8


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
	# Echo (Nimbus): die zweite Wirkung kommt kurz nach der ersten -- laeuft
	# neben allem anderen, der DROME bleibt dafuer nicht stehen.
	if not unit.echoes.is_empty():
		_tick_echoes(unit, dt)
	unit.think_left -= dt
	unit.aim_hold = maxf(0.0, unit.aim_hold - dt)

	if unit.step_left > 0.0:
		unit.step_left -= dt
		if unit.step_left > 0.0:
			return
	# Betaeubt: weder laufen noch schiessen, die Waffen laden aber weiter.
	if unit.is_stunned():
		return
	# Holt zu einer Faehigkeit aus: steht still, bis sie wirkt.
	if not unit.cast.is_empty():
		unit.cast["left"] = float(unit.cast["left"]) - dt
		if float(unit.cast["left"]) <= 0.0:
			_finish_cast(unit)
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
		var kill := _sure_kill(unit)
		if kill != null and kill != target:
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
			# Modul Taktgeber: nach der Faehigkeit sofort wieder geladen.
			mount["ready"] = 0.0 if mount.get("instant", false) \
				else (mount["attack"] as ActionData).interval / unit.attack_speed_mult()
			mount["instant"] = false
			fired = true
			if battle.outcome != BattleManager.Outcome.RUNNING:
				return
	if fired:
		return
	var next := next_step(unit, target)
	if next != unit.tile:
		_walk(unit, next, target)


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
func choose_target(unit: Unit) -> Unit:
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
##
## Der Zaehler ``mount["count"]`` steigt je Angriff um Unit.takt_step (1, mit
## Taktchip 1,25); was nach der Faehigkeit ueber den Takt hinausgeht, bleibt
## stehen. Bleibt die Faehigkeit ohne Ziel, aendert sich der Zaehler nicht.
func _fire(unit: Unit, mount: Dictionary, target: Unit) -> bool:
	var attack: ActionData = mount["attack"]
	var ability = mount["ability"]
	var fx: Dictionary = mount.get("fx", {})
	var due := ability != null and unit.takt_due(mount)
	if due:
		var aim := _support_aim(unit, ability) if (ability as ActionData).support != "" \
			else _aim(unit, ability, target)
		if not aim.is_empty():
			mount["count"] = maxf(0.0, float(mount["count"]) + unit.takt_step(mount)
				- float(trigger_every(unit, ability)))
			if (ability as ActionData).windup > 0.0:
				_begin_cast(unit, ability, aim, mount, fx)
			else:
				_resolve_ability(unit, ability, aim, mount, fx)
			mount["instant"] = bool(fx.get("ready_after_ability", false))
			unit.on_attack()
			return true
	var shot := {}
	if attack.heal > 0:
		shot = _support_aim(unit, attack)
	if shot.is_empty():
		shot = _aim(unit, attack, target)
	if shot.is_empty():
		return false
	_execute(unit, shot["tile"], attack, shot["target"])
	_attack_modules(unit, mount, attack, shot.get("target"))
	if ability != null and not due:
		mount["count"] = float(mount["count"]) + unit.takt_step(mount)
	unit.on_attack()
	return true


## Die Faehigkeit wirkt: ausfuehren, Echo, Nachwirkungen der Module.
func _resolve_ability(unit: Unit, ability: ActionData, aim: Dictionary, mount: Dictionary,
		fx: Dictionary) -> void:
	_execute(unit, aim["tile"], ability, aim["target"], bool(aim.get("thrown", false)))
	_echo(unit, ability, aim)
	_after_ability(unit, ability, aim, fx)
	_shackle(unit, mount)


## Ausholen (18. Nov. 2026): die Ansage beginnt, die Wirkung folgt nach
## ``windup`` Sekunden in _finish_cast.
func _begin_cast(unit: Unit, ability: ActionData, aim: Dictionary, mount: Dictionary,
		fx: Dictionary) -> void:
	var target = aim.get("target")
	unit.cast = {"action": ability, "aim": aim, "mount": mount, "fx": fx,
		"left": ability.windup, "target": target}
	var tile: Vector2i = aim["tile"]
	_aim_at(unit, tile)
	EventBus.ability_cast.emit(unit, tile, ability, ability.windup, target)


## Ende der Ausholzeit. Einzelziele treffen das Ziel dort, wo es jetzt
## steht; ist es weg oder ausser Reichweite, verpufft die Faehigkeit nicht --
## der Takt bleibt voll und sie kommt mit dem naechsten Angriff wieder.
## Flaechen (Vortex, Sperrfeuer; 18. Nov. 2026, Wunsch des Spielers) landen
## dort, wohin geworfen wurde: wer rechtzeitig wegläuft, entkommt.
func _finish_cast(unit: Unit) -> void:
	var cast := unit.cast
	unit.cast = {}
	var ability: ActionData = cast["action"]
	var aim := _landing(unit, ability, cast["aim"], cast.get("target"))
	if aim.is_empty():
		var mount: Dictionary = cast["mount"]
		mount["count"] = float(mount["count"]) + float(trigger_every(unit, ability))
		return
	_resolve_ability(unit, ability, aim, cast["mount"], cast["fx"])
	battle._check_victory()


## Wo eine Faehigkeit nach der Ausholzeit wirkt: Flaechen auf dem Wurffeld,
## Einzelziele dort, wo das Ziel jetzt steht. Leer, wenn sie nicht wirken kann.
## ``in_flight``: schon unterwegs (Echo) -- dann zaehlt die Reichweite nicht
## mehr, der DROME darf inzwischen weitergelaufen sein.
func _landing(unit: Unit, ability: ActionData, thrown: Dictionary, aimed,
		in_flight: bool = false) -> Dictionary:
	var aim := thrown.duplicate()
	var area := lands_on_tile(ability)
	var target = aimed
	if target is Unit:
		if not target.is_alive():
			target = null
		elif not area:
			aim["tile"] = target.tile
	aim["target"] = target
	if area:
		aim["thrown"] = true
		return {} if _throw_blocker(unit, aim["tile"], ability, in_flight) != "" else aim
	if aimed is Unit and target == null \
			or battle.resolver.target_blocker(unit, aim["tile"], ability) != "":
		return {}
	return aim


## Landet die Faehigkeit auf dem Feld, auf das sie geworfen wurde, statt dem
## Ziel zu folgen? Alle Flaechen (Vortex, Sperrfeuer, Wirbel).
static func lands_on_tile(ability: ActionData) -> bool:
	return ability.aoe_radius > 0 and not ability.is_move()


## Kann eine geworfene Flaeche noch auf ``tile`` landen? Nur Reichweite und
## Mindestabstand zaehlen -- ein leeres Feld ist kein Hindernis.
func _throw_blocker(unit: Unit, tile: Vector2i, ability: ActionData,
		in_flight: bool = false) -> String:
	var reach := Grid.distance(unit.tile, tile)
	if in_flight:
		pass
	elif reach > ability.range_tiles:
		return "Außer Reichweite"
	elif ability.min_range > 0 and reach < ability.min_range:
		return "Zu nah"
	var standing := battle.resolver.unit_at(tile)
	if standing != null and standing.is_player == unit.is_player and standing != unit:
		return "Verbündeter"
	return ""


## Module, die an einem Angriff haengen: Doppellauf (Chance auf einen
## Zusatztreffer aufs selbe Ziel), Raufbold (Vergeltung) und Abrissbirne
## (Rueckstoss). Nur auf Angriffe gegen Gegner, nicht auf Heilstrahlen.
func _attack_modules(unit: Unit, mount: Dictionary, attack: ActionData, target) -> void:
	var fx: Dictionary = mount.get("fx", {})
	if fx.is_empty() or attack.power <= 0 or battle.outcome != BattleManager.Outcome.RUNNING:
		return
	if target == null or not (target is Unit) or target.is_player == unit.is_player:
		return
	mount["shots"] = int(mount.get("shots", 0)) + 1
	var raw := unit.raw_damage(attack)
	# Doppellauf: Zusatztreffer aufs selbe Ziel.
	var chance := float(fx.get("ricochet_chance", 0.0))
	if chance > 0.0 and target.is_alive() and battle.rng.randf() < chance:
		var bounce := maxi(1, int(round(float(raw) * float(fx.get("ricochet_share", 0.25)))))
		EventBus.log_line("%s: Zusatztreffer auf %s." % [unit.display_name, target.display_name])
		battle.resolver.apply_damage(unit, target, bounce, attack)
	# Raufbold: aufgeladene Vergeltung entlaedt sich auf das Ziel.
	var payback := float(fx.get("retaliation", 0.0))
	if payback > 0.0 and unit.retaliation_stacks > 0 and target.is_alive():
		var extra_dmg := maxi(1, int(round(float(raw) * payback * unit.retaliation_stacks)))
		EventBus.log_line("%s: Vergeltung (x%d)." % [unit.display_name, unit.retaliation_stacks])
		# Berserker (BIOS): volle Ladung trifft dazu alle Gegner daneben.
		var full := unit.retaliation_stacks >= int(unit.stats.get("retaliation_max", 3))
		unit.retaliation_stacks = 0
		battle.resolver.apply_damage(unit, target, extra_dmg, attack)
		if full and bool(fx.get("berserk", false)):
			for foe in battle.enemies_of(unit):
				if foe != target and foe.is_alive() and Grid.distance(unit.tile, foe.tile) <= 1:
					battle.resolver.apply_damage(unit, foe, extra_dmg, attack)
	# Abrissbirne (BIOS): jeder N-te Angriff stoesst zurueck.
	var knock := int(fx.get("knockback_every", 0))
	if knock > 0 and int(mount["shots"]) % knock == 0 and target.is_alive():
		battle.resolver._shove(unit, target, 1)
	battle._check_victory()


## Fesselkette: Reichweite und Betaeubung (die Zahl der Gegner steht am Modul).
const SHACKLE_RANGE := 3
const SHACKLE_STUN := 1.0


## Nach einer Faehigkeit: Modul Fesselkette -- die naechsten Gegner in
## Reichweite 3 ruecken neben den Traeger und sind kurz betaeubt. Wer schon
## daneben steht, zaehlt mit. Blockierte bleiben stehen, werden aber betaeubt.
func _shackle(unit: Unit, mount: Dictionary) -> void:
	var count := int((mount.get("fx", {}) as Dictionary).get("shackle", 0))
	if count <= 0 or not unit.is_alive():
		return
	var caught: Array = []
	for foe in battle.enemies_of(unit):
		if foe.is_alive() and Grid.distance(unit.tile, foe.tile) <= SHACKLE_RANGE:
			caught.append(foe)
	if caught.is_empty():
		return
	caught.sort_custom(func(a, b):
		return Grid.distance(a.tile, unit.tile) < Grid.distance(b.tile, unit.tile))
	caught = caught.slice(0, count)
	for foe in caught:
		for _i in SHACKLE_RANGE:
			if Grid.distance(foe.tile, unit.tile) <= 1:
				break
			var next: Vector2i = battle.resolver._step_toward(foe, unit.tile)
			if next == foe.tile:
				break
			battle.resolver.move_unit(foe, next)
		foe.apply_status(&"stun", SHACKLE_STUN, {"id": "stun", "stunned": true}, unit)
	EventBus.log_line("%s legt %d Gegner in Ketten." % [unit.display_name, caught.size()])


## Nach einer Faehigkeit -- die Module des Halters (``fx``):
##   * Peilsender: das Ziel wird markiert. Hat die Faehigkeit kein Gegnerziel
##     (Schildgaben), wirkt es auf den naechsten Gegner in rules.fallback_range.
##   * Schutzimpuls: Panzerung fuer alle Verbuendeten in der Naehe.
func _after_ability(unit: Unit, ability: ActionData, aim: Dictionary, fx: Dictionary = {}) -> void:
	if not unit.is_alive() or battle.outcome != BattleManager.Outcome.RUNNING:
		return
	var target = aim.get("target")
	var foe: Unit = null
	if target is Unit and target.is_alive() and target.is_player != unit.is_player:
		foe = target
	var mark_seconds := float(fx.get("mark", 0.0))
	if foe == null and mark_seconds > 0.0:
		foe = _nearest_enemy(unit, int(ModuleData.rule("fallback_range", 3)))
	if foe != null and mark_seconds > 0.0:
		battle.resolver.mark(foe, mark_seconds)
	var aura := int(fx.get("ability_armor_aura", 0))
	if aura > 0:
		var reach := int(ModuleData.rule("aura_range", 2))
		var seconds := ModuleData.rule("aura_seconds", 4.0)
		for ally in battle.allies_of(unit):
			if ally.is_alive() and Grid.distance(unit.tile, ally.tile) <= reach:
				ally.apply_status(&"guard_pulse", seconds, {"def": aura}, unit)


func _nearest_enemy(unit: Unit, reach: int) -> Unit:
	var best: Unit = null
	var best_gap := 1 << 30
	for foe in battle.enemies_of(unit):
		if not foe.is_alive():
			continue
		var gap := Grid.distance(unit.tile, foe.tile)
		if gap <= reach and gap < best_gap:
			best = foe
			best_gap = gap
	return best


## Wen unterstuetzt ``action``? "self": den Traeger. "ally" (und Angriffe mit
## ``heal``): nach der Heilregel (_care_choice) -- nur wenn er verletzt ist
## (heal) bzw. Schild brauchen kann (shield_gain) und in Reichweite steht.
## Leer, wenn niemand Hilfe braucht.
func _support_aim(unit: Unit, action: ActionData) -> Dictionary:
	if action.support == "self":
		return {"tile": unit.tile, "target": unit}
	var best := _care_choice(unit, action.range_tiles, func(ally: Unit) -> bool:
		var hp_max := maxi(1, ally.stat("hp_max"))
		# Heilung hilft auch bei leerem Schild (der Rest wird Schild).
		return (action.heal > 0 and (ally.hp < hp_max or ally.shield < ally.shield_max())) \
			or (action.shield_gain > 0 and ally.shield < ActionResolver.shield_cap(ally)), true)
	if best == null or Grid.distance(unit.tile, best.tile) > action.range_tiles:
		return {}
	return {"tile": best.tile, "target": best}


## Die Heilregel fuer alle Support-Waffen (14. Nov. 2026, SPOT-Blatt Fragen
## 11): geheilt wird grundsaetzlich das NAECHSTE Ziel, das Hilfe braucht --
## es sei denn, ein anderes in Reichweite oder bis zu 3 Felder dahinter hat
## mehr als 30 Prozentpunkte weniger Integritaet; dann das schwaechste davon.
const CARE_EXTRA_TILES := 3
const CARE_GAP := 0.30


func _care_choice(unit: Unit, reach: int, needs: Callable, with_self: bool) -> Unit:
	var nearest: Unit = null
	var nearest_gap := 1 << 30
	var candidates: Array = []
	for ally in battle.allies_of(unit):
		if not ally.is_alive() or (ally == unit and not with_self) or not needs.call(ally):
			continue
		var gap := Grid.distance(unit.tile, ally.tile)
		if gap > reach + CARE_EXTRA_TILES:
			continue
		candidates.append(ally)
		if gap < nearest_gap or (gap == nearest_gap and ally.hp_fraction() < nearest.hp_fraction()):
			nearest = ally
			nearest_gap = gap
	if nearest == null:
		return null
	var pick := nearest
	for ally in candidates:
		if ally.hp_fraction() < nearest.hp_fraction() - CARE_GAP and ally.hp_fraction() < pick.hp_fraction():
			pick = ally
	return pick


## Der verletzte Verbuendete, zu dem ein Heiler hin muss: nach der Heilregel
## gewaehlt, aber ausser Reichweite der Heilung. Ohne Kandidaten in der
## Naehe: der mit dem geringsten Anteil Integritaet ueberhaupt. Null, wenn
## der DROME nicht heilt oder der Gewaehlte erreichbar ist.
func _patient_out_of_reach(unit: Unit) -> Unit:
	var reach := 0
	for mount in unit.mounts:
		if (mount["attack"] as ActionData).heal > 0:
			reach = maxi(reach, (mount["attack"] as ActionData).range_tiles)
	if reach <= 0:
		return null
	var hurt := func(ally: Unit) -> bool: return ally.hp < ally.stat("hp_max")
	var best := _care_choice(unit, reach, hurt, false)
	if best == null:
		var best_share := 1.0
		for ally in battle.allies_of(unit):
			if ally == unit or not ally.is_alive():
				continue
			if ally.hp_fraction() < best_share:
				best_share = ally.hp_fraction()
				best = ally
	if best != null and Grid.distance(unit.tile, best.tile) <= reach:
		return null
	return best


## Der Takt einer Faehigkeit (wie viele Angriffe bis zu ihr) an diesem DROME.
## Mit der Passive Echo (Nimbus) laenger: die normalen Angriffe dazwischen
## mal ``passives.echo.slower`` (gerundet) -- Blaster jeder 3. -> jeder 4.
func trigger_every(unit: Unit, ability: ActionData) -> int:
	return unit.takt_every(ability)


## Passive Echo (Nimbus, 7. Nov. 2026): die Faehigkeit wirkt noch einmal --
## aufs selbe Ziel, ist es gefallen, aufs naechstbeste. Seit 18. Nov. 2026
## (Wunsch des Spielers) nacheinander statt im selben Augenblick: das Echo
## kommt ``passives.echo.gap`` Sekunden spaeter. Mit Ausholzeit fliegt es
## so lange wie die erste Wirkung (Ansage wie beim Wurf), der DROME bleibt
## dafuer aber nicht stehen -- so sieht man beide, ohne Zeit zu verlieren.
func _echo(unit: Unit, ability: ActionData, aim: Dictionary) -> void:
	if unit.passive() != "echo" or battle.outcome != BattleManager.Outcome.RUNNING:
		return
	unit.echoes.append({"action": ability, "target": aim.get("target"),
		"tile": aim["tile"], "left": echo_gap()})


## Wie lange das Echo nach der Faehigkeit wartet (Sekunden).
static func echo_gap() -> float:
	return float((Config.section("passives").get("echo", {}) as Dictionary).get("gap", 0.5))


## Laesst die Echos ablaufen. Erst die Pause, dann (mit Ausholzeit) der Flug,
## dann die Wirkung.
func _tick_echoes(unit: Unit, dt: float) -> void:
	var keep: Array = []
	var due: Array = []
	for entry in unit.echoes:
		entry["left"] = float(entry["left"]) - dt
		if float(entry["left"]) > 0.0:
			keep.append(entry)
		else:
			due.append(entry)
	unit.echoes = keep
	for entry in due:
		if battle.outcome != BattleManager.Outcome.RUNNING or not unit.is_alive():
			return
		var ability: ActionData = entry["action"]
		if bool(entry.get("flying", false)):
			var aim := _landing(unit, ability, {"tile": entry["tile"]}, entry.get("target"), true)
			if not aim.is_empty():
				_execute(unit, aim["tile"], ability, aim["target"], bool(aim.get("thrown", false)))
			continue
		var again := _echo_aim(unit, ability, entry.get("target"))
		if again.is_empty():
			continue
		if ability.windup > 0.0:
			var tile: Vector2i = again["tile"]
			_aim_at(unit, tile)
			# Waehrend des Wurfs zum Ziel schauen, auch wenn er weiterlaeuft.
			unit.aim_hold = maxf(unit.aim_hold, ability.windup + 0.2)
			EventBus.ability_cast.emit(unit, tile, ability, ability.windup, again["target"])
			unit.echoes.append({"action": ability, "target": again["target"], "tile": tile,
				"left": ability.windup, "flying": true})
		else:
			_execute(unit, again["tile"], ability, again["target"])


## Worauf das Echo zielt: das alte Ziel, wenn es noch geht, sonst das
## naechstbeste.
func _echo_aim(unit: Unit, ability: ActionData, target) -> Dictionary:
	if target is Unit and target.is_alive() \
			and battle.resolver.target_blocker(unit, target.tile, ability) == "":
		return {"tile": target.tile, "target": target}
	if ability.support != "":
		return _support_aim(unit, ability)
	return _aim(unit, ability, null)


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


## Zum Ziel drehen und den Blick kurz halten (nur Anzeige).
func _aim_at(unit: Unit, tile: Vector2i) -> void:
	if tile == unit.tile:
		return
	unit.set_facing(Unit.facing_at(unit.tile, tile))
	unit.aim_hold = AIM_HOLD


func _execute(unit: Unit, tile: Vector2i, action: ActionData, target: Unit,
		thrown: bool = false) -> void:
	_aim_at(unit, tile)
	if battle.resolver.execute(unit, tile, action, thrown):
		EventBus.action_used.emit(unit, tile, action)
		battle._check_victory()


# ---------------------------------------------------------------------------
# Gadgets
# ---------------------------------------------------------------------------

## Ereignis-Faehigkeiten (Hologramm). Gibt true zurueck, wenn eine ausgeloest
## hat -- dann ist der Augenblick verbraucht.
func _use_gadgets(unit: Unit, target: Unit) -> bool:
	for gadget in unit.gadgets:
		if float(gadget["ready"]) > 0.0:
			continue
		var ability: ActionData = gadget["ability"]
		match ability.trigger_kind:
			"adjacent":
				if not _enemy_adjacent(unit):
					continue
				var landing := _escape_landing(unit, ability, target)
				if landing == unit.tile:
					continue
				# Hologramm: wer daneben stand, haengt am Koeder fest.
				var decoy := float((gadget.get("fx", {}) as Dictionary).get("decoy", 0.0))
				var fooled: Array = []
				if decoy > 0.0:
					for foe in battle.enemies_of(unit):
						if foe.is_alive() and Grid.distance(unit.tile, foe.tile) <= 1:
							fooled.append(foe)
				_execute(unit, landing, ability, null)
				for foe in fooled:
					if foe.is_alive():
						foe.apply_status(&"decoy", decoy, {"stunned": true}, unit)
				if not fooled.is_empty():
					EventBus.log_line("%s lässt einen Köder zurück." % unit.display_name)
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
			# Laeuft hinter der Frontlinie mit, bis die im Kampf ist: ein
			# Schritt nur, wenn er danach noch weiter vom Gegner weg steht
			# als die vorderste Frontlinie. Frueher stand er bis zum ersten
			# Treffer still -- zu Beginn ein paar Sekunden Leerlauf. Wer
			# selbst bedraengt wird, wartet natuerlich nicht.
			if not shooting and not _frontline_engaged(unit) \
					and _nearest_foe(unit, unit.tile) > int(_realtime.get("kite_distance", 2)):
				var step := _approach(unit, target)
				if _nearest_foe(unit, step) > _frontline_gap(unit):
					return step
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
	for tile in Grid.neighbors(unit.tile):
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


## Wie nah ist die vorderste eigene Frontlinie (vanguard, skirmisher) am
## Gegner? Ohne Frontlinie 0 -- dann haelt nichts zurueck.
func _frontline_gap(unit: Unit) -> int:
	var gap := 99
	var has_front := false
	for ally in battle.allies_of(unit):
		if ally == unit or not ally.ai_role() in ["vanguard", "skirmisher"]:
			continue
		has_front = true
		gap = mini(gap, _nearest_foe(ally, ally.tile))
	return gap if has_front else 0


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
	# Ein Hexkreis mit Radius reach passt in dieses Rechteck (versetzte Reihen:
	# eine Spalte Luft je Seite).
	for x in range(target.tile.x - reach - 1, target.tile.x + reach + 2):
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
		for prev in Grid.neighbors(tile):
			if dist.has(prev):
				continue
			if prev != unit.tile and not grid.can_stand_on(prev, unit.unit_id):
				continue
			dist[prev] = here + 1
			if prev != unit.tile:
				frontier.append(prev)

	var best: Array[Vector2i] = []
	var best_cost := 1 << 30
	for nxt in Grid.neighbors(unit.tile):
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
func _walk(unit: Unit, next: Vector2i, target: Unit = null) -> void:
	# Bleibt das Ziel vom neuen Feld aus in Reichweite (Abstand halten,
	# Stellung wechseln), schaut er beim Laufen weiter zum Ziel (24. Nov.
	# 2026) -- vorher drehte er sich zwischen zwei Schuessen jedes Mal in die
	# Laufrichtung und zum Schuss wieder zurueck.
	var step_time := 1.0 / unit.move_speed()
	if target != null and target.is_alive() and next != target.tile \
			and Grid.distance(next, target.tile) <= unit.attack_range():
		unit.set_facing(Unit.facing_at(next, target.tile))
		unit.aim_hold = maxf(unit.aim_hold, step_time + 0.1)
	# Kurz nach dem Schuss schaut er weiter zum Ziel (laeuft seitlich/rueckwaerts).
	elif unit.aim_hold <= 0.0:
		unit.set_facing(Unit.facing_toward(unit.tile, next))
	# Die Schrittzeit steht VOR dem Versetzen fest: move_unit meldet den
	# Schritt (unit_moved), und die Szene liest daran ab, wie lange die Figur
	# gleitet.
	unit.step_left = step_time
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
		unit.raw_damage(action), action.energy_fraction, action.shield_mult)
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
