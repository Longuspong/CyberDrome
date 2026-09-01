class_name RosterEntry
extends RefCounted

## Ein DROME im Roster: eine Chassis-Instanz plus zugewiesene Kern- und
## Ausruestungs-Instanzen (§10g).
##
## Der Eintrag ist der bleibende, benannte Besitz -- nicht der fluechtige
## Wegwerf-Squad von frueher. Er haelt NICHT die Werte oder die Grafik; die
## entstehen erst zur Laufzeit, wenn ``Roster.build_for()`` aus den Zuweisungen
## einen typ-basierten ``DromeBuild`` ableitet. So bleibt der Kampf-Code von der
## Besitz-Schicht voellig unberuehrt (dieselbe Trennsauberkeit wie beim Reframe).
##
## ### Das Chassis IST die Identitaet
##
## ``assignments["body"]`` ist die uid einer Chassis-Instanz -- und die macht den
## DROME aus. Kopf und Fuesse werden daraus abgeleitet (die Huelle, §9), nie
## einzeln zugewiesen. Ein anderes Chassis ist deshalb ein ANDERER DROME, kein
## Umbau: neue Chassis-Beute eroeffnet einen neuen Roster-Platz (§10g). Die
## Werkstatt tauscht darum Kern und Ausruestung, nie den Rahmen.

## Anzeigename. Frei waehlbar -- "Molok-Brecher", "Vireo-Spaeher".
var name: String = "DROME"

## Blickrichtung fuer die Darstellung, wie beim alten DromeBuild.
var direction: String = "south"

## Optional abweichende Palette je Slot -- durchgereicht an den DromeBuild.
var palette: Dictionary = {}

## slot -> uid. ``body`` traegt die Chassis-Instanz, ``core`` den Kern, die
## ``equip_*`` die Ausruestung. Kein Eintrag = leerer Slot. Kopf und Fuesse
## stehen NICHT hier -- sie gehoeren zur Huelle des Chassis.
var assignments: Dictionary = {}

## Wird dieser DROME ins naechste Gefecht mitgenommen? Die Vorauswahl aus dem
## Roster (§10b) -- "vier mitnehmen, den Rest lasse ich zuhause". Der Kampf zieht
## nur die Eintraege, bei denen das gesetzt ist.
var in_squad: bool = false


static func create(entry_name: String, chassis_uid: String) -> RosterEntry:
	var entry := RosterEntry.new()
	entry.name = entry_name
	if chassis_uid != "":
		entry.assignments["body"] = chassis_uid
	return entry


## Die uid der Chassis-Instanz -- die Identitaet des DROME. Leer, solange keine
## gesetzt ist (dann hat der Eintrag noch keinen Rahmen).
func chassis_uid() -> String:
	return str(assignments.get("body", ""))


func to_dict() -> Dictionary:
	return {
		"name": name,
		"direction": direction,
		"palette": palette,
		"in_squad": in_squad,
		"assignments": assignments.duplicate(),
	}


static func from_dict(data: Dictionary) -> RosterEntry:
	if not data is Dictionary:
		return null
	var entry := RosterEntry.new()
	entry.name = str(data.get("name", "DROME"))
	entry.direction = str(data.get("direction", "south"))
	var pal = data.get("palette", {})
	entry.palette = pal if pal is Dictionary else {}
	entry.in_squad = bool(data.get("in_squad", false))
	var raw = data.get("assignments", {})
	if raw is Dictionary:
		for slot in raw:
			var uid_value := str(raw[slot])
			if uid_value != "":
				entry.assignments[str(slot)] = uid_value
	return entry


func _to_string() -> String:
	return "RosterEntry(%s, %d Zuweisungen)" % [name, assignments.size()]
