extends SceneTree

## Schiesst ein Bild einer Szene.
##
##     xvfb-run -a -s "-screen 0 1600x900x24" godot --path . \
##         --resolution 1600x900 --script res://tests/screenshot.gd \
##         -- <szene> <zieldatei> [frames] [eigenschaft=wert ...]
##
## eigenschaft=wert setzt vorher eine Eigenschaft von GameState (z. B.
## editing_index=0 oeffnet den Hangar im Umbau). Werte werden mit
## str_to_var gelesen.
##
## Der Blicktest fuer alles, was kein Unit-Test sieht: ob die Tiefensortierung
## stimmt und die DROMEs auf ihren Feldern stehen.

const SEED := 20260806

var _frames := 0
var _target := "/tmp/drome.png"
var _limit := 150
var _scene := ""
var _extras: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene: String = args[0] if args.size() > 0 else "res://scenes/battle.tscn"
	if args.size() > 1:
		_target = args[1]
	if args.size() > 2:
		_limit = int(args[2])

	_scene = scene
	_extras = args.slice(3)


## Erst im ersten Bild: die Autoloads sind dann bereit (ihr _ready setzt
## sonst den Einsatz wieder zurueck).
func _setup() -> void:
	# Autoloads ueber den Knotenpfad statt ueber den Namen: der Bezeichner ist
	# beim Kompilieren des Hauptskripts noch nicht registriert.
	var state = root.get_node_or_null("GameState")
	if state != null:
		state.battle_seed = SEED
		for extra in _extras:
			var pair := str(extra).split("=", true, 1)
			if pair.size() != 2:
				continue
			match pair[0]:
				# run=story|endless startet einen Einsatz.
				"run":
					state.start_run(SEED, pair[1])
				# results=SSN: Kaempfe eintragen (S Sieg, N Niederlage); danach
				# steht der Einsatz im Zwischenstopp (oder am Ende).
				"results":
					for c in pair[1]:
						if state.run.phase != 0:
							state.run.continue_run()
						state.run.record_result(1 if c == "S" else 2, [])
				# caches=city:3,green:1 legt Lootcaches in den Hangar.
				"caches":
					for item in pair[1].split(","):
						var kv := item.split(":")
						state.roster.caches[kv[0]] = int(kv[1])
				# static=res://pfad.gd:variable:wert setzt eine statische Variable
				# (z. B. den Reiter im Shop).
				"static":
					var bits := pair[1].rsplit(":", true, 2)
					load(bits[0]).set(bits[1], str_to_var(bits[2]))
				# weiter=1: nach dem letzten Ergebnis zur Kampfkarte.
				"weiter":
					state.run.continue_run()
				_:
					state.set(pair[0], str_to_var(pair[1]))
	change_scene_to_file(_scene)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_setup()
	# cache_open=city[:auf]: legt nach dem Laden den Cache-Bildschirm darueber
	# (":auf" = gleich geoeffnet).
	if _frames == 20:
		for extra in _extras:
			if str(extra).begins_with("cache_open="):
				var bits := str(extra).substr(11).split(":")
				var opener = load("res://scripts/ui/cache_opener.gd").show_over(current_scene, bits[0])
				if bits.size() > 1:
					opener.call_deferred("_open")
			# kampf=los: im Kampfbildschirm die Aufstellung beenden, der Kampf laeuft.
			if str(extra) == "kampf=los" and current_scene.has_method("_start_fight"):
				current_scene.call("_start_fight")
			# karte=eq_hammer: die Waffen-Karte dieses Teils ueber der Szene.
			if str(extra).begins_with("karte="):
				var part = root.get_node("PartDB").get_part(StringName(str(extra).substr(6)))
				load("res://scripts/ui/weapon_card.gd").open(current_scene, part, Callable(),
					[{"text": "Einbauen", "primary": true}])
			# story=links|rechts: ein Probe-Dialog (StoryDialog) ueber der Szene.
			if str(extra).begins_with("story="):
				var right := str(extra).ends_with("rechts")
				load("res://scripts/ui/story_dialog.gd").play(current_scene, [
					{"name": "Sola" if right else "Kage-9",
					"faction": "Solar Sentients" if right else "Neon Ninja's",
					"side": "right" if right else "left",
					"look": "sprout" if right else "ninja",
					"color": Color("#5cf2a2") if right else Color("#ff2bd6"),
					"text": "Lass den Neuen in Ruhe, Kage. Die Parkanlage wartet." if right
						else "Du hast es also durch Neon City geschafft. Nicht schlecht für ein Squad aus Schrottteilen."},
					{"name": "Kage-9", "faction": "Neon Ninja's", "text": "..."}])
	if _frames < _limit:
		return false
	root.get_texture().get_image().save_png(_target)
	print("Bild geschrieben: ", _target)
	return true
