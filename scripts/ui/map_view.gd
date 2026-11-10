class_name MapView
extends Control

## Die Wahl des naechsten Kampfs (10. Nov. 2026, Regel des Spielers): oben
## die Knoten dieser Runde -- alle antippbar --, darunter klein die Reihe,
## die danach kaeme. Unter jedem Knoten steht, was er ist: die Stufe und der
## Gegnertyp des Teams. Der gewaehlte Knoten hat einen Ring.
##
## Die Vorausschau haengt an der Wahl: wer Elite nimmt, sieht darunter die
## Reihe mit der hoeheren Elite-Chance.
##
## Form UND Farbe je Stufe (lesbar ohne Farbsehen): Leicht Kreis gruen,
## Normal Raute gelb, Elite Stern rot, Chaos Fragezeichen violett.

signal picked(index: int)

const COLOR := {0: Color(0.46, 0.86, 0.52), 1: Color(1.0, 0.82, 0.35), 2: Color(1.0, 0.5, 0.46)}
const CHAOS_COLOR := Color(0.78, 0.55, 1.0)
const LETTER := {0: "L", 1: "N", 2: "E"}
const RADIUS := 26.0
const ROW_GAP := 104.0
const CAPTION := 15

var run: RunState


func _init(the_run: RunState = null) -> void:
	run = the_run
	custom_minimum_size = Vector2(0, 2.0 * RADIUS + ROW_GAP + 64.0)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Mittelpunkt von Knoten ``i`` in einer Reihe mit ``count`` Knoten.
func _center(i: int, count: int, row: int) -> Vector2:
	var step := size.x / float(count)
	return Vector2(step * (float(i) + 0.5), RADIUS + 8.0 + float(row) * ROW_GAP)


## Was unter einem Knoten steht: Chaos, sonst das Kurzwort des Teams oder
## sein Gegnertyp.
static func caption(data: Dictionary) -> String:
	if bool(data.get("chaos", false)):
		return "Chaos"
	var entry := Encounters.team(str(data.get("team", "")))
	if entry.is_empty():
		return ""
	if str(entry.get("label", "")) != "":
		return str(entry["label"])
	return str(Encounters.type_info(str(entry.get("type", "")))["name"])


func _draw() -> void:
	if run == null:
		return
	var here := run.row()
	var there := run.next_row()
	var font := get_theme_default_font()
	# Der Weg von der Wahl in die naechste Reihe.
	if run.node >= 0 and run.node < here.size() and not there.is_empty():
		var from := _center(run.node, here.size(), 0) + Vector2(0, RADIUS + 22.0)
		var to := Vector2(size.x * 0.5, RADIUS + 8.0 + ROW_GAP - RADIUS * 0.7 - 6.0)
		draw_line(from, to, Color(1, 1, 1, 0.3), 2.0, true)
	for j in there.size():
		var at := _center(j, there.size(), 1)
		_draw_node(at, there[j], false, false, 0.62, font)
		_caption(font, at + Vector2(0, RADIUS * 0.62 + 16.0), caption(there[j]), 13, Color(1, 1, 1, 0.45))
	for i in here.size():
		var at := _center(i, here.size(), 0)
		var chosen := i == run.node
		_draw_node(at, here[i], true, chosen, 1.0, font)
		var which := int(here[i]["tier"])
		var tint: Color = CHAOS_COLOR if bool(here[i]["chaos"]) else COLOR.get(which, Color.WHITE)
		_caption(font, at + Vector2(0, RADIUS + 20.0), caption(here[i]), CAPTION,
			tint if chosen else Color(1, 1, 1, 0.75))
	if not there.is_empty():
		draw_string(font, Vector2(4, RADIUS * 2.0 + ROW_GAP + 56.0), "unten: was nach dieser Wahl kaeme",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.45))


func _caption(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, at + Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


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
		var here := run.row()
		for i in here.size():
			# Grosszuegig: der Knoten samt Beschriftung darunter.
			var at := _center(i, here.size(), 0)
			if absf(event.position.x - at.x) <= size.x / float(here.size()) * 0.5 \
					and event.position.y <= at.y + RADIUS + 30.0:
				picked.emit(i)
				accept_event()
				return
