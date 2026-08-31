class_name PartInstance
extends RefCounted

## Ein BESESSENES Bauteil -- ein einzelnes Exemplar mit eigener Kennung (§10g).
##
## ### Warum eine Instanz und nicht bloss ein Typ
##
## ``DromeBuild.slots`` haelt Bauteil-TYPEN (``eq_rail_lance``): fuer Stats,
## Render und Kampf genuegt das, denn dort zaehlt nur, WAS an einem Slot sitzt.
## Der Besitz braucht mehr: zwei Schienen-Lanzen sind zwei Exemplare, und ein
## Exemplar darf nicht zweimal gleichzeitig verbaut sein. Dafuer braucht jedes
## eine ``uid`` -- so ist immer klar, WELCHES wo steckt, und spaeter traegt jede
## Instanz ihre eigenen Mods (§10c) und ihr eigenes Level.
##
## Bewusst schlank: heute nur ``uid`` + ``part_id``. Die Mods/Level-Felder kommen
## erst, wenn es sie im Spiel gibt -- ein leeres Feld auf Vorrat waere eine
## Behauptung ueber ein System, das noch nicht steht.

## Eindeutig im ganzen Inventar. Ein String, damit er ohne Umweg in JSON und in
## die ``assignments`` eines Roster-Eintrags passt.
var uid: String = ""

## Der Bauteiltyp, den diese Instanz IST -- der Schluessel in die PartDB. Aus ihm
## kommen Werte, Grafik und Slotregeln; die Instanz selbst haelt keine davon.
var part_id: StringName = &""


static func create(new_uid: String, new_part_id: StringName) -> PartInstance:
	var instance := PartInstance.new()
	instance.uid = new_uid
	instance.part_id = new_part_id
	return instance


## Das Teil hinter dieser Instanz. null, wenn der Typ nicht mehr existiert (ein
## alter Spielstand, ein umbenanntes Bauteil) -- der Aufrufer entscheidet, was
## das heisst.
func part() -> PartData:
	return PartDB.get_part(part_id)


## Zu welchem Bauteiltyp gehoert die Instanz? Bestimmt, in welche Bibliotheks-
## gruppe der Werkstatt sie faellt und in welchen Slot sie darf.
func type() -> int:
	var p := part()
	return p.type if p != null else -1


func to_dict() -> Dictionary:
	return {"uid": uid, "part_id": str(part_id)}


static func from_dict(data: Dictionary) -> PartInstance:
	if not data is Dictionary:
		return null
	var uid_value := str(data.get("uid", ""))
	var part_value := StringName(data.get("part_id", ""))
	if uid_value == "" or part_value == &"":
		return null
	return PartInstance.create(uid_value, part_value)


func _to_string() -> String:
	return "PartInstance(%s = %s)" % [uid, part_id]
