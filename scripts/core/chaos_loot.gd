class_name ChaosLoot
extends RefCounted

## Die reine Beute-Rechnung des Chaos-Virus.
##
## Keine Godot-Knoten, kein Roster, kein Zufall aus der Luft -- alles kommt als
## Argument herein, damit sich die Regel wie DromeBuild ohne laufende Szene
## testen laesst. Wer die Beute WIRKLICH vergibt (Instanzen anlegen, Pity
## fortschreiben, speichern), ist GameState.roll_chaos_loot(); diese Klasse sagt
## nur, WAS faellt.
##
## Die Stellschrauben stehen in data/config.json ("chaos") und nicht hier -- eine
## Beute-Kurve, die man nur durch Neukompilieren aendern kann, wird nicht getunt.


## Die Chance auf (mindestens) ein Beute-Teil aus dem Handicap:
##   chance = min(cap, base + handicap * gain)
## handicap 0 = volle Mannschaft (kaum Beute), ~1 = fast allein (viel Beute).
static func drop_chance(handicap: float) -> float:
	var c := Config.section("chaos")
	var base := float(c.get("loot_base", 0.15))
	var gain := float(c.get("loot_handicap_gain", 0.7))
	var cap := float(c.get("loot_cap", 0.9))
	return clampf(base + clampf(handicap, 0.0, 1.0) * gain, 0.0, cap)


## Wie viele Teile dieser Sieg abwirft (0..2).
##
## ``pity`` ist die Zahl der bisher erfolglosen Siege. Ab ``loot_pity_threshold``
## ist mindestens ein Teil GARANTIERT -- so kann eine Pechstraehne nicht ewig
## dauern. Ein zweites Teil faellt zusaetzlich mit ``chance * loot_second_factor``.
static func roll_count(handicap: float, pity: int, rng: RandomNumberGenerator) -> int:
	var c := Config.section("chaos")
	var threshold := int(c.get("loot_pity_threshold", 4))
	var chance := drop_chance(handicap)
	var first := (pity + 1 >= threshold) or (rng.randf() < chance)
	if not first:
		return 0
	var second := rng.randf() < chance * float(c.get("loot_second_factor", 0.4))
	return 2 if second else 1


## Waehlt ``count`` Beute-Teile aus dem Gegner-Pool (den Ausruestungs-Typen der
## besiegten Gegner). Ohne Wiederholung, solange der Pool reicht; ist er kleiner
## als ``count``, darf sich ein Typ wiederholen -- zwei gleiche Teile sind ein
## zulaessiger Besitz. Leerer Pool -> leere Beute.
static func pick(pool: Array, count: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	if pool.is_empty() or count <= 0:
		return out
	var bag: Array = pool.duplicate()
	for _i in count:
		if bag.is_empty():
			bag = pool.duplicate()
		var idx := rng.randi() % bag.size()
		out.append(bag[idx])
		bag.remove_at(idx)
	return out
