class_name SlotRules
extends RefCounted

## Was in welchen Halter passt -- im Klartext, ohne Bildschirm.
##
## Die Regel selbst steht in PartData.accepts(): jeder Halter hat eine
## Hoechstklasse (``max_class``), und alles BIS zu dieser Klasse passt hinein.
## Ein leichter Blaster sitzt also auch in einem schweren Halter, ein schwerer
## Moerser aber nicht in einem mittleren.
##
## Hier steht nur, wie man das dem Spieler SAGT: welche Halter es gibt, was
## drinsteckt und -- wenn es nicht passt -- warum nicht.
##
## Die Formen dazu (SlotShape): Dreieck = leicht, Viereck = mittel,
## Fuenfeck = schwer. Mehr Ecken heisst mehr Platz.

const SLOT_LABEL := {
	"body": "Chassis", "head": "Sensorik", "feet": "Antrieb", "core": "Kern",
}


## Der Name eines Sockels (Chassis, Sensorik ...). Ausruestungshalter heissen
## schlicht "Halter" -- die Richtung (links, rechts) steht seit 10. Nov. 2026
## nirgends mehr (Wunsch des Spielers); mehrere Halter eines DROME
## unterscheidet holder_label ueber eine Nummer.
static func slot_label(slot: String) -> String:
	return SLOT_LABEL.get(slot, "Halter" if slot.begins_with("equip_") else slot)


## Wie ein Ausruestungshalter dieses DROME im Text heisst: "Halter", bei
## mehreren (Molok) "Halter 1", "Halter 2".
static func holder_label(build: DromeBuild, slot: String) -> String:
	var holders: Array = build.equip_slots() if build != null else []
	var index := holders.find(slot)
	if holders.size() <= 1 or index < 0:
		return slot_label(slot)
	return "Halter %d" % (index + 1)


## Halter-Kuerzel (Spieler 27. Nov. 2026): sprachneutral, damit sie in jeder
## Sprache gleich bleiben -- S leicht, M mittel, X schwer.
const CLASS_CODE := {"light": "S", "medium": "M", "heavy": "X"}
## Dahinter, wenn der Halter nur eine Reichweite nimmt: F Fernkampf, N Nahkampf.
const REACH_CODE := {"ranged": "F", "melee": "N"}


static func class_code(mount_class: String) -> String:
	return str(CLASS_CODE.get(mount_class, mount_class))


## Das Kuerzel eines Halters: "M", "X-F" (Strix-Lafette), "M-N" ...
static func holder_code(chassis: PartData, slot: String) -> String:
	var code := class_code(slot_class(chassis, slot))
	var reach := slot_reach(chassis, slot)
	if REACH_CODE.has(reach):
		code += "-" + str(REACH_CODE[reach])
	return code


static func class_label(mount_class: String) -> String:
	match mount_class:
		"light": return "leicht"
		"medium": return "mittel"
		"heavy": return "schwer"
		_: return mount_class


static func category_label(category: String) -> String:
	match category:
		"weapon": return "Waffe"
		"shield": return "Schild"
		"support": return "Support"
		_: return category


## Die Hoechstklasse eines Halters dieses Chassis.
static func slot_class(chassis: PartData, slot: String) -> String:
	if chassis == null:
		return PartData.MOUNT_CLASSES[-1]
	var rule: Dictionary = chassis.slot_rules.get(slot, {})
	return rule.get("max_class", PartData.MOUNT_CLASSES[-1])


## Ob ein Halter nur Fern- oder nur Nahkampf nimmt ("ranged", "melee" oder "").
## Die Lafette des Strix nimmt nur Fernkampf (docs/DROME_DESIGNREGELN.md).
static func slot_reach(chassis: PartData, slot: String) -> String:
	if chassis == null:
		return ""
	var rule: Dictionary = chassis.slot_rules.get(slot, {})
	return str(rule.get("reach", ""))


static func reach_label(reach: String) -> String:
	match reach:
		"ranged": return "Fernkampf"
		"melee": return "Nahkampf"
		_: return reach


## Welche Halter dieses Chassis fuer dieses Teil hat -- alle, auch die, die es
## nicht nehmen, mit dem Grund daneben.
static func slot_choices(build: DromeBuild, part: PartData) -> Array:
	var choices: Array = []
	if build == null or part == null or part.type != PartData.Type.EQUIPMENT:
		return choices
	var chassis := build.body()
	if chassis == null:
		return choices

	var number := 0
	for slot in build.equip_slots():
		number += 1
		var rule: Dictionary = chassis.slot_rules.get(slot, {})
		var limit: String = rule.get("max_class", PartData.MOUNT_CLASSES[-1])
		var occupant := build.part_in(slot)
		var allowed := chassis.accepts(part, slot)

		var detail := ""
		if not allowed:
			detail = rejection(part, rule, limit)
		elif occupant == null:
			detail = "frei"
		elif occupant.id == part.id:
			detail = "steckt schon drin"
		else:
			detail = "ersetzt %s" % occupant.display_name

		choices.append({
			"slot": slot,
			"number": number,
			"label": "Halter %d (%s)" % [number, holder_code(chassis, slot)],
			"detail": detail,
			"allowed": allowed,
		})
	return choices


static func rejection(part: PartData, rule: Dictionary, limit: String) -> String:
	if PartData.MOUNT_CLASSES.find(part.mount_class) \
			> PartData.MOUNT_CLASSES.find(limit):
		return "nimmt nur bis %s" % class_label(limit)
	var reach: String = str(rule.get("reach", ""))
	if reach != "" and part.reach_kind() != reach:
		return "nur %s" % reach_label(reach)
	var allowed = rule.get("categories")
	if allowed is Array and not allowed.is_empty() and part.category not in allowed:
		var names: Array[String] = []
		for entry in allowed:
			names.append(category_label(str(entry)))
		return "nur %s" % ", ".join(names)
	return "passt nicht"
