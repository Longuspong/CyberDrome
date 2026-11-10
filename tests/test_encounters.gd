extends RefCounted

## Handverlesene Gegnerteams (data/encounters.json, scripts/core/encounters.gd).
##
## Die Teams sind Daten, die der Spieler aendern soll -- deshalb prueft diese
## Suite, dass jedes Team baubar ist: gueltige DROMEs, Waffen, die in die
## Halter passen, Module und Rezepte, die es gibt und die zur Waffe passen.

var t


func test_there_are_teams_for_every_region_and_for_training() -> void:
	t.ok(Encounters.training_teams().size() >= 2, "mindestens zwei Trainingsteams")
	for region in TerrainDB.regions.values():
		var teams := Encounters.faction_teams(region.id)
		t.ok(teams.size() >= 3, "%s: mindestens drei Teams (%d)" % [region.display_name, teams.size()])
		var types := {}
		for entry in teams:
			types[str(entry.get("type", ""))] = true
		t.ok(types.size() >= 2, "%s: mindestens zwei Gegnertypen -- sonst gibt es keine zwei verschiedenen Normalen"
			% region.display_name)


func test_every_team_can_be_built() -> void:
	var ids := {}
	for entry in Encounters.all_teams():
		var id := str(entry.get("id", ""))
		t.ok(id != "" and not ids.has(id), "Team-Id '%s' ist gesetzt und einmalig" % id)
		ids[id] = true
		t.ok(str(entry.get("name", "")) != "", "%s hat einen Namen" % id)
		t.ok((Encounters.data().get("types", {}) as Dictionary).has(str(entry.get("type", ""))),
			"%s: Gegnertyp '%s' ist bekannt" % [id, entry.get("type", "")])
		var dromes: Array = entry.get("dromes", [])
		t.ok(dromes.size() >= RunState.squad_max(), "%s: genug DROMEs fuer ein volles Feld (%d)"
			% [id, dromes.size()])
		var builds := Encounters.build(entry, dromes.size())
		t.equal(builds.size(), dromes.size(), "%s: jeder DROME laesst sich bauen" % id)
		var names := {}
		for i in builds.size():
			var build: DromeBuild = builds[i]
			var label := "%s / %s" % [id, build.display_name]
			t.ok(not names.has(build.display_name), "%s: Name einmalig im Team" % label)
			names[build.display_name] = true
			t.ok(build.is_valid(), "%s ist gueltig %s" % [label, build.validate()])
			t.equal(build.equipment().size(), (dromes[i].get("weapons", []) as Array).size(),
				"%s: jede Waffe hat einen Halter" % label)
			t.ok(not build.weapons().is_empty() or build.equipment().size() > 0, "%s ist bewaffnet" % label)


func test_team_modules_exist_and_fit_the_weapon() -> void:
	for entry in Encounters.all_teams():
		var dromes: Array = entry.get("dromes", [])
		var builds := Encounters.build(entry, dromes.size())
		for i in builds.size():
			var build: DromeBuild = builds[i]
			var weapon := build.part_in(Encounters.first_weapon_slot(build))
			var label := "%s / %s" % [entry["id"], build.display_name]
			for module_id in dromes[i].get("modules", []):
				var module := ModuleData.get_module(StringName(str(module_id)))
				t.ok(module != null, "%s: Modul %s gibt es" % [label, module_id])
				if module != null:
					t.ok(not module.is_recipe(), "%s: %s ist ein Grundmodul" % [label, module_id])
					t.ok(module.fits(weapon), "%s: %s passt zur Waffe" % [label, module_id])
			var recipe_id := str(dromes[i].get("recipe", ""))
			if recipe_id != "":
				var recipe := ModuleData.get_module(StringName(recipe_id))
				t.ok(recipe != null and recipe.is_recipe(), "%s: Rezept %s gibt es" % [label, recipe_id])
				if recipe != null:
					t.ok(recipe.fits(weapon), "%s: Rezept %s passt zur Waffe" % [label, recipe_id])


func test_modules_come_in_list_order_and_the_recipe_leads() -> void:
	var entry := Encounters.team("klingentrupp")
	var drome: Dictionary = entry["dromes"][0]
	var build := Encounters.build_drome(drome)
	t.equal(Encounters.modules_for(drome, build, 0, true), [], "ohne Plaetze keine Module")
	t.equal(Encounters.modules_for(drome, build, 1, false), [StringName(drome["modules"][0])],
		"ein Platz: das erste der Liste")
	var with_recipe := Encounters.modules_for(drome, build, 2, true)
	t.equal(with_recipe[0], StringName(drome["recipe"]), "zwei Plaetze und spaet: das Rezept vorn")
	t.equal(with_recipe.size(), 2, "und ein Grundmodul dazu")
	t.equal(Encounters.modules_for(drome, build, 1, true), [StringName(drome["modules"][0])],
		"ein Platz reicht nicht fuer ein Rezept")


func test_the_first_dromes_of_a_team_come_first() -> void:
	var entry := Encounters.team("eisenfaust")
	var two := Encounters.build(entry, 2)
	var four := Encounters.build(entry, 4)
	t.equal(two.size(), 2, "zwei von vier")
	t.equal(two[0].display_name, four[0].display_name, "dieselben vorn")
	t.equal(two[1].slots, four[1].slots, "mit derselben Ausstattung")
