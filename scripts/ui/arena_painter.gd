class_name ArenaPainter
extends RefCounted

## Die Arena im Kampf: Rand, Licht und die Plaetze der Deko (7. Nov. 2026,
## Wunsch des Spielers -- "die Spielkarte sieht fade aus").
##
## Seit dem 3D-Umbau (18. Nov. 2026) kommen Bodenplatten (ArenaFloor3D),
## Hindernisse und Deko (Arena3D) aus dem 3D-Generator. Gezeichnet wird hier
## nur noch, was flach auf dem Boden liegt; die gezeichneten Hindernisse,
## Deko und Bodenkacheln sind seit 20. Nov. 2026 entfernt
## (docs/TECHNIK_PRUEFUNG.md, Schritt B). Der Zufall haengt am Feld, nicht am
## Kampf -- derselbe Kampf sieht immer gleich aus.
##
##   Floor      die Zierlinie um das Spielfeld.
##   Lights     farbige Lichtflecken, additiv ueber dem Boden.

## Farben je Region: Kante (Zierlinie) und Lichtfarben.
const STYLE := {
	"city": {"trim": Color(0.25, 0.85, 1.0),
		"lights": [Color(1.0, 0.25, 0.7), Color(0.25, 0.85, 1.0)]},
	"green": {"trim": Color(0.55, 0.5, 0.38),
		"lights": [Color(0.85, 1.0, 0.45), Color(1.0, 0.85, 0.45)]},
	"plant7": {"trim": Color(1.0, 0.72, 0.2),
		"lights": [Color(1.0, 0.55, 0.2), Color(1.0, 0.8, 0.4)]},
}


static func style(region_id: String) -> Dictionary:
	return STYLE.get(region_id, STYLE["city"])


static func tile_rng(tile: Vector2i, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([tile.x, tile.y, salt])
	return rng


# ---------------------------------------------------------------------------
# Boden
# ---------------------------------------------------------------------------

class Floor extends Node2D:
	var grid: Grid
	var region_id := "city"

	func _ready() -> void:
		z_index = -60

	## Die Zierlinie um das Spielfeld -- zeigt, wo gekaempft wird: jede Kante
	## eines Feldes, hinter der kein Feld mehr liegt.
	func _draw() -> void:
		var trim: Color = ArenaPainter.style(region_id)["trim"]
		for pass_width in [7.0, 2.0]:
			var color := Color(trim, 0.18) if pass_width > 3.0 else Color(trim, 0.85)
			for tile in grid.all_tiles():
				var c := IsoView.tile_corners(tile)
				for i in 6:
					if grid.in_bounds(Grid.neighbor(tile, IsoView.EDGE_DIR[i])):
						continue
					draw_line(c[i], c[(i + 1) % 6], color, pass_width, true)


## Farbige Lichtflecken auf dem Boden -- additiv, unter den Einheiten.
class Lights extends Node2D:
	var spots: Array = []     # [Vector2 position, Color, float radius]

	func _ready() -> void:
		z_index = -50
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	func _draw() -> void:
		for spot in spots:
			var pos: Vector2 = spot[0]
			var color: Color = spot[1]
			var radius: float = spot[2]
			for k in 6:
				var r := radius * (1.0 - float(k) / 6.0)
				draw_set_transform(pos, 0.0, Vector2(1.0, IsoView.DEPTH_SQUASH))
				draw_circle(Vector2.ZERO, r, Color(color, 0.05))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------------------
# Zusammenbau
# ---------------------------------------------------------------------------

## Die Plaetze der Deko am Rand: [Feld, "lamp" oder "deco"]. Hexfeld: hinten
## (oben) eine Reihe, an den Seiten in Abstaenden, vorn nur die Ecken. Die
## Laterne Nummer i leuchtet in Lichtfarbe i (STYLE.lights, abwechselnd).
static func prop_spots(grid: Grid) -> Array:
	var spots: Array = []
	for i in range(0, grid.width, 3):
		spots.append([Vector2i(i, -2), "lamp" if (i / 3) % 2 == 0 else "deco"])
	for i in range(2, grid.height, 4):
		spots.append([Vector2i(-2, i), "deco" if (i / 4) % 2 == 0 else "lamp"])
		spots.append([Vector2i(grid.width + 1, i), "lamp" if (i / 4) % 2 == 0 else "deco"])
	spots.append([Vector2i(grid.width + 1, grid.height + 1), "lamp"])
	spots.append([Vector2i(-2, grid.height + 1), "lamp"])
	return spots


## Die Deko-Art auf einem Platz (fester Zufall je Feld).
static func deco_kind(region_id: String, tile: Vector2i) -> String:
	var settings := Config.section("obstacles")
	var kinds: Array = settings.get("props", {}).get(region_id,
		settings.get("kinds", {}).get(region_id, ["crate"]))
	return str(kinds[tile_rng(tile, 11).randi() % kinds.size()])


## Baut Zierlinie und Licht in ``world`` ein. Gibt die angelegten Knoten
## zurueck. Boden, Hindernisse und Deko stehen in 3D (ArenaFloor3D, Arena3D).
static func build(world: Node2D, grid: Grid) -> Array:
	var nodes: Array = []
	var region_id := str(grid.region.id) if grid.region != null else "city"
	var colors: Array = style(region_id)["lights"]

	var floor := Floor.new()
	floor.grid = grid
	floor.region_id = region_id
	world.add_child(floor)
	nodes.append(floor)

	# Das Licht der Laternen (die Laternen selbst baut Arena3D.build_props).
	var lights := Lights.new()
	var spots := prop_spots(grid)
	for index in spots.size():
		if spots[index][1] == "lamp":
			lights.spots.append([IsoView.map_to_local(spots[index][0]),
				colors[index % colors.size()], 90.0])

	# Ein paar Lichtflecken auch im Feld, gespiegelt wie die Hindernisse.
	var field_rng := tile_rng(Vector2i(grid.width, grid.height), hash(region_id))
	for i in 3:
		var tile := Vector2i(field_rng.randi_range(2, grid.width - 3),
			field_rng.randi_range(2, grid.height - 3))
		var color: Color = colors[i % colors.size()]
		lights.spots.append([IsoView.map_to_local(tile), color, 70.0])
		lights.spots.append([IsoView.map_to_local(MapGenerator.mirror(grid, tile)), color, 70.0])
	world.add_child(lights)
	nodes.append(lights)
	return nodes
