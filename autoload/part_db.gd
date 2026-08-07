extends Node

## Laedt die Bauteil-Bibliothek beim Start.
##
## Quelle ist assets/parts/ -- der von tools/bake_godot_assets.py gebackene
## Satz. Er traegt dieselben Metadaten wie parts/, nur mit aufgeloesten Farben:
## Godots SVG-Rasterizer kennt keine CSS-Variablen und wuerde den Quellbaum
## schwarz rastern.
##
## Es gibt keine zweite Bauteil-Definition irgendwo. Wer einen Wert aendern
## will, aendert die Tabelle STATS in tools/build_sample_parts.py und laesst
## Generator und Bake-Schritt laufen.

const PARTS_ROOT := "res://assets/parts"

## part_id -> PartData
var parts: Dictionary = {}

## set_id -> { id, name, description, palette }
var sets: Dictionary = {}

var _by_type: Dictionary = {}


## Bewusst _init() und nicht _ready(): das Einlesen braucht nur DirAccess und
## FileAccess, keinen Szenenbaum. Laege es in _ready(), waere die Bibliothek
## fuer alles leer, was vor dem ersten Frame laeuft -- der Testlauf zum
## Beispiel, der dann gruen durchliefe, ohne irgendetwas geprueft zu haben.
func _init() -> void:
	load_library()


func load_library() -> void:
	parts.clear()
	sets.clear()
	_by_type.clear()

	var root := DirAccess.open(PARTS_ROOT)
	if root == null:
		push_error("PartDB: %s nicht lesbar. Laeuft tools/bake_godot_assets.py?"
			% PARTS_ROOT)
		return

	for set_id in root.get_directories():
		_load_set(PARTS_ROOT.path_join(set_id), set_id)

	for part in parts.values():
		_by_type.get_or_add(part.type, []).append(part)
	for bucket in _by_type.values():
		bucket.sort_custom(func(a, b): return a.code < b.code)

	print("[PartDB] %d Teile aus %d Bausaetzen geladen: %s"
		% [parts.size(), sets.size(), ", ".join(sets.keys())])
	for type in [PartData.Type.BODY, PartData.Type.CORE, PartData.Type.FEET,
			PartData.Type.HEAD, PartData.Type.EQUIPMENT]:
		var names: Array[String] = []
		for part in of_type(type):
			names.append("%s %s" % [part.code, part.id])
		print("  %-10s %s" % [_type_label(type), ", ".join(names)])


func _load_set(dir_path: String, set_id: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var meta = _read_json(dir_path.path_join(file_name))
		if meta == null:
			continue
		if file_name == "set.json":
			sets[set_id] = meta
			continue
		var part_id := StringName(meta.get("id", ""))
		if part_id == &"":
			continue
		if not parts.has(part_id):
			parts[part_id] = PartData.from_meta(meta)
		parts[part_id].add_view(meta, dir_path)


func _read_json(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("PartDB: %s nicht lesbar" % path)
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not parsed is Dictionary:
		push_error("PartDB: %s ist kein JSON-Objekt" % path)
		return null
	return parsed


func get_part(part_id: StringName) -> PartData:
	return parts.get(part_id)


func has_part(part_id: StringName) -> bool:
	return parts.has(part_id)


func of_type(type: PartData.Type) -> Array:
	return _by_type.get(type, [])


## Alle Ausruestungsteile, die in diesen Slot dieses Chassis duerfen.
func equipment_for(body: PartData, slot: String) -> Array:
	var result: Array = []
	for part in of_type(PartData.Type.EQUIPMENT):
		if body.accepts(part, slot):
			result.append(part)
	return result


func _type_label(type: PartData.Type) -> String:
	match type:
		PartData.Type.BODY: return "Chassis"
		PartData.Type.CORE: return "Kern"
		PartData.Type.FEET: return "Antrieb"
		PartData.Type.HEAD: return "Sensorik"
		_: return "Ausruest."
