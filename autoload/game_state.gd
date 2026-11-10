extends Node

## Was zwischen den Bildschirmen ueberlebt: der Roster, der Seed, das Ergebnis.
##
## Die Werkstatt kennt die Kampfszene nicht und umgekehrt. Beide reden nur
## hierueber -- sonst haengt der Rueckweg vom Ergebnisbildschirm an einem
## Szenenpfad, und ein zweiter Einstieg in den Kampf ist nicht mehr moeglich.
##
## ### Vom Wegwerf-Squad zum Roster (§10g)
##
## Frueher hielt der GameState EINEN fluechtigen Squad frisch gebauter DROMEs.
## Jetzt liegt darunter der ``roster`` -- der bleibende Besitz (Inventar +
## DROMEs). Der ``squad`` ist nur noch die abgeleitete Auswahl derer, die ins
## naechste Gefecht ziehen (``in_squad``). Der Kampf liest weiter ``squad`` und
## merkt von der Besitz-Schicht nichts.

## ### Spielstaende (10. Nov. 2026, Wunsch des Spielers)
##
## Es gibt SLOT_COUNT Spielstaende. Jeder liegt in einem eigenen Ordner
## (``user://slot1/`` ...) mit drei Dateien: Hangar (roster.json), laufender
## Lauf (run.json) und Fortschritt (progress.json). Welcher zuletzt gespielt
## wurde, steht in ``user://slots.json``. Beim Start waehlt der Spieler einen
## aus (scenes/saves.tscn); bis dahin ist ``slot`` 0 und nichts wird
## geschrieben. Die Optionen (user://settings.json) gelten fuer alle.
const SLOT_COUNT := 3
const ROSTER_FILE := "roster.json"
const RUN_FILE := "run.json"
const PROGRESS_FILE := "progress.json"
const META_FILE := "slots.json"

## Der Stand vor den Spielstaenden: eine Datei je Art direkt in user://. Wird
## beim ersten Start einmal in Spielstand 1 ueberfuehrt.
const LEGACY_ROSTER_PATH := "user://roster.json"
const LEGACY_RUN_PATH := "user://run.json"

## Altformat v1 (Wegwerf-Squad) und der Export der SVG-Werkstatt
## (python3 main.py). Der neuere von Spielstand und Werkstatt-Export gewinnt
## beim Laden, damit ein frisch gebauter Squad nicht von einem alten Stand
## verdeckt wird -- ein v1-Squad wird dabei einmalig in den Roster ueberfuehrt.
const SQUAD_PATH := "user://squad.json"
const WORKSHOP_SQUAD_PATH := "res://builds/squad.json"

## Wo die Spielstaende liegen. Tests legen sie in einen eigenen Ordner.
var save_root: String = "user://"

## Der gewaehlte Spielstand, 1..SLOT_COUNT. 0 = noch keiner -- dann lebt der
## Bestand nur im Speicher.
var slot: int = 0

## Nur fuer Tests: Speichern erzwingen (true) oder verbieten (false), obwohl
## ein Testlauf sonst nie schreibt. null = die normale Regel.
var persistence_override = null

## Der Besitz: Inventar (Instanzen) + Roster (DROMEs). Quelle der Wahrheit.
var roster: Roster = Roster.new()

## Welchen Roster-Eintrag die Werkstatt gerade anpasst. Die Garage setzt ihn vor
## dem Szenenwechsel; -1 heisst "keiner gewaehlt".
var editing_index: int = -1

## Die DROMEs des naechsten Gefechts -- abgeleitet aus den ``in_squad``-Eintraegen
## des Rosters. Array[DromeBuild]. Der Kampf liest genau das.
var squad: Array = []

## Bestimmt Gegner, Karte und Aufstellung. Wird im Ergebnis-
## bildschirm angezeigt und kann im Startdialog gesetzt werden: derselbe Seed
## ergibt exakt denselben Kampf. Im Playtesting ist das Gold wert.
var battle_seed: int = 0

## Die zuletzt bestaetigte Aufstellung (Felder in Squad-Reihenfolge). Der
## naechste Kampf stellt sie wieder her, soweit sie in die Zone passt.
var formation: Array = []


## Ergebnis des letzten Kampfes, fuer den Ergebnisbildschirm
var last_result: Dictionary = {}

## Die Art des naechsten Laufs, vom Hauptmenue gesetzt: "story" oder
## "endless". Der Lauf-Bildschirm startet damit.
var next_run_mode: String = "story"

## Fortschritt des Spielstands ueber Laeufe hinweg: {story_cleared: bool}.
## Wer Neon City gewinnt, schaltet den Endlos-Modus frei (NEUANFANG 6h).
var progress: Dictionary = {}

## Hat der gerade beendete Lauf den Endlos-Modus freigeschaltet? Nur fuer die
## Anzeige am Ende des Laufs.
var just_unlocked_endless: bool = false


func _ready() -> void:
	boot()


## Beim Programmstart: ohne Persistenz der frische Startbestand; sonst der
## zuletzt gespielte Spielstand, damit ein Direktstart einer Szene (Editor,
## Neuladen im Browser) nicht leer dasteht. Gewaehlt wird in scenes/saves.tscn.
func boot() -> void:
	slot = 0
	run = null
	progress = {}
	if not _persistence_enabled():
		if not _is_tool_run() and persistence_override == null:
			_wipe_saves()
		roster = Roster.new()
		roster.seed_starter()
		refresh_squad()
		print("[GameState] Persistenz aus -- Startbestand gesetzt: %d DROMEs, %d Instanzen"
			% [roster.entries.size(), roster.all_instances().size()])
		return
	_migrate_legacy()
	var last := int(_read_meta().get("last", 0))
	if last >= 1 and last <= SLOT_COUNT and slot_exists(last):
		select_slot(last)
	else:
		roster = Roster.new()
		roster.seed_starter()
		refresh_squad()


func new_seed() -> int:
	battle_seed = randi()
	return battle_seed


## Der Werkstatt-Eintrag, den die Garage ausgewaehlt hat. null bei ungueltigem
## Index -- die Werkstatt schickt den Spieler dann in die Garage zurueck.
func editing_entry() -> RosterEntry:
	if editing_index < 0 or editing_index >= roster.entries.size():
		return null
	return roster.entries[editing_index]


## Materialisiert den Kampf-Squad aus dem Roster. Nach jeder Aenderung an der
## Auswahl noetig -- der Kampf liest eine feste Liste, keine Ableitung.
func refresh_squad() -> void:
	squad = roster.squad_builds()


# ---------------------------------------------------------------------------
# Persistenz
# ---------------------------------------------------------------------------

## Ob ueberhaupt auf die Platte geschrieben und von dort geladen wird
## (``save_enabled`` in data/config.json). Tests und Werkzeuge schreiben nie.
func _persistence_enabled() -> bool:
	if persistence_override != null:
		return bool(persistence_override)
	if _is_tool_run():
		return false
	return bool(Config.get_value("save_enabled", false))


## Tests und Werkzeuge (--script res://tests/..., res://tools/...) lesen,
## schreiben und loeschen den Spielstand des Spielers nie.
static func _is_tool_run() -> bool:
	for arg in OS.get_cmdline_args():
		if str(arg).begins_with("res://tests/") or str(arg).begins_with("res://tools/"):
			return true
	return false


func slot_dir(which: int) -> String:
	return "%sslot%d/" % [save_root, which]


func _slot_file(which: int, file_name: String) -> String:
	return slot_dir(which) + file_name


func slot_exists(which: int) -> bool:
	return FileAccess.file_exists(_slot_file(which, ROSTER_FILE))


## Waehlt einen Spielstand und laedt ihn. Ein leerer beginnt mit dem
## Startbestand und wird gleich angelegt.
func select_slot(which: int) -> void:
	slot = clampi(which, 1, SLOT_COUNT)
	run = null
	progress = {}
	just_unlocked_endless = false
	formation = []
	editing_index = -1
	if _persistence_enabled():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(slot_dir(slot)))
		_write_json(save_root + META_FILE, {"last": slot})
	load_roster()


## Loescht einen Spielstand ganz. War es der gewaehlte, ist danach keiner
## gewaehlt (frischer Bestand im Speicher).
func delete_slot(which: int) -> void:
	for file_name in [ROSTER_FILE, RUN_FILE, PROGRESS_FILE]:
		_remove(_slot_file(which, file_name))
	if which == slot:
		slot = 0
		run = null
		progress = {}
		roster = Roster.new()
		roster.seed_starter()
		refresh_squad()


## Was auf der Karte eines Spielstands steht, ohne ihn zu laden:
## {exists, dromes, squad, level (Schnitt der DROME-Level), run (Text zum
## laufenden Lauf oder ""), story_cleared}.
func slot_summary(which: int) -> Dictionary:
	var out := {"exists": false, "dromes": 0, "squad": 0, "level": 0.0, "run": "",
		"story_cleared": false}
	if not _persistence_enabled() or not slot_exists(which):
		return out
	var data = _read_json(_slot_file(which, ROSTER_FILE))
	if data == null:
		return out
	out["exists"] = true
	var entries: Array = data.get("roster", [])
	out["dromes"] = entries.size()
	var levels := 0
	for entry in entries:
		if entry is Dictionary:
			levels += int(entry.get("level", 0))
			if bool(entry.get("in_squad", false)):
				out["squad"] += 1
	out["level"] = float(levels) / float(maxi(1, entries.size()))
	var saved_run = _read_json(_slot_file(which, RUN_FILE)) \
		if FileAccess.file_exists(_slot_file(which, RUN_FILE)) else null
	if saved_run != null and int(saved_run.get("phase", 0)) not in [RunState.Phase.WON, RunState.Phase.LOST]:
		out["run"] = "%s, Runde %d" % ["Endlos" if str(saved_run.get("mode", "story")) == "endless"
			else "Neon City", int(saved_run.get("round", 1))]
	var saved_progress = _read_json(_slot_file(which, PROGRESS_FILE)) \
		if FileAccess.file_exists(_slot_file(which, PROGRESS_FILE)) else null
	if saved_progress != null:
		out["story_cleared"] = bool(saved_progress.get("story_cleared", false))
	return out


func save_roster() -> void:
	# refresh_squad() IMMER: der Kampf liest die abgeleitete Squad-Liste, und der
	# Hangar ruft save_roster() nach jeder Aenderung genau dafuer -- unabhaengig
	# davon, ob der Stand auch auf die Platte geht.
	refresh_squad()
	if not _persistence_enabled() or slot == 0:
		return
	_write_json(_slot_file(slot, ROSTER_FILE), roster.to_dict(), true)


## Laedt den Hangar des gewaehlten Spielstands, danach Lauf und Fortschritt.
func load_roster() -> void:
	roster = Roster.new()
	if not _persistence_enabled() or slot == 0:
		roster.seed_starter()
		refresh_squad()
		return

	var path := _newest_save_file()
	if path == "":
		# Ein frischer Spielstand: der handgesetzte Startbestand (§10g), gleich
		# abgelegt -- sonst gaebe es ihn in der Auswahl noch nicht.
		roster.seed_starter()
		save_roster()
		print("[GameState] Spielstand %d neu -- Startbestand gesetzt: %d DROMEs, %d Instanzen"
			% [slot, roster.entries.size(), roster.all_instances().size()])
		load_progress()
		load_run()
		return

	var parsed = _read_json(path)
	# v2 (Roster) direkt laden; ein v1-Stand (Wegwerf-Squad, auch der SVG-Export)
	# wird migriert und beim naechsten Speichern als v2 abgelegt.
	var loaded := false
	if parsed != null:
		if int(parsed.get("version", 0)) >= 2:
			loaded = roster.load_dict(parsed)
		else:
			loaded = roster.migrate_v1(parsed)
			if loaded:
				print("[GameState] v1-Squad aus %s in den Roster ueberfuehrt" % path)
	if not loaded:
		roster = Roster.new()
		roster.seed_starter()

	refresh_squad()
	print("[GameState] Spielstand %d aus %s: %d DROMEs, %d im Squad"
		% [slot, path, roster.entries.size(), roster.squad_count()])
	load_progress()
	load_run()


func save_progress() -> void:
	if not _persistence_enabled() or slot == 0:
		return
	_write_json(_slot_file(slot, PROGRESS_FILE), progress)


func load_progress() -> void:
	progress = {}
	if not _persistence_enabled() or slot == 0:
		return
	var path := _slot_file(slot, PROGRESS_FILE)
	if FileAccess.file_exists(path):
		var parsed = _read_json(path)
		if parsed != null:
			progress = parsed


func _read_json(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not parsed is Dictionary:
		push_warning("GameState: %s ist unlesbar" % path)
		return null
	return parsed


func _write_json(path: String, data: Dictionary, pretty: bool = false) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("GameState: %s nicht schreibbar" % path)
		return
	file.store_string(JSON.stringify(data, "  " if pretty else ""))


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if err != OK:
			push_warning("GameState: %s liess sich nicht entfernen (%d)" % [path, err])


func _read_meta() -> Dictionary:
	var path := save_root + META_FILE
	if not FileAccess.file_exists(path):
		return {}
	var parsed = _read_json(path)
	return parsed if parsed != null else {}


## Der Stand von vor den Spielstaenden (eine Datei direkt in user://) zieht
## einmal in Spielstand 1 um -- wer schon gespielt hat, verliert nichts.
func _migrate_legacy() -> void:
	if save_root != "user://" or not FileAccess.file_exists(LEGACY_ROSTER_PATH):
		return
	if not slot_exists(1):
		for pair in [[LEGACY_ROSTER_PATH, ROSTER_FILE], [LEGACY_RUN_PATH, RUN_FILE]]:
			var data = _read_json(pair[0]) if FileAccess.file_exists(pair[0]) else null
			if data != null:
				_write_json(_slot_file(1, pair[1]), data)
		_write_json(save_root + META_FILE, {"last": 1})
		print("[GameState] alter Spielstand nach Spielstand 1 ueberfuehrt")
	_remove(LEGACY_ROSTER_PATH)
	_remove(LEGACY_RUN_PATH)


## Raeumt alle Spielstaende weg (Persistenz in der Konfiguration aus). Nur
## die ``user://``-Dateien: der Werkstatt-Export unter ``res://builds`` ist
## Entwickler-Material und im Export ohnehin schreibgeschuetzt.
func _wipe_saves() -> void:
	for which in range(1, SLOT_COUNT + 1):
		for file_name in [ROSTER_FILE, RUN_FILE, PROGRESS_FILE]:
			_remove(_slot_file(which, file_name))
	for path in [save_root + META_FILE, LEGACY_ROSTER_PATH, LEGACY_RUN_PATH, SQUAD_PATH]:
		_remove(path)


## Der neuere von Spielstand und Werkstatt-Export -- so muss der Spieler nicht
## wissen, welche Datei gewinnt. "" wenn keine existiert.
func _newest_save_file() -> String:
	var newest := ""
	var newest_time := -1
	for path in [_slot_file(slot, ROSTER_FILE), WORKSHOP_SQUAD_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var mtime := FileAccess.get_modified_time(ProjectSettings.globalize_path(path))
		if mtime > newest_time:
			newest_time = mtime
			newest = path
	return newest


# ---------------------------------------------------------------------------
# Gueltigkeit
# ---------------------------------------------------------------------------

func squad_is_valid() -> bool:
	if squad.size() < 1:
		return false
	for build in squad:
		if not build.is_valid():
			return false
	return true


# ---------------------------------------------------------------------------
# Kampfbereit
# ---------------------------------------------------------------------------

## Alle kampftauglichen DROMEs des Rosters -- die Grundgesamtheit, aus der die
## Aufstellung vor dem Lauf schoepft.
func battle_ready_builds() -> Array:
	var builds: Array = []
	for entry in roster.entries:
		var build := roster.build_for(entry)
		if build.is_valid():
			builds.append(build)
	return builds


## Ist der Endlos-Modus frei? Nach dem ersten gewonnenen Lauf in Neon City --
## oder mit dem Testschalter in den Optionen (``unlock_all``).
func endless_unlocked() -> bool:
	return bool(progress.get("story_cleared", false)) or bool(progress.get("unlock_all", false))


# --- Lauf (Roguelike) --------------------------------------------------------

## Der laufende Lauf, oder null. Lebt nur im Speicher -- wie Roster und
## Inventar in dieser Dev-Phase (save_enabled).
var run: RunState = null

## Feste Gegner fuer den naechsten Kampf (Lauf: die vorher gezeigten). Leer =
## der Kampf wuerfelt selbst.
var enemy_override: Array = []

## Feste Region fuer den naechsten Kampf (Lauf: sein Gebiet). Leer = der Kampf
## wuerfelt selbst.
var battle_region: StringName = &""

## Ob der naechste/aktuelle Kampf ein Kampf dieses Laufs ist. Dann kaempft der
## Lauf-Squad statt des Roster-Squads, es gibt keine Chaos-Beute, und das
## Ergebnis geht an den Lauf zurueck.
var in_run_battle: bool = false


## Startet einen Lauf mit den DROMEs, die gerade im Squad sind.
func start_run(seed_value: int = 0, mode: String = "story") -> void:
	refresh_squad()
	just_unlocked_endless = false
	run = RunState.start(seed_value if seed_value != 0 else randi(), squad, mode)
	save_run()


## Schreibt den Lauf in den Spielstand (10. Nov. 2026); ohne Lauf wird die
## Datei entfernt. Nach jeder Aenderung am Lauf gerufen (Zwischenstopp,
## Kampfende). Ein Kampf selbst wird nicht gespeichert: wer mittendrin
## schliesst, steht danach wieder vor demselben Kampf.
func save_run() -> void:
	if not _persistence_enabled() or slot == 0:
		return
	if run == null:
		_remove(_slot_file(slot, RUN_FILE))
		return
	_write_json(_slot_file(slot, RUN_FILE), run.to_dict())


## Holt einen gespeicherten Lauf zurueck (nach dem Hangar).
func load_run() -> void:
	run = null
	if not _persistence_enabled() or slot == 0:
		return
	var path := _slot_file(slot, RUN_FILE)
	if not FileAccess.file_exists(path):
		return
	var parsed = _read_json(path)
	if parsed == null:
		return
	run = RunState.from_dict(parsed)
	if run == null:
		push_warning("GameState: gespeicherter Lauf passt nicht zur Version -- verworfen")
		save_run()
	else:
		print("[GameState] Lauf fortgesetzt: Runde %d, %d Leben" % [run.round, run.lives])


## Setzt den gewaehlten Spielstand zurueck: Hangar, Lauf, Fortschritt
## (Optionen). Die anderen Spielstaende bleiben.
func reset_progress() -> void:
	run = null
	progress = {}
	just_unlocked_endless = false
	roster = Roster.new()
	roster.seed_starter()
	save_roster()
	save_run()
	save_progress()


## Bringt die nach Hause geschickte Beute ins Inventar: Teile als neue
## Instanzen, ein DROME als neuer Roster-Eintrag (nicht im Squad).
func deliver_run_home() -> Array:
	var delivered: Array = []
	if run == null:
		return delivered
	# Am Ende des Laufs: die gesammelten EP zuhause gutschreiben.
	if run.is_over() and not run.xp_credited:
		run.final_growth = credit_run_xp()
	for item in run.home_queue:
		match item.get("kind", ""):
			"part":
				roster.add_instance(item["part_id"])
				delivered.append(item)
			"drome":
				var build := RunState.drome_from_reward(item)
				var body := build.body()
				if body == null:
					continue
				roster.add_instance(body.id)
				var entry := roster.new_drome(body.id, build.display_name)
				if entry == null:
					continue
				var core := build.part_in("core")
				if core != null:
					entry.assignments["core"] = roster.add_instance(core.id)
				for slot in build.equip_slots():
					var part := build.part_in(slot)
					if part != null:
						entry.assignments[slot] = roster.add_instance(part.id)
				delivered.append(item)
	run.home_queue.clear()
	if not delivered.is_empty():
		save_roster()
	save_run()
	return delivered


## Richtet den Kampf der aktuellen Runde ein. Der Lauf-Squad wird KOPIERT:
## der Kampf soll den Lauf nicht veraendern, nur sein Ergebnis.
func begin_run_battle() -> void:
	if run == null:
		return
	in_run_battle = true
	squad = run.squad.map(func(b): return b.clone())
	battle_seed = run.battle_seed()
	battle_region = run.region_id
	enemy_override = run.enemies().map(func(b): return b.clone())


## Nimmt das Kampfergebnis zurueck in den Lauf und raeumt die Kampfparameter
## weg -- sonst erbte ein spaeterer Chaos-Kampf Seed und Gegnerstaerke.
func finish_run_battle(outcome: int, enemy_pool: Array, fighters: Array = []) -> void:
	if run != null:
		run.collect_xp(fighters, outcome == BattleManager.Outcome.VICTORY)
		run.record_result(outcome, enemy_pool)
		# Beute, die nicht mehr in Lager oder Squad passte, gleich nach Hause --
		# im Endlos-Modus erst am Ende (wer verliert, verliert sie).
		if not run.is_over() and not run.is_endless():
			deliver_run_home()
		# Neon City gewonnen: der Endlos-Modus ist frei.
		if run.phase == RunState.Phase.WON and not run.is_endless() \
				and not bool(progress.get("story_cleared", false)):
			progress["story_cleared"] = true
			just_unlocked_endless = true
			save_progress()
	in_run_battle = false
	enemy_override = []
	battle_region = &""
	battle_seed = 0
	refresh_squad()
	save_run()


## Schreibt die gesammelten EP des Laufs zuhause gut (Leveling) -- einmal, am
## Ende des Laufs. Gibt die Aenderungen fuer die Anzeige zurueck:
## [{name, kind ("drome"/"weapon"), gain, xp, level, up}].
func credit_run_xp() -> Array:
	var out: Array = []
	if run == null or run.xp_credited:
		return out
	run.xp_credited = true
	var dromes: Dictionary = run.pending_xp.get("dromes", {})
	for uid in dromes:
		var entry := roster.entry_by_chassis(str(uid))
		if entry == null:
			continue
		var up := entry.add_xp(int(dromes[uid]))
		out.append({"name": entry.name, "kind": "drome", "gain": int(dromes[uid]),
			"xp": entry.xp, "level": entry.level, "up": up})
	var weapons: Dictionary = run.pending_xp.get("weapons", {})
	for uid in weapons:
		var owned := roster.instance(str(uid))
		if owned == null:
			continue
		var up := owned.add_xp(int(weapons[uid]))
		var part := owned.part()
		out.append({"name": part.display_name if part != null else str(owned.part_id),
			"kind": "weapon", "gain": int(weapons[uid]), "xp": owned.xp, "level": owned.level, "up": up})
	save_roster()
	return out
