extends SceneTree

## Schiesst ein Bild einer Szene.
##
##     xvfb-run -a -s "-screen 0 1600x900x24" godot --path . \
##         --resolution 1600x900 --script res://tests/screenshot.gd \
##         -- <szene> <zieldatei> [frames]
##
## Der Blicktest fuer alles, was kein Unit-Test sieht: ob die Tiefensortierung
## stimmt, ob ein Betonpfeiler den DROME davor verdeckt und den dahinter
## nicht, ob die Drift-Pfeile in die Richtung zeigen, in die geschoben wird.
## tests/visual_check.gd macht dasselbe fuer die Projektion allein.

const SEED := 20260806

var _frames := 0
var _target := "/tmp/drome.png"
var _limit := 150


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene: String = args[0] if args.size() > 0 else "res://scenes/battle.tscn"
	if args.size() > 1:
		_target = args[1]
	if args.size() > 2:
		_limit = int(args[2])

	# Autoloads ueber den Knotenpfad statt ueber den Namen: der Bezeichner ist
	# beim Kompilieren des Hauptskripts noch nicht registriert.
	var state = root.get_node_or_null("GameState")
	if state != null:
		state.battle_seed = SEED
	change_scene_to_file(scene)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < _limit:
		return false
	root.get_texture().get_image().save_png(_target)
	print("Bild geschrieben: ", _target)
	return true
