extends Node

## Signalknoten. Systeme reden hierueber miteinander, nicht ueber get_node().
##
## Der Grund ist nicht Eleganz: die Kampf-UI haengt an einem Dutzend Zustaenden,
## und jede direkte Knotenreferenz waere eine Stelle, die beim naechsten
## Szenenumbau bricht. Wer hier ein Signal ergaenzt, ergaenzt es nur hier.

# --- Kampfablauf ---
signal battle_started(seed_value: int)
signal battle_finished(outcome: int, seconds: int)

# --- Einheiten ---
signal unit_moved(unit, from_tile: Vector2i, to_tile: Vector2i)
signal unit_damaged(unit, amount: int, source)
signal unit_healed(unit, amount: int, source)
signal unit_died(unit)

## Ein DROME hat eine Aktion ausgefuehrt (Angriff oder Faehigkeit) -- fuer
## Schussspuren und den Hinweis "Streusalve!" ueber der Figur.
signal action_used(unit, tile: Vector2i, action)

# --- Protokoll ---
signal log_message(text: String)


func log_line(text: String) -> void:
	log_message.emit(text)
