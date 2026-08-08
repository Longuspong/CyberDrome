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

func test_the_incumbent_is_exempt_from_decay() -> void:
	var arena := _arena([
		{"build": _melee(), "tile": Vector2i(9, 8)},
		{"build": _melee(), "tile": Vector2i(8, 9)},
	], Vector2i(9, 9))
	var foe: Unit = arena["foe"]
	foe.aggro.add(&"P0", 100.0)
	foe.aggro.add(&"P1", 101.0)
	foe.aggro.current_target = &"P0"

	for _i in 10:
		foe.aggro.decay(0.15, 1.0)

	t.ok(foe.aggro.value_of(&"P0") > foe.aggro.value_of(&"P1"),
		"das aktuelle Ziel verliert keinen Boden, waehrend andere abbauen (%.1f vs %.1f)"
		% [foe.aggro.value_of(&"P0"), foe.aggro.value_of(&"P1")])
	t.equal(foe.aggro.value_of(&"P0"), 100.0,
		"und zwar unveraendert -- der Amtsinhaber ist ausgenommen")
	_free(arena)


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
