class_name Leveling
extends RefCounted

## Level fuer DROMEs (0-5) und Waffen (0-10) -- bleiben nach dem Lauf
## (NEUANFANG 6g, Werte nach docs/IDENTITAETEN.md, 8. Nov. 2026).
##
## DROME: zwei Hauptwerte je Chassis steigen bis Level 5 um 50 %, die anderen
## Werte (Integritaet, Schild, Schildpuls, Ruestung) um 20 %. Speed und Power
## steigen nie. Dazu Modulplaetze auf bestimmten Leveln.
##
## Waffe: es steigen immer zwei Werte -- der Schaden (Level 10 = +70 %) und
## ihr Bonus-Wert (je Waffe ein eigener Endwert, damit z. B. Speed nicht
## explodiert). Faehigkeit und Takt bleiben; der Faehigkeitsschaden waechst
## mit, weil er ein Anteil des Waffenschadens ist. Beim Neon-Blaster steigt nur
## der Energieanteil.
##
## Alle Zahlen: data/config.json -> levels.

## Die Werte, die ein DROME-Level anhebt (Schluessel wie in PartData).
const DROME_STATS := ["hp", "shield", "shield_pulse", "def"]


static func cfg() -> Dictionary:
	return Config.section("levels")


static func drome_cfg() -> Dictionary:
	return cfg().get("drome", {})


static func weapon_cfg() -> Dictionary:
	return cfg().get("weapon", {})


static func drome_max() -> int:
	return int(drome_cfg().get("max", 5))


static func weapon_max() -> int:
	return int(weapon_cfg().get("max", 10))


## Level zu einer EP-Summe: ``table`` sind die EP-Schwellen fuer Level 1, 2 ...
static func level_for(xp: int, table: Array) -> int:
	var level := 0
	for need in table:
		if xp >= int(need):
			level += 1
	return level


static func drome_level_for(xp: int) -> int:
	return mini(drome_max(), level_for(xp, drome_cfg().get("xp", [])))


static func weapon_level_for(xp: int) -> int:
	return mini(weapon_max(), level_for(xp, weapon_cfg().get("xp", [])))


## EP bis zum naechsten Level: [jetzt, Schwelle]; Schwelle 0 = Hoechstlevel.
static func progress(xp: int, table: Array) -> Array:
	for need in table:
		if xp < int(need):
			return [xp, int(need)]
	return [xp, 0]


# ---------------------------------------------------------------------------
# DROME
# ---------------------------------------------------------------------------

## Um wie viel ein Grundwert des Chassis auf diesem Level steigt (Faktor).
static func drome_mult(body_id: StringName, stat: String, level: int) -> float:
	if level <= 0:
		return 1.0
	var main: Array = (drome_cfg().get("main", {}) as Dictionary).get(str(body_id), [])
	var per := float(drome_cfg().get("main_per_level", 0.1)) if stat in main \
		else float(drome_cfg().get("other_per_level", 0.04))
	return 1.0 + per * float(mini(level, drome_max()))


## Was das DROME-Level an den Werten des Chassis aendert: stat -> Zuwachs.
static func drome_bonus(body: PartData, level: int) -> Dictionary:
	var out := {}
	if body == null or level <= 0:
		return out
	for stat in DROME_STATS:
		var base := float(body.get(stat))
		var grown := int(round(base * drome_mult(body.id, stat, level)))
		if grown != int(base):
			out[stat] = grown - int(base)
	return out


## Zusaetzliche Modulplaetze je Halter auf diesem Level.
static func extra_module_slots(body_id: StringName, level: int) -> int:
	var table: Dictionary = drome_cfg().get("module_slots_at", {})
	var steps: Array = table.get(str(body_id), table.get("default", []))
	var extra := 0
	for at in steps:
		if level >= int(at):
			extra += 1
	return extra


# ---------------------------------------------------------------------------
# Waffe
# ---------------------------------------------------------------------------

static func weapon_damage_mult(level: int) -> float:
	return 1.0 + float(weapon_cfg().get("damage_per_level", 0.07)) * float(clampi(level, 0, weapon_max()))


## Was das Waffenlevel am Bonus-Wert aendert: stat -> Zuwachs gegenueber
## Level 0. Linear vom Grundwert bis zum Endwert (bonus_at_max) auf Level 10.
static func weapon_bonus(part: PartData, level: int) -> Dictionary:
	var out := {}
	if part == null or level <= 0:
		return out
	var ends: Dictionary = (weapon_cfg().get("bonus_at_max", {}) as Dictionary).get(str(part.id), {})
	var share := float(clampi(level, 0, weapon_max())) / float(maxi(1, weapon_max()))
	for stat in ends:
		var base := float(part.get(stat))
		var grown := int(round(base + (float(ends[stat]) - base) * share))
		if grown != int(base):
			out[stat] = grown - int(base)
	return out


## Eine Aktion der Waffe auf ihrem Level -- als Kopie, die PartDB bleibt
## unberuehrt. Schaden (und Reparatur) wachsen; beim Neon-Blaster nur der
## Energieanteil.
static func level_action(action: ActionData, part: PartData, level: int) -> ActionData:
	if action == null or part == null or level <= 0:
		return action
	if action.power <= 0 and action.heal <= 0:
		return action
	var mult := weapon_damage_mult(level)
	var out := action.copy()
	if str(part.id) in weapon_cfg().get("energy_only", []):
		var energy := float(action.power) * action.energy_fraction
		var kinetic := float(action.power) - energy
		var grown := energy * mult
		out.power = int(round(kinetic + grown))
		out.energy_fraction = grown / maxf(1.0, kinetic + grown)
	else:
		out.power = int(round(float(action.power) * mult))
	if action.heal > 0:
		out.heal = int(round(float(action.heal) * mult))
	return out


# ---------------------------------------------------------------------------
# EP
# ---------------------------------------------------------------------------

## EP fuer den DROME nach einem Sieg dieser Stufe (RunState.TIER_KEYS).
static func drome_win_xp(tier_key: String) -> int:
	return int((drome_cfg().get("win_xp", {}) as Dictionary).get(tier_key, 1))


## EP fuer eine Waffe, die im Sieg getragen wurde, mit so vielen Abschuessen
## ihres Traegers.
static func weapon_win_xp(kills: int) -> int:
	return int(weapon_cfg().get("win_xp", 1)) + int(weapon_cfg().get("kill_xp", 1)) * maxi(0, kills)
