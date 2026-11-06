class_name MapGenerator
extends RefCounted

## Erzeugt das Kampffeld: ein freies Gitter mit dem Boden der Region.
##
## Seit dem Umbau zum Autobattler (Nov. 2026) gibt es kein Gelaende mehr --
## keine Stufen, Pfeiler, Oelspuren oder Nebel. Das Gitter bleibt, weil
## Reichweite, Bewegung und Aufstellung darauf rechnen und die Iso-Optik
## daran haengt.


## Ein leeres Feld in der Groesse aus der Konfiguration.
static func generate(region: Terrain.Region) -> Grid:
	var grid := Grid.new(Config.get_int("grid_width", Grid.DEFAULT_SIZE),
		Config.get_int("grid_height", Grid.DEFAULT_SIZE))
	grid.region = region
	return grid


## Spieler unten links, Gegner oben rechts.
static func deployment_zone(grid: Grid, is_player: bool) -> Array[Vector2i]:
	var deploy := Config.section("deployment")
	var rows := int(deploy.get("rows", 2))
	var columns := int(deploy.get("columns", 6))
	# Abstand der Zonen von den Ecken (Nov. 2026). Im Autobattler ist
	# Anlaufzeit Zeit ohne Inhalt: in der Ecke standen sich die Squads rund
	# 22 Felder entfernt gegenueber, und langsame DROMEs kamen erst an, als
	# der Kampf halb vorbei war. Mit 5 Feldern Einzug sind es etwa 8 bis 12.
	var inset := clampi(int(deploy.get("inset", 0)), 0,
		maxi(0, mini(grid.width - columns, grid.height - rows) / 2))
	var tiles: Array[Vector2i] = []
	for row in rows:
		for column in columns:
			if is_player:
				tiles.append(Vector2i(inset + column, grid.height - 1 - inset - row))
			else:
				tiles.append(Vector2i(grid.width - 1 - inset - column, inset + row))

	# Aufgestellt wird in dieser Reihenfolge -- deshalb steht sie hier und
	# nicht dem Zufall ueberlassen.
	#
	# Isometrisch ist x+y die Bildschirmtiefe: was hoehere Summe hat, liegt
	# weiter unten. Ohne diese Sortierung faengt jede Zone an ihrer Ecke an,
	# und beide Squads landen auf den beiden SEITLICHEN Spitzen der Raute --
	# auf gleicher Hoehe, links und rechts. Der Entwurf will "unten links"
	# gegen "oben rechts", und genau das faellt heraus, wenn der Spieler von
	# der tiefsten Kachel seiner Zone aus aufstellt und der Gegner von der
	# hoechsten seiner.
	tiles.sort_custom(func(a: Vector2i, b: Vector2i):
		var da := a.x + a.y
		var db := b.x + b.y
		if da != db:
			return da > db if is_player else da < db
		# Auch der Gleichstand wird gespiegelt: die Gegnerzone ist die um die
		# Kartenmitte gedrehte Spielerzone, also laeuft x dort andersherum.
		# Mit derselben Richtung stand der zweite Gegner eine Reihe weiter vorn
		# als sein Gegenstueck -- im Echtzeit-Kampf gewann die Spielerseite
		# dadurch 33 von 40 Spiegelkaempfen.
		return a.x < b.x if is_player else a.x > b.x)
	return tiles
