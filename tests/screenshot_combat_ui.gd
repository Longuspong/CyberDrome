extends SceneTree

## Blicktest fuer die Kampf-BEDIENUNG.
##
##     xvfb-run -a -s "-screen 0 1600x900x24" godot --path . \
##         --resolution 1600x900 --script res://tests/screenshot_combat_ui.gd \
##         -- /tmp/drome_combat_ui.png
##
## tests/screenshot.gd zeigt die Karte, wie sie beim Start dasteht -- und genau
## dort ist von der Bedienung nichts zu sehen: die Gegner stehen ausser
## Reichweite, kein Ring ist angeheftet, keine Aktion gewaehlt. Alles, was der
## Spieler zum Planen braucht, erscheint erst im Zusammenspiel.
##
## Dieses Skript stellt das Zusammenspiel her: es holt einen Gegner in
## Reichweite, heftet den Aktionsring an ihn und legt den Zeiger auf eine
## Aktion. Was danach im Bild steht, ist die Antwort auf die Frage, ob der
## Kampf lesbar ist -- Reichweite eingefaerbt, Schadenszahl ueber dem Ziel,
## Ring bedienbar stehengeblieben.
##
## Kein Unit-Test kann das: dass ein Ring VERSCHWINDET, sobald man den Zeiger
## zu ihm bewegt, ist kein falscher Rueckgabewert, sondern ein Bild.

const SEED := 20260806

var _frames := 0
var _target := "/tmp/drome_combat_ui.png"
var _armed := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_target = args[0]


## Bewusst ueber load() und nicht ueber den Klassennamen: beim Kompilieren des
## HAUPTSKRIPTS sind die Autoloads noch nicht als Bezeichner registriert, und
## DromeBuild greift auf PartDB zu. Ein direktes ``DromeBuild.create(...)``
## bricht deshalb mit "Identifier not found: PartDB" ab, bevor die Szene
## ueberhaupt startet. Dieselbe Falle steht in tests/screenshot.gd als Notiz.
func _nimbus(name: String):
	var build_class = load("res://scripts/core/drome_build.gd")
	return build_class.create(name, {
		"body": &"mage_body", "head": &"mage_head",
		"feet": &"mage_drive", "core": &"mage_core",
		"equip_left": &"eq_rune_staff", "equip_right": &"eq_orbit_focus",
	})


func _process(_delta: float) -> bool:
	_frames += 1
	# Erst ab dem zweiten Bild: der Squad wird in GameState._ready() aus dem
	# Spielstand geladen, und dieses _process laeuft im selben Bild schon
	# davor. Frueher gesetzt waere er sofort wieder ueberschrieben -- das Bild
	# zeigte dann den gespeicherten Squad und nicht den gemeinten.
	if _frames == 2:
		_deploy()
		return false
	if _frames == 45:
		_arrange()
		return false
	if _frames < 95:
		return false
	root.get_texture().get_image().save_png(_target)
	print("Bild geschrieben: ", _target)
	return true


func _deploy() -> void:
	var state = root.get_node_or_null("GameState")
	if state != null:
		state.battle_seed = SEED
		# Zweimal derselbe Aufbau: Runenstab (Angriff) plus Orbit-Fokus
		# (Faehigkeit). Damit zeigt das Bild beide Gruppen der Aktionsleiste,
		# egal welcher der beiden DROMEs zuerst zieht -- und die Trennung nach
		# Budget ist genau das, was hier zu sehen sein soll.
		state.squad = [_nimbus("ALPHA"), _nimbus("BETA")]
	change_scene_to_file("res://scenes/battle.tscn")


## Stellt die Lage her, die das Bild zeigen soll.
func _arrange() -> void:
	var screen = root.get_node_or_null("Battle")
	if screen == null:
		push_error("Kampfszene nicht gefunden")
		return
	var battle = screen.battle
	var actor = battle.active_unit
	if actor == null or not actor.is_player:
		push_error("Es zieht kein Spieler-DROME")
		return

	# Einen Gegner in Reichweite holen. Ueber move_unit(), damit Belegung und
	# Gleiten stimmen -- ein von Hand gesetztes place_at() liesse das Gitter mit
	# einer Leiche auf dem alten Feld zurueck.
	var foe = battle.enemies_of(actor)[0]
	var landing := _free_tile_near(battle, actor, foe)
	if landing != Vector2i(-1, -1):
		battle.resolver.move_unit(foe, landing, Vector2i(0, -1))

	screen._on_hover(foe.tile)
	screen._on_click(foe.tile)          # heftet den Ring an
	var attacks = actor.actions_of(ActionData.Category.ATTACK)
	if not attacks.is_empty():
		screen._on_action_hovered(attacks[0])   # faerbt ihre Reichweite ein


## Ein freies Feld zwei Schritte vor dem aktiven DROME.
func _free_tile_near(battle, actor, foe) -> Vector2i:
	var profile = foe.move_profile()
	for offset in [Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2),
			Vector2i(3, 0), Vector2i(0, 3), Vector2i(1, 2)]:
		var candidate: Vector2i = actor.tile + offset
		if battle.grid.can_stand_on(candidate, profile):
			return candidate
	return Vector2i(-1, -1)
