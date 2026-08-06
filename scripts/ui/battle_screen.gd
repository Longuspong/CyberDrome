extends Node2D

## Der Kampfbildschirm: verbindet Eingabe, Darstellung und Ablauf.
##
## Hier steht keine Regel. Was erlaubt ist, sagt der BattleManager; wie es
## aussieht, die BattleView. Dieser Knoten uebersetzt nur Klicks in Zuege und
## Zustaende in Anzeigen.

const AI_STEP_DELAY := 0.4

@onready var view: BattleView = $BattleView
@onready var camera: Camera2D = $Camera2D

var battle: BattleManager
var _selected_action: ActionData = null
var _reachable: Dictionary = {}
var _busy: bool = false
var _paused: bool = false

# UI
var _ui: CanvasLayer
var _tick_queue: HBoxContainer
var _action_bar: HBoxContainer
var _log: RichTextLabel
var _status: Label
var _end_turn: Button
var _tooltip: Label
var _mutator_banner: PanelContainer


func _ready() -> void:
	battle = BattleManager.new()
	add_child(battle)

	_build_ui()

	EventBus.log_message.connect(_on_log)
	EventBus.unit_moved.connect(_on_unit_moved)
	EventBus.unit_died.connect(_on_unit_died)
	EventBus.tick_bus_changed.connect(_refresh_tick_queue)
	battle.battle_over.connect(_on_battle_over)

	_start_battle()


func _start_battle() -> void:
	var builds := GameState.squad
	if builds.is_empty():
		builds = _demo_squad()
		GameState.squad = builds
	if GameState.battle_seed == 0:
		GameState.new_seed()

	battle.setup(GameState.battle_seed, builds)
	view.build_terrain(battle.grid)
	for unit in battle.units:
		view.attach_unit(unit)

	camera.position = IsoView.grid_center(battle.grid.width, battle.grid.height)
	camera.zoom = Vector2(0.62, 0.62)

	_show_mutator()
	_next_turn()


## Nur fuer den Direktstart der Kampfszene ohne Werkstatt. Sobald ein Squad
## in GameState liegt, wird dieser hier nicht mehr benutzt.
func _demo_squad() -> Array:
	return [
		DromeBuild.create("ALPHA", {
			"body": &"scout_body", "head": &"scout_head",
			"feet": &"scout_feet", "core": &"scout_core",
			"equip_left": &"eq_pulse_blaster", "equip_right": &"eq_deflector"}),
		DromeBuild.create("BETA", {
			"body": &"strix_body", "head": &"strix_head",
			"feet": &"strix_feet", "core": &"strix_core",
			"equip_center": &"eq_rail_lance"}),
	]


# ---------------------------------------------------------------------------
# Zugschleife
# ---------------------------------------------------------------------------

func _next_turn() -> void:
	if battle.outcome != BattleManager.Outcome.RUNNING:
		return
	var unit := battle.begin_next_turn()
	if unit == null:
		# Der DROME ist zu Zugbeginn ausgefallen (Aderlass) -- weiter.
		if battle.outcome == BattleManager.Outcome.RUNNING:
			call_deferred("_next_turn")
		return

	_selected_action = null
	_refresh_reachable()
	_refresh_tick_queue()
	_refresh_action_bar()
	_refresh_status()

	if not unit.is_player:
		_run_ai_turn()


func _run_ai_turn() -> void:
	_busy = true
	var controller := AIController.new(battle)
	# Schritt fuer Schritt statt eines Plans fuer den ganzen Zug: nur so
	# rechnet die KI mit der Lage, die nach dem letzten Schritt wirklich
	# besteht -- inklusive der Felder, auf denen sie weggerutscht ist.
	for _step_index in 6:
		if battle.outcome != BattleManager.Outcome.RUNNING:
			break
		await get_tree().create_timer(AI_STEP_DELAY).timeout
		while _paused:
			await get_tree().process_frame
		if controller.take_step().is_empty():
			break
		_refresh_status()
	await get_tree().create_timer(AI_STEP_DELAY).timeout
	_busy = false
	_end_current_turn()


func _end_current_turn() -> void:
	view.clear_overlays()
	view.clear_path_preview()
	battle.end_turn()
	if battle.outcome == BattleManager.Outcome.RUNNING:
		_next_turn()


# ---------------------------------------------------------------------------
# Eingabe
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _busy or _paused or battle.outcome != BattleManager.Outcome.RUNNING:
		return
	var unit := battle.active_unit
	if unit == null or not unit.is_player:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_end_current_turn()
			KEY_ESCAPE:
				if _selected_action != null:
					_selected_action = null
					_refresh_reachable()
					_refresh_action_bar()
				else:
					battle.undo_movement()
					_refresh_reachable()
		return

	if event is InputEventMouseMotion:
		_on_hover(view.tile_at_screen(view.get_local_mouse_position()))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_click(view.tile_at_screen(view.get_local_mouse_position()))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if _selected_action != null:
				_selected_action = null
				_refresh_action_bar()
			else:
				battle.undo_movement()
			_refresh_reachable()


func _on_hover(tile: Vector2i) -> void:
	if not battle.grid.in_bounds(tile):
		view.clear_path_preview()
		_tooltip.text = ""
		return

	_tooltip.text = _tooltip_for(tile)

	if _selected_action != null:
		view.clear_path_preview()
		return
	if _reachable.has(tile):
		var entry: Dictionary = _reachable[tile]
		view.set_path_preview(entry["path"], entry["slide_path"])
	else:
		view.clear_path_preview()


func _tooltip_for(tile: Vector2i) -> String:
	var grid := battle.grid
	var lines: Array[String] = []
	lines.append("%s  (%s)" % [grid.terrain_name(tile),
		Terrain.class_label(grid.terrain_class(tile))])

	var unit := battle.active_unit
	if unit != null and not grid.can_stand_on(tile, unit.move_profile()) \
			and grid.terrain_class(tile) != Terrain.TClass.BLOCK \
			and not grid.is_occupied(tile, unit.unit_id):
		lines.append("Fuer diesen Antrieb nicht betretbar")

	var other := battle.resolver.unit_at(tile)
	if other != null:
		lines.append("%s  Integritaet %d/%d  EN %d  SPD %d  DEF %d"
			% [other.display_name, other.hp, other.stat("hp_max"), other.en,
				other.spd(), other.def()])
		if not other.status_names().is_empty():
			lines.append("Effekte: " + ", ".join(other.status_names()))
		if _selected_action != null and unit != null:
			var blocker := battle.resolver.target_blocker(unit, tile, _selected_action)
			if blocker != "":
				lines.append(blocker)
			else:
				var amount := battle.resolver.preview_damage(unit, other, _selected_action)
				lines.append("Vorschau: %d %s" % [absi(amount),
					"Heilung" if amount < 0 else "Schaden"])
	return "\n".join(lines)


func _on_click(tile: Vector2i) -> void:
	if _selected_action != null:
		if battle.use_action(tile, _selected_action):
			_selected_action = null
			_refresh_reachable()
			_refresh_action_bar()
			_refresh_status()
		return
	if _reachable.has(tile):
		battle.move_active_to(tile)
		_refresh_reachable()
		_refresh_status()


# ---------------------------------------------------------------------------
# Anzeige
# ---------------------------------------------------------------------------

func _refresh_reachable() -> void:
	var unit := battle.active_unit
	if unit == null:
		view.clear_overlays()
		return

	var sets: Array = [{
		"tiles": [unit.tile], "color": BattleView.COLOR_ACTIVE,
		"texture": BattleView.OVERLAY_OUTLINE,
	}]

	if _selected_action == null:
		_reachable = battle.reachable_for_active() if unit.is_player else {}
		var tiles: Array = _reachable.keys()
		sets.append({"tiles": tiles, "color": BattleView.COLOR_REACHABLE})
	else:
		_reachable = {}
		var valid: Array = []
		var blocked: Array = []
		for tile in battle.resolver.tiles_in_range(unit, _selected_action):
			if battle.resolver.target_blocker(unit, tile, _selected_action) == "":
				valid.append(tile)
			elif battle.resolver.unit_at(tile) != null:
				# Ungueltige Ziele IN Reichweite werden grau statt rot -- mit
				# Grund im Tooltip. Ein Ziel einfach wegzulassen liesse den
				# Spieler raten, ob es die Reichweite oder die Sicht war.
				blocked.append(tile)
		sets.append({"tiles": blocked, "color": BattleView.COLOR_BLOCKED})
		sets.append({"tiles": valid, "color": BattleView.COLOR_TARGET})

	view.paint(sets)
	view.refresh_all_depths(battle.units)


func _refresh_status() -> void:
	var unit := battle.active_unit
	if unit == null or battle.turn_state == null:
		_status.text = ""
		return
	var state := battle.turn_state
	_status.text = "%s   Integritaet %d/%d   EN %d/%d   MP %d   Angriff %d   Faehigkeit %d   Zyklus %d" % [
		unit.display_name, unit.hp, unit.stat("hp_max"), unit.en,
		unit.stat("en_max"), state.move_points, state.attack_actions,
		state.ability_actions, battle.tick_bus.cycle_count]
	# Der Zug endet nie automatisch -- aber wenn nichts mehr geht, faellt der
	# Button ins Auge.
	_end_turn.modulate = Color(1.0, 0.85, 0.3) if state.budgets_spent() else Color.WHITE


func _refresh_tick_queue() -> void:
	for child in _tick_queue.get_children():
		child.queue_free()
	if battle.tick_bus == null:
		return
	var order := battle.tick_bus.preview(Config.get_int("tick_queue_length", 8))
	for i in order.size():
		var unit := battle._unit_by_id(order[i])
		if unit == null:
			continue
		var label := Label.new()
		label.text = unit.display_name
		label.add_theme_font_size_override("font_size", 13)
		var base := Color(0.55, 0.85, 1.0) if unit.is_player else Color(1.0, 0.55, 0.5)
		label.modulate = base if i > 0 else Color.WHITE
		if i == 0:
			label.add_theme_font_size_override("font_size", 16)
		_tick_queue.add_child(label)


func _refresh_action_bar() -> void:
	for child in _action_bar.get_children():
		child.queue_free()
	var unit := battle.active_unit
	if unit == null or not unit.is_player or battle.turn_state == null:
		return
	for action in unit.actions():
		var button := Button.new()
		var blocker := battle.turn_state.blocker_for(action)
		button.text = "%s  (EN %d)" % [action.display_name, action.en_cost]
		if blocker != "":
			button.disabled = true
			button.tooltip_text = blocker
		else:
			button.tooltip_text = "Reichweite %d%s" % [action.range_tiles,
				", Sichtlinie noetig" if action.requires_line_of_sight else ""]
		if action == _selected_action:
			button.modulate = Color(1.0, 0.85, 0.3)
		button.pressed.connect(func():
			_selected_action = null if _selected_action == action else action
			_refresh_reachable()
			_refresh_action_bar())
		_action_bar.add_child(button)


func _show_mutator() -> void:
	var label := _mutator_banner.get_child(0) as Label
	label.text = "%s\n%s" % [battle.mutator.display_name, battle.mutator.description]
	_mutator_banner.visible = true
	var tween := create_tween()
	tween.tween_interval(2.6)
	tween.tween_property(_mutator_banner, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): _mutator_banner.visible = false)


func _on_log(text: String) -> void:
	_log.append_text(text + "\n")


func _on_unit_moved(unit: Unit, _from: Vector2i, _to: Vector2i) -> void:
	view.refresh_unit_depth(unit)
	for other in battle.units:
		other.set_in_haze(
			battle.grid.terrain_class(other.tile) == Terrain.TClass.HAZE)


func _on_unit_died(unit: Unit) -> void:
	unit.visible = false
	_refresh_tick_queue()


func _on_battle_over(outcome: BattleManager.Outcome) -> void:
	view.clear_overlays()
	view.clear_path_preview()
	_status.text = "%s nach %d Zyklen.  Seed: %d" % [
		BattleManager.outcome_label(outcome), battle.tick_bus.cycle_count,
		battle.battle_seed]
	_show_result(outcome)


# ---------------------------------------------------------------------------
# UI-Aufbau
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)

	_tick_queue = HBoxContainer.new()
	_tick_queue.add_theme_constant_override("separation", 14)
	_tick_queue.position = Vector2(24, 16)
	_ui.add_child(_tick_queue)

	_status = Label.new()
	_status.position = Vector2(24, 46)
	_ui.add_child(_status)

	_tooltip = Label.new()
	_tooltip.position = Vector2(24, 74)
	_tooltip.add_theme_color_override("font_color", Color(0.8, 0.86, 0.95))
	_ui.add_child(_tooltip)

	_action_bar = HBoxContainer.new()
	_action_bar.add_theme_constant_override("separation", 8)
	_action_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_action_bar.position = Vector2(24, 830)
	_ui.add_child(_action_bar)

	_end_turn = Button.new()
	_end_turn.text = "Zug beenden  (Leertaste)"
	_end_turn.position = Vector2(1340, 826)
	_end_turn.custom_minimum_size = Vector2(230, 44)
	_end_turn.pressed.connect(func():
		if not _busy and not _paused:
			_end_current_turn())
	_ui.add_child(_end_turn)

	_log = RichTextLabel.new()
	_log.position = Vector2(1240, 120)
	_log.custom_minimum_size = Vector2(340, 420)
	_log.size = Vector2(340, 420)
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 12)
	_ui.add_child(_log)

	var pause := Button.new()
	pause.text = "Pause"
	pause.position = Vector2(1460, 16)
	pause.pressed.connect(_toggle_pause)
	_ui.add_child(pause)

	_mutator_banner = PanelContainer.new()
	_mutator_banner.position = Vector2(560, 300)
	var banner_label := Label.new()
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 26)
	_mutator_banner.add_child(banner_label)
	_mutator_banner.visible = false
	_ui.add_child(_mutator_banner)


func _toggle_pause() -> void:
	_paused = not _paused
	_status.text = "Pausiert." if _paused else _status.text


func _show_result(outcome: BattleManager.Outcome) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(520, 240)
	panel.custom_minimum_size = Vector2(560, 380)
	var box := VBoxContainer.new()
	panel.add_child(box)

	var title := Label.new()
	title.text = BattleManager.outcome_label(outcome)
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)

	var result := battle.build_result()
	var summary := Label.new()
	summary.text = "Zyklen: %d    Region: %s    Mutator: %s\nSeed: %d" % [
		result["cycles"], result["region"], result["mutator"], result["seed"]]
	box.add_child(summary)

	for row in result["units"]:
		var line := Label.new()
		line.text = "%-10s %s  Integritaet %d/%d   verursacht %d   erlitten %d" % [
			row["name"], "Spieler" if row["is_player"] else "Gegner",
			row["hp"], row["hp_max"], row["dealt"], row["taken"]]
		line.modulate = Color.WHITE if row["alive"] else Color(0.6, 0.6, 0.6)
		box.add_child(line)

	var back := Button.new()
	back.text = "Zurueck zur Werkstatt"
	back.pressed.connect(func():
		GameState.battle_seed = 0
		get_tree().change_scene_to_file("res://scenes/main.tscn"))
	box.add_child(back)

	_ui.add_child(panel)
