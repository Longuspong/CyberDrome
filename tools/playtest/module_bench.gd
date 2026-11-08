extends SceneTree

## Modul-Messung ohne Bildschirm: der Standard-Squad mit Modulen gegen eine
## Kopie von sich selbst ohne Module, je Aufbau viele Kaempfe.
##
##     godot --headless --path . --script res://tools/playtest/module_bench.gd -- [kaempfe] [aufbau ...]
##
## Ein Aufbau ist "Name=mod_a+mod_b" (Name = Anzeigename des DROME, z. B.
## Vireo=mod_takt_chip+mod_takt_chip); mehrere DROMEs mit "/" trennen.
## Ohne Aufbau laeuft eine feste Liste (siehe module_bench_logic.gd).
## Jeder Seed wird zweimal gespielt, mit getauschten Seiten.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var count := int(args[0]) if args.size() > 0 else 400
	var setups: Array = []
	for i in range(1, args.size()):
		setups.append(args[i])
	var logic = load("res://tools/playtest/module_bench_logic.gd").new()
	logic.run(count, setups)
	quit(0)
