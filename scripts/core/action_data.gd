class_name ActionData
extends RefCounted

## Eine Aktion, die ein Bauteil gewaehrt. Passive Teile gewaehren keine.
##
## Schaden ist deterministisch: kein Trefferwurf, kein Krit, keine Ausweich-
## chance -- weder im MVP noch spaeter. Balancing laeuft ueber das WIE
## (Position, Reihenfolge, Ressourcen), nicht ueber das OB. Der Spieler soll
## jede Aktion vorher exakt durchrechnen koennen.

## Welches Budget des Zuges die Aktion verbraucht.
##
## Das ist die Trennung, die der Spieler sieht und nach der er plant: ein
## ANGRIFF ist das, was eine Waffe von sich aus tut -- Blaster, Schienenschuss,
## Runenschlag --, eine FAEHIGKEIT alles, was darueber hinaus geht: ziehen,
## reparieren, provozieren, ein Flaechenschlag. Die beiden Budgets sind getrennt
## und nicht gegeneinander tauschbar (siehe TurnState): der Angriffsvorrat zaehlt
## die Waffen, die Faehigkeiten sind je einmal pro Zug ziehbar. Eine WAFFE traegt
## deshalb heute beides -- ihren Angriff UND eine eigene Faehigkeit
## (GAME_DESIGN §13); sie nimmt sich damit nichts mehr selbst weg.
enum Category { ATTACK, ABILITY }

enum Targeting { SINGLE, SELF, TILE, AOE_AROUND_TARGET }

const CATEGORY_NAMES := {"attack": Category.ATTACK, "ability": Category.ABILITY}
const CATEGORY_LABEL := {Category.ATTACK: "Angriff", Category.ABILITY: "Faehigkeit"}
const TARGETING_NAMES := {
	"single": Targeting.SINGLE,
	"self": Targeting.SELF,
	"tile": Targeting.TILE,
	"aoe_around_target": Targeting.AOE_AROUND_TARGET,
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
var targeting: Targeting = Targeting.SINGLE
var range_tiles: int = 1
var aoe_radius: int = 0
var en_cost: int = 0

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

## Wie viele EIGENE Zuege diese Aktion danach nicht zur Verfuegung steht.
## 0 = keine Abklingzeit. Wirkt nur im Bremsmodus ``abklingzeit`` oder
## ``beides`` -- siehe BRAKE unten.
var cooldown_turns: int = 0


# ---------------------------------------------------------------------------
# Die Bremse: Preis oder Wartezeit
# ---------------------------------------------------------------------------

## Womit eine Faehigkeit knapp gehalten wird. Umschaltbar, weil sich die Frage
## nicht ausrechnen laesst -- nur spielen.
##
##   energie      Der Preis bremst. ``en_cost`` gilt, ``cooldown_turns`` nicht.
##                Eine Faehigkeit laesst sich zweimal hintereinander ziehen,
##                wenn der Tank es hergibt -- dafuer ist er danach leer.
##   abklingzeit  Die Wartezeit bremst. ``cooldown_turns`` gilt, ``en_cost``
##                wird NICHT abgebucht. Der Rhythmus ist derselbe fuer jeden
##                Aufbau, unabhaengig vom Kern.
##   beides       Beide Bremsen. Ausdruecklich als Vergleichspunkt gedacht und
##                nicht als Voreinstellung: zwei Bremsen auf derselben Groesse
##                sind schwer auseinanderzuhalten, wenn eine davon zu hart ist.
##
## Der Unterschied ist nicht kosmetisch. Der Preis macht den KERN zur
## Entscheidung -- ein Arkankern zieht oefter als ein Impulskern. Die Wartezeit
## macht ihn bedeutungslos und dafuer den ZUG zur Entscheidung: nicht "kann ich
## mir das leisten", sondern "will ich sie jetzt oder gleich".
const BRAKE_ENERGY := "energie"
const BRAKE_COOLDOWN := "abklingzeit"
const BRAKE_BOTH := "beides"


static func brake() -> String:
	return str(Config.section("abilities").get("brake", BRAKE_ENERGY))


static func energy_brakes() -> bool:
	return brake() != BRAKE_COOLDOWN


static func cooldown_brakes() -> bool:
	return brake() != BRAKE_ENERGY


## Was diese Aktion im aktuellen Bremsmodus WIRKLICH kostet.
##
## Die EINZIGE Stelle, an der ``en_cost`` gelesen wird, sobald es ums Bezahlen
## geht -- Vorschau, Sperrgrund, Abbuchung und Werkstatt-Text fragen alle hier.
## Zwei Lesarten waeren zwei Gelegenheiten, dass die Aktionsleiste einen Preis
## nennt, den die Ausfuehrung nicht abbucht.
func en_cost_now() -> int:
	return en_cost if ActionData.energy_brakes() else 0


## Und dasselbe fuer die Wartezeit.
func cooldown_now() -> int:
	return cooldown_turns if ActionData.cooldown_brakes() else 0


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
	action.en_cost = meta.get("en_cost", 0)
	action.power = meta.get("power", 0)
	action.requires_line_of_sight = meta.get("requires_line_of_sight", false)
	action.push_tiles = meta.get("push_tiles", 0)
	action.status_effect = meta.get("status_effect")
	action.aggro_coeff = float(meta.get("aggro_coeff", 1.0))
	action.aggro_flat = meta.get("aggro_flat", 0)
	action.taunt_turns = meta.get("taunt_turns", 0)
	action.cooldown_turns = meta.get("cooldown_turns", 0)
	return action


func is_taunt() -> bool:
	return taunt_turns > 0


func is_attack() -> bool:
	return category == Category.ATTACK


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
	if push_tiles > 0:
		parts.append("stoesst %d" % push_tiles)
	elif push_tiles < 0:
		parts.append("zieht %d heran" % absi(push_tiles))
	if is_taunt():
		parts.append("provoziert %d Zuege" % taunt_turns)
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
	if en_cost_now() > 0:
		parts.append("EN %d" % en_cost_now())
	if cooldown_now() > 0:
		parts.append("AZ %d" % cooldown_now())
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
	if is_heal():
		lines.append("Reparatur %d" % heal_amount())
	elif power > 0:
		lines.append("Staerke %d · Schadensart %s" % [power, damage_type_label()])
	lines.append("Energie %d" % en_cost_now())
	if cooldown_now() > 0:
		lines.append("Abklingzeit %d Zuege" % cooldown_now())
	if aoe_radius > 0:
		lines.append("Flaeche: Radius %d um das Ziel" % aoe_radius)
	if requires_line_of_sight:
		lines.append("braucht Sichtlinie")
	if push_tiles > 0:
		lines.append("stoesst %d Feld(er) zurueck" % push_tiles)
	elif push_tiles < 0:
		lines.append("zieht %d Feld(er) heran" % absi(push_tiles))
	if is_taunt():
		lines.append("provoziert fuer %d Zuege" % taunt_turns)
	if targeting == Targeting.SELF:
		lines.append("wirkt nur auf den eigenen DROME")
	if source_part_name != "":
		lines.append("aus: %s%s" % [source_part_name,
			" (%s)" % source_part_code if source_part_code != "" else ""])
	return lines


func _to_string() -> String:
	return "ActionData(%s)" % id
