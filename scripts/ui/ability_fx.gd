class_name AbilityFx
extends RefCounted

## Wie Angriffe und Faehigkeiten im Kampf aussehen (18. Nov. 2026): die
## Optik zu action_used und ability_cast, aus BattleScreen herausgezogen,
## damit der Kampf und der Film-Blicktest (render_film.gd) dieselben Bilder
## zeigen. Kennt die Regeln nicht -- nur Einheiten, Feld und Aktion.
##
## Abfolge einer Faehigkeit mit Ausholzeit (ActionData.windup):
##   on_cast  Name, Ansage (AbilityPainter "<art>_cast") und Haltung des DROME:
##            Nahkampf holt so aus, dass der Schlag beim Wirken sitzt, der
##            Runenstab wird hochgehalten.
##   on_used  die Wirkung: Schuss bzw. Aufprall, dann die Form der Faehigkeit.

## Dauer, in der ein gezogener oder gestossener DROME auf sein Feld rutscht.
const FORCED_SLIDE := 0.38
## Faehigkeiten, deren Haltung schon mit der Ansage beginnt -- beim Wirken
## keine zweite Bewegung.
const CAST_POSED := ["stun", "slash", "vortex"]
const NAME_COLOR := Color(1.0, 0.86, 0.3)


static func on_used(view: BattleView, unit: Unit, tile: Vector2i, action: ActionData,
		units: Array) -> void:
	var cast := action.windup > 0.0 and not action.is_attack()
	var kind := AbilityPainter.kind_for(action)
	if tile != unit.tile and not (cast and kind in CAST_POSED):
		unit.play_attack(tile, action)
	var color := Teams.color(unit.is_player)
	if not action.is_move() and (action.power > 0 or action.heal > 0):
		var style := attack_style(unit, tile, action, unit_at(units, tile))
		if cast and kind in ["lock", "vortex"]:
			style["projectile"] = ""      # Strahl bzw. Kugel zeigt die Ansage
		# Fernkampf beginnt an der Muendung (EffectPainter hebt "from" um 34).
		var from := unit.visual_anchor()
		if unit.arena != null and str(style.get("projectile", "")) != "":
			from = unit.arena.weapon_tip(unit, action) + Vector2(0, 34)
		if action.salvo > 1:
			_salvos(view, unit, tile, action, units, from, color, style)
		else:
			view.show_attack(from, IsoView.map_to_local(tile), color, style)
	_show_ability(view, unit, tile, action, color, units)
	if not action.is_attack() and not cast:
		view.show_float(unit.visual_anchor(), action.display_name + "!", NAME_COLOR, true)


static func on_cast(view: BattleView, unit: Unit, tile: Vector2i, action: ActionData,
		seconds: float, units: Array) -> void:
	var kind := AbilityPainter.kind_for(action)
	var color := Teams.color(unit.is_player)
	view.show_float(unit.visual_anchor(), action.display_name + "!", NAME_COLOR, true)
	if kind == "":
		return
	var data := ability_data(unit, tile, action, color, kind, units)
	data["ability"] = kind
	data["release"] = Arena3D.THROW_RELEASE
	if kind == "vortex" and unit.arena != null:
		# Kugel: an der Waffenspitze, bis sie den Schwung verlaesst.
		data["tip"] = func() -> Vector2: return unit.arena.weapon_tip(unit, action)
	view.show_cast(kind, data, seconds)
	match kind:
		"stun", "slash":
			# Ausholen so getaktet, dass der Schlag beim Wirken sitzt.
			unit.play_attack(tile, action, seconds / Arena3D.MELEE_HIT_AT)
		"vortex":
			unit.play_throw(action, seconds)


## Salven (Doppelschuss): jeder Schuss fliegt einzeln, zu denselben Zeiten,
## zu denen er in den Regeln trifft (ActionResolver.salvo_time).
static func _salvos(view: BattleView, unit: Unit, tile: Vector2i, action: ActionData,
		units: Array, from: Vector2, color: Color, style: Dictionary) -> void:
	var targets := double_targets(unit, tile, action, units)
	while targets.size() < action.shots:
		targets.append(targets[0])
	for volley in targets.size():
		if volley > 0 and targets[volley] != targets[volley - 1]:
			# Vor der naechsten Salve zum naechsten Ziel drehen.
			var turn_at := ActionResolver.salvo_time(action, volley, 0) \
				- ActionResolver.SALVO_FLIGHT - ActionResolver.SALVO_PAUSE * 0.5
			var aim := IsoView.local_to_map(targets[volley])
			view.create_tween().tween_callback(func() -> void:
				if is_instance_valid(unit) and unit.is_alive():
					unit.set_facing(Unit.facing_at(unit.tile, aim))
					unit.aim_hold = maxf(unit.aim_hold, 0.6)).set_delay(maxf(0.0, turn_at))
		for b in action.salvo:
			var shot := style.duplicate()
			shot["wait"] = ActionResolver.salvo_time(action, volley, b) - ActionResolver.SALVO_FLIGHT
			shot["heavy"] = false
			if unit.arena != null:
				# Aus der Muendung, wie sie beim Abfeuern steht.
				shot["from_fn"] = func() -> Vector2:
					return unit.arena.weapon_tip(unit, action) + Vector2(0, 34) \
						if is_instance_valid(unit) else from
			view.show_attack(from, targets[volley], color, shot)


static func unit_at(units: Array, tile: Vector2i) -> Unit:
	for unit in units:
		if unit.is_alive() and unit.tile == tile:
			return unit
	return null


static func _show_ability(view: BattleView, unit: Unit, tile: Vector2i, action: ActionData,
		color: Color, units: Array) -> void:
	var kind := AbilityPainter.kind_for(action)
	if kind == "":
		return
	var data := ability_data(unit, tile, action, color, kind, units)
	if kind == "vortex":
		view.show_vortex(tile, action.aoe_radius, action.delay, color, not unit.is_player)
		return
	view.show_ability(kind, data)


## Die Angaben einer Form: Ort, Farbe, Seite, Flaeche, Schuetze, Richtung ...
static func ability_data(unit: Unit, tile: Vector2i, action: ActionData, color: Color,
		kind: String, units: Array) -> Dictionary:
	var at := IsoView.map_to_local(tile)
	var data := {"at": at, "color": color, "enemy": not unit.is_player,
		"radius": action.aoe_radius, "delay": action.delay, "from": unit.visual_anchor()}
	if unit.arena != null and kind in ["lock", "double"]:
		data["muzzle"] = func() -> Vector2: return unit.arena.weapon_tip(unit, action)
	match kind:
		"double":
			data["targets"] = double_targets(unit, tile, action, units)
		"shield":
			var aimed := unit_at(units, tile)
			if aimed == null or tile == unit.tile:
				data["at"] = unit.visual_anchor()
				data.erase("from")
			else:
				data["at"] = aimed.visual_anchor()
	return data


## Die Ziele eines Doppelschusses wie ActionResolver._multi_shot: das Ziel,
## dann der naechste Gegner in Reichweite (Feldmitten fuer die Marken).
static func double_targets(unit: Unit, tile: Vector2i, action: ActionData, units: Array) -> Array:
	var out := [IsoView.map_to_local(tile)]
	var best: Unit = null
	for other in units:
		if not other.is_alive() or other.is_player == unit.is_player or other.tile == tile:
			continue
		if Grid.distance(unit.tile, other.tile) > action.range_tiles:
			continue
		if best == null or Grid.distance(unit.tile, other.tile) < Grid.distance(unit.tile, best.tile):
			best = other
	if best != null and action.shots > 1:
		out.append(IsoView.map_to_local(best.tile))
	return out


## Wie ein Angriff aussieht (Wunsch des Spielers, 9. Nov. 2026): Nahkampf ohne
## Projektil; Blaster gerader Schuss, Lanze schweres Geschoss, Runenstab eine
## Energiekugel, eine Reparatur ein Heilstrahl. Die
## Schadensart steuert Leuchten und Einschlag (BattleView.show_attack).
static func attack_style(unit: Unit, tile: Vector2i, action: ActionData, target: Unit = null) -> Dictionary:
	var style := {"energy": action.energy_fraction, "area": action.aoe_radius,
		"heavy": not action.is_attack() or action.aoe_radius > 0, "projectile": "bolt"}
	var id := str(action.id)
	var reach := Grid.distance(unit.tile, tile)
	if action.heal > 0 and target != null and target != unit and target.is_player == unit.is_player:
		style["projectile"] = "beam"
		style["energy"] = 1.0
	elif action.range_tiles <= 1 or reach <= 1:
		style["projectile"] = ""
	elif id.begins_with("act_rune") or id.begins_with("act_repair"):
		style["projectile"] = "orb"
	elif id.begins_with("act_rail"):
		style["projectile"] = "slug"
	return style
