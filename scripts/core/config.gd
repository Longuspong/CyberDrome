class_name Config
extends RefCounted

## Zugriff auf data/config.json. Eine Stelle, an der Stellschrauben stehen.
##
## Wird als statischer Zwischenspeicher gehalten, damit auch Klassen ohne
## Szenenbaum (Grid, TickBus, Generatoren) darauf zugreifen koennen, ohne sich
## einen Autoload durchreichen zu lassen.

const PATH := "res://data/config.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_load()
	return _data


static func _load() -> void:
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("Config: %s nicht lesbar" % PATH)
		_data = {}
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_data = parsed
	else:
		push_error("Config: %s ist kein JSON-Objekt" % PATH)
		_data = {}


static func get_value(key: String, fallback = null):
	return data().get(key, fallback)


static func section(key: String) -> Dictionary:
	var value = data().get(key, {})
	return value if value is Dictionary else {}


static func get_int(key: String, fallback: int = 0) -> int:
	return int(data().get(key, fallback))


static func get_float(key: String, fallback: float = 0.0) -> float:
	return float(data().get(key, fallback))


## Bereiche stehen in der JSON als [min, max].
static func range_of(source: Dictionary, key: String,
		fallback: Vector2i = Vector2i.ZERO) -> Vector2i:
	var value = source.get(key)
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback


static func reload() -> void:
	_data = {}
	_load()
