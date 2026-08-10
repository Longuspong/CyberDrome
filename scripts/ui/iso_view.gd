class_name IsoView
extends RefCounted

## Die EINZIGE Umrechnung zwischen Gitter- und Bildschirmkoordinaten.
##
## Die Spiellogik rechnet nie in Bildschirmkoordinaten, die Darstellung nie in
## Feldern. Genau hier treffen sich beide -- und nirgends sonst. Wer eine
## zweite Umrechnung anlegt, bekommt Bots, die neben ihrem Feld stehen, und
## einen Fehler, den man erst bei 400 Feldern als System erkennt.
##
## Die Zahlen stammen nicht aus diesem Projekt, sondern aus der Werkstatt:
## ``tools/build_sample_parts.py`` projiziert jedes Bauteil auf eine Bodenraute
## von 76 x 54 px um (64, 96) in einem 128x128-Bild. Terrain-Tiles benutzen
## dieselbe Projektion. Beide Werte hier zu aendern, ohne sie dort zu aendern,
## bricht die Deckung.
##
## Anmerkung zum Entwurfsdokument: dort steht als Kachelmass 128 x 64, also
## 2:1. Der Bestand ist sqrt(2):1 -- das faellt aus der 45-Grad-Kamera des
## Renderers und laesst sich nicht unabhaengig davon waehlen. Mit 2:1 stuenden
## die Bots neben ihren Feldern.

## Bodenraute in Pixeln. Verhaeltnis sqrt(2):1.
const TILE_W := 76.0
const TILE_H := 54.0

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


## Setzt den Drehpunkt eines Sprites auf die Feldmitte. Nur fuer die Teile, die
## sich drehen -- der Drift-Pfeil. ``offset`` zaehlt in Texturpixeln und muss
## deshalb durch denselben Faktor, den fit_sprite() gesetzt hat.
static func pivot_on_tile_center(sprite: Sprite2D) -> void:
	var factor: float = sprite.scale.x if sprite.scale.x != 0.0 else 1.0
	sprite.offset = -SPRITE_ORIGIN / factor
	sprite.position += SPRITE_ORIGIN


## Feld -> Bildschirmposition der Feldmitte.
static func map_to_local(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * TILE_W * 0.5,
		(cell.x + cell.y) * TILE_H * 0.5)


## Bildschirmposition -> Feld.
static func local_to_map(pos: Vector2) -> Vector2i:
	var fx := pos.x / TILE_W + pos.y / TILE_H
	var fy := pos.y / TILE_H - pos.x / TILE_W
	return Vector2i(int(floor(fx + 0.5)), int(floor(fy + 0.5)))


## Wo ein 128x128-Sprite hin muss, damit seine Bodenraute auf diesem Feld
## liegt. Sprites laufen mit ``centered = false``; die Anker-Mathematik
## steckt bereits in der Grafik.
static func sprite_position(cell: Vector2i) -> Vector2:
	return map_to_local(cell) - SPRITE_ORIGIN


## Zeichentiefe eines Feldes. Was weiter hinten liegt, wird frueher gezeichnet.
##
## Y-Sortierung allein genuegt nicht: alle Sprites eines Feldes teilen sich
## dieselbe y-Position, und ein Betonpfeiler muss den DROME davor verdecken,
## aber den dahinter nicht.
static func depth(cell: Vector2i) -> int:
	return cell.x + cell.y


## Die vier Eckpunkte der Bodenraute eines Feldes -- fuer Umrisse und
## Trefferpruefung beim Hovern.
static func tile_corners(cell: Vector2i) -> PackedVector2Array:
	var center := map_to_local(cell)
	return PackedVector2Array([
		center + Vector2(0.0, -TILE_H * 0.5),
		center + Vector2(TILE_W * 0.5, 0.0),
		center + Vector2(0.0, TILE_H * 0.5),
		center + Vector2(-TILE_W * 0.5, 0.0),
	])


## Bildschirmmitte des Gitters -- damit die Kamera weiss, wohin.
static func grid_center(width: int, height: int) -> Vector2:
	return map_to_local(Vector2i(width - 1, height - 1)) * 0.5
