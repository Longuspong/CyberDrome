extends RefCounted

## Die Teile der Kampf-UI, die eine Regel abbilden.
##
## Nicht das Aussehen -- das sagt tests/screenshot.gd. Hier steht, dass die
## Anzeige dasselbe meint wie die Mechanik: Sperrgruende, Schadensvorschau,
## Lebensbalken, Halter-Angebot.

var t


func _build(name: String, assignment: Dictionary) -> DromeBuild:
	return DromeBuild.create(name, assignment)


func _squad() -> Array:
	return [
		_build("ALPHA", {"body": &"scout_body", "head": &"scout_head",
			"feet": &"scout_feet", "core": &"scout_core",
			"equip_left": &"eq_pulse_blaster"}),
		_build("BETA", {"body": &"strix_body", "head": &"strix_head",
			"feet": &"strix_feet", "core": &"strix_core",
			"equip_center": &"eq_rail_lance"}),
	]


func test_blocker_texts_are_readable() -> void:
	# Die Gruende landen unveraendert im Tooltip. Ein Grund wie "false" waere
	# im Taktikspiel wertlos.
	var battle := BattleManager.new()
	battle.setup(4242, _squad())
	var actor: Unit = battle.living(true)[0]
	var foe: Unit = battle.enemies_of(actor)[0]

	# Ausser Reichweite oder ohne Sicht: die Squads starten auf Abstand.
	for action in actor.actions():
		var reason := battle.resolver.target_blocker(actor, foe.tile, action)
		if reason != "":
			t.ok(reason != "false" and reason.length() > 5,
				"Grund ist lesbar: '%s'" % reason)
	battle.free()


# ---------------------------------------------------------------------------
# Was die KI anvisieren darf und was die Karte dazu schreibt
# ---------------------------------------------------------------------------

func test_the_ring_never_offers_a_pointless_target() -> void:
	# Regeltechnisch darf ein Angriff auf den eigenen DROME gehen -- die
	# Mitigationskette fragt nicht nach Seiten. Angeboten wird er trotzdem
	# nicht, und die Schadensvorschau auf der Karte muss dieselbe Antwort
	# geben: sonst stuende ueber dem eigenen Techniker eine Zahl, die wie eine
	# Drohung aussieht. Deshalb gibt es die Regel genau einmal.
	var battle := BattleManager.new()
	battle.setup(2024, _squad())
	var actor: Unit = battle.living(true)[0]
	var ally: Unit = null
	for other in battle.allies_of(actor):
		if other != actor:
			ally = other
	var foe: Unit = battle.enemies_of(actor)[0]

	for action in actor.actions():
		var hits_foe := battle.resolver.is_meaningful_target(actor, foe, action)
		t.equal(hits_foe, not action.is_heal(),
			"%s zielt auf Gegner, wenn sie Schaden macht" % action.id)
		if ally != null:
			var hits_ally := battle.resolver.is_meaningful_target(actor, ally, action)
			t.equal(hits_ally, action.is_heal(),
				"%s zielt auf Verbuendete nur, wenn sie repariert" % action.id)
	battle.free()


func test_an_action_without_damage_previews_no_damage() -> void:
	# Der Orbit-Sog zieht sein Ziel zwei Felder und richtet nichts an --
	# execute() wendet Schaden nur bei power > 0 an. Die Vorschau rechnete
	# trotzdem max(1, 0 + atk - def) und schrieb "1 Schaden" ueber ein Ziel,
	# dem nichts passiert. Genau die Zahl stand im Aktionsring.
	var grid := Grid.new(8, 8)
	grid.fill(Terrain.TClass.NORMAL)
	var mage := DromeBuild.create("MAGIER", {
		"body": &"mage_body", "head": &"mage_head",
		"feet": &"mage_drive", "core": &"mage_core",
		"equip_left": &"eq_rune_staff", "equip_right": &"eq_orbit_focus"})
	var caster := Unit.create(mage, &"P0", true)
	var victim := Unit.create(mage, &"E0", false)
	caster.tile = Vector2i(2, 2)
	victim.tile = Vector2i(4, 2)
	var resolver := ActionResolver.new(grid, [caster, victim])

	for action in caster.actions():
		var preview := resolver.preview_damage(caster, victim, action)
		if action.power > 0:
			t.ok(preview > 0, "%s verspricht Schaden und macht welchen" % action.id)
		else:
			t.equal(preview, 0,
				"%s verspricht keinen Schaden, weil sie keinen anrichtet" % action.id)
			t.ok(action.effect_summary() != "",
				"stattdessen steht dort, was sie tut: '%s'"
				% action.effect_summary())

	caster.free()
	victim.free()


func test_every_action_offers_a_readable_description() -> void:
	# Die Beschreibung steht an genau einer Stelle (ActionData) und wird von
	# Werkstatt, Aktionsleiste und Ring gelesen. Drei Texte fuer dieselbe
	# Aktion waeren drei Gelegenheiten, dass einer eine Reichweite nennt, die
	# nicht mehr stimmt.
	for part in PartDB.parts.values():
		for action in part.actions:
			var lines: Array[String] = action.description_lines()
			t.ok(lines.size() >= 3, "%s wird in mehr als einer Zeile erklaert"
				% action.id)
			t.ok(action.headline().contains("Rw"),
				"die Kurzform nennt die Reichweite: '%s'" % action.headline())
			t.ok("\n".join(lines).contains(part.display_name),
				"%s nennt das Bauteil, aus dem sie kommt" % action.id)


# ---------------------------------------------------------------------------
# Aktionssymbole
# ---------------------------------------------------------------------------

func test_every_action_has_its_own_symbol() -> void:
	# Die Symbole ersetzen im Kampf den Namen der Aktion. Damit haengt an
	# ihnen, ob der Spieler seinen Knopf wiederfindet -- und "generic" heisst
	# genau, dass keine Regel gegriffen hat: die Aktion macht weder Schaden
	# noch repariert, zieht, stoesst oder provoziert sie.
	#
	# Wer dieses Bauteil baut, muss ein Symbol dazu bauen. Der Test steht hier,
	# damit er es beim Bauen erfaehrt und nicht im Playtest, wo alle Knoepfe
	# gleich aussehen.
	for part in PartDB.parts.values():
		for action in part.actions:
			var key := ActionIcons.key_for(action)
			t.ok(key != "generic",
				"%s (%s) faellt auf das Platzhaltersymbol zurueck"
				% [action.id, part.id])
			t.ok(ActionIcons.texture(key) != null,
				"das Symbol '%s' fuer %s existiert als Datei" % [key, action.id])


func test_symbols_separate_actions_that_do_different_things() -> void:
	# Zwei Aktionen mit derselben Wirkung duerfen -- und sollen -- dasselbe
	# Symbol haben; zwei mit verschiedener Wirkung nicht. Ohne diese Zusicherung
	# waere das Symbol eine Verzierung und keine Auskunft.
	var pull := ActionData.from_meta({"id": "t_pull", "push_tiles": -2,
		"range_tiles": 4})
	var push := ActionData.from_meta({"id": "t_push", "push_tiles": 2,
		"range_tiles": 4})
	var blade := ActionData.from_meta({"id": "t_blade", "range_tiles": 1,
		"power": 18})
	var shot := ActionData.from_meta({"id": "t_shot", "range_tiles": 6,
		"power": 12})
	var mend := ActionData.from_meta({"id": "t_mend", "range_tiles": 3,
		"power": -12})
	var quiet := ActionData.from_meta({"id": "t_quiet", "range_tiles": 2})

	t.ok(ActionIcons.key_for(pull) != ActionIcons.key_for(push),
		"Sog und Stoss sind Gegenstuecke und sehen verschieden aus")
	t.ok(ActionIcons.key_for(blade) != ActionIcons.key_for(shot),
		"Nahkampf sieht anders aus als ein Schuss")
	t.equal(ActionIcons.key_for(mend), "heal",
		"negative Wirkung ist eine Reparatur, egal auf welche Entfernung")

	# Die Rangfolge: eine Flaechenreparatur ist eine REPARATUR. Was das Ziel
	# davon hat, steht ueber der Frage, wie viele Felder mitgenommen werden.
	var area_mend := ActionData.from_meta({"id": "t_area_mend", "power": -8,
		"aoe_radius": 2, "range_tiles": 3})
	t.equal(ActionIcons.key_for(area_mend), "heal",
		"Flaechenreparatur bleibt eine Reparatur")

	# Und der Gegenbeweis: der Platzhalter ist erreichbar. Gaebe es diesen Fall
	# nicht, waere die Pruefung oben eine Zusicherung, die nie fehlschlagen
	# kann -- und damit schlimmer als keine.
	t.equal(ActionIcons.key_for(quiet), "generic",
		"eine Aktion ohne erkennbare Wirkung bekommt den leeren Rahmen")


# ---------------------------------------------------------------------------
# Die Werkstatt: welche Halter die Ausruestung angeboten bekommt
# ---------------------------------------------------------------------------
#
# Die Bibliothek zeigt Bilder, keine Zeilen -- geprueft wird hier nicht das
# Aussehen (dafuer gibt es das Bild aus tests/screenshot.gd), sondern die
# einzige Regel, die der Umbau neu aufgeschrieben hat: welche Halterungen ein
# Klick auf ein Ausruestungsteil anbietet und warum die uebrigen nicht.

const Workshop := preload("res://scripts/core/slot_rules.gd")


func _molok() -> DromeBuild:
	return _build("MOLOK", {"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core"})


func test_every_mount_of_the_chassis_is_offered_with_its_verdict() -> void:
	# Der Molok hat drei Halter: zwei schwere Arme und eine leichte Schulter,
	# die nur Support nimmt. Die Belagerungskanone ist schwer und eine Waffe --
	# also zweimal ja, einmal nein, und das Nein mit Grund.
	var choices := Workshop.slot_choices(_molok(),
		PartDB.get_part(&"eq_siege_cannon"))
	t.equal(choices.size(), 3, "alle drei Halter stehen zur Wahl")
	t.equal(choices[0]["slot"], "equip_left", "Slot 1 ist der linke Arm")
	t.equal(choices[0]["number"], 1, "und wird als 1 gezaehlt")
	t.ok(choices[0]["allowed"] and choices[1]["allowed"],
		"beide Arme nehmen die Kanone")
	t.ok(not choices[2]["allowed"], "die leichte Schulter nicht")
	t.ok(choices[2]["detail"].contains("leicht"),
		"und sagt, woran es liegt: %s" % choices[2]["detail"])


func test_the_offer_says_what_a_mount_currently_holds() -> void:
	# Der Unterschied zwischen "frei" und "ersetzt X" ist der ganze Grund, die
	# Liste ueberhaupt zu zeigen: sonst raeumte der Klick blind um.
	var build := _molok()
	build.slots["equip_left"] = &"eq_pulse_blaster"
	var choices := Workshop.slot_choices(build, PartDB.get_part(&"eq_rail_lance"))
	t.ok(choices[0]["detail"].contains("Puls-Blaster"),
		"der belegte Halter nennt, was weichen wuerde: %s" % choices[0]["detail"])
	t.equal(choices[1]["detail"], "frei", "der leere Halter heisst frei")

	var same := Workshop.slot_choices(build, PartDB.get_part(&"eq_pulse_blaster"))
	t.equal(same[0]["detail"], "steckt schon drin",
		"und wo dasselbe Teil schon sitzt, wird nichts ersetzt")


func test_a_light_support_part_reaches_the_shoulder() -> void:
	# Der Gegenbeweis zur Absage oben: die Schulter ist kein toter Halter,
	# sie ist ein waehlerischer.
	var choices := Workshop.slot_choices(_molok(), PartDB.get_part(&"eq_drone_pod"))
	t.ok(choices[2]["allowed"], "leichter Support darf auf die Schulter")
	t.equal(choices[2]["number"], 3, "als dritter Halter")


func test_a_rejected_mount_names_its_rule_not_just_a_no() -> void:
	# Der Koedersender ist leicht -- an der Schulter scheitert er nicht an der
	# Klasse. Die Absage muss dann die Kategorie nennen und nicht die Groesse.
	var focus := Workshop.slot_choices(_molok(), PartDB.get_part(&"eq_rune_staff"))
	t.ok(not focus[2]["allowed"], "eine leichte WAFFE darf trotzdem nicht")
	t.ok(focus[2]["detail"].contains("Support"),
		"weil die Schulter nur Support nimmt: %s" % focus[2]["detail"])


func test_the_offer_never_disagrees_with_the_build_rule() -> void:
	# Massgeblich ist chassis.accepts() -- dieselbe Regel, die den Aufbau beim
	# Laden prueft. Die Liste ist eine Anzeige davon, keine zweite Regel.
	for chassis in PartDB.of_type(PartData.Type.BODY):
		var build := DromeBuild.create("PRUEF", {"body": chassis.id})
		for part in PartDB.of_type(PartData.Type.EQUIPMENT):
			var choices := Workshop.slot_choices(build, part)
			t.equal(choices.size(), build.equip_slots().size(),
				"%s bietet jeden seiner Halter an" % chassis.display_name)
			for choice in choices:
				t.equal(choice["allowed"], chassis.accepts(part, choice["slot"]),
					"%s in %s: Angebot und Regel sagen dasselbe"
					% [part.display_name, choice["slot"]])
				t.ok(choice["detail"] != "",
					"jede Zeile sagt etwas: %s" % choice["label"])


func test_socket_parts_ask_nothing() -> void:
	# Ein Chassis kann nur ins Chassis. Fuer Sockelteile gibt es nichts zu
	# fragen -- und genau deshalb bauen sie sich weiterhin mit einem Klick ein.
	t.ok(Workshop.slot_choices(_molok(), PartDB.get_part(&"scout_body")).is_empty(),
		"ein Chassis bekommt keine Halterliste")
	t.ok(Workshop.slot_choices(_molok(), PartDB.get_part(&"jugg_core")).is_empty(),
		"ein Kern auch nicht")


## Der eine Lebensbalken: Integritaet und Schild teilen sich die Breite nach
## ihren Hoechstwerten und leeren sich an Ort und Stelle.
func test_the_life_bar_splits_by_maximum() -> void:
	var full: Dictionary = BattleView.UnitBadgePainter.split(200, 200, 100, 100)
	t.ok(absf(full["hp_slot"] - 2.0 / 3.0) < 0.001, "200/100: zwei Drittel Integritaet")
	t.ok(absf(full["shield_slot"] - 1.0 / 3.0) < 0.001, "200/100: ein Drittel Schild")
	var hurt: Dictionary = BattleView.UnitBadgePainter.split(100, 200, 0, 100)
	t.ok(absf(hurt["hp_fill"] - 1.0 / 3.0) < 0.001, "halbe Integritaet fuellt ein Drittel")
	t.equal(hurt["shield_fill"], 0.0, "leerer Schild ist leer")
	t.ok(absf(hurt["shield_slot"] - 1.0 / 3.0) < 0.001, "sein Platz bleibt aber")
	var bare: Dictionary = BattleView.UnitBadgePainter.split(50, 50, 0, 0)
	t.equal(bare["hp_slot"], 1.0, "ohne Schild gehoert der Balken der Integritaet")
