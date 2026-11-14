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

	# Glitch-Logo wie auf dem Titel (Arcade-Stil, 14. Nov. 2026).
	var logo := Arcade.GlitchLogo.new("CYBERDROME", 38, 4.0, [
		[0.0, Vector2(-2, 0), Vector2(2, 0)],
		[0.91, Vector2(-6, 2), Vector2(6, -2)],
		[0.93, Vector2(4, -1), Vector2(-4, 1)]], 2.0)
	var title := Arcade.tilt(logo, -4.0)
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(title)
	var tag := Arcade.tilt(Arcade.tag("NEON CITY · ARENA", 13, 0.0), 2.0)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(tag)

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
	var story := UiKit.button("Einsatz fortsetzen" if running and not endless_running
		else "Einsatz · Neon City", not endless_running)
	story.disabled = endless_running
	story.pressed.connect(func(): _open_run("story"))
	content.add_child(story)

	# Endlos-Modus: frei nach dem ersten Sieg in Neon City (NEUANFANG 6h).
	var unlocked := GameState.endless_unlocked()
	_endless = UiKit.button("Infinity-Einsatz fortsetzen" if endless_running else
		("Infinity-Einsatz" if unlocked else "Infinity-Einsatz  ·  nach Neon City"), endless_running)
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
		box.add_child(UiKit.label("Noch kein kampfbereiter Squad – ab in den Hangar.",
			UiKit.SMALL, UiKit.MUTED))
	else:
		var levels := 0
		for build in squad:
			levels += build.drome_level
		box.add_child(UiKit.label("Dein Squad: %d DROMEs  ·  Ø Level %.1f  ·  Kampfwert %d"
			% [squad.size(), float(levels) / squad.size(), int(DromeBuild.squad_power(squad))],
			UiKit.SMALL, UiKit.MUTED))
	return panel


func _refresh_status() -> void:
	# Ein Lauf braucht kampftaugliche eigene DROMEs; die Aufstellung im Lauf
	# sagt es selbst, hier steht es vorab.
	var ready := not GameState.battle_ready_builds().is_empty()
	_status.visible = not ready
	if not ready:
		_status.text = "Noch kein kampftauglicher DROME – im Hangar einen bauen."
		_status.modulate = UiKit.BAD
