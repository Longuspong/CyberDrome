class_name Arena3D
extends Node2D

## Der Kampf als EINE 3D-Szene (18. Nov. 2026, docs/UEBERGABE_3D.md Schritt 4).
##
## Bis dahin hatte jeder DROME eine eigene 3D-Ansicht (SubViewport) und wurde
## als flaches Bild in die 2D-Welt gesetzt. Der Leistungstest auf dem Handy
## des Spielers zeigte: Einzelansichten tragen bis ~12 bewegte DROMEs, eine
## gemeinsame Szene auch 48. Ausserdem verdecken sich DROMEs und Hindernisse
## so richtig -- auch Teile, die ineinander ragen.
##
## Aufbau: eine 3D-Welt mit Hindernissen und allen DROMEs, gesehen von drei
## Kameras (Bild, Signalfarbe je Teil fuer die Kontur, Leuchtroehren). Die
## Kameras laufen mit der Camera2D des Kampfbildschirms mit; das Bild liegt als
## ein Sprite in der 2D-Welt -- ueber Boden, Zone und Bodenringen, unter
## Balken und Effekten. Die Einheiten (Unit) bleiben die Wahrheit fuer Feld,
## Position und Blickrichtung; ihr 3D-Modell folgt ihnen jedes Bild.
##
## Die Umrechnung 2D-Welt -> 3D-Boden ist dieselbe Projektion wie IsoView:
## 1,35 Bildpunkte je Einheit (DromeModel.SCALE), in der Tiefe cos 45.

## Aufloesung der 3D-Bilder relativ zur 2D-Welt (2 = doppelt, wie im
## Leistungstest gemessen).
const OVERSAMPLE := 2.0
const ARENA_DIR := "res://assets/arena3d/%s.m3d"
## Hindernisse schauen mit der Vorderseite zur Kamera (Bild unten).
const OBSTACLE_FACING := "deg270"
## Signalfarbe der Hindernisse: nur der dunkle Strich, kein farbiger Rand.
const OBSTACLE_SIGNAL := Color(0.03, 0.04, 0.07)
## Hindernisse etwas groesser als im Generator -- sie fuellen ihr Feld.
const OBSTACLE_SCALE := 1.25

var world := World3D.new()
var _image: SubViewport
var _signal: SubViewport
var _neon: SubViewport
var _cameras: Array[Camera3D] = []
var _scene: Node3D
var _sprite: Sprite2D
var _glow: NeonGlow
var _outline: ShaderMaterial
## Unit -> Node3D (Wurzel aus DromeModel.build_node)
var _models: Dictionary = {}
var _has_neon := false
## Unit -> Bewegungszustand {"time", "phase", "attack", "tint"}
var _anim: Dictionary = {}

## Bewegung (Schritt 5, 18. Nov. 2026). Laengen in Generator-Einheiten (ein
## DROME ist ~80 hoch), Zeiten in Sekunden.
const IDLE_BOB := 0.5            # Atmen im Stand
const IDLE_SPEED := 2.2
const WALK_BOB := 1.4            # Wippen beim Laufen
const WALK_SPEED := 9.0
const NIMBUS_TILT := 0.13        # Nimbus kippt beim Fahren nach vorn (rad)
const STRIX_HOP := 2.6           # die Eule huepft
const RECOIL := 2.6              # Fernkampf: Rueckstoss
const RANGED_TIME := 0.24
const FLASH_TIME := 0.07         # Muendungsblitz (Waffe leuchtet auf)
const SWING_BACK := -0.55        # Nahkampf: ausholen (rad, um die Schulter)
const SWING_HIT := 0.65          # ... und zuschlagen
const MELEE_TIME := 0.42
const SHIELD_PUSH := 3.2         # Schild stoesst vor
const SHIELD_TIME := 0.3


## Aufbau im Konstruktor, damit die Arena auch ausserhalb des Baums (Tests)
## vollstaendig ist; erst _ready legt die Kameras an die Camera2D.
func _init() -> void:
	z_index = 4000
	z_as_relative = false
	_image = _make_view("Bild3D", DromeModel.LAYER_IMAGE, true)
	_signal = _make_view("Signal3D", DromeModel.LAYER_SIGNAL, false)
	_scene = Node3D.new()
	_scene.name = "Szene"
	_image.add_child(_scene)
	_sprite = Sprite2D.new()
	_sprite.name = "Bild"
	_sprite.centered = false
	_sprite.texture = _image.get_texture()
	_outline = ShaderMaterial.new()
	_outline.shader = DromeSprites.OUTLINE_SHADER
	_outline.set_shader_parameter("line_color", Color(0.03, 0.04, 0.07))
	_outline.set_shader_parameter("signal_tex", _signal.get_texture())
	_outline.set_shader_parameter("use_signal", true)
	_sprite.material = _outline
	add_child(_sprite)


func _ready() -> void:
	_sync_camera()


func _make_view(view_name: String, layer: int, smooth: bool) -> SubViewport:
	var view := SubViewport.new()
	view.name = view_name
	view.transparent_bg = true
	view.world_3d = world
	view.msaa_3d = Viewport.MSAA_4X if smooth else Viewport.MSAA_DISABLED
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := DromeModel.make_camera()
	cam.cull_mask = layer
	view.add_child(cam)
	_cameras.append(cam)
	add_child(view)
	return view


## Leuchtebene erst, wenn ein Neon-Teil mitkaempft.
func _ensure_neon() -> void:
	if _neon != null:
		return
	_neon = _make_view("Neon3D", DromeModel.LAYER_NEON, true)
	_glow = NeonGlow.create_3d(_neon.get_texture(), 256)
	_sprite.add_child(_glow)
	_sync_camera()


# ---------------------------------------------------------------------------
# Umrechnung
# ---------------------------------------------------------------------------

## 2D-Weltpunkt (IsoView-Koordinaten, auf dem Boden) -> 3D-Bodenpunkt.
static func ground(p: Vector2) -> Vector3:
	var c := DromeModel.COS45
	var right := Vector3(c, 0, c)
	var up := Vector3(c, 0, -c)
	return right * (p.x / DromeModel.SCALE) + up * (-p.y / (DromeModel.SCALE * c))


# ---------------------------------------------------------------------------
# Hindernisse
# ---------------------------------------------------------------------------

func build_obstacles(grid: Grid) -> void:
	for child in _scene.get_children():
		if child.has_meta("obstacle"):
			child.queue_free()
	for tile in grid.obstacles:
		var kind := str(grid.obstacles[tile])
		var path := ARENA_DIR % kind
		if not FileAccess.file_exists(path):
			path = ARENA_DIR % "block"
		var model = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not model is Dictionary:
			continue
		DromeModel._edge = DromeModel.edge_px(256)
		var mesh := DromeModel._mesh_for("arena3d|" + kind, model, model.get("colors", {}))
		if mesh == null:
			continue
		var inst := MeshInstance3D.new()
		inst.name = "Hindernis_%d_%d" % [tile.x, tile.y]
		inst.set_meta("obstacle", true)
		inst.mesh = mesh
		inst.layers = DromeModel.LAYER_IMAGE
		inst.position = ground(IsoView.map_to_local(tile))
		inst.basis = DromeModel.facing_basis(OBSTACLE_FACING).scaled(Vector3.ONE * OBSTACLE_SCALE)
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for layer_info in [[DromeModel.LAYER_SIGNAL, OBSTACLE_SIGNAL],
				[DromeModel.LAYER_NEON, Color.BLACK]]:
			var copy := MeshInstance3D.new()
			copy.mesh = mesh
			copy.layers = layer_info[0]
			copy.material_override = DromeModel._flat_material(layer_info[1])
			inst.add_child(copy)
		_scene.add_child(inst)


# ---------------------------------------------------------------------------
# Einheiten
# ---------------------------------------------------------------------------

## Baut das 3D-Modell einer Einheit (neu, z. B. nach einem Umbau).
func rebuild(unit: Unit) -> void:
	forget(unit)
	if unit.build == null or unit.build.body() == null:
		return
	var node := DromeModel.build_node(unit.build, unit.facing, 256, true)
	node.name = "Einheit_%s" % unit.unit_id
	if bool(node.get_meta("neon", false)):
		_has_neon = true
		_ensure_neon()
	_scene.add_child(node)
	_models[unit] = node
	var turn := node.get_node("Ausrichtung") as Node3D
	for block in turn.get_children():
		block.set_meta("base", block.transform)
	var old: Dictionary = _anim.get(unit, {})
	_anim[unit] = {"time": 0.0, "phase": float(hash(str(unit.unit_id)) % 628) / 100.0,
		"attack": {}, "tint": old.get("tint", Color.WHITE)}
	_sync_unit(unit, node)


func forget(unit: Unit) -> void:
	if _models.has(unit):
		var node: Node3D = _models[unit]
		_models.erase(unit)
		_anim.erase(unit)
		node.queue_free()


func model_of(unit: Unit) -> Node3D:
	return _models.get(unit)


## Die Ausrichtung (Blickrichtung) eines Modells -- darunter je Block ein Knoten.
func turn_of(unit: Unit) -> Node3D:
	var node := model_of(unit)
	return node.get_node_or_null("Ausrichtung") as Node3D if node != null else null


func face(unit: Unit) -> void:
	var turn := turn_of(unit)
	if turn != null:
		turn.basis = DromeModel.facing_basis(unit.facing)


## Farbstich (Team, Trefferblende) -- multiplikativ wie modulate.
func tint(unit: Unit, color: Color) -> void:
	var node := model_of(unit)
	if node == null:
		return
	if _anim.has(unit):
		_anim[unit]["tint"] = color
	_tint_tree(node, color)


static func _tint_tree(node: Node, color: Color) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.layers == DromeModel.LAYER_IMAGE:
			child.set_instance_shader_parameter("tint", color)
		_tint_tree(child, color)


func _sync_unit(unit: Unit, node: Node3D) -> void:
	node.visible = unit.visible and unit.is_inside_tree()
	var rig := unit.rig()
	var feet := unit.position + IsoView.SPRITE_ORIGIN
	var factor := 1.0
	if rig != null:
		feet = unit.position + rig.position + IsoView.SPRITE_ORIGIN * rig.scale
		factor = rig.scale.x
	node.position = ground(feet)
	node.scale = Vector3.ONE * factor


# ---------------------------------------------------------------------------
# Bewegung (Schritt 5)
# ---------------------------------------------------------------------------

## Angriff mit der Waffe, die ``action`` ausloest. false, wenn es nichts zu
## bewegen gibt (dann ruckt der ganze DROME wie bisher).
func attack(unit: Unit, action: ActionData) -> bool:
	var turn := turn_of(unit)
	if turn == null or not _anim.has(unit):
		return false
	var slot := _slot_for(unit, action)
	if slot == "" or turn.get_node_or_null(slot) == null:
		return false
	var part: PartData = unit.build.part_in(slot)
	var kind := "shield" if part.tags.has("defense") else part.reach_kind()
	_anim[unit]["attack"] = {"slot": slot, "kind": kind, "t": 0.0,
		"time": {"melee": MELEE_TIME, "shield": SHIELD_TIME}.get(kind, RANGED_TIME)}
	return true


## Der Waffenplatz, dessen Waffe die Aktion mitbringt (sonst der erste).
static func _slot_for(unit: Unit, action: ActionData) -> String:
	var first := ""
	for slot in unit.build.body().equip_slots():
		var part: PartData = unit.build.part_in(slot)
		if part == null:
			continue
		if first == "":
			first = slot
		if action != null:
			for own in part.actions:
				if own.id == action.id:
					return slot
	return first


func _animate(unit: Unit, node: Node3D, delta: float) -> void:
	var state: Dictionary = _anim.get(unit, {})
	var turn := node.get_node_or_null("Ausrichtung") as Node3D
	# Beim Zerfallen gehoeren die Bloecke der Todesanimation.
	if state.is_empty() or turn == null or not unit.is_alive():
		return
	state["time"] += delta
	var t: float = state["time"] + state["phase"]
	var calm := Accessibility.reduce_motion
	var chassis := str(unit.build.body().id)
	var bob := 0.0
	var tilt := 0.0
	var hop := 0.0
	if not calm:
		if unit.is_gliding():
			var wave := absf(sin(t * WALK_SPEED))
			if chassis == "strix_body":
				hop = wave * STRIX_HOP
			else:
				bob = wave * WALK_BOB
			if chassis == "mage_body":
				tilt = NIMBUS_TILT
		else:
			bob = sin(t * IDLE_SPEED) * IDLE_BOB
	turn.basis = DromeModel.facing_basis(unit.facing) * Basis(Vector3(0, 1, 0), tilt)
	node.position.y += hop

	# Angriff: Fortschritt 0..1, danach vorbei.
	var attack: Dictionary = state["attack"]
	var k := -1.0
	if not attack.is_empty():
		attack["t"] += delta
		k = attack["t"] / attack["time"]
		if k >= 1.0:
			state["attack"] = {}
			attack = {}
			k = -1.0
	var slot: String = attack.get("slot", "")
	var kind: String = attack.get("kind", "")
	var pivot := Vector3.ZERO
	var arm := turn.get_node_or_null(slot + "_arm") as Node3D if slot != "" else null
	if arm != null:
		var base_arm: Transform3D = arm.get_meta("base", arm.transform)
		pivot = base_arm.origin + _anchor(arm, "mount")
	elif slot != "":
		var weapon := turn.get_node_or_null(slot) as Node3D
		if weapon != null:
			pivot = (weapon.get_meta("base", weapon.transform) as Transform3D).origin \
				+ _anchor(weapon, "mount")

	for block in turn.get_children():
		if not block is Node3D or not block.has_meta("base"):
			continue
		var tr: Transform3D = block.get_meta("base")
		var bname := str(block.name)
		if bname != "feet":
			tr.origin.z += bob
		if bname == "head":
			tr.origin.z += bob * 0.4
		if k >= 0.0 and (bname == slot or bname == slot + "_arm"):
			tr = _attack_pose(tr, kind, k, pivot)
		block.transform = tr

	# Muendungsblitz: die Waffe leuchtet kurz auf.
	if slot != "" and kind == "ranged":
		var weapon := turn.get_node_or_null(slot)
		if weapon != null:
			var bright: bool = attack["t"] < FLASH_TIME
			var base_tint: Color = state["tint"]
			_tint_tree_self(weapon, base_tint * (2.2 if bright else 1.0))


## Haltung eines Waffenblocks im Angriff (k = 0..1).
static func _attack_pose(tr: Transform3D, kind: String, k: float, pivot: Vector3) -> Transform3D:
	match kind:
		"melee":
			# ausholen (bis 35 %), zuschlagen (bis 60 %), zurueck
			var angle := 0.0
			if k < 0.35:
				angle = lerpf(0.0, SWING_BACK, ease(k / 0.35, 0.5))
			elif k < 0.6:
				angle = lerpf(SWING_BACK, SWING_HIT, ease((k - 0.35) / 0.25, 2.0))
			else:
				angle = lerpf(SWING_HIT, 0.0, ease((k - 0.6) / 0.4, 0.5))
			var turn := Transform3D(Basis(Vector3(0, 1, 0), angle), Vector3.ZERO)
			return Transform3D(Basis.IDENTITY, pivot) * turn \
				* Transform3D(Basis.IDENTITY, -pivot) * tr
		"shield":
			var push := sin(PI * k) * SHIELD_PUSH
			tr.origin.x += push
			return tr
		_:
			var kick := k / 0.2 if k < 0.2 else 1.0 - (k - 0.2) / 0.8
			tr.origin.x -= RECOIL * kick
			return tr


static func _anchor(block: Node3D, name: String) -> Vector3:
	var anchors: Dictionary = block.get_meta("anchors", {})
	var a = anchors.get(name)
	if a == null:
		return Vector3.ZERO
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func _tint_tree_self(node: Node, color: Color) -> void:
	if node is MeshInstance3D and node.layers == DromeModel.LAYER_IMAGE:
		node.set_instance_shader_parameter("tint", color)
	_tint_tree(node, color)


# ---------------------------------------------------------------------------
# Jedes Bild
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	for unit in _models.keys():
		if not is_instance_valid(unit):
			forget(unit)
			continue
		_sync_unit(unit, _models[unit])
		_animate(unit, _models[unit], _delta)
	_sync_camera()


## Kameras und Bild an die Camera2D anlegen: gleicher Ausschnitt, gleicher Zoom.
func _sync_camera() -> void:
	if not is_inside_tree():
		return
	var screen := get_viewport().get_visible_rect().size
	var cam2d := get_viewport().get_camera_2d()
	var center := screen * 0.5
	var zoom := 1.0
	if cam2d != null:
		center = cam2d.get_screen_center_position()
		zoom = cam2d.zoom.x
	# Bis hier globale Koordinaten; die 3D-Welt rechnet in den lokalen der
	# 2D-Welt (IsoView), also in denen dieses Knotens.
	var local_center := to_local(center)
	var world_scale := get_global_transform().get_scale().x
	var px_zoom := zoom * world_scale
	var size := Vector2i(maxi(1, int(screen.x * OVERSAMPLE)), maxi(1, int(screen.y * OVERSAMPLE)))
	for view in [_image, _signal, _neon]:
		if view != null and view.size != size:
			view.size = size
	var half_height := screen.y * 0.5 / px_zoom
	for cam in _cameras:
		cam.size = 2.0 * half_height / DromeModel.SCALE
		var back := cam.basis.z
		cam.position = ground(local_center) + back * 400.0
	# Das Bild deckt genau den sichtbaren Ausschnitt.
	_sprite.position = local_center - screen * 0.5 / px_zoom
	_sprite.scale = Vector2.ONE / (px_zoom * OVERSAMPLE)
	# Strich und Kontur wie beim Einzelbild: 0,45 und 1,6 Entwurfspunkte.
	var px_per_design := px_zoom * OVERSAMPLE
	_outline.set_shader_parameter("line_px", 0.45 * px_per_design)
	_outline.set_shader_parameter("rim_px", 1.6 * px_per_design)
	if _glow != null:
		(_glow.material as ShaderMaterial).set_shader_parameter("halo_px", 1.3 * px_per_design)
