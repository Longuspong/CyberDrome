class_name Workbench
extends RefCounted

## Die Werkbank als Logik (24. Nov. 2026, docs/FACTORY_KONZEPT.md Abschnitt 13):
## alles, was aus dem Lager entsteht, an einem Ort. Produkte:
##
##   "rohling"               Charger-Rohling aus Ressourcen
##   "teil:<chassis>:<teil>" ein DROME-Teil aus Ressourcen (liegt danach im Lager)
##   "drome:<chassis>"       Standard-DROME aus seinen fuenf Teilen
##   "faction:<variante>"    Fraktions-DROME: die Teile, aber der Fraktionskern
##                           ersetzt das Kern-Teil
##   "free:<chassis>"        freies Chassis aus alter Beute (kostenlos)
##
## Alles liegt in ``Roster.materials``: Ressourcen als "res:<ware>", Teile als
## "teil:<chassis>:<teil>", Fraktionskerne als "kern:<fraktion>", zusaetzliche
## Bauplaene als "bauplan:<produkt>". Herstellen geht sofort -- die Zeit steckt
## in der Fabrik.

var roster: Roster


func _init(owner_roster: Roster) -> void:
	roster = owner_roster


static func cfg() -> Dictionary:
	return FactorySim.data().get("werkbank", {})


## Die Teile eines Chassis: [{id, name, kosten, anzahl?}].
static func parts_of(chassis: String) -> Array:
	return (cfg().get("dromes", {}) as Dictionary).get(chassis, [])


static func part_key(chassis: String, part_id: String) -> String:
	return "teil:%s:%s" % [chassis, part_id]


static func part_spec(key: String) -> Dictionary:
	var bits := key.split(":")
	if bits.size() != 3:
		return {}
	for part in parts_of(bits[1]):
		if str(part["id"]) == bits[2]:
			return part
	return {}


static func chassis_name(chassis: String) -> String:
	var body := PartDB.get_part(StringName(chassis)) if PartDB != null else null
	return body.display_name.replace(" Chassis", "") if body != null else chassis


## Anzeigename eines Lager-Schluessels.
static func key_name(key: String) -> String:
	if key.begins_with("res:"):
		return FactorySim.ware_name(key.substr(4))
	if key == "rohling":
		return FactorySim.ware_name("rohling")
	if key.begins_with("teil:"):
		return str(part_spec(key).get("name", key))
	if key.begins_with("kern:"):
		return Roster.core_name(key.substr(5))
	return key


## Lager-Schluessel einer Ware (Ressource) wie FactorySim.
static func ware_key(ware: String) -> String:
	return FactorySim.material_key(ware)


func have(key: String) -> int:
	return int(roster.materials.get(key, 0))


func _add(key: String, amount: int) -> void:
	var total := maxi(0, have(key) + amount)
	if total == 0:
		roster.materials.erase(key)
	else:
		roster.materials[key] = total


# ---------------------------------------------------------------- Produkte

## Kennt der Spieler den Bauplan?
func known(id: String) -> bool:
	if id.begins_with("free:") or id.begins_with("teil:"):
		return true
	if id.begins_with("faction:"):
		return roster.faction_cores(_faction_of(id.substr(8))) > 0
	return id in (cfg().get("bauplaene_start", []) as Array) or have("bauplan:" + id) > 0


func _faction_of(variant: String) -> String:
	var spec: Dictionary = (Formations.data().get("dromes", {}) as Dictionary).get(variant, {})
	return str(spec.get("faction", ""))


## Das Chassis hinter einem Produkt ("" = keins).
static func chassis_of(id: String) -> String:
	if id.begins_with("drome:") or id.begins_with("free:"):
		return id.split(":")[1]
	if id.begins_with("teil:"):
		return id.split(":")[1]
	if id.begins_with("faction:"):
		var spec: Dictionary = (Formations.data().get("dromes", {}) as Dictionary).get(id.substr(8), {})
		return str(spec.get("chassis", ""))
	return ""


func name_of(id: String) -> String:
	if id == "rohling":
		return FactorySim.ware_name("rohling")
	if id.begins_with("teil:"):
		return key_name(id)
	if id.begins_with("faction:"):
		return Roster.faction_drome_name(id.substr(8))
	return chassis_name(chassis_of(id))


## Was sich in einer Kategorie bauen laesst ("charger" oder "dromes"): Produkt-ids.
func products(category: String) -> Array:
	var out: Array = []
	if category == "charger":
		out.append("rohling")
		return out
	for chassis_id in roster.free_chassis_types():
		out.append("free:%s" % chassis_id)
	for chassis in (cfg().get("dromes", {}) as Dictionary):
		if known("drome:" + str(chassis)):
			out.append("drome:" + str(chassis))
	for variant in Roster.faction_variants():
		if known("faction:" + str(variant)):
			out.append("faction:" + str(variant))
	return out


## Was ein Produkt direkt verbraucht: {lager-schluessel: menge}.
func needs(id: String) -> Dictionary:
	var out := {}
	if id == "rohling":
		for ware in FactorySim.craft_cost("rohling"):
			out[ware_key(str(ware))] = int(FactorySim.craft_cost("rohling")[ware])
	elif id.begins_with("teil:"):
		var cost: Dictionary = part_spec(id).get("kosten", {})
		for ware in cost:
			out[ware_key(str(ware))] = int(cost[ware])
	elif id.begins_with("drome:") or id.begins_with("faction:"):
		var chassis := chassis_of(id)
		for part in parts_of(chassis):
			if id.begins_with("faction:") and str(part["id"]) == "kern":
				out["kern:" + _faction_of(id.substr(8))] = 1
				continue
			out[part_key(chassis, str(part["id"]))] = int(part.get("anzahl", 1))
	return out


## Was fehlt: {lager-schluessel: menge}.
func missing(id: String) -> Dictionary:
	var out := {}
	var need := needs(id)
	for key in need:
		var short := int(need[key]) - have(str(key))
		if short > 0:
			out[key] = short
	return out


func can_craft(id: String) -> bool:
	return known(id) and missing(id).is_empty()


## Die Ressourcen, die insgesamt noch fehlen -- fehlende Teile in ihre Zutaten
## aufgeloest: {ware: menge}. Fuer "Als Ziel" und die Schaetzung in Kaempfen.
func raw_shortfall(id: String) -> Dictionary:
	var total := {}
	var need := needs(id)
	for key in need:
		if str(key).begins_with("res:"):
			total[str(key).substr(4)] = int(total.get(str(key).substr(4), 0)) + int(need[key])
	var miss := missing(id)
	for key in miss:
		if str(key).begins_with("teil:"):
			var cost: Dictionary = part_spec(str(key)).get("kosten", {})
			for ware in cost:
				total[ware] = int(total.get(ware, 0)) + int(cost[ware]) * int(miss[key])
	var out := {}
	for ware in total:
		var short := int(total[ware]) - have(ware_key(str(ware)))
		if short > 0:
			out[ware] = short
	return out


## Wie viele Kaempfe die Platine fuer ``shortfall`` braucht (-1 = nie: eine Ware
## entsteht dort gerade nicht). ``per_tick`` aus FactorySim.estimate_per_tick.
static func battles_for(shortfall: Dictionary, per_tick: Dictionary) -> int:
	var worst := 0.0
	for ware in shortfall:
		var rate := float(per_tick.get(ware, 0.0)) * FactorySim.ticks_per_battle()
		if rate <= 0.0:
			return -1
		worst = maxf(worst, float(shortfall[ware]) / rate)
	return int(ceilf(worst))


## Stellt her. Gibt zurueck: {"ok": bool, "entry": RosterEntry oder null, "why": String}.
func craft(id: String) -> Dictionary:
	if not known(id):
		return {"ok": false, "entry": null, "why": "Bauplan fehlt."}
	if not missing(id).is_empty():
		return {"ok": false, "entry": null, "why": "Es fehlt noch etwas."}
	var entry: RosterEntry = null
	if id.begins_with("free:"):
		entry = roster.new_drome(StringName(chassis_of(id)))
		return {"ok": entry != null, "entry": entry, "why": ""}
	var need := needs(id)
	for key in need:
		_add(str(key), -int(need[key]))
	if id == "rohling":
		_add("rohling", 1)
	elif id.begins_with("teil:"):
		_add(id, 1)
	elif id.begins_with("drome:"):
		var chassis := StringName(chassis_of(id))
		entry = roster.craft_drome_free(chassis, Roster._starter_name(chassis))
	elif id.begins_with("faction:"):
		var variant := id.substr(8)
		entry = roster.craft_drome_free(StringName(chassis_of(id)), Roster.faction_drome_name(variant))
		entry.variant = variant
	return {"ok": true, "entry": entry, "why": ""}
