class_name ActionData
extends RefCounted

## Eine Aktion, die ein Bauteil gewaehrt. Passive Teile gewaehren keine.
##
## Schaden ist deterministisch: kein Trefferwurf, kein Krit, keine Ausweich-
## chance -- weder im MVP noch spaeter. Balancing laeuft ueber das WIE
## (Position, Reihenfolge, Ressourcen), nicht ueber das OB. Der Spieler soll
## jede Aktion vorher exakt durchrechnen koennen.

## Welches Budget des Zuges die Aktion verbraucht.
enum Category { ATTACK, ABILITY }

enum Targeting { SINGLE, SELF, TILE, AOE_AROUND_TARGET }

const CATEGORY_NAMES := {"attack": Category.ATTACK, "ability": Category.ABILITY}
const TARGETING_NAMES := {
	"single": Targeting.SINGLE,
	"self": Targeting.SELF,
	"tile": Targeting.TILE,
	"aoe_around_target": Targeting.AOE_AROUND_TARGET,
}

var id: StringName
var display_name: String
var category: Category = Category.ATTACK
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


static func from_meta(meta: Dictionary, owner_name: String = "") -> ActionData:
	var action := ActionData.new()
	action.id = StringName(meta.get("id", ""))
	action.display_name = meta.get("display_name", owner_name)
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
	return action


func is_taunt() -> bool:
	return taunt_turns > 0


func is_attack() -> bool:
	return category == Category.ATTACK


func is_heal() -> bool:
	return power < 0


func heal_amount() -> int:
	return -power


func _to_string() -> String:
	return "ActionData(%s)" % id
