extends RefCounted

## Der Zusammenbau: sitzt jedes Teil auf seinem Sockel?
##
## Die Regel steht in parts/README.md, Abschnitt 2, und lautet
## ``verschiebung = body.anker[slot] - teil.anker["mount"]``. Sie hier
## festzuhalten kostet wenig und faengt einen Fehler, den man sonst nur sieht
## und nicht misst -- und selbst dann erst, wenn man den Bot dreht.

var t

## Die vier Ansichten, in denen jedes Teil vorliegt.
const DIRECTIONS := ["south", "west", "east", "north"]


func _bodies() -> Array[PartData]:
	var bodies: Array[PartData] = []
	for part in PartDB.of_type(PartData.Type.BODY):
		bodies.append(part)
	bodies.sort_custom(func(a, b): return str(a.id) < str(b.id))
	return bodies


## Was in diesen Slot darf -- bevorzugt aus dem eigenen Bausatz, denn das ist
## der Fall, den der Spieler zu sehen bekommt.
func _equipment_for(chassis: PartData, slot: String) -> PartData:
	var fallback: PartData = null
	for part in PartDB.equipment_for(chassis, slot):
		if part.set_id == chassis.set_id:
			return part
		if fallback == null:
			fallback = part
	return fallback


## Der Standardaufbau eines Bausatzes -- Sockelteile aus demselben Satz, in
## jeden Ausruestungsslot das erste Teil, das dort hineindarf.
func _stock(chassis: PartData) -> DromeBuild:
	var assignment := {"body": chassis.id}
	for type in [PartData.Type.HEAD, PartData.Type.FEET, PartData.Type.CORE]:
		for part in PartDB.of_type(type):
			if part.set_id == chassis.set_id:
				assignment[part.slot_name()] = part.id
	for slot in chassis.equip_slots():
		var part := _equipment_for(chassis, slot)
		if part != null:
			assignment[slot] = part.id
	return DromeBuild.create(chassis.set_id.to_upper(), assignment)


# ---------------------------------------------------------------------------
# Die Regel selbst
# ---------------------------------------------------------------------------

func test_equipment_lands_on_its_socket_in_every_direction() -> void:
	# Der eigentliche Fehler: Ausruestung wurde ohne Verschiebung gezeichnet
	# und sass damit auf der Mittelachse des Bots. Die Sockel wandern beim
	# Drehen um ihn herum, der Fehler wechselte also mit der Richtung die
	# Seite -- ein Orbit-Fokus schien seinen Platz zu tauschen.
	for chassis: PartData in _bodies():
		for direction in DIRECTIONS:
			var sockets: Dictionary = chassis.view(direction).get("anchors", {})
			for slot in chassis.equip_slots():
				var part := _equipment_for(chassis, slot)
				if part == null:
					continue
				var view := part.view(direction)
				var mount: Vector2 = view["anchors"]["mount"]
				var offset := DromeSprites.mount_offset(slot, view, sockets)
				t.ok(mount + offset == sockets[slot],
					"%s/%s %s: der Anker muss auf dem Sockel landen (%s + %s)"
					% [chassis.id, slot, direction, mount, offset])


func test_socket_parts_are_not_moved() -> void:
	# Kopf, Fuesse und Kern haben ihren "mount" AUF dem Sockel -- ihre Grafik
	# sitzt bereits richtig. Faellt hier etwas anderes als (0,0) heraus, sind
	# die Anker auseinandergelaufen, und die Verschiebung wuerde ein Teil
	# verschieben, das schon am Platz war.
	for chassis: PartData in _bodies():
		var build := _stock(chassis)
		for direction in DIRECTIONS:
			var sockets: Dictionary = chassis.view(direction).get("anchors", {})
			for slot in ["head", "feet", "core"]:
				var part := build.part_in(slot)
				if part == null:
					continue
				t.equal(DromeSprites.mount_offset(slot, part.view(direction), sockets),
					Vector2.ZERO,
					"%s/%s %s sitzt schon auf seinem Sockel"
					% [chassis.id, slot, direction])


func test_the_body_stays_where_its_graphic_puts_it() -> void:
	# Der Body traegt die Bodenraute auf (64, 96), und daran haengt die
	# Platzierung auf dem Feld. Wird er verschoben, steht der ganze Bot
	# neben seinem Feld -- und zwar in allen vier Richtungen anders.
	for chassis: PartData in _bodies():
		for direction in DIRECTIONS:
			var view := chassis.view(direction)
			t.equal(DromeSprites.mount_offset("body", view, view.get("anchors", {})),
				Vector2.ZERO, "%s %s: der Body bleibt liegen" % [chassis.id, direction])


# ---------------------------------------------------------------------------
# ... und der Zusammenbau, der sie anwendet
# ---------------------------------------------------------------------------

func test_assemble_places_every_sprite_on_its_socket() -> void:
	# Dieselbe Rechnung, aber am fertigen Baum: assemble() muss die
	# Verschiebung auch wirklich an den Sprite schreiben.
	var root := Node2D.new()
	for chassis: PartData in _bodies():
		var build := _stock(chassis)
		for direction in DIRECTIONS:
			var sprites := DromeSprites.assemble(root, build, direction)
			var sockets: Dictionary = chassis.view(direction).get("anchors", {})
			t.ok(sprites.has("body"), "%s %s: der Body ist da" % [chassis.id, direction])
			for slot in sprites:
				if slot == "body":
					continue
				var mount: Vector2 = build.part_in(slot).view(direction)["anchors"]["mount"]
				t.equal(sprites[slot].position + mount, sockets[slot],
					"%s/%s %s sitzt am Sockel" % [chassis.id, slot, direction])
	root.free()


func test_turning_does_not_move_equipment_relative_to_its_socket() -> void:
	# Die Formulierung des Spielers: "der Orbit-Fokus wechselt den Platz".
	# Gemessen heisst das: der Abstand zwischen Teil und Sockel darf sich
	# beim Drehen nicht aendern -- er muss null bleiben, in jeder Richtung.
	var chassis := PartDB.get_part(&"mage_body")
	var focus := PartDB.get_part(&"eq_orbit_focus")
	var seen := {}
	for direction in DIRECTIONS:
		var sockets: Dictionary = chassis.view(direction).get("anchors", {})
		var view := focus.view(direction)
		var placed: Vector2 = view["anchors"]["mount"] \
			+ DromeSprites.mount_offset("equip_right", view, sockets)
		seen[direction] = placed - sockets["equip_right"]
	for direction in seen:
		t.equal(seen[direction], Vector2.ZERO,
			"Orbit-Fokus %s: kein Abstand zum Sockel" % direction)
