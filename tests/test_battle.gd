extends RefCounted

## M4/M8/M9: der Kampf als Ganzes.
##
## Spielt vollstaendige Kaempfe ohne Szene und ohne Eingabe -- beide Seiten
## von der KI gesteuert. Was hier durchlaeuft, laeuft auch mit einem Spieler
## davor; was hier haengt oder abstuerzt, wuerde im Spiel genauso haengen,
## nur schwerer zu finden.

var t

func _squad() -> Array:
	return [
		DromeBuild.create("ALPHA", {
			"body": &"scout_body", "head": &"scout_head",
			"feet": &"scout_feet", "core": &"scout_core",
			"equip_left": &"eq_pulse_blaster"}),
		DromeBuild.create("BETA", {
			"body": &"strix_body", "head": &"strix_head",
			"feet": &"strix_feet", "core": &"strix_core",
			"equip_center": &"eq_rail_lance"}),
	]


## Spielt einen Kampf zu Ende (Echtzeit, ohne Bildschirm). Gibt die
## Zusammenfassung zurueck.
func _play(seed_value: int) -> Dictionary:
	var battle := BattleManager.new()
	battle.setup(seed_value, _squad())
	battle.run_to_end()
	var result := battle.build_result()
	battle.free()
	return result


func test_a_battle_runs_to_a_conclusion() -> void:
	var outcomes := {}
	var total := 0
	for i in 25:
		var result := _play(4000 + i)
		total += int(result["seconds"])
		t.ok(result["outcome"] != BattleManager.Outcome.RUNNING,
			"Kampf %d endet (nach %d s)" % [4000 + i, result["seconds"]])
		var label := BattleManager.outcome_label(result["outcome"])
		outcomes[label] = outcomes.get(label, 0) + 1
	t.note("25 Kaempfe, im Schnitt %.0f s: %s"
		% [float(total) / 25.0, str(outcomes)])


func test_both_sides_can_win() -> void:
	# Eine KI, die nie gewinnt oder nie verliert, ist entweder kaputt oder
	# das Matching ist es.
	var seen := {}
	for i in 40:
		var result := _play(9000 + i)
		seen[BattleManager.outcome_label(result["outcome"])] = true
	t.ok(seen.size() > 1,
		"nicht jeder Kampf endet gleich: %s" % str(seen.keys()))


func test_damage_actually_happens() -> void:
	var result := _play(1234)
	var dealt := 0
	for row in result["units"]:
		dealt += row["dealt"]
	t.ok(dealt > 0, "im Kampf wurde Schaden verursacht (%d)" % dealt)


## Zwei Molok-Aufbauten, die sich nur in der Waffe unterscheiden -- und beide
## tragen den Orbit-Sog am rechten Halter. Damit haengt der Unterschied im
## Verhalten allein an der Reichweite, so wie die Bewertung es behauptet.
func _with_orbit_pull(display_name: String, weapon: StringName) -> DromeBuild:
	return DromeBuild.create(display_name, {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": weapon, "equip_right": &"eq_orbit_focus"})


func _pull_action(unit: Unit) -> ActionData:
	for action in unit.actions():
		if action.push_tiles != 0:
			return action
	return null


func test_the_ai_does_not_drag_its_target_into_its_own_face() -> void:
	# Der Orbit-Sog hat Staerke 0 und wurde ueber preview_damage() bewertet --
	# das liefert die Mindestmenge 1. Zusammen mit dem Faehigkeitsbudget, das
	# ein Angriffs-Aufbau ohnehin nicht braucht, hat die KI ihn jeden Zug
	# gezogen und sich als Fernkaempfer selbst den Abstand genommen.
	var battle := BattleManager.new()
	battle.setup(9210, [_with_orbit_pull("SCHUETZE", &"eq_rail_lance"),
		_with_orbit_pull("NAHKAMPF", &"eq_rune_staff")])
	var controller := AIController.new(battle)
	var sniper: Unit = battle.living(true)[0]
	var brawler: Unit = battle.living(true)[1]
	sniper.tile = Vector2i(4, 4)
	brawler.tile = Vector2i(4, 8)

	var pull := _pull_action(sniper)
	t.ok(pull != null and pull.power <= 0,
		"der Orbit-Sog zieht und richtet dabei keinen Schaden an")

	t.ok(controller._shove_score(sniper, pull, brawler) < 0.0,
		"wer weiter schiesst, will den Abstand behalten (%.1f)"
		% controller._shove_score(sniper, pull, brawler))
	t.ok(controller._action_score(sniper, pull, brawler) <= 0.0,
		"und zieht deshalb gar nicht -- _best_move() verwirft alles <= 0")

	t.ok(controller._shove_score(brawler, pull, sniper) > 0.0,
		"wer kuerzer schiesst, will ihn schliessen (%.1f)"
		% controller._shove_score(brawler, pull, sniper))
	battle.free()


func test_armour_can_never_swallow_a_whole_hit() -> void:
	# Der schwerste im Bestand baubare Aufbau gegen die schwaechste Waffe:
	# DEF 14 (Chassis 5 + Bunkerkopf 2 + Standbeine 2 + Deflektor 5) gegen den
	# Puls-Blaster. Ueber den flachen Abzug blieb davon die Mindestmenge 1 --
	# 145 Integritaet bei 1 Schaden je Treffer sind 145 Treffer.
	var bunker := DromeBuild.create("BUNKER", {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": &"eq_pulse_blaster", "equip_right": &"eq_deflector"})
	t.ok(bunker.is_valid(), "der Bunker ist baubar: %s" % ", ".join(bunker.validate()))
	t.equal(bunker.stats()["def"], 14, "und kommt auf DEF 14")

	var grid := Grid.new(10, 10)
	var shooter := Unit.create(_squad()[0], &"P0", true)
	var wall := Unit.create(bunker, &"E0", false)
	shooter.tile = Vector2i(2, 2)
	wall.tile = Vector2i(4, 2)
	# Geprueft wird die Panzerung, nicht der Energieschild davor.
	wall.shield = 0
	var resolver := ActionResolver.new(grid, [shooter, wall])

	var blaster: ActionData = null
	for action in shooter.actions():
		if action.is_attack():
			blaster = action
	var dealt := resolver.preview_damage(shooter, wall, blaster)

	t.ok(dealt >= int(ceil(blaster.power * 0.5)),
		"DEF nimmt hoechstens die Haelfte weg: %d von %d" % [dealt, blaster.power])
	var hits := int(ceil(float(wall.stat("hp_max")) / float(dealt)))
	t.ok(hits <= 30,
		"und der Bunker faellt in absehbarer Zeit (%d Treffer)" % hits)
	t.equal(resolver.apply_damage(shooter, wall, blaster.power + shooter.atk(), blaster), dealt,
		"die Vorschau sagt genau das, was die Ausfuehrung tut")

	shooter.free()
	wall.free()


## Ein Aufbau mit Flaechenwaffe und Flaechenheilung -- beides auf einem Molok,
## damit ein einziger DROME beide Seiten der Frage stellt: wen trifft ein Radius?
func _siege_and_drones(display_name: String) -> DromeBuild:
	return DromeBuild.create(display_name, {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": &"eq_siege_cannon", "equip_right": &"eq_drone_pod"})


func _action_by_id(unit: Unit, id: StringName) -> ActionData:
	for action in unit.actions():
		if action.id == id:
			return action
	return null


func test_an_area_hit_only_touches_who_it_means() -> void:
	# Der Belagerungsschlag hat Radius 1. Zielte er auf ein Nachbarfeld, lag der
	# Schuetze SELBST im Radius -- und execute() wendete die Wirkung auf jeden an,
	# der auf einem getroffenen Feld stand, ohne nach der Seite zu fragen. Ein
	# Molok im Handgemenge schoss sich so selbst zusammen, und weder
	# Vorschau noch KI zeigten es an: beide bewerten das anvisierte Ziel.
	var build := _siege_and_drones("BELAGERER")
	t.ok(build.is_valid(), "der Belagerer ist baubar: %s" % ", ".join(build.validate()))

	var grid := Grid.new(12, 12)
	var shooter := Unit.create(build, &"E0", false)
	var comrade := Unit.create(build, &"E1", false)
	var foe := Unit.create(_squad()[0], &"P0", true)
	var second_foe := Unit.create(_squad()[0], &"P1", true)
	shooter.tile = Vector2i(5, 5)
	foe.tile = Vector2i(6, 5)          # Nachbarfeld: der Schuetze liegt im Radius
	comrade.tile = Vector2i(6, 6)      # ebenfalls im Radius, eigene Seite
	second_foe.tile = Vector2i(6, 4)   # im Radius, gegnerische Seite
	var resolver := ActionResolver.new(grid, [shooter, comrade, foe, second_foe])

	var siege := _action_by_id(shooter, &"act_siege")
	t.ok(siege != null and siege.aoe_radius > 0, "der Belagerungsschlag ist eine Flaeche")
	t.ok(shooter.tile in resolver.affected_tiles(foe.tile, siege),
		"und der Schuetze steht bei diesem Ziel wirklich in der eigenen Flaeche")

	# Geprueft wird die Flaeche, nicht der Energieschild davor.
	foe.shield = 0
	second_foe.shield = 0
	var expected := resolver.preview_damage(shooter, foe, siege)
	t.ok(resolver.execute(shooter, foe.tile, siege), "der Schuss geht raus")

	t.equal(shooter.hp, shooter.stat("hp_max"), "der Schuetze nimmt keinen eigenen Schaden")
	t.equal(comrade.hp, comrade.stat("hp_max"), "der Verbuendete im Radius bleibt heil")
	t.equal(foe.hp, foe.stat("hp_max") - expected, "das Ziel nimmt genau die Vorschau")
	t.ok(second_foe.hp < second_foe.stat("hp_max"),
		"der zweite Gegner im Radius wird mitgenommen -- die Flaeche bleibt eine Flaeche")

	shooter.free()
	comrade.free()
	foe.free()
	second_foe.free()


func test_drone_pod_regenerates_its_carrier_passively() -> void:
	# Der Drohnen-Pod ist keine aktive Heilung mehr, sondern eine PASSIVE: 5 %
	# der maximalen Integritaet je eigenem Zug, ohne Knopf. Er heilt nur seinen
	# Traeger und laeuft nicht ueber das Maximum.
	var carrier := Unit.create(_siege_and_drones("SANI"), &"E0", false)
	var maximum := carrier.stat("hp_max")
	var pct := carrier.stat("hp_regen_pct")
	t.ok(pct > 0, "der Drohnen-Pod bringt Selbstheilung mit (%d%%)" % pct)

	var expected := int(floor(float(maximum) * float(pct) / 100.0))
	carrier.hp = maximum - 30
	t.equal(carrier.regenerate_hp(), expected,
		"geheilt werden %d (= %d%% von %d)" % [expected, pct, maximum])
	t.equal(carrier.hp, maximum - 30 + expected, "die Integritaet steigt entsprechend")

	carrier.hp = maximum - 1
	carrier.regenerate_hp()
	t.equal(carrier.hp, maximum, "die Heilung laeuft nicht ueber das Maximum")

	var plain := Unit.create(_squad()[0], &"P0", true)
	plain.hp = 10
	t.equal(plain.regenerate_hp(), 0, "wer keinen Drohnen-Pod traegt, regeneriert nicht")

	carrier.free()
	plain.free()


## Ein Squad, das ALLE drei Faehigkeiten des Bestands traegt -- sonst misst der
## Test unten nur, was zufaellig mitgewuerfelt wurde.
func _ability_squad() -> Array:
	return [
		DromeBuild.create("KOEDER", {
			"body": &"jugg_body", "head": &"jugg_head",
			"feet": &"jugg_feet", "core": &"jugg_core",
			"equip_left": &"eq_siege_cannon", "equip_right": &"eq_bait_beacon"}),
		DromeBuild.create("SANI", {
			"body": &"mage_body", "head": &"mage_head",
			"feet": &"mage_drive", "core": &"mage_core",
			"equip_left": &"eq_rune_staff", "equip_right": &"eq_orbit_focus"}),
	]


## Spielt ``battles`` Gefechte und schreibt je DROME die Folge seiner Aktionen
## mit (ueber EventBus.action_used). Gibt { uses: id -> Anzahl, seqs:
## unit_name -> [action_id, ...] } zurueck.
func _record(battles: int, builds: Array, first_seed: int) -> Dictionary:
	var uses := {}
	var seqs := {}
	var current := {"seed": first_seed}
	var record := func(unit, _tile, action):
		uses[action.id] = int(uses.get(action.id, 0)) + 1
		var key := "%d:%s" % [current["seed"], unit.unit_id]
		if not seqs.has(key):
			seqs[key] = []
		seqs[key].append(action.id)
	EventBus.action_used.connect(record)
	for i in battles:
		current["seed"] = first_seed + i
		var battle := BattleManager.new()
		battle.setup(first_seed + i, builds)
		battle.run_to_end()
		battle.free()
	EventBus.action_used.disconnect(record)
	return {"uses": uses, "seqs": seqs}


func test_every_ability_fires_by_itself() -> void:
	# Echtzeit (Nov. 2026): Faehigkeiten werden nicht mehr gezogen, sie loesen
	# nach ihrer Regel aus. Jede Faehigkeit im Bestand muss im Kampf auch
	# wirklich kommen -- sonst ist ihr Ausloeser kaputt.
	var squads := [_ability_squad(), _squad(), [DromeBuild.create("BOOST", {
		"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core",
		"equip_left": &"eq_holo_boost"})]]
	var uses := {}
	for squad in squads:
		var measured: Dictionary = _record(8, squad, 7000)
		for id in measured["uses"]:
			uses[id] = int(uses.get(id, 0)) + int(measured["uses"][id])
	# Der Hologramm-Boost fehlt hier mit Absicht: er loest aus, wenn ein Gegner
	# direkt danebensteht, und solange es keine Nahkampfwaffe gibt (Plasmaklinge
	# und Hammer kommen erst), kommt im Kampf niemand so nah. Sein Ausloeser
	# wird in tests/test_dash.gd geprueft.
	for id in [&"act_pulse_scatter", &"act_siege_barrage", &"act_rune_vortex",
			&"act_rail_pierce", &"act_orbitpull"]:
		t.ok(int(uses.get(id, 0)) > 0, "%s loest im Kampf aus (%d)" % [id, uses.get(id, 0)])
	t.note("Aktionen: %s" % str(uses))


func test_every_nth_attack_is_the_ability() -> void:
	# Die Regel "jeder 3. Schuss ist die Streusalve": zwischen zwei Faehigkeiten
	# derselben Waffe fallen genau N-1 normale Angriffe. Gemessen am Squad mit
	# je EINER Waffe, damit sich keine zwei Zaehler mischen. Streusalve und
	# Praezisionsschuss reichen mindestens so weit wie ihr Angriff -- sie
	# kommen also nie zu spaet.
	var measured: Dictionary = _record(6, _squad(), 7300)
	var rules := {&"act_pulse_scatter": [&"act_pulse", 3],
		&"act_rail_pierce": [&"act_raillance", 4]}
	var checked := 0
	for key in measured["seqs"]:
		# Nur die eigene Seite: generierte Gegner tragen auch zwei Blaster,
		# deren Zaehler sich in der Folge mischen.
		if not str(key).contains(":P"):
			continue
		var seq: Array = measured["seqs"][key]
		for ability in rules:
			var attack: StringName = rules[ability][0]
			var every: int = rules[ability][1]
			if not seq.has(attack):
				continue
			var since := 0
			for id in seq:
				if id == attack:
					since += 1
				elif id == ability:
					t.equal(since, every - 1,
						"%s kommt nach %d Angriffen (%s)" % [ability, every - 1, key])
					since = 0
					checked += 1
	t.ok(checked > 3, "die Regel wurde oft genug geprueft (%d)" % checked)


func test_same_seed_gives_the_same_battle() -> void:
	# Akzeptanzkriterium: denselben Seed zweimal spielen und exakt dasselbe
	# bekommen -- Karte, Region, Gegner, Ausgang.
	var a := _play(20260806)
	var b := _play(20260806)
	t.equal(a["region"], b["region"], "dieselbe Region")
	t.equal(a["seconds"], b["seconds"], "dieselbe Dauer")
	t.equal(BattleManager.outcome_label(a["outcome"]),
		BattleManager.outcome_label(b["outcome"]), "derselbe Ausgang")
	for i in a["units"].size():
		t.equal(a["units"][i]["name"], b["units"][i]["name"],
			"dieselben DROMEs in derselben Reihenfolge")
		t.equal(a["units"][i]["taken"], b["units"][i]["taken"],
			"derselbe erlittene Schaden bei %s" % a["units"][i]["name"])


## Der Test, der oben FEHLT -- und zwar prinzipiell.
##
## test_same_seed_gives_the_same_battle() vergleicht zwei Laeufe DERSELBEN
## Engine. Genau daran ist ein Bruch vorbeigelaufen: unter Godot 4.7 zog
## derselbe Seed eine andere Region als unter 4.3, weil ``Array.sort()`` auf
## ``StringName`` nach interner Adresse sortiert und nicht alphabetisch. Beide
## Laeufe waren in sich einig, nur nicht miteinander -- gruener Test, kaputtes
## Versprechen.
##
## Deshalb wird hier nicht "zweimal dasselbe" geprueft, sondern der INHALT der
## Reihenfolge: die Auswahl muss der alphabetischen Folge der Region-IDs
## entsprechen. Das ist die einzige Formulierung, die eine Engine nicht
## unbemerkt umdeuten kann.
func test_region_choice_follows_the_alphabet_not_the_memory_layout() -> void:
	var ids: Array[String] = []
	for key in TerrainDB.regions:
		ids.append(str(key))
	ids.sort()
	t.ok(ids.size() >= 2, "es gibt mehr als eine Region, sonst prueft das nichts")

	var seen := {}
	for seed_value in range(40):
		# Denselben Wurf zweimal: einmal fuer den erwarteten Index, einmal fuer
		# die echte Auswahl. Beide starten bei demselben Seed.
		var counter := RandomNumberGenerator.new()
		counter.seed = seed_value
		var expected: String = ids[counter.randi() % ids.size()]

		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var region := TerrainDB.pick_region(rng)
		t.equal(str(region.id), expected,
			"Seed %d zieht die alphabetisch %d. Region" % [seed_value,
				ids.find(expected) + 1])
		seen[expected] = true
	t.equal(seen.size(), ids.size(),
		"und ueber 40 Seeds kommt jede Region auch wirklich vor")


func test_enemy_power_matches_the_player_squad() -> void:
	var player := _squad()
	var target := DromeBuild.squad_power(player)
	var tolerance := Config.get_float("power_tolerance", 0.12)
	var misses := 0
	for i in 30:
		var generator := EnemyGenerator.new(7000 + i)
		generator.generate(player.size(), target)
		if absf(generator.achieved_power - target) / target > tolerance:
			misses += 1
	t.ok(misses <= 3, "das Gegner-Matching trifft die Toleranz (%d von 30 daneben)"
		% misses)


func test_generated_enemies_are_always_valid() -> void:
	# Auch auf dem Strix, der genau einen Ausruestungsanker hat.
	for i in 40:
		for build in EnemyGenerator.new(8000 + i).generate(3, 600.0):
			var problems: Array[String] = build.validate()
			t.ok(problems.is_empty(), "%s ist baubar: %s"
				% [build.display_name, ", ".join(problems)])
