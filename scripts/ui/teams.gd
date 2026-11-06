class_name Teams
extends RefCounted

## Die zwei Fraktionsfarben -- an EINER Stelle.
##
## Im Kampf beantwortet die Farbe genau eine Frage, und zwar die erste, die
## sich der Spieler stellt: welche Figur ist meine? Sie taucht dafuer an vier
## Stellen auf -- Bodenring, Statusbadge, TICK-Balken, Namen in der Warteliste.
## Laufen die auseinander, beantwortet die Farbe die Frage nicht mehr, sondern
## stellt eine neue.
##
## ### Warum die Bauteile nur getoent und nicht umgefaerbt werden
##
## Ein DROME traegt die Palette seines Bausatzes -- ein Nimbus ist violett, ein
## Molok ockern. Die einzufaerben waere die naheliegende Loesung und die
## falsche: der Spieler muss den Bot wiedererkennen, den er in der Werkstatt
## gebaut hat, und zwei Nimbus-Aufbauten in Rot und Blau sind derselbe Bot in
## zwei Lackierungen -- unterscheidbar, aber nicht mehr wiedererkennbar.
##
## Deshalb traegt die INFORMATION der Bodenring, unuebersehbar und in voller
## Saettigung. Der Farbstich auf den Bauteilen ist nur die Verstaerkung: er
## kippt die Silhouette merklich ins Kuehle oder Warme, ohne die Palette zu
## ersetzen.

## Voll gesaettigt -- Ring, Balken, Namen.
const PLAYER := Color(0.30, 0.72, 0.95)
const ENEMY := Color(0.95, 0.42, 0.38)

## Abgedunkelt fuer Flaechen hinter den Balken.
const PLAYER_DARK := Color(0.10, 0.22, 0.32)
const ENEMY_DARK := Color(0.30, 0.13, 0.13)

## Der Farbstich auf den Bauteilen. Multiplikativ, also kippt er die Palette,
## statt sie zu ersetzen. Werte ueber 1.0 heben den Kanal an -- ohne sie waere
## der Farbstich nur ein Abdunkeln, und beide Fraktionen saehen matter aus als
## dieselben Teile in der Werkstatt.
const PLAYER_TINT := Color(0.84, 0.95, 1.14)
const ENEMY_TINT := Color(1.16, 0.86, 0.82)

## Trefferblende -- kurz, hell, fraktionsunabhaengig. Ein Treffer ist ein
## Treffer, egal wen er erwischt.
const HIT_FLASH := Color(2.4, 1.5, 1.4)


static func color(is_player: bool) -> Color:
	return PLAYER if is_player else ENEMY


static func dark(is_player: bool) -> Color:
	return PLAYER_DARK if is_player else ENEMY_DARK


static func tint(is_player: bool) -> Color:
	return PLAYER_TINT if is_player else ENEMY_TINT


## Der Lebensbalken ueber der Figur und in den Kacheln (Wunsch des Spielers,
## Nov. 2026): eigene Integritaet gruen, eigener Schild blau; beim Gegner
## Integritaet rot, Schild violett. Feste Farben, kein Umfaerben bei wenig
## Leben -- die Laenge sagt das schon.
const PLAYER_HP := Color(0.36, 0.86, 0.42)
const PLAYER_SHIELD := Color(0.35, 0.62, 1.0)
const ENEMY_HP := Color(0.92, 0.26, 0.26)
const ENEMY_SHIELD := Color(0.70, 0.40, 0.98)


static func hp_color(is_player: bool) -> Color:
	return PLAYER_HP if is_player else ENEMY_HP


static func shield_color(is_player: bool) -> Color:
	return PLAYER_SHIELD if is_player else ENEMY_SHIELD
