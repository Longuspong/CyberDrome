extends Control

## Tab "Fabrik" -- herstellen (seit 22. Nov. 2026, Design-Canvas "CyberDrome
## Bildschirme", Vorschlag "ein Verb je Tab", vom Spieler abgesegnet). Drei
## Reiter in einer festen Zeile unter der Kopfzeile, der Inhalt scrollt:
##
##   linien   das kommende Ressourcen-System (Linien produzieren ueber Zeit) --
##            Platzhalter, Form noch offen
##   charger  Charger bauen (Rohling + Energy Phases, ChargerCrafter); fertige
##            Charger liegen im Inventar und werden auf der DROME-Seite
##            unter Waffe eingesetzt
##   dromes   neue DROMEs aus Baukernen (DromeForge)

## Oeffnet die Fabrik beim naechsten Aufbau in diesem Reiter.
static var _tab := "charger"

var _content: VBoxContainer
var _fixed: VBoxContainer


static func open_tab(tab: String) -> void:
	_tab = tab


func _ready() -> void:
	_content = UiKit.page(self, "Fabrik", "", UiKit.TAB_RESOURCES, true)
	# Der Schalter steht fest unter der Kopfzeile (scrollt nicht mit).
	var frame := _content.get_parent().get_parent().get_parent() as VBoxContainer
	var holder := MarginContainer.new()
	for side in ["left", "right"]:
		holder.add_theme_constant_override("margin_" + side, UiKit.PAD)
	holder.add_theme_constant_override("margin_top", 6)
	holder.add_theme_constant_override("margin_bottom", 6)
	_fixed = VBoxContainer.new()
	holder.add_child(_fixed)
	frame.add_child(holder)
	frame.move_child(holder, 1)
	_refresh()


func _refresh() -> void:
	if _tab not in ["linien", "charger", "dromes"]:
		_tab = "charger"
	UiKit.clear(_fixed)
	UiKit.clear(_content)
	var switch := UiKit.segmented([["linien", "Linien"], ["charger", "Charger"], ["dromes", "DROMEs"]],
		_tab, func(id):
			_tab = id
			Tile.clear_choice()
			_refresh(), true)
	switch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fixed.add_child(switch)
	match _tab:
		"linien": _lines()
		"dromes": DromeForge.add_to(_content, self)
		_:
			var crafter := ChargerCrafter.new()
			crafter.built.connect(_charger_built)
			_content.add_child(crafter)


## Ressourcen-Linien: noch nicht entschieden, bis dahin sagt die Seite, was kommt.
func _lines() -> void:
	_content.add_child(UiKit.label(tr("Hier entstehen bald Ressourcen für Level und Skilltrees von "
		+ "DROMEs und Waffen: Linien produzieren über Zeit, du sammelst ein."), UiKit.BODY, UiKit.TEXT))
	for line in [[tr("LINIE 1"), tr("Ressource und Dauer noch offen")],
			[tr("LINIE 2"), tr("Ressource und Dauer noch offen")],
			[tr("LINIE 3"), tr("freischalten -- Kosten noch offen")]]:
		var card := Arcade.Card.new(Arcade.EMPTY_LINE, Color.TRANSPARENT, true)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		card.add_child(box)
		box.add_child(Arcade.label(str(line[0]), 15, Arcade.MUTED, "display"))
		box.add_child(Arcade.label(str(line[1]), 14, Arcade.MUTED))
		_content.add_child(card)


## Nach dem Bauen: der neue Charger, dazu der Weg zum Einsetzen.
func _charger_built(charger: Dictionary) -> void:
	_refresh()
	var phases: Array = charger.get("phases", [])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for e in phases:
		if str(e) != "":
			row.add_child(PhaseGem.new(str(e), 40))
	var dom := Charger.dominant(phases)
	var lines: Array = [row]
	lines.append("Liegt jetzt im Inventar. Einsetzen: DROMEs › DROME antippen › Waffe.")
	if dom != "":
		lines.append(["Die Fähigkeit legt %s-Stapel an." % Charger.element_name(dom), UiKit.HEADING])
	# Bisher wirkt nur Feuer (CHARGER_KONZEPT 4) -- sonst sieht man im Kampf
	# nichts und haelt es fuer einen Fehler (24. Nov. 2026).
	var silent: Array = []
	for e in Charger.counts(phases):
		if str(e) != "" and not Charger.is_built(str(e)):
			silent.append(Charger.element_name(str(e)))
	if not silent.is_empty():
		lines.append(tr("%s: Stapel werden gezählt, wirken im Kampf aber noch nicht (bisher nur Feuer).")
			% ", ".join(silent))
	InfoPopup.open(self, Charger.display_name(phases).to_upper(), {"subtitle": "NEU IM INVENTAR",
		"lines": lines, "actions": [{"text": "Zu den DROMEs", "primary": true, "call": func():
			Fader.go("res://scenes/hangar.tscn")}]})
