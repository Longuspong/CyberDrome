extends Control

## Leistungstest (17. Nov. 2026, Wunsch des Spielers): wie viele 3D-DROMEs
## schafft das Geraet -- im Browser (PWA) und spaeter als Android-App? Zu
## oeffnen ueber Optionen > Zum Testen.
##
## Drei Arten, die DROMEs zu zeigen:
##   ruhend   wie heute im Spiel: jedes Modell einmal gerendert (UPDATE_ONCE)
##   einzeln  jedes Modell dreht sich und wird in JEDEM Bild neu gerendert,
##            je DROME eine eigene 3D-Ansicht -- so saehe Schritt 5
##            (Bewegung) ohne Umbau aus
##   szene    alle Modelle drehen sich in EINER gemeinsamen 3D-Szene mit
##            einer Kamera -- die Alternative fuer animierte Kaempfe
## "Messreihe" laeuft alle Arten und Anzahlen durch und zeigt eine Tabelle.

const COUNTS := [3, 6, 12, 24, 48]
const MODES := [["ruhend", "Ruhend"], ["einzeln", "Einzeln"], ["szene", "Eine Szene"]]
const WARMUP := 1.5
const MEASURE := 3.0
const CHASSIS := [&"scout_body", &"jugg_body", &"mage_body", &"strix_body"]

var _mode := "einzeln"
var _count := 6
var _stage: Control
var _holder: Node2D
var _readout: Label
var _table: Label
var _mode_slot: VBoxContainer
var _turns: Array = []          # Node3D je DROME, das sich dreht
var _views: Array = []          # SubViewports je DROME (Art "einzeln")
var _time := 0.0
var _frames: Array = []         # letzte Bildzeiten
var _series: Array = []         # offene Schritte der Messreihe
var _series_results: Array = []
var _phase_time := 0.0
var _phase_frames := 0


func _ready() -> void:
	var content := UiKit.page(self, "Leistung", "res://scenes/settings.tscn", -1)
	content.add_theme_constant_override("separation", 12)
	content.add_child(UiKit.label("Wie viele 3D-DROMEs schafft dieses Gerät? „Einzeln“ ist der "
		+ "heutige Weg mit Bewegung, „Eine Szene“ die Alternative. Messwerte sind Bilder pro "
		+ "Sekunde (60 = flüssig, unter 30 = ruckelt).", 14, UiKit.TEXT))

	_mode_slot = VBoxContainer.new()
	content.add_child(_mode_slot)
	_rebuild_mode_picker()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	var minus := UiKit.outline_button("−", Arcade.CYAN)
	minus.custom_minimum_size = Vector2(56, 48)
	minus.pressed.connect(func(): _step_count(-1))
	row.add_child(minus)
	_readout = Arcade.label("", 15, Arcade.WHITE, "bold")
	_readout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_readout)
	var plus := UiKit.outline_button("+", Arcade.CYAN)
	plus.custom_minimum_size = Vector2(56, 48)
	plus.pressed.connect(func(): _step_count(1))
	row.add_child(plus)

	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(0, 360)
	_stage.clip_contents = true
	content.add_child(_stage)
	_holder = Node2D.new()
	_stage.add_child(_holder)

	var run := UiKit.outline_button("Messreihe starten", Arcade.YELLOW)
	run.custom_minimum_size = Vector2(0, 48)
	run.pressed.connect(_start_series)
	content.add_child(run)
	_table = Arcade.label("", 13, Arcade.MUTED, "bold")
	_table.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_table)
	content.add_child(UiKit.label(_platform_text(), 12, Arcade.MUTED))

	_stage.resized.connect(_build.call_deferred)
	_build.call_deferred()


func _rebuild_mode_picker() -> void:
	for child in _mode_slot.get_children():
		child.queue_free()
	_mode_slot.add_child(UiKit.segmented(MODES, _mode, func(id):
		_mode = id
		_rebuild_mode_picker()
		_build()))


func _step_count(direction: int) -> void:
	var i := clampi(COUNTS.find(_count) + direction, 0, COUNTS.size() - 1)
	_count = COUNTS[i]
	_build()


func _platform_text() -> String:
	return "Gerät: %s · Renderer: %s · Grafik: %s" % [OS.get_name(),
		str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "?")),
		RenderingServer.get_video_adapter_name()]


## Ein Aufbau je Chassis mit der ersten passenden Waffe.
func _build_for(index: int) -> DromeBuild:
	var build := DromeBuild.create("Test", {})
	var chassis_id: StringName = CHASSIS[index % CHASSIS.size()]
	build.apply_chassis(chassis_id)
	var chassis := PartDB.get_part(chassis_id)
	for slot in chassis.equip_slots():
		var options := PartDB.equipment_for(chassis, slot)
		if not options.is_empty():
			build.slots[slot] = options[index % options.size()].id
	return build


func _clear() -> void:
	for child in _holder.get_children():
		_holder.remove_child(child)
		child.queue_free()
	_turns.clear()
	_views.clear()
	_frames.clear()


func _build() -> void:
	if _stage == null or _stage.size.x <= 0:
		return
	_clear()
	var cols := int(ceil(sqrt(float(_count) * _stage.size.x / maxf(_stage.size.y, 1.0))))
	cols = maxi(cols, 1)
	var rows := int(ceil(float(_count) / cols))
	var cell := minf(_stage.size.x / cols, _stage.size.y / rows)
	if _mode == "szene":
		_build_scene(cols, rows, cell)
	else:
		for i in _count:
			var rig := Node2D.new()
			var factor := cell / 128.0
			rig.scale = Vector2(factor, factor)
			rig.position = Vector2((i % cols) * cell, (i / cols) * cell)
			_holder.add_child(rig)
			DromeSprites.assemble(rig, _build_for(i), "south", 256)
			var view := rig.get_node_or_null("Ansicht3D") as SubViewport
			if view == null:
				continue
			if _mode == "einzeln":
				# alle Ansichten (Bild, Signal, Neon) jedes Bild neu
				DromeSprites.redraw(rig, true)
				_views.append(view)
				_turns.append(view.get_node("Drome/Ausrichtung"))


## Alle DROMEs in einer 3D-Welt mit einer Kamera, als ein Bild gezeigt.
func _build_scene(cols: int, rows: int, cell: float) -> void:
	var px := Vector2i(int(cols * cell), int(rows * cell))
	var view := SubViewport.new()
	view.size = px * 2
	view.transparent_bg = true
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := DromeModel.make_camera()
	# Eine Zelle = 128 Entwurfspunkte; das Gitter liegt in der Bildebene,
	# also entlang "rechts" und "oben" der Iso-Kamera.
	var right := Vector3(DromeModel.COS45, 0, DromeModel.COS45)
	var up := Vector3(0.5, DromeModel.COS45, -0.5)
	var unit := 128.0 / DromeModel.SCALE
	cam.size = unit * rows
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	view.add_child(cam)
	var span_x := unit * cols
	var span_y := unit * rows
	cam.position += right * (span_x / 2.0 - unit / 2.0) - up * (span_y / 2.0 - unit / 2.0)
	for i in _count:
		var node := DromeModel.build_node(_build_for(i), "south", 256)
		# Zellmitte im Bild; der Bot steht mit der Bodenmitte 32 Punkte
		# unter der Zellmitte (wie im Einzelbild).
		node.position = right * ((i % cols) * unit) - up * ((i / cols) * unit)
		view.add_child(node)
		_turns.append(node.get_node("Ausrichtung"))
	_holder.add_child(view)
	var sprite := Sprite2D.new()
	sprite.texture = view.get_texture()
	sprite.centered = false
	sprite.scale = Vector2(0.5, 0.5)
	var outline := ShaderMaterial.new()
	outline.shader = DromeSprites.OUTLINE_SHADER
	outline.set_shader_parameter("line_px", 0.45 * cell * 2.0 / 128.0)
	outline.set_shader_parameter("rim_px", 1.6 * cell * 2.0 / 128.0)
	sprite.material = outline
	_holder.add_child(sprite)
	_views.append(view)


func _process(delta: float) -> void:
	_time += delta
	if _mode != "ruhend":
		for i in _turns.size():
			var turn: Node3D = _turns[i]
			turn.basis = DromeModel.facing_basis("south").rotated(Vector3.UP, _time * 1.5 + i * 0.7)
	_frames.append(delta)
	if _frames.size() > 60:
		_frames.pop_front()
	var avg := 0.0
	for f in _frames:
		avg += f
	avg /= maxf(_frames.size(), 1)
	_readout.text = "%d DROMEs · %d B/s · %.1f ms" % [_count,
		int(round(1.0 / maxf(avg, 0.0001))), avg * 1000.0]
	_series_tick(delta)


# ---------------------------------------------------------------------------
# Messreihe
# ---------------------------------------------------------------------------

func _start_series() -> void:
	_series.clear()
	_series_results.clear()
	for mode in MODES:
		for count in COUNTS:
			_series.append([mode[0], count])
	_table.text = "Messreihe läuft …"
	_next_step()


func _next_step() -> void:
	if _series.is_empty():
		_show_results()
		return
	var step: Array = _series.pop_front()
	_mode = step[0]
	_count = step[1]
	_rebuild_mode_picker()
	_build()
	_phase_time = -WARMUP
	_phase_frames = 0


func _series_tick(delta: float) -> void:
	if _table.text == "" or not _table.text.begins_with("Messreihe läuft"):
		return
	_phase_time += delta
	if _phase_time < 0.0:
		return
	_phase_frames += 1
	if _phase_time >= MEASURE:
		_series_results.append([_mode, _count, _phase_frames / _phase_time])
		_table.text = "Messreihe läuft … %d von %d" % [_series_results.size(),
			MODES.size() * COUNTS.size()]
		_next_step()


func _show_results() -> void:
	var lines := ["ERGEBNIS (Bilder pro Sekunde)"]
	var header := "Anzahl"
	for mode in MODES:
		header += " · " + str(mode[1])
	lines.append(header)
	for count in COUNTS:
		var line := "%2d" % count
		for mode in MODES:
			for r in _series_results:
				if r[0] == mode[0] and r[1] == count:
					line += " · %d" % int(round(r[2]))
		lines.append(line)
	_table.text = "\n".join(lines)
