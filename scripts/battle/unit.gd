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

## Reihenfolge, in der Slots angelegt werden. Die tatsaechliche Ueberdeckung
## entscheidet slot_z; das hier ist nur ein stabiler Ausgangszustand fuer
## Slots, fuer die das Chassis keine Tiefe kennt.
const SLOT_ORDER := ["feet", "body", "core", "equip_left", "equip_center",
	"equip_right", "equip_shoulder", "head"]

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
	for child in _sprites.values():
		child.queue_free()
	_sprites.clear()
	if build == null:
		return

	var chassis := build.body()
	var slot_z: Dictionary = {}
	if chassis != null:
		slot_z = chassis.view(facing).get("slot_z", {})

	# Die Tiefe des Ankers IST die Zeichenreihenfolge. Damit stimmt die
	# Ueberdeckung in allen vier Richtungen von selbst: in der Nordansicht
	# rutscht die Ausruestung hinter den Koerper, ein Schulterpod vor den Kopf.
	#
	# Die Rohwerte sind Kameratiefen (32 bis 72) und taugen NICHT direkt als
	# z_index: Kindknoten rechnen relativ zum Elternknoten, und ein Aufschlag
	# von 70 wuerde das Bauteil in die Tiefenstufe einer ganz anderen Reihe
	# schieben -- der Kopf laege dann vor einem Betonpfeiler drei Felder
	# weiter vorn. Gebraucht wird nur die REIHENFOLGE, also wird auf 0..n
	# normalisiert.
	var ordered: Array = []
	for slot in SLOT_ORDER:
		var part := build.part_in(slot)
		if part == null:
			continue
		var view := part.view(facing)
		var depth: float = float(view.get("z_index", 50)) if slot == "body" \
			else float(slot_z.get(slot, 20))
		ordered.append({"slot": slot, "part": part, "view": view, "depth": depth})
	ordered.sort_custom(func(a, b): return a["depth"] < b["depth"])

	for rank in ordered.size():
		var entry: Dictionary = ordered[rank]
		var path: String = entry["view"].get("svg", "")
		if path == "" or not ResourceLoader.exists(path):
			push_warning("Unit %s: Textur fehlt fuer %s (%s)"
				% [unit_id, entry["slot"], path])
			continue
		var sprite := Sprite2D.new()
		sprite.texture = load(path)
		sprite.centered = false
		sprite.position = Vector2.ZERO
		sprite.z_index = rank
		add_child(sprite)
		_sprites[entry["slot"]] = sprite

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
	var tint := Color(0.55, 0.60, 0.70, 0.75) if _in_haze else Color.WHITE
	for sprite in _sprites.values():
		sprite.modulate = tint


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


func status_names() -> Array[String]:
	var names: Array[String] = []
	for id in statuses:
		names.append(str(id))
	return names


func _to_string() -> String:
	return "Unit(%s %s hp=%d/%d en=%d)" % [
		unit_id, tile, hp, stats.get("hp_max", 0), en]
