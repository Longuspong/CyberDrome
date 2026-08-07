class_name Mutator
extends RefCounted

## Der Chaos-Mutator: eine Regel, die fuer ALLE DROMEs gilt.
##
## Er wird vor Kampfbeginn aus dem Seed gezogen und gross eingeblendet. Zwei
## Sorten, und beide laufen ohne Sonderfall:
##
##   * Kartenmutatoren skalieren nur Mengen im Generator (block_scale ...).
##     Der Generator kennt den Mutator nicht, er bekommt Faktoren.
##   * Statmutatoren haengen sich als Statuseffekt an jede Einheit. Damit
##     laufen sie durch denselben Weg wie Virus-Injektor und Schildmatrix
##     und muessen nirgends gesondert abgezogen werden.

const STATUS_ID := &"mutator"

var id: StringName
var display_name: String
var description: String
var data: Dictionary = {}


static func draw(rng: RandomNumberGenerator) -> Mutator:
	var pool: Array = Config.get_value("mutators", [])
	if pool.is_empty():
		return Mutator.new()
	return from_meta(pool[rng.randi() % pool.size()])


static func from_meta(meta: Dictionary) -> Mutator:
	var mutator := Mutator.new()
	mutator.id = StringName(meta.get("id", "clean"))
	mutator.display_name = meta.get("name", "Sauberer Lauf")
	mutator.description = meta.get("description", "")
	mutator.data = meta
	return mutator


## Faktoren fuer den Kartengenerator. Er bekommt nur Zahlen, keine Absicht.
func map_scales() -> Dictionary:
	var scales := {}
	for key in ["block_scale", "step_scale", "drift_scale", "haze_scale"]:
		if data.has(key):
			scales[key] = float(data[key])
	return scales


## Wirkt der Mutator auf Werte, nicht auf die Karte?
func has_stat_effect() -> bool:
	return data.has("spd_bonus") or data.has("def_bonus") \
		or data.has("en_regen_scale")


## Haengt sich als dauerhafter Statuseffekt an. cycles_left ist absichtlich
## riesig: der Mutator laeuft nie ab, aber er nimmt denselben Weg wie jeder
## andere Effekt.
func apply_to(unit: Unit) -> void:
	if not has_stat_effect():
		return
	var modifiers := {}
	if data.has("spd_bonus"):
		modifiers["spd"] = int(data["spd_bonus"])
	if data.has("def_bonus"):
		modifiers["def"] = int(data["def_bonus"])
	if data.has("en_regen_scale"):
		# Halbiert, abgerundet -- als Abzug formuliert, damit die Kette
		# additiv bleibt und nicht ploetzlich multiplikativ wird.
		var base: int = unit.stats.get("en_regen", 0)
		var scaled := int(floor(base * float(data["en_regen_scale"])))
		modifiers["en_regen"] = scaled - base
	unit.apply_status(STATUS_ID, 999999, modifiers)


## Schaden zu Beginn jedes eigenen Zuges (Aderlass). 0 = keiner.
func turn_damage() -> int:
	return int(data.get("turn_damage", 0))


func is_clean() -> bool:
	return id == &"clean"
