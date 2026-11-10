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
	var build := DromeBuild.create(display_name, {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": weapon})
	return build


## Ein Sog ohne Schaden (frueher der Orbit-Sog, seit 9. Nov. 2026 wurzelt der
## Orbit-Fokus nur noch) -- die Bewertung _shove_score bleibt fuer jede
## Aktion mit push_tiles < 0 gueltig.
func _pull_action(_unit: Unit) -> ActionData:
	var pull := ActionData.new()
	pull.id = &"test_pull"
	pull.category = ActionData.Category.ABILITY
	pull.range_tiles = 4
	pull.push_tiles = -2
	return pull


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
		"der Sog zieht und richtet dabei keinen Schaden an")

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
	t.equal(bunker.stats()["def"], 14, "und kommt auf Ruestung 14 (Molok 10 + Schild 4)")

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
	t.ok(hits <= 45,
		"und der Bunker faellt in absehbarer Zeit (%d Treffer)" % hits)
	t.equal(resolver.apply_damage(shooter, wall, shooter.raw_damage(blaster), blaster), dealt,
		"die Vorschau sagt genau das, was die Ausfuehrung tut")

	shooter.free()
	wall.free()


## Ein Aufbau mit Flaechenwaffe und Flaechenheilung -- beides auf einem Molok,
## damit ein einziger DROME beide Seiten der Frage stellt: wen trifft ein Radius?
func _siege_and_drones(display_name: String) -> DromeBuild:
	return DromeBuild.create(display_name, {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": &"eq_hammer", "equip_right": &"eq_drone_pod"})


func _action_by_id(unit: Unit, id: StringName) -> ActionData:
	for action in unit.actions():
		if action.id == id:
			return action
	return null


func test_an_area_hit_only_touches_who_it_means() -> void:
	# Ein Flaechenschuss mit Radius 1 (frueher die Kanone). Zielte er auf ein Nachbarfeld, lag der
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

	# Seit die Kanone weg ist (6g), traegt kein Teil mehr einen reinen
	# Flaechenschuss -- die Regel gilt trotzdem, also mit einer eigenen Aktion.
	var siege := ActionData.from_meta({"id": "act_test_area", "category": "attack",
		"targeting": "aoe_around_target", "range_tiles": 6, "aoe_radius": 1, "power": 20,
		"interval": 2.0})
	t.ok(siege != null and siege.aoe_radius > 0, "der Testschuss ist eine Flaeche")
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


func test_the_drone_pod_repairs_the_most_hurt_ally() -> void:
	# 7. Nov. 2026: der Drohnen-Pod ist eine Heil-Waffe. Sein Angriff repariert
	# den Verbuendeten mit dem geringsten Anteil Integritaet in Reichweite;
	# ist niemand verletzt, schiesst er auf Gegner.
	var medic := DromeBuild.create("SANI", {
		"body": &"mage_body", "head": &"mage_head",
		"feet": &"mage_drive", "core": &"mage_core",
		"equip_left": &"eq_drone_pod"})
	var tiles := [Vector2i(10, 15), Vector2i(11, 15), Vector2i(12, 15), Vector2i(10, 12)]
	var battle := BattleManager.new()
	battle.setup(4242, [medic, _squad()[0], _squad()[1]], [_squad()[0]])
	for i in tiles.size():
		var unit: Unit = battle.units[i]
		battle.grid.clear_occupant(unit.tile)
	for i in tiles.size():
		var unit: Unit = battle.units[i]
		unit.place_at(tiles[i])
		battle.grid.set_occupant(unit.tile, unit.unit_id)
	var sani: Unit = battle.units[0]
	var light: Unit = battle.units[1]
	var heavy: Unit = battle.units[2]
	var foe: Unit = battle.units[3]
	var repair := _action_by_id(sani, &"act_drone_repair")
	t.ok(repair != null and repair.heal > 0, "der Pod hat einen Heil-Angriff")

	var aim: Dictionary = battle.brain._support_aim(sani, repair)
	t.ok(aim.is_empty(), "niemand verletzt: keine Heilung")
	light.hp -= 10
	heavy.hp = heavy.stat("hp_max") / 2
	aim = battle.brain._support_aim(sani, repair)
	t.equal(aim.get("target"), heavy, "geheilt wird, wer den geringsten Anteil hat")
	var before := heavy.hp
	t.ok(battle.resolver.execute(sani, heavy.tile, repair), "die Heilung geht raus")
	var amount := ActionResolver.support_amount(sani, heavy, repair.heal)
	t.equal(heavy.hp, before + amount,
		"und repariert %d (Grundwert x Power + 3 %% der Integritaet des Ziels)" % amount)

	# Ueber die volle Integritaet hinaus wird die Heilung zu Schild -- aber
	# nur bis zum normalen Maximum; ist beides voll, verpufft sie.
	heavy.hp = heavy.stat("hp_max") - 1
	heavy.shield = heavy.shield_max() - 3
	battle.resolver.execute(sani, heavy.tile, repair)
	t.equal(heavy.hp, heavy.stat("hp_max"), "Integritaet voll")
	t.equal(heavy.shield, heavy.shield_max(), "der Rest fuellt den Schild, kein Ueberschild")
	battle.resolver.execute(sani, heavy.tile, repair)
	t.equal(heavy.shield, heavy.shield_max(), "beides voll: die Heilung geht ins Leere")

	heavy.hp = heavy.stat("hp_max")
	light.hp = light.stat("hp_max")
	var foe_before := foe.shield + foe.hp
	t.ok(battle.brain._fire(sani, sani.mounts[0], foe), "niemand verletzt: er schiesst")
	t.ok(foe.shield + foe.hp < foe_before, "und trifft den Gegner")
	battle.free()


func test_the_deflector_charges_its_own_shield() -> void:
	var tank := DromeBuild.create("WALL", {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": &"eq_hammer", "equip_right": &"eq_deflector"})
	var unit := Unit.create(tank, &"P0", true)
	var resolver := ActionResolver.new(Grid.new(10, 10), [unit])
	unit.tile = Vector2i(3, 3)
	var charge := _action_by_id(unit, &"act_deflector_charge")
	t.ok(charge != null and charge.shield_gain > 0, "der Deflektor hat die Schildladung")
	unit.shield = unit.shield_max()
	t.ok(resolver.execute(unit, unit.tile, charge), "sie wirkt auf den Traeger")
	t.equal(unit.shield, unit.shield_max() + ActionResolver.support_amount(unit, unit, charge.shield_gain),
		"auch ueber das Maximum")
	for _i in 6:
		resolver.execute(unit, unit.tile, charge)
	t.equal(unit.shield, ActionResolver.shield_cap(unit), "aber hoechstens Maximum + 50 %")
	t.equal(ActionResolver.shield_cap(unit), int(round(unit.shield_max() * 1.5)), "das ist der Deckel")
	unit.free()


## Ein Squad, das ALLE drei Faehigkeiten des Bestands traegt -- sonst misst der
## Test unten nur, was zufaellig mitgewuerfelt wurde.
func _ability_squad() -> Array:
	return [
		DromeBuild.create("KOEDER", {
			"body": &"jugg_body", "head": &"jugg_head",
			"feet": &"jugg_feet", "core": &"jugg_core",
			"equip_left": &"eq_hammer", "equip_right": &"eq_deflector"}),
		_with_modules(DromeBuild.create("SANI", {
			"body": &"mage_body", "head": &"mage_head",
			"feet": &"mage_drive", "core": &"mage_core",
			"equip_left": &"eq_rune_staff"}), "equip_left", [&"mod_orbit"]),
	]


func _with_modules(build: DromeBuild, slot: String, ids: Array) -> DromeBuild:
	build.modules[slot] = ids
	return build


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
	var squads := [_ability_squad(), _squad()]
	var uses := {}
	for squad in squads:
		var measured: Dictionary = _record(8, squad, 7000)
		for id in measured["uses"]:
			uses[id] = int(uses.get(id, 0)) + int(measured["uses"][id])
	# Der Hologramm-Boost fehlt hier mit Absicht: er loest aus, wenn ein Gegner
	# direkt danebensteht, und solange es keine Nahkampfwaffe gibt (Plasmaklinge
	# und Hammer kommen erst), kommt im Kampf niemand so nah. Sein Ausloeser
	# wird in tests/test_dash.gd geprueft.
	for id in [&"act_pulse_double", &"act_rune_vortex", &"act_rail_pierce"]:
		t.ok(int(uses.get(id, 0)) > 0, "%s loest im Kampf aus (%d)" % [id, uses.get(id, 0)])
	t.note("Aktionen: %s" % str(uses))


func test_every_nth_attack_is_the_ability() -> void:
	# Die Regel "jeder 3. Schuss ist die Doppelschuss": zwischen zwei Faehigkeiten
	# derselben Waffe fallen genau N-1 normale Angriffe. Gemessen am Squad mit
	# je EINER Waffe, damit sich keine zwei Zaehler mischen. Doppelschuss und
	# Praezisionsschuss reichen mindestens so weit wie ihr Angriff -- sie
	# kommen also nie zu spaet.
	var measured: Dictionary = _record(6, _squad(), 7300)
	var rules := {&"act_pulse_double": [&"act_pulse", 3],
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


func test_shield_overflow_is_not_multiplied_onto_integrity() -> void:
	# Bricht ein Treffer den Schild, trifft nur der Rest die Integritaet --
	# ohne Schildfaktor. Frueher ging der Schildbrecher (Energie x1,2, Schild
	# x2) mit dem vollen Faktor auf die HP durch.
	var grid := Grid.new(10, 10)
	var target := Unit.create(_squad()[0], &"E0", false)
	var resolver := ActionResolver.new(grid, [target])
	target.shield = 0
	var bare: int = resolver.resolve_damage(target, 12, 1.0, 2.0)["hp"]
	target.shield = 5
	var broken: Dictionary = resolver.resolve_damage(target, 12, 1.0, 2.0)
	t.equal(int(broken["shield_after"]), 0, "der Schild ist weg")
	t.ok(int(broken["hp"]) < bare,
		"ein Rest Schild faengt etwas ab: %d < %d" % [broken["hp"], bare])
	target.shield = 0
	var rest: int = resolver.resolve_damage(target, 10, 1.0, 2.0)["hp"]
	t.ok(int(broken["hp"]) <= rest,
		"5 Schild kosten den Schildbrecher gut 2 Rohschaden: %d <= %d" % [broken["hp"], rest])
	target.free()


func test_shield_recharges_only_after_a_calm_spell() -> void:
	# 6g: keine Grundregeneration. Erst nach der Ruhezeit laedt der Schild.
	var unit := Unit.create(_squad()[0], &"P0", true)
	var maximum := unit.shield_max()
	unit.shield = 0
	unit.note_damage()
	var gained := 0
	for i in 60:   # 3 s
		gained += unit.recharge_shield(0.05)
	t.equal(gained, 0, "in den ersten Sekunden nach einem Treffer laedt nichts")
	for i in 60:   # weitere 3 s
		gained += unit.recharge_shield(0.05)
	t.ok(gained > 0 and unit.shield <= maximum,
		"nach der Ruhezeit laedt er wieder (%d von %d)" % [unit.shield, maximum])
	unit.note_damage()
	var before := unit.shield
	unit.recharge_shield(0.05)
	t.equal(unit.shield, before, "ein neuer Treffer stoppt das Nachladen")
	unit.free()
