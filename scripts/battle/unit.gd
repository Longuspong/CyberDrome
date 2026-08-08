class_name Unit
extends Node2D

## Ein DROME im Kampf: Darstellung und Laufzeitwerte.
##
## Zusammengesetzt wird er wie in der Werkstatt -- ein Sprite2D je Bauteil,
## alle auf Position (0,0), ``centered = false``, Zeichenreihenfolge aus
## ``slot_z`` des Chassis. Die Anker-Mathematik steckt bereits in der Grafik;
## Offsets aus der JSON sind deshalb gar nicht noetig.
##
## Das ist keine Bequemlichkeit, sondern ein Akzeptanzkriterium: der Spieler
## muss den Bot, den er gebaut hat, im Kampf wiedererkennen. Dieselben Teile,
## sichtbar derselbe Bot.

signal died(unit)

var unit_id: StringName
var display_name: String = "DROME"
var build: DromeBuild
var is_player: bool = false

var tile: Vector2i = Vector2i.ZERO
var facing: String = "south"

## Laufzeitwerte. Die Maxima stehen im Build, hier steht der aktuelle Stand.
var hp: int = 0
var en: int = 0
var stats: Dictionary = {}

## Aktive Statuseffekte: id -> { cycles_left, spd, def, ... }
var statuses: Dictionary = {}

## Die Aggro-Buchfuehrung dieses DROME -- nur bei Gegnern belegt, bei
## Spieler-DROMEs immer null. Wer die Zielwahl des Spielers trifft, ist der
## Spieler; eine Tabelle, die niemand liest, waere eine zweite Wahrheit.
var aggro: AggroTable = null

## Provokation: solange gesetzt, darf dieser DROME nur die Quelle angreifen.
## { "source": unit_id, "turns_left": int } oder leer.
##
## Sitzt beim PROVOZIERTEN, nicht beim Provozierenden -- deshalb funktioniert
## der Zwang in beide Richtungen, obwohl nur Gegner eine Aggro-Tabelle haben.
## Durchgesetzt wird er an genau einer Stelle: ActionResolver.target_blocker().
var taunt_lock: Dictionary = {}

## Kampfbilanz fuer den Ergebnisbildschirm
var damage_dealt: int = 0
var damage_taken: int = 0

var _sprites: Dictionary = {}


static func create(from_build: DromeBuild, id: StringName, player: bool) -> Unit:
	var unit := Unit.new()
	unit.unit_id = id
	unit.display_name = from_build.display_name
	unit.build = from_build
	unit.is_player = player
	unit.stats = from_build.stats()
	unit.hp = unit.stats["hp_max"]
	unit.en = unit.stats["en_max"]
	unit.name = "Unit_%s" % id
	if not player:
		unit.aggro = AggroTable.new()
	return unit


func _ready() -> void:
	# Y-Sortierung innerhalb der Einheit aus, sonst sortiert Godot die
	# Bauteile gegeneinander und ignoriert slot_z.
	y_sort_enabled = false
	_build_sprites()


# ---------------------------------------------------------------------------
# Darstellung
# ---------------------------------------------------------------------------

func _build_sprites() -> void:
	# Zusammengesetzt wird ueber DromeSprites -- dieselbe Funktion, die auch
	# die Werkstatt-Vorschau benutzt. Zwei Zusammenbauten waeren zwei
	# Gelegenheiten, dass der Bot im Kampf anders aussieht als beim Bauen.
	_sprites = DromeSprites.assemble(self, build, facing)
	_apply_haze_tint()


## Beim Richtungswechsel werden alle Teile auf ihre Variante fuer diese
## Richtung gewechselt -- und die Zeichenebenen gleich mit.
func set_facing(direction: String) -> void:
	if direction == facing:
		return
	facing = direction
	_build_sprites()


## Setzt die Einheit auf ein Feld. Rein visuell -- die Belegung des Gitters
## fuehrt der BattleManager, damit es nur eine Wahrheit gibt.
func place_at(new_tile: Vector2i) -> void:
	tile = new_tile
	position = IsoView.sprite_position(new_tile)


## Alles in einem Haze-Feld wird ausgegraut. Position bleibt sichtbar -- es
## gibt keinen Fog of War --, aber der Zustand "von hier aus nicht
## beschiessbar" muss sofort lesbar sein.
var _in_haze: bool = false

func set_in_haze(value: bool) -> void:
	if value == _in_haze:
		return
	_in_haze = value
	_apply_haze_tint()


func _apply_haze_tint() -> void:
	DromeSprites.tint(_sprites,
		Color(0.55, 0.60, 0.70, 0.75) if _in_haze else Color.WHITE)


# ---------------------------------------------------------------------------
# Laufzeitwerte
# ---------------------------------------------------------------------------

func is_alive() -> bool:
	return hp > 0


func hp_fraction() -> float:
	var maximum: int = stats.get("hp_max", 0)
	return 0.0 if maximum <= 0 else float(hp) / float(maximum)


## Effektiver Wert inklusive Statuseffekten und Mutator. Die Basiswerte im
## Build bleiben unangetastet -- ein Effekt, der den Build veraendert, waere
## nach dem Kampf nicht mehr zurueckzunehmen.
func stat(key: String) -> int:
	var value: int = stats.get(key, 0)
	for status in statuses.values():
		value += int(status.get(key, 0))
	return value


func spd() -> int:
	return stat("spd")


func def() -> int:
	return maxi(0, stat("def"))


func atk() -> int:
	return stat("atk")


func sees_through_haze() -> bool:
	return stats.get("grants_ignore_haze", false)


func move_profile() -> MoveProfile:
	return MoveProfile.from_stats(stats, unit_id, tile)


## Alle Aktionen dieses DROME -- die seiner Teile.
func actions() -> Array:
	return build.actions() if build != null else []


func can_afford(action: ActionData) -> bool:
	return en >= action.en_cost


func spend_energy(amount: int) -> void:
	en = maxi(0, en - amount)


func regenerate() -> void:
	en = mini(stat("en_max"), en + stat("en_regen"))


# ---------------------------------------------------------------------------
# Statuseffekte
# ---------------------------------------------------------------------------

## Wirkt bis zum Ablauf der Zyklen. ``modifiers`` sind Stat-Aufschlaege.
func apply_status(id: StringName, cycles: int, modifiers: Dictionary) -> void:
	var status := modifiers.duplicate()
	status["cycles_left"] = cycles
	statuses[id] = status


## Zu Beginn des eigenen Zuges. Gibt true zurueck, wenn sich etwas geaendert
## hat -- dann muss die TICK-Vorschau neu gerechnet werden.
func tick_statuses() -> bool:
	var changed := false
	for id in statuses.keys():
		statuses[id]["cycles_left"] -= 1
		if statuses[id]["cycles_left"] <= 0:
			statuses.erase(id)
			changed = true
	return changed


# ---------------------------------------------------------------------------
# Provokation
# ---------------------------------------------------------------------------

func is_taunted() -> bool:
	return not taunt_lock.is_empty() and int(taunt_lock.get("turns_left", 0)) > 0


func taunted_by():
	return taunt_lock.get("source") if is_taunted() else null


func apply_taunt(source_id, turns: int) -> void:
	taunt_lock = {"source": source_id, "turns_left": maxi(1, turns)}


func clear_taunt() -> void:
	taunt_lock = {}


## Zu Beginn des eigenen Zuges. Die Provokation laeuft in EIGENEN Zuegen ab,
## nicht in Zyklen -- "drei Zuege lang" ist das, was der Spieler abzaehlt, und
## Statuseffekte rechnen an derselben Stelle genauso.
func tick_taunt() -> void:
	if taunt_lock.is_empty():
		return
	taunt_lock["turns_left"] = int(taunt_lock.get("turns_left", 0)) - 1
	if int(taunt_lock["turns_left"]) <= 0:
		taunt_lock = {}


func status_names() -> Array[String]:
	var names: Array[String] = []
	for id in statuses:
		names.append(str(id))
	return names


func _to_string() -> String:
	return "Unit(%s %s hp=%d/%d en=%d)" % [
		unit_id, tile, hp, stats.get("hp_max", 0), en]
