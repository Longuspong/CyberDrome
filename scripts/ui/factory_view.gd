class_name FactoryView
extends VBoxContainer

## Reiter "Platine" im Fabrik-Tab (23. Nov. 2026, docs/FACTORY_KONZEPT.md
## Abschnitt 11). Die Logik steckt in ``FactorySim``
## (``GameState.roster.factory_sim()``); hier nur Anzeige und Bedienung.
##
## Fabrikstadt (28. Nov. 2026, Abschnitt 14, Entwurf docs/design/fabrik_stadt):
## die Platine ist eine kleine Stadt in 3D (``FactoryCity``), feste Kamera
## steil von Sueden, ein Feld gut 92 px breit -- die Platine scrollt (Finger
## ziehen) statt zu zoomen. Leuchtflaechen ohne Strom grau, Schilder nur bei
## Problemen (Stau, kein Strom) und fuer das Werkbank-Ziel.
##
## Live laeuft alle ``FactorySim.live_seconds()`` ein Takt, aber nur, solange
## der Reiter offen ist.
##
## Bedienung: unten rechts das Plus; offen stehen links daneben Bauen
## (Sechseck, Kran), Abreissen (Fuenfeck, roter Hammer) und Verschieben
## (Viereck).
##   * Bauen klappt nach oben die fuenf Gruppen aus (Foerdern, Veredeln,
##     Herstellen, Strom, Logistik), eine Gruppe darueber die Reihe ihrer
##     Typen: die Gebaeude selbst in Platinengroesse mit Name und Stand,
##     freigeschaltete nah am Gruppenknopf, gesperrte grau weiter aussen
##     ("AB BASIS T2"), ueber jedem T1 klein und grau das T2. Neu gebaut wird
##     immer T1. Typ waehlen (oder aufs Feld ziehen), Feld tippen = Vorschau
##     mit kuenftigen Leiterbahnen, nochmal tippen = bauen bzw. kaufen und bauen.
##   * Verschieben: Gebaeude ziehen oder antippen und Zielfeld tippen; auf
##     ein belegtes Feld wird getauscht, wenn beide Arten dort passen.
##   * Abreissen: Tipp auf ein Gebaeude reisst es ohne Rueckfrage ab (es geht
##     samt Stufe zurueck in den Besitz, der Puffer ins Lager).
## Ohne Modus: Gebaeude antippen = Blatt mit Details und Aufruesten (T2/T3,
## sobald die Basis die Stufe hat); die Basis zeigt Lager und das Aufruesten
## der Basis. Gesperrte Felder: einmal tippen = Vorschau mit Preis, nochmal = kaufen.

## Modi von rechts nach links neben dem Plus: [id, Name, Symbol, Form].
const MODES := [["build", "Bauen", "fab_bauen", "hex"], ["remove", "Abreißen", "hammer", "pent"],
	["move", "Verschieben", "fab_move", "square"]]
const BTN := 52.0
const GAP := 6.0
## Bildpunkte je Einheit der Fabrikstadt (Entwurf: U = 50, Feld ~92 px breit).
const PX_PER_UNIT := 50.0
## Breite eines Typs in der Typen-Reihe.
const ITEM_W := 100.0
const GREEN := Color("#5cf2a2")

var _sim: FactorySim
var _board: Board
var _head: Label
var _tier_label: Label
var _power_label: Label
var _tick_label: Label
var _stage: Control
var _hint: Label
var _plus: ShapeButton
var _mode_buttons: Dictionary = {}
var _cat_buttons: Dictionary = {}
var _tray: HBoxContainer
var _tray_tween: Tween
var _timer: Timer
## Ziel der Zeilen von ``_row``/``_title`` (ein Popup).
var _box: VBoxContainer

## 3D: Bild, Welt, Kamera, Knoten je Feld ({k: {sig, node}}), Leiterbahnen, Vorschau.
var _view: SubViewportContainer
var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _cells: Dictionary = {}
var _traces_node: Node3D
var _traces_sig := ""
var _ghost_node: Node3D
var _ghost_sig := ""
## Kamerablick auf den Boden (x, z in Welt-Einheiten).
var cam_target := Vector2(0.0, 0.4)

## Gewaehltes Feld (Rahmen + Reichweite), "" = keins.
var selected := ""
## Plus ausgeklappt, Modus ("", "build", "remove", "move"), Gruppe im Baumodus.
var menu_open := false
var mode := ""
var category := ""
## Gewaehlte Gebaeudeart im Baumodus.
var armed := ""
## Vorschau: {"k", "type"} fuers Bauen oder {"chunk": id} fuer Feldgruppen.
var pending: Dictionary = {}
## Leiterbahnen der Bau-Vorschau ([{path, ware}]).
var preview: Array = []
## Verschieben: das gewaehlte Gebaeude.
var move_from := ""
## Waren, die dem Werkbank-Ziel fehlen ({ware: menge}) -- die Platine hebt ihre
## Hersteller mit einer Fahne hervor.
var goal_wares: Dictionary = {}


func _ready() -> void:
	_sim = GameState.roster.factory_sim()
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 14)
	add_child(stats)
	_tier_label = Arcade.label("", 14, UiKit.MUTED, "bold", 0.1)
	_tier_label.tooltip_text = "Stufe der Basis"
	_tier_label.mouse_filter = Control.MOUSE_FILTER_PASS
	stats.add_child(_tier_label)
	var power := UiIcon.text("energy", "", 14, UiKit.MUTED, "bold")
	power.tooltip_text = "Strom: gebraucht / vorhanden"
	power.mouse_filter = Control.MOUSE_FILTER_PASS
	_power_label = power.get_child(1)
	stats.add_child(power)
	var tick := UiIcon.text("reroll", "", 14, UiKit.MUTED, "bold")
	tick.tooltip_text = "Takte"
	tick.mouse_filter = Control.MOUSE_FILTER_PASS
	_tick_label = tick.get_child(1)
	stats.add_child(tick)
	_head = UiKit.label("", UiKit.SMALL, UiKit.MUTED)
	add_child(_head)
	# Hinweiszeile: fest zwei Zeilen hoch, damit die Platine nicht springt.
	_hint = UiKit.label("", UiKit.SMALL, UiKit.MUTED)
	_hint.custom_minimum_size = Vector2(0, 38)
	_hint.max_lines_visible = 2
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_hint)
	_stage = Control.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.custom_minimum_size = Vector2(0, 380)
	_stage.clip_contents = true
	add_child(_stage)
	_build_world()
	_board = Board.new(self)
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(_board)
	_tray = HBoxContainer.new()
	_tray.add_theme_constant_override("separation", 0)
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray.alignment = BoxContainer.ALIGNMENT_END
	_tray.visible = false
	_stage.add_child(_tray)
	for m in MODES:
		var id := str(m[0])
		var button := ShapeButton.new(str(m[3]), str(m[2]), UiKit.BAD if id == "remove" else Arcade.YELLOW)
		button.tooltip_text = str(m[1])
		button.pressed.connect(func(): _choose_mode(id))
		button.visible = false
		_stage.add_child(button)
		_mode_buttons[id] = button
	for g in FactorySim.groups():
		var id := str(g["id"])
		var button := ShapeButton.new("hex", str(g["symbol"]), Arcade.YELLOW, Color("#6e5ab4"))
		button.tooltip_text = str(g["name"])
		button.pressed.connect(func(): _choose_category(id))
		button.visible = false
		_stage.add_child(button)
		_cat_buttons[id] = button
	_plus = ShapeButton.new("plus", "plus", Arcade.YELLOW)
	_plus.tooltip_text = "Bauen, Verschieben, Abreißen"
	_plus.pressed.connect(_toggle_menu)
	_stage.add_child(_plus)
	_stage.resized.connect(func():
		_layout(false)
		_place_camera())
	_timer = Timer.new()
	_timer.wait_time = FactorySim.live_seconds()
	_timer.timeout.connect(_live_tick)
	add_child(_timer)
	_timer.start()
	# Einmal rechnen, damit Status und Strom gleich stehen.
	if _sim.info.is_empty():
		_live_tick()
	else:
		refresh()
	_restyle_controls()
	_say("Antippen zeigt Details · Plus = bauen, verschieben, abreißen", UiKit.MUTED)
	_layout.call_deferred(false)


func _exit_tree() -> void:
	GameState.save_roster()


func _live_tick() -> void:
	_sim.tick()
	GameState.save_roster()
	refresh()


## Nach jedem Takt und jeder Handlung: Kopfzeile, Stadt und Platine.
func refresh() -> void:
	_tier_label.text = "BASIS T%d" % _sim.tier()
	_power_label.text = "%s/%s" % [FactorySim.num(float(_sim.power["used"])),
		FactorySim.num(float(_sim.power["supply"]))]
	_tick_label.text = str(_sim.tick_count())
	_head.text = ""
	goal_wares = {}
	if _sim.goal() != "":
		var bench := Workbench.new(GameState.roster)
		goal_wares = bench.raw_shortfall(_sim.goal())
		var parts: Array = []
		for ware in goal_wares:
			parts.append("%d %s" % [int(goal_wares[ware]), FactorySim.ware_name(str(ware))])
		_head.text = "ZIEL %s: %s" % [bench.name_of(_sim.goal()).to_upper(),
			"fehlt " + ", ".join(parts) if not parts.is_empty() else "alles da – Werkbank"]
	_head.visible = _head.text != ""
	_sync_world()
	_board.queue_redraw()


func _say(text: String, color: Color = UiKit.WARN) -> void:
	_hint.text = text
	_hint.modulate = color


# ---------------------------------------------------------------- 3D-Stadt

func _build_world() -> void:
	_view = SubViewportContainer.new()
	_view.stretch = true
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_view)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_view.add_child(_viewport)
	_world = Node3D.new()
	_world.name = "Fabrikstadt"
	_world.scale = Vector3(1.0, FactoryCity.Y_STRETCH, 1.0)
	_viewport.add_child(_world)
	_world.add_child(FactoryCity.instance(FactoryCity.board_mesh(int(FactorySim.data().get("platine_radius", 3)))))
	_traces_node = Node3D.new()
	_world.add_child(_traces_node)
	_ghost_node = Node3D.new()
	_world.add_child(_ghost_node)
	_camera = FactoryCity.make_camera(PX_PER_UNIT, 400.0)
	_viewport.add_child(_camera)
	_place_camera()


## Kamera auf ``cam_target``, am Rand der Platine gehalten.
func _place_camera() -> void:
	if _camera == null or _stage == null:
		return
	var w := maxf(1.0, _stage.size.x)
	var h := maxf(1.0, _stage.size.y)
	_camera.size = w / PX_PER_UNIT
	var radius := float(FactorySim.data().get("platine_radius", 3))
	var ext_x := 1.5 * radius + 1.2
	var ext_z := FactoryCity.K * radius + 1.4
	var half_w := w / PX_PER_UNIT / 2.0
	var half_h := h / PX_PER_UNIT / 2.0 / FactoryCity.PITCH_SIN
	# Unten verdecken Knopfleiste und Bauleiste einen Teil: dort darf die
	# Platine weiter nach oben rutschen.
	var reserve := bottom_reserve() / PX_PER_UNIT / FactoryCity.PITCH_SIN
	var lim_x := maxf(0.0, ext_x - half_w)
	cam_target.x = clampf(cam_target.x, -lim_x, lim_x)
	var lo := -ext_z + half_h
	var hi := ext_z - half_h + reserve
	if lo > hi:
		cam_target.y = (lo + hi) / 2.0
	else:
		cam_target.y = clampf(cam_target.y, lo, hi)
	FactoryCity.place_camera(_camera, Vector3(cam_target.x, 0.0, cam_target.y))
	if _board != null:
		_board.queue_redraw()


## Bildschirmpunkt eines Weltpunkts (y ungestreckt wie im Entwurf).
func project(x: float, y: float, z: float) -> Vector2:
	if _camera == null or not _camera.is_inside_tree():
		return Vector2.ZERO
	return _camera.unproject_position(Vector3(x, y * FactoryCity.Y_STRETCH, z))


func cell_screen(k: String, y: float = FactoryCity.TILE_H) -> Vector2:
	var p := FactoryCity.key_pos(k)
	return project(p.x, y, p.y)


## Sechseck eines Feldes auf dem Bildschirm (``radius`` in Einheiten).
func cell_hex(k: String, radius: float) -> PackedVector2Array:
	var p := FactoryCity.key_pos(k)
	var out := PackedVector2Array()
	for c in FactoryCity.hex_corners(radius):
		out.append(project(p.x + c.x, FactoryCity.TILE_H, p.y + c.y))
	out.append(out[0])
	return out


## Feld unter einem Bildschirmpunkt.
func key_at(pos: Vector2) -> String:
	if _camera == null or not _camera.is_inside_tree():
		return ""
	var origin := _camera.project_ray_origin(pos)
	var dir := _camera.project_ray_normal(pos)
	if absf(dir.y) < 0.0001:
		return ""
	var t := (FactoryCity.TILE_H * FactoryCity.Y_STRETCH - origin.y) / dir.y
	var hit := origin + dir * t
	return FactoryCity.key_at(hit.x, hit.z)


## Steht ein Gebaeude ohne Strom (Leuchtflaechen grau)?
func building_on(k: String) -> bool:
	var b := _sim.building_at(k)
	if b.is_empty():
		return true
	var d := FactorySim.def(str(b["t"]))
	if d.get("relais", false):
		return bool(b["rel_on"])
	if d.has("brennstoff"):
		return bool(b["on"])
	var inf := _sim.info_of(k)
	return not (float(inf.get("need", 0.0)) > 0.0 and float(inf.get("got", 0.0)) <= 0.0)


## Gleicht die 3D-Knoten mit dem Stand ab: nur geaenderte Felder neu bauen.
func _sync_world() -> void:
	if _world == null:
		return
	for k in FactorySim.cells():
		var sig := _cell_sig(k)
		var entry: Dictionary = _cells.get(k, {})
		if str(entry.get("sig", "")) == sig:
			continue
		if entry.has("node"):
			(entry["node"] as Node).queue_free()
		_cells[k] = {"sig": sig, "node": _cell_node(k)}
	var traces := _sim.traces()
	var tsig := ""
	for tr in traces:
		tsig += "%s:%s:%s;" % [",".join(tr["path"]), tr["ware"], trace_jammed(tr)]
	if tsig != _traces_sig:
		_traces_sig = tsig
		for child in _traces_node.get_children():
			child.queue_free()
		for tr in traces:
			var pts := PackedVector2Array()
			for k in tr["path"]:
				pts.append(FactoryCity.key_pos(str(k)))
			_traces_node.add_child(FactoryCity.instance(FactoryCity.trace_mesh(pts,
				FactorySim.ware_color(str(tr["ware"])), trace_jammed(tr))))
	var gsig := ""
	if pending.has("k"):
		gsig = "%s|%s" % [pending["k"], pending["type"]]
	if gsig != _ghost_sig:
		_ghost_sig = gsig
		for child in _ghost_node.get_children():
			child.queue_free()
		if gsig != "":
			var p := FactoryCity.key_pos(str(pending["k"]))
			_ghost_node.add_child(FactoryCity.instance(FactoryCity.building_mesh(str(pending["type"]), 1,
				true, true), Vector3(p.x, 0.0, p.y)))


func _cell_sig(k: String) -> String:
	if not _sim.unlocked(k):
		return "locked|%s" % FactorySim.source_at(k)
	if k == FactorySim.net_cell():
		return "basis|%d" % _sim.tier()
	var b := _sim.building_at(k)
	if b.is_empty():
		return "free|%s" % FactorySim.source_at(k)
	return "b|%s|%d|%s" % [b["t"], int(b.get("lv", 1)), building_on(k)]


func _cell_node(k: String) -> Node3D:
	var p := FactoryCity.key_pos(k)
	var node := Node3D.new()
	node.position = Vector3(p.x, 0.0, p.y)
	_world.add_child(node)
	var src := FactorySim.source_at(k)
	if not _sim.unlocked(k):
		node.add_child(FactoryCity.instance(FactoryCity.tile_mesh("locked")))
		if src != "":
			node.add_child(FactoryCity.instance(FactoryCity.deposit_mesh(src, true)))
		return node
	if k == FactorySim.net_cell():
		node.add_child(FactoryCity.instance(FactoryCity.tile_mesh("built", ["logistik"], _sim.tier())))
		node.add_child(FactoryCity.instance(FactoryCity.building_mesh("basis", _sim.tier())))
		return node
	var b := _sim.building_at(k)
	if b.is_empty():
		node.add_child(FactoryCity.instance(FactoryCity.tile_mesh("free")))
		if src != "":
			node.add_child(FactoryCity.instance(FactoryCity.deposit_mesh(src, false)))
		return node
	var type := str(b["t"])
	var lv := int(b.get("lv", 1))
	node.add_child(FactoryCity.instance(FactoryCity.tile_mesh("built", FactorySim.lines_of(type), lv)))
	node.add_child(FactoryCity.instance(FactoryCity.building_mesh(type, lv, building_on(k))))
	return node


## Leiterbahn gestaut: der Abnehmer hat im letzten Takt nichts davon bekommen.
func trace_jammed(tr: Dictionary) -> bool:
	var path: Array = tr["path"]
	var hist: Array = _sim.info_of(str(path[path.size() - 1])).get("in_h", [])
	return hist.is_empty() or float((hist.back() as Dictionary).get(tr["ware"], 0)) <= 0.0


## Schild ueber einem Gebaeude: "jam" (Stau), "off" (kein Strom), "flag" (Ziel), "" = keins.
func badge_of(k: String) -> String:
	var b := _sim.building_at(k)
	if b.is_empty():
		return ""
	var d := FactorySim.def(str(b["t"]))
	if str(_sim.info_of(k).get("status", "")) == "strom":
		return "off"
	if _sim.engpass == k:
		return "jam"
	for ware in d.get("aus", {}):
		if goal_wares.has(ware):
			return "flag"
	return ""


# ---------------------------------------------------------------- Knoepfe

func _restyle_controls() -> void:
	_plus.icon_name = "close" if menu_open else "plus"
	_plus.queue_redraw()
	for id in _mode_buttons:
		(_mode_buttons[id] as ShapeButton).set_active(mode == id)
	for id in _cat_buttons:
		(_cat_buttons[id] as ShapeButton).set_active(category == id)


## Unten verdeckter Platz (Knopfleiste, Gruppen, Typen) -- die Platine darf
## so weit hochrutschen.
func bottom_reserve() -> float:
	var r := BTN + 10.0
	if menu_open and mode == "build":
		r += BTN + 8.0
		if category != "":
			r += 170.0
	return r


## Rechts das Plus, links daneben die Modi; darueber die Gruppen, darueber
## die Typen der gewaehlten Gruppe.
func _layout(animate: bool = true) -> void:
	if _stage == null or _plus == null:
		return
	var w := _stage.size.x
	var h := _stage.size.y
	var y := h - BTN - 4.0
	_plus.position = Vector2(w - BTN - 4.0, y)
	var moving := animate and Accessibility.motion() > 0.0
	var x := w - BTN - 4.0
	for m in MODES:
		var b: ShapeButton = _mode_buttons[str(m[0])]
		x -= b.size.x + GAP
		_show(b, menu_open, Vector2(x, y + (BTN - b.size.y) / 2.0), _plus.position, moving)
	var groups := FactorySim.groups()
	var show_cats := menu_open and mode == "build"
	var gy := y - BTN - 8.0
	var total := groups.size() * BTN + (groups.size() - 1) * GAP
	var gx := clampf(w - BTN - 4.0 - total, 4.0, maxf(4.0, w - total - 4.0))
	for i in groups.size():
		var b: ShapeButton = _cat_buttons[str(groups[i]["id"])]
		_show(b, show_cats, Vector2(gx + i * (BTN + GAP), gy), _mode_buttons["build"].position, moving)
	var show_tray := show_cats and category != ""
	if show_tray:
		_tray.reset_size()
		var tsize := _tray.get_combined_minimum_size()
		_tray.size = tsize
		var under: ShapeButton = _cat_buttons[category]
		var center := under.position.x + BTN / 2.0
		var tx: float
		if center < w / 2.0:
			tx = clampf(center - ITEM_W / 2.0, 4.0, maxf(4.0, w - 4.0 - tsize.x))
		else:
			tx = clampf(center + ITEM_W / 2.0 - tsize.x, 4.0, maxf(4.0, w - 4.0 - tsize.x))
		var target := Vector2(tx, gy - tsize.y - 4.0)
		if _tray_tween != null and _tray_tween.is_valid():
			_tray_tween.kill()
		if not _tray.visible and moving:
			_tray.position = Vector2(tx, h)
			_tray.visible = true
			_tray_tween = _tray.create_tween()
			_tray_tween.tween_property(_tray, "position:y", target.y, 0.2) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			_tray.visible = true
			_tray.position = target
	else:
		_tray.visible = false
	_place_camera()


func _show(b: Control, visible_now: bool, target: Vector2, from: Vector2, moving: bool) -> void:
	if not visible_now:
		if b.visible and moving:
			var tween := b.create_tween().set_parallel()
			tween.tween_property(b, "position", from, 0.12)
			tween.tween_property(b, "modulate:a", 0.0, 0.12)
			tween.chain().tween_callback(func(): b.visible = false)
		else:
			b.visible = false
		return
	if not b.visible and moving:
		b.position = from
		b.modulate.a = 0.0
		b.visible = true
		var tween := b.create_tween().set_parallel()
		tween.tween_property(b, "position", target, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(b, "modulate:a", 1.0, 0.12)
	else:
		b.visible = true
		b.modulate.a = 1.0
		b.position = target


# ---------------------------------------------------------------- Modi

func _toggle_menu() -> void:
	Accessibility.tap()
	menu_open = not menu_open
	_leave_mode()
	_say("Modus wählen" if menu_open else "", UiKit.MUTED)
	_restyle_controls()
	_layout()
	refresh()


func _leave_mode() -> void:
	mode = ""
	category = ""
	armed = ""
	pending = {}
	preview = []
	move_from = ""


func _choose_mode(id: String) -> void:
	Accessibility.tap()
	var was := mode
	_leave_mode()
	if was != id:
		mode = id
	match mode:
		"build": _say("Gruppe wählen", UiKit.MUTED)
		"move": _say("Gebäude tippen oder ziehen, dann das Ziel-Feld", UiKit.MUTED)
		"remove": _say("Gebäude tippen = abreißen (geht in den Besitz zurück)", UiKit.BAD)
		_: _say("Modus wählen", UiKit.MUTED)
	_restyle_controls()
	_layout()
	refresh()


func _choose_category(id: String) -> void:
	Accessibility.tap()
	category = "" if category == id else id
	armed = ""
	pending = {}
	preview = []
	if category != "":
		_build_tray()
		_tray.visible = false    # damit es neu hochfaehrt
		_say("%s: Typ wählen · gebaut wird immer T1" % _group_name(category), UiKit.MUTED)
		# Wie im Prototyp: die Platine rutscht hoch, damit die Reihe nichts verdeckt.
		cam_target.y = maxf(cam_target.y, 2.4)
	else:
		_say("Gruppe wählen", UiKit.MUTED)
	_restyle_controls()
	_layout()
	refresh()


static func _group_name(id: String) -> String:
	for g in FactorySim.groups():
		if str(g["id"]) == id:
			return str(g["name"])
	return id


## Typen der Gruppe: freigeschaltete zuerst (nah am Gruppenknopf), gesperrte danach.
func ordered_types(group: String) -> Array:
	var open: Array = []
	var locked: Array = []
	for type in FactorySim.types_in(group):
		if FactorySim.basis_of(type) > _sim.tier():
			locked.append(type)
		else:
			open.append(type)
	return open + locked


## "bereit" = freies Exemplar im Besitz, "kaufen" = freigeschaltet, aber keins
## uebrig, "gesperrt" = erst ab hoeherer Basis-Stufe.
func type_state(type: String) -> String:
	if FactorySim.basis_of(type) > _sim.tier():
		return "gesperrt"
	return "bereit" if _sim.best_free_level(type) > 0 else "kaufen"


func _build_tray() -> void:
	UiKit.clear(_tray)
	var types := ordered_types(category)
	# Links der Bildmitte waechst die Reihe nach rechts, sonst nach links --
	# der erste (freigeschaltete) Typ steht immer am Gruppenknopf.
	var under: ShapeButton = _cat_buttons.get(category)
	if under != null and under.position.x + BTN / 2.0 >= _stage.size.x / 2.0:
		types.reverse()
	for type in types:
		_tray.add_child(_item(str(type)))
	# Die Groesse steht erst, wenn die Schriften im Baum sind.
	_layout.call_deferred(false)


## Ein Typ in der Reihe: oben klein T2 (grau), darunter das Gebaeude auf
## seinem Feld, Name und Stand. Tippen waehlt, ziehen legt es aufs Feld.
func _item(type: String) -> Control:
	var d := FactorySim.def(type)
	var state := type_state(type)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(ITEM_W, 0)
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if state != "gesperrt":
		var next := ItemButton.new(self, type, 2, 46.0, true)
		next.tooltip_text = "%s T2" % str(d["name"])
		next.pressed.connect(func():
			Accessibility.tap()
			_say("%s T2: Aufrüsten auf der Platine, ab Basis T2." % str(d["name"]), Arcade.YELLOW))
		var t2 := Arcade.label("T2", 11, Color("#8f80bd"), "bold", 0.14)
		t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(t2)
		col.add_child(next)
	var main := ItemButton.new(self, type, 1, 88.0, state == "gesperrt")
	main.tooltip_text = str(d["name"])
	main.highlight = armed == type
	main.pressed.connect(func(): _arm(type))
	col.add_child(main)
	var name := Arcade.label(str(d["name"]), 13, Arcade.YELLOW if armed == type
		else (Color("#8f80bd") if state == "gesperrt" else Color("#fff7fe")), "bold")
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_constant_override("outline_size", 4)
	name.add_theme_color_override("font_outline_color", UiKit.BG)
	col.add_child(name)
	var sub := "KAUFEN"
	var sub_col := UiKit.MUTED
	if state == "gesperrt":
		sub = "AB BASIS T%d" % FactorySim.basis_of(type)
		sub_col = Color("#8f80bd")
	elif state == "bereit":
		sub = "%d FREI" % (_sim.owned(type) - _sim.placed(type))
		sub_col = GREEN
	var line := Arcade.label(sub, 11, sub_col, "bold", 0.02)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_constant_override("outline_size", 4)
	line.add_theme_color_override("font_outline_color", UiKit.BG)
	col.add_child(line)
	return col


## Gebaeude im Baumodus waehlen; nochmal tippen = Details.
func _arm(type: String) -> void:
	Accessibility.tap()
	if armed == type:
		_open_type_details(type)
		return
	var d := FactorySim.def(type)
	if type_state(type) == "gesperrt":
		_say("%s kommt mit Basis T%d." % [str(d["name"]), FactorySim.basis_of(type)], Arcade.YELLOW)
		return
	armed = type
	pending = {}
	preview = []
	match type_state(type):
		"bereit":
			_say("%s gewählt · %d frei · Feld tippen = Vorschau" % [str(d["name"]),
				_sim.owned(type) - _sim.placed(type)], Arcade.YELLOW)
		_:
			_say("%s T1 gewählt · %s · Feld tippen = Vorschau" % [str(d["name"]),
				FactorySim.amounts_text(d.get("preis", {}))], Arcade.YELLOW)
	_build_tray()
	_layout(false)
	refresh()


# ---------------------------------------------------------------- Tippen

## Ein Tipp auf die Platine.
func tapped(k: String) -> void:
	if k not in FactorySim.cells():
		selected = ""
		pending = {}
		preview = []
		move_from = ""
		refresh()
		return
	if not _sim.unlocked(k):
		_tap_locked(k)
	else:
		match mode:
			"build": _tap_build(k)
			"remove": _tap_remove(k)
			"move": _tap_move(k)
			_: _tap_look(k)
	refresh()


func _tap_look(k: String) -> void:
	pending = {}
	preview = []
	selected = k
	if k == FactorySim.net_cell():
		_say("")
		_open_basis()
	elif not _sim.building_at(k).is_empty():
		_say("")
		_open_building_details(k)
	else:
		var src := FactorySim.source_at(k)
		_say("%s · %s" % [FactorySim.source_name(src), FactorySim.ware_name(FactorySim.source_ware(src))]
			if src != "" else "", UiKit.MUTED)


func _tap_locked(k: String) -> void:
	var c := FactorySim.chunk_of(k)
	if c.is_empty():
		return
	var id := str(c["id"])
	var price: Dictionary = c.get("preis", {})
	preview = []
	if int(c.get("tier", 1)) > _sim.tier():
		pending = {}
		_say("Felder %s erst ab Basis T%d." % [str(c["name"]), int(c["tier"])], UiKit.MUTED)
		return
	if str(pending.get("chunk", "")) == id:
		var gap := _sim.missing(price)
		if not gap.is_empty():
			_say("Felder %s: fehlt %s." % [str(c["name"]), FactorySim.amounts_text(gap)], UiKit.BAD)
			return
		var why := _sim.buy_chunk(id)
		pending = {}
		_say(why if why != "" else "Felder %s gekauft." % str(c["name"]), UiKit.BAD if why != "" else GREEN)
		if why == "":
			GameState.save_roster()
		return
	pending = {"chunk": id}
	selected = ""
	var gap := _sim.missing(price)
	if gap.is_empty():
		_say("Felder %s · %s · nochmal tippen kauft" % [str(c["name"]), FactorySim.amounts_text(price)], GREEN)
	else:
		_say("Felder %s · %s · fehlt %s" % [str(c["name"]), FactorySim.amounts_text(price),
			FactorySim.amounts_text(gap)], UiKit.BAD)


func _tap_build(k: String) -> void:
	if armed == "":
		_say("Erst einen Typ wählen." if category != "" else "Gruppe wählen", UiKit.MUTED)
		return
	if str(pending.get("k", "")) == k and str(pending.get("type", "")) == armed:
		_confirm_build()
		return
	show_build_preview(k, armed)


## Vorschau einer Art auf einem Feld (auch beim Ziehen aus der Reihe).
func show_build_preview(k: String, type: String) -> void:
	var why := _sim.fits(k, type)
	if why == "" and not _sim.building_at(k).is_empty():
		why = "Hier steht schon etwas."
	if why != "":
		pending = {}
		preview = []
		_say(why, UiKit.MUTED)
		return
	pending = {"k": k, "type": type}
	preview = _sim.preview_traces(k, type)
	selected = ""
	var d := FactorySim.def(type)
	var links := _preview_text()
	match pending_state():
		"own":
			_say("%s aus dem Besitz setzen%s · nochmal tippen bestätigt" % [str(d["name"]), links], GREEN)
		"buy":
			_say("%s kaufen und setzen · %s%s · nochmal tippen bestätigt" % [str(d["name"]),
				FactorySim.amounts_text(d.get("preis", {})), links], GREEN)
		_:
			_say("%s · fehlt %s%s" % [str(d["name"]), FactorySim.amounts_text(pending_missing()), links], UiKit.BAD)


func _preview_text() -> String:
	var parts: Array = []
	for tr in preview:
		var path: Array = tr["path"]
		var from := _sim.building_at(str(path[0]))
		var name := str(FactorySim.def(str(from["t"]))["name"]) if not from.is_empty() \
			else str(FactorySim.def(str(pending.get("type", "")))["name"])
		parts.append("%s %s" % [FactorySim.ware_name(str(tr["ware"])),
			"von " + name if str(path[0]) != str(pending.get("k", "")) else "an " + _name_at(str(path[path.size() - 1]))])
	if parts.is_empty():
		return " · keine Verbindung"
	return " · " + ", ".join(parts)


func _name_at(k: String) -> String:
	var b := _sim.building_at(k)
	return str(FactorySim.def(str(b["t"]))["name"]) if not b.is_empty() else "?"


## "own" = aus dem Besitz, "buy" = kaufen und setzen, "poor" = zu wenig im Lager.
func pending_state() -> String:
	var type := str(pending.get("type", ""))
	if type == "":
		return ""
	if _sim.best_free_level(type) > 0:
		return "own"
	return "buy" if pending_missing().is_empty() else "poor"


func pending_missing() -> Dictionary:
	if pending.has("chunk"):
		var c := {}
		for entry in FactorySim.chunks():
			if str(entry["id"]) == str(pending["chunk"]):
				c = entry
		return _sim.missing(c.get("preis", {}))
	var type := str(pending.get("type", ""))
	return _sim.missing(FactorySim.def(type).get("preis", {})) if type != "" else {}


func _confirm_build() -> void:
	var k := str(pending["k"])
	var type := str(pending["type"])
	var name := str(FactorySim.def(type)["name"])
	var why := ""
	match pending_state():
		"own": why = _sim.place(k, type)
		"buy": why = _sim.buy_and_place(k, type)
		_:
			_say("%s: fehlt %s." % [name, FactorySim.amounts_text(pending_missing())], UiKit.BAD)
			return
	if why != "":
		_say(why, UiKit.BAD)
		return
	Accessibility.vibrate(20)
	pending = {}
	preview = []
	selected = k
	GameState.save_roster()
	_say("%s T%d gebaut." % [name, _sim.level_at(k)], GREEN)
	_build_tray()
	_layout(false)


func _tap_remove(k: String) -> void:
	var b := _sim.building_at(k)
	if b.is_empty():
		_say("Die Basis bleibt stehen." if k == FactorySim.net_cell() else "", UiKit.MUTED)
		return
	var name := str(FactorySim.def(str(b["t"]))["name"])
	_sim.remove(k)
	Accessibility.vibrate(15)
	selected = ""
	GameState.save_roster()
	_say("%s abgerissen" % name, UiKit.BAD)


func _tap_move(k: String) -> void:
	if move_from == "":
		if _sim.building_at(k).is_empty():
			_say("")
			return
		move_from = k
		selected = k
		_say("%s · Ziel-Feld tippen" % _name_at(k), Arcade.YELLOW)
		return
	if k == move_from:
		move_from = ""
		selected = ""
		_say("")
		return
	move_to(move_from, k)


## Verschieben bzw. tauschen (Tippen oder Ziehen).
func move_to(from: String, to: String) -> void:
	var name := _name_at(from)
	var swap := not _sim.building_at(to).is_empty()
	var other := _name_at(to) if swap else ""
	var why := _sim.move(from, to)
	if why != "":
		_say(why, UiKit.BAD)
		return
	Accessibility.vibrate(15)
	move_from = ""
	selected = to
	GameState.save_roster()
	_say(("%s und %s getauscht." % [name, other]) if swap else "%s verschoben." % name, GREEN)


## Darf ``from`` auf ``to`` (frei oder tauschbar)? Fuer die Markierung.
func move_target_ok(from: String, to: String) -> bool:
	var a := _sim.building_at(from)
	if a.is_empty() or from == to or _sim.fits(to, str(a["t"])) != "":
		return false
	var b := _sim.building_at(to)
	return b.is_empty() or _sim.fits(from, str(b["t"])) == ""


## Aus der Reihe aufs Feld gezogen: Bau-Vorschau (bestaetigt wird per Tipp).
func drop_type(k: String, type: String) -> void:
	if type_state(type) == "gesperrt":
		return
	armed = type
	show_build_preview(k, type)
	_build_tray()
	_layout(false)
	refresh()


## Aufruesten aus dem Gebaeude-Blatt (Abschnitt 14). "" = geklappt.
func upgrade_at(k: String) -> String:
	var name := _name_at(k)
	var why := _sim.upgrade(k)
	if why != "":
		_say(why, UiKit.BAD)
		return why
	Accessibility.vibrate(20)
	GameState.save_roster()
	_say("%s auf T%d aufgerüstet." % [name, _sim.level_at(k)], GREEN)
	refresh()
	return ""


# ---------------------------------------------------------------- Popups

func _open_type_details(type: String) -> void:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	_box = body
	_tool_info(type)
	InfoPopup.open(self, "", {"sheet": true, "body": body})


func _open_building_details(k: String) -> void:
	var b := _sim.building_at(k)
	if b.is_empty():
		return
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	_box = body
	_building_info(k, b)
	var actions: Array = []
	var lv := int(b.get("lv", 1))
	if lv < FactorySim.MAX_LEVEL:
		var type := str(b["t"])
		var cost := FactorySim.upgrade_cost(type, lv + 1)
		body.add_child(Arcade.label("AUFRÜSTEN AUF T%d" % (lv + 1), 14, Arcade.CYAN, "bold", 0.2))
		_row(FactorySim.recipe_text(type, lv + 1) + _power_text(type, lv + 1))
		for ware in cost:
			var have := _sim.have(str(ware))
			_row("%s  %d / %d" % [FactorySim.ware_name(str(ware)), mini(have, int(cost[ware])), int(cost[ware])],
				UiKit.GOOD if have >= int(cost[ware]) else UiKit.TEXT, 14)
		var why := _sim.can_upgrade(k)
		if _sim.tier() < lv + 1:
			_row("T%d erst ab Basis T%d." % [lv + 1, lv + 1], UiKit.WARN)
		actions.append({"text": "Auf T%d" % (lv + 1), "primary": why == "", "disabled": why != "",
			"call": func(): upgrade_at(k)})
	InfoPopup.open(self, "", {"sheet": true, "body": body, "actions": actions})


static func _power_text(type: String, lv: int) -> String:
	var d := FactorySim.def_at(type, lv)
	if float(d.get("strom", 0)) > 0.0:
		return " · braucht %s Strom" % FactorySim.num(float(d["strom"]))
	return ""


## Die Basis: Strom, Lager und Aufruesten = naechste Basis-Stufe.
func _open_basis() -> void:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	_box = body
	var netz: Dictionary = FactorySim.data().get("netz", {})
	var si: Dictionary = _sim.source_info.get(FactorySim.net_cell(), {})
	_row("Strom %s/%d · Reichweite %d" % [FactorySim.num(float(si.get("used", 0.0))), int(netz.get("strom", 4)),
		int(netz.get("reichweite", 2))], UiKit.MUTED)
	_store_into(body)
	var actions: Array = []
	var goal := _sim.next_tier_goal()
	if goal.is_empty():
		body.add_child(Arcade.label("ALLE STUFEN FREI", 14, Arcade.CYAN, "bold", 0.2))
	else:
		body.add_child(Arcade.label("BASIS T%d" % int(goal["tier"]), 14, Arcade.CYAN, "bold", 0.2))
		_row(str(goal.get("text", "")), UiKit.MUTED, 14)
		if str(goal.get("weg", "fabrik")) == "fabrik":
			var cost: Dictionary = goal.get("kosten", {})
			for ware in cost:
				var have := _sim.have(str(ware))
				_row("%s  %d / %d" % [FactorySim.ware_name(str(ware)), mini(have, int(cost[ware])), int(cost[ware])],
					UiKit.GOOD if have >= int(cost[ware]) else UiKit.TEXT, 14)
			# Gelb erst, wenn es geht; die Voraussetzungen stehen darueber.
			var ready := _sim.can_pay(cost)
			actions.append({"text": "Aufrüsten", "primary": ready, "disabled": not ready,
				"call": func():
					var why := _sim.unlock_tier()
					_say(why if why != "" else "Basis aufgerüstet: T%d!" % _sim.tier(),
						UiKit.BAD if why != "" else GREEN)
					GameState.save_roster()
					refresh()})
	InfoPopup.open(self, "Basis · T%d" % _sim.tier(), {"sheet": true, "body": body, "actions": actions})


func _store_into(box: VBoxContainer) -> void:
	box.add_child(Arcade.label("LAGER", 14, Arcade.CYAN, "bold", 0.2))
	var mission := FactorySim.ticks_per_battle() * RunState.rounds_total()
	var proj := _sim.projection(mission)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	var note := UiKit.label("", 13, UiKit.MUTED)
	note.visible = false
	for ware in FactorySim.wares():
		var n := _sim.have(str(ware))
		var line := "%s  %d" % [FactorySim.ware_name(str(ware)), n]
		if int(proj.get(ware, 0)) > 0:
			line += " (+%d)" % int(proj[ware])
		var label := UiKit.label(line, 14, FactorySim.ware_color(str(ware)) if n > 0 else UiKit.MUTED)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(label)
		# Die Zahl in Klammern erklaert sich erst auf Tipp (Wunsch des Spielers).
		if int(proj.get(ware, 0)) > 0:
			var amount := int(proj[ware])
			var name := FactorySim.ware_name(str(ware))
			label.mouse_filter = Control.MOUSE_FILTER_STOP
			label.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					note.text = "+%d %s je Einsatz (Hochrechnung)" % [amount, name]
					note.visible = true)
	box.add_child(note)


# ---------------------------------------------------------------- Info-Zeilen

func _row(text: String, color: Color = UiKit.TEXT, size: int = UiKit.SMALL) -> Label:
	var label := UiKit.label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(label)
	return label


func _title(name: String, color: Color) -> void:
	_box.add_child(Arcade.label(name.strip_edges().to_upper(), 16, color, "bold", 0.1))


func _building_info(k: String, b: Dictionary) -> void:
	var type := str(b["t"])
	var lv := int(b.get("lv", 1))
	var d := FactorySim.def_at(type, lv)
	var inf := _sim.info_of(k)
	var res := _sim.resonance(k)
	_title("%s · T%d" % [str(d["name"]), lv], Color(str(d["farbe"])))
	_row(FactorySim.recipe_text(type, lv))
	var status := _sim.status_text(k)
	if res > 0.0:
		status += " · Resonanz +%d %%" % int(roundf(res * 100.0))
	if d.has("liefert") and not d.has("brennstoff") and not d.get("batterie", false) and _sim.shaded(k):
		status += " · Schatten: nur halber Strom"
	_row(status, _status_color(str(inf.get("status", "ok"))))
	var factor := int(FactorySim.setting("eingang_mal_rezept", 10))
	for ware in d.get("ein", {}):
		var per := 1.0 if d.has("brennstoff") else float(d["ein"][ware]) * float(d.get("rate", 1)) * (1.0 + res)
		_row("%s: braucht %s/Takt · kommt %s/Takt · Puffer %d/%d" % [FactorySim.ware_name(str(ware)),
			FactorySim.num(per), FactorySim.num(_sim.avg_in(k, str(ware))), int(b["in"].get(ware, 0)),
			int(d["ein"][ware]) * factor], UiKit.MUTED)
	if d.has("aus"):
		var per_tick := _sim.avg_out(k)
		var mission := FactorySim.ticks_per_battle() * RunState.rounds_total()
		_row("Ausstoß: %s Durchläufe/Takt (max %s) · ≈ %d je Einsatz" % [FactorySim.num(per_tick),
			FactorySim.num(float(d.get("rate", 1)) * (1.0 + res)), int(roundf(per_tick * mission))], UiKit.MUTED)
		var outs: Array = []
		for ware in d["aus"]:
			outs.append("%s %d/%d" % [FactorySim.ware_name(str(ware)), int(b["out"].get(ware, 0)),
				int(FactorySim.setting("ausgang", 10))])
		_row("Ausgang: " + " · ".join(outs), UiKit.MUTED)
		var up := _sim.avg_up(k)
		if not up.is_empty():
			var ups: Array = []
			for ware in up:
				ups.append("+%s %s" % [FactorySim.num(float(up[ware])), FactorySim.ware_name(str(ware))])
			_row("Per Uplink ins Lager: %s je Takt" % ", ".join(ups), UiKit.WARN)
	if float(d.get("strom", 0)) > 0.0:
		_row("Strom: bekommt %s von %s" % [FactorySim.num(float(inf.get("got", 0.0))),
			FactorySim.num(float(inf.get("need", 0.0)))] if float(inf.get("need", 0.0)) > 0.0
			else "Strom: braucht %s (gerade nichts zu tun)" % FactorySim.num(float(d["strom"])), UiKit.MUTED)
	if d.has("liefert"):
		var si: Dictionary = _sim.source_info.get(k, {})
		_row("Abgabe: %s von %s Strom · Reichweite %d (gelb markiert)" % [
			FactorySim.num(float(si.get("used", 0.0))), FactorySim.num(float(si.get("cap", 0.0))),
			int(d.get("reichweite", 0))], UiKit.MUTED)
	if d.get("batterie", false):
		_row("Ladung: %s / %d" % [FactorySim.num(float(b["charge"])), int(d.get("speicher", 20))], UiKit.MUTED)
	if d.has("brennstoff"):
		_row("Brenner: " + ("gezündet" if b["on"] else "aus, zündet bei %d %s" % [
			int(FactorySim.setting("zuenden_bei", 5)), FactorySim.ware_name(str(d["brennstoff"]))]), UiKit.MUTED)


func _tool_info(type: String) -> void:
	var d := FactorySim.def(type)
	_title("%s · T1" % str(d["name"]), Color(str(d["farbe"])))
	_row(FactorySim.recipe_text(type) + _power_text(type, 1))
	_row(str(d.get("text", "Holt seine Zutaten bei den Nachbarn ab.")), UiKit.MUTED)
	for lv in range(2, FactorySim.MAX_LEVEL + 1):
		_row("T%d: %s%s · Aufrüsten %s (ab Basis T%d)" % [lv, FactorySim.recipe_text(type, lv),
			_power_text(type, lv), FactorySim.amounts_text(FactorySim.upgrade_cost(type, lv)), lv], UiKit.MUTED, 14)
	_row("Besitz %d · gebaut %d · Preis je Stück %s" % [_sim.owned(type), _sim.placed(type),
		FactorySim.amounts_text(d.get("preis", {}))], UiKit.MUTED)
	if FactorySim.basis_of(type) > _sim.tier():
		_row("Erst ab Basis T%d." % FactorySim.basis_of(type), UiKit.WARN)


static func _status_color(status: String) -> Color:
	match status:
		"anlauf": return Color("#9d84ff")
		"wait": return UiKit.MAGENTA
		"strom": return Color("#ff6a3d")
		"uplink": return UiKit.WARN
		"relay": return Color("#9d84ff")
	return UiKit.ACCENT


# ---------------------------------------------------------------- Knopfformen

## Knopf als Form (Abschnitt 14): "hex" (Sechseck, Spitze oben), "pent"
## (Fuenfeck), "square" (Viereck) oder "plus" (gelbes Plus mit Schatten).
## Aktiv = gefuellt in der Signalfarbe, das Symbol dunkel.
class ShapeButton extends Button:
	var shape := "square"
	var icon_name := ""
	var color := Color.WHITE
	var rim := Color.WHITE
	var active := false

	func _init(form: String, symbol: String, signal_color: Color, rim_color: Color = Color(0, 0, 0, 0)) -> void:
		shape = form
		icon_name = symbol
		color = signal_color
		rim = rim_color if rim_color.a > 0.0 else signal_color
		focus_mode = Control.FOCUS_NONE
		flat = true
		var w := 56.0 if form == "hex" else (58.0 if form == "pent" else 52.0)
		var h := 60.0 if form == "hex" and symbol == "fab_bauen" else (56.0 if form == "pent" else 52.0)
		custom_minimum_size = Vector2(w, h)
		size = custom_minimum_size
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())

	func set_active(on: bool) -> void:
		active = on
		queue_redraw()

	func _points(inset: float) -> PackedVector2Array:
		var w := size.x
		var h := size.y
		var raw: Array
		match shape:
			"hex": raw = [Vector2(0.5, 0), Vector2(1, 0.25), Vector2(1, 0.75), Vector2(0.5, 1), Vector2(0, 0.75), Vector2(0, 0.25)]
			"pent": raw = [Vector2(0.5, 0), Vector2(1, 0.38), Vector2(0.82, 1), Vector2(0.18, 1), Vector2(0, 0.38)]
			_: raw = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		var c := Vector2(w, h) / 2.0
		var out := PackedVector2Array()
		for p in raw:
			var q := Vector2(p.x * w, p.y * h)
			out.append(q + (c - q).normalized() * inset)
		return out

	func _draw() -> void:
		if shape == "plus":
			var cut := 12.0
			var pts := PackedVector2Array([Vector2(cut, 0), Vector2(size.x, 0), Vector2(size.x, size.y - cut),
				Vector2(size.x - cut, size.y), Vector2(0, size.y), Vector2(0, cut)])
			var shadow := PackedVector2Array()
			for p in pts:
				shadow.append(p + Vector2(4, 4))
			draw_colored_polygon(shadow, Color(UiKit.MAGENTA, 0.75))
			draw_colored_polygon(pts, color)
			_icon(UiKit.ON_PRIMARY, 26.0)
			return
		draw_colored_polygon(_points(0.0), color if active else rim)
		draw_colored_polygon(_points(2.4), color if active else Color(0.106, 0.043, 0.227, 0.94))
		_icon(UiKit.ON_PRIMARY if active else color, 26.0 if shape != "hex" or icon_name == "fab_bauen" else 24.0)

	func _icon(tint: Color, edge: float) -> void:
		var tex := UiIcon.texture(icon_name)
		if tex == null:
			return
		var off := Vector2(0, 3) if shape == "pent" else Vector2.ZERO
		draw_texture_rect(tex, Rect2(size / 2.0 - Vector2(edge, edge) / 2.0 + off, Vector2(edge, edge)), false, tint)


# ---------------------------------------------------------------- Typen-Reihe

## Ein Gebaeude in der Typen-Reihe (ohne Kachel): eigene kleine 3D-Ansicht in
## Platinengroesse. Tippen waehlt, ziehen legt es aufs Feld.
class ItemButton extends Button:
	var view: FactoryView
	var type: String
	var level := 1
	var gray := false
	var highlight := false

	func _init(owner_view: FactoryView, item_type: String, lv: int, edge: float, mono: bool) -> void:
		view = owner_view
		type = item_type
		level = lv
		gray = mono
		focus_mode = Control.FOCUS_NONE
		flat = true
		custom_minimum_size = Vector2(edge, edge)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var holder := SubViewportContainer.new()
		holder.stretch = true
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(holder)
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_2X
		vp.size = Vector2i(int(edge), int(edge))
		vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		holder.add_child(vp)
		var world := Node3D.new()
		world.scale = Vector3(1.0, FactoryCity.Y_STRETCH, 1.0)
		vp.add_child(world)
		var grayed := mono or lv > 1
		world.add_child(FactoryCity.instance(FactoryCity.tile_mesh("built", FactorySim.lines_of(type), lv)))
		world.add_child(FactoryCity.instance(FactoryCity.building_mesh(type, lv, true, false, grayed)))
		# Platinengroesse: so viele Bildpunkte je Einheit wie die Platine.
		var cam := FactoryCity.make_camera(edge / 2.08, edge, Vector3(0.0, 0.32, 0.0))
		vp.add_child(cam)

	func _draw() -> void:
		if not highlight:
			return
		# Gelbe Kontur um das gewaehlte Gebaeude (Sechseck des Feldes).
		var c := size / 2.0 + Vector2(0, size.y * 0.06)
		var pts := PackedVector2Array()
		for i in 7:
			var a := deg_to_rad(60.0 * i)
			pts.append(c + Vector2(cos(a) * size.x * 0.46, sin(a) * size.y * 0.4))
		draw_polyline(pts, Arcade.YELLOW, 2.5)

	func _get_drag_data(_at: Vector2) -> Variant:
		if gray or level > 1 or view.type_state(type) == "gesperrt":
			return null
		var ghost := Label.new()
		ghost.text = str(FactorySim.def(type)["name"])
		ghost.add_theme_font_override("font", Arcade.font("display", 16, 0.04))
		ghost.add_theme_font_size_override("font_size", 16)
		ghost.modulate = Color(Color(str(FactorySim.def(type)["farbe"])), 0.85)
		set_drag_preview(ghost)
		return {"factory_type": type}


# ---------------------------------------------------------------- Platine (Bedienung + Zeichnen ueber der Stadt)

## Liegt ueber der 3D-Stadt: nimmt Tippen, Ziehen (Platine scrollen bzw.
## Gebaeude verschieben) und Fallenlassen an und zeichnet Markierungen,
## Leiterbahn-Pulse und Schilder.
class Board extends Control:
	const SLOP := 10.0
	var view: FactoryView
	var _pulse := 0.0
	var _press_cell := ""
	var _press_at := Vector2.ZERO
	var _pressed := false
	var _dragging := false
	var _panning := false
	var _finger := Vector2.ZERO
	var _hover := ""

	func _init(owner_view: FactoryView) -> void:
		view = owner_view
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(delta: float) -> void:
		_pulse += delta
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = true
				_press_cell = view.key_at(event.position)
				_press_at = event.position
				_finger = event.position
				_dragging = false
				_panning = false
			else:
				var cell := view.key_at(event.position)
				if _dragging:
					_dragging = false
					view.move_from = ""
					if cell != _press_cell and cell in FactorySim.cells():
						view.move_to(_press_cell, cell)
					view.refresh()
				elif not _panning and _pressed:
					view.tapped(cell)
				_pressed = false
				_panning = false
				_press_cell = ""
			accept_event()
		elif event is InputEventMouseMotion and _pressed:
			var delta: Vector2 = event.position - _finger
			_finger = event.position
			if not _dragging and not _panning and event.position.distance_to(_press_at) > SLOP:
				if view.mode == "move" and not view._sim.building_at(_press_cell).is_empty():
					_dragging = true
					view.move_from = _press_cell
					view.selected = _press_cell
				else:
					_panning = true
					delta = event.position - _press_at
			if _panning:
				view.cam_target -= Vector2(delta.x, delta.y / FactoryCity.PITCH_SIN) / FactoryView.PX_PER_UNIT
				view._place_camera()
			accept_event()

	func _can_drop_data(at: Vector2, data: Variant) -> bool:
		if not (data is Dictionary and (data as Dictionary).has("factory_type")):
			return false
		var cell := view.key_at(at)
		if cell != _hover and cell in FactorySim.cells():
			_hover = cell
			view.show_build_preview(cell, str(data["factory_type"]))
			view.refresh()
		return true

	func _drop_data(at: Vector2, data: Variant) -> void:
		_hover = ""
		view.drop_type(view.key_at(at), str(data["factory_type"]))

	func _icon(name: String, c: Vector2, edge: float, color: Color) -> void:
		var tex := UiIcon.texture(name)
		if tex != null:
			draw_texture_rect(tex, Rect2(c - Vector2(edge, edge) / 2.0, Vector2(edge, edge)), false, color)

	## Schild: dunkles Viereck mit farbigem Rand und Symbol.
	func _badge(c: Vector2, icon: String, color: Color, edge: float = 24.0) -> void:
		var r := Rect2(c - Vector2(edge, edge) / 2.0, Vector2(edge, edge))
		draw_rect(r, Color(UiKit.BG, 0.95))
		draw_rect(r, color, false, 2.0)
		_icon(icon, c, edge * 0.7, color)

	func _draw() -> void:
		var sim := view._sim
		var pa := 0.5 + 0.5 * sin(_pulse * 5.5)
		var sel := view.selected
		var reach := sim.range_of(sel) if sel != "" else -1
		var armed := view.armed if view.mode == "build" else ""
		var pend_chunk := str(view.pending.get("chunk", ""))
		var locks := {}
		for k in FactorySim.cells():
			if not sim.unlocked(k):
				var chunk := FactorySim.chunk_of(k)
				var id := str(chunk.get("id", ""))
				if id != "" and id == pend_chunk:
					var ok := view.pending_missing().is_empty()
					draw_colored_polygon(view.cell_hex(k, 0.86), Color(FactoryView.GREEN if ok else UiKit.BAD, 0.22))
				if id != "" and not locks.has(id):
					var felder: Array = chunk["felder"]
					locks[id] = str(felder[felder.size() / 2])
				continue
			var b := sim.building_at(k)
			if reach >= 0 and k != sel and FactorySim.distance(sel, k) <= reach:
				draw_colored_polygon(view.cell_hex(k, 0.88), Color("#ffe14d", 0.12))
			var target := false
			if armed != "" and b.is_empty() and sim.fits(k, armed) == "":
				target = true
			elif view.mode == "move" and view.move_from != "" and view.move_target_ok(view.move_from, k):
				target = true
			if target:
				draw_polyline(view.cell_hex(k, 0.84), Color("#ffe14d", 0.3 + 0.5 * pa), 2.0)
			if view.mode == "remove" and not b.is_empty():
				draw_polyline(view.cell_hex(k, 0.92), Color(UiKit.BAD, 0.35 + 0.5 * pa), 2.5)
			if sel == k or view.move_from == k:
				draw_polyline(view.cell_hex(k, 0.95), Color("#ffe14d"), 3.0)
		# Schloss je gesperrter Feldgruppe (gekaufte Vorschau: Tasche).
		for id in locks:
			var c := view.cell_screen(str(locks[id]))
			if str(id) == pend_chunk:
				var ok := view.pending_missing().is_empty()
				_badge(c, "bag", FactoryView.GREEN if ok else UiKit.BAD, 26.0)
			else:
				_badge(c + Vector2(-18, -10), "fab_lock", Color("#8f80bd"), 20.0)
		# Leiterbahnen: Pulse wandern in der Warenfarbe (gestaute stehen still).
		for tr in sim.traces():
			if view.trace_jammed(tr):
				continue
			var path: Array = tr["path"]
			var pts: Array = []
			for k in path:
				pts.append(view.cell_screen(str(k), FactoryCity.TILE_H + 0.02))
			var col := FactorySim.ware_color(str(tr["ware"]))
			for n in 2:
				var t := fmod(_pulse * 0.45 + n * 0.5, 1.0) * (pts.size() - 1)
				var i := mini(int(t), pts.size() - 2)
				var p: Vector2 = (pts[i] as Vector2).lerp(pts[i + 1], t - i)
				var r := Rect2(p - Vector2(3.5, 3.5), Vector2(7, 7))
				draw_rect(r, col)
				draw_rect(r, UiKit.BG, false, 1.0)
		# Bau-Vorschau: kuenftige Leiterbahnen gestrichelt, Rand gruen/rot.
		var pk := str(view.pending.get("k", ""))
		if pk != "":
			for tr in view.preview:
				var col := FactorySim.ware_color(str(tr["ware"]))
				var path: Array = tr["path"]
				for i in path.size() - 1:
					draw_dashed_line(view.cell_screen(str(path[i])), view.cell_screen(str(path[i + 1])),
						Color(col, 0.6 + 0.4 * pa), 3.0, 6.0)
			var state := view.pending_state()
			var tint := FactoryView.GREEN if state != "poor" else UiKit.BAD
			draw_polyline(view.cell_hex(pk, 0.92), Color(tint, 0.6 + 0.4 * pa), 3.0)
			var c := view.cell_screen(pk)
			_badge(c + Vector2(34, 18), "check" if state == "own" else "bag", tint, 22.0)
			if state == "poor":
				var gap := view.pending_missing()
				var small := Arcade.font("bold")
				var y := c.y + 50.0
				var x := c.x - (gap.size() - 1) * 26.0
				for ware in gap:
					draw_circle(Vector2(x - 10, y - 4), 5.0, FactorySim.ware_color(str(ware)))
					draw_string(small, Vector2(x - 2, y + 1), "-%d" % int(gap[ware]), HORIZONTAL_ALIGNMENT_LEFT,
						-1, 13, UiKit.BAD)
					x += 52.0
		# Schilder nur bei Problemen und fuer das Ziel.
		for k in sim.buildings():
			var kind := view.badge_of(str(k))
			if kind == "":
				continue
			var c := view.cell_screen(str(k), 1.05) + Vector2(16, -6)
			match kind:
				"off": _badge(c, "fab_off", UiKit.BAD)
				"jam": _badge(c, "fab_jam", Color("#ff9e26"))
				"flag": _badge(c, "fab_flag", Arcade.YELLOW)
		if _dragging and _press_cell != "":
			var b := sim.building_at(_press_cell)
			if not b.is_empty():
				var d := FactorySim.def(str(b["t"]))
				var col := Color(str(d["farbe"]))
				var pts := PackedVector2Array()
				for i in 7:
					var a := deg_to_rad(60.0 * i)
					pts.append(_finger + Vector2(cos(a) * 40.0, sin(a) * 34.0))
				draw_colored_polygon(pts, Color("#0f0724", 0.8))
				draw_polyline(pts, col, 2.0)
				draw_string(Arcade.font("bold"), _finger + Vector2(-50, 5), str(d["name"]),
					HORIZONTAL_ALIGNMENT_CENTER, 100, 13, col)
