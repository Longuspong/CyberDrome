extends SceneTree

## Testlauf ohne Editor:
##
##     godot --headless --script res://tests/run_tests.gd
##
## Bewusst kein Test-Framework als Abhaengigkeit. Das Projekt kommt bis hierher
## ohne node_modules und ohne pip aus; ein Runner in 40 Zeilen haelt das
## durch, und die Tests sind dieselben.

var _passed := 0
var _failed := 0
var _current := ""

const SUITES := [
	"res://tests/test_drome_build.gd",
	"res://tests/test_drome_sprites.gd",
	"res://tests/test_grid.gd",
	"res://tests/test_tick_bus.gd",
	"res://tests/test_reachability.gd",
	"res://tests/test_aggro.gd",
	"res://tests/test_battle.gd",
	"res://tests/test_workshop_handoff.gd",
	"res://tests/test_ui_pieces.gd",
]


## _initialize() statt _init(): zu Zeiten von _init() steht der Baum noch nicht,
## die Autoloads (PartDB!) fehlen, und ein quit() dort verpufft -- der Prozess
## laeuft dann bis zum Timeout weiter, statt einen Exitcode zu liefern.
func _initialize() -> void:
	print("\n=== DROME Tests ===\n")
	for path in SUITES:
		if not ResourceLoader.exists(path):
			print("  [uebersprungen] %s fehlt noch" % path)
			continue
		var name: String = path.get_file().get_basename()
		# Ein Suite-Script mit Syntaxfehler laedt nicht. Ohne diese Pruefung
		# lief der Durchgang danach in einen Fehlerlauf ohne Ausgabe und ohne
		# Exitcode -- ein Tippfehler in einer Suite sah damit aus wie ein
		# haengender Testlauf. Hier wird daraus ein Fehlschlag mit Namen.
		var script = load(path)
		var suite = script.new() if script is GDScript else null
		if suite == null:
			_current = name
			ok(false, "Suite laedt nicht (Syntaxfehler in %s?)" % path)
			continue
		suite.t = self
		print("-- %s" % name)
		for method in suite.get_method_list():
			if not method["name"].begins_with("test_"):
				continue
			_current = "%s.%s" % [name, method["name"]]
			suite.call(method["name"])
		print("")

	print("=== %d bestanden, %d fehlgeschlagen ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func ok(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("  [FEHLER] %s: %s" % [_current, message])


func equal(actual, expected, message: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		print("  [FEHLER] %s: %s\n           erwartet %s, war %s"
			% [_current, message, expected, actual])


func note(text: String) -> void:
	print("  %s" % text)
