class_name Encounters
extends RefCounted

## Bausteine fuer Gegner: einen DROME aus Chassis und Waffen bauen, Module
## passend zur Waffe waehlen, den Halter der ersten Waffe finden.
##
## Die handverlesenen Teams (10. Nov. 2026) sind seit 14. Nov. 2026 durch
## Formationen ersetzt (Formations, data/formations.json; SPOT-Blatt Fragen
## 35). Uebrig bleiben diese Helfer, die Formations und der Chaos-Kampf nutzen.


## Ein DROME aus seinem Eintrag {name, chassis, weapons}. Die Waffen kommen
## der Reihe nach in die Halter des Chassis.
static func build_drome(entry: Dictionary) -> DromeBuild:
	var chassis := PartDB.get_part(StringName(str(entry.get("chassis", ""))))
	if chassis == null or chassis.type != PartData.Type.BODY:
		push_warning("Encounters: unbekanntes Chassis '%s'" % entry.get("chassis", ""))
		return null
	var build := DromeBuild.create(str(entry.get("name", "DROME")), {})
	build.apply_chassis(chassis.id)
	var holders := build.equip_slots()
	var weapons: Array = entry.get("weapons", [])
	for i in mini(weapons.size(), holders.size()):
		build.slots[holders[i]] = StringName(str(weapons[i]))
	return build


## Der Halter mit der ersten Waffe -- dort stecken die Module der Gegner.
static func first_weapon_slot(build: DromeBuild) -> String:
	for slot in build.equip_slots():
		if build.part_in(slot) != null:
			return slot
	return ""
