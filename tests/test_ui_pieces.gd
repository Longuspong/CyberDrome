extends RefCounted

## Die Teile der Kampf-UI, die eine Regel abbilden.
##
## Nicht das Aussehen -- das sagt tests/screenshot.gd. Hier steht, dass die
## Anzeige dasselbe meint wie die Mechanik: der TICK-Balken den Uebertrag,
## der Aktionsring die tatsaechlich moeglichen Aktionen.

var t


func _build(name: String, assignment: Dictionary) -> DromeBuild:
	return DromeBuild.create(name, assignment)


func _squad() -> Array:
	return [
		_build("ALPHA", {"body": &"scout_body", "head": &"scout_head",
			"feet": &"scout_feet", "core": &"scout_core",
			"equip_left": &"eq_pulse_blaster"}),
		_build("BETA", {"body": &"strix_body", "head": &"strix_head",
			"feet": &"strix_feet", "core": &"strix_core",
			"equip_center": &"eq_rail_lance"}),
	]


func test_bar_state_reports_the_carry() -> void:
	# Der Balken zeigt den Uebertrag als eigenes Segment. Die Zahl dahinter
	# kommt aus dem TICK-Bus, nicht aus der UI -- sonst koennten Balken und
	# Queue auseinanderlaufen.
	var bus := TickBus.new(100)
	bus.add_unit(&"fast", 14)
	var actor = bus.advance()
	var before := bus.bar_state(actor)
	t.equal(before["tick"], 112, "8 Ticks x 14")
	t.equal(before["carry"], 12, "der Ueberschuss ueber die Schwelle")
	t.equal(before["fill"], 1.0, "der Balken steht voll")

	bus.finish_turn(actor)
	var after := bus.bar_state(actor)
	t.equal(after["tick"], 12, "nach dem Zug bleibt der Uebertrag stehen")
	t.equal(after["carry"], 0, "und ist kein Ueberschuss mehr, sondern Vorsprung")


func test_bar_state_never_disagrees_with_the_queue() -> void:
	# Massgeblich ist die Queue. Widersprechen sich beide, hat der Balken den
	# Fehler -- also wird hier festgehalten, dass sie sich nicht widersprechen.
	var bus := TickBus.new(100)
	bus.add_unit(&"a", 7)
	bus.add_unit(&"b", 10)
	bus.add_unit(&"c", 14)
	for _turn in 12:
		var next = bus.advance()
		var highest = null
		var best := -1
		for entry in bus.living():
			var state := bus.bar_state(entry.unit_id)
			if state["tick"] > best:
				best = state["tick"]
				highest = entry.unit_id
		t.equal(str(next), str(highest),
			"der vollste Balken gehoert dem, der als Naechstes zieht")
		bus.finish_turn(next)


func test_the_action_ring_offers_exactly_what_is_allowed() -> void:
	# Der Ring trifft keine Entscheidung -- er zeigt, was der BattleManager
	# erlaubt. Geprueft wird deshalb die Quelle, aus der er sich bedient.
	var battle := BattleManager.new()
	battle.setup(31337, _squad())
	var actor := battle.begin_next_turn()
	t.ok(actor != null, "es zieht jemand")

	var foe: Unit = battle.enemies_of(actor)[0]
	var offered := 0
	var refused := 0
	for action in actor.actions():
		var reason := battle.turn_state.blocker_for(action)
		if reason == "":
			reason = battle.resolver.target_blocker(actor, foe.tile, action)
		if reason == "":
			offered += 1
		else:
			refused += 1
			t.ok(reason.length() > 0,
				"eine abgelehnte Aktion nennt immer einen Grund")
	t.ok(offered + refused == actor.actions().size(),
		"jede Aktion wird entweder angeboten oder begruendet abgelehnt")
	battle.free()


func test_blocker_texts_are_readable() -> void:
	# Die Gruende landen unveraendert im Tooltip. Ein Grund wie "false" waere
	# im Taktikspiel wertlos.
	var battle := BattleManager.new()
	battle.setup(4242, _squad())
	var actor := battle.begin_next_turn()
	var foe: Unit = battle.enemies_of(actor)[0]

	# Ausser Reichweite: die Squads starten in gegenueberliegenden Ecken.
	for action in actor.actions():
		var reason := battle.resolver.target_blocker(actor, foe.tile, action)
		if reason != "":
			t.ok(reason != "false" and reason.length() > 5,
				"Grund ist lesbar: '%s'" % reason)
	battle.free()


func test_energy_shortfall_is_named_with_numbers() -> void:
	var battle := BattleManager.new()
	battle.setup(99, _squad())
	var actor := battle.begin_next_turn()
	actor.en = 0
	var expensive: ActionData = null
	for action in actor.actions():
		if action.en_cost > 0:
			expensive = action
	if expensive != null:
		var reason := battle.turn_state.blocker_for(expensive)
		t.ok(reason.begins_with("Energie:"),
			"fehlende Energie wird mit Zahlen genannt: '%s'" % reason)
	battle.free()


# ---------------------------------------------------------------------------
# Was der Ring anbietet und was die Karte dazu schreibt
# ---------------------------------------------------------------------------

func test_the_ring_never_offers_a_pointless_target() -> void:
	# Regeltechnisch darf ein Angriff auf den eigenen DROME gehen -- die
	# Mitigationskette fragt nicht nach Seiten. Angeboten wird er trotzdem
	# nicht, und die Schadensvorschau auf der Karte muss dieselbe Antwort
	# geben: sonst stuende ueber dem eigenen Techniker eine Zahl, die wie eine
	# Drohung aussieht. Deshalb gibt es die Regel genau einmal.
	var battle := BattleManager.new()
	battle.setup(2024, _squad())
	var actor := battle.begin_next_turn()
	var ally: Unit = null
	for other in battle.allies_of(actor):
		if other != actor:
			ally = other
	var foe: Unit = battle.enemies_of(actor)[0]

	for action in actor.actions():
		var hits_foe := battle.resolver.is_meaningful_target(actor, foe, action)
		t.equal(hits_foe, not action.is_heal(),
			"%s zielt auf Gegner, wenn sie Schaden macht" % action.id)
		if ally != null:
			var hits_ally := battle.resolver.is_meaningful_target(actor, ally, action)
			t.equal(hits_ally, action.is_heal(),
				"%s zielt auf Verbuendete nur, wenn sie repariert" % action.id)
	battle.free()


func test_an_action_without_damage_previews_no_damage() -> void:
	# Der Orbit-Sog zieht sein Ziel zwei Felder und richtet nichts an --
	# execute() wendet Schaden nur bei power > 0 an. Die Vorschau rechnete
	# trotzdem max(1, 0 + atk - def) und schrieb "1 Schaden" ueber ein Ziel,
	# dem nichts passiert. Genau die Zahl stand im Aktionsring.
	var grid := Grid.new(8, 8)
	grid.fill(Terrain.TClass.NORMAL)
	var mage := DromeBuild.create("MAGIER", {
		"body": &"mage_body", "head": &"mage_head",
		"feet": &"mage_drive", "core": &"mage_core",
		"equip_left": &"eq_rune_staff", "equip_right": &"eq_orbit_focus"})
	var caster := Unit.create(mage, &"P0", true)
	var victim := Unit.create(mage, &"E0", false)
	caster.tile = Vector2i(2, 2)
	victim.tile = Vector2i(4, 2)
	var resolver := ActionResolver.new(grid, [caster, victim])

	for action in caster.actions():
		var preview := resolver.preview_damage(caster, victim, action)
		if action.power > 0:
			t.ok(preview > 0, "%s verspricht Schaden und macht welchen" % action.id)
		else:
			t.equal(preview, 0,
				"%s verspricht keinen Schaden, weil sie keinen anrichtet" % action.id)
			t.ok(action.effect_summary() != "",
				"stattdessen steht dort, was sie tut: '%s'"
				% action.effect_summary())

	caster.free()
	victim.free()


func test_budgets_are_reported_per_category() -> void:
	# Die Aktionsleiste schreibt die Zahl ueber die Gruppe: "Angriff (0)" sagt
	# in einem Blick, was "Angriff verbraucht" erst nach dem Hovern verraet.
	var battle := BattleManager.new()
	battle.setup(777, _squad())
	var actor := battle.begin_next_turn()
	var state := battle.turn_state
	t.equal(state.actions_left(ActionData.Category.ATTACK), 1, "ein Angriff je Zug")
	t.equal(state.actions_left(ActionData.Category.ABILITY), 1, "eine Faehigkeit je Zug")

	var attack: ActionData = null
	for action in actor.actions():
		if action.is_attack():
			attack = action
	if attack != null:
		state.consume(attack)
		t.equal(state.actions_left(ActionData.Category.ATTACK), 0,
			"nach dem Angriff ist das Angriffsbudget leer")
		t.equal(state.actions_left(ActionData.Category.ABILITY), 1,
			"das Faehigkeitsbudget ist davon unberuehrt")
	battle.free()


func test_every_action_offers_a_readable_description() -> void:
	# Die Beschreibung steht an genau einer Stelle (ActionData) und wird von
	# Werkstatt, Aktionsleiste und Ring gelesen. Drei Texte fuer dieselbe
	# Aktion waeren drei Gelegenheiten, dass einer eine Reichweite nennt, die
	# nicht mehr stimmt.
	for part in PartDB.parts.values():
		if part.action == null:
			continue
		var lines: Array[String] = part.action.description_lines()
		t.ok(lines.size() >= 3, "%s wird in mehr als einer Zeile erklaert"
			% part.action.id)
		t.ok(part.action.headline().contains("Rw"),
			"die Kurzform nennt die Reichweite: '%s'" % part.action.headline())
		t.ok("\n".join(lines).contains(part.display_name),
			"%s nennt das Bauteil, aus dem sie kommt" % part.action.id)
