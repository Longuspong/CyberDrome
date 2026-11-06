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

	static func from_meta(meta: Dictionary, base_dir: String) -> Region:
		var region := Region.new()
		region.id = StringName(meta.get("id", ""))
		region.display_name = meta.get("name", str(region.id))
		var floor: Dictionary = meta.get("floor", {})
		region.floor_name = floor.get("name", "")
		var svg: String = floor.get("svg", "")
		region.floor_texture = base_dir.path_join(svg) if svg != "" else ""
		return region
