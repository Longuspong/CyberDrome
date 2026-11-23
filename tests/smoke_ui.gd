extends SceneTree

## Smoke-Test der UI-Szenen: instanziiert den Hangar (Squad, dann Umbau)
## und den Lauf im Zwischenstopp
## headless und prueft, dass ihr _ready ohne Laufzeitfehler durchlaeuft. Die
## regulaeren Tests pruefen das Datenmodell; hier geht es nur darum, dass die
## Bildschirme sich ueberhaupt aufbauen. Kein Teil der SUITES -- eigener Lauf:
##
##     godot --headless --path . --script res://tests/smoke_ui.gd
##
## Der Autoload wird ueber den Knotenpfad geholt, nicht ueber den globalen Namen:
## das Einstiegsskript wird kompiliert, bevor die Autoload-Namen registriert
## sind -- ``GameState`` als Bezeichner gaebe hier einen Compilefehler.

var _frame := 0


func _game_state() -> Node:
	return root.get_node("GameState")


func _process(_delta: float) -> bool:
	_frame += 1
	var gs := _game_state()
	match _frame:
		2:
			var hangar = load("res://scenes/hangar.tscn").instantiate()
			root.add_child(hangar)
			print("SMOKE: Hangar (Squad) instanziiert (%d DROMEs, %d im Squad)"
				% [gs.roster.entries.size(), gs.roster.squad_count()])
		5:
			for child in root.get_children():
				if child.name == "Hangar":
					child.free()
		7:
			# Mit gewaehltem Eintrag oeffnet der Hangar direkt den Umbau.
			gs.editing_index = 0
			var umbau = load("res://scenes/hangar.tscn").instantiate()
			root.add_child(umbau)
			print("SMOKE: Hangar (Umbau) instanziiert für '%s'"
				% gs.roster.entries[0].name)
		9:
			# Doppeltipp auf eine Teil-Kachel: die freie Plasmaklinge in den
			# ersten DROME einbauen -- dieselben Pruefungen wie im Spiel.
			var hangar = null
			for child in root.get_children():
				if child.has_method("_install_part"):
					hangar = child
			var entry = gs.roster.entries[0]
			var build = gs.roster.build_for(entry)
			var slot: String = build.equip_slots()[0]
			var blade = root.get_node("PartDB").get_part(&"eq_plasma_blade")
			if hangar != null:
				hangar._selected_slot = slot
			if hangar != null and hangar._install_part(entry, build, blade):
				print("SMOKE: Einbauen per Doppeltipp -> %s" % gs.roster.build_for(entry).part_in(slot).display_name)
			else:
				print("SMOKE: Einbauen per Doppeltipp nicht möglich")
		12:
			# Lauf im Zwischenstopp: Lager mit Waffe, eine davon angetippt.
			gs.start_run(4242)
			gs.run.record_result(1, [&"eq_plasma_blade"])
			gs.run.storage.append(&"eq_hammer")
			var stop = load("res://scenes/run.tscn").instantiate()
			stop.name = "RunStop"
			root.add_child(stop)
			stop._selected_storage = 0
			stop._refresh()
			print("SMOKE: Lauf (Zwischenstopp) instanziiert, Lager %d" % gs.run.storage.size())
		14:
			# Module im Lager, eines angetippt, eines eingesetzt, Rezeptbuch offen.
			var stop = root.get_node("RunStop")
			gs.run.storage.append_array([&"amp_attack", &"amp_shield", &"amp_power"])
			gs.run.squad[0].modules[gs.run.squad[0].equip_slots()[0]] = [&"amp_shield"]
			stop._recipes_open = true
			stop._selected_storage = gs.run.storage.size() - 1
			stop._refresh()
			print("SMOKE: Zwischenstopp mit Modulen und Rezeptbuch, Lager %d" % gs.run.storage.size())
			# Modul gewaehlt, dann eine Waffe (Waffenfeld) angetippt: eingesetzt.
			var before: int = gs.run.storage.size()
			stop._selected_storage = gs.run.storage.find(&"amp_attack")
			stop._refresh()
			var card = null
			for tile in stop.find_children("*", "Tile", true, false):
				if tile.key.begins_with("holder:1:") and tile.is_visible_in_tree() and card == null:
					card = tile
			if card != null and card.glow:
				card.on_select.call()
			if gs.run.storage.size() < before:
				print("SMOKE: Modul per Tippen eingesetzt, Lager %d" % gs.run.storage.size())
		16:
			# Titel (13. Nov. 2026), Spielstand-Auswahl, Hauptmenue, Optionen (10. Nov. 2026).
			root.get_node("RunStop").free()
			# Charger (20. Nov. 2026): Crafter im Shop-Reiter Bauen, Upgrade im Hangar.
			gs.roster.add_blanks(1)
			gs.roster.add_phases("fire", 3)
			var made: Dictionary = gs.roster.craft_charger(["fire", "fire", "", "", "", ""])
			var first_weapon := ""
			for slot in gs.roster.entries[0].assignments:
				if str(slot).begins_with("equip_"):
					first_weapon = str(gs.roster.entries[0].assignments[slot])
			gs.roster.mount_charger(str(made.get("uid", "")), first_weapon)
			load("res://scripts/ui/shop_screen.gd").open_tab("charger")
			load("res://scripts/ui/hangar_screen.gd").open_tab("upgrade")
			var upgrade = load("res://scenes/hangar.tscn").instantiate()
			upgrade.name = "Probe_upgrade"
			root.add_child(upgrade)
			print("SMOKE: Hangar (Upgrade) mit Charger instanziiert")
			# Tab DROMEs (22. Nov. 2026): Reiter und Unterseiten, Vergleich in der Ausruestung.
			for t in ["dromes", "overview", "umbau", "drome_up"]:
				load("res://scripts/ui/hangar_screen.gd").open_tab(t)
				var page = load("res://scenes/hangar.tscn").instantiate()
				page.name = "Probe_h_" + t
				root.add_child(page)
			var umbau = root.get_node("Probe_h_umbau")
			umbau._set_compare(root.get_node("PartDB").get_part(&"eq_hammer"))
			print("SMOKE: DROMEs-Tab mit Reitern und Vergleich instanziiert")
			for scene in ["title", "saves", "main", "settings", "shop", "inventory", "resources"]:
				var node = load("res://scenes/%s.tscn" % scene).instantiate()
				node.name = "Probe_%s" % scene
				root.add_child(node)
			print("SMOKE: Titel, Spielstände, Hauptmenü und Optionen instanziiert")
			# Fabrik-Platine (23. Nov. 2026): Reiter Linien, Feld, Werkzeug, Feldgruppe.
			load("res://scripts/ui/resources_screen.gd").open_tab("linien")
			var factory = load("res://scenes/resources.tscn").instantiate()
			factory.name = "Probe_factory"
			root.add_child(factory)
			var board_view = factory.find_children("*", "FactoryView", true, false)
			if board_view.is_empty():
				push_error("SMOKE: FactoryView fehlt im Reiter Linien")
			else:
				board_view[0].tapped("1,0")
				board_view[0].tool = "sol"
				board_view[0].tapped("1,1")
				board_view[0].tapped("3,0")
				board_view[0]._live_tick()
			load("res://scripts/ui/resources_screen.gd").open_tab("charger")
			print("SMOKE: Fabrik-Platine instanziiert und bedient")
			# Cache oeffnen (21. Nov. 2026): jede Stufe der Glitch-Abfolge einmal.
			gs.roster.caches["city"] = int(gs.roster.caches.get("city", 0)) + 1
			var opener = load("res://scripts/ui/cache_opener.gd").show_over(
				root.get_node("Probe_shop"), "city")
			opener._open()
			opener._wind_up(0.7)
			opener._glitch_jump(1)
			opener._bang()
			opener._show_results()
			print("SMOKE: Cache geöffnet, %d Ergebnisse" % opener._results.size())
		18:
			for scene in ["title", "saves", "main", "settings", "shop", "inventory", "resources", "upgrade", "factory"]:
				root.get_node("Probe_%s" % scene).free()
			for t in ["dromes", "overview", "umbau", "drome_up"]:
				root.get_node("Probe_h_" + t).free()
			# Lauf vor dem Kampf: Story-Reihe, dann Endlos mit Chaos-Knoten.
			gs.start_run(4242)
			gs.run.round = 4
			gs.run._pick_default_node()
			var prepare = load("res://scenes/run.tscn").instantiate()
			prepare.name = "RunPrepare"
			root.add_child(prepare)
			print("SMOKE: Lauf (Gegnerwahl) instanziiert, %d Knoten" % gs.run.row().size())
		20:
			var prepare = root.get_node("RunPrepare")
			for seed_value in range(12000, 12200):
				gs.start_run(seed_value, "endless")
				gs.run.round = 3
				gs.run._pick_default_node()
				var chaos: Array = gs.run.available_nodes().filter(func(i): return gs.run.row()[i]["chaos"])
				if not chaos.is_empty():
					gs.run.choose_node(chaos[0])
					break
			prepare._refresh()
			print("SMOKE: Endlos-Lauf mit Chaos-Knoten: %s" % gs.run.is_chaos())
		22:
			root.get_node("RunPrepare").free()
			gs.begin_run_battle()
			var battle = load("res://scenes/battle.tscn").instantiate()
			battle.name = "Battle"
			root.add_child(battle)
			print("SMOKE: Kampf instanziiert")
		26:
			var battle = root.get_node("Battle")
			battle._start_fight()
			print("SMOKE: Kampf gestartet, %d DROMEs" % battle.battle.units.size())
		40:
			root.get_node("Battle").free()
			gs.run = null
			print("SMOKE_OK")
			quit(0)
	return false
