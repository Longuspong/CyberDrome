## Szene fuer render_film.gd: Neon-City-Arena, drei Gegner oben, drei eigene
## DROMEs darunter, die Kamera auf dem Ausschnitt. tick(k) spielt die
## Faehigkeit nach Bild k ab (60 Bilder = 1 s).
extends RefCounted

const W := 540
const H := 420
const HIT := 20             # Bild, in dem die Faehigkeit ausgeloest wird

var painter: AbilityPainter
var kind := ""
var units: Array = []
var players: Array = []
var enemies: Array = []

func _build(chassis: StringName, weapon: StringName) -> DromeBuild:
	var b := DromeBuild.create("X", {})
	b.apply_chassis(chassis)
	b.slots[PartDB.get_part(chassis).equip_slots()[0]] = weapon
	return b

func build(root: Window, kind_arg: String) -> SubViewport:
	kind = kind_arg
	var view := SubViewport.new()
	view.size = Vector2i(W, H)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new(); bg.color = Color("#0a0618"); bg.size = Vector2(W, H) * 6
	bg.position = -Vector2(W, H) * 2.5
	bg.z_index = -4000
	view.add_child(bg)
	var world := Node2D.new()
	view.add_child(world)
	var grid := MapGenerator.generate(TerrainDB.get_region(&"city"))
	ArenaPainter.build(world, grid, func(tile: Vector2i) -> int: return tile.y * 16 + 8, false, true, true)
	var floor := ArenaFloor3D.new()
	floor.z_index = -70
	floor.build(grid)
	world.add_child(floor)
	var arena := Arena3D.new()
	world.add_child(arena)
	painter = AbilityPainter.new()
	world.add_child(painter)
	var source: Array = {
		"vortex": [&"mage_body", &"eq_rune_staff"], "barrage": [&"strix_body", &"eq_mortar"],
		"lock": [&"strix_body", &"eq_rail_lance"], "stun": [&"jugg_body", &"eq_hammer"],
		"push": [&"jugg_body", &"eq_bulwark_ram"], "slash": [&"scout_body", &"eq_plasma_blade"],
		"whirl": [&"scout_body", &"eq_boomerang"], "double": [&"scout_body", &"eq_pulse_blaster"],
		"breaker": [&"scout_body", &"eq_neon_blaster"], "shield": [&"scout_body", &"eq_deflector"],
		"shield_ally": [&"jugg_body", &"eq_drone_pod"]}.get(kind, [&"scout_body", &"eq_pulse_blaster"])
	var melee := kind in ["stun", "push", "slash"]
	var squad := [
		[source[0], source[1], Vector2i(4, 6) if not melee else Vector2i(4, 4), true],
		[&"scout_body", &"eq_plasma_blade", Vector2i(2, 7), true],
		[&"mage_body", &"eq_rune_staff", Vector2i(6, 7), true],
		[&"jugg_body", &"eq_hammer", Vector2i(4, 3), false],
		[&"scout_body", &"eq_plasma_blade", Vector2i(3, 2), false],
		[&"strix_body", &"eq_rail_lance", Vector2i(5, 2), false],
	]
	for i in squad.size():
		var d: Array = squad[i]
		var b := _build(d[0], d[1])
		if not d[3]:
			b.faction = ["neon", "mecha", "solar"][i % 3]
		var unit := Unit.create(b, StringName("u%d" % i), d[3])
		unit.arena = arena
		unit.place_at(d[2])
		unit.facing = Unit.FACING_PLAYER if d[3] else Unit.FACING_ENEMY
		unit.hp = 100
		world.add_child(unit)
		units.append(unit)
		(players if d[3] else enemies).append(unit)
	painter.units = units
	var cam := Camera2D.new()
	cam.zoom = Vector2(1.45, 1.45)
	cam.position = IsoView.map_to_local(Vector2i(4, 4)) + Vector2(0, -62)
	world.add_child(cam)
	root.add_child(view)
	cam.make_current()
	return view

func tick(k: int) -> void:
	if k != HIT:
		_status_tick(k)
		return
	var me: Unit = players[0]
	var target: Unit = enemies[0]
	var at := IsoView.map_to_local(target.tile)
	var color := Teams.color(true)
	if kind not in ["shield", "shield_ally"]:
		me.play_attack(target.tile)
	var data := {"at": at, "color": color, "enemy": false, "radius": 2, "delay": 0.8,
		"from": me.visual_anchor(), "dir": (at - IsoView.map_to_local(me.tile)).normalized()}
	match kind:
		"vortex":
			painter.add_vortex(at, 2, 0.6, color)
		"whirl":
			data["radius"] = 1
			painter.add("whirl", data)
		"double":
			data["targets"] = [at, IsoView.map_to_local(enemies[1].tile)]
			painter.add("double", data)
		"shield":
			data["at"] = me.visual_anchor()
			data.erase("from")
			painter.add("shield", data)
		"shield_ally":
			data["at"] = players[1].visual_anchor()
			painter.add("shield", data)
		_:
			painter.add(kind, data)

## Zustaende so, wie die Wirkung sie setzt (nach der Verzoegerung).
func _status_tick(k: int) -> void:
	var target: Unit = enemies[0]
	if kind == "vortex" and k == HIT + 36:
		for e in enemies:
			e.apply_status(&"slow", 2.5, {"move_mult": 0.6})
	if kind == "stun" and k == HIT + 4:
		target.apply_status(&"stun", 1.0, {"stunned": true})
	if kind == "slash" and k == HIT + 8:
		target.apply_status(&"vulnerable", 5.0, {"damage_taken_mult": 1.5})
	for u in units:
		u.tick_statuses(1.0 / 60.0)
