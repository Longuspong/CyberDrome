extends SceneTree
## Rendert Entwuerfe aus .m3d-Modellen mit dem Spiel-Renderer (DromeModel) in
## PNG-Dateien -- ohne Fenster dazwischen (das Projekt skaliert sein Fenster).
##
##   xvfb-run -a godot --path . --script res://docs/design/drome_entwurf/godot/render_main.gd -- \
##       res://docs/design/drome_entwurf/godot/render_shogun.gd /tmp/out/bild /tmp/shogun9
##
## Argumente: Helfer-Skript, Ausgabe-Praefix (bild_0.png, bild_1.png ...),
## Ordner mit den .m3d-Dateien (aus v8/v9_shogun.py bzw. v10_hexboden.py).
## Helfer: RefCounted mit build(root, model_dir) -> Array[SubViewport].

var _f := 0
var _outs: Array = []

func _process(_d: float) -> bool:
	_f += 1
	var args := OS.get_cmdline_user_args()
	if _f == 2:
		_outs = load(args[0]).new().build(root, args[2])
	if _f == 10:
		for i in _outs.size():
			_outs[i].get_texture().get_image().save_png(args[1] + "_%d.png" % i)
		return true
	return false
