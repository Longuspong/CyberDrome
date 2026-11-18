class_name ArenaFloor3D
extends Node2D

## Der Boden des Kampffelds aus 3D-Hexplatten (18. Nov. 2026).
##
## Die Platten kommen aus tools/build_arena_models.py (Entwurf
## docs/design/drome_entwurf/v10_hexboden.py) -- dieselbe Optik wie DROMEs
## und Hindernisse. Der Boden bewegt sich nie, deshalb wird er EINMAL in ein
## grosses Bild in Weltkoordinaten gerendert und liegt dann als Sprite ganz
## unten in der 2D-Welt: Aufstellzone, Bodenringe und Lichter bleiben darueber
## sichtbar, die Arena (DROMEs, Hindernisse) darueber.
##
## Im Feld wechseln die Sorten nach Gewichten je Region (floor.json), der
## Zufall haengt am Feld -- derselbe Kampf sieht immer gleich aus. Drumherum
## ein Randstreifen dunklerer Platten, vorn mit tiefem Sockel.

const DIR := "res://assets/arena3d/"
## Aufloesung des Bodenbildes je Weltpunkt (Zoom bis ZOOM_MAX bleibt scharf).
const OVERSAMPLE := 2.5
const APRON := 3

var _view: SubViewport


static func _model(region_id: String, sort: String) -> Dictionary:
	var path := DIR + "floor_%s_%s.m3d" % [region_id, sort]
	if not FileAccess.file_exists(path):
		path = DIR + "floor_city_%s.m3d" % sort
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func weights(region_id: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DIR + "floor.json"))
	if not parsed is Dictionary:
		return {"platte": 1.0}
	return parsed.get(region_id, parsed.get("city", {"platte": 1.0}))


## Welche Platte auf einem Feld liegt.
static func sort_for(grid: Grid, tile: Vector2i, region_id: String, table: Dictionary) -> String:
	if not grid.in_bounds(tile):
		return "sockel" if tile.y == grid.height + APRON - 1 else "rand"
	var rng := ArenaPainter.tile_rng(tile, 21)
	var total := 0.0
	for w in table.values():
		total += float(w)
	var roll := rng.randf() * total
	for sort in table:
		roll -= float(table[sort])
		if roll <= 0.0:
			return str(sort)
	return "platte"


## Rendert den Boden fuer ``grid`` (einmal). Braucht keinen Baum.
func build(grid: Grid) -> void:
	for child in get_children():
		child.queue_free()
	var region_id := str(grid.region.id) if grid.region != null else "city"
	var table := weights(region_id)
	var tiles: Array[Vector2i] = []
	var box := Rect2()
	var first := true
	for y in range(-APRON, grid.height + APRON):
		for x in range(-APRON, grid.width + APRON):
			var tile := Vector2i(x, y)
			tiles.append(tile)
			for corner in IsoView.tile_corners(tile):
				if first:
					box = Rect2(corner, Vector2.ZERO)
					first = false
				else:
					box = box.expand(corner)
	# Platz fuer Plattendicke und Sockel unten.
	box = box.grow_individual(2, 2, 2, 40)

	_view = SubViewport.new()
	_view.name = "Boden3D"
	_view.transparent_bg = true
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.size = Vector2i(ceili(box.size.x * OVERSAMPLE), ceili(box.size.y * OVERSAMPLE))
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cam := DromeModel.make_camera()
	cam.size = box.size.y / DromeModel.SCALE
	cam.far = 4000.0
	cam.position = Arena3D.ground(box.get_center()) + cam.basis.z * 1500.0
	_view.add_child(cam)
	DromeModel._edge = maxf(0.75, 0.45 * OVERSAMPLE)
	var basis := DromeModel.facing_basis("deg90")
	for tile in tiles:
		var sort := sort_for(grid, tile, region_id, table)
		var model := _model(region_id, sort)
		if model.is_empty():
			continue
		var mesh := DromeModel._mesh_for("floor|%s|%s" % [region_id, sort], model,
			model.get("colors", {}))
		if mesh == null:
			continue
		var inst := DromeModel.mesh_instance(mesh)
		inst.position = Arena3D.ground(IsoView.map_to_local(tile))
		inst.basis = basis
		_view.add_child(inst)
	add_child(_view)
	var sprite := Sprite2D.new()
	sprite.name = "Boden"
	sprite.centered = false
	sprite.texture = _view.get_texture()
	sprite.position = box.position
	sprite.scale = Vector2.ONE / OVERSAMPLE
	add_child(sprite)
