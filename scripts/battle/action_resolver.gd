class_name ActionResolver
extends RefCounted

## Fuehrt Aktionen aus und wendet Schaden und Effekte an.
##
## Schaden ist deterministisch:
##
##     schaden = max(1, waffe.power + angreifer.atk - ziel.def)
##
## Kein Trefferwurf, kein Krit, keine Ausweichchance -- weder im MVP noch
## spaeter. Das ist eine bewusste Designentscheidung: Balancing laeuft ueber
## das WIE (Positionierung, Reihenfolge, Ressourceneinsatz), nicht ueber das
## OB. Der Spieler soll jede Aktion vorher exakt durchrechnen koennen.

var grid: Grid
var units: Array = []


func _init(battle_grid: Grid, all_units: Array) -> void:
	grid = battle_grid
	units = all_units


# ---------------------------------------------------------------------------
# Die Mitigationskette
# ---------------------------------------------------------------------------

## Die EINZIGE Stelle, an der Schaden angewendet wird.
##
## Die Kette ist geordnet und hat vier Glieder. Schritt 1 und 2 sind im MVP
## leere Durchreichungen -- wichtig ist nur, dass es sie als Kettenglieder
## GIBT, damit Energieschild und Ruestung spaeter ohne Umbau eingehaengt
## werden koennen.
func apply_damage(source: Unit, target: Unit, raw: int) -> int:
	var amount := raw

	amount = _absorb_shield(source, target, amount)      # 1. Post-MVP
	amount = _apply_armor(source, target, amount)        # 2. Post-MVP
	amount = amount - target.def()                       # 3. DEF flach abziehen
	amount = maxi(1, amount)                             # 4. Mindestens 1

	target.hp = maxi(0, target.hp - amount)
	target.damage_taken += amount
	if source != null:
		source.damage_dealt += amount

	EventBus.unit_damaged.emit(target, amount, source)
	EventBus.log_line("%s trifft %s fuer %d Schaden."
		% [source.display_name if source else "?", target.display_name, amount])

	if target.hp <= 0:
		_kill(target)
	return amount


## Post-MVP: Energieschild absorbiert. Der Haken existiert, damit ein Schild
## spaeter genau hier eingehaengt wird und nicht an fuenf Stellen im Code.
func _absorb_shield(_source: Unit, _target: Unit, amount: int) -> int:
	return amount


## Post-MVP: Ruestung und Schadenstypen. Im MVP neutral.
func _apply_armor(_source: Unit, _target: Unit, amount: int) -> int:
	return amount


func heal(source: Unit, target: Unit, amount: int) -> int:
	var before := target.hp
	target.hp = mini(target.stat("hp_max"), target.hp + amount)
	var healed := target.hp - before
	if healed > 0:
		EventBus.unit_healed.emit(target, healed, source)
		EventBus.log_line("%s repariert %s um %d Integritaet."
			% [source.display_name if source else "?", target.display_name, healed])
	return healed


func _kill(unit: Unit) -> void:
	grid.clear_occupant(unit.tile)
	EventBus.log_line("%s ist ausgefallen." % unit.display_name)
	EventBus.unit_died.emit(unit)
	unit.died.emit(unit)


# ---------------------------------------------------------------------------
# Vorhersage -- damit der Spieler rechnen kann, bevor er klickt
# ---------------------------------------------------------------------------

## Was wuerde diese Aktion anrichten? Benutzt exakt dieselbe Rechnung wie die
## Ausfuehrung, nur ohne sie anzuwenden.
func preview_damage(source: Unit, target: Unit, action: ActionData) -> int:
	if action.is_heal():
		var missing := target.stat("hp_max") - target.hp
		return -mini(action.heal_amount(), missing)
	var raw := action.power + source.atk()
	return maxi(1, _apply_armor(source, target,
		_absorb_shield(source, target, raw)) - target.def())


# ---------------------------------------------------------------------------
# Ziele
# ---------------------------------------------------------------------------

func unit_at(tile: Vector2i) -> Unit:
	for unit in units:
		if unit.is_alive() and unit.tile == tile:
			return unit
	return null


## Alle Felder in Reichweite der Aktion -- unabhaengig davon, ob dort etwas
## Sinnvolles steht. Die Sichtlinie entscheidet erst danach.
func tiles_in_range(source: Unit, action: ActionData) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if action.targeting == ActionData.Targeting.SELF:
		tiles.append(source.tile)
		return tiles
	for tile in grid.all_tiles():
		if Grid.distance(source.tile, tile) <= action.range_tiles:
			tiles.append(tile)
	return tiles


## Ist dieses Feld ein gueltiges Ziel? Leerer String = ja, sonst der Grund.
##
## Der Grund wandert unveraendert in den Tooltip: "Sicht durch Betonpfeiler
## blockiert". Ein graues Feld ohne Begruendung ist im Taktikspiel wertlos.
func target_blocker(source: Unit, tile: Vector2i, action: ActionData) -> String:
	if action.targeting == ActionData.Targeting.SELF:
		return "" if tile == source.tile else "Nur auf sich selbst"
	if Grid.distance(source.tile, tile) > action.range_tiles:
		return "Ausser Reichweite"
	if action.requires_line_of_sight:
		var blocker := grid.sight_blocker(source.tile, tile,
			source.sees_through_haze())
		if blocker != "":
			return "Sicht durch %s blockiert" % blocker
	if action.targeting == ActionData.Targeting.TILE:
		return "" if grid.can_stand_on(tile, source.move_profile()) \
			else "Feld nicht betretbar"
	if unit_at(tile) == null:
		return "Kein Ziel"
	return ""


## Welche Felder trifft die Aktion, wenn sie auf ``tile`` gezielt wird?
func affected_tiles(tile: Vector2i, action: ActionData) -> Array[Vector2i]:
	if action.aoe_radius <= 0:
		return [tile] as Array[Vector2i]
	var tiles: Array[Vector2i] = []
	for candidate in grid.all_tiles():
		if Grid.distance(tile, candidate) <= action.aoe_radius:
			tiles.append(candidate)
	return tiles


# ---------------------------------------------------------------------------
# Ausfuehrung
# ---------------------------------------------------------------------------

## Fuehrt die Aktion aus. Gibt zurueck, ob sie ueberhaupt zulaessig war.
func execute(source: Unit, tile: Vector2i, action: ActionData) -> bool:
	if target_blocker(source, tile, action) != "":
		return false
	if not source.can_afford(action):
		return false

	source.spend_energy(action.en_cost)

	for affected in affected_tiles(tile, action):
		var target := unit_at(affected)
		if target == null:
			continue
		if action.is_heal():
			heal(source, target, action.heal_amount())
		elif action.power > 0:
			apply_damage(source, target, action.power + source.atk())
		if action.push_tiles != 0 and target != source:
			_shove(source, target, action.push_tiles)
		if action.status_effect != null:
			_apply_status(target, action.status_effect)

	if action.targeting == ActionData.Targeting.SELF:
		_apply_self_effects(source, action)

	EventBus.tick_bus_changed.emit()
	return true


## Stossen und Ziehen. Positiv = weg, negativ = heran.
##
## Beides laeuft ueber move_unit() und damit durch simulate_drift(): wer per
## Stossfeld auf eine Oelspur geschoben wird, gleitet weiter. Das ist keine
## Sonderregel, sondern faellt automatisch heraus.
func _shove(source: Unit, target: Unit, tiles: int) -> void:
	var delta := target.tile - source.tile
	var step := Vector2i(signi(delta.x), signi(delta.y))
	if Grid.ALLOW_DIAGONALS == false and step.x != 0 and step.y != 0:
		# Ohne Diagonalen wird auf die dominante Achse gerundet.
		if absi(delta.x) >= absi(delta.y):
			step = Vector2i(signi(delta.x), 0)
		else:
			step = Vector2i(0, signi(delta.y))
	if step == Vector2i.ZERO:
		return
	if tiles < 0:
		step = -step

	var profile := target.move_profile()
	var moved := 0
	for _i in absi(tiles):
		var nxt := target.tile + step
		if not grid.can_stand_on(nxt, profile):
			break
		move_unit(target, nxt, step)
		profile.tile = target.tile
		moved += 1
	if moved > 0:
		EventBus.log_line("%s wird %d Feld(er) %s."
			% [target.display_name, moved,
				"zurueckgestossen" if tiles > 0 else "herangezogen"])


## Die EINZIGE Stelle, an der die Position eines DROME gesetzt wird.
##
## Jede Positionsaenderung laeuft hier durch und wertet am Ende das Gleiten
## aus. Gaebe es eine zweite Stelle, waere Push-auf-Drift eine Sonderregel --
## und irgendwann eine, die jemand vergisst.
func move_unit(unit: Unit, to_tile: Vector2i, entry_dir: Vector2i) -> Vector2i:
	var from := unit.tile
	grid.clear_occupant(from)

	var landing := grid.simulate_drift(to_tile, entry_dir, unit.move_profile())
	unit.place_at(landing)
	grid.set_occupant(landing, unit.unit_id)
	unit.set_in_haze(grid.terrain_class(landing) == Terrain.TClass.HAZE)

	if landing != to_tile:
		EventBus.log_line("%s gleitet von %s nach %s."
			% [unit.display_name, to_tile, landing])
	EventBus.unit_moved.emit(unit, from, landing)
	return landing


func _apply_status(target: Unit, status) -> void:
	if not status is Dictionary:
		return
	target.apply_status(StringName(status.get("id", "status")),
		int(status.get("cycles", 1)), status)


func _apply_self_effects(source: Unit, action: ActionData) -> void:
	if action.is_heal():
		heal(source, source, action.heal_amount())
