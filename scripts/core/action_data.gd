class_name ActionData
extends RefCounted

## Eine Aktion, die ein Bauteil gewaehrt. Passive Teile gewaehren keine.
##
## Schaden ist deterministisch: kein Trefferwurf, kein Krit, keine Ausweich-
## chance -- weder im MVP noch spaeter. Balancing laeuft ueber das WIE
## (Position, Reihenfolge, Ressourcen), nicht ueber das OB. Der Spieler soll
## jede Aktion vorher exakt durchrechnen koennen.

## ANGRIFF ist das, was eine Waffe in ihrem Takt tut; FAEHIGKEIT alles, was
## darueber hinausgeht und nach seinem Ausloeser kommt (trigger_*).
enum Category { ATTACK, ABILITY }

## AOE_AROUND_TARGET trifft den vollen Ring (Chebyshev-Radius, „8 angrenzende
## Felder" bei Radius 1). AOE_CROSS trifft nur ORTHOGONAL (Ziel + die geraden
## Nachbarn) -- die Kreuzform des Runenstabs („4 angrenzende Felder orthogonal").
##
## DASH ist die einzige BEWEGUNGS-Aktion: sie zielt auf ein LEERES Feld und
## versetzt den Handelnden selbst dorthin -- gerade Linie, ``range_tiles`` weit,
## und im Gegensatz zur normalen Bewegung ausdruecklich NICHT ueber Hindernisse
## oder Stufen (der Hologramm-Boost des Vireo). Kein Ziel-DROME, kein Schaden.
enum Targeting { SINGLE, SELF, TILE, AOE_AROUND_TARGET, AOE_CROSS, DASH }

const CATEGORY_NAMES := {"attack": Category.ATTACK, "ability": Category.ABILITY}
const CATEGORY_LABEL := {Category.ATTACK: "Angriff", Category.ABILITY: "Faehigkeit"}
const TARGETING_NAMES := {
	"single": Targeting.SINGLE,
	"self": Targeting.SELF,
	"tile": Targeting.TILE,
	"aoe_around_target": Targeting.AOE_AROUND_TARGET,
	"aoe_cross": Targeting.AOE_CROSS,
	"dash": Targeting.DASH,
}

## Schadensarten. Bis auf ``normal`` ist noch keine entschieden -- die
## Schadensordnung (Resistenzen, Anfaelligkeiten, Ruestungstypen) ist offen.
##
## Das Feld existiert trotzdem schon, und zwar mit genau einem Wert: solange
## jede Aktion "normal" ist, ist die Anzeige ehrlich und die spaetere Erweiterung
## kostet kein Umschreiben. ActionResolver._apply_armor() ist der Haken, an dem
## sie einmal haengt; im MVP reicht die Kette den Schaden dort unveraendert
## durch.
const DAMAGE_TYPE_LABEL := {&"normal": "normal"}

var id: StringName
var display_name: String
var category: Category = Category.ATTACK

## Wo diese Aktion herkommt. Rein fuer die Anzeige: der Spieler soll im Kampf
## sehen, welches Bauteil ihm diese Zeile gibt.
var source_part_name: String = ""
var source_part_code: String = ""

## Siehe DAMAGE_TYPE_LABEL. Im Bestand immer &"normal".
var damage_type: StringName = &"normal"

## Anteil des Schadens, der ENERGIESCHADEN ist (0.0 = ganz physisch, 1.0 = ganz
## Energie, 0.5 = halb/halb wie der Puls-Blaster). Energie knackt Schilde,
## Physisch prallt an ihnen ab -- siehe §11 und ActionResolver.resolve_damage().
var energy_fraction: float = 0.0
var targeting: Targeting = Targeting.SINGLE
var range_tiles: int = 1
var aoe_radius: int = 0

## > 0 Schaden, < 0 Heilung. Ein Vorzeichen statt zweier Felder, damit es nur
## eine Stelle gibt, an der ein Effekt seine Groesse hat.
var power: int = 0

var requires_line_of_sight: bool = false

## positiv = wegstossen, negativ = heranziehen
var push_tiles: int = 0

var status_effect = null

## Wie laut ist diese Aktion? Multiplikator auf die Aggro, die ihre Wirkung
## erzeugt (scripts/battle/aggro_table.gd). 1.0 ist die Grundlinie, alles
## andere ist relativ dazu zu lesen:
##
##     1.0   normaler Angriff -- die Baseline
##     0.5   Heilung: der Techniker ist angreifbar, aber kein Aggro-Magnet
##     0.35  Praezisionswaffen: viel Schaden, wenig Krach
##
## Steht ausdruecklich pro Aktion in den Bauteil-Daten und wird NICHT aus
## ``range_tiles`` abgeleitet. Eine Ableitung waere eine zweite, stillschweigende
## Wahrheit darueber, wie auffaellig eine Waffe ist -- und untunebar dazu.
var aggro_coeff: float = 1.0

## Pauschale Aggro fuer Aktionen ohne Wirkungsmenge. Der Orbit-Sog richtet
## keinen Schaden an, zerrt sein Ziel aber zwei Felder aus der Stellung; ohne
## diesen Wert waere ein reiner Kontroll-Aufbau vollkommen lautlos.
##
## Der einzige Teil der Formel, der NICHT mit der Schadenskurve mitskaliert --
## bei groesseren Balancing-Aenderungen also von Hand nachzuziehen.
var aggro_flat: int = 0

## > 0 macht die Aktion zu einer Provokation: das Ziel muss fuer so viele
## EIGENE Zuege den Verursacher angreifen. Harter Zwang, deshalb befristet.
var taunt_turns: int = 0

## Echtzeit (Nov. 2026): Sekunden zwischen zwei Angriffen dieser Waffe. Nur
## fuer Angriffe; jede Waffe laedt fuer sich nach.
var interval: float = 2.0

## Wann eine Faehigkeit von selbst ausloest. Faehigkeiten werden nicht mehr
## gezogen, sie kommen nach einer festen Regel:
##
##   attacks   jeder ``trigger_every``-te Angriff der Waffe ``trigger_weapon``
##             IST die Faehigkeit (sie ersetzt diesen Angriff).
##   time      alle ``trigger_every`` Sekunden, sobald ein Ziel in Reichweite ist.
##   adjacent  wenn ein Gegner direkt danebensteht, hoechstens alle
##             ``trigger_every`` Sekunden.
var trigger_kind: String = ""
var trigger_every: float = 0.0
var trigger_weapon: StringName = &""


## Wie lange eine Provokation haelt: ``taunt_turns`` zaehlt Pulse.
func taunt_seconds() -> int:
	return int(round(float(taunt_turns) * float(Config.section("realtime").get("pulse", 3.0))))


static func from_meta(meta: Dictionary, owner_name: String = "",
		owner_code: String = "") -> ActionData:
	var action := ActionData.new()
	action.id = StringName(meta.get("id", ""))
	action.display_name = meta.get("display_name", owner_name)
	action.source_part_name = owner_name
	action.source_part_code = owner_code
	action.damage_type = StringName(meta.get("damage_type", "normal"))
	action.category = CATEGORY_NAMES.get(meta.get("category", "attack"), Category.ATTACK)
	action.targeting = TARGETING_NAMES.get(meta.get("targeting", "single"), Targeting.SINGLE)
	action.range_tiles = meta.get("range_tiles", 1)
	action.aoe_radius = meta.get("aoe_radius", 0)
	action.power = meta.get("power", 0)
	action.requires_line_of_sight = meta.get("requires_line_of_sight", false)
	action.push_tiles = meta.get("push_tiles", 0)
	action.status_effect = meta.get("status_effect")
	action.aggro_coeff = float(meta.get("aggro_coeff", 1.0))
	action.aggro_flat = meta.get("aggro_flat", 0)
	action.taunt_turns = meta.get("taunt_turns", 0)
	action.energy_fraction = float(meta.get("energy_fraction", 0.0))
	action.interval = float(meta.get("interval", 2.0))
	var trigger = meta.get("trigger")
	if trigger is Dictionary:
		action.trigger_kind = str(trigger.get("kind", ""))
		action.trigger_every = float(trigger.get("every", 0.0))
		action.trigger_weapon = StringName(str(trigger.get("weapon", "")))
	return action


## Der Ausloeser in Klartext -- fuer Teil-Info und Kacheln.
func trigger_text() -> String:
	match trigger_kind:
		"attacks":
			return "jeder %d. Angriff" % int(trigger_every)
		"time":
			return "alle %s s" % _seconds(trigger_every)
		"adjacent":
			return "wenn ein Gegner direkt daneben steht (hoechstens alle %s s)" \
				% _seconds(trigger_every)
	return ""


static func _seconds(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return ("%.1f" % value).replace(".", ",")


func is_taunt() -> bool:
	return taunt_turns > 0


func is_attack() -> bool:
	return category == Category.ATTACK


## Eine Bewegungs-Aktion (Dash): sie versetzt den Handelnden selbst, statt ein
## Ziel zu treffen. Der Resolver behandelt sie deshalb in einem eigenen Zweig,
## und die Schadensvorschau meldet fuer sie 0.
func is_move() -> bool:
	return targeting == Targeting.DASH


func is_heal() -> bool:
	return power < 0


func heal_amount() -> int:
	return -power


func category_label() -> String:
	return CATEGORY_LABEL.get(category, "Aktion")


func damage_type_label() -> String:
	return DAMAGE_TYPE_LABEL.get(damage_type, str(damage_type))


## Was diese Aktion tut, wenn sie KEINE Wirkungsmenge hat -- Stossen, Ziehen,
## Provozieren. Steht dort, wo sonst die Schadenszahl steht: "0 Schaden" waere
## richtig gerechnet und trotzdem eine Falschauskunft ueber die Aktion.
func effect_summary() -> String:
	var parts: Array[String] = []
	if is_move():
		parts.append("Boost %d gerade" % range_tiles)
	if push_tiles > 0:
		parts.append("stoesst %d" % push_tiles)
	elif push_tiles < 0:
		parts.append("zieht %d heran" % absi(push_tiles))
	if is_taunt():
		parts.append("provoziert %d s" % taunt_seconds())
	if status_effect != null:
		parts.append("Effekt")
	return " · ".join(parts) if not parts.is_empty() else "ohne Schaden"


## Kurzform fuer eine Zeile: "Angriff · Rw 4 · EN 0".
##
## Genannt wird, was im aktuellen Bremsmodus tatsaechlich gilt. Ein "EN 35" an
## einer Aktion, die gerade gar keine Energie abbucht, waere eine Falschauskunft
## -- und zwar eine, nach der der Spieler seinen Kern aussucht.
func headline() -> String:
	var parts: Array[String] = [category_label(), "Rw %d" % range_tiles]
	return " · ".join(parts)


## Was diese Aktion tut, vollstaendig und in Klartext.
##
## Die EINE Beschreibung: Werkstatt-Tooltip, Aktionsleiste und Aktionsring
## lesen alle hier. Drei Texte fuer dieselbe Aktion waeren drei Gelegenheiten,
## dass einer davon eine Reichweite nennt, die nicht mehr stimmt -- und in
## einem Spiel, das verspricht, dass sich jede Aktion vorher durchrechnen
## laesst, ist eine falsche Tooltip-Zahl ein Regelfehler.
func description_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append("%s · Reichweite %d" % [category_label(), range_tiles])
	if is_move():
		lines.append("Boost: bis %d Felder gerade -- nicht ueber Hindernisse/Stufen"
			% range_tiles)
	if is_heal():
		lines.append("Reparatur %d" % heal_amount())
	elif power > 0:
		lines.append("Staerke %d · Schadensart %s" % [power, damage_type_label()])
	if aoe_radius > 0:
		lines.append("Flaeche: Radius %d um das Ziel" % aoe_radius)
	if requires_line_of_sight:
		lines.append("braucht Sichtlinie")
	if push_tiles > 0:
		lines.append("stoesst %d Feld(er) zurueck" % push_tiles)
	elif push_tiles < 0:
		lines.append("zieht %d Feld(er) heran" % absi(push_tiles))
	if is_taunt():
		lines.append("provoziert fuer %d s" % taunt_seconds())
	if targeting == Targeting.SELF:
		lines.append("wirkt nur auf den eigenen DROME")
	if source_part_name != "":
		lines.append("aus: %s%s" % [source_part_name,
			" (%s)" % source_part_code if source_part_code != "" else ""])
	return lines


func _to_string() -> String:
	return "ActionData(%s)" % id
