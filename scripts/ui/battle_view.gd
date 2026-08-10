class_name BattleView
extends Node2D

## Zeichnet Gitter, Einheiten und Markierungen.
##
## Kennt die Regeln nicht -- es fragt den BattleManager und stellt dar, was er
## sagt. Umgekehrt kennt der Manager diese Klasse nicht.
##
## ### Warum kein TileMapLayer
##
## Der Entwurf nennt TileMapLayer im Modus Isometric. Zwei Gruende sprechen im
## Bestand dagegen:
##
## 1. Das Kachelverhaeltnis ist sqrt(2):1 und faellt aus der 45-Grad-Kamera des
##    Bauteil-Renderers. Es laesst sich nicht unabhaengig waehlen.
## 2. STEP und BLOCK sind hoch. Sie muessen sich mit den DROMEs sortieren --
##    ein Betonpfeiler verdeckt den Bot davor, aber nicht den dahinter. Eine
##    TileMap sortiert gegen Node2D-Einheiten nur ueber getrennte Ebenen je
##    Hoehe; Sprites in einer gemeinsamen Tiefenordnung tun es ohne Sonderfall.
##
## Die Umrechnung bleibt trotzdem an genau einer Stelle: IsoView.

## Abstand zwischen zwei Tiefenstufen. Gross genug, dass die Bauteile einer
## Einheit dazwischen passen, ohne in die naechste Reihe zu rutschen.
const DEPTH_STRIDE := 16
const UNIT_DEPTH_OFFSET := 8

const OVERLAY_TILE := "res://assets/terrain/overlay_tile.svg"
const OVERLAY_OUTLINE := "res://assets/terrain/overlay_outline.svg"
const OVERLAY_ARROW := "res://assets/terrain/overlay_drift_arrow.svg"

## Farben der Feldmarkierungen. Dieselbe Raute, fuenf Bedeutungen.
const COLOR_REACHABLE := Color(0.25, 0.55, 1.0, 0.38)
const COLOR_TARGET := Color(1.0, 0.25, 0.25, 0.42)
const COLOR_BLOCKED := Color(0.55, 0.55, 0.58, 0.38)
const COLOR_ACTIVE := Color(1.0, 0.85, 0.25, 0.85)
const COLOR_HAZE := Color(0.75, 0.82, 0.95, 0.30)

## Der Umriss der Flaechenwirkung unter dem Zeiger.
const COLOR_SPLASH := Color(1.0, 0.55, 0.15, 0.9)

## Der gelaufene Teil des Weges und der gerutschte -- bewusst verschiedene
## Farben. Der Spieler muss VOR dem Klick sehen, dass er wegrutschen wird.
const COLOR_PATH := Color(0.45, 0.75, 1.0, 0.95)
const COLOR_SLIDE := Color(1.0, 0.65, 0.15, 0.95)

var grid: Grid

var _world: Node2D
var _overlays: Node2D
var _paths: Node2D
var _numbers: DamagePainter
var _badges: UnitBadgePainter
var _tile_sprites: Dictionary = {}
var _overlay_pool: Array[Sprite2D] = []

var _hover_tile: Vector2i = Vector2i(-1, -1)
var _preview_path: Array = []
var _preview_slide: Array = []


func _ready() -> void:
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)

	_overlays = Node2D.new()
	_overlays.name = "Overlays"
	add_child(_overlays)

	_paths = PathPainter.new()
	_paths.name = "Paths"
	add_child(_paths)

	_badges = UnitBadgePainter.new()
	_badges.name = "UnitBadges"
	add_child(_badges)

	_numbers = DamagePainter.new()
	_numbers.name = "DamagePreview"
	add_child(_numbers)


# ---------------------------------------------------------------------------
# Terrain
# ---------------------------------------------------------------------------

func build_terrain(battle_grid: Grid) -> void:
	grid = battle_grid
	for sprite in _tile_sprites.values():
		sprite.queue_free()
	_tile_sprites.clear()

	for tile in grid.all_tiles():
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.position = IsoView.sprite_position(tile)
		sprite.z_index = IsoView.depth(tile) * DEPTH_STRIDE

		var type := grid.terrain_type(tile)
		var path: String = type.texture_path if type != null else ""
		if path != "" and ResourceLoader.exists(path):
			sprite.texture = load(path)
		else:
			# Fehlendes Tile wird als Fehlmarkierung sichtbar, nicht ersetzt.
			sprite.texture = load(OVERLAY_TILE)
			sprite.modulate = Color.MAGENTA
		IsoView.fit_sprite(sprite)
		_world.add_child(sprite)
		_tile_sprites[tile] = sprite

		if grid.terrain_class(tile) == Terrain.TClass.DRIFT:
			_add_drift_marker(tile)
		elif grid.terrain_class(tile) == Terrain.TClass.HAZE:
			_add_haze_veil(tile)


## Gerichtete Drift bekommt einen Pfeil, ungerichtete traegt ihre Schliere
## schon im Tile. Unsichtbares Rutschen ist die schnellste Art, ein
## Taktikspiel unfair wirken zu lassen.
func _add_drift_marker(tile: Vector2i) -> void:
	var flow := grid.flow_direction(tile)
	if flow == Vector2i.ZERO:
		return
	var arrow := Sprite2D.new()
	arrow.texture = load(OVERLAY_ARROW)
	arrow.centered = false
	arrow.position = IsoView.sprite_position(tile)
	arrow.z_index = IsoView.depth(tile) * DEPTH_STRIDE + 1
	arrow.modulate = Color(0.6, 0.95, 1.0, 0.9)
	IsoView.fit_sprite(arrow)
	# Der Pfeil zeigt in Gitterrichtung +x. Die anderen drei ergeben sich
	# durch Drehung um Vielfache von 90 Grad um die Feldmitte.
	var turns := {Vector2i(1, 0): 0.0, Vector2i(0, 1): 90.0,
		Vector2i(-1, 0): 180.0, Vector2i(0, -1): 270.0}
	arrow.rotation_degrees = turns.get(flow, 0.0)
	IsoView.pivot_on_tile_center(arrow)
	_world.add_child(arrow)


## Haze-Felder werden halbtransparent ueberlagert. Kein Fog of War -- die
## Position bleibt sichtbar; lesbar sein muss nur "von hier aus nicht
## beschiessbar".
func _add_haze_veil(tile: Vector2i) -> void:
	var veil := Sprite2D.new()
	veil.texture = load(OVERLAY_TILE)
	veil.centered = false
	IsoView.fit_sprite(veil)
	veil.position = IsoView.sprite_position(tile)
	veil.z_index = IsoView.depth(tile) * DEPTH_STRIDE + 12
	veil.modulate = COLOR_HAZE
	_world.add_child(veil)


# ---------------------------------------------------------------------------
# Einheiten
# ---------------------------------------------------------------------------

func attach_unit(unit: Unit) -> void:
	_world.add_child(unit)
	refresh_unit_depth(unit)
	unit.set_in_haze(grid.terrain_class(unit.tile) == Terrain.TClass.HAZE)


func refresh_unit_depth(unit: Unit) -> void:
	unit.z_index = IsoView.depth(unit.tile) * DEPTH_STRIDE + UNIT_DEPTH_OFFSET


func refresh_all_depths(units: Array) -> void:
	for unit in units:
		if unit.is_alive():
			refresh_unit_depth(unit)
		else:
			unit.visible = false


# ---------------------------------------------------------------------------
# Markierungen
# ---------------------------------------------------------------------------

func clear_overlays() -> void:
	for sprite in _overlay_pool:
		sprite.visible = false


func _overlay(index: int) -> Sprite2D:
	while _overlay_pool.size() <= index:
		var sprite := Sprite2D.new()
		sprite.texture = load(OVERLAY_TILE)
		sprite.centered = false
		sprite.visible = false
		_overlays.add_child(sprite)
		_overlay_pool.append(sprite)
	return _overlay_pool[index]


## Faerbt Felder ein. ``sets`` ist eine Liste aus { tiles, color }.
func paint(sets: Array) -> void:
	clear_overlays()
	var index := 0
	for entry in sets:
		for tile in entry["tiles"]:
			var sprite := _overlay(index)
			sprite.position = IsoView.sprite_position(tile)
			# Markierungen liegen ueber ihrem Feld, aber unter allem, was
			# davor steht -- sonst leuchtet die Raute durch den Betonpfeiler.
			sprite.z_index = IsoView.depth(tile) * DEPTH_STRIDE + 2
			sprite.modulate = entry["color"]
			sprite.texture = load(entry.get("texture", OVERLAY_TILE))
			# Die Sprites im Pool wechseln ihre Textur -- Umriss und Raute
			# koennen verschieden fein gerastert sein, also wird nach JEDEM
			# Wechsel neu angepasst.
			IsoView.fit_sprite(sprite)
			sprite.visible = true
			index += 1


## Wie viele Welteinheiten ein Bildschirmpixel sind -- der Kehrwert des
## Kamerazooms.
##
## Balken, Namen und Schadenszahlen werden in der Welt gezeichnet, weil sie ueber
## einem FELD stehen und mit ihm wandern muessen. Ihre GROESSE gehoert aber zum
## Bildschirm: bei Zoom 0.62 schrumpfte ein 12-Punkt-Name auf sieben Pixel und
## war nicht mehr zu lesen. Hier wird das getrennt -- Position aus der Welt,
## Groesse aus dem Bildschirm.
func set_pixel_scale(camera_zoom: float) -> void:
	var factor := 1.0 / maxf(0.01, camera_zoom)
	_badges.pixel_scale = factor
	_badges.queue_redraw()
	_numbers.pixel_scale = factor
	_numbers.queue_redraw()


## Die Statusbadges ueber den Einheiten. ``entries`` ist eine Liste aus
## { tile, name, hp, hp_max, en, en_max, tick, is_player, active } -- gefuellt
## wird sie im Kampfbildschirm, hier wird sie nur gezeichnet.
func show_unit_badges(entries: Array) -> void:
	_badges.entries = entries
	_badges.queue_redraw()


## Die Schadenszahlen ueber den Zielen. ``entries`` ist eine Liste aus
## { tile, text, heal, lethal } -- gerechnet wird sie im Kampfbildschirm, hier
## wird sie nur gezeichnet.
func show_damage_preview(entries: Array) -> void:
	_numbers.entries = entries
	_numbers.queue_redraw()


func clear_damage_preview() -> void:
	show_damage_preview([])


func set_path_preview(walked: Array, slide: Array) -> void:
	_preview_path = walked
	_preview_slide = slide
	_paths.walked = walked
	_paths.slide = slide
	_paths.queue_redraw()


func clear_path_preview() -> void:
	set_path_preview([], [])


func tile_at_screen(world_position: Vector2) -> Vector2i:
	return IsoView.local_to_map(world_position)


## Zeichnet die Pfadvorschau. Eigene Klasse, weil _draw() an einen Knoten
## gebunden ist und die Linien ueber allen Feldern liegen muessen.
class PathPainter extends Node2D:
	var walked: Array = []
	var slide: Array = []

	func _ready() -> void:
		z_index = 4000

	func _draw() -> void:
		if walked.size() >= 2:
			var points := PackedVector2Array()
			for tile in walked:
				points.append(IsoView.map_to_local(tile))
			draw_polyline(points, BattleView.COLOR_PATH, 3.0, true)

		if slide.is_empty():
			return
		# Der gerutschte Teil gestrichelt und in anderer Farbe.
		var from: Vector2i = walked[-1] if not walked.is_empty() else slide[0]
		var chain: Array = [from] + slide
		for i in range(chain.size() - 1):
			_dashed(IsoView.map_to_local(chain[i]),
				IsoView.map_to_local(chain[i + 1]))
		var last := IsoView.map_to_local(chain[-1])
		draw_circle(last, 7.0, BattleView.COLOR_SLIDE)

	func _dashed(a: Vector2, b: Vector2) -> void:
		var total := a.distance_to(b)
		var dir := (b - a).normalized()
		var travelled := 0.0
		while travelled < total:
			var seg := minf(6.0, total - travelled)
			draw_line(a + dir * travelled, a + dir * (travelled + seg),
				BattleView.COLOR_SLIDE, 3.0, true)
			travelled += 12.0


## Das Statusbadge ueber jedem DROME: Name, Integritaet, Energie, TICK.
##
## ### Warum das ueber der Figur steht und nicht am Bildrand
##
## Integritaet und Energie standen bisher nur in der Statuszeile der AKTIVEN
## Einheit und im Tooltip beim Hovern. Beides beantwortet die Frage zu spaet:
## wer entscheidet, welchen Gegner er angreift, vergleicht drei Einheiten
## miteinander, und dafuer muss er sie nebeneinander sehen -- nicht
## nacheinander unter dem Mauszeiger.
##
## Der TICK-Balken ist dieselbe Zahl wie in der Leiste links oben, nur am Ort
## des Geschehens: die Leiste sagt, WER als naechstes zieht, der Balken hier
## sagt es UEBER DER FIGUR, die man gerade anschaut. Massgeblich ist auch hier
## die TICK-Queue; widersprechen sich Balken und Queue, hat der Balken den Bug.
##
## Alles in EINEM Knoten und nicht als Label je Einheit: die Werte aendern sich
## nach jeder Aktion, und Knoten, die dabei entstehen und vergehen, haengen
## zwangslaeufig irgendwann als Rest im Baum.
class UnitBadgePainter extends Node2D:
	const WIDTH := 88.0
	const BASE_Y := -74.0            ## Unterkante des Badges ueber der Feldmitte

	const HP_HEIGHT := 7.0
	const EN_HEIGHT := 4.0
	const TICK_HEIGHT := 3.0
	const GAP := 2.0
	const NAME_SIZE := 12
	const NAME_GAP := 4.0

	const COLOR_HP := Color(0.42, 0.86, 0.45)
	const COLOR_HP_LOW := Color(0.95, 0.72, 0.25)
	const COLOR_HP_CRITICAL := Color(0.95, 0.32, 0.28)
	const COLOR_EN := Color(0.45, 0.72, 1.0)
	const COLOR_TICK := Color(0.85, 0.80, 0.55)
	const COLOR_TRACK := Color(0.05, 0.06, 0.09, 0.85)
	const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.85)

	## Ab hier faerbt sich der Integritaetsbalken um. Die Schwellen sind
	## Anzeige, keine Regel -- mechanisch passiert bei 40% nichts. Sie stehen
	## trotzdem hier, weil "fast tot" eine Information ist, die der Spieler
	## sonst aus zwei Zahlen im Kopf ausrechnet, waehrend er zielt.
	const HP_WARN := 0.40
	const HP_CRITICAL := 0.20

	var entries: Array = []

	## Umrechnung Welt -> Bildschirm. Siehe BattleView.set_pixel_scale().
	var pixel_scale: float = 1.0

	func _ready() -> void:
		# Ueber den Einheiten, unter den Schadenszahlen.
		z_index = 4005

	## Nur wegen des wippenden Zeigers -- ohne aktive Einheit steht das Bild,
	## und dann wird auch nichts neu gezeichnet.
	func _process(_delta: float) -> void:
		for entry in entries:
			if entry.get("active", false):
				queue_redraw()
				return

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		for entry in entries:
			_badge(font, entry)

	func _badge(font: Font, entry: Dictionary) -> void:
		var s := pixel_scale
		var center: Vector2 = IsoView.map_to_local(entry["tile"])
		var team: Color = Teams.color(entry.get("is_player", false))
		var active: bool = entry.get("active", false)

		var width := WIDTH * s
		var left := center.x - width * 0.5
		var bottom := center.y + BASE_Y * s

		# Von unten nach oben gestapelt: TICK, Energie, Integritaet, Name.
		var y := bottom
		y -= TICK_HEIGHT * s
		_bar(Vector2(left, y), width, TICK_HEIGHT * s,
			entry.get("tick", 0.0), COLOR_TICK)
		y -= (GAP + EN_HEIGHT) * s
		_bar(Vector2(left, y), width, EN_HEIGHT * s,
			_fraction(entry, "en", "en_max"), COLOR_EN)
		y -= (GAP + HP_HEIGHT) * s
		var hp := _fraction(entry, "hp", "hp_max")
		_bar(Vector2(left, y), width, HP_HEIGHT * s, hp, _hp_color(hp))

		# Der Rahmen traegt die Fraktionsfarbe -- er umschliesst alle drei
		# Balken, damit die Zugehoerigkeit an EINER Kante haengt und nicht an
		# der Faerbung der Balken selbst. Die muessen ihre eigene Bedeutung
		# behalten: gruen ist Integritaet, nicht "Spieler".
		var pad := 2.0 * s
		draw_rect(Rect2(Vector2(left - pad, y - pad),
			Vector2(width + pad * 2.0, bottom - y + pad * 2.0)),
			Color(team, 0.95 if active else 0.55), false, (2.0 if active else 1.0) * s)

		var label := "%s   %d/%d" % [entry.get("name", ""), entry.get("hp", 0),
			entry.get("hp_max", 0)]
		var size := maxi(1, int(round(NAME_SIZE * s)))
		var name_top := y - NAME_GAP * s - float(size)
		_text(font, Vector2(center.x, y - NAME_GAP * s), label, size,
			Color.WHITE if active else Color(0.86, 0.9, 0.96))

		# Der Zeiger auf die aktive Einheit. Er wippt, weil ein stehendes
		# Dreieck neben drei Balken und einem Rahmen untergeht -- Bewegung ist
		# das einzige Signal auf diesem Bild, das noch niemand belegt hat.
		if active:
			_marker(Vector2(center.x, name_top - 6.0 * s), team, s)

	## Ein nach unten zeigendes Dreieck, das ueber der Nulllage wippt.
	func _marker(at: Vector2, color: Color, s: float) -> void:
		var bob := sin(float(Time.get_ticks_msec()) / 260.0) * 3.5 * s
		var tip := at + Vector2(0.0, bob)
		draw_colored_polygon(PackedVector2Array([
			tip + Vector2(-9.0 * s, -13.0 * s), tip + Vector2(9.0 * s, -13.0 * s), tip,
		]), Color(color, 0.95))

	func _fraction(entry: Dictionary, key: String, max_key: String) -> float:
		var maximum: float = float(entry.get(max_key, 0))
		if maximum <= 0.0:
			return 0.0
		return clampf(float(entry.get(key, 0)) / maximum, 0.0, 1.0)

	func _hp_color(fraction: float) -> Color:
		if fraction <= HP_CRITICAL:
			return COLOR_HP_CRITICAL
		return COLOR_HP_LOW if fraction <= HP_WARN else COLOR_HP

	func _bar(at: Vector2, width: float, height: float, fraction: float,
			color: Color) -> void:
		draw_rect(Rect2(at, Vector2(width, height)), COLOR_TRACK)
		if fraction > 0.0:
			draw_rect(Rect2(at, Vector2(width * clampf(fraction, 0.0, 1.0),
				height)), color)

	func _text(font: Font, at: Vector2, text: String, size: int,
			color: Color) -> void:
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			size).x
		var origin := at - Vector2(width * 0.5, 0.0)
		# Schatten zuerst: der Name steht ueber wechselndem Untergrund und waere
		# auf hellem Terrain sonst nicht zu lesen.
		font.draw_string(get_canvas_item(), origin + Vector2(1, 1), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, COLOR_SHADOW)
		font.draw_string(get_canvas_item(), origin, text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Schreibt die Schadensvorschau ueber die Ziele.
##
## Als gezeichneter Text und nicht als Label je Einheit: die Zahlen wechseln
## bei jeder Zeigerbewegung, und ein Knoten, der dabei entsteht und vergeht,
## haengt zwangslaeufig irgendwann als Rest im Baum.
##
## Ein toedlicher Treffer bekommt eine eigene Farbe. Das ist die eine Zahl, die
## der Spieler nicht ueberlesen darf.
class DamagePainter extends Node2D:
	const COLOR_DAMAGE := Color(1.0, 0.86, 0.42)
	const COLOR_LETHAL := Color(1.0, 0.36, 0.32)
	const COLOR_HEAL := Color(0.45, 0.95, 0.6)
	const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.85)
	const FONT_SIZE := 22

	## Hoehe ueber der Feldmitte -- oberhalb des Statusbadges.
	const ABOVE_BADGE := -126.0

	var entries: Array = []

	## Umrechnung Welt -> Bildschirm. Siehe BattleView.set_pixel_scale().
	var pixel_scale: float = 1.0

	func _ready() -> void:
		# Ueber den Feldern, aber unter dem Aktionsring -- der liegt in der
		# CanvasLayer und damit ohnehin darueber.
		z_index = 4010

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var s := pixel_scale
		var size := maxi(1, int(round(FONT_SIZE * s)))
		for entry in entries:
			var text: String = entry.get("text", "")
			if text == "":
				continue
			var color: Color = COLOR_HEAL if entry.get("heal", false) \
				else (COLOR_LETHAL if entry.get("lethal", false) else COLOR_DAMAGE)
			# Ueber dem Statusbadge, nicht auf der Brust: darunter stehen der
			# DROME und seine Balken. Tiefer verdeckte die Zahl genau den
			# Integritaetsbalken, gegen den sie zu lesen ist.
			var at: Vector2 = IsoView.map_to_local(entry["tile"]) \
				+ Vector2(0, ABOVE_BADGE * s)
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
				-1, size).x
			var origin := at - Vector2(width * 0.5, 0)
			# Schatten zuerst: die Zahl steht ueber wechselndem Untergrund und
			# waere auf hellem Terrain sonst nicht zu lesen.
			font.draw_string(get_canvas_item(), origin + Vector2(2, 2), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, COLOR_SHADOW)
			font.draw_string(get_canvas_item(), origin, text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
