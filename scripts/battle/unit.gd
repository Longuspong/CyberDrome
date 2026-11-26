class_name Unit
extends Node2D

## Ein DROME im Kampf: Darstellung und Laufzeitwerte.
##
## Ohne Arena (Tests, Bench) wird er als 2D-Bild zusammengesetzt -- ein Sprite2D je Bauteil,
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
var facing: String = FACING_ENEMY

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
## Abschuesse in diesem Kampf (EP fuer die Waffen, Leveling).
var kills: int = 0
## Schaden (Schild + Integritaet) und Abschuesse je Aktions-ID -- daraus
## bekommt jede Waffe ihre EP (Leveling.weapon_fight_xp).
var damage_by_action: Dictionary = {}
var kills_by_action: Dictionary = {}


## Was die Waffe in ``slot`` in diesem Kampf angerichtet hat: {damage, kills}.
## Zwei gleiche Waffen teilen sich die Summe.
func weapon_record(slot: String) -> Dictionary:
	var part := build.part_in(slot) if build != null else null
	if part == null:
		return {"damage": 0, "kills": 0}
	var twins := 0
	for other in build.equip_slots():
		if build.part_in(other) == part:
			twins += 1
	var damage := 0
	var downs := 0
	for action in part.actions:
		damage += int(damage_by_action.get(action.id, 0))
		downs += int(kills_by_action.get(action.id, 0))
	return {"damage": damage / maxi(1, twins), "kills": downs / maxi(1, twins)}
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
## Bis zum naechsten Puls (Reparatur, Kabelbrand, Virus ...).
var pulse_left: float = 0.0
## Sekunden seit dem letzten Schaden, und der Bruchteil Schild, der beim
## Nachladen noch nicht ganz voll ist.
var calm_time: float = 0.0
## Passive "steady" (Strix, 8. Nov. 2026): Sekunden ohne Feldwechsel und ob
## er gerade angelegt hat (+Schaden, +Reichweite).
var still_time: float = 0.0
var steady: bool = false
var _still_tile: Vector2i = Vector2i(-9999, -9999)
## Modul Raufbold (Vergeltung): eingesteckte Treffer, die den naechsten
## Angriff aufladen (max. 3, Berserker 5).
var retaliation_stacks: int = 0
## Modul Entladung: Sekunden bis zur naechsten Entladung (tick_statuses).
var burst_cooldown: float = 0.0
## Cyberspeed (Vireo-Passive, 25. Nov. 2026): liegende Stapel, Angriffe seit
## dem letzten Stapel und Restdauer (jeder Angriff startet sie neu).
var cyberspeed_stacks: int = 0
var cyberspeed_count: int = 0
var cyberspeed_left: float = 0.0
## Kabelbrand (Statuseffekt mit Stapeln, 20. Nov. 2026): liegende Stapel,
## mit Bruchteil aus der Effizienz; wer zuletzt angesteckt hat.
var cable_fire: float = 0.0
## Elementarbelastung am Ziel (Charger, 20. Nov. 2026): Element -> Belastung
## unter ``charger.stack_at``. Stapel der Elemente, die noch nicht wirken
## (alles ausser Feuer), zaehlt ``element_stacks``.
var element_load: Dictionary = {}
var element_stacks: Dictionary = {}
var cable_fire_source = null
var _recharge_carry: float = 0.0
## Bis zur naechsten Pruefung des Ziels, und das aktuelle Ziel.
var think_left: float = 0.0
## Laufende Ausholzeit einer Faehigkeit (AIController): {"action", "aim",
## "mount", "fx", "left", "target"}; leer = keine.
var cast: Dictionary = {}
## Ausstehende Echos (Passive Echo, Nimbus): je {action, target, tile, left}.
var echoes: Array = []
## Sekunden, die der DROME nach einem Schuss noch zum Ziel schaut, auch wenn
## er schon laeuft (nur Anzeige, 18. Nov. 2026).
var aim_hold: float = 0.0
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
## Erzwungene Versetzung (Sog, Stoss): schnell los, dann abbremsen.
var _glide_eased := false
var _prev_position: Vector2 = Vector2.ZERO

## Bewegung "mehr 3D" (21. Nov. 2026, Paket 1/2): die Logik gleitet weiter
## linear von Feldmitte zu Feldmitte (_glide_*, der Fuehrungspunkt). Die Figur
## (``position``) haengt an einer gedaempften Feder daran: sie laeuft weich an,
## schneidet Ecken leicht, laeuft ueber die Feldmitten durch und bremst erst
## am Ziel. Daraus kommen auch Tempo und Beschleunigung fuer die
## Koerpersprache (Arena3D). Werte in data/config.json -> motion.
var _track: Vector2 = Vector2.ZERO
var _vel: Vector2 = Vector2.ZERO
var _acc: Vector2 = Vector2.ZERO
var _spring_on := false
var _prev_vel: Vector2 = Vector2.ZERO
var _prev_track: Vector2 = Vector2.ZERO
## Aufstellung: die Figur haengt am Finger -- keine Feder.
var held := false
## Ausweichen beim Vorbeilaufen (Arena3D setzt es), in Bildpunkten.
var nudge: Vector2 = Vector2.ZERO:
	set(value):
		if value.distance_squared_to(nudge) > 0.01:
			_spring_on = true
		nudge = value

var _sprites: Dictionary = {}

## Die Bauteile haengen unter einem eigenen Knoten, nicht direkt unter der
## Einheit. Der Grund ist das Trefferfeedback: Rueckstoss und Erschuetterung
## verschieben die FIGUR, und ``position`` der Einheit gehoert dem Feld.
var _rig: Node2D

## Die gemeinsame 3D-Kampfszene (seit 18. Nov. 2026). Gesetzt, bevor die
## Einheit in den Baum kommt -- dann baut sie kein eigenes Bild, sondern ihr
## Modell steht in der Arena. Ohne Arena (Tests, Bench) als 2D-Bild.
var arena: Arena3D = null

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
	# Zusammengesetzt wird ueber DromeSprites (wie im Bench-Bildschirm).
	_ensure_chrome()
	if arena != null:
		# Gemeinsame 3D-Szene: ein 2D-Bild aus der Zeit vor dem Einhaengen
		# (Aufstellung setzt die Blickrichtung frueher) muss weg -- sonst stand
		# der DROME doppelt da, einmal eingefroren (18. Nov. 2026, Spieler).
		for child in _rig.get_children():
			if child is Sprite2D or child is SubViewport:
				_rig.remove_child(child)
				child.queue_free()
		_sprites = {}
		arena.rebuild(self)
	else:
		_sprites = DromeSprites.assemble(_rig, build, facing)
	# Sentinels kleiner (60 %, SPOT-Blatt Fragen 13), bis eigene Sprites kommen.
	# Skaliert um die Fuesse (SPRITE_ORIGIN = Feldmitte), nicht um die linke
	# obere Bildecke -- sonst hingen sie ueber ihrem Feld in der Luft (bis
	# 16. Nov. 2026: "die Sentinels schweben").
	if build != null and build.sprite_scale != 1.0:
		_scale_about_feet(_rig, build.sprite_scale)
	# Der Bodenring passt zur Figur (Arena3D.figure_scale, 18. Nov. 2026).
	var small := maxf(0.7, build.sprite_scale) if build != null else 1.0
	_scale_about_feet(_ring, small * Arena3D.figure_scale())
	_refresh_tint()


## Die Ruhelage der Figur: bei kleineren Einheiten (Sentinels) liegt sie um
## die Fuesse verschoben, nicht bei null. Rueckstoss und Erschuetterung kehren
## hierher zurueck -- bis 17. Nov. 2026 kehrten sie nach (0, 0) zurueck, und
## ein Sentinel schwebte nach dem ersten Schuss wieder ueber seinem Feld.
func _rig_home() -> Vector2:
	var factor := build.sprite_scale if build != null else 1.0
	return IsoView.SPRITE_ORIGIN * (1.0 - factor)


static func _scale_about_feet(node: Node2D, factor: float) -> void:
	node.scale = Vector2.ONE * factor
	node.position = IsoView.SPRITE_ORIGIN * (1.0 - factor)


## Beim Richtungswechsel werden alle Teile auf ihre Variante fuer diese
## Richtung gewechselt -- und die Zeichenebenen gleich mit.
func set_facing(direction: String) -> void:
	if direction == facing:
		return
	facing = direction
	if arena != null and arena.model_of(self) != null:
		arena.face(self)
		return
	_build_sprites()


## Setzt die Einheit auf ein Feld. Rein visuell -- die Belegung des Gitters
## fuehrt der BattleManager, damit es nur eine Wahrheit gibt.
func place_at(new_tile: Vector2i) -> void:
	tile = new_tile
	_prev_position = position
	_prev_vel = _vel
	_prev_track = _track
	_track = IsoView.sprite_position(new_tile)
	position = _track + stand_offset()
	_vel = Vector2.ZERO
	_acc = Vector2.ZERO
	_spring_on = false
	_glide_total = 0.0


## Die letzte Versetzung (place_at) sichtbar nachgleiten: vom Ort, an dem die
## Figur vorher gezeichnet wurde, zum neuen Feld. Laufen (``eased`` false)
## geht ueber die Feder -- die Figur behaelt ihr Tempo aus dem letzten
## Schritt und laeuft durch; Sog und Stoss rutschen wie bisher.
func animate_last_move(seconds: float, eased: bool = false) -> void:
	if eased:
		glide_to(tile, seconds, _prev_position)
		_glide_eased = true
		return
	position = _prev_position
	_vel = _prev_vel
	_glide_from = _prev_track
	_glide_to = IsoView.sprite_position(tile)
	_track = _glide_from
	_glide_time = 0.0
	_glide_total = maxf(0.01, seconds)
	_glide_eased = false
	_spring_on = true


## Wie place_at, aber die Figur gleitet in ``seconds`` vom bisherigen Ort
## dorthin (gerade, ohne Feder). Das Feld gilt sofort -- nur das Bild laeuft
## hinterher.
func glide_to(new_tile: Vector2i, seconds: float, from_position: Vector2) -> void:
	tile = new_tile
	_glide_from = from_position - stand_offset()
	_glide_to = IsoView.sprite_position(new_tile)
	_glide_time = 0.0
	_glide_total = maxf(0.01, seconds)
	_glide_eased = false
	_spring_on = false
	_vel = Vector2.ZERO
	position = from_position


func _process(delta: float) -> void:
	if _glide_total > 0.0:
		_glide_time += delta
		var t := clampf(_glide_time / _glide_total, 0.0, 1.0)
		_track = _glide_from.lerp(_glide_to, ease(t, 0.35) if _glide_eased else t)
		if t >= 1.0:
			_glide_total = 0.0
		if _glide_eased:
			position = _track + stand_offset() + nudge
			return
	if held or not _spring_on:
		return
	_spring_step(delta)


## Gedaempfte Feder (kritisch gedaempft) von der Figur zum Fuehrungspunkt.
## In kleinen Teilschritten, damit sie auch bei ruckelnden Bildern stabil ist.
func _spring_step(delta: float) -> void:
	var omega := motion_value("omega", 14.0)
	var target := _track + stand_offset() + nudge
	var left := minf(delta, 0.25)
	var before := _vel
	while left > 0.0:
		var dt := minf(left, 1.0 / 120.0)
		left -= dt
		var acc := (target - position) * omega * omega - _vel * 2.0 * omega
		_vel += acc * dt
		position += _vel * dt
	if delta > 0.0:
		_acc = _acc.lerp((_vel - before) / delta, clampf(delta * 20.0, 0.0, 1.0))
	if _glide_total <= 0.0 and position.distance_to(target) < 0.25 and _vel.length() < 3.0:
		position = target
		_vel = Vector2.ZERO
		_acc = Vector2.ZERO
		_spring_on = false


## Tempo und Beschleunigung der gezeichneten Figur (Bildpunkte je s bzw. s^2)
## -- fuer Neigung, Schrittlaenge und Blick in Laufrichtung (Arena3D).
func visual_velocity() -> Vector2:
	return _vel


func visual_accel() -> Vector2:
	return _acc


## Lockere Aufstellung (A5): ein kleiner, fester Versatz je Figur in ihrem
## Feld -- aus der Kennung, nicht gewuerfelt, also in jedem Kampf gleich.
func stand_offset() -> Vector2:
	var share := float(Config.section("motion").get("offset", 0.0))
	if share <= 0.0:
		return Vector2.ZERO
	var h := hash(str(unit_id))
	var angle := float(h % 6283) / 1000.0
	var radius := (0.45 + 0.55 * float((h / 6283) % 1000) / 1000.0) * share * IsoView.TILE_W * 0.5
	return Vector2(cos(angle), sin(angle) * IsoView.DEPTH_SQUASH) * radius


## Ein Wert je Chassis aus data/config.json -> motion (Eintrag "_" als Vorgabe).
func motion_value(key: String, fallback: float) -> float:
	return Unit.motion_for(key, str(build.body().id) if build != null and build.body() != null else "", fallback)


static func motion_for(key: String, chassis: String, fallback: float) -> float:
	var entry = Config.section("motion").get(key, fallback)
	if entry is Dictionary:
		return float(entry.get(chassis, entry.get("_", fallback)))
	return float(entry)


## Die Feldmitte unter der Figur, so wie sie gerade gezeichnet wird -- fuer
## den Lebensbalken, der mitgleiten soll.
func visual_anchor() -> Vector2:
	return position + IsoView.SPRITE_ORIGIN


## Blickrichtung auf dem Hexfeld (17. Nov. 2026): ein Winkel im Bild,
## "deg<grad>" (0 = rechts, gegen den Uhrzeigersinn), siehe
## DromeModel.facing_basis. Zu Beginn schaut der Spieler nach oben, der
## Gegner nach unten; danach in eine der sechs Hexrichtungen.
const FACING_PLAYER := "deg90"
const FACING_ENEMY := "deg270"


## Genau zum Ziel (18. Nov. 2026): der Winkel im Bild statt der naechsten
## Hexrichtung -- sonst zeigt ein Gewehr bis zu 30 Grad am Ziel vorbei.
## Fuer Angriffe und Faehigkeiten; Laufen bleibt bei den sechs Richtungen.
static func facing_at(from: Vector2i, to: Vector2i) -> String:
	var d := IsoView.map_to_local(to) - IsoView.map_to_local(from)
	if d == Vector2.ZERO:
		return FACING_PLAYER
	# Auf dem Boden gemessen (21. Nov. 2026): die Tiefe ist im Bild gestaucht,
	# also zurueckrechnen -- sonst zeigte die Waffe bei steilen Winkeln vorbei.
	return "deg%d" % int(round(fposmod(rad_to_deg(atan2(-d.y / IsoView.DEPTH_SQUASH, d.x)), 360.0)))


static func facing_toward(from: Vector2i, to: Vector2i) -> String:
	var dir := Grid.direction_toward(from, to)
	if dir < 0:
		return FACING_PLAYER
	return "deg%d" % int(Grid.direction_angle(dir))


## Fraktionsfarbstich und Trefferblende treffen sich hier -- und nur hier.
func _refresh_tint() -> void:
	if _flashing:
		return
	_apply_tint(base_tint())


## Der Farbstich der Seite -- entfaellt bei DROMEs mit Fraktions-Palette
## (18. Nov. 2026): ihre Farben sind die Erkennung, der rote Stich wuerde
## z. B. das Solar-Gruen verschmutzen. Die Seite zeigen Bodenring und Balken.
func base_tint() -> Color:
	if not DromeModel.faction_palette(build).is_empty():
		return Color.WHITE
	return Teams.tint(is_player)


## Das Rig (Rueckstoss, Erschuetterung, Sentinel-Groesse) -- die Arena liest
## daraus, wo das 3D-Modell steht.
func rig() -> Node2D:
	return _rig


func _apply_tint(color: Color) -> void:
	if arena != null:
		arena.tint(self, color)
	else:
		DromeSprites.tint(_sprites, color)


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
##
## In der gemeinsamen 3D-Szene bewegt sich statt des ganzen DROME die Waffe
## (Arena3D.attack, 18. Nov. 2026): Nahkampf holt aus und schlaegt zu,
## Fernkampf mit Rueckstoss und Muendungsblitz, Schild stoesst vor.
func play_attack(toward: Vector2i, action: ActionData = null, seconds: float = -1.0) -> void:
	if _rig == null:
		return
	if arena != null and arena.attack(self, action, seconds):
		return
	var delta := IsoView.map_to_local(toward) - IsoView.map_to_local(tile)
	var push := Vector2.ZERO if delta == Vector2.ZERO \
		else delta.normalized() * RECOIL_DISTANCE
	var tween := create_tween()
	var home := _rig_home()
	tween.tween_property(_rig, "position", home + push, RECOIL_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_rig, "position", home, RECOIL_TIME * 2.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Ein Wurf (Runenstab-Faehigkeit, Bumerang): hoch, Schwung, loslassen in der
## Mitte des Schwungs; ``hide`` Sekunden ist die Waffe danach nicht in der Hand.
func play_throw(action: ActionData, seconds: float, hide: float = 0.0) -> void:
	if arena != null:
		arena.throw(self, action, seconds, hide)


## Das Ziel zuckt und blendet kurz hell auf. Die Erschuetterung laeuft ueber
## abklingende Ausschlaege statt ueber ein Rauschen -- so endet sie sichtbar
## und nicht einfach irgendwann.
func play_hit() -> void:
	if _rig == null:
		return
	if arena != null:
		arena.hit(self)
	var home := _rig_home()
	var tween := create_tween()
	var steps := 5
	for i in steps:
		var decay := 1.0 - float(i) / float(steps)
		var side := 1.0 if i % 2 == 0 else -1.0
		tween.tween_property(_rig, "position",
			home + Vector2(SHAKE_AMPLITUDE * decay * side, 0.0),
			SHAKE_TIME / float(steps)).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_rig, "position", home, SHAKE_TIME / float(steps))

	_flashing = true
	_apply_tint(Teams.HIT_FLASH)
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
	_apply_tint(Color(1.1, 2.2, 1.3))
	var flash := create_tween()
	flash.tween_interval(0.14)
	flash.tween_callback(func():
		_flashing = false
		_refresh_tint())


## Wie lange das Zerfallen dauert -- der Kampfbildschirm wartet so lange,
## bevor das Ergebnis kommt (Wunsch des Spielers, 17. Nov. 2026).
const DEATH_TIME := 1.1
const DEATH_TIME_CALM := 0.35


## Zerstoert: kurzer heller Blitz, dann fallen die Bauteile auseinander --
## jedes fliegt ein Stueck zur Seite, kippt, faellt auf den Boden und
## verblasst; der Bodenring erlischt. Bei "Bewegung reduzieren" blendet die
## Figur nur aus. Am Ende ist die Einheit unsichtbar wie bisher.
func play_death() -> void:
	if _rig == null:
		visible = false
		return
	var calm := Accessibility.reduce_motion
	var total := DEATH_TIME_CALM if calm else DEATH_TIME
	_apply_tint(Teams.HIT_FLASH)
	_flashing = true
	var turn: Node3D = arena.turn_of(self) if arena != null \
		else _rig.get_node_or_null("Ansicht3D/Drome/Ausrichtung") as Node3D
	if turn != null:
		_death_3d(turn, total, calm)
		return
	var parts: Array = []
	for child in _rig.get_children():
		if child is Sprite2D:
			parts.append(child)
	# Gleiche Zufallsfolge je Einheit: sieht jedes Mal gleich aus, wirkt aber
	# nicht schematisch.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(unit_id))
	var center := IsoView.SPRITE_ORIGIN + Vector2(0, -28)
	for sprite: Sprite2D in parts:
		var tween := create_tween().set_parallel(true)
		if calm:
			tween.tween_property(sprite, "modulate:a", 0.0, total)
			continue
		var start := sprite.position
		var away: Vector2 = (sprite.position + sprite.offset - center)
		var side := signf(away.x) if absf(away.x) > 2.0 else (1.0 if rng.randf() < 0.5 else -1.0)
		var land := start + Vector2(side * rng.randf_range(10.0, 26.0),
			rng.randf_range(14.0, 30.0))
		var hop := start + Vector2(side * rng.randf_range(4.0, 10.0), -rng.randf_range(8.0, 18.0))
		var spin := side * rng.randf_range(0.5, 1.4)
		tween.tween_property(sprite, "position", hop, total * 0.25) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "position", land, total * 0.5) \
			.set_delay(total * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(sprite, "rotation", spin, total * 0.75)
		tween.tween_property(sprite, "modulate:a", 0.0, total * 0.35).set_delay(total * 0.65)
	if _ring != null:
		create_tween().tween_property(_ring, "modulate:a", 0.0, total * 0.6)
	var flash := create_tween()
	flash.tween_interval(0.08)
	flash.tween_callback(func():
		_flashing = false
		_refresh_tint())
	var done := create_tween()
	done.tween_interval(total)
	done.tween_callback(func(): visible = false)


## Zerfallen des 3D-DROME (17. Nov. 2026): jeder Block (Fuesse, Rumpf, Kern,
## Kopf, Waffe, Waffenarm) springt ein Stueck vom Koerper weg, kippt und
## faellt auf den Boden; am Ende verblasst das ganze Bild. Koordinaten unter
## "Ausrichtung" sind bot-lokal (f, l, z) in Weltmetern.
func _death_3d(turn: Node3D, total: float, calm: bool) -> void:
	var sprite := _rig.get_node_or_null("Drome") as Sprite2D
	if arena == null:
		DromeSprites.redraw(_rig, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(unit_id))
	if not calm:
		var unit_m := 1.0 / DromeModel.SCALE      # ein Entwurfspunkt in Metern
		# Jeder Block bekommt seine eigene Richtung (goldener Winkel), dazu
		# ein Zug weg von der Koerpermitte -- so streuen die Teile rundum.
		var base := rng.randf() * TAU
		var index := 0
		for block in turn.get_children():
			if not block is MeshInstance3D:
				continue
			var inst := block as MeshInstance3D
			var box := inst.get_aabb()
			var mid := inst.position + box.get_center()
			var away := Vector2.from_angle(base + index * 2.39996) + Vector2(mid.x, mid.y) * 0.08
			away = away.normalized()
			index += 1
			var reach := rng.randf_range(12.0, 22.0) * unit_m
			var start := inst.position
			var pivot := box.get_center()          # gedreht wird um die Blockmitte
			var hop := start + Vector3(away.x, away.y, 0) * reach * 0.35 \
				+ Vector3(0, 0, rng.randf_range(4.0, 10.0) * unit_m)
			# Landen: die Blockmitte knapp ueber dem Boden (z = 0) -- liegt.
			var land := start + Vector3(away.x, away.y, 0) * reach
			land.z = minf(box.size.z, box.size.x) * 0.4 - pivot.z
			var axis := Vector3(-away.y, away.x, 0).normalized()
			var angle := rng.randf_range(0.6, 1.4) * (1.0 if rng.randf() < 0.5 else -1.0)
			create_tween().tween_method(func(t: float) -> void:
				var p: Vector3
				if t < 1.0 / 3.0:
					var u := t * 3.0
					p = start.lerp(hop, 1.0 - (1.0 - u) * (1.0 - u))
				else:
					var u := (t - 1.0 / 3.0) * 1.5
					p = hop.lerp(land, u * u)
				var turn_b := Basis(axis, angle * t)
				inst.transform = Transform3D(turn_b, p + pivot - turn_b * pivot),
				0.0, 1.0, total * 0.75)
	if sprite != null:
		create_tween().tween_property(sprite, "modulate:a", 0.0,
			total if calm else total * 0.35).set_delay(0.0 if calm else total * 0.65)
	elif arena != null:
		# Gemeinsame Szene: kein eigenes Bild zum Ausblenden -- die Truemmer
		# verdunkeln sich und verschwinden dann.
		var dark := create_tween()
		dark.tween_interval(0.0 if calm else total * 0.6)
		dark.tween_method(func(k: float) -> void:
			_apply_tint(base_tint().lerp(Color(0.15, 0.15, 0.2), k)),
			0.0, 1.0, total * (1.0 if calm else 0.4))
	if _ring != null:
		create_tween().tween_property(_ring, "modulate:a", 0.0, total * 0.6)
	var flash := create_tween()
	flash.tween_interval(0.08)
	flash.tween_callback(func():
		_flashing = false
		_refresh_tint())
	var done := create_tween()
	done.tween_interval(total)
	done.tween_callback(func():
		if arena == null:
			DromeSprites.redraw(_rig)
		visible = false)


## Der Bodenring: eine flache Ellipse in Fraktionsfarbe unter den Fuessen.
class UnitRing extends Node2D:
	const RADIUS_X := 30.0
	const RADIUS_Y := 30.0 * IsoView.TILE_H / IsoView.TILE_W
	const SHADOW_STEPS := 5
	const SHADOW_SIZE := 1.08
	const SHADOW_ALPHA := 0.15

	var tint: Color = Teams.PLAYER:
		set(value):
			tint = value
			queue_redraw()

	func _draw() -> void:
		# Die Einheit sitzt mit ihrem Ursprung in der oberen linken Ecke des
		# 128er Bildes; die Feldmitte liegt bei SPRITE_ORIGIN.
		var center := IsoView.SPRITE_ORIGIN
		# Blob-Schatten (21. Nov. 2026, Kampfbild mehr 3D B6 Stufe 1): ein
		# weicher dunkler Fleck unter der Figur -- sie steht auf dem Boden.
		for k in SHADOW_STEPS:
			var f := 1.0 - float(k) / float(SHADOW_STEPS)
			_fill_ellipse(center, RADIUS_X * SHADOW_SIZE * f, RADIUS_Y * SHADOW_SIZE * f,
				Color(0.0, 0.0, 0.03, SHADOW_ALPHA))
		_ellipse(center, RADIUS_X, RADIUS_Y, Color(tint, 0.85), 3.0)
		_ellipse(center, RADIUS_X * 0.62, RADIUS_Y * 0.62, Color(tint, 0.30), 2.0)

	func _fill_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
		var points := PackedVector2Array()
		for i in 24:
			var angle := TAU * float(i) / 24.0
			points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
		draw_colored_polygon(points, color)

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
	cast = {}
	echoes.clear()
	aim_hold = 0.0
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
		# Waffenlevel (Leveling): Schaden waechst, als Kopie.
		var level := build.weapon_level(slot)
		# Charger der Waffe (20. Nov. 2026): Elementarbelastung je Treffer.
		var spec := Charger.combat_spec(build.charger_phases(slot))
		var attack: ActionData = null
		for action in part.actions:
			if action.is_attack():
				attack = Leveling.level_action(action, part, level).with_modules(fx).with_charger(spec, false)
				break
		for action in part.actions:
			if action.is_attack() or build.auto_only:
				continue
			if action.trigger_kind == "attacks" and attack != null:
				continue
			var gadget_action: ActionData = Leveling.level_action(action, part, level).with_modules(fx)
			var first := float(gadget_action.trigger_every) * echo_slower() \
				if gadget_action.trigger_kind == "time" else 0.0
			gadgets.append({"part": part, "ability": gadget_action, "ready": first, "fx": fx})
		# Module mit eigener Faehigkeit (Orbit-Fokus, Hologramm). Seit 9. Nov.
		# 2026 zaehlen sie die Angriffe der Waffe in ihrem Halter ("extras"
		# am Halter); nur Ereignisse (Hologramm: Gegner daneben) bleiben Gadgets.
		var extras: Array = []
		for module in build.active_modules(slot):
			var granted := ModuleData.gadget_action(module.gadget)
			if granted != null:
				granted = granted.with_modules(fx)
				if granted.trigger_kind == "attacks":
					extras.append({"ability": granted, "count": 0.0})
					continue
				var first_ready := float(granted.trigger_every) * echo_slower() \
					if granted.trigger_kind == "time" else 0.0
				gadgets.append({"part": part, "ability": granted, "ready": first_ready, "fx": fx})
		if attack == null:
			continue
		var ability: ActionData = null
		# Sentinels loesen nur den Auto-Angriff aus (SPOT-Blatt Fragen 2).
		for action in ([] if build.auto_only else part.actions):
			if not action.is_attack() and action.trigger_kind == "attacks":
				ability = Leveling.level_action(action, part, level).with_modules(fx).with_charger(spec, true)
		# Ein halbes Intervall Vorlauf: niemand schiesst im ersten Augenblick.
		mounts.append({"slot": slot, "part": part, "attack": attack,
			"ability": ability, "ready": attack.interval * 0.5, "count": 0,
			"fx": fx, "shots": 0, "base_attack": attack, "base_ability": ability,
			"extras": extras})


## Der Takt einer Treffer-Faehigkeit an diesem DROME: der wievielte Angriff
## sie ist. Mit der Passive Echo (Nimbus) laenger: die normalen Angriffe
## dazwischen mal ``passives.echo.slower`` (gerundet) -- Blaster jeder 3. ->
## jeder 4.
func takt_every(ability: ActionData) -> int:
	var every := int(ability.trigger_every)
	if ability.trigger_kind != "attacks" or passive() != "echo":
		return every
	return int(round(float(every - 1) * echo_slower())) + 1


## Wie viel ein Angriff im Treffer-Takt zaehlt: 1, mit Taktchip 1,25
## (modules.json -> takt_count). Der Zaehler (mount["count"]) ist deshalb
## eine Kommazahl; der Rest ueber den Takt hinaus bleibt nach der Faehigkeit.
func takt_step(mount: Dictionary) -> float:
	return maxf(1.0, float((mount.get("fx", {}) as Dictionary).get("takt_count", 1.0)))


## Ist der naechste Angriff dieses Halters die Faehigkeit?
func takt_due(mount: Dictionary) -> bool:
	var ability = mount.get("ability")
	if ability == null:
		return false
	return float(mount["count"]) + takt_step(mount) >= float(takt_every(ability)) - 0.001


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
		var count := float(mount["count"])
		var ready := takt_due(mount)
		out.append({"kind": "hits", "segments": every,
			"filled": every if ready else mini(every - 1, int(count)), "ready": ready})
	# Modul-Faehigkeiten nach Angriffen (Orbit-Fokus).
	for mount in mounts:
		for extra in mount.get("extras", []):
			var each := takt_every(extra["ability"])
			var have := int(float(extra["count"]))
			out.append({"kind": "hits", "segments": each,
				"filled": mini(each, have), "ready": have >= each - 1})
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
	var needed := float(rule.get("seconds", 4.0))
	var now := passive() == "steady" and still_time >= needed
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
	if build == null or build.body() == null or build.is_sentinel():
		return ""
	return build.body().passive


## Faktor aufs Angriffstempo aus Statuseffekten.
func attack_speed_mult() -> float:
	var mult := 1.0 + float(cyberspeed_stacks) * float(_cyberspeed().get("attack_speed", 0.1))
	for status in statuses.values():
		mult *= float(status.get("attack_speed_mult", 1.0))
	return maxf(0.1, mult)


## Wie die KI diesen DROME fuehrt -- aus dem Chassis. Leer = nach Waffe.
func ai_role() -> String:
	if build != null and build.role_override != "":
		return build.role_override
	if build == null or build.body() == null:
		return ""
	return build.body().ai_role


func is_sentinel() -> bool:
	return build != null and build.is_sentinel()


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
	speed *= 1.0 + float(cyberspeed_stacks) * float(_cyberspeed().get("move", 0.1))
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


## So lange nach dem letzten Feldwechsel gilt ein DROME als "in Bewegung"
## (Klingenbumerang, ActionData.moving_bonus).
const MOVING_WINDOW := 1.0


## Rohschaden einer Aktion: ihr Schaden mal Power. Davor kommt nichts, danach
## Schild und Ruestung (ActionResolver.resolve_damage).
func raw_damage(action: ActionData) -> int:
	if action == null or action.power <= 0:
		return 0
	var raw := float(action.power) * power_factor()
	if steady:
		raw *= float(steady_rule().get("damage_mult", 1.2))
	# Klingenbumerang: wer gerade gelaufen ist, wirft haerter.
	if action.moving_bonus > 0.0 and still_time < MOVING_WINDOW:
		raw *= 1.0 + action.moving_bonus
	# Rammbock: ein Teil der eigenen Panzerung kommt dazu, ohne Power.
	if action.armor_to_damage > 0.0:
		raw += float(def()) * action.armor_to_damage
	# Bollwerk-Ramme: ein Teil der eigenen maximalen Integritaet, ohne Power.
	if action.hp_scaling > 0.0:
		raw += float(stat("hp_max")) * action.hp_scaling
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
## ``source``: wer den Effekt ausloest -- seine Effizienz streckt die Dauer.
func apply_status(id: StringName, seconds: float, modifiers: Dictionary,
		source: Unit = null) -> void:
	var status := modifiers.duplicate()
	if source != null:
		var factor := source.efficiency_factor()
		seconds *= factor
		_scale_strength(status, factor)
	status["seconds_left"] = seconds
	statuses[id] = status


## Staerke eines Statuseffekts mit der Effizienz: die Abweichung von 1 der
## Faktoren (Verlangsamen, Sprint, Angriffstempo, verwundbar) waechst mit.
## Verlangsamen hoechstens ``statuses.efficiency.slow_cap`` (Anteil).
static func _scale_strength(status: Dictionary, factor: float) -> void:
	if is_equal_approx(factor, 1.0):
		return
	for key in ["move_mult", "attack_speed_mult", "damage_taken_mult"]:
		if status.has(key):
			status[key] = maxf(0.0, 1.0 + (float(status[key]) - 1.0) * factor)
	if status.has("move_mult"):
		var rule := Config.section("statuses").get("efficiency", {}) as Dictionary
		var cap := float(rule.get("slow_cap", 0.7))
		status["move_mult"] = maxf(1.0 - cap, float(status["move_mult"]))


## Cyberspeed (Vireo-Passive, Spieler 22. Nov. 2026, gebaut 25. Nov.): jeder
## ``every``-te Angriff gibt einen Stapel (hoechstens ``max_stacks``), je
## Stapel mehr Angriffs- und Lauftempo. Jeder Angriff startet die Dauer
## ``seconds`` neu (mit der Effizienz gestreckt); laeuft sie ab, fallen alle
## Stapel und der Zaehler. Die Faehigkeit zaehlt als Angriff.
func on_attack() -> void:
	if passive() != "cyberspeed" or not is_alive():
		return
	var rule := _cyberspeed()
	cyberspeed_count += 1
	if cyberspeed_count >= maxi(1, int(rule.get("every", 3))):
		cyberspeed_count = 0
		cyberspeed_stacks = mini(int(rule.get("max_stacks", 3)), cyberspeed_stacks + 1)
	cyberspeed_left = float(rule.get("seconds", 3.0)) * efficiency_factor()


static func _cyberspeed() -> Dictionary:
	return Config.section("passives").get("cyberspeed", {}) as Dictionary


## Effizienz (20. Nov. 2026): versteckter Wert, Grundwert
## ``statuses.efficiency.base`` (10 = 100 %). Streckt Dauer und Wirkung der
## Statuseffekte, die dieser DROME ausloest -- nie die Schadenszahl.
func efficiency() -> int:
	return maxi(0, stat("efficiency"))


static func efficiency_base() -> int:
	var rule := Config.section("statuses").get("efficiency", {}) as Dictionary
	return maxi(1, int(rule.get("base", 10)))


func efficiency_factor() -> float:
	return float(efficiency()) / float(efficiency_base())


## Kabelbrand: legt ``stacks`` Stapel auf diesen DROME, gestreckt mit der
## Effizienz des Ausloesers. Bruchteile sammeln sich (zwei Treffer mit 1,5
## ergeben drei Stapel). Verbraucht wird je Puls (BattleManager).
func add_cable_fire(stacks: float, source: Unit = null) -> void:
	if stacks <= 0.0 or not is_alive():
		return
	if source != null:
		stacks *= source.efficiency_factor()
		cable_fire_source = source.unit_id
	cable_fire += stacks


## Legt Elementarbelastung an und gibt zurueck, wie viele Stapel dabei voll
## wurden (je ``stack_at``; der Rest zaehlt weiter).
func add_element_load(element: String, amount: float, stack_at: float = 100.0) -> int:
	if amount <= 0.0 or not is_alive() or stack_at <= 0.0:
		return 0
	var total := float(element_load.get(element, 0.0)) + amount
	var stacks := int(floor(total / stack_at + 0.0001))
	element_load[element] = maxf(0.0, total - float(stacks) * stack_at)
	return stacks


## Ganze Kabelbrand-Stapel, die gerade auf dem DROME liegen.
func cable_fire_stacks() -> int:
	return int(floor(cable_fire + 0.0001))


## Nimmt hoechstens ``limit`` ganze Stapel herunter und gibt ihre Zahl zurueck.
func take_cable_fire(limit: int) -> int:
	var taken := mini(cable_fire_stacks(), maxi(0, limit))
	cable_fire = maxf(0.0, cable_fire - float(taken))
	return taken


## Je Simulationsschritt. Gibt true zurueck, wenn ein Effekt abgelaufen ist.
func tick_statuses(dt: float) -> bool:
	burst_cooldown = maxf(0.0, burst_cooldown - dt)
	var changed := false
	if cyberspeed_left > 0.0:
		cyberspeed_left -= dt
		if cyberspeed_left <= 0.0:
			changed = cyberspeed_stacks > 0
			cyberspeed_left = 0.0
			cyberspeed_stacks = 0
			cyberspeed_count = 0
	for id in statuses.keys():
		statuses[id]["seconds_left"] = float(statuses[id]["seconds_left"]) - dt
		if float(statuses[id]["seconds_left"]) <= 0.0:
			statuses.erase(id)
			changed = true
	return changed


func status_names() -> Array[String]:
	var names: Array[String] = []
	for id in statuses:
		# Das kurze Festhalten im Sog zeigt der Vortex selbst.
		if id == &"vortex_hold":
			continue
		names.append(str(id))
	# Cyberspeed: ein Sprint-Symbol je Stapel.
	for i in cyberspeed_stacks:
		names.append("rush")
	if cable_fire_stacks() > 0:
		names.append("cable_fire")
	return names


func _to_string() -> String:
	return "Unit(%s %s hp=%d/%d)" % [
		unit_id, tile, hp, stats.get("hp_max", 0)]
