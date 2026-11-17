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
			var variants: Dictionary = chassis.view(direction).get("variants", {})
			for slot in sprites:
				if slot == "body" or str(slot).ends_with("_arm"):
					continue
				var part := build.part_in(slot)
				var variant := chassis.weapon_variant
				if variant != "" and slot == "equip_right":
					variant += "_right"
				var view := part.view_for(direction, variant) \
					if str(slot).begins_with("equip_") else part.view(direction)
				var mount: Vector2 = view["anchors"]["mount"]
				# Arme gehoeren zum Chassis (Schritt 4b): der Arm sitzt am
				# Sockel, die Waffe mit ihrem Griff an der Hand des Arms.
				var arm: Dictionary = variants.get("arm_%s_%s" % [slot, part.pose], {})
				if part.pose != "" and not arm.is_empty():
					t.ok(sprites.has("%s_arm" % slot),
						"%s/%s %s hat seinen Arm" % [chassis.id, slot, direction])
					var arm_mount: Vector2 = arm["anchors"]["mount"]
					t.equal(sprites["%s_arm" % slot].position + arm_mount, sockets[slot],
						"%s/%s %s: Arm sitzt am Sockel" % [chassis.id, slot, direction])
					t.equal(sprites[slot].position + mount, arm["anchors"]["hand"],
						"%s/%s %s: Waffe sitzt in der Hand" % [chassis.id, slot, direction])
					continue
				t.equal(sprites[slot].position + mount, sockets[slot],
					"%s/%s %s sitzt am Sockel" % [chassis.id, slot, direction])
	root.free()


## Kontur je Teil (docs/DROME_DESIGNREGELN.md, Abschnitt 5): jedes Teil
## traegt seine Kontur als Kind, alle Konturen liegen auf Ebene 0 unter allen
## Teilen (ab 1) -- so geht sie mit dem Teil mit und zeigt nur den Aussenrand.
func test_every_part_carries_its_rim_below_all_parts() -> void:
	var root := Node2D.new()
	for chassis: PartData in _bodies():
		var sprites := DromeSprites.assemble(root, _stock(chassis), "south")
		for slot in sprites:
			var sprite: Sprite2D = sprites[slot]
			var rim := sprite.get_node_or_null("Kontur") as Sprite2D
			t.ok(rim != null, "%s/%s hat eine Kontur" % [chassis.id, slot])
			if rim == null:
				continue
			t.ok(sprite.z_index >= 1, "%s/%s liegt über den Konturen" % [chassis.id, slot])
			t.equal(sprite.z_index + rim.z_index, 0, "%s/%s: Kontur auf Ebene 0" % [chassis.id, slot])
	root.free()


func test_turning_does_not_move_equipment_relative_to_its_socket() -> void:
	# Die Formulierung des Spielers: "der Orbit-Fokus wechselt den Platz".
	# Gemessen heisst das: der Abstand zwischen Teil und Sockel darf sich
	# beim Drehen nicht aendern -- er muss null bleiben, in jeder Richtung.
	var chassis := PartDB.get_part(&"mage_body")
	var focus := PartDB.get_part(&"eq_rune_staff")
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
