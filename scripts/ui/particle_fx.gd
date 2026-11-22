class_name ParticleFx
extends Node2D

## Einschlaege als 3D-Teilchen (21. Nov. 2026, Kampfbild mehr 3D B7, Paket 2).
##
## Funken springen weg und fallen zu Boden, schwere Treffer qualmen, beim
## Zerfallen fliegen Truemmer, Molok wirbelt beim Auftreten Staub auf, in
## Factory 5 steigt Dampf aus den Rosten (D12).
##
## Gerechnet wird im Raum -- Bodenpunkt (x, y wie die 2D-Welt) plus Hoehe h in
## Bildpunkten, mit Schwerkraft und Abprall am Boden --, gezeichnet flach in
## der Iso-Projektion (Bild = (x, y - h)). Das ist so billig wie die alten
## Striche: keine 3D-Knoten, kein eigener Zeichendurchgang, eine feste
## Obergrenze (motion.particles_max). Die Teilchen liegen ueber den DROMEs und
## unter den Zahlen (z 4012); Schadenszahl und Ring bleiben das Hauptsignal.
##
## Mit "Bewegung reduzieren" entstehen keine Teilchen.

const GRAVITY := 900.0
const SPARK_SPEED := 150.0
const SPARK_LIFE := 0.75
const SMOKE_LIFE := 0.9
const DEBRIS_LIFE := 1.1
const DUST_LIFE := 0.45
const STEAM_LIFE := 1.6
const DEFAULT_MAX := 240

## Teilchen: {"kind", "p": Vector3 (x, y, h), "v": Vector3, "age", "life",
## "color", "size", "spin", "rot", "rest"}.
var _parts: Array = []
var pixel_scale: float = 1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 4012
	z_as_relative = false
	_rng.seed = 7351


static func limit() -> int:
	return int(Config.section("motion").get("particles_max", DEFAULT_MAX))


func count() -> int:
	return _parts.size()


func _add(part: Dictionary) -> void:
	if Accessibility.reduce_motion:
		return
	part["age"] = 0.0
	part["rot"] = float(part.get("rot", 0.0))
	part["spin"] = float(part.get("spin", 0.0))
	part["rest"] = false
	_parts.append(part)
	var cap := limit()
	if _parts.size() > cap:
		_parts = _parts.slice(_parts.size() - cap)


## Richtung auf dem Boden, in der Bildtiefe gestaucht.
func _ground_dir(angle: float) -> Vector2:
	return Vector2(cos(angle), sin(angle) * IsoView.DEPTH_SQUASH)


# ---------------------------------------------------------------------------
# Ausloeser
# ---------------------------------------------------------------------------

## Einschlag am Bodenpunkt ``at`` in Hoehe ``lift`` (Bildpunkte): Funken fuer
## den kinetischen Anteil, beim schweren Treffer zusaetzlich Rauch.
func hit(at: Vector2, lift: float, color: Color, energy: float, heavy: bool) -> void:
	var sparks := int(round((7.0 if heavy else 5.0) * (1.0 - energy * 0.6)))
	var hot := Color(1.0, 0.86, 0.45) if energy < 0.5 else color.lightened(0.45)
	for i in sparks:
		var angle := _rng.randf() * TAU
		var speed := SPARK_SPEED * _rng.randf_range(0.55, 1.15) * (1.25 if heavy else 1.0)
		var flat := _ground_dir(angle) * speed
		_add({"kind": "spark", "p": Vector3(at.x, at.y, lift),
			"v": Vector3(flat.x, flat.y, _rng.randf_range(40.0, 150.0)),
			"life": SPARK_LIFE * _rng.randf_range(0.7, 1.1), "color": hot, "size": 1.0})
	if heavy:
		smoke(at, lift, 3)


## Rauch: ein paar Woelkchen, die aufsteigen und wachsen.
func smoke(at: Vector2, lift: float, amount: int = 3) -> void:
	for i in amount:
		var drift := _ground_dir(_rng.randf() * TAU) * _rng.randf_range(4.0, 14.0)
		_add({"kind": "smoke", "p": Vector3(at.x + drift.x, at.y + drift.y, lift + _rng.randf_range(-4.0, 6.0)),
			"v": Vector3(drift.x, drift.y, _rng.randf_range(22.0, 40.0)),
			"life": SMOKE_LIFE * _rng.randf_range(0.8, 1.2),
			"color": Color(0.42, 0.38, 0.5), "size": _rng.randf_range(5.0, 8.0)})


## Truemmer beim Zerfallen: kleine Platten in den Farben des DROME, die
## aufspringen, einmal abprallen und liegen bleiben, bis sie verblassen.
func debris(at: Vector2, colors: Array, amount: int = 9) -> void:
	for i in amount:
		var angle := _rng.randf() * TAU
		var flat := _ground_dir(angle) * _rng.randf_range(40.0, 120.0)
		_add({"kind": "debris", "p": Vector3(at.x, at.y, _rng.randf_range(12.0, 36.0)),
			"v": Vector3(flat.x, flat.y, _rng.randf_range(120.0, 300.0)),
			"life": DEBRIS_LIFE * _rng.randf_range(0.85, 1.15),
			"color": colors[i % colors.size()] if not colors.is_empty() else Color.GRAY,
			"size": _rng.randf_range(2.5, 4.5), "spin": _rng.randf_range(-12.0, 12.0),
			"rot": _rng.randf() * TAU})
	smoke(at, 18.0, 4)


## Staub beim Auftreten (Molok).
func dust(at: Vector2) -> void:
	for i in 3:
		var side := _ground_dir(_rng.randf() * TAU) * _rng.randf_range(16.0, 30.0)
		_add({"kind": "dust", "p": Vector3(at.x, at.y, 1.0),
			"v": Vector3(side.x, side.y, _rng.randf_range(8.0, 18.0)),
			"life": DUST_LIFE * _rng.randf_range(0.8, 1.2),
			"color": Color(0.62, 0.56, 0.66), "size": _rng.randf_range(2.5, 4.0)})


## Dampfstoss aus einem Rost (Factory 5).
func steam(at: Vector2) -> void:
	for i in 4:
		var side := _ground_dir(_rng.randf() * TAU) * _rng.randf_range(2.0, 6.0)
		_add({"kind": "steam", "p": Vector3(at.x + side.x, at.y + side.y, 4.0 + 6.0 * i),
			"v": Vector3(side.x, side.y, _rng.randf_range(28.0, 44.0)),
			"life": STEAM_LIFE * _rng.randf_range(0.8, 1.1),
			"color": Color(0.85, 0.82, 0.9), "size": _rng.randf_range(4.0, 6.0)})


# ---------------------------------------------------------------------------
# Rechnen und Zeichnen
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _parts.is_empty():
		return
	step(delta)
	queue_redraw()


## Ein Zeitschritt (auch fuer Tests ohne Baum).
func step(delta: float) -> void:
	var keep: Array = []
	for part in _parts:
		part["age"] = float(part["age"]) + delta
		if float(part["age"]) >= float(part["life"]):
			continue
		keep.append(part)
		var p: Vector3 = part["p"]
		var v: Vector3 = part["v"]
		match str(part["kind"]):
			"spark", "debris":
				if not part["rest"]:
					v.z -= GRAVITY * delta
					p += v * delta
					if p.z <= 0.0:
						p.z = 0.0
						if absf(v.z) < 60.0:
							part["rest"] = true
							v = Vector3.ZERO
						else:
							v = Vector3(v.x * 0.45, v.y * 0.45, -v.z * 0.3)
					part["rot"] = float(part["rot"]) + float(part["spin"]) * delta
			_:
				# Rauch, Staub, Dampf: steigen, werden langsamer.
				v *= maxf(0.0, 1.0 - delta * 1.6)
				p += v * delta
		part["p"] = p
		part["v"] = v
	_parts = keep


func _draw() -> void:
	var s := maxf(1.0, pixel_scale * 0.8)
	for part in _parts:
		var p: Vector3 = part["p"]
		var at := Vector2(p.x, p.y - p.z)
		var k := float(part["age"]) / float(part["life"])
		var color: Color = part["color"]
		match str(part["kind"]):
			"spark":
				var v: Vector3 = part["v"]
				var screen_v := Vector2(v.x, v.y - v.z)
				var tail := at - screen_v.limit_length(220.0) * 0.03
				if part["rest"]:
					draw_circle(at, 1.3 * s, Color(color, 0.8 * (1.0 - k)))
				else:
					draw_line(tail, at, Color(color, 1.0 - k * 0.6), 1.6 * s, true)
			"debris":
				var r := float(part["size"]) * s
				var rot := float(part["rot"])
				var pts := PackedVector2Array()
				for i in 4:
					var a := rot + i * PI * 0.5
					pts.append(at + Vector2(cos(a), sin(a) * 0.7) * r)
				var fade := 1.0 if k < 0.7 else 1.0 - (k - 0.7) / 0.3
				draw_colored_polygon(pts, Color(color, fade))
				pts.append(pts[0])
				draw_polyline(pts, Color(0.03, 0.04, 0.07, fade), 1.0 * s, true)
			_:
				var grow := 1.0 + k * (1.6 if part["kind"] != "dust" else 0.8)
				var alpha := (0.42 if part["kind"] == "smoke" else 0.32) * (1.0 - k)
				draw_circle(at, float(part["size"]) * grow * s, Color(color, alpha))
