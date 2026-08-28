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
##
## ``action`` dient allein der Aggro-Buchung (dem Koeffizienten der Aktion).
## Sie darf fehlen: Schaden ohne Aktion -- Aderlass, spaeter Schaden ueber
## Zeit -- bucht dann mit dem Grundkoeffizienten 1.0.
func apply_damage(source: Unit, target: Unit, raw: int,
		action: ActionData = null) -> int:
	var frac := action.energy_fraction if action != null else 0.0
	var shield_before := target.shield
	var res := resolve_damage(target, raw, frac)
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
	EventBus.log_line("%s trifft %s fuer %d Schaden."
		% [source.display_name if source else "?", target.display_name, amount])

	if target.hp <= 0:
		_kill(target)
	return amount


## Das Zwei-Verteidigungs-System (§11) als reine Rechnung -- was von ``raw`` auf
## HP und Schild ankommt, OHNE etwas zu veraendern. Gibt
## ``{"hp": int, "shield_after": int}`` zurueck.
##
## Vorschau UND Ausfuehrung rufen exakt diese Funktion, aus demselben Grund wie
## frueher: eine zweite, "vereinfachte" Rechnung ist die Stelle, an der das
## Versprechen bricht, dass sich jeder Zug vorher durchrechnen laesst.
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
func resolve_damage(target: Unit, raw: int, energy_fraction: float) -> Dictionary:
	var section := Config.section("combat")
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
			var eff := int(round(float(amt) * float(portion["sf"])))
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
func mitigate(source: Unit, target: Unit, raw: int, energy_fraction: float = 0.0) -> int:
	return resolve_damage(target, raw, energy_fraction)["hp"]


func heal(source: Unit, target: Unit, amount: int, action: ActionData = null) -> int:
	var before := target.hp
	target.hp = mini(target.stat("hp_max"), target.hp + amount)
	var healed := target.hp - before
	if healed > 0:
		# Gegen ALLE Gegner des Geheilten, nicht nur gegen den, der ihn
		# angeschlagen hat. Sonst waere der Techniker genau in dem Moment
		# unangreifbar, in dem er am wertvollsten ist.
		#
		# Und: die TATSAECHLICH geheilte Menge, nicht die nominelle. Deshalb
		# steht die Buchung hier unten und nicht oben -- Heilen auf Vollleben
		# waere sonst eine Gratis-Aggro-Maschine.
		for observer in units:
			if observer.is_player != target.is_player:
				_book_aggro(observer, source, float(healed),
					action.aggro_coeff if action != null else 1.0)
		EventBus.unit_healed.emit(target, healed, source)
		EventBus.log_line("%s repariert %s um %d Integritaet."
			% [source.display_name if source else "?", target.display_name, healed])
	return healed


func _kill(unit: Unit) -> void:
	grid.clear_occupant(unit.tile)
	forget_unit(unit)
	EventBus.log_line("%s ist ausgefallen." % unit.display_name)
	EventBus.unit_died.emit(unit)
	unit.died.emit(unit)


# ---------------------------------------------------------------------------
# Aggro
# ---------------------------------------------------------------------------

## Ein DROME faellt aus: sein Eintrag verschwindet aus jeder Tabelle, und wen
## er provoziert hatte, ist wieder frei -- sonst stuende der Provozierte
## untaetig herum und wartete auf ein Ziel, das es nicht mehr gibt.
##
## Aggro ist begegnungslokal. Sie ueberlebt weder ein Ziel noch das Gefecht.
## Oeffentlich, weil es zwei Wege in den Tod gibt: die Mitigationskette hier
## und den Aderlass im BattleManager. Beide muessen hier durch.
func forget_unit(unit: Unit) -> void:
	for other in units:
		if other.aggro != null:
			other.aggro.forget(unit.unit_id)
		if other.taunted_by() == unit.unit_id:
			other.clear_taunt()


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
	# Gebucht wird auch gegen einen actor, den der observer gerade gar nicht
	# anvisieren KANN -- etwa weil er in einem Haze-Feld steht. Gefiltert wird
	# ausschliesslich bei der Zielwahl. Sonst waere Haze ein Aggro-Reset und
	# aus der Deckung zu schiessen kostenlos.
	observer.aggro.add(actor.unit_id, AggroTable.contribution(
		base, coeff, Grid.distance(actor.tile, observer.tile),
		actor.stat("aggro_bonus")))


## Provokation: harter Zwang beim Ziel plus ein Eintrag in dessen Tabelle.
##
## Der neue Wert leitet sich vom Tabellenmaximum ab und wird NICHT addiert.
## Zweimal hintereinander provozieren bringt dadurch praktisch nichts -- man
## ist ja bereits das Maximum. Eine flache Addition wuerde durch Wiederholung
## zur dauerhaften Aggro-Sperre und die Tabelle entwerten.
##
## Nach Ablauf steht die Quelle knapp vorn, aber nicht uneinholbar: das Gefecht
## kippt zurueck ins normale Tabellenmodell, statt hart umzuschalten.
func _apply_taunt(source: Unit, target: Unit, action: ActionData) -> void:
	target.apply_taunt(source.unit_id, action.taunt_turns)
	if target.aggro != null:
		var factor := float(Config.section("aggro").get("taunt_factor", 1.1))
		target.aggro.entries[source.unit_id] = maxf(
			target.aggro.value_of(source.unit_id),
			target.aggro.peak_excluding(source.unit_id) * factor)
	EventBus.log_line("%s provoziert %s fuer %d Zuege."
		% [source.display_name, target.display_name, action.taunt_turns])


# ---------------------------------------------------------------------------
# Vorhersage -- damit der Spieler rechnen kann, bevor er klickt
# ---------------------------------------------------------------------------

## Was wuerde diese Aktion anrichten? Benutzt exakt dieselbe Rechnung wie die
## Ausfuehrung, nur ohne sie anzuwenden -- dieselbe Funktion, nicht dieselbe
## Formel zweimal aufgeschrieben.
##
## Eine Aktion OHNE Wirkungsmenge liefert 0 und nicht die Mindestmenge 1. Das
## ist dieselbe Bedingung, unter der execute() ueberhaupt Schaden anwendet
## (``action.power > 0``) -- der Orbit-Sog zieht sein Ziel zwei Felder, richtet
## aber nichts an. Ohne diese Zeile rechnete die Vorschau ``max(1, 0 + atk -
## def)`` und schrieb "1 Schaden" ueber ein Ziel, dem nichts passiert. Die KI
## hatte genau diese Falle schon umgangen, indem sie vorher abbog
## (AIController._action_score); die Anzeige lief weiter hinein.
func preview_damage(source: Unit, target: Unit, action: ActionData) -> int:
	if action.is_heal():
		var missing := target.stat("hp_max") - target.hp
		return -mini(action.heal_amount(), missing)
	if action.power <= 0:
		return 0
	return mitigate(source, target, action.power + source.atk(), action.energy_fraction)


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

	# Provokation. Steht bewusst HIER und nicht in der KI: sie ist eine Regel
	# ueber gueltige Ziele, keine Vorliebe. Damit gilt sie fuer beide Seiten --
	# die KI fragt diese Funktion in _targets_from(), und beim Spieler faerbt
	# sich das Feld grau und der Grund steht im Tooltip. Eine zweite
	# Durchsetzung in der KI waere eine zweite Regel.
	if action.is_attack() and source.is_taunted():
		var forcer := unit_by_id(source.taunted_by())
		if forcer != null and forcer.is_alive() and tile != forcer.tile:
			return "Von %s provoziert" % forcer.display_name

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


## Ist dieses Ziel ueberhaupt gemeint?
##
## Regeltechnisch darf ein Angriff auf den eigenen DROME gehen und eine
## Reparatur auf den Gegner -- die Mitigationskette fragt nicht nach Seiten.
## Angeboten wird beides trotzdem nicht: es waere nie das, was der Spieler
## meint, und in einer Schadensvorschau ueber dem eigenen Techniker steht sonst
## eine Zahl, die wie eine Drohung aussieht.
##
## Steht hier und nicht in der UI, weil Aktionsring und Schadensvorschau
## dieselbe Antwort brauchen. Zwei Kopien waeren zwei Gelegenheiten, dass der
## Ring eine Aktion anbietet, deren Zahl daneben fehlt.
func is_meaningful_target(source: Unit, target: Unit, action: ActionData) -> bool:
	if source == null or target == null:
		return false
	if target == source:
		return action.is_heal() or action.targeting == ActionData.Targeting.SELF
	var friendly := target.is_player == source.is_player
	return action.is_heal() == friendly


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
##
## EINE Schleife ueber die getroffenen Felder, auch fuer ``Targeting.SELF``:
## ``affected_tiles()`` liefert dort das eigene Feld, darauf steht der Handelnde,
## und ``is_meaningful_target()`` laesst ihn ausdruecklich durch. Ein zweiter
## Zweig hinter der Schleife -- den es hier einmal gab -- wendete die Wirkung ein
## zweites Mal an und haette die erste SELF-Aktion des Bestands still verdoppelt.
func execute(source: Unit, tile: Vector2i, action: ActionData) -> bool:
	if target_blocker(source, tile, action) != "":
		return false
	if not source.can_afford(action):
		return false

	source.spend_energy(action.en_cost_now())

	for affected in affected_tiles(tile, action):
		var target := unit_at(affected)
		if target == null:
			continue
		# Die Flaeche fragt dieselbe Frage wie das Fadenkreuz: ist dieser DROME
		# ueberhaupt gemeint? Ohne diese Zeile traf der Belagerungsschlag jeden,
		# der im Radius stand -- den eigenen Verbuendeten, und bei einem Ziel auf
		# dem Nachbarfeld den Schuetzen selbst. Ein Molok, der auf Tuchfuehlung
		# feuerte, schoss sich damit Zug um Zug die eigene Integritaet weg, ohne
		# dass Vorschau oder KI davon etwas ahnten: beide bewerten das ANVISIERTE
		# Ziel, und dort stand die Zahl richtig.
		#
		# Dieselbe Zeile richtet die Reparaturdrohnen mit: deren Radius heilte
		# bisher auch Gegner, die neben dem Verbuendeten standen.
		if not is_meaningful_target(source, target, action):
			continue
		if action.is_heal():
			heal(source, target, action.heal_amount(), action)
		elif action.power > 0:
			apply_damage(source, target, action.power + source.atk(), action)
		elif action.aggro_flat > 0:
			# Wirkung ohne Wirkungsmenge -- Stossen, Ziehen, reine Kontrolle.
			# Ohne den Pauschalwert waere ein Kontroll-Aufbau lautlos.
			_book_aggro(target, source, float(action.aggro_flat), action.aggro_coeff)
		if action.push_tiles != 0 and target != source:
			_shove(source, target, action.push_tiles)
		if action.status_effect != null:
			_apply_status(target, action.status_effect)
		if action.is_taunt() and target != source:
			_apply_taunt(source, target, action)

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
