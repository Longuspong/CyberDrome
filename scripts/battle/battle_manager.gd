class_name BattleManager
extends Node

## Der Kampfablauf in Echtzeit: Aufbau, Takt, Siegbedingung.
##
## Seit November 2026 handeln alle DROMEs GLEICHZEITIG. Es gibt keine Zuege
## mehr: jede Waffe laedt fuer sich nach (``ActionData.interval``), gelaufen
## wird Feld fuer Feld mit einer Geschwindigkeit aus SPD, Faehigkeiten loesen
## nach ihrer Regel selbst aus. Gesteuert wird jeder DROME vom AIController --
## auf beiden Seiten, der Spieler entscheidet nur Aufbau und Auswahl.
##
## Die Zeit laeuft in festen Schritten (``realtime.tick``, 0,05 s). Derselbe
## Seed ergibt damit exakt denselben Kampf, egal wie schnell der Bildschirm
## zeichnet -- die Szene ruft tick() so oft, wie Zeit vergangen ist, ein Test
## ruft es in einer Schleife.

enum Outcome { RUNNING, VICTORY, DEFEAT, DRAW }

signal battle_over(outcome: Outcome)

var battle_seed: int = 0
var grid: Grid
var region: Terrain.Region
var resolver: ActionResolver
var brain: AIController

var units: Array = []
var outcome: Outcome = Outcome.RUNNING

## Zufall fuer Gleichstaende in der KI (welcher von zwei gleich guten Wegen).
## Am Seed, damit der Kampf reproduzierbar bleibt -- aber eben Zufall und
## keine feste Richtung: eine feste Reihenfolge (erst Norden, dann Osten ...)
## bevorzugte die Seite, die zufaellig "nach Norden" laeuft.
var rng := RandomNumberGenerator.new()

## Vergangene Kampfzeit in Sekunden und die Zahl der Schritte dahin.
var time: float = 0.0
var ticks: int = 0

## Die Ausruestungs-Typen der Gegner dieses Gefechts -- der Beute-Pool des
## Chaos-Virus. Steht schon beim Aufbau fest und ueberlebt den Tod der Gegner,
## damit die Beute-Rechnung nach dem Sieg noch weiss, WAS zu erbeuten war.
var enemy_equipment: Array = []

## Overtime: ab ``overtime.start_seconds`` verliert jeder DROME je Puls einen
## wachsenden ANTEIL seiner maximalen Integritaet. Ohne das endeten
## Spiegelkaempfe KI gegen KI oft unentschieden -- im Autobattler, in dem man
## nur zusieht, das schlechteste denkbare Ende. Prozentual statt fest, damit
## ein dickes Chassis nicht ewig steht und ein duennes nicht sofort faellt.
var overtime_enabled: bool = true

var _dt: float = 0.05
var _pulse: float = 3.0
var _time_limit: float = 180.0

# ---------------------------------------------------------------------------
# Aufbau
# ---------------------------------------------------------------------------

## ``enemy_override``: feste Gegner statt gewuerfelter -- fuer Spiegel- und
## Fairness-Tests (dasselbe Squad auf beiden Seiten).
## ``region_id``: feste Region (Lauf: das Gebiet des Laufs). Leer = aus dem
## Seed gewuerfelt (Chaos-Virus, Tests).
func setup(seed_value: int, player_builds: Array, enemy_override: Array = [],
		region_id: StringName = &"") -> void:
	battle_seed = seed_value
	var realtime := Config.section("realtime")
	_dt = float(realtime.get("tick", 0.05))
	_pulse = maxf(0.5, float(realtime.get("pulse", 3.0)))
	_time_limit = float(realtime.get("time_limit", 180.0))
	time = 0.0
	ticks = 0

	var rng := RandomNumberGenerator.new()
	rng.seed = battle_seed

	region = _region_for(rng, region_id)
	grid = MapGenerator.generate(region)
	MapGenerator.place_obstacles(grid, battle_seed)

	# Der Gegner spiegelt normalerweise den eigenen Squad (Anzahl und Staerke).
	# Im Chaos-Virus entkoppeln GameState.chaos_* das: der Gegner tritt in voller
	# Staerke an (chaos_reference_power), unabhaengig davon, wie wenige DROMEs man
	# selbst mitnimmt -- genau das ist die Erschwernis, an der die Beute haengt.
	var enemy_count := player_builds.size()
	var target_power := DromeBuild.squad_power(player_builds)
	if GameState.chaos_enemy_count > 0:
		enemy_count = GameState.chaos_enemy_count
	if GameState.chaos_reference_power > 0.0:
		# Etwas schwaecher als die volle eigene Mannschaft: im Chaos-Virus sieht
		# man den Gegner vorher nicht (chaos.enemy_power_factor). Das Handicap und
		# damit die Beute rechnen weiter gegen die volle Referenz.
		target_power = GameState.chaos_reference_power \
			* float(Config.section("chaos").get("enemy_power_factor", 1.0))
	var enemy_builds: Array = enemy_override
	if enemy_builds.is_empty():
		enemy_builds = EnemyGenerator.new(battle_seed).generate(enemy_count, target_power)
	enemy_equipment = _distinct_equipment(enemy_builds)

	units.clear()
	_spawn(player_builds, true)
	_spawn(enemy_builds, false)

	# Die Pulse der DROMEs sind gegeneinander versetzt: liefen alle auf
	# denselben Schritt, regenerierten alle Schilde im selben Augenblick. Der
	# Versatz haengt an der Position INNERHALB der eigenen Seite -- der erste
	# Spieler-DROME und der erste Gegner teilen ihn. Ueber die ganze Liste
	# gezaehlt regenerierte die Spielerseite immer zuerst.
	for is_player in [true, false]:
		var side: Array = units.filter(func(u): return u.is_player == is_player)
		for i in side.size():
			side[i].init_realtime(_pulse * float(i) / float(maxi(1, side.size())))

	# Zufallsversatz der Takte (9. Nov. 2026, vom Spieler freigegeben): jeder
	# DROME laedt Waffen und Zeit-Faehigkeiten um 0..realtime.start_jitter s
	# spaeter. Ohne ihn loesten gleiche DROMEs auf beiden Seiten exakt im
	# selben Augenblick aus, und ein minimal schnellerer Takt entschied den
	# Spiegelkampf. Deterministisch je Seed.
	var jitter_rng := RandomNumberGenerator.new()
	jitter_rng.seed = battle_seed ^ 0x7A1C3
	var spread := float(Config.section("realtime").get("start_jitter", 0.0))
	for unit in units:
		var late := jitter_rng.randf() * spread
		for mount in unit.mounts:
			mount["ready"] = float(mount["ready"]) + late
		# Nur Zeit-Faehigkeiten -- Ereignisse (Hologramm) bleiben sofort bereit.
		for gadget in unit.gadgets:
			if (gadget["ability"] as ActionData).trigger_kind == "time":
				gadget["ready"] = float(gadget["ready"]) + late

	resolver = ActionResolver.new(grid, units)
	resolver.rng = self.rng
	# self: setup() hat eine lokale "rng" fuer Karte und Gegner.
	self.rng.seed = battle_seed ^ 0x5EED5
	brain = AIController.new(self)
	outcome = Outcome.RUNNING

	EventBus.battle_started.emit(battle_seed)
	EventBus.log_line("Kampf startet. Region: %s." % region.display_name)


## Die Region, die setup() mit diesem Seed ziehen wuerde -- fuer die
## Vorschau vor dem Kampf (Lauf). Dieselbe Reihenfolge der Zufallszuege wie
## oben; wer setup() umstellt, stellt hier mit um, sonst zeigt die Vorschau
## einen anderen Kampf als den, der dann kommt. tests/test_run.gd prueft das.
static func preview_conditions(seed_value: int, region_id: StringName = &"") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var preview_region := _region_for(rng, region_id)
	return {
		"seed": seed_value,
		"region": preview_region.display_name if preview_region else "",
	}



## Die feste Region, wenn eine Id gegeben und bekannt ist, sonst aus dem Seed.
## Der Zufallszug laeuft in beiden Faellen, damit die Folge danach gleich bleibt.
static func _region_for(rng: RandomNumberGenerator, region_id: StringName) -> Terrain.Region:
	var drawn := TerrainDB.pick_region(rng)
	if region_id != &"":
		var fixed := TerrainDB.get_region(region_id)
		if fixed != null:
			return fixed
		push_warning("BattleManager: unbekannte Region '%s', gewuerfelt" % region_id)
	return drawn

## Wie weit vorn eine Rolle in der Aufstellung steht: Frontlinie zuerst,
## Scharfschuetze zuletzt. Ohne eigenes Zutun des Spielers steht damit der
## Molok vorn und der Strix hinten -- auf beiden Seiten.
const FRONT_ORDER := {"vanguard": 0, "skirmisher": 1, "": 2, "controller": 3, "sniper": 4}


func _spawn(builds: Array, is_player: bool) -> void:
	var zone := deployment_tiles(is_player)
	var prefix := "P" if is_player else "E"
	var created: Array = []
	var index := 0
	for build in builds:
		created.append(Unit.create(build, StringName("%s%d" % [prefix, index]), is_player))
		index += 1
	# Die Reihenfolge der Aufstellung nach Rolle, stabil innerhalb einer Rolle.
	var ordered := created.duplicate()
	ordered.sort_custom(func(a, b):
		var ra: int = FRONT_ORDER.get(a.ai_role(), 2)
		var rb: int = FRONT_ORDER.get(b.ai_role(), 2)
		if ra != rb:
			return ra < rb
		return created.find(a) < created.find(b))
	for unit in ordered:
		var tile := _free_deployment_tile(zone, unit)
		unit.place_at(tile)
		unit.set_facing("north" if is_player else "south")
		grid.set_occupant(tile, unit.unit_id)
	# In der Einheitenliste bleibt die Reihenfolge des Squads.
	units.append_array(created)


## Die distinkten Ausruestungs-Typen einer Squad-Liste -- der Beute-Pool. Waffen
## UND Gadgets: was ein Gegner traegt, kann man ihm abnehmen.
func _distinct_equipment(builds: Array) -> Array:
	var seen := {}
	var ids: Array = []
	for build in builds:
		for part in build.equipment():
			if not seen.has(part.id):
				seen[part.id] = true
				ids.append(part.id)
	return ids


## Die Aufstellungszone einer Seite, vorderstes Feld zuerst (dem Gegner am
## naechsten).
func deployment_tiles(is_player: bool) -> Array[Vector2i]:
	var zone := MapGenerator.deployment_zone(grid, is_player)
	var foe_zone := MapGenerator.deployment_zone(grid, not is_player)
	var center := Vector2.ZERO
	for tile in foe_zone:
		center += Vector2(tile)
	center /= maxf(1.0, float(foe_zone.size()))
	var ranked := zone.duplicate()
	ranked.sort_custom(func(a: Vector2i, b: Vector2i):
		var da := Vector2(a).distance_to(center)
		var db := Vector2(b).distance_to(center)
		if not is_equal_approx(da, db):
			return da < db
		return zone.find(a) < zone.find(b))
	return ranked


## Aufstellung vor dem Kampf: einen eigenen DROME auf ein Feld der eigenen
## Zone setzen. Steht dort schon ein eigener, tauschen beide. Nur solange der
## Kampf noch nicht laeuft (time == 0). Gibt true zurueck, wenn sich etwas
## bewegt hat.
func place_unit(unit: Unit, tile: Vector2i) -> bool:
	if unit == null or time > 0.0 or tile == unit.tile:
		return false
	if not tile in deployment_tiles(unit.is_player):
		return false
	var other_id = grid.occupant(tile)
	var other: Unit = _unit_by_id(other_id) if other_id != null else null
	if other != null and other.is_player != unit.is_player:
		return false
	var from := unit.tile
	grid.clear_occupant(from)
	if other != null:
		grid.clear_occupant(tile)
		other.place_at(from)
		grid.set_occupant(from, other.unit_id)
	unit.place_at(tile)
	grid.set_occupant(tile, unit.unit_id)
	return true


## Die aktuelle Aufstellung einer Seite als Liste von Feldern in Squad-
## Reihenfolge -- zum Merken fuer den naechsten Kampf.
func formation(is_player: bool) -> Array:
	var out: Array = []
	for unit in units:
		if unit.is_player == is_player:
			out.append(unit.tile)
	return out


## Eine gemerkte Aufstellung wiederherstellen. Felder ausserhalb der Zone oder
## doppelte werden uebersprungen.
func apply_formation(tiles: Array) -> void:
	var own: Array = units.filter(func(u): return u.is_player)
	for i in mini(own.size(), tiles.size()):
		var tile = tiles[i]
		if tile is Vector2i:
			place_unit(own[i], tile)


func _free_deployment_tile(zone: Array[Vector2i], unit: Unit) -> Vector2i:
	for tile in zone:
		if grid.can_stand_on(tile, unit.unit_id):
			return tile
	# Sollte nicht vorkommen -- die Zone hat Platz fuer zwoelf.
	for tile in grid.all_tiles():
		if grid.can_stand_on(tile, unit.unit_id):
			push_warning("BattleManager: Aufstellungszone voll, weiche aus.")
			return tile
	return zone[0]


# ---------------------------------------------------------------------------
# Takt
# ---------------------------------------------------------------------------

## Ein Simulationsschritt. Jeder lebende DROME handelt einmal (laufen,
## nachladen, schiessen), dann laufen Pulse und Zeitgrenze.
##
## Die Reihenfolge, in der die DROMEs innerhalb eines Schritts drankommen,
## wird jeden Schritt neu gemischt (Zufall am Seed). Sie ist nicht egal: wer
## im selben Schritt als Zweiter handelt, sieht den Gegner, der eben in
## Reichweite gelaufen ist, und schiesst sofort. Eine feste Reihenfolge --
## auch eine reihum wandernde -- traf bei gleichen Laufzeiten immer dieselbe
## Seite; Spiegelkaempfe gingen 38 zu 2 aus.
func tick() -> void:
	if outcome != Outcome.RUNNING:
		return
	time += _dt
	ticks += 1
	var order := units.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = order[i]
		order[i] = order[j]
		order[j] = swap
	for unit in order:
		if not unit.is_alive():
			continue
		unit.tick_statuses(_dt)
		unit.recharge_shield(_dt)
		unit.track_stillness(_dt)
		brain.update(unit, _dt)
		if outcome != Outcome.RUNNING:
			return
		unit.pulse_left -= _dt
		if unit.pulse_left <= 0.0:
			unit.pulse_left += _pulse
			_pulse_unit(unit)
			if outcome != Outcome.RUNNING:
				return

	if resolver.advance(_dt):
		_check_victory()
		if outcome != Outcome.RUNNING:
			return


	if time >= _time_limit:
		_finish(Outcome.DRAW)
		return
	_check_victory()


## Spielt den Kampf ohne Bildschirm zu Ende -- fuer Tests und Playtest.
func run_to_end(max_seconds: float = -1.0) -> Outcome:
	var limit := _time_limit if max_seconds <= 0.0 else max_seconds
	while outcome == Outcome.RUNNING and time < limit:
		tick()
	return outcome


func step_seconds() -> float:
	return _dt


func pulse_seconds() -> float:
	return _pulse


## Was je Puls laeuft: Reparatur, Overtime. Der Schild laedt nicht mehr je
## Puls, sondern nach Ruhe (Unit.recharge_shield, jeden Schritt).
func _pulse_unit(unit: Unit) -> void:
	var healed := unit.regenerate_hp()
	if healed > 0:
		EventBus.unit_healed.emit(unit, healed, unit)
		EventBus.log_line("%s regeneriert %d Integritaet (Reparatur)."
			% [unit.display_name, healed])
	var collapse := overtime_damage(unit)
	if collapse > 0:
		unit.hp = maxi(0, unit.hp - collapse)
		EventBus.log_line("%s verliert %d Integritaet (Overtime)."
			% [unit.display_name, collapse])
		EventBus.unit_damaged.emit(unit, collapse, null)
		if unit.hp <= 0:
			_handle_death(unit)


## Overtime-Schaden je Puls fuer diesen DROME. 0 vor dem Start oder wenn
## Overtime aus ist. Waechst je Puls um ``pct_per_cycle`` der maximalen
## Integritaet, aufgerundet.
func overtime_damage(unit: Unit) -> int:
	if not overtime_enabled or unit == null:
		return 0
	var section := Config.section("overtime")
	var start := float(section.get("start_seconds", 60.0))
	if time < start:
		return 0
	var past := int(floor((time - start) / _pulse)) + 1
	var pct := float(section.get("pct_per_cycle", 0.05))
	return int(ceil(float(unit.stat("hp_max")) * pct * float(past)))


## Laeuft die Overtime schon? Fuer die Anzeige.
func in_overtime() -> bool:
	return overtime_enabled \
		and time >= float(Config.section("overtime").get("start_seconds", 60.0))


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
	EventBus.unit_died.emit(unit)
	_check_victory()


func _check_victory() -> void:
	if outcome != Outcome.RUNNING:
		return
	if living(false).is_empty():
		_finish(Outcome.VICTORY)
	elif living(true).is_empty():
		_finish(Outcome.DEFEAT)


func _finish(result: Outcome) -> void:
	outcome = result
	GameState.last_result = build_result()
	EventBus.battle_finished.emit(result, int(time))
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
		"seconds": int(round(time)),
		"seed": battle_seed,
		"region": region.display_name if region else "",
		"units": rows,
	}


static func outcome_label(result: Outcome) -> String:
	match result:
		Outcome.VICTORY: return "Sieg"
		Outcome.DEFEAT: return "Niederlage"
		Outcome.DRAW: return "Unentschieden"
		_: return "laeuft"
