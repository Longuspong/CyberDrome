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

## Aktion, ueber der der Zeiger gerade steht -- in der Aktionsleiste oder im
## Ring. Ihre Reichweite wird eingefaerbt, ohne dass sie gewaehlt sein muss:
## der Spieler soll sehen koennen, wie weit etwas reicht, bevor er es waehlt.
var _hovered_action: ActionData = null

var _reachable: Dictionary = {}
var _busy: bool = false
var _paused: bool = false

## Feld, ueber dem der Zeiger zuletzt stand. Fuer den Flaechenumriss: bei einer
## Flaechenaktion muss VOR dem Klick sichtbar sein, wen sie mittrifft.
var _hover_tile: Vector2i = Vector2i(-1, -1)

# UI
var _ui: CanvasLayer
var _tick_queue: HBoxContainer
var _action_bar: HBoxContainer
var _log: RichTextLabel
var _status: Label
var _end_turn: Button
var _tooltip: Label
var _mutator_banner: PanelContainer
var _tick_bars: TickBarPanel
var _action_ring: ActionRing


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

	_tick_bars.rebuild(battle.units, battle.tick_bus)
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
	_hovered_action = null
	_action_ring.hide_ring()
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
	view.clear_damage_preview()
	_hovered_action = null
	_action_ring.hide_ring()

	# Erst der echte Zug, dann die Inszenierung: der Balken zeigt, was schon
	# passiert ist, und bestimmt nichts.
	var finished := battle.active_unit
	battle.end_turn()
	if finished != null:
		_tick_bars.play_turn_end(finished.unit_id, battle.tick_bus)

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
				# Eine Ebene je Druck: erst die gewaehlte Aktion, dann der
				# angeheftete Ring, dann die Bewegung.
				if _selected_action != null:
					_selected_action = null
					_refresh_reachable()
					_refresh_action_bar()
				elif _action_ring.pinned:
					_action_ring.hide_ring()
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
			elif _action_ring.pinned:
				_action_ring.hide_ring()
			else:
				battle.undo_movement()
			_refresh_reachable()


func _on_hover(tile: Vector2i) -> void:
	if not battle.grid.in_bounds(tile):
		view.clear_path_preview()
		_tooltip.text = ""
		return

	var changed := tile != _hover_tile
	_hover_tile = tile
	_tooltip.text = _tooltip_for(tile)

	# Aktionsring: beim Hovern ueber einen DROME erscheinen die Aktionen ueber
	# der Einheit. Ein angehefteter Ring bleibt dagegen stehen -- sonst waere
	# er unbedienbar, weil zwischen Einheit und Knoepfen leere Flaeche liegt.
	var hovered := battle.resolver.unit_at(tile)
	if not _action_ring.pinned:
		if _selected_action == null and hovered != null \
				and battle.active_unit != null and battle.active_unit.is_player:
			if not _action_ring.is_showing_for(tile):
				_action_ring.show_for(battle, hovered, _ring_anchor(hovered))
		else:
			_action_ring.hide_ring()

	if _selected_action != null:
		view.clear_path_preview()
		# Der Flaechenumriss haengt am Zielfeld und muss deshalb bei jeder
		# Feldaenderung neu.
		if changed:
			_refresh_reachable()
		return
	if _reachable.has(tile):
		var entry: Dictionary = _reachable[tile]
		view.set_path_preview(entry["path"], entry["slide_path"])
	else:
		view.clear_path_preview()


## Wo der Ring haengt: mittig ueber dem Kopf des DROME.
##
## Bezugspunkt ist nicht der Knotenursprung -- der liegt in der oberen linken
## Ecke des 128er Bildes und damit merklich links neben dem Bot. Genommen wird
## die Mittelachse des Bildes, und zwar durch die Leinwandtransformation, damit
## der Kamerazoom mitgerechnet ist.
func _ring_anchor(unit: Unit) -> Vector2:
	return unit.get_global_transform_with_canvas() \
		* Vector2(IsoView.SPRITE_ORIGIN.x, 0.0)


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
		var aggro := _aggro_line(other)
		if aggro != "":
			lines.append(aggro)
		# Auch die nur gehoverte Aktion rechnet ihre Vorschau -- man soll
		# vergleichen koennen, ohne sich vorher festzulegen.
		var shown: ActionData = _selected_action if _selected_action != null \
			else _hovered_action
		if shown != null and unit != null:
			var blocker := battle.resolver.target_blocker(unit, tile, shown)
			if blocker != "":
				lines.append("%s: %s" % [shown.display_name, blocker])
			else:
				var amount := battle.resolver.preview_damage(unit, other, shown)
				var wirkung: String = shown.effect_summary() if amount == 0 \
					else "%d %s" % [absi(amount), "Heilung" if amount < 0
						else "Schaden %s" % shown.damage_type_label()]
				lines.append("%s: %s%s" % [shown.display_name, wirkung,
					"  (Ausfall)" if amount > 0 and amount >= other.hp else ""])
	return "\n".join(lines)


## Worauf dieser DROME achtet -- als Rangfolge mit Anteilen.
##
## Das ist keine Zugabe, sondern Bedingung. Der Kampf ist deterministisch und
## verspricht dem Spieler, dass er jede Aktion vorher durchrechnen kann; die
## TICK-Leiste legt die Zugreihenfolge sogar acht Zuege im Voraus offen. Eine
## verdeckte Aggro-Tabelle waere die einzige Stelle, an der ein Gegner etwas
## tut, das der Spieler nicht nachvollziehen kann -- und damit fuer ihn nicht
## von Zufall zu unterscheiden.
##
## Angezeigt werden Anteile, keine Rohwerte: die Zahl an sich bedeutet nichts,
## nur die Rangfolge (siehe AggroTable).
func _aggro_line(unit: Unit) -> String:
	if unit.is_taunted():
		var forcer := battle.resolver.unit_by_id(unit.taunted_by())
		if forcer != null:
			return "Provoziert von %s (noch %d Zuege)" % [forcer.display_name,
				int(unit.taunt_lock.get("turns_left", 0))]
	if unit.aggro == null or unit.aggro.is_empty():
		return ""
	var parts: Array[String] = []
	for row in unit.aggro.ranking():
		var other := battle.resolver.unit_by_id(row["id"])
		if other == null:
			continue
		parts.append("%s %d%%%s" % [other.display_name, int(round(row["share"] * 100.0)),
			" <" if row["id"] == unit.aggro.current_target else ""])
	return "" if parts.is_empty() else "Achtet auf: " + "  ".join(parts)


## Aus dem Aktionsring gewaehlt. Geht denselben Weg wie ein Klick in der
## Aktionsleiste -- der Ring ist eine zweite Bedienung, keine zweite Regel.
func _on_ring_action(action: ActionData, target_tile: Vector2i) -> void:
	if not battle.use_action(target_tile, action):
		return
	_selected_action = null
	_hovered_action = null
	_refresh_reachable()
	_refresh_action_bar()
	_refresh_status()
	# Der Ring bleibt am selben Ziel stehen und zeigt jetzt den neuen Stand:
	# weniger Integritaet, verbrauchtes Budget, veraenderte Gruende. Wer zwei
	# Aktionen auf dasselbe Ziel legen will, soll es nicht zweimal anklicken
	# muessen.
	var target := battle.resolver.unit_at(target_tile)
	if _action_ring.pinned and target != null and target.is_alive():
		_action_ring.show_for(battle, target, _ring_anchor(target), true)
	else:
		_action_ring.hide_ring()


## Ein Klick auf ein Feld. Drei Faelle, in dieser Reihenfolge:
##
##     1. Es ist eine Aktion gewaehlt -> sie wird auf dieses Feld angewendet.
##     2. Dort steht ein DROME        -> sein Aktionsring wird angeheftet.
##     3. Das Feld ist erreichbar     -> es wird hingelaufen.
##
## Fall 2 ist der Grund, warum der Kampf ueberhaupt bedienbar ist: der Ring
## verschwand vorher, sobald der Zeiger die Einheit verliess.
func _on_click(tile: Vector2i) -> void:
	if _selected_action != null:
		if battle.use_action(tile, _selected_action):
			_selected_action = null
			_refresh_reachable()
			_refresh_action_bar()
			_refresh_status()
		return

	var unit := battle.active_unit
	var clicked := battle.resolver.unit_at(tile)
	if clicked != null and unit != null and unit.is_player:
		if _action_ring.pinned and _action_ring.is_showing_for(tile):
			_action_ring.hide_ring()
		else:
			_action_ring.hide_ring()
			_action_ring.show_for(battle, clicked, _ring_anchor(clicked), true)
		return

	if _reachable.has(tile):
		# Wer losgeht, meint nicht mehr den Ring von vorhin -- er zeigte den
		# Stand von einem anderen Feld aus.
		_action_ring.hide_ring()
		battle.move_active_to(tile)
		_refresh_reachable()
		_refresh_status()


## Der Zeiger steht auf einem Aktionsknopf: seine Reichweite wird eingefaerbt,
## ohne dass die Aktion gewaehlt ist.
func _on_action_hovered(action) -> void:
	var next: ActionData = action as ActionData
	if next == _hovered_action:
		return
	_hovered_action = next
	_refresh_reachable()


# ---------------------------------------------------------------------------
# Anzeige
# ---------------------------------------------------------------------------

## Was auf der Karte eingefaerbt ist. Genau drei Zustaende, und sie schliessen
## sich aus:
##
##     keine Aktion    -> wohin komme ich (blau)
##     Aktion gewaehlt -> wen treffe ich (rot), wen nicht und warum (grau)
##     Aktion gehovert -> wie weit reicht sie (rot, aber nichts ist gewaehlt)
##
## Der dritte Fall ist neu und der Grund, warum sich der Kampf ueberhaupt
## planen laesst: die Reichweite einer Waffe stand vorher nirgends, ausser man
## waehlte sie aus und gab damit die Bewegungsvorschau auf.
func _refresh_reachable() -> void:
	var unit := battle.active_unit
	if unit == null:
		view.clear_overlays()
		view.clear_damage_preview()
		return

	var sets: Array = [{
		"tiles": [unit.tile], "color": BattleView.COLOR_ACTIVE,
		"texture": BattleView.OVERLAY_OUTLINE,
	}]

	var shown: ActionData = _selected_action if _selected_action != null \
		else _hovered_action

	if shown == null:
		_reachable = battle.reachable_for_active() if unit.is_player else {}
		var tiles: Array = _reachable.keys()
		sets.append({"tiles": tiles, "color": BattleView.COLOR_REACHABLE})
		view.clear_damage_preview()
	else:
		if _selected_action != null:
			_reachable = {}
		var valid: Array = []
		var blocked: Array = []
		for tile in battle.resolver.tiles_in_range(unit, shown):
			if battle.resolver.target_blocker(unit, tile, shown) == "":
				valid.append(tile)
			elif battle.resolver.unit_at(tile) != null:
				# Ungueltige Ziele IN Reichweite werden grau statt rot -- mit
				# Grund im Tooltip. Ein Ziel einfach wegzulassen liesse den
				# Spieler raten, ob es die Reichweite oder die Sicht war.
				blocked.append(tile)
		sets.append({"tiles": blocked, "color": BattleView.COLOR_BLOCKED})
		sets.append({"tiles": valid, "color": BattleView.COLOR_TARGET})
		var splash := _splash_tiles(unit, shown)
		if not splash.is_empty():
			sets.append({"tiles": splash, "color": BattleView.COLOR_SPLASH,
				"texture": BattleView.OVERLAY_OUTLINE})
		view.show_damage_preview(_damage_preview(unit, shown))

	view.paint(sets)
	view.refresh_all_depths(battle.units)


## Der Flaechenumriss unter dem Zeiger. Eine Flaechenaktion trifft mehr als das
## Feld, auf das gezielt wird -- auch eigene DROMEs. Das muss vor dem Klick zu
## sehen sein und nicht danach im Kampflog.
func _splash_tiles(unit: Unit, action: ActionData) -> Array:
	if action.aoe_radius <= 0 or not battle.grid.in_bounds(_hover_tile):
		return []
	if battle.resolver.target_blocker(unit, _hover_tile, action) != "":
		return []
	return battle.resolver.affected_tiles(_hover_tile, action)


## Die Schadenszahl ueber jedem Ziel in Reichweite.
##
## Dieselbe Rechnung, die auch der Treffer benutzt (ActionResolver.mitigate) --
## eine zweite, "ungefaehre" Vorschau waere genau die Stelle, an der das
## Versprechen bricht, dass sich jede Aktion vorher durchrechnen laesst.
func _damage_preview(unit: Unit, action: ActionData) -> Array:
	var entries: Array = []
	for other in battle.units:
		if not other.is_alive():
			continue
		if not battle.resolver.is_meaningful_target(unit, other, action):
			continue
		if battle.resolver.target_blocker(unit, other.tile, action) != "":
			continue
		var amount := battle.resolver.preview_damage(unit, other, action)
		if amount == 0:
			continue
		entries.append({
			"tile": other.tile,
			"text": "%d" % absi(amount),
			"heal": amount < 0,
			"lethal": amount > 0 and amount >= other.hp,
		})
	return entries


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
	if _tick_bars != null:
		_tick_bars.sync(battle.tick_bus)
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


## Die Aktionsleiste, getrennt nach Budget.
##
## Angriff und Faehigkeit sind zwei Budgets und werden deshalb als zwei Gruppen
## gezeigt, jede mit ihrer Ueberschrift. Vorher standen alle Aktionen in einer
## Reihe -- damit war einem Aufbau nicht anzusehen, dass ein Puls-Blaster und
## ein Runenstab sich dasselbe Budget teilen, ein Orbit-Fokus dagegen ein
## eigenes hat.
func _refresh_action_bar() -> void:
	for child in _action_bar.get_children():
		child.queue_free()
	var unit := battle.active_unit
	if unit == null or not unit.is_player or battle.turn_state == null:
		return

	for category in [ActionData.Category.ATTACK, ActionData.Category.ABILITY]:
		var actions := unit.actions_of(category)
		if actions.is_empty():
			continue
		var group := VBoxContainer.new()
		group.add_theme_constant_override("separation", 2)

		var heading := Label.new()
		var left: int = battle.turn_state.actions_left(category)
		heading.text = "%s  (%d)" % [ActionData.CATEGORY_LABEL[category], left]
		heading.add_theme_font_size_override("font_size", 11)
		heading.modulate = Color(0.62, 0.78, 0.92) if left > 0 \
			else Color(0.5, 0.5, 0.55)
		group.add_child(heading)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		group.add_child(row)
		for action in actions:
			row.add_child(_action_button(action))
		_action_bar.add_child(group)


func _action_button(action: ActionData) -> Button:
	var button := Button.new()
	var blocker := battle.turn_state.blocker_for(action)
	# Die Kurzform steht auf dem Knopf, die vollstaendige Beschreibung im
	# Tooltip -- und beide kommen aus ActionData, nicht aus dieser Datei.
	button.text = "%s   %s" % [action.display_name, action.headline()]
	var described: Array[String] = action.description_lines()
	if blocker != "":
		button.disabled = true
		described.push_front("Geht nicht: %s" % blocker)
	button.tooltip_text = "\n".join(described)
	if action == _selected_action:
		button.modulate = Color(1.0, 0.85, 0.3)
	button.pressed.connect(func():
		_selected_action = null if _selected_action == action else action
		_action_ring.hide_ring()
		_refresh_reachable()
		_refresh_action_bar())
	# Auch ein gesperrter Knopf zeigt beim Hovern seine Reichweite: wer wissen
	# will, ob er im naechsten Zug herankommt, braucht dafuer keine Energie.
	button.mouse_entered.connect(func(): _on_action_hovered(action))
	button.mouse_exited.connect(func(): _on_action_hovered(null))
	return button


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
	_tick_bars.drop_unit(unit.unit_id)
	_action_ring.hide_ring()
	_refresh_tick_queue()


func _on_battle_over(outcome: BattleManager.Outcome) -> void:
	view.clear_overlays()
	view.clear_path_preview()
	view.clear_damage_preview()
	_status.text = "%s nach %d Zyklen.  Seed: %d" % [
		BattleManager.outcome_label(outcome), battle.tick_bus.cycle_count,
		battle.battle_seed]
	_show_result(outcome)


# ---------------------------------------------------------------------------
# UI-Aufbau
# ---------------------------------------------------------------------------

## Haengt ein Bedienelement an die untere Bildkante, ``above_bottom`` Pixel
## darueber.
##
## Der Umweg ist noetig, weil ``set_anchors_preset(PRESET_BOTTOM_LEFT)`` genau
## das NICHT tut: der Preset setzt die Anker und rechnet die Abstaende auf die
## bisherige Lage zurueck; ein danach gesetztes ``position`` zaehlt dann zur
## Unterkante HINZU. Die Aktionsleiste stand dadurch bei y = 900 + 830 = 1730
## -- also weit unter dem Bildrand, unsichtbar. Damit gab es im Kampf keine
## Aktionsleiste, und der einzige verbliebene Weg zu einer Aktion war der
## Aktionsring, der beim Hinfahren verschwand.
func _place_bottom(control: Control, x: float, above_bottom: float) -> void:
	control.anchor_left = 0.0
	control.anchor_right = 0.0
	control.anchor_top = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = x
	control.offset_right = x
	control.offset_top = -above_bottom
	control.offset_bottom = -above_bottom


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
	_tooltip.position = Vector2(24, 240)
	_tooltip.add_theme_color_override("font_color", Color(0.8, 0.86, 0.95))
	_ui.add_child(_tooltip)

	# Die Leiste traegt jetzt zwei Gruppen mit Ueberschrift und braucht deshalb
	# mehr Hoehe als frueher.
	_action_bar = HBoxContainer.new()
	_action_bar.add_theme_constant_override("separation", 22)
	_ui.add_child(_action_bar)
	_place_bottom(_action_bar, 24, 100)

	var legend := Label.new()
	legend.add_theme_font_size_override("font_size", 11)
	legend.modulate = Color(0.6, 0.66, 0.74)
	legend.text = "Klick auf einen DROME heftet seinen Aktionsring an  ·  "\
		+ "Zeiger auf eine Aktion zeigt ihre Reichweite  ·  "\
		+ "Rechtsklick/ESC loest, Leertaste beendet den Zug"
	_ui.add_child(legend)
	_place_bottom(legend, 24, 128)

	_end_turn = Button.new()
	_end_turn.text = "Zug beenden  (Leertaste)"
	_end_turn.custom_minimum_size = Vector2(230, 44)
	_end_turn.pressed.connect(func():
		if not _busy and not _paused:
			_end_current_turn())
	_ui.add_child(_end_turn)
	_place_bottom(_end_turn, 1340, 70)

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

	_tick_bars = TickBarPanel.new()
	_tick_bars.position = Vector2(24, 104)
	_tick_bars.add_theme_constant_override("separation", 3)
	_ui.add_child(_tick_bars)

	_action_ring = ActionRing.new()
	_action_ring.action_chosen.connect(_on_ring_action)
	_action_ring.action_hovered.connect(_on_action_hovered)
	_ui.add_child(_action_ring)

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
		get_tree().change_scene_to_file("res://scenes/workshop.tscn"))
	box.add_child(back)

	var menu := Button.new()
	menu.text = "Hauptmenue"
	menu.pressed.connect(func():
		GameState.battle_seed = 0
		get_tree().change_scene_to_file("res://scenes/main.tscn"))
	# Stand hier ``box.add_child(back)`` -- derselbe Knopf ein zweites Mal.
	# Godot lehnt das ab ("already has a parent"), der Knopf ins Hauptmenue
	# tauchte nie auf, und vom Ergebnisbildschirm fuehrte nur ein Weg zurueck.
	box.add_child(menu)

	_ui.add_child(panel)
