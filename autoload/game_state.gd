extends Node

## Was zwischen den Bildschirmen ueberlebt: der Squad, der Seed, das Ergebnis.
##
## Die Werkstatt kennt die Kampfszene nicht und umgekehrt. Beide reden nur
## hierueber -- sonst haengt der Rueckweg vom Ergebnisbildschirm an einem
## Szenenpfad, und ein zweiter Einstieg in den Kampf ist nicht mehr moeglich.

const SQUAD_PATH := "user://squad.json"

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
	var payload := {"squad_size": squad_size, "squad": []}
	for build in squad:
		payload["squad"].append(build.to_loadout())
	var file := FileAccess.open(SQUAD_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: %s nicht schreibbar" % SQUAD_PATH)
		return
	file.store_string(JSON.stringify(payload, "  "))


func load_squad() -> void:
	squad.clear()
	if not FileAccess.file_exists(SQUAD_PATH):
		return
	var file := FileAccess.open(SQUAD_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not parsed is Dictionary:
		push_warning("GameState: %s ist unlesbar, Squad bleibt leer" % SQUAD_PATH)
		return
	squad_size = parsed.get("squad_size", squad_size)
	for loadout in parsed.get("squad", []):
		var build := DromeBuild.from_loadout(loadout)
		if build != null:
			squad.append(build)


func squad_is_valid() -> bool:
	if squad.size() < 1:
		return false
	for build in squad:
		if not build.is_valid():
			return false
	return true
