class_name WeaponCard
extends RefCounted

## Die Popup-Kachel einer Waffe (Wunsch des Spielers, 7. Nov. 2026).
##
## Oeffnet sich, wenn man das Bild einer Waffe antippt -- im Hangar-Umbau und
## im Zwischenstopp. Aufbau:
##
##   +-------+  Name
##   | Bild  |  [Schwert] 12   [>>] 1,4 s   [->] 3
##   +-------+  (Angriff: Schaden mit Art, Tempo, Reichweite)
##   [Blitz] Faehigkeitsname     [Zahnrad] 3.  bzw. [Uhr] 3 s
##   Kurzbeschreibung
##   (Hinweiszeile: Klartext zum zuletzt angetippten Symbol)
##   Knoepfe
##
## Alles Wiederkehrende steht als Symbol da (StatIcon); ein Tipp auf ein
## Symbol schreibt seinen Klartext in die Hinweiszeile. So bleibt die Kachel
## kurz, und nichts bleibt unbestimmt.

const PICTURE_EDGE := 84.0
const ICON_EDGE := 22.0


## Oeffnet die Kachel ueber ``host`` (ein Control ueber den ganzen Schirm).
## ``extra`` (optional) bekommt die VBox der Kachel und kann Zeilen anhaengen
## (Wertaenderung, "ersetzt X"). ``buttons``: je Knopf
## {"text", "primary", "disabled", "on": Callable} -- nach dem Druck schliesst
## die Kachel, dann wird ``on`` gerufen. ``compare``: die Waffe, die dafuer
## weichen wuerde -- die Balken zeigen dann den Unterschied. Gibt die Ebene
## zurueck.
static func open(host: Control, part: PartData, extra: Callable = Callable(),
		buttons: Array = [], compare: PartData = null) -> CanvasLayer:
	# Eigene Zeichenebene: die DROME-Bilder darunter sortieren ihre Teile mit
	# z_index und laegen sonst ueber einer normalen Ueberlagerung.
	var layer := CanvasLayer.new()
	layer.layer = 20
	host.add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(shade)
	# Tipp neben die Kachel: schliessen.
	shade.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and not event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			layer.queue_free())

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(center)
	var panel := PanelContainer.new()
	var style := UiKit.card_style(true)
	style.bg_color = Color(UiKit.CARD, 1.0)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var width := minf(420.0, host.get_viewport_rect().size.x - 2.0 * UiKit.PAD)
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var hint := UiKit.label("Symbol antippen: Erklaerung", UiKit.SMALL, UiKit.MUTED)
	fill(box, part, hint, compare)
	if extra.is_valid():
		extra.call(box)
	box.add_child(hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for spec in buttons:
		var button := UiKit.button(str(spec.get("text", "")), bool(spec.get("primary", false)))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = bool(spec.get("disabled", false))
		var on: Callable = spec.get("on", Callable())
		button.pressed.connect(func():
			layer.queue_free()
			if on.is_valid():
				on.call())
		row.add_child(button)
	var close := UiKit.button("Schliessen")
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(func(): layer.queue_free())
	row.add_child(close)
	return layer


## Der Inhalt der Kachel ohne Ebene und Knoepfe -- auch fuer Tests.
static func fill(box: VBoxContainer, part: PartData, hint: Label, compare: PartData = null) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	var picture := SlotShape.new(part.mount_class, UiKit.part_texture(part), PICTURE_EDGE)
	picture.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(picture)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	top.add_child(right)
	right.add_child(UiKit.label(part.display_name, UiKit.H2))
	right.add_child(UiKit.label(SlotRules.class_label(part.mount_class), UiKit.SMALL,
		_class_color(part.mount_class)))

	var attack: ActionData = null
	var abilities: Array = []
	for action in part.actions:
		if action.is_attack() and attack == null:
			attack = action
		elif not action.is_attack():
			abilities.append(action)

	# Werte am Teil selbst (Deflektor DEF +5).
	var extras := _chip_row(right)
	if part.def != 0:
		extras.add_child(_chip("def", "%+d" % part.def, hint, "DEF %+d" % part.def))
	if part.shield != 0:
		extras.add_child(_chip("shield", "%+d" % part.shield, hint, "Schild %+d" % part.shield))
	if extras.get_child_count() == 0:
		extras.queue_free()
	# Der Bonus-Wert der Waffe fuer den Traeger (8. Nov. 2026).
	var bonus := bonus_text(part)
	if bonus != "":
		right.add_child(UiKit.label("Bonus: " + bonus, UiKit.SMALL, UiKit.GOOD))

	# Der Angriff als Symbol + Balken (Wunsch des Spielers, 10. Nov. 2026):
	# hinter jedem Symbol sein Wert, vergleichbar -- mit ``compare`` gegen die
	# Waffe, die gerade im Halter steckt.
	var other := _first_attack(compare)
	if attack != null:
		for row in attack_bars(attack, other, hint):
			box.add_child(row)

	for ability in abilities:
		box.add_child(HSeparator.new())
		var head := _chip_row(box)
		head.add_child(_chip("ability", "", hint, "Faehigkeit"))
		var name := UiKit.label(ability.display_name, UiKit.BODY, UiKit.ACCENT)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name)
		var takt := takt_chip(ability)
		if not takt.is_empty():
			head.add_child(_chip(takt[0], takt[1], hint, "Takt: %s" % ability.trigger_text()))
		var rival: ActionData = null
		if compare != null:
			for action in compare.actions:
				if not action.is_attack() and rival == null:
					rival = action
		for row in ability_bars(ability, rival, hint):
			box.add_child(row)
		# Was schon als Balken dasteht, kommt nicht nochmal als Symbol.
		var shown_as_bar := ["kinetic", "energy"]
		if ability.power > 0 and ability.support != "self" and not ability.is_move():
			shown_as_bar.append("range")
		var effects := attack_chips(ability).filter(
			func(spec): return spec[0] not in shown_as_bar)
		if not effects.is_empty():
			var row := _chip_row(box)
			for spec in effects:
				row.add_child(_chip(spec[0], spec[1], hint, spec[2]))
		var text := short_text(ability)
		if ability.damage_pct > 0.0:
			text = ("%d %% des Waffenschadens. " % int(round(ability.damage_pct * 100.0))) + text
		if text != "":
			box.add_child(UiKit.label(text, UiKit.SMALL, Color(0.9, 0.93, 1.0)))

	for line in PartInfo.traits(part):
		box.add_child(UiKit.label(line, UiKit.SMALL, UiKit.WARN))


static func _first_attack(part: PartData) -> ActionData:
	if part == null:
		return null
	for action in part.actions:
		if action.is_attack():
			return action
	return null


## Volle Balken in der Waffen-Karte: Schaden je Treffer, Angriffe je Sekunde,
## Reichweite -- etwa das Hoechste, was eine Waffe erreicht.
const BAR_DAMAGE := 30.0
const BAR_RATE := 1.25
const BAR_RANGE := 8.0


## Die Zeilen "Symbol + Balken + Wert" eines Angriffs: Schaden, Tempo,
## Reichweite (und Reparatur). ``other``: der Angriff zum Vergleich oder null.
static func attack_bars(attack: ActionData, other: ActionData, hint: Label) -> Array:
	var rows: Array = []
	if attack.power > 0:
		var type := "energy" if attack.energy_fraction >= 0.5 else "kinetic"
		var damage := float(attack.power * attack.shots)
		var before := float(other.power * other.shots) if other != null else -1.0
		var shown := str(attack.power) + (" x%d" % attack.shots if attack.shots > 1 else "")
		rows.append(_bar_row(type, "Schaden", damage, BAR_DAMAGE, before,
			shown + _delta(damage, before), hint, attack_chips(attack)[0][2]))
	if attack.heal > 0:
		rows.append(_bar_row("heal", "Reparatur", float(attack.heal), BAR_DAMAGE,
			float(other.heal) if other != null else -1.0, "", hint,
			"Repariert %d Integritaet" % attack.heal))
	if attack.interval > 0.0:
		# Der Balken zeigt Angriffe je Sekunde (laenger = schneller), der Text
		# die Sekunden zwischen zwei Angriffen.
		var rate := 1.0 / attack.interval
		var before := 1.0 / other.interval if other != null and other.interval > 0.0 else -1.0
		var shown := "%s s" % ActionData._seconds(attack.interval)
		if other != null and not is_equal_approx(other.interval, attack.interval):
			shown += " (%s)" % ("%+.1f" % (attack.interval - other.interval)).replace(".", ",")
		rows.append(_bar_row("speed", "Tempo", rate, BAR_RATE, before, shown, hint,
			"Greift alle %s s an" % ActionData._seconds(attack.interval)))
	if attack.support != "self":
		var reach := float(attack.range_tiles)
		var before := float(other.range_tiles) if other != null else -1.0
		rows.append(_bar_row("range", "Reichweite", reach, BAR_RANGE, before, "", hint,
			"Reichweite %d%s" % [attack.range_tiles, " (Nahkampf)" if attack.range_tiles <= 1 else ""]))
	return rows


## Die Balken einer Faehigkeit: ihr Schaden (oder ihre Reparatur / ihr Schild).
static func ability_bars(ability: ActionData, other: ActionData, hint: Label) -> Array:
	var rows: Array = []
	if ability.power > 0:
		var type := "energy" if ability.energy_fraction >= 0.5 else "kinetic"
		var damage := float(ability.power * ability.shots)
		var before := float(other.power * other.shots) if other != null else -1.0
		var shown := str(ability.power) + (" x%d" % ability.shots if ability.shots > 1 else "")
		rows.append(_bar_row(type, "Schaden", damage, BAR_DAMAGE, before,
			shown + _delta(damage, before), hint, attack_chips(ability)[0][2]))
	if ability.support != "self" and not ability.is_move() and ability.power > 0:
		rows.append(_bar_row("range", "Reichweite", float(ability.range_tiles), BAR_RANGE,
			float(other.range_tiles) if other != null else -1.0, "", hint,
			"Reichweite %d" % ability.range_tiles))
	return rows


## " (+3)" / " (-2)" hinter einem Wert, leer ohne Vergleich oder Unterschied.
static func _delta(now: float, before: float) -> String:
	if before < 0.0 or is_equal_approx(now, before):
		return ""
	return " (%+d)" % int(round(now - before))


## Eine Zeile: antippbares Symbol, dahinter der Balken mit Wert.
static func _bar_row(kind: String, name: String, value: float, scale: float, before: float,
		shown: String, hint: Label, title: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_chip(kind, "", hint, title))
	var bar := StatBar.custom(name, value, scale, StatIcon.COLORS.get(kind, UiKit.ACCENT),
		before, shown)
	bar.name_width = 84.0
	row.add_child(bar)
	return row


## Was die Waffe dem Traeger gibt: "Speed +2", "Power +10 %" ...
static func bonus_text(part: PartData) -> String:
	var out: Array[String] = []
	if part.hp != 0:
		out.append("Integritaet %+d" % part.hp)
	if part.shield != 0:
		out.append("Schild %+d" % part.shield)
	if part.shield_pulse != 0:
		out.append("Schildpuls %+d" % part.shield_pulse)
	if part.def != 0:
		out.append("Ruestung %+d" % part.def)
	if part.spd != 0:
		out.append("Speed %+d" % part.spd)
	if part.power != 0:
		out.append("Power %+d (%+d %%)" % [part.power, part.power * 10])
	return ", ".join(out)


## Die Symbol-Werte einer Aktion: [art, wert, klartext] -- Schaden mit Art,
## Tempo (nur Angriffe), Reichweite, Flaeche, Reparatur, Schild.
static func attack_chips(action: ActionData) -> Array:
	var out: Array = []
	if action.power > 0:
		var type := "energy" if action.energy_fraction >= 0.5 else "kinetic"
		var what := "Energieschaden" if type == "energy" else "kinetischer Schaden"
		var value := str(action.power)
		if action.shots > 1:
			value += " x%d" % action.shots
		if action.energy_fraction > 0.0 and action.energy_fraction < 1.0:
			var e := int(round(action.power * action.energy_fraction))
			what = "%d kinetisch + %d Energie" % [action.power - e, e]
		out.append([type, value, "%s, Staerke %d%s" % [what, action.power,
			(" -- %d Treffer" % action.shots) if action.shots > 1 else ""]])
	if action.heal > 0:
		out.append(["heal", str(action.heal), "Repariert %d Integritaet" % action.heal])
	if action.shield_gain > 0:
		out.append(["shield", "+%d" % action.shield_gain, "Gibt %d Schild" % action.shield_gain])
	if action.is_attack():
		out.append(["speed", "%s s" % ActionData._seconds(action.interval),
			"Greift alle %s s an" % ActionData._seconds(action.interval)])
	if action.support != "self" and not action.is_move():
		out.append(["range", str(action.range_tiles),
			"Reichweite %d%s" % [action.range_tiles,
				" (Nahkampf)" if action.range_tiles <= 1 else ""]])
	if action.aoe_radius > 0:
		out.append(["area", str(action.aoe_radius), "Flaeche: Umkreis %d" % action.aoe_radius])
	return out


## Das Takt-Symbol einer Faehigkeit: Zahnrad mit "3." (jeder 3. Angriff),
## Uhr mit "3 s", zwei Punkte fuer "Gegner daneben".
static func takt_chip(ability: ActionData) -> Array:
	match ability.trigger_kind:
		"attacks": return ["hits", "%d." % int(ability.trigger_every)]
		"time": return ["time", "%s s" % ActionData._seconds(ability.trigger_every)]
		"adjacent": return ["adjacent", ""]
	return []


## Die Kurzbeschreibung einer Faehigkeit -- was nicht schon als Symbol dasteht.
static func short_text(action: ActionData) -> String:
	var parts: Array[String] = []
	if action.is_move():
		parts.append("springt bis %d Felder geradeaus weg" % action.range_tiles)
	if action.shield_mult > 1.0:
		parts.append("%d %% Schaden am Schild" % int(round(action.shield_mult * 100.0)))
	if action.shots > 1:
		parts.append("trifft bis zu %d Gegner" % action.shots)
	if action.gather:
		parts.append("zieht die Gegner zum Ziel")
	if action.delay > 0.0:
		parts.append("Schockwelle nach %s s" % ActionData._seconds(action.delay))
	if not action.status.is_empty():
		parts.append(action.status_text())
	if action.push_tiles > 0:
		parts.append("stoesst %d Feld weg" % action.push_tiles)
	elif action.push_tiles < 0:
		parts.append("zieht %d Feld heran" % absi(action.push_tiles))
	if action.heal > 0:
		parts.append("beim Verbuendeten mit dem geringsten Anteil")
	if action.shield_gain > 0:
		parts.append("fuer sich selbst, auch ueber das Maximum" if action.support == "self"
			else "fuer den am staerksten verletzten Verbuendeten")
	if action.trigger_kind == "attacks":
		parts.append("ersetzt diesen Angriff")
	if parts.is_empty():
		return ""
	var text := ", ".join(parts)
	return text.substr(0, 1).to_upper() + text.substr(1) + "."


static func _chip_row(parent: Control) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 4)
	parent.add_child(row)
	return row


## Symbol + Wert. Antippen schreibt den Klartext in die Hinweiszeile.
static func _chip(kind: String, value: String, hint: Label, title: String) -> Control:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 4)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.tooltip_text = "%s\n%s" % [title, StatIcon.explain(kind)]
	var icon := StatIcon.new(kind, ICON_EDGE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(icon)
	if value != "":
		var label := UiKit.label(value, UiKit.BODY)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(label)
	chip.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and not event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT and hint != null:
			hint.text = "%s -- %s" % [title, StatIcon.explain(kind)]
			hint.modulate = Color.WHITE)
	return chip


static func _class_color(kind: String) -> Color:
	match kind:
		"light": return UiKit.GOOD
		"medium": return UiKit.WARN
		"heavy": return UiKit.BAD
	return UiKit.ACCENT
