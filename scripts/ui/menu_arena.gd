class_name MenuArena
extends Node2D

## Die Hintergrund-Inszenierung des Hauptmenues: zwei zufaellig gewuerfelte
## Teams, die einander bearbeiten. Rein DEKORATIV -- kein echter Kampf, keine
## Regel, kein Einfluss auf irgendeinen Spielstand.
##
## Die Bots kommen aus demselben Generator wie die Gegner im Chaos-Virus
## (EnemyGenerator), damit man im Hintergrund wirklich VERSCHIEDENE Aufbauten
## sieht.
##
## ### Was sich bewegt
##
##   * Leerlauf: jedes Bauteil wippt fuer sich -- Koerper und Ausruestung
##     atmen, der Kopf folgt mit Verzoegerung, der Kern pulsiert. Die Fuesse
##     bleiben stehen, sonst schwebt der Bot.
##   * Auftritt: eine neue Runde marschiert von der Bildkante herein.
##   * Angriff: Fernkaempfer schiessen (Muendungsblitz, Geschoss, Rueckstoss),
##     Nahkaempfer stossen zu. Die Farbe des Geschosses sagt, ob die Waffe
##     Energie oder Projektile verschiesst.
##   * Treffer: Funken, ein Ruck, und bei Schildtraegern flackert der Schild.
##   * Ausfall: der Bot faellt auseinander -- jedes Teil fliegt fuer sich weg.
##
## ### Animationen reduzieren
##
## Mit ``Accessibility.reduce_motion`` stehen die Bots still, es gibt keine
## Spruenge und kein Auseinanderfliegen -- nur ein ruhiges Aufblenden der
## Treffer. Die Kulisse bleibt lebendig genug, um zu zeigen, dass hier
## gekaempft wird, ohne dass sich etwas schnell bewegt.

const TEAM_SIZE := 2
const BOT_SCALE := 1.15

const COLOR_ENERGY := Color(0.45, 0.95, 1.0)
const COLOR_KINETIC := Color(1.0, 0.72, 0.35)
const COLOR_SHIELD := Color(0.5, 0.8, 1.0)

## Ein Bot der Kulisse: Rig, Teile mit Ruhelage, Seite, Zustand.
var _bots: Array = []
var _running := false
var _time := 0.0
## Textur -> Mitte ihres sichtbaren Teils (0..1), siehe _visible_center().
var _centers := {}


func start() -> void:
	if _running:
		return
	_running = true
	_new_round()


func _calm() -> bool:
	return Accessibility.reduce_motion


# ---------------------------------------------------------------------------
# Runden
# ---------------------------------------------------------------------------

func _new_round() -> void:
	for bot in _bots:
		if is_instance_valid(bot["rig"]):
			bot["rig"].queue_free()
	_bots.clear()

	var left := EnemyGenerator.new(randi()).generate(TEAM_SIZE, 260.0)
	var right := EnemyGenerator.new(randi()).generate(TEAM_SIZE, 260.0)
	for i in left.size():
		_spawn_bot(left[i], -1, i)
	for i in right.size():
		_spawn_bot(right[i], 1, i)

	_schedule_clash(1.6)


func _spawn_bot(build: DromeBuild, side: int, row: int) -> void:
	var rig := Node2D.new()
	rig.scale = Vector2(BOT_SCALE, BOT_SCALE)
	var sprites := DromeSprites.assemble(rig, build, "east" if side < 0 else "west")
	add_child(rig)

	var home := Vector2(side * (150.0 + row * 26.0), -30.0 + row * 64.0)
	var base := home - IsoView.SPRITE_ORIGIN * BOT_SCALE
	rig.z_index = int(home.y)

	var rest := {}
	for slot in sprites:
		rest[slot] = sprites[slot].position

	var bot := {
		"rig": rig, "home": home, "base": base, "side": side,
		"sprites": sprites, "rest": rest, "alive": true,
		"phase": randf() * TAU, "walking": 0.0,
		"weapons": _weapon_slots(build),
		"ranged": _is_ranged(build),
		"energy": _is_energy(build),
		"shield": int(build.stats().get("shield_max", 0)) > 0,
	}
	_bots.append(bot)

	if _calm():
		rig.position = base
		rig.modulate.a = 0.0
		create_tween().tween_property(rig, "modulate:a", 1.0, 0.6)
		return

	# Hereinmarschieren von der Bildkante, gestaffelt.
	var edge := get_viewport_rect().size.x * 0.5 + 160.0
	rig.position = Vector2(side * edge, base.y)
	bot["walking"] = 1.0
	var tween := create_tween()
	tween.tween_interval(row * 0.25)
	tween.tween_property(rig, "position", base, 1.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): bot["walking"] = 0.0)


func _weapon_slots(build: DromeBuild) -> Array:
	var slots: Array = []
	for slot in build.equip_slots():
		var part := build.part_in(slot)
		if part != null and part.category == "weapon":
			slots.append(slot)
	return slots


func _is_ranged(build: DromeBuild) -> bool:
	for action in build.actions():
		if action.is_attack() and action.range_tiles > 1:
			return true
	return false


func _is_energy(build: DromeBuild) -> bool:
	for action in build.actions():
		if action.is_attack():
			return action.energy_fraction >= 0.5
	return false


func _living(side: int) -> Array:
	return _bots.filter(func(b): return b["alive"] and b["side"] == side)


# ---------------------------------------------------------------------------
# Leerlauf
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _running or _calm():
		return
	_time += delta
	for bot in _bots:
		if not bot["alive"] or not is_instance_valid(bot["rig"]):
			continue
		var walking: float = bot["walking"]
		# Beim Laufen schneller und kraeftiger -- das sind dann Schritte.
		var speed := 2.2 + walking * 7.0
		var amount := 1.6 + walking * 2.4
		var t: float = _time * speed + float(bot["phase"])
		var bob := sin(t) * amount
		var sprites: Dictionary = bot["sprites"]
		var rest: Dictionary = bot["rest"]
		for slot in sprites:
			var sprite: Sprite2D = sprites[slot]
			if not is_instance_valid(sprite):
				continue
			var offset := Vector2.ZERO
			match slot:
				"feet":
					offset = Vector2(0, maxf(0.0, -bob) * 0.4 * walking)
				"head":
					offset = Vector2(0, sin(t - 0.7) * amount * 1.15)
				"core":
					offset = Vector2(0, bob)
					var glow := 1.0 + 0.25 * (0.5 + 0.5 * sin(_time * 3.1 + float(bot["phase"])))
					sprite.modulate = Color(glow, glow, glow, 1.0)
				"body":
					offset = Vector2(0, bob)
				_:
					# Ausruestung schwingt leicht gegen den Koerper.
					offset = Vector2(sin(t * 0.5) * 0.8, sin(t + 0.5) * amount * 1.2)
			sprite.position = rest[slot] + offset


# ---------------------------------------------------------------------------
# Kampf
# ---------------------------------------------------------------------------

func _schedule_clash(wait: float = -1.0) -> void:
	if not _running:
		return
	if wait < 0.0:
		wait = randf_range(0.9, 1.7) * (1.8 if _calm() else 1.0)
	get_tree().create_timer(wait).timeout.connect(_clash)


func _clash() -> void:
	if not _running or not is_inside_tree():
		return
	if _living(-1).is_empty() or _living(1).is_empty():
		get_tree().create_timer(1.6).timeout.connect(_new_round)
		return

	var attackers := _living(-1) + _living(1)
	var attacker: Dictionary = attackers[randi() % attackers.size()]
	var targets := _living(-attacker["side"])
	var target: Dictionary = targets[randi() % targets.size()]
	if attacker["ranged"]:
		_shoot(attacker, target)
	else:
		_lunge(attacker, target)
	_schedule_clash()


## Mitte des Torsos in Arena-Koordinaten -- dorthin zielt ein Schuss. Aus dem
## tatsaechlichen Koerper-Sprite gerechnet, nicht aus einem geschaetzten
## Versatz: der lag beim ersten Versuch einen halben Bot zu hoch, und der
## Schildring schwebte ueber dem Kopf.
func _torso(bot: Dictionary) -> Vector2:
	var sprites: Dictionary = bot["sprites"]
	if sprites.has("body") and is_instance_valid(sprites["body"]):
		var sprite: Sprite2D = sprites["body"]
		return to_local(sprite.global_transform * _visible_center(sprite))
	return bot["home"] + Vector2(0, -44.0) * BOT_SCALE


## Mitte des sichtbaren Teils einer Textur. get_rect() umfasst die ganze
## 128er Leinwand, auf der das Teil nur einen Ausschnitt belegt -- deren Mitte
## liegt oft neben dem Teil.
##
## Je Textur einmal gerechnet: get_image() holt die Pixel von der Grafikkarte.
func _visible_center(sprite: Sprite2D) -> Vector2:
	var rect := sprite.get_rect()
	if sprite.texture == null:
		return rect.get_center()
	var key := sprite.texture.get_rid()
	if not _centers.has(key):
		var image := sprite.texture.get_image()
		var center := Vector2(-1, -1)
		if image != null and not image.is_empty():
			var used := image.get_used_rect()
			if used.size != Vector2i.ZERO:
				center = (Vector2(used.position) + Vector2(used.size) * 0.5) \
					/ Vector2(image.get_width(), image.get_height())
		_centers[key] = center
	var relative: Vector2 = _centers[key]
	if relative.x < 0.0:
		return rect.get_center()
	return rect.position + relative * rect.size


## Muendung: die Mitte des Waffen-Sprites, sonst der Torso.
func _muzzle(bot: Dictionary) -> Vector2:
	var sprites: Dictionary = bot["sprites"]
	for slot in bot["weapons"]:
		if sprites.has(slot) and is_instance_valid(sprites[slot]):
			var sprite: Sprite2D = sprites[slot]
			return to_local(sprite.global_transform * _visible_center(sprite))
	return _torso(bot)


func _shoot(attacker: Dictionary, target: Dictionary) -> void:
	var color := COLOR_ENERGY if attacker["energy"] else COLOR_KINETIC
	var from := _muzzle(attacker)
	var to := _torso(target) + Vector2(randf_range(-8, 8), randf_range(-10, 6))

	_flash_at(from, color, 10.0)
	if not _calm():
		_recoil(attacker)

	var bolt := Line2D.new()
	bolt.width = 4.0
	bolt.default_color = color
	bolt.begin_cap_mode = Line2D.LINE_CAP_ROUND
	bolt.end_cap_mode = Line2D.LINE_CAP_ROUND
	bolt.z_index = 200
	var direction := (to - from).normalized()
	bolt.points = PackedVector2Array([Vector2.ZERO, -direction * 26.0])
	bolt.position = from
	add_child(bolt)

	var travel := from.distance_to(to) / 900.0
	var tween := create_tween()
	if _calm():
		# Kein fliegendes Geschoss: kurz eine Linie, die verblasst.
		bolt.points = PackedVector2Array([Vector2.ZERO, to - from])
		bolt.width = 2.0
		bolt.modulate.a = 0.7
		tween.tween_property(bolt, "modulate:a", 0.0, 0.5)
	else:
		tween.tween_property(bolt, "position", to, travel)
	tween.tween_callback(func():
		bolt.queue_free()
		_impact(target, to, color))


func _lunge(attacker: Dictionary, target: Dictionary) -> void:
	var rig: Node2D = attacker["rig"]
	if not is_instance_valid(rig):
		return
	if _calm():
		_impact(target, _torso(target), COLOR_KINETIC)
		return
	var base: Vector2 = attacker["base"]
	var toward := Vector2(target["home"].x - attacker["home"].x, 0.0).normalized() * 40.0
	var tween := create_tween()
	tween.tween_property(rig, "position", base + toward, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): _impact(target, _torso(target), COLOR_KINETIC))
	tween.tween_property(rig, "position", base, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _recoil(bot: Dictionary) -> void:
	var rig: Node2D = bot["rig"]
	if not is_instance_valid(rig):
		return
	var base: Vector2 = bot["base"]
	var tween := create_tween()
	tween.tween_property(rig, "position", base + Vector2(bot["side"] * 6.0, 0), 0.05)
	tween.tween_property(rig, "position", base, 0.2)


func _impact(target: Dictionary, at: Vector2, color: Color) -> void:
	var rig: Node2D = target["rig"]
	if not target["alive"] or not is_instance_valid(rig):
		return

	if target["shield"] and randf() < 0.6:
		_shield_flicker(target)
	else:
		_sparks(at, color)

	var flash := create_tween()
	flash.tween_property(rig, "modulate", Color(1.7, 0.75, 0.7, 1.0), 0.06)
	flash.tween_property(rig, "modulate", Color(1, 1, 1, 1), 0.25)

	if not _calm():
		var base: Vector2 = target["base"]
		var kick := create_tween()
		kick.tween_property(rig, "position", base + Vector2(target["side"] * 12.0, -3.0), 0.07)
		kick.tween_property(rig, "position", base, 0.22)

	if randf() < 0.2:
		_ko(target)


## Ein kurzer Lichtpunkt -- Muendungsblitz oder Aufschlag.
func _flash_at(at: Vector2, color: Color, radius: float) -> void:
	var dot := Polygon2D.new()
	dot.polygon = _circle(radius, 12)
	dot.color = color
	dot.position = at
	dot.z_index = 210
	add_child(dot)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(dot, "scale", Vector2(1.8, 1.8), 0.14)
	tween.tween_property(dot, "modulate:a", 0.0, 0.16)
	tween.chain().tween_callback(dot.queue_free)


func _sparks(at: Vector2, color: Color) -> void:
	_flash_at(at, Color(1, 1, 1), 7.0)
	if _calm():
		return
	var sparks := CPUParticles2D.new()
	sparks.position = at
	sparks.z_index = 220
	sparks.amount = 14
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.lifetime = 0.45
	sparks.spread = 180.0
	sparks.initial_velocity_min = 80.0
	sparks.initial_velocity_max = 200.0
	sparks.gravity = Vector2(0, 380)
	sparks.scale_amount_min = 2.0
	sparks.scale_amount_max = 3.5
	sparks.color = color
	add_child(sparks)
	sparks.emitting = true
	get_tree().create_timer(0.8).timeout.connect(sparks.queue_free)


func _shield_flicker(target: Dictionary) -> void:
	var ring := Line2D.new()
	var points := _circle(1.0, 32)
	var scaled := PackedVector2Array()
	for p in points:
		scaled.append(Vector2(p.x * 46.0, p.y * 62.0))
	scaled.append(scaled[0])
	ring.points = scaled
	ring.width = 3.0
	ring.default_color = COLOR_SHIELD
	ring.position = _torso(target)
	ring.z_index = 205
	add_child(ring)
	var tween := create_tween()
	if not _calm():
		tween.tween_property(ring, "modulate:a", 0.3, 0.06)
		tween.tween_property(ring, "modulate:a", 1.0, 0.06)
	tween.tween_property(ring, "modulate:a", 0.0, 0.4)
	tween.tween_callback(ring.queue_free)


## Ausfall: der Bot faellt auseinander. Jedes Teil fliegt fuer sich -- die
## Kulisse zeigt damit nebenbei, dass ein DROME aus Teilen besteht.
func _ko(target: Dictionary) -> void:
	target["alive"] = false
	var rig: Node2D = target["rig"]
	if not is_instance_valid(rig):
		return
	_flash_at(_torso(target), Color(1.0, 0.85, 0.5), 18.0)
	var tween := create_tween()
	tween.set_parallel(true)
	if _calm():
		tween.tween_property(rig, "modulate:a", 0.0, 0.8)
		return
	var sprites: Dictionary = target["sprites"]
	for slot in sprites:
		var sprite: Sprite2D = sprites[slot]
		if not is_instance_valid(sprite):
			continue
		var push := Vector2(target["side"] * randf_range(20.0, 70.0), randf_range(-50.0, 10.0))
		if slot == "feet":
			push = Vector2(push.x * 0.2, 6.0)
		tween.tween_property(sprite, "position", sprite.position + push, 0.7) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "rotation", randf_range(-0.9, 0.9), 0.7)
	tween.tween_property(rig, "modulate:a", 0.0, 0.9).set_delay(0.3)


static func _circle(radius: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
