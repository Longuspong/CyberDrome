extends RefCounted

## Fabrik-Logik (23. Nov. 2026, docs/FACTORY_KONZEPT.md Abschnitt 11).

var t


func _sim(lager: Dictionary = {}) -> FactorySim:
	return FactorySim.new({}, lager)


## Eine leere Platine (ohne Startaufbau) mit genug Besitz fuer Tests.
func _empty(lager: Dictionary = {}) -> FactorySim:
	var sim := _sim(lager)
	for k in sim.buildings().keys():
		sim.remove(k)
	lager.clear()
	for type in FactorySim.defs():
		sim.state["owned"][type] = 10
	return sim


func test_fresh_board() -> void:
	var sim := _sim()
	t.equal(sim.buildings().size(), 4, "Startaufbau: vier Gebäude")
	t.equal(sim.tier(), 1, "Start in Tier 1")
	t.equal(sim.owned("sam"), 2, "zwei Sammler im Besitz")
	t.ok(not FactorySim.defs().has("rpr"), "keine Rohlingpresse")
	t.equal(FactorySim.cells().size(), 37, "Platine Radius 3")
	t.ok(sim.unlocked("1,1") and not sim.unlocked("3,0"), "Ring 3 erst nach Kauf")


func test_neighbor_delivery_and_uplink() -> void:
	var lager := {}
	var sim := _sim(lager)
	sim.run(40)
	t.ok(int(lager.get("res:legierung", 0)) > 0, "Schmelze macht Legierung aus Schrott vom Nachbarn")
	t.ok(int(lager.get("res:schlacke", 0)) > 0, "Schlacke ohne Abnehmer geht per Uplink ins Lager")
	t.ok(int(lager.get("res:plasma", 0)) > 0, "Plasmakammer bekommt Neon vom Zapfer")
	t.equal(int(lager.get("res:schrott", 0)), 0, "Schrott hat einen Abnehmer: nichts ins Lager")


func test_startup_needs_three_runs() -> void:
	var lager := {}
	var sim := _sim(lager)
	sim.run(5)
	t.equal(str(sim.info_of("1,0")["status"]), "anlauf", "Schmelze sammelt erst Vorrat")
	t.equal(int(lager.get("res:legierung", 0)), 0, "vor dem Anlauf keine Legierung")
	sim.run(10)
	t.ok(int(lager.get("res:legierung", 0)) > 0, "nach dem Anlauf läuft sie")


func test_relay_without_power_links_nothing() -> void:
	var lager := {"res:legierung": 40, "res:plasma": 10}
	var sim := _empty(lager)
	lager["res:legierung"] = 40
	lager["res:plasma"] = 10
	t.equal(sim.buy_chunk("osten"), "", "Feldgruppe Osten gekauft")
	t.equal(int(lager.get("res:legierung", 0)), 0, "Preis bezahlt")
	t.equal(sim.place("3,-3", "sam"), "", "Sammler auf Schrottquelle")
	t.equal(sim.place("3,-2", "rel"), "", "Relais außer Reichweite des Netzes")
	t.equal(sim.place("2,-1", "smz"), "", "Schmelze am Relais")
	sim.run(10)
	t.equal(int(sim.building_at("2,-1")["in"].get("schrott", 0)), 0, "ohne Strom leitet das Relais nichts")
	t.ok(int(lager.get("res:schrott", 0)) > 0, "der Schrott geht ins Lager")
	t.equal(sim.place("2,-2", "sol"), "", "Solarpanel neben dem Relais")
	sim.run(10)
	t.ok(int(sim.building_at("2,-1")["in"].get("schrott", 0)) > 0, "mit Strom kommt der Schrott an")


func test_power_by_distance() -> void:
	var sim := _empty()
	# Netz: 4 Strom, Reichweite 2. Fuenf Relais wollen je 1.
	for k in ["1,0", "-1,0", "0,1", "2,0", "-2,0"]:
		if FactorySim.source_at(k) != "":
			continue
		t.equal(sim.place(k, "rel"), "", "Relais auf " + k)
	for k in ["2,-2", "-2,2"]:
		t.equal(sim.place(k, "rel"), "", "Relais auf " + k)
	sim.tick()
	for k in ["1,0", "-1,0", "0,1"]:
		t.equal(float(sim.info_of(k)["got"]), 1.0, "nah am Netz voll versorgt: " + k)
	t.equal(float(sim.info_of("2,-2")["got"]), 1.0, "Abstand 2, früher gebaut: bekommt den Rest")
	t.equal(float(sim.info_of("-2,2")["got"]), 0.0, "Abstand 2, später gebaut: leer")
	t.equal(float(sim.power["demand"]), 5.0, "Bedarf 5")


func test_solar_shadow() -> void:
	var sim := _empty()
	t.equal(sim.place("1,1", "sol"), "", "Panel 1")
	t.equal(sim.place("-1,1", "sol"), "", "Panel 2 nicht daneben")
	sim.tick()
	t.equal(float(sim.source_info["1,1"]["cap"]), 1.0, "ohne Nachbar-Panel 1 Strom")
	sim.remove("-1,1")
	t.equal(sim.place("1,0", "sol"), "", "Panel direkt daneben")
	sim.tick()
	t.equal(float(sim.source_info["1,1"]["cap"]), 0.5, "Schatten: nur 0,5")


func test_buy_and_move() -> void:
	var lager := {}
	var sim := _sim(lager)
	t.ok(sim.buy_building("sam") != "", "ohne Legierung kein Kauf")
	lager["res:legierung"] = 8
	t.equal(sim.buy_building("sam"), "", "Sammler gekauft")
	t.equal(sim.owned("sam"), 3, "jetzt drei im Besitz")
	t.ok(sim.can_place("0,2", "sam") != "", "Sammler nicht auf Datenknoten")
	t.ok(sim.can_place("1,1", "smz") != "", "alle Schmelzen stehen schon")
	sim.run(12)
	var before := int(lager.get("res:schrott", 0))
	var buffered := int(sim.building_at("1,0")["in"].get("schrott", 0))
	t.ok(sim.remove("1,0"), "Schmelze abgerissen")
	t.equal(int(lager.get("res:schrott", 0)), before + buffered, "Pufferinhalt ins Lager")
	t.equal(sim.place("1,1", "smz"), "", "und woanders wieder aufgebaut")
	t.ok(sim.buy_building("gen") != "", "Generator erst ab Tier 2")


## Verschieben, Tauschen, Vorschau und Kauf mit Setzen (27. Nov. 2026).
func test_move_swap_preview() -> void:
	var lager := {}
	var sim := _empty(lager)
	t.equal(sim.place("1,-1", "sam"), "", "Sammler auf Schrott")
	t.equal(sim.place("1,0", "smz"), "", "Schmelze daneben")
	t.equal(sim.place("0,1", "rel"), "", "Relais")
	t.equal(sim.place("-1,1", "lot"), "", "Löter")
	var buffer := {"schrott": 4}
	sim.building_at("1,0")["in"] = buffer
	t.equal(sim.move("1,0", "1,1"), "", "Schmelze verschoben")
	t.ok(sim.building_at("1,0").is_empty() and str(sim.building_at("1,1")["t"]) == "smz", "jetzt auf 1,1")
	t.equal(int(sim.building_at("1,1")["in"].get("schrott", 0)), 4, "Puffer zieht mit")
	t.equal(sim.move("0,1", "-1,1"), "", "Relais und Löter getauscht")
	t.equal(str(sim.building_at("0,1")["t"]), "lot", "Löter jetzt auf 0,1")
	t.ok(sim.move("1,-1", "1,1") != "", "Sammler nicht mit Schmelze tauschen")
	t.ok(sim.move("1,1", "0,0") != "", "nicht auf die Basis")
	var traces := sim.preview_traces("1,0", "smz")
	t.ok(not traces.is_empty(), "Vorschau: Schmelze neben Sammler bekommt Schrott")
	t.ok(sim.building_at("1,0").is_empty(), "Vorschau setzt nichts")
	sim.state["owned"]["rec"] = 0
	t.ok(sim.buy_and_place("1,0", "rec") != "", "ohne Legierung kein Kauf")
	t.equal(sim.missing({"legierung": 12}), {"legierung": 12}, "fehlt 12 Legierung")
	lager["res:legierung"] = 12
	t.equal(sim.buy_and_place("1,0", "rec"), "", "gekauft und gesetzt")
	t.equal(str(sim.building_at("1,0")["t"]), "rec", "Recycler steht")


func test_tier_goal_only_factory_wares() -> void:
	var goal: Dictionary = _sim().next_tier_goal()
	for ware in goal.get("kosten", {}):
		t.ok(not bool((FactorySim.wares()[ware] as Dictionary).get("nur_lager", false)),
			"Tier-2-Ziel nur aus Fabrikwaren: " + str(ware))
	var lager := {"res:legierung": 109, "res:plasma": 100, "res:schaltkreis": 35}
	var sim := _sim(lager)
	t.ok(sim.unlock_tier() != "", "eine Legierung zu wenig: kein Tier 2")
	lager["res:legierung"] = 110
	t.equal(sim.unlock_tier(), "", "Tier 2 frei")
	t.equal(sim.tier(), 2, "jetzt Tier 2")
	t.ok(lager.is_empty(), "Kosten verbraucht")
	t.ok(sim.unlock_tier() != "", "Tier 3 nur über die Story")


func test_ticks_per_battle() -> void:
	t.equal(FactorySim.ticks_per_battle(), 20, "20 Takte je Kampf (160 je Einsatz)")


func test_craft_blank_from_lager() -> void:
	var lager := {"res:legierung": 2, "res:plasma": 1}
	var sim := _sim(lager)
	t.equal(sim.craft("rohling"), "", "Rohling aus Lager-Ressourcen")
	t.equal(int(lager.get("rohling", 0)), 1, "liegt als Charger-Rohling im Lager")
	t.ok(sim.craft("rohling") != "", "danach reicht es nicht mehr")


func test_run_800_is_deterministic() -> void:
	var a_lager := {}
	var b_lager := {}
	var a := _sim(a_lager)
	var b := _sim(b_lager)
	var gain := a.run(800)
	b.run(800)
	t.equal(JSON.stringify(a_lager), JSON.stringify(b_lager), "gleiches Lager")
	t.equal(JSON.stringify(a.to_dict()), JSON.stringify(b.to_dict()), "gleicher Stand")
	t.equal(int(gain.get("legierung", 0)), int(a_lager.get("res:legierung", 0)), "Ertrag = Lagerzuwachs")


func test_save_roundtrip_continues_identically() -> void:
	var a_lager := {}
	var a := _sim(a_lager)
	a.run(37)
	var saved = JSON.parse_string(JSON.stringify(a.to_dict()))
	var b_lager := a_lager.duplicate()
	var b := FactorySim.new(saved, b_lager)
	a.run(100)
	b.run(100)
	t.equal(JSON.stringify(a_lager), JSON.stringify(b_lager), "nach Laden läuft es gleich weiter")


func test_roster_keeps_factory() -> void:
	var roster := Roster.new()
	roster.seed_starter()
	var gain := roster.run_factory(100)
	t.ok(int(gain.get("legierung", 0)) > 0, "100 Takte bringen Legierung")
	t.equal(int(roster.materials.get("res:legierung", 0)), int(gain["legierung"]), "im Inventar")
	var copy := Roster.new()
	copy.load_dict(JSON.parse_string(JSON.stringify(roster.to_dict())))
	t.equal(copy.factory_sim().tick_count(), 100, "Takte im Spielstand")
	t.equal(copy.factory_sim().buildings().size(), 4, "Gebäude im Spielstand")


## Fabrikstadt (28. Nov. 2026, Abschnitt 14): Zapfer in der Neonpumpe, neue Gruppen.
func test_pump_replaces_tapper_and_groups() -> void:
	t.ok(not FactorySim.defs().has("zap"), "kein Zapfer mehr")
	var pump := FactorySim.def("pmp")
	t.equal(FactorySim.basis_of("pmp"), 1, "Neonpumpe ab Basis T1")
	t.equal(float(pump["rate"]), 1.0, "T1 = alter Zapfer: 1 Neon")
	t.equal(float(pump["strom"]), 0.0, "T1 ohne Strom")
	t.equal(float(FactorySim.def_at("pmp", 2)["rate"]), 3.0, "T2 = alte Pumpe: 3 Neon")
	t.equal(float(FactorySim.def_at("pmp", 2)["strom"]), 2.0, "T2 braucht 2 Strom")
	var ids: Array = FactorySim.groups().map(func(g): return str(g["id"]))
	t.equal(ids, ["foerdern", "veredeln", "herstellen", "strom", "logistik"], "fünf Gruppen")
	for type in FactorySim.defs():
		t.ok(str(FactorySim.def(type)["gruppe"]) in ids, "Gruppe bekannt: " + str(type))
		t.ok(not FactorySim.lines_of(str(type)).is_empty(), "Linie gesetzt: " + str(type))
	for type in ["gen", "bat", "vdi", "chp"]:
		t.equal(FactorySim.basis_of(type), 2, type + " ab Basis T2")
	t.equal(FactorySim.types_in("herstellen"), ["lot", "chp"], "Herstellen: Löter, Chipfabrik")


func test_upgrade_on_board() -> void:
	var lager := {}
	var sim := _sim(lager)
	t.equal(sim.level_at("1,0"), 1, "Startgebäude auf T1")
	t.ok(sim.can_upgrade("1,0") != "", "T2 erst ab Basis T2")
	sim.state["tier"] = 2
	t.ok(sim.can_upgrade("1,0") != "", "ohne Ware kein Aufrüsten")
	var cost := FactorySim.upgrade_cost("smz", 2)
	t.equal(cost, {"legierung": 30}, "T2 kostet Kaufpreis mal 2")
	lager["res:legierung"] = 30
	t.equal(sim.upgrade("1,0"), "", "Schmelze auf T2")
	t.equal(sim.level_at("1,0"), 2, "jetzt T2")
	t.ok(lager.is_empty(), "bezahlt")
	t.ok(sim.can_upgrade("1,0") != "", "T3 erst ab Basis T3")
	t.equal(float(FactorySim.def_at("smz", 2)["rate"]), 0.75, "T2 schneller")
	t.equal(FactorySim.def_at("smz", 2)["ein"], FactorySim.def("smz")["ein"], "gleiche Funktion")
	# Abreissen und wieder setzen: die Stufe bleibt beim Exemplar.
	sim.remove("1,0")
	t.equal(sim.free_at("smz", 2), 1, "T2-Schmelze liegt im Besitz")
	t.equal(sim.place("1,1", "smz"), "", "wieder gesetzt")
	t.equal(sim.level_at("1,1"), 2, "kommt als T2 zurück")
	# Neu gekauft wird immer T1.
	lager["res:legierung"] = 15
	t.equal(sim.buy_building("smz"), "", "zweite Schmelze gekauft")
	t.equal(sim.place("-1,1", "smz"), "", "gesetzt")
	t.equal(sim.level_at("-1,1"), 1, "neu = T1")
	# Gespeichert und geladen bleibt die Stufe.
	var saved = JSON.parse_string(JSON.stringify(sim.to_dict()))
	var again := FactorySim.new(saved, lager)
	t.equal(again.level_at("1,1"), 2, "Stufe im Spielstand")
	t.equal(again.free_at("smz", 2), 0, "Besitz je Stufe im Spielstand")


func test_upgrade_changes_output() -> void:
	var a_lager := {}
	var b_lager := {}
	var a := _sim(a_lager)
	var b := _sim(b_lager)
	b.state["tier"] = 3
	b_lager["res:legierung"] = 1000
	t.equal(b.upgrade("-1,-1"), "", "Pumpe T2")
	t.equal(b.upgrade("0,-1"), "", "Plasmakammer T2")
	b_lager.clear()
	a.run(120)
	b.run(120)
	t.ok(int(b_lager.get("res:plasma", 0)) > int(a_lager.get("res:plasma", 0)), "T2 macht mehr Plasma")


func test_migrate_old_save() -> void:
	var old := {"version": 1, "tick": 5, "next_id": 4, "tier": 2, "owned": {"zap": 1, "pmp": 1, "sam": 2},
		"chunks": [], "ziel": "",
		"b": {"-1,-1": {"id": 1, "t": "zap"}, "2,0": {"id": 2, "t": "pmp"}, "1,-1": {"id": 3, "t": "sam"}}}
	var sim := FactorySim.new(old, {})
	t.equal(str(sim.building_at("-1,-1")["t"]), "pmp", "Zapfer wird Neonpumpe")
	t.equal(sim.level_at("-1,-1"), 1, "als T1")
	t.equal(sim.level_at("2,0"), 2, "alte Neonpumpe wird T2")
	t.equal(sim.owned("pmp"), 2, "Besitz zusammengelegt")
	t.equal(sim.owned_at("pmp", 2), 1, "eine davon T2")
	t.equal(sim.tier(), 2, "Basis-Stufe bleibt")
	t.equal(int(sim.to_dict()["version"]), FactorySim.SAVE_VERSION, "neue Version")
