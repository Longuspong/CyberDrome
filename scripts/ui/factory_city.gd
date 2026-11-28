class_name FactoryCity
extends RefCounted

## Die Fabrikstadt in 3D (28. Nov. 2026, docs/FACTORY_KONZEPT.md Abschnitt 14).
##
## Baut Felder, Quellen, Gebaeude (je Typ T1-T3) und Leiterbahnen als Meshes
## aus Grundformen -- uebertragen aus dem Entwurfs-Skript
## docs/design/fabrik_stadt/fabrikstadt.py (``building``, ``tile``) und
## grundformen.py (``prism``, ``box``, ``cyl``, ``lamp``, ``deposit``).
## Stil wie die DROMEs: matte Platten, oben heller als vorn, dunkle Kante je
## Flaeche (factory_face.gdshader), Kontur je Teil in der Linienfarbe als
## Huelle (factory_hull.gdshader). Leuchtteile sind flache Farbflaechen; ohne
## Strom werden sie grau.
##
## Einheiten wie im Entwurf: ein Hexfeld hat Radius 1 (Abstand der Mitten
## 1,5 bzw. sqrt 3), x nach rechts, z nach Sueden (zur Kamera), y nach oben.
## Die Kamera (``make_camera``) schaut steil von Sueden; ``Y_STRETCH`` streckt
## die Hoehe auf das Mass des Entwurfs (Tiefe 0,86, Hoehe 0,58 je Einheit).

const K := 1.7320508
const TILE_H := 0.16
## Kamera: Neigung so, dass der Boden wie im Entwurf auf 0,86 schrumpft.
const PITCH_SIN := 0.86
const Y_STRETCH := 0.58 / 0.5103
## Breite der Kontur je Teil (Entwurf: 3,5 px Strich bei 50 px je Einheit).
const HULL := 0.034
const NIGHT := "#0a0618"
const OFF := "#3a3450"
const GHOST_FILL := "#1a1430"
const GHOST_LINE := "#ffe14d"

const LINE := {"schrott": "#ff6a3d", "neon": "#2ee3eb", "daten": "#9d84ff", "strom": "#6dffa8",
	"logistik": "#fff7fe"}
## Blech je Linie und Stufe: [oben, vorn].
const PAL := {
	"schrott": {1: ["#6b5466", "#45334a"], 2: ["#8c7088", "#5e4a62"], 3: ["#b49bb0", "#7e6784"]},
	"neon": {1: ["#4a5a8e", "#2e3a66"], 2: ["#6478b0", "#43548a"], 3: ["#91a4d8", "#6074a8"]},
	"daten": {1: ["#5d4c8e", "#3a2c66"], 2: ["#7d70b4", "#51458a"], 3: ["#a197d6", "#6c61a8"]},
	"strom": {1: ["#3f5a6a", "#27404c"], 2: ["#577c8c", "#3a5866"], 3: ["#82a8b6", "#577e8c"]},
	"logistik": {1: ["#5a5470", "#3a3550"], 2: ["#7a7494", "#544e6e"], 3: ["#a7a2c0", "#76708f"]},
}
const DARK := ["#30244f", "#1d1538"]
const RUST := ["#8a5a40", "#5e3c2a"]
const WARE_TRACK := "#8a6a12"

const FACE_SHADER := preload("res://assets/shaders/factory_face.gdshader")
const HULL_SHADER := preload("res://assets/shaders/factory_hull.gdshader")

static var _meshes: Dictionary = {}
static var _face_mat: ShaderMaterial = null
static var _hull_mat: ShaderMaterial = null


# ---------------------------------------------------------------- Lage

## Mitte eines Feldes (axial q, r) in Welt-Einheiten (x, z).
static func cell_pos(q: int, r: int) -> Vector2:
	return Vector2(1.5 * q, K * (r + q / 2.0))


static func key_pos(k: String) -> Vector2:
	var p := FactorySim.unkey(k)
	return cell_pos(p.x, p.y)


## Feld unter einem Weltpunkt (x, z) -- runden in Wuerfelkoordinaten.
static func key_at(x: float, z: float) -> String:
	var q := (2.0 / 3.0 * x)
	var r := (-1.0 / 3.0 * x + K / 3.0 * z)
	var s := -q - r
	var rq := roundf(q)
	var rr := roundf(r)
	var rs := roundf(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return FactorySim.key(int(rq), int(rr))


## Ecken eines flachen Sechsecks (Kante oben/unten) um (0, 0).
static func hex_corners(radius: float, rot_deg: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i + rot_deg)
		out.append(Vector2(cos(a), sin(a)) * radius)
	return out


## Feste Kamera steil von Sueden, ``px_per_unit`` Bildpunkte je Einheit
## (Entwurf: 50, ein Feld also gut 92 px breit). Blickt auf ``target``.
static func make_camera(px_per_unit: float, viewport_width: float, target := Vector3.ZERO) -> Camera3D:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.near = 0.1
	cam.far = 200.0
	cam.size = maxf(1.0, viewport_width) / px_per_unit
	place_camera(cam, target)
	return cam


static func place_camera(cam: Camera3D, target: Vector3) -> void:
	var t := asin(PITCH_SIN)
	var back := Vector3(0.0, sin(t), cos(t))
	cam.transform = Transform3D(Basis.from_euler(Vector3(-t, 0.0, 0.0)), target + back * 60.0)


static func face_material() -> ShaderMaterial:
	if _face_mat == null:
		_face_mat = ShaderMaterial.new()
		_face_mat.shader = FACE_SHADER
	return _face_mat


static func hull_material() -> ShaderMaterial:
	if _hull_mat == null:
		_hull_mat = ShaderMaterial.new()
		_hull_mat.shader = HULL_SHADER
	return _hull_mat


## Ein Mesh als Knoten (ohne Schatten).
static func instance(mesh: Mesh, at := Vector3.ZERO) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst


# ---------------------------------------------------------------- Meshes (gecacht)

## Feld: "free", "locked" oder "built" (Rand in den Linienfarben, Kerben je Stufe).
static func tile_mesh(kind: String, lines: Array = [], tier: int = 1) -> ArrayMesh:
	var key := "tile|%s|%s|%d" % [kind, ",".join(lines), tier]
	if _meshes.has(key):
		return _meshes[key]
	var g := Geo.new()
	var top: String = {"locked": "#160d2e", "built": "#2f1d5e", "free": "#28184f"}.get(kind, "#28184f")
	g.hexp(0, 0, 0.92, 0, TILE_H, [top, "#120a26" if kind == "locked" else "#190f36"], null)
	var inner := hex_corners(0.8)
	if kind == "built":
		var cols: Array = []
		for l in lines:
			cols.append(LINE.get(l, LINE["logistik"]))
		for i in 6:
			g.flat_line(inner[i], inner[(i + 1) % 6], TILE_H + 0.002, 0.036, cols[i % cols.size()])
		var zz := 0.92 * K / 2.0
		for i in tier:
			var dx := (i - (tier - 1) / 2.0) * 0.24
			g.front_quad(dx, zz + 0.004, 0.18, 0.0, TILE_H, cols[0])
	elif kind == "free":
		for i in 6:
			g.flat_line(inner[i], inner[(i + 1) % 6], TILE_H + 0.002, 0.02, "#4a3a80")
	else:
		for i in 6:
			var a := inner[i]
			var b := inner[(i + 1) % 6]
			for s in 4:
				var t0 := s / 4.0 + 0.02
				g.flat_line(a.lerp(b, t0), a.lerp(b, t0 + 0.13), TILE_H + 0.002, 0.028, "#6a5a96")
	var mesh := g.commit()
	_meshes[key] = mesh
	return mesh


## Quelle ohne Gebaeude (S, N, D); gesperrt dunkler.
static func deposit_mesh(kind: String, locked: bool) -> ArrayMesh:
	var key := "dep|%s|%s" % [kind, locked]
	if _meshes.has(key):
		return _meshes[key]
	var g := Geo.new()
	g.deposit(_deposit_name(kind), 0, 0, locked, 1.0)
	var mesh := g.commit()
	_meshes[key] = mesh
	return mesh


static func _deposit_name(kind: String) -> String:
	match kind:
		"S": return "schrott"
		"N": return "neon"
	return "daten"


## Ein Gebaeude auf Stufe ``tier``. ``on`` = mit Strom (sonst graue
## Leuchtflaechen), ``ghost`` = Bau-Vorschau, ``mono`` = gesperrt (grau).
static func building_mesh(type: String, tier: int, on: bool = true, ghost: bool = false,
		mono: bool = false) -> ArrayMesh:
	var key := "b|%s|%d|%s|%s|%s" % [type, tier, on, ghost, mono]
	if _meshes.has(key):
		return _meshes[key]
	var g := Geo.new()
	g.ghost = ghost
	g.mono = mono
	_building(g, type, 0.0, 0.0, clampi(tier, 1, 3), on)
	var mesh := g.commit()
	_meshes[key] = mesh
	return mesh


## Die Platte unter den Feldern: grosses Sechseck mit Rand und Leiterbahn-Deko.
static func board_mesh(radius: int) -> ArrayMesh:
	var key := "board|%d" % radius
	if _meshes.has(key):
		return _meshes[key]
	var g := Geo.new()
	var br := 1.5 * radius + 2.05
	var pc := hex_corners(br, 30.0)
	g.prism(0, 0, pc, -0.45, 0.449, ["#1b0b3a", "#120a26"], null, false, 0.25)
	for i in 6:
		g.flat_line(pc[i], pc[(i + 1) % 6], 0.0, 0.05, "#2ee3eb")
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 4
	for n in 80:
		var a := rnd.randf() * TAU
		var rr := br - 1.35 + rnd.randf() * 0.9
		var p := Vector2(cos(a), sin(a)) * rr
		var d: float = [0.0, PI / 3.0, 2.0 * PI / 3.0][rnd.randi() % 3]
		var p2 := p + Vector2(cos(d), sin(d)) * (0.3 + rnd.randf() * 0.6)
		if not (_inside(p, br - 0.3) and _inside(p2, br - 0.3)):
			continue
		g.flat_line(p, p2, 0.001, 0.04, "#4a3a80")
		g.flat_dot(p2, 0.002, 0.05, "#8a6a12")
	var mesh := g.commit()
	_meshes[key] = mesh
	return mesh


static func _inside(p: Vector2, br: float) -> bool:
	return absf(p.y) <= br * K / 2.0 and absf(p.y) + absf(p.x) / K <= br


## Leiterbahn zwischen Feldmitten (Weltpunkte x/z): dunkler Grund, Bahn, Ware.
static func trace_mesh(points: PackedVector2Array, ware_color: Color, jam: bool) -> ArrayMesh:
	var g := Geo.new()
	for i in points.size() - 1:
		g.flat_line(points[i], points[i + 1], TILE_H + 0.006, 0.16, NIGHT)
	for i in points.size() - 1:
		g.flat_line(points[i], points[i + 1], TILE_H + 0.008, 0.12, "#5a4a3a" if jam else WARE_TRACK)
	if not jam:
		for i in points.size() - 1:
			g.flat_line(points[i], points[i + 1], TILE_H + 0.01, 0.04, "#" + ware_color.to_html(false))
	return g.commit()


# ---------------------------------------------------------------- Gebaeude

static func _pal(line: String, tier: int) -> Array:
	return (PAL.get(line, PAL["logistik"]) as Dictionary)[clampi(tier, 1, 3)]


static func _plinth(g: Geo, x: float, z: float, y: float, tier: int, line: String) -> float:
	var t := _pal(line, mini(3, tier + 1))
	var c: String = LINE[line]
	if tier == 2:
		g.hexp(x, z, 0.74, y, 0.1, t, c)
		return y + 0.1
	if tier == 3:
		g.hexp(x, z, 0.8, y, 0.08, t, c)
		g.hexp(x, z, 0.66, y + 0.08, 0.08, t, c)
		return y + 0.16
	return y


static func _building(g: Geo, t: String, x: float, z: float, tier: int, on: bool) -> void:
	var lines: Array = ["logistik"] if t == "basis" else FactorySim.lines_of(t)
	var main := str(lines[0])
	var lit := func(c: String) -> String: return c if on else OFF
	var C := {}
	var B := {}
	var TR := {}
	for l in lines:
		C[l] = LINE[l]
		B[l] = _pal(l, tier)
		TR[l] = _pal(l, mini(3, tier + 1))
	var roof := func(l: String) -> Array:
		return [LINE[l], _pal(l, 1)[1]] if tier == 3 else TR[l]
	var y := TILE_H
	if t != "basis":
		y = _plinth(g, x, z, y, tier, main)
	match t:
		"basis":
			var c: String = LINE["logistik"]
			g.hexp(x, z, 0.74, y, 0.12, DARK, c)
			g.hexp(x, z, 0.52, y + 0.12, 0.3, _pal("logistik", 1), c)
			for dx in [-0.24, 0.0, 0.24]:
				g.lamp(x + dx, z + 0.45, 0.1, y + 0.2, 0.12, "#2ee3eb")
			var top := y + 0.42
			for k in tier - 1:
				g.hexp(x, z, 0.42 - 0.06 * k, top, 0.24, _pal("logistik", 2 + k), c)
				g.lamp(x, z + 0.36 - 0.05 * k, 0.28, top + 0.08, 0.07, "#2ee3eb")
				top += 0.24
			g.hexp(x, z, 0.3, top, 0.24, _pal("logistik", 3), c)
			top += 0.24
			g.hexp(x, z, 0.33, top, 0.06, ["#ffe14d", "#b89a1c"], c)
			top += 0.06
			var h := 0.2 + 0.12 * tier
			g.cyl(x, z, 0.05, top, h, DARK, c)
			g.cyl(x, z, 0.09, top + h, 0.07, ["#fff7fe", "#c3b3e6"], c)
		# ---------- Schrott: kantig, schwer, Rost, Schornsteine, Magnet ----------
		"sam":
			var c: String = C["schrott"]
			var b: Array = B["schrott"]
			g.deposit("schrott", x + 0.16, z + 0.14, false, 0.8)
			g.box(x - 0.38, z - 0.28, 0.4, 0.34, y, 0.3, b, c)
			if tier == 1:
				g.box(x - 0.48, z - 0.12, 0.12, 0.02, y + 0.05, 0.1, RUST, null)
			g.lamp(x - 0.32, z - 0.11, 0.14, y + 0.14, 0.08, lit.call(c))
			g.box(x - 0.38, z - 0.28, 0.1, 0.1, y + 0.3, 0.42 + 0.06 * tier, TR["schrott"], c)
			var top := y + 0.72 + 0.06 * tier
			g.box(x - 0.05, z - 0.28, 0.74, 0.1, top, 0.07, roof.call("schrott"), c)
			if tier >= 2:
				g.box(x - 0.48, z - 0.28, 0.16, 0.14, top - 0.04, 0.1, DARK, c)
			g.box(x + 0.28, z - 0.06, 0.3, 0.2, y + 0.38, 0.08, DARK, c)
			g.lamp(x + 0.28, z + 0.04, 0.22, y + 0.38, 0.04, lit.call(c))
		"smz":
			var c: String = C["schrott"]
			var b: Array = B["schrott"]
			g.box(x, z + 0.02, 0.92, 0.62, y, 0.32, b, c)
			if tier == 1:
				g.box(x + 0.32, z + 0.33, 0.18, 0.02, y + 0.05, 0.12, RUST, null)
			g.lamp(x - 0.12, z + 0.33, 0.44, y + 0.1, 0.1, lit.call(c))
			g.box(x - 0.14, z - 0.02, 0.44, 0.38, y + 0.32, 0.12, roof.call("schrott"), c)
			g.box(x - 0.14, z - 0.02, 0.28, 0.24, y + 0.44, 0.02, [lit.call("#ffb347"), "#b8762a"], null)
			for i in tier:
				var cz := z - 0.18 + i * 0.16
				g.box(x + 0.32, cz, 0.14, 0.12, y + 0.32, 0.5 - 0.08 * i, DARK, c)
		"rec":
			var c: String = C["schrott"]
			var b: Array = B["schrott"]
			g.box(x, z - 0.06, 0.88, 0.56, y, 0.16, b, c)
			for i in (2 if tier >= 2 else 1):
				g.box(x - 0.22 + i * 0.4, z - 0.14, 0.32, 0.3, y + 0.16, 0.26, TR["schrott"], c)
				g.lamp(x - 0.22 + i * 0.4, z + 0.01, 0.18, y + 0.24, 0.06, lit.call(c))
			if tier == 3:
				g.box(x, z - 0.14, 0.86, 0.12, y + 0.42, 0.05, roof.call("schrott"), c)
			for p in [Vector2(-0.2, 0), Vector2(0, 0), Vector2(0.2, 0), Vector2(-0.1, 0.12), Vector2(0.1, 0.12)]:
				g.box(x + p.x, z + 0.34, 0.17, 0.14, y + p.y, 0.12, ["#6a5c78", "#463c54"], null)
		"vdi":
			var c: String = C["schrott"]
			var b: Array = B["schrott"]
			g.box(x, z - 0.05, 0.9, 0.56, y, 0.12, DARK, c)
			for dx in [-0.36, 0.36]:
				g.box(x + dx, z - 0.12, 0.14, 0.14, y + 0.12, 0.6, b, c)
			g.box(x, z - 0.12, 0.9, 0.16, y + 0.72, 0.1, roof.call("schrott"), c)
			g.box(x, z - 0.12, 0.38, 0.3, y + 0.42, 0.18, TR["schrott"], c)
			g.lamp(x, z + 0.03, 0.22, y + 0.46, 0.06, lit.call(c))
			for i in tier + 1:
				g.box(x, z + 0.32, 0.34, 0.16, y + i * 0.06, 0.06, ["#ffb347", "#b8762a"], null)
		"ofn":
			var c: String = C["schrott"]
			var b: Array = B["schrott"]
			g.box(x, z, 0.8, 0.6, y, 0.26, b, c)
			if tier == 1:
				g.box(x - 0.28, z + 0.3, 0.16, 0.02, y + 0.04, 0.1, RUST, null)
			g.lamp(x + 0.08, z + 0.3, 0.3, y + 0.06, 0.1, lit.call("#ff9e26"))
			g.box(x - 0.16, z - 0.1, 0.36, 0.32, y + 0.26, 0.16, roof.call("schrott"), c)
			for i in tier:
				g.box(x + 0.28, z - 0.2 + i * 0.14, 0.12, 0.1, y + 0.26, 0.36 - 0.06 * i, DARK, c)
			g.box(x - 0.16, z + 0.07, 0.14, 0.02, y + 0.3, 0.08, [lit.call("#6dffa8"), "#3aa870"], null)
		# ---------- Neon: rund, Tanks, Glas, Ringe ----------
		"pmp":
			var c: String = C["neon"]
			var b: Array = B["neon"]
			g.deposit("neon", x + 0.26, z + 0.16, false, 0.75)
			g.cyl(x - 0.18, z - 0.08, 0.3, y, 0.26, b, c, lit.call(c))
			for i in tier:
				g.cyl(x - 0.4 + i * 0.2, z - 0.3, 0.07, y + 0.08, 0.36 + 0.04 * i, TR["neon"], c, DARK[0])
			g.cyl(x + 0.2, z - 0.24, 0.1, y, 0.22, roof.call("neon"), c, lit.call(c))
		"pls":
			var c: String = C["neon"]
			var b: Array = B["neon"]
			g.cyl(x, z, 0.5, y, 0.1, DARK, c)
			g.cyl(x, z, 0.34, y + 0.1, 0.26, b, c, lit.call("#ff2bd6"))
			var n := 2 if tier < 3 else 4
			for i in n:
				var a := PI * (0.15 + float(i) / n * 2.0)
				g.cyl(x + 0.42 * cos(a), z + 0.42 * sin(a) * 0.8, 0.06, y + 0.1, 0.34 + 0.06 * tier,
					TR["neon"], c, lit.call(c))
			if tier >= 2:
				g.cyl(x, z, 0.12, y + 0.36, 0.1, roof.call("neon"), c, "#fff7fe")
		"gen":
			var c: String = C["neon"]
			var b: Array = B["neon"]
			g.cyl(x, z, 0.58, y, 0.14, DARK, c)
			g.cyl(x - 0.1, z - 0.04, 0.36, y + 0.14, 0.3, b, c, lit.call(c))
			for i in tier:
				g.cyl(x - 0.1, z - 0.04, 0.38, y + 0.18 + i * 0.08, 0.03, TR["neon"], c)
			g.cyl(x - 0.1, z - 0.04, 0.12, y + 0.44, 0.14, roof.call("neon"), c, "#fff7fe")
			g.cyl(x + 0.42, z + 0.08, 0.13, y + 0.14, 0.26, TR["neon"], c, lit.call("#6dffa8"))
		# ---------- Daten: schlank, Masten, Schuesseln ----------
		"scn":
			var c: String = C["daten"]
			var b: Array = B["daten"]
			g.deposit("daten", x + 0.3, z + 0.16, false, 0.85)
			g.box(x - 0.22, z - 0.14, 0.12, 0.12, y, 0.36 + 0.06 * tier, b, c)
			var r := 0.26 + 0.05 * tier
			var top := y + 0.36 + 0.06 * tier
			g.prism(x - 0.22, z - 0.14, hex_corners(r, 30.0), top, 0.06, TR["daten"], c)
			g.prism(x - 0.22, z - 0.14, hex_corners(r * 0.6, 30.0), top + 0.06, 0.02,
				roof.call("daten") if tier == 3 else DARK, null)
			g.box(x - 0.22, z - 0.14, 0.04, 0.04, top + 0.06, 0.14, DARK, c)
			if tier >= 2:
				g.box(x - 0.5, z + 0.18, 0.08, 0.08, y, 0.4, b, c)
				g.lamp(x - 0.5, z + 0.22, 0.06, y + 0.3, 0.06, lit.call(c))
		# ---------- Herstellen: Mischung ----------
		"lot":
			var cs: String = C["schrott"]
			var cd: String = C["daten"]
			g.box(x + 0.06, z + 0.02, 0.74, 0.6, y, 0.18, B["schrott"], cs)
			for i in 3:
				g.toplamp(x + 0.1, z - 0.16 + i * 0.16, 0.46, 0.04, y + 0.18, lit.call("#6dffa8"))
			g.box(x - 0.38, z - 0.22, 0.12, 0.12, y, 0.56 + 0.06 * tier, B["daten"], cd)
			var top := y + 0.56 + 0.06 * tier
			g.box(x - 0.12, z - 0.22, 0.56, 0.08, top, 0.06, roof.call("daten") if tier == 3 else TR["daten"], cd)
			g.box(x + 0.14, z - 0.22, 0.05, 0.05, top - 0.22, 0.22, DARK, cd)
			for i in tier:
				g.lamp(x - 0.38, z - 0.16, 0.06, y + 0.12 + i * 0.12, 0.06, lit.call(cd))
		"chp":
			var cs: String = C["schrott"]
			var cd: String = C["daten"]
			var cn: String = C["neon"]
			g.box(x - 0.06, z + 0.02, 0.78, 0.66, y, 0.26, B["schrott"], cs)
			for i in tier:
				g.lamp(x - 0.3 + i * 0.22, z + 0.35, 0.16, y + 0.08, 0.1, lit.call(cs))
			g.box(x - 0.1, z - 0.04, 0.36, 0.36, y + 0.26, 0.08, ["#fff7fe", "#c3b3e6"], cd)
			for i in 4:
				g.toplamp(x - 0.25 + i * 0.1, z - 0.27, 0.04, 0.08, y + 0.34, "#d4a017")
				g.toplamp(x - 0.25 + i * 0.1, z + 0.19, 0.04, 0.08, y + 0.34, "#d4a017")
			g.cyl(x + 0.42, z - 0.14, 0.14, y, 0.42, B["neon"], cn, lit.call("#ff2bd6"))
		# ---------- Strom (gruen) ----------
		"sol":
			var c: String = C["strom"]
			var b: Array = B["strom"]
			var rows := 3 if tier >= 2 else 2
			for i in rows:
				var zz := z - 0.3 + i * (0.6 / maxf(1.0, rows - 1))
				g.box(x, zz, 0.06, 0.06, y, 0.14, DARK, null)
				g.box(x, zz, 0.7, 0.22, y + 0.14, 0.05, b, c)
				for j in [-0.22, 0.0, 0.22]:
					g.toplamp(x + j, zz, 0.02, 0.2, y + 0.19, "#7ccff0" if tier < 3 else c)
			if tier == 3:
				g.box(x - 0.42, z, 0.06, 0.06, y, 0.4, TR["strom"], c)
		"bat":
			var c: String = C["strom"]
			var b: Array = B["strom"]
			var n := tier + 1
			g.box(x, z, 0.88, 0.56, y, 0.08, DARK, c)
			for i in n:
				var dx := (i - (n - 1) / 2.0) * (0.7 / maxf(1.0, n - 1)) if n > 1 else 0.0
				g.box(x + dx, z - 0.04, 0.18, 0.18, y + 0.08, 0.44, b, c)
				g.lamp(x + dx, z + 0.05, 0.12, y + 0.2, 0.05, lit.call(c))
				g.lamp(x + dx, z + 0.05, 0.12, y + 0.3, 0.05, lit.call(c))
				g.box(x + dx, z - 0.04, 0.08, 0.08, y + 0.52, 0.04, roof.call("strom"), null)
		# ---------- Logistik (weiss) ----------
		"rel":
			var c: String = C["logistik"]
			var b: Array = B["logistik"]
			g.hexp(x, z, 0.28, y, 0.1, DARK, c)
			var h := 0.5 + 0.12 * tier
			g.box(x, z, 0.1, 0.1, y + 0.1, h, b, c)
			g.box(x, z, 0.62, 0.08, y + 0.1 + h, 0.06, roof.call("logistik") if tier == 3 else TR["logistik"], c)
			for dx in [-0.3, 0.3]:
				g.box(x + dx, z, 0.1, 0.1, y + 0.16 + h, 0.08, [lit.call("#2ee3eb"), "#1f9aa5"], c)
		_:
			g.box(x, z, 0.6, 0.5, y, 0.3, _pal(main, tier), LINE[main])


# ---------------------------------------------------------------- Baukasten

## Sammelt Flaechen (factory_face) und Konturhuellen (factory_hull) in zwei
## Oberflaechen eines Mesh.
class Geo extends RefCounted:
	var faces := SurfaceTool.new()
	var hull := SurfaceTool.new()
	var _nfaces := 0
	var _nhull := 0
	## Bau-Vorschau: dunkle Flaechen, gelbe Kontur, keine Leuchtteile.
	var ghost := false
	## Gesperrt im Bau-Menue: alle Farben grau.
	var mono := false

	func _init() -> void:
		faces.begin(Mesh.PRIMITIVE_TRIANGLES)
		hull.begin(Mesh.PRIMITIVE_TRIANGLES)

	func commit() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		if _nfaces > 0:
			faces.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, FactoryCity.face_material())
		if _nhull > 0:
			hull.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, FactoryCity.hull_material())
		return mesh

	func col(hex: String) -> Color:
		var c := Color(hex)
		if mono and hex != FactoryCity.NIGHT:
			var v := (0.3 * c.r + 0.59 * c.g + 0.11 * c.b) * 0.55 + 30.0 / 255.0
			return Color(v, v, minf(1.0, v + 12.0 / 255.0))
		return c

	func _v(st: SurfaceTool, n: Vector3, c: Color, mode: float, uv: Vector2, p: Vector3) -> void:
		st.set_normal(n)
		st.set_uv(uv)
		st.set_color(Color(c.r, c.g, c.b, mode))
		st.add_vertex(p)

	## Viereck p0..p3 (gegen den Uhrzeigersinn um n gesehen egal -- ohne Culling).
	func _quad(st: SurfaceTool, p: Array, n: Vector3, c: Color, mode: float) -> void:
		var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for i in [0, 1, 2, 0, 2, 3]:
			_v(st, n, c, mode, uv[i], p[i])
		if st == faces:
			_nfaces += 6
		else:
			_nhull += 6

	## Prisma ueber den Ecken ``corners`` (um x/z), Hoehe y0..y0+h.
	## ``cols`` [oben, Seiten], ``con`` Konturfarbe (null = keine),
	## ``round`` = Zylinder (Mantel ohne senkrechte Kanten, Deckel als Scheibe).
	func prism(x: float, z: float, corners: PackedVector2Array, y0: float, h: float, cols: Array,
			con, round: bool = false, mode_override: float = -1.0) -> void:
		var top_c := col(FactoryCity.GHOST_FILL if ghost else str(cols[0]))
		var side_c := col(FactoryCity.GHOST_FILL if ghost else str(cols[1]))
		var n := corners.size()
		var cen := Vector2.ZERO
		for p in corners:
			cen += p
		cen /= float(n)
		var y1 := y0 + h
		# Deckel
		if n == 4 and not round:
			var pts := []
			for p in corners:
				pts.append(Vector3(x + p.x, y1, z + p.y))
			_quad(faces, pts, Vector3.UP, top_c, 1.0 if mode_override < 0.0 else mode_override)
		else:
			var c3 := Vector3(x + cen.x, y1, z + cen.y)
			var m := 0.5 if mode_override < 0.0 else mode_override
			for i in n:
				var a := corners[i]
				var b := corners[(i + 1) % n]
				_v(faces, Vector3.UP, top_c, m, Vector2(0, 0), c3)
				_v(faces, Vector3.UP, top_c, m, Vector2(1, 0), Vector3(x + a.x, y1, z + a.y))
				_v(faces, Vector3.UP, top_c, m, Vector2(1, 0), Vector3(x + b.x, y1, z + b.y))
				_nfaces += 3
		# Seiten
		var side_mode := (0.75 if round else 1.0) if mode_override < 0.0 else mode_override
		for i in n:
			var a := corners[i]
			var b := corners[(i + 1) % n]
			var mid := (a + b) * 0.5 - cen
			var nn := Vector3(b.y - a.y, 0, -(b.x - a.x)).normalized()
			if nn.x * mid.x + nn.z * mid.y < 0.0:
				nn = -nn
			_quad(faces, [Vector3(x + a.x, y1, z + a.y), Vector3(x + b.x, y1, z + b.y),
				Vector3(x + b.x, y0, z + b.y), Vector3(x + a.x, y0, z + a.y)], nn, side_c, side_mode)
		var line = FactoryCity.GHOST_LINE if ghost else con
		if line == null:
			return
		_hull_prism(x, z, corners, cen, y0, h, col(str(line)))

	func _hull_prism(x: float, z: float, corners: PackedVector2Array, cen: Vector2, y0: float, h: float,
			c: Color) -> void:
		var w := FactoryCity.HULL
		var big := PackedVector2Array()
		for p in corners:
			var d := p - cen
			big.append(p + (d.normalized() * w * 1.2 if d.length() > 0.0001 else Vector2.ZERO))
		var n := big.size()
		var y_lo := y0 - w
		var y_hi := y0 + h + w
		var ccen := Vector3(x + cen.x, y_hi, z + cen.y)
		var bcen := Vector3(x + cen.x, y_lo, z + cen.y)
		for i in n:
			var a := big[i]
			var b := big[(i + 1) % n]
			var pa := Vector3(x + a.x, y_hi, z + a.y)
			var pb := Vector3(x + b.x, y_hi, z + b.y)
			var qa := Vector3(x + a.x, y_lo, z + a.y)
			var qb := Vector3(x + b.x, y_lo, z + b.y)
			for p in [ccen, pa, pb]:
				_v(hull, Vector3.UP, c, 0.0, Vector2.ZERO, p)
			for p in [bcen, qb, qa]:
				_v(hull, Vector3.DOWN, c, 0.0, Vector2.ZERO, p)
			_nhull += 6
			var mid := (a + b) * 0.5 - cen
			var nn := Vector3(b.y - a.y, 0, -(b.x - a.x)).normalized()
			if nn.x * mid.x + nn.z * mid.y < 0.0:
				nn = -nn
			_quad(hull, [pa, pb, qb, qa], nn, c, 0.0)

	func box(x: float, z: float, w: float, d: float, y0: float, h: float, cols: Array, con) -> void:
		var c := PackedVector2Array([Vector2(-w / 2, -d / 2), Vector2(w / 2, -d / 2), Vector2(w / 2, d / 2),
			Vector2(-w / 2, d / 2)])
		prism(x, z, c, y0, h, cols, con)

	func hexp(x: float, z: float, r: float, y0: float, h: float, cols: Array, con, rot: float = 0.0) -> void:
		prism(x, z, FactoryCity.hex_corners(r, rot), y0, h, cols, con)

	func cyl(x: float, z: float, r: float, y0: float, h: float, cols: Array, con, top_fill = null,
			inner: float = 0.68) -> void:
		var c := PackedVector2Array()
		for i in 18:
			var a := deg_to_rad(20.0 * i)
			c.append(Vector2(cos(a), sin(a)) * r)
		prism(x, z, c, y0, h, cols, con, true)
		if top_fill != null and not ghost:
			var disc := PackedVector2Array()
			for p in c:
				disc.append(p * inner)
			_disc(x, z, disc, y0 + h + 0.003, col(str(top_fill)))

	func _disc(x: float, z: float, corners: PackedVector2Array, y: float, c: Color) -> void:
		var c3 := Vector3(x, y, z)
		var n := corners.size()
		for i in n:
			var a := corners[i]
			var b := corners[(i + 1) % n]
			_v(faces, Vector3.UP, c, 0.5, Vector2(0, 0), c3)
			_v(faces, Vector3.UP, c, 0.5, Vector2(1, 0), Vector3(x + a.x, y, z + a.y))
			_v(faces, Vector3.UP, c, 0.5, Vector2(1, 0), Vector3(x + b.x, y, z + b.y))
			_nfaces += 3

	## Leuchtflaeche senkrecht, nach Sueden (zur Kamera).
	func lamp(x: float, z: float, w: float, y0: float, h: float, c: String) -> void:
		if ghost:
			return
		var zz := z + 0.004
		_quad(faces, [Vector3(x - w / 2, y0 + h, zz), Vector3(x + w / 2, y0 + h, zz),
			Vector3(x + w / 2, y0, zz), Vector3(x - w / 2, y0, zz)], Vector3.BACK, col(c), 1.0)

	## Leuchtflaeche waagerecht (auf einem Dach).
	func toplamp(x: float, z: float, w: float, d: float, y: float, c: String) -> void:
		if ghost:
			return
		var yy := y + 0.003
		_quad(faces, [Vector3(x - w / 2, yy, z - d / 2), Vector3(x + w / 2, yy, z - d / 2),
			Vector3(x + w / 2, yy, z + d / 2), Vector3(x - w / 2, yy, z + d / 2)], Vector3.UP, col(c), 1.0)

	## Kerbe an der Suedkante eines Feldes.
	func front_quad(x: float, z: float, w: float, y0: float, y1: float, c: String) -> void:
		_quad(faces, [Vector3(x - w / 2, y1, z), Vector3(x + w / 2, y1, z), Vector3(x + w / 2, y0, z),
			Vector3(x - w / 2, y0, z)], Vector3.BACK, col(c), 1.0)

	## Flacher Strich auf Hoehe ``y`` von a nach b (Welt x/z), Breite ``width``.
	func flat_line(a: Vector2, b: Vector2, y: float, width: float, c: String) -> void:
		var d := b - a
		if d.length() < 0.0001:
			return
		var side := Vector2(-d.y, d.x).normalized() * width * 0.5
		var ext := d.normalized() * width * 0.5
		var a2 := a - ext
		var b2 := b + ext
		_quad(faces, [Vector3(a2.x + side.x, y, a2.y + side.y), Vector3(b2.x + side.x, y, b2.y + side.y),
			Vector3(b2.x - side.x, y, b2.y - side.y), Vector3(a2.x - side.x, y, a2.y - side.y)],
			Vector3.UP, col(c), 0.25)

	func flat_dot(p: Vector2, y: float, r: float, c: String) -> void:
		var corners := FactoryCity.hex_corners(r)
		var c3 := Vector3(p.x, y, p.y)
		var cc := col(c)
		for i in 6:
			var a := corners[i]
			var b := corners[(i + 1) % 6]
			_v(faces, Vector3.UP, cc, 0.25, Vector2.ZERO, c3)
			_v(faces, Vector3.UP, cc, 0.25, Vector2.ZERO, Vector3(p.x + a.x, y, p.y + a.y))
			_v(faces, Vector3.UP, cc, 0.25, Vector2.ZERO, Vector3(p.x + b.x, y, p.y + b.y))
			_nfaces += 3

	## Quelle: Schrotthaufen, Neonkristalle oder Datenturm.
	func deposit(kind: String, x: float, z: float, locked: bool, sc: float) -> void:
		var y := FactoryCity.TILE_H
		if kind == "schrott":
			var cols: Array = FactoryCity.RUST if not locked else ["#4a4050", "#2f2838"]
			for v in [[-0.22, -0.12, 0.26, 0.14], [0.12, -0.18, 0.22, 0.1], [0.0, 0.08, 0.3, 0.18],
					[0.26, 0.12, 0.18, 0.12], [-0.25, 0.2, 0.2, 0.08]]:
				box(x + v[0] * sc, z + v[1] * sc, v[2] * sc, v[2] * 0.8 * sc, y, v[3] * sc, cols, null)
		elif kind == "neon":
			var cols: Array = ["#7ff0f5", "#1f9aa5"] if not locked else ["#3a5a6a", "#243a46"]
			for v in [[0.0, -0.05, 0.16, 0.5], [-0.22, 0.12, 0.12, 0.32], [0.22, 0.14, 0.11, 0.26]]:
				var r: float = v[2] * sc
				prism(x + v[0] * sc, z + v[1] * sc, PackedVector2Array([Vector2(0, -r), Vector2(r, 0),
					Vector2(0, r), Vector2(-r, 0)]), y, v[3] * sc, cols, null)
		else:
			var cols: Array = FactoryCity.DARK if not locked else ["#22193a", "#150f28"]
			box(x, z, 0.36 * sc, 0.3 * sc, y, 0.4 * sc, cols, null)
			for i in 3:
				lamp(x, z + 0.15 * sc, 0.22 * sc, y + (0.06 + i * 0.11) * sc, 0.04 * sc,
					"#9d84ff" if not locked else "#3a2a6a")
