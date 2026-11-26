class_name ActionResolver
extends RefCounted

## Fuehrt Aktionen aus und wendet Schaden und Effekte an.
##
## Schaden ist deterministisch:
##
##     roh = waffe.power x angreifer.power / 10   (Unit.raw_damage)
##     danach Schild (Faktor je Schadensart) und Ruestung (eHP-Multiplikator)
##
## Kein Trefferwurf, kein Krit, keine Ausweichchance: derselbe Seed ergibt
## denselben Kampf.

var grid: Grid
var units: Array = []

## Verzoegerte Wirkungen (Schockwelle nach dem Sog):
## { left: Sekunden, source: Unit, tile: Vector2i, action: ActionData }.
## Der BattleManager ruft advance() je Schritt.
var delayed: Array = []
## Waehrend Sog oder Stoss gesetzt (18. Nov. 2026): die Versetzung ist
## erzwungen -- die Anzeige laesst den DROME sichtbar rutschen.
var forcing := false

## Salven (18. Nov. 2026): Abstand der Schuesse einer Salve, Pause zwischen
## zwei Salven und die Flugzeit bis zum Treffer -- dieselben Zeiten nutzt die
## Anzeige (AbilityFx), damit Schuss und Zahl zusammenpassen.
const SALVO_GAP := 0.07
const SALVO_PAUSE := 0.16
const SALVO_FLIGHT := 0.12


## Wann der Schuss ``bullet`` der Salve ``volley`` trifft (Sekunden nach dem
## Ausloesen).
static func salvo_time(action: ActionData, volley: int, bullet: int) -> float:
	return volley * (action.salvo * SALVO_GAP + SALVO_PAUSE) + bullet * SALVO_GAP + SALVO_FLIGHT

## Zufall des Kampfes (BattleManager.rng) -- fuer den Zusatztreffer der
## Stacheln (Splitterpanzer). Fehlt er, gibt es keinen.
var rng: RandomNumberGenerator


func _init(battle_grid: Grid, all_units: Array) -> void:
	grid = battle_grid
	units = all_units


# ---------------------------------------------------------------------------
# Die Mitigationskette
# ---------------------------------------------------------------------------

## Die EINZIGE Stelle, an der Schaden angewendet wird.
##
## ``action`` traegt die Schadensart. Sie darf fehlen (Overtime).
##
## Charger (24. Nov. 2026): ``charge_share`` ist der Anteil eines Treffers,
## den dieser Schuss fuer die Elementarbelastung zaehlt (eine Salve aus drei
## Schuessen = ein Treffer, je Schuss 1/3). ``ability_bonus`` false: der
## Bonus der Faehigkeit (Belastung + Stapel) ist in diesem Einsatz an diesem
## Ziel schon angelegt.
func apply_damage(source: Unit, target: Unit, raw: int,
		action: ActionData = null, pierce_shield: bool = false,
		charge_share: float = 1.0, ability_bonus: bool = true) -> int:
	# Zielsucher: Angriffe gegen markierte Gegner treffen haerter.
	if action != null and action.bonus_vs_marked > 0.0 and is_marked(target):
		raw = int(round(float(raw) * (1.0 + action.bonus_vs_marked)))
	# Phasenbruch: gegen Gegner ohne Schild.
	if action != null and action.bonus_vs_unshielded > 0.0 and target.shield <= 0:
		raw = int(round(float(raw) * (1.0 + action.bonus_vs_unshielded)))
	var frac := action.energy_fraction if action != null else 0.0
	# Ueberspannung: solange der eigene Schild steht, wird ein Teil des
	# kinetischen Schadens zu Energie.
	if action != null and action.kinetic_to_energy > 0.0 and source != null and source.shield > 0:
		frac += (1.0 - frac) * clampf(action.kinetic_to_energy, 0.0, 1.0)
	var shield_before := target.shield
	var res := resolve_damage(target, raw, frac,
		action.shield_mult if action != null else 1.0, pierce_shield,
		action.virus_fraction if action != null else 0.0)
	target.shield = res["shield_after"]
	var amount: int = res["hp"]

	target.hp = maxi(0, target.hp - amount)
	target.damage_taken += amount
	if source != null:
		source.damage_dealt += amount

	var dealt := (shield_before - target.shield) + amount
	if dealt > 0:
		target.note_damage()
		if source != null and action != null and source.is_player != target.is_player:
			source.damage_by_action[action.id] = int(source.damage_by_action.get(action.id, 0)) + dealt

	EventBus.unit_damaged.emit(target, amount, source)
	# Was der Schild geschluckt hat, eigens melden -- sonst sieht ein Treffer
	# auf den Schild aus wie kein Treffer (24. Nov. 2026).
	if shield_before > target.shield:
		EventBus.shield_damaged.emit(target, shield_before - target.shield, source)
	# Was der Schild geschluckt hat, steht mit im Log. Vorher hiess ein
	# Treffer auf den vollen Schild "fuer 0 Schaden" -- das las sich, als
	# waere nichts passiert, obwohl der Schild gerade halbiert wurde.
	var absorbed := shield_before - target.shield
	var who := source.display_name if source else "?"
	if absorbed > 0 and amount > 0:
		EventBus.log_line("%s trifft %s: Schild -%d, Integrität -%d."
			% [who, target.display_name, absorbed, amount])
	elif absorbed > 0:
		EventBus.log_line("%s trifft %s: Schild -%d (Integrität unversehrt)."
			% [who, target.display_name, absorbed])
	else:
		EventBus.log_line("%s trifft %s für %d Schaden."
			% [who, target.display_name, amount])

	# Lebensraub (Fusion Attack + Integrity): der Treffer heilt den Schuetzen.
	if action != null and action.lifesteal > 0.0 and source != null and source.is_alive() \
			and dealt > 0 and source != target:
		var heal := int(round(float(dealt) * action.lifesteal))
		if heal > 0:
			source.hp = mini(int(source.stats.get("hp_max", source.hp)), source.hp + heal)
	if action != null and not action.charger.is_empty() and target.hp > 0 \
			and source != null and source.is_player != target.is_player \
			and (charge_share > 0.0 or ability_bonus):
		_charge(source, target, action, charge_share, ability_bonus)
	if shield_before > 0 and target.shield <= 0 and target.hp > 0:
		_shield_broken(target)
	if target.hp <= 0:
		_hunt(source, target)
		if source != null and source != target and source.is_player != target.is_player:
			source.kills += 1
			if action != null:
				source.kills_by_action[action.id] = int(source.kills_by_action.get(action.id, 0)) + 1
		_kill(target)
	else:
		_thorns(source, target, action)
	return amount


## Konter am Traeger, wenn ihn ein ANGRIFF trifft (nicht Faehigkeiten, nicht
## der Konter selbst -- der kommt ohne Aktion):
##   * Stachelgitter: jeder Angreifer nimmt ``thorns``, im Nahkampf dazu
##     ``thorns_melee``. Splitterpanzer: am Schild vorbei, mit Chance auf
##     einen Zusatztreffer (Doppellauf des Traegers).
##   * Raufbold: der Treffer laedt den naechsten eigenen Angriff auf
##     (Nahkampf zaehlt doppelt, hoechstens 3x).
##   * Brandmarke: der Angreifer wird markiert.
func _thorns(source: Unit, target: Unit, action: ActionData) -> void:
	if source == null or action == null or not action.is_attack() or not source.is_alive():
		return
	if source.is_player == target.is_player:
		return
	var melee := Grid.distance(source.tile, target.tile) <= 1
	if float(target.stats.get("retaliation", 0.0)) > 0.0:
		target.retaliation_stacks = mini(int(target.stats.get("retaliation_max", 3)),
			target.retaliation_stacks + (2 if melee else 1))
	var brand := float(target.stats.get("mark_on_hit_taken", 0.0))
	if brand > 0.0:
		mark(source, brand)
	var spikes := int(target.stats.get("thorns", 0))
	if melee:
		spikes += int(target.stats.get("thorns_melee", 0))
	if spikes <= 0:
		return
	var pierce := bool(target.stats.get("thorns_true", false))
	apply_damage(target, source, spikes, null, pierce)
	var chance := float(target.stats.get("thorn_ricochet", 0.0))
	if pierce and chance > 0.0 and rng != null and source.is_alive() and rng.randf() < chance:
		var extra := maxi(1, int(round(float(spikes) * float(target.stats.get("thorn_ricochet_share", 0.25)))))
		apply_damage(target, source, extra, null, true)


# ---------------------------------------------------------------------------
# Markierung und Entladung (Module, MODULE_KONZEPT.md)
# ---------------------------------------------------------------------------

## Markiert ``foe`` (Peilsender, Brandmarke): nimmt ``rules.mark_damage_taken``
## mehr Schaden von allen. Stapelt nicht, frischt nur die Dauer auf.
func mark(foe: Unit, seconds: float) -> void:
	if foe == null or not foe.is_alive() or seconds <= 0.0:
		return
	var left := float((foe.statuses.get(&"mark", {}) as Dictionary).get("seconds_left", 0.0))
	foe.apply_status(&"mark", maxf(seconds, left),
		{"damage_taken_mult": 1.0 + ModuleData.rule("mark_damage_taken", 0.1)})


static func is_marked(unit: Unit) -> bool:
	return unit != null and unit.statuses.has(&"mark")


## Treibjagd (BIOS): stirbt ein markierter Gegner, springt die Markierung auf
## den naechsten seiner Seite -- wenn irgendein Gegner von ihm Treibjagd traegt.
func _hunt(_source: Unit, fallen: Unit) -> void:
	if not is_marked(fallen):
		return
	var hunter := false
	for unit in units:
		if unit.is_alive() and unit.is_player != fallen.is_player and bool(unit.stats.get("mark_hunt", false)):
			hunter = true
	if not hunter:
		return
	var left := float((fallen.statuses[&"mark"] as Dictionary).get("seconds_left", 0.0))
	var best: Unit = null
	var best_gap := 1 << 30
	for unit in units:
		if unit == fallen or not unit.is_alive() or unit.is_player != fallen.is_player:
			continue
		var gap := Grid.distance(unit.tile, fallen.tile)
		if gap < best_gap:
			best = unit
			best_gap = gap
	if best != null:
		mark(best, maxf(left, 2.0))
		EventBus.log_line("Treibjagd: %s ist markiert." % best.display_name)


## Modul Entladung: bricht der Schild des Traegers, nehmen alle Gegner in
## ``rules.burst_range`` Energieschaden und sind kurz betaeubt.
func _shield_broken(unit: Unit) -> void:
	var burst := int(unit.stats.get("shield_break_burst", 0))
	if burst <= 0 or unit.burst_cooldown > 0.0:
		return
	unit.burst_cooldown = ModuleData.rule("burst_cooldown", 6.0)
	var reach := int(ModuleData.rule("burst_range", 2))
	var stun := ModuleData.rule("burst_stun", 0.5)
	var spark := ActionData.new()
	spark.id = &"mod_discharge"
	spark.display_name = "Entladung"
	spark.category = ActionData.Category.ABILITY
	spark.energy_fraction = 1.0
	EventBus.log_line("%s: Entladung." % unit.display_name)
	for foe in units.duplicate():
		if foe.is_player == unit.is_player or not foe.is_alive():
			continue
		if Grid.distance(unit.tile, foe.tile) > reach:
			continue
		apply_damage(unit, foe, burst, spark)
		if foe.is_alive():
			foe.apply_status(&"stun", stun, {"id": "stun", "stunned": true}, unit)


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
		shield_mult: float = 1.0, pierce_shield: bool = false, virus_fraction: float = 0.0) -> Dictionary:
	var section := Config.section("combat")
	# Verwundbar (Plasmaklinge): der Statuseffekt vergroessert jeden Treffer.
	raw = int(round(float(raw) * target.damage_taken_mult()))
	# Virusschaden (Power-Hyperfusion, 20. Nov. 2026): dieser Anteil ignoriert
	# Panzerung und Schild-Faktoren, trifft aber zuerst den Schild.
	var v := int(round(float(raw) * clampf(virus_fraction, 0.0, 1.0)))
	raw -= v
	var e := int(round(float(raw) * clampf(energy_fraction, 0.0, 1.0)))
	var p := raw - e
	# Splitterpanzer: die Stacheln gehen am Schild vorbei.
	var shield := 0 if pierce_shield else target.shield
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
			var factor := float(portion["sf"]) * shield_mult
			var eff := int(round(float(amt) * factor))
			if eff <= shield:
				shield -= eff
			else:
				# Ueberschuss: der Rest wird in Rohschaden zurueckgerechnet und
				# trifft die Integritaet ohne Schildfaktor (frueher ging er mit
				# Faktor durch -- der Schildbrecher traf dann x2,4 auf HP).
				var used_raw := float(shield) / factor if factor > 0.0 else float(amt)
				to_hp += maxf(0.0, float(amt) - used_raw) * float(portion["hf"])
				shield = 0
		else:
			to_hp += float(amt) * float(portion["hf"])
	var true_hp := 0
	if v > 0:
		if shield > 0 and not pierce_shield:
			var taken := mini(shield, v)
			shield -= taken
			true_hp = v - taken
		else:
			true_hp = v
	return {"hp": _apply_armor_ehp(to_hp, target.def()) + true_hp,
		"shield_after": target.shield if pierce_shield else shield}


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
	var a := float(maxi(0, armor)) * (1.0 - clampf(pen, 0.0, 1.0))
	return maxi(1, int(round(raw_hp / armor_multiplier(a))))


## Der eHP-Faktor einer Panzerung (>= 1) -- auch fuer den Kampfwert
## (DromeBuild.power_parts).
static func armor_multiplier(armor: float) -> float:
	var section := Config.section("combat")
	var cap := float(section.get("armor_ehp_cap", 0.5))
	var k := maxf(0.001, float(section.get("armor_ehp_k", 15.0)))
	var a := maxf(0.0, armor)
	return 1.0 + cap * a / (a + k)


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
# Ausfall
# ---------------------------------------------------------------------------

## Ein DROME faellt aus: wer ihn als Ziel hatte, waehlt neu.
func forget_unit(unit: Unit) -> void:
	for other in units:
		if other.target_id == unit.unit_id:
			other.target_id = null


# ---------------------------------------------------------------------------
# Vorhersage -- fuer die Bewertung der KI
# ---------------------------------------------------------------------------

## Was wuerde diese Aktion anrichten? Dieselbe Rechnung wie die Ausfuehrung,
## nur ohne sie anzuwenden. Eine Aktion ohne Wirkungsmenge liefert 0.
func preview_damage(source: Unit, target: Unit, action: ActionData) -> int:
	if action.power <= 0:
		return 0
	return mitigate(source, target, source.raw_damage(action), action.energy_fraction,
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
## eine der sechs Hexrichtungen, bis zu ``range_tiles`` weit, nicht durch
## einen anderen DROME hindurch.
func dash_landings(source: Unit, action: ActionData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dir in 6:
		var tile := source.tile
		for _step in action.range_tiles:
			tile = Grid.neighbor(tile, dir)
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
		if Grid.line_direction(source.tile, tile) < 0:
			return "Nur in gerader Linie"
		if Grid.distance(source.tile, tile) > action.range_tiles:
			return "Zu weit für den Boost"
		return "Weg blockiert"
	if Grid.distance(source.tile, tile) > action.range_tiles:
		return "Außer Reichweite"
	# Moerser: zu nah kann er nicht feuern.
	if action.min_range > 0 and Grid.distance(source.tile, tile) < action.min_range:
		return "Zu nah"
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
		# Das Kreuz (auf dem Hexfeld ein Stern) trifft nur auf den sechs
		# geraden Linien vom Ziel aus.
		if cross and candidate != tile and Grid.line_direction(tile, candidate) < 0:
			continue
		tiles.append(candidate)
	return tiles


# ---------------------------------------------------------------------------
# Ausfuehrung
# ---------------------------------------------------------------------------

## Fuehrt die Aktion aus. Gibt zurueck, ob sie ueberhaupt zulaessig war.
## ``thrown``: eine geworfene Flaeche, deren Landefeld der Aufrufer schon
## geprueft hat (AIController._landing) -- sie wirkt auch auf ein leeres Feld.
func execute(source: Unit, tile: Vector2i, action: ActionData, thrown: bool = false) -> bool:
	if not thrown and target_blocker(source, tile, action) != "":
		return false
	# Dash: der Handelnde versetzt sich selbst.
	if action.is_move():
		EventBus.log_line("%s boostet %d Feld(er) nach %s."
			% [source.display_name, Grid.distance(source.tile, tile), tile])
		move_unit(source, tile)
		return true

	# Unterstuetzung: auf einen Verbuendeten (oder sich selbst) gezielt heilt
	# bzw. laedt sie, statt Schaden zu machen.
	var aimed := unit_at(tile)
	if aimed != null and aimed.is_player == source.is_player:
		if action.heal <= 0 and action.shield_gain <= 0:
			return false
		support(source, aimed, action)
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


## Wie viel eine Heilung oder Schildgabe bewirkt (9. Nov. 2026, Vorgabe des
## Spielers): Grundwert x Power des Anwenders / 10, dazu ein Anteil der
## maximalen Integritaet des ZIELS (combat.support.target_share) -- so bleibt
## Unterstuetzung auch spaeter wertvoll, wenn Tanks viel Integritaet haben.
static func support_amount(source: Unit, target: Unit, base: int) -> int:
	if base <= 0:
		return 0
	var share := float((Config.section("combat").get("support", {}) as Dictionary).get("target_share", 0.03))
	var from_source := float(base) * (source.power_factor() if source != null else 1.0)
	return int(round(from_source + share * float(target.stat("hp_max"))))


## Der hoechste Schild, den Schildgaben erreichen koennen: Maximum plus
## Ueberschild (combat.support.overshield, Anteil des Maximums).
static func shield_cap(target: Unit) -> int:
	var over := float((Config.section("combat").get("support", {}) as Dictionary).get("overshield", 0.5))
	return int(round(float(target.shield_max()) * (1.0 + over)))


## Heilen und Schild geben (Schild-Waffe, E-Schraubenschluessel). Was die
## Heilung ueber die volle Integritaet hinaus bringt, wird zu Schild -- aber
## nur bis zum normalen Maximum (kein Ueberschild aus Heilung). Ist beides
## voll, geht die Heilung ins Leere. Schildgaben duerfen ueber das Maximum,
## gedeckelt bei Maximum + 50 %. Gibt zurueck, wie viel zusammen dazukam.
func support(source: Unit, target: Unit, action: ActionData) -> int:
	var healed := 0
	var charged := 0
	var before_shield := target.shield
	if action.heal > 0:
		var amount := support_amount(source, target, action.heal)
		var before := target.hp
		target.hp = mini(target.stat("hp_max"), target.hp + amount)
		healed = target.hp - before
		var rest := amount - healed
		if rest > 0 and target.shield < target.shield_max():
			target.shield = mini(target.shield_max(), target.shield + rest)
		if healed > 0:
			EventBus.unit_healed.emit(target, healed, source)
	if action.shield_gain > 0:
		var gain := support_amount(source, target, action.shield_gain)
		target.shield = maxi(target.shield, mini(shield_cap(target), target.shield + gain))
	charged = target.shield - before_shield
	if healed > 0 or charged > 0:
		EventBus.log_line("%s: %s +%d Integrität, +%d Schild."
			% [source.display_name, target.display_name, healed, charged])
	return healed + charged


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
	# Der Bonus der Faehigkeit (Charger) gilt je Ziel einmal je Einsatz, nicht
	# je Schuss -- vorher legte jede Kugel eines Doppelschusses ihn neu an.
	var bonus_given: Array = []
	if action.salvo > 1:
		# Salven: die Schuesse treffen nacheinander, wenn sie ankommen. Eine
		# Salve zaehlt fuer die Elementarbelastung als EIN Treffer.
		var bullet := maxi(1, int(round(float(source.raw_damage(action)) / action.salvo)))
		for volley in targets.size():
			for b in action.salvo:
				var first: bool = not bonus_given.has(targets[volley])
				if first:
					bonus_given.append(targets[volley])
				delayed.append({"left": salvo_time(action, volley, b), "source": source,
					"target": targets[volley], "damage": bullet, "action": action,
					"share": 1.0 / float(action.salvo), "bonus": first})
		return
	for target in targets:
		if target.is_alive():
			var first: bool = not bonus_given.has(target)
			if first:
				bonus_given.append(target)
			apply_damage(source, target, source.raw_damage(action), action, false, 1.0, first)


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
		fired = true
		if entry.has("target"):
			# Ein Schuss einer Salve.
			var hit: Unit = entry["target"]
			if hit.is_alive() and source.is_alive():
				apply_damage(source, hit, int(entry["damage"]), action, false,
					float(entry.get("share", 1.0)), bool(entry.get("bonus", true)))
			continue
		EventBus.log_line("%s: %s schlägt ein." % [source.display_name, action.display_name])
		_apply_area(source, entry["tile"], action)
		if action.gather:
			_release_hold(entry["tile"], action)
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
			apply_damage(source, target, source.raw_damage(action), action)
		if action.push_tiles != 0 and target.is_alive():
			_shove(source, target, action.push_tiles)
		if not action.status.is_empty() and target.is_alive():
			apply_action_status(source, target, action)


## Charger (20. Nov. 2026, docs/CHARGER_KONZEPT.md): jeder Treffer legt die
## Elementarbelastung seiner Phasen an. Resonanz 4/6 verdoppelt jeden 5./3.
## Treffer; die Faehigkeit legt beim ueberwiegenden Element Stapel direkt an
## und ab Resonanz 2 zusaetzlich ``ability_load``. Volle Stapel wirken je
## Element (_element_stack).
func _charge(source: Unit, target: Unit, action: ActionData, share: float = 1.0,
		bonus: bool = true) -> void:
	var spec := action.charger
	# Treffer zaehlen auch in Bruchteilen (Salve); ein Treffer ist voll, wenn
	# die Summe eine ganze Zahl ueberschreitet.
	var before := float(spec.get("hits", 0))
	spec["hits"] = before + maxf(0.0, share)
	var done := int(floor(float(spec["hits"]) + 0.0001))
	var completed := done > int(floor(before + 0.0001))
	# Resonanz 4/6: der volle Treffer legt doppelt an -- der Zuschlag kommt
	# einmal ganz mit dem Schuss, der den Treffer voll macht.
	var extra := 0.0
	if completed:
		for every in spec.get("double_every", []):
			if int(every) > 0 and done % int(every) == 0:
				extra = 1.0
	var stack_at := float(spec.get("stack_at", 100))
	var dominant := str(spec.get("dominant", ""))
	var is_ability := bool(spec.get("ability", false)) and bonus
	var loads: Dictionary = spec.get("load", {})
	for element in loads:
		var amount := float(loads[element]) * (maxf(0.0, share) + extra)
		if is_ability and str(element) == dominant:
			amount += float(spec.get("ability_load", 0))
		var stacks := target.add_element_load(str(element), amount, stack_at)
		if stacks > 0:
			_element_stack(source, target, str(element), stacks)
	if is_ability and dominant != "" and target.is_alive():
		_element_stack(source, target, dominant, int(spec.get("ability_stacks", 1)))


## Volle Stapel eines Elements. Feuer = Kabelbrand (gebaut); die uebrigen
## werden gezaehlt, wirken aber noch nicht.
func _element_stack(source: Unit, target: Unit, element: String, stacks: int) -> void:
	if stacks <= 0:
		return
	if element == "fire":
		target.add_cable_fire(float(stacks), source)
	else:
		target.element_stacks[element] = int(target.element_stacks.get(element, 0)) + stacks
	EventBus.log_line("%s: %d %s-Stapel." % [target.display_name, stacks, Charger.element_name(element)])


## Der Statuseffekt einer Aktion am Ziel. Mit ``stacks`` (Kabelbrand) legt er
## Stapel, sonst wirkt er ``seconds`` lang -- beides gestreckt mit der
## Effizienz des Ausloesers.
func apply_action_status(source: Unit, target: Unit, action: ActionData) -> void:
	var status := action.status
	if str(status.get("id", "")) == "cable_fire":
		target.add_cable_fire(float(status.get("stacks", 1)), source)
		return
	target.apply_status(StringName(str(status.get("id", "status"))),
		float(status.get("seconds", 1.0)), status, source)


## Kabelbrand je Puls: verbraucht hoechstens ``max_per_pulse`` Stapel, je
## Stapel kinetischen und Energieschaden (ohne Power). Der Rest bleibt liegen.
## Gibt den angerichteten Schaden zurueck.
func burn_cable_fire(unit: Unit) -> int:
	if unit == null or not unit.is_alive():
		return 0
	var rule := Config.section("statuses").get("cable_fire", {}) as Dictionary
	var stacks := unit.take_cable_fire(int(rule.get("max_per_pulse", 10)))
	if stacks <= 0:
		return 0
	var kinetic := int(rule.get("kinetic", 5))
	var energy := int(rule.get("energy", 5))
	var raw := (kinetic + energy) * stacks
	if raw <= 0:
		return 0
	var burn := ActionData.new()
	burn.id = &"status_cable_fire"
	burn.display_name = "Kabelbrand"
	burn.category = ActionData.Category.ABILITY
	burn.energy_fraction = float(energy) / float(kinetic + energy)
	var source: Unit = null
	for other in units:
		if other.unit_id == unit.cable_fire_source and other.is_alive():
			source = other
	EventBus.log_line("%s: Kabelbrand, %d Stapel." % [unit.display_name, stacks])
	var shield_before := unit.shield
	var hp_before := unit.hp
	apply_damage(source, unit, raw, burn)
	return (shield_before - unit.shield) + (hp_before - unit.hp)


## Festhalten im Sog: Statuskennung. Die Dauer reicht sicher bis zur
## Schockwelle; dort wird das Festhalten aufgehoben (_release_hold).
const HOLD_STATUS := &"vortex_hold"
const HOLD_SLACK := 0.5
## Anteil der Verzoegerung, ueber den die Gezogenen sichtbar heranrutschen.
const PULL_SHARE := 0.85

## Wie lange eine erzwungene Versetzung gerade zu sehen sein soll (0 = die
## Vorgabe der Anzeige). Der Sog setzt sie auf seine Sog-Zeit.
var forced_seconds := 0.0


## Sog (24. Nov. 2026, Vorgabe des Spielers -- "wie ein schwarzes Loch"):
## beim Aufprall werden alle Gegner im Radius zum Zielfeld gezogen. Der
## naechste kommt auf das Zielfeld selbst (wenn es frei ist), die uebrigen so
## weit, wie in ihrer Richtung Platz ist -- bis zu ``aoe_radius`` Felder. Bis
## zur Schockwelle sind alle Erfassten festgehalten: kein Laufen, kein
## Schiessen. Danach sind sie frei, aber verlangsamt (Statuseffekt).
func _gather(source: Unit, center: Vector2i, action: ActionData) -> void:
	var caught: Array = []
	for unit in units:
		if not unit.is_alive() or unit.is_player == source.is_player:
			continue
		if Grid.distance(unit.tile, center) <= action.aoe_radius:
			caught.append(unit)
	caught.sort_custom(func(a, b):
		return Grid.distance(a.tile, center) < Grid.distance(b.tile, center))
	forcing = true
	forced_seconds = action.delay * PULL_SHARE if action.delay > 0.0 else 0.0
	var moved := 0
	for unit in caught:
		var start: Vector2i = unit.tile
		for _i in action.aoe_radius:
			if unit.tile == center:
				break
			var next := _step_toward(unit, center)
			if next == unit.tile:
				break
			move_unit(unit, next)
		if unit.tile != start:
			moved += 1
	forcing = false
	forced_seconds = 0.0
	if moved > 0:
		EventBus.log_line("%s zieht %d Gegner zusammen." % [source.display_name, moved])
	if action.delay > 0.0:
		for unit in caught:
			unit.apply_status(HOLD_STATUS, action.delay + HOLD_SLACK, {"stunned": true})


## Nach der Schockwelle: die Festgehaltenen sind wieder frei.
func _release_hold(center: Vector2i, action: ActionData) -> void:
	for unit in units:
		if unit.statuses.has(HOLD_STATUS) and Grid.distance(unit.tile, center) <= action.aoe_radius:
			unit.statuses.erase(HOLD_STATUS)


## Ein Feld naeher an ``center``, wenn frei -- erst die Richtung, die am
## besten hinzeigt, dann die beiden daneben.
func _step_toward(unit: Unit, center: Vector2i) -> Vector2i:
	var dir := Grid.direction_toward(unit.tile, center)
	if dir < 0:
		return unit.tile
	var here := Grid.distance(unit.tile, center)
	for turn in [0, 1, -1]:
		var tile := Grid.neighbor(unit.tile, dir + turn)
		if Grid.distance(tile, center) < here and grid.can_stand_on(tile, unit.unit_id):
			return tile
	return unit.tile


## Stossen und Ziehen. Positiv = weg, negativ = heran.
func _shove(source: Unit, target: Unit, tiles: int) -> void:
	# Die Hexrichtung von der Quelle zum Ziel; ziehen = Gegenrichtung.
	var dir := Grid.direction_toward(source.tile, target.tile)
	if dir < 0:
		return
	if tiles < 0:
		dir += 3

	var moved := 0
	forcing = true
	for _i in absi(tiles):
		var nxt := Grid.neighbor(target.tile, dir)
		if not grid.can_stand_on(nxt, target.unit_id):
			break
		move_unit(target, nxt)
		moved += 1
	forcing = false
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
