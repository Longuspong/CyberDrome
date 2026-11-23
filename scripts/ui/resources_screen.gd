extends Control

## Tab "Fabrik" -- herstellen (seit 22. Nov. 2026, Design-Canvas "CyberDrome
## Bildschirme", Vorschlag "ein Verb je Tab", vom Spieler abgesegnet). Drei
## Reiter in einer festen Zeile unter der Kopfzeile, der Inhalt scrollt:
##
##   linien   die Fabrik-Platine (FactoryView, seit 23. Nov. 2026): Gebaeude
##            stellen Ressourcen her, die ins Lager (= Inventar) gehen
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


## Die Fabrik-Platine (docs/FACTORY_KONZEPT.md).
func _lines() -> void:
	_content.add_child(FactoryView.new())


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
	InfoPopup.open(self, Charger.display_name(phases).to_upper(), {"subtitle": "NEU IM INVENTAR",
		"lines": lines, "actions": [{"text": "Zu den DROMEs", "primary": true, "call": func():
			Fader.go("res://scenes/hangar.tscn")}]})
