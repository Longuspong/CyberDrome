class_name PartData
extends RefCounted

## Ein Bauteil, so wie es im Repo tatsaechlich definiert ist.
##
## Bewusst KEINE Resource mit .tres-Dateien. Die Bauteile dieses Projekts
## werden von tools/build_sample_parts.py erzeugt und liegen als JSON neben
## ihren SVGs. Ein zweiter Satz .tres daneben waere ein zweites
## Bauteil-Datenmodell -- die Anker liefen von den Werten weg, und niemand
## koennte sagen, welche Seite recht hat. Diese Klasse liest deshalb das
## vorhandene Format, statt es zu ersetzen.
##
## Ein Teil existiert einmal, seine Grafik viermal. ``id`` ist
## richtungsunabhaengig (``scout_body``), die Ansichten haengen darunter.

## Die fuenf Bauteiltypen des Bestands. NICHT die sechs Slots des
## Entwurfsdokuments -- hier gewinnt das Repo: ein DROME hat einen Kopf, und
## wie viele Ausruestungsslots er hat, sagen die Anker seines Chassis.
enum Type { BODY, HEAD, FEET, CORE, EQUIPMENT }

const TYPE_NAMES := {
	"body": Type.BODY,
	"head": Type.HEAD,
	"feet": Type.FEET,
	"core": Type.CORE,
	"equipment": Type.EQUIPMENT,
}

## Die vier Sockel-Slots heissen wie ihr Bauteiltyp. Ausruestungsslots nicht --
## sie heissen nach ihrem Anker (equip_left, equip_shoulder, ...).
const SOCKET_SLOTS := ["body", "head", "feet", "core"]

## Montageklassen, aufsteigend. Ein Slot nimmt alles bis zu seiner Grenze.
const MOUNT_CLASSES := ["light", "medium", "heavy"]

var id: StringName
var code: String            ## stabile Kennung fuers Game Design, z.B. "CHS-001"
var set_id: String          ## bot1 .. bot4
var display_name: String
var type: Type
var tags: PackedStringArray

## Nur equipment
var mount_class: String = "light"
var category: String = "weapon"     ## weapon | shield | support

## Nur body: welcher Ausruestungsslot was annimmt
var slot_rules: Dictionary = {}

## Spielwerte. Flach, additiv, ohne Grundwerte irgendwo sonst.
var hp: int = 0
var en_max: int = 0
var en_regen: int = 0
var spd: int = 0
var mov: int = 0
var atk: int = 0
var def: int = 0
var weight: int = 0
var power_draw: int = 0
var weight_capacity: int = 0        ## nur body
var power_output: int = 0           ## nur core

## Traversierung -- die eigentliche Kaufentscheidung beim Antrieb
var can_pass_units: bool = false
var can_enter_steps: bool = false
var can_pass_blocks: bool = false   ## Post-MVP (Tunnelbauer). Immer false.
var ignores_drift: bool = false
var drift_modifier: int = 0
var step_cost_reduced: bool = false

## Sensorik
var grants_ignore_haze: bool = false

## Gewaehrte Aktion, oder null bei passiven Teilen
var action: ActionData = null

## direction -> { svg: String, anchors: {name: Vector2}, slot_z: {slot: float},
##                z_index: float }
var views: Dictionary = {}


static func type_from_string(text: String) -> Type:
	return TYPE_NAMES.get(text, Type.EQUIPMENT)


## Baut ein Teil aus einer der vier Richtungs-JSONs. Die richtungsabhaengigen
## Felder kommen ueber add_view() dazu.
static func from_meta(meta: Dictionary) -> PartData:
	var part := PartData.new()
	part.id = StringName(meta.get("id", ""))
	part.code = meta.get("code", "")
	part.set_id = meta.get("set", "")
	part.display_name = meta.get("name", str(part.id))
	part.type = type_from_string(meta.get("type", "equipment"))
	part.tags = PackedStringArray(meta.get("tags", []))
	part.mount_class = meta.get("mount_class", "light")
	part.category = meta.get("category", "weapon")
	part.slot_rules = meta.get("slot_rules", {})

	var stats: Dictionary = meta.get("stats", {})
	part.hp = stats.get("hp", 0)
	part.en_max = stats.get("en_max", 0)
	part.en_regen = stats.get("en_regen", 0)
	part.spd = stats.get("spd", 0)
	part.mov = stats.get("mov", 0)
	part.atk = stats.get("atk", 0)
	part.def = stats.get("def", 0)
	part.weight = stats.get("weight", 0)
	part.power_draw = stats.get("power_draw", 0)
	part.weight_capacity = stats.get("weight_capacity", 0)
	part.power_output = stats.get("power_output", 0)
	part.can_pass_units = stats.get("can_pass_units", false)
	part.can_enter_steps = stats.get("can_enter_steps", false)
	part.can_pass_blocks = stats.get("can_pass_blocks", false)
	part.ignores_drift = stats.get("ignores_drift", false)
	part.drift_modifier = stats.get("drift_modifier", 0)
	part.step_cost_reduced = stats.get("step_cost_reduced", false)
	part.grants_ignore_haze = stats.get("grants_ignore_haze", false)

	var action_meta = stats.get("action")
	if action_meta != null:
		part.action = ActionData.from_meta(action_meta, part.display_name)
	return part


## Haengt eine der vier Ansichten an. ``dir_path`` ist das Verzeichnis, in dem
## das SVG liegt -- damit der Loader nicht raten muss, wo der Satz steht.
func add_view(meta: Dictionary, dir_path: String) -> void:
	var anchors := {}
	for entry in meta.get("anchors", []):
		anchors[entry.get("name", "")] = Vector2(entry.get("x", 0.0), entry.get("y", 0.0))
	views[meta.get("direction", "south")] = {
		"svg": dir_path.path_join(meta.get("svg", "")),
		"anchors": anchors,
		"slot_z": meta.get("slot_z", {}),
		"z_index": meta.get("z_index", 20.0),
	}


func view(direction: String) -> Dictionary:
	return views.get(direction, views.get("south", {}))


## Die Ausruestungsslots eines Chassis sind exakt seine equip_*-Anker. Kein
## Sonderfall im Code -- ein Chassis bekommt einen dritten Slot, indem es einen
## dritten Anker in seine JSON schreibt.
func equip_slots() -> Array[String]:
	var slots: Array[String] = []
	if type != Type.BODY:
		return slots
	for name in view("south").get("anchors", {}):
		if str(name).begins_with("equip_"):
			slots.append(str(name))
	slots.sort()
	return slots


## Darf dieses Ausruestungsteil in diesen Slot dieses Chassis?
## Spiegelt fits_rule() aus tools/build_sample_parts.py -- die Werkstatt prueft
## das beim Bauen, aber ein Loadout kann von Hand entstehen oder aus einem
## aelteren Stand kommen. Die Regel muss deshalb auch hier gelten.
func accepts(equipment: PartData, slot: String) -> bool:
	if type != Type.BODY or equipment.type != Type.EQUIPMENT:
		return false
	var rule: Dictionary = slot_rules.get(slot, {})
	if rule.is_empty():
		return true
	var limit: String = rule.get("max_class", MOUNT_CLASSES[-1])
	if MOUNT_CLASSES.find(equipment.mount_class) > MOUNT_CLASSES.find(limit):
		return false
	var allowed = rule.get("categories")
	if allowed == null or (allowed is Array and allowed.is_empty()):
		return true
	return equipment.category in allowed


func slot_name() -> String:
	match type:
		Type.BODY: return "body"
		Type.HEAD: return "head"
		Type.FEET: return "feet"
		Type.CORE: return "core"
		_: return "equipment"


func _to_string() -> String:
	return "PartData(%s %s)" % [code, id]
