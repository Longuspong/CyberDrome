extends Node

## Laedt die Regionen aus data/regions.json.
##
## Eine Region ist reine Optik: Name, Boden und die Kulisse dahinter.

const PATH := "res://data/regions.json"
const TILE_DIR := "res://assets/terrain"

## region_id -> Terrain.Region
var regions: Dictionary = {}

## Tiles, die noch fehlen. Wird beim Laden gefuellt und im Kampf als
## Magenta-Fehlfeld dargestellt -- sichtbar, nicht stillschweigend ersetzt.
var missing_tiles: Array[String] = []

## Gewichte der Fraktions-Profile (data/regions.json -> weapon_weight ...).
var _weights: Dictionary = {}


func _init() -> void:
	load_regions()


func load_regions() -> void:
	regions.clear()
	missing_tiles.clear()

	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("TerrainDB: %s nicht lesbar" % PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("TerrainDB: %s ist kein JSON-Objekt" % PATH)
		return

	for key in ["weapon_weight", "module_weight"]:
		if parsed.has(key):
			_weights[key] = float(parsed[key])
	for meta in parsed.get("regions", []):
		var region_id: String = meta.get("id", "")
		var region := Terrain.Region.from_meta(meta, TILE_DIR.path_join(region_id))
		regions[region.id] = region
		if region.floor_texture == "" or not ResourceLoader.exists(region.floor_texture):
			missing_tiles.append("%s (Boden)" % region_id)

	print("[TerrainDB] %d Regionen geladen: %s"
		% [regions.size(), ", ".join(region_names())])
	if not missing_tiles.is_empty():
		print("[TerrainDB] %d Tiles fehlen und werden magenta dargestellt:"
			% missing_tiles.size())
		for entry in missing_tiles:
			print("    %s" % entry)


func region_names() -> Array[String]:
	var names: Array[String] = []
	for region in regions.values():
		names.append(region.display_name)
	return names


func get_region(region_id: StringName) -> Terrain.Region:
	return regions.get(region_id)


## Ein Gewicht der Fraktions-Profile (weapon_weight, module_weight).
func weight(key: String, fallback: float) -> float:
	return float(_weights.get(key, fallback))


## Zieht eine Region aus dem Seed. Derselbe Seed ergibt dieselbe Region.
##
## ### Warum hier ausdruecklich nach TEXT sortiert wird
##
## Hier stand ``keys.sort()`` mit dem Kommentar, das sei stabil. Das ist es
## nicht: die Schluessel sind ``StringName``, und ``Array.sort()`` vergleicht
## die nicht alphabetisch, sondern nach ihrer internen Adresse. Die haengt
## davon ab, in welcher Reihenfolge die Namen im Prozess zum ersten Mal
## auftauchen -- also von Ladereihenfolge und Engine-Version, nicht vom Seed.
##
## Nachgemessen beim Umstieg von Godot 4.3 auf 4.7: derselbe Seed, dieselbe
## Zufallsfolge (``randi``, ``randf`` und ``randi_range`` liefern bitgleiche
## Werte), aber eine andere Karte -- unter 4.3 kam ``city, green, plant7``
## heraus, unter 4.7 ``green, city, plant7``. Damit war "derselbe Seed ergibt
## denselben Kampf" ueber Versionsgrenzen hinweg gebrochen, und zwar
## stillschweigend: die Reproduzierbarkeits-Tests vergleichen zwei Laeufe
## DERSELBEN Engine und blieben deshalb gruen.
##
## ``str()`` vor dem Vergleich macht daraus eine Sortierung nach Inhalt. Unter
## 4.3 aendert das nichts -- dort waren die Schluessel ohnehin ``String`` und
## damit alphabetisch --, bestehende Seeds behalten also ihre Bedeutung.
func pick_region(rng: RandomNumberGenerator) -> Terrain.Region:
	if regions.is_empty():
		return null
	var keys := regions.keys()
	keys.sort_custom(func(a, b): return str(a) < str(b))
	return regions[keys[rng.randi() % keys.size()]]
