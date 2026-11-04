extends Node2D

## Der Kampfbildschirm: verbindet Eingabe, Darstellung und Ablauf.
##
## Hier steht keine Regel. Was erlaubt ist, sagt der BattleManager; wie es
## aussieht, die BattleView. Dieser Knoten uebersetzt nur Klicks in Zuege und
## Zustaende in Anzeigen.

## Wie schnell der Kampf ablaeuft.
##
## Die Werte standen als eine einzige Konstante im Code und waren zu knapp: der
## Zug wechselte, waehrend der TICK-Balken noch lief, und zwei KI-Schritte
## folgten so dicht aufeinander, dass nicht zu sehen war, welcher davon der
## Angriff war. Ein Kampf, dem man nicht folgen kann, ist nicht schneller --
## er ist nur kuerzer.
##
## Aus der Konfiguration, damit sich das Tempo ohne Codeaenderung nachziehen
## laesst (data/config.json, Abschnitt "pacing").
var _ai_step_delay: float = 0.65
var _turn_handover_delay: float = 0.35

## Kamerastoss beim Treffer. Der Ausschlag skaliert mit dem Anteil der
## Integritaet, den der Treffer gekostet hat.
const CAMERA_SHAKE_MAX := 9.0
const CAMERA_SHAKE_TIME := 0.26

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

## Autokampf: die KI zieht fuer BEIDE Seiten, der Spieler sieht zu. Immer an
## (GameState.auto_battle ist nur noch ein Entwickler-Schalter) und wird beim
## Aufbau einmal gelesen -- ein Kampf wechselt den Modus nicht mittendrin.
var _auto: bool = false

## Tempo des Autokampfs. Laeuft ueber Engine.time_scale, damit Pausen,
## TICK-Balken und Tweens gemeinsam schneller werden und nichts aus dem Takt
## geraet. Bewusst nur 1x und 2x: schneller ist der Kampf nicht mehr lesbar.
const SPEEDS := [1.0, 2.0]
var _speed_index: int = 0
var _speed_button: Button

## Kamera (mobile first). Auf dem Handy ist die 20x20-Karte nur als Ganzes
## sichtbar, wenn alles daumennagelgross ist. Deshalb folgt die Kamera dem
## aktiven DROME in einem lesbaren Zoom; mit einem Finger ziehen verschiebt,
## mit zwei Fingern zoomt. Wer selbst schiebt, schaltet das Folgen ab -- der
## Knopf "Folgen" holt es zurueck.
const ZOOM_MIN := 0.2
const ZOOM_MAX := 1.2
const DRAG_THRESHOLD := 10.0
var _follow := true
var _touches: Dictionary = {}
var _drag_distance := 0.0
var _pinch_distance := 0.0
var _pinch_zoom := 1.0
var _camera_tween: Tween
var _follow_button: Button
var _pause_button: Button
var _log_panel: PanelContainer
var _order_panel: PanelContainer

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
var _squad_tiles: SquadTiles
var _action_ring: ActionRing


func _ready() -> void:
	# Ein Lauf ist der Autobattler: dort kaempft immer die KI.
	_auto = GameState.auto_battle or GameState.in_run_battle
	battle = BattleManager.new()
	add_child(battle)

	var pacing := Config.section("pacing")
	_ai_step_delay = float(pacing.get("ai_step_delay", _ai_step_delay))
	_turn_handover_delay = float(pacing.get("turn_handover_delay",
		_turn_handover_delay))

	_build_ui()

	EventBus.log_message.connect(_on_log)
	EventBus.unit_moved.connect(_on_unit_moved)
	EventBus.unit_died.connect(_on_unit_died)
	EventBus.unit_damaged.connect(_on_unit_damaged)
	EventBus.unit_healed.connect(_on_unit_healed)
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

	battle.setup(GameState.battle_seed, builds, GameState.enemy_override)
	battle.overtime_enabled = _auto
	view.build_terrain(battle.grid)
	for unit in battle.units:
		view.attach_unit(unit)

	camera.position = IsoView.grid_center(battle.grid.width, battle.grid.height)
	_add_scenery()
	_fit_camera()
	get_viewport().size_changed.connect(_fit_camera)

	_tick_bars.rebuild(battle.units, battle.tick_bus)
	_squad_tiles.setup(battle.living(true))
	_squad_tiles.tile_pressed.connect(_look_at_unit)
	_show_mutator()
	_next_turn()


## Die Kulisse ausserhalb des Spielfelds, passend zur Region: Neon-Grossstadt
## in Sektor City, ueberwucherte Ruinen in der Gruenzone, Schlote in Anlage 7.
## Sie liegt in einer eigenen Ebene hinter der Karte und wandert mit der
## Kamera ein wenig mit (Parallaxe).
func _add_scenery() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var region_id := str(battle.region.id) if battle.region != null else ""
	var scenery := Ambience.create(Ambience.kind_for_region(region_id))
	scenery.camera = camera
	scenery.camera_home = camera.position
	layer.add_child(scenery)


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
	_follow_unit(unit)
	_refresh_reachable()
	_refresh_tick_queue()
	_refresh_action_bar()
	_refresh_status()
	_refresh_badges()

	if _auto or not unit.is_player:
		_run_ai_turn()


func _run_ai_turn() -> void:
	_busy = true
	var controller := AIController.new(battle)
	# Schritt fuer Schritt statt eines Plans fuer den ganzen Zug: nur so
	# rechnet die KI mit der Lage, die nach dem letzten Schritt wirklich
	# besteht -- inklusive der Felder, auf denen sie weggerutscht ist.
	# Die Obergrenze ist grosszuegig: ein Aufbau kann jetzt mehrere Angriffe
	# (einen je Waffe) und mehrere Faehigkeiten pro Zug ziehen (GAME_DESIGN §13).
	for _step_index in AIController.MAX_STEPS:
		if battle.outcome != BattleManager.Outcome.RUNNING:
			break
		await get_tree().create_timer(_ai_step_delay).timeout
		while _paused:
			await get_tree().process_frame
		if controller.take_step().is_empty():
			break
		_refresh_status()
		_refresh_badges()
	await get_tree().create_timer(_ai_step_delay).timeout
	_busy = false
	_end_current_turn()


## Zugende und Uebergabe.
##
## Der naechste Zug beginnt erst, wenn der TICK-Balken seine Bewegung beendet
## hat. Vorher lief beides gleichzeitig: der Balken der abtretenden Einheit
## leerte sich, waehrend die naechste schon markiert war und die KI bereits
## lief. Beide Vorgaenge waren einzeln richtig animiert und zusammen nicht mehr
## auseinanderzuhalten -- der Kampf sprang, statt uebergeben zu werden.
##
## ``_busy`` bleibt waehrend der Uebergabe gesetzt, sonst faellt ein Klick in
## die Luecke und trifft eine Einheit, die noch gar nicht am Zug ist.
func _end_current_turn() -> void:
	view.clear_overlays()
	view.clear_path_preview()
	view.clear_damage_preview()
	_hovered_action = null
	_action_ring.hide_ring()

	# Erst der echte Zug, dann die Inszenierung: der Balken zeigt, was schon
	# passiert ist, und bestimmt nichts.
	var finished := battle.active_unit
	var was_busy := _busy
	battle.end_turn()
	if finished != null:
		finished.set_active(false)
		_busy = true
		await _tick_bars.play_turn_end(finished.unit_id, battle.tick_bus)
		await get_tree().create_timer(_turn_handover_delay).timeout
		_busy = was_busy

	_refresh_badges()
	if battle.outcome == BattleManager.Outcome.RUNNING:
		_next_turn()


# ---------------------------------------------------------------------------
# Eingabe
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _camera_input(event):
		get_viewport().set_input_as_handled()
		return
	if _busy or _paused or battle.outcome != BattleManager.Outcome.RUNNING:
		return
	var unit := battle.active_unit
	if _auto or unit == null or not unit.is_player:
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
	_refresh_badges()
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
			_refresh_badges()
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
		_refresh_badges()


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
		_reachable = battle.reachable_for_active() \
			if unit.is_player and not _auto else {}
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
## Feld, auf das gezielt wird; wie weit sie reicht, muss vor dem Klick zu sehen
## sein und nicht danach im Kampflog.
##
## Der Umriss zeigt die REICHWEITE, nicht die Opfer -- getroffen wird darin nur,
## wen die Aktion ueberhaupt meint (ActionResolver.is_meaningful_target). Die
## Schadenszahlen in _damage_preview() fragen dieselbe Regel, Umriss und Zahlen
## widersprechen sich also nicht mehr: ein eigener DROME im Umriss bekommt keine
## Zahl, weil ihm auch nichts passiert.
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
	# Die Zahlen der eigenen DROMEs stehen in den Kacheln; hier nur, wer
	# gerade zieht und in welchem Zyklus.
	_status.text = "Am Zug: %s  ·  Zyklus %d" % [unit.display_name,
		battle.tick_bus.cycle_count]
	if not _auto:
		_status.text += "  ·  HP %d/%d  ·  EN %d/%d" % [unit.hp,
			unit.stat("hp_max"), unit.en, unit.stat("en_max")]
	if not _auto:
		_status.text += "\nMP %d  ·  Angriff %d  ·  Faehigkeit %d" % [state.move_points,
			state.attack_actions, state.actions_left(ActionData.Category.ABILITY)]
	if battle.in_overtime():
		_status.text += "\nOVERTIME: -%d je Zug" % battle.overtime_damage(unit)
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
		label.add_theme_font_size_override("font_size", UiKit.SMALL)
		var base := Color(0.55, 0.85, 1.0) if unit.is_player else Color(1.0, 0.55, 0.5)
		label.modulate = base if i > 0 else Color.WHITE
		if i == 0:
			label.add_theme_font_size_override("font_size", UiKit.BODY)
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
	if _auto or unit == null or not unit.is_player or battle.turn_state == null:
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


## Ein Aktionsknopf: das Symbol traegt die Aktion, die Zahlen darunter das,
## was sich nicht zeichnen laesst.
##
## Der Knopf trug vorher "Runenschlag   Angriff · Rw 1" als Fliesstext. Das ist
## im Kampf die falsche Form: der Spieler sucht dort nicht nach einem Namen,
## sondern nach einer Wirkung, und drei Woerter lesen sich langsamer als eine
## Silhouette. Der Name bleibt vollstaendig im Tooltip -- zusammen mit dem
## Bauteil, das die Aktion gibt.
##
## Reichweite und Energiekosten bleiben dagegen als ZAHL auf dem Knopf. Sie
## sind kein Klartext, sondern der Kern des Versprechens, dass sich jeder Zug
## vorher durchrechnen laesst; als Symbol waeren sie geraten.
const ACTION_ICON_SIZE := Vector2(46, 46)

func _action_button(action: ActionData) -> Button:
	var button := Button.new()
	var blocker := battle.turn_state.blocker_for(action)
	button.icon = ActionIcons.texture_for(action)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.custom_minimum_size = ACTION_ICON_SIZE + Vector2(18, 26)
	button.text = "Rw %d%s" % [action.range_tiles,
		"   EN %d" % action.en_cost if action.en_cost > 0 else ""]
	button.add_theme_font_size_override("font_size", 10)
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
	if unit == battle.active_unit:
		_follow_unit(unit)
	for other in battle.units:
		other.set_in_haze(
			battle.grid.terrain_class(other.tile) == Terrain.TClass.HAZE)
	_refresh_badges()


## Ein Treffer muss man sehen, nicht im Protokoll nachlesen.
##
## Der Kampf wuerfelt nicht: es gibt keinen Trefferwurf und kein Vorbeischiessen,
## und damit auch nichts, was von sich aus nach Einschlag aussieht. Ohne
## Rueckstoss, Erschuetterung und Kamerastoss aendert ein Angriff nur eine Zahl.
##
## Der Kamerastoss haengt am ANTEIL des Schadens, nicht an der Rohzahl: 20
## Schaden sind an einem Molok ein Kratzer und an einem Vireo ein Drittel seiner
## Integritaet. Ein Stoss, der beides gleich laut inszeniert, luegt ueber die
## Lage.
func _on_unit_damaged(unit: Unit, amount: int, source) -> void:
	if source is Unit and source != unit:
		source.play_attack(unit.tile)
	unit.play_hit()
	var maximum: int = maxi(1, unit.stat("hp_max"))
	_shake_camera(clampf(float(amount) / float(maximum), 0.0, 1.0))
	_refresh_badges()


func _on_unit_healed(unit: Unit, _amount: int, _source) -> void:
	unit.play_heal()
	_refresh_badges()


## Kurzer Kamerastoss, der von selbst zur Ruhe kommt. ``severity`` ist der
## Anteil der Maximalintegritaet, den der Treffer gekostet hat.
func _shake_camera(severity: float) -> void:
	if Accessibility.reduce_motion:
		return
	var strength := CAMERA_SHAKE_MAX * severity
	if strength < 0.6:
		return
	var home := camera.offset
	var tween := create_tween()
	var steps := 6
	for i in steps:
		var decay := 1.0 - float(i) / float(steps)
		tween.tween_property(camera, "offset",
			home + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
				* strength * decay,
			CAMERA_SHAKE_TIME / float(steps))
	tween.tween_property(camera, "offset", home, CAMERA_SHAKE_TIME / float(steps))


func _on_unit_died(unit: Unit) -> void:
	unit.visible = false
	_tick_bars.drop_unit(unit.unit_id)
	_action_ring.hide_ring()
	_refresh_tick_queue()
	_refresh_badges()


## Die Balken ueber den Figuren. Gefuellt wird hier, gezeichnet in der
## BattleView -- dieselbe Trennung wie bei der Schadensvorschau.
func _refresh_badges() -> void:
	var entries: Array = []
	var active := battle.active_unit
	for unit in battle.units:
		if not unit.is_alive():
			continue
		var tick := 0.0
		if battle.tick_bus != null:
			var state := battle.tick_bus.bar_state(unit.unit_id)
			tick = state.get("fill", 0.0) if not state.is_empty() else 0.0
		entries.append({
			"tile": unit.tile,
			"name": unit.display_name,
			"hp": unit.hp, "hp_max": unit.stat("hp_max"),
			"shield": unit.shield, "shield_max": unit.shield_max(),
			"en": unit.en, "en_max": unit.stat("en_max"),
			"tick": tick,
			"is_player": unit.is_player,
			"active": unit == active,
		})
		unit.set_active(unit == active)
	view.show_unit_badges(entries)
	if _squad_tiles != null:
		_squad_tiles.refresh(battle.units, active)


func _on_battle_over(outcome: BattleManager.Outcome) -> void:
	view.clear_overlays()
	view.clear_path_preview()
	view.clear_damage_preview()
	view.show_unit_badges([])
	_status.text = "%s nach %d Zyklen.  Seed: %d" % [
		BattleManager.outcome_label(outcome), battle.tick_bus.cycle_count,
		battle.battle_seed]
	_grant_loot(outcome)
	_show_result(outcome)


## Beute: nur bei SIEG und nur in einem echten Chaos-Lauf (chaos_reference_power
## gesetzt). Der Wuerfel haengt am Seed des Gefechts -- derselbe Kampf gibt
## dieselbe Beute, wie ueberall in diesem Projekt. Laeuft genau einmal, weil
## battle_over genau einmal feuert.
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
## Startzoom: das ganze Feld in der Breite. Danach uebernimmt das Folgen.
func _fit_camera() -> void:
	var visible := get_viewport().get_visible_rect().size
	var map := Vector2(battle.grid.width + battle.grid.height,
		battle.grid.width + battle.grid.height) * 0.5 \
		* Vector2(IsoView.TILE_W, IsoView.TILE_H)
	var zoom := clampf(minf(visible.x * 0.96 / map.x, visible.y * 0.6 / map.y),
		ZOOM_MIN, ZOOM_MAX)
	_set_zoom(zoom)


## Lesbarer Zoom fuers Folgen: rund neun Felder ueber die Breite.
func _follow_zoom() -> float:
	var visible := get_viewport().get_visible_rect().size
	return clampf(visible.x / (9.0 * IsoView.TILE_W), ZOOM_MIN, ZOOM_MAX)


func _set_zoom(zoom: float) -> void:
	zoom = clampf(zoom, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(zoom, zoom)
	view.set_pixel_scale(zoom)


func _follow_unit(unit: Unit) -> void:
	if not _follow or unit == null:
		return
	var target := IsoView.map_to_local(unit.tile) + Vector2(0, -40)
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	var zoom := maxf(camera.zoom.x, _follow_zoom())
	if Accessibility.reduce_motion:
		camera.position = target
		_set_zoom(zoom)
		return
	_camera_tween = create_tween().set_parallel(true)
	_camera_tween.tween_property(camera, "position", target, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_method(_set_zoom, camera.zoom.x, zoom, 0.45)


## Kachel angetippt: die Kamera faehrt zu diesem DROME. Das Folgen bleibt
## wie es ist -- beim naechsten Zug geht es dann wieder zum Aktiven.
func _look_at_unit(unit: Unit) -> void:
	if unit == null or not unit.is_alive():
		return
	var was := _follow
	_follow = true
	_follow_unit(unit)
	_follow = was


func _set_follow(on: bool) -> void:
	_follow = on
	if _follow_button != null:
		_follow_button.text = "Folgt" if on else "Folgen"
		_follow_button.modulate = UiKit.ACCENT if on else Color.WHITE
	if on:
		_follow_unit(battle.active_unit)


## Ziehen und Zoomen. Gibt true zurueck, wenn die Geste das Ereignis
## verbraucht hat -- dann geht es nicht als Klick auf ein Feld weiter.
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
			_stop_follow()
			_set_zoom(_pinch_zoom * distance / _pinch_distance)
			return true
		_drag_distance += event.relative.length()
		if _drag_distance > DRAG_THRESHOLD:
			_stop_follow()
			camera.position -= event.relative / camera.zoom
			return true
		return false
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_stop_follow()
			_set_zoom(camera.zoom.x * 1.1)
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_stop_follow()
			_set_zoom(camera.zoom.x / 1.1)
			return true
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		_stop_follow()
		camera.position -= event.relative / camera.zoom
		return true
	return false


func _stop_follow() -> void:
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	if _follow:
		_set_follow(false)


## Haengt ein Control an eine Ecke oder Kante (anchor in 0..1) mit Versatz.
## Rechts und unten verankert statt fest positioniert: auf der logischen
## Flaeche eines Handys (~1150 breit) stuende ein Knopf bei x = 1460 im Aus.
func _anchor(control: Control, anchor: Vector2, offset: Vector2) -> void:
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = offset.x
	control.offset_top = offset.y
	control.offset_right = offset.x
	control.offset_bottom = offset.y
	control.grow_horizontal = Control.GROW_DIRECTION_BEGIN if anchor.x >= 1.0 \
		else (Control.GROW_DIRECTION_BOTH if anchor.x > 0.0 else Control.GROW_DIRECTION_END)
	control.grow_vertical = Control.GROW_DIRECTION_BEGIN if anchor.y >= 1.0 \
		else (Control.GROW_DIRECTION_BOTH if anchor.y > 0.0 else Control.GROW_DIRECTION_END)


func _place_bottom(control: Control, x: float, above_bottom: float) -> void:
	control.anchor_left = 0.0
	control.anchor_right = 0.0
	control.anchor_top = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = x
	control.offset_right = x
	control.offset_top = -above_bottom
	control.offset_bottom = -above_bottom


## Der Aufbau, mobile first:
##
##   oben    Kopfleiste: Zugreihenfolge (waagrecht scrollbar) und Status
##   Mitte   die Karte -- Kamera folgt, Ziehen und Zoomen per Finger
##   unten   Daumenleiste: Tempo, Pause, Log, Reihenfolge, Folgen
##
## Log und Initiative-Balken sind einklappbare Paneele ueber der Daumenleiste:
## im Hochformat ist fuer feste Seitenleisten kein Platz, und die Karte ist
## das, was man ansehen will.
func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)

	var frame := VBoxContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_constant_override("separation", 0)
	root.add_child(frame)

	# --- Kopfleiste ------------------------------------------------------
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _bar_style(false))
	frame.add_child(top)
	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 4)
	top.add_child(top_box)
	var queue_scroll := ScrollContainer.new()
	queue_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	queue_scroll.custom_minimum_size = Vector2(0, 28)
	top_box.add_child(queue_scroll)
	_tick_queue = HBoxContainer.new()
	_tick_queue.add_theme_constant_override("separation", 12)
	queue_scroll.add_child(_tick_queue)
	_squad_tiles = SquadTiles.new()
	top_box.add_child(_squad_tiles)
	_status = UiKit.label("", UiKit.SMALL)
	top_box.add_child(_status)

	# --- Mitte: frei fuer die Karte --------------------------------------
	var middle := Control.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(middle)

	_tooltip = UiKit.label("", UiKit.SMALL, Color(0.8, 0.86, 0.95))
	_tooltip.position = Vector2(UiKit.PAD, 8)
	# Ohne Breite bricht ein Label mit Umbruch zeichenweise um (senkrechter Text).
	_tooltip.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(_tooltip)

	_mutator_banner = PanelContainer.new()
	_mutator_banner.add_theme_stylebox_override("panel", UiKit.card_style(true))
	_mutator_banner.anchor_left = 0.0
	_mutator_banner.anchor_right = 1.0
	_mutator_banner.anchor_top = 0.3
	_mutator_banner.anchor_bottom = 0.3
	_mutator_banner.offset_left = UiKit.PAD
	_mutator_banner.offset_right = -UiKit.PAD
	var banner_label := UiKit.label("", UiKit.H2)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mutator_banner.add_child(banner_label)
	_mutator_banner.visible = false
	middle.add_child(_mutator_banner)

	# --- Paneele ueber der Daumenleiste ----------------------------------
	_order_panel = PanelContainer.new()
	_order_panel.add_theme_stylebox_override("panel", _bar_style(true))
	_order_panel.visible = false
	frame.add_child(_order_panel)
	_tick_bars = TickBarPanel.new()
	_tick_bars.add_theme_constant_override("separation", 3)
	_order_panel.add_child(_tick_bars)

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

	# Manueller Zug: Aktionsleiste und "Zug beenden" (nur ausserhalb des
	# Autokampfs).
	var manual := VBoxContainer.new()
	manual.add_theme_constant_override("separation", 6)
	manual.visible = not _auto
	frame.add_child(manual)
	var action_scroll := ScrollContainer.new()
	action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	action_scroll.custom_minimum_size = Vector2(0, 70)
	manual.add_child(action_scroll)
	_action_bar = HBoxContainer.new()
	_action_bar.add_theme_constant_override("separation", 14)
	action_scroll.add_child(_action_bar)
	_end_turn = UiKit.button("Zug beenden")
	_end_turn.pressed.connect(func():
		if not _busy and not _paused:
			_end_current_turn())
	manual.add_child(_end_turn)

	# --- Daumenleiste ----------------------------------------------------
	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", _bar_style(false))
	frame.add_child(bottom)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	bottom.add_child(buttons)
	if _auto:
		_speed_button = _bar_button("Tempo 1x", _cycle_speed)
		buttons.add_child(_speed_button)
		_apply_speed()
	_pause_button = _bar_button("Pause", _toggle_pause)
	buttons.add_child(_pause_button)
	buttons.add_child(_bar_button("Log", func(): _toggle_panel(_log_panel)))
	buttons.add_child(_bar_button("Reihe", func(): _toggle_panel(_order_panel)))
	_follow_button = _bar_button("Folgt", func(): _set_follow(not _follow))
	_follow_button.modulate = UiKit.ACCENT
	buttons.add_child(_follow_button)

	_action_ring = ActionRing.new()
	_action_ring.action_chosen.connect(_on_ring_action)
	_action_ring.action_hovered.connect(_on_action_hovered)
	_ui.add_child(_action_ring)


func _bar_button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_font_size_override("font_size", UiKit.SMALL)
	button.pressed.connect(on_press)
	return button


func _toggle_panel(panel: Control) -> void:
	var show := not panel.visible
	_log_panel.visible = false
	_order_panel.visible = false
	panel.visible = show


func _bar_style(sheet: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.96 if sheet else 0.92)
	style.border_color = UiKit.CARD_LINE
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.content_margin_left = UiKit.PAD
	style.content_margin_right = UiKit.PAD
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _cycle_speed() -> void:
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	_apply_speed()


func _apply_speed() -> void:
	Engine.time_scale = SPEEDS[_speed_index]
	if _speed_button != null:
		_speed_button.text = "Tempo %dx" % int(SPEEDS[_speed_index])


## Das Tempo ist global (Engine.time_scale) und darf den Kampf nicht
## ueberleben -- sonst laeuft die Werkstatt danach doppelt so schnell.
func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _toggle_pause() -> void:
	_paused = not _paused
	if _pause_button != null:
		_pause_button.text = "Weiter" if _paused else "Pause"
	_status.text = "Pausiert." if _paused else _status.text


## Die Beute-Zeile im Ergebnis. Nur bei einem echten Chaos-Sieg; sonst
## schweigt sie. Bei Beute nennt sie die Teile, bei Duerre den Pity-Fortschritt
## -- damit man sieht, dass der garantierte Drop naeher rueckt.
func _add_loot_section(box: VBoxContainer, outcome: BattleManager.Outcome) -> void:
	if GameState.chaos_reference_power <= 0.0 and GameState.last_loot.is_empty():
		return
	if outcome != BattleManager.Outcome.VICTORY:
		return

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)

	var heading := Label.new()
	heading.add_theme_font_size_override("font_size", 18)
	if GameState.last_loot.is_empty():
		heading.text = "Keine Beute."
		heading.modulate = Color(0.7, 0.72, 0.78)
		box.add_child(heading)
		var threshold := int(Config.section("chaos").get("loot_pity_threshold", 4))
		var pity := Label.new()
		pity.text = "Pity: %d / %d bis zum garantierten Drop." % [
			GameState.chaos_pity, threshold]
		pity.add_theme_font_size_override("font_size", 12)
		pity.modulate = Color(0.6, 0.64, 0.7)
		box.add_child(pity)
		return

	heading.text = "Beute!"
	heading.modulate = Color(0.55, 0.9, 0.6)
	box.add_child(heading)
	for part_id in GameState.last_loot:
		var part := PartDB.get_part(part_id)
		var row := Label.new()
		row.text = "  + %s" % (part.display_name if part != null else str(part_id))
		row.modulate = Color(0.55, 0.9, 0.6)
		box.add_child(row)


func _show_result(outcome: BattleManager.Outcome) -> void:
	# Eine Karte ueber die volle Breite, mittig, scrollbar -- im Hochformat
	# passt eine feste 560er Tafel nicht hinein.
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
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, minf(560.0, get_viewport().get_visible_rect().size.y - 120.0))
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)

	var won := outcome == BattleManager.Outcome.VICTORY
	box.add_child(UiKit.label(BattleManager.outcome_label(outcome), UiKit.H1,
		UiKit.GOOD if won else (UiKit.BAD if outcome == BattleManager.Outcome.DEFEAT else UiKit.WARN)))

	var result := battle.build_result()
	box.add_child(UiKit.label("%d Zyklen  ·  %s  ·  %s" % [
		result["cycles"], result["region"], result["mutator"]], UiKit.SMALL, UiKit.MUTED))

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
		onward.pressed.connect(func():
			GameState.finish_run_battle(outcome, pool)
			get_tree().change_scene_to_file("res://scenes/run.tscn"))
		box.add_child(onward)
		onward.grab_focus.call_deferred()
		return

	var back := UiKit.button("Zum Hangar", true)
	back.pressed.connect(func():
		GameState.battle_seed = 0
		GameState.clear_chaos_run()
		get_tree().change_scene_to_file("res://scenes/hangar.tscn"))
	box.add_child(back)

	var menu := UiKit.button("Zur Startseite")
	menu.pressed.connect(func():
		GameState.battle_seed = 0
		GameState.clear_chaos_run()
		get_tree().change_scene_to_file("res://scenes/main.tscn"))
	# Stand hier ``box.add_child(back)`` -- derselbe Knopf ein zweites Mal.
	# Godot lehnt das ab ("already has a parent"), der Knopf ins Hauptmenue
	# tauchte nie auf, und vom Ergebnisbildschirm fuehrte nur ein Weg zurueck.
	box.add_child(menu)
