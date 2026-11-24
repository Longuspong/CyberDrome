extends RefCounted

## Werkbank (24. Nov. 2026, docs/FACTORY_KONZEPT.md Abschnitt 13).

var t


func _roster() -> Roster:
	var roster := Roster.new()
	roster.seed_starter()
	return roster


## Legt alle Zutaten fuer die Teile eines Chassis ins Lager.
func _stock_parts_for(roster: Roster, chassis: String) -> void:
	for part in Workbench.parts_of(chassis):
		var cost: Dictionary = part["kosten"]
		for ware in cost:
			var key := FactorySim.material_key(str(ware))
			roster.materials[key] = int(roster.materials.get(key, 0)) + int(cost[ware]) * int(part.get("anzahl", 1))


func test_start_blueprints() -> void:
	var bench := Workbench.new(_roster())
	var ids := bench.products("dromes")
	for chassis in ["scout_body", "jugg_body", "mage_body", "strix_body"]:
		t.ok("drome:" + chassis in ids, "Bauplan von Anfang an: " + chassis)
		t.equal(Workbench.parts_of(chassis).size(), 5, "fünf Teile: " + chassis)
	t.equal(bench.products("charger"), ["rohling"], "Charger-Kategorie: Rohling")
	t.equal(int(bench.needs("drome:jugg_body")["teil:jugg_body:halter"]), 2, "Molok: zwei Waffenhalter")


func test_part_then_drome() -> void:
	var roster := _roster()
	var bench := Workbench.new(roster)
	var before := roster.entries.size()
	t.ok(not bench.can_craft("drome:scout_body"), "ohne Teile kein Vireo")
	t.ok(not bench.can_craft("teil:scout_body:kopf"), "ohne Ressourcen kein Kopf")
	_stock_parts_for(roster, "scout_body")
	for part in Workbench.parts_of("scout_body"):
		var key := Workbench.part_key("scout_body", str(part["id"]))
		t.ok(bool(bench.craft(key)["ok"]), "Teil hergestellt: " + str(part["name"]))
	t.ok(roster.materials.keys().all(func(k): return not str(k).begins_with("res:")), "Ressourcen verbraucht")
	var result := bench.craft("drome:scout_body")
	t.ok(bool(result["ok"]) and result["entry"] != null, "Vireo aus Teilen gebaut")
	t.equal(roster.entries.size(), before + 1, "neuer DROME im Hangar")
	t.ok(roster.materials.keys().all(func(k): return not str(k).begins_with("teil:")), "Teile verbraucht")


func test_special_part_replaces_core_part() -> void:
	var roster := _roster()
	var bench := Workbench.new(roster)
	var variant := "neon_vireo"
	var chassis := "scout_body"
	t.ok(not bench.known("faction:" + variant), "ohne Neon-Kern kein Bauplan")
	roster.add_faction_core("neon")
	t.ok(bench.known("faction:" + variant), "mit Neon-Kern bekannt")
	var need := bench.needs("faction:" + variant)
	t.ok(not need.has(Workbench.part_key(chassis, "kern")), "kein Kern-Teil")
	t.equal(int(need.get("spezial:" + variant, 0)), 1, "dafür das Spezialteil")
	t.equal(Workbench.key_name("spezial:" + variant), "Neon-Booster", "heißt Neon-Booster")
	var special := bench.needs("spezial:" + variant)
	t.equal(int(special.get("kern:neon", 0)), 1, "Spezialteil braucht den Neon-Kern")
	t.equal(int(special.get("res:chip", 0)), 15, "und die Zutaten des Kern-Teils")
	_stock_parts_for(roster, chassis)
	t.ok(bool(bench.craft("spezial:" + variant)["ok"]), "Neon-Booster hergestellt")
	t.equal(roster.faction_cores("neon"), 0, "Neon-Kern verbraucht")
	t.ok(bench.known("faction:" + variant), "Bauplan bleibt über das Spezialteil bekannt")
	for part in Workbench.parts_of(chassis):
		if str(part["id"]) != "kern":
			bench.craft(Workbench.part_key(chassis, str(part["id"])))
	var result := bench.craft("faction:" + variant)
	t.ok(bool(result["ok"]), "Neon Vireo gebaut")
	t.equal(result["entry"].variant, variant, "mit Variante")


func test_salvage_yield() -> void:
	var molok := Workbench.salvage_yield("jugg_body")
	t.equal(molok["wares"], {"platte": 48, "legierung": 150}, "Molok: Brustharnisch + Unterbau")
	var neon := Workbench.salvage_yield("scout_body", "neon_vireo")
	t.equal(str(neon["special"]), "neon_vireo", "Fraktions-DROME: Spezialteil zurück")


func test_shortfall_and_battles() -> void:
	var roster := _roster()
	var bench := Workbench.new(roster)
	var short := bench.raw_shortfall("drome:scout_body")
	t.equal(int(short.get("chip", 0)), 33, "Vireo braucht 33 Chips")
	t.equal(int(short.get("platte", 0)), 42, "und 42 Platten")
	roster.materials["res:platte"] = 40
	t.equal(int(bench.raw_shortfall("drome:scout_body").get("platte", 0)), 2, "Lager zählt mit")
	t.equal(Workbench.battles_for({"platte": 20}, {"platte": 0.5}), 2, "20 Platten bei 10 je Kampf: 2 Kämpfe")
	t.equal(Workbench.battles_for({"chip": 1}, {}), -1, "nicht herstellbar: -1")


func test_rohling_from_bench() -> void:
	var roster := _roster()
	var bench := Workbench.new(roster)
	roster.materials["res:legierung"] = 2
	roster.materials["res:plasma"] = 1
	var blanks := roster.blanks()
	t.ok(bool(bench.craft("rohling")["ok"]), "Rohling hergestellt")
	t.equal(roster.blanks(), blanks + 1, "als Charger-Rohling im Lager")


func test_goal_saved_and_estimate_is_dry() -> void:
	var roster := _roster()
	var sim := roster.factory_sim()
	sim.set_goal("drome:jugg_body")
	var ticks := sim.tick_count()
	var per: Dictionary = sim.estimate_per_tick()
	t.ok(float(per.get("legierung", 0.0)) > 0.0, "Schätzung: Legierung je Takt")
	t.equal(sim.tick_count(), ticks, "Schätzung lässt die Platine unberührt")
	t.ok(roster.materials.keys().all(func(k): return not str(k).begins_with("res:")), "und das Lager")
	var copy := Roster.new()
	copy.load_dict(JSON.parse_string(JSON.stringify(roster.to_dict())))
	t.equal(copy.factory_sim().goal(), "drome:jugg_body", "Ziel im Spielstand")
