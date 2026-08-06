class_name Terrain
extends RefCounted

## Terrainklassen und ihre regionsabhaengige Ausprägung.
##
## Die Trennung ist verbindlich: die KLASSE bestimmt die Regeln, der TYP nur
## Name und Optik. Dieselbe Klasse sieht in der City anders aus als in der
## Gruenzone, verhaelt sich aber identisch. Spiellogik fragt NIEMALS den Typ
## ab, immer nur die Klasse -- sonst ist eine neue Region kein Datensatz mehr,
## sondern ein Codeeingriff.

## Fuenf Klassen, aufgespannt von zwei unabhaengigen Achsen: sperrt Fuesse,
## sperrt Sicht.
##
##                 Sicht frei        Sicht gesperrt
##   Fuesse frei   NORMAL / DRIFT    HAZE
##   Fuesse dicht  STEP              BLOCK
##
## HAZE war das fehlende Feld dieser Matrix. Mit ihm ist jede Kombination
## abgedeckt, und die Klassen erklaeren sich gegenseitig, statt beliebig zu
## wirken.
enum TClass { NORMAL, STEP, BLOCK, DRIFT, HAZE }

const CLASS_NAMES := {
	"normal": TClass.NORMAL,
	"step": TClass.STEP,
	"block": TClass.BLOCK,
	"drift": TClass.DRIFT,
	"haze": TClass.HAZE,
}

const CLASS_KEYS := ["normal", "step", "block", "drift", "haze"]

## Nur fuer Anzeige und Protokoll. Keine Regel haengt daran.
const CLASS_LABELS := {
	TClass.NORMAL: "Normal",
	TClass.STEP: "Stufe",
	TClass.BLOCK: "Block",
	TClass.DRIFT: "Drift-Zone",
	TClass.HAZE: "Haze-Feld",
}

## Blockiert die Klasse die Sichtlinie?
const BLOCKS_SIGHT := {
	TClass.NORMAL: false,
	TClass.STEP: false,     # Mauer fuer die Fuesse, kein Hindernis fuer Waffen
	TClass.BLOCK: true,
	TClass.DRIFT: false,
	TClass.HAZE: true,      # genau umgekehrt: kein Hindernis fuer die Fuesse
}


static func class_from_string(text: String) -> TClass:
	return CLASS_NAMES.get(text, TClass.NORMAL)


static func class_label(terrain_class: TClass) -> String:
	return CLASS_LABELS.get(terrain_class, "?")


class TerrainType extends RefCounted:
	## Die konkrete Auspraegung einer Klasse in einer Region.
	var id: StringName
	var display_name: String        ## "Asphalt", "Eisplatte", "Sumpf" ...
	var terrain_class: TClass = TClass.NORMAL
	var texture_path: String = ""

	## Nur DRIFT. ZERO = ungerichtet (der DROME gleitet in seiner eigenen
	## Laufrichtung weiter), sonst festes Foerderband. Beide Varianten laufen
	## durch denselben Code -- der Unterschied ist ein Vector2i.
	var flow_direction: Vector2i = Vector2i.ZERO

	static func from_meta(meta: Dictionary, base_dir: String) -> TerrainType:
		var type := TerrainType.new()
		type.id = StringName(meta.get("id", ""))
		type.display_name = meta.get("name", str(type.id))
		type.terrain_class = Terrain.class_from_string(meta.get("class", "normal"))
		var svg: String = meta.get("svg", "")
		type.texture_path = base_dir.path_join(svg) if svg != "" else ""
		var flow = meta.get("flow_direction", [0, 0])
		if flow is Array and flow.size() == 2:
			type.flow_direction = Vector2i(flow[0], flow[1])
		return type


class Region extends RefCounted:
	## Eine Region belegt alle fuenf Klassen. Neue Region = ein Datensatz plus
	## fuenf Tiles, kein Codeeingriff.
	var id: StringName
	var display_name: String
	var types: Dictionary = {}      ## TClass -> TerrainType

	func type_for(terrain_class: TClass) -> TerrainType:
		return types.get(terrain_class)

	## Ist die Drift dieser Region gerichtet (Foerderband) oder ungerichtet?
	func drift_is_directed() -> bool:
		var drift: TerrainType = types.get(TClass.DRIFT)
		return drift != null and drift.flow_direction != Vector2i.ZERO

	static func from_meta(meta: Dictionary, base_dir: String) -> Region:
		var region := Region.new()
		region.id = StringName(meta.get("id", ""))
		region.display_name = meta.get("name", str(region.id))
		for key in Terrain.CLASS_KEYS:
			var entry = meta.get(key)
			if entry == null:
				continue
			var type := TerrainType.from_meta(entry, base_dir)
			type.terrain_class = Terrain.class_from_string(key)
			region.types[type.terrain_class] = type
		return region

	func is_complete() -> bool:
		for key in Terrain.CLASS_KEYS:
			if not types.has(Terrain.class_from_string(key)):
				return false
		return true
