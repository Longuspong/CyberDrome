class_name ActionIcons
extends RefCounted

## Welches Symbol zu welcher Aktion gehoert.
##
## ### Warum die Regel an der WIRKUNG haengt und nicht an der ID
##
## Eine Tabelle ``act_orbitpull -> pull`` waere kuerzer und waere die falsche
## Loesung: sie muesste bei jedem neuen Bauteil nachgepflegt werden, und wer sie
## vergisst, bekommt kein Symbol, sondern das Platzhaltersymbol -- also einen
## Fehler, der wie eine Gestaltungsentscheidung aussieht.
##
## Gefragt wird deshalb, was die Aktion TUT. Ein neues Bauteil mit einer
## Zugaktion bekommt dadurch ohne eine Zeile Code dasselbe Symbol wie der
## Orbit-Sog -- und das ist auch richtig so: fuer den Spieler sind es zwei
## Teile, die dasselbe machen.
##
## Die Reihenfolge der Pruefungen ist die Rangfolge der Bedeutungen. Eine
## Flaechenreparatur ist eine Reparatur und keine Flaechenwirkung: was das Ziel
## davon HAT, steht ueber der Frage, wie viele Felder es trifft. Der
## Drohnen-Pod ist genau dieser Fall und der Grund, warum die Reihenfolge hier
## als Regel steht und nicht als Zufall der Schreibweise.
##
## ### Warum "generic" erreichbar bleiben MUSS
##
## Naheliegend waere, am Ende einfach "shot" zurueckzugeben -- jede Aktion
## haette dann ein Symbol, und der Platzhalter waere totes Holz. Genau das
## waere der Fehler: eine Aktion, die weder Schaden macht noch repariert,
## zieht, stoesst oder provoziert, tut etwas, wofuer es hier noch kein Bild
## gibt. Sie als Schuss zu zeichnen waere keine Luecke mehr, sondern eine
## Falschauskunft -- und niemand wuerde sie je bemerken.
##
## Deshalb faellt sie sichtbar auf den leeren Rahmen, und ein Test im Bestand
## (tests/test_ui_pieces.gd) schlaegt an, sobald ein Bauteil dort landet. Der
## Platzhalter ist die Warnung, nicht die Loesung.

const DIR := "res://assets/icons"

## Symbolname -> geladene Textur. Die Symbole haengen an jedem Aktionsknopf und
## in jeder Zeile des Aktionsrings; beide werden nach jeder Aktion neu gebaut.
## Ohne Zwischenspeicher waere das ein load() je Knopf und Neuaufbau.
static var _cache: Dictionary = {}


## Der Symbolname fuer diese Aktion. Ohne Dateiendung und ohne Pfad -- das ist
## die Regel, nicht der Speicherort.
static func key_for(action: ActionData) -> String:
	if action == null:
		return "generic"
	if action.is_move():
		return "dash"
	if action.is_heal():
		return "heal"
	if action.is_taunt():
		return "taunt"
	if action.push_tiles < 0:
		return "pull"
	if action.push_tiles > 0:
		return "push"
	if action.power > 0:
		if action.aoe_radius > 0:
			return "blast"
		return "melee" if action.range_tiles <= 1 else "shot"
	return "generic"


static func texture_for(action: ActionData) -> Texture2D:
	return texture(key_for(action))


static func texture(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var path := "%s/act_%s.svg" % [DIR, key]
	if not ResourceLoader.exists(path):
		# Ein fehlendes Symbol ist ein fehlendes Bild, kein Absturz -- der Knopf
		# bleibt bedienbar, und die Warnung sagt, welche Datei fehlt.
		push_warning("ActionIcons: %s fehlt" % path)
		_cache[key] = null
		return null
	var texture := load(path) as Texture2D
	_cache[key] = texture
	return texture
