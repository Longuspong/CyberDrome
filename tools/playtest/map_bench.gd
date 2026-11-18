extends SceneTree

## Karten-Messung ohne Bildschirm (18. Nov. 2026): dieselben Kaempfe auf
## verschiedenen Kartengroessen und -formen. Je Karte: Siege, Dauer, erster
## Treffer, Laufanteil -- und Siege je Formation (welche Karte passt zu
## welchem Trupp).
##
##     godot --headless --path . --script res://tools/playtest/map_bench.gd -- [seeds] [level] [nur-karte]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var count := int(args[0]) if args.size() > 0 else 6
	var level := int(args[1]) if args.size() > 1 else 4
	var only := str(args[2]) if args.size() > 2 else ""
	load("res://tools/playtest/map_bench_logic.gd").new().run(count, level, only)
	quit(0)
