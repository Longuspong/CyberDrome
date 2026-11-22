class_name Cinema
extends CanvasLayer

## Kamera fuer Sonderszenen (21. Nov. 2026, Kampfbild mehr 3D C10, Paket 3).
##
## Fuer ein paar Sekunden AUSSERHALB des Kampfes wird die Kamera tief und
## perspektivisch: beim Auftritt der Gegner in einem Elite-Kampf (spaeter
## Bosse) und beim Sieg. Sobald gekaempft wird, gilt wieder die feste
## Iso-Ansicht -- die Lesbarkeit bleibt unangetastet.
##
## Technik: eine eigene Ansicht auf dieselbe 3D-Welt (Arena3D.world) mit
## einer perspektivischen Kamera; den Boden legt Arena3D.build_cinema_floor
## auf eine eigene Ebene, die nur diese Kamera sieht. Die Flaechen der Modelle
## sind fuer die Iso-Sicht gebaut (abgewandte Seiten fehlen), deshalb bleibt
## die Kamera nahe der Iso-Richtung (hoechstens ORBIT_MAX Grad seitlich).
##
## Antippen ueberspringt. Mit "Bewegung reduzieren" gibt es keine Szenen.

const FADE_IN := 0.25
const FADE_OUT := 0.35
const ORBIT_MAX := 20.0
const FOV := 38.0
const BAR_SHARE := 0.11
## Kameraweg je Art: Seitenwinkel (Grad), Hoehenwinkel (Grad), Abstand
## (Welteinheiten) jeweils von/bis, und die Dauer.
const SHOTS := {
	"entrance": {"az": Vector2(-12.0, 6.0), "el": Vector2(18.0, 28.0),
		"dist": Vector2(430.0, 340.0), "time": 2.4},
	"victory": {"az": Vector2(-18.0, 18.0), "el": Vector2(20.0, 24.0),
		"dist": Vector2(380.0, 330.0), "time": 2.6},
}

var arena: Arena3D
var kind := "victory"
## Blickpunkt in der 3D-Welt (Mitte der Gruppe, Bodenhoehe).
var target := Vector3.ZERO
## Halbe Breite der Gruppe (Welteinheiten) -- die Kamera tritt so weit zurueck,
## dass alle im Bild sind.
var spread := 0.0
const SPREAD_BACK := 2.4
var title := ""
var title_color := Color.WHITE
var on_done: Callable = Callable()

var _view: SubViewport
var _cam: Camera3D
var _root: Control
var _t := 0.0
var _leaving := false
var _left := 0.0


## Spielt eine Szene ueber ``parent`` ab; ``done`` wird danach gerufen (auch
## beim Ueberspringen). Gibt null zurueck, wenn keine Szene laeuft (dann ist
## ``done`` schon gerufen).
static func play(parent: Node, on_arena: Arena3D, which: String, at: Vector3,
		text: String, color: Color, done: Callable, group_spread: float = 0.0) -> Cinema:
	if Accessibility.reduce_motion or on_arena == null or not SHOTS.has(which):
		if done.is_valid():
			done.call()
		return null
	var cinema := Cinema.new()
	cinema.name = "Szene"
	cinema.arena = on_arena
	cinema.kind = which
	cinema.target = at
	cinema.spread = group_spread
	cinema.title = text
	cinema.title_color = color
	cinema.on_done = done
	parent.add_child(cinema)
	return cinema


## Kameraort zur Zeit ``k`` (0..1) einer Szene: Iso-Richtung, gedreht um
## ``az``, gehoben um ``el``, im Abstand ``dist`` vom Blickpunkt.
static func camera_place(shot: Dictionary, focus: Vector3, k: float, extra: float = 0.0) -> Vector3:
	var e := ease(clampf(k, 0.0, 1.0), -1.6)
	var az := deg_to_rad(clampf(lerpf(shot["az"].x, shot["az"].y, e), -ORBIT_MAX, ORBIT_MAX))
	var el := deg_to_rad(lerpf(shot["el"].x, shot["el"].y, e))
	var dist := lerpf(shot["dist"].x, shot["dist"].y, e) + extra
	var back := Vector3(-1.0, 0.0, 1.0).normalized().rotated(Vector3.UP, az)
	return focus + back * cos(el) * dist + Vector3.UP * sin(el) * dist


func _ready() -> void:
	layer = 60
	var size := get_viewport().get_visible_rect().size
	_view = SubViewport.new()
	_view.name = "Kamera"
	_view.world_3d = arena.world
	_view.size = Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_cam = Camera3D.new()
	_cam.fov = FOV
	_cam.near = 1.0
	_cam.far = 3000.0
	_cam.cull_mask = DromeModel.LAYER_IMAGE | Arena3D.LAYER_CINEMA_FLOOR
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Arcade.NIGHT
	_cam.environment = env
	_view.add_child(_cam)
	add_child(_view)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.modulate.a = 0.0
	add_child(_root)
	var picture := TextureRect.new()
	picture.texture = _view.get_texture()
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(picture)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0.0, 0.0, 0.0, 0.92)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		if top:
			bar.anchor_bottom = BAR_SHARE
		else:
			bar.anchor_top = 1.0 - BAR_SHARE
			bar.anchor_bottom = 1.0
		_root.add_child(bar)
	if title != "":
		var label := Arcade.label(title, 34, title_color, "display")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.anchor_right = 1.0
		label.anchor_top = 1.0 - BAR_SHARE * 2.2
		label.anchor_bottom = 1.0 - BAR_SHARE
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(label)
	var hint := Arcade.label(tr("Antippen überspringt"), 13, Arcade.MUTED, "medium")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.anchor_left = 0.0
	hint.anchor_right = 0.97
	hint.anchor_top = 1.0 - BAR_SHARE * 0.62
	hint.anchor_bottom = 1.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hint)
	_root.gui_input.connect(_on_input)
	_place_camera(0.0)


func _on_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
		skip()


## Szene abbrechen: kurz ausblenden, dann weiter.
func skip() -> void:
	if not _leaving:
		_leaving = true
		_left = 0.0


func _place_camera(k: float) -> void:
	var shot: Dictionary = SHOTS[kind]
	var focus := target + Vector3.UP * 26.0
	_cam.position = Cinema.camera_place(shot, target, k, spread * SPREAD_BACK)
	_cam.look_at(focus, Vector3.UP)


func _process(delta: float) -> void:
	var shot: Dictionary = SHOTS[kind]
	var total := float(shot["time"])
	_t += delta
	_place_camera(_t / total)
	if _leaving:
		_left += delta
		_root.modulate.a = clampf(1.0 - _left / FADE_OUT, 0.0, 1.0)
		if _left >= FADE_OUT:
			_finish()
		return
	_root.modulate.a = clampf(_t / FADE_IN, 0.0, 1.0)
	if _t >= total:
		skip()


func _finish() -> void:
	set_process(false)
	var done := on_done
	on_done = Callable()
	queue_free()
	if done.is_valid():
		done.call()
