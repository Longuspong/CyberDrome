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
	# Modul Koedersender: wer angelockt wurde, greift den Traeger an.
	var taunt = unit.statuses.get(&"taunt")
	if taunt is Dictionary:
		var lurer := battle.resolver.unit_by_id(taunt.get("taunt_by"))
		if lurer != null and lurer.is_alive():
			return lurer
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
			_execute(unit, aim["tile"], ability, aim["target"])
			_echo(unit, ability, aim)
			_after_ability(unit, ability, aim, fx)
			_shackle(unit, mount)
			mount["count"] = maxf(0.0, float(mount["count"]) + unit.takt_step(mount)
				- float(trigger_every(unit, ability)))
			mount["instant"] = bool(fx.get("ready_after_ability", false))
			# Ueberladung: die naechsten Angriffe treffen haerter.
			if float(fx.get("post_ability_power", 0.0)) > 0.0:
				mount["overload"] = int(ModuleData.rule("overload_attacks", 3))
			return true
	# Ueberladung: eine aufgeladene Kopie des Angriffs.
	var overload := int(mount.get("overload", 0))
	if overload > 0:
		if not mount.has("overload_attack"):
			var strong := attack.copy()
			strong.power = int(round(float(attack.power) * (1.0 + float(fx.get("post_ability_power", 0.0)))))
			mount["overload_attack"] = strong
		attack = mount["overload_attack"]
	var shot := {}
	if attack.heal > 0:
		shot = _support_aim(unit, attack)
	if shot.is_empty():
		shot = _aim(unit, attack, target)
	if shot.is_empty():
		return false
	_execute(unit, shot["tile"], attack, shot["target"])
	_attack_modules(unit, mount, attack, shot.get("target"))
	_tick_extras(unit, mount, target)
	if overload > 0:
		mount["overload"] = overload - 1
	if ability != null and not due:
		mount["count"] = float(mount["count"]) + unit.takt_step(mount)
	return true


## Modul-Faehigkeiten nach Angriffen (Orbit-Fokus, 9. Nov. 2026): jeder
## Angriff der Waffe zaehlt mit (Taktchip 1,25); ist der Takt voll, loest die
## Faehigkeit dazu aus. Mit Echo laenger wie jeder Treffer-Takt.
func _tick_extras(unit: Unit, mount: Dictionary, target: Unit) -> void:
	for extra in mount.get("extras", []):
		if not unit.is_alive() or battle.outcome != BattleManager.Outcome.RUNNING:
			return
		var ability: ActionData = extra["ability"]
		extra["count"] = float(extra["count"]) + unit.takt_step(mount)
		if float(extra["count"]) < float(unit.takt_every(ability)) - 0.001:
			continue
		var aim := _aim(unit, ability, target)
		if aim.is_empty():
			continue
		extra["count"] = maxf(0.0, float(extra["count"]) - float(unit.takt_every(ability)))
		_execute(unit, aim["tile"], ability, aim["target"])
		_echo(unit, ability, aim)
		_after_ability(unit, ability, aim, mount.get("fx", {}))


## Module, die an einem Angriff haengen (NEUANFANG 6g): Doppellauf (Chance
## auf einen Querschlaeger aufs selbe Ziel), Raufbold (Vergeltung), Rundum-
## schlag (Nachbarn) und Gunslinger (jeder N-te Angriff trifft dazu einen
## Gegner irgendwo auf dem Feld). Nur auf Angriffe
## gegen Gegner, nicht auf Heilstrahlen.
func _attack_modules(unit: Unit, mount: Dictionary, attack: ActionData, target) -> void:
	var fx: Dictionary = mount.get("fx", {})
	if fx.is_empty() or attack.power <= 0 or battle.outcome != BattleManager.Outcome.RUNNING:
		return
	if target == null or not (target is Unit) or target.is_player == unit.is_player:
		return
	mount["shots"] = int(mount.get("shots", 0)) + 1
	var raw := unit.raw_damage(attack)
	# Doppellauf: Zusatztreffer. Kettenreaktion: er kann erneut ausloesen
	# und springt bevorzugt auf markierte Gegner.
	var chance := float(fx.get("ricochet_chance", 0.0))
	if chance > 0.0:
		var bounce := maxi(1, int(round(float(raw) * float(fx.get("ricochet_share", 0.25)))))
		var jumps := int(fx.get("chain_jumps", 0))
		var at: Unit = target
		for hop in jumps + 1:
			if at == null or not at.is_alive() or battle.rng.randf() >= chance:
				break
			EventBus.log_line("%s: Zusatztreffer auf %s." % [unit.display_name, at.display_name])
			battle.resolver.apply_damage(unit, at, bounce, attack)
			if jumps > 0:
				at = _chain_next(unit, at)
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
	# Rundumschlag: alle anderen Gegner direkt neben dem Traeger.
	var cleave := float(fx.get("cleave", 0.0))
	if cleave > 0.0:
		var side := maxi(1, int(round(float(raw) * cleave)))
		for foe in battle.enemies_of(unit):
			if foe == target or not foe.is_alive() or Grid.distance(unit.tile, foe.tile) > 1:
				continue
			battle.resolver.apply_damage(unit, foe, side, attack)
	# Abrissbirne (BIOS): jeder N-te Angriff stoesst zurueck.
	var knock := int(fx.get("knockback_every", 0))
	if knock > 0 and int(mount["shots"]) % knock == 0 and target.is_alive():
		battle.resolver._shove(unit, target, 1)
	var every := int(fx.get("field_shot_every", 0))
	if every > 0 and int(mount["shots"]) % every == 0:
		var extra := _field_shot_target(unit, target, bool(fx.get("field_shot_marked", false)))
		if extra != null:
			EventBus.log_line("%s trifft quer uebers Feld %s." % [unit.display_name, extra.display_name])
			battle.resolver.apply_damage(unit, extra, raw, attack)
			EventBus.action_used.emit(unit, extra.tile, attack)
	battle._check_victory()


## Kettenreaktion: wohin springt der naechste Zusatztreffer? Ein markierter
## Gegner nahe dem letzten (Reichweite 3), sonst wieder derselbe.
func _chain_next(unit: Unit, last: Unit) -> Unit:
	var best: Unit = null
	var best_gap := 1 << 30
	for foe in battle.enemies_of(unit):
		if foe == last or not foe.is_alive() or not ActionResolver.is_marked(foe):
			continue
		var gap := Grid.distance(foe.tile, last.tile)
		if gap <= 3 and gap < best_gap:
			best = foe
			best_gap = gap
	return best if best != null else last


## Gunslinger: ein ANDERER Gegner irgendwo auf dem Feld -- der mit dem
## geringsten Anteil Integritaet. Ist nur das Ziel uebrig, dieses.
func _field_shot_target(unit: Unit, target: Unit, marked_first: bool = false) -> Unit:
	var best: Unit = null
	var best_share := 2.0
	# Revolverheld (BIOS): markierte Gegner zuerst.
	if marked_first:
		for foe in battle.enemies_of(unit):
			if foe.is_alive() and foe != target and ActionResolver.is_marked(foe) \
					and foe.hp_fraction() < best_share:
				best_share = foe.hp_fraction()
				best = foe
		if best != null:
			return best
	for foe in battle.enemies_of(unit):
		if not foe.is_alive() or foe == target:
			continue
		var share: float = foe.hp_fraction()
		if share < best_share:
			best_share = share
			best = foe
	if best == null and target != null and target.is_alive():
		return target
	return best


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
		foe.apply_status(&"stun", SHACKLE_STUN, {"id": "stun", "stunned": true})
	EventBus.log_line("%s legt %d Gegner in Ketten." % [unit.display_name, caught.size()])


## Nach einer Faehigkeit -- die Module des Halters (``fx``):
##   * Koedersender: das Ziel muss eine Weile den Traeger angreifen (Status
##     "taunt", lured_by liest ihn).
##   * Peilsender: das Ziel wird markiert.
##     Hat die Faehigkeit kein Gegnerziel (Schildgaben), wirken beide auf den
##     naechsten Gegner in rules.fallback_range.
##   * Gabelung: die Faehigkeit noch einmal auf ein zweites Ziel, schwaecher.
##   * Schutzimpuls: Panzerung fuer alle Verbuendeten in der Naehe.
func _after_ability(unit: Unit, ability: ActionData, aim: Dictionary, fx: Dictionary = {}) -> void:
	if not unit.is_alive() or battle.outcome != BattleManager.Outcome.RUNNING:
		return
	var target = aim.get("target")
	var foe: Unit = null
	if target is Unit and target.is_alive() and target.is_player != unit.is_player:
		foe = target
	var mark_seconds := float(fx.get("mark", 0.0))
	if foe == null and (ability.taunt_seconds > 0.0 or mark_seconds > 0.0):
		foe = _nearest_enemy(unit, int(ModuleData.rule("fallback_range", 3)))
	if foe != null and ability.taunt_seconds > 0.0:
		foe.apply_status(&"taunt", ability.taunt_seconds, {"taunt_by": unit.unit_id})
		EventBus.log_line("%s lockt %s an." % [unit.display_name, foe.display_name])
	if foe != null and mark_seconds > 0.0:
		battle.resolver.mark(foe, mark_seconds * ActionResolver.mark_mult(unit))
	# Gravitation (BIOS): ein zweites Ziel heran, beide verlangsamt.
	if bool(fx.get("gravity", false)) and ability.push_tiles < 0:
		_gravity(unit, ability, foe)
	# Nimbus-BIOS: jede Faehigkeit gibt dem Traeger Schild.
	if unit.passive() == "echo" and unit.has_bios():
		var gain := int(round(ModuleData.rule("bios_ability_shield", 6) * unit.power_factor()))
		unit.shield = mini(ActionResolver.shield_cap(unit), unit.shield + gain)
	var fork := float(fx.get("ability_fork", 0.0))
	if fork > 0.0:
		_fork(unit, ability, aim, fork)
	var aura := int(fx.get("ability_armor_aura", 0))
	if aura > 0:
		var reach := int(ModuleData.rule("aura_range", 2))
		var seconds := ModuleData.rule("aura_seconds", 4.0)
		for ally in battle.allies_of(unit):
			if ally.is_alive() and Grid.distance(unit.tile, ally.tile) <= reach:
				ally.apply_status(&"guard_pulse", seconds, {"def": aura})


func _gravity(unit: Unit, ability: ActionData, first: Unit) -> void:
	var slow := {"move_mult": ModuleData.rule("gravity_move_mult", 0.6)}
	var seconds := ModuleData.rule("gravity_slow", 1.5)
	var second: Unit = null
	var best_gap := 1 << 30
	for foe in battle.enemies_of(unit):
		if foe == first or not foe.is_alive():
			continue
		var gap := Grid.distance(unit.tile, foe.tile)
		if gap <= ability.range_tiles and gap < best_gap:
			best_gap = gap
			second = foe
	if second != null:
		battle.resolver._shove(unit, second, ability.push_tiles)
	for foe in [first, second]:
		if foe != null and foe.is_alive():
			foe.apply_status(&"slow", seconds, slow)


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


## Gabelung: die Faehigkeit wird mit ``share`` Wirkung auf ein zweites Ziel
## wiederholt -- ein anderer Gegner nahe dem ersten (rules.fork_range), bei
## Schildgaben und Heilung ein anderer Verbuendeter in Reichweite.
func _fork(unit: Unit, ability: ActionData, aim: Dictionary, share: float) -> void:
	var first = aim.get("target")
	var half := ability.copy()
	half.power = int(round(float(ability.power) * share))
	half.heal = int(round(float(ability.heal) * share))
	half.shield_gain = int(round(float(ability.shield_gain) * share))
	half.taunt_seconds = 0.0
	var second: Unit = null
	if ability.support != "":
		var best_share := 2.0
		for ally in battle.allies_of(unit):
			if ally == first or not ally.is_alive():
				continue
			if Grid.distance(unit.tile, ally.tile) > maxi(1, ability.range_tiles):
				continue
			if ally.hp_fraction() < best_share:
				best_share = ally.hp_fraction()
				second = ally
	else:
		var from_tile: Vector2i = aim.get("tile", unit.tile)
		var reach := int(ModuleData.rule("fork_range", 3))
		var best_gap := 1 << 30
		for foe in battle.enemies_of(unit):
			if foe == first or not foe.is_alive():
				continue
			var gap := Grid.distance(from_tile, foe.tile)
			if gap <= reach and gap < best_gap:
				best_gap = gap
				second = foe
	if second == null:
		return
	# Die Gabelung springt vom ersten Ziel weiter -- die Reichweite der Waffe
	# zaehlt dafuer nicht.
	half.range_tiles = maxi(ability.range_tiles, Grid.distance(unit.tile, second.tile))
	EventBus.log_line("%s: Gabelung auf %s." % [unit.display_name, second.display_name])
	_execute(unit, second.tile, half, second)


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
		# Heilung hilft auch bei leerem Schild (der Rest wird Schild).
		var needs: bool = (action.heal > 0 and (ally.hp < hp_max or ally.shield < ally.shield_max())) \
			or (action.shield_gain > 0 and ally.shield < ActionResolver.shield_cap(ally))
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
	return unit.takt_every(ability)


## Der Takt einer Zeit-Faehigkeit in Sekunden -- mit Echo ebenso laenger
## (Runenstab: 3 s -> 4,5 s).
func _time_after_ability(unit: Unit, ability: ActionData) -> float:
	return unit.takt_seconds(ability)


## Passive Echo (Nimbus, 7. Nov. 2026): die Faehigkeit wirkt gleich noch
## einmal -- aufs selbe Ziel, ist es gefallen, aufs naechstbeste.
func _echo(unit: Unit, ability: ActionData, aim: Dictionary) -> void:
	if unit.passive() != "echo" or battle.outcome != BattleManager.Outcome.RUNNING:
		return
	var again := aim
	var target: Unit = aim.get("target")
	if target == null or not target.is_alive():
		again = _aim(unit, ability, null)
	elif unit.has_bios() and ability.support == "":
		# Nimbus-BIOS: das Echo darf ein anderes Ziel waehlen.
		for foe in battle.enemies_of(unit):
			if foe != target and foe.is_alive() \
					and battle.resolver.target_blocker(unit, foe.tile, ability) == "":
				again = {"tile": foe.tile, "target": foe}
				break
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
				_after_ability(unit, ability, aim, gadget.get("fx", {}))
				gadget["ready"] = _time_after_ability(unit, ability)
				return true
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
						foe.apply_status(&"decoy", decoy, {"stunned": true})
				if not fooled.is_empty():
					EventBus.log_line("%s laesst einen Koeder zurueck." % unit.display_name)
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
