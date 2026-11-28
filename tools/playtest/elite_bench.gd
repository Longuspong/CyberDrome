extends SceneTree

## Elite-Messung ohne Bildschirm (28. Nov. 2026): verschiedene Squads aus den
## vier Standard-DROMEs, je DROME eine zufaellige passende Fusion (Rezeptmodul),
## gegen alle Elite-Formationen einer Runde -- die Gegner wie im Lauf
## (Reinforcement-Level, Elite-Ränge, Module, Level). Formationen mit Neon
## Nimbus laufen zusaetzlich mit dem Supporter-Nimbus an seiner Stelle.
##
##     godot --headless --path . --script res://tools/playtest/elite_bench.gd -- [laeufe] [DROME-Lv] [Waffen-Lv]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var count := int(args[0]) if args.size() > 0 else 12
	var drome_level := int(args[1]) if args.size() > 1 else 0
	var weapon_level := int(args[2]) if args.size() > 2 else 0
	load("res://tools/playtest/elite_bench_logic.gd").new().run(count, drome_level, weapon_level)
	quit(0)
