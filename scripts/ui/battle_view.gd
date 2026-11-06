class_name BattleView
extends Node2D

## Zeichnet Gitter, Einheiten und Markierungen.
##
## Kennt die Regeln nicht -- es fragt den BattleManager und stellt dar, was er
## sagt. Umgekehrt kennt der Manager diese Klasse nicht.
##
## ### Warum kein TileMapLayer
##
## Das Kachelverhaeltnis ist sqrt(2):1 und faellt aus der 45-Grad-Kamera des
## Bauteil-Renderers; Felder und Einheiten sortieren sich als Sprites in einer
## gemeinsamen Tiefenordnung.
##
## Die Umrechnung bleibt trotzdem an genau einer Stelle: IsoView.

## Abstand zwischen zwei Tiefenstufen. Gross genug, dass die Bauteile einer
## Einheit dazwischen passen, ohne in die naechste Reihe zu rutschen.
const DEPTH_STRIDE := 16
const UNIT_DEPTH_OFFSET := 8

const OVERLAY_TILE := "res://assets/terrain/overlay_tile.svg"

var grid: Grid

var _world: Node2D
var _badges: UnitBadgePainter
var _effects: EffectPainter
var _tile_sprites: Dictionary = {}
var _zone_sprites: Array = []


func _ready() -> void:
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)

	_badges = UnitBadgePainter.new()
	_badges.name = "UnitBadges"
	add_child(_badges)

	_effects = EffectPainter.new()
	_effects.name = "Effects"
	add_child(_effects)


# ---------------------------------------------------------------------------
# Boden
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

		var path: String = grid.region.floor_texture if grid.region != null else ""
		if path != "" and ResourceLoader.exists(path):
			sprite.texture = load(path)
		else:
			# Fehlendes Tile wird als Fehlmarkierung sichtbar, nicht ersetzt.
			sprite.texture = load(OVERLAY_TILE)
			sprite.modulate = Color.MAGENTA
		IsoView.fit_sprite(sprite)
		_world.add_child(sprite)
		_tile_sprites[tile] = sprite


## Felder einfaerben -- die Aufstellungszone vor dem Kampf.
func show_zone(tiles: Array, color: Color) -> void:
	clear_zone()
	for tile in tiles:
		var sprite := Sprite2D.new()
		sprite.texture = load(OVERLAY_TILE)
		sprite.centered = false
		sprite.position = IsoView.sprite_position(tile)
		sprite.z_index = IsoView.depth(tile) * DEPTH_STRIDE + 2
		sprite.modulate = color
		IsoView.fit_sprite(sprite)
		_world.add_child(sprite)
		_zone_sprites.append(sprite)


func clear_zone() -> void:
	for sprite in _zone_sprites:
		sprite.queue_free()
	_zone_sprites.clear()


# ---------------------------------------------------------------------------
# Einheiten
# ---------------------------------------------------------------------------

func attach_unit(unit: Unit) -> void:
	_world.add_child(unit)
	refresh_unit_depth(unit)


func refresh_unit_depth(unit: Unit) -> void:
	unit.z_index = IsoView.depth(unit.tile) * DEPTH_STRIDE + UNIT_DEPTH_OFFSET


func refresh_all_depths(units: Array) -> void:
	for unit in units:
		if unit.is_alive():
			refresh_unit_depth(unit)
		else:
			unit.visible = false


# ---------------------------------------------------------------------------
# Anzeige ueber den Einheiten
# ---------------------------------------------------------------------------

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
	_effects.pixel_scale = factor


## Echtzeit: eine Schussspur von ``from`` nach ``to`` (Weltkoordinaten der
## Feldmitten), kurz und in Teamfarbe.
func show_shot(from: Vector2, to: Vector2, color: Color, heavy: bool = false) -> void:
	_effects.add_shot(from, to, color, heavy)


## Schwebender Text ueber einer Stelle: Schaden, Reparatur, Faehigkeit.
func show_float(at: Vector2, text: String, color: Color, big: bool = false) -> void:
	_effects.add_text(at, text, color, big)


func show_unit_badges(entries: Array) -> void:
	_badges.entries = entries
	_badges.queue_redraw()


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
	const COLOR_LURED := Color(1.0, 0.62, 0.15)

	var entries: Array = []

	## Umrechnung Welt -> Bildschirm. Siehe BattleView.set_pixel_scale().
	var pixel_scale: float = 1.0

	func _ready() -> void:
		# Ueber den Einheiten, unter den Schadenszahlen.
		z_index = 4005

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
		var center: Vector2 = entry["at"] if entry.has("at") \
			else IsoView.map_to_local(entry["tile"])
		var mine: bool = entry.get("is_player", false)

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

		# Gelockt (Molok-Praesenz, Koedersender): ein kleines Ausrufezeichen
		# in Orange links neben dem Balken -- "der greift gerade den Locker an".
		if entry.get("lured", false):
			var at := Vector2(left - 7.0 * s, top + height * 0.5)
			draw_circle(at, 5.0 * s, COLOR_OUTLINE)
			draw_circle(at, 4.0 * s, COLOR_LURED)
			draw_rect(Rect2(at + Vector2(-0.8, -2.8) * s, Vector2(1.6, 3.4) * s), COLOR_OUTLINE)
			draw_rect(Rect2(at + Vector2(-0.8, 1.2) * s, Vector2(1.6, 1.4) * s), COLOR_OUTLINE)



## Echtzeit-Effekte: Schussspuren und schwebende Zahlen.
##
## Im Echtzeit-Kampf passiert viel gleichzeitig. Ohne sichtbare Spur waere
## nicht zu erkennen, WER auf WEN schiesst. Alles in einem Knoten, aus
## demselben Grund wie die Balken: Knoten, die dauernd entstehen und vergehen,
## bleiben irgendwann als Rest im Baum haengen.
class EffectPainter extends Node2D:
	const SHOT_TIME := 0.22
	const TEXT_TIME := 0.9
	const TEXT_SIZE := 16
	const BIG_SIZE := 18
	const RISE := 34.0
	const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.85)

	var pixel_scale: float = 1.0
	var _shots: Array = []
	var _texts: Array = []

	func _ready() -> void:
		z_index = 4020

	func add_shot(from: Vector2, to: Vector2, color: Color, heavy: bool) -> void:
		_shots.append({"from": from, "to": to, "color": color, "age": 0.0,
			"heavy": heavy})

	func add_text(at: Vector2, text: String, color: Color, big: bool) -> void:
		# Mehrere Zahlen am selben Ort stapeln sich, statt sich zu ueberdecken.
		var stack := 0
		for entry in _texts:
			if (entry["at"] as Vector2).distance_to(at) < 8.0 and float(entry["age"]) < 0.3:
				stack += 1
		_texts.append({"at": at, "text": text, "color": color, "age": 0.0,
			"big": big, "stack": stack})

	func _process(delta: float) -> void:
		if _shots.is_empty() and _texts.is_empty():
			return
		for entry in _shots:
			entry["age"] = float(entry["age"]) + delta
		for entry in _texts:
			entry["age"] = float(entry["age"]) + delta
		_shots = _shots.filter(func(e): return float(e["age"]) < SHOT_TIME)
		_texts = _texts.filter(func(e): return float(e["age"]) < TEXT_TIME)
		queue_redraw()

	func _draw() -> void:
		var s := pixel_scale
		for entry in _shots:
			var t: float = float(entry["age"]) / SHOT_TIME
			var color: Color = entry["color"]
			var from: Vector2 = entry["from"] + Vector2(0, -34)
			var to: Vector2 = entry["to"] + Vector2(0, -24)
			# Die Spur waechst zum Ziel und verblasst dann von hinten.
			var head := from.lerp(to, clampf(t * 2.5, 0.0, 1.0))
			var tail := from.lerp(to, clampf(t * 2.5 - 0.6, 0.0, 1.0))
			var width := (5.0 if entry["heavy"] else 3.0) * maxf(1.0, s * 0.8)
			draw_line(tail, head, Color(color, 0.35 * (1.0 - t)), width * 2.2, true)
			draw_line(tail, head, Color(color.lightened(0.5), 1.0 - t), width, true)
			if t > 0.35:
				draw_circle(to, (6.0 if entry["heavy"] else 4.0) * s * (1.0 - t) + 1.0,
					Color(color.lightened(0.6), 1.0 - t))
		var font := ThemeDB.fallback_font
		for entry in _texts:
			var t: float = float(entry["age"]) / TEXT_TIME
			var size := maxi(1, int(round((BIG_SIZE if entry["big"] else TEXT_SIZE) * s)))
			var at: Vector2 = entry["at"] + Vector2(0, (-84.0 - RISE * t - 18.0 * int(entry["stack"])) * s)
			var text: String = entry["text"]
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var origin := at - Vector2(width * 0.5, 0)
			var alpha := 1.0 if t < 0.6 else 1.0 - (t - 0.6) / 0.4
			font.draw_string(get_canvas_item(), origin + Vector2(1.5, 1.5) * s, text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(COLOR_SHADOW, alpha))
			font.draw_string(get_canvas_item(), origin, text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(entry["color"], alpha))
