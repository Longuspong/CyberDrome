class_name MenuArena
extends Node2D

## Die Hintergrund-Inszenierung des Hauptmenues: zwei zufaellig gewuerfelte
## Teams, die einander bearbeiten. Rein DEKORATIV -- kein echter Kampf, keine
## Regel, kein Einfluss auf irgendeinen Spielstand. Es soll nur aussehen, als
## waere im Menue etwas los.
##
## Die Bots kommen aus demselben Generator wie die Gegner im Chaos-Virus
## (EnemyGenerator), damit man im Hintergrund wirklich VERSCHIEDENE Aufbauten
## sieht und nicht viermal denselben. Bewegung und Treffer sind ein kleiner
## Zustandsautomat auf Tweens; wenn eine Seite leer ist, wird frisch gewuerfelt.

## Wie viele je Seite. Klein halten -- es ist Kulisse hinter Knoepfen.
const TEAM_SIZE := 2
const BOT_SCALE := 1.15

## Ein Bot der Kulisse: sein Rig, seine Ruhelage und ob er noch steht.
var _bots: Array = []
var _running := false


func start() -> void:
	if _running:
		return
	_running = true
	_new_round()


func _new_round() -> void:
	for bot in _bots:
		if is_instance_valid(bot["rig"]):
			bot["rig"].queue_free()
	_bots.clear()

	# Zwei getrennte Wuerfe, damit die Seiten nicht gespiegelt sind.
	var left := EnemyGenerator.new(randi()).generate(TEAM_SIZE, 260.0)
	var right := EnemyGenerator.new(randi()).generate(TEAM_SIZE, 260.0)
	for i in left.size():
		_spawn_bot(left[i], -1, i)
	for i in right.size():
		_spawn_bot(right[i], 1, i)

	_schedule_clash()


## Ein Bot je Seite (side -1 = links/„east", 1 = rechts/„west"), gestaffelt in
## der Tiefe, damit sich zwei auf einer Seite nicht exakt ueberdecken.
func _spawn_bot(build: DromeBuild, side: int, row: int) -> void:
	var rig := Node2D.new()
	rig.scale = Vector2(BOT_SCALE, BOT_SCALE)
	DromeSprites.assemble(rig, build, "east" if side < 0 else "west")
	add_child(rig)

	var home := Vector2(
		side * (150.0 + row * 26.0),
		-30.0 + row * 64.0)
	rig.position = home - IsoView.SPRITE_ORIGIN * BOT_SCALE
	rig.z_index = int(home.y)
	_bots.append({"rig": rig, "home": home, "side": side, "alive": true})


func _living(side: int) -> Array:
	return _bots.filter(func(b): return b["alive"] and b["side"] == side)


func _schedule_clash() -> void:
	if not _running:
		return
	var timer := get_tree().create_timer(randf_range(0.9, 1.8))
	timer.timeout.connect(_clash)


func _clash() -> void:
	if not _running:
		return
	var attackers := _living(-1) + _living(1)
	# Ist eine Seite leer, ist die Runde vorbei -- kurz durchatmen, dann neu.
	if _living(-1).is_empty() or _living(1).is_empty():
		var pause := get_tree().create_timer(1.4)
		pause.timeout.connect(_new_round)
		return

	var attacker: Dictionary = attackers[randi() % attackers.size()]
	var targets := _living(-attacker["side"])
	var target: Dictionary = targets[randi() % targets.size()]
	_lunge(attacker, target)
	_schedule_clash()


## Der Angreifer stoesst ein Stueck auf das Ziel zu und wieder zurueck; am
## Umkehrpunkt zuckt das Ziel auf und verliert vielleicht.
func _lunge(attacker: Dictionary, target: Dictionary) -> void:
	var rig: Node2D = attacker["rig"]
	if not is_instance_valid(rig):
		return
	var base: Vector2 = attacker["home"] - IsoView.SPRITE_ORIGIN * BOT_SCALE
	var toward := Vector2((target["home"].x - attacker["home"].x), 0.0).normalized() * 34.0

	var tween := create_tween()
	tween.tween_property(rig, "position", base + toward, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): _impact(target))
	tween.tween_property(rig, "position", base, 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _impact(target: Dictionary) -> void:
	var rig: Node2D = target["rig"]
	if not target["alive"] or not is_instance_valid(rig):
		return
	# Aufblitzen und ein kleiner Ruck nach hinten.
	var flash := create_tween()
	flash.tween_property(rig, "modulate", Color(1.6, 0.6, 0.6, 1.0), 0.06)
	flash.tween_property(rig, "modulate", Color(1, 1, 1, 1), 0.22)
	var kick_from: Vector2 = rig.position
	var kick := create_tween()
	kick.tween_property(rig, "position",
		kick_from + Vector2(target["side"] * 10.0, 0.0), 0.08)
	kick.tween_property(rig, "position", kick_from, 0.18)

	# Ab und zu faellt einer -- dann sinkt er ein und verblasst.
	if randf() < 0.22:
		_ko(target)


func _ko(target: Dictionary) -> void:
	target["alive"] = false
	var rig: Node2D = target["rig"]
	if not is_instance_valid(rig):
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(rig, "modulate:a", 0.0, 0.6)
	tween.tween_property(rig, "scale", Vector2(BOT_SCALE, BOT_SCALE) * 0.85, 0.6)
