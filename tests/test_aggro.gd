extends RefCounted

## Das Aggro-System: Buchung, Verfall, Traegheit, Provokation.
##
## Die vier Kernszenarien stehen absichtlich VOR jedem Balancing. Sie pruefen
## nicht, ob die Zahlen gut sind -- sie pruefen die Eigenschaften, die das
## Modell haben muss, damit Balancing ueberhaupt Sinn ergibt:
##
##   1. Aggro entsteht aus Aktionen, nicht aus Identitaet; wer vorne steht,
##      haelt sie leichter.
##   2. Die Zielwahl flackert nicht bei fast gleichauf liegenden Werten.
##   3. Wiederholtes Provozieren eskaliert nicht.
##   4. Ein leiser Koeffizient schuetzt die Backline auch bei mehr Schaden.
##   5. Anhaltende Wirkung loest ein einmal gesetztes Ziel ab.
##
## Die ersten vier pruefen alle die Ober- und die Kurzfristseite. Die fuenfte
## kam spaeter dazu und prueft die Langfristseite -- sie war rot, und zwar aus
## zwei Gruenden gleichzeitig: der eingefrorene Amtsinhaber und ein
## incumbent_bonus, der ueber dem gesamten Wertebereich des Aggro-Terms lag.
## Beides sah im Spiel nicht nach einem Fehler aus, sondern nach Absicht.
##
## Gebaut wird ohne Szene und ohne Kampf, wo es geht: die Tabelle ist reine
## Logik, und ein Test, der dafuer eine Karte wuerfeln muss, prueft am Ende
## den Kartengenerator mit.

var t


# ---------------------------------------------------------------------------
# Werkzeug
# ---------------------------------------------------------------------------

func _melee() -> DromeBuild:
	return DromeBuild.create("NAHKAMPF", {
		"body": &"mage_body", "head": &"mage_head",
		"feet": &"mage_drive", "core": &"mage_core",
		"equip_left": &"eq_rune_staff"})


func _sniper() -> DromeBuild:
	return DromeBuild.create("SCHUETZE", {
		"body": &"strix_body", "head": &"strix_head",
		"feet": &"strix_feet", "core": &"strix_core",
		"equip_center": &"eq_rail_lance"})


func _unit(build: DromeBuild, id: StringName, player: bool, tile: Vector2i) -> Unit:
	var unit := Unit.create(build, id, player)
	unit.tile = tile
	return unit


## Ein Gefecht ohne Szene: Gitter, Einheiten, Resolver. Die Einheiten werden
## nicht in den Baum gehaengt -- fuer Aggro braucht es keine Sprites.
func _arena(player_tiles: Array, enemy_tile: Vector2i) -> Dictionary:
	var grid := Grid.new(20, 20)
	grid.fill(Terrain.TClass.NORMAL)
	var units: Array = []
	var index := 0
	for entry in player_tiles:
		units.append(_unit(entry["build"], StringName("P%d" % index), true, entry["tile"]))
		index += 1
	var foe := _unit(_melee(), &"E0", false, enemy_tile)
	units.append(foe)
	for unit in units:
		grid.set_occupant(unit.tile, unit.unit_id)
	return {"grid": grid, "units": units, "foe": foe,
		"resolver": ActionResolver.new(grid, units)}


func _attack_of(unit: Unit) -> ActionData:
	for action in unit.actions():
		if action.is_attack():
			return action
	return null


func _free(arena: Dictionary) -> void:
	for unit in arena["units"]:
		unit.free()


# ---------------------------------------------------------------------------
# 1. Aggro entsteht aus Aktionen, nicht aus Identitaet
# ---------------------------------------------------------------------------

func test_a_fresh_table_is_empty() -> void:
	var arena := _arena([{"build": _melee(), "tile": Vector2i(5, 5)}], Vector2i(9, 9))
	t.ok(arena["foe"].aggro != null, "ein Gegner fuehrt eine Aggro-Tabelle")
	t.ok(arena["foe"].aggro.is_empty(),
		"zu Gefechtsbeginn steht niemand darin -- Aggro kommt aus Aktionen")
	t.equal(arena["units"][0].aggro, null,
		"ein Spieler-DROME fuehrt keine Tabelle: seine Ziele waehlt der Spieler")
	_free(arena)


func test_presence_alone_creates_no_aggro() -> void:
	# Direkt nebeneinander, ueber mehrere Zyklen. Ohne Aktion passiert nichts.
	var arena := _arena([{"build": _melee(), "tile": Vector2i(5, 5)}], Vector2i(5, 6))
	for _i in 5:
		arena["foe"].aggro.decay(0.15, 1.0)
	t.ok(arena["foe"].aggro.is_empty(),
		"blosse Naehe erzeugt keine Aggro -- Praesenz kostet einen Slot")
	_free(arena)


func test_the_closer_attacker_holds_aggro_at_equal_damage() -> void:
	# Zwei Angreifer, identische Waffe, identischer Schaden -- einer im
	# Nahbereich, einer weit weg. Der Nahe muss vorn liegen, und zwar allein
	# ueber den Naehe-Faktor, nicht ueber irgendeine Klasseneigenschaft.
	var arena := _arena([
		{"build": _melee(), "tile": Vector2i(9, 8)},    # direkt daneben
		{"build": _melee(), "tile": Vector2i(2, 2)},    # weit weg
	], Vector2i(9, 9))
	var resolver: ActionResolver = arena["resolver"]
	var near: Unit = arena["units"][0]
	var far: Unit = arena["units"][1]
	var foe: Unit = arena["foe"]

	for _i in 5:
		foe.hp = foe.stat("hp_max")
		resolver.apply_damage(near, foe, 20, _attack_of(near))
		resolver.apply_damage(far, foe, 20, _attack_of(far))

	t.ok(foe.aggro.value_of(near.unit_id) > foe.aggro.value_of(far.unit_id),
		"bei gleichem Schaden haelt der Nahe die Aggro (%.0f vs %.0f)"
		% [foe.aggro.value_of(near.unit_id), foe.aggro.value_of(far.unit_id)])
	t.equal(int(round(foe.aggro.share(near.unit_id))), 1,
		"der Spitzenreiter hat den Anteil 1.0")
	_free(arena)


func test_healing_is_booked_against_every_foe_and_only_what_landed() -> void:
	var techie := DromeBuild.create("TECHNIK", {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_shoulder": &"eq_drone_pod"})
	var arena := _arena([
		{"build": techie, "tile": Vector2i(4, 4)},
		{"build": _melee(), "tile": Vector2i(5, 4)},
	], Vector2i(9, 9))
	var resolver: ActionResolver = arena["resolver"]
	var healer: Unit = arena["units"][0]
	var patient: Unit = arena["units"][1]
	var foe: Unit = arena["foe"]
	var heal_action: ActionData = null
	for action in healer.actions():
		if action.is_heal():
			heal_action = action

	# Auf Vollleben darf gar nichts gebucht werden.
	resolver.heal(healer, patient, heal_action.heal_amount(), heal_action)
	t.ok(foe.aggro.is_empty(),
		"Heilen auf Vollleben erzeugt keine Aggro -- nur was ankommt, zaehlt")

	patient.hp = 10
	resolver.heal(healer, patient, heal_action.heal_amount(), heal_action)
	t.ok(foe.aggro.value_of(healer.unit_id) > 0.0,
		"echte Heilung bucht gegen den Gegner des Geheilten")
	_free(arena)


# ---------------------------------------------------------------------------
# 2. Kein Flackern
# ---------------------------------------------------------------------------

func test_the_incumbent_decays_slower_but_it_decays() -> void:
	# Frueher war der Amtsinhaber ganz vom Verfall ausgenommen. Das war die
	# Ursache der Decke aus dem Test darunter: gegen eine eingefrorene Summe
	# kommt kein Herausforderer an. Er verfaellt jetzt mit, nur langsamer --
	# gerade genug, dass ein Ziel nicht mitten im Anlauf wegrutscht.
	var arena := _arena([
		{"build": _melee(), "tile": Vector2i(9, 8)},
		{"build": _melee(), "tile": Vector2i(8, 9)},
	], Vector2i(9, 9))
	var foe: Unit = arena["foe"]
	foe.aggro.add(&"P0", 100.0)
	foe.aggro.add(&"P1", 100.0)
	foe.aggro.current_target = &"P0"

	for _i in 10:
		foe.aggro.decay(0.15, 1.0, 0.5)

	var incumbent := foe.aggro.value_of(&"P0")
	var other := foe.aggro.value_of(&"P1")
	t.ok(incumbent > other,
		"das aktuelle Ziel baut langsamer ab als die anderen (%.1f vs %.1f)"
		% [incumbent, other])
	t.ok(incumbent < 100.0,
		"aber es baut ab -- eingefroren war es die Ursache der Aggro-Decke (%.1f)"
		% incumbent)
	_free(arena)


func test_sustained_pressure_can_always_take_the_target_over() -> void:
	# Die Langfristseite des Modells, und die einzige Zusicherung, die dem
	# Spieler ueberhaupt Einfluss auf die gegnerische Zielwahl gibt: wer lange
	# genug draufhaelt, BEKOMMT das Ziel.
	#
	# Vorher ging das nicht, aus zwei Gruenden gleichzeitig. Der Amtsinhaber
	# war vom Verfall ausgenommen, waehrend ein Herausforderer mit d Aggro je
	# Zyklus bei d * (1 - rate) / rate saettigt -- bei rate 0.15 das
	# 5,67-fache. Und selbst wer die Tabelle anfuehrte, kam nicht durch: der
	# Aggro-Term ist ein ANTEIL und damit auf aggro_weight (10) gedeckelt,
	# der incumbent_bonus_ranged stand auf 12. Die Traegheit war groesser als
	# der gesamte Wertebereich dessen, wogegen sie antritt.
	var battle := BattleManager.new()
	battle.setup(9117, [_melee(), _sniper()])
	var foe: Unit = battle.living(false)[0]
	var incumbent: Unit = battle.living(true)[0]
	var challenger: Unit = battle.living(true)[1]
	var controller := AIController.new(battle)

	# Ein grosser Treffer frueh im Gefecht -- der Fall, den GAME_DESIGN 6e
	# ausdruecklich nicht zementieren will.
	foe.aggro.add(incumbent.unit_id, 240.0)
	foe.aggro.current_target = incumbent.unit_id

	var took_over_in := 0
	for cycle in 30:
		foe.aggro.add(challenger.unit_id, 40.0)
		if controller._aggro_score(foe, challenger) > controller._aggro_score(foe, incumbent):
			took_over_in = cycle + 1
			break
		foe.aggro.decay(0.15, 1.0, 0.5)

	t.ok(took_over_in > 0,
		"anhaltende Wirkung loest ein einmal gesetztes Ziel ab (Zyklus %d, %.1f gegen %.1f)"
		% [took_over_in, foe.aggro.value_of(challenger.unit_id),
			foe.aggro.value_of(incumbent.unit_id)])
	battle.free()


func test_the_incumbent_bonus_stays_under_the_aggro_weight() -> void:
	# Als Invariante, weil sie beim Tunen unsichtbar bricht. Der Aggro-Term
	# ist ein Anteil (0..1) mal aggro_weight und damit nach oben gedeckelt.
	# Steht ein incumbent_bonus darueber, kann ihn kein Herausforderer je
	# aufholen -- die Tabelle waere fuer die Zielwahl wirkungslos, und zwar
	# ohne dass irgendetwas danach aussieht.
	var ai := Config.section("ai")
	var weight := float(ai.get("aggro_weight", 10.0))
	for key in ["incumbent_bonus_melee", "incumbent_bonus_ranged"]:
		t.ok(float(ai.get(key, 0.0)) < weight,
			"%s (%.1f) bleibt unter aggro_weight (%.1f)"
			% [key, float(ai.get(key, 0.0)), weight])


func test_the_target_does_not_flicker_at_a_one_percent_difference() -> void:
	# Zwei Einheiten, ein Prozent Unterschied, zehn Zyklen. Die KI darf das
	# Ziel nicht wechseln: fuer den Spieler waere das nicht von Zufall zu
	# unterscheiden, und damit waere die Aggro nicht steuerbar.
	var battle := BattleManager.new()
	battle.setup(9111, [_melee(), _sniper()])
	var foe: Unit = battle.living(false)[0]
	var a: Unit = battle.living(true)[0]
	var b: Unit = battle.living(true)[1]
	var controller := AIController.new(battle)

	foe.aggro.add(a.unit_id, 100.0)
	foe.aggro.add(b.unit_id, 101.0)
	foe.aggro.current_target = a.unit_id

	var switches := 0
	for _i in 10:
		# Nur die Bewertung, ohne den Kampf zu spielen: welches der beiden
		# Ziele haette den hoeheren Aggro-Anteil?
		var score_a := controller._aggro_score(foe, a)
		var score_b := controller._aggro_score(foe, b)
		if score_b > score_a:
			switches += 1
		foe.aggro.decay(0.15, 1.0)

	t.equal(switches, 0,
		"bei ~1 %% Unterschied bleibt das Ziel ueber 10 Zyklen dasselbe")
	battle.free()


func test_a_ranged_enemy_clings_harder_than_a_melee_one() -> void:
	var battle := BattleManager.new()
	battle.setup(9112, [_melee()])
	var controller := AIController.new(battle)
	var foe: Unit = battle.living(false)[0]

	# Derselbe Gegner, einmal mit kurzer, einmal mit langer Waffe bewertet.
	var melee_unit := Unit.create(_melee(), &"X0", false)
	var ranged_unit := Unit.create(_sniper(), &"X1", false)
	t.ok(controller._incumbent_bonus(ranged_unit) > controller._incumbent_bonus(melee_unit),
		"wer aus sieben Feldern schiesst, laesst sich schwerer umlenken (%.0f vs %.0f)"
		% [controller._incumbent_bonus(ranged_unit), controller._incumbent_bonus(melee_unit)])
	melee_unit.free()
	ranged_unit.free()
	t.ok(foe.aggro != null, "der generierte Gegner hat eine Tabelle")
	battle.free()


# ---------------------------------------------------------------------------
# 3. Provokation eskaliert nicht
# ---------------------------------------------------------------------------

func test_repeated_taunts_do_not_escalate() -> void:
	var arena := _arena([
		{"build": _melee(), "tile": Vector2i(9, 8)},
		{"build": _melee(), "tile": Vector2i(8, 9)},
	], Vector2i(9, 9))
	var resolver: ActionResolver = arena["resolver"]
	var provoker: Unit = arena["units"][0]
	var foe: Unit = arena["foe"]
	foe.aggro.add(arena["units"][1].unit_id, 200.0)

	var taunt := ActionData.new()
	taunt.id = &"act_test_taunt"
	taunt.display_name = "Provokation"
	taunt.category = ActionData.Category.ABILITY
	taunt.taunt_turns = 3

	resolver._apply_taunt(provoker, foe, taunt)
	var after_first := foe.aggro.value_of(provoker.unit_id)
	for _i in 2:
		resolver._apply_taunt(provoker, foe, taunt)
	var after_third := foe.aggro.value_of(provoker.unit_id)

	t.equal(after_third, after_first,
		"dreimal provozieren bringt nicht mehr als einmal (%.0f)" % after_third)
	t.ok(after_first > 200.0 and after_first < 300.0,
		"die Quelle steht danach knapp vorn, nicht uneinholbar (%.0f bei Maximum 200)"
		% after_first)
	_free(arena)


func test_a_taunt_forbids_every_other_target() -> void:
	var arena := _arena([
		{"build": _melee(), "tile": Vector2i(9, 8)},
		{"build": _melee(), "tile": Vector2i(8, 9)},
	], Vector2i(9, 9))
	var resolver: ActionResolver = arena["resolver"]
	var forcer: Unit = arena["units"][0]
	var other: Unit = arena["units"][1]
	var foe: Unit = arena["foe"]
	var attack := _attack_of(foe)

	t.equal(resolver.target_blocker(foe, other.tile, attack), "",
		"ohne Provokation ist jedes Ziel in Reichweite erlaubt")

	foe.apply_taunt(forcer.unit_id, 3)
	t.ok(resolver.target_blocker(foe, other.tile, attack) != "",
		"provoziert ist jedes andere Ziel gesperrt")
	t.equal(resolver.target_blocker(foe, forcer.tile, attack), "",
		"die Quelle selbst bleibt angreifbar")

	# Faellt die Quelle aus, loest sich der Zwang sofort -- sonst stuende der
	# Provozierte untaetig herum.
	forcer.hp = 0
	resolver.forget_unit(forcer)
	t.equal(resolver.target_blocker(foe, other.tile, attack), "",
		"stirbt die Quelle, ist der Provozierte wieder frei")
	_free(arena)


func test_a_taunt_expires_on_the_victims_own_turns() -> void:
	var unit := Unit.create(_melee(), &"E9", false)
	unit.apply_taunt(&"P0", 3)
	for i in 3:
		t.ok(unit.is_taunted(), "Provokation gilt noch vor Zug %d" % (i + 1))
		unit.tick_taunt()
	t.ok(not unit.is_taunted(), "nach drei eigenen Zuegen laeuft sie ab")
	unit.free()


# ---------------------------------------------------------------------------
# 4. Der leise Koeffizient schuetzt die Backline
# ---------------------------------------------------------------------------

func test_a_quiet_sniper_does_not_take_aggro_from_the_frontline() -> void:
	# Der Schuetze richtet MEHR Schaden an als der Nahkaempfer und darf die
	# Aggro trotzdem nicht uebernehmen. Genau dafuer gibt es den Koeffizienten:
	# 0.35 x 40 x 1.0 = 14  <  1.0 x 20 x 1.5 = 30
	var arena := _arena([
		{"build": _melee(), "tile": Vector2i(9, 8)},
		{"build": _sniper(), "tile": Vector2i(3, 3)},
	], Vector2i(9, 9))
	var resolver: ActionResolver = arena["resolver"]
	var brawler: Unit = arena["units"][0]
	var sniper: Unit = arena["units"][1]
	var foe: Unit = arena["foe"]

	for _i in 4:
		foe.hp = foe.stat("hp_max")
		resolver.apply_damage(brawler, foe, 20, _attack_of(brawler))
		resolver.apply_damage(sniper, foe, 40, _attack_of(sniper))

	t.ok(foe.aggro.value_of(brawler.unit_id) > foe.aggro.value_of(sniper.unit_id),
		"der leise Schuetze zieht trotz doppeltem Schaden weniger Aggro (%.0f vs %.0f)"
		% [foe.aggro.value_of(sniper.unit_id), foe.aggro.value_of(brawler.unit_id)])
	_free(arena)


func test_control_without_damage_is_not_silent() -> void:
	var puller := DromeBuild.create("SOG", {
		"body": &"mage_body", "head": &"mage_head",
		"feet": &"mage_drive", "core": &"mage_core",
		"equip_left": &"eq_rune_staff", "equip_right": &"eq_orbit_focus"})
	var arena := _arena([{"build": puller, "tile": Vector2i(6, 9)}], Vector2i(9, 9))
	var resolver: ActionResolver = arena["resolver"]
	var unit: Unit = arena["units"][0]
	var foe: Unit = arena["foe"]
	var pull: ActionData = null
	for action in unit.actions():
		if action.push_tiles != 0:
			pull = action

	t.ok(pull != null and pull.aggro_flat > 0,
		"der Orbit-Sog fuehrt einen Pauschalwert -- er richtet keinen Schaden an")
	resolver.execute(unit, foe.tile, pull)
	t.ok(foe.aggro.value_of(unit.unit_id) > 0.0,
		"eine reine Kontroll-Aktion ist nicht lautlos")
	_free(arena)


# ---------------------------------------------------------------------------
# Der Koedersender -- das einzige Teil, das Aggro ohne Handeln erzeugt
# ---------------------------------------------------------------------------

func test_the_beacon_is_a_light_support_module_with_a_taunt() -> void:
	var part := PartDB.get_part(&"eq_bait_beacon")
	t.ok(part != null, "EQP-008 ist im Bestand")
	t.equal(part.mount_class, "light", "leicht -- passt auch auf die Molok-Schulter")
	t.equal(part.category, "support", "Support, keine Waffe")
	t.ok(part.aggro_bonus > 0, "es fuehrt als einziges Teil aggro_bonus")
	var taunt: ActionData = null
	for action in part.actions:
		if action.is_taunt():
			taunt = action
	t.ok(taunt != null, "und als einziges eine Provokation")
	t.ok(taunt.taunt_turns > 0 and taunt.en_cost > 0,
		"befristet und nicht umsonst -- harter Zwang muss beides sein")


func test_the_beacon_raises_the_aggro_its_carrier_generates() -> void:
	# Zwei identische Aufbauten, einer mit Sender im zweiten Slot. Bei exakt
	# gleichem Schaden muss der Traeger mehr Aggro erzeugen -- sonst ist der
	# Stat irgendwo auf dem Weg von der Bauteil-JSON zur Formel verlorengegangen.
	var plain := DromeBuild.create("OHNE", {
		"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core",
		"equip_left": &"eq_pulse_blaster"})
	var loud := DromeBuild.create("MIT", {
		"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core",
		"equip_left": &"eq_pulse_blaster", "equip_right": &"eq_bait_beacon"})
	t.ok(loud.stats()["aggro_bonus"] > 0, "der Aufbau summiert den Bonus")

	var arena := _arena([
		{"build": plain, "tile": Vector2i(9, 8)},
		{"build": loud, "tile": Vector2i(8, 9)},
	], Vector2i(9, 9))
	var resolver: ActionResolver = arena["resolver"]
	var quiet: Unit = arena["units"][0]
	var noisy: Unit = arena["units"][1]
	var foe: Unit = arena["foe"]

	foe.hp = foe.stat("hp_max")
	resolver.apply_damage(quiet, foe, 20, _attack_of(quiet))
	foe.hp = foe.stat("hp_max")
	resolver.apply_damage(noisy, foe, 20, _attack_of(noisy))

	t.ok(foe.aggro.value_of(noisy.unit_id) > foe.aggro.value_of(quiet.unit_id),
		"der Sender-Traeger erzeugt bei gleichem Schaden mehr Aggro (%.1f vs %.1f)"
		% [foe.aggro.value_of(noisy.unit_id), foe.aggro.value_of(quiet.unit_id)])
	_free(arena)


func test_the_beacon_costs_a_slot_and_the_strix_cannot_pay_it() -> void:
	# Die Behauptung aus GAME_DESIGN 6b, als Test: Praesenz-Aggro kostet einen
	# Ausruestungsslot. Wer nur einen hat, bezahlt ihn mit seiner Waffe.
	#
	# Frueher war dieser Aufbau schlicht ungueltig ("Keine Waffe bestueckt").
	# Seit ein waffenloser Aufbau eine Entscheidung sein darf, ist der Preis
	# nicht mehr die Ablehnung, sondern die leere Angriffsliste -- und das ist
	# die ehrlichere Formulierung derselben Aussage: der Strix KANN den Sender
	# tragen, nur eben statt zu schiessen.
	var strix := DromeBuild.create("STRIX", {
		"body": &"strix_body", "head": &"strix_head",
		"feet": &"strix_feet", "core": &"strix_core",
		"equip_center": &"eq_bait_beacon"})
	t.ok(strix.is_valid(),
		"der Strix mit Sender statt Lanze ist baubar: %s"
		% ", ".join(strix.validate()))
	t.ok(strix.actions_of(ActionData.Category.ATTACK).is_empty(),
		"und hat dafuer keinen einzigen Angriff mehr")

	var molok := DromeBuild.create("MOLOK", {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": &"eq_siege_cannon", "equip_shoulder": &"eq_bait_beacon"})
	t.ok(molok.is_valid(),
		"der Molok traegt ihn auf der Schulter und behaelt seine Waffe: %s"
		% ", ".join(molok.validate()))


# ---------------------------------------------------------------------------
# Was eine Umlenkung wert ist
# ---------------------------------------------------------------------------

## Baut eine Lage, in der eine Provokation ueberhaupt etwas bewirken KANN:
## zwei Gegner und ein Spieler-DROME, alle in Reichweite voneinander.
func _redirect_case(seed_value: int, tough_hp: int, fragile_hp: int) -> Dictionary:
	var battle := BattleManager.new()
	battle.setup(seed_value, [_melee(), _sniper()])
	var foes := battle.living(false)
	var case := {
		"battle": battle,
		"controller": AIController.new(battle),
		"tough": foes[0],
		"fragile": foes[1],
		"threat": battle.living(true)[0],
	}
	case["tough"].stats["hp_max"] = tough_hp
	case["tough"].hp = tough_hp
	case["fragile"].stats["hp_max"] = fragile_hp
	case["fragile"].hp = fragile_hp
	# Nebeneinander -- _can_strike() rechnet ueber die Distanz.
	case["threat"].tile = Vector2i(5, 5)
	case["tough"].tile = Vector2i(5, 6)
	case["fragile"].tile = Vector2i(6, 5)
	return case


func _taunt_action() -> ActionData:
	var taunt := ActionData.new()
	taunt.id = &"act_test_taunt"
	taunt.category = ActionData.Category.ABILITY
	taunt.taunt_turns = 3
	return taunt


func test_a_tough_drome_redirects_and_a_fragile_one_does_not() -> void:
	# Der Kern der Bewertung: gerechnet wird in Lebensleisten, nicht in
	# Schadenspunkten. Wer selbst duenner ist als der, den er schuetzen
	# will, gewinnt nichts -- er verheizt sich nur.
	var case := _redirect_case(9114, 300, 30)
	var controller: AIController = case["controller"]

	var tough_score := controller._taunt_score(
		case["tough"], _taunt_action(), case["threat"])
	var fragile_score := controller._taunt_score(
		case["fragile"], _taunt_action(), case["threat"])

	t.ok(tough_score > 0.0,
		"das robuste Chassis lenkt den Angriff auf sich (%.1f)" % tough_score)
	t.equal(fragile_score, 0.0,
		"der duenne Gegner laesst es bleiben -- er ist selbst das gefaehrdetste Ziel")
	case["battle"].free()


func test_a_redirect_is_worthless_when_there_is_nobody_to_protect() -> void:
	var case := _redirect_case(9115, 300, 30)
	var controller: AIController = case["controller"]
	# Der Schuetzling ist ausser Reichweite: es gibt nichts umzulenken.
	case["fragile"].tile = Vector2i(19, 19)
	t.equal(controller._taunt_score(case["tough"], _taunt_action(), case["threat"]), 0.0,
		"wen niemand bedroht, den muss man auch nicht wegprovozieren")
	case["battle"].free()


func test_the_ai_does_not_renew_a_taunt_it_already_holds() -> void:
	# Sonst wird aus einer befristeten Zwangsmechanik eine dauerhafte.
	var case := _redirect_case(9116, 300, 30)
	var controller: AIController = case["controller"]
	var taunt := _taunt_action()

	t.ok(controller._action_score(case["tough"], taunt, case["threat"]) > 0.0,
		"ein freies Ziel zu provozieren ist etwas wert")
	case["threat"].apply_taunt(case["tough"].unit_id, 3)
	t.equal(controller._action_score(case["tough"], taunt, case["threat"]), 0.0,
		"ein bereits provoziertes Ziel erneut zu provozieren nicht")
	case["battle"].free()


func test_a_certain_kill_always_beats_the_best_possible_redirect() -> void:
	# Eine Invariante der Gewichte, kein Spielzustand: die Umlenkung ist nach
	# oben gedeckelt (hoechstens eine gerettete Lebensleiste plus der Bonus
	# fuers verhinderte Ausscheiden). Waere die Summe groesser als kill_bonus,
	# liefe die KI an sicheren Abschuessen vorbei, um jemanden umzulenken.
	var ai := Config.section("ai")
	var best_redirect: float = float(ai.get("taunt_weight", 50.0)) \
		+ float(ai.get("rescue_bonus", 45.0))
	t.ok(float(ai.get("kill_bonus", 100.0)) > best_redirect,
		"kill_bonus (%.0f) liegt ueber der bestmoeglichen Umlenkung (%.0f)"
		% [float(ai.get("kill_bonus", 100.0)), best_redirect])


# ---------------------------------------------------------------------------
# Begegnungslokal
# ---------------------------------------------------------------------------

func test_aggro_does_not_survive_its_target() -> void:
	var arena := _arena([
		{"build": _melee(), "tile": Vector2i(9, 8)},
		{"build": _melee(), "tile": Vector2i(8, 9)},
	], Vector2i(9, 9))
	var foe: Unit = arena["foe"]
	var gone: Unit = arena["units"][0]
	foe.aggro.add(gone.unit_id, 500.0)
	foe.aggro.current_target = gone.unit_id

	arena["resolver"].forget_unit(gone)
	t.equal(foe.aggro.value_of(gone.unit_id), 0.0,
		"der Eintrag eines gefallenen DROME verschwindet")
	t.equal(foe.aggro.current_target, null,
		"und das aktuelle Ziel wird geleert")
	_free(arena)


func test_scratches_are_dropped_instead_of_lingering_forever() -> void:
	var arena := _arena([{"build": _melee(), "tile": Vector2i(9, 8)}], Vector2i(9, 9))
	var foe: Unit = arena["foe"]
	foe.aggro.add(&"P0", 3.0)
	for _i in 20:
		foe.aggro.decay(0.15, 1.0)
	t.ok(foe.aggro.is_empty(),
		"ein Kratzer aus Zyklus 1 laeuft nicht ewig als Restposten mit")
	_free(arena)
