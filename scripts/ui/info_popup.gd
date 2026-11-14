class_name InfoPopup
extends CanvasLayer

## Das Popup zu einer Kachel (14. Nov. 2026): Titel, Bild, ein paar Zeilen
## und die Handlungen dazu (Kaufen, Verkaufen, Zusammenfuegen ...). Liegt
## ueber allem; Tippen daneben oder auf X schliesst es.
##
##     InfoPopup.open(self, "Schnellfeuer", {
##         "subtitle": "Modul · Angriff", "subtitle_color": Color.RED,
##         "picture": ModuleChip.new(module, 56),
##         "lines": ["+8 % Angriffstempo", ["nur in diesem Einsatz", UiKit.MUTED]],
##         "actions": [{"text": "Verkaufen +2", "call": func(): ...}],
##     })
##
## ``body`` (ein eigenes Control) ersetzt oder ergaenzt die Zeilen -- so baut
## das Rezeptbuch sein Raster hinein. Aktionen schliessen das Popup, ausser
## sie tragen "keep_open": true.

signal closed

const MAX_WIDTH := 420.0

var _panel: PanelContainer
var _content: VBoxContainer


static func open(host: Node, title: String, options: Dictionary = {}) -> InfoPopup:
	close_all(host)
	var popup := InfoPopup.new()
	popup.name = "InfoPopup"
	host.add_child(popup)
	popup._build(title, options)
	return popup


static func close_all(host: Node) -> void:
	if host == null:
		return
	for child in host.get_children():
		if child is InfoPopup:
			child.close()


func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()


func _build(title: String, options: Dictionary) -> void:
	layer = 40
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.0, 0.06, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			close())
	root.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	_panel = PanelContainer.new()
	var style := UiKit.card_style(true)
	style.bg_color = Color(UiKit.CARD, 0.98)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var view := get_viewport().get_visible_rect().size
	var width := minf(MAX_WIDTH, view.x - 28.0)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	outer.custom_minimum_size = Vector2(width - 32.0, 0)
	_panel.add_child(outer)

	# Kopf: Bild, Titel, Untertitel, X
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	outer.add_child(head)
	if options.get("picture") is Control:
		var picture: Control = options["picture"]
		picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(picture)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 2)
	head.add_child(names)
	var heading := UiKit.label(title, 21, Arcade.WHITE)
	heading.add_theme_font_override("font", Arcade.font("bold", 21, 0.04))
	names.add_child(heading)
	if str(options.get("subtitle", "")) != "":
		names.add_child(UiKit.label(str(options["subtitle"]), UiKit.SMALL,
			options.get("subtitle_color", UiKit.MUTED)))
	var x := Button.new()
	x.text = "✕"
	x.flat = true
	x.custom_minimum_size = Vector2(44, 44)
	x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	x.add_theme_color_override("font_color", Arcade.YELLOW)
	x.add_theme_font_size_override("font_size", 22)
	x.pressed.connect(close)
	head.add_child(x)

	# Inhalt: rollt, wenn er hoeher wird als der Bildschirm.
	var scroller := ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroller)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	scroller.add_child(_content)
	for line in options.get("lines", []):
		if line is Array:
			_content.add_child(UiKit.label(str(line[0]), int(line[2]) if line.size() > 2 else UiKit.BODY - 1,
				line[1]))
		elif line is Control:
			_content.add_child(line)
		else:
			_content.add_child(UiKit.label(str(line), UiKit.BODY - 1))
	if options.get("body") is Control:
		_content.add_child(options["body"])
	var limit := view.y * 0.62
	var fit := func():
		scroller.custom_minimum_size = Vector2(0, minf(_content.get_combined_minimum_size().y, limit))
	_content.minimum_size_changed.connect(fit)
	fit.call_deferred()

	# Handlungen
	var actions: Array = options.get("actions", [])
	if not actions.is_empty():
		var row: BoxContainer = HBoxContainer.new() if actions.size() <= 2 else VBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		outer.add_child(row)
		for action in actions:
			var button := UiKit.button(str(action.get("text", "")), bool(action.get("primary", false)))
			button.disabled = bool(action.get("disabled", false))
			if str(action.get("why", "")) != "" and button.disabled:
				button.text += "\n" + str(action["why"])
			var call: Callable = action.get("call", Callable())
			var keep := bool(action.get("keep_open", false))
			button.pressed.connect(func():
				if not keep:
					close()
				if call.is_valid():
					call.call())
			row.add_child(button)

	# Kurzes Aufploppen (ausser bei "Bewegung reduzieren").
	if Accessibility.motion() > 0.0:
		_panel.modulate = Color(1, 1, 1, 0)
		_panel.scale = Vector2(0.94, 0.94)
		_panel.resized.connect(func(): _panel.pivot_offset = _panel.size * 0.5)
		var tween := create_tween().set_parallel()
		tween.tween_property(_panel, "modulate:a", 1.0, 0.12)
		tween.tween_property(_panel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


## Der Inhaltsbereich -- fuer Popups, die sich selbst neu fuellen.
func content() -> VBoxContainer:
	return _content
