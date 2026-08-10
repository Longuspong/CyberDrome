class_name Unit
extends Node2D

## Ein DROME im Kampf: Darstellung und Laufzeitwerte.
##
## Zusammengesetzt wird er wie in der Werkstatt -- ein Sprite2D je Bauteil,
## ``centered = false``, auf den Sockel des Chassis verschoben,
## Zeichenreihenfolge aus ``slot_z``. Beides rechnet DromeSprites.
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

## Die Bauteile haengen unter einem eigenen Knoten, nicht direkt unter der
## Einheit. Der Grund ist das Trefferfeedback: Rueckstoss und Erschuetterung
## verschieben die FIGUR, und ``position`` der Einheit gehoert dem Feld -- wer
## dort waehrend eines Zuges hineinschreibt, verliert bei jedem Zusammentreffen
## von Bewegung und Treffer die Feldposition.
var _rig: Node2D

## Der Bodenring in Fraktionsfarbe. Liegt UNTER den Bauteilen (z_index -1) und
## damit in derselben Tiefenstufe wie die Einheit -- ein Ring, der aus seinem
## Tiefenband ausbricht, leuchtet durch den Betonpfeiler davor.
var _ring: UnitRing

## Laeuft gerade eine Trefferblende? Dann darf der Haze-Farbstich sie nicht
## ueberschreiben -- sonst blinkt ein Treffer im Haze nicht.
var _flashing: bool = false


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


## Bodenring und Rig, beim ersten Bedarf.
##
## Nicht in _ready(): der BattleManager setzt die Blickrichtung schon beim
## Aufstellen, also bevor die Einheit im Baum haengt. _ready() lief da noch
## nicht, und _build_sprites() haette in einen Knoten gebaut, den es noch nicht
## gab. Lazy statt frueh ist hier keine Optimierung, sondern die einzige
## Reihenfolge, die beide Aufrufwege ueberlebt.
func _ensure_chrome() -> void:
	if _rig != null:
		return
	_ring = UnitRing.new()
	_ring.name = "Bodenring"
	_ring.tint = Teams.color(is_player)
	# Unter den Bauteilen, aber in derselben Tiefenstufe wie die Einheit --
	# ein Ring, der aus seinem Tiefenband ausbricht, leuchtet durch den
	# Betonpfeiler davor.
	_ring.z_index = -1
	add_child(_ring)

	_rig = Node2D.new()
	_rig.name = "Rig"
	add_child(_rig)


# ---------------------------------------------------------------------------
# Darstellung
# ---------------------------------------------------------------------------

func _build_sprites() -> void:
	# Zusammengesetzt wird ueber DromeSprites -- dieselbe Funktion, die auch
	# die Werkstatt-Vorschau benutzt. Zwei Zusammenbauten waeren zwei
	# Gelegenheiten, dass der Bot im Kampf anders aussieht als beim Bauen.
	_ensure_chrome()
	_sprites = DromeSprites.assemble(_rig, build, facing)
	_refresh_tint()


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
	_refresh_tint()


## Fraktionsfarbstich, Haze-Schleier und Trefferblende treffen sich hier -- und
## nur hier. Drei Stellen, die ``modulate`` setzen, waeren drei Stellen, an
## denen eine die andere still ueberschreibt: die Trefferblende einer Einheit
## im Haze verschwand genau so.
func _refresh_tint() -> void:
	if _flashing:
		return
	var color := Teams.tint(is_player)
	if _in_haze:
		color = Teams.blend(color, Teams.HAZE)
	DromeSprites.tint(_sprites, color)


## Der Ring markiert, wer am Zug ist -- er pulsiert dann statt still zu liegen.
func set_active(value: bool) -> void:
	_ensure_chrome()
	_ring.active = value


# ---------------------------------------------------------------------------
# Trefferfeedback
# ---------------------------------------------------------------------------
#
# Der Kampf ist deterministisch: es gibt keinen Trefferwurf, kein Vorbeischiessen
# und damit auch keine Spannung im Wuerfel. Was ein Treffer ist, muss deshalb
# vollstaendig aus der Darstellung kommen -- sonst aendert sich beim Angriff
# nur eine Zahl im Protokoll.

const RECOIL_DISTANCE := 9.0
const RECOIL_TIME := 0.09
const SHAKE_TIME := 0.30
const SHAKE_AMPLITUDE := 7.0

## Der Angreifer stemmt sich kurz gegen sein Ziel und faellt zurueck. Die
## Richtung kommt aus dem Feld, nicht aus ``facing``: bei einer Flaechenaktion
## steht der Bot woanders hin, als er trifft.
func play_attack(toward: Vector2i) -> void:
	if _rig == null:
		return
	var delta := IsoView.map_to_local(toward) - IsoView.map_to_local(tile)
	var push := Vector2.ZERO if delta == Vector2.ZERO \
		else delta.normalized() * RECOIL_DISTANCE
	var tween := create_tween()
	tween.tween_property(_rig, "position", push, RECOIL_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_rig, "position", Vector2.ZERO, RECOIL_TIME * 2.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Das Ziel zuckt und blendet kurz hell auf. Die Erschuetterung laeuft ueber
## abklingende Ausschlaege statt ueber ein Rauschen -- so endet sie sichtbar
## und nicht einfach irgendwann.
func play_hit() -> void:
	if _rig == null:
		return
	var tween := create_tween()
	var steps := 5
	for i in steps:
		var decay := 1.0 - float(i) / float(steps)
		var side := 1.0 if i % 2 == 0 else -1.0
		tween.tween_property(_rig, "position",
			Vector2(SHAKE_AMPLITUDE * decay * side, 0.0),
			SHAKE_TIME / float(steps)).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_rig, "position", Vector2.ZERO, SHAKE_TIME / float(steps))

	_flashing = true
	DromeSprites.tint(_sprites, Teams.HIT_FLASH)
	var flash := create_tween()
	flash.tween_interval(0.09)
	flash.tween_callback(func():
		_flashing = false
		_refresh_tint())


## Wer repariert wird, wackelt nicht -- er leuchtet kurz gruen auf. Sonst waere
## eine Reparatur an derselben Bewegung zu erkennen wie ein Treffer.
func play_heal() -> void:
	if _rig == null:
		return
	_flashing = true
	DromeSprites.tint(_sprites, Color(1.1, 2.2, 1.3))
	var flash := create_tween()
	flash.tween_interval(0.14)
	flash.tween_callback(func():
		_flashing = false
		_refresh_tint())


## Der Bodenring: eine flache Ellipse in Fraktionsfarbe unter den Fuessen.
##
## Als gezeichneter Ring und nicht als Raute wie die Feldmarkierungen -- die
## Raute heisst auf dieser Karte bereits "erreichbar", "Ziel" oder "gesperrt".
## Eine sechste Bedeutung fuer dieselbe Form waere keine Auskunft mehr.
class UnitRing extends Node2D:
	const RADIUS_X := 30.0
	const RADIUS_Y := 30.0 * IsoView.TILE_H / IsoView.TILE_W
	const PULSE_SPEED := 3.4

	var tint: Color = Teams.PLAYER:
		set(value):
			tint = value
			queue_redraw()

	## Am Zug: der Ring pulsiert und bekommt einen zweiten, weiteren Reif.
	var active: bool = false:
		set(value):
			active = value
			set_process(value)
			queue_redraw()

	var _phase: float = 0.0

	func _ready() -> void:
		set_process(false)

	func _process(delta: float) -> void:
		_phase += delta * PULSE_SPEED
		queue_redraw()

	func _draw() -> void:
		# Die Einheit sitzt mit ihrem Ursprung in der oberen linken Ecke des
		# 128er Bildes; die Feldmitte liegt bei SPRITE_ORIGIN.
		var center := IsoView.SPRITE_ORIGIN
		_ellipse(center, RADIUS_X, RADIUS_Y, Color(tint, 0.85), 3.0)
		_ellipse(center, RADIUS_X * 0.62, RADIUS_Y * 0.62, Color(tint, 0.30), 2.0)
		if not active:
			return
		# Der Puls laeuft nach aussen und verblasst dabei -- eine Welle, die den
		# Blick von der Figur wegtraegt, statt sie zu ueberdecken.
		var swell := fposmod(_phase, TAU) / TAU
		var scale := 1.0 + swell * 0.75
		_ellipse(center, RADIUS_X * scale, RADIUS_Y * scale,
			Color(tint, 0.55 * (1.0 - swell)), 2.5)

	func _ellipse(center: Vector2, rx: float, ry: float, color: Color,
			width: float) -> void:
		var points := PackedVector2Array()
		for i in 33:
			var angle := TAU * float(i) / 32.0
			points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
		draw_polyline(points, color, width, true)


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


## Alle Aktionen dieses DROME -- die seiner Teile, jede genau einmal.
func actions() -> Array:
	return build.actions() if build != null else []


## Die Aktionen eines Budgets. Angriff und Faehigkeit sind getrennt zu planen
## und werden deshalb auch getrennt angezeigt.
func actions_of(category: ActionData.Category) -> Array:
	return build.actions_of(category) if build != null else []


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
