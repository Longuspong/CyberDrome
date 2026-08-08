class_name BattleManager
extends Node

## Der Kampfablauf: Aufbau, Zugreihenfolge, Siegbedingung.
##
## Haelt den Zustand und treibt die Schleife. Was der Spieler klickt, kommt
## von der Szene; was die KI tut, vom AIController. Beide reden ueber
## dieselben Methoden -- ein Zug ist ein Zug, egal wer ihn macht.

enum Outcome { RUNNING, VICTORY, DEFEAT, DRAW }

signal turn_ready(unit: Unit)
signal battle_over(outcome: Outcome)

var battle_seed: int = 0
var grid: Grid
var region: Terrain.Region
var mutator: Mutator
var resolver: ActionResolver
var tick_bus: TickBus

var units: Array = []
var active_unit: Unit = null
var turn_state: TurnState = null
var outcome: Outcome = Outcome.RUNNING

var _cycle_limit: int = 30


# ---------------------------------------------------------------------------
# Aufbau
# ---------------------------------------------------------------------------

func setup(seed_value: int, player_builds: Array) -> void:
	battle_seed = seed_value
	_cycle_limit = Config.get_int("cycle_limit", 30)

	var rng := RandomNumberGenerator.new()
	rng.seed = battle_seed

	region = TerrainDB.pick_region(rng)
	mutator = Mutator.draw(rng)
	grid = MapGenerator.new(battle_seed).generate(region, mutator.map_scales())

	var enemy_builds := EnemyGenerator.new(battle_seed).generate(
		player_builds.size(), DromeBuild.squad_power(player_builds))

	units.clear()
	_spawn(player_builds, true)
	_spawn(enemy_builds, false)

	tick_bus = TickBus.new()
	for unit in units:
		mutator.apply_to(unit)
		tick_bus.add_unit(unit.unit_id, unit.spd())

	resolver = ActionResolver.new(grid, units)
	outcome = Outcome.RUNNING

	EventBus.battle_started.emit(battle_seed)
	EventBus.log_line("Chaos-Virus startet. Region: %s. Mutator: %s."
		% [region.display_name, mutator.display_name])


func _spawn(builds: Array, is_player: bool) -> void:
	var zone := MapGenerator.deployment_zone(grid, is_player)
	var prefix := "P" if is_player else "E"
	var index := 0
	for build in builds:
		var unit := Unit.create(build, StringName("%s%d" % [prefix, index]), is_player)
		var tile := _free_deployment_tile(zone, unit)
		unit.place_at(tile)
		unit.set_facing("north" if is_player else "south")
		grid.set_occupant(tile, unit.unit_id)
		units.append(unit)
		index += 1


func _free_deployment_tile(zone: Array[Vector2i], unit: Unit) -> Vector2i:
	var profile := unit.move_profile()
	for tile in zone:
		if grid.can_stand_on(tile, profile):
			return tile
	# Sollte nicht vorkommen -- die Kartenvalidierung haelt die Zonen frei.
	for tile in grid.all_tiles():
		if grid.can_stand_on(tile, profile):
			push_warning("BattleManager: Aufstellungszone voll, weiche aus.")
			return tile
	return zone[0]


# ---------------------------------------------------------------------------
# Zugreihenfolge
# ---------------------------------------------------------------------------

## Ermittelt den naechsten Zieher und richtet seinen Zug ein.
func begin_next_turn() -> Unit:
	if outcome != Outcome.RUNNING:
		return null
	var next_id = tick_bus.advance()
	if next_id == null:
		return null

	active_unit = _unit_by_id(next_id)
	if active_unit == null or not active_unit.is_alive():
		return null

	# Energie, Statuseffekte, Provokation, Aderlass -- in dieser Reihenfolge.
	active_unit.regenerate()
	if active_unit.tick_statuses():
		_refresh_speeds()
	# Die Provokation laeuft in EIGENEN Zuegen ab und deshalb hier, zusammen mit
	# den Statuseffekten. Der Verfall der Aggro laeuft dagegen im Zyklus -- ein
	# Zug ist in diesem Spiel keine gleichmaessige Zeiteinheit (siehe
	# AggroTable.decay).
	active_unit.tick_taunt()
	var bleed := mutator.turn_damage()
	if bleed > 0:
		active_unit.hp = maxi(0, active_unit.hp - bleed)
		EventBus.log_line("%s verliert %d Integritaet (Aderlass)."
			% [active_unit.display_name, bleed])
		if active_unit.hp <= 0:
			_handle_death(active_unit)
			return null

	turn_state = TurnState.begin(active_unit)
	EventBus.turn_started.emit(active_unit)
	turn_ready.emit(active_unit)
	return active_unit


func end_turn() -> void:
	if active_unit == null:
		return
	var finished := active_unit
	var cycle_closed := tick_bus.finish_turn(finished.unit_id)
	EventBus.turn_ended.emit(finished)
	active_unit = null
	turn_state = null

	if cycle_closed:
		_decay_aggro()
		EventBus.cycle_ended.emit(tick_bus.cycle_count)
		if tick_bus.cycle_count > _cycle_limit:
			_finish(Outcome.DRAW)
			return
	_check_victory()


## Einmal je Zyklus verblassen alle Aggro-Eintraege ausser denen des jeweils
## aktuellen Ziels. Der Zyklus ist die einzige gleichmaessige Uhr im Kampf --
## ein Zug ist es nicht, weil SPD bestimmt, wie oft jemand drankommt.
func _decay_aggro() -> void:
	var section := Config.section("aggro")
	var rate := float(section.get("decay_rate", 0.15))
	var drop := float(section.get("decay_drop_below", 1.0))
	for unit in units:
		if unit.aggro != null:
			unit.aggro.decay(rate, drop)


## Statuseffekte koennen SPD veraendert haben. Der TICK-Bus muss das
## mitbekommen, sonst rechnet die Vorschau mit alten Werten.
func _refresh_speeds() -> void:
	for unit in units:
		tick_bus.set_spd(unit.unit_id, unit.spd())
	EventBus.tick_bus_changed.emit()


# ---------------------------------------------------------------------------
# Bewegung
# ---------------------------------------------------------------------------

## Alle Landefelder, die der aktive DROME noch erreichen kann.
func reachable_for_active() -> Dictionary:
	if active_unit == null or turn_state == null:
		return {}
	return grid.reachable_tiles(active_unit.move_profile(), turn_state.move_points)


## Bewegt den aktiven DROME auf ein Landefeld aus reachable_for_active().
func move_active_to(landing: Vector2i) -> bool:
	if active_unit == null or turn_state == null:
		return false
	var reachable := reachable_for_active()
	if not reachable.has(landing):
		return false

	var entry: Dictionary = reachable[landing]
	var spent: int = turn_state.move_points - int(entry["mp_left"])
	var path: Array = entry["path"]
	var step: Vector2i = path[-1]
	var entry_dir: Vector2i = step - (path[-2] if path.size() >= 2 else step)

	resolver.move_unit(active_unit, step, entry_dir)
	turn_state.spend_movement(spent)
	EventBus.budgets_changed.emit(active_unit)
	return true


## Zuruecknehmen, solange in diesem Zug noch keine Aktion lief.
func undo_movement() -> bool:
	if turn_state == null or not turn_state.can_undo_movement():
		return false
	grid.clear_occupant(active_unit.tile)
	active_unit.place_at(turn_state.start_tile)
	grid.set_occupant(turn_state.start_tile, active_unit.unit_id)
	active_unit.set_in_haze(
		grid.terrain_class(turn_state.start_tile) == Terrain.TClass.HAZE)
	turn_state.move_points = turn_state.start_move_points
	EventBus.budgets_changed.emit(active_unit)
	return true


# ---------------------------------------------------------------------------
# Aktionen
# ---------------------------------------------------------------------------

func use_action(tile: Vector2i, action: ActionData) -> bool:
	if active_unit == null or turn_state == null:
		return false
	if turn_state.blocker_for(action) != "":
		return false
	if not resolver.execute(active_unit, tile, action):
		return false
	turn_state.consume(action)
	_refresh_speeds()
	EventBus.budgets_changed.emit(active_unit)
	_check_victory()
	return true


# ---------------------------------------------------------------------------
# Zustand
# ---------------------------------------------------------------------------

func _unit_by_id(unit_id) -> Unit:
	for unit in units:
		if unit.unit_id == unit_id:
			return unit
	return null


func living(is_player: bool) -> Array:
	return units.filter(func(u): return u.is_alive() and u.is_player == is_player)


func enemies_of(unit: Unit) -> Array:
	return units.filter(func(u): return u.is_alive() and u.is_player != unit.is_player)


func allies_of(unit: Unit) -> Array:
	return units.filter(func(u): return u.is_alive() and u.is_player == unit.is_player)


func _handle_death(unit: Unit) -> void:
	grid.clear_occupant(unit.tile)
	resolver.forget_unit(unit)
	tick_bus.set_alive(unit.unit_id, false)
	EventBus.unit_died.emit(unit)
	_check_victory()


func _check_victory() -> void:
	if outcome != Outcome.RUNNING:
		return
	for unit in units:
		if not unit.is_alive():
			tick_bus.set_alive(unit.unit_id, false)
	if living(false).is_empty():
		_finish(Outcome.VICTORY)
	elif living(true).is_empty():
		_finish(Outcome.DEFEAT)


func _finish(result: Outcome) -> void:
	outcome = result
	active_unit = null
	turn_state = null
	GameState.last_result = build_result()
	EventBus.battle_finished.emit(result, tick_bus.cycle_count)
	battle_over.emit(result)


## Zusammenfassung fuer den Ergebnisbildschirm.
func build_result() -> Dictionary:
	var rows: Array = []
	for unit in units:
		rows.append({
			"name": unit.display_name,
			"is_player": unit.is_player,
			"alive": unit.is_alive(),
			"hp": unit.hp,
			"hp_max": unit.stat("hp_max"),
			"dealt": unit.damage_dealt,
			"taken": unit.damage_taken,
		})
	return {
		"outcome": outcome,
		"cycles": tick_bus.cycle_count,
		"seed": battle_seed,
		"region": region.display_name if region else "",
		"mutator": mutator.display_name if mutator else "",
		"units": rows,
	}


static func outcome_label(result: Outcome) -> String:
	match result:
		Outcome.VICTORY: return "Sieg"
		Outcome.DEFEAT: return "Niederlage"
		Outcome.DRAW: return "Unentschieden"
		_: return "laeuft"
