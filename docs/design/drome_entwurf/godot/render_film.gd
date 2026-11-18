extends SceneTree
## Nimmt eine Faehigkeit als Film auf (18. Nov. 2026): die echte Arena, zwei
## Seiten DROMEs, AbilityPainter und Angriffsbewegung wie im Kampf; speichert
## jedes STEP-te Bild als PNG (daraus macht ein Python-Schritt ein GIF).
##   xvfb-run -a godot --fixed-fps 60 --path . --script \
##       res://docs/design/drome_entwurf/godot/render_film.gd -- /tmp/out/film ART [BILDER] [STEP]
## ART: vortex barrage lock stun push slash whirl double breaker shield shield_ally

var _f := 0
var _view: SubViewport
var _scene: RefCounted
var _frames := 84
var _step := 3
var _prefix := ""

func _process(_d: float) -> bool:
	_f += 1
	var args := OS.get_cmdline_user_args()
	if _f == 2:
		_prefix = args[0]
		_frames = int(args[2]) if args.size() > 2 else 84
		_step = int(args[3]) if args.size() > 3 else 3
		_scene = load("res://docs/design/drome_entwurf/godot/film_scene.gd").new()
		_view = _scene.build(root, args[1])
	elif _f > 2:
		var k := _f - 3
		_scene.tick(k)
		if k % _step == 0 and k > 0:
			_view.get_texture().get_image().save_png(_prefix + "_%03d.png" % (k / _step))
		if k >= _frames:
			return true
	return false
