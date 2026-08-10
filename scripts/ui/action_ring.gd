class_name ActionRing
extends PanelContainer

## Der Aktionsring: ueber einem DROME stehen alle Aktionen, die der AKTIVE
## DROME auf dieses Ziel anwenden kann -- getrennt nach Angriff und Faehigkeit,
## jede mit ihrer Schadensvorschau.
##
## ### Warum er sich anheften laesst
##
## Zuerst erschien der Ring nur beim Hovern und verschwand, sobald der Zeiger
## das Feld verliess. Damit war er unbedienbar: zwischen dem DROME und den
## Knoepfen ueber ihm liegt leere Flaeche, und wer den Zeiger dorthin bewegte,
## verlor den Ring, bevor er ihn erreichte. Ein Klick auf die Einheit heftet
## ihn deshalb fest -- Hovern zeigt nur noch die Vorschau. Angeheftet bleibt er
## bis zum Rechtsklick, ESC, einem Klick auf eine andere Einheit oder dem
## Zugende.
##
## Nicht bezahlbare oder blockierte Aktionen werden ausgegraut -- mit Grund.
## Ein ausgegrauter Eintrag ohne Begruendung ist im Taktikspiel wertlos: der
## Spieler muss wissen, ob ihm Energie fehlt, das Budget, oder ob ein
## Betonpfeiler dazwischensteht.
##
## Der Ring trifft keine Entscheidung. Was moeglich ist, sagt der
## BattleManager; hier wird es nur angeordnet.

signal action_chosen(action: ActionData, target_tile: Vector2i)

## Der Zeiger steht auf einer Aktion. Der Kampfbildschirm faerbt daraufhin
## ihre Reichweite auf der Karte ein -- ohne dass die Aktion gewaehlt sein
## muss. ``null`` heisst: keine mehr.
signal action_hovered(action)

const COLOR_READY := Color(1, 1, 1)
const COLOR_BLOCKED := Color(0.55, 0.55, 0.60)
const COLOR_HEADING := Color(0.62, 0.78, 0.92)
const COLOR_PINNED := Color(1.0, 0.85, 0.3)
const OFFSET_ABOVE := Vector2(0, -28)

var _rows: VBoxContainer
var _title: Label
var _hint: Label
var _target_tile: Vector2i = Vector2i(-1, -1)

## Angeheftet: der Ring bleibt stehen, auch wenn der Zeiger woanders hinfaehrt.
var pinned: bool = false


func _ready() -> void:
	visible = false
	# Der Ring liegt ueber allem, auch ueber Einheiten weiter vorn.
	z_index = 4090
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Eigener Hintergrund: der Ring steht ueber der Karte, und die ist bunt.
	# Mit dem durchscheinenden Standardpanel lagen Schadenszahlen ueber Gras --
	# lesbar nur dort, wo zufaellig etwas Dunkles darunter lag.
	add_theme_stylebox_override("panel", _panel_style())

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	add_child(_rows)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 12)
	_title.modulate = COLOR_HEADING
	_rows.add_child(_title)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 10)
	_hint.modulate = Color(0.6, 0.65, 0.72)
	_rows.add_child(_hint)


## Baut den Ring fuer ein Ziel auf. ``screen_position`` ist die Position der
## Einheit auf dem Bildschirm, nicht im Gitter.
func show_for(battle: BattleManager, target: Unit, screen_position: Vector2,
		pin: bool = false) -> void:
	var actor := battle.active_unit
	var state := battle.turn_state
	if actor == null or state == null or target == null or not actor.is_player:
		hide_ring()
		return

	for child in _rows.get_children():
		if child != _title and child != _hint:
			child.queue_free()

	pinned = pin or pinned
	_target_tile = target.tile
	_title.text = "%s  %d/%d%s" % [target.display_name, target.hp,
		target.stat("hp_max"), "  ANGEHEFTET" if pinned else ""]
	_title.modulate = COLOR_PINNED if pinned else COLOR_HEADING
	_hint.text = "Rechtsklick loest" if pinned else "Klick heftet an"

	# Getrennt nach Budget, denn genau so muss der Spieler planen: ein Angriff
	# und eine Faehigkeit je Zug, nicht zwei beliebige Aktionen.
	var any := false
	for category in [ActionData.Category.ATTACK, ActionData.Category.ABILITY]:
		var rows := _rows_for(battle, actor, target, category)
		if rows.is_empty():
			continue
		_rows.add_child(_heading(ActionData.CATEGORY_LABEL[category]))
		for row in rows:
			_rows.add_child(row)
		any = true

	if not any:
		var none := Label.new()
		none.text = "Keine Aktion moeglich"
		none.add_theme_font_size_override("font_size", 11)
		none.modulate = COLOR_BLOCKED
		_rows.add_child(none)

	visible = true
	# Erst nach dem Layout kennt der Ring seine Groesse -- vorher waere er
	# um seine halbe Breite daneben.
	await get_tree().process_frame
	if visible:
		position = screen_position + OFFSET_ABOVE - Vector2(size.x * 0.5, size.y)


## Ein Knopf je Aktion dieser Kategorie -- oder nichts, wenn keine passt.
func _rows_for(battle: BattleManager, actor: Unit, target: Unit,
		category: ActionData.Category) -> Array[Button]:
	var buttons: Array[Button] = []
	var state := battle.turn_state
	for action in actor.actions_of(category):
		# Heilung auf Gegner und Angriff auf eigene DROMEs gehoeren nicht in
		# den Ring -- sie waeren nie das, was der Spieler meint. Die Regel
		# steht im ActionResolver, weil die Schadensvorschau auf der Karte
		# dieselbe braucht.
		if not battle.resolver.is_meaningful_target(actor, target, action):
			continue

		var reason := state.blocker_for(action)
		if reason == "":
			reason = battle.resolver.target_blocker(actor, target.tile, action)

		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 11)
		button.modulate = COLOR_BLOCKED if reason != "" else COLOR_READY
		button.disabled = reason != ""

		var described: Array[String] = action.description_lines()
		if reason != "":
			button.text = "%s — %s" % [action.display_name, reason]
			described.push_front("Geht nicht: %s" % reason)
		else:
			var amount := battle.resolver.preview_damage(actor, target, action)
			var wirkung: String = action.effect_summary() if amount == 0 \
				else "%d %s" % [absi(amount),
					"Reparatur" if amount < 0 else "Schaden"]
			button.text = "%s   %s   (EN %d)" % [action.display_name, wirkung,
				action.en_cost]
			var chosen: ActionData = action
			button.pressed.connect(func(): action_chosen.emit(chosen, _target_tile))
		button.tooltip_text = "\n".join(described)

		# Auch ein gesperrter Eintrag zeigt seine Reichweite. Wer sehen will,
		# ob er im naechsten Zug herankommt, soll dafuer nicht erst Energie
		# haben muessen.
		var hovered: ActionData = action
		button.mouse_entered.connect(func(): action_hovered.emit(hovered))
		button.mouse_exited.connect(func(): action_hovered.emit(null))
		buttons.append(button)
	return buttons


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.13, 0.96)
	style.border_color = Color(0.35, 0.55, 0.75, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", 10)
	label.modulate = COLOR_HEADING
	return label


func hide_ring() -> void:
	visible = false
	pinned = false
	_target_tile = Vector2i(-1, -1)
	action_hovered.emit(null)


func is_showing_for(tile: Vector2i) -> bool:
	return visible and _target_tile == tile


func pinned_tile() -> Vector2i:
	return _target_tile if pinned and visible else Vector2i(-1, -1)
