extends SceneTree

## Smoke-Test der UI-Szenen: instanziiert den Hangar (Squad, dann Umbau)
## headless und prueft, dass ihr _ready ohne Laufzeitfehler durchlaeuft. Die
## regulaeren Tests pruefen das Datenmodell; hier geht es nur darum, dass die
## Bildschirme sich ueberhaupt aufbauen. Kein Teil der SUITES -- eigener Lauf:
##
##     godot --headless --path . --script res://tests/smoke_ui.gd
##
## Der Autoload wird ueber den Knotenpfad geholt, nicht ueber den globalen Namen:
## das Einstiegsskript wird kompiliert, bevor die Autoload-Namen registriert
## sind -- ``GameState`` als Bezeichner gaebe hier einen Compilefehler.

var _frame := 0


func _game_state() -> Node:
	return root.get_node("GameState")


func _process(_delta: float) -> bool:
	_frame += 1
	var gs := _game_state()
	match _frame:
		2:
			var hangar = load("res://scenes/hangar.tscn").instantiate()
			root.add_child(hangar)
			print("SMOKE: Hangar (Squad) instanziiert (%d DROMEs, %d im Squad)"
				% [gs.roster.entries.size(), gs.roster.squad_count()])
		5:
			for child in root.get_children():
				if child.name == "Hangar":
					child.free()
		7:
			# Mit gewaehltem Eintrag oeffnet der Hangar direkt den Umbau.
			gs.editing_index = 0
			var umbau = load("res://scenes/hangar.tscn").instantiate()
			root.add_child(umbau)
			print("SMOKE: Hangar (Umbau) instanziiert fuer '%s'"
				% gs.roster.entries[0].name)
		12:
			print("SMOKE_OK")
			quit(0)
	return false
