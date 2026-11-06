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
var spd: int = 0
var atk: int = 0
var def: int = 0
## Zwei-Verteidigungs-System (§11): Energieschild-Grundwert (Chassis), seine
## Nachfuellung je Puls (Kern) und die prozentuale Schild-Effizienz (Kern).
var shield: int = 0
var shield_regen: int = 0
var shield_bonus: float = 0.0
var weight: int = 0

## Passive Selbstheilung je Puls, in Prozent der maximalen Integritaet (5 = 5 %).
## Der Drohnen-Pod traegt sie -- eine Passive statt einer aktiven Heilung.
var hp_regen_pct: int = 0

## Lockradius in Feldern: Gegner so nah greifen den Traeger an statt ihres
## eigenen Ziels (Koedersender). Sichtbar ueber den Gelockten.
var lure_radius: int = 0

## Nur body: wie die KI diesen DROME fuehrt (vanguard, skirmisher, sniper,
## controller -- siehe AIController). Leer = nach Waffenreichweite.
var ai_role: String = ""

## Nur body: die Passive des DROME (siehe Unit.passive()). Leer = keine.
var passive: String = ""

## Gewaehrte Aktionen. Leer bei passiven Teilen. Eine Waffe traegt zwei
## Eintraege -- ihren Angriff und ihre eigene Faehigkeit (GAME_DESIGN §13); ein
## Gadget null oder eine.
var actions: Array = []

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
	part.spd = stats.get("spd", 0)
	part.atk = stats.get("atk", 0)
	part.def = stats.get("def", 0)
	part.shield = stats.get("shield", 0)
	part.shield_regen = stats.get("shield_regen", 0)
	part.shield_bonus = float(stats.get("shield_bonus", 0.0))
	part.weight = stats.get("weight", 0)
	part.hp_regen_pct = stats.get("hp_regen_pct", 0)
	part.lure_radius = int(stats.get("lure_radius", 0))
	part.ai_role = str(stats.get("ai_role", ""))
	part.passive = str(stats.get("passive", ""))

	# Ein Teil gewaehrt eine LISTE von Aktionen. ``action`` (Einzahl) bleibt als
	# Altformat lesbar, damit ein aelterer Datensatz nicht stumm seine Aktion
	# verliert.
	for action_meta in stats.get("actions", []):
		part.actions.append(
			ActionData.from_meta(action_meta, part.display_name, part.code))
	var legacy = stats.get("action")
	if legacy != null and part.actions.is_empty():
		part.actions.append(
			ActionData.from_meta(legacy, part.display_name, part.code))
	return part


## Haengt eine der vier Ansichten an. ``dir_path`` ist das Verzeichnis, in dem
## das SVG liegt -- damit der Loader nicht raten muss, wo der Satz steht.
func add_view(meta: Dictionary, dir_path: String) -> void:
	var anchors := {}
	for entry in meta.get("anchors", []):
		anchors[entry.get("name", "")] = Vector2(entry.get("x", 0.0), entry.get("y", 0.0))
	var svg := dir_path.path_join(meta.get("svg", ""))
	# Neon-Teile haben eine eigene Leuchtebene (tools/bake_godot_assets.py).
	var glow := svg.replace(".svg", "_glow.svg")
	views[meta.get("direction", "south")] = {
		"svg": svg,
		"glow": glow if ResourceLoader.exists(glow) else "",
		"anchors": anchors,
		"slot_z": meta.get("slot_z", {}),
		"z_index": meta.get("z_index", 20.0),
	}


func view(direction: String) -> Dictionary:
	return views.get(direction, views.get("south", {}))


## Die Ausruestungsslots eines Chassis sind seine equip_*-Anker -- ausser
## denen, die ``slot_rules`` mit ``off`` abschaltet. Seit Nov. 2026 hat jeder
## DROME einen Platz, der Molok zwei; die uebrigen Anker sind reine Optik.
func equip_slots() -> Array[String]:
	var slots: Array[String] = []
	if type != Type.BODY:
		return slots
	for name in view("south").get("anchors", {}):
		if not str(name).begins_with("equip_"):
			continue
		var rule: Dictionary = slot_rules.get(str(name), {})
		if rule.get("off", false):
			continue
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
	if rule.get("off", false):
		return false
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
