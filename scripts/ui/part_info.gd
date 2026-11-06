class_name PartInfo
extends RefCounted

## Was ein Teil tut, in Klartext -- fuer den Umbau im Hangar.
##
## Der Spieler soll im Spiel selbst herausfinden koennen, wie eine Ausruestung
## funktioniert, ohne Tabelle daneben: Werte, Besonderheiten, jede Aktion mit
## Reichweite, Kosten und Wirkung, und wann sie zum Einsatz kommt.
##
## Gerechnet wird aus den Teildaten selbst (PartData, ActionData). Nur der
## eine einleitende Satz je Teil steht hier von Hand -- er erklaert die Rolle,
## nicht die Zahlen. Die Zahlen kommen immer aus den Daten, damit kein Text
## eine Reichweite nennt, die nicht mehr stimmt.

## Ein Satz je Teil: wozu ist es da? Fehlt ein Eintrag, entfaellt die Zeile.
const ROLE := {
	&"eq_pulse_blaster": "Leichte Allzweckwaffe auf mittlere Distanz. Halb Energieschaden -- gut gegen Schilde.",
	&"eq_deflector": "Ein Energieschild zum Umschnallen: mehr Schild, der sich jeden Puls (alle 3 s) wieder auflaedt. Keine eigene Aktion.",
	&"eq_siege_cannon": "Schwerer Moerser mit grosser Reichweite. Trifft das Ziel und alle acht Felder darum herum.",
	&"eq_drone_pod": "Reparaturdrohnen: jeden Puls (alle 3 s) kommt ein Teil der Integritaet zurueck.",
	&"eq_rune_staff": "Nahkampfstab mit reinem Energieschaden. Trifft das Ziel und die vier geraden Nachbarfelder.",
	&"eq_orbit_focus": "Kontrolle statt Schaden: zieht einen Gegner zu sich heran.",
	&"eq_rail_lance": "Scharfschuetzenwaffe mit der groessten Reichweite. Leise -- zieht wenig Aggro auf sich.",
	&"eq_bait_beacon": "Lockt Gegner an: wer ihn traegt, steht in jeder gegnerischen Aggro-Liste weiter oben.",
	&"eq_holo_boost": "Ein schneller Sprung in gerader Linie -- fuer Stellungswechsel, nicht fuer Schaden.",
}

## Seit dem Echtzeit-Kampf zaehlen Bewegung (MOV) und Energie nicht mehr:
## SPD ist die Laufgeschwindigkeit, Faehigkeiten loesen nach ihrer Regel aus.
const STAT_LABELS := [
	["hp", "Integritaet"], ["shield", "Schild"], ["shield_regen", "Schild je Puls"],
	["def", "Panzerung"], ["atk", "Angriff"], ["spd", "Tempo (SPD, Laufgeschwindigkeit)"],
]


## Die Info als Zeilen: [text, art]. art ist "role", "stat", "trait",
## "action", "detail" oder "note" -- danach richtet sich die Darstellung.
static func lines(part: PartData) -> Array:
	var out: Array = []
	if part == null:
		return out
	if ROLE.has(part.id):
		out.append([ROLE[part.id], "role"])

	var head: Array[String] = []
	if part.type == PartData.Type.EQUIPMENT:
		head.append(SlotRules.class_label(part.mount_class))
		head.append(SlotRules.category_label(part.category))
	if not head.is_empty():
		out.append([" · ".join(head), "detail"])

	for entry in STAT_LABELS:
		var value = part.get(entry[0])
		if value is int and value != 0:
			out.append(["%s %+d" % [entry[1], value], "stat"])
	if part.shield_bonus > 0.0:
		out.append(["Schild-Effizienz +%d %%" % int(round(part.shield_bonus * 100.0)), "stat"])

	# Gewicht zeigt sich nur als das, was es kostet: Tempo. Gerechnet wird wie
	# in DromeBuild.payload_slowdown() -- hier fuer das Teil allein.
	if part.type == PartData.Type.EQUIPMENT:
		var step := Config.get_int("spd_weight_step", 4)
		var slow := part.weight / step if step > 0 else 0
		if slow > 0:
			out.append(["Schwer: bremst um %d SPD" % slow, "stat_bad"])

	for text in traits(part):
		out.append([text, "trait"])

	if part.type == PartData.Type.EQUIPMENT:
		if part.actions.is_empty():
			out.append(["Passiv: wirkt immer, ohne eigene Aktion.", "note"])
		for action in part.actions:
			out.append(["%s (%s)" % [action.display_name, action.category_label()], "action"])
			for line in action_lines(action):
				out.append([line, "detail"])
	return out


## Besonderheiten, die keine Zahl im Werteblock sind.
static func traits(part: PartData) -> Array[String]:
	var out: Array[String] = []
	if part.hp_regen_pct > 0:
		out.append("Repariert jeden Puls (alle 3 s) %d %% der Integritaet." % part.hp_regen_pct)
	if part.aggro_bonus > 0:
		out.append("Zieht Aufmerksamkeit: +%d Aggro bei allen Gegnern." % part.aggro_bonus)
	match part.passive:
		"hit_rush":
			var rush := Config.section("passives").get("hit_rush", {}) as Dictionary
			out.append("Sprint: jeder Treffer macht %s s lang %d %% schneller." % [
				ActionData._seconds(float(rush.get("seconds", 2.0))),
				int(round((float(rush.get("move_mult", 1.4)) - 1.0) * 100.0))])
		"presence":
			var p := Config.section("passives").get("presence", {}) as Dictionary
			out.append("Praesenz: Gegner im Umkreis %d richten ihre Aufmerksamkeit auf ihn; %d %% des Schadens an Verbuendeten im Umkreis %d faengt er ab." % [
				int(p.get("aggro_radius", 2)), int(round(float(p.get("guard_share", 0.3)) * 100.0)),
				int(p.get("guard_radius", 3))])
		"spellcaster":
			out.append("Zauberwirker: nach jeder Faehigkeit braucht die Waffe nur halb so viele Angriffe bis zur naechsten.")
	return out


## Eine Aktion in Klartext, so wie sie im Kampf wirkt.
static func action_lines(action: ActionData) -> Array[String]:
	var out: Array[String] = []
	var reach := "Reichweite %d" % action.range_tiles
	if action.range_tiles <= 1:
		reach = "Nahkampf (Reichweite 1)"
	var what := ""
	if action.is_move():
		what = "springt bis %d Felder geradeaus" % action.range_tiles
	elif action.power > 0:
		what = "Staerke %d" % action.power
	else:
		what = action.effect_summary()
	out.append("%s · %s" % [reach, what])

	match action.targeting:
		ActionData.Targeting.AOE_AROUND_TARGET:
			out.append("Flaeche: trifft auch alle Felder im Umkreis %d um das Ziel." % action.aoe_radius)
		ActionData.Targeting.AOE_CROSS:
			out.append("Kreuz: trifft das Ziel und die vier geraden Nachbarfelder.")
	if action.power > 0:
		if action.energy_fraction >= 1.0:
			out.append("Reiner Energieschaden -- stark gegen Schilde.")
		elif action.energy_fraction > 0.0:
			out.append("%d %% Energieschaden -- gut gegen Schilde." % int(round(action.energy_fraction * 100.0)))
		else:
			out.append("Kinetischer Schaden -- stark gegen Integritaet, schwach gegen Schilde.")
	if action.shield_mult > 1.0:
		out.append("Schildbrecher: macht %d %% Schaden an Schilden." % int(round(action.shield_mult * 100.0)))
	if action.shots > 1:
		out.append("%d schnelle Treffer auf bis zu %d Gegner in Reichweite; ist nur einer da, trifft er ihn mehrfach." % [action.shots, action.shots])
	if action.gather:
		out.append("Zieht die Gegner im Umkreis %d zum Ziel heran." % action.aoe_radius)
	if action.delay > 0.0:
		out.append("Danach schlaegt nach %s s eine Schockwelle zu." % ActionData._seconds(action.delay))
	if not action.status.is_empty():
		out.append("Getroffene: %s." % action.status_text())
	if action.push_tiles > 0:
		out.append("Stoesst das Ziel %d Feld(er) weg." % action.push_tiles)
	elif action.push_tiles < 0:
		out.append("Zieht das Ziel %d Feld(er) heran." % absi(action.push_tiles))

	# Wann sie kommt: Waffen schiessen in ihrem Takt, Faehigkeiten nach ihrer
	# Regel -- beides ohne Energie.
	if action.is_attack():
		out.append("Schiesst alle %s s." % ActionData._seconds(action.interval))
	elif action.trigger_kind != "":
		out.append("Loest von selbst aus: %s." % action.trigger_text())
		if action.trigger_kind == "attacks":
			out.append("Dieser Angriff ersetzt den normalen Schuss.")
	if action.aggro_coeff < 1.0:
		out.append("Leise: erzeugt nur %d %% der ueblichen Aggro." % int(round(action.aggro_coeff * 100.0)))
	elif action.aggro_coeff > 1.0:
		out.append("Laut: erzeugt %d %% der ueblichen Aggro." % int(round(action.aggro_coeff * 100.0)))
	return out


## Die Info als fertige Liste von Labels -- fuer den Hangar.
static func build(part: PartData, into: VBoxContainer) -> void:
	for entry in lines(part):
		var text: String = entry[0]
		var label: Label
		match entry[1]:
			"role": label = UiKit.label(text, UiKit.SMALL, Color(0.9, 0.93, 1.0))
			"action": label = UiKit.label(text, UiKit.BODY, UiKit.ACCENT)
			"stat": label = UiKit.label(text, UiKit.SMALL, UiKit.GOOD)
			"stat_bad": label = UiKit.label(text, UiKit.SMALL, UiKit.BAD)
			"trait": label = UiKit.label(text, UiKit.SMALL, UiKit.WARN)
			_: label = UiKit.label(text, UiKit.SMALL, UiKit.MUTED)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		into.add_child(label)
