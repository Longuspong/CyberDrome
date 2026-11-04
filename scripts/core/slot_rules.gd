class_name SlotRules
extends RefCounted

## Was in welchen Halter passt -- im Klartext, ohne Bildschirm.
##
## Die Regel selbst steht in PartData.accepts(): jeder Halter hat eine
## Hoechstklasse (``max_class``), und alles BIS zu dieser Klasse passt hinein.
## Ein leichter Blaster sitzt also auch in einem schweren Halter, eine
## Belagerungskanone (schwer) aber nicht in einem mittleren. Manche Halter
## nehmen zusaetzlich nur bestimmte Arten (die Molok-Schulter nur Support).
##
## Hier steht nur, wie man das dem Spieler SAGT: welche Halter es gibt, was
## drinsteckt und -- wenn es nicht passt -- warum nicht.
##
## Die Formen dazu (SlotShape): Dreieck = leicht, Viereck = mittel,
## Fuenfeck = schwer, Kreis = Kern. Mehr Ecken heisst mehr Platz.

const SLOT_LABEL := {
	"body": "Chassis", "head": "Sensorik", "feet": "Antrieb", "core": "Kern",
	"equip_left": "links", "equip_right": "rechts",
	"equip_shoulder": "Schulter", "equip_center": "Zentral",
}


static func slot_label(slot: String) -> String:
	return SLOT_LABEL.get(slot, slot)


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
			"label": "Slot %d · %s (%s)" % [number, slot_label(slot), class_label(limit)],
			"detail": detail,
			"allowed": allowed,
		})
	return choices


static func rejection(part: PartData, rule: Dictionary, limit: String) -> String:
	if PartData.MOUNT_CLASSES.find(part.mount_class) \
			> PartData.MOUNT_CLASSES.find(limit):
		return "nimmt nur bis %s" % class_label(limit)
	var allowed = rule.get("categories")
	if allowed is Array and not allowed.is_empty() and part.category not in allowed:
		var names: Array[String] = []
		for entry in allowed:
			names.append(category_label(str(entry)))
		return "nur %s" % ", ".join(names)
	return "passt nicht"
