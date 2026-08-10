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


## Haengt die Sprites unter ``parent``. Gibt slot -> Sprite2D zurueck.
##
## Vorhandene Kinder werden vorher entfernt -- ein Richtungswechsel baut neu
## auf, statt Texturen zu tauschen: mit der Richtung aendert sich auch die
## Zeichenreihenfolge, und die haengt am Sprite, nicht an der Textur.
static func assemble(parent: Node2D, build: DromeBuild, facing: String) -> Dictionary:
	for child in parent.get_children():
		if child is Sprite2D:
			parent.remove_child(child)
			child.queue_free()

	var sprites := {}
	if build == null:
		return sprites

	var chassis := build.body()
	var slot_z: Dictionary = {}
	var sockets: Dictionary = {}
	if chassis != null:
		var chassis_view := chassis.view(facing)
		slot_z = chassis_view.get("slot_z", {})
		sockets = chassis_view.get("anchors", {})

	# Die Tiefe des Ankers IST die Zeichenreihenfolge. Damit stimmt die
	# Ueberdeckung in allen vier Richtungen von selbst: in der Nordansicht
	# rutscht die Ausruestung hinter den Koerper, ein Schulterpod vor den Kopf.
	#
	# Die Rohwerte sind Kameratiefen (32 bis 72) und taugen NICHT direkt als
	# z_index: Kindknoten rechnen relativ zum Elternknoten, und ein Aufschlag
	# von 70 wuerde das Bauteil in die Tiefenstufe einer ganz anderen Feldreihe
	# schieben -- der Kopf laege dann vor einem Betonpfeiler drei Felder weiter
	# vorn. Gebraucht wird nur die REIHENFOLGE, also wird auf 0..n normalisiert.
	var ordered: Array = []
	for slot in SLOT_ORDER:
		var part := build.part_in(slot)
		if part == null:
			continue
		var view := part.view(facing)
		var depth: float = float(view.get("z_index", 50)) if slot == "body" \
			else float(slot_z.get(slot, 20))
		ordered.append({"slot": slot, "part": part, "view": view, "depth": depth})
	ordered.sort_custom(func(a, b): return a["depth"] < b["depth"])

	for rank in ordered.size():
		var entry: Dictionary = ordered[rank]
		var path: String = entry["view"].get("svg", "")
		if path == "" or not ResourceLoader.exists(path):
			push_warning("DromeSprites: Textur fehlt fuer %s (%s)"
				% [entry["slot"], path])
			continue
		var sprite := Sprite2D.new()
		sprite.texture = load(path)
		sprite.centered = false
		sprite.position = mount_offset(entry["slot"], entry["view"], sockets)
		# Die Textur ist feiner gerastert als der Entwurfsraum (siehe
		# tools/set_import_scale.py). Hier wird sie darauf zurueckgerechnet --
		# sonst stuende ein DROME viermal zu gross neben seinem Feld.
		# Der Versatz oben zaehlt im Entwurfsraum und ist eine Position im
		# Elternknoten, keine Texturkoordinate -- die Skalierung des Sprites
		# geht ihn deshalb nichts an.
		IsoView.fit_sprite(sprite)
		sprite.z_index = rank
		parent.add_child(sprite)
		sprites[entry["slot"]] = sprite

	return sprites


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
		push_warning("DromeSprites: kein Ankerpaar fuer %s" % slot)
		return Vector2.ZERO
	return socket - mount


## Faerbt alle Teile ein -- fuer den Haze-Grauschleier oder eine Trefferblende.
static func tint(sprites: Dictionary, color: Color) -> void:
	for sprite in sprites.values():
		sprite.modulate = color
