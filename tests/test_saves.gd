extends RefCounted

## Die drei Spielstaende (GameState, 10. Nov. 2026).
##
## Tests schreiben sonst nie auf die Platte. Hier wird das Speichern gezielt
## eingeschaltet, aber in einen eigenen Ordner gelenkt -- der Spielstand des
## Spielers bleibt unberuehrt. Am Ende steht GameState wieder wie vorher.

const ROOT := "user://_test_saves/"

var t


func _begin() -> Dictionary:
	var before := {"root": GameState.save_root, "override": GameState.persistence_override,
		"slot": GameState.slot, "roster": GameState.roster, "run": GameState.run,
		"progress": GameState.progress, "squad": GameState.squad}
	GameState.save_root = ROOT
	GameState.persistence_override = true
	_clear()
	GameState.boot()
	return before


func _end(before: Dictionary) -> void:
	_clear()
	GameState.save_root = before["root"]
	GameState.persistence_override = before["override"]
	GameState.slot = before["slot"]
	GameState.roster = before["roster"]
	GameState.run = before["run"]
	GameState.progress = before["progress"]
	GameState.squad = before["squad"]


func _clear() -> void:
	for which in range(1, GameState.SLOT_COUNT + 1):
		GameState.delete_slot(which)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.slot_dir(which)))
	GameState._remove(ROOT + GameState.META_FILE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ROOT))


func test_before_a_slot_is_chosen_nothing_is_written() -> void:
	var before := _begin()
	t.equal(GameState.slot, 0, "noch kein Spielstand gewählt")
	t.equal(GameState.roster.entries.size(), 4, "trotzdem ein spielbarer Bestand")
	GameState.save_roster()
	for which in range(1, GameState.SLOT_COUNT + 1):
		if which == GameState.TEST_SLOT:
			continue
		t.ok(not GameState.slot_exists(which), "Spielstand %d bleibt leer" % which)
		t.ok(not GameState.slot_summary(which)["exists"], "und die Karte sagt es")
	_end(before)


func test_slot_three_is_the_test_stock_and_renews_with_each_version() -> void:
	# Spieler 27. Nov. 2026: Platz 3 ist ein Testspielstand mit 1000 von allem,
	# jeder Waffe einmal extra und jedem DROME; jede neue Version schreibt ihn neu.
	var before := _begin()
	t.equal(GameState.TEST_SLOT, 3, "Platz 3")
	t.ok(GameState.slot_exists(3), "liegt schon beim Start bereit")
	GameState.select_slot(3)
	var roster := GameState.roster
	t.equal(roster.entries.size(), 4, "jeder fertige DROME einmal")
	for ware in FactorySim.wares():
		t.equal(int(roster.materials.get(FactorySim.material_key(str(ware)), 0)), 1000,
			"1000 %s" % ware)
	for element in Charger.element_ids():
		t.equal(int(roster.materials.get("phase:" + str(element), 0)), 1000, "1000 Phasen %s" % element)
	t.equal(roster.blanks(), 1000, "1000 Charger-Rohlinge")
	for part in PartDB.of_type(PartData.Type.EQUIPMENT):
		t.ok(roster.free_count(part.id) >= 1, "%s liegt frei im Lager" % part.id)
		t.equal(roster.total_count(part.id), 2, "%s zweimal im Bestand" % part.id)
	# Der Spieler baut etwas -- dieselbe Version laesst es stehen.
	roster.materials["res:legierung"] = 5
	GameState.save_roster()
	t.ok(not GameState.refresh_test_slot(), "dieselbe Version schreibt nicht neu")
	GameState.select_slot(3)
	t.equal(int(GameState.roster.materials.get("res:legierung", 0)), 5, "der Stand bleibt")
	# Eine neue Version (anderer Eintrag in der Meta-Datei) schreibt neu.
	var meta := GameState._read_meta()
	meta["test_build"] = "alte-version"
	GameState._write_json(GameState.save_root + GameState.META_FILE, meta)
	t.ok(GameState.refresh_test_slot(), "eine neue Version schreibt neu")
	GameState.select_slot(3)
	t.equal(int(GameState.roster.materials.get("res:legierung", 0)), 1000, "wieder 1000")
	_end(before)


func test_three_slots_keep_their_own_hangar_run_and_progress() -> void:
	var before := _begin()
	t.equal(GameState.SLOT_COUNT, 3, "drei Spielstände")

	GameState.select_slot(1)
	t.ok(GameState.slot_exists(1), "ein neuer Spielstand wird gleich angelegt")
	GameState.roster.entries[0].name = "Erster"
	GameState.roster.entries[0].level = 3
	GameState.save_roster()
	GameState.start_run(4711)
	GameState.progress["story_cleared"] = true
	GameState.save_progress()

	GameState.select_slot(2)
	t.equal(GameState.roster.entries[0].name, "Vireo", "Spielstand 2 beginnt frisch")
	t.equal(GameState.run, null, "ohne Lauf")
	t.ok(not GameState.endless_unlocked(), "und ohne Fortschritt")
	GameState.start_run(815, "story")

	GameState.select_slot(1)
	t.equal(GameState.roster.entries[0].name, "Erster", "Spielstand 1 hat seinen Hangar")
	t.equal(GameState.roster.entries[0].level, 3, "mit Level")
	t.ok(GameState.run != null and GameState.run.run_seed == 4711, "und seinen Lauf")
	t.ok(GameState.endless_unlocked(), "und seinen Fortschritt")

	var first := GameState.slot_summary(1)
	t.ok(first["exists"], "Karte 1: belegt")
	# Neuer Spielstand (23. Nov. 2026): die vier CyberDrome-DROMEs.
	t.equal(first["dromes"], 4, "die vier CyberDrome-DROMEs")
	t.equal(first["squad"], 3, "drei im Squad")
	t.ok(str(first["run"]).begins_with("Neon City"), "laufender Lauf steht drauf (%s)" % first["run"])
	t.ok(first["story_cleared"], "Neon City bezwungen")
	t.ok(GameState.slot_summary(3)["exists"], "Karte 3: der Testspielstand")
	_end(before)


func test_the_last_slot_comes_back_after_a_restart() -> void:
	var before := _begin()
	GameState.select_slot(2)
	GameState.roster.entries[1].name = "Zweiter"
	GameState.save_roster()
	# Neustart: der zuletzt gespielte Spielstand ist wieder da.
	GameState.boot()
	t.equal(GameState.slot, 2, "der zuletzt gespielte Spielstand")
	t.equal(GameState.roster.entries[1].name, "Zweiter", "mit seinem Hangar")
	_end(before)


func test_deleting_and_resetting_touch_only_one_slot() -> void:
	var before := _begin()
	GameState.select_slot(1)
	GameState.roster.entries[0].name = "Bleibt"
	GameState.save_roster()
	GameState.select_slot(3)
	GameState.roster.entries[0].name = "Geht"
	GameState.save_roster()
	GameState.start_run(99)
	GameState.reset_progress()
	t.equal(GameState.roster.entries[0].name, "Vireo", "zurückgesetzt: frischer Hangar")
	t.equal(GameState.run, null, "kein Lauf mehr")
	t.ok(GameState.slot_exists(3), "der Spielstand selbst bleibt")
	t.equal(GameState.slot_summary(3)["run"], "", "ohne laufenden Lauf")
	GameState.delete_slot(3)
	t.ok(not GameState.slot_exists(3), "geloescht")
	t.equal(GameState.slot, 0, "danach ist keiner gewählt")
	GameState.select_slot(1)
	t.equal(GameState.roster.entries[0].name, "Bleibt", "Spielstand 1 ist unberührt")
	_end(before)


func test_winning_neon_city_unlocks_the_endless_run() -> void:
	var before := _begin()
	GameState.select_slot(1)
	t.ok(not GameState.endless_unlocked(), "anfangs gesperrt")
	GameState.start_run(5)
	var run: RunState = GameState.run
	run.round = RunState.rounds_total()
	run._pick_default_node()
	GameState.begin_run_battle()
	GameState.finish_run_battle(BattleManager.Outcome.VICTORY, [])
	t.equal(run.phase, RunState.Phase.WON, "Neon City gewonnen")
	t.ok(GameState.endless_unlocked(), "der Endlos-Modus ist frei")
	t.ok(GameState.just_unlocked_endless, "und das Ende sagt es")
	GameState.boot()
	t.ok(GameState.endless_unlocked(), "auch nach einem Neustart")
	_end(before)
