extends SceneTree

## Playtest ohne Bildschirm: spielt viele Autokaempfe mit dem Start-Squad
## gegen gewuerfelte Gegner und schreibt je DROME mit, was er tut.
##
##     godot --headless --path . --script res://tools/playtest/playtest.gd -- [kaempfe] [detail-seed]
##
## Die Logik steht in playtest_logic.gd (RefCounted, zur Laufzeit geladen),
## weil ein SceneTree-Skript vor den Autoloads kompiliert.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var count := int(args[0]) if args.size() > 0 else 30
	var detail := int(args[1]) if args.size() > 1 else 0
	var logic = load("res://tools/playtest/playtest_logic.gd").new()
	logic.run(count, detail)
	quit(0)
