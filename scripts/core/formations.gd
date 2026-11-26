class_name Formations
extends RefCounted

## Gegner-Squads aus Formationen (14. Nov. 2026, SPOT-Blaetter Sentinels,
## Gegner-DROMEs, Formationen; data/formations.json).
##
## Eine Squad ist ein oder zwei DROMEs plus Sentinels. Jede Formation hat
## einen Grundgedanken und Stufen nach dem **Reinforcement-Level**, das nach
## jedem Kampf steigt. Leicht, Normal und Elite sind dieselbe Formation mit
## anderem Level und anderen Raengen (``variants``).
##
## Sentinels: feste Waffe, nur Auto-Angriff, keine Passive, kein Level,
## 60 % gross (Platzhalter: verkleinerter Vireo, Strix, Nimbus). Ihre Werte
## stehen fest; der Rang (Basic, Elite, Heavy, Heavy Elite) multipliziert sie.
## Elite traegt ein festes Modul, Heavy Elite zwei.
##
## Gegner-DROMEs mit festen Werten (Neon Vireo ...) oder Standard-DROMEs. Ihre
## Module wuerfelt der Seed passend zur Waffe -- ab zwei Modulen verschmilzt
## ein Paar zu einem Rezept.
##
## Reine Daten und Logik, ohne Szene testbar.

const PATH := "res://data/formations.json"
const MAX_DROMES := 2
const SENTINEL_SCALE := 0.6

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file == null:
			push_error("Formations: %s nicht lesbar" % PATH)
			return {}
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_data = parsed
	return _data


## Die Formationen eines Gebiets. Gebiete ohne eigene bekommen die von
## Neon City (bis die anderen Fraktionen ihre haben).
static func of_region(region_id: StringName) -> Array:
	var all: Dictionary = data().get("formations", {})
	if all.has(str(region_id)):
		return all[str(region_id)]
	return all.get("city", [])


## Alle Formationen aller Gebiete (Tests, Infinity-Einsatz).
static func all() -> Array:
	var out: Array = []
	for region in data().get("formations", {}):
		out.append_array(data()["formations"][region])
	return out


static func formation(formation_id: String) -> Dictionary:
	for entry in all():
		if str(entry.get("id", "")) == formation_id:
			return entry
	return {}


static func variant(tier_key: String) -> Dictionary:
	return (data().get("variants", {}) as Dictionary).get(tier_key, {})


static func reinforcement_cfg() -> Dictionary:
	return data().get("reinforcement", {})


## Die erste Stufe einer Formation, ab der sie auftauchen kann.
static func first_level(entry: Dictionary) -> int:
	var steps: Array = entry.get("steps", [])
	return int(steps[0].get("from", 1)) if not steps.is_empty() else 1


## Die Stufe einer Formation fuer ein Reinforcement-Level: die letzte, deren
## ``from`` erreicht ist (sonst die erste).
static func step_for(entry: Dictionary, level: int) -> Dictionary:
	var steps: Array = entry.get("steps", [])
	if steps.is_empty():
		return {}
	var pick: Dictionary = steps[0]
	for step in steps:
		if level >= int(step.get("from", 1)):
			pick = step
	return pick


## Die Zusammensetzung fuer Level und Variante: {dromes: [id], sentinels:
## [[id, rang]], drome_modules: Zahl}. Leicht: tieferes Level, nur Basic,
## ein Sentinel weniger (mindestens zwei bleiben). Elite: hoeheres Level,
## die ersten Sentinels einen Rang hoeher, ein Modul mehr an den DROMEs.
static func composition(entry: Dictionary, level: int, tier_key: String) -> Dictionary:
	var rule := variant(tier_key)
	var effective := maxi(1, level + int(rule.get("level_offset", 0)))
	var step := step_for(entry, effective)
	var dromes: Array = (step.get("dromes", []) as Array).slice(0, MAX_DROMES)
	var sentinels: Array = []
	for spec in step.get("sentinels", []):
		var parts := str(spec).split(":")
		sentinels.append([parts[0], parts[1] if parts.size() > 1 else "basic"])
	if bool(rule.get("basic_only", false)):
		for pair in sentinels:
			pair[1] = "heavy" if pair[1] == "heavy_elite" else ("basic" if pair[1] == "elite" else pair[1])
			if pair[1] == "heavy":
				pair[1] = "basic"
	var drop := int(rule.get("drop_sentinels", 0))
	while drop > 0 and sentinels.size() > 2:
		sentinels.pop_back()
		drop -= 1
	var promote := int(rule.get("promote", 0))
	for pair in sentinels:
		if promote <= 0:
			break
		match pair[1]:
			"basic":
				pair[1] = "elite"
				promote -= 1
			"heavy":
				pair[1] = "heavy_elite"
				promote -= 1
	var per := maxi(1, int(reinforcement_cfg().get("drome_modules_per", 2)))
	var modules := maxi(0, effective / per + int(rule.get("drome_modules", 0)))
	return {"dromes": dromes, "sentinels": sentinels, "drome_modules": modules,
		"level": effective}


## Baut die Squad: erst die DROMEs, dann die Sentinels. ``seed_value``
## wuerfelt nur die Module der DROMEs.
static func build(entry: Dictionary, level: int, tier_key: String, seed_value: int) -> Array:
	var plan := composition(entry, level, tier_key)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array = []
	for drome_id in plan["dromes"]:
		var drome := build_drome(str(drome_id))
		if drome != null:
			arm_drome(drome, int(plan["drome_modules"]), rng)
			out.append(drome)
	for pair in plan["sentinels"]:
		var sentinel := build_sentinel(str(pair[0]), str(pair[1]))
		if sentinel != null:
			out.append(sentinel)
	return out


## Ein Gegner-DROME aus data/formations.json -> dromes.
static func build_drome(drome_id: String) -> DromeBuild:
	var spec: Dictionary = (data().get("dromes", {}) as Dictionary).get(drome_id, {})
	if spec.is_empty():
		push_warning("Formations: unbekannter DROME '%s'" % drome_id)
		return null
	var build := Encounters.build_drome({"name": spec.get("name", drome_id),
		"chassis": spec.get("chassis", ""), "weapons": spec.get("weapons", [])})
	if build == null:
		return null
	var stats: Dictionary = spec.get("stats", {})
	for key in stats:
		build.stat_override[key] = int(stats[key])
	build.faction = str(spec.get("faction", ""))
	return build


## Ein Sentinel: Platzhalter-Chassis, feste Waffe im ersten Halter, feste
## Werte mal Rang. Elite-Raenge tragen ihre festen Module.
static func build_sentinel(sentinel_id: String, rank_id: String = "basic") -> DromeBuild:
	var spec: Dictionary = (data().get("sentinels", {}) as Dictionary).get(sentinel_id, {})
	var rank: Dictionary = (data().get("ranks", {}) as Dictionary).get(rank_id, {})
	if spec.is_empty() or rank.is_empty():
		push_warning("Formations: unbekannter Sentinel '%s:%s'" % [sentinel_id, rank_id])
		return null
	var build := DromeBuild.create(_sentinel_name(spec, rank_id), {})
	build.apply_chassis(StringName(str(spec.get("look", "scout_body"))))
	var holders := build.equip_slots()
	if holders.is_empty():
		return null
	# Feste Waffe, an der Halterklasse vorbei: ein Sentinel hat keinen Halter.
	for slot in holders:
		build.slots.erase(slot)
	build.slots[holders[0]] = StringName(str(spec.get("weapon", "")))
	var base: Dictionary = spec.get("stats", {})
	build.stat_override = {
		"hp_max": int(round(float(base.get("hp_max", 40)) * float(rank.get("hp", 1.0)))),
		"shield": int(round(float(base.get("shield", 0)) * float(rank.get("shield", 1.0)))),
		"power": int(round(float(base.get("power", 5)) * float(rank.get("power", 1.0)))),
		"def": int(base.get("def", 0)) + int(rank.get("def", 0)),
		"spd": int(base.get("spd", 8)) + int(rank.get("spd", 0)),
		"shield_pulse": int(base.get("shield_pulse", 0)),
		"module_slots": int(rank.get("modules", 0)),
		"hp_regen_pct": 0, "shield_bonus": 0.0,
	}
	build.unit_kind = "sentinel"
	build.rank = rank_id
	build.archetype = str(spec.get("archetype", "assault"))
	build.auto_only = true
	build.sprite_scale = SENTINEL_SCALE
	build.faction = str(spec.get("faction", ""))
	build.role_override = {"assault": "vanguard", "sniper": "sniper"}.get(build.archetype, "")
	var count := int(rank.get("modules", 0))
	if count > 0:
		var weapon := build.part_in(holders[0])
		var picked: Array = []
		for module_id in spec.get("elite_modules", []):
			var module := ModuleData.get_module(StringName(str(module_id)))
			if module != null and (weapon == null or module.fits(weapon)) and picked.size() < count:
				picked.append(module.id)
		if not picked.is_empty():
			build.modules[holders[0]] = picked
	return build


static func _sentinel_name(spec: Dictionary, rank_id: String) -> String:
	var name := str(spec.get("name", "Sentinel"))
	match rank_id:
		"elite": return name.replace("Sentinel", "Elite")
		"heavy": return name.replace("Sentinel", "Heavy")
		"heavy_elite": return name.replace("Sentinel", "Heavy Elite")
	return name


## Module eines Gegner-DROME: ``count`` passende, am Seed gewuerfelt. Ab zwei
## wird ein Paar zu einem Rezept verschmolzen, dessen Zutaten beide passen
## (Blatt Fragen 32). In den Halter der ersten Waffe.
static func arm_drome(build: DromeBuild, count: int, rng: RandomNumberGenerator) -> void:
	var slot := Encounters.first_weapon_slot(build)
	if slot == "" or count <= 0:
		return
	var weapon := build.part_in(slot)
	var room := ModuleData.slots_for(build, slot)
	var left := count
	var picked: Array = []
	if left >= 2 and room >= 1:
		var recipes := ModuleData.recipes().filter(func(m): return not m.is_bios_result and m.fits(weapon))
		if not recipes.is_empty():
			picked.append(recipes[rng.randi() % recipes.size()].id)
			left -= 2        # ein Rezept belegt einen Platz, steht aber fuer zwei Module
	var pool := ModuleData.base_modules().filter(func(m): return m.fits(weapon))
	while left > 0 and picked.size() < room and not pool.is_empty():
		var pick := rng.randi() % pool.size()
		picked.append(pool[pick].id)
		pool.remove_at(pick)
		left -= 1
	if not picked.is_empty():
		build.modules[slot] = picked


## Symbole fuer die Vorschau: je Einheit {kind, archetype, rank, name}.
static func roster_icons(builds: Array) -> Array:
	var out: Array = []
	for build in builds:
		out.append({"kind": build.unit_kind, "archetype": build.archetype, "rank": build.rank,
			"name": build.display_name})
	return out
