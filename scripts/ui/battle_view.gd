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


var grid: Grid

var _world: Node2D
var _badges: UnitBadgePainter
var _effects: EffectPainter
var _arena: Array = []
var _zone: ZonePainter
## Faehigkeiten lesbar: Bodenmarken und Statuszeichen (18. Nov. 2026).
var abilities: AbilityPainter
## Die gemeinsame 3D-Szene: Hindernisse und alle DROMEs (seit 18. Nov. 2026).
var arena3d: Arena3D
## Kampfbild mehr 3D (21. Nov. 2026): Teilchen (B7), liegende Ringe am Boden,
## lebendiger Rand (D12).
var particles: ParticleFx
var _floor_rings: FloorRings
var _edge: EdgeLife


func _ready() -> void:
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)

	_zone = ZonePainter.new()
	_zone.name = "Zone"
	_world.add_child(_zone)

	abilities = AbilityPainter.new()
	abilities.name = "Faehigkeiten"
	_world.add_child(abilities)

	_badges = UnitBadgePainter.new()
	_badges.name = "UnitBadges"
	add_child(_badges)

	_effects = EffectPainter.new()
	_effects.name = "Effects"
	add_child(_effects)

	particles = ParticleFx.new()
	particles.name = "Teilchen"
	add_child(particles)
	_effects.particles = particles

	_floor_rings = FloorRings.new()
	_floor_rings.name = "Bodenringe"
	_floor_rings.painter = _effects
	add_child(_floor_rings)
	_effects.floor_rings = _floor_rings


# ---------------------------------------------------------------------------
# Boden
# ---------------------------------------------------------------------------

## Boden aus 3D-Platten (ArenaFloor3D), Zierlinie und Licht (ArenaPainter),
## Hindernisse und Deko in der 3D-Szene (Arena3D).
func build_terrain(battle_grid: Grid) -> void:
	grid = battle_grid
	abilities.grid = grid
	for node in _arena:
		node.queue_free()
	_arena = ArenaPainter.build(_world, grid)
	# Boden aus 3D-Hexplatten, einmal gerendert (18. Nov. 2026), ganz unten.
	var floor := ArenaFloor3D.new()
	floor.name = "Boden3D"
	floor.z_index = -70
	floor.build(grid)
	_world.add_child(floor)
	_arena.append(floor)
	if arena3d == null:
		arena3d = Arena3D.new()
		arena3d.name = "Arena3D"
		_world.add_child(arena3d)
	arena3d.build_obstacles(grid)
	arena3d.build_props(grid)
	arena3d.fx = particles
	for node in _arena:
		if node is ArenaPainter.Lights:
			arena3d.light_spots = node.spots
	if _edge != null and is_instance_valid(_edge):
		_edge.queue_free()
	_edge = EdgeLife.create(grid, particles)
	_world.add_child(_edge)
	_arena.append(_edge)


## Felder einfaerben -- die Aufstellungszone vor dem Kampf.
func show_zone(tiles: Array, color: Color) -> void:
	_zone.tiles = tiles
	_zone.color = color
	_zone.target = null
	_zone.selected = null
	_zone.queue_redraw()


func clear_zone() -> void:
	show_zone([], Color.WHITE)


## Aufstellung: das Feld, auf dem die gezogene Figur landen wuerde (``ok``:
## in der Zone), und das Feld der angetippten Figur. null loescht.
func mark_zone(target, ok: bool, selected) -> void:
	if _zone.target == target and _zone.target_ok == ok and _zone.selected == selected:
		return
	_zone.target = target
	_zone.target_ok = ok
	_zone.selected = selected
	_zone.queue_redraw()


## Die Aufstellungszone als einzelne Kaestchen (10. Nov. 2026): je Feld eine
## Raute mit Rand, damit man sieht, WO eine Figur stehen kann -- vorher eine
## durchgehende gruene Flaeche. Dazu das Zielfeld beim Ziehen und das Feld der
## gewaehlten Figur.
class ZonePainter extends Node2D:
	var tiles: Array = []
	var color := Color.WHITE
	var target = null
	var target_ok := true
	var selected = null

	func _ready() -> void:
		# Ueber dem Boden (-60/-50), unter Hindernissen und Figuren (ab 8).
		z_index = -40

	func _draw() -> void:
		for tile in tiles:
			_tile(tile, 0.86, Color(color, 0.14), Color(color, 0.6), 1.5)
		if selected != null:
			_tile(selected, 0.92, Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.95), 2.5)
		if target != null:
			var mark := Color(0.45, 1.0, 0.7) if target_ok else Color(1.0, 0.4, 0.35)
			_tile(target, 0.94, Color(mark, 0.4), Color(mark, 1.0), 3.0)

	func _tile(tile: Vector2i, shrink: float, fill: Color, line: Color, width: float) -> void:
		var center := IsoView.map_to_local(tile)
		var points := PackedVector2Array()
		for corner in IsoView.tile_corners(tile):
			points.append(center + (corner - center) * shrink)
		draw_colored_polygon(points, fill)
		points.append(points[0])
		draw_polyline(points, line, width, true)


# ---------------------------------------------------------------------------
# Einheiten
# ---------------------------------------------------------------------------

func attach_unit(unit: Unit) -> void:
	if arena3d != null:
		unit.arena = arena3d
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
	_badges.zoom = camera_zoom
	_badges.queue_redraw()
	_effects.pixel_scale = factor
	abilities.pixel_scale = factor
	if particles != null:
		particles.pixel_scale = factor
	if _floor_rings != null:
		_floor_rings.pixel_scale = factor


## Echtzeit: eine Schussspur von ``from`` nach ``to`` (Weltkoordinaten der
## Feldmitten), kurz und in Teamfarbe. Alter Weg ohne Stil (gerader Schuss).
func show_shot(from: Vector2, to: Vector2, color: Color, heavy: bool = false) -> void:
	_effects.add_attack(from, to, color, {"projectile": "bolt", "energy": 0.0, "heavy": heavy})


## Ein Angriff mit Stil (9. Nov. 2026, Wunsch des Spielers):
##   projectile  "" (Nahkampf, keins), "bolt" (gerader Schuss), "slug"
##               (schweres Geschoss), "orb" (Energiekugel), "beam" (Heilstrahl)
##   energy      Energieanteil 0..1: >= 0,5 leuchtend und durchscheinend,
##               sonst matt; der Einschlag zeigt Ring (Energie) und/oder
##               Funken (kinetisch) nach dem Anteil
##   heavy       groesser (Faehigkeit, Flaeche)
##   area        Radius der Flaeche in Feldern (Ring am Ziel)
func show_attack(from: Vector2, to: Vector2, color: Color, style: Dictionary) -> void:
	# Seit 21. Nov. 2026 fliegen Geschosse in der 3D-Szene (Arena3D.add_shot);
	# hier bleibt nur der Einschlag, zur selben Zeit.
	var kind := str(style.get("projectile", ""))
	if arena3d != null and arena3d.add_shot(from, to, color, style,
			float(EffectPainter.FLIGHT.get(kind, 0.0))):
		style = style.duplicate()
		style["in_3d"] = true
	_effects.add_attack(from, to, color, style)


## Vortex lesbar (DROME_DESIGNREGELN Abschnitt 7): Bodenmarke ueber die
## Flaeche um ``tile`` bis zum Einschlag, dann Schockwelle.
func show_vortex(tile: Vector2i, radius: int, delay: float, color: Color, enemy: bool = false) -> void:
	abilities.add_vortex(IsoView.map_to_local(tile), radius, delay, color, enemy)


## Die Ansage einer Faehigkeit waehrend ihrer Ausholzeit.
func show_cast(kind: String, data: Dictionary, seconds: float) -> void:
	abilities.add_cast(kind, data, seconds)


## Jede andere Faehigkeit lesbar (Formen siehe AbilityPainter.add).
func show_ability(kind: String, data: Dictionary) -> void:
	abilities.add(kind, data)


## Schwebender Text ueber einer Stelle: Schaden, Reparatur, Faehigkeit.
func show_float(at: Vector2, text: String, color: Color, big: bool = false) -> void:
	_effects.add_text(at, text, color, big)


func show_unit_badges(entries: Array) -> void:
	_badges.entries = entries
	_badges.queue_redraw()


## Der Lebensbalken ueber jedem DROME.
##
## Integritaet und Schild teilen sich die Breite im Verhaeltnis ihrer
## Hoechstwerte: 200 Integritaet und 100 Schild heisst zwei Drittel
## Integritaet, ein Drittel Schild. Beide Teile leeren sich an Ort und Stelle,
## die Gesamtlaenge bleibt -- so sieht man auf einen Blick, wie viel vom
## ganzen DROME noch steht. Die Farbe traegt die Seite (eigene gruen/blau,
## Gegner rot/violett), dazu die FORM: Gegnerbalken haben abgeschraegte
## Enden -- lesbar auch ohne Farbsehen.
##
## Lesbarkeit (7. Nov. 2026, mit dem Spieler abgesprochen):
##   * Der Abstand zur Figur rechnet in Welt-Einheiten (er gehoert zur
##     Figur), die Groesse des Balkens in Bildschirm-Pixeln. Vorher wuchs
##     auch der Abstand beim Herauszoomen mit, und der Balken schwebte
##     mehrere Figurenhoehen ueber dem DROME.
##   * Detailstufen nach Zoom: nah Balken, Takt und Zustands-Symbole; mittel
##     Balken und Takt; fern nur ein schmaler Balken, und wo es eng wird,
##     bleibt nur der Ring am Boden.
##   * Ein Treffer laesst den verlorenen Teil kurz hell stehen, dann laeuft
##     er nach -- man sieht, wie gross der Treffer war.
##   * Unter 25 % Integritaet pulsiert der Rand rot.
##   * Ueberlappende Balken weichen nach oben aus (duenne Linie zur Figur).
##   * Ein angetippter DROME (Kachel oben) hat ein paar Sekunden lang einen
##     groesseren Balken.
##
## Alles in EINEM Knoten und nicht als Label je Einheit: die Werte aendern sich
## nach jeder Aktion, und Knoten, die dabei entstehen und vergehen, haengen
## zwangslaeufig irgendwann als Rest im Baum.
class UnitBadgePainter extends Node2D:
	const WIDTH := 56.0
	## Seit 22. Nov. 2026 (Spieler): 6 hoch, ohne schwarzen Grund -- nur ein
	## schwarzer Umriss, der oben rechts und unten links mit abgeschraegt ist.
	const HEIGHT := 6.0
	## Deckkraft des leeren Teils (nur ein Hauch, kein schwarzer Balken).
	const EMPTY_ALPHA := 0.22
	## Unterkante von Balken samt Takt-Leisten ueber der Feldmitte -- in
	## WELT-Einheiten, mal Figurgroesse. Seit 24. Nov. 2026 (Spieler: "die
	## Balken verdecken den halben DROME") ueber dem Kopf statt auf der Brust.
	const BASE_Y := -106.0

	const COLOR_TRACK := Color(0.04, 0.05, 0.08, 0.9)
	const COLOR_OUTLINE := Color(0.0, 0.0, 0.0, 0.9)
	const COLOR_LURED := Color(1.0, 0.62, 0.15)
	const COLOR_GHOST := Color(1.0, 0.95, 0.85)
	const COLOR_DANGER := Color(1.0, 0.25, 0.2)
	## Takt-Leiste unter dem Lebensbalken: wann kommt die Faehigkeit?
	## Seit 21. Nov. 2026 als einzelne Kaestchen je Angriff (vorher eine 3 px
	## duenne Leiste, kaum zu lesen): leer nur als Umriss, gefuellt gelb, voll
	## = alle hell und ein pulsierender Rahmen -- der naechste Angriff ist die
	## Faehigkeit.
	const TAKT_HEIGHT := 5.0
	const TAKT_GAP := 3.0
	const TAKT_PIP_GAP := 2.0
	const COLOR_TAKT := Color(1.0, 0.82, 0.35)
	const COLOR_TAKT_READY := Color(1.0, 1.0, 0.85)

	## Zoomstufen fuer die Details.
	const ZOOM_NEAR := 0.75
	const ZOOM_FAR := 0.45
	const LOW_HP := 0.25
	const FOCUS_SCALE := 1.35
	## Nachlauf nach einem Treffer: so lange steht der verlorene Teil, dann
	## laeuft er mit dieser Rate (Anteil der Breite je Sekunde) nach.
	const GHOST_HOLD := 0.35
	const GHOST_RATE := 0.8

	var entries: Array = []

	## Umrechnung Welt -> Bildschirm. Siehe BattleView.set_pixel_scale().
	var pixel_scale: float = 1.0
	## Der Kamera-Zoom selbst -- fuer die Detailstufe.
	var zoom: float = 1.0

	## Nachlauf je Einheit: id -> {hp, shield, hold_until}
	var _ghosts: Dictionary = {}

	func _ready() -> void:
		# Ueber den Einheiten, unter den Schadenszahlen.
		z_index = 4005

	func detail() -> String:
		if zoom >= ZOOM_NEAR:
			return "near"
		return "mid" if zoom >= ZOOM_FAR else "far"

	func _draw() -> void:
		var now := Time.get_ticks_msec() / 1000.0
		var level := detail()
		var boxes := []
		for entry in entries:
			boxes.append(_box(entry, level))
		var lifts := UnitBadgePainter.layout(boxes.map(func(b): return b["rect"]),
			3 if level != "far" else 0)
		for i in entries.size():
			var lift: float = lifts[i]
			if lift < 0.0:
				continue      # fern und verdeckt: nur der Ring am Boden
			_badge(entries[i], boxes[i], lift, level, now)

	## Wo der Balken samt Takt-Leisten liegt (ohne Ausweichen).
	func _box(entry: Dictionary, level: String) -> Dictionary:
		var s := pixel_scale * _size_factor(level)
		if entry.get("focus", false):
			s *= FOCUS_SCALE
		var center: Vector2 = entry["at"] if entry.has("at") \
			else IsoView.map_to_local(entry["tile"])
		var width := WIDTH * s
		var height := HEIGHT * s * (0.7 if level == "far" else 1.0)
		var takt_rows: int = 0 if level == "far" else (entry.get("takt", []) as Array).size()
		var base := BASE_Y * Arena3D.figure_scale()
		# Sentinels: kleiner Balken, naeher an der kleineren Figur.
		if entry.get("small", false):
			width *= 0.6
			height *= 0.75
			base *= 0.62
			takt_rows = 0
		var total := height + float(takt_rows) * (TAKT_HEIGHT + TAKT_GAP) * s
		var top := center.y + base - total
		return {"s": s, "width": width, "height": height, "center": center,
			"rect": Rect2(center.x - width * 0.5, top, width, total)}

	## Fern werden die Balken etwas kleiner, damit mehr Feld frei bleibt.
	func _size_factor(level: String) -> float:
		match level:
			"far": return 0.7
			"mid": return 0.85
		return 1.0

	## Ausweichen: von unten nach oben, jeder Balken, der einen schon
	## gesetzten ueberlappt, rueckt um seine Hoehe nach oben -- hoechstens
	## ``max_lifts`` Mal. Gibt je Rechteck den Versatz nach oben zurueck,
	## -1 heisst "nicht zeichnen" (bei max_lifts 0: verdeckt). Statisch, damit
	## der Test es ohne Zeichnen pruefen kann.
	static func layout(rects: Array, max_lifts: int) -> Array:
		var order := range(rects.size())
		order.sort_custom(func(a, b): return rects[a].position.y > rects[b].position.y)
		var placed: Array = []
		var lifts := []
		lifts.resize(rects.size())
		for index in order:
			var rect: Rect2 = rects[index]
			var lift := 0.0
			var tries := 0
			while _hits(rect, placed):
				if tries >= max_lifts:
					lift = -1.0
					break
				var step := rect.size.y + 3.0
				rect.position.y -= step
				lift += step
				tries += 1
			lifts[index] = lift
			if lift >= 0.0:
				placed.append(rect.grow(1.0))
		return lifts

	static func _hits(rect: Rect2, placed: Array) -> bool:
		for other in placed:
			if rect.intersects(other):
				return true
		return false

	## Die Aufteilung des Balkens als Anteile 0..1 der Gesamtbreite:
	## { hp_slot, hp_fill, shield_slot, shield_fill }. Statisch, damit der
	## Test sie ohne Zeichnen pruefen kann.
	static func split(hp: int, hp_max: int, shield: int, shield_max: int) -> Dictionary:
		var total := float(maxi(0, hp_max) + maxi(0, shield_max))
		if total <= 0.0:
			return {"hp_slot": 0.0, "hp_fill": 0.0, "shield_slot": 0.0, "shield_fill": 0.0, "over": 0.0}
		var hp_slot := float(maxi(0, hp_max)) / total
		var shield_slot := 1.0 - hp_slot
		return {
			"hp_slot": hp_slot,
			"hp_fill": hp_slot * clampf(float(hp) / maxf(1.0, float(hp_max)), 0.0, 1.0),
			"shield_slot": shield_slot,
			"shield_fill": shield_slot * (clampf(float(shield) / float(shield_max), 0.0, 1.0)
				if shield_max > 0 else 0.0),
			"over": overshield(shield, shield_max),
		}

	## Wie weit der Ueberschild gefuellt ist, 0..1: der Schild ueber dem
	## Maximum, gemessen an dem, was Schildgaben hoechstens drauflegen
	## (combat.support.overshield, 50 % des Maximums).
	static func overshield(shield: int, shield_max: int) -> float:
		if shield_max <= 0 or shield <= shield_max:
			return 0.0
		var share := float((Config.section("combat").get("support", {}) as Dictionary)
			.get("overshield", 0.5))
		if share <= 0.0:
			return 0.0
		return clampf(float(shield - shield_max) / (float(shield_max) * share), 0.0, 1.0)

	## Der nachlaufende Anteil: steht nach einem Treffer kurz, dann laeuft er
	## dem echten Wert nach. Heilung springt sofort.
	func _ghost(id, key: String, value: float, now: float) -> float:
		if id == null:
			return value
		var state: Dictionary = _ghosts.get(id, {})
		var last: float = state.get(key, value)
		var last_time: float = state.get("t_" + key, now)
		var hold: float = state.get("hold_" + key, 0.0)
		if value > last:
			last = value
		elif value < last - 0.0001 and hold <= 0.0:
			hold = now + GHOST_HOLD
		if hold > 0.0 and now >= hold:
			last = maxf(value, last - GHOST_RATE * (now - last_time))
			if last <= value + 0.0001:
				hold = 0.0
		state[key] = last
		state["t_" + key] = now
		state["hold_" + key] = hold
		_ghosts[id] = state
		return last

	func _badge(entry: Dictionary, box: Dictionary, lift: float, level: String, now: float) -> void:
		var s: float = box["s"]
		var center: Vector2 = box["center"]
		var mine: bool = entry.get("is_player", false)
		var width: float = box["width"]
		var height: float = box["height"]
		var left := center.x - width * 0.5
		var top: float = (box["rect"] as Rect2).position.y - lift

		var parts := split(int(entry.get("hp", 0)), int(entry.get("hp_max", 0)),
			int(entry.get("shield", 0)), int(entry.get("shield_max", 0)))
		var id = entry.get("id")
		var hp_ghost := _ghost(id, "hp", parts["hp_fill"], now)
		var sh_ghost := _ghost(id, "shield", parts["shield_fill"], now)
		var pad := 1.0 * s

		# Ausgewichen: duenne Linie zur Figur, damit klar bleibt, wem er gehoert.
		if lift > 0.0:
			draw_line(Vector2(center.x, top + height), Vector2(center.x, center.y + BASE_Y),
				Color(1, 1, 1, 0.35), 1.0 * s)

		var hp_ratio := float(entry.get("hp", 0)) / maxf(1.0, float(entry.get("hp_max", 1)))
		var outline := COLOR_OUTLINE
		if hp_ratio < LOW_HP and hp_ratio > 0.0:
			var pulse := 0.5 + 0.5 * sin(now * TAU * 1.5)
			outline = COLOR_DANGER.lerp(COLOR_OUTLINE, 0.6 * (1.0 - pulse))
			pad = 1.6 * s
		# Form: abgeschraegt oben rechts und unten links (Arcade-Form). Fuellungen
		# werden auf diese Form beschnitten, darum nur ein Umriss.
		var cut := height * 0.9
		var shape := _chamfer(left, top, width, height, cut)
		draw_colored_polygon(shape, Color(COLOR_TRACK, EMPTY_ALPHA))
		# Nachlauf zuerst, darueber der echte Wert.
		_fill(shape, left, left + width * hp_ghost, top, height, COLOR_GHOST)
		_fill(shape, left, left + width * parts["hp_fill"], top, height, Teams.hp_color(mine))
		var shield_left: float = left + width * float(parts["hp_slot"])
		_fill(shape, shield_left, shield_left + width * sh_ghost, top, height, COLOR_GHOST)
		_fill(shape, shield_left, shield_left + width * parts["shield_fill"], top, height,
			Teams.shield_color(mine))
		# Die Fuge zwischen den beiden Teilen, damit ein leerer Schild nicht
		# wie ein Stueck fehlender Integritaet aussieht.
		if parts["hp_slot"] > 0.0 and parts["shield_slot"] > 0.0:
			draw_line(Vector2(shield_left, top), Vector2(shield_left, top + height),
				COLOR_OUTLINE, 1.0 * s)
		var ring := _chamfer(left - pad * 0.5, top - pad * 0.5, width + pad, height + pad,
			cut + pad * 0.5)
		ring.append(ring[0])
		draw_polyline(ring, outline, pad * 1.6)
		# Ueberschild: Rahmen um den Schildteil, links immer ganz, oben und
		# unten so weit, wie er gefuellt ist; voll = rundum (folgt der Schraege).
		var over: float = parts["over"]
		var below := top + height + pad
		if over > 0.0 and parts["shield_slot"] > 0.0:
			below += 1.6 * s
			var line := 1.6 * s
			# Aussen um den Balken (ueber dem dunklen Rand), damit die
			# Schildfuellung frei bleibt.
			var x0 := shield_left
			var x1 := left + width + pad + line * 0.5
			var y0 := top - pad - line * 0.5
			var y1 := top + height + pad + line * 0.5
			var reach := x0 + (x1 - x0) * over
			var corner := cut + line * 0.5
			if over >= 0.999:
				draw_polyline(PackedVector2Array([Vector2(x0, y0), Vector2(x1 - corner, y0),
					Vector2(x1, y0 + corner), Vector2(x1, y1), Vector2(x0, y1), Vector2(x0, y0)]),
					Teams.OVERSHIELD, line)
			else:
				draw_polyline(PackedVector2Array([Vector2(minf(reach, x1 - corner), y0),
					Vector2(x0, y0), Vector2(x0, y1), Vector2(reach, y1)]), Teams.OVERSHIELD, line)

		if level != "far":
			_takt(entry.get("takt", []), left, below, width, s, now)
		if level == "near":
			_statuses(entry.get("statuses", []), left + width + 5.0 * s, top + height * 0.5, s)

		# Gelockt (Molok-Praesenz, Koedersender): ein kleines Ausrufezeichen
		# in Orange links neben dem Balken -- "der greift gerade den Locker an".
		if entry.get("lured", false) and level != "far":
			var at := Vector2(left - 7.0 * s, top + height * 0.5)
			draw_circle(at, 5.0 * s, COLOR_OUTLINE)
			_icon("lured", at, 5.0 * s, COLOR_LURED)

	## Rechteck mit abgeschraegten Ecken oben rechts und unten links.
	static func _chamfer(x: float, y: float, w: float, h: float, cut: float) -> PackedVector2Array:
		cut = minf(cut, minf(w, h))
		return PackedVector2Array([Vector2(x, y), Vector2(x + w - cut, y), Vector2(x + w, y + cut),
			Vector2(x + w, y + h), Vector2(x + cut, y + h), Vector2(x, y + h - cut)])

	## Fuellt den Streifen x0..x1 innerhalb von ``shape``.
	func _fill(shape: PackedVector2Array, x0: float, x1: float, top: float, height: float,
			color: Color) -> void:
		if x1 - x0 < 0.05:
			return
		var strip := PackedVector2Array([Vector2(x0, top - 1.0), Vector2(x1, top - 1.0),
			Vector2(x1, top + height + 1.0), Vector2(x0, top + height + 1.0)])
		for piece in Geometry2D.intersect_polygons(strip, shape):
			if piece.size() >= 3:
				draw_colored_polygon(piece, color)

	## UI-Symbol (assets/ui_icons) mittig auf ``at``, halbe Kante ``half``.
	func _icon(name: String, at: Vector2, half: float, color: Color) -> void:
		var texture := UiIcon.texture(name)
		if texture == null:
			draw_circle(at, half * 0.4, color)
			return
		draw_texture_rect(texture, Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0), false, color)

	## Kleine Zustands-Symbole rechts neben dem Balken (nur nah):
	## betaeubt = gelber Stern, verlangsamt = blauer Pfeil nach unten,
	## verwundbar = roter Riss, Sprint = gruener Pfeil nach vorn, Kabelbrand =
## oranger Blitz am Kabel
	## (assets/ui_icons/<id>.svg, seit 15. Nov. 2026).
	const STATUS_COLOR := {"stun": Color(1.0, 0.9, 0.3), "slow": Color(0.45, 0.7, 1.0),
		"vulnerable": Color(1.0, 0.4, 0.35), "rush": Color(0.5, 0.95, 0.55),
		"cable_fire": Color(1.0, 0.55, 0.15)}

	func _statuses(ids: Array, x: float, y: float, s: float) -> void:
		for id in ids:
			var c := Vector2(x + 4.0 * s, y)
			draw_circle(c, 5.0 * s, COLOR_OUTLINE)
			_icon(str(id), c, 4.6 * s, STATUS_COLOR.get(str(id), Color.WHITE))
			x += 11.0 * s

	## Je Faehigkeit eine duenne Leiste unter dem Lebensbalken, gleich breit.
	## Treffer-Takt: ein Abschnitt je Angriff (jeder 4. Angriff = vier
	## Abschnitte zu je einem Viertel), gefuellt je Treffer. Zeit-Takt: eine
	## Leiste, die sich in halben Sekunden fuellt. Volle Leiste leuchtet hell:
	## als Naechstes kommt die Faehigkeit.
	func _takt(bars: Array, left: float, top: float, width: float, s: float,
			now: float = 0.0) -> void:
		var h := TAKT_HEIGHT * s
		var y := top + TAKT_GAP * s * 0.5
		for bar in bars:
			var ready: bool = bar.get("ready", false)
			var color := COLOR_TAKT_READY if ready else COLOR_TAKT
			if ready:
				# Pulsierender Rahmen um die ganze Leiste.
				var glow := 1.0 if Accessibility.reduce_motion else 0.55 + 0.45 * sin(now * TAU * 2.5)
				draw_rect(Rect2(Vector2(left - 2.5 * s, y - 2.5 * s), Vector2(width + 5.0 * s, h + 5.0 * s)),
					Color(COLOR_TAKT_READY, 0.9 * glow), false, 1.5 * s)
			if bar["kind"] == "hits":
				var n: int = maxi(1, int(bar["segments"]))
				var gap := TAKT_PIP_GAP * s
				var piece := (width - gap * float(n - 1)) / float(n)
				for i in n:
					var rect := Rect2(Vector2(left + (piece + gap) * float(i), y), Vector2(piece, h))
					draw_rect(rect.grow(s), COLOR_OUTLINE)
					if ready or i < int(bar["filled"]):
						draw_rect(rect, color)
					else:
						draw_rect(rect, COLOR_TRACK)
						draw_rect(rect, Color(COLOR_TAKT, 0.45), false, 1.0 * s)
			else:
				draw_rect(Rect2(Vector2(left - s, y - s), Vector2(width + 2.0 * s, h + 2.0 * s)),
					COLOR_OUTLINE)
				draw_rect(Rect2(Vector2(left, y), Vector2(width, h)), COLOR_TRACK)
				draw_rect(Rect2(Vector2(left, y), Vector2(width * float(bar["fill"]), h)),
					color)
			y += h + TAKT_GAP * s


## Echtzeit-Effekte: Schussspuren und schwebende Zahlen.
##
## Im Echtzeit-Kampf passiert viel gleichzeitig. Ohne sichtbare Spur waere
## nicht zu erkennen, WER auf WEN schiesst. Alles in einem Knoten, aus
## demselben Grund wie die Balken: Knoten, die dauernd entstehen und vergehen,
## bleiben irgendwann als Rest im Baum haengen.
class EffectPainter extends Node2D:
	const TEXT_TIME := 0.9
	const TEXT_SIZE := 16
	const BIG_SIZE := 18
	const RISE := 34.0
	const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.85)
	## Flugzeit je Projektil (Sekunden) und Dauer des Einschlags.
	const FLIGHT := {"": 0.0, "bolt": 0.12, "slug": 0.08, "orb": 0.26, "beam": 0.0}
	const IMPACT_TIME := 0.32
	const BEAM_TIME := 0.35

	var pixel_scale: float = 1.0
	var _shots: Array = []
	var _texts: Array = []
	## Kampfbild mehr 3D (21. Nov. 2026): Funken und Rauch als Teilchen,
	## Energie- und Flaechenringe liegend am Boden (FloorRings).
	var particles: ParticleFx
	var floor_rings: FloorRings

	func _ready() -> void:
		z_index = 4020

	func add_attack(from: Vector2, to: Vector2, color: Color, style: Dictionary) -> void:
		var kind := str(style.get("projectile", "bolt"))
		var flight := float(FLIGHT.get(kind, 0.12))
		var total := (BEAM_TIME if kind == "beam" else flight + IMPACT_TIME)
		# Funken: feste Richtungen je Treffer, damit nichts flackert.
		var seed_angle := fmod(absf(to.x * 0.37 + to.y * 0.71 + from.x * 0.13), TAU)
		_shots.append({"from": from, "to": to, "color": color,
			"age": -float(style.get("wait", 0.0)),
			"kind": kind, "flight": flight, "total": total,
			"energy": float(style.get("energy", 0.0)), "heavy": bool(style.get("heavy", false)),
			"area": int(style.get("area", 0)), "spin": seed_angle,
			"from_fn": style.get("from_fn", null), "in_3d": bool(style.get("in_3d", false))})

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
			var was := float(entry["age"])
			entry["age"] = was + delta
			# Startpunkt erst beim Abfeuern holen (Salven: der Schuetze hat
			# sich inzwischen zum naechsten Ziel gedreht).
			if was < 0.0 and float(entry["age"]) >= 0.0 and entry["from_fn"] is Callable:
				entry["from"] = (entry["from_fn"] as Callable).call()
			# Einschlag beginnt: Teilchen fuer den kinetischen Anteil.
			if not entry.has("burst") and entry["kind"] != "beam" \
					and float(entry["age"]) >= float(entry["flight"]):
				entry["burst"] = true
				if _uses_particles():
					particles.hit(entry["to"], 24.0, entry["color"], float(entry["energy"]),
						bool(entry["heavy"]))
		for entry in _texts:
			entry["age"] = float(entry["age"]) + delta
		_shots = _shots.filter(func(e): return float(e["age"]) < float(e["total"]))
		_texts = _texts.filter(func(e): return float(e["age"]) < TEXT_TIME)
		queue_redraw()
		if floor_rings != null:
			floor_rings.queue_redraw()

	func _uses_particles() -> bool:
		return particles != null and is_instance_valid(particles) and not Accessibility.reduce_motion

	func shots() -> Array:
		return _shots

	func _draw() -> void:
		for entry in _shots:
			if float(entry["age"]) < 0.0:
				continue
			if entry["kind"] == "beam":
				_draw_beam(entry)
				continue
			var age: float = entry["age"]
			var flight: float = entry["flight"]
			if age < flight and entry["kind"] != "":
				if not entry["in_3d"]:
					_draw_projectile(entry, age / maxf(0.001, flight))
			elif age >= flight:
				_draw_impact(entry, (age - flight) / IMPACT_TIME)
		_draw_texts()

	func _ends(entry: Dictionary) -> Array:
		return [entry["from"] + Vector2(0, -34), entry["to"] + Vector2(0, -24)]

	## Das Projektil im Flug: leuchtend/durchscheinend bei Energie, matt bei
	## kinetisch. Gerader Schuss = Streifen, Geschoss = kurzer dicker Bolzen,
	## Kugel = pulsierender Ball mit Blitzen.
	func _draw_projectile(entry: Dictionary, t: float) -> void:
		var s := pixel_scale
		var ends := _ends(entry)
		var pos: Vector2 = (ends[0] as Vector2).lerp(ends[1], t)
		var dir: Vector2 = ((ends[1] as Vector2) - ends[0]).normalized()
		var color: Color = entry["color"]
		var glow: bool = float(entry["energy"]) >= 0.5
		var big := 1.4 if entry["heavy"] else 1.0
		match entry["kind"]:
			"orb":
				var r := 6.0 * big * maxf(1.0, s * 0.8)
				var pulse := 1.0 + 0.15 * sin(t * 30.0)
				draw_circle(pos, r * 2.0 * pulse, Color(color, 0.18))
				draw_circle(pos, r * pulse, Color(color.lightened(0.3), 0.55))
				draw_circle(pos, r * 0.45, Color(1, 1, 1, 0.9))
				# Kleine Blitze um die Kugel.
				for i in 3:
					var ang := float(entry["spin"]) + t * 12.0 + i * TAU / 3.0
					var a := pos + Vector2(cos(ang), sin(ang)) * r
					var b := pos + Vector2(cos(ang + 0.5), sin(ang + 0.5)) * r * 1.9
					draw_line(a, b, Color(color.lightened(0.6), 0.8), 1.5 * maxf(1.0, s * 0.6), true)
			"slug":
				var len := 16.0 * big * maxf(1.0, s * 0.8)
				var width := 5.0 * big * maxf(1.0, s * 0.8)
				var tail := pos - dir * len
				if glow:
					draw_line(tail, pos, Color(color, 0.3), width * 2.4, true)
					draw_line(tail, pos, Color(color.lightened(0.6), 0.85), width, true)
				else:
					draw_line(tail - dir * len, pos, Color(0.85, 0.82, 0.75, 0.25), width * 0.5, true)
					draw_line(tail, pos, Color(0.55, 0.55, 0.58), width, true)
					draw_line(tail, pos, Color(0.85, 0.85, 0.88), width * 0.4, true)
			_:
				var len := 22.0 * big * maxf(1.0, s * 0.8)
				var width := 3.0 * big * maxf(1.0, s * 0.8)
				var tail := pos - dir * len
				if glow:
					draw_line(tail, pos, Color(color, 0.28), width * 3.0, true)
					draw_line(tail, pos, Color(color.lightened(0.5), 0.75), width, true)
					draw_line(tail.lerp(pos, 0.5), pos, Color(1, 1, 1, 0.8), width * 0.5, true)
				else:
					draw_line(tail, pos, Color(0.6, 0.6, 0.62, 0.9), width, true)
					draw_line(tail.lerp(pos, 0.6), pos, Color(0.9, 0.88, 0.8), width * 0.6, true)

	## Der Einschlag: Ring fuer den Energieanteil, Funken fuer den kinetischen.
	func _draw_impact(entry: Dictionary, t: float) -> void:
		var s := pixel_scale
		var at: Vector2 = _ends(entry)[1]
		var color: Color = entry["color"]
		var energy: float = entry["energy"]
		var big := 1.5 if entry["heavy"] else 1.0
		var fade := 1.0 - t
		var on_floor := floor_rings != null and is_instance_valid(floor_rings)
		if energy > 0.0:
			if on_floor:
				# Der Ring liegt am Boden (FloorRings); hier nur ein kurzer
				# Lichtblitz an der Trefferstelle.
				if t < 0.4:
					var flash := (1.0 - t / 0.4) * clampf(0.4 + energy, 0.0, 1.0)
					draw_circle(at, 7.0 * big * maxf(1.0, s * 0.8), Color(color.lightened(0.6), 0.5 * flash))
			else:
				var r := (6.0 + 18.0 * t) * big * maxf(1.0, s * 0.8)
				var alpha := fade * clampf(0.4 + energy, 0.0, 1.0)
				draw_arc(at, r, 0.0, TAU, 28, Color(color.lightened(0.4), alpha), 2.5 * maxf(1.0, s * 0.7), true)
				draw_arc(at, r * 0.6, 0.0, TAU, 20, Color(1, 1, 1, alpha * 0.6), 1.2 * maxf(1.0, s * 0.7), true)
		if energy < 1.0 and not _uses_particles():
			var count := 7 if entry["heavy"] else 5
			for i in count:
				var ang := float(entry["spin"]) + i * TAU / float(count) + sin(i * 1.7) * 0.4
				var dir := Vector2(cos(ang), sin(ang) * 0.6)
				var from := at + dir * (3.0 + 10.0 * t) * big * maxf(1.0, s * 0.8)
				var to := at + dir * (8.0 + 22.0 * t) * big * maxf(1.0, s * 0.8)
				draw_line(from, to, Color(1.0, 0.85 - 0.3 * t, 0.45, fade * (1.0 - energy * 0.5)),
					2.0 * maxf(1.0, s * 0.6), true)
		if int(entry["area"]) > 0 and not on_floor:
			var reach := float(entry["area"]) * 34.0 * (0.4 + 0.6 * t)
			draw_arc(at + Vector2(0, 24), reach, 0.0, TAU, 40, Color(color, fade * 0.5), 3.0, true)

	## Elektronischer Heilstrahl: ein zitternder Zickzack-Strahl mit Glanz.
	func _draw_beam(entry: Dictionary) -> void:
		var s := pixel_scale
		var ends := _ends(entry)
		var a: Vector2 = ends[0]
		var b: Vector2 = ends[1]
		var t: float = float(entry["age"]) / BEAM_TIME
		var fade := 1.0 - t
		var green := Color(0.45, 1.0, 0.7)
		var normal := (b - a).normalized().orthogonal()
		var points := PackedVector2Array()
		var steps := 9
		for i in steps + 1:
			var f := float(i) / float(steps)
			var jitter := 0.0 if i == 0 or i == steps else sin(f * 37.0 + float(entry["age"]) * 60.0) * 5.0
			points.append(a.lerp(b, f) + normal * jitter * maxf(1.0, s * 0.7))
		draw_polyline(points, Color(green, 0.3 * fade), 7.0 * maxf(1.0, s * 0.7), true)
		draw_polyline(points, Color(green.lightened(0.4), 0.9 * fade), 2.0 * maxf(1.0, s * 0.7), true)
		draw_circle(b, (5.0 + 6.0 * t) * maxf(1.0, s * 0.8), Color(green, 0.4 * fade))

	func _draw_texts() -> void:
		var s := pixel_scale
		# Arcade-Schrift mit dunklem Umriss (14. Nov. 2026): lesbar auch ueber
		# hellen Effekten. Kurzes Aufpoppen am Anfang.
		var font := Arcade.font("display")
		for entry in _texts:
			var t: float = float(entry["age"]) / TEXT_TIME
			var pop := 1.0 + 0.35 * maxf(0.0, 1.0 - t * 6.0)
			var size := maxi(1, int(round((BIG_SIZE if entry["big"] else TEXT_SIZE) * s * pop)))
			var at: Vector2 = entry["at"] + Vector2(0, (-84.0 - RISE * t - 18.0 * int(entry["stack"])) * s)
			var text: String = entry["text"]
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var origin := at - Vector2(width * 0.5, 0)
			var alpha := 1.0 if t < 0.6 else 1.0 - (t - 0.6) / 0.4
			font.draw_string_outline(get_canvas_item(), origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				size, maxi(2, int(round(4.0 * s))), Color(0.04, 0.02, 0.1, alpha))
			font.draw_string(get_canvas_item(), origin + Vector2(1.5, 1.5) * s, text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(COLOR_SHADOW, alpha * 0.6))
			font.draw_string(get_canvas_item(), origin, text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(entry["color"], alpha))


## Energie- und Flaechenringe liegend auf dem Boden (21. Nov. 2026, Kampfbild
## mehr 3D B7): flache Ellipsen um die Fuesse des Getroffenen, UNTER den
## DROMEs (z 3990, die 3D-Szene liegt bei 4000). Liest die Einschlaege des
## EffectPainter, damit Zeit und Farbe genau passen.
class FloorRings extends Node2D:
	var painter: EffectPainter
	var pixel_scale: float = 1.0

	func _ready() -> void:
		z_index = 3990
		z_as_relative = false

	func _draw() -> void:
		if painter == null or not is_instance_valid(painter):
			return
		var s := maxf(1.0, pixel_scale * 0.8)
		var squash := IsoView.DEPTH_SQUASH
		for entry in painter.shots():
			var flight := float(entry["flight"])
			var age := float(entry["age"])
			if entry["kind"] == "beam" or age < flight:
				continue
			var t := (age - flight) / EffectPainter.IMPACT_TIME
			if t > 1.0:
				continue
			var at: Vector2 = entry["to"]
			var color: Color = entry["color"]
			var energy := float(entry["energy"])
			var big := 1.5 if entry["heavy"] else 1.0
			var fade := 1.0 - t
			draw_set_transform(at, 0.0, Vector2(1.0, squash))
			if energy > 0.0:
				var r := (10.0 + 22.0 * t) * big * s
				var alpha := fade * clampf(0.4 + energy, 0.0, 1.0)
				draw_circle(Vector2.ZERO, r, Color(color, 0.12 * alpha))
				draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(color.lightened(0.4), alpha), 2.6 * s, true)
				draw_arc(Vector2.ZERO, r * 0.6, 0.0, TAU, 24, Color(1, 1, 1, alpha * 0.55), 1.2 * s, true)
			if int(entry["area"]) > 0:
				var reach := float(entry["area"]) * IsoView.TILE_W * (0.4 + 0.6 * t)
				draw_arc(Vector2.ZERO, reach, 0.0, TAU, 48, Color(color, fade * 0.55), 3.0 * s, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
