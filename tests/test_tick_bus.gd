extends RefCounted

## M3: Initiative, Zyklus-Logik, Gleichstandsregeln, Vorschau.

var t


func _bus(spds: Dictionary) -> TickBus:
	var bus := TickBus.new(100)
	var keys := spds.keys()
	keys.sort()
	for unit_id in keys:
		bus.add_unit(unit_id, spds[unit_id])
	return bus


## Spielt ``turns`` Zuege und protokolliert die Reihenfolge.
##
## Gibt Strings zurueck, nicht StringNames: ein Array-Vergleich in GDScript
## haelt &"fast" und "fast" auseinander, und ein Test, der an dieser Stelle
## scheitert, sagt nichts ueber den TICK-Bus aus.
func _play(bus: TickBus, turns: int) -> Array[String]:
	var order: Array[String] = []
	for _i in turns:
		var actor = bus.advance()
		if actor == null:
			break
		order.append(str(actor))
		bus.finish_turn(actor)
	return order


func test_faster_unit_acts_more_often() -> void:
	var bus := _bus({&"slow": 7, &"mid": 10, &"fast": 14})
	var order := _play(bus, 31)

	var counts := {&"slow": 0, &"mid": 0, &"fast": 0}
	for actor in order:
		counts[StringName(actor)] += 1
	t.ok(counts[&"fast"] > counts[&"mid"], "SPD 14 zieht oefter als SPD 10 (%d vs %d)"
		% [counts[&"fast"], counts[&"mid"]])
	t.ok(counts[&"mid"] > counts[&"slow"], "SPD 10 zieht oefter als SPD 7 (%d vs %d)"
		% [counts[&"mid"], counts[&"slow"]])
	t.note("31 Zuege: fast %d, mid %d, slow %d"
		% [counts[&"fast"], counts[&"mid"], counts[&"slow"]])


func test_carry_lets_the_fast_unit_cut_back_in() -> void:
	# Nachgerechnet mit SPD 7/10/14 und Schwelle 100:
	#   8 Ticks -> 56 / 80 / 112. fast zieht, behaelt 12 Uebertrag.
	#   2 Ticks -> 70 / 100 /  40. mid zieht, behaelt 0.
	#   5 Ticks -> 105 / 50 / 110. fast zieht ERNEUT, obwohl slow laengst
	#                              ueber der Schwelle steht.
	# Genau dafuer ist der Uebertrag da: ohne ihn stuende fast hier bei 70
	# und slow kaeme dran. Der dritte Zug ist der eigentliche Beweis.
	var bus := _bus({&"slow": 7, &"mid": 10, &"fast": 14})
	var order := _play(bus, 3)
	t.equal(order, ["fast", "mid", "fast"] as Array[String],
		"der Uebertrag laesst den Schnellsten vor dem Langsamsten erneut ziehen")


func test_ticks_survive_the_cycle_end() -> void:
	# Der Kern der Mechanik: das Zyklusende setzt NUR die Flags zurueck.
	var bus := _bus({&"a": 7, &"b": 10, &"c": 14})
	var before_cycle := bus.cycle_count

	var closed := false
	var guard := 0
	while not closed and guard < 20:
		guard += 1
		var actor = bus.advance()
		closed = bus.finish_turn(actor)

	t.equal(bus.cycle_count, before_cycle + 1, "der Zyklus ist weitergezaehlt")

	var carried := false
	for entry in bus.living():
		t.ok(not entry.has_acted, "%s: Flag ist zurueckgesetzt" % entry.unit_id)
		if entry.tick != 0:
			carried = true
	t.ok(carried, "mindestens ein tick-Wert hat das Zyklusende ueberlebt")


func test_overflow_is_carried_not_discarded() -> void:
	# SPD 14 fuellt in 8 Ticks auf 112. Nach dem Zug muessen 12 stehen
	# bleiben, nicht 0 -- das ist der Grund, warum SPD sich lohnt.
	var bus := _bus({&"fast": 14})
	var actor = bus.advance()
	t.equal(bus.tick_of(actor), 112, "8 Ticks x 14 = 112")
	bus.finish_turn(actor)
	t.equal(bus.tick_of(actor), 12, "der Ueberschuss wird uebertragen")


func test_tie_is_broken_by_pending_turn_then_spd_then_id() -> void:
	var bus := TickBus.new(100)
	bus.add_unit(&"b_slow", 10)
	bus.add_unit(&"a_fast", 20)
	# Gleichstand herstellen, aber a_fast hat in diesem Zyklus schon gezogen.
	bus.entry_for(&"b_slow").tick = 100
	bus.entry_for(&"a_fast").tick = 100
	bus.entry_for(&"a_fast").has_acted = true
	t.equal(bus.advance(), &"b_slow",
		"wer noch nicht gezogen hat, geht vor -- auch gegen hoeheres SPD")

	# Gleichstand ohne diesen Unterschied: hoeheres SPD gewinnt.
	var bus2 := TickBus.new(100)
	bus2.add_unit(&"b_slow", 10)
	bus2.add_unit(&"a_fast", 20)
	bus2.entry_for(&"b_slow").tick = 100
	bus2.entry_for(&"a_fast").tick = 100
	t.equal(bus2.advance(), &"a_fast", "bei Gleichstand gewinnt hoeheres SPD")

	# Auch SPD gleich: die kleinere unit_id, stabil.
	var bus3 := TickBus.new(100)
	bus3.add_unit(&"zeta", 10)
	bus3.add_unit(&"alpha", 10)
	bus3.entry_for(&"zeta").tick = 100
	bus3.entry_for(&"alpha").tick = 100
	t.equal(bus3.advance(), &"alpha", "zuletzt entscheidet die unit_id, stabil")


func test_turn_order_shifts_between_cycles() -> void:
	# Die Zugreihenfolge soll sich von Zyklus zu Zyklus verschieben, weil die
	# tick-Werte weiterlaufen. Ein Akzeptanzkriterium des MVP.
	var bus := _bus({&"a": 7, &"b": 10, &"c": 14})
	var cycles: Array = []
	var current: Array = []
	for _i in 40:
		var actor = bus.advance()
		current.append(actor)
		if bus.finish_turn(actor):
			cycles.append(current)
			current = []
		if cycles.size() >= 4:
			break

	var distinct := {}
	for cycle in cycles:
		distinct[str(cycle)] = true
	t.ok(distinct.size() > 1,
		"die Zugreihenfolge unterscheidet sich zwischen Zyklen: %s" % str(cycles))


func test_preview_does_not_touch_the_real_state() -> void:
	var bus := _bus({&"a": 7, &"b": 10, &"c": 14})
	var before: Array = []
	for entry in bus.living():
		before.append([entry.unit_id, entry.tick, entry.has_acted])
	var cycle_before := bus.cycle_count

	var order := bus.preview(8)

	var after: Array = []
	for entry in bus.living():
		after.append([entry.unit_id, entry.tick, entry.has_acted])
	t.equal(after, before, "die Vorschau veraendert die tick-Werte nicht")
	t.equal(bus.cycle_count, cycle_before, "die Vorschau zaehlt keinen Zyklus weiter")
	t.equal(order.size(), 8, "acht Zuege Vorschau")


func test_preview_matches_what_actually_happens() -> void:
	var bus := _bus({&"a": 7, &"b": 10, &"c": 14})
	var predicted: Array[String] = []
	for unit_id in bus.preview(8):
		predicted.append(str(unit_id))
	var actual := _play(bus, 8)
	t.equal(actual, predicted,
		"die Vorschau sagt genau das voraus, was dann passiert")


func test_dead_units_drop_out() -> void:
	var bus := _bus({&"a": 10, &"b": 10, &"c": 10})
	bus.set_alive(&"b", false)
	var order := _play(bus, 6)
	t.ok(not ("b" in order), "ein toter DROME zieht nicht mehr")


func test_cycle_ends_although_the_fast_unit_acted_twice() -> void:
	# Ein schneller DROME kann innerhalb eines Zyklus mehrfach ziehen, weil
	# der Zyklus erst endet, wenn auch der langsamste einmal dran war.
	var bus := _bus({&"slow": 4, &"fast": 20})
	var seen := {&"slow": 0, &"fast": 0}
	var closed := false
	var guard := 0
	while not closed and guard < 30:
		guard += 1
		var actor = bus.advance()
		seen[StringName(actor)] += 1
		closed = bus.finish_turn(actor)
	t.ok(seen[&"fast"] > 1, "der schnelle DROME zog mehrfach im selben Zyklus (%dx)"
		% seen[&"fast"])
	t.equal(seen[&"slow"], 1, "der langsame genau einmal -- er schliesst den Zyklus")


func test_add_tick_moves_the_preview() -> void:
	# Overdrive: +50 TICK sofort. Die Vorschau muss sich sichtbar aendern.
	var bus := _bus({&"a": 10, &"b": 10, &"c": 10})
	var before := bus.preview(8)
	bus.add_tick(&"c", 50)
	var after := bus.preview(8)
	t.ok(before != after, "Overdrive verschiebt die Vorschau sichtbar")
	t.equal(after[0], &"c", "der angeschobene DROME zieht als Naechstes")


func test_never_hangs_on_zero_or_negative_spd() -> void:
	# Der Virus-Injektor kann SPD unter null druecken. Das darf die Schleife
	# nicht anhalten.
	# MIN_EFFECTIVE_SPD ist 1, also braucht der gebremste DROME 100 Ticks fuer
	# einen Zug, waehrend der normale alle 10 Ticks zieht. Nach 12 Zuegen muss
	# er einmal dabei gewesen sein -- vorher waere es kein Beweis.
	var bus := _bus({&"crippled": -5, &"normal": 10})
	var order := _play(bus, 12)
	t.equal(order.size(), 12, "die Schleife laeuft auch mit negativem SPD weiter")
	t.ok("crippled" in order, "der gebremste DROME kommt trotzdem irgendwann dran")
