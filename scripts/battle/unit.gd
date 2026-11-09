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
## Energieschild: die regenerierende Leiste VOR der HP (§11). Getrennt von der
## HP, weil Schadensarten sie unterschiedlich treffen und sie sich je Puls
## wieder auffuellt.
var shield: int = 0
var stats: Dictionary = {}

## Aktive Statuseffekte: id -> { seconds_left, spd, def, ... }. Laufen in
## Sekunden ab (Echtzeit), nicht mehr in Zuegen.
var statuses: Dictionary = {}


## Kampfbilanz fuer den Ergebnisbildschirm
var damage_dealt: int = 0
var damage_taken: int = 0

# --- Echtzeit (Nov. 2026) ---------------------------------------------------

## Je Waffen-TEIL ein Eintrag: zwei Blaster sind zwei Waffen, jede laedt fuer
## sich. { slot, part, attack: ActionData, ability: ActionData|null,
## ready: Sekunden bis zum naechsten Schuss, count: Angriffe seit der letzten
## Faehigkeit }.
var mounts: Array = []
## Faehigkeiten, die nicht an einem Angriff haengen (Gadgets, nach Zeit oder
## Ereignis): { part, ability: ActionData, ready: Sekunden }.
var gadgets: Array = []
## Restzeit des laufenden Schritts. Solange > 0, laeuft der DROME und schiesst
## nicht; das Feld (``tile``) ist schon das Zielfeld.
var step_left: float = 0.0
## Bis zum naechsten Puls (Schild, Reparatur, Overtime ...).
var pulse_left: float = 0.0
## Sekunden seit dem letzten Schaden, und der Bruchteil Schild, der beim
## Nachladen noch nicht ganz voll ist.
var calm_time: float = 0.0
## Passive "steady" (Strix, 8. Nov. 2026): Sekunden ohne Feldwechsel und ob
## er gerade angelegt hat (+Schaden, +Reichweite).
var still_time: float = 0.0
var steady: bool = false
var _still_tile: Vector2i = Vector2i(-9999, -9999)
## Modul Raufbold (Vergeltung): eingesteckte Nahkampftreffer, die den
## naechsten Angriff aufladen (max. 3).
var retaliation_stacks: int = 0
var _recharge_carry: float = 0.0
## Bis zur naechsten Pruefung des Ziels, und das aktuelle Ziel.
var think_left: float = 0.0
var target_id = null
## Wie lange das aktuelle Ziel schon nicht angreifbar ist (Sekunden).
## Ein Ziel wird gehalten -- erst wenn es zu lange ausser Reichweite bleibt,
## wird neu gewaehlt (AIController).
var target_blocked: float = 0.0

## Darstellung: der DROME gleitet von Feld zu Feld statt zu springen.
var _glide_from: Vector2 = Vector2.ZERO
var _glide_to: Vector2 = Vector2.ZERO
var _glide_time: float = 0.0
var _glide_total: float = 0.0
var _prev_position: Vector2 = Vector2.ZERO

var _sprites: Dictionary = {}

## Die Bauteile haengen unter einem eigenen Knoten, nicht direkt unter der
## Einheit. Der Grund ist das Trefferfeedback: Rueckstoss und Erschuetterung
## verschieben die FIGUR, und ``position`` der Einheit gehoert dem Feld.
var _rig: Node2D

## Der Bodenring in Fraktionsfarbe, UNTER den Bauteilen (z_index -1).
var _ring: UnitRing

## Laeuft gerade eine Trefferblende? Dann wartet der Farbstich.
var _flashing: bool = false


static func create(from_build: DromeBuild, id: StringName, player: bool) -> Unit:
	var unit := Unit.new()
	unit.unit_id = id
	unit.display_name = from_build.display_name
	unit.build = from_build
	unit.is_player = player
	unit.stats = from_build.stats()
	unit.hp = unit.stats["hp_max"]
	unit.shield = unit.stats.get("shield_max", 0)
	unit.name = "Unit_%s" % id
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
	_prev_position = position
	position = IsoView.sprite_position(new_tile)
	_glide_total = 0.0


## Die letzte Versetzung (place_at) sichtbar nachgleiten: vom Ort, an dem die
## Figur vorher gezeichnet wurde, zum neuen Feld.
func animate_last_move(seconds: float) -> void:
	glide_to(tile, seconds, _prev_position)


## Wie place_at, aber die Figur gleitet in ``seconds`` vom bisherigen Ort
## dorthin. Das Feld gilt sofort -- nur das Bild laeuft hinterher.
func glide_to(new_tile: Vector2i, seconds: float, from_position: Vector2) -> void:
	tile = new_tile
	_glide_from = from_position
	_glide_to = IsoView.sprite_position(new_tile)
	_glide_time = 0.0
	_glide_total = maxf(0.01, seconds)
	position = _glide_from


func _process(delta: float) -> void:
	if _glide_total <= 0.0:
		return
	_glide_time += delta
	var t := clampf(_glide_time / _glide_total, 0.0, 1.0)
	position = _glide_from.lerp(_glide_to, t)
	if t >= 1.0:
		_glide_total = 0.0


## Die Feldmitte unter der Figur, so wie sie gerade gezeichnet wird -- fuer
## den Lebensbalken, der mitgleiten soll.
func visual_anchor() -> Vector2:
	return position + IsoView.SPRITE_ORIGIN


## Blickrichtung aus einem Schritt im Gitter.
static func facing_for(step: Vector2i) -> String:
	if absi(step.x) >= absi(step.y):
		return "east" if step.x > 0 else "west"
	return "south" if step.y > 0 else "north"


## Fraktionsfarbstich und Trefferblende treffen sich hier -- und nur hier.
func _refresh_tint() -> void:
	if _flashing:
		return
	DromeSprites.tint(_sprites, Teams.tint(is_player))


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
class UnitRing extends Node2D:
	const RADIUS_X := 30.0
	const RADIUS_Y := 30.0 * IsoView.TILE_H / IsoView.TILE_W

	var tint: Color = Teams.PLAYER:
		set(value):
			tint = value
			queue_redraw()

	func _draw() -> void:
		# Die Einheit sitzt mit ihrem Ursprung in der oberen linken Ecke des
		# 128er Bildes; die Feldmitte liegt bei SPRITE_ORIGIN.
		var center := IsoView.SPRITE_ORIGIN
		_ellipse(center, RADIUS_X, RADIUS_Y, Color(tint, 0.85), 3.0)
		_ellipse(center, RADIUS_X * 0.62, RADIUS_Y * 0.62, Color(tint, 0.30), 2.0)

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


## Echtzeit-Zustand zum Kampfbeginn: Waffen geladen bis auf einen kleinen
## Versatz, Gadgets nach ihrem Takt, Puls versetzt um ``pulse_offset``.
func init_realtime(pulse_offset: float) -> void:
	mounts.clear()
	gadgets.clear()
	step_left = 0.0
	pulse_left = maxf(0.05, pulse_offset)
	think_left = 0.0
	target_id = null
	target_blocked = 0.0
	calm_time = 0.0
	_recharge_carry = 0.0
	still_time = 0.0
	steady = false
	_still_tile = Vector2i(-9999, -9999)
	if build == null:
		return
	for slot in build.equip_slots():
		var part := build.part_in(slot)
		if part == null:
			continue
		# Module des Halters (nur im Lauf): die Aktionen werden als Kopie
		# angepasst, die PartDB bleibt unberuehrt.
		var fx := build.module_effects(slot)
		var attack: ActionData = null
		for action in part.actions:
			if action.is_attack():
				attack = action.with_modules(fx)
				break
		for action in part.actions:
			if action.is_attack():
				continue
			if action.trigger_kind == "attacks" and attack != null:
				continue
			var gadget_action: ActionData = action.with_modules(fx)
			var first := float(gadget_action.trigger_every) * echo_slower() \
				if gadget_action.trigger_kind == "time" else 0.0
			gadgets.append({"part": part, "ability": gadget_action, "ready": first, "fx": fx})
		if attack == null:
			continue
		var ability: ActionData = null
		for action in part.actions:
			if not action.is_attack() and action.trigger_kind == "attacks":
				ability = action.with_modules(fx)
		# Ein halbes Intervall Vorlauf: niemand schiesst im ersten Augenblick.
		mounts.append({"slot": slot, "part": part, "attack": attack,
			"ability": ability, "ready": attack.interval * 0.5, "count": 0,
			"fx": fx, "shots": 0, "base_attack": attack, "base_ability": ability})


## Der Takt einer Treffer-Faehigkeit an diesem DROME: der wievielte Angriff
## sie ist. Mit der Passive Echo (Nimbus) laenger: die normalen Angriffe
## dazwischen mal ``passives.echo.slower`` (gerundet) -- Blaster jeder 3. ->
## jeder 4.
func takt_every(ability: ActionData) -> int:
	var every := int(ability.trigger_every)
	if ability.trigger_kind != "attacks" or passive() != "echo":
		return every
	return int(round(float(every - 1) * echo_slower())) + 1


## Der Takt einer Zeit-Faehigkeit in Sekunden -- mit Echo ebenso laenger.
func takt_seconds(ability: ActionData) -> float:
	return float(ability.trigger_every) * echo_slower()


## Wann kommen die Faehigkeiten? Je Faehigkeit ein Eintrag fuer die Leiste
## unter dem Lebensbalken:
##   {"kind": "hits", "segments": N, "filled": k, "ready": bool}
##       Treffer-Takt: N Abschnitte, k gefuellt; ready = der naechste
##       Angriff ist die Faehigkeit (dann sind alle gefuellt).
##   {"kind": "time", "fill": 0..1, "ready": bool}
##       Zeit-Takt: fuellt sich in Schritten von ``step`` Sekunden.
func takt_bars(step: float = 0.5) -> Array:
	var out: Array = []
	for mount in mounts:
		var ability = mount.get("ability")
		if ability == null:
			continue
		var every := takt_every(ability)
		var count := int(mount["count"])
		var ready := count + 1 >= every
		out.append({"kind": "hits", "segments": every,
			"filled": every if ready else count, "ready": ready})
	for gadget in gadgets:
		var ability: ActionData = gadget["ability"]
		if ability.trigger_kind != "time":
			continue
		var total := takt_seconds(ability)
		var passed := clampf(total - float(gadget["ready"]), 0.0, total)
		if step > 0.0:
			passed = floorf(passed / step) * step
		out.append({"kind": "time", "fill": passed / maxf(0.01, total),
			"ready": float(gadget["ready"]) <= 0.0})
	return out


## Wie viel laenger der Takt der Faehigkeiten ist: mit der Passive Echo
## ``passives.echo.slower`` (1,5), sonst 1.
func echo_slower() -> float:
	if passive() != "echo":
		return 1.0
	return float((Config.section("passives").get("echo", {}) as Dictionary).get("slower", 1.5))


## Passive "steady" (Strix): wer passives.steady.seconds lang das Feld nicht
## wechselt, legt an -- mehr Schaden (raw_damage) und mehr Reichweite (die
## Aktionen der Halter werden als Kopie verlaengert). Jeder Feldwechsel setzt
## zurueck. Jeden Schritt vom BattleManager gerufen.
func track_stillness(dt: float) -> void:
	if tile != _still_tile:
		_still_tile = tile
		still_time = 0.0
	else:
		still_time += dt
	var rule := steady_rule()
	var now := passive() == "steady" and still_time >= float(rule.get("seconds", 4.0))
	if now == steady:
		return
	steady = now
	if steady:
		EventBus.log_line("%s legt an." % display_name)
	var mult := float(rule.get("range_mult", 1.2))
	for mount in mounts:
		mount["attack"] = _steady_copy(mount["base_attack"], mult)
		mount["ability"] = _steady_copy(mount.get("base_ability"), mult)


func _steady_copy(action, mult: float):
	if action == null or not steady:
		return action
	var out: ActionData = (action as ActionData).copy()
	if out.range_tiles > 0:
		out.range_tiles += maxi(1, int(round(float(out.range_tiles) * (mult - 1.0))))
	return out


static func steady_rule() -> Dictionary:
	return Config.section("passives").get("steady", {}) as Dictionary


## Die Passive des Chassis ("echo" ...). Leer = keine.
func passive() -> String:
	if build == null or build.body() == null:
		return ""
	return build.body().passive


## Lockradius: Gegner so nah greifen diesen DROME an statt ihres Ziels.
## Koedersender (lure_radius) oder Molok-Praesenz (passives.presence).
func lure_radius() -> int:
	var radius := int(stats.get("lure_radius", 0))
	if passive() == "presence":
		var p := Config.section("passives").get("presence", {}) as Dictionary
		radius = maxi(radius, int(p.get("lure_radius", 2)))
	return radius


## Wie die KI diesen DROME fuehrt -- aus dem Chassis. Leer = nach Waffe.
func ai_role() -> String:
	if build == null or build.body() == null:
		return ""
	return build.body().ai_role


## Betaeubt (Hammer): handelt nicht, solange der Status laeuft.
func is_stunned() -> bool:
	for status in statuses.values():
		if status.get("stunned", false):
			return true
	return false


## Faktor auf jeden eingehenden Treffer (Statuseffekt "verwundbar").
func damage_taken_mult() -> float:
	var mult := 1.0
	for status in statuses.values():
		mult *= float(status.get("damage_taken_mult", 1.0))
	return mult


## Felder je Sekunde. SPD ist seit dem Echtzeit-Kampf die Laufgeschwindigkeit.
func move_speed() -> float:
	var section := Config.section("realtime")
	var speed := maxf(float(section.get("move_min", 1.2)),
		float(section.get("move_base", 1.0)) + float(spd()) * float(section.get("move_per_spd", 0.12)))
	# Verlangsamung und Beschleunigung wirken als Faktor (move_mult).
	for status in statuses.values():
		speed *= float(status.get("move_mult", 1.0))
	return speed


## Die groesste Reichweite unter den Waffen dieses DROME.
func attack_range() -> int:
	var longest := 0
	for mount in mounts:
		longest = maxi(longest, (mount["attack"] as ActionData).range_tiles)
	return longest


func hp_fraction() -> float:
	var maximum: int = stats.get("hp_max", 0)
	return 0.0 if maximum <= 0 else float(hp) / float(maximum)


## Effektiver Wert inklusive Statuseffekten. Die Basiswerte im
## Build bleiben unangetastet -- ein Effekt, der den Build veraendert, waere
## nach dem Kampf nicht mehr zurueckzunehmen.
func stat(key: String) -> int:
	var value: int = stats.get(key, 0)
	for status in statuses.values():
		var bonus = status.get(key, 0)
		if bonus is int or bonus is float:
			value += int(bonus)
	return value


func spd() -> int:
	return stat("spd")


func def() -> int:
	return maxi(0, stat("def"))


## Das Schild-Maximum, inklusive Statuseffekten.
func shield_max() -> int:
	return maxi(0, stat("shield_max"))


func shield_fraction() -> float:
	var maximum := shield_max()
	return 0.0 if maximum <= 0 else float(shield) / float(maximum)


## Schild-Nachfuellung nach dem SCHILDPULS (8. Nov. 2026): ein Wert S regelt
## beides -- die Ruhezeit ohne Schaden (base_delay - delay_per_point * S,
## mindestens min_delay) und die Ladung je Puls (gain_per_point * S je
## ``pulse`` Sekunden, gleichmaessig verteilt). Wird jeden Schritt
## aufgerufen; gibt die aufgefuellte Menge zurueck.
func recharge_shield(dt: float) -> int:
	calm_time += dt
	var maximum := shield_max()
	if maximum <= 0 or shield >= maximum:
		_recharge_carry = 0.0
		return 0
	var rule: Dictionary = Config.section("combat").get("shield_pulse", {})
	var pulse_points := maxi(0, stat("shield_pulse"))
	var delay := maxf(float(rule.get("min_delay", 1.5)),
		float(rule.get("base_delay", 6.0)) - float(rule.get("delay_per_point", 0.3)) * pulse_points)
	# Modul Bollwerk: laedt frueher.
	var quick := float(stats.get("shield_delay", 0.0))
	if quick > 0.0:
		delay = minf(delay, quick)
	if calm_time < delay:
		return 0
	var per_pulse := float(rule.get("gain_per_point", 2.0)) * pulse_points
	_recharge_carry += per_pulse / maxf(0.1, float(rule.get("pulse", 3.0))) * dt
	var gain := mini(int(_recharge_carry), maximum - shield)
	_recharge_carry -= float(gain)
	shield += gain
	return gain


## Schaden genommen: die Ruhezeit faengt von vorn an.
func note_damage() -> void:
	calm_time = 0.0
	_recharge_carry = 0.0


## Power als Faktor (8. Nov. 2026): 10 Punkte = 100 % Waffenschaden.
func power_factor() -> float:
	var points := stat("power")
	return 1.0 if points <= 0 else float(points) / 10.0


## Rohschaden einer Aktion: ihr Schaden mal Power. Davor kommt nichts, danach
## Schild und Ruestung (ActionResolver.resolve_damage).
func raw_damage(action: ActionData) -> int:
	if action == null or action.power <= 0:
		return 0
	var raw := float(action.power) * power_factor()
	if steady:
		raw *= float(steady_rule().get("damage_mult", 1.2))
	return maxi(1, int(round(raw)))


## Alle Aktionen dieses DROME -- die seiner Teile, jede genau einmal.
func actions() -> Array:
	return build.actions() if build != null else []


## Die Aktionen einer Art (Angriff oder Faehigkeit).
func actions_of(category: ActionData.Category) -> Array:
	return build.actions_of(category) if build != null else []


## Passive Selbstheilung je Puls (Drohnen-Pod): ein Prozentsatz der
## maximalen Integritaet. Gibt die tatsaechlich geheilte Menge zurueck -- 0,
## wenn nichts zu heilen ist oder der DROME schon liegt.
func regenerate_hp() -> int:
	var pct := stat("hp_regen_pct")
	if pct <= 0 or hp <= 0:
		return 0
	var maximum := stat("hp_max")
	var amount := int(floor(float(maximum) * float(pct) / 100.0))
	if amount <= 0:
		return 0
	var before := hp
	hp = mini(maximum, hp + amount)
	return hp - before


# ---------------------------------------------------------------------------
# Statuseffekte
# ---------------------------------------------------------------------------

## Wirkt ``seconds`` lang. ``modifiers`` sind Stat-Aufschlaege (spd, def ...).
## Derselbe Effekt noch einmal frischt die Dauer auf, statt zu stapeln.
func apply_status(id: StringName, seconds: float, modifiers: Dictionary) -> void:
	var status := modifiers.duplicate()
	status["seconds_left"] = seconds
	statuses[id] = status


## Je Simulationsschritt. Gibt true zurueck, wenn ein Effekt abgelaufen ist.
func tick_statuses(dt: float) -> bool:
	var changed := false
	for id in statuses.keys():
		statuses[id]["seconds_left"] = float(statuses[id]["seconds_left"]) - dt
		if float(statuses[id]["seconds_left"]) <= 0.0:
			statuses.erase(id)
			changed = true
	return changed


func status_names() -> Array[String]:
	var names: Array[String] = []
	for id in statuses:
		names.append(str(id))
	return names


func _to_string() -> String:
	return "Unit(%s %s hp=%d/%d)" % [
		unit_id, tile, hp, stats.get("hp_max", 0)]
