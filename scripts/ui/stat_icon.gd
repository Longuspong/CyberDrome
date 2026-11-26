class_name StatIcon
extends Control

## Ein kleines gezeichnetes Symbol fuer wiederkehrende Begriffe -- Schaden,
## Angriffstempo, Takt, Schadensart (Wunsch des Spielers, 7. Nov. 2026).
##
## Die Formen kommen seit 15. Nov. 2026 aus assets/ui_icons (UiIcon). Jede
## Art hat einen Klartext (EXPLAIN), den die Waffen-Karte beim Antippen zeigt.
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
	"kinetic": "Kinetischer Schaden (Schwert): stark gegen Integrität, schwach gegen Schilde.",
	"energy": "Energieschaden (Kugel): stark gegen Schilde.",
	"speed": "Angriffstempo: so oft greift die Waffe an.",
	"range": "Reichweite in Feldern. 1 heißt Nahkampf.",
	"attack": "Angriff: der normale Angriff der Waffe. Er kommt von selbst, sobald ein Ziel in Reichweite ist.",
	"ability": "Fähigkeit: die besondere Aktion der Waffe. Sie kommt von selbst, wenn ihr Takt erreicht ist.",
	"hits": "Takt nach Angriffen (Zahnrad): der so-vielte Angriff IST die Fähigkeit.",
	"adjacent": "Takt: sobald ein Gegner direkt daneben steht.",
	"heal": "Reparatur: stellt Integrität beim Verbündeten mit dem geringsten Anteil wieder her.",
	"shield": "Schild: fängt Schaden ab, bevor er die Integrität trifft.",
	"area": "Fläche: trifft auch alles im Umkreis um das Ziel.",
	"def": "Panzerung (DEF): zieht von jedem Treffer etwas ab.",
	"hp": "Integrität: fällt sie auf 0, ist der DROME zerstört.",
}

const COLORS := {
	"kinetic": Color(0.86, 0.88, 0.92), "energy": Color(0.38, 0.85, 1.0),
	"speed": Color(1.0, 0.78, 0.4), "range": Color(0.75, 0.8, 0.9),
	"attack": Color(1.0, 0.55, 0.45), "ability": Color(1.0, 0.86, 0.35),
	"hits": Color(0.8, 0.9, 1.0),
	"adjacent": Color(1.0, 0.62, 0.15), "heal": Color(0.46, 0.86, 0.52),
	"shield": Color(0.45, 0.65, 1.0), "area": Color(0.95, 0.6, 1.0),
	"def": Color(0.75, 0.78, 0.85),
	"hp": Color(0.46, 0.86, 0.52),
}

var kind := "attack"


func _init(which: String = "attack", edge: float = 22.0) -> void:
	kind = which
	custom_minimum_size = Vector2(edge, edge)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func explain(which: String) -> String:
	return EXPLAIN.get(which, which)


## Seit 15. Nov. 2026 das SVG gleichen Namens aus assets/ui_icons (weiss,
## eingefaerbt mit COLORS) statt von Hand gezeichneter Formen.
func _draw() -> void:
	var edge := minf(size.x, size.y)
	var col: Color = COLORS.get(kind, Color.WHITE)
	var texture := UiIcon.texture(kind)
	if texture == null:
		draw_circle(size * 0.5, edge * 0.25, col)
		return
	draw_texture_rect(texture, Rect2((size - Vector2(edge, edge)) * 0.5, Vector2(edge, edge)),
		false, col)
