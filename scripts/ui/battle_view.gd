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


## Der Lebensbalken ueber jedem DROME: EIN schmaler Balken, sonst nichts.
##
## Integritaet und Schild teilen sich die Breite im Verhaeltnis ihrer
## Hoechstwerte: 200 Integritaet und 100 Schild heisst zwei Drittel
## Integritaet, ein Drittel Schild. Beide Teile leeren sich an Ort und Stelle,
## die Gesamtlaenge bleibt -- so sieht man auf einen Blick, wie viel vom
## ganzen DROME noch steht.
##
## Die Farbe traegt die Seite: eigene gruen (Integritaet) und blau (Schild),
## Gegner rot und violett. Name, Zahlen, Energie und Initiative stehen in den
## Kacheln oben -- ueber der Figur war es im Nahkampf nicht mehr lesbar, weil
## sich drei Badges uebereinanderschoben.
##
## Alles in EINEM Knoten und nicht als Label je Einheit: die Werte aendern sich
## nach jeder Aktion, und Knoten, die dabei entstehen und vergehen, haengen
## zwangslaeufig irgendwann als Rest im Baum.
class UnitBadgePainter extends Node2D:
	const WIDTH := 56.0
	const HEIGHT := 6.0
	const BASE_Y := -72.0            ## Unterkante des Balkens ueber der Feldmitte

	const COLOR_TRACK := Color(0.04, 0.05, 0.08, 0.9)
	const COLOR_OUTLINE := Color(0.0, 0.0, 0.0, 0.9)

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
		for entry in entries:
			_badge(entry)

	## Die Aufteilung des Balkens als Anteile 0..1 der Gesamtbreite:
	## { hp_slot, hp_fill, shield_slot, shield_fill }. Statisch, damit der
	## Test sie ohne Zeichnen pruefen kann.
	static func split(hp: int, hp_max: int, shield: int, shield_max: int) -> Dictionary:
		var total := float(maxi(0, hp_max) + maxi(0, shield_max))
		if total <= 0.0:
			return {"hp_slot": 0.0, "hp_fill": 0.0, "shield_slot": 0.0, "shield_fill": 0.0}
		var hp_slot := float(maxi(0, hp_max)) / total
		var shield_slot := 1.0 - hp_slot
		return {
			"hp_slot": hp_slot,
			"hp_fill": hp_slot * clampf(float(hp) / maxf(1.0, float(hp_max)), 0.0, 1.0),
			"shield_slot": shield_slot,
			"shield_fill": shield_slot * (clampf(float(shield) / float(shield_max), 0.0, 1.0)
				if shield_max > 0 else 0.0),
		}

	func _badge(entry: Dictionary) -> void:
		var s := pixel_scale
		var center: Vector2 = IsoView.map_to_local(entry["tile"])
		var mine: bool = entry.get("is_player", false)
		var active: bool = entry.get("active", false)

		var width := WIDTH * s
		var height := HEIGHT * s
		var left := center.x - width * 0.5
		var top := center.y + BASE_Y * s - height

		var parts := split(int(entry.get("hp", 0)), int(entry.get("hp_max", 0)),
			int(entry.get("shield", 0)), int(entry.get("shield_max", 0)))
		var pad := 1.0 * s
		draw_rect(Rect2(Vector2(left - pad, top - pad),
			Vector2(width + pad * 2.0, height + pad * 2.0)), COLOR_OUTLINE)
		draw_rect(Rect2(Vector2(left, top), Vector2(width, height)), COLOR_TRACK)
		draw_rect(Rect2(Vector2(left, top), Vector2(width * parts["hp_fill"], height)),
			Teams.hp_color(mine))
		var shield_left: float = left + width * float(parts["hp_slot"])
		draw_rect(Rect2(Vector2(shield_left, top),
			Vector2(width * parts["shield_fill"], height)), Teams.shield_color(mine))
		# Die Fuge zwischen den beiden Teilen, damit ein leerer Schild nicht
		# wie ein Stueck fehlender Integritaet aussieht.
		if parts["hp_slot"] > 0.0 and parts["shield_slot"] > 0.0:
			draw_rect(Rect2(Vector2(shield_left - 0.5 * s, top),
				Vector2(1.0 * s, height)), COLOR_OUTLINE)

		# Der Zeiger auf die aktive Einheit. Er wippt, weil ein stehendes
		# Dreieck neben dem Balken untergeht.
		if active:
			_marker(Vector2(center.x, top - 4.0 * s), Teams.color(mine), s)

	## Ein nach unten zeigendes Dreieck, das ueber der Nulllage wippt.
	func _marker(at: Vector2, color: Color, s: float) -> void:
		var bob := sin(float(Time.get_ticks_msec()) / 260.0) * 3.0 * s
		var tip := at + Vector2(0.0, bob)
		draw_colored_polygon(PackedVector2Array([
			tip + Vector2(-7.0 * s, -10.0 * s), tip + Vector2(7.0 * s, -10.0 * s), tip,
		]), Color(color, 0.95))


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
	const ABOVE_BADGE := -96.0

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
