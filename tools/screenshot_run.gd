extends SceneTree

## Bild des Lauf-Bildschirms (Karte, Vorschau) in Handygroesse:
##
##     xvfb-run -a -s "-screen 0 900x1600x24" godot --path . --resolution 450x800 \
##         --script res://tools/screenshot_run.gd -- <ziel.png> <seed> <siege>
##
## Startet einen Lauf mit ``seed``, gewinnt ``siege`` Runden ohne Kampf und
## fotografiert dann die Wegwahl. Als Werkzeug (res://tools/) beruehrt es den
## Spielstand nicht.

var _frame := 0


func _process(_d: float) -> bool:
	_frame += 1
	var args := OS.get_cmdline_user_args()
	if _frame == 2:
		var gs = root.get_node("GameState")
		gs.start_run(int(args[1]) if args.size() > 1 else 4242)
		for i in (int(args[2]) if args.size() > 2 else 0):
			gs.run.record_result(1, [])
			gs.run.continue_run()
		change_scene_to_file("res://scenes/run.tscn")
	if _frame == 40:
		var img := root.get_texture().get_image()
		img.save_png(args[0] if args.size() > 0 else "/tmp/run.png")
		quit(0)
	return false
