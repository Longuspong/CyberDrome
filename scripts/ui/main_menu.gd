extends Control

## Die Startseite -- mobile first, Hochformat (neu 9. Nov. 2026).
##
##   oben     der Name des Spiels als Neonschrift, darunter der Ort
##   Mitte    die Buehne (HomeStage): das Tor der Arena von Neon City bei
##            Nacht, davor DEIN Squad auf dem Podest
##   darunter eine Karte: naechstes Gebiet und dein Squad in einer Zeile
##   unten    die Hauptaktion "Lauf starten", darunter der Chaos-Virus
##   Leiste   Spielen · Hangar · Optionen (UiKit.tab_bar)
##
## Der Daumen erreicht unten alles, was man hier tut; oben steht nur, was man
## ansieht.

var _status: Label
var _chaos: Button
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

	var running: bool = GameState.run != null and not GameState.run.is_over()
	var run := UiKit.button("Lauf fortsetzen" if running else "Lauf starten", true)
	run.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/run.tscn"))
	content.add_child(run)

	_chaos = UiKit.button("Chaos-Virus")
	_chaos.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/chaos_select.tscn"))
	content.add_child(_chaos)

	_refresh_status()
	run.grab_focus.call_deferred()


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
		box.add_child(UiKit.label("Dein Squad: %d DROMEs  ·  Level im Schnitt %.1f  ·  Staerke %d"
			% [squad.size(), float(levels) / squad.size(), int(DromeBuild.squad_power(squad))],
			UiKit.SMALL, UiKit.MUTED))
	return panel


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
