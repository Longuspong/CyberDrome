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
##         (Aktionen nehmen optional "icon": Name aus assets/ui_icons)
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


## Blaetterbares Popup (15. Nov. 2026, Wunsch des Spielers): ``pages`` ist
## eine Liste von Callables, die je Seite die Optionen liefern (mit "title");
## ``index`` die erste. Pfeile links und rechts im Kopf und Wischen schalten
## durch -- am Ende geht es vorn weiter.
static func open_pages(host: Node, pages: Array, index: int, animate: bool = true) -> InfoPopup:
	if pages.is_empty():
		return null
	index = posmod(index, pages.size())
	var options: Dictionary = (pages[index] as Callable).call()
	options["pages"] = pages
	options["page"] = index
	options["animate"] = animate
	return open(host, str(options.get("title", "")), options)


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

	# "sheet": Blatt von unten ueber die ganze Breite (Entwurf Waffen-Karte,
	# 15. Nov. 2026), sonst mittig.
	var sheet := bool(options.get("sheet", false))
	var view := get_viewport().get_visible_rect().size
	_panel = PanelContainer.new()
	var style := UiKit.card_style(true)
	style.bg_color = Color(UiKit.CARD, 0.98)
	style.set_content_margin_all(16)
	var width := minf(MAX_WIDTH, view.x - 28.0)
	if sheet:
		style = StyleBoxFlat.new()
		style.bg_color = Color("#160930")
		style.border_color = Arcade.MAGENTA
		style.border_width_top = 3
		style.set_content_margin_all(18)
		style.content_margin_top = 14
		width = minf(UiKit.MAX_COLUMN, view.x)
		var bottom := VBoxContainer.new()
		bottom.set_anchors_preset(Control.PRESET_FULL_RECT)
		bottom.alignment = BoxContainer.ALIGNMENT_END
		bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bottom)
		_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bottom.add_child(_panel)
	else:
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(center)
		center.add_child(_panel)
	_panel.add_theme_stylebox_override("panel", style)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	outer.custom_minimum_size = Vector2(width - (36.0 if sheet else 32.0), 0)
	_panel.add_child(outer)
	if sheet:
		var handle := ColorRect.new()
		handle.color = UiKit.CARD_LINE
		handle.custom_minimum_size = Vector2(44, 4)
		handle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		outer.add_child(handle)

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
	if str(options.get("kicker", "")) != "":
		var kicker := Arcade.tilt(Arcade.tag(str(options["kicker"]).to_upper(), 12, 0.0), -3.0)
		kicker.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		names.add_child(kicker)
	if title != "":
		# Titel in Bungee wie die Kopfzeilen (Entwurf 15. Nov. 2026).
		var heading := UiKit.label(title.to_upper(), 22, Arcade.WHITE)
		heading.add_theme_font_override("font", Arcade.font("display"))
		names.add_child(heading)
	if str(options.get("subtitle", "")) != "":
		names.add_child(UiKit.label(str(options["subtitle"]), UiKit.SMALL,
			options.get("subtitle_color", UiKit.MUTED)))
	var pages: Array = options.get("pages", [])
	var page := int(options.get("page", 0))
	if pages.size() > 1:
		var nav := HBoxContainer.new()
		nav.add_theme_constant_override("separation", 6)
		outer.add_child(nav)
		outer.move_child(nav, 0)
		nav.add_child(_arrow("play_left", func(): _turn(pages, page - 1)))
		var count := UiKit.label("%d / %d" % [page + 1, pages.size()], UiKit.SMALL, UiKit.MUTED)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nav.add_child(count)
		nav.add_child(_arrow("play", func(): _turn(pages, page + 1)))
		# Wischen nach links/rechts blaettert.
		var start := {"at": Vector2.ZERO, "down": false}
		_panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					start["at"] = event.global_position
					start["down"] = true
				elif start["down"]:
					start["down"] = false
					var moved: Vector2 = event.global_position - start["at"]
					if absf(moved.x) > 60.0 and absf(moved.x) > absf(moved.y) * 1.4:
						_turn(pages, page + (1 if moved.x < 0.0 else -1)))
		_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var x := Button.new()
	x.flat = true
	x.tooltip_text = "Schließen"
	x.custom_minimum_size = Vector2(44, 44)
	x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	UiIcon.on_button(x, "close", 20, Arcade.YELLOW, "center")
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
			var primary := bool(action.get("primary", false))
			var button := UiKit.button(str(action.get("text", "")), primary)
			if str(action.get("icon", "")) != "":
				UiIcon.on_button(button, str(action["icon"]), 18,
					UiKit.ON_PRIMARY if primary else UiKit.TEXT)
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

	# Kurzes Aufploppen (ausser bei "Bewegung reduzieren" und beim Blaettern).
	if sheet and Accessibility.motion() > 0.0 and bool(options.get("animate", true)):
		_panel.modulate = Color(1, 1, 1, 0)
		# Nur einblenden: die Lage setzt der Container, ein Schieben wuerde
		# sich mit ihm streiten.
		create_tween().tween_property(_panel, "modulate:a", 1.0, 0.14)
	elif Accessibility.motion() > 0.0 and bool(options.get("animate", true)):
		_panel.modulate = Color(1, 1, 1, 0)
		_panel.scale = Vector2(0.94, 0.94)
		_panel.resized.connect(func(): _panel.pivot_offset = _panel.size * 0.5)
		var tween := create_tween().set_parallel()
		tween.tween_property(_panel, "modulate:a", 1.0, 0.12)
		tween.tween_property(_panel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


func _arrow(icon: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(56, 40)
	UiIcon.on_button(button, icon, 18, Arcade.YELLOW, "center")
	button.pressed.connect(func():
		Accessibility.tap()
		on_press.call())
	return button


func _turn(pages: Array, index: int) -> void:
	var host := get_parent()
	if host == null:
		return
	InfoPopup.open_pages(host, pages, index, false)


## Der Inhaltsbereich -- fuer Popups, die sich selbst neu fuellen.
func content() -> VBoxContainer:
	return _content
