class_name DromeModel
extends RefCounted

## Ein DROME als echtes 3D-Modell (17. Nov. 2026, Wunsch des Spielers).
##
## Bis dahin war ein DROME ein Stapel flacher SVG-Bilder mit EINER Tiefe je
## Bild -- Teile, die sich durchdringen (Schild vor dem Arm, Oberarm unter
## der Schulter), liessen sich so nie richtig sortieren. Jetzt liefert der
## Generator je Teil ein Modell (``<id>.m3d``: Flaechen in bot-lokalen
## Koordinaten), hier wird der ganze DROME daraus gebaut und mit
## Tiefenpuffer gerendert. Die Optik bleibt die der SVGs: drei Toene je
## Material (drome_face.gdshader), dunkle Kanten, Kontur in Signalfarbe.
##
## Koordinaten: Formen sind bot-lokal (f vorn, l links, z oben). Die
## Blickrichtung dreht das Modell (``facing_basis``); die Welt ist so gelegt,
## dass Godot X = px, Y = pz, Z = -py der Gitterkoordinaten des Generators
## ist. Die Kamera (``make_camera``) bildet das exakt auf dieselbe Projektion
## ab wie ``to_screen`` im Generator -- Bodenmitte auf (64, 96) im 128er
## Entwurfsraum, ein Weltmeter = SCALE Entwurfspunkte.

const SCALE := 1.35
const COS45 := 0.70710678
## Reihenfolge wie DromeSprites: Ausruestung nach dem Rumpf.
const SLOT_ORDER := ["feet", "body", "core", "head", "equip_left", "equip_center",
	"equip_right", "equip_shoulder"]
## Material -> (oben, links, rechts, Kante?) wie MATERIALS im Generator.
const MATERIALS := {
	"plate": ["plate_light", "plate", "plate_dark", true],
	"dark": ["plate", "plate_dark", "plate_dark", true],
	"light": ["plate_light", "plate_light", "plate", true],
	"metal": ["metal", "metal", "plate_dark", true],
	"visor": ["visor", "visor", "visor", true],
	"glow": ["glow", "glow", "glow", false],
	"accent": ["accent", "accent", "accent", false],
}
## Bot-lokale Achsen je Blickrichtung (FACINGS im Generator): F, L.
const FACINGS := {
	"south": [Vector2(-1, 0), Vector2(0, -1)],
	"east": [Vector2(0, -1), Vector2(1, 0)],
	"north": [Vector2(1, 0), Vector2(0, 1)],
	"west": [Vector2(0, 1), Vector2(-1, 0)],
}

const FACE_SHADER := preload("res://assets/shaders/drome_face.gdshader")
const HULL_SHADER := preload("res://assets/shaders/drome_hull.gdshader")

static var _models: Dictionary = {}     # Pfad -> geparstes Modell
static var _meshes: Dictionary = {}     # Schluessel -> ArrayMesh
static var _materials: Dictionary = {}  # Farben -> Material
static var _edge := 1.0                 # Kantenbreite des laufenden Aufbaus
static var _neon_build := false         # baut der laufende Aufbau eine Leuchtebene?

## Render-Ebenen (17. Nov. 2026): das Bild selbst, die Signalfarbe je Teil
## (fuer die Kontur je Teil, drome_outline.gdshader) und die Leuchtroehren
## der Neon-Teile (NeonGlow). Jede Ebene sieht eine eigene Kamera.
const LAYER_IMAGE := 1
const LAYER_SIGNAL := 2
const LAYER_NEON := 4
## Materialien, die in der Leuchtebene leuchten (wie glow_svg im Backen).
const NEON_MATS := ["glow", "accent"]


## Das Modell eines Teils, oder {} wenn es (noch) keins gibt.
static func model_of(part: PartData) -> Dictionary:
	if part == null:
		return {}
	var path := "res://assets/parts/%s/%s.m3d" % [part.set_id, part.id]
	if _models.has(path):
		return _models[path]
	var parsed = null
	if FileAccess.file_exists(path):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	var model: Dictionary = parsed if parsed is Dictionary else {}
	_models[path] = model
	return model


## Basis der Blickrichtung: bot-lokal (f, l, z) -> Godot-Welt.
##
## Neben den vier Iso-Richtungen (Hangar, Podest) gibt es seit dem Hexfeld
## (17. Nov. 2026) Winkel im Bild: "deg<grad>", 0 = nach rechts, 90 = nach
## oben, gegen den Uhrzeigersinn -- gemessen auf dem Boden, der im Kampf so
## liegt, dass die Hexreihen waagerecht laufen. Die alten Namen entsprechen
## south 225, east 315, north 45, west 135.
static func facing_basis(facing: String) -> Basis:
	if facing.begins_with("deg"):
		return angle_basis(float(facing.substr(3)))
	var fl: Array = FACINGS.get(facing, FACINGS["south"])
	var f: Vector2 = fl[0]
	var l: Vector2 = fl[1]
	return Basis(Vector3(f.x, 0, -f.y), Vector3(l.x, 0, -l.y), Vector3(0, 1, 0))


## Blick in Bildwinkel ``degrees`` (siehe facing_basis). Bildrechts auf dem
## Boden ist (1, 0, 1)/sqrt2, Bildoben (1, 0, -1)/sqrt2 -- so liegen die
## Achsen der Iso-Kamera.
static func angle_basis(degrees: float) -> Basis:
	var right := Vector3(COS45, 0, COS45)
	var up := Vector3(COS45, 0, -COS45)
	var a := deg_to_rad(degrees)
	var forward := right * cos(a) + up * sin(a)
	var left := right * cos(a + PI * 0.5) + up * sin(a + PI * 0.5)
	return Basis(forward, left, Vector3(0, 1, 0))


## Die Iso-Kamera, die genau wie ``to_screen`` im Generator projiziert.
static func make_camera() -> Camera3D:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	# 128 Entwurfspunkte hoch, ein Weltmeter = SCALE Punkte.
	cam.size = 128.0 / SCALE
	cam.near = 0.1
	cam.far = 1000.0
	cam.cull_mask = LAYER_IMAGE
	var right := Vector3(COS45, 0, COS45)
	var up := Vector3(0.5, COS45, -0.5)
	var back := Vector3(-0.5, COS45, 0.5)
	# Bildmitte (64, 64) liegt 32 Punkte ueber der Bodenmitte (64, 96).
	var center := up * (32.0 / SCALE)
	cam.transform = Transform3D(Basis(right, up, back), center + back * 400.0)
	return cam


## Baut den ganzen DROME. Rueckgabe: Node3D mit einem Kind "Ausrichtung",
## dessen Basis die Blickrichtung ist; darunter je Block ein MeshInstance3D,
## versetzt in bot-lokalen Koordinaten. Meta "accent": Signalfarbe des Chassis.
##
## ``neon_layer``: Leuchtebene immer anlegen (gemeinsame Kampfszene -- dort
## muss jeder DROME die Roehren anderer verdecken, auch ohne eigene).
static func build_node(build: DromeBuild, facing: String, resolution: int = 256,
		neon_layer: bool = false) -> Node3D:
	_edge = edge_px(resolution)
	var root := Node3D.new()
	root.name = "Drome"
	var turn := Node3D.new()
	turn.name = "Ausrichtung"
	turn.basis = facing_basis(facing)
	root.add_child(turn)
	if build == null:
		return root
	var chassis := build.body()
	var body_model := model_of(chassis)
	var body_anchors: Dictionary = body_model.get("anchors", {})
	var body_variants: Dictionary = body_model.get("variants", {})
	var weapon_variant := chassis.weapon_variant if chassis != null else ""
	root.set_meta("accent", _color(body_model.get("colors", {}).get("accent", "#2de2e6")))
	root.set_meta("line", _color(body_model.get("colors", {}).get("outline", "#080b13")))
	_neon_build = false
	for slot in SLOT_ORDER:
		if bool(model_of(build.part_in(slot)).get("neon", false)):
			_neon_build = true
	root.set_meta("neon", _neon_build)
	_neon_build = _neon_build or neon_layer

	for slot in SLOT_ORDER:
		var part := build.part_in(slot)
		var model := model_of(part)
		if model.is_empty():
			continue
		var block := model
		if str(slot).begins_with("equip_") and weapon_variant != "":
			var vname := weapon_variant + ("_right" if slot == "equip_right" else "")
			var variants: Dictionary = model.get("variants", {})
			if not variants.has(vname):
				vname = weapon_variant
			if variants.has(vname):
				block = variants[vname]
		var mount := _vec(block.get("anchors", {}).get("mount", [0, 0, 0]))
		var socket := Vector3.ZERO if slot == "body" \
			else _vec(body_anchors.get(slot, block.get("anchors", {}).get("mount", [0, 0, 0])))
		var colors: Dictionary = model.get("colors", {})
		# Waffe mit Haltung: Arm des Chassis an den Sockel, Waffe in die Hand.
		var pose: String = model.get("pose", "")
		var arm: Dictionary = body_variants.get("arm_%s_%s" % [slot, pose], {}) \
			if pose != "" else {}
		if not arm.is_empty():
			var arm_mount := _vec(arm.get("anchors", {}).get("mount", [0, 0, 0]))
			_add_block(turn, "%s_arm" % slot, "%s|arm_%s_%s" % [chassis.id, slot, pose],
				arm, body_model.get("colors", {}), socket - arm_mount, false)
			socket = _vec(arm.get("anchors", {}).get("hand", [0, 0, 0]))
		var key := str(part.id) if block == model \
			else "%s|%s" % [part.id, _variant_name(model, block)]
		# Der Rumpf bleibt liegen: sein "mount" ist nur der Bezugspunkt fuer die
		# Bildmitte, kein Sockel.
		_add_block(turn, slot, key, block, colors,
			Vector3.ZERO if slot == "body" else socket - mount, bool(model.get("neon", false)))
		# Sichtbare Passive als eigener Block (Nimbus-Kugel), damit sie sich im
		# Kampf bewegen kann (Arena3D, 18. Nov. 2026).
		if slot == "body" and body_variants.has("passive"):
			_add_block(turn, "body_passive", "%s|passive" % part.id, body_variants["passive"],
				colors, Vector3.ZERO, false)
	return root


static func _variant_name(model: Dictionary, block: Dictionary) -> String:
	var variants: Dictionary = model.get("variants", {})
	for name in variants:
		if variants[name] == block:
			return str(name)
	return ""


## Ein MeshInstance3D fuer Flaechen dieses Moduls (Bildebene, ohne Schatten).
static func mesh_instance(mesh: Mesh) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.layers = LAYER_IMAGE
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst


static func _add_block(parent: Node3D, node_name: String, key: String,
		block: Dictionary, colors: Dictionary, offset: Vector3, neon: bool) -> void:
	var mesh := _mesh_for(key, block, colors)
	if mesh == null:
		return
	var inst := mesh_instance(mesh)
	inst.name = node_name
	inst.position = offset
	# Anker (mount, hand, muzzle) fuer die Bewegung im Kampf (Arena3D).
	inst.set_meta("anchors", block.get("anchors", {}))
	parent.add_child(inst)
	# Signalfarbe: dasselbe Mesh einfarbig in der Signalfarbe des Teils. Als
	# Kind, damit es jede Bewegung des Blocks mitmacht (Zerfallen, Schritt 5).
	var signal_inst := MeshInstance3D.new()
	signal_inst.name = "Signal"
	signal_inst.mesh = mesh
	signal_inst.layers = LAYER_SIGNAL
	signal_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	signal_inst.material_override = _flat_material(_color(colors.get("accent", "#2de2e6")))
	inst.add_child(signal_inst)
	if not _neon_build:
		return
	# Leuchtebene: Roehren der Neon-Teile in ihrer Farbe, alles andere schwarz
	# -- schwarz verdeckt nur (additiv gemischt leuchtet es nicht).
	var neon_inst := MeshInstance3D.new()
	neon_inst.name = "Neon"
	neon_inst.mesh = mesh
	neon_inst.layers = LAYER_NEON
	neon_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in mesh.get_surface_count():
		var mat := str(mesh.surface_get_name(i))
		var lit := Color.BLACK
		if neon and mat in NEON_MATS:
			lit = _color(colors.get(mat, "#ff00ff"))
		neon_inst.set_surface_override_material(i, _flat_material(lit))
	inst.add_child(neon_inst)


## Einfarbiges Material ohne Licht (Signal- und Leuchtebene).
static func _flat_material(color: Color) -> StandardMaterial3D:
	var key := "flat|%s" % color.to_html()
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	_materials[key] = m
	return m


## Ein Mesh je Block: eine Flaeche je Material, dazu die Huellen.
static func _mesh_for(key: String, block: Dictionary, colors: Dictionary) -> ArrayMesh:
	var cache_key := "%s#%s#%s" % [key, str(colors.hash()), _edge]
	if _meshes.has(cache_key):
		return _meshes[cache_key]
	var by_mat: Dictionary = {}
	for face in block.get("faces", []):
		var mat: String = face[0]
		if not by_mat.has(mat):
			by_mat[mat] = SurfaceTool.new()
			by_mat[mat].begin(Mesh.PRIMITIVE_TRIANGLES)
		_add_face(by_mat[mat], face[1], _vec(face[2]), face[3])
	var mesh := ArrayMesh.new()
	for mat in by_mat:
		var st: SurfaceTool = by_mat[mat]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _face_material(mat, colors))
		mesh.surface_set_name(mesh.get_surface_count() - 1, mat)
	var hulls: Array = block.get("hulls", [])
	if not hulls.is_empty():
		var hs := SurfaceTool.new()
		hs.begin(Mesh.PRIMITIVE_TRIANGLES)
		for hull in hulls:
			_add_face(hs, "seam", _vec(hull[0]), hull[1])
		hs.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _hull_material(colors))
		mesh.surface_set_name(mesh.get_surface_count() - 1, "hull")
	if mesh.get_surface_count() == 0:
		mesh = null
	_meshes[cache_key] = mesh
	return mesh


## Eine Flaeche als Dreiecksfaecher. UV und COLOR.a tragen die Kante (siehe
## drome_face.gdshader).
static func _add_face(st: SurfaceTool, kind: String, normal: Vector3, points: Array) -> void:
	var n := points.size()
	if n < 3:
		return
	var pts: Array[Vector3] = []
	for p in points:
		pts.append(_vec(p))
	var mode := 1.0 if kind == "box" else (0.5 if kind == "disc" else 0.0)
	if kind == "disc":
		var center := Vector3.ZERO
		for p in pts:
			center += p
		center /= float(n)
		for i in n:
			_vertex(st, normal, mode, Vector2(0, 0), center)
			_vertex(st, normal, mode, Vector2(1, 0), pts[i])
			_vertex(st, normal, mode, Vector2(1, 0), pts[(i + 1) % n])
		return
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in range(1, n - 1):
		_vertex(st, normal, mode, uvs[0] if n == 4 else Vector2.ZERO, pts[0])
		_vertex(st, normal, mode, uvs[i] if n == 4 else Vector2.ZERO, pts[i])
		_vertex(st, normal, mode, uvs[i + 1] if n == 4 else Vector2.ZERO, pts[i + 1])


static func _vertex(st: SurfaceTool, normal: Vector3, mode: float, uv: Vector2,
		p: Vector3) -> void:
	st.set_normal(normal)
	st.set_uv(uv)
	st.set_color(Color(1, 1, 1, mode))
	st.add_vertex(p)


static func _face_material(mat: String, colors: Dictionary) -> ShaderMaterial:
	var roles: Array = MATERIALS.get(mat, MATERIALS["plate"])
	var key := "%s|%s|%s|%s|%s|%s" % [colors.get(roles[0], ""), colors.get(roles[1], ""),
		colors.get(roles[2], ""), colors.get("outline", ""), roles[3], _edge]
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = FACE_SHADER
	m.set_shader_parameter("c_top", _color(colors.get(roles[0], "#ff00ff")))
	m.set_shader_parameter("c_left", _color(colors.get(roles[1], "#ff00ff")))
	m.set_shader_parameter("c_right", _color(colors.get(roles[2], "#ff00ff")))
	m.set_shader_parameter("c_line", _color(colors.get("outline", "#080b13")))
	# Leucht- und Akzentmaterial tragen keinen Strich (wie im SVG).
	m.set_shader_parameter("edge_px", _edge if roles[3] else 0.0)
	_materials[key] = m
	return m


static func _hull_material(colors: Dictionary) -> ShaderMaterial:
	var key := "hull|%s" % colors.get("outline", "")
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = HULL_SHADER
	m.set_shader_parameter("c_line", _color(colors.get("outline", "#080b13")))
	_materials[key] = m
	return m


## Kantenbreite in Bildpunkten fuer eine Aufloesung (128 Entwurfspunkte =
## ``resolution`` Pixel): halbe Strichbreite 0.45 des SVG.
static func edge_px(resolution: int) -> float:
	return maxf(0.75, 0.45 * float(resolution) / 128.0)


static func _vec(a) -> Vector3:
	if a is Vector3:
		return a
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func _color(hex) -> Color:
	return Color.html(str(hex)) if Color.html_is_valid(str(hex)) else Color.MAGENTA
