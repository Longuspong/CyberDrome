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
			old_view.render_target_update_mode = SubViewport.UPDATE_ONCE
			return {"drome": old_sprite}
	for child in parent.get_children():
		if child is Sprite2D or child is SubViewport:
			parent.remove_child(child)
			child.queue_free()

	var sprites := {}
	if build == null or build.body() == null:
		return sprites

	var view := SubViewport.new()
	view.name = "Ansicht3D"
	view.size = Vector2i(resolution, resolution)
	view.transparent_bg = true
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	view.set_meta("build", build)
	view.set_meta("signature", _signature(build))
	var model := DromeModel.build_node(build, facing, resolution)
	view.add_child(DromeModel.make_camera())
	view.add_child(model)
	parent.add_child(view)

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
	sprite.material = outline
	parent.add_child(sprite)
	sprites["drome"] = sprite
	return sprites


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
