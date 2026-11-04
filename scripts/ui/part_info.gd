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
	&"eq_deflector": "Ein Energieschild zum Umschnallen: mehr Schild, der sich jeden Zug wieder auflaedt. Keine eigene Aktion.",
	&"eq_siege_cannon": "Schwerer Moerser mit grosser Reichweite. Trifft das Ziel und alle acht Felder darum herum.",
	&"eq_drone_pod": "Reparaturdrohnen: zu Beginn jedes eigenen Zuges kommt ein Teil der Integritaet zurueck.",
	&"eq_rune_staff": "Nahkampfstab mit reinem Energieschaden. Trifft das Ziel und die vier geraden Nachbarfelder.",
	&"eq_orbit_focus": "Kontrolle statt Schaden: zieht einen Gegner zu sich heran.",
	&"eq_rail_lance": "Scharfschuetzenwaffe mit der groessten Reichweite. Leise -- zieht wenig Aggro auf sich.",
	&"eq_bait_beacon": "Lockt Gegner an: wer ihn traegt, steht in jeder gegnerischen Aggro-Liste weiter oben.",
	&"eq_holo_boost": "Ein schneller Sprung in gerader Linie -- fuer Stellungswechsel, nicht fuer Schaden.",
}

const STAT_LABELS := [
	["hp", "Integritaet"], ["shield", "Schild"], ["shield_regen", "Schild-Regeneration"],
	["def", "Panzerung"], ["atk", "Angriff"], ["spd", "Tempo (SPD)"], ["mov", "Bewegung"],
	["en_max", "Energie"], ["en_regen", "Energie-Regeneration"],
	["weight_capacity", "Traglast"], ["power_output", "Leistung"],
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
	if part.weight > 0:
		head.append("Gewicht %d" % part.weight)
	if part.power_draw > 0:
		head.append("Strombedarf %d" % part.power_draw)
	if part.code != "":
		head.append(part.code)
	if not head.is_empty():
		out.append([" · ".join(head), "detail"])

	for entry in STAT_LABELS:
		var value = part.get(entry[0])
		if value is int and value != 0:
			out.append(["%s %+d" % [entry[1], value], "stat"])
	if part.shield_bonus > 0.0:
		out.append(["Schild-Effizienz +%d %%" % int(round(part.shield_bonus * 100.0)), "stat"])

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
		out.append("Repariert zu Beginn jedes eigenen Zuges %d %% der Integritaet." % part.hp_regen_pct)
	if part.aggro_bonus > 0:
		out.append("Zieht Aufmerksamkeit: +%d Aggro bei allen Gegnern." % part.aggro_bonus)
	if part.can_pass_units:
		out.append("Kann durch andere DROMEs hindurchlaufen.")
	if part.can_enter_steps:
		out.append("Kann auf Podeste und Stufen steigen%s." %
			(" (zum halben Preis)" if part.step_cost_reduced else ""))
	if part.ignores_drift:
		out.append("Rutscht nicht auf Oel, Schlamm oder Eis.")
	if part.drift_modifier > 0:
		out.append("Gleitet auf rutschigem Boden %d Feld(er) weiter." % part.drift_modifier)
	if part.grants_ignore_haze:
		out.append("Sieht durch Dampf und hohes Gras.")
	return out


## Eine Aktion in Klartext, so wie sie im Kampf wirkt.
static func action_lines(action: ActionData) -> Array[String]:
	var out: Array[String] = []
	var reach := "Reichweite %d" % action.range_tiles
	if action.range_tiles <= 1:
		reach = "Nahkampf (Reichweite 1)"
	var what := ""
	if action.is_move():
		what = "springt bis %d Felder geradeaus -- nicht ueber Hindernisse" % action.range_tiles
	elif action.is_heal():
		what = "repariert %d" % action.heal_amount()
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
	if action.power > 0 and not action.is_heal():
		if action.energy_fraction >= 1.0:
			out.append("Reiner Energieschaden -- stark gegen Schilde.")
		elif action.energy_fraction > 0.0:
			out.append("%d %% Energieschaden -- gut gegen Schilde." % int(round(action.energy_fraction * 100.0)))
		else:
			out.append("Kinetischer Schaden -- stark gegen Integritaet, schwach gegen Schilde.")
	if action.push_tiles > 0:
		out.append("Stoesst das Ziel %d Feld(er) weg." % action.push_tiles)
	elif action.push_tiles < 0:
		out.append("Zieht das Ziel %d Feld(er) heran." % absi(action.push_tiles))
	if action.is_taunt():
		out.append("Provoziert: das Ziel muss %d Zuege lang diesen DROME angreifen." % action.taunt_turns)
	if action.requires_line_of_sight:
		out.append("Braucht freie Sicht aufs Ziel.")

	# Wann sie zum Zug kommt -- heute entscheidet das die KI.
	var cost: Array[String] = []
	if action.en_cost_now() > 0:
		cost.append("kostet %d Energie" % action.en_cost_now())
	if action.cooldown_now() > 0:
		cost.append("danach %d Zuege Pause" % action.cooldown_now())
	if action.is_attack():
		out.append("Einsatz: ein Angriff pro Zug und Waffe%s." %
			(", " + ", ".join(cost) if not cost.is_empty() else ""))
	else:
		out.append("Einsatz: hoechstens einmal pro Zug, wenn es sich lohnt%s." %
			(" -- " + ", ".join(cost) if not cost.is_empty() else ""))
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
			"trait": label = UiKit.label(text, UiKit.SMALL, UiKit.WARN)
			_: label = UiKit.label(text, UiKit.SMALL, UiKit.MUTED)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		into.add_child(label)
