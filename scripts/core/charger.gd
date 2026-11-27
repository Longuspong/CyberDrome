class_name Charger
extends RefCounted

## Charger und Energy Phases (20. Nov. 2026, docs/CHARGER_KONZEPT.md).
##
## Ein Charger ist eine Liste von bis zu sechs Phasen (Element-ids, "" = leeres
## Feld). Diese Klasse rechnet nur: Namen, Farben, Belastung je Treffer,
## ueberwiegendes Element, Resonanz und die Angaben fuer den Kampf. Besitz und
## Bauen liegen im Roster, die Wirkung im ActionResolver. Werte in
## data/config.json -> charger.


static func cfg() -> Dictionary:
	return Config.section("charger")


static func slots() -> int:
	return int(cfg().get("slots", 6))


## Die Element-ids in fester Reihenfolge (fire, cryo, volt, terra, virus, chaos).
static func element_ids() -> Array:
	var out: Array = []
	for e in cfg().get("elements", []):
		out.append(str(e.get("id", "")))
	return out


static func element(id: String) -> Dictionary:
	for e in cfg().get("elements", []):
		if str(e.get("id", "")) == id:
			return e
	return {}


static func element_name(id: String) -> String:
	return str(element(id).get("name", id))


static func element_color(id: String) -> Color:
	return Color(str(element(id).get("color", "#ffffff")))


## Wirken Stapel dieses Elements schon (heute nur Feuer)?
static func is_built(id: String) -> bool:
	return bool(element(id).get("built", false))


## Bringt eine Phasenliste auf genau ``slots()`` Felder, unbekannte zu "".
static func normalized(phases: Array) -> Array:
	var ids := element_ids()
	var out: Array = []
	for i in slots():
		var e := str(phases[i]) if i < phases.size() else ""
		out.append(e if e in ids else "")
	return out


## Element -> Anzahl Phasen (nur die vorhandenen).
static func counts(phases: Array) -> Dictionary:
	var out := {}
	for e in phases:
		var id := str(e)
		if id != "":
			out[id] = int(out.get(id, 0)) + 1
	return out


static func filled(phases: Array) -> int:
	var n := 0
	for e in phases:
		if str(e) != "":
			n += 1
	return n


## Das Element mit MEHR Phasen als jedes andere, sonst "" (Gleichstand, leer).
static func dominant(phases: Array) -> String:
	var c := counts(phases)
	var best := ""
	var best_n := 0
	var tie := false
	for id in element_ids():
		var n := int(c.get(id, 0))
		if n > best_n:
			best = id
			best_n = n
			tie = false
		elif n == best_n and n > 0:
			tie = true
	return "" if tie else best


## Wie viele gleiche Phasen das ueberwiegende Element hat.
static func dominant_count(phases: Array) -> int:
	var d := dominant(phases)
	return int(counts(phases).get(d, 0)) if d != "" else 0


## Die hoechste erreichte Resonanzstufe (0, 2, 4 oder 6).
static func resonance(phases: Array) -> int:
	var n := dominant_count(phases)
	var best := 0
	for r in cfg().get("resonance", []):
		var at := int(r.get("at", 99))
		if n >= at:
			best = maxi(best, at)
	return best


## Alle erreichten Resonanzstufen (sie zaehlen zusammen), aufsteigend.
static func active_resonances(phases: Array) -> Array:
	var n := dominant_count(phases)
	var out: Array = []
	for r in cfg().get("resonance", []):
		if n >= int(r.get("at", 99)):
			out.append(r)
	return out


## Element -> Belastung je Treffer.
static func loads(phases: Array) -> Dictionary:
	var per := int(cfg().get("load_per_phase", 20))
	var out := {}
	var c := counts(phases)
	for id in element_ids():
		if c.has(id):
			out[id] = int(c[id]) * per
	return out


## Was die Faehigkeit an Belastung des ueberwiegenden Elements anlegt (die
## hoechste erreichte Stufe; 0 ohne Resonanz).
static func ability_load(phases: Array) -> int:
	var best := 0
	for r in active_resonances(phases):
		best = maxi(best, int(r.get("ability_load", 0)))
	return best


## Der Takt, an dem ein Treffer doppelt anlegt: die hoechste erreichte Stufe
## gilt, Stufe 6 macht aus "jeder 5." ein "jeder 3." (Upgrade, Spieler 20. Nov.
## 2026). Als Liste (leer = nie), damit der Kampf sie wie bisher liest.
static func double_every(phases: Array) -> Array:
	var out: Array = []
	for r in active_resonances(phases):
		var every := int(r.get("double_every", 0))
		if every > 0:
			out = [every]
	return out


## Kurztexte je Resonanzstufe fuer die Anzeige.
static func resonance_text(at: int) -> String:
	match at:
		2:
			return "Fähigkeit +%d" % _res_value(2, "ability_load", 100)
		4:
			return "jeder %d. Treffer ×2" % _res_value(4, "double_every", 5)
		6:
			return "jeder %d. Treffer ×2, Fähigkeit +%d" % [
				_res_value(6, "double_every", 3), _res_value(6, "ability_load", 200)]
	return ""


## Wird diese Stufe von einer hoeheren ueberboten? (Stufe 6 verbessert die
## Faehigkeit von 2 und den Takt von 4.)
static func upgraded(at: int, phases: Array) -> bool:
	return at < 6 and resonance(phases) >= 6


static func _res_value(at: int, key: String, fallback: int) -> int:
	for r in cfg().get("resonance", []):
		if int(r.get("at", 0)) == at:
			return int(r.get(key, fallback))
	return fallback


## Anzeigename: FIRECHARGER, CRYOCHARGER ... oder MISCHCHARGER.
static func display_name(phases: Array) -> String:
	var d := dominant(phases)
	if d == "":
		return "Mischcharger" if filled(phases) > 0 else "Leerer Charger"
	return "%scharger" % element_name(d)


## Die Angaben fuer den Kampf (ActionData.charger). Leer ohne Phasen.
static func combat_spec(phases: Array) -> Dictionary:
	if filled(phases) == 0:
		return {}
	return {
		"load": loads(phases),
		"dominant": dominant(phases),
		"ability_load": ability_load(phases),
		"double_every": double_every(phases),
		"ability_stacks": int(cfg().get("dominant_ability_stacks", 1)),
		"stack_at": int(cfg().get("stack_at", 100)),
		"hits": 0,
	}
