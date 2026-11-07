class_name StatIcon
extends Control

## Ein kleines gezeichnetes Symbol fuer wiederkehrende Begriffe -- Schaden,
## Angriffstempo, Takt, Schadensart (Wunsch des Spielers, 7. Nov. 2026).
##
## Gezeichnet statt aus der Schrift: die Standardschrift hat weder Schwert
## noch Uhr (bekannte Glyphen-Luecken, siehe PROJEKTSTAND 3). Jede Art hat
## einen Klartext (EXPLAIN), den die Waffen-Karte beim Antippen zeigt.
##
##   kinetic  Schwert         kinetischer Schaden
##   energy   Energiekugel    Energieschaden
##   speed    Doppelpfeil     Angriffstempo
##   range    Pfeil mit Fuss  Reichweite
##   attack   Fadenkreuz      Angriff (kommt von selbst)
##   ability  Blitz           Faehigkeit
##   time     Uhr             Takt nach Zeit
##   hits     Zahnrad         Takt nach Angriffen
##   adjacent zwei Punkte     Takt: Gegner daneben
##   heal     Kreuz           Reparatur
##   shield   Schildform      Schild
##   area     Ringe           Flaechenwirkung
##   def      Platte          Panzerung (DEF)
##   weight   Gewichtsklotz   Gewicht, bremst den Traeger
##   hp       Herz            Integritaet

const EXPLAIN := {
	"kinetic": "Kinetischer Schaden (Schwert): stark gegen Integritaet, schwach gegen Schilde.",
	"energy": "Energieschaden (Kugel): stark gegen Schilde.",
	"speed": "Angriffstempo: so oft greift die Waffe an.",
	"range": "Reichweite in Feldern. 1 heisst Nahkampf.",
	"attack": "Angriff: der normale Angriff der Waffe. Er kommt von selbst, sobald ein Ziel in Reichweite ist.",
	"ability": "Faehigkeit: die besondere Aktion der Waffe. Sie kommt von selbst, wenn ihr Takt erreicht ist.",
	"time": "Takt nach Zeit (Uhr): die Faehigkeit kommt nach dieser Zeit, auch ohne Angriff.",
	"hits": "Takt nach Angriffen (Zahnrad): der so-vielte Angriff IST die Faehigkeit.",
	"adjacent": "Takt: sobald ein Gegner direkt daneben steht.",
	"heal": "Reparatur: stellt Integritaet beim Verbuendeten mit dem geringsten Anteil wieder her.",
	"shield": "Schild: faengt Schaden ab, bevor er die Integritaet trifft.",
	"area": "Flaeche: trifft auch alles im Umkreis um das Ziel.",
	"def": "Panzerung (DEF): zieht von jedem Treffer etwas ab.",
	"weight": "Gewicht: schwere Waffen bremsen den Traeger (weniger SPD).",
	"hp": "Integritaet: faellt sie auf 0, ist der DROME zerstoert.",
}

const COLORS := {
	"kinetic": Color(0.86, 0.88, 0.92), "energy": Color(0.38, 0.85, 1.0),
	"speed": Color(1.0, 0.78, 0.4), "range": Color(0.75, 0.8, 0.9),
	"attack": Color(1.0, 0.55, 0.45), "ability": Color(1.0, 0.86, 0.35),
	"time": Color(0.8, 0.9, 1.0), "hits": Color(0.8, 0.9, 1.0),
	"adjacent": Color(1.0, 0.62, 0.15), "heal": Color(0.46, 0.86, 0.52),
	"shield": Color(0.45, 0.65, 1.0), "area": Color(0.95, 0.6, 1.0),
	"def": Color(0.75, 0.78, 0.85), "weight": Color(1.0, 0.5, 0.46),
	"hp": Color(0.46, 0.86, 0.52),
}

var kind := "attack"


func _init(which: String = "attack", edge: float = 22.0) -> void:
	kind = which
	custom_minimum_size = Vector2(edge, edge)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func explain(which: String) -> String:
	return EXPLAIN.get(which, which)


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	var col: Color = COLORS.get(kind, Color.WHITE)
	var line := maxf(1.5, r * 0.18)
	match kind:
		"kinetic":
			# Schwert schraeg: Klinge, Parierstange, Griff.
			var tip := c + Vector2(r * 0.8, -r * 0.8)
			var guard := c + Vector2(-r * 0.25, r * 0.25)
			draw_line(guard, tip, col, line * 1.6)
			draw_line(guard + Vector2(-r * 0.35, -r * 0.35), guard + Vector2(r * 0.35, r * 0.35),
				col, line * 1.2)
			draw_line(guard, c + Vector2(-r * 0.75, r * 0.75), Color(0.75, 0.5, 0.3), line * 1.4)
		"energy":
			draw_circle(c, r * 0.95, Color(col, 0.25))
			draw_circle(c, r * 0.7, col)
			draw_circle(c + Vector2(-r * 0.2, -r * 0.2), r * 0.25, Color(1, 1, 1, 0.85))
		"speed":
			for dx in [-0.45, 0.15]:
				var o := c + Vector2(r * dx, 0)
				draw_polyline(PackedVector2Array([o + Vector2(-r * 0.3, -r * 0.6), o + Vector2(r * 0.3, 0),
					o + Vector2(-r * 0.3, r * 0.6)]), col, line * 1.3)
		"range":
			draw_line(c + Vector2(-r * 0.8, 0), c + Vector2(r * 0.8, 0), col, line)
			draw_line(c + Vector2(-r * 0.8, -r * 0.5), c + Vector2(-r * 0.8, r * 0.5), col, line)
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.9, 0),
				c + Vector2(r * 0.4, -r * 0.4), c + Vector2(r * 0.4, r * 0.4)]), col)
		"attack":
			draw_arc(c, r * 0.6, 0, TAU, 24, col, line)
			for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				draw_line(c + d * r * 0.35, c + d * r * 0.95, col, line)
			draw_circle(c, line * 0.7, col)
		"ability":
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.15, -r * 0.95),
				c + Vector2(-r * 0.55, r * 0.1), c + Vector2(-r * 0.05, r * 0.1),
				c + Vector2(-r * 0.2, r * 0.95), c + Vector2(r * 0.55, -r * 0.15),
				c + Vector2(r * 0.05, -r * 0.15)]), col)
		"time":
			draw_arc(c, r * 0.8, 0, TAU, 28, col, line)
			draw_line(c, c + Vector2(0, -r * 0.55), col, line)
			draw_line(c, c + Vector2(r * 0.4, 0), col, line)
		"hits":
			for i in 8:
				var a := TAU * float(i) / 8.0
				draw_line(c + Vector2.from_angle(a) * r * 0.5, c + Vector2.from_angle(a) * r * 0.95,
					col, line * 1.6)
			draw_circle(c, r * 0.62, col)
			draw_circle(c, r * 0.25, Color(0.1, 0.12, 0.17))
		"adjacent":
			draw_circle(c + Vector2(-r * 0.45, 0), r * 0.35, Teams.color(true))
			draw_circle(c + Vector2(r * 0.45, 0), r * 0.35, col)
		"heal":
			draw_rect(Rect2(c - Vector2(r * 0.25, r * 0.8), Vector2(r * 0.5, r * 1.6)), col)
			draw_rect(Rect2(c - Vector2(r * 0.8, r * 0.25), Vector2(r * 1.6, r * 0.5)), col)
		"shield", "def":
			var pts := PackedVector2Array([c + Vector2(-r * 0.75, -r * 0.75),
				c + Vector2(r * 0.75, -r * 0.75), c + Vector2(r * 0.75, r * 0.05),
				c + Vector2(0, r * 0.9), c + Vector2(-r * 0.75, r * 0.05)])
			if kind == "shield":
				draw_colored_polygon(pts, Color(col, 0.35))
			else:
				draw_colored_polygon(pts, col)
			pts.append(pts[0])
			draw_polyline(pts, col, line)
		"hp":
			draw_circle(c + Vector2(-r * 0.38, -r * 0.2), r * 0.45, col)
			draw_circle(c + Vector2(r * 0.38, -r * 0.2), r * 0.45, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.82, -r * 0.05),
				c + Vector2(r * 0.82, -r * 0.05), c + Vector2(0, r * 0.85)]), col)
		"weight":
			draw_arc(c + Vector2(0, -r * 0.55), r * 0.25, 0, TAU, 16, col, line)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.45, -r * 0.3),
				c + Vector2(r * 0.45, -r * 0.3), c + Vector2(r * 0.8, r * 0.85),
				c + Vector2(-r * 0.8, r * 0.85)]), col)
		"area":
			for k in [0.3, 0.6, 0.9]:
				draw_arc(c, r * k, 0, TAU, 24, Color(col, 1.1 - k), line)
		_:
			draw_circle(c, r * 0.5, col)
