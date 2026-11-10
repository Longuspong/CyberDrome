class_name MapView
extends Control

## Die Karte des Laufs wie bei FTL (10. Nov. 2026, Wunsch des Spielers):
## oben die Reihe dieser Runde, darunter die naechste als kleine Vorausschau,
## dazwischen die Wege. Erreichbare Knoten sind hell und antippbar, der
## gewaehlte hat einen Ring; die Vorausschau zeigt nur, wohin es von dort geht.
##
## Form UND Farbe je Stufe (lesbar ohne Farbsehen): Leicht Kreis gruen,
## Normal Raute gelb, Elite Stern-Spitze rot, Chaos Fragezeichen violett.

signal picked(index: int)

const COLOR := {0: Color(0.46, 0.86, 0.52), 1: Color(1.0, 0.82, 0.35), 2: Color(1.0, 0.5, 0.46)}
const CHAOS_COLOR := Color(0.78, 0.55, 1.0)
const LETTER := {0: "L", 1: "N", 2: "E"}
const RADIUS := 24.0
const ROW_GAP := 92.0

var run: RunState


func _init(the_run: RunState = null) -> void:
	run = the_run
	custom_minimum_size = Vector2(0, 2.0 * RADIUS + ROW_GAP + 40.0)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Mittelpunkt von Knoten ``i`` in einer Reihe mit ``count`` Knoten.
func _center(i: int, count: int, row: int) -> Vector2:
	var step := size.x / float(count + 1)
	return Vector2(step * float(i + 1), RADIUS + 6.0 + float(row) * ROW_GAP)


func _draw() -> void:
	if run == null:
		return
	var layers := run.map_layers()
	if run.round < 1 or run.round > layers.size():
		return
	var here: Array = layers[run.round - 1]
	var there: Array = layers[run.round] if run.round < layers.size() else []
	var open := run.available_nodes()
	var font := get_theme_default_font()
	# Wege von den erreichbaren Knoten in die naechste Reihe.
	for i in here.size():
		if i not in open:
			continue
		var from := _center(i, here.size(), 0)
		for j in here[i]["next"]:
			var to := _center(j, there.size(), 1)
			var strong := i == run.node
			draw_line(from, to, Color(1, 1, 1, 0.55 if strong else 0.18), 3.0 if strong else 2.0, true)
	# Die Vorausschau: gedaempft, nur die von der Wahl erreichbaren deutlicher.
	var ahead: Array = here[run.node]["next"] if run.node >= 0 and run.node < here.size() else []
	for j in there.size():
		_draw_node(_center(j, there.size(), 1), there[j], j in ahead, false, 0.7, font)
	for i in here.size():
		_draw_node(_center(i, here.size(), 0), here[i], i in open, i == run.node, 1.0, font)
	draw_string(font, Vector2(4, RADIUS * 2.0 + ROW_GAP + 30.0), "Runde %d -> %d (Vorausschau)"
		% [run.round, mini(run.round + 1, layers.size())], HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(1, 1, 1, 0.45))


func _draw_node(at: Vector2, data: Dictionary, reachable: bool, chosen: bool,
		scale_by: float, font: Font) -> void:
	var which := int(data["tier"])
	var chaos := bool(data["chaos"])
	var color: Color = CHAOS_COLOR if chaos else COLOR.get(which, Color.WHITE)
	if not reachable:
		color = Color(color, 0.28)
	var r := RADIUS * scale_by
	draw_circle(at, r, Color(0.08, 0.1, 0.14))
	match which:
		0:
			draw_arc(at, r * 0.8, 0.0, TAU, 24, color, 3.0, true)
		1:
			draw_polyline(PackedVector2Array([at + Vector2(0, -r * 0.8), at + Vector2(r * 0.8, 0),
				at + Vector2(0, r * 0.8), at + Vector2(-r * 0.8, 0), at + Vector2(0, -r * 0.8)]),
				color, 3.0, true)
		_:
			var pts := PackedVector2Array()
			for k in 11:
				var a := -PI / 2.0 + TAU * float(k) / 10.0
				var rr := r * (0.85 if k % 2 == 0 else 0.42)
				pts.append(at + Vector2(cos(a), sin(a)) * rr)
			draw_polyline(pts, color, 2.5, true)
	var text: String = "?" if chaos else str(LETTER.get(which, ""))
	var fs := int(16 * scale_by)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, at + Vector2(-w * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		Color(1, 1, 1, 1.0 if reachable else 0.35))
	if chosen:
		draw_arc(at, r + 5.0, 0.0, TAU, 32, Color(0.38, 0.8, 0.98), 3.0, true)


func _gui_input(event: InputEvent) -> void:
	if run == null:
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var layers := run.map_layers()
		if run.round < 1 or run.round > layers.size():
			return
		var here: Array = layers[run.round - 1]
		for i in run.available_nodes():
			if event.position.distance_to(_center(i, here.size(), 0)) <= RADIUS + 10.0:
				picked.emit(i)
				accept_event()
				return
