class_name TickBarPanel
extends VBoxContainer

## Die Initiativbalken -- ein Balken je lebendem DROME.
##
## ### Warum der Balken luegt, und warum das richtig ist
##
## Mechanisch wird der Ueberschuss uebertragen: wer mit 112 ticks zieht, steht
## danach bei 12. Ein Balken, der nach dem Zug einfach auf 12 Prozent stehen
## bleibt, liest sich aber nicht als "hat gezogen", sondern als "haengt fest".
##
## Deshalb wird der Vorgang inszeniert statt gesprungen: der Balken laeuft
## sichtbar auf 0 leer -- das ist das Signal "dieser DROME hat gezogen" -- und
## fuellt sich danach kurz auf den Uebertrag, abgesetzt in einer eigenen Farbe.
## Der Spieler sieht einen Reset und bekommt den Uebertrag als sichtbaren Bonus
## obendrauf.
##
## Das ist REINE PRAESENTATION. tick_bus.gd weiss von diesen Animationen
## nichts, und massgeblich fuer die Reihenfolge ist ohnehin die TICK-Queue.
## Widersprechen sich Queue und Balken, ist die Queue richtig und der Balken
## hat einen Bug.

const DRAIN_TIME := 0.25
const CARRY_TIME := 0.15

const COLOR_FILL := Color(0.30, 0.72, 0.95)
const COLOR_CARRY := Color(1.0, 0.78, 0.25)
const COLOR_ENEMY := Color(0.95, 0.42, 0.38)
const COLOR_TRACK := Color(0.10, 0.12, 0.17)

var _rows: Dictionary = {}          ## unit_id -> Row


class Row extends HBoxContainer:
	var unit_id
	var bar: TickBarPanel.Meter
	var label: Label


class Meter extends Control:
	## Zwei Segmente: die normale Fuellung und der Uebertrag daneben.
	## Beide getrennt animierbar, damit der Reset und der Bonus als zwei
	## Bewegungen lesbar sind und nicht als ein Sprung.
	var fill: float = 0.0:
		set(value):
			fill = value
			queue_redraw()
	var carry: float = 0.0:
		set(value):
			carry = value
			queue_redraw()
	var tint: Color = TickBarPanel.COLOR_FILL

	func _ready() -> void:
		custom_minimum_size = Vector2(190, 12)

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		draw_rect(box, TickBarPanel.COLOR_TRACK)
		if fill > 0.0:
			draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * clampf(fill, 0.0, 1.0),
				size.y)), tint)
		if carry > 0.0:
			# Der Uebertrag sitzt am Anfang und ueberlagert -- er IST der
			# Vorsprung in den naechsten Zug, kein Anhaengsel am Ende.
			draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * clampf(carry, 0.0, 1.0),
				size.y)), TickBarPanel.COLOR_CARRY)
		draw_rect(box, Color(1, 1, 1, 0.12), false, 1.0)


func rebuild(units: Array, bus: TickBus) -> void:
	for child in get_children():
		child.queue_free()
	_rows.clear()

	for unit in units:
		if not unit.is_alive():
			continue
		var row := Row.new()
		row.unit_id = unit.unit_id
		row.add_theme_constant_override("separation", 8)

		row.label = Label.new()
		row.label.text = unit.display_name
		row.label.custom_minimum_size = Vector2(90, 0)
		row.label.add_theme_font_size_override("font_size", 11)
		row.label.modulate = COLOR_FILL if unit.is_player else COLOR_ENEMY
		row.add_child(row.label)

		row.bar = Meter.new()
		row.bar.tint = COLOR_FILL if unit.is_player else COLOR_ENEMY
		row.add_child(row.bar)

		add_child(row)
		_rows[unit.unit_id] = row

	sync(bus)


## Uebernimmt den echten Zustand ohne Animation.
func sync(bus: TickBus) -> void:
	if bus == null:
		return
	for unit_id in _rows:
		var state := bus.bar_state(unit_id)
		if state.is_empty():
			continue
		var row: Row = _rows[unit_id]
		row.bar.fill = state["fill"]
		row.bar.carry = float(state["carry"]) / float(state["threshold"])
		_update_tooltip(row, state)


## Inszeniert den Zugwechsel: erst leerlaufen, dann der Uebertrag.
## Der Aufrufer wartet darauf -- so bleibt die Reihenfolge lesbar.
func play_turn_end(unit_id, bus: TickBus) -> void:
	var row: Row = _rows.get(unit_id)
	if row == null:
		return
	var state := bus.bar_state(unit_id)
	var carry := 0.0 if state.is_empty() \
		else clampf(float(state["tick"]) / float(state["threshold"]), 0.0, 1.0)

	var tween := create_tween()
	tween.tween_property(row.bar, "fill", 0.0, DRAIN_TIME)
	tween.parallel().tween_property(row.bar, "carry", 0.0, DRAIN_TIME)
	if carry > 0.0:
		tween.tween_property(row.bar, "carry", carry, CARRY_TIME)
	if not state.is_empty():
		tween.tween_callback(func(): _update_tooltip(row, state))


func _update_tooltip(row: Row, state: Dictionary) -> void:
	var carry: int = state.get("carry", 0)
	var tick: int = state.get("tick", 0)
	var text := "TICK %d / %d" % [tick, state.get("threshold", 100)]
	# Der Uebertrag bekommt seinen eigenen Satz -- er ist der Grund, warum
	# SPD sich lohnt, und das soll man ablesen koennen.
	if tick > 0 and carry == 0 and tick < state.get("threshold", 100):
		text += "\nUebertrag: %d" % tick
	elif carry > 0:
		text += "\nUebertrag: %d" % carry
	row.tooltip_text = text
	row.bar.tooltip_text = text
	row.label.tooltip_text = text


func drop_unit(unit_id) -> void:
	var row: Row = _rows.get(unit_id)
	if row == null:
		return
	row.queue_free()
	_rows.erase(unit_id)
