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
	t.equal(GameState.slot, 0, "noch kein Spielstand gewaehlt")
	t.equal(GameState.roster.entries.size(), 4, "trotzdem ein spielbarer Bestand")
	GameState.save_roster()
	for which in range(1, GameState.SLOT_COUNT + 1):
		t.ok(not GameState.slot_exists(which), "Spielstand %d bleibt leer" % which)
		t.ok(not GameState.slot_summary(which)["exists"], "und die Karte sagt es")
	_end(before)


func test_three_slots_keep_their_own_hangar_run_and_progress() -> void:
	var before := _begin()
	t.equal(GameState.SLOT_COUNT, 3, "drei Spielstaende")

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
	t.equal(first["dromes"], 4, "vier DROMEs")
	t.equal(first["squad"], 4, "vier im Squad")
	t.ok(str(first["run"]).begins_with("Neon City"), "laufender Lauf steht drauf (%s)" % first["run"])
	t.ok(first["story_cleared"], "Neon City bezwungen")
	t.ok(not GameState.slot_summary(3)["exists"], "Karte 3: leer")
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
	t.equal(GameState.roster.entries[0].name, "Vireo", "zurueckgesetzt: frischer Hangar")
	t.equal(GameState.run, null, "kein Lauf mehr")
	t.ok(GameState.slot_exists(3), "der Spielstand selbst bleibt")
	t.equal(GameState.slot_summary(3)["run"], "", "ohne laufenden Lauf")
	GameState.delete_slot(3)
	t.ok(not GameState.slot_exists(3), "geloescht")
	t.equal(GameState.slot, 0, "danach ist keiner gewaehlt")
	GameState.select_slot(1)
	t.equal(GameState.roster.entries[0].name, "Bleibt", "Spielstand 1 ist unberuehrt")
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
