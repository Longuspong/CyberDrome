class_name IsoView
extends RefCounted

## Die EINZIGE Umrechnung zwischen Gitter- und Bildschirmkoordinaten.
##
## Die Spiellogik rechnet nie in Bildschirmkoordinaten, die Darstellung nie in
## Feldern. Genau hier treffen sich beide -- und nirgends sonst. Wer eine
## zweite Umrechnung anlegt, bekommt Bots, die neben ihrem Feld stehen, und
## einen Fehler, den man erst bei 400 Feldern als System erkennt.
##
## Die Zahlen stammen aus dem Generator: ``tools/build_sample_parts.py``
## projiziert jedes Bauteil mit 1,35 Bildpunkten je Einheit in ein 128x128-
## Bild, die Feldmitte liegt dort auf (64, 96). Bis 17. Nov. 2026 war das
## Feld eine Bodenraute von 76 x 54 px (Quadrat 40 x 40, diagonal gesehen).

## Hexfeld (seit 17. Nov. 2026). Gemessen in derselben Projektion wie die
## DROMEs (1,35 Bildpunkte je Generator-Einheit, Iso-Kamera 45 Grad); in der
## Tiefe staucht die Kamera auf cos 45. Ein Sechseck hat 22 Einheiten
## Eckradius, so gross wie die Platten aus dem 3D-Entwurf
## (docs/design/drome_entwurf/v10_hexboden.py). Seit 18. Nov. 2026 liegen die
## Sechsecke flach (Kante oben und unten, Spitze links und rechts): Spalten
## laufen senkrecht, ungerade Spalten ein halbes Feld tiefer (Grid "odd-q").
const HEX_R := 26.0
const PX_PER_UNIT := 1.35
const DEPTH_SQUASH := 0.70710678
## Abstand zweier Nachbarn quer im Bild (Mitte zu Mitte, sqrt(3) * R) -- die
## "Feldbreite" fuer Kamera, Zoom und Reichweiten.
const TILE_W := 1.7320508 * HEX_R * PX_PER_UNIT
## Hoehe eines Sechsecks im Bild (Kante zu Kante).
const TILE_H := 1.7320508 * HEX_R * PX_PER_UNIT * DEPTH_SQUASH
## Abstand zweier Spalten im Bild.
const COL_W := 1.5 * HEX_R * PX_PER_UNIT
## Abstand zweier Reihen (in einer Spalte) im Bild.
const ROW_H := 1.7320508 * HEX_R * PX_PER_UNIT * DEPTH_SQUASH

## Grosse aller Teil- und Tile-Bilder -- im ENTWURFSRAUM, nicht in Pixeln.
## Jedes SVG dieses Projekts zeichnet in ``viewBox="0 0 128 128"``.
const SPRITE_SIZE := 128

## Wo die Feldmitte innerhalb eines solchen Bildes liegt.
const SPRITE_ORIGIN := Vector2(64.0, 96.0)


## Rechnet einen Sprite auf den 128er Entwurfsraum zurueck.
##
## Godot rastert die SVGs feiner, als sie nominell sind (siehe
## tools/set_import_scale.py) -- sonst waere der DROME in der Werkstatt
## sichtbar verpixelt, weil dort 128 Pixel auf ueber 300 hochgezogen werden.
## Eine 512er Textur ist damit aber viermal so gross wie das Feld, auf dem sie
## stehen soll.
##
## Der Faktor wird an der Textur GEMESSEN und steht nirgends im Code. Damit
## bleiben alle Positionsrechnungen -- Bodenraute, Anker, Zeichenreihenfolge --
## im Entwurfsraum, und die Rasterung laesst sich aendern, ohne eine einzige
## Zeile hier anzufassen.
static func fit_sprite(sprite: Sprite2D) -> void:
	var texture := sprite.texture
	if texture == null or texture.get_width() <= 0:
		return
	var factor := float(SPRITE_SIZE) / float(texture.get_width())
	sprite.scale = Vector2(factor, factor)


## Feld -> Bildschirmposition der Feldmitte.
static func map_to_local(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) * COL_W, (float(cell.y) + 0.5 * float(cell.x & 1)) * ROW_H)


## Bildschirmposition -> Feld (das Sechseck, in dem der Punkt liegt).
static func local_to_map(pos: Vector2) -> Vector2i:
	var q := pos.x / COL_W
	var r := pos.y / ROW_H - q * 0.5
	# Wuerfelkoordinaten runden (q + r + s = 0).
	var s := -q - r
	var rq := roundf(q)
	var rr := roundf(r)
	var rs := roundf(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Grid.from_axial(Vector2i(int(rq), int(rr)))


## Wo ein 128x128-Sprite hin muss, damit seine Bodenraute auf diesem Feld
## liegt. Sprites laufen mit ``centered = false``; die Anker-Mathematik
## steckt bereits in der Grafik.
static func sprite_position(cell: Vector2i) -> Vector2:
	return map_to_local(cell) - SPRITE_ORIGIN


## Zeichentiefe eines Feldes. Was weiter hinten liegt, wird frueher gezeichnet.
##
## Y-Sortierung allein genuegt nicht: alle Sprites eines Feldes teilen sich
## dieselbe y-Position, und ein Betonpfeiler muss den DROME davor verdecken,
## aber den dahinter nicht. Auf dem flachen Hexfeld: halbe Reihen (ungerade
## Spalten liegen ein halbes Feld tiefer).
static func depth(cell: Vector2i) -> int:
	return 2 * cell.y + (cell.x & 1)


## Die sechs Ecken eines Feldes im Bild -- fuer Boden, Umrisse und
## Trefferpruefung. Reihenfolge: oben links, oben rechts, rechts, unten
## rechts, unten links, links. Kante i verbindet Ecke i und i + 1; ueber ihr
## liegt der Nachbar in Richtung EDGE_DIR[i] (Grid.AXIAL_DIRS): oben N,
## oben rechts NO, unten rechts SO, unten S, unten links SW, oben links NW.
const EDGE_DIR := [1, 0, 5, 4, 3, 2]

static func tile_corners(cell: Vector2i) -> PackedVector2Array:
	var center := map_to_local(cell)
	var out := PackedVector2Array()
	for angle in [120.0, 60.0, 0.0, -60.0, -120.0, 180.0]:
		var a := deg_to_rad(angle)
		out.append(center + Vector2(cos(a) * HEX_R * PX_PER_UNIT,
			-sin(a) * HEX_R * PX_PER_UNIT * DEPTH_SQUASH))
	return out


## Bildschirmmitte des Gitters -- damit die Kamera weiss, wohin.
static func grid_center(width: int, height: int) -> Vector2:
	return Vector2(float(width - 1) * 0.5 * COL_W, float(height - 1) * 0.5 * ROW_H)
