class_name EnemyGenerator
extends RefCounted

## Wuerfelt das Gegnersquad fuer den Chaos-Virus.
##
## Keine Godot-Knoten, ohne Szene testbar. Derselbe Seed ergibt exakt
## dieselben Gegner -- zusammen mit Karte und Mutator macht das einen Kampf
## reproduzierbar, und im Playtesting ist das Gold wert.
##
## Die Slots werden PRO CHASSIS gewuerfelt, nicht gegen eine feste Sechserliste:
## der Molok hat drei Ausruestungsanker, der Strix genau einen. Ein Generator,
## der von zwei Waffen und einem Modul ausgeht, baut auf dem Strix Aufbauten,
## die es nicht geben kann.

var rng := RandomNumberGenerator.new()

## Wie oft musste das Squad neu gewuerfelt werden, bis der Kampfwert passte?
var attempts_used: int = 0
var achieved_power: float = 0.0


func _init(battle_seed: int = 0) -> void:
	rng.seed = battle_seed


## Erzeugt ``count`` Gegner, deren Gesamtstaerke nahe an ``target_power``
## liegt. Innerhalb der Toleranz wird sofort genommen, sonst gewinnt der beste
## Treffer aus allen Versuchen.
func generate(count: int, target_power: float) -> Array:
	var tolerance := Config.get_float("power_tolerance", 0.12)
	var attempts := Config.get_int("power_attempts", 200)
	var names := _draw_names(count)

	var best: Array = []
	var best_error := INF

	for attempt in attempts:
		attempts_used = attempt + 1
		var squad: Array = []
		for i in count:
			squad.append(_random_build(names[i]))
		var power := DromeBuild.squad_power(squad)
		var error: float = absf(power - target_power)
		if error < best_error:
			best_error = error
			best = squad
			achieved_power = power
		if target_power <= 0.0 or error / target_power <= tolerance:
			return squad

	return best


# ---------------------------------------------------------------------------
# Ein einzelner Aufbau
# ---------------------------------------------------------------------------

func _random_build(display_name: String) -> DromeBuild:
	var attempts := Config.get_int("build_attempts", 50)
	for _i in attempts:
		var build := _roll(display_name)
		# Die Waffe wird hier SEPARAT verlangt. Fuer den Spieler ist ein Aufbau
		# ohne Waffe eine zulaessige Entscheidung (DromeBuild.structural_problems),
		# fuer einen Gegner waere sie keine: ein Squad, das nichts anrichten kann,
		# laeuft das Gefecht bis ans ``cycle_limit`` und endet unentschieden. Der
		# Spieler haette dann einen Kampf verloren bekommen, den der Wuerfel
		# entschieden hat.
		if build.is_valid() and not build.weapons().is_empty():
			return build
	return _fallback(display_name)


func _roll(display_name: String) -> DromeBuild:
	# Der Rahmen ist eine Huelle: Kopf und Fuesse stammen aus DEMSELBEN Set wie
	# das Chassis (GAME_DESIGN §9). Frei gewuerfelt entstuenden gemischte Rahmen,
	# die der Aufbau ablehnt. Der Kern dagegen ist universal -- er wird weiter
	# frei gewuerfelt.
	var chassis: PartData = _pick(PartDB.of_type(PartData.Type.BODY))
	var assignment := {
		"body": chassis.id,
		"head": _frame_mate(chassis.set_id, PartData.Type.HEAD).id,
		"feet": _frame_mate(chassis.set_id, PartData.Type.FEET).id,
		"core": _pick(PartDB.of_type(PartData.Type.CORE)).id,
	}

	# Der erste Ausruestungsslot bekommt garantiert eine Waffe -- ein Aufbau
	# ohne Waffe ist per Regel ungueltig, und ihn 50 Mal wegzuwerfen waere
	# Rechenzeit fuer nichts.
	var slots: Array[String] = chassis.equip_slots()
	var weapon_placed := false
	for slot in slots:
		var candidates := PartDB.equipment_for(chassis, slot)
		if candidates.is_empty():
			continue
		if not weapon_placed:
			var weapons: Array = candidates.filter(
				func(part): return part.category == "weapon")
			if not weapons.is_empty():
				assignment[slot] = _pick(weapons).id
				weapon_placed = true
				continue
		# Die weiteren Slots nur mit 70 Prozent Wahrscheinlichkeit -- ein
		# vollbestueckter Gegner soll die Ausnahme sein, nicht die Regel.
		if rng.randf() < 0.7:
			assignment[slot] = _pick(candidates).id

	return DromeBuild.create(display_name, assignment)


## Notfall-Aufbau, wenn 50 Wuerfe nichts Gueltiges ergeben haben. Fest
## definiert und garantiert baubar -- besser ein langweiliger Gegner als
## ein Kampf, der nicht startet.
func _fallback(display_name: String) -> DromeBuild:
	var build := DromeBuild.create(display_name, {
		"body": &"scout_body", "head": &"scout_head",
		"feet": &"scout_feet", "core": &"scout_core",
		"equip_left": &"eq_pulse_blaster",
	})
	if not build.is_valid():
		push_error("EnemyGenerator: selbst der Notfall-Aufbau ist ungueltig: %s"
			% ", ".join(build.validate()))
	return build


# ---------------------------------------------------------------------------
# Namen
# ---------------------------------------------------------------------------

func _draw_names(count: int) -> Array[String]:
	var pool: Array = Config.get_value("enemy_names",
		["VEX", "NUL", "KRA", "ORB", "ZYN", "HEX"])
	var names: Array[String] = []
	var used := {}
	for _i in count:
		var label := ""
		for _try in 20:
			label = "%s-%d" % [pool[rng.randi() % pool.size()], rng.randi_range(1, 9)]
			if not used.has(label):
				break
		used[label] = true
		names.append(label)
	return names


func _pick(pool: Array):
	return pool[rng.randi() % pool.size()]


## Das Rahmenteil eines Typs (Kopf/Fuesse) aus demselben Set wie das Chassis --
## die drei bilden gemeinsam die Huelle (GAME_DESIGN §9).
func _frame_mate(set_id: String, type: int) -> PartData:
	for part in PartDB.of_type(type):
		if part.set_id == set_id:
			return part
	return null
