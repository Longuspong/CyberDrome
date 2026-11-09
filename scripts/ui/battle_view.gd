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
var _arena: Array = []
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

## Boden, Rand, Hindernisse, Deko und Licht -- gezeichnet von ArenaPainter
## (7. Nov. 2026; vorher eine SVG-Kachel je Feld mit schwarzem Umriss).
## Hindernisse und Deko sortieren sich wie Einheiten nach der Tiefe ihres
## Feldes.
func build_terrain(battle_grid: Grid) -> void:
	grid = battle_grid
	for node in _arena:
		node.queue_free()
	_arena = ArenaPainter.build(_world, grid, func(tile: Vector2i) -> int:
		return IsoView.depth(tile) * DEPTH_STRIDE + UNIT_DEPTH_OFFSET)


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
	_badges.zoom = camera_zoom
	_badges.queue_redraw()
	_effects.pixel_scale = factor


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
	_effects.add_attack(from, to, color, style)


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
	const HEIGHT := 6.0
	## Unterkante des Balkens ueber der Feldmitte -- in WELT-Einheiten.
	const BASE_Y := -72.0

	const COLOR_TRACK := Color(0.04, 0.05, 0.08, 0.9)
	const COLOR_OUTLINE := Color(0.0, 0.0, 0.0, 0.9)
	const COLOR_LURED := Color(1.0, 0.62, 0.15)
	const COLOR_GHOST := Color(1.0, 0.95, 0.85)
	const COLOR_DANGER := Color(1.0, 0.25, 0.2)
	## Takt-Leiste unter dem Lebensbalken: wann kommt die Faehigkeit?
	const TAKT_HEIGHT := 3.0
	const TAKT_GAP := 2.0
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
		var total := height + float(takt_rows) * (TAKT_HEIGHT + TAKT_GAP) * s
		var top := center.y + BASE_Y - height
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
		var top := center.y + BASE_Y - height - lift

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
		draw_rect(Rect2(Vector2(left - pad, top - pad),
			Vector2(width + pad * 2.0, height + pad * 2.0)), outline)
		draw_rect(Rect2(Vector2(left, top), Vector2(width, height)), COLOR_TRACK)
		# Nachlauf zuerst, darueber der echte Wert.
		draw_rect(Rect2(Vector2(left, top), Vector2(width * hp_ghost, height)), COLOR_GHOST)
		draw_rect(Rect2(Vector2(left, top), Vector2(width * parts["hp_fill"], height)),
			Teams.hp_color(mine))
		var shield_left: float = left + width * float(parts["hp_slot"])
		draw_rect(Rect2(Vector2(shield_left, top), Vector2(width * sh_ghost, height)), COLOR_GHOST)
		draw_rect(Rect2(Vector2(shield_left, top),
			Vector2(width * parts["shield_fill"], height)), Teams.shield_color(mine))
		# Die Fuge zwischen den beiden Teilen, damit ein leerer Schild nicht
		# wie ein Stueck fehlender Integritaet aussieht.
		if parts["hp_slot"] > 0.0 and parts["shield_slot"] > 0.0:
			draw_rect(Rect2(Vector2(shield_left - 0.5 * s, top),
				Vector2(1.0 * s, height)), COLOR_OUTLINE)
		# Gegner: abgeschraegte Enden (Form statt nur Farbe).
		if not mine:
			var cut := height + pad
			var bottom := top + height + pad
			draw_colored_polygon(PackedVector2Array([Vector2(left - pad, bottom),
				Vector2(left - pad, bottom - cut), Vector2(left - pad + cut, bottom)]), outline)
			draw_colored_polygon(PackedVector2Array([Vector2(left + width + pad, top - pad),
				Vector2(left + width + pad - cut, top - pad),
				Vector2(left + width + pad, top - pad + cut)]), outline)

		if level != "far":
			_takt(entry.get("takt", []), left, top + height + pad, width, s)
		if level == "near":
			_statuses(entry.get("statuses", []), left + width + 5.0 * s, top + height * 0.5, s)

		# Gelockt (Molok-Praesenz, Koedersender): ein kleines Ausrufezeichen
		# in Orange links neben dem Balken -- "der greift gerade den Locker an".
		if entry.get("lured", false) and level != "far":
			var at := Vector2(left - 7.0 * s, top + height * 0.5)
			draw_circle(at, 5.0 * s, COLOR_OUTLINE)
			draw_circle(at, 4.0 * s, COLOR_LURED)
			draw_rect(Rect2(at + Vector2(-0.8, -2.8) * s, Vector2(1.6, 3.4) * s), COLOR_OUTLINE)
			draw_rect(Rect2(at + Vector2(-0.8, 1.2) * s, Vector2(1.6, 1.4) * s), COLOR_OUTLINE)

	## Kleine Zustands-Symbole rechts neben dem Balken (nur nah):
	## betaeubt = gelber Stern, verlangsamt = blauer Pfeil nach unten,
	## verwundbar = roter Riss, Sprint = gruener Pfeil nach vorn.
	func _statuses(ids: Array, x: float, y: float, s: float) -> void:
		for id in ids:
			var c := Vector2(x + 4.0 * s, y)
			draw_circle(c, 5.0 * s, COLOR_OUTLINE)
			match str(id):
				"stun":
					for k in 4:
						var a := TAU * float(k) / 8.0
						var d := Vector2.from_angle(a) * 3.5 * s
						draw_line(c - d, c + d, Color(1.0, 0.9, 0.3), 1.4 * s)
				"slow":
					draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -2) * s,
						c + Vector2(3, -2) * s, c + Vector2(0, 3) * s]), Color(0.45, 0.7, 1.0))
				"vulnerable":
					draw_polyline(PackedVector2Array([c + Vector2(-1, -4) * s, c + Vector2(1, -1) * s,
						c + Vector2(-1, 1) * s, c + Vector2(1, 4) * s]), Color(1.0, 0.4, 0.35), 1.5 * s)
				"rush":
					draw_colored_polygon(PackedVector2Array([c + Vector2(-2, -3) * s,
						c + Vector2(3, 0) * s, c + Vector2(-2, 3) * s]), Color(0.5, 0.95, 0.55))
				_:
					draw_circle(c, 2.0 * s, Color.WHITE)
			x += 11.0 * s

	## Je Faehigkeit eine duenne Leiste unter dem Lebensbalken, gleich breit.
	## Treffer-Takt: ein Abschnitt je Angriff (jeder 4. Angriff = vier
	## Abschnitte zu je einem Viertel), gefuellt je Treffer. Zeit-Takt: eine
	## Leiste, die sich in halben Sekunden fuellt. Volle Leiste leuchtet hell:
	## als Naechstes kommt die Faehigkeit.
	func _takt(bars: Array, left: float, top: float, width: float, s: float) -> void:
		var h := TAKT_HEIGHT * s
		var y := top + TAKT_GAP * s * 0.5
		for bar in bars:
			var color := COLOR_TAKT_READY if bar.get("ready", false) else COLOR_TAKT
			draw_rect(Rect2(Vector2(left - s, y - s), Vector2(width + 2.0 * s, h + 2.0 * s)),
				COLOR_OUTLINE)
			draw_rect(Rect2(Vector2(left, y), Vector2(width, h)), COLOR_TRACK)
			if bar["kind"] == "hits":
				var n: int = maxi(1, int(bar["segments"]))
				var piece := width / float(n)
				for i in n:
					var x := left + piece * float(i)
					if i < int(bar["filled"]):
						draw_rect(Rect2(Vector2(x, y), Vector2(piece, h)), color)
					if i > 0:
						draw_rect(Rect2(Vector2(x - 0.5 * s, y), Vector2(1.0 * s, h)),
							COLOR_OUTLINE)
			else:
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

	func _ready() -> void:
		z_index = 4020

	func add_attack(from: Vector2, to: Vector2, color: Color, style: Dictionary) -> void:
		var kind := str(style.get("projectile", "bolt"))
		var flight := float(FLIGHT.get(kind, 0.12))
		var total := (BEAM_TIME if kind == "beam" else flight + IMPACT_TIME)
		# Funken: feste Richtungen je Treffer, damit nichts flackert.
		var seed_angle := fmod(absf(to.x * 0.37 + to.y * 0.71 + from.x * 0.13), TAU)
		_shots.append({"from": from, "to": to, "color": color, "age": 0.0,
			"kind": kind, "flight": flight, "total": total,
			"energy": float(style.get("energy", 0.0)), "heavy": bool(style.get("heavy", false)),
			"area": int(style.get("area", 0)), "spin": seed_angle})

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
		_shots = _shots.filter(func(e): return float(e["age"]) < float(e["total"]))
		_texts = _texts.filter(func(e): return float(e["age"]) < TEXT_TIME)
		queue_redraw()

	func _draw() -> void:
		for entry in _shots:
			if entry["kind"] == "beam":
				_draw_beam(entry)
				continue
			var age: float = entry["age"]
			var flight: float = entry["flight"]
			if age < flight and entry["kind"] != "":
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
		if energy > 0.0:
			var r := (6.0 + 18.0 * t) * big * maxf(1.0, s * 0.8)
			var alpha := fade * clampf(0.4 + energy, 0.0, 1.0)
			draw_arc(at, r, 0.0, TAU, 28, Color(color.lightened(0.4), alpha), 2.5 * maxf(1.0, s * 0.7), true)
			draw_arc(at, r * 0.6, 0.0, TAU, 20, Color(1, 1, 1, alpha * 0.6), 1.2 * maxf(1.0, s * 0.7), true)
		if energy < 1.0:
			var count := 7 if entry["heavy"] else 5
			for i in count:
				var ang := float(entry["spin"]) + i * TAU / float(count) + sin(i * 1.7) * 0.4
				var dir := Vector2(cos(ang), sin(ang) * 0.6)
				var from := at + dir * (3.0 + 10.0 * t) * big * maxf(1.0, s * 0.8)
				var to := at + dir * (8.0 + 22.0 * t) * big * maxf(1.0, s * 0.8)
				draw_line(from, to, Color(1.0, 0.85 - 0.3 * t, 0.45, fade * (1.0 - energy * 0.5)),
					2.0 * maxf(1.0, s * 0.6), true)
		if int(entry["area"]) > 0:
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
