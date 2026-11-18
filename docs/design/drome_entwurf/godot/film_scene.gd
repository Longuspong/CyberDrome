## Szene fuer render_film.gd (18. Nov. 2026): der echte Kampfbildschirm-
## Unterbau (BattleView) mit Neon-City-Arena, drei eigene DROMEs unten, drei
## Gegner in Fraktionsfarben oben. Die Faehigkeit laeuft wie im Kampf ab:
## AbilityFx.on_cast (Ansage, Haltung), nach der Ausholzeit AbilityFx.on_used
## (Wirkung), dazu die Folgen, die sonst die Regeln ausloesen: Sog bzw. Stoss
## (Rutschen), Treffer mit Zahl, Zustaende. 60 Bilder = 1 s.
extends RefCounted

const W := 540
const H := 420
const CAST_AT := 12          # Bild, in dem ausgeholt wird

var view: BattleView
var kind := ""
var action: ActionData
var units: Array = []
var players: Array = []
var enemies: Array = []
var _hit_at := 0
var _boom_at := -1
## Spaete Treffer (Salven): [Bild, Einheit, Schaden]
var _later: Array = []

const SOURCES := {
	"vortex": [&"mage_body", &"eq_rune_staff", &"act_rune_vortex"],
	"barrage": [&"strix_body", &"eq_mortar", &"act_mortar_barrage"],
	"lock": [&"strix_body", &"eq_rail_lance", &"act_rail_pierce"],
	"stun": [&"jugg_body", &"eq_hammer", &"act_hammer_stun"],
	"push": [&"jugg_body", &"eq_bulwark_ram", &"act_ram_slam"],
	"slash": [&"scout_body", &"eq_plasma_blade", &"act_plasma_rend"],
	"whirl": [&"scout_body", &"eq_boomerang", &"act_boomerang_whirl"],
	"double": [&"scout_body", &"eq_pulse_blaster", &"act_pulse_double"],
	"breaker": [&"scout_body", &"eq_neon_blaster", &"act_neon_breaker"],
	"shield": [&"scout_body", &"eq_deflector", &"act_deflector_charge"],
	"shield_ally": [&"jugg_body", &"eq_drone_pod", &"act_drone_guard"],
}

func _build(chassis: StringName, weapon: StringName) -> DromeBuild:
	var b := DromeBuild.create("X", {})
	b.apply_chassis(chassis)
	b.slots[PartDB.get_part(chassis).equip_slots()[0]] = weapon
	return b

func build(root: Window, kind_arg: String) -> SubViewport:
	kind = kind_arg
	var src: Array = SOURCES.get(kind, SOURCES["double"])
	for a in PartDB.get_part(src[1]).actions:
		if a.id == src[2]:
			action = a
	var port := SubViewport.new()
	port.size = Vector2i(W, H)
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new(); bg.color = Color("#0a0618"); bg.size = Vector2(W, H) * 6
	bg.position = -Vector2(W, H) * 2.5
	bg.z_index = -4000
	port.add_child(bg)
	view = BattleView.new()
	port.add_child(view)
	root.add_child(port)
	view.build_terrain(MapGenerator.generate(TerrainDB.get_region(&"city")))
	var melee := kind in ["stun", "push", "slash"]
	var squad := [
		[src[0], src[1], Vector2i(4, 4) if melee else (Vector2i(3, 5) if kind in ["whirl", "double"] else Vector2i(4, 7)), true],
		[&"scout_body", &"eq_plasma_blade", Vector2i(2, 7), true],
		[&"mage_body", &"eq_rune_staff", Vector2i(6, 7), true],
		[&"jugg_body", &"eq_hammer", Vector2i(4, 3), false],
		[&"scout_body", &"eq_plasma_blade", Vector2i(2, 2), false],
		[&"strix_body", &"eq_rail_lance", Vector2i(5, 1), false],
	]
	for i in squad.size():
		var d: Array = squad[i]
		var b := _build(d[0], d[1])
		if not d[3]:
			b.faction = ["neon", "mecha", "solar"][i % 3]
		var unit := Unit.create(b, StringName("u%d" % i), d[3])
		unit.place_at(d[2])
		unit.facing = Unit.FACING_PLAYER if d[3] else Unit.FACING_ENEMY
		unit.hp = 100
		view.attach_unit(unit)
		units.append(unit)
		(players if d[3] else enemies).append(unit)
	view.abilities.units = units
	view.set_pixel_scale(1.45)
	var cam := Camera2D.new()
	cam.zoom = Vector2(1.45, 1.45)
	cam.position = IsoView.map_to_local(Vector2i(4, 4)) + Vector2(0, -50)
	view.add_child(cam)
	cam.make_current()
	_hit_at = CAST_AT + int(round(action.windup * 60.0))
	if action.delay > 0.0:
		_boom_at = _hit_at + int(round(action.delay * 60.0))
	return port

func _target_tile() -> Vector2i:
	if kind == "shield":
		return players[0].tile
	if kind == "shield_ally":
		return players[1].tile
	return enemies[0].tile

func tick(k: int) -> void:
	var me: Unit = players[0]
	if k == CAST_AT:
		if _target_tile() != me.tile:
			me.set_facing(Unit.facing_at(me.tile, _target_tile()))
		AbilityFx.on_cast(view, me, _target_tile(), action, action.windup, units)
	if k == _hit_at:
		var tile := _target_tile()
		_consequences(me, tile)
		AbilityFx.on_used(view, me, tile, action, units)
	for entry in _later:
		if int(entry[0]) == k:
			_hurt(entry[1], int(entry[2]))
	if k == _boom_at:
		for e in enemies:
			if Grid.distance(e.tile, enemies[0].tile) <= action.aoe_radius:
				_hurt(e, 18)
				if kind == "vortex":
					e.apply_status(&"slow", 2.5, {"move_mult": 0.6})
	for u in units:
		u.tick_statuses(1.0 / 60.0)

## Was sonst die Regeln tun: Sog/Stoss, Schaden, Zustaende.
func _consequences(me: Unit, tile: Vector2i) -> void:
	var target: Unit = AbilityFx.unit_at(units, tile)
	match kind:
		"vortex":
			_slide(enemies[1], Vector2i(3, 2))
			_slide(enemies[2], Vector2i(5, 2))
		"push":
			_slide(target, Vector2i(4, 2))
			_hurt(target, 24)
		"stun":
			_hurt(target, 20)
			target.apply_status(&"stun", 1.0, {"stunned": true})
		"slash":
			_hurt(target, 22)
			target.apply_status(&"vulnerable", 5.0, {"damage_taken_mult": 1.5})
		"lock", "breaker", "whirl":
			_hurt(target, 26)
		"double":
			# Je Schuss ein Treffer, wenn er ankommt (wie ActionResolver).
			var spots := AbilityFx.double_targets(me, tile, action, units)
			for volley in action.shots:
				var at: Vector2 = spots[mini(volley, spots.size() - 1)]
				var who: Unit = AbilityFx.unit_at(units, IsoView.local_to_map(at))
				for b in action.salvo:
					_later.append([_hit_at + int(round(ActionResolver.salvo_time(action, volley, b) * 60.0)), who, 4])

func _slide(unit: Unit, to: Vector2i) -> void:
	if unit == null:
		return
	unit.place_at(to)
	unit.animate_last_move(AbilityFx.FORCED_SLIDE, true)
	view.refresh_unit_depth(unit)

func _hurt(unit: Unit, amount: int) -> void:
	if unit == null:
		return
	unit.play_hit()
	view.show_float(unit.visual_anchor(), "-%d" % amount, Color(1.0, 0.9, 0.5))
