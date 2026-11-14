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


## Die Module eines Team-DROME bei ``count`` Plaetzen: die ersten der Liste;
## mit ``with_recipe`` und mindestens zwei Plaetzen steht vorn sein Rezept.
## Nur was zur Waffe im ersten Halter passt (ruhende Module traegt kein
## Gegner) und was es gibt.
static func modules_for(entry: Dictionary, build: DromeBuild, count: int, with_recipe: bool) -> Array:
	var picked: Array = []
	if count <= 0 or build == null:
		return picked
	var slot := first_weapon_slot(build)
	if slot == "":
		return picked
	var weapon := build.part_in(slot)
	var recipe_id := str(entry.get("recipe", ""))
	if with_recipe and count >= 2 and recipe_id != "":
		var recipe := ModuleData.get_module(StringName(recipe_id))
		if recipe != null and recipe.fits(weapon):
			picked.append(recipe.id)
	for module_id in entry.get("modules", []):
		if picked.size() >= count:
			break
		var module := ModuleData.get_module(StringName(str(module_id)))
		if module != null and module.fits(weapon) and not picked.has(module.id):
			picked.append(module.id)
	return picked


## Der Halter mit der ersten Waffe -- dort stecken die Module der Gegner.
static func first_weapon_slot(build: DromeBuild) -> String:
	for slot in build.equip_slots():
		if build.part_in(slot) != null:
			return slot
	return ""
