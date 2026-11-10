extends Control

## Die Startseite -- mobile first, Hochformat (neu 9. Nov. 2026).
##
##   oben     der Name des Spiels als Neonschrift, darunter der Ort
##   Mitte    die Buehne (HomeStage): das Tor der Arena von Neon City bei
##            Nacht, davor DEIN Squad auf dem Podest
##   darunter eine Karte: naechstes Gebiet und dein Squad in einer Zeile
##   unten    die Hauptaktion "Neon City" (der Lauf), darunter der
##            Endlos-Modus (frei nach dem ersten Sieg in Neon City)
##   Leiste   Spielen · Hangar · Optionen (UiKit.tab_bar)
##
## Der Daumen erreicht unten alles, was man hier tut; oben steht nur, was man
## ansieht.

var _status: Label
var _endless: Button
var _stage: HomeStage


func _ready() -> void:
	var content := UiKit.page(self, "", "", 0, false, Ambience.Kind.MENU)

	var title := UiKit.label("CYBERDROME", 40, Color(1.0, 0.8, 0.96))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(1.0, 0.17, 0.84, 0.55))
	title.add_theme_constant_override("outline_size", 10)
	content.add_child(title)
	var subtitle := UiKit.label("Die Arena von Neon City", UiKit.SMALL, Color(0.18, 0.89, 0.92))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)

	_stage = HomeStage.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.custom_minimum_size = Vector2(0, 260)
	content.add_child(_stage)
	_stage.show_squad(GameState.battle_ready_builds())

	content.add_child(_info_card())

	_status = UiKit.label("", UiKit.SMALL)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_status)

	# Ein laufender Lauf geht vor: er wird fortgesetzt, ein zweiter beginnt
	# erst, wenn er zu Ende ist.
	var running: bool = GameState.run != null and not GameState.run.is_over()
	var endless_running: bool = running and GameState.run.is_endless()
	var story := UiKit.button("Neon City fortsetzen" if running and not endless_running
		else "Neon City", not endless_running)
	story.disabled = endless_running
	story.pressed.connect(func(): _open_run("story"))
	content.add_child(story)

	# Endlos-Modus: frei nach dem ersten Sieg in Neon City (NEUANFANG 6h).
	var unlocked := GameState.endless_unlocked()
	_endless = UiKit.button("Endlos-Modus fortsetzen" if endless_running else
		("Endlos-Modus" if unlocked else "Endlos-Modus  ·  nach Neon City"), endless_running)
	_endless.disabled = not unlocked or (running and not endless_running)
	_endless.pressed.connect(func(): _open_run("endless"))
	content.add_child(_endless)

	_refresh_status()
	story.grab_focus.call_deferred()


func _open_run(mode: String) -> void:
	GameState.next_run_mode = mode
	get_tree().change_scene_to_file("res://scenes/run.tscn")


## Eine schmale Karte: wohin der naechste Lauf geht und wer mitkommt.
func _info_card() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.card_style(false))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	box.add_child(UiKit.label("Neon City  ·  Revier der Neon Ninja's", UiKit.BODY, UiKit.HEADING))
	var squad: Array = GameState.battle_ready_builds()
	if squad.is_empty():
		box.add_child(UiKit.label("Noch kein kampfbereiter Squad -- ab in den Hangar.",
			UiKit.SMALL, UiKit.MUTED))
	else:
		var levels := 0
		for build in squad:
			levels += build.drome_level
		box.add_child(UiKit.label("Dein Squad: %d DROMEs  ·  Level im Schnitt %.1f  ·  Kampfwert %d"
			% [squad.size(), float(levels) / squad.size(), int(DromeBuild.squad_power(squad))],
			UiKit.SMALL, UiKit.MUTED))
	return panel


func _refresh_status() -> void:
	# Ein Lauf braucht kampftaugliche eigene DROMEs; die Aufstellung im Lauf
	# sagt es selbst, hier steht es vorab.
	var ready := not GameState.battle_ready_builds().is_empty()
	_status.visible = not ready
	if not ready:
		_status.text = "Noch kein kampftauglicher DROME -- im Hangar einen bauen."
		_status.modulate = UiKit.BAD
