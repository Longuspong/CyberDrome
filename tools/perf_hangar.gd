extends SceneTree
## Misst, wie lange ein Wechsel des DROME im Hangar dauert (echtes Rendern,
## 18. Nov. 2026). Je Wechsel: Dauer des Umbaus der Anzeige und die Dauer der
## naechsten Bilder in ms.
##
##     xvfb-run -a -s "-screen 0 600x1000x24" godot --path . --resolution 450x900 \
##         --script res://tools/perf_hangar.gd
var _f := 0
var _last := 0
var _phase := 0
var _switch_at := -1
var _times: Array = []
var _cur := []
var _screen: Node = null
var _n := 0

func _process(_d: float) -> bool:
	_f += 1
	var now := Time.get_ticks_usec()
	if _f == 2:
		change_scene_to_file("res://scenes/hangar.tscn")
	if _f == 40:
		_screen = _find(root)
		print("Hangar: ", _screen, " DROMEs ", root.get_node("GameState").roster.entries.size())
	if _f >= 60 and _f % 20 == 0 and _n < 8 and _screen != null:
		if not _cur.is_empty():
			_times.append(_cur.duplicate())
		_cur = []
		_screen._selected = _n % root.get_node("GameState").roster.entries.size()
		var t0 := Time.get_ticks_usec()
		_screen._select_in_squad(_screen._selected)
		_cur.append((Time.get_ticks_usec() - t0) / 1000.0)
		_n += 1
	elif not _cur.is_empty() and _cur.size() < 6:
		_cur.append((now - _last) / 1000.0)
	_last = now
	if _f > 60 + 20 * 9:
		for t in _times:
			print("refresh %.0f ms, danach Bilder: %s" % [t[0], ", ".join(t.slice(1).map(func(x): return "%.0f" % x))])
		quit(0)
	return false

func _find(n: Node) -> Node:
	if n.has_method("_show_squad"):
		return n
	for c in n.get_children():
		var r := _find(c)
		if r != null:
			return r
	return null
