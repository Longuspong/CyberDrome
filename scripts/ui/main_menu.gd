extends Control

## Die Startseite -- mobile first, Hochformat.
##
##   oben     der Name des Spiels
##   Mitte    die Kulisse: zufaellige DROMEs, die einander bearbeiten
##            (MenuArena). Sie fuellt den Platz, den die Knoepfe uebrig lassen.
##   unten    die Hauptaktion "Lauf starten", darunter der Chaos-Virus
##   Leiste   Spielen · Hangar · Optionen (UiKit.tab_bar)
##
## Der Daumen erreicht unten alles, was man hier tut; oben steht nur, was man
## ansieht.

var _status: Label
var _chaos: Button
var _stage: Control
var _arena: MenuArena


func _ready() -> void:
	var content := UiKit.page(self, "", "", 0, false, Ambience.Kind.MENU)

	var title := UiKit.label("CYBERDROME", 40, UiKit.HEADING)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var subtitle := UiKit.label("Baue DROMEs. Lass sie kaempfen.", UiKit.SMALL, UiKit.MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)

	# Die Buehne der Kulisse. Ein Control, damit sie im Layout Platz bekommt;
	# die Bots selbst sind ein Node2D darin, mittig und auf die Breite skaliert.
	_stage = Control.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.custom_minimum_size = Vector2(0, 180)
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_stage)
	_arena = MenuArena.new()
	_stage.add_child(_arena)
	_stage.resized.connect(_place_arena)
	_arena.start()

	_status = UiKit.label("", UiKit.SMALL)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_status)

	var run := UiKit.button("Lauf starten", true)
	run.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/run.tscn"))
	content.add_child(run)
	var run_hint := UiKit.label("Roguelike: 8 Autokaempfe, 3 Leben, Beute nach jedem Sieg.",
		UiKit.SMALL, UiKit.MUTED)
	run_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(run_hint)

	_chaos = UiKit.button("Chaos-Virus")
	_chaos.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/chaos_select.tscn"))
	content.add_child(_chaos)

	_refresh_status()
	run.grab_focus.call_deferred()


## Die Kulisse braucht rund 460 Pixel Breite (zwei Teams links und rechts der
## Mitte) und 240 Hoehe. Sie wird so gross wie moeglich eingepasst -- auf dem
## Handy ist die Buehne hoch, aber schmal, also entscheidet meist die Breite.
func _place_arena() -> void:
	var area := _stage.size
	var fit := clampf(minf(area.x / 460.0, area.y / 240.0), 0.4, 1.6)
	_arena.scale = Vector2(fit, fit)
	_arena.position = Vector2(area.x * 0.5, area.y * 0.62)


func _refresh_status() -> void:
	# Chaos-Virus und Lauf brauchen kampftaugliche eigene DROMEs; die
	# Aufstellung im Lauf sagt es selbst, hier steht es fuer den Chaos-Virus.
	var ready := not GameState.battle_ready_builds().is_empty()
	if ready:
		_status.text = ""
		_status.visible = false
	else:
		_status.text = "Fuer den Chaos-Virus fehlen kampftaugliche DROMEs -- im Hangar welche bauen."
		_status.modulate = UiKit.BAD
	_chaos.disabled = not ready
