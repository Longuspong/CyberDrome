extends Node

## Was zwischen den Bildschirmen ueberlebt: der Squad, der Seed, das Ergebnis.
##
## Die Werkstatt kennt die Kampfszene nicht und umgekehrt. Beide reden nur
## hierueber -- sonst haengt der Rueckweg vom Ergebnisbildschirm an einem
## Szenenpfad, und ein zweiter Einstieg in den Kampf ist nicht mehr moeglich.

## Wohin das Spiel schreibt.
const SQUAD_PATH := "user://squad.json"

## Woher die SVG-Werkstatt liefert. Sie ist ein eigenstaendiges Werkzeug
## (python3 main.py) und kann nicht in Godots user://-Verzeichnis schreiben --
## sie legt ihren Squad neben die Builds. Beim Start gewinnt der neuere der
## beiden, damit ein frisch gebauter Squad nicht von einem alten Spielstand
## verdeckt wird.
##
## Dieser Weg ueberlebt einen Export NICHT: builds/ liegt im Repo und nicht im
## Spielpaket. Das ist kein Mangel -- die SVG-Werkstatt laeuft ohnehin nur
## neben dem Quellbaum. Im ausgelieferten Spiel baut man in der
## Godot-Werkstatt, und die schreibt nach user://.
const WORKSHOP_SQUAD_PATH := "res://builds/squad.json"

## Wie viele DROMEs ein Squad hat. Konfigurierbar 1-4.
var squad_size: int = 2

## Array[DromeBuild] -- die Bots des Spielers
var squad: Array = []

## Bestimmt Gegner, Mutator, Karte und Aufstellung. Wird im Ergebnis-
## bildschirm angezeigt und kann im Startdialog gesetzt werden: derselbe Seed
## ergibt exakt denselben Kampf. Im Playtesting ist das Gold wert.
var battle_seed: int = 0

## Ergebnis des letzten Kampfes, fuer den Ergebnisbildschirm
var last_result: Dictionary = {}

func _ready() -> void:
	load_squad()


func new_seed() -> int:
	battle_seed = randi()
	return battle_seed


## Squad als JSON. Bewusst dasselbe Loadout-Format wie die SVG-Werkstatt es
## exportiert -- ein Build aus builds/ laesst sich damit direkt spielen.
func save_squad() -> void:
	var payload := {
		"squad_size": squad_size,
		"squad": [],
	}
	for build in squad:
		payload["squad"].append(build.to_loadout())
	var file := FileAccess.open(SQUAD_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: %s nicht schreibbar" % SQUAD_PATH)
		return
	file.store_string(JSON.stringify(payload, "  "))


func load_squad() -> void:
	squad.clear()
	var path := _newest_squad_file()
	if path == "":
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not parsed is Dictionary:
		push_warning("GameState: %s ist unlesbar, Squad bleibt leer" % path)
		return

	squad_size = parsed.get("squad_size", squad_size)
	# Aeltere Spielstaende koennen noch ein "ignore_build_limits" tragen -- das
	# Feld ist bedeutungslos geworden (es gibt keine Bau-Budgets mehr) und wird
	# beim Lesen einfach ignoriert.
	for loadout in parsed.get("squad", []):
		var build := DromeBuild.from_loadout(loadout)
		if build != null:
			squad.append(build)
	print("[GameState] Squad aus %s: %d DROMEs" % [path, squad.size()])


## Der neuere von Spielstand und Werkstatt-Export. Ohne diesen Vergleich
## muesste der Spieler wissen, welche der beiden Dateien gewinnt -- und ein in
## der Werkstatt gebauter Squad taeuchte im Kampf einfach nicht auf.
func _newest_squad_file() -> String:
	var candidates: Array[String] = []
	for path in [SQUAD_PATH, WORKSHOP_SQUAD_PATH]:
		if FileAccess.file_exists(path):
			candidates.append(path)
	if candidates.is_empty():
		return ""
	if candidates.size() == 1:
		return candidates[0]
	var a := FileAccess.get_modified_time(ProjectSettings.globalize_path(candidates[0]))
	var b := FileAccess.get_modified_time(ProjectSettings.globalize_path(candidates[1]))
	return candidates[0] if a >= b else candidates[1]


func squad_is_valid() -> bool:
	if squad.size() < 1:
		return false
	for build in squad:
		if not build.is_valid():
			return false
	return true
