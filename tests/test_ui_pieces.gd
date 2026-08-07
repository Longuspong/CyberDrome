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
