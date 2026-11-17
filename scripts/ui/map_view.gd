class_name MapView
extends Control

## Die Kampfkarte (14. Nov. 2026, FTL-artig, SPOT-Blatt Fragen 34/43): oben
## die Reihe dieses Kampfs, darunter die naechsten zwei -- verbunden durch
## die festen Wege (RunState.links). Erreichbar sind nur die Knoten, zu denen
## ein Weg vom letzten Kampf fuehrt; sie leuchten, die anderen sind blass.
## Der gewaehlte Knoten hat einen gelben Rahmen, und sein Weg nach unten ist
## hervorgehoben.
##
## Knoten sind breite Kacheln mit Stufen-Zeichen und dem Namen der Formation.
## Form UND Farbe je Stufe (lesbar ohne Farbsehen): Leicht Kreis cyan,
## Normal Raute orange, Elite Stern magenta, Chaos Fragezeichen violett (SVGs
## aus assets/ui_icons). Seit 17. Nov. 2026 die Farben aus dem Entwurf
## (Vorlage 05): kalt -> warm -> heiss, alle aus der Arcade-Palette. Gelb
## bleibt der Auswahl vorbehalten, Gruen/Rot den Bedeutungen gut/schlecht.
## Der gewaehlte Knoten wirft seinen Schatten in der Stufenfarbe.

signal picked(index: int)

const COLOR := {0: Color("#2ee3eb"), 1: Color("#ff6a3d"), 2: Color("#ff2bd6")}
const CHAOS_COLOR := Color("#c58cff")
const ICON := {0: "tier_light", 1: "tier_normal", 2: "tier_elite"}
const NODE_HEIGHT := 54.0
const ROW_GAP := 40.0
const ROWS := 3

var run: RunState


func _init(the_run: RunState = null) -> void:
	run = the_run
	custom_minimum_size = Vector2(0, ROWS * NODE_HEIGHT + (ROWS - 1) * ROW_GAP + 26.0)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Was auf einem Knoten steht: Chaos, sonst der Name der Formation.
static func caption(data: Dictionary) -> String:
	if bool(data.get("chaos", false)):
		return "Chaos"
	return str(Formations.formation(str(data.get("team", ""))).get("name", ""))


func _rect(i: int, count: int, row: int) -> Rect2:
	var gap := 8.0
	var width := (size.x - gap * float(count - 1)) / float(maxi(1, count))
	width = minf(width, 170.0)
	var total := width * count + gap * (count - 1)
	var left := (size.x - total) * 0.5 + float(i) * (width + gap)
	var scale_y := 1.0 if row == 0 else 0.86
	var top := float(row) * (NODE_HEIGHT + ROW_GAP)
	return Rect2(left, top, width, NODE_HEIGHT * scale_y)


func _draw() -> void:
	if run == null:
		return
	var font := Arcade.font("bold")
	var rows: Array = []
	for k in ROWS:
		var r := run.round + k
		if not run.is_endless() and r > RunState.rounds_total():
			break
		rows.append(r)
	var open := run.available_nodes()
	# Wege zuerst, darunter die Knoten.
	for k in rows.size() - 1:
		var here := run.row(rows[k])
		var there := run.row(rows[k + 1])
		var paths := run.links(rows[k])
		for i in paths.size():
			for j in paths[i]:
				var a := _rect(i, here.size(), k)
				var b := _rect(int(j), there.size(), k + 1)
				var hot := k == 0 and i == run.node
				var color := Color(UiKit.PRIMARY, 0.85) if hot else Color(UiKit.ACCENT, 0.22)
				draw_line(Vector2(a.get_center().x, a.end.y), Vector2(b.get_center().x, b.position.y),
					color, 3.0 if hot else 2.0, true)
	for k in rows.size():
		var nodes := run.row(rows[k])
		for i in nodes.size():
			var reachable := k > 0 or open.has(i)
			_draw_node(_rect(i, nodes.size(), k), nodes[i], reachable and k == 0,
				k == 0 and i == run.node, k > 0, font)
	if rows.size() > 1:
		draw_string(font, Vector2(0, size.y - 6.0), "darunter: die Wege danach",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UiKit.MUTED, 0.7))


func _draw_node(box: Rect2, data: Dictionary, reachable: bool, chosen: bool, ahead: bool,
		font: Font) -> void:
	var which := int(data["tier"])
	var chaos := bool(data["chaos"])
	var color: Color = CHAOS_COLOR if chaos else COLOR.get(which, Color.WHITE)
	var alpha := 1.0 if reachable else (0.55 if ahead else 0.28)
	# Kachel mit abgeschraegten Ecken (Arcade).
	var cut := 9.0
	var shape := PackedVector2Array([box.position + Vector2(cut, 0), Vector2(box.end.x, box.position.y),
		box.end - Vector2(0, cut), box.end - Vector2(cut, 0), Vector2(box.position.x, box.end.y),
		box.position + Vector2(0, cut)])
	if chosen:
		var shadow := PackedVector2Array()
		for p in shape:
			shadow.append(p + Vector2(4, 4))
		draw_colored_polygon(shadow, Color(color, 0.8))
	draw_colored_polygon(shape, Color(UiKit.CARD, 0.95 * maxf(alpha, 0.6)))
	var outline := shape.duplicate()
	outline.append(shape[0])
	draw_polyline(outline, Color(UiKit.PRIMARY, 1.0) if chosen else Color(color, alpha),
		3.0 if chosen else 2.0, true)
	# Stufen-Zeichen links (UI-Symbol, seit 15. Nov. 2026 statt Form + Buchstabe)
	var r := minf(box.size.y * 0.32, 15.0)
	var at := Vector2(box.position.x + r + 8.0, box.get_center().y)
	var mark := Color(color, alpha)
	var icon := UiIcon.texture("unknown" if chaos else str(ICON.get(which, "tier_elite")))
	if icon != null:
		draw_texture_rect(icon, Rect2(at - Vector2(r, r) * 1.15, Vector2(r, r) * 2.3), false, mark)
	# Name der Formation, zweizeilig wenn noetig
	var text := caption(data)
	var left := at.x + r + 6.0
	var room := box.end.x - left - 6.0
	var size_px := 13 if not ahead else 11
	var lines := _wrap(text, font, size_px, room)
	var line_h := float(size_px) + 2.0
	var top := box.get_center().y - line_h * float(lines.size()) * 0.5 + float(size_px) * 0.85
	for k in lines.size():
		draw_string(font, Vector2(left, top + line_h * k), lines[k], HORIZONTAL_ALIGNMENT_LEFT,
			room, size_px, Color(UiKit.TEXT, alpha))


static func _wrap(text: String, font: Font, size_px: int, room: float) -> Array:
	var words := text.split(" ")
	var lines: Array = []
	var line := ""
	for word in words:
		var trial := word if line == "" else line + " " + word
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > room and line != "":
			lines.append(line)
			line = word
		else:
			line = trial
	if line != "":
		lines.append(line)
	return lines.slice(0, 2)


func _gui_input(event: InputEvent) -> void:
	if run == null:
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var here := run.row()
		for i in here.size():
			if _rect(i, here.size(), 0).grow(4.0).has_point(event.position):
				if run.available_nodes().has(i):
					picked.emit(i)
				accept_event()
				return
