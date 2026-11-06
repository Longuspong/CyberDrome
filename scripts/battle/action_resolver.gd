class_name ActionResolver
extends RefCounted

## Fuehrt Aktionen aus und wendet Schaden und Effekte an.
##
## Schaden ist deterministisch:
##
##     schaden = max(1, waffe.power + angreifer.atk - ziel.def)
##
## Kein Trefferwurf, kein Krit, keine Ausweichchance: derselbe Seed ergibt
## denselben Kampf.

var grid: Grid
var units: Array = []

## Verzoegerte Wirkungen (Schockwelle nach dem Sog):
## { left: Sekunden, source: Unit, tile: Vector2i, action: ActionData }.
## Der BattleManager ruft advance() je Schritt.
var delayed: Array = []


func _init(battle_grid: Grid, all_units: Array) -> void:
	grid = battle_grid
	units = all_units


# ---------------------------------------------------------------------------
# Die Mitigationskette
# ---------------------------------------------------------------------------

## Die EINZIGE Stelle, an der Schaden angewendet wird.
##
## ``action`` dient der Aggro-Buchung (dem Koeffizienten der Aktion) und der
## Schadensart. Sie darf fehlen (Overtime).
func apply_damage(source: Unit, target: Unit, raw: int,
		action: ActionData = null) -> int:
	var frac := action.energy_fraction if action != null else 0.0
	var shield_before := target.shield
	var res := resolve_damage(target, raw, frac,
		action.shield_mult if action != null else 1.0)
	target.shield = res["shield_after"]
	var amount: int = res["hp"]

	target.hp = maxi(0, target.hp - amount)
	target.damage_taken += amount
	if source != null:
		source.damage_dealt += amount

	# Gebucht wird der GESAMTE angerichtete Schaden -- was ins Schild ging UND
	# was auf die HP kam. Sonst zoege ein Energiewaffentraeger, der ein Schild
	# knackt, keine Aufmerksamkeit, obwohl er dem Gegner spuerbar wehtut.
	# Flaechenschaden bucht pro getroffenem DROME, weil er hier pro Feld ankommt.
	var dealt := (shield_before - target.shield) + amount
	_book_aggro(target, source, float(dealt),
		action.aggro_coeff if action != null else 1.0)

	EventBus.unit_damaged.emit(target, amount, source)
	# Was der Schild geschluckt hat, steht mit im Log. Vorher hiess ein
	# Treffer auf den vollen Schild "fuer 0 Schaden" -- das las sich, als
	# waere nichts passiert, obwohl der Schild gerade halbiert wurde.
	var absorbed := shield_before - target.shield
	var who := source.display_name if source else "?"
	if absorbed > 0 and amount > 0:
		EventBus.log_line("%s trifft %s: Schild -%d, Integritaet -%d."
			% [who, target.display_name, absorbed, amount])
	elif absorbed > 0:
		EventBus.log_line("%s trifft %s: Schild -%d (Integritaet unversehrt)."
			% [who, target.display_name, absorbed])
	else:
		EventBus.log_line("%s trifft %s fuer %d Schaden."
			% [who, target.display_name, amount])

	_on_hit(source, dealt)
	if target.hp <= 0:
		_kill(target)
	return amount


## Passiven, die an einem Treffer haengen. Vireo (hit_rush): kurz schneller.
func _on_hit(source: Unit, dealt: int) -> void:
	if source == null or dealt <= 0 or not source.is_alive():
		return
	if source.passive() == "hit_rush":
		var rush := Config.section("passives").get("hit_rush", {}) as Dictionary
		source.apply_status(&"rush", float(rush.get("seconds", 2.0)),
			{"move_mult": float(rush.get("move_mult", 1.4))})


## Das Zwei-Verteidigungs-System (§11) als reine Rechnung -- was von ``raw`` auf
## HP und Schild ankommt, OHNE etwas zu veraendern. Gibt
## ``{"hp": int, "shield_after": int}`` zurueck.
##
## Vorschau (KI-Bewertung) UND Ausfuehrung rufen exakt diese Funktion.
##
## ### Das Modell
##
## Der Schaden teilt sich nach ``energy_fraction`` in einen physischen und einen
## Energie-Anteil. Solange das SCHILD steht, wird jeder Anteil mit seinem
## Schild-Faktor skaliert (physisch 0.8, Energie 1.2); der skalierte Schaden
## zehrt das Schild, und was darueber hinausgeht, laeuft in diesem skalierten
## Wert auf die HP durch. Daraus folgt genau das gewuenschte Verhalten:
##
##   * Man braucht MEHR als 50 physischen Schaden, um 50 Schild zu brechen
##     (100 * 0.8 = 80; erst 62.5 physisch reissen 50 Schild).
##   * Ein 100er-Treffer (physisch) auf 50 Schild + 50 HP laesst 20 HP: 80
##     skaliert, 50 ins Schild, 30 Ueberlauf auf die HP.
##   * Energie zerlegt Schilde (1.2) und stroemt darueber hinaus auf die HP.
##
## Trifft der Schaden direkt die HP (kein Schild mehr), gilt der HP-Faktor
## (beide 1.0). Zuletzt wirkt die PANZERUNG als effektive-HP-Multiplikator mit
## abnehmendem Ertrag, gedeckelt bei +50 % eHP -- so bringt selbst volle
## Panzerdurchdringung den Schaden nie ueber 100 %, nie darueber.
##
## Erst das Schild vollstaendig, dann die HP: das Schild wird immer zuerst leer.
func resolve_damage(target: Unit, raw: int, energy_fraction: float,
		shield_mult: float = 1.0) -> Dictionary:
	var section := Config.section("combat")
	# Verwundbar (Plasmaklinge): der Statuseffekt vergroessert jeden Treffer.
	raw = int(round(float(raw) * target.damage_taken_mult()))
	var e := int(round(float(raw) * clampf(energy_fraction, 0.0, 1.0)))
	var p := raw - e
	var shield := target.shield
	var to_hp := 0.0
	# Feste Reihenfolge physisch -> Energie, damit die Rechnung reproduzierbar
	# bleibt (bei gemischtem Schaden wie dem Puls-Blaster).
	var portions := [
		{"amt": p, "sf": float(section.get("physical_vs_shield", 0.8)),
			"hf": float(section.get("physical_vs_hp", 1.0))},
		{"amt": e, "sf": float(section.get("energy_vs_shield", 1.2)),
			"hf": float(section.get("energy_vs_hp", 1.0))},
	]
	for portion in portions:
		var amt: int = portion["amt"]
		if amt <= 0:
			continue
		if shield > 0:
			# shield_mult: Schildbrecher (Neon-Blaster) trifft den Schild doppelt.
			var eff := int(round(float(amt) * float(portion["sf"]) * shield_mult))
			if eff <= shield:
				shield -= eff
			else:
				to_hp += float(eff - shield)
				shield = 0
		else:
			to_hp += float(amt) * float(portion["hf"])
	return {"hp": _apply_armor_ehp(to_hp, target.def()), "shield_after": shield}


## Die Panzerung als effektive-HP-Multiplikator mit abnehmendem Ertrag,
## asymptotisch gedeckelt: ``m = 1 + cap * A/(A+K)`` erreicht ``1 + cap`` nie
## ganz, bleibt also immer unter +50 % eHP. Der ankommende HP-Schaden wird durch
## ``m`` geteilt. Ohne Panzerung (A=0) ist ``m = 1`` -- voller Schaden.
##
## ``pen`` (Panzerdurchdringung, 0..1, spaeter aus Loot/Faehigkeiten) senkt die
## wirksame Panzerung; bei 1.0 ist ``m = 1`` und der Schaden voll -- nie mehr.
func _apply_armor_ehp(raw_hp: float, armor: int, pen: float = 0.0) -> int:
	if raw_hp <= 0.0:
		return 0
	var section := Config.section("combat")
	var cap := float(section.get("armor_ehp_cap", 0.5))
	var k := maxf(0.001, float(section.get("armor_ehp_k", 15.0)))
	var a := float(maxi(0, armor)) * (1.0 - clampf(pen, 0.0, 1.0))
	var m := 1.0 + cap * a / (a + k)
	return maxi(1, int(round(raw_hp / m)))


## Duenner Vorschau-Zugang: nur der HP-Schaden. Fuer alte Aufrufer und Tests.
func mitigate(source: Unit, target: Unit, raw: int, energy_fraction: float = 0.0,
		shield_mult: float = 1.0) -> int:
	return resolve_damage(target, raw, energy_fraction, shield_mult)["hp"]


func _kill(unit: Unit) -> void:
	grid.clear_occupant(unit.tile)
	forget_unit(unit)
	EventBus.log_line("%s ist ausgefallen." % unit.display_name)
	EventBus.unit_died.emit(unit)
	unit.died.emit(unit)


# ---------------------------------------------------------------------------
# Aggro
# ---------------------------------------------------------------------------

## Ein DROME faellt aus: sein Eintrag verschwindet aus jeder Tabelle.
##
## Aggro ist begegnungslokal. Sie ueberlebt weder ein Ziel noch das Gefecht.
## Oeffentlich, weil es zwei Wege in den Tod gibt: die Mitigationskette hier
## und den Aderlass im BattleManager. Beide muessen hier durch.
func forget_unit(unit: Unit) -> void:
	for other in units:
		if other.aggro != null:
			other.aggro.forget(unit.unit_id)


## Die EINZIGE Stelle, an der Aggro gebucht wird.
##
## Dieselbe Regel wie bei apply_damage() und move_unit(): gaebe es eine zweite,
## waere jede kuenftige Schadensquelle eine Gelegenheit, die Buchung zu
## vergessen -- und der Fehler faellt erst auf, wenn ein Gegner sich
## unerklaerlich verhaelt.
##
## ``observer`` ist der DROME, dessen Tabelle waechst; ``actor`` der, der die
## Aufmerksamkeit auf sich zieht.
func _book_aggro(observer: Unit, actor: Unit, base: float, coeff: float) -> void:
	if observer == null or actor == null or observer.aggro == null:
		return
	if not observer.is_alive() or observer.is_player == actor.is_player:
		return
	observer.aggro.add(actor.unit_id, AggroTable.contribution(
		base, coeff, Grid.distance(actor.tile, observer.tile),
		actor.stat("aggro_bonus")))


# ---------------------------------------------------------------------------
# Vorhersage -- fuer die Bewertung der KI
# ---------------------------------------------------------------------------

## Was wuerde diese Aktion anrichten? Dieselbe Rechnung wie die Ausfuehrung,
## nur ohne sie anzuwenden. Eine Aktion ohne Wirkungsmenge liefert 0.
func preview_damage(source: Unit, target: Unit, action: ActionData) -> int:
	if action.power <= 0:
		return 0
	return mitigate(source, target, action.power + source.atk(), action.energy_fraction,
		action.shield_mult)


# ---------------------------------------------------------------------------
# Ziele
# ---------------------------------------------------------------------------

func unit_at(tile: Vector2i) -> Unit:
	for unit in units:
		if unit.is_alive() and unit.tile == tile:
			return unit
	return null


func unit_by_id(unit_id) -> Unit:
	if unit_id == null:
		return null
	for unit in units:
		if unit.unit_id == unit_id:
			return unit
	return null


## Die Felder, auf die der Dash den Handelnden versetzen kann: gerade Linie in
## eine der vier Richtungen, bis zu ``range_tiles`` weit, nicht durch einen
## anderen DROME hindurch.
func dash_landings(source: Unit, action: ActionData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dir in Grid.DIRS_4:
		var tile := source.tile
		for _step in action.range_tiles:
			tile += dir
			if not grid.in_bounds(tile):
				break
			if grid.is_occupied(tile, source.unit_id):
				break
			out.append(tile)
	return out


## Ist dieses Feld ein gueltiges Ziel? Leerer String = ja, sonst der Grund.
func target_blocker(source: Unit, tile: Vector2i, action: ActionData) -> String:
	if action.is_move():
		if tile == source.tile:
			return "Schon hier"
		if tile in dash_landings(source, action):
			return ""
		if source.tile.x != tile.x and source.tile.y != tile.y:
			return "Nur in gerader Linie"
		if Grid.distance(source.tile, tile) > action.range_tiles:
			return "Zu weit fuer den Boost"
		return "Weg blockiert"
	if Grid.distance(source.tile, tile) > action.range_tiles:
		return "Ausser Reichweite"
	if unit_at(tile) == null:
		return "Kein Ziel"
	return ""


## Ist dieses Ziel ueberhaupt gemeint? Angriffe treffen nur Gegner.
func is_meaningful_target(source: Unit, target: Unit, _action: ActionData) -> bool:
	if source == null or target == null or target == source:
		return false
	return target.is_player != source.is_player


## Welche Felder trifft die Aktion, wenn sie auf ``tile`` gezielt wird?
func affected_tiles(tile: Vector2i, action: ActionData) -> Array[Vector2i]:
	if action.aoe_radius <= 0:
		return [tile] as Array[Vector2i]
	var cross := action.targeting == ActionData.Targeting.AOE_CROSS
	var tiles: Array[Vector2i] = []
	for candidate in grid.all_tiles():
		if Grid.distance(tile, candidate) > action.aoe_radius:
			continue
		# Das Kreuz trifft nur orthogonal: die Diagonalen (x UND y verschoben)
		# fallen weg, das Ziel und die geraden Nachbarn bleiben.
		if cross and candidate.x != tile.x and candidate.y != tile.y:
			continue
		tiles.append(candidate)
	return tiles


# ---------------------------------------------------------------------------
# Ausfuehrung
# ---------------------------------------------------------------------------

## Fuehrt die Aktion aus. Gibt zurueck, ob sie ueberhaupt zulaessig war.
func execute(source: Unit, tile: Vector2i, action: ActionData) -> bool:
	if target_blocker(source, tile, action) != "":
		return false
	# Dash: der Handelnde versetzt sich selbst.
	if action.is_move():
		var delta := tile - source.tile
		var step := Vector2i(signi(delta.x), signi(delta.y))
		EventBus.log_line("%s boostet %d Feld(er) nach %s."
			% [source.display_name, Grid.distance(source.tile, tile), tile])
		move_unit(source, tile, step)
		return true

	if action.gather:
		_gather(source, tile, action)
	if action.delay > 0.0:
		delayed.append({"left": action.delay, "source": source, "tile": tile,
			"action": action})
		return true
	if action.shots > 1 and action.aoe_radius <= 0:
		_multi_shot(source, tile, action)
		return true
	_apply_area(source, tile, action)
	return true


## Mehrere schnelle Treffer: das Ziel zuerst, dann die naechsten Gegner in
## Reichweite; reichen die Gegner nicht, geht der Rest wieder aufs Ziel.
func _multi_shot(source: Unit, tile: Vector2i, action: ActionData) -> void:
	var primary := unit_at(tile)
	if primary == null:
		return
	var others: Array = []
	for unit in units:
		if unit == primary or not unit.is_alive() or unit.is_player == source.is_player:
			continue
		if Grid.distance(source.tile, unit.tile) <= action.range_tiles:
			others.append(unit)
	others.sort_custom(func(a, b):
		return Grid.distance(source.tile, a.tile) < Grid.distance(source.tile, b.tile))
	var targets: Array = [primary]
	for unit in others:
		if targets.size() >= action.shots:
			break
		targets.append(unit)
	while targets.size() < action.shots:
		targets.append(primary)
	for target in targets:
		if target.is_alive():
			apply_damage(source, target, action.power + source.atk(), action)


## Laesst verzoegerte Wirkungen ablaufen. Gibt zurueck, ob eine ausgeloest hat.
func advance(dt: float) -> bool:
	if delayed.is_empty():
		return false
	var fired := false
	var keep: Array = []
	for entry in delayed:
		entry["left"] = float(entry["left"]) - dt
		if float(entry["left"]) > 0.0:
			keep.append(entry)
			continue
		var source: Unit = entry["source"]
		var action: ActionData = entry["action"]
		EventBus.log_line("%s: %s schlaegt ein." % [source.display_name, action.display_name])
		_apply_area(source, entry["tile"], action)
		fired = true
	delayed = keep
	return fired


## Die Wirkung auf alle getroffenen Felder: Schaden, Stossen, Statuseffekt.
func _apply_area(source: Unit, tile: Vector2i, action: ActionData) -> void:
	for affected in affected_tiles(tile, action):
		var target := unit_at(affected)
		if target == null or not target.is_alive():
			continue
		# Die Flaeche trifft nur Gegner -- weder Verbuendete noch den Schuetzen.
		if not is_meaningful_target(source, target, action):
			continue
		if action.power > 0:
			apply_damage(source, target, action.power + source.atk(), action)
		elif action.aggro_flat > 0:
			# Wirkung ohne Schaden (Ziehen): ohne Pauschalwert waere sie lautlos.
			_book_aggro(target, source, float(action.aggro_flat), action.aggro_coeff)
		if action.push_tiles != 0 and target.is_alive():
			_shove(source, target, action.push_tiles)
		if not action.status.is_empty() and target.is_alive():
			target.apply_status(StringName(str(action.status.get("id", "status"))),
				float(action.status.get("seconds", 1.0)), action.status)


## Sog: die Gegner im Radius ruecken Feld fuer Feld zum Zielfeld, die
## naechsten zuerst, damit sie sich dicht an dicht packen. Wer blockiert ist,
## bleibt stehen.
func _gather(source: Unit, center: Vector2i, action: ActionData) -> void:
	var pulled: Array = []
	for unit in units:
		if not unit.is_alive() or unit.is_player == source.is_player:
			continue
		var gap := Grid.distance(unit.tile, center)
		if gap >= 2 and gap <= action.aoe_radius:
			pulled.append(unit)
	pulled.sort_custom(func(a, b):
		return Grid.distance(a.tile, center) < Grid.distance(b.tile, center))
	for unit in pulled:
		for _i in action.aoe_radius:
			if Grid.distance(unit.tile, center) <= 1:
				break
			var next := _step_toward(unit, center)
			if next == unit.tile:
				break
			move_unit(unit, next)
	if not pulled.is_empty():
		EventBus.log_line("%s zieht %d Gegner zusammen." % [source.display_name, pulled.size()])


## Ein Feld naeher an ``center``, wenn frei -- erst die laengere Achse.
func _step_toward(unit: Unit, center: Vector2i) -> Vector2i:
	var delta := center - unit.tile
	var steps: Array[Vector2i] = []
	if absi(delta.x) >= absi(delta.y):
		steps = [Vector2i(signi(delta.x), 0), Vector2i(0, signi(delta.y))]
	else:
		steps = [Vector2i(0, signi(delta.y)), Vector2i(signi(delta.x), 0)]
	for step in steps:
		if step == Vector2i.ZERO:
			continue
		var tile := unit.tile + step
		if grid.can_stand_on(tile, unit.unit_id):
			return tile
	return unit.tile


## Stossen und Ziehen. Positiv = weg, negativ = heran.
func _shove(source: Unit, target: Unit, tiles: int) -> void:
	var delta := target.tile - source.tile
	var step := Vector2i(signi(delta.x), signi(delta.y))
	if step.x != 0 and step.y != 0:
		# Ohne Diagonalen wird auf die dominante Achse gerundet.
		if absi(delta.x) >= absi(delta.y):
			step = Vector2i(signi(delta.x), 0)
		else:
			step = Vector2i(0, signi(delta.y))
	if step == Vector2i.ZERO:
		return
	if tiles < 0:
		step = -step

	var moved := 0
	for _i in absi(tiles):
		var nxt := target.tile + step
		if not grid.can_stand_on(nxt, target.unit_id):
			break
		move_unit(target, nxt)
		moved += 1
	if moved > 0:
		EventBus.log_line("%s wird %d Feld(er) %s."
			% [target.display_name, moved,
				"zurueckgestossen" if tiles > 0 else "herangezogen"])


## Die EINZIGE Stelle, an der die Position eines DROME gesetzt wird.
func move_unit(unit: Unit, to_tile: Vector2i, _entry_dir: Vector2i = Vector2i.ZERO) -> Vector2i:
	var from := unit.tile
	grid.clear_occupant(from)
	unit.place_at(to_tile)
	grid.set_occupant(to_tile, unit.unit_id)
	EventBus.unit_moved.emit(unit, from, to_tile)
	return to_tile
