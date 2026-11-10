extends Control

## Der erste Bildschirm: Spielstand waehlen (10. Nov. 2026, Wunsch des
## Spielers). Drei Karten -- ein belegter Spielstand zeigt, was drin ist und
## laedt beim Antippen; ein leerer beginnt ein neues Spiel. Loeschen fragt
## nach (zweites Tippen).
##
## Die Regeln stehen in GameState (select_slot, delete_slot, slot_summary).

var _list: VBoxContainer
## Der Spielstand, dessen Loeschen gerade bestaetigt werden muss (0 = keiner).
var _armed: int = 0


func _ready() -> void:
	var content := UiKit.page(self, "", "", -1, true, Ambience.Kind.MENU, 0.25)

	var title := UiKit.label("CYBERDROME", 40, Color(1.0, 0.8, 0.96))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(1.0, 0.17, 0.84, 0.55))
	title.add_theme_constant_override("outline_size", 10)
	content.add_child(title)
	var subtitle := UiKit.label("Spielstand waehlen", UiKit.BODY, Color(0.18, 0.89, 0.92))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	content.add_child(spacer)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", UiKit.GAP)
	content.add_child(_list)
	_refresh()


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	for which in range(1, GameState.SLOT_COUNT + 1):
		_list.add_child(_slot_card(which, GameState.slot_summary(which)))
	_list.add_child(UiKit.label("Jeder Spielstand hat seinen eigenen Hangar, seine Level und "
		+ "seinen laufenden Lauf. Gespeichert wird automatisch.", UiKit.SMALL, UiKit.MUTED))


func _slot_card(which: int, info: Dictionary) -> Control:
	var used: bool = info["exists"]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.card_style(used and which == GameState.slot))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	var name_label := UiKit.label("Spielstand %d" % which, UiKit.H2, UiKit.HEADING if used else UiKit.MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	if used and which == GameState.slot:
		head.add_child(UiKit.label("zuletzt gespielt", UiKit.SMALL, UiKit.GOOD))

	if used:
		box.add_child(UiKit.label("%d DROMEs  ·  %d im Squad  ·  Level im Schnitt %.1f"
			% [info["dromes"], info["squad"], info["level"]], UiKit.SMALL))
		var state := "Laufender Lauf: %s" % info["run"] if str(info["run"]) != "" else "Kein laufender Lauf"
		if bool(info["story_cleared"]):
			state += "  ·  Neon City bezwungen"
		box.add_child(UiKit.label(state, UiKit.SMALL, UiKit.MUTED))
	else:
		box.add_child(UiKit.label("Leer -- beginnt mit den vier Standard-DROMEs.",
			UiKit.SMALL, UiKit.MUTED))

	var play := UiKit.button("Weiterspielen" if used else "Neues Spiel", used or _first_empty() == which)
	play.pressed.connect(func():
		GameState.select_slot(which)
		get_tree().change_scene_to_file("res://scenes/main.tscn"))
	box.add_child(play)

	if used:
		var remove := Button.new()
		remove.flat = true
		remove.custom_minimum_size = Vector2(0, 44)
		remove.add_theme_font_size_override("font_size", UiKit.SMALL)
		remove.add_theme_color_override("font_color", UiKit.BAD)
		remove.text = "Wirklich loeschen? Nochmal tippen" if _armed == which else "Loeschen"
		remove.pressed.connect(func():
			if _armed != which:
				_armed = which
			else:
				_armed = 0
				GameState.delete_slot(which)
			_refresh())
		box.add_child(remove)
	return panel


## Der erste leere Spielstand -- sein Knopf ist hervorgehoben, wenn noch
## keiner belegt ist.
func _first_empty() -> int:
	for which in range(1, GameState.SLOT_COUNT + 1):
		if GameState.slot_exists(which):
			return 0
	return 1
