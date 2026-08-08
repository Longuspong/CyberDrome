class_name AggroTable
extends RefCounted

## Die Aggro-Buchfuehrung EINES Gegner-DROME.
##
## Sie beantwortet genau eine Frage: wie sehr stoert mich jede feindliche
## Einheit? Nicht mehr. Positionierung, Faehigkeitswahl und Annaeherung bleiben
## Sache des AIController -- Aggro sagt WEN, nicht WIE.
##
## ### Nur Gegner fuehren eine Tabelle
##
## Spieler-DROMEs bekommen keine. Ihre Ziele waehlt der Spieler, und eine
## Tabelle, die niemand liest, waere eine zweite Wahrheit ueber die Zielwahl.
## Der einzige Weg, einen Spieler-DROME zu einem Ziel zu zwingen, ist die
## Provokation -- und die laeuft nicht ueber diese Klasse, sondern ueber
## ``Unit.taunt_lock`` und ``ActionResolver.target_blocker()``.
##
## ### Nicht zu verwechseln mit dem Kampfwert
##
## ``DromeBuild.power_score()`` sagt, wie stark ein Aufbau IST, existiert vor
## dem Gefecht und ist fuer beide Seiten dieselbe Zahl. Aggro sagt, wie sehr
## eine Einheit EINEN BESTIMMTEN Gegner stoert, entsteht erst im Gefecht und
## ist fuer jeden Gegner eine andere Zahl. Beide hiessen frueher "Threat";
## das Wort kommt im Projekt bewusst nicht mehr vor.
##
## ### Die Zahl an sich bedeutet nichts
##
## Massgeblich ist ausschliesslich die Rangfolge INNERHALB einer Tabelle.
## Deshalb gibt ``share()`` den Anteil am Tabellenmaximum zurueck und nicht
## den Rohwert: nur so laesst sich Aggro in die Nutzenbewertung der KI
## einhaengen, ohne dass eine unbegrenzt wachsende Zahl gegen Schadenspunkte
## antritt. Die Tabelle skaliert dadurch mit jeder Balancing-Aenderung von
## selbst mit.

## unit_id -> aufgelaufener Aggro-Wert
var entries: Dictionary = {}

## Wen dieser Gegner zuletzt tatsaechlich angegriffen hat. Der Amtsinhaber
## bekommt einen Bonus (Traegheit) und ist vom Verfall ausgenommen.
var current_target = null


# ---------------------------------------------------------------------------
# Die Formel
# ---------------------------------------------------------------------------

## Der Beitrag einer einzelnen Aktion.
##
##     delta = wirkung x aggro_coeff x naehe x generierung
##
## ``base`` ist die TATSAECHLICHE Wirkungsmenge -- angerichteter Schaden nach
## der Mitigationskette, tatsaechlich geheilte Integritaet nach dem Deckeln auf
## hp_max. Nicht die nominelle Menge: sonst waere Heilen auf Vollleben eine
## Gratis-Aggro-Maschine.
##
## Die Aufteilung in Wirkung und Koeffizient ist der eigentliche Designhebel.
## Sie entkoppelt "wie viel richtet die Waffe an" von "wie sehr provoziert
## sie" -- der Strix macht mit der Schienen-Lanze viel Schaden und zieht
## trotzdem kaum Aufmerksamkeit, ohne dass es dafuer eine Sonderregel braucht.
static func contribution(base: float, coeff: float, distance: int,
		gen_bonus: int) -> float:
	var section := Config.section("aggro")
	var near: int = int(section.get("near_distance", 1))
	var proximity: float = float(section.get("proximity_near", 1.5)) \
		if distance <= near else float(section.get("proximity_far", 1.0))
	# Wie in den Bauteil-Daten notiert: aggro_bonus sind Prozentpunkte, die
	# sich addieren. Ein Modul mit +20 macht aus 1.0 eine 1.2.
	var generation := 1.0 + float(gen_bonus) / 100.0
	return absf(base) * coeff * proximity * maxf(0.0, generation)


# ---------------------------------------------------------------------------
# Buchen und Lesen
# ---------------------------------------------------------------------------

func add(unit_id, amount: float) -> void:
	if unit_id == null or amount <= 0.0:
		return
	entries[unit_id] = float(entries.get(unit_id, 0.0)) + amount


func value_of(unit_id) -> float:
	return float(entries.get(unit_id, 0.0))


func peak() -> float:
	var highest := 0.0
	for value in entries.values():
		highest = maxf(highest, float(value))
	return highest


## Das Maximum OHNE einen bestimmten Eintrag. Die Provokation rechnet damit,
## und das ist kein Detail: rechnete sie gegen das volle Maximum, waere die
## Quelle beim zweiten Mal ihr eigener Bezugswert und stiege mit jedem
## weiteren Mal um denselben Faktor. Spam eskaliert dann eben doch -- nur
## geometrisch statt linear.
func peak_excluding(unit_id) -> float:
	var highest := 0.0
	for other_id in entries:
		if other_id != unit_id:
			highest = maxf(highest, float(entries[other_id]))
	return highest


## Anteil am Tabellenmaximum, 0.0 .. 1.0. Die einzige Lesart, die nach aussen
## gehen darf -- siehe Klassenkopf.
func share(unit_id) -> float:
	var highest := peak()
	return 0.0 if highest <= 0.0 else value_of(unit_id) / highest


func is_empty() -> bool:
	return entries.is_empty()


## Absteigend sortierte Rangfolge als [{id, value, share}]. Fuer die Anzeige --
## der Spieler muss sehen koennen, warum ein Gegner wen angreift.
func ranking() -> Array:
	var rows: Array = []
	var highest := peak()
	for unit_id in entries:
		rows.append({
			"id": unit_id,
			"value": float(entries[unit_id]),
			"share": 0.0 if highest <= 0.0 else float(entries[unit_id]) / highest,
		})
	rows.sort_custom(func(a, b): return a["value"] > b["value"])
	return rows


# ---------------------------------------------------------------------------
# Verfall
# ---------------------------------------------------------------------------

## Alte Beitraege verblassen -- ausser denen des aktuellen Ziels. Ohne Verfall
## zementiert ein einzelner grosser Treffer in Zyklus 1 die Zielwahl fuer das
## ganze Gefecht; mit zu starkem Verfall wird jeder Zug zur Neuwahl.
##
## Dass der Amtsinhaber ausgenommen ist, ist kein Detail: er verliert keinen
## Boden, waehrend alle anderen abbauen. Das ist dieselbe Traegheit, die der
## Amtsinhaber-Bonus in der KI erzeugt, nur ueber die Zeit statt ueber die
## einzelne Entscheidung.
##
## **Der Takt ist der ZYKLUS, nicht der eigene Zug.** Ein Zug ist in diesem
## Spiel keine gleichmaessige Zeiteinheit -- SPD entscheidet, wie oft jemand
## drankommt. Verfiele die Tabelle pro eigenem Zug, wuerde ein schneller
## Gegner die Beitraege aller Nicht-Ziele schneller abbauen und dadurch
## STAERKER an seinem Ziel kleben als ein langsamer. Niemand wuerde das als
## Absicht lesen. Der Zyklus ist die einzige gleichmaessige Uhr im Kampf.
func decay(rate: float, drop_below: float) -> void:
	for unit_id in entries.keys():
		if unit_id == current_target:
			continue
		var value := float(entries[unit_id]) * (1.0 - rate)
		if value < drop_below:
			entries.erase(unit_id)
		else:
			entries[unit_id] = value


## Eintrag entfernen -- wenn eine Einheit ausfaellt. Aggro ist begegnungslokal
## und ueberlebt weder den Tod eines Ziels noch das Gefecht.
func forget(unit_id) -> void:
	entries.erase(unit_id)
	if current_target == unit_id:
		current_target = null


func _to_string() -> String:
	var parts: Array[String] = []
	for row in ranking():
		parts.append("%s:%.0f%s" % [row["id"], row["value"],
			"*" if row["id"] == current_target else ""])
	return "AggroTable(%s)" % " ".join(parts)
