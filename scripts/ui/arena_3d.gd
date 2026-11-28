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
## Geschosse im Flug (21. Nov. 2026, add_shot).
var _shots: Array = []
## Lichtflecken der Laternen ([Vector2, Color, Radius] wie ArenaPainter.Lights)
## fuer das vorgetaeuschte Licht auf den DROMEs (21. Nov. 2026).
var light_spots: Array = []
## Muendungsblitze, die kurz die Nachbarn aufhellen: {"at", "t"}.
var _flashes: Array = []
## Teilchen (ParticleFx im Kampfbild) -- fuer den Staub beim Auftreten.
var fx = null
## Mitte des sichtbaren Ausschnitts (2D-Welt), fuer die Wahl der Lichter.
var _view_center := Vector2.ZERO
var _real_on := false
var _cinema_floor := false

## Bewegung (Schritt 5, 18. Nov. 2026). Laengen in Generator-Einheiten (ein
## DROME ist ~80 hoch), Zeiten in Sekunden.
const IDLE_BOB := 0.5            # Atmen im Stand
const IDLE_SPEED := 2.2
const WALK_BOB := 1.4            # Wippen beim Laufen
const WALK_SPEED := 9.0
## Ab diesem Tempo der Figur (Bildpunkte/s) gilt sie als laufend.
const WALK_MIN_SPEED := 10.0
## Ab diesem Tempo schaut sie in Laufrichtung (sonst wie die Logik sagt).
const TURN_WALK_SPEED := 22.0
## Waehrend eines Angriffs dreht sie so viel schneller zum Ziel.
const ATTACK_TURN_BOOST := 5.0
const STOMP_BOB := 1.9           # Molok setzt tiefer auf
const GLIDE_BOB := 0.8           # Nimbus schwebt beim Fahren
const GLIDE_SPEED := 2.6
## Neigung weich nachziehen (Zeitkonstante, s) und begrenzen (rad).
const LEAN_TIME := 0.08
const LEAN_MAX := 0.3
const LEAN_BACK_MAX := 0.22
const ROLL_MAX := 0.26
## Vorgetaeuschtes Licht (B6 Stufe 1): Staerke der Laternen und Blitze,
## Reichweite der Laternen als Vielfaches ihres Lichtflecks.
const LIGHT_GAIN := 0.26
const LIGHT_REACH := 1.5
const FLASH_GAIN := 0.55
const FLASH_LIGHT_TIME := 0.12
const FLASH_REACH := 2.0         # in Feldbreiten
const FLASH_COLOR := Color(1.0, 0.86, 0.6)
## Echtes Licht (B6 Stufe 2, Option "Echtes Licht"): bis zu acht Punktlichter
## je Bild fuer den Flaechen-Shader (globale Werte arena_light_*). Hoehe der
## Laternen und Reichweiten in Welteinheiten (ein DROME ist ~60 hoch).
const REAL_LIGHTS := 8
const REAL_FLASHES := 3
const LAMP_HEIGHT := 52.0
const LAMP_REACH := 1.25         # mal Lichtfleck-Radius (Bildpunkte -> Welt)
const LAMP_ENERGY := 0.6
const FLASH_REACH_3D := 95.0
const FLASH_ENERGY := 1.5
## Kamera-Szenen (C10): eigene Ebene fuer den Boden, den nur die Szenen-Kamera
## sieht (der Kampf zeichnet seinen Boden einmal als Bild, ArenaFloor3D).
const LAYER_CINEMA_FLOOR := 8
const STRIX_HOP := 2.6           # die Eule huepft
const RECOIL := 2.6              # Fernkampf: Rueckstoss
const RANGED_TIME := 0.24
const FLASH_TIME := 0.09         # Muendungsblitz (Waffe leuchtet auf)
const SWING_BACK := -0.55        # Nahkampf: ausholen (rad, um die Schulter)
const SWING_HIT := 0.65          # ... und zuschlagen
const MELEE_TIME := 0.42
## Anteil der Nahkampfbewegung, an dem der Schlag sitzt (Ende des Zuschlagens)
## -- damit BattleScreen das Ausholen auf die Ausholzeit takten kann.
const MELEE_HIT_AT := 0.6
## Waffe hochhalten (Runenstab): Winkel um die Schulter, Anteil Heben/Senken.
const RAISE_ANGLE := -1.15
const RAISE_UP := 0.35
const RAISE_DOWN := 0.25
## Wurf (Runenstab-Faehigkeit): hoch, halten, schneller Schwung nach
## vorn-unten bis ueber die Ruhelage hinaus, zurueck. Die Kugel loest sich in
## der Mitte des Schwungs (THROW_RELEASE, Anteil).
const THROW_UP := 0.32
const THROW_HOLD := 0.42
const THROW_SWING := 0.58
const THROW_RELEASE := 0.5
const THROW_FOLLOW := 0.5        # rad ueber die Ruhelage nach vorn-unten
const SHIELD_PUSH := 3.2         # Schild stoesst vor
const SHIELD_TIME := 0.3
## Ausholen auch von vorn lesbar: die Schwungachse kippt zur Seite.
const SWING_AXIS := Vector3(0, 1, 0.5)
const RECOIL_LIFT := 0.9         # Rueckstoss hebt die Waffe leicht
const HIT_TILT := 0.16           # Treffer: der DROME kippt kurz nach hinten
const HIT_TIME := 0.28
## Sichtbare Passiven (DROME_DESIGNREGELN Abschnitt 6).
const ORB_FLOAT := 1.6           # Nimbus-Kugel schwebt
const ORB_SPEED := 1.8
const BLINK_EVERY := 3.6         # Strix-Linsen blinzeln
const BLINK_TIME := 0.14
const FLASH_SIZE := 3.6          # Muendungsblitz (Radius, Generator-Einheiten)
## Beine im Wechsel (18. Nov. 2026): Schwung um die Huefte (rad) und Beugen
## des Knies, solange das Bein nach vorn schwingt. Knie-Richtung -1 = Knie
## nach hinten (Strix).
const LEG_SWING := {"scout_body": 0.38, "jugg_body": 0.24, "strix_body": 0.3}
const KNEE_BEND := {"scout_body": 0.7, "jugg_body": 0.45, "strix_body": -0.45}


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


## Umkehrung fuer beliebige 3D-Punkte (auch ueber dem Boden): wo die
## Iso-Kamera sie in der 2D-Welt zeigt.
static func to_world_2d(g: Vector3) -> Vector2:
	var c := DromeModel.COS45
	return Vector2(g.dot(Vector3(c, 0, c)), -g.dot(Vector3(0.5, c, -0.5))) * DromeModel.SCALE


## Die Spitze der Waffe einer Einheit (``muzzle``-Anker), so wie sie gerade
## steht -- auch mitten in einer Bewegung (Stab hochgehalten). In der 2D-Welt.
func weapon_tip(unit: Unit, action: ActionData) -> Vector2:
	var turn := turn_of(unit)
	var fallback := unit.visual_anchor() + Vector2(0, -90)
	if turn == null or not turn.is_inside_tree():
		return fallback
	var weapon := turn.get_node_or_null(_slot_for(unit, action)) as Node3D
	if weapon == null:
		return fallback
	return to_world_2d(weapon.global_transform * _anchor(weapon, "muzzle"))


# ---------------------------------------------------------------------------
# Hindernisse
# ---------------------------------------------------------------------------

func build_obstacles(grid: Grid) -> void:
	_clear_meta("obstacle")
	for tile in grid.obstacles:
		_place_model(str(grid.obstacles[tile]), tile, "obstacle")


## Deko am Rand (18. Nov. 2026): Laternen in den Lichtfarben der Region,
## dazu Kiosk, Schuessel, Haltestelle ... bzw. die Hindernisarten der Region.
## Dieselben Plaetze wie die gezeichnete Deko (ArenaPainter.prop_spots).
func build_props(grid: Grid) -> void:
	_clear_meta("prop")
	var region_id := str(grid.region.id) if grid.region != null else "city"
	var spots := ArenaPainter.prop_spots(grid)
	for index in spots.size():
		var tile: Vector2i = spots[index][0]
		var kind := ArenaPainter.deco_kind(region_id, tile)
		if spots[index][1] == "lamp":
			kind = "lamp_%s_%s" % [region_id, "a" if index % 2 == 0 else "b"]
		_place_model(kind, tile, "prop")


func _clear_meta(tag: String) -> void:
	for child in _scene.get_children():
		if child.has_meta(tag):
			child.queue_free()


## Ein Modell aus assets/arena3d auf ein Feld stellen (Vorderseite zur
## Kamera), mit dunklem Rand in der Signal- und Verdecker in der Leuchtebene.
func _place_model(kind: String, tile: Vector2i, tag: String) -> void:
	var path := ARENA_DIR % kind
	if not FileAccess.file_exists(path):
		kind = "block"
		path = ARENA_DIR % kind
	var model = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not model is Dictionary:
		return
	DromeModel._edge = DromeModel.edge_px(256)
	var mesh := DromeModel._mesh_for("arena3d|" + kind, model, model.get("colors", {}))
	if mesh == null:
		return
	var inst := DromeModel.mesh_instance(mesh)
	inst.name = "%s_%d_%d" % [tag, tile.x, tile.y]
	inst.set_meta(tag, true)
	inst.position = ground(IsoView.map_to_local(tile))
	inst.basis = DromeModel.facing_basis(OBSTACLE_FACING).scaled(Vector3.ONE * OBSTACLE_SCALE)
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
		_tint_mesh(child, color)
		_tint_tree(child, color)


## Farbstich auf eigenen Materialkopien des Blocks (die Materialien der
## Meshes teilen sich alle DROMEs). Nur Flaechen-Materialien (mit ``tint``).
static func _tint_mesh(node: Node, color: Color) -> void:
	if not node is MeshInstance3D or node.layers != DromeModel.LAYER_IMAGE:
		return
	var inst := node as MeshInstance3D
	if inst.mesh == null:
		return
	for i in inst.mesh.get_surface_count():
		var own := inst.get_surface_override_material(i) as ShaderMaterial
		if own == null:
			var shared := inst.mesh.surface_get_material(i) as ShaderMaterial
			if shared == null or shared.shader != DromeModel.FACE_SHADER:
				continue
			own = shared.duplicate() as ShaderMaterial
			inst.set_surface_override_material(i, own)
		own.set_shader_parameter("tint", color)


## Wie gross die DROMEs im Verhaeltnis zum Feld sind (18. Nov. 2026,
## Spieler: "die DROMEs sind zu gross fuer die Sechsecke").
## data/config.json -> figures.scale.
static func figure_scale() -> float:
	return float(Config.section("figures").get("scale", 1.0))


func _sync_unit(unit: Unit, node: Node3D) -> void:
	node.visible = unit.visible and unit.is_inside_tree()
	var rig := unit.rig()
	var feet := unit.position + IsoView.SPRITE_ORIGIN
	var factor := figure_scale()
	if rig != null:
		feet = unit.position + rig.position + IsoView.SPRITE_ORIGIN * rig.scale
		factor *= rig.scale.x
	node.position = ground(feet)
	node.scale = Vector3.ONE * factor


# ---------------------------------------------------------------------------
# Bewegung (Schritt 5)
# ---------------------------------------------------------------------------

## Angriff mit der Waffe, die ``action`` ausloest. false, wenn es nichts zu
## bewegen gibt (dann ruckt der ganze DROME wie bisher).
func attack(unit: Unit, action: ActionData, seconds: float = -1.0) -> bool:
	var turn := turn_of(unit)
	if turn == null or not _anim.has(unit):
		return false
	var slot := _slot_for(unit, action)
	if slot == "" or turn.get_node_or_null(slot) == null:
		return false
	var part: PartData = unit.build.part_in(slot)
	var kind := "shield" if part.tags.has("defense") else part.reach_kind()
	var time: float = {"melee": MELEE_TIME, "shield": SHIELD_TIME}.get(kind, RANGED_TIME)
	if seconds > 0.0:
		time = seconds
	_anim[unit]["attack"] = {"slot": slot, "kind": kind, "t": 0.0, "time": time}
	if kind == "ranged":
		_flashes.append({"unit": unit, "at": unit.visual_anchor() + Vector2(0, -18),
			"foot": unit.visual_anchor(), "t": 0.0})
	return true


## Ein Wurf: hoch, halten, Schwung nach vorn-unten (``seconds`` insgesamt).
func throw(unit: Unit, action: ActionData, seconds: float) -> bool:
	if not raise(unit, action, seconds):
		return false
	_anim[unit]["attack"]["kind"] = "throw"
	return true


## Die Waffe hochhalten: Arm und Waffe drehen um die Schulter nach oben,
## halten, und senken sich am Ende (``seconds`` insgesamt).
func raise(unit: Unit, action: ActionData, seconds: float) -> bool:
	var turn := turn_of(unit)
	if turn == null or not _anim.has(unit):
		return false
	var slot := _slot_for(unit, action)
	if slot == "" or turn.get_node_or_null(slot) == null:
		return false
	_anim[unit]["attack"] = {"slot": slot, "kind": "raise", "t": 0.0, "time": maxf(0.1, seconds)}
	return true


## Der Waffenplatz, dessen Waffe die Aktion mitbringt (sonst der erste).
static func _slot_for(unit: Unit, action: ActionData) -> String:
	# Gunship (Molok): der Arm, der gerade feuert -- die Arme wechseln sich ab.
	if action != null and unit.firing_slot != "" \
			and unit.build.mirror_slots().has(unit.firing_slot):
		var twin: PartData = unit.build.part_in(unit.firing_slot)
		if twin != null:
			for own in twin.actions:
				if own.id == action.id:
					return unit.firing_slot
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
		if turn != null and state.has("attack") and not state["attack"].is_empty():
			var weapon := turn.get_node_or_null(str(state["attack"].get("slot", "")))
			if weapon != null and weapon.get_node_or_null("Blitz") != null:
				weapon.get_node("Blitz").queue_free()
			state["attack"] = {}
		return
	state["time"] += delta
	var t: float = state["time"] + state["phase"]
	var calm := Accessibility.reduce_motion
	var chassis := str(unit.build.body().id)
	# Bewegung aus der gezeichneten Figur (Feder in Unit, 21. Nov. 2026):
	# Tempo, Beschleunigung, Schrittlaenge.
	var vel := unit.visual_velocity()
	var speed := vel.length()
	var ref_speed := float(Config.section("motion").get("ref_speed", 80.0))
	var walking := speed > WALK_MIN_SPEED
	var cadence := clampf(speed / ref_speed, 0.55, 1.7)
	if walking:
		state["walk"] = float(state.get("walk", 0.0)) + delta * WALK_SPEED * cadence
	var stride: float = float(state.get("walk", 0.0)) + float(state["phase"]) * WALK_SPEED
	var bob := 0.0
	var tilt := 0.0
	var hop := 0.0
	if not calm:
		if walking:
			# Mit Beinen ist der Rumpf oben, wenn ein Bein senkrecht steht.
			var wave := absf(cos(stride)) if LEG_SWING.has(chassis) \
				else absf(sin(stride))
			match chassis:
				"strix_body":
					hop = wave * STRIX_HOP
				"jugg_body":
					# Molok stampft: tief und hart aufsetzen, Staub beim Auftritt.
					bob = pow(wave, 3.0) * WALK_BOB * STOMP_BOB
					var sign_now := cos(stride) >= 0.0
					if state.has("foot") and bool(state["foot"]) != sign_now:
						_footfall(unit)
					state["foot"] = sign_now
				"mage_body":
					# Nimbus gleitet: kein Schritt, nur ein weiches Schweben.
					bob = sin(t * GLIDE_SPEED) * GLIDE_BOB
				_:
					bob = wave * WALK_BOB
		else:
			bob = sin(t * IDLE_SPEED) * IDLE_BOB
	# Treffer: kurz nach hinten kippen.
	if state.has("hit"):
		state["hit"] += delta
		var h: float = state["hit"] / HIT_TIME
		if h >= 1.0:
			state.erase("hit")
		elif not calm:
			tilt -= HIT_TILT * sin(PI * h)
	var yaw := _turn_toward(unit, state, vel, delta, calm)
	var lean := _lean(unit, state, yaw, delta, calm)
	turn.basis = DromeModel.angle_basis(yaw) * Basis(Vector3(0, 1, 0), tilt + lean.x) \
		* Basis(Vector3(1, 0, 0), lean.y)
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
		if bname.begins_with("feet_leg_"):
			if walking:
				block.transform = _leg_pose(turn, block, chassis, stride / WALK_SPEED, bname)
			else:
				block.transform = tr
			continue
		if bname != "feet":
			tr.origin.z += bob
		if bname == "head":
			tr.origin.z += bob * 0.4
		if bname == "body_passive" and not calm:
			tr.origin.z += sin(t * ORB_SPEED) * ORB_FLOAT
			tr.origin.y += sin(t * ORB_SPEED * 0.6) * ORB_FLOAT * 0.4
		if k >= 0.0 and (bname == slot or bname == slot + "_arm"):
			tr = _attack_pose(tr, kind, k, pivot)
		block.transform = tr

	# Muendungsblitz: an der Waffenspitze ein Lichtball, die Waffe leuchtet auf.
	if slot != "" and kind == "ranged":
		var weapon := turn.get_node_or_null(slot) as Node3D
		if weapon != null:
			var bright: bool = attack["t"] < FLASH_TIME
			var base_tint: Color = state["tint"]
			_tint_tree_self(weapon, base_tint * (1.6 if bright else 1.0))
			_muzzle_flash(weapon, attack, bright)
	elif state.has("flash"):
		_clear_flash(state)
	_passive_glow(unit, turn, state, t, calm)


## Drehen statt Springen (A3, 21. Nov. 2026): die Blickrichtung zieht weich
## nach (Zeitkonstante motion.turn_time, Hoechsttempo je Chassis). Beim
## Laufen schaut die Figur in ihre Laufrichtung, beim Zielen genau auf das
## Ziel (unit.facing). Rueckgabe: Winkel in Grad (DromeModel.angle_basis).
func _turn_toward(unit: Unit, state: Dictionary, vel: Vector2, delta: float, calm: bool) -> float:
	var target := Arena3D.facing_degrees(unit.facing)
	if vel.length() > TURN_WALK_SPEED and unit.aim_hold <= 0.0 and unit.cast.is_empty():
		target = rad_to_deg(atan2(-vel.y / IsoView.DEPTH_SQUASH, vel.x))
	if calm or not state.has("yaw"):
		state["yaw"] = target
		return target
	var yaw: float = state["yaw"]
	var diff := wrapf(target - yaw, -180.0, 180.0)
	var chassis := str(unit.build.body().id)
	var turn_time := maxf(0.005, float(Config.section("motion").get("turn_time", 0.045)))
	var limit := rad_to_deg(Unit.motion_for("turn_rate", chassis, 12.0)) * delta
	# Beim Angriff schnell herumreissen (24. Nov. 2026): die Waffe feuert bzw.
	# schlaegt sofort -- mit dem normalen Drehtempo (Molok bis 0,4 s fuer eine
	# halbe Drehung) zeigte sie dabei noch zur Seite oder nach hinten.
	if not (state.get("attack", {}) as Dictionary).is_empty():
		limit *= ATTACK_TURN_BOOST
		turn_time /= ATTACK_TURN_BOOST
	var step := diff * (1.0 - exp(-delta / turn_time))
	yaw += clampf(step, -limit, limit)
	state["yaw"] = wrapf(yaw, 0.0, 360.0)
	return float(state["yaw"])


## Blickrichtung als Winkel in Grad -- "deg<grad>" oder die alten Namen.
static func facing_degrees(facing: String) -> float:
	if facing.begins_with("deg"):
		return float(facing.substr(3))
	return float({"south": 225.0, "east": 315.0, "north": 45.0, "west": 135.0}.get(facing, 225.0))


## Koerpersprache (A4): nach vorn lehnen je Tempo und Anlauf, zurueck beim
## Bremsen, in Kurven zur Innenseite kippen. Rueckgabe (Nicken, Rollen) in rad.
func _lean(unit: Unit, state: Dictionary, yaw: float, delta: float, calm: bool) -> Vector2:
	if calm:
		return Vector2.ZERO
	var motion := Config.section("motion")
	var ref_speed := float(motion.get("ref_speed", 80.0))
	var ref_acc := float(motion.get("ref_acc", 420.0))
	var chassis := str(unit.build.body().id)
	var squash := IsoView.DEPTH_SQUASH
	var vel := unit.visual_velocity()
	var acc := unit.visual_accel()
	var vg := Vector2(vel.x, vel.y / squash)
	var ag := Vector2(acc.x, acc.y / squash)
	var a := deg_to_rad(yaw)
	var ahead := Vector2(cos(a), -sin(a))
	var left := Vector2(-sin(a), -cos(a))
	var pitch := Unit.motion_for("lean", chassis, 0.1) * vg.dot(ahead) / ref_speed \
		+ Unit.motion_for("lean_acc", chassis, 0.1) * ag.dot(ahead) / ref_acc
	var roll := -Unit.motion_for("roll", chassis, 0.1) * ag.dot(left) / ref_acc
	var target := Vector2(clampf(pitch, -LEAN_BACK_MAX, LEAN_MAX), clampf(roll, -ROLL_MAX, ROLL_MAX))
	var now: Vector2 = state.get("lean", Vector2.ZERO)
	now = now.lerp(target, 1.0 - exp(-delta / LEAN_TIME))
	state["lean"] = now
	return now


## Molok tritt auf: ein Staubwoelkchen am Fuss (B7-Teilchen).
func _footfall(unit: Unit) -> void:
	if fx != null and is_instance_valid(fx):
		fx.dust(unit.visual_anchor())


## Ausweichen beim Vorbeilaufen (A5): wer steht, rueckt ein Stueck von einem
## nahen Laeufer weg -- nur im Bild (Unit.nudge), das Feld bleibt.
func _update_nudges() -> void:
	var motion := Config.section("motion")
	var share := float(motion.get("nudge", 0.0))
	var reach := float(motion.get("nudge_reach", 0.95)) * IsoView.TILE_W
	var units: Array = []
	for unit in _models.keys():
		if is_instance_valid(unit) and unit.is_alive() and unit.is_inside_tree():
			units.append(unit)
	var push: Dictionary = {}
	for unit in units:
		push[unit] = Vector2.ZERO
	if share > 0.0 and not Accessibility.reduce_motion:
		for i in units.size():
			var a: Unit = units[i]
			var a_moves := a.visual_velocity().length() > TURN_WALK_SPEED
			for j in range(i + 1, units.size()):
				var b: Unit = units[j]
				var b_moves := b.visual_velocity().length() > TURN_WALK_SPEED
				if a_moves == b_moves:
					continue
				var d := a.visual_anchor() - b.visual_anchor()
				var ground_d := Vector2(d.x, d.y / IsoView.DEPTH_SQUASH)
				var dist := ground_d.length()
				if dist >= reach or dist < 0.01:
					continue
				var away := ground_d / dist * (1.0 - dist / reach)
				if not a_moves:
					push[a] += away
				else:
					push[b] -= away
	for unit in units:
		var p: Vector2 = (push[unit] as Vector2).limit_length(1.0) * share * IsoView.TILE_W
		unit.nudge = Vector2(p.x, p.y * IsoView.DEPTH_SQUASH)


## Vorgetaeuschtes Licht (B6 Stufe 1): Farbe der Laternen in der Naehe und
## kurzer Muendungsblitze, als Zusatzfarbe auf die Flaechen der Einheit.
func _apply_light(unit: Unit, node: Node3D, state: Dictionary) -> void:
	var at := unit.visual_anchor()
	var sum := Vector3.ZERO
	var dir := Vector3.ZERO
	var here := ground(at)
	# Mit echtem Licht (Stufe 2) uebernimmt der Shader -- hier nichts dazu.
	var spots: Array = [] if Accessibility.real_light else light_spots
	var flashes: Array = [] if Accessibility.real_light else _flashes
	for spot in spots:
		var radius := float(spot[2]) * LIGHT_REACH
		var d: Vector2 = (spot[0] as Vector2) - at
		var dist := Vector2(d.x, d.y / IsoView.DEPTH_SQUASH).length()
		if dist >= radius:
			continue
		var w := pow(1.0 - dist / radius, 2.0) * LIGHT_GAIN
		var c: Color = spot[1]
		sum += Vector3(c.r, c.g, c.b) * w
		dir += (ground(spot[0]) - here).normalized() * w
	for flash in flashes:
		if flash["unit"] == unit:
			continue
		var reach := FLASH_REACH * IsoView.TILE_W
		var d: Vector2 = (flash["at"] as Vector2) - at
		var dist := Vector2(d.x, d.y / IsoView.DEPTH_SQUASH).length()
		if dist >= reach:
			continue
		var w := (1.0 - dist / reach) * FLASH_GAIN * (1.0 - float(flash["t"]) / FLASH_LIGHT_TIME)
		sum += Vector3(FLASH_COLOR.r, FLASH_COLOR.g, FLASH_COLOR.b) * w
		dir += (ground(flash["at"]) - here).normalized() * w
	var last: Vector3 = state.get("glow", Vector3(-1, -1, -1))
	if last.distance_to(sum) < 0.012:
		return
	state["glow"] = sum
	var direction := (dir.normalized() + Vector3.UP * 0.35).normalized() if dir.length() > 0.0001 \
		else Vector3.UP
	if not state.has("face_mats"):
		state["face_mats"] = _collect_faces(node, state.get("tint", Color.WHITE))
	for mat in state["face_mats"]:
		(mat as ShaderMaterial).set_shader_parameter("glow_in", sum)
		(mat as ShaderMaterial).set_shader_parameter("glow_dir", direction)


## Echtes Licht (B6 Stufe 2): Muendungsblitze zuerst, dann die Laternen, die
## dem sichtbaren Ausschnitt am naechsten sind -- hoechstens REAL_LIGHTS.
func _update_real_light() -> void:
	if not Accessibility.real_light:
		if _real_on:
			Arena3D.clear_real_light()
			_real_on = false
		return
	_real_on = true
	var lights: Array = real_lights()
	RenderingServer.global_shader_parameter_set("arena_light_count", lights.size())
	for i in lights.size():
		RenderingServer.global_shader_parameter_set("arena_light_pos_%d" % i, lights[i][0])
		RenderingServer.global_shader_parameter_set("arena_light_col_%d" % i, lights[i][1])


## Die Lichter dieses Bildes: [Vector4 (Weltpunkt, Reichweite), Vector4 Farbe].
func real_lights() -> Array:
	var out: Array = []
	var flashes := _flashes.duplicate()
	flashes.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	for flash in flashes:
		if out.size() >= REAL_FLASHES:
			break
		var k := 1.0 - float(flash["t"]) / FLASH_LIGHT_TIME
		var p := ground(flash.get("foot", flash["at"])) + Vector3.UP * 30.0
		out.append([Vector4(p.x, p.y, p.z, FLASH_REACH_3D),
			Vector4(FLASH_COLOR.r, FLASH_COLOR.g, FLASH_COLOR.b, 1.0) * FLASH_ENERGY * k])
	var lamps: Array = []
	for spot in light_spots:
		if float(spot[2]) < 80.0:
			continue
		lamps.append(spot)
	var center := _view_center
	lamps.sort_custom(func(a, b): return (a[0] as Vector2).distance_squared_to(center) \
		< (b[0] as Vector2).distance_squared_to(center))
	for spot in lamps:
		if out.size() >= REAL_LIGHTS:
			break
		var p := ground(spot[0]) + Vector3.UP * LAMP_HEIGHT
		var reach := float(spot[2]) * LAMP_REACH / DromeModel.SCALE * 2.0
		var c: Color = spot[1]
		out.append([Vector4(p.x, p.y, p.z, reach), Vector4(c.r, c.g, c.b, 1.0) * LAMP_ENERGY])
	return out


static func clear_real_light() -> void:
	RenderingServer.global_shader_parameter_set("arena_light_count", 0)


func _exit_tree() -> void:
	if _real_on:
		Arena3D.clear_real_light()
		_real_on = false


# ---------------------------------------------------------------------------
# Kamera-Szenen (C10, 21. Nov. 2026)
# ---------------------------------------------------------------------------

## Den Boden des Feldes einmal in die Szene legen -- nur fuer die Kamera der
## Szenen sichtbar (Ebene LAYER_CINEMA_FLOOR). Im Kampf bleibt der Boden ein
## einmal gerendertes Bild (ArenaFloor3D).
func build_cinema_floor(grid: Grid) -> void:
	if _cinema_floor or grid == null:
		return
	_cinema_floor = true
	var region_id := str(grid.region.id) if grid.region != null else "city"
	var table := ArenaFloor3D.weights(region_id)
	var basis := DromeModel.facing_basis("deg60")
	DromeModel._edge = DromeModel.edge_px(256)
	var apron := ArenaFloor3D.APRON
	for y in range(-apron, grid.height + apron):
		for x in range(-apron, grid.width + apron):
			var tile := Vector2i(x, y)
			var sort := ArenaFloor3D.sort_for(grid, tile, region_id, table)
			var model := ArenaFloor3D._model(region_id, sort)
			if model.is_empty():
				continue
			var mesh := DromeModel._mesh_for("floor|%s|%s" % [region_id, sort], model,
				model.get("colors", {}))
			if mesh == null:
				continue
			var inst := DromeModel.mesh_instance(mesh)
			inst.layers = LAYER_CINEMA_FLOOR
			inst.set_meta("cinema_floor", true)
			inst.position = ground(IsoView.map_to_local(tile))
			inst.basis = basis
			_scene.add_child(inst)


## Alle Flaechen-Materialien einer Einheit als eigene Kopien (wie beim
## Farbstich), einmal gesammelt.
static func _collect_faces(node: Node, color: Color) -> Array:
	_tint_tree(node, color)
	var out: Array = []
	var stack: Array = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		stack.append_array(current.get_children())
		if not current is MeshInstance3D or (current as MeshInstance3D).layers != DromeModel.LAYER_IMAGE:
			continue
		var inst := current as MeshInstance3D
		if inst.mesh == null:
			continue
		for i in inst.mesh.get_surface_count():
			var own := inst.get_surface_override_material(i) as ShaderMaterial
			if own != null and own.shader == DromeModel.FACE_SHADER:
				out.append(own)
	return out


## Ein Bein im Schritt: der Oberschenkel schwingt um die Huefte, das linke
## gegen das rechte; der Unterschenkel beugt sich zusaetzlich um das Knie,
## solange das Bein nach vorn schwingt (Fuss hebt ab).
func _leg_pose(turn: Node3D, block: Node3D, chassis: String, t: float,
		bname: String) -> Transform3D:
	var base: Transform3D = block.get_meta("base")
	var left := bname.begins_with("feet_leg_left")
	var side := "feet_leg_left" if left else "feet_leg_right"
	var upper := turn.get_node_or_null(side + "_upper") as Node3D
	if upper == null:
		return base
	var origin: Vector3 = (upper.get_meta("base") as Transform3D).origin
	var hip := origin + _anchor(upper, "mount")
	var knee := origin + _anchor(upper, "knee")
	var w := t * WALK_SPEED + (0.0 if left else PI)
	# Basis um +y: positiver Winkel schiebt den Fuss nach hinten.
	var swing := -float(LEG_SWING.get(chassis, 0.0)) * sin(w)
	var hip_tr := _turn_about(hip, swing)
	if bname.ends_with("_upper"):
		return hip_tr * base
	var bend := float(KNEE_BEND.get(chassis, 0.0)) * maxf(0.0, cos(w))
	return hip_tr * _turn_about(knee, bend) * base


static func _turn_about(pivot: Vector3, angle: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, pivot) \
		* Transform3D(Basis(Vector3(0, 1, 0), angle), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -pivot)


## Der Lichtball an der Muendung (``muzzle``-Anker der Waffe): waechst kurz
## auf und verschwindet. In der Bild- und der Leuchtebene.
func _muzzle_flash(weapon: Node3D, attack: Dictionary, bright: bool) -> void:
	var flash := weapon.get_node_or_null("Blitz") as Node3D
	if not bright:
		if flash != null:
			flash.queue_free()
		return
	if flash == null:
		var color := Color(1.0, 0.95, 0.75)
		var mesh := SphereMesh.new()
		mesh.radius = FLASH_SIZE
		mesh.height = FLASH_SIZE * 2.0
		mesh.radial_segments = 10
		mesh.rings = 5
		flash = Node3D.new()
		flash.name = "Blitz"
		flash.position = _anchor(weapon, "muzzle")
		for layer_info in [[DromeModel.LAYER_IMAGE, color], [DromeModel.LAYER_NEON, color],
				[DromeModel.LAYER_SIGNAL, color]]:
			var ball := MeshInstance3D.new()
			ball.mesh = mesh
			ball.layers = layer_info[0]
			ball.material_override = DromeModel._flat_material(layer_info[1])
			ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			flash.add_child(ball)
		weapon.add_child(flash)
	var grow: float = clampf(attack["t"] / FLASH_TIME, 0.0, 1.0)
	flash.scale = Vector3.ONE * lerpf(0.6, 1.3, grow)


func _clear_flash(state: Dictionary) -> void:
	state.erase("flash")


## Leuchtteile der Passiven: Vireo-Booster flackern (beim Laufen staerker,
## je Cyberspeed-Stapel heller),
## Molok-Leitungen pulsieren, Nimbus-Kugel glimmt, Strix-Linsen blinzeln.
## Ueber die Materialkopien der Einheit (Farbstich je Flaeche).
func _passive_glow(unit: Unit, turn: Node3D, state: Dictionary, t: float, calm: bool) -> void:
	if calm:
		return
	if not state.has("glow_mats"):
		state["glow_mats"] = _collect_glow(turn)
	var mats: Array = state["glow_mats"]
	if mats.is_empty():
		return
	var chassis := str(unit.build.body().id)
	var factor := 1.0
	match chassis:
		"scout_body":
			var strength := 1.0 if unit.visual_velocity().length() > WALK_MIN_SPEED else 0.45
			# Cyberspeed: je Stapel leuchten die Booster heller.
			factor = 1.0 + 0.25 * float(unit.cyberspeed_stacks) \
				+ strength * (0.3 * sin(t * 23.0) + 0.2 * sin(t * 37.0 + 1.3))
		"jugg_body":
			factor = 1.0 + 0.35 * sin(t * 3.0)
		"mage_body":
			factor = 1.0 + 0.3 * sin(t * ORB_SPEED * 2.0)
		"strix_body":
			factor = 0.2 if fmod(t, BLINK_EVERY) < BLINK_TIME else 1.0
	var base: Color = state["tint"]
	for entry in mats:
		var mat: ShaderMaterial = entry
		mat.set_shader_parameter("tint", Color(base.r * factor, base.g * factor, base.b * factor))


## Die Leuchtflaechen (glow, bei der Strix auch die Linsen) von Rumpf, Kopf
## und Passive -- als eigene Materialkopien.
static func _collect_glow(turn: Node3D) -> Array:
	var out: Array = []
	for bname in ["body", "head", "body_passive"]:
		var inst := turn.get_node_or_null(bname) as MeshInstance3D
		if inst == null or inst.mesh == null:
			continue
		for i in inst.mesh.get_surface_count():
			var sname := str(inst.mesh.surface_get_name(i))
			if sname != "glow" and not (sname == "visor" and bname == "head"):
				continue
			var own := inst.get_surface_override_material(i) as ShaderMaterial
			if own == null:
				var shared := inst.mesh.surface_get_material(i) as ShaderMaterial
				if shared == null:
					continue
				own = shared.duplicate() as ShaderMaterial
				inst.set_surface_override_material(i, own)
			out.append(own)
	return out


## Treffer: der DROME kippt kurz nach hinten (zusaetzlich zum Zucken).
func hit(unit: Unit) -> void:
	if _anim.has(unit):
		_anim[unit]["hit"] = 0.0


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
			var turn := Transform3D(Basis(SWING_AXIS.normalized(), angle), Vector3.ZERO)
			return Transform3D(Basis.IDENTITY, pivot) * turn \
				* Transform3D(Basis.IDENTITY, -pivot) * tr
		"throw":
			var angle := RAISE_ANGLE
			if k < THROW_UP:
				angle = RAISE_ANGLE * ease(k / THROW_UP, 0.4)
			elif k < THROW_HOLD:
				angle = RAISE_ANGLE
			elif k < THROW_SWING:
				angle = lerpf(RAISE_ANGLE, THROW_FOLLOW, ease((k - THROW_HOLD) / (THROW_SWING - THROW_HOLD), 1.8))
			else:
				angle = lerpf(THROW_FOLLOW, 0.0, ease((k - THROW_SWING) / (1.0 - THROW_SWING), 0.6))
			var spin := Transform3D(Basis(Vector3(0, 1, 0), angle), Vector3.ZERO)
			return Transform3D(Basis.IDENTITY, pivot) * spin \
				* Transform3D(Basis.IDENTITY, -pivot) * tr
		"raise":
			var lift := 1.0
			if k < RAISE_UP:
				lift = ease(k / RAISE_UP, 0.4)
			elif k > 1.0 - RAISE_DOWN:
				lift = 1.0 - ease((k - (1.0 - RAISE_DOWN)) / RAISE_DOWN, 2.0)
			var turn := Transform3D(Basis(Vector3(0, 1, 0), RAISE_ANGLE * lift), Vector3.ZERO)
			return Transform3D(Basis.IDENTITY, pivot) * turn \
				* Transform3D(Basis.IDENTITY, -pivot) * tr
		"shield":
			var push := sin(PI * k) * SHIELD_PUSH
			tr.origin.x += push
			return tr
		_:
			var kick := k / 0.2 if k < 0.2 else 1.0 - (k - 0.2) / 0.8
			tr.origin.x -= RECOIL * kick
			tr.origin.z += RECOIL_LIFT * kick
			return tr


static func _anchor(block: Node3D, name: String) -> Vector3:
	var anchors: Dictionary = block.get_meta("anchors", {})
	var a = anchors.get(name)
	if a == null:
		return Vector3.ZERO
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func _tint_tree_self(node: Node, color: Color) -> void:
	_tint_mesh(node, color)
	_tint_tree(node, color)


# ---------------------------------------------------------------------------
# Geschosse (21. Nov. 2026, Spieler: "Geschosse auch 3D, lieber jetzt")
# ---------------------------------------------------------------------------
# Schuss, schweres Geschoss und Energiekugel fliegen als Koerper durch die
# Szene: DROMEs und Hindernisse verdecken sie, wo sie davor stehen. Einschlag,
# Zahlen und Heilstrahl bleiben 2D obenauf (BattleView.EffectPainter) -- sie
# sollen immer lesbar sein. Groessen in Entwurfspunkten wie bisher in 2D.

## Laenge und Dicke je Art (Entwurfspunkte); die Kugel nutzt nur die Dicke.
const SHOT_SIZE := {"bolt": Vector2(22.0, 3.4), "slug": Vector2(16.0, 5.5), "orb": Vector2(7.0, 7.0)}
## Hoehe ueber dem Boden, auf die ein Schuss am Ziel zielt (Brust), in
## Bildpunkten der 2D-Welt -- dieselbe wie bisher im EffectPainter.
const SHOT_LIFT_TO := 24.0
## Der Startpunkt kommt als Bildpunkt um so viel unter der Muendung
## (AbilityFx: weapon_tip + 34).
const SHOT_LIFT_FROM := 34.0
## Kinetische Geschosse: Stahl, mit dunklem Rand.
const SHOT_STEEL := Color(0.78, 0.78, 0.82)
const SHOT_STEEL_SIGNAL := Color(0.3, 0.3, 0.34)

static var _shot_meshes: Dictionary = {}


## Der 3D-Punkt ueber dem Bodenpunkt ``p`` (2D-Welt), so hoch, dass die
## Iso-Kamera ihn ``lift`` Bildpunkte hoeher zeigt (bei p - (0, lift)).
static func lifted(p: Vector2, lift: float) -> Vector3:
	return ground(p) + Vector3.UP * (lift / (DromeModel.COS45 * DromeModel.SCALE))


## Ein Geschoss von ``from`` (Bildpunkt unter der Muendung, s. SHOT_LIFT_FROM)
## nach ``to`` (Feldmitte des Ziels). ``style`` wie BattleView.show_attack
## ("projectile", "energy", "heavy", "wait", "from_fn"). Gibt false zurueck,
## wenn die Art nicht in 3D fliegt.
func add_shot(from: Vector2, to: Vector2, color: Color, style: Dictionary, flight: float) -> bool:
	var kind := str(style.get("projectile", ""))
	if not SHOT_SIZE.has(kind) or flight <= 0.0:
		return false
	var glow := float(style.get("energy", 0.0)) >= 0.5 or kind == "orb"
	var big := 1.4 if bool(style.get("heavy", false)) else 1.0
	var node := Node3D.new()
	node.name = "Geschoss"
	node.visible = false
	var core := color.lightened(0.55) if glow else SHOT_STEEL
	var signal_color := color if glow else SHOT_STEEL_SIGNAL
	var mesh := _shot_mesh(kind)
	for layer_info in [[DromeModel.LAYER_IMAGE, core], [DromeModel.LAYER_SIGNAL, signal_color],
			[DromeModel.LAYER_NEON, color if glow else Color.BLACK]]:
		if layer_info[0] == DromeModel.LAYER_NEON and not glow:
			continue
		var inst := MeshInstance3D.new()
		inst.mesh = mesh
		inst.layers = layer_info[0]
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inst.material_override = DromeModel._flat_material(layer_info[1])
		node.add_child(inst)
	if glow:
		_ensure_neon()
	var size: Vector2 = SHOT_SIZE[kind] * big
	# Kapsel laeuft entlang y (Laenge), die Kugel ist rund.
	node.scale = Vector3(size.y, size.x if kind != "orb" else size.y, size.y)
	_scene.add_child(node)
	_shots.append({"node": node, "from": lifted(from, SHOT_LIFT_FROM),
		"to": lifted(to, SHOT_LIFT_TO), "age": -float(style.get("wait", 0.0)),
		"flight": flight, "kind": kind, "size": node.scale,
		"from_fn": style.get("from_fn", null)})
	return true


## Einheits-Mesh je Art: Bolzen/Geschoss als Kapsel entlang y (Laenge 1),
## die Kugel mit Durchmesser 1.
static func _shot_mesh(kind: String) -> Mesh:
	if _shot_meshes.has(kind):
		return _shot_meshes[kind]
	var mesh: Mesh
	if kind == "orb":
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 12
		sphere.rings = 6
		mesh = sphere
	else:
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.5
		capsule.height = 1.0
		capsule.radial_segments = 8
		capsule.rings = 2
		mesh = capsule
	_shot_meshes[kind] = mesh
	return mesh


func _fly_shots(delta: float) -> void:
	if _shots.is_empty():
		return
	var keep: Array = []
	for shot in _shots:
		var node: Node3D = shot["node"]
		var was := float(shot["age"])
		shot["age"] = was + delta
		var age := float(shot["age"])
		# Salven: der Startpunkt erst beim Abfeuern (der Schuetze hat sich
		# inzwischen zum naechsten Ziel gedreht).
		if was < 0.0 and age >= 0.0 and shot["from_fn"] is Callable:
			shot["from"] = lifted((shot["from_fn"] as Callable).call(), SHOT_LIFT_FROM)
		if age >= float(shot["flight"]) or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			continue
		keep.append(shot)
		if age < 0.0:
			continue
		var t := age / float(shot["flight"])
		var from: Vector3 = shot["from"]
		var to: Vector3 = shot["to"]
		node.visible = true
		var dir := to - from
		var size: Vector3 = shot["size"]
		if shot["kind"] == "orb":
			node.position = from.lerp(to, t)
			node.scale = size * (1.0 + 0.15 * sin(age * 30.0))
		elif dir.length() > 0.001:
			# Die Spitze fliegt von der Muendung zum Ziel, der Schweif folgt.
			var along := dir.normalized()
			node.position = from.lerp(to, t) - along * size.y * 0.5
			var side := along.cross(Vector3.UP if absf(along.y) < 0.99 else Vector3.RIGHT).normalized()
			var third := side.cross(along)
			node.basis = Basis(side * size.x, along * size.y, third * size.z)
	_shots = keep


func shots_in_flight() -> int:
	return _shots.size()


# ---------------------------------------------------------------------------
# Jedes Bild
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	_update_nudges()
	for flash in _flashes:
		flash["t"] = float(flash["t"]) + _delta
	_flashes = _flashes.filter(func(f): return float(f["t"]) < FLASH_LIGHT_TIME)
	for unit in _models.keys():
		if not is_instance_valid(unit):
			forget(unit)
			continue
		_sync_unit(unit, _models[unit])
		# Sicherung (18. Nov. 2026, "Tote bleiben stehen"): wer gefallen ist,
		# verschwindet spaetestens nach der Zerfallszeit -- auch wenn die
		# Todesanimation nicht lief.
		if not unit.is_alive():
			var state: Dictionary = _anim.get(unit, {})
			state["dead_for"] = float(state.get("dead_for", 0.0)) + _delta
			_anim[unit] = state
			if float(state["dead_for"]) > Unit.DEATH_TIME + 0.3:
				unit.visible = false
				_models[unit].visible = false
		_animate(unit, _models[unit], _delta)
		if unit.is_alive() and _anim.has(unit):
			_apply_light(unit, _models[unit], _anim[unit])
	_update_real_light()
	_fly_shots(_delta)
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
	_view_center = local_center
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
