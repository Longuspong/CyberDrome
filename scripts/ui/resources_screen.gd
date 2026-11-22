extends Control

## Tab "Fabrik" (22. Nov. 2026, Design-Canvas "Fuenf Tabs"): das kommende
## Ressourcen-System, eher fabrikartig -- Linien produzieren ueber Zeit, der
## Spieler sammelt ein. Noch nicht entschieden: welche Ressourcen, wie lange,
## was es kostet. Bis dahin ein Platzhalter mit dem, was geplant ist.

func _ready() -> void:
	var content := UiKit.page(self, "Fabrik", "", UiKit.TAB_RESOURCES, true)
	var slot := UiKit.header_slot(self)
	if slot != null:
		slot.add_child(Arcade.tilt(Arcade.tag(tr("KOMMT NOCH"), 12, 0.0), 2.0))
	content.add_child(UiKit.label(tr("Hier entstehen bald Ressourcen für Upgrades von DROMEs und "
		+ "Waffen: Linien produzieren über Zeit, du sammelst ein."), UiKit.BODY, UiKit.TEXT))
	for line in [[tr("LINIE 1"), tr("Ressource und Dauer noch offen")],
			[tr("LINIE 2"), tr("Ressource und Dauer noch offen")],
			[tr("LINIE 3"), tr("freischalten -- Kosten noch offen")]]:
		var card := Arcade.Card.new(Arcade.EMPTY_LINE, Color.TRANSPARENT, true)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		card.add_child(box)
		box.add_child(Arcade.label(str(line[0]), 15, Arcade.MUTED, "display"))
		box.add_child(Arcade.label(str(line[1]), 14, Arcade.MUTED))
		content.add_child(card)
