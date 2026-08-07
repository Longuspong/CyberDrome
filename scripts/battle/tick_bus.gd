class_name TickBus
extends RefCounted

## Die Initiativleiste. Herzstueck des Kampfes.
##
## Reine Logik: keine Godot-Knoten, keine Animation, kein delta. Ganzzahlig
## und deterministisch -- derselbe Ausgangszustand ergibt immer dieselbe
## Zugreihenfolge.
##
## ### Der TICK-Bus wird beim Zyklusende NIEMALS zurueckgesetzt
##
## Das Zyklusende ist reine Buchhaltung: es setzt die has_acted-Flags zurueck
## und sonst gar nichts. Die tick-Werte laufen ununterbrochen weiter ueber
## alle Zyklen hinweg.
##
## Steht ein DROME am Ende von Zyklus 1 bei 99 ticks, ist er der erste Zug in
## Zyklus 2 -- voellig unabhaengig davon, wer Zyklus 1 eroeffnet hat. Die
## Zugreihenfolge ist von Zyklus zu Zyklus unterschiedlich, und das ist der
## Punkt.
##
## Es gibt im gesamten Code genau EINE Stelle, an der tick verringert wird:
## finish_turn(). Wer eine zweite findet, hat einen Bug.

## Ein DROME zieht, sobald sein tick diese Schwelle erreicht.
const DEFAULT_THRESHOLD := 100

## Selbst ein bis zur Unkenntlichkeit verlangsamter DROME fuellt pro Tick
## mindestens 1 -- sonst haengt die Schleife, sobald ein Statuseffekt SPD
## unter null zieht. Eine Bremse, keine Spielregel.
const MIN_EFFECTIVE_SPD := 1


class Entry extends RefCounted:
	var unit_id
	var spd: int = 1
	var alive: bool = true
	var tick: int = 0
	var has_acted: bool = false

	func effective_spd() -> int:
		return maxi(TickBus.MIN_EFFECTIVE_SPD, spd)

	func copy() -> Entry:
		var other := Entry.new()
		other.unit_id = unit_id
		other.spd = spd
		other.alive = alive
		other.tick = tick
		other.has_acted = has_acted
		return other


var threshold: int = DEFAULT_THRESHOLD
var cycle_count: int = 1

var _entries: Array[Entry] = []


func _init(tick_threshold: int = 0) -> void:
	threshold = tick_threshold if tick_threshold > 0 \
		else Config.get_int("tick_threshold", DEFAULT_THRESHOLD)


func add_unit(unit_id, spd: int) -> void:
	var entry := Entry.new()
	entry.unit_id = unit_id
	entry.spd = spd
	_entries.append(entry)


func entry_for(unit_id) -> Entry:
	for entry in _entries:
		if entry.unit_id == unit_id:
			return entry
	return null


func set_spd(unit_id, spd: int) -> void:
	var entry := entry_for(unit_id)
	if entry != null:
		entry.spd = spd


func set_alive(unit_id, alive: bool) -> void:
	var entry := entry_for(unit_id)
	if entry != null:
		entry.alive = alive


## Overdrive und Verwandtes: schiebt den Bus direkt an, ohne einen Zug zu
## verbrauchen. Nur hier wird tick ERHOEHT ausserhalb der Tick-Schleife.
func add_tick(unit_id, amount: int) -> void:
	var entry := entry_for(unit_id)
	if entry != null:
		entry.tick += amount


func living() -> Array[Entry]:
	var out: Array[Entry] = []
	for entry in _entries:
		if entry.alive:
			out.append(entry)
	return out


func tick_of(unit_id) -> int:
	var entry := entry_for(unit_id)
	return entry.tick if entry != null else 0


# ---------------------------------------------------------------------------
# Zugreihenfolge
# ---------------------------------------------------------------------------

## Wer ist als Naechstes dran? Laesst den Bus so lange laufen, bis mindestens
## einer die Schwelle erreicht, und liefert dann den Hoechsten.
##
## Veraendert den Zustand (die tick-Werte laufen ja weiter). Fuer die Vorschau
## gibt es preview(), die auf einer Kopie arbeitet.
func advance() -> Variant:
	var pool := living()
	if pool.is_empty():
		return null

	# Solange kein lebender DROME die Schwelle erreicht: alle fuellen auf.
	var guard := 0
	while not _anyone_ready(pool):
		for entry in pool:
			entry.tick += entry.effective_spd()
		guard += 1
		if guard > threshold * 10:
			push_error("TickBus: niemand erreicht die Schwelle. SPD-Werte pruefen.")
			return null

	return _highest(pool).unit_id


func _anyone_ready(pool: Array[Entry]) -> bool:
	for entry in pool:
		if entry.tick >= threshold:
			return true
	return false


## Hoechster tick. Gleichstand in dieser Reihenfolge:
##   1. Wer in diesem Zyklus noch nicht gezogen hat, geht vor.
##   2. Hoeherer SPD.
##   3. Niedrigere unit_id -- stabil, damit nichts flackert.
func _highest(pool: Array[Entry]) -> Entry:
	var best: Entry = null
	for entry in pool:
		if entry.tick < threshold:
			continue
		if best == null or _outranks(entry, best):
			best = entry
	return best


func _outranks(a: Entry, b: Entry) -> bool:
	if a.tick != b.tick:
		return a.tick > b.tick
	if a.has_acted != b.has_acted:
		return not a.has_acted
	if a.spd != b.spd:
		return a.spd > b.spd
	return str(a.unit_id) < str(b.unit_id)


## Nach dem Zug. Die EINZIGE Stelle, an der tick verringert wird.
##
## Der Ueberschuss wird uebertragen, nicht auf 0 gesetzt -- das ist der Grund,
## warum SPD sich lohnt.
##
## Rueckgabe: true, wenn dieser Zug den Zyklus beendet hat.
func finish_turn(unit_id) -> bool:
	var entry := entry_for(unit_id)
	if entry == null:
		return false
	entry.tick -= threshold
	entry.has_acted = true
	return _close_cycle_if_done()


## Zyklusende ist reine Buchhaltung: NUR die Flags fallen, die tick-Werte
## bleiben unangetastet.
func _close_cycle_if_done() -> bool:
	var pool := living()
	if pool.is_empty():
		return false
	for entry in pool:
		if not entry.has_acted:
			return false
	for entry in pool:
		entry.has_acted = false
	cycle_count += 1
	return true


# ---------------------------------------------------------------------------
# Vorschau
# ---------------------------------------------------------------------------

## Die naechsten ``count`` Zuege. Simuliert die obige Schleife auf einer KOPIE
## der tick-Werte -- der echte Zustand darf dabei nie veraendert werden.
##
## Massgeblich fuer die Reihenfolge ist diese Queue, nicht die Balkenfuellung
## in der UI. Widersprechen sich beide, ist die Queue richtig und der Balken
## hat einen Bug.
func preview(count: int = 0) -> Array:
	if count <= 0:
		count = Config.get_int("tick_queue_length", 8)

	var shadow := TickBus.new(threshold)
	for entry in _entries:
		shadow._entries.append(entry.copy())
	shadow.cycle_count = cycle_count

	var order: Array = []
	for _i in count:
		var next = shadow.advance()
		if next == null:
			break
		order.append(next)
		shadow.finish_turn(next)
	return order


## Zustand fuer die Balkenanzeige. Reine Ablesung, keine Regel.
func bar_state(unit_id) -> Dictionary:
	var entry := entry_for(unit_id)
	if entry == null:
		return {}
	return {
		"tick": entry.tick,
		"threshold": threshold,
		"fill": clampf(float(entry.tick) / float(threshold), 0.0, 1.0),
		"carry": maxi(0, entry.tick - threshold),
		"has_acted": entry.has_acted,
	}


func _to_string() -> String:
	var parts: Array[String] = []
	for entry in _entries:
		parts.append("%s:%d%s" % [entry.unit_id, entry.tick,
			"" if entry.alive else "+"])
	return "TickBus(Zyklus %d, %s)" % [cycle_count, " ".join(parts)]
