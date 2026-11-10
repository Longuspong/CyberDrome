class_name Encounters
extends RefCounted

## Handverlesene Gegnerteams (data/encounters.json).
##
## Vorgabe des Spielers (10. Nov. 2026): Gegner werden nicht gewuerfelt --
## ausser im Chaos-Kampf des Endlos-Modus. Jedes Team ist eine feste Liste
## von DROMEs mit Namen, Waffen und Modulen und hat einen **Typ** (Sturm,
## Schuetzen, Bollwerk, Kontrolle, Gemischt), an dem der Spieler erkennt, was
## auf ihn zukommt. Treten weniger Gegner an, als das Team hat, sind es die
## ersten der Liste.
##
## Reine Daten und Logik, ohne Szene testbar.

const PATH := "res://data/encounters.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file == null:
			push_error("Encounters: %s nicht lesbar" % PATH)
			return {}
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("Encounters: %s ist kein JSON-Objekt" % PATH)
	return _data


## Die Teams der Fraktion eines Gebiets (leer, wenn das Gebiet keine hat).
static func faction_teams(region_id: StringName) -> Array:
	var faction: Dictionary = (data().get("factions", {}) as Dictionary).get(str(region_id), {})
	return faction.get("teams", [])


## Die Trainingsteams: normale DROMEs ohne Fraktion, fuer die ersten Runden.
static func training_teams() -> Array:
	return data().get("training", [])


## Alle Teams aller Fraktionen und das Training -- fuer Tests und Uebersichten.
static func all_teams() -> Array:
	var out: Array = training_teams().duplicate()
	for region in data().get("factions", {}):
		out.append_array(faction_teams(StringName(region)))
	return out


static func team(team_id: String) -> Dictionary:
	for entry in all_teams():
		if str(entry.get("id", "")) == team_id:
			return entry
	return {}


## Die Teams, die in dieser Runde und Stufe auftauchen duerfen. ``training``:
## die ersten Runden des Laufs (run.training_rounds) -- dann nur die
## Trainingsteams.
static func pool(region_id: StringName, round: int, tier_key: String, training: bool) -> Array:
	var source: Array = training_teams() if training else faction_teams(region_id)
	var out: Array = []
	for entry in source:
		var tiers: Array = entry.get("tiers", [])
		if not tiers.is_empty() and not tiers.has(tier_key):
			continue
		if round < int(entry.get("from_round", 1)) or round > int(entry.get("to_round", 9999)):
			continue
		out.append(entry)
	# Nie leer: lieber ein Team ausserhalb seines Bereichs als gar keins.
	return out if not out.is_empty() else source.duplicate()


## Name und Hinweis eines Gegnertyps: {name, hint}.
static func type_info(type_id: String) -> Dictionary:
	var info: Dictionary = (data().get("types", {}) as Dictionary).get(type_id, {})
	return {"name": str(info.get("name", type_id.capitalize())), "hint": str(info.get("hint", ""))}


## Baut die ersten ``count`` DROMEs eines Teams -- ohne Level und Module (die
## setzt RunState nach Runde und Stufe, siehe modules_for).
static func build(entry: Dictionary, count: int) -> Array:
	var builds: Array = []
	var dromes: Array = entry.get("dromes", [])
	for i in mini(count, dromes.size()):
		var build := build_drome(dromes[i])
		if build != null:
			builds.append(build)
	return builds


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
