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
##     core   Pflicht, fest am Chassis wie Kopf und Fuesse. Seit 6g nur Optik.
##     feet   Pflicht. Der Antrieb bringt das Tempo (SPD).
##     head   Pflicht. Sensorik.
##     equip_* Variabel: zwei beim Vireo, drei beim Molok, genau einer beim
##            Strix. Ein Chassis bekommt einen weiteren Slot, indem es einen
##            weiteren Anker in seine JSON schreibt -- kein Sonderfall im Code.

## Ein DROME hat keine Grundwerte. Jeder Stat ist die Summe seiner Teile.
const SOCKET_SLOTS := ["body", "head", "feet", "core"]

## ### Keine Bau-Budgets
##
## Frueher deckelten Traglast und Strombedarf den Aufbau; beide sind gestrichen,
## ebenso die Energie (Echtzeit-Kampf, Nov. 2026) und seit 8. Nov. 2026 das
## Gewicht -- die Halterklasse reicht. Die natuerliche Grenze ist ``spd >= 1``
## in ``structural_problems()``.

var display_name: String = "DROME"

## slot -> part_id. Slots ohne Eintrag sind leer.
var slots: Dictionary = {}

## Optional: abweichende Palette je Slot, wie die Werkstatt sie exportiert.
var palette: Dictionary = {}

## Blickrichtung fuer die Darstellung
var direction: String = "south"

## Module im Lauf (NEUANFANG 6g): Waffenhalter -> Modul-IDs. Sie gehoeren zum
## Halter, nicht zur Waffe: wer die Waffe tauscht, behaelt die Module. Passt
## die Waffe nicht zur Bedingung eines Moduls, ruht es. Nur Lauf-Kopien
## tragen Module; der Hangar zuhause kennt keine (sie verfallen nach dem Lauf).
var modules: Dictionary = {}


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


## Setzt das ganze Chassis auf einmal: Koerper, Kopf und Fuesse aus dem Set des
## uebergebenen Koerper-Teils. Kopf, Fuesse und Kern werden nie einzeln
## gewaehlt -- das Chassis ist eine Huelle (GAME_DESIGN §9). Der Kern ist seit
## 6g nur noch Optik ohne Werte. Die Ausruestung bleibt unberuehrt.
func apply_chassis(body_id: StringName) -> void:
	var chassis := PartDB.get_part(body_id)
	if chassis == null or chassis.type != PartData.Type.BODY:
		return
	slots["body"] = chassis.id
	for type in [PartData.Type.HEAD, PartData.Type.FEET, PartData.Type.CORE]:
		var mate := PartDB.frame_mate(chassis.set_id, type)
		if mate != null:
			slots[mate.slot_name()] = mate.id


## Alle belegten Teile, Sockel und Ausruestung gemeinsam.
## Alle Teile, die WIRKEN: die vier Sockel und die Ausruestung in echten
## Haltern. Ein Teil an einem abgeschalteten Anker (``off``) zaehlt nicht --
## structural_problems() meldet es.
func all_parts() -> Array:
	var result: Array = []
	for slot in SOCKET_SLOTS:
		var part := part_in(slot)
		if part != null:
			result.append(part)
	result.append_array(equipment())
	return result


## Die Ausruestungsslots dieses DROME -- die equip_*-Anker seines Chassis,
## ohne die abgeschalteten. Ohne Chassis gibt es keine.
func equip_slots() -> Array[String]:
	var chassis := body()
	if chassis == null:
		return []
	return chassis.equip_slots()


## In welchen Slot gehoert dieses Teil?
##
## Sockelteile in ihren Sockel. Ausruestung in ``preferred``, wenn dieser
## Halter sie nimmt -- sonst in den ersten freien passenden, sonst in den
## ersten passenden ueberhaupt. Leerer String heisst: nirgendwo, dieses Chassis
## hat keinen Halter dafuer.
##
## Dieselbe Reihenfolge wie in der SVG-Werkstatt (README: "angewaehlter Slot,
## sonst erster freier"), damit ein Klick in beiden Werkstaetten dasselbe tut.
## Steht hier und nicht in der Oberflaeche, weil es eine Aussage ueber den
## Aufbau ist und nicht ueber die Bedienung -- und weil es sich hier ohne
## laufende Szene pruefen laesst.
func slot_for(part: PartData, preferred: String = "") -> String:
	if part == null:
		return ""
	if part.type != PartData.Type.EQUIPMENT:
		return part.slot_name()
	var chassis := body()
	if chassis == null:
		return ""
	var slots := equip_slots()
	if preferred in slots and chassis.accepts(part, preferred):
		return preferred
	for slot in slots:
		if chassis.accepts(part, slot) and part_in(slot) == null:
			return slot
	for slot in slots:
		if chassis.accepts(part, slot):
			return slot
	return ""


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


## Alle Aktionen, die dieser Aufbau gewaehrt -- jede genau einmal. Eine Waffe
## steuert zwei bei (Angriff und Faehigkeit), ein Gadget null oder eine.
##
## ### Warum zweimal dasselbe Teil nicht zwei Eintraege ergibt
##
## Die Aktionsliste entdoppelt ueber die Aktions-ID. Im Kampf laedt trotzdem
## jede Waffe (je Teil) fuer sich nach -- zwei Blaster schiessen doppelt.
##
## Der doppelte Anbau bleibt sinnvoll -- Stats summieren sich weiter (zwei
## Fokusse sind +2 ATK), nur die Aktionsliste entdoppelt ueber die Aktions-ID:
## zwei verschiedene Teile mit derselben Aktion sind dieselbe Aktion.
func actions() -> Array:
	var result: Array = []
	var seen := {}
	for part in all_parts():
		for action in part.actions:
			if seen.has(action.id):
				continue
			seen[action.id] = true
			result.append(action)
	# Faehigkeiten aus Modulen (Orbit-Fokus, Hologramm-Boost), solange sie wirken.
	if not modules.is_empty():
		for slot in equip_slots():
			for module in active_modules(slot):
				if module.gadget == &"" or seen.has(module.gadget):
					continue
				var granted := ModuleData.gadget_action(module.gadget)
				if granted != null:
					seen[granted.id] = true
					result.append(granted)
	return result


## Die WAFFEN dieses Aufbaus tragen je einen Angriffs-Aktionspunkt bei: zwei
## Waffen, zwei Angriffe (GAME_DESIGN §13). Gezaehlt werden die Waffen-TEILE,
## nicht die verschiedenen Angriffe -- zwei gleiche Blaster sind zwei Schuss,
## obwohl es derselbe Angriff ist.
func attack_budget() -> int:
	return weapons().size()


## Die Aktionen einer Kategorie. Angriff und Faehigkeit sind getrennte Budgets
## und werden dem Spieler deshalb auch getrennt gezeigt.
func actions_of(category: ActionData.Category) -> Array:
	return actions().filter(func(action): return action.category == category)


# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------

## Summiert alles. Einzige Stelle, an der Stats entstehen.
func stats() -> Dictionary:
	var total := {
		"hp_max": 0,
		"spd": 0, "def": 0, "power": 0, "shield_pulse": 0, "module_slots": 0,
		"shield": 0, "shield_regen": 0, "shield_bonus": 0.0, "shield_max": 0,
		"hp_regen_pct": 0,
		"lure_radius": 0,
	}
	for part in all_parts():
		total["hp_max"] += part.hp
		total["spd"] += part.spd
		total["power"] += part.power
		total["shield_pulse"] += part.shield_pulse
		total["module_slots"] = maxi(int(total["module_slots"]), part.module_slots)
		total["def"] += part.def
		total["shield"] += part.shield
		total["shield_regen"] += part.shield_regen
		total["shield_bonus"] += part.shield_bonus
		total["hp_regen_pct"] += part.hp_regen_pct
		total["lure_radius"] = maxi(int(total["lure_radius"]), part.lure_radius)

	# Module (nur im Lauf): Panzerung, Schild und Konter des Traegers.
	if not modules.is_empty():
		var fx := all_module_effects()
		total["def"] += int(fx.get("def", 0))
		total["shield"] += int(fx.get("shield", 0))
		total["thorns"] = int(fx.get("thorns", 0))
		total["shield_delay"] = float(fx.get("shield_delay", 0.0))
		total["retaliation"] = float(fx.get("retaliation", 0.0))

	# Negative Summen sind sinnlos, aber ein DROME darf sie erreichen -- die
	# Validierung faengt das ab und sagt dem Spieler, welche Regel bricht.
	total["hp_max"] = maxi(0, total["hp_max"])
	total["def"] = maxi(0, total["def"])
	total["power"] = maxi(0, total["power"])
	total["shield_pulse"] = maxi(0, total["shield_pulse"])
	total["shield"] = maxi(0, total["shield"])
	# Das Schild-Maximum ist der Grundwert mal der prozentualen Schild-Effizienz
	# des Kerns (§11): shield_max = shield * (1 + shield_bonus). Der Bonus ist
	# ein Anteil (0.1 = +10 %).
	total["shield_max"] = int(round(float(total["shield"]) * (1.0 + total["shield_bonus"])))
	return total


## Power als Faktor: 10 Punkte = 100 % Waffenschaden (8. Nov. 2026). Ohne
## Power-Wert (alte Daten) gilt 100 %.
func power_factor() -> float:
	var points := int(stats().get("power", 0))
	return 1.0 if points <= 0 else float(points) / 10.0


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
	copy.modules = modules.duplicate(true)
	return copy


# ---------------------------------------------------------------------------
# Module (nur im Lauf)
# ---------------------------------------------------------------------------

## Die Module in diesem Halter, als ModuleData (unbekannte fallen weg).
func modules_in(slot: String) -> Array:
	var out: Array = []
	for module_id in modules.get(slot, []):
		var module := ModuleData.get_module(module_id)
		if module != null:
			out.append(module)
	return out


## Die Module, die gerade WIRKEN: ihre Bedingung passt zur Waffe im Halter.
func active_modules(slot: String) -> Array:
	var weapon := part_in(slot)
	return modules_in(slot).filter(func(m): return m.fits(weapon))


## Summe der Wirkungen aller wirkenden Module eines Halters.
func module_effects(slot: String) -> Dictionary:
	var total := {}
	for module in active_modules(slot):
		total = ModuleData.add_effects(total, module.effects)
	return total


## Die Wirkungen aller Halter zusammen -- fuer Werte des Traegers.
func all_module_effects() -> Dictionary:
	var total := {}
	for slot in equip_slots():
		total = ModuleData.add_effects(total, module_effects(slot))
	return total


func module_count(slot: String) -> int:
	return (modules.get(slot, []) as Array).size()


# ---------------------------------------------------------------------------
# Validierung
# ---------------------------------------------------------------------------

## Alle verletzten Regeln im Klartext. Leer = gueltig. Die UI zeigt diese Liste
## unveraendert an: der Spieler soll nicht raten, welche der Regeln bricht.
##
## Seit die beiden Bau-Budgets gestrichen sind (siehe Klassenkommentar), ist
## Validierung reine Struktur: was ein DROME sein MUSS, um im Kampf zu handeln.
## Gewicht und Energie sind keine Grenzen mehr, sondern Preise (Tempo, Mana).
func validate() -> Array[String]:
	return structural_problems()


## Was ein DROME sein MUSS, damit er im Kampf handeln kann. Diese Liste haengt
## nicht am Playtest-Schalter -- ohne Antrieb kommt niemand vom Feld, und ein
## Teil im falschen Halter haengt sichtbar in der Luft.
##
## ### Warum "keine Waffe" hier NICHT mehr steht
##
## Ein Aufbau ohne Waffe war frueher ungueltig. Das nahm dem Slotmodell aber
## genau die Aussage, fuer die es da ist: welche Aktionen ein DROME hat, sagt
## seine Ausruestung -- und wer Schraubenschluessel und Reparaturdrohnen traegt,
## hat eben keinen Angriff. Das ist eine Entscheidung mit Folgen, keine Panne.
##
## Wer sein ganzes Squad so baut, gewinnt kein Gefecht mehr -- das ist dann
## seine Rechnung. Der Gegnergenerator setzt weiter garantiert eine Waffe, damit
## dieselbe Freiheit nicht als unentscheidbares Gefecht auf den Spieler
## zurueckfaellt (siehe EnemyGenerator._roll).
func structural_problems() -> Array[String]:
	var problems: Array[String] = []

	for slot in SOCKET_SLOTS:
		if part_in(slot) == null:
			problems.append("%s fehlt" % _slot_label(slot))

	# Der Rahmen ist eine HUELLE: Kopf, Koerper und Fuesse stammen aus einem Set
	# und werden gemeinsam gewaehlt, nie einzeln getauscht (GAME_DESIGN §9). So
	# gibt es keinen Strix-Kopf auf Molok-Beinen mehr. Der Kern bleibt frei --
	# er ist die Stil-Achse, kein Rahmen (§9b, §9i).
	var frame_sets := {}
	for slot in ["body", "head", "feet"]:
		var part := part_in(slot)
		if part != null:
			frame_sets[part.set_id] = true
	if frame_sets.size() > 1:
		problems.append("Rahmen ist keine Huelle: Kopf, Koerper und Fuesse "
			+ "stammen aus verschiedenen Saetzen")

	var chassis := body()
	if chassis != null:
		var holders := equip_slots()
		for slot in slots:
			if str(slot) in SOCKET_SLOTS or str(slot) in holders:
				continue
			var stray := part_in(slot)
			if stray != null:
				problems.append("%s: %s hat keinen Halter mehr"
					% [stray.display_name, _slot_label(slot)])
		for slot in holders:
			var part := part_in(slot)
			if part != null and not chassis.accepts(part, slot):
				problems.append("%s passt nicht in %s"
					% [part.display_name, _slot_label(slot)])

	var total := stats()
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
func power_score() -> float:
	var total := stats()
	var best_weapon := 0
	for part in equipment():
		for action in part.actions:
			if action.power > best_weapon:
				best_weapon = action.power
	return (
		float(total["hp_max"]) * 1.0
		+ float(total["def"]) * 8.0
		+ float(total["spd"]) * 3.0
		+ float(best_weapon) * 2.0 * power_factor()
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
	return "DromeBuild(%s hp=%d spd=%d)" % [
		display_name, total["hp_max"], total["spd"]]
