extends SceneTree

## Wie gut sagt der Kampfwert den Ausgang eines Kampfes voraus?
##
## Wuerfelt Paarungen aus zufaelligen Squads (1-4 DROMEs je Seite, zur Haelfte
## mit Leveln und Modulen), laesst sie kaempfen und zaehlt, wie oft die Seite
## mit dem hoeheren Kampfwert gewinnt.
##
##     godot --headless --path . --script res://tools/playtest/power_bench.gd -- [kaempfe] [ausgabe.json] [seed]
##
## Mit einer Ausgabedatei werden die Rohdaten je Kampf geschrieben (Werte und
## Waffen jedes DROME, Ergebnis) -- damit laesst sich eine Formel ausserhalb
## des Spiels anpassen.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var count := int(args[0]) if args.size() > 0 else 300
	var out := str(args[1]) if args.size() > 1 else ""
	var seed_base := int(args[2]) if args.size() > 2 else 77000
	load("res://tools/playtest/power_bench_logic.gd").new().run(count, out, seed_base)
	quit(0)
