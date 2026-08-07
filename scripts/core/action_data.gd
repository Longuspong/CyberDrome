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
	return action


func is_attack() -> bool:
	return category == Category.ATTACK


func is_heal() -> bool:
	return power < 0


func heal_amount() -> int:
	return -power


func _to_string() -> String:
	return "ActionData(%s)" % id
