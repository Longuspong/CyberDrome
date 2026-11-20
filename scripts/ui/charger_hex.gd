class_name ChargerHex
extends Control

## Ein Charger als kleines Hexagon (Design-Canvas 20. Nov. 2026, Hangar ›
## Upgrade): sechs Phasen-Kristalle um einen Kern in der Farbe des
## ueberwiegenden Elements. Leere Felder gestrichelt; ohne Charger ein
## gestrichelter Platz.

var phases: Array = []
var empty_slot := false


func _init(phase_list: Array = [], edge: float = 168.0, is_empty: bool = false) -> void:
	phases = Charger.normalized(phase_list)
	empty_slot = is_empty
	custom_minimum_size = Vector2(edge, edge * ChargerCrafter.STAGE.y / ChargerCrafter.STAGE.x)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 6:
		var gem := PhaseGem.new("" if empty_slot else str(phases[i]), 80)
		gem.custom_minimum_size = Vector2.ZERO
		gem.name = "Gem%d" % i
		add_child(gem)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var k := size.x / ChargerCrafter.STAGE.x
		for i in 6:
			var gem := get_node("Gem%d" % i) as Control
			gem.position = ChargerCrafter.SLOT_POS[i] * k
			gem.size = Vector2(80, 69) * k
		queue_redraw()


func _draw() -> void:
	var k := size.x / ChargerCrafter.STAGE.x
	var c := Vector2(170, 147.5) * k
	var dom := "" if empty_slot else Charger.dominant(phases)
	var col := Charger.element_color(dom) if dom != "" else Arcade.EMPTY_LINE
	var outer := PhaseGem.hex(c, 332 * k, 287 * k)
	draw_colored_polygon(outer, Arcade.DEEP)
	outer.append(outer[0])
	if empty_slot:
		for i in 6:
			draw_dashed_line(outer[i], outer[i + 1], Arcade.EMPTY_LINE, 2.0, 6.0)
	else:
		draw_polyline(outer, col, 2.0)
	draw_colored_polygon(PhaseGem.hex(c, 100 * k, 87 * k), col if not empty_slot else Color("#3a1a6e"))
