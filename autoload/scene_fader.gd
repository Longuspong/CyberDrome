extends CanvasLayer

## Weicher Bildschirmwechsel (16. Nov. 2026): statt eines harten Schnitts
## blendet das Bild kurz nach Nachtschwarz ab, wechselt die Szene und blendet
## wieder auf. Waehrend der Blende schluckt eine Flaeche alle Eingaben --
## ein zweiter Tipp startet keinen zweiten Wechsel.
##
## Alle Bildschirme wechseln ueber Fader.go(pfad). Bei "Bewegung reduzieren"
## (und ohne Bildschirm) wird sofort gewechselt.

const OUT_SECONDS := 0.12
const IN_SECONDS := 0.22

var _cover: ColorRect
var _busy := false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cover = ColorRect.new()
	_cover.color = Color("#0b0618")
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.modulate.a = 0.0
	_cover.visible = false
	add_child(_cover)


func is_busy() -> bool:
	return _busy


## Wechselt zur Szene ``path`` mit Blende.
func go(path: String) -> void:
	if _busy:
		return
	if Accessibility.reduce_motion or DisplayServer.get_name() == "headless":
		get_tree().change_scene_to_file.call_deferred(path)
		return
	_busy = true
	_cover.visible = true
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	var out := create_tween()
	out.tween_property(_cover, "modulate:a", 1.0, OUT_SECONDS * (1.0 - _cover.modulate.a))
	await out.finished
	get_tree().change_scene_to_file(path)
	# Zwei Bilder warten: im ersten baut die neue Szene ihr _ready, im zweiten
	# steht ihr Layout -- erst dann aufblenden, sonst blitzt der Aufbau durch.
	await get_tree().process_frame
	await get_tree().process_frame
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	var back := create_tween()
	back.tween_property(_cover, "modulate:a", 0.0, IN_SECONDS).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	await back.finished
	if not _busy:
		_cover.visible = false
