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
var _dragged: Unit = null
var _deploy_bar: Control
var _play_bar: Control
var _paused: bool = false
var _over: bool = false
var _accumulator: float = 0.0
var _speed_index: int = 0

var _follow := true
var _touches: Dictionary = {}
var _drag_distance := 0.0
var _pinch_distance := 0.0
var _pinch_zoom := 1.0

# UI
var _ui: CanvasLayer
var _status: Label
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
		GameState.battle_region)
	battle.overtime_enabled = true
	view.build_terrain(battle.grid)
	# Die gemerkte Aufstellung des letzten Kampfs, wenn sie noch passt.
	battle.apply_formation(GameState.formation)
	for unit in battle.units:
		view.attach_unit(unit)

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
	if _follow and not _over and not _deploying:
		_follow_fight(delta)


## Kacheln und Statuszeile -- je Bild, das ist billig genug.
func _refresh_hud() -> void:
	_refresh_badges()
	if _squad_tiles != null:
		_squad_tiles.refresh(battle.units)
	if _over:
		return
	if _deploying:
		_status.text = "Aufstellung  ·  %s" % (battle.region.display_name
			if battle.region != null else "")
		return
	var seconds := int(battle.time)
	_status.text = "%d:%02d  ·  %s" % [seconds / 60, seconds % 60,
		battle.region.display_name if battle.region != null else ""]
	if battle.in_overtime():
		_status.text += "  ·  OVERTIME"
	if _paused:
		_status.text += "  ·  Pause"


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
	var seconds := unit.step_left if unit.step_left > 0.0 else 0.18
	unit.animate_last_move(seconds)
	view.refresh_unit_depth(unit)


## Schussspur vom Schuetzen zum Ziel, Rueckstoss, und bei einer Faehigkeit
## ihr Name ueber der Figur -- damit man sieht, dass gerade der dritte Schuss
## die Doppelschuss war.
func _on_action_used(unit: Unit, tile: Vector2i, action: ActionData) -> void:
	if tile != unit.tile:
		unit.play_attack(tile)
	var color := Teams.color(unit.is_player)
	if not action.is_move() and (action.power > 0 or action.heal > 0):
		view.show_attack(unit.visual_anchor(), IsoView.map_to_local(tile), color,
			attack_style(unit, tile, action, battle.resolver.unit_at(tile)))
	if not action.is_attack():
		view.show_float(unit.visual_anchor(), action.display_name + "!",
			Color(1.0, 0.86, 0.3), true)
	_refresh_hud()


## Wie ein Angriff aussieht (Wunsch des Spielers, 9. Nov. 2026): Nahkampf ohne
## Projektil; Blaster gerader Schuss, Lanze schweres Geschoss, Runenstab und
## E-Schraubenschluessel eine Energiekugel, die Reparatur ein Heilstrahl. Die
## Schadensart steuert Leuchten und Einschlag (BattleView.show_attack).
static func attack_style(unit: Unit, tile: Vector2i, action: ActionData, target: Unit = null) -> Dictionary:
	var style := {"energy": action.energy_fraction, "area": action.aoe_radius,
		"heavy": not action.is_attack() or action.aoe_radius > 0, "projectile": "bolt"}
	var id := str(action.id)
	var reach := Grid.distance(unit.tile, tile)
	if action.heal > 0 and target != null and target != unit and target.is_player == unit.is_player:
		style["projectile"] = "beam"
		style["energy"] = 1.0
	elif action.range_tiles <= 1 or reach <= 1:
		style["projectile"] = ""
	elif id.begins_with("act_rune") or id.begins_with("act_drone"):
		style["projectile"] = "orb"
	elif id.begins_with("act_rail"):
		style["projectile"] = "slug"
	return style


## Ein Treffer muss man sehen: Zucken, Blende, Zahl, und bei einem grossen
## Anteil an der Integritaet ein kurzer Kamerastoss.
func _on_unit_damaged(unit: Unit, amount: int, _source) -> void:
	unit.play_hit()
	if amount > 0:
		view.show_float(unit.visual_anchor(), "-%d" % amount,
			Color(1.0, 0.45, 0.4) if unit.is_player else Color(1.0, 0.9, 0.5))
	var maximum: int = maxi(1, unit.stat("hp_max"))
	_shake_camera(clampf(float(amount) / float(maximum), 0.0, 1.0))
	_refresh_hud()


func _on_unit_healed(unit: Unit, amount: int, _source) -> void:
	unit.play_heal()
	if amount > 0:
		view.show_float(unit.visual_anchor(), "+%d" % amount, Color(0.45, 0.95, 0.6))
	_refresh_hud()


func _on_unit_died(unit: Unit) -> void:
	unit.visible = false
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
	_grant_loot(outcome)
	_show_result(outcome)


## Beute: nur bei SIEG und nur in einem echten Chaos-Lauf (chaos_reference_power
## gesetzt). Der Wuerfel haengt am Seed des Gefechts -- derselbe Kampf gibt
## dieselbe Beute. Laeuft genau einmal, weil battle_over genau einmal feuert.
func _grant_loot(outcome: BattleManager.Outcome) -> void:
	GameState.last_loot = []
	if GameState.in_run_battle:
		return              # im Lauf ist die Belohnung die Kartenwahl danach
	if outcome != BattleManager.Outcome.VICTORY:
		return
	if GameState.chaos_reference_power <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = battle.battle_seed ^ 0x10CE10C
	GameState.roll_chaos_loot(battle.enemy_equipment, rng)


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


## Der naechste Zoom, den das Folgen zulaesst: rund sieben Felder ueber die
## Breite -- naeher heran, wenn nur noch wenige stehen.
func _follow_zoom() -> float:
	var visible := get_viewport().get_visible_rect().size
	return clampf(visible.x / (7.0 * IsoView.TILE_W), ZOOM_MIN, ZOOM_MAX)


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
	var close := clampf(visible.x / (5.0 * IsoView.TILE_W), ZOOM_MIN, ZOOM_MAX)
	tween.tween_method(_set_zoom, camera.zoom.x, close, 0.4)


func _set_follow(on: bool) -> void:
	_follow = on
	if _follow_button != null:
		_follow_button.text = "Folgt" if on else "Folgen"
		_follow_button.modulate = UiKit.ACCENT if on else Color.WHITE


func _unhandled_input(event: InputEvent) -> void:
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

const ZONE_COLOR := Color(0.25, 0.85, 0.55, 0.32)
const ZONE_FOE_COLOR := Color(1.0, 0.35, 0.35, 0.18)


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
	_dragged = null
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


## Ziehen und Ablegen der eigenen DROMEs. Tippt der Finger auf einen eigenen
## DROME, wird er gezogen; sonst bleibt die Geste bei der Kamera. Touch kommt
## auf dem Handy zusaetzlich als Maus an -- beides fuehrt zum selben Ergebnis.
func _deploy_input(event: InputEvent) -> bool:
	var pressed := false
	var released := false
	var moved := false
	var at := Vector2.ZERO
	if event is InputEventScreenTouch and event.index == 0:
		pressed = event.pressed
		released = not event.pressed
		at = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		released = not event.pressed
		at = event.position
	elif event is InputEventScreenDrag and event.index == 0:
		moved = true
		at = event.position
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		moved = true
		at = event.position
	else:
		return false

	if pressed and _dragged == null:
		var unit := battle.resolver.unit_at(_pointer_tile(at))
		if unit != null and unit.is_player:
			_dragged = unit
			unit.z_index = 5000
			return true
		return false
	if moved and _dragged != null:
		_dragged.position = _pointer_world(at) - IsoView.SPRITE_ORIGIN
		return true
	if released and _dragged != null:
		var unit := _dragged
		_dragged = null
		var target := _pointer_tile(at)
		var other := battle.resolver.unit_at(target)
		if not battle.place_unit(unit, target):
			unit.place_at(unit.tile)
		if other != null and other != unit:
			view.refresh_unit_depth(other)
		view.refresh_unit_depth(unit)
		return true
	return false


## Ziehen und Zoomen. Gibt true zurueck, wenn die Geste das Ereignis
## verbraucht hat.
func _camera_input(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			_drag_distance = 0.0
			if _touches.size() == 2:
				var points: Array = _touches.values()
				_pinch_distance = maxf(1.0, points[0].distance_to(points[1]))
				_pinch_zoom = camera.zoom.x
		else:
			_touches.erase(event.index)
		return false
	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			var points: Array = _touches.values()
			var distance: float = points[0].distance_to(points[1])
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

	var frame := VBoxContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_constant_override("separation", 0)
	_ui.add_child(frame)

	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _bar_style(false))
	frame.add_child(top)
	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 4)
	top.add_child(top_box)
	_squad_tiles = SquadTiles.new()
	top_box.add_child(_squad_tiles)
	_top_box = top_box
	_status = UiKit.label("", UiKit.SMALL)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.clip_text = true
	top_box.add_child(_status)

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
	var hint := UiKit.label("Zieh deine DROMEs in der gruenen Zone zurecht -- "
		+ "Molok nach vorn, Strix nach hinten.", UiKit.SMALL, UiKit.MUTED)
	deploy.add_child(hint)
	var start := UiKit.button("Kampf starten", true)
	start.pressed.connect(_start_fight)
	deploy.add_child(start)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	_play_bar = buttons
	buttons.visible = false
	bars.add_child(buttons)
	_speed_button = _bar_button("Tempo 1x", _cycle_speed)
	buttons.add_child(_speed_button)
	_apply_speed()
	_pause_button = _bar_button("Pause", _toggle_pause)
	buttons.add_child(_pause_button)
	buttons.add_child(_bar_button("Log", func(): _log_panel.visible = not _log_panel.visible))
	_follow_button = _bar_button("Folgt", func(): _set_follow(not _follow))
	_follow_button.modulate = UiKit.ACCENT
	buttons.add_child(_follow_button)

	# Die Kacheln und die Zeit muessen nicht jedes Bild neu: zehnmal pro
	# Sekunde reicht und spart auf dem Handy Arbeit.
	var timer := Timer.new()
	timer.wait_time = 0.1
	timer.autostart = true
	timer.timeout.connect(_refresh_hud)
	add_child(timer)


func _bar_button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_font_size_override("font_size", UiKit.SMALL)
	button.pressed.connect(on_press)
	return button


func _bar_style(raised: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.94 if raised else 0.88)
	style.border_color = UiKit.CARD_LINE
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.set_content_margin_all(8)
	return style


func _cycle_speed() -> void:
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	_apply_speed()


func _apply_speed() -> void:
	Engine.time_scale = SPEEDS[_speed_index]
	if _speed_button != null:
		_speed_button.text = "Tempo %dx" % int(SPEEDS[_speed_index])


## Das Tempo ist global (Engine.time_scale) und darf den Kampf nicht
## ueberleben -- sonst laeuft der Hangar danach doppelt so schnell.
func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _toggle_pause() -> void:
	_paused = not _paused
	if _pause_button != null:
		_pause_button.text = "Weiter" if _paused else "Pause"
	_refresh_hud()


# ---------------------------------------------------------------------------
# Ergebnis
# ---------------------------------------------------------------------------

## Die Beute-Zeile im Ergebnis. Nur bei einem echten Chaos-Sieg; sonst
## schweigt sie. Bei Beute nennt sie die Teile, bei Duerre den Pity-Fortschritt.
func _add_loot_section(box: VBoxContainer, outcome: BattleManager.Outcome) -> void:
	if GameState.in_run_battle:
		# Im Lauf kommen Credits und danach die Belohnung -- kein Chaos-Wuerfel.
		if GameState.run != null:
			var won := outcome == BattleManager.Outcome.VICTORY
			box.add_child(UiKit.label("+%d Credits%s" % [GameState.run.battle_credits(won),
				"  ·  Belohnung im Lauf" if won else ""], UiKit.BODY, UiKit.WARN))
		return
	if GameState.chaos_reference_power <= 0.0 and GameState.last_loot.is_empty():
		return
	if outcome != BattleManager.Outcome.VICTORY:
		return
	if GameState.last_loot.is_empty():
		box.add_child(UiKit.label("Keine Beute.", UiKit.BODY, UiKit.MUTED))
		var threshold := int(Config.section("chaos").get("loot_pity_threshold", 4))
		box.add_child(UiKit.label("Pity: %d / %d bis zum garantierten Drop." % [
			GameState.chaos_pity, threshold], UiKit.SMALL, UiKit.MUTED))
		return
	box.add_child(UiKit.label("Beute!", UiKit.H2, UiKit.GOOD))
	for part_id in GameState.last_loot:
		var part := PartDB.get_part(part_id)
		box.add_child(UiKit.label("  + %s" % (part.display_name if part != null else str(part_id)),
			UiKit.BODY, UiKit.GOOD))


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
	box.add_child(UiKit.label(BattleManager.outcome_label(outcome), UiKit.H1,
		UiKit.GOOD if won else (UiKit.BAD if outcome == BattleManager.Outcome.DEFEAT else UiKit.WARN)))

	var result := battle.build_result()
	box.add_child(UiKit.label("%d s  ·  %s" % [
		result["seconds"], result["region"]], UiKit.SMALL, UiKit.MUTED))

	for row in result["units"]:
		var line := VBoxContainer.new()
		line.add_theme_constant_override("separation", 0)
		var head := UiKit.row(row["name"], "%d / %d" % [row["hp"], row["hp_max"]],
			Color.WHITE if row["alive"] else UiKit.MUTED)
		(head.get_child(0) as Label).modulate = Teams.color(row["is_player"]) \
			if row["alive"] else UiKit.MUTED
		line.add_child(head)
		line.add_child(UiKit.label("verursacht %d  ·  erlitten %d%s" % [row["dealt"], row["taken"],
			"" if row["alive"] else "  ·  ausgefallen"], UiKit.SMALL, UiKit.MUTED))
		box.add_child(line)

	_add_loot_section(box, outcome)

	if GameState.in_run_battle:
		var onward := UiKit.button("Weiter im Lauf", true)
		var pool: Array = battle.enemy_equipment.duplicate()
		# Wer hat wie viele Abschuesse -- fuer die EP der Waffen (Leveling).
		var fighters: Array = []
		for unit in battle.units:
			if unit.is_player and unit.build != null:
				var weapons := {}
				for slot in unit.build.equip_slots():
					weapons[slot] = unit.weapon_record(slot)
				fighters.append({"source_uid": unit.build.source_uid, "weapons": weapons})
		onward.pressed.connect(func():
			GameState.finish_run_battle(outcome, pool, fighters)
			get_tree().change_scene_to_file("res://scenes/run.tscn"))
		buttons.add_child(onward)
		onward.grab_focus.call_deferred()
		return

	var back := UiKit.button("Zum Hangar", true)
	back.pressed.connect(func():
		GameState.battle_seed = 0
		GameState.clear_chaos_run()
		get_tree().change_scene_to_file("res://scenes/hangar.tscn"))
	buttons.add_child(back)

	var menu := UiKit.button("Zur Startseite")
	menu.pressed.connect(func():
		GameState.battle_seed = 0
		GameState.clear_chaos_run()
		get_tree().change_scene_to_file("res://scenes/main.tscn"))
	buttons.add_child(menu)
