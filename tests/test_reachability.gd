extends RefCounted

## M4b: der verbindliche Test aus dem Entwurf.
##
## Fuer JEDES Feld aus reachable_tiles(): den Zug tatsaechlich ausfuehren und
## pruefen, dass der DROME exakt auf diesem Feld steht und exakt die
## vorhergesagten Bewegungspunkte uebrig hat. Ueber viele zufaellige Karten mit
## allen Antriebstypen. Kein einziger Fehlschlag ist akzeptabel.
##
## Der Test existiert, weil die Vorschau und die Ausfuehrung sonst
## auseinanderlaufen -- und der Bug, bei dem der DROME woanders landet als die
## blaue Markierung versprochen hat, zerstoert das Vertrauen in ein
## Taktikspiel schneller als jeder Absturz.

var t

const MAPS := 200
const GRID := 12
const MP := 6


## Die sechs Traversierungsprofile des Entwurfs. Vier davon tragen Antriebe
## des Bestands, zwei sind Reserve fuer spaetere Teile -- der Algorithmus muss
## sie trotzdem korrekt behandeln.
func _profiles() -> Array:
	var out: Array = []
	for spec in [
		{"name": "Rad (keine Flags)", "flags": {}},
		{"name": "Ketten", "flags": {"ignores_drift": true}},
		{"name": "Schweber", "flags": {"can_enter_steps": true, "drift_modifier": 1}},
		{"name": "Kletterbeine", "flags": {"can_enter_steps": true,
			"ignores_drift": true, "step_cost_reduced": true}},
		{"name": "Sprung-Servos", "flags": {"can_pass_units": true,
			"can_enter_steps": true}},
		{"name": "Phasenlaeufer", "flags": {"can_pass_units": true,
			"can_enter_steps": true, "ignores_drift": true}},
	]:
		var profile := MoveProfile.from_stats(spec["flags"], &"hero")
		out.append({"name": spec["name"], "profile": profile})
	return out


## Zufallskarte mit allen fuenf Klassen, gerichteter und ungerichteter Drift.
func _random_grid(rng: RandomNumberGenerator) -> Grid:
	var grid := Grid.new(GRID, GRID)
	for tile in grid.all_tiles():
		var roll := rng.randf()
		if roll < 0.10:
			grid.set_terrain_class(tile, Terrain.TClass.BLOCK)
		elif roll < 0.22:
			grid.set_terrain_class(tile, Terrain.TClass.STEP)
		elif roll < 0.40:
			grid.set_terrain_class(tile, Terrain.TClass.DRIFT)
			# Ein Drittel der Drift-Felder gerichtet -- Foerderband und
			# Schlitterflaeche muessen durch denselben Code laufen.
			if rng.randf() < 0.33:
				var dirs := Grid.directions()
				grid.set_flow_direction(tile, dirs[rng.randi() % dirs.size()])
		elif roll < 0.50:
			grid.set_terrain_class(tile, Terrain.TClass.HAZE)
	return grid


## Setzt ein paar fremde Einheiten, damit can_pass_units und das Abprallen
## beim Gleiten ueberhaupt gepruefte Faelle sind.
func _populate(grid: Grid, rng: RandomNumberGenerator, exclude: Vector2i) -> void:
	for i in 6:
		var tile := Vector2i(rng.randi_range(0, GRID - 1), rng.randi_range(0, GRID - 1))
		if tile == exclude:
			continue
		grid.set_occupant(tile, StringName("foe%d" % i))


## Fuehrt den vorhergesagten Zug Schritt fuer Schritt wirklich aus.
##
## Bewusst OHNE Blick auf den Eintrag: die Ausfuehrung laeuft nur ueber
## ``path`` und rechnet Kosten und Gleiten selbst nach. Wuerde sie das
## Ergebnis aus der Vorhersage uebernehmen, prueefte der Test sich selbst.
func _execute(grid: Grid, profile: MoveProfile, path: Array) -> Dictionary:
	var pos: Vector2i = profile.tile
	var spent := 0
	for i in range(1, path.size()):
		var step: Vector2i = path[i]
		var dir: Vector2i = step - pos
		if not grid.can_traverse(step, profile):
			return {"ok": false, "why": "Schritt auf %s nicht erlaubt" % step}
		spent += grid.terrain_cost(step, profile)
		var landing := grid.simulate_drift(step, dir, profile)
		if not grid.can_stand_on(landing, profile):
			return {"ok": false, "why": "Landefeld %s nicht betretbar" % landing}
		pos = landing
	return {"ok": true, "tile": pos, "spent": spent}


func test_every_predicted_landing_is_actually_reached() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260806

	var checked := 0
	var failures := 0
	var first_failure := ""

	for map_index in MAPS:
		var grid := _random_grid(rng)
		for entry in _profiles():
			var profile: MoveProfile = entry["profile"]
			# Startfeld suchen, auf dem dieses Profil ueberhaupt stehen kann.
			var start := Vector2i(-1, -1)
			for _try in 40:
				var candidate := Vector2i(rng.randi_range(0, GRID - 1),
					rng.randi_range(0, GRID - 1))
				if grid.can_stand_on(candidate, profile):
					start = candidate
					break
			if start.x < 0:
				continue

			var work := grid.duplicate_grid()
			_populate(work, rng, start)
			profile.tile = start
			work.set_occupant(start, profile.unit_id)

			var reachable := work.reachable_tiles(profile, MP)
			for landing in reachable:
				var predicted: Dictionary = reachable[landing]
				var result := _execute(work, profile, predicted["path"])
				checked += 1

				var problem := ""
				if not result["ok"]:
					problem = result["why"]
				elif result["tile"] != landing:
					problem = "vorhergesagt %s, tatsaechlich %s" % [landing, result["tile"]]
				elif MP - result["spent"] != predicted["mp_left"]:
					problem = "MP vorhergesagt %d, tatsaechlich %d" % [
						predicted["mp_left"], MP - result["spent"]]

				if problem != "":
					failures += 1
					if first_failure == "":
						first_failure = "Karte %d, %s, Start %s: %s" % [
							map_index, entry["name"], start, problem]

	t.ok(failures == 0, "%d von %d Vorhersagen falsch. Erste: %s"
		% [failures, checked, first_failure])
	t.note("%d Karten x %d Antriebe: %d Vorhersagen geprueft, %d falsch"
		% [MAPS, _profiles().size(), checked, failures])


func test_landing_is_never_on_block_or_occupied() -> void:
	# Traversierung erlaubt das Durchziehen, nicht das Landen.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var violations := 0
	for _map in 40:
		var grid := _random_grid(rng)
		for entry in _profiles():
			var profile: MoveProfile = entry["profile"]
			var start := Vector2i(-1, -1)
			for _try in 40:
				var candidate := Vector2i(rng.randi_range(0, GRID - 1),
					rng.randi_range(0, GRID - 1))
				if grid.can_stand_on(candidate, profile):
					start = candidate
					break
			if start.x < 0:
				continue
			_populate(grid, rng, start)
			profile.tile = start
			grid.set_occupant(start, profile.unit_id)
			for landing in grid.reachable_tiles(profile, MP):
				if grid.terrain_class(landing) == Terrain.TClass.BLOCK:
					violations += 1
				if grid.is_occupied(landing, profile.unit_id):
					violations += 1
	t.equal(violations, 0, "kein Zug endet auf BLOCK oder einem besetzten Feld")


func test_drift_is_one_implementation() -> void:
	# Vorschau und Ausfuehrung MUESSEN dieselbe Funktion benutzen. Der Test
	# haelt fest, dass drift_result() rein ist: zweimal aufgerufen, zweimal
	# dasselbe, und der Spielzustand unveraendert.
	var grid := Grid.new(8, 8)
	for x in range(2, 6):
		grid.set_terrain_class(Vector2i(x, 3), Terrain.TClass.DRIFT)
	var profile := MoveProfile.from_stats({}, &"hero")

	var first := grid.drift_result(Vector2i(2, 3), Vector2i(1, 0), profile)
	var second := grid.drift_result(Vector2i(2, 3), Vector2i(1, 0), profile)
	t.equal(first["tile"], second["tile"], "drift_result ist deterministisch")
	t.equal(first["tile"], Vector2i(6, 3), "gleitet durch die Zone bis dahinter")
	t.equal(grid.occupant(Vector2i(6, 3)), null,
		"drift_result veraendert den Spielzustand nicht")


func test_directed_drift_overrides_running_direction() -> void:
	var grid := Grid.new(8, 8)
	for x in range(2, 6):
		grid.set_terrain_class(Vector2i(x, 3), Terrain.TClass.DRIFT)
		grid.set_flow_direction(Vector2i(x, 3), Vector2i(0, 1))
	var profile := MoveProfile.from_stats({}, &"hero")
	# Betritt nach rechts laufend, wird aber nach unten geschoben.
	var result := grid.drift_result(Vector2i(3, 3), Vector2i(1, 0), profile)
	t.equal(result["tile"], Vector2i(3, 4), "das Foerderband gewinnt gegen die Laufrichtung")


func test_ignores_drift_stands_still() -> void:
	var grid := Grid.new(8, 8)
	for x in range(2, 6):
		grid.set_terrain_class(Vector2i(x, 3), Terrain.TClass.DRIFT)
	var tracks := MoveProfile.from_stats({"ignores_drift": true}, &"tracks")
	t.equal(grid.simulate_drift(Vector2i(3, 3), Vector2i(1, 0), tracks), Vector2i(3, 3),
		"der Ketten-Antrieb steht auf Drift wie festgenagelt")


func test_drift_modifier_only_after_leaving_the_zone() -> void:
	var grid := Grid.new(10, 10)
	for x in range(2, 5):
		grid.set_terrain_class(Vector2i(x, 3), Terrain.TClass.DRIFT)
	var hover := MoveProfile.from_stats({"drift_modifier": 1}, &"hover")
	# Regulaer verlassen: ein Feld weiter als der Rest.
	t.equal(grid.simulate_drift(Vector2i(2, 3), Vector2i(1, 0), hover), Vector2i(6, 3),
		"Schweber rutscht ein Feld weiter, wenn er die Zone regulaer verlaesst")

	# Gegen eine Wand gerutscht: kein Extraschritt.
	var walled := Grid.new(10, 10)
	for x in range(2, 5):
		walled.set_terrain_class(Vector2i(x, 3), Terrain.TClass.DRIFT)
	walled.set_terrain_class(Vector2i(5, 3), Terrain.TClass.BLOCK)
	t.equal(walled.simulate_drift(Vector2i(2, 3), Vector2i(1, 0), hover), Vector2i(4, 3),
		"wer gegen eine Wand rutscht, rutscht nicht noch weiter hinein")


func test_sliding_does_not_pass_through_units() -> void:
	var grid := Grid.new(8, 8)
	for x in range(2, 6):
		grid.set_terrain_class(Vector2i(x, 3), Terrain.TClass.DRIFT)
	grid.set_occupant(Vector2i(4, 3), &"blocker")
	# can_pass_units hilft beim Gleiten ausdruecklich nicht: man prallt ab.
	var jumper := MoveProfile.from_stats({"can_pass_units": true}, &"hero")
	t.equal(grid.simulate_drift(Vector2i(2, 3), Vector2i(1, 0), jumper), Vector2i(3, 3),
		"man rutscht nicht durch einen anderen DROME hindurch")


func test_a_tile_can_be_unreachable_although_adjacent() -> void:
	# Jeder Weg dorthin fuehrt ueber Drift, und man wird vorbeigeschoben.
	# Ein radiusbasierter Ansatz liefert das falsch, dieser Algorithmus nicht.
	var grid := Grid.new(9, 9)
	var start := Vector2i(4, 4)
	for dir in Grid.directions():
		grid.set_terrain_class(start + dir, Terrain.TClass.DRIFT)
	var profile := MoveProfile.from_stats({}, &"hero")
	profile.tile = start
	grid.set_occupant(start, profile.unit_id)

	var reachable := grid.reachable_tiles(profile, 1)
	for dir in Grid.directions():
		t.ok(not reachable.has(start + dir),
			"das Drift-Nachbarfeld %s ist kein Landefeld" % (start + dir))
	t.ok(reachable.size() > 0, "aber die Felder dahinter sind erreichbar")
