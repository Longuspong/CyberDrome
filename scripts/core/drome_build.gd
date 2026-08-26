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
##     core   Pflicht. Traegt den Energietank (en_max/en_regen), aus dem
##            Faehigkeiten im Kampf bezahlt werden.
##     feet   Pflicht. Ohne Antrieb ist mov 0.
##     head   Pflicht. Sensorik.
##     equip_* Variabel: zwei beim Vireo, drei beim Molok, genau einer beim
##            Strix. Ein Chassis bekommt einen weiteren Slot, indem es einen
##            weiteren Anker in seine JSON schreibt -- kein Sonderfall im Code.

## Ein DROME hat keine Grundwerte. Jeder Stat ist die Summe seiner Teile.
const SOCKET_SLOTS := ["body", "head", "feet", "core"]

## ### Warum es keine Bau-Budgets mehr gibt
##
## Frueher deckelten zwei Grenzen den Aufbau: die Traglast (Gewicht gegen
## ``weight_capacity``) und der Energiebedarf (``power_draw`` gegen
## ``power_output`` des Kerns). Beide blockierten das Bauen -- und beide
## produzierten Unsinn: ein Vireo mit zwei Puls-Blastern riss die Traglast um
## EINEN Punkt (19/18), der offensichtlichste Standard-Aufbau der Welt liess
## sich nicht bauen. Aus Spielersicht war das kaputt.
##
## Die beiden Deckel sind darum gestrichen. Energie ist jetzt reines Mana
## (``en_max`` / ``en_regen`` / ``en_cost`` einer Aktion), und Gewicht ist
## reines Tempo (``payload_slowdown`` zieht SPD ab). Was frueher ein harter
## Riegel war, ist jetzt ein weicher Preis: der teure Aufbau ist baubar, aber
## langsam und energiehungrig -- moeglich, nur nicht optimal.
##
## Die natuerliche Grenze ist damit ``spd >= 1`` / ``mov >= 1`` in
## ``structural_problems()``: man kann Masse stapeln, bis der DROME festfaehrt,
## dann bewegt er sich nicht mehr und ist ungueltig. Kein Zahlendeckel, sondern
## eine Regel, die man fuehlt.

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


## Setzt das ganze Chassis auf einmal: Koerper, Kopf und Fuesse aus dem Set des
## uebergebenen Koerper-Teils. Kopf und Fuesse werden nie einzeln gewaehlt -- das
## Chassis ist eine Huelle (GAME_DESIGN §9). Der Kern und die Ausruestung bleiben
## unberuehrt: der Kern ist universal, die Ausruestung eine eigene Entscheidung.
func apply_chassis(body_id: StringName) -> void:
	var chassis := PartDB.get_part(body_id)
	if chassis == null or chassis.type != PartData.Type.BODY:
		return
	slots["body"] = chassis.id
	for type in [PartData.Type.HEAD, PartData.Type.FEET]:
		var mate := PartDB.frame_mate(chassis.set_id, type)
		if mate != null:
			slots[mate.slot_name()] = mate.id


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
## Zwei Orbit-Fokusse gaben frueher zweimal "Orbit-Sog" in Aktionsleiste und
## Aktionsring. Das war keine zweite Moeglichkeit, sondern eine doppelte Zeile
## fuer dieselbe Faehigkeit: eine Faehigkeit laesst sich ohnehin nur einmal pro
## Zug ziehen (TurnState), der zweite Eintrag versprach eine Wahl, die es nicht
## gab.
##
## Beim ANGRIFF ist das anders: zwei Waffen sind zwei Angriffe pro Zug
## (GAME_DESIGN §13). Das trennt aber das BUDGET, nicht die Aktionsliste -- die
## Zeile "Puls-Salve" steht auch bei zwei Blastern nur einmal da, das
## Angriffsbudget (siehe TurnState.attack_actions) zaehlt dagegen beide.
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
	return result


## Die WAFFEN dieses Aufbaus tragen je einen Angriffs-Aktionspunkt bei: zwei
## Waffen, zwei Angriffe (GAME_DESIGN §13). Gezaehlt werden die Waffen-TEILE,
## nicht die verschiedenen Angriffe -- zwei gleiche Blaster sind zwei Schuss,
## obwohl es dieselbe Puls-Salve ist.
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
		"hp_max": 0, "en_max": 0, "en_regen": 0,
		"spd": 0, "mov": 0, "atk": 0, "def": 0,
		"weight": 0, "power_draw": 0,
		"weight_capacity": 0, "power_output": 0,
		"can_pass_units": false, "can_enter_steps": false,
		"can_pass_blocks": false, "ignores_drift": false,
		"drift_modifier": 0, "step_cost_reduced": false,
		"grants_ignore_haze": false,
		"hp_regen_pct": 0,
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
		total["hp_regen_pct"] += part.hp_regen_pct
		total["aggro_bonus"] += part.aggro_bonus

	total["spd"] -= payload_slowdown()

	# Negative Summen sind sinnlos, aber ein DROME darf sie erreichen -- die
	# Validierung faengt das ab und sagt dem Spieler, welche Regel bricht.
	total["hp_max"] = maxi(0, total["hp_max"])
	total["en_max"] = maxi(0, total["en_max"])
	total["def"] = maxi(0, total["def"])
	total["atk"] = maxi(0, total["atk"])
	return total


## Wie sehr die ZULADUNG bremst: je ``spd_weight_step`` Gewicht an Ausruestung
## ein Punkt SPD weniger.
##
## ### Warum die Masse und nicht die Energie
##
## Was ein Bauteil kostet, soll dem entsprechen, was es IST. Eine Pulverkanone
## zieht keinen Strom -- sie wiegt. Frueher trug sie ``power_draw`` 5, und der
## Energiebedarf war damit ein Universalhebel, der auf jedem Teil klebte, egal
## ob es physikalisch Strom braucht. Das war Balancing im Kostuem der Fiktion:
## der Spieler las "Energiebedarf" und konnte sich nichts darunter vorstellen.
##
## Jetzt gilt: **Masse bremst, Strom kostet.** Mechanische Teile (Kanone) zahlen
## in Gewicht und Tempo, energetische (Blaster, Lanze, Fokus) in Energie. Der
## schwere Slot bleibt die Erlaubnis, das Tempo ist der Preis.
##
## Gerechnet wird auf der AUSRUESTUNG, nicht auf dem Gesamtgewicht. Die Sockel
## sind der Rahmen -- ihr Gewicht traegt das Chassis per ``weight_capacity``, und
## der Antrieb sagt ueber sein eigenes ``spd`` schon, wie flink er ist. Zoege das
## Gesamtgewicht mit, bestrafte die Rechnung denselben Rahmen zweimal, und jeder
## voll ausgelastete Aufbau kaeme auf denselben Abzug -- die Formel wuerde
## aufhoeren, zwischen Kanone und Runenstab zu unterscheiden. Genau das ist aber
## ihr Zweck: dieselbe Waffe bremst an jedem Chassis gleich viel.
##
## Abgerundet, damit leichte Module (Gewicht 3) gratis bleiben und der Abzug
## erst bei echter Zuladung einsetzt.
func payload_slowdown() -> int:
	var step := Config.get_int("spd_weight_step", 4)
	if step <= 0:
		return 0
	var payload := 0
	for part in equipment():
		payload += part.weight
	return payload / step


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
## hat eben keinen Angriff. Das ist eine Entscheidung mit Folgen, keine Panne,
## und der Kampf traegt sie schon: ``TurnState`` vergibt das Angriffsbudget
## ohnehin nur an Aktionen, die es gibt, und die Aktionsleiste bleibt dann leer.
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
		for slot in equip_slots():
			var part := part_in(slot)
			if part != null and not chassis.accepts(part, slot):
				problems.append("%s passt nicht in %s"
					% [part.display_name, _slot_label(slot)])

	var total := stats()
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
		for action in part.actions:
			if action.power > best_weapon:
				best_weapon = action.power
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
