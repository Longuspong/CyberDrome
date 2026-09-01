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

## Wohin das Spiel schreibt (v2: Inventar + Roster).
const ROSTER_PATH := "user://roster.json"

## Altformate, aus denen migriert wird. ``SQUAD_PATH`` ist der fruehere
## Wegwerf-Squad des Spiels; ``WORKSHOP_SQUAD_PATH`` liefert die SVG-Werkstatt
## (python3 main.py) neben die Builds. Beide tragen das v1-Loadout-Format. Der
## neuere der drei Dateien gewinnt beim Start, damit ein frisch gebauter Squad
## nicht von einem alten Stand verdeckt wird -- und ein v1-Squad wird dabei
## einmalig in den Roster ueberfuehrt.
const SQUAD_PATH := "user://squad.json"
const WORKSHOP_SQUAD_PATH := "res://builds/squad.json"

## Der Besitz: Inventar (Instanzen) + Roster (DROMEs). Quelle der Wahrheit.
var roster: Roster = Roster.new()

## Welchen Roster-Eintrag die Werkstatt gerade anpasst. Die Garage setzt ihn vor
## dem Szenenwechsel; -1 heisst "keiner gewaehlt".
var editing_index: int = -1

## Die DROMEs des naechsten Gefechts -- abgeleitet aus den ``in_squad``-Eintraegen
## des Rosters. Array[DromeBuild]. Der Kampf liest genau das.
var squad: Array = []

## Bestimmt Gegner, Mutator, Karte und Aufstellung. Wird im Ergebnis-
## bildschirm angezeigt und kann im Startdialog gesetzt werden: derselbe Seed
## ergibt exakt denselben Kampf. Im Playtesting ist das Gold wert.
var battle_seed: int = 0

## Ergebnis des letzten Kampfes, fuer den Ergebnisbildschirm
var last_result: Dictionary = {}


func _ready() -> void:
	load_roster()


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

## Ob ueberhaupt auf die Platte geschrieben und von dort geladen wird. In der
## Dev-Phase steht ``save_enabled`` in data/config.json auf false: dann bleibt
## der Roster ein reiner Laufzeit-Bestand, jeder Start beginnt frisch. Die
## ganze Persistenz haengt an diesem einen Schalter -- umlegen genuegt, sobald
## Spielstaende gewollt sind.
func _persistence_enabled() -> bool:
	return bool(Config.get_value("save_enabled", false))


func save_roster() -> void:
	# refresh_squad() IMMER: der Kampf liest die abgeleitete Squad-Liste, und die
	# Garage ruft save_roster() nach jeder Aenderung genau dafuer -- unabhaengig
	# davon, ob der Stand auch auf die Platte geht.
	refresh_squad()
	if not _persistence_enabled():
		return
	var file := FileAccess.open(ROSTER_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: %s nicht schreibbar" % ROSTER_PATH)
		return
	file.store_string(JSON.stringify(roster.to_dict(), "  "))


func load_roster() -> void:
	# Persistenz aus (Dev-Phase): frisch starten und einen alten Stand wegraeumen,
	# statt ihn zu laden. So kann ein kaputter Spielstand aus einer aelteren
	# Version das Spiel nicht mehr in einen unbrauchbaren Zustand ziehen.
	if not _persistence_enabled():
		_wipe_saves()
		roster.seed_starter()
		refresh_squad()
		print("[GameState] Persistenz aus -- Startbestand gesetzt: %d DROMEs, %d Instanzen"
			% [roster.entries.size(), roster.all_instances().size()])
		return

	var path := _newest_save_file()
	if path == "":
		# Ein frischer Start: der handgesetzte Startbestand (§10g).
		roster.seed_starter()
		refresh_squad()
		print("[GameState] Kein Spielstand -- Startbestand gesetzt: %d DROMEs, %d Instanzen"
			% [roster.entries.size(), roster.all_instances().size()])
		return

	var parsed = _read_json(path)
	if parsed == null:
		roster.seed_starter()
		refresh_squad()
		return

	# v2 (Roster) direkt laden; ein v1-Stand (Wegwerf-Squad, auch der SVG-Export)
	# wird migriert und beim naechsten Speichern als v2 abgelegt.
	var loaded := false
	if int(parsed.get("version", 0)) >= 2:
		loaded = roster.load_dict(parsed)
	else:
		loaded = roster.migrate_v1(parsed)
		if loaded:
			print("[GameState] v1-Squad aus %s in den Roster ueberfuehrt" % path)
	if not loaded:
		roster.seed_starter()

	refresh_squad()
	print("[GameState] Roster aus %s: %d DROMEs, %d im Squad"
		% [path, roster.entries.size(), roster.squad_count()])


func _read_json(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not parsed is Dictionary:
		push_warning("GameState: %s ist unlesbar" % path)
		return null
	return parsed


## Raeumt die beschreibbaren Spielstaende weg (der Reset). Nur die ``user://``-
## Dateien: der Werkstatt-Export unter ``res://builds`` ist Entwickler-Material
## und im Export ohnehin schreibgeschuetzt. Fehlt eine Datei, ist nichts zu tun.
func _wipe_saves() -> void:
	for path in [ROSTER_PATH, SQUAD_PATH]:
		if FileAccess.file_exists(path):
			var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			if err == OK:
				print("[GameState] alter Spielstand entfernt: %s" % path)
			else:
				push_warning("GameState: %s liess sich nicht entfernen (%d)" % [path, err])


## Der neuere von Spielstand und Werkstatt-Export -- so muss der Spieler nicht
## wissen, welche Datei gewinnt. "" wenn keine existiert.
func _newest_save_file() -> String:
	var newest := ""
	var newest_time := -1
	for path in [ROSTER_PATH, SQUAD_PATH, WORKSHOP_SQUAD_PATH]:
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
