class_name ActionRing
extends PanelContainer

## Der Aktionsring: beim Hovern ueber einen DROME erscheinen UEBER der Einheit
## alle Aktionen, die der AKTIVE DROME auf dieses Ziel anwenden kann.
##
## Nicht bezahlbare oder blockierte Aktionen werden ausgegraut -- mit Grund.
## Ein ausgegrauter Eintrag ohne Begruendung ist im Taktikspiel wertlos: der
## Spieler muss wissen, ob ihm Energie fehlt, das Budget, oder ob ein
## Betonpfeiler dazwischensteht.
##
## Der Ring trifft keine Entscheidung. Was moeglich ist, sagt der
## BattleManager; hier wird es nur angeordnet.

signal action_chosen(action: ActionData, target_tile: Vector2i)

const COLOR_READY := Color(1, 1, 1)
const COLOR_BLOCKED := Color(0.55, 0.55, 0.60)
const OFFSET_ABOVE := Vector2(0, -96)

var _rows: VBoxContainer
var _title: Label
var _target_tile: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	visible = false
	# Der Ring liegt ueber allem, auch ueber Einheiten weiter vorn.
	z_index = 4090
	mouse_filter = Control.MOUSE_FILTER_PASS

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	add_child(_rows)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 11)
	_title.modulate = Color(0.65, 0.82, 0.95)
	_rows.add_child(_title)


## Baut den Ring fuer ein Ziel auf. ``screen_position`` ist die Position der
## Einheit auf dem Bildschirm, nicht im Gitter.
func show_for(battle: BattleManager, target: Unit, screen_position: Vector2) -> void:
	var actor := battle.active_unit
	var state := battle.turn_state
	if actor == null or state == null or target == null or not actor.is_player:
		hide_ring()
		return

	for child in _rows.get_children():
		if child != _title:
			child.queue_free()

	_target_tile = target.tile
	_title.text = "%s  %d/%d" % [target.display_name, target.hp,
		target.stat("hp_max")]

	var any := false
	for action in actor.actions():
		# Heilung auf Gegner und Angriff auf eigene DROMEs gehoeren nicht in
		# den Ring -- sie waeren nie das, was der Spieler meint.
		var friendly := target.is_player == actor.is_player
		if action.is_heal() != friendly and target != actor:
			continue

		var reason := state.blocker_for(action)
		if reason == "":
			reason = battle.resolver.target_blocker(actor, target.tile, action)

		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 11)
		button.modulate = COLOR_BLOCKED if reason != "" else COLOR_READY
		button.disabled = reason != ""

		if reason != "":
			button.text = "%s — %s" % [action.display_name, reason]
			button.tooltip_text = reason
		else:
			var amount := battle.resolver.preview_damage(actor, target, action)
			button.text = "%s  %d %s" % [action.display_name, absi(amount),
				"Heilung" if amount < 0 else "Schaden"]
			button.tooltip_text = "Reichweite %d%s\nEnergie %d" % [
				action.range_tiles,
				", Sichtlinie noetig" if action.requires_line_of_sight else "",
				action.en_cost]
			var chosen: ActionData = action
			button.pressed.connect(func():
				action_chosen.emit(chosen, _target_tile)
				hide_ring())
		_rows.add_child(button)
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


func hide_ring() -> void:
	visible = false
	_target_tile = Vector2i(-1, -1)


func is_showing_for(tile: Vector2i) -> bool:
	return visible and _target_tile == tile
