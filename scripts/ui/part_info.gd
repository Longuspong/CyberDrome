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
	&"eq_plasma_blade": "Nahkampfklinge des Vireo: schnelle Schnitte, das Aufschlitzen macht das Ziel verwundbar.",
	&"eq_hammer": "Nahkampfwaffe des Molok: der Betäubungsschlag trifft mit der eigenen Integrität und heilt.",
	&"eq_deflector": "Schild zum Umschnallen: stößt zu und lädt dem Träger Schild auf, auch über das Maximum.",
	&"eq_rune_staff": "Energiestab auf mittlere Distanz. Der Vortex zieht Gegner zusammen und verlangsamt sie.",
	&"eq_rail_lance": "Scharfschützenwaffe mit der größten Reichweite.",
}

## Seit dem Echtzeit-Kampf zaehlen Bewegung (MOV) und Energie nicht mehr:
## SPD ist die Laufgeschwindigkeit, Faehigkeiten loesen nach ihrer Regel aus.
const STAT_LABELS := [
	["hp", "Integrität"], ["shield", "Schild"],
	["shield_pulse", "Schildpuls"], ["def", "Rüstung"], ["power", "Power"],
	["efficiency", "Effizienz (Statuseffekte)"],
	["spd", "Speed (Laufgeschwindigkeit)"], ["module_slots", "Modulplätze je Halter"],
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

	for text in traits(part):
		out.append([text, "trait"])

	if part.type == PartData.Type.EQUIPMENT:
		if part.actions.is_empty():
			out.append(["Passiv: wirkt immer, ohne eigene Aktion.", "note"])
		for action in part.actions:
			# Angriffe haben keinen eigenen Namen (6g) -- nur die Faehigkeit.
			var title: String = action.category_label() if action.is_attack() \
				else "%s (%s)" % [action.display_name, action.category_label()]
			out.append([title, "action"])
			for line in action_lines(action):
				out.append([line, "detail"])
	return out


## Besonderheiten, die keine Zahl im Werteblock sind.
static func traits(part: PartData) -> Array[String]:
	var out: Array[String] = []
	if part.hp_regen_pct > 0:
		out.append("Repariert jeden Puls (alle 3 s) %d %% der Integrität." % part.hp_regen_pct)
	match part.passive:
		"cyberspeed":
			var cs := Config.section("passives").get("cyberspeed", {}) as Dictionary
			out.append("Cyberspeed: jeder %d. Angriff gibt einen Stapel (höchstens %d), je Stapel +%d %% Angriffs- und Lauftempo. Jeder Angriff hält die Stapel %s s." % [
				int(cs.get("every", 3)), int(cs.get("max_stacks", 3)),
				int(round(float(cs.get("attack_speed", 0.1)) * 100.0)),
				ActionData._seconds(float(cs.get("seconds", 3.0)))])
		"safe_haven":
			var fo := Config.section("passives").get("safe_haven", {}) as Dictionary
			out.append("Safe Haven: Heilung, Regeneration und Schildgaben am Molok +%d %%." % int(round((float(fo.get("care_mult", 1.2)) - 1.0) * 100.0)))
		"echo":
			out.append("Echo: jede Fähigkeit wirkt zweimal, ihr Takt ist dafür 1,5-mal so lang (aufgerundet).")
		"focuslense":
			var fl := Config.section("passives").get("focuslense", {}) as Dictionary
			out.append("Focuslense: +%d %% kinetischer, -%d %% Energieschaden; das anvisierte Ziel (vom letzten Schuss getroffen) nimmt +%d %%." % [
				int(round((float(fl.get("kinetic_mult", 1.2)) - 1.0) * 100.0)),
				int(round((1.0 - float(fl.get("energy_mult", 0.3))) * 100.0)),
				int(round((float(fl.get("focus_mult", 1.2)) - 1.0) * 100.0))])
	return out


## Eine Aktion in Klartext, so wie sie im Kampf wirkt.
static func action_lines(action: ActionData) -> Array[String]:
	var out: Array[String] = []
	var reach := "Reichweite %d" % action.range_tiles
	if action.support == "self":
		reach = "auf sich selbst"
	elif action.range_tiles <= 1:
		reach = "Nahkampf (Reichweite 1)"
	var what := ""
	if action.is_move():
		what = "springt bis %d Felder geradeaus" % action.range_tiles
	elif action.power > 0:
		what = "Stärke %d" % action.power
	elif action.heal > 0 or action.shield_gain > 0:
		what = "Unterstützung"
	else:
		what = action.effect_summary()
	out.append("%s · %s" % [reach, what])

	match action.targeting:
		ActionData.Targeting.AOE_AROUND_TARGET:
			out.append("Fläche: trifft auch alle Felder im Umkreis %d um das Ziel." % action.aoe_radius)
		ActionData.Targeting.AOE_CROSS:
			out.append("Kreuz: trifft das Ziel und die vier geraden Nachbarfelder.")
	if action.power > 0:
		if action.energy_fraction >= 1.0:
			out.append("Reiner Energieschaden -- stark gegen Schilde.")
		elif action.energy_fraction > 0.0:
			out.append("%d %% Energieschaden -- gut gegen Schilde." % int(round(action.energy_fraction * 100.0)))
		else:
			out.append("Kinetischer Schaden -- stark gegen Integrität, schwach gegen Schilde.")
	if action.shots > 1 and action.salvo > 1:
		out.append("%d Salven zu je %d Schüssen (je 1/%d Schaden): erst aufs Ziel, dann auf den nächsten Gegner in Reichweite; ist nur einer da, alle auf ihn." % [action.shots, action.salvo, action.salvo])
	elif action.shots > 1:
		out.append("%d schnelle Treffer auf bis zu %d Gegner in Reichweite; ist nur einer da, trifft er ihn mehrfach." % [action.shots, action.shots])
	if action.gather:
		out.append("Zieht die Gegner im Umkreis %d zum Ziel heran." % action.aoe_radius)
	if action.delay > 0.0:
		out.append("Danach schlägt nach %s s eine Schockwelle zu." % ActionData._seconds(action.delay))
	if not action.status.is_empty():
		out.append("Getroffene: %s." % action.status_text())
	if action.heal > 0:
		out.append("Repariert %d Integrität beim Verbündeten mit dem geringsten Anteil; ist niemand verletzt, schießt er auf Gegner." % action.heal)
	if action.shield_gain > 0:
		var who := "dem Träger" if action.support == "self" \
			else "dem am stärksten verletzten Verbündeten"
		out.append("Gibt %s %d Schild (auch über das Maximum)." % [who, action.shield_gain])
	if action.hp_scaling > 0.0:
		out.append("Dazu %d %% der eigenen maximalen Integrität als Schaden." % int(round(action.hp_scaling * 100.0)))
	if action.lifesteal > 0.0:
		out.append("Heilt den Träger um %d %% des Schadens." % int(round(action.lifesteal * 100.0)))
	if action.push_tiles > 0:
		out.append("Stößt das Ziel %d Feld(er) weg." % action.push_tiles)
	elif action.push_tiles < 0:
		out.append("Zieht das Ziel %d Feld(er) heran." % absi(action.push_tiles))

	# Wann sie kommt: Angriffe nach ihrem Intervall, Faehigkeiten nach ihrem
	# Takt (so heisst die Ausloesevoraussetzung seit 7. Nov. 2026).
	if action.is_attack():
		out.append("Schießt alle %s s." % ActionData._seconds(action.interval))
	elif action.trigger_kind != "":
		out.append("Takt: %s." % action.trigger_text())
		if action.trigger_kind == "attacks":
			out.append("Dieser Angriff ersetzt den normalen Schuss.")
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
