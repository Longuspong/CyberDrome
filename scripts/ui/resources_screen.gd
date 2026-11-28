extends Control

## Tab "Fabrik" -- herstellen (seit 22. Nov. 2026, Design-Canvas "CyberDrome
## Bildschirme", Vorschlag "ein Verb je Tab", vom Spieler abgesegnet). Drei
## Reiter in einer festen Zeile unter der Kopfzeile, der Inhalt scrollt:
##
##   linien   die Fabrik-Platine (FactoryView, seit 23. Nov. 2026): Gebaeude
##            stellen Ressourcen her, die ins Lager (= Inventar) gehen
##   werkbank alles, was aus dem Lager entsteht (WorkbenchView, seit 24. Nov. 2026):
##            Charger (Rohling + ChargerCrafter) und DROMEs aus Teilen. Ersetzt
##            die frueheren Reiter Charger und DROMEs (DromeForge mit Baukernen).

## Oeffnet die Fabrik beim naechsten Aufbau in diesem Reiter.
static var _tab := "werkbank"

var _content: VBoxContainer
var _fixed: VBoxContainer
## Die Platine liegt ohne Scrollen ueber der ganzen Hoehe (28. Nov. 2026).
var _factory: FactoryView


static func open_tab(tab: String) -> void:
	# Alte Reiter (bis 24. Nov. 2026) fuehren in die Werkbank.
	if tab in ["charger", "dromes"]:
		WorkbenchView.category = tab
		WorkbenchView.selected = ""
		tab = "werkbank"
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
	if _tab not in ["linien", "werkbank"]:
		_tab = "werkbank"
	UiKit.clear(_fixed)
	UiKit.clear(_content)
	var switch := UiKit.segmented([["linien", "Platine"], ["werkbank", "Werkbank"]],
		_tab, func(id):
			_tab = id
			Tile.clear_choice()
			_refresh(), true)
	switch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fixed.add_child(switch)
	var scroller := _content.get_parent() as Control
	if _factory != null:
		_factory.queue_free()
		_factory = null
	scroller.visible = _tab != "linien"
	match _tab:
		"linien":
			_factory = FactoryView.new()
			scroller.get_parent().add_child(_factory)
		_:
			var bench := WorkbenchView.new()
			bench.charger_built.connect(_charger_built)
			_content.add_child(bench)


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
