extends Node2D

## Der Kampfbildschirm im Echtzeit-Kampf (Nov. 2026).
##
## Hier steht keine Regel. Der BattleManager rechnet den Kampf in festen
## Schritten; dieser Knoten ruft die Schritte so oft auf, wie Zeit vergangen
## ist, und uebersetzt, was dabei passiert, in Bilder: gleitende Figuren,
## Schussspuren, schwebende Zahlen, Balken und Kacheln.
##
## Der Spieler steuert nicht. Er sieht zu, kann pausieren, das Tempo
## verdoppeln, das Protokoll oeffnen und die Kamera selbst fuehren.

## Kamerastoss beim Treffer. Der Ausschlag skaliert mit dem Anteil der
## Integritaet, den der Treffer gekostet hat.
const CAMERA_SHAKE_MAX := 7.0
const CAMERA_SHAKE_TIME := 0.22

## Tempo. Laeuft ueber Engine.time_scale, damit Simulation, Gleiten und Tweens
## gemeinsam schneller werden. Bewusst nur 1x und 2x: schneller ist der Kampf
## nicht mehr lesbar.
const SPEEDS := [1.0, 2.0]

## Kamera (mobile first): sie haelt das Geschehen im Bild -- den Rahmen um alle
## lebenden DROMEs, in einem lesbaren Zoom. Ein Finger zieht, zwei zoomen; wer
## selbst schiebt, schaltet das Folgen ab, "Folgen" holt es zurueck.
const ZOOM_MIN := 0.2
const ZOOM_MAX := 1.2
const DRAG_THRESHOLD := 10.0
const FOLLOW_EASE := 2.5

## Hoechstens so viele Simulationsschritte je Bild -- haengt ein Bild, holt der
## Kampf nicht in einem Ruck Sekunden nach.
const MAX_STEPS_PER_FRAME := 8

@onready var view: BattleView = $BattleView
@onready var camera: Camera2D = $Camera2D

var battle: BattleManager
## Aufstellung vor dem Kampf (Nov. 2026): solange true, laeuft die Zeit nicht,
## und der Spieler zieht seine DROMEs in der markierten Zone zurecht.
var _deploying: bool = true
## Aufstellung: die Figur unter dem Finger (_grabbed), ab der Ziehschwelle
## auch gezogen (_dragged), und die per Antippen gewaehlte (_selected).
var _grabbed: Unit = null
var _dragged: Unit = null
var _selected: Unit = null
var _grab_start := Vector2.ZERO
var _grab_offset := Vector2.ZERO
var _deploy_bar: Control
var _play_bar: Control
var _paused: bool = false
var _over: bool = false
var _accumulator: float = 0.0
## Das gewaehlte Tempo bleibt fuer den naechsten Kampf (14. Nov. 2026).
static var _speed_memory: int = 0
var _speed_index: int = _speed_memory

var _follow := true
var _touches: Dictionary = {}
var _drag_distance := 0.0
var _pinch_distance := 0.0
var _pinch_zoom := 1.0

# UI
var _ui: CanvasLayer
var _status: Label
var _clock: Label
var _foes: Label
var _where: Label
var _round_label: Label
var _squad_tiles: SquadTiles
var _top_box: VBoxContainer
var _side_panel: PanelContainer
var _frame: Control
const SIDE_WIDTH := 132.0

## Fokus nach Antippen einer Kachel: groesserer Balken bis _focus_until (ms).
const FOCUS_MS := 3000
var _focus_id = null
var _focus_until: int = 0
var _log: RichTextLabel
var _log_panel: PanelContainer
var _speed_button: Button
var _pause_button: Button
var _follow_button: Button
## Glitch ueber dem Bild: Vorwarnung vor dem Virus und je Viruspuls.
var _glitch: Arcade.GlitchOverlay
## Kampfzeit des naechsten Warn-Flackerns (-1 = noch nicht gesetzt).
var _next_flicker: float = -1.0


func _ready() -> void:
	battle = BattleManager.new()
	add_child(battle)
	_build_ui()

	EventBus.log_message.connect(_on_log)
	EventBus.unit_moved.connect(_on_unit_moved)
	EventBus.unit_died.connect(_on_unit_died)
	EventBus.unit_damaged.connect(_on_unit_damaged)
	EventBus.unit_healed.connect(_on_unit_healed)
	EventBus.action_used.connect(_on_action_used)
	EventBus.ability_cast.connect(_on_ability_cast)
	EventBus.virus_pulsed.connect(_on_virus_pulse)
	battle.battle_over.connect(_on_battle_over)

	_start_battle()


func _start_battle() -> void:
	var builds := GameState.squad
	if builds.is_empty():
		builds = _demo_squad()
		GameState.squad = builds
	if GameState.battle_seed == 0:
		GameState.new_seed()

	battle.setup(GameState.battle_seed, builds, GameState.enemy_override,
		GameState.battle_region, GameState.battle_map)
	battle.virus_enabled = true
	view.build_terrain(battle.grid)
	# Die gemerkte Aufstellung des letzten Kampfs, wenn sie noch passt.
	battle.apply_formation(GameState.formation)
	for unit in battle.units:
		view.attach_unit(unit)
	view.abilities.units = battle.units

	camera.position = IsoView.grid_center(battle.grid.width, battle.grid.height)
	_add_scenery()
	_set_zoom(_follow_zoom())
	_follow_fight(1.0)
	_begin_deployment()

	_squad_tiles.setup(battle.living(true))
	_squad_tiles.tile_pressed.connect(_look_at_unit)
	_refresh_hud()


## Hochformat: Kacheln oben nebeneinander. Querformat: als Spalte links.
## Dazu die sicheren Raender (Notch, Gestenleiste), wo das System sie meldet.
func _apply_orientation() -> void:
	if _squad_tiles == null:
		return
	var portrait := Accessibility.is_portrait()
	var wanted: Node = _top_box if portrait else _side_panel
	if _squad_tiles.get_parent() != wanted:
		_squad_tiles.get_parent().remove_child(_squad_tiles)
		wanted.add_child(_squad_tiles)
		if portrait:
			_top_box.move_child(_squad_tiles, 0)
	_squad_tiles.set_vertical(not portrait)
	_side_panel.visible = not portrait
	var insets := UiKit.safe_insets(self)
	_frame.offset_top = insets["top"]
	_frame.offset_bottom = -insets["bottom"]
	_frame.offset_left = insets["left"]
	_frame.offset_right = -insets["right"]


## Nur fuer den Direktstart der Kampfszene ohne Hangar.
func _demo_squad() -> Array:
	return [
		DromeBuild.create("ALPHA", {
			"body": &"scout_body", "head": &"scout_head",
			"feet": &"scout_feet", "core": &"scout_core",
			"equip_left": &"eq_pulse_blaster"}),
		DromeBuild.create("BETA", {
			"body": &"strix_body", "head": &"strix_head",
			"feet": &"strix_feet", "core": &"strix_core",
			"equip_center": &"eq_rail_lance"}),
	]


## Die Kulisse ausserhalb des Spielfelds, passend zur Region. Eigene Ebene
## hinter der Karte, mit leichter Parallaxe zur Kamera.
func _add_scenery() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var region_id := str(battle.region.id) if battle.region != null else ""
	var scenery := Ambience.create(Ambience.kind_for_region(region_id))
	scenery.camera = camera
	scenery.camera_home = camera.position
	layer.add_child(scenery)


# ---------------------------------------------------------------------------
# Takt
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if battle == null or battle.grid == null:
		return
	if not _paused and not _over and not _deploying:
		_accumulator += delta
		var dt := battle.step_seconds()
		var steps := 0
		while _accumulator >= dt and steps < MAX_STEPS_PER_FRAME:
			battle.tick()
			_accumulator -= dt
			steps += 1
			if battle.outcome != BattleManager.Outcome.RUNNING:
				break
		if steps >= MAX_STEPS_PER_FRAME:
			_accumulator = 0.0
	_refresh_badges()
	_virus_flicker()
	if _follow and not _over and not _deploying:
		_follow_fight(delta)


func _virus_warn() -> float:
	return float(Config.section("virus").get("warn_seconds", 30.0))


## Die letzten Sekunden vor dem Virus flackert das Bild -- erst selten, dann
## immer schneller, bis es beim Start im Takt der Viruspulse ankommt.
func _virus_flicker() -> void:
	if _glitch == null or _over or _deploying or battle.virus_in() <= 0.0:
		return
	var warn := _virus_warn()
	var start := battle.virus_start()
	if _next_flicker < 0.0:
		_next_flicker = start - warn
	if battle.time < _next_flicker:
		return
	var progress := clampf(1.0 - battle.virus_in() / warn, 0.0, 1.0)
	_glitch.burst(0.35 + 0.55 * progress, 0.14 + 0.08 * progress)
	_next_flicker = battle.time + lerpf(2.4 * battle.pulse_seconds(), battle.pulse_seconds(), progress)


func _on_virus_pulse() -> void:
	if _glitch != null:
		_glitch.burst(1.0, 0.32)
	_shake_camera(0.6)
	Accessibility.vibrate(60)


## Kacheln und Statuszeile -- je Bild, das ist billig genug.
func _refresh_hud() -> void:
	_refresh_badges()
	if _squad_tiles != null:
		_squad_tiles.refresh(battle.units)
	if _over:
		return
	var region := battle.region.display_name if battle.region != null else ""
	_where.text = region.to_upper()
	var run := GameState.run if GameState.in_run_battle else null
	_round_label.text = ("KAMPF %d/%d" % [run.round, RunState.rounds_total()]) if run != null \
		and not run.is_endless() else ("KAMPF %d" % run.round if run != null else "")
	var foes_alive := 0
	var foes_total := 0
	for unit in battle.units:
		if not unit.is_player:
			foes_total += 1
			if unit.is_alive():
				foes_alive += 1
	_foes.text = "%d/%d" % [foes_alive, foes_total]
	if _deploying:
		_clock.text = "00:00"
		_clock.add_theme_color_override("font_color", Arcade.MUTED)
		_status.text = "AUFSTELLUNG"
		_status.add_theme_color_override("font_color", Arcade.YELLOW)
		return
	var seconds := int(battle.time)
	_clock.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	var until := battle.virus_in()
	var color := Arcade.WHITE
	_status.text = ""
	if until <= 0.0:
		_status.text = "VIRUS −%d %%" % int(round(float(Config.section("virus").get("pct_of_max", 0.1)) * 100.0))
		color = Arcade.MAGENTA
	elif until <= _virus_warn():
		_status.text = "VIRUS IN %d S" % int(ceil(until))
		color = Arcade.MAGENTA
	_clock.add_theme_color_override("font_color", color)
	_status.add_theme_color_override("font_color", Arcade.MAGENTA)
	if _paused:
		_status.text = ("%s · PAUSE" % _status.text) if _status.text != "" else "PAUSE"


func _refresh_badges() -> void:
	var entries: Array = []
	for unit in battle.units:
		if not unit.is_alive():
			continue
		entries.append({
			"at": unit.visual_anchor(),
			"hp": unit.hp, "hp_max": unit.stat("hp_max"),
			"shield": unit.shield, "shield_max": unit.shield_max(),
			"is_player": unit.is_player,
			"lured": battle.brain != null and battle.brain.lured_by(unit) != null,
			"takt": unit.takt_bars(),
			"id": unit.unit_id,
			"statuses": unit.statuses.keys(),
			"focus": unit.unit_id == _focus_id and Time.get_ticks_msec() < _focus_until,
			"small": unit.is_sentinel(),
		})
	view.show_unit_badges(entries)


# ---------------------------------------------------------------------------
# Ereignisse
# ---------------------------------------------------------------------------

func _on_log(text: String) -> void:
	_log.append_text(text + "\n")


## Gelaufen, gestossen, gesprungen: die Figur gleitet hinterher. Ein normaler
## Schritt dauert so lange wie die Schrittzeit; Stossen und Boost sind kurz.
func _on_unit_moved(unit: Unit, _from: Vector2i, _to: Vector2i) -> void:
	# Sog und Stoss (18. Nov. 2026): sichtbar rutschen statt springen.
	if battle.resolver.forcing:
		unit.animate_last_move(FORCED_SLIDE, true)
		view.refresh_unit_depth(unit)
		return
	var seconds := unit.step_left if unit.step_left > 0.0 else 0.18
	unit.animate_last_move(seconds)
	view.refresh_unit_depth(unit)


## Schussspur vom Schuetzen zum Ziel, Rueckstoss, und bei einer Faehigkeit
## ihr Name ueber der Figur -- damit man sieht, dass gerade der dritte Schuss
## die Doppelschuss war.
func _on_action_used(unit: Unit, tile: Vector2i, action: ActionData) -> void:
	AbilityFx.on_used(view, unit, tile, action, battle.units)
	_refresh_hud()


## Ausholen einer Faehigkeit (18. Nov. 2026): Ansage und Haltung, AbilityFx.
func _on_ability_cast(unit: Unit, tile: Vector2i, action: ActionData, seconds: float, _target) -> void:
	AbilityFx.on_cast(view, unit, tile, action, seconds, battle.units)


## Dauer, in der ein gezogener oder gestossener DROME auf sein Feld rutscht.
const FORCED_SLIDE := AbilityFx.FORCED_SLIDE


## Ein Treffer muss man sehen: Zucken, Blende, Zahl, und bei einem grossen
## Anteil an der Integritaet ein kurzer Kamerastoss.
func _on_unit_damaged(unit: Unit, amount: int, _source) -> void:
	unit.play_hit()
	if amount > 0:
		view.show_float(unit.visual_anchor(), "-%d" % amount,
			Color(1.0, 0.45, 0.4) if unit.is_player else Color(1.0, 0.9, 0.5))
	var maximum: int = maxi(1, unit.stat("hp_max"))
	_shake_camera(clampf(float(amount) / float(maximum), 0.0, 1.0))
	# Haptik: nur schwere Treffer auf die eigenen DROMEs (ab 10 %).
	if unit.is_player and float(amount) >= 0.1 * float(maximum):
		Accessibility.vibrate(25)
	_refresh_hud()


func _on_unit_healed(unit: Unit, amount: int, _source) -> void:
	unit.play_heal()
	if amount > 0:
		view.show_float(unit.visual_anchor(), "+%d" % amount, Color(0.45, 0.95, 0.6))
	_refresh_hud()


func _on_unit_died(unit: Unit) -> void:
	unit.play_death()
	Accessibility.vibrate(70 if unit.is_player else 35, true)
	_refresh_hud()


## Kurzer Kamerastoss, der von selbst zur Ruhe kommt. ``severity`` ist der
## Anteil der Maximalintegritaet, den der Treffer gekostet hat.
func _shake_camera(severity: float) -> void:
	if Accessibility.reduce_motion:
		return
	var strength := CAMERA_SHAKE_MAX * severity
	if strength < 1.5:
		return
	var tween := create_tween()
	var steps := 5
	for i in steps:
		var decay := 1.0 - float(i) / float(steps)
		tween.tween_property(camera, "offset",
			Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * decay,
			CAMERA_SHAKE_TIME / float(steps))
	tween.tween_property(camera, "offset", Vector2.ZERO, CAMERA_SHAKE_TIME / float(steps))


func _on_battle_over(outcome: BattleManager.Outcome) -> void:
	_over = true
	view.show_unit_badges([])
	_status.text = "%s nach %d s  ·  Seed %d" % [
		BattleManager.outcome_label(outcome), int(battle.time), battle.battle_seed]
	# Erst den letzten DROME zerfallen sehen, dann das Ergebnis (17. Nov. 2026).
	var wait := (Unit.DEATH_TIME_CALM if Accessibility.reduce_motion else Unit.DEATH_TIME) + 0.4
	get_tree().create_timer(wait).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			_show_result(outcome))


# ---------------------------------------------------------------------------
# Kamera
# ---------------------------------------------------------------------------

## Das Geschehen im Bild halten: Mitte und Zoom aus dem Rahmen um alle
## lebenden DROMEs, weich nachgefuehrt.
func _follow_fight(delta: float) -> void:
	var living: Array = battle.units.filter(func(u): return u.is_alive())
	if living.is_empty():
		return
	var box := Rect2(living[0].visual_anchor(), Vector2.ZERO)
	for unit in living:
		box = box.expand(unit.visual_anchor())
	box = box.grow(IsoView.TILE_W * 1.2)
	var target := box.get_center() + Vector2(0, -30)
	var visible := get_viewport().get_visible_rect().size
	# Platz fuer Kopfleiste und Daumenleiste lassen.
	var usable := Vector2(visible.x, visible.y * 0.62)
	var zoom := clampf(minf(usable.x / box.size.x, usable.y / box.size.y),
		ZOOM_MIN, _follow_zoom())
	var k := 1.0 if Accessibility.reduce_motion else clampf(delta * FOLLOW_EASE, 0.0, 1.0)
	camera.position = camera.position.lerp(target, k)
	_set_zoom(lerpf(camera.zoom.x, zoom, k))


## Der naechste Zoom, den das Folgen zulaesst: rund zehn Hexfelder ueber die
## Breite (so gross wie frueher sieben Rauten -- die DROMEs behalten ihre
## Groesse) -- naeher heran, wenn nur noch wenige stehen.
func _follow_zoom() -> float:
	var visible := get_viewport().get_visible_rect().size
	return clampf(visible.x / (10.4 * IsoView.TILE_W), ZOOM_MIN, ZOOM_MAX)


func _set_zoom(zoom: float) -> void:
	zoom = clampf(zoom, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(zoom, zoom)
	view.set_pixel_scale(zoom)


## Kachel angetippt: die Kamera faehrt zu diesem DROME und bleibt dort, bis
## "Folgen" wieder das ganze Geschehen zeigt.
func _look_at_unit(unit: Unit) -> void:
	if unit == null or not unit.is_alive():
		return
	# Der angetippte DROME bekommt ein paar Sekunden einen groesseren Balken.
	_focus_id = unit.unit_id
	_focus_until = Time.get_ticks_msec() + FOCUS_MS
	_set_follow(false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(camera, "position", unit.visual_anchor() + Vector2(0, -40), 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var visible := get_viewport().get_visible_rect().size
	var close := clampf(visible.x / (7.4 * IsoView.TILE_W), ZOOM_MIN, ZOOM_MAX)
	tween.tween_method(_set_zoom, camera.zoom.x, close, 0.4)


func _set_follow(on: bool) -> void:
	_follow = on
	if _follow_button != null:
		UiIcon.on_button(_follow_button, "camera_follow" if on else "camera_free", 20, Color.WHITE, "top")
		_follow_button.modulate = UiKit.ACCENT if on else Color.WHITE


func _unhandled_input(event: InputEvent) -> void:
	_track_touches(event)
	if _deploying and _deploy_input(event):
		get_viewport().set_input_as_handled()
		return
	if _camera_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_SPACE:
		_toggle_pause()


# ---------------------------------------------------------------------------
# Aufstellung
# ---------------------------------------------------------------------------

const ZONE_COLOR := Color(0.3, 0.95, 0.62)


## Vor dem Kampf: Zonen zeigen, Kamera auf beide Seiten, Startknopf.
func _begin_deployment() -> void:
	_deploying = true
	view.show_zone(battle.deployment_tiles(true), ZONE_COLOR)
	_frame_deployment()
	_deploy_bar.visible = true
	_play_bar.visible = false
	_refresh_hud()


func _start_fight() -> void:
	if not _deploying:
		return
	_deploying = false
	_cancel_drag()
	_selected = null
	GameState.formation = battle.formation(true)
	view.clear_zone()
	_deploy_bar.visible = false
	_play_bar.visible = true
	_set_follow(true)
	_refresh_hud()


## Beide Aufstellungen im Bild.
func _frame_deployment() -> void:
	var box := Rect2(IsoView.map_to_local(battle.deployment_tiles(true)[0]), Vector2.ZERO)
	for side in [true, false]:
		for tile in battle.deployment_tiles(side):
			box = box.expand(IsoView.map_to_local(tile))
	box = box.grow(IsoView.TILE_W)
	var visible := get_viewport().get_visible_rect().size
	var usable := Vector2(visible.x, visible.y * 0.6)
	camera.position = box.get_center()
	_set_zoom(minf(usable.x / box.size.x, usable.y / box.size.y))


func _pointer_tile(screen_position: Vector2) -> Vector2i:
	var world := get_canvas_transform().affine_inverse() * screen_position
	return IsoView.local_to_map(view.to_local(world))


func _pointer_world(screen_position: Vector2) -> Vector2:
	return view.to_local(get_canvas_transform().affine_inverse() * screen_position)


## Der eigene DROME unter dem Finger. Gegriffen wird die FIGUR, nicht ihr
## Feld: das Bild steht gut eine Feldhoehe ueber seinem Feld, und wer auf den
## Koerper tippte, traf vorher das Feld dahinter (oder keins). Liegen mehrere
## uebereinander, gewinnt die vordere. Ohne Treffer zaehlt das Feld.
func _unit_under(screen_position: Vector2) -> Unit:
	var world := _pointer_world(screen_position)
	var best: Unit = null
	for unit in battle.units:
		if not unit.is_player or not unit.is_alive():
			continue
		var feet: Vector2 = unit.visual_anchor()
		# Koerper im 128er Bild: rund 64 breit, vom Boden 84 hoch; dazu etwas
		# Rand fuer den Finger.
		if Rect2(feet + Vector2(-36, -88), Vector2(72, 108)).has_point(world):
			if best == null or IsoView.depth(unit.tile) > IsoView.depth(best.tile):
				best = unit
	if best != null:
		return best
	var on_tile := battle.resolver.unit_at(_pointer_tile(screen_position))
	return on_tile if on_tile != null and on_tile.is_player else null


## Aufstellen per Finger (10. Nov. 2026 ueberarbeitet):
##
##   Ziehen   Figur greifen und auf ein Feld der Zone ziehen. Sie haengt am
##            Finger, wie sie gegriffen wurde; es zaehlt das Feld unter ihren
##            Fuessen, und das leuchtet (gruen: geht, rot: ausserhalb).
##   Tippen   Figur antippen (ihr Feld wird weiss), dann ein Feld der Zone
##            oder eine andere eigene Figur -- setzt um bzw. tauscht.
##
## Beginnt die Geste nicht auf einer eigenen Figur, gehoert sie der Kamera.
## Der Browser schickt jede Beruehrung zusaetzlich als Maus-Ereignis; diese
## Doppelgaenger werden uebergangen, sonst zaehlte jedes Tippen zweimal.
func _deploy_input(event: InputEvent) -> bool:
	var pressed := false
	var released := false
	var moved := false
	var at := Vector2.ZERO
	if event is InputEventScreenTouch:
		if event.index != 0:
			# Zweiter Finger: Zoomen -- eine laufende Geste endet ohne Wirkung.
			_cancel_drag()
			return false
		pressed = event.pressed
		released = not event.pressed
		at = event.position
	elif event is InputEventScreenDrag:
		if event.index != 0:
			return false
		moved = true
		at = event.position
	elif event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return _grabbed != null
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		released = not event.pressed
		at = event.position
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		moved = true
		at = event.position
	else:
		return false

	if pressed:
		_grabbed = _unit_under(at)
		_dragged = null
		_grab_start = at
		if _grabbed != null:
			_grab_offset = _pointer_world(at) - _grabbed.position
			return true
		# Daneben getippt: ein Feld der Zone setzt die gewaehlte Figur um.
		return _selected != null
	if moved and _grabbed != null:
		if _dragged == null and at.distance_to(_grab_start) > DRAG_THRESHOLD:
			_dragged = _grabbed
			_selected = null
			_dragged.z_index = 4000
		if _dragged != null:
			_dragged.position = _pointer_world(at) - _grab_offset
			var under := IsoView.local_to_map(_dragged.visual_anchor())
			view.mark_zone(under, under in battle.deployment_tiles(true), null)
		return true
	if released:
		var grabbed := _grabbed
		var dragged := _dragged
		_grabbed = null
		_dragged = null
		if dragged != null:
			# Abgelegt: das Feld unter den Fuessen der Figur.
			_place(dragged, IsoView.local_to_map(dragged.visual_anchor()))
			return true
		if grabbed != null:
			# Angetippt: waehlen, abwaehlen oder mit der gewaehlten tauschen.
			if _selected != null and _selected != grabbed:
				_place(_selected, grabbed.tile)
			else:
				_selected = null if _selected == grabbed else grabbed
				view.mark_zone(null, true, _selected.tile if _selected != null else null)
			return true
		if _selected != null and at.distance_to(_grab_start) <= DRAG_THRESHOLD:
			var tile := _pointer_tile(at)
			if tile in battle.deployment_tiles(true):
				_place(_selected, tile)
				return true
			_selected = null
			view.mark_zone(null, true, null)
	return false


## Setzt eine Figur auf ein Feld der Zone (oder zurueck, wenn es nicht geht)
## und raeumt Auswahl und Markierung ab.
func _place(unit: Unit, tile: Vector2i) -> void:
	var other := battle.resolver.unit_at(tile)
	if battle.place_unit(unit, tile):
		Accessibility.vibrate(15)
	else:
		unit.place_at(unit.tile)
	if other != null and other != unit:
		view.refresh_unit_depth(other)
	view.refresh_unit_depth(unit)
	_selected = null
	view.mark_zone(null, true, null)
	_refresh_hud()


func _cancel_drag() -> void:
	if _dragged != null:
		_dragged.place_at(_dragged.tile)
		view.refresh_unit_depth(_dragged)
	_dragged = null
	_grabbed = null
	view.mark_zone(null, true, _selected.tile if _selected != null else null)


## Buchfuehrung ueber die Finger auf dem Bildschirm -- immer, auch wenn die
## Aufstellung die Geste verbraucht. Sonst kennt das Zoomen den ersten Finger
## nicht, wenn der zweite dazukommt.
func _track_touches(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			_drag_distance = 0.0
		else:
			_touches.erase(event.index)
		_pinch_distance = 0.0
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position


## Ziehen und Zoomen. Gibt true zurueck, wenn die Geste das Ereignis
## verbraucht hat.
func _camera_input(event: InputEvent) -> bool:
	if event is InputEventScreenDrag:
		if _touches.size() >= 2:
			var points: Array = _touches.values()
			var distance: float = maxf(1.0, points[0].distance_to(points[1]))
			if _pinch_distance <= 0.0:
				# Der erste Zug mit zwei Fingern legt den Bezug fest.
				_pinch_distance = distance
				_pinch_zoom = camera.zoom.x
			_set_follow(false)
			_set_zoom(_pinch_zoom * distance / _pinch_distance)
			return true
		_drag_distance += event.relative.length()
		if _drag_distance > DRAG_THRESHOLD:
			_set_follow(false)
			camera.position -= event.relative / camera.zoom
			return true
		return false
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_follow(false)
			_set_zoom(camera.zoom.x * 1.1)
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_follow(false)
			_set_zoom(camera.zoom.x / 1.1)
			return true
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		_set_follow(false)
		camera.position -= event.relative / camera.zoom
		return true
	return false


# ---------------------------------------------------------------------------
# UI-Aufbau
# ---------------------------------------------------------------------------

## Der Aufbau, mobile first:
##
##   oben    Kopfleiste: die Kacheln des eigenen Squads, darunter Zeit und Region
##   Mitte   die Karte -- Kamera folgt, Ziehen und Zoomen per Finger
##   unten   Daumenleiste: Tempo, Pause, Log, Folgen
func _build_ui() -> void:
	# Vignette ueber dem Spielfeld, unter der Bedienung: die Raender dunkler,
	# das Geschehen in der Mitte tritt hervor.
	var shade_layer := CanvasLayer.new()
	shade_layer.layer = 1
	add_child(shade_layer)
	var vignette := TextureRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0.0))
	gradient.set_color(1, Color(0, 0, 0, 0.55))
	gradient.add_point(0.55, Color(0, 0, 0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.05, 1.05)
	vignette.texture = texture
	shade_layer.add_child(vignette)

	_ui = CanvasLayer.new()
	_ui.layer = 2
	add_child(_ui)
	var glitch_layer := CanvasLayer.new()
	glitch_layer.layer = 3
	add_child(glitch_layer)
	_glitch = Arcade.GlitchOverlay.new()
	glitch_layer.add_child(_glitch)

	var frame := VBoxContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_constant_override("separation", 0)
	# Eine CanvasLayer erbt das Theme der Wurzel nicht -- ohne das stuende im
	# Kampf die Godot-Schrift statt Chakra Petch.
	frame.theme = get_tree().root.theme
	_ui.add_child(frame)

	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _bar_style(false))
	frame.add_child(top)
	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 4)
	top.add_child(top_box)
	# Kopf (Entwurf 15. Nov. 2026): links Ort und Kampf, Mitte die Uhr in
	# Bungee (Virus: Magenta mit "VIRUS IN n S"), rechts die Gegner.
	var head := HBoxContainer.new()
	top_box.add_child(head)
	var where := VBoxContainer.new()
	where.add_theme_constant_override("separation", 0)
	where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(where)
	_where = Arcade.label("", 11, Arcade.MUTED, "bold", 0.16)
	where.add_child(_where)
	_round_label = Arcade.label("", 11, Arcade.MUTED, "bold", 0.16)
	where.add_child(_round_label)
	var clock_box := VBoxContainer.new()
	clock_box.add_theme_constant_override("separation", 0)
	clock_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(clock_box)
	_clock = Arcade.label("00:00", 26, Arcade.WHITE, "display")
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_box.add_child(_clock)
	_status = Arcade.label("", 11, Arcade.MAGENTA, "bold", 0.16)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.clip_text = true
	clock_box.add_child(_status)
	var foes := VBoxContainer.new()
	foes.add_theme_constant_override("separation", 0)
	foes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(foes)
	var foes_title := Arcade.label("GEGNER", 11, Arcade.MUTED, "bold", 0.16)
	foes_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foes.add_child(foes_title)
	_foes = Arcade.label("", 20, Arcade.MAGENTA, "display")
	_foes.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foes.add_child(_foes)
	_squad_tiles = SquadTiles.new()
	top_box.add_child(_squad_tiles)
	_top_box = top_box

	var middle := Control.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(middle)

	# Querformat: die Kacheln als Spalte am linken Rand, damit oben mehr
	# Spielfeld bleibt (_apply_orientation).
	_side_panel = PanelContainer.new()
	_side_panel.add_theme_stylebox_override("panel", _bar_style(true))
	_side_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_side_panel.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	_side_panel.visible = false
	middle.add_child(_side_panel)
	_frame = frame
	get_viewport().size_changed.connect(_apply_orientation)
	_apply_orientation.call_deferred()


	_log_panel = PanelContainer.new()
	_log_panel.add_theme_stylebox_override("panel", _bar_style(true))
	_log_panel.custom_minimum_size = Vector2(0, 220)
	_log_panel.visible = false
	frame.add_child(_log_panel)
	_log = RichTextLabel.new()
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", UiKit.SMALL)
	_log_panel.add_child(_log)

	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", _bar_style(false))
	frame.add_child(bottom)
	var bars := VBoxContainer.new()
	bottom.add_child(bars)

	# Vor dem Kampf: Hinweis und Startknopf.
	var deploy := VBoxContainer.new()
	deploy.add_theme_constant_override("separation", 6)
	_deploy_bar = deploy
	bars.add_child(deploy)
	# Entwurf: Hinweis-Karte, darunter "Danach kaempft dein Squad selbststaendig."
	var hint_card := PanelContainer.new()
	var hint_box := StyleBoxFlat.new()
	hint_box.bg_color = Color(Arcade.VIOLET, 0.95)
	hint_box.border_color = Arcade.CYAN
	hint_box.set_border_width_all(2)
	hint_box.set_content_margin_all(10)
	hint_card.add_theme_stylebox_override("panel", hint_box)
	var hint_column := VBoxContainer.new()
	hint_column.add_theme_constant_override("separation", 0)
	hint_card.add_child(hint_column)
	hint_column.add_child(Arcade.label("Ziehe deine DROMEs in Position", 15, Arcade.WHITE, "bold"))
	var hint := UiKit.label("Nur innerhalb der markierten Zone -- oder erst die Figur antippen, "
		+ "dann das Feld. Danach kämpft dein Squad selbstständig.", 13, UiKit.MUTED)
	hint_column.add_child(hint)
	deploy.add_child(hint_card)
	var start := UiKit.button("Los", true)
	UiIcon.on_button(start, "play", 18, UiKit.ON_PRIMARY, "right")
	start.pressed.connect(_start_fight)
	deploy.add_child(start)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	_play_bar = buttons
	buttons.visible = false
	bars.add_child(buttons)
	_speed_button = _bar_button("1×\nTEMPO", _cycle_speed)
	buttons.add_child(_speed_button)
	_apply_speed()
	_pause_button = _bar_button("PAUSE", _toggle_pause, "pause")
	buttons.add_child(_pause_button)
	buttons.add_child(_bar_button("PROTOKOLL", func(): _log_panel.visible = not _log_panel.visible, "log"))
	_follow_button = _bar_button("KAMERA", func(): _set_follow(not _follow), "camera_follow")
	_follow_button.modulate = UiKit.ACCENT
	buttons.add_child(_follow_button)

	# Die Kacheln und die Zeit muessen nicht jedes Bild neu: zehnmal pro
	# Sekunde reicht und spart auf dem Handy Arbeit.
	var timer := Timer.new()
	timer.wait_time = 0.1
	timer.autostart = true
	timer.timeout.connect(_refresh_hud)
	add_child(timer)


## ``icon``: UI-Symbol ueber dem Text (assets/ui_icons).
func _bar_button(text: String, on_press: Callable, icon: String = "") -> Button:
	var button := Button.new()
	button.text = text
	if icon != "":
		UiIcon.on_button(button, icon, 20, Color.WHITE, "top")
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 58)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_font_override("font", Arcade.font("bold", 12, 0.12))
	button.pressed.connect(Accessibility.tap)
	button.pressed.connect(on_press)
	return button


## Leisten im Arcade-Stil: Nachtschwarz, Linie in Cyan (oben) bzw. Magenta.
func _bar_style(raised: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiKit.BG, 0.95 if raised else 0.9)
	style.border_color = Color(UiKit.MAGENTA if raised else UiKit.ACCENT, 0.5)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.set_content_margin_all(10)
	return style


func _cycle_speed() -> void:
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	_speed_memory = _speed_index
	_apply_speed()


func _apply_speed() -> void:
	Engine.time_scale = SPEEDS[_speed_index]
	if _speed_button != null:
		_speed_button.text = "%d×\nTEMPO" % int(SPEEDS[_speed_index])


## Das Tempo ist global (Engine.time_scale) und darf den Kampf nicht
## ueberleben -- sonst laeuft der Hangar danach doppelt so schnell.
func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _toggle_pause() -> void:
	_paused = not _paused
	if _pause_button != null:
		_pause_button.text = "WEITER" if _paused else "PAUSE"
		UiIcon.on_button(_pause_button, "play" if _paused else "pause", 20, Color.WHITE, "top")
	_refresh_hud()


# ---------------------------------------------------------------------------
# Ergebnis
# ---------------------------------------------------------------------------

func _result_cell(title: String, value: String, color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Arcade.chamfer_box(Arcade.DEEP, 8, Color("#3a1a6e"), 2))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	column.add_child(Arcade.label(title.to_upper(), 11, Arcade.MUTED, "bold", 0.16))
	column.add_child(Arcade.label(value, 20, color, "display"))
	return panel


## Die Beute dieses Kampfs (schon eingetragen): ein Cache, Coins -- oder bei
## einer Niederlage ein Leben weniger.
func _loot_card(run: RunState, won: bool) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.card_style(true))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	column.add_child(Arcade.label("BEUTE" if won else "NIEDERLAGE", 13,
		Arcade.CYAN if won else Arcade.MAGENTA, "bold", 0.2))
	if not won:
		column.add_child(Arcade.label("−1 LEBEN", 20, Arcade.MAGENTA, "display"))
		column.add_child(UiKit.label("Der Einsatz geht mit %d Leben weiter." % run.lives
			if run.lives > 0 else "Keine Leben mehr -- der Einsatz ist vorbei.", 14, UiKit.MUTED))
	for item in run.last_loot:
		var kind := str(item.get("kind", ""))
		if kind == "cache":
			column.add_child(Arcade.label(RunState.cache_name(StringName(str(item.get("cache", "city"))))
				.to_upper() + (" ×%d" % int(item.get("count", 1)) if int(item.get("count", 1)) > 1 else ""),
				20, Arcade.WHITE, "display"))
			column.add_child(UiKit.label("Geschlossen. Kommt zu deinen gesammelten Caches.", 14,
				UiKit.MUTED))
		else:
			column.add_child(Arcade.label(str(item.get("title", "")).to_upper(), 18, Arcade.YELLOW,
				"display"))
			if str(item.get("text", "")) != "":
				column.add_child(UiKit.label(str(item["text"]), 13, UiKit.MUTED))
	if won and run.last_loot.is_empty():
		column.add_child(UiKit.label("Diesmal keine Beute.", 14, UiKit.MUTED))
	return panel


func _show_result(outcome: BattleManager.Outcome) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(shade)
	var holder := MarginContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	var side := int(maxf(UiKit.PAD, (get_viewport().get_visible_rect().size.x - UiKit.MAX_COLUMN) * 0.5))
	holder.add_theme_constant_override("margin_left", side)
	holder.add_theme_constant_override("margin_right", side)
	holder.add_theme_constant_override("margin_top", 40)
	holder.add_theme_constant_override("margin_bottom", 40)
	shade.add_child(holder)
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", UiKit.card_style(true))
	holder.add_child(panel)
	# Oben die Zahlen zum Scrollen, darunter die Knoepfe fest -- sonst lag
	# "Weiter im Lauf" bei vier gegen drei unter dem Rand der Liste.
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	var button_room := float(UiKit.BUTTON_HEIGHT) * (1.0 if GameState.in_run_battle else 2.0) + 24.0
	scroll.custom_minimum_size = Vector2(0, minf(560.0,
		get_viewport().get_visible_rect().size.y - 120.0) - button_room)
	column.add_child(scroll)
	column.add_child(buttons)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)

	var won := outcome == BattleManager.Outcome.VICTORY
	Accessibility.vibrate(120 if won else 200, true)
	var result := battle.build_result()
	# Im Einsatz wird das Ergebnis gleich eingetragen (Entwurf 15. Nov. 2026:
	# die Beute steht schon hier) -- "Weiter" wechselt nur noch die Seite.
	var in_run := GameState.in_run_battle and GameState.run != null
	var run: RunState = GameState.run if in_run else null
	var where := str(result["region"]).to_upper()
	var credits := 0
	if in_run:
		where = "%s · KAMPF %d/%d" % [where, run.round, RunState.rounds_total()] if not run.is_endless() \
			else "%s · KAMPF %d" % [where, run.round]
		credits = run.battle_credits(won)
		var pool: Array = battle.enemy_equipment.duplicate()
		# Wer hat wie viele Abschuesse -- fuer die EP der Waffen (Leveling).
		var fighters: Array = []
		for unit in battle.units:
			if unit.is_player and unit.build != null:
				var weapons := {}
				for slot in unit.build.equip_slots():
					weapons[slot] = unit.weapon_record(slot)
				fighters.append({"source_uid": unit.build.source_uid, "weapons": weapons})
		GameState.finish_run_battle(outcome, pool, fighters)
	var tag := Arcade.tilt(Arcade.tag(where, 12, 0.0), 2.0)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(tag)
	# Der Ausgang als grosser Glitch-Schriftzug.
	var logo := Arcade.GlitchLogo.new(BattleManager.outcome_label(outcome).to_upper(),
		54 if won else 38, 3.6, [
		[0.0, Vector2(-2, 0), Vector2(2, 0)],
		[0.9, Vector2(-6, 2), Vector2(6, -2)],
		[0.93, Vector2(4, -1), Vector2(-4, 1)]], 2.0)
	var tilted := Arcade.tilt(logo, -3.0)
	tilted.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(tilted)
	var kills := 0
	var foes := 0
	for row in result["units"]:
		if not row["is_player"]:
			foes += 1
			if not row["alive"]:
				kills += 1
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	box.add_child(stats)
	var seconds := int(result["seconds"])
	stats.add_child(_result_cell("Zeit", "%02d:%02d" % [seconds / 60, seconds % 60], Arcade.WHITE))
	stats.add_child(_result_cell("Abschüsse", "%d/%d" % [kills, foes], Arcade.WHITE))
	if in_run:
		stats.add_child(_result_cell("Credits", "+%d" % credits, UiKit.GOOD))
		box.add_child(_loot_card(run, won))

	var details := Arcade.label("KAMPFBERICHT", 12, Arcade.CYAN, "bold", 0.2)
	box.add_child(details)

	# Eine Zeile je Einheit (14. Nov. 2026 kompakt -- mit Sentinels werden
	# es schnell zehn): Name, verursacht / erlitten, Leben.
	var table := GridContainer.new()
	table.columns = 3
	table.add_theme_constant_override("h_separation", 10)
	table.add_theme_constant_override("v_separation", 4)
	box.add_child(table)
	# Zahlen-Spalten brechen nie um: mit Umbruch schrumpfte die Spalte auf ein
	# Zeichen Breite, und "814 / 360" stand senkrecht (17. Nov. 2026).
	var cell := func(text: String, size: int, color: Color) -> Label:
		var label := UiKit.label(text, size, color)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		return label
	for text in ["", "Schaden / erlitten", "Leben"]:
		table.add_child(cell.call(text, 12, UiKit.MUTED))
	for row in result["units"]:
		var name := UiKit.label(str(row["name"]), 15, Teams.color(row["is_player"])
			if row["alive"] else UiKit.MUTED)
		name.autowrap_mode = TextServer.AUTOWRAP_OFF
		name.clip_text = true
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		table.add_child(name)
		table.add_child(cell.call("%d / %d" % [row["dealt"], row["taken"]], 15, UiKit.TEXT))
		table.add_child(cell.call("%d / %d" % [row["hp"], row["hp_max"]] if row["alive"] else "aus",
			15, UiKit.TEXT if row["alive"] else UiKit.BAD))

	if in_run:
		var onward := UiKit.button("Weiter", true)
		UiIcon.on_button(onward, "play", 18, UiKit.ON_PRIMARY, "right")
		onward.pressed.connect(func():
			Fader.go("res://scenes/run.tscn"))
		buttons.add_child(onward)
		onward.grab_focus.call_deferred()
		return

	var back := UiKit.button("Zum Hangar", true)
	back.pressed.connect(func():
		GameState.battle_seed = 0
		Fader.go("res://scenes/hangar.tscn"))
	buttons.add_child(back)

	var menu := UiKit.button("Zur Startseite")
	menu.pressed.connect(func():
		GameState.battle_seed = 0
		Fader.go("res://scenes/main.tscn"))
	buttons.add_child(menu)
