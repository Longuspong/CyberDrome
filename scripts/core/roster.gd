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
## darum schlicht: in keiner Zuweisung. Der Hangar bietet fuer einen Slot nur
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

## Lootcaches (14. Nov. 2026, SPOT-Blatt Lootcaches): Gebiet -> Anzahl. Noch
## nicht zu oeffnen (kommt mit dem Hangar-Shop, Bauschritt 4/5).
var caches: Dictionary = {}
## Platzhaltercoin (Arbeitsname): Waehrung fuer den Hangar-Shop.
var coins: int = 0
## Baumaterial: "kern:<fraktion>" -> Anzahl (Baukerne bis 24. Nov. 2026).
## Seit 20. Nov. 2026 auch "phase:<element>" (Energy Phases) und "rohling"
## (Charger-Rohlinge).
var materials: Dictionary = {}
## Charger (20. Nov. 2026, docs/CHARGER_KONZEPT.md): je Eintrag
## {"uid": "chg-N", "phases": [6 Element-ids oder ""], "on": Waffen-uid oder ""}.
## Ein Charger sitzt an hoechstens einer Waffe, eine Waffe traegt hoechstens einen.
var chargers: Array = []
var _next_charger: int = 1
## Fabrik (23. Nov. 2026, docs/FACTORY_KONZEPT.md): der gespeicherte Stand der
## Platine (``FactorySim.state``, eigene Versionsnummer). Die Waren liegen in
## ``materials`` ("res:<ware>"), das Lager IST das Inventar.
var factory: Dictionary = {}
var _factory_sim: FactorySim = null

## Die vier Standard-DROMEs mit ihrer VOLLEN Standard-Ausstattung -- der
## handgesetzte Startbestand (§10g/§12c). Reihenfolge = Reihenfolge im frischen
## Roster. Die Ausruestung wird der Reihe nach in den ersten passenden freien
## Slot gelegt (``_seed_equip``).
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
## Zahl, die der Hangar zeigt: so viele kann ich noch einbauen.
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
## sortiert, damit die Bibliothek stabil steht. Grundlage der Hangar-Ansicht:
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
	# Fraktions-DROME: feste Werte aus data/formations.json.
	if entry.variant != "":
		var spec: Dictionary = (Formations.data().get("dromes", {}) as Dictionary).get(entry.variant, {})
		for key in spec.get("stats", {}):
			build.stat_override[key] = int(spec["stats"][key])
		build.faction = str(spec.get("faction", ""))

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
				var mounted := charger_on(uid)
				if not mounted.is_empty():
					build.chargers[slot] = (mounted["phases"] as Array).duplicate()
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
## Platz, §10g). Kern und Ausruestung bleiben leer -- die waehlt der Hangar.
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


# ---------------------------------------------------------------------------
# Verwerten und Bauen (15. Nov. 2026, Wunsch des Spielers)
# ---------------------------------------------------------------------------

static func crafting_cfg() -> Dictionary:
	return Config.section("crafting")


static func core_name(faction: String) -> String:
	return str((crafting_cfg().get("faction_core_names", {}) as Dictionary).get(faction,
		"%s-Kern" % faction.capitalize()))


func faction_cores(faction: String) -> int:
	return int(materials.get("kern:" + faction, 0))


## Ein Fraktionskern aus einem Einsatz (Chaos-Beute, 19. Nov. 2026).
func add_faction_core(faction: String) -> void:
	if faction != "":
		_add_material("kern:" + faction, 1)


# ---------------------------------------------------------------------------
# Charger und Energy Phases (20. Nov. 2026)
# ---------------------------------------------------------------------------

func phases(element: String) -> int:
	return int(materials.get("phase:" + element, 0))


func add_phases(element: String, amount: int = 1) -> void:
	if element in Charger.element_ids():
		_add_material("phase:" + element, amount)


func blanks() -> int:
	return int(materials.get("rohling", 0))


func add_blanks(amount: int = 1) -> void:
	_add_material("rohling", amount)


## Warum sich diese Phasen nicht bauen lassen ("" = geht).
func charger_blocker(phase_list: Array) -> String:
	if blanks() < 1:
		return "Kein Charger-Rohling."
	var want := Charger.counts(Charger.normalized(phase_list))
	if want.is_empty():
		return "Keine Phase im Hexagon."
	for id in want:
		if phases(id) < int(want[id]):
			return "Zu wenig %s-Phasen." % Charger.element_name(id)
	return ""


## Baut einen Charger: ein Rohling und die Phasen werden verbraucht. Gibt den
## neuen Charger zurueck (leer, wenn es nicht geht).
func craft_charger(phase_list: Array) -> Dictionary:
	var list := Charger.normalized(phase_list)
	if charger_blocker(list) != "":
		return {}
	var want := Charger.counts(list)
	for id in want:
		add_phases(id, -int(want[id]))
	add_blanks(-1)
	var charger := {"uid": "chg-%d" % _next_charger, "phases": list, "on": ""}
	_next_charger += 1
	chargers.append(charger)
	return charger


func charger(uid: String) -> Dictionary:
	for c in chargers:
		if str(c.get("uid", "")) == uid:
			return c
	return {}


## Der Charger an dieser Waffe (Exemplar-uid), sonst leer.
func charger_on(weapon_uid: String) -> Dictionary:
	if weapon_uid == "":
		return {}
	for c in chargers:
		if str(c.get("on", "")) == weapon_uid:
			return c
	return {}


## Setzt einen Charger in eine Waffe. Ein Charger an einer anderen Waffe zieht
## um; was vorher in dieser Waffe sass, wird frei.
func mount_charger(charger_uid: String, weapon_uid: String) -> bool:
	var c := charger(charger_uid)
	if c.is_empty() or instance(weapon_uid) == null:
		return false
	unmount_charger(weapon_uid)
	c["on"] = weapon_uid
	return true


func unmount_charger(weapon_uid: String) -> void:
	var old := charger_on(weapon_uid)
	if not old.is_empty():
		old["on"] = ""


# ---------------------------------------------------------------------------
# Lootcaches oeffnen (20. Nov. 2026, CHARGER_KONZEPT.md 5)
# ---------------------------------------------------------------------------

## Oeffnet einen Cache aus dem Lager: ``charger.cache.rolls`` Wuerfe nach der
## Tabelle, alles wird gutgeschrieben. Gibt die Ergebnisse in Wurf-Reihenfolge
## zurueck, je {"kind", "element"?, "amount"?, "faction"?, "name"?}. Leer, wenn
## kein Cache da ist.
func open_cache(kind: String, rng: RandomNumberGenerator = null) -> Array:
	if int(caches.get(kind, 0)) <= 0:
		return []
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	caches[kind] = int(caches[kind]) - 1
	if int(caches[kind]) <= 0:
		caches.erase(kind)
	var faction := str((RunState.loot_cfg().get("faction_cores", {}) as Dictionary).get(kind, ""))
	var cache_cfg := Charger.cfg().get("cache", {}) as Dictionary
	var results: Array = []
	for i in int(cache_cfg.get("rolls", 4)):
		results.append(_cache_roll(cache_cfg.get("table", []), faction, rng))
	return results


func _cache_roll(table: Array, faction: String, rng: RandomNumberGenerator) -> Dictionary:
	var roll := rng.randf()
	var row: Dictionary = table[table.size() - 1] if not table.is_empty() else {"kind": "coins"}
	for r in table:
		roll -= float(r.get("chance", 0.0))
		if roll < 0.0:
			row = r
			break
	match str(row.get("kind", "")):
		"faction_drome":
			var picks: Array = []
			for id in faction_variants():
				if str(((Formations.data().get("dromes", {}) as Dictionary).get(id, {}) as Dictionary).get("faction", "")) == faction:
					picks.append(id)
			if not picks.is_empty():
				var id: String = picks[rng.randi() % picks.size()]
				var spec: Dictionary = (Formations.data().get("dromes", {}) as Dictionary)[id]
				var entry := craft_drome_free(StringName(str(spec.get("chassis", ""))), faction_drome_name(id))
				if entry != null:
					entry.variant = id
					return {"kind": "faction_drome", "name": faction_drome_name(id), "faction": faction}
			add_faction_core(faction)
			return {"kind": "faction_core", "faction": faction}
		"faction_core":
			if faction == "":
				add_blanks(1)
				return {"kind": "blank"}
			add_faction_core(faction)
			return {"kind": "faction_core", "faction": faction}
		"keynode":
			_add_material("keynode", 1)
			return {"kind": "keynode"}
		"phase":
			var ids := Charger.element_ids()
			var e: String = ids[rng.randi() % ids.size()]
			add_phases(e, 1)
			return {"kind": "phase", "element": e}
		"blank":
			add_blanks(1)
			return {"kind": "blank"}
	var amount := rng.randi_range(int(row.get("min", 10)), int(row.get("max", 20)))
	coins += amount
	return {"kind": "coins", "amount": amount}


func _add_material(key: String, amount: int) -> void:
	materials[key] = maxi(0, int(materials.get(key, 0)) + amount)
	if int(materials[key]) == 0:
		materials.erase(key)


## Warum dieser DROME nicht verwertet werden darf ("" = darf). Der letzte
## bleibt: ohne DROME gaebe es kein Spiel und keine Baukerne.
func salvage_blocker(entry: RosterEntry) -> String:
	if not entries.has(entry):
		return "nicht im Hangar"
	if entries.size() <= 1:
		return "der letzte DROME bleibt"
	return ""


## Verwertet einen DROME (statt ihn aufzuloesen): Chassis und Kern
## verschwinden, die Waffen kommen frei in den Hangar, Level gehen verloren.
## Seit 24. Nov. 2026 (Werkbank): zurueck kommen die Zutaten der teuersten Teile
## (``Workbench.salvage_yield``), ein Fraktions-DROME gibt dazu sein Spezialteil.
## Gibt zurueck, was es gab: {wares: {ware: menge}, special: variante oder ""}.
func salvage(entry: RosterEntry) -> Dictionary:
	if salvage_blocker(entry) != "":
		return {}
	var body_uid := str(entry.assignments.get("body", ""))
	var chassis := str(_instances[body_uid].part_id) if _instances.has(body_uid) else ""
	var got := Workbench.salvage_yield(chassis, entry.variant)
	for slot in ["body", "core"]:
		var uid := str(entry.assignments.get(slot, ""))
		if uid != "":
			_instances.erase(uid)
	entries.erase(entry)
	for ware in got["wares"]:
		_add_material(FactorySim.material_key(str(ware)), int(got["wares"][ware]))
	if str(got["special"]) != "":
		_add_material("spezial:" + str(got["special"]), 1)
	return got


## Der Kern, der zu einem Standard-Chassis gehoert (Startbestand).
static func core_for(chassis_id: StringName) -> StringName:
	for row in STARTER_CHASSIS:
		if row["body"] == chassis_id:
			return row["core"]
	return &""


## Name eines Fraktions-DROME (21. Nov. 2026, Spieler): eine Variante heisst wie
## ihr Chassis (Molok), ein neuer DROME traegt seinen eigenen Namen (Neon Vireo).
static func faction_drome_name(variant_id: String) -> String:
	var spec: Dictionary = (Formations.data().get("dromes", {}) as Dictionary).get(variant_id, {})
	if str(spec.get("art", "")) == "variante":
		return _starter_name(StringName(str(spec.get("chassis", ""))))
	return str(spec.get("name", variant_id))


## Untertitel unter dem Namen: die Fraktion ("Mega Mechas", "Neon Ninja's") oder
## "CyberDrome" fuer die Standard-DROMEs. ``faction`` ist der Schluessel (mecha).
static func subtitle_for(faction: String) -> String:
	if faction == "":
		return "CyberDrome"
	var cores: Dictionary = RunState.loot_cfg().get("faction_cores", {})
	for region_id in cores:
		if str(cores[region_id]).to_lower() == faction.to_lower():
			var region := TerrainDB.get_region(StringName(str(region_id)))
			if region != null:
				return str(region.faction.get("name", faction))
	return faction.capitalize()


## Der Untertitel eines Roster-Eintrags.
static func subtitle(entry: RosterEntry) -> String:
	if entry == null or entry.variant == "":
		return subtitle_for("")
	var spec: Dictionary = (Formations.data().get("dromes", {}) as Dictionary).get(entry.variant, {})
	return subtitle_for(str(spec.get("faction", "")))


## Die Fraktions-DROMEs, die sich bauen liessen (alle mit festen Werten).
static func faction_variants() -> Array:
	var out: Array = []
	var dromes: Dictionary = Formations.data().get("dromes", {})
	for id in dromes:
		if str(dromes[id].get("faction", "")) != "" and not (dromes[id].get("stats", {}) as Dictionary).is_empty():
			out.append(str(id))
	return out


## Chassis und Kern ohne Kosten (Werkbank, Cache-Beute).
func craft_drome_free(chassis_id: StringName, entry_name: String) -> RosterEntry:
	var entry := RosterEntry.create(entry_name, add_instance(chassis_id))
	var core := core_for(chassis_id)
	if core != &"":
		entry.assignments["core"] = add_instance(core)
	entries.append(entry)
	return entry


# ---------------------------------------------------------------------------
# Hangar-Shop (15. Nov. 2026): Baukerne und Caches fuer Platzhaltercoin
# ---------------------------------------------------------------------------

static func shop_offers() -> Array:
	return (Config.section("hangar_shop").get("offers", []) as Array)


## Warum ein Angebot nicht zu kaufen ist ("" = geht).
func offer_blocker(offer: Dictionary) -> String:
	if coins < int(offer.get("price", 0)):
		return "zu wenig Coins"
	return ""


## Kauft ein Angebot: Coins weg, Cache dazu.
func buy_offer(offer: Dictionary) -> bool:
	if offer_blocker(offer) != "":
		return false
	match str(offer.get("kind", "")):
		"cache":
			var key := str(offer.get("cache", "city"))
			caches[key] = int(caches.get(key, 0)) + 1
		_:
			return false
	coins -= int(offer.get("price", 0))
	return true


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
	caches = {}
	coins = 0
	materials = {}
	factory = {}
	_factory_sim = null

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
	trim_squad()

	for part_id in STARTER_LOOSE_EQUIPMENT:
		add_instance(part_id)


## Startbestand eines NEUEN Spielstands (21. Nov. 2026, Wunsch des Spielers;
## 23. Nov.: ohne Fraktions-DROMEs): die vier CyberDrome-DROMEs mit ihrer
## Ausstattung, jede Waffe einmal (die uebrigen frei im Inventar), jede Energy Phase 6-mal, 2 Charger-
## Rohlinge, je Gebiet 5 Lootcaches und 200 Platzhaltercoin. Werte in
## config.json -> new_game. ``seed_starter`` bleibt der schlanke Bestand fuer
## Tests und den Standard-Squad.
func seed_new_game() -> void:
	seed_starter()
	var cfg := Config.section("new_game")
	# Fraktions-DROMEs (ohne Waffe gebaut, bekommen gleich eine). Seit 23. Nov.
	# 2026 aus (Spieler: Start nur mit den vier CyberDrome-DROMEs, die
	# Fraktions-DROMEs werden gerade ueberarbeitet) -- config new_game.faction_dromes.
	var fresh: Array = []
	for variant in (faction_variants() if bool(cfg.get("faction_dromes", false)) else []):
		var spec: Dictionary = (Formations.data().get("dromes", {}) as Dictionary).get(variant, {})
		var entry := craft_drome_free(StringName(str(spec.get("chassis", ""))), faction_drome_name(variant))
		if entry == null:
			continue
		entry.variant = variant
		fresh.append(entry)
	# Jede Waffe genau einmal: was der Startbestand nicht hat, kommt dazu.
	for part in PartDB.of_type(PartData.Type.EQUIPMENT):
		if total_count(part.id) < 1:
			add_instance(part.id)
	# Freie Waffen in die neuen DROMEs, in der Reihenfolge der Vorliebe.
	var order: Array = cfg.get("weapon_order", [])
	for entry in fresh:
		var build := build_for(entry)
		var body := build.body()
		if body == null:
			continue
		for slot in build.equip_slots():
			if entry.assignments.has(slot):
				continue
			var picks: Array = order.duplicate()
			for inst in all_instances():
				if not picks.has(str(inst.part_id)):
					picks.append(str(inst.part_id))
			for pid in picks:
				var inst := free_instance(StringName(pid))
				if inst != null and inst.type() == PartData.Type.EQUIPMENT and body.accepts(inst.part(), slot):
					entry.assignments[slot] = inst.uid
					break
	for e in Charger.element_ids():
		add_phases(e, int(cfg.get("phases_each", 6)))
	add_blanks(int(cfg.get("blanks", 2)))
	for kind in (RunState.loot_cfg().get("cache_names", {}) as Dictionary):
		caches[str(kind)] = int(cfg.get("caches_each", 5))
	coins = int(cfg.get("coins", 200))


## Legt eine neue Instanz von ``part_id`` in den ersten Ausruestungsslot dieses
## Eintrags, der noch frei ist UND das Teil annimmt. Findet sich kein
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
		"caches": caches.duplicate(),
		"coins": coins,
		"materials": materials.duplicate(),
		"chargers": chargers.duplicate(true),
		"factory": factory_state(),
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
	caches = {}
	for key in data.get("caches", {}):
		caches[str(key)] = int(data["caches"][key])
	coins = int(data.get("coins", 0))
	materials = {}
	for key in data.get("materials", {}):
		materials[str(key)] = int(data["materials"][key])
	factory = data.get("factory", {}) if data.get("factory", {}) is Dictionary else {}
	_factory_sim = null
	chargers = []
	_next_charger = 1
	for c in data.get("chargers", []):
		if not c is Dictionary or str(c.get("uid", "")) == "":
			continue
		var uid := str(c["uid"])
		chargers.append({"uid": uid, "phases": Charger.normalized(c.get("phases", [])),
			"on": str(c.get("on", ""))})
		if uid.begins_with("chg-"):
			_next_charger = maxi(_next_charger, int(uid.substr(4)) + 1)

	for entry_data in data.get("inventory", []):
		var inst := PartInstance.from_dict(entry_data)
		if inst == null:
			continue
		if not PartDB.has_part(inst.part_id):
			push_warning("Roster: unbekanntes Teil %s übersprungen" % inst.part_id)
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
		# Varianten hiessen bis 21. Nov. 2026 "Mecha Molok" -- jetzt "Molok"
		# mit der Fraktion als Untertitel (selbst vergebene Namen bleiben).
		if entry.variant != "":
			var spec: Dictionary = (Formations.data().get("dromes", {}) as Dictionary).get(entry.variant, {})
			if str(spec.get("art", "")) == "variante" and entry.name == str(spec.get("name", "")):
				entry.name = faction_drome_name(entry.variant)
		entries.append(entry)
	for c in chargers:
		if str(c["on"]) != "" and not _instances.has(str(c["on"])):
			c["on"] = ""
	trim_squad()
	return true


## Die Fabrik dieses Spielstands. Arbeitet direkt auf ``materials`` (Lager).
func factory_sim() -> FactorySim:
	if _factory_sim == null or not is_same(_factory_sim.lager, materials):
		_factory_sim = FactorySim.new(factory, materials)
	return _factory_sim


## Der Stand zum Speichern (ohne Sim: so, wie er geladen wurde).
func factory_state() -> Dictionary:
	if _factory_sim != null:
		factory = _factory_sim.to_dict()
	return factory.duplicate(true)


## Laesst die Fabrik ``ticks`` Takte laufen (nach einem Kampf). Gibt zurueck,
## was ins Lager ging: {ware: menge}.
func run_factory(ticks: int) -> Dictionary:
	return factory_sim().run(ticks)


## Der Squad ist seit 16. Nov. 2026 hoechstens drei DROMEs gross (Vorgabe des
## Spielers; run.squad_max). Ein aelterer Spielstand mit vier im Squad behaelt
## die ersten drei, der vierte bleibt im Hangar.
func trim_squad(limit: int = -1) -> void:
	if limit < 0:
		limit = RunState.squad_max()
	var kept := 0
	for entry in entries:
		if entry.in_squad:
			kept += 1
			if kept > limit:
				entry.in_squad = false


## Setzt den uid-Zaehler hinter eine geladene uid, damit ``add_instance`` nie
## eine vergibt, die schon existiert.
func _bump_uid(uid: String) -> void:
	if uid.begins_with("inst-"):
		var n := int(uid.substr(5))
		if n >= _next_uid:
			_next_uid = n + 1
