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
		t.ok(hits_foe, "%s zielt auf Gegner" % action.id)
		if ally != null:
			t.ok(not battle.resolver.is_meaningful_target(actor, ally, action),
				"%s trifft keine Verbuendeten" % action.id)
		t.ok(not battle.resolver.is_meaningful_target(actor, actor, action),
			"%s trifft nicht den Schuetzen selbst" % action.id)
	battle.free()


func test_an_action_without_damage_previews_no_damage() -> void:
	# Der Orbit-Sog zieht sein Ziel zwei Felder und richtet nichts an --
	# execute() wendet Schaden nur bei power > 0 an. Die Vorschau rechnete
	# trotzdem max(1, 0 + atk - def) und schrieb "1 Schaden" ueber ein Ziel,
	# dem nichts passiert -- und die KI zog die Aktion deshalb.
	var grid := Grid.new(8, 8)
	var mage := DromeBuild.create("SOG", {
		"body": &"jugg_body", "head": &"jugg_head",
		"feet": &"jugg_feet", "core": &"jugg_core",
		"equip_left": &"eq_siege_cannon", "equip_right": &"eq_orbit_focus"})
	var caster := Unit.create(mage, &"P0", true)
	var victim := Unit.create(mage, &"E0", false)
	caster.tile = Vector2i(2, 2)
	victim.tile = Vector2i(4, 2)
	victim.shield = 0               # die Vorschau zaehlt Integritaetsschaden
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
	# Der Molok hat zwei Halter (Nov. 2026): links alles bis schwer, rechts nur
	# Schild oder Gadget. Die Belagerungskanone ist eine Waffe -- also einmal
	# ja, einmal nein, und das Nein mit Grund.
	var choices := Workshop.slot_choices(_molok(),
		PartDB.get_part(&"eq_siege_cannon"))
	t.equal(choices.size(), 2, "beide Halter stehen zur Wahl")
	t.equal(choices[0]["slot"], "equip_left", "Slot 1 ist der linke Arm")
	t.equal(choices[0]["number"], 1, "und wird als 1 gezaehlt")
	t.ok(choices[0]["allowed"], "der linke Arm nimmt die Kanone")
	t.ok(not choices[1]["allowed"], "der rechte nicht")
	t.ok(choices[1]["detail"].contains("Schild"),
		"und sagt, woran es liegt: %s" % choices[1]["detail"])


func test_the_offer_says_what_a_mount_currently_holds() -> void:
	# Der Unterschied zwischen "frei" und "ersetzt X" ist der ganze Grund, die
	# Liste ueberhaupt zu zeigen: sonst raeumte der Klick blind um.
	var build := _molok()
	build.slots["equip_left"] = &"eq_pulse_blaster"
	var shield := Workshop.slot_choices(build, PartDB.get_part(&"eq_deflector"))
	t.ok(shield[0]["detail"].contains("Puls-Blaster"),
		"der belegte Halter nennt, was weichen wuerde: %s" % shield[0]["detail"])
	t.equal(shield[1]["detail"], "frei", "der leere Halter heisst frei")

	var same := Workshop.slot_choices(build, PartDB.get_part(&"eq_pulse_blaster"))
	t.equal(same[0]["detail"], "steckt schon drin",
		"und wo dasselbe Teil schon sitzt, wird nichts ersetzt")


func test_a_vireo_takes_no_shield() -> void:
	# Ein Platz, Waffe oder Gadget -- ein Deflektor am Vireo ergibt keinen Sinn.
	var vireo := _build("VIREO", {"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core"})
	var choices := Workshop.slot_choices(vireo, PartDB.get_part(&"eq_deflector"))
	t.equal(choices.size(), 1, "der Vireo hat genau einen Halter")
	t.ok(not choices[0]["allowed"], "und der nimmt keinen Schild")
	t.ok(choices[0]["detail"].contains("Waffe"),
		"die Absage nennt, was er nimmt: %s" % choices[0]["detail"])


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
