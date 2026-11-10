class_name Roster
extends RefCounted

## Die Besitz-Schicht (§10g): das Inventar aller Instanzen und das Roster der
## DROMEs, die daraus gebaut sind.
##
## Drei Schichten, sauber getrennt:
##
##     Inventar   ``_instances`` -- jede besessene Instanz, die Quelle der
##                Wahrheit fuer "was habe ich".
##     Roster     ``entries`` -- die DROMEs. Jeder ist eine Chassis-Instanz plus
##                zugewiesene Kern-/Ausruestungs-Instanzen.
##     DromeBuild wird bei Bedarf abgeleitet (``build_for``) und bleibt
##                typ-basiert und unberuehrt -- der Kampf kennt diese Schicht nicht.
##
## ### Eindeutigkeit faellt von selbst
##
## Eine uid steckt in HOECHSTENS einer Zuweisung im ganzen Roster. "Frei" heisst
## darum schlicht: in keiner Zuweisung. Die Werkstatt bietet fuer einen Slot nur
## freie Instanzen an -- "Schienen-Lanze nur waehlbar, wenn nicht woanders
## verbaut" ist damit kein Sonderfall, sondern die Grundregel.
##
## Keine Godot-Knoten: die ganze Klasse ist ohne laufende Szene testbar, wie
## DromeBuild. Gegner haben KEIN Inventar -- sie werden weiter typ-basiert
## generiert und kosten diese Schicht nichts.

## uid -> PartInstance. Alle besessenen Exemplare.
var _instances: Dictionary = {}

## Array[RosterEntry] -- die DROMEs, in Anzeigereihenfolge.
var entries: Array = []

## Zaehler fuer die naechste uid. Instanzen heissen ``inst-1``, ``inst-2``, ...
## -- laufend und stabil, damit ein gespeicherter Eintrag seine Teile
## wiederfindet. Wird beim Laden hinter das hoechste vorhandene gesetzt.
var _next_uid: int = 1

## Die vier Standard-DROMEs mit ihrer VOLLEN Standard-Ausstattung -- der
## handgesetzte Startbestand (§10g/§12c). Reihenfolge = Reihenfolge im frischen
## Roster. Die Ausruestung wird der Reihe nach in den ersten passenden freien
## Slot gelegt (``_seed_equip``), damit ein support-only-Schulterpod nicht die
## Waffe schluckt.
##
## Die Kits stehen so im Konzept:
##   Vireo   Hologramm-Boost (Dash) + Puls-Blaster
##   Molok   Belagerungskanone + Deflektor-Schild + Drohnen-Pod (Reparatur)
##   Nimbus  Orbit-Fokus (Orbital) + Runenstab
##   Strix   Schienen-Lanze (nur ein Slot)
const STARTER_CHASSIS := [
	{"body": &"scout_body", "core": &"scout_core",
	 "equipment": [&"eq_pulse_blaster"]},
	{"body": &"jugg_body", "core": &"jugg_core",
	 "equipment": [&"eq_hammer", &"eq_deflector"]},
	{"body": &"mage_body", "core": &"mage_core",
	 "equipment": [&"eq_rune_staff"]},
	{"body": &"strix_body", "core": &"strix_core",
	 "equipment": [&"eq_rail_lance"]},
]

## Ausruestung, die KEINEM Start-DROME zugeteilt ist und frei im Inventar liegt.
## Seit es nur noch einen Platz je DROME gibt (Molok zwei), liegen die
## Gadgets hier und laden zum Umbauen ein.
const STARTER_LOOSE_EQUIPMENT := [
	&"eq_drone_pod", &"eq_plasma_blade",
]


# ---------------------------------------------------------------------------
# Inventar
# ---------------------------------------------------------------------------

func instance(uid: String) -> PartInstance:
	return _instances.get(uid)


func all_instances() -> Array:
	return _instances.values()


## Der Bauteiltyp hinter einer uid -- oder &"" fuer eine unbekannte/leere uid.
func instance_part_id(uid: String) -> StringName:
	var inst: PartInstance = _instances.get(uid)
	return inst.part_id if inst != null else &""


## Legt eine neue Instanz eines Typs ins Inventar und gibt ihre uid zurueck. Der
## einzige Weg, Besitz zu erzeugen -- so vergibt niemand sonst uids.
func add_instance(part_id: StringName) -> String:
	var uid := "inst-%d" % _next_uid
	_next_uid += 1
	_instances[uid] = PartInstance.create(uid, part_id)
	return uid


## Alle uids, die IRGENDWO im Roster zugewiesen sind. Grundlage der
## Eindeutigkeit: was hier drin steht, ist nicht frei.
func assigned_uids() -> Dictionary:
	var used := {}
	for entry in entries:
		for slot in entry.assignments:
			used[str(entry.assignments[slot])] = true
	return used


## Wie viele Exemplare eines Typs besitzt der Spieler insgesamt.
func total_count(part_id: StringName) -> int:
	var n := 0
	for inst in _instances.values():
		if inst.part_id == part_id:
			n += 1
	return n


## Wie viele Exemplare eines Typs FREI sind -- in keiner Zuweisung. Das ist die
## Zahl, die die Werkstatt zeigt: so viele kann ich noch einbauen.
func free_count(part_id: StringName) -> int:
	var used := assigned_uids()
	var n := 0
	for inst in _instances.values():
		if inst.part_id == part_id and not used.has(inst.uid):
			n += 1
	return n


## Eine freie Instanz eines Typs (die erste) -- oder null, wenn alle verbaut sind.
func free_instance(part_id: StringName) -> PartInstance:
	var used := assigned_uids()
	for inst in _instances.values():
		if inst.part_id == part_id and not used.has(inst.uid):
			return inst
	return null


## Die distinkten Bauteiltypen eines Typs, die der Spieler BESITZT -- nach Code
## sortiert, damit die Bibliothek stabil steht. Grundlage der Werkstatt-Ansicht:
## sie zeigt die eigene Sammlung, nicht den freien Katalog.
func owned_part_ids(type: int) -> Array:
	var seen := {}
	for inst in _instances.values():
		var part: PartData = inst.part()
		if part != null and part.type == type:
			seen[inst.part_id] = part.code
	var ids: Array = seen.keys()
	ids.sort_custom(func(a, b): return str(seen[a]) < str(seen[b]))
	return ids


# ---------------------------------------------------------------------------
# Zuweisung -- die Eindeutigkeit lebt hier
# ---------------------------------------------------------------------------

## Wie viele Exemplare eines Typs in DIESEM Eintrag stecken. Fuer die Werkstatt:
## "ist das hier verbaut" und "an wie vielen Haltern".
func count_in_entry(entry: RosterEntry, part_id: StringName) -> int:
	var n := 0
	for slot in entry.assignments:
		if instance_part_id(str(entry.assignments[slot])) == part_id:
			n += 1
	return n


## Weist dem Slot eine FREIE Instanz des Typs zu (§10g). Was vorher im Slot
## steckte, wird dadurch automatisch frei -- "frei" ist ja nur "in keiner
## Zuweisung". Steckt bereits eine Instanz dieses Typs im Slot, oder ist keine
## frei, passiert nichts. Gibt zurueck, ob sich etwas geaendert hat.
func assign(entry: RosterEntry, slot: String, part_id: StringName) -> bool:
	if str(entry.assignments.get(slot, "")) != "" \
			and instance_part_id(str(entry.assignments[slot])) == part_id:
		return false
	var free := free_instance(part_id)
	if free == null:
		return false
	entry.assignments[slot] = free.uid
	return true


## Leert einen Slot. Die Instanz kehrt ins Inventar zurueck (sie ist danach in
## keiner Zuweisung mehr und damit frei). Das Chassis (``body``) laesst sich so
## nicht entfernen -- es ist die Identitaet des DROME, nicht eine Zuweisung.
func clear_slot(entry: RosterEntry, slot: String) -> void:
	if slot == "body":
		return
	entry.assignments.erase(slot)


## "Bester Aufbau" (10. Nov. 2026, Wunsch des Spielers): ruestet die
## gegebenen Eintraege neu aus. Zuerst werden ihre Waffen frei, dann bekommt
## Halter fuer Halter das Exemplar, das den Aufbau am staerksten macht
## (loadout_score) -- von mehreren Exemplaren eines Typs das mit dem hoechsten
## Level. Gibt zurueck, wie viele Halter jetzt anders bestueckt sind.
func best_loadout(targets: Array) -> int:
	var before := {}
	for entry in targets:
		before[entry] = entry.assignments.duplicate()
		for slot in entry.assignments.keys():
			if str(slot).begins_with("equip_"):
				entry.assignments.erase(slot)
	for entry in targets:
		var chassis := PartDB.get_part(instance_part_id(entry.chassis_uid()))
		if chassis == null:
			continue
		for slot in chassis.equip_slots():
			var best_uid := ""
			var best_score := loadout_score(build_for(entry))
			for part_id in owned_part_ids(PartData.Type.EQUIPMENT):
				var part := PartDB.get_part(part_id)
				if part == null or not chassis.accepts(part, slot):
					continue
				var uid := _best_free_uid(part_id)
				if uid == "":
					continue
				entry.assignments[slot] = uid
				var trial := build_for(entry)
				if trial.is_valid():
					var score := loadout_score(trial)
					if score > best_score:
						best_score = score
						best_uid = uid
				entry.assignments.erase(slot)
			if best_uid != "":
				entry.assignments[slot] = best_uid
	var changed := 0
	for entry in targets:
		var old: Dictionary = before[entry]
		for slot in entry.assignments.keys() + old.keys():
			if str(entry.assignments.get(slot, "")) != str(old.get(slot, "")):
				changed += 1
	return changed


## Das freie Exemplar eines Typs mit dem hoechsten Level ("" = keins frei).
func _best_free_uid(part_id: StringName) -> String:
	var used := assigned_uids()
	var best: PartInstance = null
	for inst in _instances.values():
		if inst.part_id != part_id or used.has(inst.uid):
			continue
		if best == null or inst.level > best.level:
			best = inst
	return best.uid if best != null else ""


## Wie gut ein Aufbau zum Kaempfen ist -- fuer "Bester Aufbau". Der Kampfwert
## (power_score) zaehlt nur den staerksten Treffer; hier kommt der Schaden je
## Sekunde jeder Waffe dazu (mit Power, Schuessen und Waffenlevel), damit eine
## schnelle Waffe nicht hinter einer langsamen, harten zurueckfaellt.
static func loadout_score(build: DromeBuild) -> float:
	var score := build.power_score()
	for slot in build.equip_slots():
		var part := build.part_in(slot)
		if part == null:
			continue
		var level_mult := 1.0 + 0.07 * float(build.weapon_level(slot))
		for item in part.actions:
			var action: ActionData = item
			if action.is_attack() and action.interval > 0.0:
				var dps: float = float(action.power * maxi(1, action.shots)) / action.interval
				score += dps * build.power_factor() * level_mult * 10.0
				score += float(action.heal) / action.interval * 10.0
	return score


# ---------------------------------------------------------------------------
# Ableitung: Roster-Eintrag -> DromeBuild
# ---------------------------------------------------------------------------

## Leitet aus einem Eintrag den typ-basierten Aufbau ab: uid -> Instanz -> Typ ->
## Slot. DromeBuild bleibt dabei voellig unberuehrt -- Stats, Render und Kampf
## sehen denselben Build wie zuvor, egal ob er aus der Besitz-Schicht oder (beim
## Gegner) direkt aus Typen entstand.
func build_for(entry: RosterEntry) -> DromeBuild:
	var build := DromeBuild.new()
	build.display_name = entry.name
	build.direction = entry.direction
	build.palette = entry.palette.duplicate(true)

	# Das Chassis zuerst: es setzt Koerper, Kopf und Fuesse gemeinsam als Huelle
	# (§9). Kopf und Fuesse stehen deshalb in keiner Zuweisung.
	var chassis_id := instance_part_id(entry.chassis_uid())
	if chassis_id != &"":
		build.apply_chassis(chassis_id)
	build.drome_level = entry.level
	build.source_uid = entry.chassis_uid()

	for slot in entry.assignments:
		if slot == "body":
			continue
		var uid := str(entry.assignments[slot])
		var part_id := instance_part_id(uid)
		if part_id != &"":
			build.slots[slot] = part_id
			if str(slot).begins_with("equip_"):
				build.instance_uids[slot] = uid
				var owned := instance(uid)
				if owned != null and owned.level > 0:
					build.weapon_levels[slot] = owned.level
	return build


## Der Eintrag, dessen Chassis-Exemplar diese uid hat (DromeBuild.source_uid).
func entry_by_chassis(uid: String) -> RosterEntry:
	if uid == "":
		return null
	for entry in entries:
		if entry.chassis_uid() == uid:
			return entry
	return null


## Die Aufbauten aller DROMEs, die ins Gefecht mitgenommen werden (§10b). Das
## ist, was der Kampf als "Squad" bekommt.
func squad_builds() -> Array:
	var builds: Array = []
	for entry in entries:
		if entry.in_squad:
			builds.append(build_for(entry))
	return builds


func squad_count() -> int:
	var n := 0
	for entry in entries:
		if entry.in_squad:
			n += 1
	return n


# ---------------------------------------------------------------------------
# DROMEs anlegen und aufloesen
# ---------------------------------------------------------------------------

## Baut aus einer FREIEN Chassis-Instanz einen neuen DROME (einen neuen Roster-
## Platz, §10g). Kern und Ausruestung bleiben leer -- die waehlt die Werkstatt.
## null, wenn kein freies Chassis dieses Typs vorhanden ist.
func new_drome(chassis_part_id: StringName, entry_name: String = "") -> RosterEntry:
	var free := free_instance(chassis_part_id)
	if free == null:
		return null
	var part := free.part()
	var display := entry_name
	if display == "":
		display = part.display_name if part != null else "DROME"
	var entry := RosterEntry.create(display, free.uid)
	entries.append(entry)
	return entry


## Loest einen DROME auf: der Eintrag verschwindet, alle seine Instanzen (Chassis,
## Kern, Ausruestung) sind danach wieder frei im Inventar. Die Instanzen selbst
## bleiben besessen -- aufgeloest wird der DROME, nicht die Teile.
func disband(entry: RosterEntry) -> void:
	entries.erase(entry)


## Die freien Chassis-Instanzen, nach denen die Garage fragt, wenn sie einen neuen
## DROME anbietet -- ein Eintrag je distinktem freien Chassis-TYP.
func free_chassis_types() -> Array:
	var ids: Array = []
	for part_id in owned_part_ids(PartData.Type.BODY):
		if free_count(part_id) > 0:
			ids.append(part_id)
	return ids


# ---------------------------------------------------------------------------
# Startbestand, Persistenz, Migration
# ---------------------------------------------------------------------------

## Der handgesetzte Startbestand (§10g/§12c): vier Standard-Chassis als vier
## DROMEs mit ihrem themengleichen Kern und einer Startwaffe, dazu die uebrige
## Standard-Ausruestung frei im Inventar. Alle vier ziehen ins Gefecht: ein
## neuer Spielstand beginnt mit jedem Standard-DROME einmal im Squad.
func seed_starter() -> void:
	_instances.clear()
	entries.clear()
	_next_uid = 1

	for row in STARTER_CHASSIS:
		var chassis_uid := add_instance(row["body"])
		var entry := RosterEntry.create(_starter_name(row["body"]), chassis_uid)
		entry.assignments["core"] = add_instance(row["core"])
		# Jedes Teil des Kits in den ERSTEN passenden freien Slot legen -- welche
		# Slots die Huelle hat und was in sie darf, sagt die Huelle selbst
		# (equip_slots/accepts), nicht eine Annahme hier.
		for part_id in row["equipment"]:
			_seed_equip(entry, part_id)
		entry.in_squad = true
		entries.append(entry)

	for part_id in STARTER_LOOSE_EQUIPMENT:
		add_instance(part_id)


## Legt eine neue Instanz von ``part_id`` in den ersten Ausruestungsslot dieses
## Eintrags, der noch frei ist UND das Teil annimmt. So landet der support-only
## Drohnen-Pod im Schulterpod und nicht auf einem Waffenarm. Findet sich kein
## Slot, bleibt das Teil aussen vor (der Aufbau ist trotzdem gueltig).
func _seed_equip(entry: RosterEntry, part_id: StringName) -> void:
	var build := build_for(entry)
	var body := build.body()
	var part := PartDB.get_part(part_id)
	if body == null or part == null:
		return
	for slot in build.equip_slots():
		if entry.assignments.has(slot):
			continue
		if body.accepts(part, slot):
			entry.assignments[slot] = add_instance(part_id)
			return


## Ein sprechender Startname aus dem Chassis-Namen ("Vireo Chassis" -> "Vireo").
static func _starter_name(chassis_id: StringName) -> String:
	var part := PartDB.get_part(chassis_id)
	if part == null:
		return "DROME"
	return part.display_name.replace(" Chassis", "")


func to_dict() -> Dictionary:
	var inventory: Array = []
	for inst in _instances.values():
		inventory.append(inst.to_dict())
	var roster: Array = []
	for entry in entries:
		roster.append(entry.to_dict())
	return {
		"version": 2,
		"inventory": inventory,
		"roster": roster,
	}


## Laedt das v2-Format. Unbekannte Teile (alter Stand, umbenanntes Bauteil)
## werden uebersprungen -- ihre Zuweisungen zeigen dann ins Leere und der Slot
## ist einfach leer, statt dass der ganze Spielstand kippt.
func load_dict(data: Dictionary) -> bool:
	if not data is Dictionary or int(data.get("version", 0)) < 2:
		return false
	_instances.clear()
	entries.clear()
	_next_uid = 1

	for entry_data in data.get("inventory", []):
		var inst := PartInstance.from_dict(entry_data)
		if inst == null:
			continue
		if not PartDB.has_part(inst.part_id):
			push_warning("Roster: unbekanntes Teil %s uebersprungen" % inst.part_id)
			continue
		_instances[inst.uid] = inst
		_bump_uid(inst.uid)

	for entry_data in data.get("roster", []):
		var entry := RosterEntry.from_dict(entry_data)
		if entry == null:
			continue
		# Zuweisungen auf Instanzen pruefen, die es wirklich gibt -- eine uid ins
		# Leere waere eine stille Luege ueber den Aufbau.
		for slot in entry.assignments.keys():
			if not _instances.has(str(entry.assignments[slot])):
				entry.assignments.erase(slot)
		entries.append(entry)
	return true


## Setzt den uid-Zaehler hinter eine geladene uid, damit ``add_instance`` nie
## eine vergibt, die schon existiert.
func _bump_uid(uid: String) -> void:
	if uid.begins_with("inst-"):
		var n := int(uid.substr(5))
		if n >= _next_uid:
			_next_uid = n + 1


## Migriert den alten Wegwerf-Squad (v1: {squad_size, squad:[loadout]}) in
## Inventar + Roster. Fuer jeden alten Bot entstehen frische Instanzen fuer
## Chassis, Kern und Ausruestung; Kopf und Fuesse fallen weg (sie sind Teil der
## Huelle). So verliert niemand seinen gebauten Squad beim Umstieg auf §10g.
func migrate_v1(data: Dictionary) -> bool:
	if not data is Dictionary or not data.has("squad"):
		return false
	_instances.clear()
	entries.clear()
	_next_uid = 1

	for loadout in data.get("squad", []):
		var build := DromeBuild.from_loadout(loadout)
		if build == null:
			continue
		var chassis := build.body()
		if chassis == null:
			continue
		var entry := RosterEntry.create(build.display_name,
			add_instance(chassis.id))
		entry.direction = build.direction
		entry.palette = build.palette.duplicate(true)
		var core := build.part_in("core")
		if core != null:
			entry.assignments["core"] = add_instance(core.id)
		for slot in build.equip_slots():
			var part := build.part_in(slot)
			if part != null:
				entry.assignments[slot] = add_instance(part.id)
		entry.in_squad = true
		entries.append(entry)
	return not entries.is_empty()
