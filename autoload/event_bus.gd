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
## Ein Viruspuls hat alle Einheiten getroffen (Virusschaden, 14. Nov. 2026).
signal virus_pulsed

## Ein DROME hat eine Aktion ausgefuehrt (Angriff oder Faehigkeit) -- fuer
## Schussspuren und den Hinweis "Streusalve!" ueber der Figur.
signal action_used(unit, tile: Vector2i, action)

## Ein DROME holt zu einer Faehigkeit aus (Ausholzeit, 18. Nov. 2026): die
## Ansage laeuft ``seconds`` lang, dann folgt action_used mit der Wirkung.
signal ability_cast(unit, tile: Vector2i, action, seconds: float, target)

# --- Protokoll ---
signal log_message(text: String)


func log_line(text: String) -> void:
	log_message.emit(text)
