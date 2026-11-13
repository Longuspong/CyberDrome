extends Control

## Spielstand waehlen (10. Nov. 2026, Wunsch des Spielers), seit 13. Nov. 2026
## im Arcade-Glitch-Stil (Entwurf docs/design/spielstand_arcade). Drei Karten
## -- ein belegter Spielstand zeigt, was drin ist, und laedt; ein leerer
## beginnt ein neues Spiel. Loeschen fragt nach (zweites Tippen). Davor
## kommt der Titelbildschirm (scenes/title.tscn), der Pfeil fuehrt zurueck.
##
## Die Regeln stehen in GameState (select_slot, delete_slot, slot_summary).

const TITLE := "res://scenes/title.tscn"
const COLUMN := 450.0

var _list: VBoxContainer
var _toast: Label
var _cursor: Label
var _margin: MarginContainer
## Der Spielstand, dessen Loeschen gerade bestaetigt werden muss (0 = keiner).
var _armed: int = 0
var _blink := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(Arcade.Backdrop.new(false))

	var scroller := ScrollContainer.new()
	scroller.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroller)
	_margin = MarginContainer.new()
	_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(_margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	_margin.add_child(content)

	# Kopf: zurueck zum Titel, Etikett
	var head := HBoxContainer.new()
	head.custom_minimum_size = Vector2(0, 44)
	content.add_child(head)
	var back := Arcade.BackButton.new()
	back.pressed.connect(func(): get_tree().change_scene_to_file(TITLE))
	head.add_child(back)
	var push := Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(push)
	var tag := Arcade.tilt(Arcade.tag("SAVE SELECT", 13, 0.0), 2.0)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tag)

	# Logo und Ueberschrift
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(top)
	var logo := Arcade.GlitchLogo.new("CYBERDROME", 36, 4.0, [
		[0.0, Vector2(-2, 0), Vector2(2, 0)],
		[0.91, Vector2(-6, 2), Vector2(6, -2)],
		[0.93, Vector2(4, -1), Vector2(-4, 1)]], 2.0)
	var tilted := Arcade.tilt(logo, -4.0)
	tilted.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(tilted)
	var heading := Arcade.label("SPIELSTAND WÄHLEN", 18, Arcade.CYAN, "bold", 0.26)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(heading)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	top.add_child(gap)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 14)
	content.add_child(_list)

	# Meldung mit blinkendem Cursor
	var toast_panel := PanelContainer.new()
	var toast_box := StyleBoxFlat.new()
	toast_box.bg_color = Arcade.NIGHT
	toast_box.border_color = Arcade.CYAN
	toast_box.set_border_width_all(2)
	toast_box.content_margin_left = 14
	toast_box.content_margin_right = 14
	toast_box.content_margin_top = 12
	toast_box.content_margin_bottom = 12
	toast_panel.add_theme_stylebox_override("panel", toast_box)
	var toast_row := HBoxContainer.new()
	toast_row.add_theme_constant_override("separation", 0)
	toast_panel.add_child(toast_row)
	_toast = Arcade.label("", 15, Arcade.CYAN, "bold", 0.14)
	toast_row.add_child(_toast)
	_cursor = Arcade.label("_", 15, Arcade.CYAN, "bold")
	toast_row.add_child(_cursor)
	toast_panel.visible = false
	content.add_child(toast_panel)

	var foot := Arcade.label("Jeder Slot hat seinen eigenen Hangar, seine Level und seinen "
		+ "laufenden Lauf. Gespeichert wird automatisch.", 14, Arcade.MUTED)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(foot)

	add_child(Arcade.Scanlines.new(0.16))
	resized.connect(_layout)
	_layout()
	_refresh(true)
	set_process(Arcade.moving())


func _process(delta: float) -> void:
	_blink = fmod(_blink + delta, 1.0)
	_cursor.modulate.a = 1.0 if _blink < 0.5 else 0.0


## Spalte wie im Entwurf (Rand 20 / 16 / 24), im Querformat mittig.
func _layout() -> void:
	var side := maxf(20.0, (size.x - COLUMN) * 0.5 + 20.0)
	_margin.add_theme_constant_override("margin_left", int(side))
	_margin.add_theme_constant_override("margin_right", int(side))
	_margin.add_theme_constant_override("margin_top", 16)
	_margin.add_theme_constant_override("margin_bottom", 24)


func _refresh(first: bool = false) -> void:
	for child in _list.get_children():
		child.queue_free()
	for which in range(1, GameState.SLOT_COUNT + 1):
		var card := _slot_card(which, GameState.slot_summary(which))
		_list.add_child(card)
		if first and Arcade.moving():
			card.modulate.a = 0.0
			create_tween().tween_property(card, "modulate:a", 1.0, 0.3)


func _show(text: String) -> void:
	_toast.text = text
	_toast.get_parent().get_parent().visible = text != ""


func _slot_card(which: int, info: Dictionary) -> Control:
	var used: bool = info["exists"]
	var hot := used and which == GameState.slot
	var line := (Arcade.CYAN if hot else Arcade.MAGENTA) if used else Arcade.EMPTY_LINE
	var shadow := (Arcade.MAGENTA if hot else Color("#3a1a6e")) if used else Color.TRANSPARENT

	# Der Versatzschatten ragt wie im Entwurf 6 px ueber die Spalte hinaus.
	var card := Arcade.Card.new(line, shadow, not used)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var number := PanelContainer.new()
	number.custom_minimum_size = Vector2(60, 60)
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	number.add_theme_stylebox_override("panel", Arcade.chamfer_box(line if used else Color.TRANSPARENT, 12))
	var code := Arcade.label("%02d" % which, 26, Arcade.NIGHT if used else Arcade.EMPTY_NUM, "display")
	code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.add_child(code)
	row.add_child(number)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	text.add_child(name_row)
	name_row.add_child(Arcade.label("SLOT %d" % which, 19, Arcade.WHITE if used else Arcade.MUTED,
		"bold", 0.08))
	if hot:
		var badge := PanelContainer.new()
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var badge_box := StyleBoxFlat.new()
		badge_box.bg_color = Arcade.CYAN
		badge_box.content_margin_left = 6
		badge_box.content_margin_right = 6
		badge_box.content_margin_top = 2
		badge_box.content_margin_bottom = 2
		badge.add_theme_stylebox_override("panel", badge_box)
		badge.add_child(Arcade.label("ZULETZT", 11, Arcade.NIGHT, "bold", 0.14))
		name_row.add_child(badge)

	if used:
		text.add_child(_wrap(Arcade.label("%d DROMEs · %d im Squad · Ø Level %s" % [info["dromes"],
			info["squad"], ("%.1f" % float(info["level"])).replace(".", ",")], 15, Arcade.TEXT)))
		var state := "Lauf: %s" % info["run"] if str(info["run"]) != "" else "Kein Lauf"
		if bool(info["story_cleared"]):
			state += " · Neon City bezwungen"
		text.add_child(_wrap(Arcade.label(state, 15, Arcade.MUTED)))
	else:
		text.add_child(_wrap(Arcade.label("Leer – startet mit den vier Standard-DROMEs.", 15,
			Arcade.MUTED)))

	var play := Arcade.button("Weiterspielen ▶" if used else "Neues Spiel +", used)
	play.pressed.connect(func():
		_show(("LADE SLOT %02d" if used else "NEUES SPIEL IN SLOT %02d") % which)
		Accessibility.vibrate(20)
		GameState.select_slot(which)
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn"))
	box.add_child(play)

	if used:
		var remove := Arcade.text_button("WIRKLICH LÖSCHEN? NOCHMAL TIPPEN" if _armed == which
			else "LÖSCHEN", Arcade.ROSE)
		remove.pressed.connect(func():
			if _armed != which:
				_armed = which
				_show("")
			else:
				_armed = 0
				GameState.delete_slot(which)
				_show("SLOT %02d GELÖSCHT" % which)
			_refresh())
		box.add_child(remove)
	return card


func _wrap(label: Label) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
