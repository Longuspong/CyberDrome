class_name Ambience
extends Control

## Die Kulisse hinter den Bildschirmen: Neon-Grossstadt, Sci-Fi-Hangar,
## Gruenzone, Industrieanlage.
##
## Gezeichnet statt als Bild geladen. Ein Hochformat-Hintergrund als Grafik
## muesste fuer jedes Seitenverhaeltnis passen und kostet im Web-Export
## Megabytes; ein paar hundert Rechtecke kosten nichts und passen sich jeder
## Groesse an. Der Zufall haengt an einem festen Seed -- dieselbe Skyline bei
## jedem Aufbau, sonst springt die Stadt beim Seitenwechsel.
##
## Bewegt wird wenig und langsam (Fenster flackern, Leuchtreklame, Gleiter am
## Himmel, Scheinwerfer im Hangar), neu gezeichnet nur ein paar Mal pro
## Sekunde. Mit "Bewegung reduzieren" steht das Bild still.
##
## Die Kulisse ist bewusst dunkel und entsaettigt gegenueber dem, was davor
## steht: sie ist Stimmung, keine Information. Karten und Texte muessen
## darueber lesbar bleiben.

enum Kind { CITY, HANGAR, GREEN, PLANT, MENU, PLAIN }

const FRAME_TIME := 0.12

## Leuchtreklame-Farben der Stadt -- schrill, aber nur als kleine Flaechen.
const NEON := [Color(1.0, 0.18, 0.62), Color(0.18, 0.95, 1.0), Color(1.0, 0.86, 0.2),
	Color(0.62, 0.3, 1.0), Color(0.3, 1.0, 0.55), Color(1.0, 0.42, 0.18)]

var kind: Kind = Kind.CITY
## Abdunkeln ueber allem (0 = keine). Seiten mit viel Text brauchen mehr.
var dim: float = 0.0
## Parallaxe: der Kampf verschiebt die Kulisse ein wenig mit der Kamera.
var drift: Vector2 = Vector2.ZERO
## Im Kampf: die Kamera, an der die Parallaxe haengt. Sonst null.
var camera: Camera2D
var camera_home: Vector2 = Vector2.ZERO

var _time := 0.0
var _since_draw := 0.0
var _layout: Dictionary = {}
var _layout_size := Vector2.ZERO


static func create(which: Kind, darken: float = 0.0) -> Ambience:
	var node := Ambience.new()
	node.kind = which
	node.dim = darken
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Die passende Kulisse zu einer Kampfregion (data/regions.json).
static func kind_for_region(region_id: String) -> Kind:
	match region_id:
		"green": return Kind.GREEN
		"plant7": return Kind.PLANT
	return Kind.CITY


func _ready() -> void:
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	if camera != null and is_instance_valid(camera):
		set_drift(-(camera.position - camera_home) * 0.6)
	if Accessibility.reduce_motion or kind == Kind.PLAIN:
		return
	_time += delta
	_since_draw += delta
	if _since_draw >= FRAME_TIME:
		_since_draw = 0.0
		queue_redraw()


func set_drift(value: Vector2) -> void:
	if value.distance_to(drift) > 0.5:
		drift = value
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if _layout_size != size:
		_layout_size = size
		_layout = _build_layout()
	match kind:
		Kind.CITY: _draw_city(1.0, 0.56)
		Kind.MENU: _draw_city(0.8, 0.62)
		Kind.HANGAR: _draw_hangar()
		Kind.GREEN: _draw_green()
		Kind.PLANT: _draw_plant()
		_: _draw_plain()
	if dim > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.04, dim))


# ---------------------------------------------------------------------------
# Hilfen
# ---------------------------------------------------------------------------

func _gradient(top: Color, bottom: Color, from_y: float, to_y: float, steps: int = 24) -> void:
	var h := (to_y - from_y) / float(steps)
	for i in steps:
		var t := float(i) / float(steps - 1)
		draw_rect(Rect2(0.0, from_y + h * i, size.x, h + 1.0), top.lerp(bottom, t))


## Weiches Leuchten: ein paar uebereinander gelegte, transparente Kreise.
func _glow(at: Vector2, radius: float, color: Color, strength: float = 0.18) -> void:
	for i in 5:
		var r := radius * (1.0 - float(i) * 0.18)
		draw_circle(at, r, Color(color, strength * (0.35 + float(i) * 0.18)))


## Ein Flackern zwischen 0 und 1, je Lichtquelle eigener Takt.
func _flicker(seed_value: int, rate: float = 1.0) -> float:
	if Accessibility.reduce_motion:
		return 1.0
	var phase := float(seed_value % 97) * 0.37
	var v := sin(_time * rate * (1.3 + float(seed_value % 7) * 0.21) + phase)
	# Gelegentlicher Aussetzer, wie eine kaputte Roehre.
	if seed_value % 11 == 0 and fmod(_time * 0.9 + phase, 5.0) < 0.18:
		return 0.15
	return 0.75 + 0.25 * v


func _build_layout() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741 + int(kind) * 131
	var layers: Array = []
	# Drei Hochhausreihen: hinten blass, vorn dunkel und mit Licht.
	for layer in 3:
		var buildings: Array = []
		var x := -20.0
		while x < size.x + 40.0:
			var w := rng.randf_range(26.0, 62.0) * (1.0 + layer * 0.25)
			var h := rng.randf_range(0.18, 0.46) * size.y * (1.25 - layer * 0.22)
			var windows: Array = []
			var cols := int(w / 9.0)
			var rows := int(h / 11.0)
			for cx in cols:
				for ry in rows:
					if rng.randf() < 0.32:
						windows.append({"x": 4.0 + cx * 9.0, "y": 6.0 + ry * 11.0,
							"c": rng.randi_range(0, 3), "s": rng.randi()})
			var sign := {}
			if layer >= 1 and rng.randf() < 0.45:
				sign = {"color": rng.randi_range(0, NEON.size() - 1),
					"vertical": rng.randf() < 0.6, "y": rng.randf_range(0.1, 0.5),
					"s": rng.randi()}
			buildings.append({"x": x, "w": w, "h": h, "windows": windows,
				"antenna": rng.randf() < 0.3, "sign": sign, "s": rng.randi(),
				"roof": rng.randi_range(0, 2)})
			x += w + rng.randf_range(-6.0, 10.0)
		layers.append(buildings)
	var cars: Array = []
	for i in 9:
		cars.append({"y": rng.randf_range(0.08, 0.5), "speed": rng.randf_range(18.0, 60.0)
			* (1.0 if rng.randf() < 0.5 else -1.0), "off": rng.randf() * 1000.0,
			"c": rng.randi_range(0, NEON.size() - 1)})
	var stars: Array = []
	for i in 60:
		stars.append(Vector2(rng.randf() * size.x, rng.randf() * size.y * 0.5))
	var flies: Array = []
	for i in 26:
		flies.append({"p": Vector2(rng.randf() * size.x, rng.randf_range(0.3, 1.0) * size.y),
			"s": rng.randi()})
	var trees: Array = []
	var tx := -30.0
	while tx < size.x + 30.0:
		trees.append({"x": tx, "h": rng.randf_range(0.35, 0.8) * size.y,
			"w": rng.randf_range(40.0, 90.0), "s": rng.randi()})
		tx += rng.randf_range(35.0, 70.0)
	var stacks: Array = []
	var sx := -10.0
	while sx < size.x + 20.0:
		stacks.append({"x": sx, "w": rng.randf_range(18.0, 46.0),
			"h": rng.randf_range(0.25, 0.6) * size.y, "chimney": rng.randf() < 0.45,
			"s": rng.randi()})
		sx += rng.randf_range(30.0, 70.0)
	return {"layers": layers, "cars": cars, "stars": stars, "flies": flies,
		"trees": trees, "stacks": stacks}


# ---------------------------------------------------------------------------
# Neon-Grossstadt
# ---------------------------------------------------------------------------

func _draw_city(brightness: float, horizon: float) -> void:
	var hy := size.y * horizon
	_gradient(Color(0.03, 0.01, 0.08), Color(0.24, 0.05, 0.26), 0.0, hy)
	_gradient(Color(0.24, 0.05, 0.26), Color(0.04, 0.02, 0.07), hy, size.y)
	for star in _layout["stars"]:
		draw_rect(Rect2(star + drift * 0.02, Vector2(1.5, 1.5)), Color(0.8, 0.7, 1.0, 0.35))

	# Die grosse Holo-Sonne hinter der Stadt, in Streifen geschnitten.
	var sun := Vector2(size.x * 0.62, hy - size.y * 0.06) + drift * 0.03
	var radius := size.x * 0.32
	_glow(sun, radius * 1.6, Color(1.0, 0.2, 0.6), 0.10 * brightness)
	draw_circle(sun, radius, Color(1.0, 0.32, 0.55, 0.55 * brightness))
	draw_circle(sun, radius * 0.82, Color(1.0, 0.55, 0.35, 0.45 * brightness))
	var stripe := 0
	var sy := sun.y
	while sy < sun.y + radius:
		var gap := 2.0 + stripe * 1.4
		draw_rect(Rect2(sun.x - radius, sy, radius * 2.0, gap), Color(0.12, 0.03, 0.16, 0.9))
		sy += 9.0 - minf(stripe, 5.0) * 0.6
		stripe += 1

	# Gleiter: Lichtstriche, die am Himmel durchziehen.
	if not Accessibility.reduce_motion:
		for car in _layout["cars"]:
			var span := size.x + 120.0
			var x: float = fposmod(float(car["off"]) + _time * float(car["speed"]), span) - 60.0
			var y: float = float(car["y"]) * size.y + drift.y * 0.04
			var c: Color = NEON[int(car["c"])]
			var tail := -14.0 if float(car["speed"]) > 0.0 else 14.0
			draw_line(Vector2(x + tail, y), Vector2(x, y), Color(c, 0.35 * brightness), 2.0)
			draw_circle(Vector2(x, y), 1.8, Color(c, 0.9 * brightness))

	var layers: Array = _layout["layers"]
	var tones := [Color(0.13, 0.06, 0.22), Color(0.07, 0.04, 0.13), Color(0.025, 0.02, 0.05)]
	var window_colors := [Color(1.0, 0.85, 0.45), Color(0.4, 0.95, 1.0),
		Color(1.0, 0.4, 0.75), Color(0.7, 0.6, 1.0)]
	for li in layers.size():
		var parallax := drift * (0.04 + li * 0.05)
		var base_y := size.y + 4.0 - li * size.y * 0.06
		for b in layers[li]:
			var w: float = b["w"]
			var h: float = b["h"]
			var top_left := Vector2(float(b["x"]), base_y - h) + parallax
			var tone: Color = tones[li]
			draw_rect(Rect2(top_left, Vector2(w, h + 40.0)), tone)
			# Dachkanten: Stufe oder Spitze, damit die Skyline nicht wie ein
			# Balkendiagramm aussieht.
			match int(b["roof"]):
				1:
					draw_rect(Rect2(top_left + Vector2(w * 0.2, -h * 0.06),
						Vector2(w * 0.6, h * 0.06 + 1.0)), tone)
				2:
					draw_colored_polygon(PackedVector2Array([top_left,
						top_left + Vector2(w * 0.5, -h * 0.1), top_left + Vector2(w, 0.0)]), tone)
			# Kante gegen den Himmel, ganz schwach in Magenta.
			draw_line(top_left, top_left + Vector2(w, 0.0),
				Color(1.0, 0.3, 0.7, 0.12 + li * 0.05), 1.0)
			var light := (0.18 + li * 0.25) * brightness
			for win in b["windows"]:
				var wc: Color = window_colors[int(win["c"])]
				var f := _flicker(int(win["s"]), 0.4)
				draw_rect(Rect2(top_left + Vector2(float(win["x"]), float(win["y"])),
					Vector2(4.0, 5.0)), Color(wc, light * f))
			if b["antenna"]:
				var tip := top_left + Vector2(w * 0.5, -h * 0.12 - 18.0)
				draw_line(tip, tip + Vector2(0.0, 18.0), tone.lightened(0.15), 1.5)
				if _flicker(int(b["s"]), 2.0) > 0.8:
					draw_circle(tip, 2.2, Color(1.0, 0.2, 0.2, 0.9 * brightness))
			var sign: Dictionary = b["sign"]
			if not sign.is_empty():
				var c: Color = NEON[int(sign["color"])]
				var f2 := _flicker(int(sign["s"]), 1.6)
				var rect: Rect2
				if sign["vertical"]:
					rect = Rect2(top_left + Vector2(w - 8.0, h * float(sign["y"])),
						Vector2(6.0, minf(60.0, h * 0.4)))
				else:
					rect = Rect2(top_left + Vector2(4.0, h * float(sign["y"])),
						Vector2(w - 8.0, 7.0))
				_glow(rect.get_center(), maxf(rect.size.x, rect.size.y) * 0.9, c,
					0.07 * f2 * brightness)
				draw_rect(rect, Color(c, 0.85 * f2 * brightness))
				draw_rect(rect.grow(-1.5), Color(c.lightened(0.5), 0.6 * f2 * brightness))

	# Dunst ueber den Strassen -- die Stadt verschwimmt nach unten.
	_gradient(Color(0.5, 0.1, 0.45, 0.0), Color(0.35, 0.05, 0.35, 0.22 * brightness),
		size.y * 0.7, size.y, 10)


# ---------------------------------------------------------------------------
# Sci-Fi-Hangar
# ---------------------------------------------------------------------------

func _draw_hangar() -> void:
	var w := size.x
	var h := size.y
	_gradient(Color(0.04, 0.05, 0.08), Color(0.07, 0.09, 0.13), 0.0, h * 0.62)
	var floor_y := h * 0.62
	_gradient(Color(0.08, 0.1, 0.14), Color(0.02, 0.025, 0.04), floor_y, h)

	# Rueckwand: das grosse Tor in Lamellen, halb offen -- dahinter Nacht.
	var door := Rect2(w * 0.14, h * 0.16, w * 0.72, floor_y - h * 0.16)
	draw_rect(door, Color(0.03, 0.03, 0.06))
	var open_h := door.size.y * 0.32
	var city := Rect2(door.position + Vector2(0, door.size.y - open_h), Vector2(door.size.x, open_h))
	_gradient_rect(city, Color(0.2, 0.05, 0.25), Color(0.05, 0.02, 0.08))
	for i in 12:
		var bx := city.position.x + i * city.size.x / 12.0
		var bh := city.size.y * (0.3 + 0.6 * fposmod(sin(i * 12.9) * 43758.5, 1.0))
		draw_rect(Rect2(bx, city.end.y - bh, city.size.x / 12.0 - 2.0, bh), Color(0.02, 0.02, 0.05))
		if i % 3 == 0:
			draw_rect(Rect2(bx + 3.0, city.end.y - bh + 4.0, 3.0, 10.0),
				Color(NEON[i % NEON.size()], 0.6 * _flicker(i * 13, 1.2)))
	var slats := int((door.size.y - open_h) / 14.0)
	for i in slats:
		var y := door.position.y + i * 14.0
		draw_rect(Rect2(door.position.x, y, door.size.x, 12.0), Color(0.13, 0.15, 0.2))
		draw_line(Vector2(door.position.x, y + 12.0), Vector2(door.end.x, y + 12.0),
			Color(0.02, 0.02, 0.03), 2.0)
	# Warnstreifen an der Torkante.
	var edge_y := door.position.y + door.size.y - open_h - 6.0
	var stripe_x := door.position.x
	var k := 0
	while stripe_x < door.end.x:
		draw_colored_polygon(PackedVector2Array([Vector2(stripe_x, edge_y),
			Vector2(stripe_x + 8.0, edge_y), Vector2(stripe_x + 14.0, edge_y + 6.0),
			Vector2(stripe_x + 6.0, edge_y + 6.0)]),
			Color(0.95, 0.75, 0.15, 0.8) if k % 2 == 0 else Color(0.05, 0.05, 0.06))
		stripe_x += 8.0
		k += 1

	# Seitenwaende in Fluchtperspektive.
	var vp := Vector2(w * 0.5, h * 0.42)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), door.position,
		Vector2(door.position.x, floor_y), Vector2(0, h)]), Color(0.06, 0.07, 0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(w, 0), Vector2(door.end.x, door.position.y),
		Vector2(door.end.x, floor_y), Vector2(w, h)]), Color(0.06, 0.07, 0.1))
	# Wandrippen.
	for i in 5:
		var t := float(i + 1) / 6.0
		var lx := lerpf(0.0, door.position.x, t)
		var rx := lerpf(w, door.end.x, t)
		draw_line(Vector2(lx, lerpf(0.0, door.position.y, t)), Vector2(lx, lerpf(h, floor_y, t)),
			Color(0.12, 0.14, 0.19), 3.0 - t * 2.0)
		draw_line(Vector2(rx, lerpf(0.0, door.position.y, t)), Vector2(rx, lerpf(h, floor_y, t)),
			Color(0.12, 0.14, 0.19), 3.0 - t * 2.0)
	# Leuchtband an den Waenden, cyan.
	var band := Color(0.2, 0.85, 1.0, 0.55)
	draw_line(Vector2(0, h * 0.5), Vector2(door.position.x, floor_y - 8.0), band, 2.0)
	draw_line(Vector2(w, h * 0.5), Vector2(door.end.x, floor_y - 8.0), band, 2.0)

	# Deckentraeger, die zum Fluchtpunkt laufen.
	for i in 7:
		var x := lerpf(-w * 0.2, w * 1.2, float(i) / 6.0)
		draw_line(Vector2(x, 0), vp.lerp(Vector2(x, 0), 0.72), Color(0.1, 0.12, 0.16), 4.0)
	for i in 4:
		var y := h * (0.03 + i * 0.035)
		draw_line(Vector2(0, y), Vector2(w, y), Color(0.09, 0.1, 0.14), 3.0)

	# Boden: Raster in Perspektive und eine leuchtende Landeplattform.
	for i in 13:
		var x := lerpf(-w * 0.6, w * 1.6, float(i) / 12.0)
		draw_line(Vector2(lerpf(x, vp.x, 0.62), floor_y), Vector2(x, h),
			Color(0.2, 0.6, 0.8, 0.12), 1.0)
	var row := 0
	var y2 := floor_y
	while y2 < h:
		draw_line(Vector2(0, y2), Vector2(w, y2), Color(0.2, 0.6, 0.8, 0.10), 1.0)
		row += 1
		y2 += 6.0 + row * row * 1.6
	var pad_c := Vector2(w * 0.5, h * 0.8)
	var pulse := 0.6 + 0.4 * sin(_time * 1.4) if not Accessibility.reduce_motion else 1.0
	_ellipse(pad_c, w * 0.36, h * 0.07, Color(0.2, 0.85, 1.0, 0.22 * pulse), 2.0)
	_ellipse(pad_c, w * 0.28, h * 0.054, Color(0.2, 0.85, 1.0, 0.14 * pulse), 1.5)

	# Scheinwerfer von der Decke, die langsam schwenken.
	for i in 3:
		var origin := Vector2(w * (0.2 + i * 0.3), 0.0)
		var swing := sin(_time * 0.35 + i * 2.1) * w * 0.08 if not Accessibility.reduce_motion else 0.0
		var target := Vector2(origin.x + swing, h * 0.86)
		var spread := w * 0.13
		draw_colored_polygon(PackedVector2Array([origin + Vector2(-6, 0), origin + Vector2(6, 0),
			target + Vector2(spread, 0), target + Vector2(-spread, 0)]),
			Color(0.75, 0.9, 1.0, 0.045))
		_glow(origin + Vector2(0, 6), 14.0, Color(0.8, 0.95, 1.0), 0.25)
	# Statuslampen an den Waenden.
	for i in 4:
		var at := Vector2(w * 0.05 + (i % 2) * w * 0.9, h * (0.3 + int(i / 2) * 0.14))
		var c := Color(1.0, 0.25, 0.2) if i % 2 == 0 else Color(0.3, 1.0, 0.5)
		draw_circle(at, 3.0, Color(c, 0.9 * _flicker(i * 17 + 3, 2.4)))


func _gradient_rect(rect: Rect2, top: Color, bottom: Color, steps: int = 12) -> void:
	var h := rect.size.y / float(steps)
	for i in steps:
		var t := float(i) / float(steps - 1)
		draw_rect(Rect2(rect.position.x, rect.position.y + h * i, rect.size.x, h + 1.0),
			top.lerp(bottom, t))


func _ellipse(center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in 41:
		var a := TAU * float(i) / 40.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(points, color, width, true)


# ---------------------------------------------------------------------------
# Gruenzone: ueberwucherte Ruinen, Biolumineszenz
# ---------------------------------------------------------------------------

func _draw_green() -> void:
	_gradient(Color(0.01, 0.05, 0.06), Color(0.04, 0.16, 0.14), 0.0, size.y * 0.6)
	_gradient(Color(0.04, 0.16, 0.14), Color(0.01, 0.04, 0.03), size.y * 0.6, size.y)
	_glow(Vector2(size.x * 0.3, size.y * 0.18) + drift * 0.03, size.x * 0.25,
		Color(0.6, 1.0, 0.85), 0.07)
	draw_circle(Vector2(size.x * 0.3, size.y * 0.18) + drift * 0.03, size.x * 0.07,
		Color(0.85, 1.0, 0.92, 0.5))
	# Ruinen-Tuerme hinten, zugewachsen.
	for b in _layout["layers"][0]:
		var top := Vector2(float(b["x"]), size.y - float(b["h"]) * 0.9) + drift * 0.05
		draw_rect(Rect2(top, Vector2(float(b["w"]), float(b["h"]) + 40.0)), Color(0.05, 0.12, 0.11))
	for tree in _layout["trees"]:
		var x: float = float(tree["x"]) + drift.x * 0.1
		var th: float = tree["h"]
		var tw: float = tree["w"]
		var base := size.y + 5.0
		draw_rect(Rect2(x - 4.0, base - th, 8.0, th), Color(0.02, 0.06, 0.05))
		for i in 4:
			var cy := base - th + i * th * 0.12
			draw_circle(Vector2(x + sin(i * 1.7) * tw * 0.2, cy), tw * (0.5 - i * 0.07),
				Color(0.02, 0.08 + i * 0.01, 0.06))
		# Leuchtpilze und Ranken.
		var f := _flicker(int(tree["s"]), 0.5)
		draw_circle(Vector2(x + 6.0, base - th * 0.3), 3.0, Color(0.3, 1.0, 0.75, 0.6 * f))
	for fly in _layout["flies"]:
		var p: Vector2 = fly["p"]
		var s := int(fly["s"])
		var wobble := Vector2(sin(_time * 0.7 + s % 13) * 8.0, cos(_time * 0.5 + s % 7) * 6.0) \
			if not Accessibility.reduce_motion else Vector2.ZERO
		var f2 := _flicker(s, 1.1)
		_glow(p + wobble, 5.0, Color(0.7, 1.0, 0.4), 0.12 * f2)
		draw_circle(p + wobble, 1.4, Color(0.85, 1.0, 0.6, 0.9 * f2))
	_gradient(Color(0.1, 0.4, 0.3, 0.0), Color(0.1, 0.35, 0.28, 0.25), size.y * 0.72, size.y, 10)


# ---------------------------------------------------------------------------
# Anlage 7: Industrie, Schlote, Warnlichter, Smog
# ---------------------------------------------------------------------------

func _draw_plant() -> void:
	_gradient(Color(0.06, 0.04, 0.03), Color(0.32, 0.15, 0.06), 0.0, size.y * 0.58)
	_gradient(Color(0.32, 0.15, 0.06), Color(0.04, 0.03, 0.03), size.y * 0.58, size.y)
	for stack in _layout["stacks"]:
		var x: float = float(stack["x"]) + drift.x * 0.08
		var sh: float = stack["h"]
		var sw: float = stack["w"]
		var top := size.y - sh
		var tone := Color(0.07, 0.05, 0.05)
		draw_rect(Rect2(x, top, sw, sh + 10.0), tone)
		# Rohrleitungen quer.
		draw_rect(Rect2(x - 6.0, top + sh * 0.35, sw + 12.0, 4.0), Color(0.12, 0.09, 0.08))
		if stack["chimney"]:
			var cx := x + sw * 0.3
			var ch := sh * 0.45
			draw_rect(Rect2(cx, top - ch, sw * 0.28, ch), tone)
			# Rauch: aufsteigende, verblassende Kreise.
			for i in 5:
				var rise := fposmod(_time * 10.0 + i * 14.0 + float(int(stack["s"]) % 50), 70.0) \
					if not Accessibility.reduce_motion else i * 14.0
				draw_circle(Vector2(cx + sw * 0.14 + rise * 0.3, top - ch - rise),
					6.0 + rise * 0.18, Color(0.45, 0.32, 0.25, 0.16 * (1.0 - rise / 70.0)))
			var warn := _flicker(int(stack["s"]), 2.2)
			draw_circle(Vector2(cx + sw * 0.14, top - ch + 3.0), 2.4,
				Color(1.0, 0.3, 0.1, 0.9 * warn))
		for i in 3:
			draw_rect(Rect2(x + 4.0 + i * 8.0, top + 10.0, 4.0, 4.0),
				Color(1.0, 0.7, 0.3, 0.35 * _flicker(int(stack["s"]) + i, 0.3)))
	_gradient(Color(0.55, 0.3, 0.1, 0.0), Color(0.45, 0.25, 0.1, 0.22), size.y * 0.7, size.y, 10)


func _draw_plain() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiKit.BG)
	var step := 28.0
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.3, 0.6, 0.9, 0.04), 1.0)
		x += step
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.3, 0.6, 0.9, 0.04), 1.0)
		y += step
