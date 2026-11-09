extends SceneTree

## Lauf-Messung ohne Bildschirm: der Standard-Squad (ohne Beute, ohne Module)
## gegen die Lauf-Gegner je Runde und Stufe -- einmal mit ihren Modulen, einmal
## ohne. Zeigt, wie stark die Gegner-Module (6i) die Kurve verschieben.
##
##     godot --headless --path . --script res://tools/playtest/run_bench.gd -- [laeufe] [DROME-Lv] [Waffen-Lv]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var count := int(args[0]) if args.size() > 0 else 40
	var drome_level := int(args[1]) if args.size() > 1 else 0
	var weapon_level := int(args[2]) if args.size() > 2 else 0
	load("res://tools/playtest/run_bench_logic.gd").new().run(count, drome_level, weapon_level)
	quit(0)
