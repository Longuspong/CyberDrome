class_name ArenaPainter
extends RefCounted

## Die Arena im Kampf: Boden, Rand, Hindernisse, Deko und Licht (7. Nov. 2026,
## Wunsch des Spielers -- "die Spielkarte sieht fade aus").
##
## Alles gezeichnet statt als Bilddatei, je Region eigene Farben und Motive.
## Reine Optik: welche Felder gesperrt sind, sagt Grid.obstacles, hier steht
## nur, wie es aussieht. Der Zufall fuer Verzierungen haengt am Feld, nicht am
## Kampf -- derselbe Kampf sieht immer gleich aus.
##
##   Floor      Spielfeld (Nuancen je Feld, feine helle Fugen, Verzierungen),
##              darum ein dunklerer Randstreifen (APRON Felder breit) mit
##              Kante und Sockel nach vorn.
##   Obstacle   ein Hindernis als Iso-Block, je Art eigene Form.
##   Prop       Deko auf dem Randstreifen: Laternen, Container, Kabel ...
##   Lights     farbige Lichtflecken, additiv ueber dem Boden.

## Breite des Randstreifens in Feldern.
const APRON := 3
## Hoehe des Sockels unter der Vorderkante.
const PLINTH := 22.0

const TW := IsoView.TILE_W
const TH := IsoView.TILE_H

## Farben je Region: Boden, Randstreifen, Kante (Zierlinie), Lichtfarben.
const STYLE := {
	"city": {"floor": Color(0.19, 0.21, 0.26), "apron": Color(0.12, 0.13, 0.17),
		"trim": Color(0.25, 0.85, 1.0), "plinth": Color(0.09, 0.1, 0.13),
		"lights": [Color(1.0, 0.25, 0.7), Color(0.25, 0.85, 1.0)]},
	"green": {"floor": Color(0.2, 0.31, 0.18), "apron": Color(0.17, 0.2, 0.13),
		"trim": Color(0.55, 0.5, 0.38), "plinth": Color(0.2, 0.16, 0.11),
		"lights": [Color(0.85, 1.0, 0.45), Color(1.0, 0.85, 0.45)]},
	"plant7": {"floor": Color(0.22, 0.24, 0.27), "apron": Color(0.14, 0.14, 0.15),
		"trim": Color(1.0, 0.72, 0.2), "plinth": Color(0.1, 0.1, 0.11),
		"lights": [Color(1.0, 0.55, 0.2), Color(1.0, 0.8, 0.4)]},
}


static func style(region_id: String) -> Dictionary:
	return STYLE.get(region_id, STYLE["city"])


## Punkt auf einem Feld: u, v von -0,5 bis 0,5 entlang der Gitterachsen.
static func at(tile: Vector2i, u: float, v: float) -> Vector2:
	return IsoView.map_to_local(tile) + Vector2((u - v) * TW * 0.5, (u + v) * TH * 0.5)


## Ein flacher Kreis auf dem Boden (im Bild eine Ellipse).
static func floor_disc(tile: Vector2i, cu: float, cv: float, r: float, points := 14) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points:
		var a := TAU * float(i) / float(points)
		out.append(at(tile, cu + cos(a) * r, cv + sin(a) * r))
	return out


static func tile_rng(tile: Vector2i, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([tile.x, tile.y, salt])
	return rng


static func shade(color: Color, amount: float) -> Color:
	return color.lightened(amount) if amount > 0.0 else color.darkened(-amount)


# ---------------------------------------------------------------------------
# Boden
# ---------------------------------------------------------------------------

class Floor extends Node2D:
	var grid: Grid
	var region_id := "city"

	func _ready() -> void:
		z_index = -60

	func _draw() -> void:
		var s := ArenaPainter.style(region_id)
		var w := grid.width
		var h := grid.height
		var a := ArenaPainter.APRON
		# Randstreifen und Sockel zuerst -- von hinten nach vorn.
		for y in range(-a, h + a):
			for x in range(-a, w + a):
				var tile := Vector2i(x, y)
				if grid.in_bounds(tile):
					continue
				var rng := ArenaPainter.tile_rng(tile, 3)
				var color: Color = ArenaPainter.shade(s["apron"], rng.randf_range(-0.05, 0.05))
				draw_colored_polygon(IsoView.tile_corners(tile), color)
		_plinth(s, w, h, a)
		for tile in grid.all_tiles():
			_tile(tile, s)
		# Feine helle Fugen statt der harten schwarzen Umrisse.
		var seam := Color(1, 1, 1, 0.07)
		for tile in grid.all_tiles():
			var c := IsoView.tile_corners(tile)
			draw_line(c[0], c[1], seam, 1.0)
			draw_line(c[0], c[3], seam, 1.0)
		_border(s, w, h)

	func _tile(tile: Vector2i, s: Dictionary) -> void:
		var rng := ArenaPainter.tile_rng(tile, 1)
		var base: Color = s["floor"]
		draw_colored_polygon(IsoView.tile_corners(tile),
			ArenaPainter.shade(base, rng.randf_range(-0.06, 0.06)))
		var roll := rng.randf()
		match region_id:
			"green": _green_decal(tile, rng, roll)
			"plant7": _plant_decal(tile, rng, roll)
			_: _city_decal(tile, rng, roll)

	func _city_decal(tile: Vector2i, rng: RandomNumberGenerator, roll: float) -> void:
		# Mittelstreifen quer ueber das Feld, Risse, Pfuetzen, Gullis.
		if (tile.x + tile.y) == grid.width - 1 and tile.x % 2 == 0:
			draw_colored_polygon(PackedVector2Array([
				ArenaPainter.at(tile, -0.32, 0.27), ArenaPainter.at(tile, 0.27, -0.32),
				ArenaPainter.at(tile, 0.32, -0.27), ArenaPainter.at(tile, -0.27, 0.32)]),
				Color(0.95, 0.8, 0.3, 0.45))
		if roll < 0.14:
			var p := ArenaPainter.at(tile, rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
			var pts := PackedVector2Array([p])
			for i in 4:
				p += Vector2(rng.randf_range(-9, 9), rng.randf_range(-5, 5))
				pts.append(p)
			draw_polyline(pts, Color(0, 0, 0, 0.35), 1.2)
		elif roll < 0.22:
			var cu := rng.randf_range(-0.15, 0.15)
			var cv := rng.randf_range(-0.15, 0.15)
			draw_colored_polygon(ArenaPainter.floor_disc(tile, cu, cv, rng.randf_range(0.15, 0.28)),
				Color(0.25, 0.4, 0.7, 0.28))
			draw_line(ArenaPainter.at(tile, cu - 0.08, cv), ArenaPainter.at(tile, cu + 0.1, cv),
				Color(1.0, 0.3, 0.75, 0.5), 1.5)
		elif roll < 0.25:
			draw_colored_polygon(ArenaPainter.floor_disc(tile, 0, 0, 0.2), Color(0.08, 0.09, 0.11))
			draw_polyline(ArenaPainter.floor_disc(tile, 0, 0, 0.2), Color(0.4, 0.42, 0.48, 0.6), 1.0)

	func _green_decal(tile: Vector2i, rng: RandomNumberGenerator, roll: float) -> void:
		# Grasbueschel, Erdflecken, Steine, Blueten.
		var tufts := rng.randi_range(0, 3)
		for i in tufts:
			var base := ArenaPainter.at(tile, rng.randf_range(-0.35, 0.35), rng.randf_range(-0.35, 0.35))
			var green := Color(0.35, 0.58, 0.26, 0.9)
			for k in 3:
				draw_line(base, base + Vector2(float(k - 1) * 2.5, -5.0 - rng.randf() * 3.0), green, 1.2)
		if roll < 0.1:
			draw_colored_polygon(ArenaPainter.floor_disc(tile, rng.randf_range(-0.1, 0.1),
				rng.randf_range(-0.1, 0.1), rng.randf_range(0.18, 0.3)), Color(0.33, 0.25, 0.15, 0.5))
		elif roll < 0.18:
			var cu := rng.randf_range(-0.2, 0.2)
			var cv := rng.randf_range(-0.2, 0.2)
			draw_colored_polygon(ArenaPainter.floor_disc(tile, cu, cv, 0.09, 8), Color(0.5, 0.5, 0.47))
			draw_colored_polygon(ArenaPainter.floor_disc(tile, cu - 0.02, cv - 0.02, 0.05, 8),
				Color(0.62, 0.62, 0.58))
		elif roll < 0.26:
			for i in 3:
				draw_circle(ArenaPainter.at(tile, rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)),
					1.6, Color(1.0, 0.85, 0.3) if i % 2 == 0 else Color(0.95, 0.95, 1.0))

	func _plant_decal(tile: Vector2i, rng: RandomNumberGenerator, roll: float) -> void:
		# Gitterrost auf jedem zweiten Feld, Rost, Oel, Warnstreifen.
		if (tile.x + tile.y) % 2 == 0:
			for k in 5:
				var u := -0.36 + float(k) * 0.18
				draw_line(ArenaPainter.at(tile, u, -0.4), ArenaPainter.at(tile, u, 0.4),
					Color(0, 0, 0, 0.28), 1.0)
		if roll < 0.12:
			draw_colored_polygon(ArenaPainter.floor_disc(tile, rng.randf_range(-0.15, 0.15),
				rng.randf_range(-0.15, 0.15), rng.randf_range(0.12, 0.26)), Color(0.55, 0.28, 0.12, 0.4))
		elif roll < 0.18:
			var cu := rng.randf_range(-0.15, 0.15)
			var cv := rng.randf_range(-0.15, 0.15)
			draw_colored_polygon(ArenaPainter.floor_disc(tile, cu, cv, 0.22), Color(0.02, 0.02, 0.03, 0.6))
			draw_line(ArenaPainter.at(tile, cu - 0.1, cv + 0.05), ArenaPainter.at(tile, cu + 0.1, cv - 0.02),
				Color(0.6, 0.3, 0.9, 0.45), 1.2)
		elif roll < 0.22:
			for k in 4:
				var u := -0.4 + float(k) * 0.2
				draw_colored_polygon(PackedVector2Array([
					ArenaPainter.at(tile, u, -0.12), ArenaPainter.at(tile, u + 0.1, -0.12),
					ArenaPainter.at(tile, u + 0.1, 0.12), ArenaPainter.at(tile, u, 0.12)]),
					Color(1.0, 0.75, 0.15, 0.55) if k % 2 == 0 else Color(0.05, 0.05, 0.05, 0.55))

	## Der Sockel unter den beiden Vorderkanten des Randstreifens.
	func _plinth(s: Dictionary, w: int, h: int, a: int) -> void:
		var down := Vector2(0, ArenaPainter.PLINTH)
		var base: Color = s["plinth"]
		for y in range(-a, h + a):
			var tile := Vector2i(w + a - 1, y)
			var c := IsoView.tile_corners(tile)
			draw_colored_polygon(PackedVector2Array([c[1], c[2], c[2] + down, c[1] + down]),
				ArenaPainter.shade(base, -0.2))
		for x in range(-a, w + a):
			var tile := Vector2i(x, h + a - 1)
			var c := IsoView.tile_corners(tile)
			draw_colored_polygon(PackedVector2Array([c[3], c[2], c[2] + down, c[3] + down]), base)

	## Die Zierlinie um das Spielfeld -- zeigt, wo gekaempft wird.
	func _border(s: Dictionary, w: int, h: int) -> void:
		var top := IsoView.tile_corners(Vector2i(0, 0))[0]
		var right := IsoView.tile_corners(Vector2i(w - 1, 0))[1]
		var bottom := IsoView.tile_corners(Vector2i(w - 1, h - 1))[2]
		var left := IsoView.tile_corners(Vector2i(0, h - 1))[3]
		var ring := PackedVector2Array([top, right, bottom, left, top])
		var trim: Color = s["trim"]
		draw_polyline(ring, Color(trim, 0.18), 7.0)
		draw_polyline(ring, Color(trim, 0.85), 2.0)


# ---------------------------------------------------------------------------
# Hindernisse
# ---------------------------------------------------------------------------

## Ein Hindernis auf einem Feld. Sortiert sich wie eine Einheit (Tiefe des
## Feldes), damit es DROMEs dahinter verdeckt und die davor nicht.
class Obstacle extends Node2D:
	var tile := Vector2i.ZERO
	var kind := "block"

	func _draw() -> void:
		var rng := ArenaPainter.tile_rng(tile, 7)
		match kind:
			"container":
				_box(0.44, 38.0, Color(0.2, 0.3, 0.45), rng)
				_ribs(0.44, 38.0, 5)
				_glow_edge(0.44, 38.0, Color(1.0, 0.25, 0.7))
			"crate":
				_box(0.4, 30.0, Color(0.5, 0.36, 0.2), rng)
				_straps(0.4, 30.0)
			"barrier":
				_box(0.46, 20.0, Color(0.55, 0.55, 0.55), rng)
				_stripes(0.46, 20.0)
			"ruin":
				_box(0.44, 30.0, Color(0.46, 0.45, 0.41), rng)
				_box(0.22, 46.0, Color(0.44, 0.43, 0.4), rng, Vector2(-0.18, -0.1))
				_moss(0.44, 30.0, rng)
			"rock":
				_rock(rng)
			"tank":
				_tank(rng)
			"pipes":
				_pipes()
			_:
				_box(0.42, 28.0, Color(0.4, 0.42, 0.46), rng)

	func _foot(r: float, off := Vector2.ZERO) -> PackedVector2Array:
		return PackedVector2Array([
			ArenaPainter.at(tile, off.x, off.y - r) - position,
			ArenaPainter.at(tile, off.x + r, off.y) - position,
			ArenaPainter.at(tile, off.x, off.y + r) - position,
			ArenaPainter.at(tile, off.x - r, off.y) - position])

	## Iso-Quader: Oberseite hell, linke Flanke mittel, rechte dunkel -- wie
	## die Bauteile der DROMEs. Footprint als Raute mit Halbkante ``r``.
	## at(tile, u, v): u Richtung rechts unten, v Richtung links unten.
	func _box(r: float, height: float, color: Color, _rng: RandomNumberGenerator,
			off := Vector2.ZERO) -> void:
		var f := _foot(r, off)   # 0 oben, 1 rechts, 2 unten, 3 links (im Bild)
		var up := Vector2(0, -height)
		# Schatten auf dem Boden
		draw_colored_polygon(PackedVector2Array([f[1], f[2] + Vector2(6, 2), f[3]]), Color(0, 0, 0, 0.25))
		draw_colored_polygon(PackedVector2Array([f[3], f[2], f[2] + up, f[3] + up]), color)
		draw_colored_polygon(PackedVector2Array([f[2], f[1], f[1] + up, f[2] + up]),
			ArenaPainter.shade(color, -0.3))
		draw_colored_polygon(PackedVector2Array([f[0] + up, f[1] + up, f[2] + up, f[3] + up]),
			ArenaPainter.shade(color, 0.18))
		var line := Color(0, 0, 0, 0.55)
		draw_polyline(PackedVector2Array([f[3], f[2], f[1], f[1] + up, f[0] + up, f[3] + up, f[3]]), line, 1.0)
		draw_line(f[2], f[2] + up, line, 1.0)
		draw_polyline(PackedVector2Array([f[3] + up, f[2] + up, f[1] + up]), line, 1.0)

	func _ribs(r: float, height: float, count: int) -> void:
		var f := _foot(r)
		for k in range(1, count):
			var t := float(k) / float(count)
			for pair in [[f[3], f[2]], [f[2], f[1]]]:
				var p: Vector2 = pair[0].lerp(pair[1], t)
				draw_line(p + Vector2(0, -2), p + Vector2(0, -height + 2), Color(0, 0, 0, 0.25), 1.0)

	func _glow_edge(r: float, height: float, color: Color) -> void:
		var f := _foot(r)
		var y := Vector2(0, -height * 0.72)
		draw_line(f[3] + y, f[2] + y, Color(color, 0.3), 5.0)
		draw_line(f[3] + y, f[2] + y, color, 1.6)
		draw_line(f[2] + y, f[1] + y, Color(color, 0.2), 5.0)
		draw_line(f[2] + y, f[1] + y, ArenaPainter.shade(color, -0.2), 1.6)

	func _straps(r: float, height: float) -> void:
		var f := _foot(r)
		var up := Vector2(0, -height)
		var strap := Color(0.25, 0.17, 0.08)
		draw_line(f[3], f[2] + up, strap, 2.0)
		draw_line(f[2], f[3] + up, strap, 2.0)
		draw_line(f[2], f[1] + up, strap, 2.0)
		draw_line(f[1], f[2] + up, strap, 2.0)

	func _stripes(r: float, height: float) -> void:
		var f := _foot(r)
		var up := Vector2(0, -height)
		for pair in [[f[3], f[2]], [f[2], f[1]]]:
			for k in 6:
				if k % 2 == 1:
					continue
				var a: Vector2 = pair[0].lerp(pair[1], float(k) / 6.0)
				var b: Vector2 = pair[0].lerp(pair[1], float(k + 1) / 6.0)
				draw_colored_polygon(PackedVector2Array([a + up * 0.3, b + up * 0.3, b + up * 0.75,
					a + up * 0.75]), Color(1.0, 0.78, 0.15))

	func _moss(r: float, height: float, rng: RandomNumberGenerator) -> void:
		var f := _foot(r)
		var up := Vector2(0, -height)
		var moss := Color(0.3, 0.52, 0.22, 0.9)
		for i in 5:
			var p: Vector2 = (f[3] + up).lerp(f[1] + up, rng.randf()) + Vector2(0, rng.randf_range(-6, 6))
			draw_circle(p, rng.randf_range(2.5, 5.0), moss)
		for i in 3:
			var start: Vector2 = f[3].lerp(f[2], rng.randf_range(0.2, 0.9)) + up
			draw_line(start, start + Vector2(rng.randf_range(-3, 3), height * rng.randf_range(0.4, 0.8)),
				Color(0.25, 0.45, 0.18), 1.5)

	func _rock(rng: RandomNumberGenerator) -> void:
		var center := Vector2.ZERO
		var pts := PackedVector2Array()
		var top := PackedVector2Array()
		var height := rng.randf_range(16.0, 24.0)
		for i in 8:
			var a := TAU * float(i) / 8.0
			var rr := rng.randf_range(0.3, 0.42)
			var p := center + Vector2(cos(a) * rr * TW * 0.7, sin(a) * rr * TH * 0.7)
			pts.append(p)
			top.append(p * 0.7 + Vector2(0, -height))
		var stone := Color(0.42, 0.41, 0.38)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.25))
		# Flanken: je zwei Nachbarpunkte unten und oben.
		for i in 8:
			var j := (i + 1) % 8
			if pts[i].y + pts[j].y < 0.0:
				continue
			draw_colored_polygon(PackedVector2Array([pts[i], pts[j], top[j], top[i]]),
				ArenaPainter.shade(stone, -0.1 - 0.15 * float(pts[i].x + pts[j].x > 0.0)))
		draw_colored_polygon(top, ArenaPainter.shade(stone, 0.15))
		draw_circle(top[5].lerp(top[1], 0.5), 5.0, Color(0.32, 0.52, 0.24, 0.9))

	func _tank(rng: RandomNumberGenerator) -> void:
		var r := 0.42 * TW * 0.5
		var ry := r * TH / TW
		var height := 50.0
		var metal := Color(0.36, 0.4, 0.45)
		draw_colored_polygon(_ellipse(Vector2(4, 2), r, ry), Color(0, 0, 0, 0.25))
		draw_colored_polygon(PackedVector2Array([Vector2(-r, 0), Vector2(r, 0), Vector2(r, -height),
			Vector2(-r, -height)]), metal)
		draw_colored_polygon(_ellipse(Vector2.ZERO, r, ry, 0.0, PI), metal)
		draw_colored_polygon(PackedVector2Array([Vector2(r * 0.2, 0), Vector2(r, 0), Vector2(r, -height),
			Vector2(r * 0.2, -height)]), ArenaPainter.shade(metal, -0.3))
		draw_colored_polygon(_ellipse(Vector2(0, -height), r, ry), ArenaPainter.shade(metal, 0.2))
		draw_line(Vector2(-r, -height * 0.4), Vector2(r, -height * 0.4), Color(1.0, 0.55, 0.15), 4.0)
		var lamp := Vector2(0, -height - 3)
		draw_circle(lamp, 6.0, Color(1.0, 0.4, 0.15, 0.3))
		draw_circle(lamp, 2.5, Color(1.0, 0.6, 0.25))

	func _pipes() -> void:
		var metal := Color(0.45, 0.4, 0.34)
		for k in 3:
			var x := (float(k) - 1.0) * 14.0
			var y := (float(k) - 1.0) * -4.0
			var height := 44.0 - float(k) * 5.0
			draw_colored_polygon(PackedVector2Array([Vector2(x - 7, y), Vector2(x + 7, y),
				Vector2(x + 7, y - height), Vector2(x - 7, y - height)]), metal)
			draw_colored_polygon(PackedVector2Array([Vector2(x + 2, y), Vector2(x + 7, y),
				Vector2(x + 7, y - height), Vector2(x + 2, y - height)]), ArenaPainter.shade(metal, -0.3))
			draw_colored_polygon(_ellipse(Vector2(x, y - height), 7.0, 3.5), ArenaPainter.shade(metal, 0.25))
			draw_line(Vector2(x - 7, y - height * 0.6), Vector2(x + 7, y - height * 0.6),
				Color(0.65, 0.3, 0.12), 2.0)

	func _ellipse(c: Vector2, rx: float, ry: float, from := 0.0, to := TAU) -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in 17:
			var a := lerpf(from, to, float(i) / 16.0)
			out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		return out


# ---------------------------------------------------------------------------
# Deko auf dem Randstreifen
# ---------------------------------------------------------------------------

## Ein Stueck Deko ausserhalb des Spielfelds. Nutzt die Formen der Hindernisse
## und dazu Laternen (mit Lichtfleck, siehe Lights).
class Prop extends Node2D:
	var tile := Vector2i.ZERO
	var kind := "lamp"
	var light := Color.WHITE

	func _draw() -> void:
		if kind == "lamp":
			var height := 70.0
			draw_line(Vector2(0, 0), Vector2(0, -height), Color(0.15, 0.16, 0.2), 3.0)
			draw_line(Vector2(0, -height), Vector2(10, -height + 4), Color(0.15, 0.16, 0.2), 3.0)
			var head := Vector2(11, -height + 5)
			draw_circle(head, 10.0, Color(light, 0.18))
			draw_circle(head, 4.0, light.lightened(0.4))
			draw_colored_polygon(PackedVector2Array([head, head + Vector2(-10, height - 6),
				head + Vector2(22, height - 6)]), Color(light, 0.06))


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
				draw_set_transform(pos, 0.0, Vector2(1.0, TH / TW))
				draw_circle(Vector2.ZERO, r, Color(color, 0.05))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------------------
# Zusammenbau
# ---------------------------------------------------------------------------

## Baut alles in ``world`` ein. ``depth_of`` rechnet ein Feld in z_index um
## (wie bei den Einheiten). Gibt die angelegten Knoten zurueck.
static func build(world: Node2D, grid: Grid, depth_of: Callable) -> Array:
	var nodes: Array = []
	var region_id := str(grid.region.id) if grid.region != null else "city"
	var s := style(region_id)

	var floor := Floor.new()
	floor.grid = grid
	floor.region_id = region_id
	world.add_child(floor)
	nodes.append(floor)

	for tile in grid.obstacles:
		var block := Obstacle.new()
		block.tile = tile
		block.kind = str(grid.obstacles[tile])
		block.position = IsoView.map_to_local(tile)
		block.z_index = depth_of.call(tile)
		world.add_child(block)
		nodes.append(block)

	var lights := Lights.new()
	var colors: Array = s["lights"]
	# Deko: auf dem hinteren Randstreifen dichter, vorn nur an den Ecken --
	# hohe Deko vorn verdeckte das Spielfeld.
	var kinds: Array = Config.section("obstacles").get("kinds", {}).get(region_id, ["crate"])
	var spots: Array = []
	for i in range(1, grid.width, 4):
		spots.append([Vector2i(i, -2), "lamp" if (i / 4) % 2 == 0 else "deco"])
		spots.append([Vector2i(-2, i), "deco" if (i / 4) % 2 == 0 else "lamp"])
	spots.append([Vector2i(grid.width + 1, grid.height + 1), "lamp"])
	spots.append([Vector2i(grid.width + 1, -2), "lamp"])
	spots.append([Vector2i(-2, grid.height + 1), "lamp"])
	for index in spots.size():
		var tile: Vector2i = spots[index][0]
		var rng := tile_rng(tile, 11)
		var node: Node2D
		if spots[index][1] == "lamp":
			var lamp := Prop.new()
			lamp.light = colors[index % colors.size()]
			node = lamp
			lights.spots.append([IsoView.map_to_local(tile) + Vector2(11, 0), lamp.light, 90.0])
		else:
			var block := Obstacle.new()
			block.kind = str(kinds[rng.randi() % kinds.size()])
			node = block
		node.set("tile", tile)
		node.position = IsoView.map_to_local(tile)
		node.z_index = depth_of.call(tile)
		world.add_child(node)
		nodes.append(node)

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
