extends SceneTree

## Schiesst ein Bild der laufenden Kampfszene.
##
##     xvfb-run -a -s "-screen 0 1600x900x24" \
##         godot --path . --resolution 1600x900 --script res://tests/screenshot.gd
##     -> /tmp/drome_battle.png
##
## Der Blicktest fuer alles, was kein Unit-Test sieht: ob die Tiefensortierung
## stimmt, ob ein Betonpfeiler den DROME davor verdeckt und den dahinter
## nicht, ob die Drift-Pfeile in die Richtung zeigen, in die tatsaechlich
## geschoben wird. tests/visual_check.gd macht dasselbe fuer die Projektion
## allein, ohne Szene.

const SEED := 20260806
const FRAMES := 150

var _frames := 0


func _initialize() -> void:
	# Autoloads ueber den Knotenpfad statt ueber den Namen: der Bezeichner ist
	# beim Kompilieren des Hauptskripts noch nicht registriert.
	var state = root.get_node_or_null("GameState")
	if state != null:
		state.battle_seed = SEED
	change_scene_to_file("res://scenes/battle.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < FRAMES:
		return false
	root.get_texture().get_image().save_png("/tmp/drome_battle.png")
	print("Bild geschrieben: /tmp/drome_battle.png")
	return true
