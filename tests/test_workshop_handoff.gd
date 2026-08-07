extends RefCounted

## M7: die Uebergabe von der Werkstatt an den Kampf.
##
## Die Werkstatt ist ein eigenstaendiges Werkzeug (python3 main.py) und
## schreibt ihren Squad als JSON. Getestet wird hier die Naht: dass genau das
## Format, das sie erzeugt, im Kampf ankommt -- mit denselben Teilen.
##
## Das Loadout enthaelt ausschliesslich Teile-IDs, keine Werte. Damit kann ein
## gespeicherter Squad nicht veralten, wenn sich das Balancing aendert: die
## Stats werden beim Laden aus den Bauteilen neu gerechnet.

var t


## Genau das, was tools -- also index.html -- ueber /api/squad schreibt.
func _workshop_payload() -> Dictionary:
	return {
		"squad_size": 2,
		"squad": [
			{
				"name": "ALPHA",
				"set": "bot1",
				"direction": "south",
				"palette": {},
				"slots": {
					"body": {"part_id": "scout_body", "code": "CHS-001", "name": "Vireo Chassis"},
					"head": {"part_id": "scout_head", "code": "HED-001", "name": "Vireo Sensorkopf"},
					"feet": {"part_id": "scout_feet", "code": "LEG-001", "name": "Vireo Sprintbeine"},
					"core": {"part_id": "scout_core", "code": "COR-001", "name": "Vireo Impulskern"},
					"equip_left": {"part_id": "eq_pulse_blaster", "code": "EQP-001", "name": "Puls-Blaster"},
				},
			},
			{
				"name": "BETA",
				"set": "bot4",
				"direction": "south",
				"palette": {},
				"slots": {
					"body": {"part_id": "strix_body", "code": "CHS-004", "name": "Strix Chassis"},
					"head": {"part_id": "strix_head", "code": "HED-004", "name": "Strix Okularkopf"},
					"feet": {"part_id": "strix_feet", "code": "LEG-004", "name": "Strix Federbeine"},
					"core": {"part_id": "strix_core", "code": "COR-004", "name": "Strix Zielrechner"},
					"equip_center": {"part_id": "eq_rail_lance", "code": "EQP-007", "name": "Schienen-Lanze"},
				},
			},
		],
	}


func test_workshop_format_loads_as_a_playable_squad() -> void:
	var payload := _workshop_payload()
	var builds: Array = []
	for loadout in payload["squad"]:
		var build := DromeBuild.from_loadout(loadout)
		t.ok(build != null, "Loadout %s laesst sich laden" % loadout["name"])
		builds.append(build)

	t.equal(builds.size(), 2, "beide DROMEs kommen an")
	t.equal(builds[0].display_name, "ALPHA", "der Name kommt mit")
	for build in builds:
		var problems: Array[String] = build.validate()
		t.ok(problems.is_empty(), "%s ist kampftauglich: %s"
			% [build.display_name, ", ".join(problems)])


func test_the_squad_reaches_the_battle_with_the_same_parts() -> void:
	# Akzeptanzkriterium: der gebaute Bot muss im Kampf wiedererkennbar sein --
	# dieselben Bauteil-Assets, sichtbar derselbe Bot.
	var builds: Array = []
	for loadout in _workshop_payload()["squad"]:
		builds.append(DromeBuild.from_loadout(loadout))

	var battle := BattleManager.new()
	battle.setup(555, builds)

	var players := battle.living(true)
	t.equal(players.size(), 2, "beide DROMEs stehen im Kampf")
	for i in players.size():
		var unit: Unit = players[i]
		t.equal(unit.display_name, builds[i].display_name,
			"der Name aus der Werkstatt steht im Kampf")
		t.equal(unit.build.slots, builds[i].slots,
			"exakt dieselben Teile in denselben Slots")
		# Und dieselben Grafiken -- die Sprites entstehen aus genau diesen Views.
		for slot in unit.build.slots:
			var part := unit.build.part_in(slot)
			var path: String = part.view("south").get("svg", "")
			t.ok(ResourceLoader.exists(path),
				"Textur fuer %s liegt vor: %s" % [part.id, path])
	battle.free()


func test_a_loadout_survives_saving_and_loading() -> void:
	var original := DromeBuild.from_loadout(_workshop_payload()["squad"][0])
	var restored := DromeBuild.from_loadout(original.to_loadout())
	t.equal(restored.slots, original.slots, "Slots ueberstehen den Rundlauf")
	t.equal(restored.stats(), original.stats(), "Stats ebenso")
	t.equal(restored.display_name, original.display_name, "und der Name")


func test_unknown_parts_are_skipped_not_fatal() -> void:
	# Ein Loadout kann von Hand entstehen oder aus einem aelteren Stand kommen.
	# Ein unbekanntes Teil darf den Start nicht verhindern -- die Validierung
	# meldet danach ohnehin, was fehlt.
	var loadout := {
		"name": "ALTLAST",
		"slots": {
			"body": {"part_id": "scout_body"},
			"head": {"part_id": "gibt_es_nicht"},
			"feet": {"part_id": "scout_feet"},
			"core": {"part_id": "scout_core"},
			"equip_left": {"part_id": "eq_pulse_blaster"},
		},
	}
	var build := DromeBuild.from_loadout(loadout)
	t.ok(build != null, "das Loadout laedt trotzdem")
	t.ok(not build.slots.has("head"), "das unbekannte Teil wurde uebersprungen")
	t.ok(build.validate().has("Sensorik fehlt"),
		"und die Validierung sagt, was fehlt")


func test_slot_rules_still_hold_after_loading() -> void:
	# Die Werkstatt prueft beim Bauen, aber eine Loadout-Datei kann von Hand
	# entstehen. Der Loader muss die Regel erneut anwenden -- sonst haelt sie
	# nur im Werkzeug, und genau dort braucht sie niemand.
	var loadout := {
		"name": "SCHUMMEL",
		"slots": {
			"body": {"part_id": "scout_body"},
			"head": {"part_id": "scout_head"},
			"feet": {"part_id": "scout_feet"},
			"core": {"part_id": "scout_core"},
			# Belagerungskanone auf dem Sprinter: mount_class heavy gegen
			# einen Slot, der nur bis medium nimmt.
			"equip_left": {"part_id": "eq_siege_cannon"},
		},
	}
	var build := DromeBuild.from_loadout(loadout)
	var problems: Array[String] = build.validate()
	var named := false
	for line in problems:
		if line.contains("passt nicht in"):
			named = true
	t.ok(named, "die Slotregel wird auch beim Laden durchgesetzt: %s"
		% ", ".join(problems))
