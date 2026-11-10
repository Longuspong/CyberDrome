class_name Terrain
extends RefCounted

## Regionen: wie das Kampffeld aussieht. Reine Optik -- seit dem Umbau zum
## Autobattler (Nov. 2026) hat das Feld kein Gelaende mehr, jede Region
## belegt nur noch ihren Boden.


class Region extends RefCounted:
	var id: StringName
	var display_name: String
	var floor_name: String = ""          ## "Asphalt", "Wiese" ...
	var floor_texture: String = ""
	## Die Fraktion des Gebiets und ihr Profil (MODULE_KONZEPT.md 9): wie
	## sich ihre Gegner zusammensetzen. Leer = frei gewuerfelt.
	var faction: Dictionary = {}

	static func from_meta(meta: Dictionary, base_dir: String) -> Region:
		var region := Region.new()
		region.id = StringName(meta.get("id", ""))
		region.display_name = meta.get("name", str(region.id))
		var floor: Dictionary = meta.get("floor", {})
		region.floor_name = floor.get("name", "")
		var svg: String = floor.get("svg", "")
		region.floor_texture = base_dir.path_join(svg) if svg != "" else ""
		region.faction = meta.get("faction", {})
		return region
