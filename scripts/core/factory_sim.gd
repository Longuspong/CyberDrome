class_name FactorySim
extends RefCounted

## Die Fabrik als reine Logik (23. Nov. 2026, docs/FACTORY_KONZEPT.md Abschnitt 11).
##
## Eine Hex-Platine (flache Sechsecke, axiale Felder "q,r"), Gebaeude holen ihre
## Zutaten bei direkten Nachbarn ab (Relais verbinden weiter), Strom kommt vom
## Netzanschluss in der Mitte und von Strom-Gebaeuden nach Naehe, was keiner
## braucht oder ueber den Ausgangspuffer geht, geht per Uplink ins Lager.
##
## Ablauf je Takt wie im Prototyp v2 (docs/design/factory_prototyp/factory_v2.html):
##   0 Verbindungen  1 Abholen reihum  2 Strom (Bedarf, Quellen nach Naehe,
##   Batterie, Brennstoff nur bei Verbrauch)  3 Herstellen (Anlauf, Resonanz,
##   Schatten)  4 Uplink.
## Deterministisch: alles in der Reihenfolge der Gebaeude-ids, kein Zufall.
##
## ``state`` ist der gespeicherte Stand (JSON-tauglich, mit Version), ``lager``
## das Woerterbuch, in dem die Waren liegen -- im Spiel ``Roster.materials``
## (Schluessel ueber ``material_key``: "res:<ware>", der Charger-Rohling als
## "rohling"). Alles uebrige (Status, Verlauf, Strom) lebt nur zur Laufzeit.

const PATH := "res://data/factory.json"
const SAVE_VERSION := 1
## Die sechs Nachbarn in axialen Koordinaten.
const DIRS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0),
	Vector2i(-1, 1), Vector2i(0, 1)]
## So viele Takte merkt sich die Anzeige je Gebaeude (Durchsatz).
const HISTORY := 30

static var _data: Dictionary = {}

var state: Dictionary = {}
var lager: Dictionary = {}

## Laufzeit: Feld -> [{k, path}] (verbundene Gebaeude mit Weg ueber Relais).
var links: Dictionary = {}
## Laufzeit: Gebaeude-id -> {status, miss, need, got, eff, wait, in_h, out_h, up_h}.
var info: Dictionary = {}
## Laufzeit: Summe {supply, demand, used, batt, batt_max}.
var power: Dictionary = {"supply": 0.0, "demand": 0.0, "used": 0.0, "batt": 0.0, "batt_max": 0.0}
## Laufzeit: Feld einer Stromquelle -> {cap, used}.
var source_info: Dictionary = {}
## Laufzeit: Feld des Gebaeudes, das am laengsten wartet ("" = keins).
var engpass: String = ""
## Laufzeit: je Takt die Waren, die ins Lager gingen (die letzten HISTORY).
var gain_history: Array = []


static func data() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data


static func defs() -> Dictionary:
	return data().get("gebaeude", {})


static func def(type: String) -> Dictionary:
	return defs().get(type, {})


static func wares() -> Dictionary:
	return data().get("waren", {})


static func ware_name(ware: String) -> String:
	return str((wares().get(ware, {}) as Dictionary).get("name", ware))


static func ware_color(ware: String) -> Color:
	return Color(str((wares().get(ware, {}) as Dictionary).get("farbe", "#ffffff")))


## Unter welchem Schluessel eine Ware im Lager (``Roster.materials``) liegt.
static func material_key(ware: String) -> String:
	var entry: Dictionary = wares().get(ware, {})
	return str(entry.get("material", "res:" + ware))


static func setting(key: String, fallback = 0):
	return (data().get("takte", {}) as Dictionary).get(key, fallback)


static func ticks_per_battle() -> int:
	return int(setting("je_kampf", 100))


static func live_seconds() -> float:
	return float(setting("live_sekunden", 6))


## "Kurz", wie viele Durchlaeufe: "jeden Takt", "alle 2 Takte", "3× je Takt".
static func recipe_text(type: String) -> String:
	var d := def(type)
	var rate := float(d.get("rate", 0))
	var every := ""
	if rate >= 1.0:
		every = "%s× je Takt" % _num(rate) if rate > 1.0 else "jeden Takt"
	elif rate > 0.0:
		every = "alle %s Takte" % _num(1.0 / rate)
	if d.get("relais", false):
		return "Leitet Waren weiter"
	if d.get("batterie", false):
		return "Speichert bis %d Strom" % int(d.get("speicher", 0))
	if d.has("brennstoff"):
		return "1 %s → %d Strom je Takt, Reichweite %d" % [ware_name(str(d["brennstoff"])),
			int(d.get("liefert", 0)), int(d.get("reichweite", 0))]
	if d.has("liefert"):
		return "%d Strom, Reichweite %d" % [int(d["liefert"]), int(d.get("reichweite", 0))]
	if not d.has("ein"):
		return "→ %s, %s" % [amounts_text(d.get("aus", {})), every]
	return "%s → %s, %s" % [amounts_text(d["ein"]), amounts_text(d.get("aus", {})), every]


static func amounts_text(amounts: Dictionary) -> String:
	var parts: Array = []
	for ware in amounts:
		parts.append("%d %s" % [int(amounts[ware]), ware_name(str(ware))])
	return " + ".join(parts)


## Zahl mit Komma und hoechstens einer Nachkommastelle.
static func _num(value: float) -> String:
	var rounded := roundf(value * 10.0) / 10.0
	if is_equal_approx(rounded, roundf(rounded)):
		return str(int(roundf(rounded)))
	return str(rounded).replace(".", ",")


static func num(value: float) -> String:
	return _num(value)


# ---------------------------------------------------------------- Stand

func _init(saved: Dictionary = {}, store = null) -> void:
	lager = store if store is Dictionary else {}
	state = _normalized(saved) if int(saved.get("version", 0)) == SAVE_VERSION else fresh_state()
	compute_links()


## Neue Platine: Startgebaeude stehen, Startbestand gehoert dem Spieler.
static func fresh_state() -> Dictionary:
	var s := {"version": SAVE_VERSION, "tick": 0, "next_id": 1, "tier": 1, "owned": {},
		"chunks": [], "b": {}}
	for type in defs():
		s["owned"][type] = int(def(type).get("start", 0))
	for pair in data().get("startaufbau", []):
		s["b"][str(pair[0])] = _new_building(str(pair[1]), int(s["next_id"]))
		s["next_id"] = int(s["next_id"]) + 1
	return s


static func _new_building(type: String, id: int) -> Dictionary:
	return {"id": id, "t": type, "in": {}, "out": {}, "prog": 0.0, "run": false, "on": false,
		"charge": 0.0, "rel_on": true, "rr": 0}


## JSON macht aus ganzen Zahlen Kommazahlen -- hier wieder geraderuecken.
static func _normalized(saved: Dictionary) -> Dictionary:
	var s := {"version": SAVE_VERSION, "tick": int(saved.get("tick", 0)),
		"next_id": int(saved.get("next_id", 1)), "tier": int(saved.get("tier", 1)), "owned": {},
		"chunks": [], "b": {}}
	for type in defs():
		s["owned"][type] = int((saved.get("owned", {}) as Dictionary).get(type, def(type).get("start", 0)))
	for id in saved.get("chunks", []):
		s["chunks"].append(str(id))
	var buildings: Dictionary = saved.get("b", {})
	for k in buildings:
		var raw: Dictionary = buildings[k]
		var type := str(raw.get("t", ""))
		if not defs().has(type):
			continue
		var b := _new_building(type, int(raw.get("id", 0)))
		for side in ["in", "out"]:
			var buf: Dictionary = raw.get(side, {})
			for ware in buf:
				b[side][str(ware)] = int(buf[ware])
		b["prog"] = float(raw.get("prog", 0.0))
		b["run"] = bool(raw.get("run", false))
		b["on"] = bool(raw.get("on", false))
		b["charge"] = float(raw.get("charge", 0.0))
		b["rel_on"] = bool(raw.get("rel_on", true))
		b["rr"] = int(raw.get("rr", 0))
		s["b"][str(k)] = b
		s["next_id"] = maxi(int(s["next_id"]), b["id"] + 1)
	return s


func to_dict() -> Dictionary:
	return state.duplicate(true)


func tier() -> int:
	return int(state["tier"])


func tick_count() -> int:
	return int(state["tick"])


func buildings() -> Dictionary:
	return state["b"]


func building_at(k: String) -> Dictionary:
	return (state["b"] as Dictionary).get(k, {})


func info_of(k: String) -> Dictionary:
	var b := building_at(k)
	if b.is_empty():
		return {}
	return _info(int(b["id"]))


func _info(id: int) -> Dictionary:
	if not info.has(id):
		info[id] = {"status": "ok", "miss": "", "need": 0.0, "got": 0.0, "eff": 1.0, "wait": [],
			"in_h": [], "out_h": [], "up_h": []}
	return info[id]


# ---------------------------------------------------------------- Lager

func have(ware: String) -> int:
	return int(lager.get(material_key(ware), 0))


func add_to_lager(ware: String, amount: int) -> void:
	var key := material_key(ware)
	var total := maxi(0, int(lager.get(key, 0)) + amount)
	if total == 0:
		lager.erase(key)
	else:
		lager[key] = total


func can_pay(price: Dictionary) -> bool:
	for ware in price:
		if have(str(ware)) < int(price[ware]):
			return false
	return true


func pay(price: Dictionary) -> bool:
	if not can_pay(price):
		return false
	for ware in price:
		add_to_lager(str(ware), -int(price[ware]))
	return true


# ---------------------------------------------------------------- Platine

static func key(q: int, r: int) -> String:
	return "%d,%d" % [q, r]


static func unkey(k: String) -> Vector2i:
	var parts := k.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))


static func ring(q: int, r: int) -> int:
	return maxi(absi(q), maxi(absi(r), absi(-q - r)))


static func distance(a: String, b: String) -> int:
	var pa := unkey(a)
	var pb := unkey(b)
	return ring(pa.x - pb.x, pa.y - pb.y)


static func neighbors(k: String) -> Array:
	var p := unkey(k)
	var out: Array = []
	for d in DIRS:
		out.append(key(p.x + d.x, p.y + d.y))
	return out


static func cells() -> Array:
	var radius := int(data().get("platine_radius", 3))
	var out: Array = []
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if ring(q, r) <= radius:
				out.append(key(q, r))
	return out


static func net_cell() -> String:
	return str((data().get("netz", {}) as Dictionary).get("feld", "0,0"))


static func source_at(k: String) -> String:
	return str((data().get("quellen", {}) as Dictionary).get(k, ""))


static func source_ware(kind: String) -> String:
	return str(((data().get("quellen_arten", {}) as Dictionary).get(kind, {}) as Dictionary).get("ware", ""))


static func source_name(kind: String) -> String:
	return str(((data().get("quellen_arten", {}) as Dictionary).get(kind, {}) as Dictionary).get("name", kind))


static func chunks() -> Array:
	return data().get("feldgruppen", [])


static func chunk_of(k: String) -> Dictionary:
	for chunk in chunks():
		if k in (chunk["felder"] as Array):
			return chunk
	return {}


func unlocked(k: String) -> bool:
	var p := unkey(k)
	if ring(p.x, p.y) <= int(data().get("start_radius", 2)):
		return true
	var chunk := chunk_of(k)
	return not chunk.is_empty() and str(chunk["id"]) in (state["chunks"] as Array)


func owned(type: String) -> int:
	return int((state["owned"] as Dictionary).get(type, 0))


func placed(type: String) -> int:
	var n := 0
	for k in state["b"]:
		if str(state["b"][k]["t"]) == type:
			n += 1
	return n


## "" = darf, sonst der Grund in Worten.
func can_place(k: String, type: String) -> String:
	if k not in cells():
		return "Außerhalb der Platine."
	if k == net_cell():
		return "Hier sitzt der Netzanschluss."
	if not unlocked(k):
		return "Dieses Feld ist noch gesperrt."
	if (state["b"] as Dictionary).has(k):
		return "Hier steht schon etwas."
	var d := def(type)
	if d.is_empty():
		return "Unbekanntes Gebäude."
	if int(d.get("tier", 1)) > tier():
		return "%s gibt es erst ab Tier %d." % [str(d["name"]), int(d["tier"])]
	if placed(type) >= owned(type):
		return "Alle %s stehen schon. Kauf ein weiteres oder setz eins um." % str(d["name"])
	var src := source_at(k)
	if d.has("quelle") and src != str(d["quelle"]):
		return "%s geht nur auf %s." % [str(d["name"]), source_name(str(d["quelle"]))]
	if not d.has("quelle") and src != "":
		return "Quellen sind für Förderer reserviert."
	return ""


func place(k: String, type: String) -> String:
	var why := can_place(k, type)
	if why != "":
		return why
	state["b"][k] = _new_building(type, int(state["next_id"]))
	state["next_id"] = int(state["next_id"]) + 1
	compute_links()
	return ""


## Abreissen: das Gebaeude geht zurueck in den Besitz, der Pufferinhalt ins Lager.
func remove(k: String) -> bool:
	var b := building_at(k)
	if b.is_empty():
		return false
	for side in ["in", "out"]:
		for ware in b[side]:
			if int(b[side][ware]) > 0:
				add_to_lager(str(ware), int(b[side][ware]))
	info.erase(int(b["id"]))
	(state["b"] as Dictionary).erase(k)
	compute_links()
	return true


func buy_building(type: String) -> String:
	var d := def(type)
	if d.is_empty():
		return "Unbekanntes Gebäude."
	if int(d.get("tier", 1)) > tier():
		return "Erst ab Tier %d." % int(d["tier"])
	if not pay(d.get("preis", {})):
		return "Nicht genug im Lager."
	state["owned"][type] = owned(type) + 1
	return ""


func buy_chunk(id: String) -> String:
	for chunk in chunks():
		if str(chunk["id"]) != id:
			continue
		if id in (state["chunks"] as Array):
			return "Schon gekauft."
		if int(chunk.get("tier", 1)) > tier():
			return "Erst ab Tier %d." % int(chunk["tier"])
		if not pay(chunk.get("preis", {})):
			return "Nicht genug im Lager."
		state["chunks"].append(id)
		return ""
	return "Unbekannte Feldgruppe."


## Das naechste Tier-Ziel ({} = keins mehr).
func next_tier_goal() -> Dictionary:
	for goal in data().get("tiers", []):
		if int(goal["tier"]) == tier() + 1:
			return goal
	return {}


func unlock_tier() -> String:
	var goal := next_tier_goal()
	if goal.is_empty():
		return "Alle Tiers frei."
	if str(goal.get("weg", "fabrik")) != "fabrik":
		return "Schaltet der Story-Fortschritt frei."
	if not pay(goal.get("kosten", {})):
		return "Nicht genug im Lager."
	state["tier"] = int(goal["tier"])
	return ""


## Etwas aus dem Lager herstellen, das nicht in der Fabrik entsteht (z. B. der
## Charger-Rohling). "" = geklappt.
func craft(ware: String) -> String:
	var recipe: Dictionary = (data().get("herstellen", {}) as Dictionary).get(ware, {})
	if recipe.is_empty():
		return "Kein Rezept."
	if not pay(recipe.get("kosten", {})):
		return "Nicht genug im Lager."
	add_to_lager(ware, 1)
	return ""


static func craft_cost(ware: String) -> Dictionary:
	return ((data().get("herstellen", {}) as Dictionary).get(ware, {}) as Dictionary).get("kosten", {})


func resonance(k: String) -> float:
	var b := building_at(k)
	if b.is_empty():
		return 0.0
	var d := def(str(b["t"]))
	if not d.has("ein") or d.has("brennstoff"):
		return 0.0
	var n := 0
	for nk in neighbors(k):
		var other := building_at(nk)
		if not other.is_empty() and other["t"] == b["t"]:
			n += 1
	return mini(int(setting("resonanz_max_nachbarn", 2)), n) * float(setting("resonanz_je_nachbar", 0.25))


func shaded(k: String) -> bool:
	for nk in neighbors(k):
		var other := building_at(nk)
		if not other.is_empty() and other["t"] == "sol":
			return true
	return false


## Reichweite der Stromquelle auf dem Feld (-1 = keine Quelle).
func range_of(k: String) -> int:
	if k == net_cell():
		return int((data().get("netz", {}) as Dictionary).get("reichweite", 2))
	var b := building_at(k)
	if b.is_empty():
		return -1
	return int(def(str(b["t"])).get("reichweite", -1))


# ---------------------------------------------------------------- Verbindungen

func compute_links() -> void:
	links = {}
	var all: Dictionary = state["b"]
	for k in all:
		if def(str(all[k]["t"])).get("relais", false):
			continue
		var found: Array = []
		var seen := {k: true}
		var queue: Array = [{"k": k, "path": [k]}]
		while not queue.is_empty():
			var cur: Dictionary = queue.pop_front()
			for nk in neighbors(cur["k"]):
				if seen.has(nk) or not all.has(nk):
					continue
				seen[nk] = true
				var path: Array = (cur["path"] as Array).duplicate()
				path.append(nk)
				if def(str(all[nk]["t"])).get("relais", false):
					if bool(all[nk]["rel_on"]):
						queue.append({"k": nk, "path": path})
				else:
					found.append({"k": nk, "path": path})
		links[k] = found


## Verbindungen zwischen Erzeuger und Verbraucher: [{path, ware}] (fuer die Anzeige).
func traces() -> Array:
	var out: Array = []
	for k in links:
		var outs: Dictionary = def(str(building_at(k)["t"])).get("aus", {})
		for l in links[k]:
			var ins: Dictionary = def(str(building_at(l["k"])["t"])).get("ein", {})
			for ware in outs:
				if ins.has(ware):
					out.append({"path": l["path"], "ware": str(ware)})
					break
	return out


func has_consumer(k: String, ware: String) -> bool:
	for l in links.get(k, []):
		if (def(str(building_at(l["k"])["t"])).get("ein", {}) as Dictionary).has(ware):
			return true
	return false


func _sorted() -> Array:
	var list: Array = []
	for k in state["b"]:
		var b: Dictionary = state["b"][k]
		list.append({"k": k, "b": b, "d": def(str(b["t"]))})
	list.sort_custom(func(x, y): return int(x["b"]["id"]) < int(y["b"]["id"]))
	return list


# ---------------------------------------------------------------- Takt

## Ein Takt. Gibt zurueck, was ins Lager ging: {ware: menge}.
func tick() -> Dictionary:
	state["tick"] = tick_count() + 1
	compute_links()
	var list := _sorted()
	var gain := {}
	var recv := {}
	for x in list:
		recv[x["k"]] = {}
	var anlauf := int(setting("anlauf", 3))
	var in_factor := int(setting("eingang_mal_rezept", 10))
	var out_cap := int(setting("ausgang", 10))

	# 1. Abholen: reihum, jeder Verbraucher bekommt abwechselnd ein Stueck.
	var consumers: Array = list.filter(func(x): return x["d"].has("ein"))
	var wanted: Array = []
	for x in consumers:
		for ware in x["d"]["ein"]:
			if ware not in wanted:
				wanted.append(ware)
	for ware in wanted:
		var cs: Array = consumers.filter(func(x): return (x["d"]["ein"] as Dictionary).has(ware))
		if cs.is_empty():
			continue
		var offset := tick_count() % cs.size()
		var moved := true
		var guard := 0
		while moved and guard < 60:
			guard += 1
			moved = false
			for j in cs.size():
				var x: Dictionary = cs[(j + offset) % cs.size()]
				var b: Dictionary = x["b"]
				var cap := int(x["d"]["ein"][ware]) * in_factor
				if int(b["in"].get(ware, 0)) >= cap:
					continue
				var sup: Array = (links.get(x["k"], []) as Array).filter(func(l):
					return int(building_at(l["k"])["out"].get(ware, 0)) > 0)
				if sup.is_empty():
					continue
				var l: Dictionary = sup[int(b["rr"]) % sup.size()]
				b["rr"] = int(b["rr"]) + 1
				var giver := building_at(l["k"])
				giver["out"][ware] = int(giver["out"][ware]) - 1
				b["in"][ware] = int(b["in"].get(ware, 0)) + 1
				recv[x["k"]][ware] = int(recv[x["k"]].get(ware, 0)) + 1
				moved = true

	# 2. Strom: Quellen und Bedarf.
	var netz: Dictionary = data().get("netz", {})
	var sources: Array = [{"k": net_cell(), "left": float(netz.get("strom", 4)),
		"range": int(netz.get("reichweite", 2)), "bat": false, "id": 0, "x": {}, "fuel": false}]
	var ignite := int(setting("zuenden_bei", 5))
	for x in list:
		var d: Dictionary = x["d"]
		var b: Dictionary = x["b"]
		if d.get("batterie", false):
			sources.append({"k": x["k"], "left": minf(float(d["liefert"]), float(b["charge"])),
				"range": int(d["reichweite"]), "bat": true, "id": b["id"], "x": x, "fuel": false})
		elif d.has("brennstoff"):
			var f := int(b["in"].get(d["brennstoff"], 0))
			if not b["on"] and f >= ignite:
				b["on"] = true
			if b["on"] and f < 1:
				b["on"] = false
			if b["on"]:
				sources.append({"k": x["k"], "left": float(d["liefert"]), "range": int(d["reichweite"]),
					"bat": false, "id": b["id"], "x": x, "fuel": true})
		elif d.has("liefert"):
			var factor := float(setting("schatten_faktor", 0.5)) if shaded(x["k"]) else 1.0
			sources.append({"k": x["k"], "left": float(d["liefert"]) * factor,
				"range": int(d["reichweite"]), "bat": false, "id": b["id"], "x": x, "fuel": false})
	for s in sources:
		s["cap"] = s["left"]
		s["used"] = 0.0
	var demand := 0.0
	for x in list:
		var d: Dictionary = x["d"]
		var b: Dictionary = x["b"]
		var need := 0.0
		if d.get("relais", false):
			need = float(d.get("strom", 1))
		elif d.has("ein") and not d.has("brennstoff"):
			if not b["run"] and _stock_at_least(b, d, anlauf):
				b["run"] = true
			if b["run"] and _stock_at_least(b, d, 1) and float(d.get("strom", 0)) > 0.0:
				need = float(d["strom"])
		elif d.has("quelle") and float(d.get("strom", 0)) > 0.0:
			need = float(d["strom"])
		var inf := _info(int(b["id"]))
		inf["need"] = need
		inf["got"] = 0.0
		demand += need
	var pairs: Array = []
	for x in list:
		if float(_info(int(x["b"]["id"]))["need"]) <= 0.0:
			continue
		for s in sources:
			var dist := distance(s["k"], x["k"])
			if dist <= int(s["range"]):
				pairs.append({"s": s, "x": x, "dist": dist})
	pairs.sort_custom(func(p1, p2):
		if p1["s"]["bat"] != p2["s"]["bat"]:
			return not p1["s"]["bat"]
		if p1["dist"] != p2["dist"]:
			return p1["dist"] < p2["dist"]
		if int(p1["s"]["id"]) != int(p2["s"]["id"]):
			return int(p1["s"]["id"]) < int(p2["s"]["id"])
		return int(p1["x"]["b"]["id"]) < int(p2["x"]["b"]["id"]))
	for p in pairs:
		var inf := _info(int(p["x"]["b"]["id"]))
		var want := float(inf["need"]) - float(inf["got"])
		if want <= 0.0 or float(p["s"]["left"]) <= 0.0:
			continue
		var g := minf(want, float(p["s"]["left"]))
		p["s"]["left"] = float(p["s"]["left"]) - g
		p["s"]["used"] = float(p["s"]["used"]) + g
		inf["got"] = float(inf["got"]) + g
	# Batterien: erst abziehen, was sie abgegeben haben, dann mit Ueberschuss laden.
	for s in sources:
		if s["bat"]:
			s["x"]["b"]["charge"] = float(s["x"]["b"]["charge"]) - float(s["used"])
	for x in list:
		var d: Dictionary = x["d"]
		if not d.get("batterie", false):
			continue
		var room := float(d.get("speicher", 20)) - float(x["b"]["charge"])
		var rate := float(setting("batterie_laden_je_takt", 2))
		for s in sources:
			if s["bat"] or float(s["left"]) <= 0.0 or room <= 0.0 or rate <= 0.0:
				continue
			if distance(s["k"], x["k"]) > int(s["range"]):
				continue
			var c := minf(room, minf(rate, float(s["left"])))
			s["left"] = float(s["left"]) - c
			s["used"] = float(s["used"]) + c
			room -= c
			rate -= c
			x["b"]["charge"] = float(x["b"]["charge"]) + c
	# Brennstoff nur verbrennen, wenn Strom gebraucht wurde.
	for s in sources:
		if s["fuel"] and float(s["used"]) > 0.0:
			var fb: Dictionary = s["x"]["b"]
			var fuel := str(s["x"]["d"]["brennstoff"])
			fb["in"][fuel] = int(fb["in"].get(fuel, 0)) - 1
	source_info = {}
	var supply := 0.0
	var used := 0.0
	for s in sources:
		source_info[s["k"]] = {"cap": float(s["cap"]), "used": float(s["used"])}
		if not s["bat"]:
			supply += float(s["cap"])
		used += float(s["used"])
	var batt := 0.0
	var batt_max := 0.0
	for x in list:
		var inf := _info(int(x["b"]["id"]))
		inf["eff"] = float(inf["got"]) / float(inf["need"]) if float(inf["need"]) > 0.0 else 1.0
		if x["d"].get("relais", false):
			x["b"]["rel_on"] = float(inf["got"]) >= float(x["d"].get("strom", 1))
		if x["d"].get("batterie", false):
			batt += float(x["b"]["charge"])
			batt_max += float(x["d"].get("speicher", 20))
	power = {"supply": supply, "demand": demand, "used": used, "batt": batt, "batt_max": batt_max}

	# 3. Herstellen.
	var made_by := {}
	for x in list:
		var b: Dictionary = x["b"]
		var d: Dictionary = x["d"]
		var inf := _info(int(b["id"]))
		var made := 0
		inf["status"] = "ok"
		inf["miss"] = ""
		if d.get("relais", false):
			inf["status"] = "relay" if b["rel_on"] else "strom"
		elif d.has("brennstoff"):
			inf["status"] = "ok" if b["on"] else "wait"
			inf["miss"] = "" if b["on"] else str(d["brennstoff"])
		elif d.has("liefert"):
			inf["status"] = "ok"
		elif not d.has("ein"):
			var eff := float(inf["eff"]) if float(d.get("strom", 0)) > 0.0 else 1.0
			b["prog"] = float(b["prog"]) + float(d.get("rate", 1)) * eff
			while float(b["prog"]) >= 1.0:
				for ware in d.get("aus", {}):
					b["out"][ware] = int(b["out"].get(ware, 0)) + int(d["aus"][ware])
				b["prog"] = float(b["prog"]) - 1.0
				made += 1
			if eff < 1.0:
				inf["status"] = "strom"
		else:
			var missing := _missing(b, d, 1)
			if not b["run"]:
				inf["miss"] = _missing(b, d, anlauf)
				var any := false
				for ware in d["ein"]:
					if int(b["in"].get(ware, 0)) > 0:
						any = true
				inf["status"] = "anlauf" if any else "wait"
			elif missing != "":
				inf["status"] = "wait"
				inf["miss"] = missing
				b["run"] = false
			else:
				var eff := float(inf["eff"]) if float(d.get("strom", 0)) > 0.0 else 1.0
				b["prog"] = float(b["prog"]) + float(d.get("rate", 1)) * eff * (1.0 + resonance(x["k"]))
				while float(b["prog"]) >= 1.0 and _missing(b, d, 1) == "":
					for ware in d["ein"]:
						b["in"][ware] = int(b["in"][ware]) - int(d["ein"][ware])
					for ware in d.get("aus", {}):
						b["out"][ware] = int(b["out"].get(ware, 0)) + int(d["aus"][ware])
					b["prog"] = float(b["prog"]) - 1.0
					made += 1
				if float(b["prog"]) >= 1.0:
					b["prog"] = 0.999
				if eff < 1.0:
					inf["status"] = "strom"
		made_by[x["k"]] = made
		_push(inf["wait"], 1 if inf["status"] in ["wait", "anlauf"] else 0, 10)
		_push(inf["in_h"], recv[x["k"]], HISTORY)
		_push(inf["out_h"], made, HISTORY)

	# 4. Uplink: was keiner braucht oder ueber den Ausgangspuffer geht.
	for x in list:
		var b: Dictionary = x["b"]
		var inf := _info(int(b["id"]))
		var up := {}
		var overflow := false
		for ware in b["out"].keys():
			var n := int(b["out"][ware])
			if n <= 0:
				continue
			if not has_consumer(x["k"], ware):
				up[ware] = n
				b["out"][ware] = 0
			elif n > out_cap:
				up[ware] = n - out_cap
				b["out"][ware] = out_cap
				overflow = true
		for ware in up:
			add_to_lager(str(ware), int(up[ware]))
			gain[ware] = int(gain.get(ware, 0)) + int(up[ware])
		if overflow and inf["status"] == "ok":
			inf["status"] = "uplink"
		_push(inf["up_h"], up, HISTORY)
	_push(gain_history, gain, HISTORY)

	# Engpass: der Verarbeiter, der in den letzten 10 Takten am meisten wartete.
	engpass = ""
	var worst := 5
	for x in list:
		if not x["d"].has("ein") or x["d"].has("brennstoff"):
			continue
		var w := 0
		for v in _info(int(x["b"]["id"]))["wait"]:
			w += int(v)
		if w > worst:
			worst = w
			engpass = x["k"]
	return gain


## Viele Takte ohne Anzeige (nach einem Kampf). Gibt die Summe fuers Lager zurueck.
func run(ticks: int) -> Dictionary:
	var total := {}
	for i in ticks:
		var gain := tick()
		for ware in gain:
			total[ware] = int(total.get(ware, 0)) + int(gain[ware])
	return total


func _stock_at_least(b: Dictionary, d: Dictionary, times: int) -> bool:
	return _missing(b, d, times) == ""


## Die erste Zutat, von der weniger als ``times`` Durchlaeufe im Eingang liegen.
func _missing(b: Dictionary, d: Dictionary, times: int) -> String:
	for ware in d.get("ein", {}):
		if int(b["in"].get(ware, 0)) < int(d["ein"][ware]) * times:
			return str(ware)
	return ""


static func _push(list: Array, value, limit: int) -> void:
	list.append(value)
	while list.size() > limit:
		list.pop_front()


# ---------------------------------------------------------------- Anzeige-Hilfen

## Mittel der letzten Takte: wie viel von ``ware`` je Takt ankam.
func avg_in(k: String, ware: String) -> float:
	var hist: Array = info_of(k).get("in_h", [])
	if hist.is_empty():
		return 0.0
	var sum := 0.0
	for h in hist:
		sum += float(h.get(ware, 0))
	return sum / hist.size()


func avg_out(k: String) -> float:
	var hist: Array = info_of(k).get("out_h", [])
	if hist.is_empty():
		return 0.0
	var sum := 0.0
	for v in hist:
		sum += float(v)
	return sum / hist.size()


## Was das Gebaeude im Mittel je Takt per Uplink ins Lager schickt.
func avg_up(k: String) -> Dictionary:
	var hist: Array = info_of(k).get("up_h", [])
	var out := {}
	if hist.is_empty():
		return out
	for h in hist:
		for ware in h:
			out[ware] = float(out.get(ware, 0.0)) + float(h[ware])
	for ware in out:
		out[ware] = float(out[ware]) / hist.size()
	return out


## Hochrechnung fuers Lager je Ware: Mittel der letzten Takte mal ``ticks``.
func projection(ticks: int) -> Dictionary:
	var out := {}
	if gain_history.is_empty():
		return out
	for g in gain_history:
		for ware in g:
			out[ware] = float(out.get(ware, 0.0)) + float(g[ware])
	for ware in out:
		out[ware] = int(roundf(float(out[ware]) / gain_history.size() * ticks))
	return out


## Zustand in Worten fuer ein Gebaeude.
func status_text(k: String) -> String:
	var b := building_at(k)
	if b.is_empty():
		return ""
	var d := def(str(b["t"]))
	var inf := info_of(k)
	var anlauf := int(setting("anlauf", 3))
	match str(inf.get("status", "ok")):
		"anlauf":
			var parts: Array = []
			for ware in d.get("ein", {}):
				parts.append("%s %d/%d" % [ware_name(str(ware)), int(b["in"].get(ware, 0)),
					int(d["ein"][ware]) * anlauf])
			return "Läuft an: sammelt Vorrat für %d Durchläufe (%s)" % [anlauf, " · ".join(parts)]
		"wait":
			var miss := str(inf.get("miss", ""))
			# Playtest v2: eine Zutat ist voll, die andere fehlt -- dann holt das
			# Gebaeude nichts mehr, der Lieferant staut und schickt ins Lager.
			for ware in d.get("ein", {}):
				if str(ware) != miss and int(b["in"].get(ware, 0)) \
						>= int(d["ein"][ware]) * int(setting("eingang_mal_rezept", 10)):
					return "Eingang %s voll -- wartet auf %s" % [ware_name(str(ware)), ware_name(miss)]
			return "Wartet auf %s" % ware_name(miss) if miss != "" else "Wartet"
		"strom":
			if d.get("relais", false):
				return "Kein Strom -- leitet nichts"
			return "Zu wenig Strom: %s von %s → %d %% Tempo" % [num(float(inf["got"])),
				num(float(inf["need"])), int(roundf(float(inf["eff"]) * 100.0))]
		"uplink":
			return "Ausgang voll: Überschuss geht per Uplink ins Lager"
		"relay":
			return "Leitet weiter"
	return "Läuft"
