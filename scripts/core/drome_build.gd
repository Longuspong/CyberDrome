class_name DromeBuild
extends RefCounted

## Ein zusammengebauter DROME: Slots -> Stats, Validierung, Kampfwert.
##
## Keine Godot-Knoten, keine UI. Diese Klasse muss ohne laufende Szene testbar
## sein -- sie ist die Grundlage fuer Werkstatt, Gegner-Generator und KI
## gleichermassen, und ein Fehler hier faellt sonst erst im Kampf auf.
##
## Slotmodell des Repos (nicht die sechs festen Slots des Entwurfs):
##
##     body   Pflicht. Bestimmt ueber seine equip_*-Anker, wie viele
##            Ausruestungsslots dieser DROME ueberhaupt hat.
##     core   Pflicht. Deckelt ueber power_output, was drumherum haengen darf.
##     feet   Pflicht. Ohne Antrieb ist mov 0.
##     head   Pflicht. Sensorik.
##     equip_* Variabel: zwei beim Vireo, drei beim Molok, genau einer beim
##            Strix. Ein Chassis bekommt einen weiteren Slot, indem es einen
##            weiteren Anker in seine JSON schreibt -- kein Sonderfall im Code.

## Ein DROME hat keine Grundwerte. Jeder Stat ist die Summe seiner Teile.
const SOCKET_SLOTS := ["body", "head", "feet", "core"]

var display_name: String = "DROME"

## slot -> part_id. Slots ohne Eintrag sind leer.
var slots: Dictionary = {}

## Optional: abweichende Palette je Slot, wie die Werkstatt sie exportiert.
var palette: Dictionary = {}

## Blickrichtung fuer die Darstellung
var direction: String = "south"


static func create(name: String, assignment: Dictionary) -> DromeBuild:
	var build := DromeBuild.new()
	build.display_name = name
	for slot in assignment:
		var value = assignment[slot]
		if value != null and StringName(value) != &"":
			build.slots[slot] = StringName(value)
	return build


# ---------------------------------------------------------------------------
# Teile
# ---------------------------------------------------------------------------

func part_in(slot: String) -> PartData:
	var part_id = slots.get(slot)
	if part_id == null:
		return null
	return PartDB.get_part(part_id)


func body() -> PartData:
	return part_in("body")


## Alle belegten Teile, Sockel und Ausruestung gemeinsam.
func all_parts() -> Array:
	var result: Array = []
	for slot in slots:
		var part := part_in(slot)
		if part != null:
			result.append(part)
	return result


## Die Ausruestungsslots dieses DROME -- exakt die equip_*-Anker seines
## Chassis. Ohne Chassis gibt es keine.
func equip_slots() -> Array[String]:
	var chassis := body()
	if chassis == null:
		return []
	return chassis.equip_slots()


func equipment() -> Array:
	var result: Array = []
	for slot in equip_slots():
		var part := part_in(slot)
		if part != null:
			result.append(part)
	return result


func weapons() -> Array:
	var result: Array = []
	for part in equipment():
		if part.category == "weapon":
			result.append(part)
	return result


## Alle Aktionen, die dieser Aufbau gewaehrt.
func actions() -> Array:
	var result: Array = []
	for part in all_parts():
		if part.action != null:
			result.append(part.action)
	return result


# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------

## Summiert alles. Einzige Stelle, an der Stats entstehen.
func stats() -> Dictionary:
	var total := {
		"hp_max": 0, "en_max": 0, "en_regen": 0,
		"spd": 0, "mov": 0, "atk": 0, "def": 0,
		"weight": 0, "power_draw": 0,
		"weight_capacity": 0, "power_output": 0,
		"can_pass_units": false, "can_enter_steps": false,
		"can_pass_blocks": false, "ignores_drift": false,
		"drift_modifier": 0, "step_cost_reduced": false,
		"grants_ignore_haze": false,
		"aggro_bonus": 0,
	}
	for part in all_parts():
		total["hp_max"] += part.hp
		total["en_max"] += part.en_max
		total["en_regen"] += part.en_regen
		total["spd"] += part.spd
		total["mov"] += part.mov
		total["atk"] += part.atk
		total["def"] += part.def
		total["weight"] += part.weight
		total["power_draw"] += part.power_draw
		total["weight_capacity"] += part.weight_capacity
		total["power_output"] += part.power_output
		# Flags addieren sich als ODER: ein einziges Teil genuegt.
		total["can_pass_units"] = total["can_pass_units"] or part.can_pass_units
		total["can_enter_steps"] = total["can_enter_steps"] or part.can_enter_steps
		total["can_pass_blocks"] = total["can_pass_blocks"] or part.can_pass_blocks
		total["ignores_drift"] = total["ignores_drift"] or part.ignores_drift
		total["step_cost_reduced"] = total["step_cost_reduced"] or part.step_cost_reduced
		total["grants_ignore_haze"] = total["grants_ignore_haze"] or part.grants_ignore_haze
		total["drift_modifier"] += part.drift_modifier
		total["aggro_bonus"] += part.aggro_bonus

	# Negative Summen sind sinnlos, aber ein DROME darf sie erreichen -- die
	# Validierung faengt das ab und sagt dem Spieler, welche Regel bricht.
	total["hp_max"] = maxi(0, total["hp_max"])
	total["en_max"] = maxi(0, total["en_max"])
	total["def"] = maxi(0, total["def"])
	total["atk"] = maxi(0, total["atk"])
	return total


## Was ein einzelnes Teil an den Stats aendern wuerde -- fuer die Delta-Anzeige
## beim Hovern in der Werkstatt. Gibt nur die Felder zurueck, die sich
## tatsaechlich unterscheiden.
func preview_delta(slot: String, candidate_id: StringName) -> Dictionary:
	var before := stats()
	var probe := clone()
	if candidate_id == &"":
		probe.slots.erase(slot)
	else:
		probe.slots[slot] = candidate_id
	# Ein Chassiswechsel kann Ausruestungsslots wegnehmen. Was nicht mehr
	# passt, faellt ab -- sonst zeigte die Vorschau Werte fuer einen Aufbau,
	# den man so gar nicht bauen kann.
	probe._drop_invalid_equipment()
	var after := probe.stats()

	var delta := {}
	for key in after:
		if after[key] != before[key]:
			delta[key] = {"before": before[key], "after": after[key]}
	return delta


func _drop_invalid_equipment() -> void:
	var chassis := body()
	if chassis == null:
		for slot in slots.keys():
			if str(slot).begins_with("equip_"):
				slots.erase(slot)
		return
	var allowed := chassis.equip_slots()
	for slot in slots.keys():
		if not str(slot).begins_with("equip_"):
			continue
		if slot not in allowed:
			slots.erase(slot)
			continue
		var part := part_in(slot)
		if part != null and not chassis.accepts(part, slot):
			slots.erase(slot)


func clone() -> DromeBuild:
	var copy := DromeBuild.new()
	copy.display_name = display_name
	copy.slots = slots.duplicate()
	copy.palette = palette.duplicate(true)
	copy.direction = direction
	return copy


# ---------------------------------------------------------------------------
# Validierung
# ---------------------------------------------------------------------------

## Alle verletzten Regeln im Klartext. Leer = gueltig.
## Die UI zeigt diese Liste unveraendert an: der Spieler soll nicht raten,
## welche der vier Regeln bricht.
func validate() -> Array[String]:
	var problems: Array[String] = []

	for slot in SOCKET_SLOTS:
		if part_in(slot) == null:
			problems.append("%s fehlt" % _slot_label(slot))

	if weapons().is_empty():
		problems.append("Keine Waffe bestueckt")

	var chassis := body()
	if chassis != null:
		for slot in equip_slots():
			var part := part_in(slot)
			if part != null and not chassis.accepts(part, slot):
				problems.append("%s passt nicht in %s"
					% [part.display_name, _slot_label(slot)])

	var total := stats()
	if total["weight"] > total["weight_capacity"]:
		problems.append("Traglast ueberschritten: %d / %d"
			% [total["weight"], total["weight_capacity"]])
	if total["power_draw"] > total["power_output"]:
		problems.append("Energiebedarf zu hoch: %d / %d"
			% [total["power_draw"], total["power_output"]])
	if total["mov"] < 1:
		problems.append("Bewegung zu gering: mov %d (mindestens 1)" % total["mov"])
	if total["spd"] < 1:
		problems.append("Geschwindigkeit zu gering: spd %d (mindestens 1)" % total["spd"])

	return problems


func is_valid() -> bool:
	return validate().is_empty()


func _slot_label(slot: String) -> String:
	match slot:
		"body": return "Chassis"
		"head": return "Sensorik"
		"feet": return "Antrieb"
		"core": return "Kern"
		"equip_left": return "Ausruestung links"
		"equip_right": return "Ausruestung rechts"
		"equip_shoulder": return "Schulterhalterung"
		"equip_center": return "Zentralhalterung"
		_: return slot


# ---------------------------------------------------------------------------
# Kampfwert
# ---------------------------------------------------------------------------

## Errechnete Staerke eines Aufbaus. Basis fuers Gegner-Matching im
## Chaos-Virus: das Gegnersquad wird so lange neu gewuerfelt, bis sein Wert
## nahe genug am Spielersquad liegt.
##
## NICHT zu verwechseln mit der Aggro (scripts/battle/aggro_table.gd). Der
## Kampfwert beschreibt, wie stark ein Aufbau IST, und existiert vor dem
## Gefecht; Aggro beschreibt, wie sehr eine Einheit einen bestimmten Gegner
## stoert, und entsteht erst im Gefecht aus Aktionen. Beide hiessen einmal
## "Threat" -- daher die ausdrueckliche Notiz.
func power_score() -> float:
	var total := stats()
	var best_weapon := 0
	for part in equipment():
		if part.action != null and part.action.power > best_weapon:
			best_weapon = part.action.power
	return (
		float(total["hp_max"]) * 1.0
		+ float(total["atk"]) * 6.0
		+ float(total["def"]) * 8.0
		+ float(total["spd"]) * 3.0
		+ float(total["mov"]) * 4.0
		+ float(total["en_max"]) * 0.5
		+ float(best_weapon) * 2.0
	)


static func squad_power(builds: Array) -> float:
	var total := 0.0
	for build in builds:
		total += build.power_score()
	return total


# ---------------------------------------------------------------------------
# Persistenz -- dasselbe Loadout-Format, das die SVG-Werkstatt exportiert
# ---------------------------------------------------------------------------

func to_loadout() -> Dictionary:
	var chassis := body()
	var slot_payload := {}
	for slot in slots:
		var part := part_in(slot)
		if part == null:
			continue
		slot_payload[slot] = {
			"part_id": str(part.id),
			"code": part.code,
			"name": part.display_name,
		}
	return {
		"name": display_name,
		"set": chassis.set_id if chassis != null else "",
		"direction": direction,
		"palette": palette,
		"slots": slot_payload,
	}


static func from_loadout(loadout: Dictionary) -> DromeBuild:
	if not loadout is Dictionary:
		return null
	var build := DromeBuild.new()
	build.display_name = loadout.get("name", "DROME")
	build.direction = loadout.get("direction", "south")
	build.palette = loadout.get("palette", {})
	for slot in loadout.get("slots", {}):
		var entry = loadout["slots"][slot]
		var part_id = entry.get("part_id", "") if entry is Dictionary else entry
		if part_id == null or str(part_id) == "":
			continue
		if not PartDB.has_part(StringName(part_id)):
			push_warning("DromeBuild: unbekanntes Teil %s in Slot %s uebersprungen"
				% [part_id, slot])
			continue
		build.slots[slot] = StringName(part_id)
	return build


func _to_string() -> String:
	var total := stats()
	return "DromeBuild(%s hp=%d spd=%d mov=%d)" % [
		display_name, total["hp_max"], total["spd"], total["mov"]]
