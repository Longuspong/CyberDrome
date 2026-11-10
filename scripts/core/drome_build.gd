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

## Chassis-BIOS (MODULE_KONZEPT.md 6.5, nur im Lauf): +1 Modulplatz und eine
## verstaerkte Passive. ``bios_slot``: der Halter mit dem Extraplatz (Molok,
## zwei Halter); leer = der einzige Halter.
var chassis_bios: bool = false
var bios_slot: String = ""

## Level (6g, 8. Nov. 2026): DROME 0-5, je Waffenhalter das Level der Waffe
## darin (0-10). Kommen aus dem Hangar (Roster.build_for); Gegner haben 0.
var drome_level: int = 0
var weapon_levels: Dictionary = {}

## Herkunft im Hangar, damit EP aus dem Lauf zurueckfinden: die uid des
## Chassis-Exemplars (= der DROME) und je Halter die uid der Waffe.
var source_uid: String = ""
var instance_uids: Dictionary = {}


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

	# Level: DROME-Werte des Chassis und Bonus-Werte der Waffen.
	var chassis := body()
	if chassis != null and drome_level > 0:
		_add_stats(total, Leveling.drome_bonus(chassis, drome_level))
		total["module_slots"] += Leveling.extra_module_slots(chassis.id, drome_level)
	for slot in equip_slots():
		if weapon_level(slot) > 0:
			_add_stats(total, Leveling.weapon_bonus(part_in(slot), weapon_level(slot)))

	# Module (nur im Lauf): Panzerung, Schild und Konter des Traegers.
	if not modules.is_empty():
		var fx := all_module_effects()
		total["def"] += int(fx.get("def", 0))
		total["shield"] += int(fx.get("shield", 0))
		total["thorns"] = int(fx.get("thorns", 0))
		total["thorns_melee"] = int(fx.get("thorns_melee", 0))
		total["shield_delay"] = float(fx.get("shield_delay", 0.0))
		total["retaliation"] = float(fx.get("retaliation", 0.0))
		# Konter, die am Traeger haengen (nicht an einer Waffe): Splitterpanzer,
		# Brandmarke, Entladung. Der Zusatztreffer der Stacheln nutzt den
		# Doppellauf des Traegers.
		total["thorns_true"] = bool(fx.get("thorns_true", false))
		total["mark_on_hit_taken"] = float(fx.get("mark", 0.0)) \
			if bool(fx.get("mark_on_hit_taken", false)) else 0.0
		total["shield_break_burst"] = int(fx.get("shield_break_burst", 0))
		total["thorn_ricochet"] = float(fx.get("ricochet_chance", 0.0)) \
			if bool(fx.get("thorns_true", false)) else 0.0
		total["thorn_ricochet_share"] = float(fx.get("ricochet_share", 0.25))
		# BIOS-Rezepte am Traeger: Berserker, Treibjagd.
		total["retaliation_max"] = int(fx.get("retaliation_max", 3))
		total["berserk"] = bool(fx.get("berserk", false))
		total["mark_hunt"] = bool(fx.get("mark_hunt", false))

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


## Zuwaechse (Schluessel wie in PartData) auf die Summe: hp -> hp_max.
static func _add_stats(total: Dictionary, bonus: Dictionary) -> void:
	for stat in bonus:
		var key := "hp_max" if stat == "hp" else str(stat)
		total[key] = total.get(key, 0) + bonus[stat]


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
	copy.chassis_bios = chassis_bios
	copy.bios_slot = bios_slot
	copy.drome_level = drome_level
	copy.weapon_levels = weapon_levels.duplicate()
	copy.source_uid = source_uid
	copy.instance_uids = instance_uids.duplicate()
	return copy


## Das Level der Waffe in diesem Halter.
func weapon_level(slot: String) -> int:
	return int(weapon_levels.get(slot, 0))


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

## Der Kampfwert: wie viel ein Aufbau im Kampf wert ist. 100 = der
## Durchschnitt der vier Standard-DROMEs.
##
##     Kampfwert = POWER_SCALE * Wurzel(Standhaftigkeit * Feuerkraft)
##
##   Standhaftigkeit  Integritaet mal Ruestungsfaktor, dazu der Schild
##                    (dreifach: er laedt nach) und was der DROME je Sekunde
##                    repariert oder an Schild gibt.
##   Feuerkraft       Schaden je Sekunde jeder Waffe (Angriffe und Faehigkeit
##                    im Takt, mit Power, Level und Modulen) MAL ihrer
##                    Reichweite, dazu Betaeubung und Stacheln.
##
## ### Warum so (10. Nov. 2026)
##
## Die alte Formel zaehlte Integritaet + 8 x Ruestung + 3 x Speed + den
## staerksten Einzeltreffer. Damit stand der Molok immer oben (viel
## Integritaet), und eine schnelle Waffe zaehlte weniger als eine langsame,
## harte. Gemessen an 1500 Kaempfen zufaelliger Squads gewann die Seite mit
## dem hoeheren Wert nur in 65 % der Faelle -- selbst bei ueber 25 % Abstand
## nur in 74 %. Diese Formel ist an 2500 Kaempfe angepasst und an 1500 anderen
## geprueft: 80 % insgesamt, 94 % bei ueber 25 % Abstand
## (tools/playtest/power_bench.gd). Die Gewichte stehen in POWER_WEIGHTS.
##
## Was sie nicht kann: Zusammenspiel. Ein Molok ist allein wenig wert und
## macht einen Strix dahinter erst stark; der Wert eines Squads ist hier
## trotzdem die Summe seiner DROMEs.
const POWER_SCALE := 0.979
const POWER_WEIGHTS := {
	"shield": 3.0,          # ein Punkt Schild gegen einen Punkt Integritaet
	"support": 20.0,        # Reparatur/Schildgabe je Sekunde als Standhaftigkeit
	"attack_heal": 2.0,     # Heil-Angriff (Schraubenschluessel) gegen Faehigkeit
	"stun": 15.0,           # Sekunden Betaeubung je Sekunde als Feuerkraft
	"soft_control": 0.3,    # Verlangsamen/Wurzeln/Verwundbar gegen Betaeubung
	"thorns": 6.0,          # Stacheln je Punkt
	"moving": 0.5,          # Anteil der Zeit, in der der Bewegungsbonus gilt
}


func power_score() -> float:
	var parts := power_parts()
	return POWER_SCALE * sqrt(float(parts["staying"]) * float(parts["firepower"]))


## Die zwei Haelften des Kampfwerts: {staying, firepower}.
func power_parts() -> Dictionary:
	var total := stats()
	var weights := POWER_WEIGHTS
	var armor := float(total["def"])
	var staying := float(total["hp_max"]) * ActionResolver.armor_multiplier(armor) \
		+ float(total["shield_max"]) * float(weights["shield"])
	var firepower := 0.0
	var support := 0.0
	var control := 0.0
	var factor := power_factor()
	var chassis := body()
	var echo := chassis != null and chassis.passive == "echo"
	var slower := float((Config.section("passives").get("echo", {}) as Dictionary).get("slower", 1.5))
	for slot in equip_slots():
		var part := part_in(slot)
		if part == null:
			continue
		var fx := module_effects(slot)
		var level := weapon_level(slot)
		var attack: ActionData = null
		var ability: ActionData = null
		for action in part.actions:
			var tuned: ActionData = Leveling.level_action(action, part, level).with_modules(fx)
			if tuned.is_attack():
				if attack == null:
					attack = tuned
			elif tuned.trigger_kind == "attacks":
				ability = tuned
		if attack == null or attack.interval <= 0.0:
			continue
		var hit := _expected_damage(attack, factor, total)
		var per_attack := hit
		if ability != null:
			# Jeder N-te Angriff IST die Faehigkeit; Echo: seltener, zweimal.
			var every := float(ability.trigger_every)
			var times := 1.0
			if echo:
				every = round((every - 1.0) * slower) + 1.0
				times = 2.0
			every = maxf(1.0, every / maxf(1.0, float(fx.get("takt_count", 1.0))))
			per_attack = ((every - 1.0) * hit + times * _expected_damage(ability, factor, total)) / every
			var cycle := every * attack.interval
			support += times * float(ability.heal + ability.shield_gain) / cycle
			var seconds := float(ability.status.get("seconds", 0.0))
			match str(ability.status.get("id", "")):
				"stun":
					control += times * seconds / cycle
				"slow", "vulnerable", "root":
					control += float(weights["soft_control"]) * times * seconds / cycle
		firepower += per_attack / attack.interval * float(maxi(1, attack.range_tiles))
		support += float(weights["attack_heal"]) * float(attack.heal) / attack.interval
	firepower += control * float(weights["stun"]) + float(total.get("thorns", 0)) * float(weights["thorns"])
	staying += support * float(weights["support"])
	return {"staying": staying, "firepower": maxf(0.1, firepower)}


## Erwarteter Schaden eines Ausloesens: Staerke mal Treffer mal Power, dazu
## der Anteil der eigenen Integritaet (Bollwerk-Ramme) und der halbe
## Bewegungsbonus (Klingenbumerang).
func _expected_damage(action: ActionData, factor: float, total: Dictionary) -> float:
	var damage := float(action.power * maxi(1, action.shots)) * factor \
		+ action.hp_scaling * float(total["hp_max"])
	return damage * (1.0 + float(POWER_WEIGHTS["moving"]) * action.moving_bonus)


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


## Spielstand eines Lauf-DROME (10. Nov. 2026): das Loadout plus alles, was
## nur im Lauf dazukommt (Module, Chassis-BIOS) und was ihn mit dem Hangar
## verbindet (Level, Exemplar-uids).
func to_save() -> Dictionary:
	var out := to_loadout()
	var mods := {}
	for slot in modules:
		mods[slot] = (modules[slot] as Array).map(func(id): return str(id))
	out["modules"] = mods
	out["drome_level"] = drome_level
	out["weapon_levels"] = weapon_levels.duplicate()
	out["source_uid"] = source_uid
	out["instance_uids"] = instance_uids.duplicate()
	out["chassis_bios"] = chassis_bios
	out["bios_slot"] = bios_slot
	return out


static func from_save(data: Dictionary) -> DromeBuild:
	var build := from_loadout(data)
	if build == null:
		return null
	for slot in data.get("modules", {}):
		build.modules[slot] = (data["modules"][slot] as Array).map(func(id): return StringName(str(id)))
	build.drome_level = int(data.get("drome_level", 0))
	for slot in data.get("weapon_levels", {}):
		build.weapon_levels[slot] = int(data["weapon_levels"][slot])
	build.source_uid = str(data.get("source_uid", ""))
	for slot in data.get("instance_uids", {}):
		build.instance_uids[slot] = str(data["instance_uids"][slot])
	build.chassis_bios = bool(data.get("chassis_bios", false))
	build.bios_slot = str(data.get("bios_slot", ""))
	return build


func _to_string() -> String:
	var total := stats()
	return "DromeBuild(%s hp=%d spd=%d)" % [
		display_name, total["hp_max"], total["spd"]]
