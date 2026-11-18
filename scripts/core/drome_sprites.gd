class_name DromeSprites
extends RefCounted

## Setzt einen DROME aus seinen Bauteil-Texturen zusammen.
##
## Die EINE Stelle, an der das passiert -- Werkstatt-Vorschau und Kampfeinheit
## rufen dieselbe Funktion. Das ist kein Aufraeumen, sondern ein
## Akzeptanzkriterium: der Spieler muss den Bot, den er gebaut hat, im Kampf
## wiedererkennen. Zwei Zusammenbauten waeren zwei Gelegenheiten, dass er es
## nicht tut.
##
## Pipeline A aus docs/GODOT_INTEGRATION.md: ein Sprite2D je Teil,
## ``centered = false``, alle im gemeinsamen 128er Entwurfsraum. Verschoben
## wird nach der Regel aus parts/README.md, Abschnitt 2:
##
##     verschiebung = body.anker[slot] - teil.anker["mount"]

## Reihenfolge, in der Slots angelegt werden. Die tatsaechliche Ueberdeckung
## entscheidet slot_z; das hier ist nur ein stabiler Ausgangszustand.
const SLOT_ORDER := ["feet", "body", "core", "equip_left", "equip_center",
	"equip_right", "equip_shoulder", "head"]


const OUTLINE_SHADER := preload("res://assets/shaders/drome_outline.gdshader")

## Aufloesung der 3D-Ansicht in Pixeln fuer 128 Entwurfspunkte. 256 reicht
## fuer den Kampf (Kamerazoom 0.62 auf dem Handy), der Hangar gibt mehr mit.
const DEFAULT_RESOLUTION := 256


## Haengt den DROME unter ``parent``. Gibt {"drome": Sprite2D} zurueck.
##
## Seit 17. Nov. 2026 ein echtes 3D-Modell (DromeModel): ein SubViewport mit
## der Iso-Kamera rendert den ganzen DROME in einem Durchgang mit
## Tiefenpuffer, ein Sprite2D zeigt das Bild im 128er Entwurfsraum -- an
## derselben Stelle wie vorher die Einzelbilder (Bodenmitte auf (64, 96)).
## Gerendert wird einmal je Aufbau (UPDATE_ONCE); ein Richtungswechsel baut
## neu auf.
##
## Vorhandene Kinder (Sprites, 3D-Ansichten) werden vorher entfernt.
static func assemble(parent: Node2D, build: DromeBuild, facing: String,
		resolution: int = DEFAULT_RESOLUTION) -> Dictionary:
	# Nur gedreht (Kampf: jeder Schritt kann die Richtung wechseln)? Dann
	# bleibt die 3D-Ansicht, das Modell dreht sich und wird neu gezeichnet.
	var old_view := parent.get_node_or_null("Ansicht3D") as SubViewport
	var old_sprite := parent.get_node_or_null("Drome") as Sprite2D
	if old_view != null and old_sprite != null and build != null \
			and old_view.get_meta("build", null) == build \
			and old_view.get_meta("signature", "") == _signature(build) \
			and old_view.size == Vector2i(resolution, resolution):
		var turn := old_view.get_node_or_null("Drome/Ausrichtung") as Node3D
		if turn != null:
			turn.basis = DromeModel.facing_basis(facing)
			redraw(parent)
			return {"drome": old_sprite}
	for child in parent.get_children():
		if child is Sprite2D or child is SubViewport:
			parent.remove_child(child)
			child.queue_free()

	var sprites := {}
	if build == null or build.body() == null:
		return sprites

	# Drei Ansichten derselben 3D-Welt: das Bild, die Signalfarbe je Teil
	# (Kontur je Teil) und -- nur mit Neon-Teilen -- die Leuchtroehren.
	var world := World3D.new()
	var view := _make_view("Ansicht3D", world, resolution, DromeModel.LAYER_IMAGE, true)
	view.set_meta("build", build)
	view.set_meta("signature", _signature(build))
	var model := DromeModel.build_node(build, facing, resolution)
	view.add_child(model)
	parent.add_child(view)
	var signal_view := _make_view("Signal3D", world, resolution, DromeModel.LAYER_SIGNAL, false)
	parent.add_child(signal_view)
	var neon_view: SubViewport = null
	if bool(model.get_meta("neon", false)):
		neon_view = _make_view("Neon3D", world, resolution, DromeModel.LAYER_NEON, true)
		parent.add_child(neon_view)

	var sprite := Sprite2D.new()
	sprite.name = "Drome"
	sprite.texture = view.get_texture()
	sprite.centered = false
	IsoView.fit_sprite(sprite)
	sprite.z_index = 1
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	outline.set_shader_parameter("line_color", model.get_meta("line", Color(0.03, 0.04, 0.07)))
	outline.set_shader_parameter("rim_color", model.get_meta("accent", Color(0.18, 0.89, 0.9)))
	# Strich 0.9 und Kontur 3.2 Entwurfspunkte wie im SVG (rim_svg), je zur
	# Haelfte ausserhalb der Flaeche.
	outline.set_shader_parameter("line_px", 0.45 * resolution / 128.0)
	outline.set_shader_parameter("rim_px", 1.6 * resolution / 128.0)
	outline.set_shader_parameter("signal_tex", signal_view.get_texture())
	outline.set_shader_parameter("use_signal", true)
	sprite.material = outline
	parent.add_child(sprite)
	if neon_view != null:
		sprite.add_child(NeonGlow.create_3d(neon_view.get_texture(), resolution))
	sprites["drome"] = sprite
	return sprites


## Fertige Bilder je Aufbau (18. Nov. 2026, Hangar ruckelte beim Wechsel):
## Schluessel -> {image, signal, neon, line, accent}. Ein Bild fuer die
## Bildschirme ausserhalb des Kampfes wird einmal in 3D gerendert und danach
## aus dem Zwischenspeicher gezeigt -- ohne SubViewports.
static var _pictures: Dictionary = {}
static var _picture_order: Array = []
static var _picture_pending: Array = []   # [parent, key] bis nach dem Rendern
const PICTURE_CACHE_MAX := 48


## Wie ``assemble``, aber fuer stehende Bilder (Hangar, Shop, Auswahl): beim
## ersten Mal wird gerendert und das Ergebnis gemerkt, danach nur noch ein
## Sprite mit den gemerkten Bildern gezeigt.
static func assemble_picture(parent: Node2D, build: DromeBuild, facing: String,
		resolution: int = DEFAULT_RESOLUTION) -> Dictionary:
	if build == null or build.body() == null:
		return {}
	var key := "%s|%s|%s|%d" % [_signature(build), build.faction, facing, resolution]
	if _pictures.has(key):
		return _picture_sprite(parent, _pictures[key], resolution)
	var sprites := assemble(parent, build, facing, resolution)
	if not sprites.is_empty():
		_picture_pending.append([parent, key])
		if not RenderingServer.frame_post_draw.is_connected(_remember_pictures):
			RenderingServer.frame_post_draw.connect(_remember_pictures, CONNECT_ONE_SHOT)
	return sprites


## Nach dem Bild, in dem die neuen DROMEs gerendert wurden: alle merken.
static func _remember_pictures() -> void:
	var pending := _picture_pending
	_picture_pending = []
	for item in pending:
		_remember_picture(item[0], item[1])


## Nach dem ersten Rendern: die drei Ebenen als feste Bilder merken.
static func _remember_picture(parent: Node2D, key: String) -> void:
	if not is_instance_valid(parent) or _pictures.has(key):
		return
	var view := parent.get_node_or_null("Ansicht3D") as SubViewport
	var signal_view := parent.get_node_or_null("Signal3D") as SubViewport
	var sprite := parent.get_node_or_null("Drome") as Sprite2D
	if view == null or signal_view == null or sprite == null:
		return
	var image := view.get_texture().get_image()
	var signal_image := signal_view.get_texture().get_image()
	# Ohne echtes Rendern (headless) gibt es keine Bilder -- dann nichts merken.
	if image == null or image.is_empty() or signal_image == null or signal_image.is_empty():
		return
	var entry := {"image": ImageTexture.create_from_image(image),
		"signal": ImageTexture.create_from_image(signal_image), "neon": null,
		"line": (sprite.material as ShaderMaterial).get_shader_parameter("line_color"),
		"accent": (sprite.material as ShaderMaterial).get_shader_parameter("rim_color")}
	var neon_view := parent.get_node_or_null("Neon3D") as SubViewport
	if neon_view != null:
		var neon_image := neon_view.get_texture().get_image()
		if neon_image != null and not neon_image.is_empty():
			entry["neon"] = ImageTexture.create_from_image(neon_image)
	_pictures[key] = entry
	_picture_order.append(key)
	while _picture_order.size() > PICTURE_CACHE_MAX:
		_pictures.erase(_picture_order.pop_front())


## Der DROME aus gemerkten Bildern: dasselbe Sprite mit Kontur und Neon wie
## in ``assemble``, nur ohne 3D-Ansichten dahinter.
static func _picture_sprite(parent: Node2D, entry: Dictionary, resolution: int) -> Dictionary:
	for child in parent.get_children():
		if child is Sprite2D or child is SubViewport:
			parent.remove_child(child)
			child.queue_free()
	var sprite := Sprite2D.new()
	sprite.name = "Drome"
	sprite.texture = entry["image"]
	sprite.centered = false
	IsoView.fit_sprite(sprite)
	sprite.z_index = 1
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	outline.set_shader_parameter("line_color", entry["line"])
	outline.set_shader_parameter("rim_color", entry["accent"])
	outline.set_shader_parameter("line_px", 0.45 * resolution / 128.0)
	outline.set_shader_parameter("rim_px", 1.6 * resolution / 128.0)
	outline.set_shader_parameter("signal_tex", entry["signal"])
	outline.set_shader_parameter("use_signal", true)
	sprite.material = outline
	parent.add_child(sprite)
	if entry["neon"] != null:
		sprite.add_child(NeonGlow.create_3d(entry["neon"], resolution))
	return {"drome": sprite}


## Eine Ansicht der gemeinsamen 3D-Welt mit eigener Kamera fuer eine Ebene.
static func _make_view(view_name: String, world: World3D, resolution: int, layer: int,
		smooth: bool) -> SubViewport:
	var view := SubViewport.new()
	view.name = view_name
	view.size = Vector2i(resolution, resolution)
	view.transparent_bg = true
	view.world_3d = world
	# Die Signalebene ohne Kantenglaettung: ihre Farben werden nur gelesen,
	# Mischfarben an den Kanten waeren dort falsch.
	view.msaa_3d = Viewport.MSAA_4X if smooth else Viewport.MSAA_DISABLED
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cam := DromeModel.make_camera()
	cam.cull_mask = layer
	view.add_child(cam)
	return view


## Zeichnet alle Ansichten eines DROME einmal neu (nach Drehen oder Bewegen).
static func redraw(parent: Node, always: bool = false) -> void:
	for view_name in ["Ansicht3D", "Signal3D", "Neon3D"]:
		var view := parent.get_node_or_null(view_name) as SubViewport
		if view != null:
			view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if always \
				else SubViewport.UPDATE_ONCE


## Was im Aufbau steckt -- aendert es sich (Umbau), wird neu gebaut.
static func _signature(build: DromeBuild) -> String:
	return str(build.slots)


## Wohin ein Teil im Entwurfsraum des Bodys muss: von seinem eigenen "mount"
## auf den gleichnamigen Sockel des Chassis.
##
## Fuer Kopf, Fuesse und Kern faellt hier immer (0,0) heraus -- ihr "mount" IST
## der Sockel, und tools/build_sample_parts.py haelt das mit check_mounts()
## fest. Genau deshalb fiel das Fehlen der Verschiebung so lange nicht auf:
## drei von vier Sockelteilen sassen auch ohne sie richtig.
##
## Bei Ausruestung ist sie dagegen zwingend: deren Anker sitzt bewusst in der
## EIGENEN Mitte, damit dasselbe Teil an den linken wie an den rechten Arm
## passt (parts/README.md, Abschnitt 6). Ohne die Verschiebung landet jede
## Ausruestung auf der Mittelachse des Bots, waehrend die Sockel mit der
## Richtung um ihn herumwandern -- der Fehler wechselt beim Drehen die Seite,
## und ein Orbit-Fokus scheint seinen Platz zu tauschen.
##
## Der Body selbst wird nicht verschoben: seine Grafik legt die Bodenraute auf
## (64, 96), und daran haengt die Platzierung auf dem Feld. Alle anderen Teile
## rechnen deshalb in seinem ungerueckten Rahmen.
static func mount_offset(slot: String, view: Dictionary, sockets: Dictionary) -> Vector2:
	if slot == "body":
		return Vector2.ZERO
	var socket = sockets.get(slot)
	var mount = view.get("anchors", {}).get("mount")
	if socket == null or mount == null:
		# Ohne Sockel oder ohne Gegenstueck gibt es nichts auszurichten. Das
		# Teil bleibt sichtbar, statt zu verschwinden -- ein Bauteil an der
		# falschen Stelle ist ein Hinweis, ein fehlendes ist ein Raetsel.
		push_warning("DromeSprites: kein Ankerpaar für %s" % slot)
		return Vector2.ZERO
	return socket - mount


## Faerbt alle Teile ein -- fuer den Haze-Grauschleier oder eine Trefferblende.
static func tint(sprites: Dictionary, color: Color) -> void:
	for sprite in sprites.values():
		sprite.modulate = color
