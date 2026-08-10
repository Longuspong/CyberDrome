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
## Pipeline A aus docs/GODOT_INTEGRATION.md: ein Sprite2D je Teil, alle auf
## Position (0,0), ``centered = false``. Die Anker-Mathematik steckt bereits
## in der Grafik, Offsets aus der JSON sind nicht noetig.

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
	if chassis != null:
		slot_z = chassis.view(facing).get("slot_z", {})

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
		sprite.position = Vector2.ZERO
		# Die Textur ist feiner gerastert als der Entwurfsraum (siehe
		# tools/set_import_scale.py). Hier wird sie darauf zurueckgerechnet --
		# sonst stuende ein DROME viermal zu gross neben seinem Feld.
		IsoView.fit_sprite(sprite)
		sprite.z_index = rank
		parent.add_child(sprite)
		sprites[entry["slot"]] = sprite

	return sprites


## Faerbt alle Teile ein -- fuer den Haze-Grauschleier oder eine Trefferblende.
static func tint(sprites: Dictionary, color: Color) -> void:
	for sprite in sprites.values():
		sprite.modulate = color
