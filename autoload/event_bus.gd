extends Node

## Signalknoten. Systeme reden hierueber miteinander, nicht ueber get_node().
##
## Der Grund ist nicht Eleganz: die Kampf-UI haengt an einem Dutzend Zustaenden,
## und jede direkte Knotenreferenz waere eine Stelle, die beim naechsten
## Szenenumbau bricht. Wer hier ein Signal ergaenzt, ergaenzt es nur hier.

# --- Kampfablauf ---
signal battle_started(seed_value: int)
signal battle_finished(outcome: int, cycles: int)
signal cycle_ended(cycle_count: int)

# --- Zug ---
signal turn_started(unit)
signal turn_ended(unit)
signal budgets_changed(unit)

# --- Einheiten ---
signal unit_moved(unit, from_tile: Vector2i, to_tile: Vector2i)
signal unit_damaged(unit, amount: int, source)
signal unit_healed(unit, amount: int, source)
signal unit_died(unit)

## Der TICK-Bus hat sich geaendert -- die Vorschau muss neu gerechnet werden.
## Wird nach jeder Aktion ausgeloest, die SPD oder tick beruehrt.
signal tick_bus_changed()

# --- Protokoll ---
signal log_message(text: String)


func log_line(text: String) -> void:
	log_message.emit(text)
