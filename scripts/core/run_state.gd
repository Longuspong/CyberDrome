class_name RunState
extends RefCounted

## Ein Lauf (Roguelike): eine Folge von Autokaempfen mit begrenzten Leben.
##
## Reine Logik -- keine Szene, kein Zufall aus der Luft. Alles haengt am Seed
## des Laufs: derselbe Seed ergibt dieselben Kaempfe und dieselben
## Belohnungen, damit sich ein Lauf nachspielen und testen laesst.
##
## ### Der Bogen
##
##   * Start mit zwei schwach bestueckten DROMEs -- je eine Waffe, die
##     uebrigen Halter frei. Die freien Halter sind der Platz fuer Beute.
##   * Vor jedem Kampf steht fest, WO und UNTER WELCHER REGEL gekaempft wird
##     (Region, Mutator) und wie stark der Gegner ist. Im Autokampf greift man
##     nicht mehr ein; die Vorschau ist der Ort, an dem man plant.
##   * Die Gegnerstaerke folgt einer FESTEN Kurve, nicht dem eigenen Aufbau.
##     Wuchse sie mit, waere jede Belohnung wertlos -- der Gegner holte sie
##     sofort wieder ein.
##   * Sieg: eine von drei Belohnungen. Niederlage: ein Leben weniger, der
##     Lauf geht weiter. Null Leben = vorbei, alle Runden geschafft = gewonnen.
##
## Die Stellschrauben stehen in data/config.json, Abschnitt "run".

enum Phase { PREPARE, REWARD, WON, LOST }

var run_seed: int = 0
var round: int = 1
var lives: int = 3
var squad: Array = []
var phase: Phase = Phase.PREPARE

## Die Belohnungen, zwischen denen gerade gewaehlt wird (Phase REWARD).
var reward_options: Array = []

## Ergebnisse der bisherigen Kaempfe, fuer die Abschlussanzeige.
var history: Array = []


static func cfg() -> Dictionary:
	return Config.section("run")


static func rounds_total() -> int:
	return int(cfg().get("rounds", 8))


static func max_lives() -> int:
	return int(cfg().get("lives", 3))


static func start(seed_value: int) -> RunState:
	var run := RunState.new()
	run.run_seed = seed_value
	run.lives = max_lives()
	run.squad = starter_squad()
	return run


## Zwei DROMEs mit je einer Waffe und je einem freien Halter fuer Beute.
##
## Gemessen, nicht geschaetzt (14 Kaempfe je Paar gegen die Gegner der ersten
## Runde): Vireo + Nimbus mit Runenstab gewinnt 11 von 14. Der erste Entwurf,
## Vireo + Molok mit Belagerungskanone, gewann 0 von 14 -- trotz HOEHEREM
## Kampfwert: die Kanone drueckt den Molok auf SPD 6, er kommt kaum zum Zug,
## und der Vireo laeuft allein in zwei Gegner.
static func starter_squad() -> Array:
	var vireo := _frame("Vireo", &"scout_body", &"scout_core")
	_equip(vireo, &"eq_pulse_blaster")
	var nimbus := _frame("Nimbus", &"mage_body", &"mage_core")
	_equip(nimbus, &"eq_rune_staff")
	return [vireo, nimbus]


static func _frame(name: String, body_id: StringName, core_id: StringName) -> DromeBuild:
	var build := DromeBuild.create(name, {})
	build.apply_chassis(body_id)
	build.slots["core"] = core_id
	return build


static func _equip(build: DromeBuild, part_id: StringName) -> String:
	var part := PartDB.get_part(part_id)
	var slot := build.slot_for(part)
	if slot != "":
		build.slots[slot] = part_id
	return slot


func is_over() -> bool:
	return phase == Phase.WON or phase == Phase.LOST


# ---------------------------------------------------------------------------
# Der naechste Kampf
# ---------------------------------------------------------------------------

## Der Seed des Kampfes dieser Runde. Aus Lauf-Seed und Runde, damit jede
## Runde anders ist und derselbe Lauf trotzdem dieselben Kaempfe hat.
func battle_seed() -> int:
	return absi(hash([run_seed, round])) % 2000000000 + 1


func enemy_count() -> int:
	var counts: Array = cfg().get("enemy_counts", [2, 2, 2, 3, 3, 3, 4, 4])
	return int(counts[clampi(round - 1, 0, counts.size() - 1)])


## Die Gegnerstaerke dieser Runde: ein fester Anteil der Startstaerke, der je
## Runde waechst. Bewusst unabhaengig vom aktuellen Squad (siehe oben).
func enemy_power() -> float:
	var base := DromeBuild.squad_power(starter_squad())
	var start_factor := float(cfg().get("power_start", 0.85))
	var growth := float(cfg().get("power_growth", 0.2))
	return base * (start_factor + growth * float(round - 1))


## Alles, was man vor dem Kampf wissen muss. Region und Mutator kommen aus
## demselben Seed und derselben Reihenfolge wie im echten Aufbau
## (BattleManager.preview_conditions), sind also keine Schaetzung.
func preview() -> Dictionary:
	var conditions := BattleManager.preview_conditions(battle_seed())
	conditions["enemies"] = enemy_count()
	conditions["enemy_power"] = enemy_power()
	conditions["own_power"] = DromeBuild.squad_power(squad)
	return conditions


# ---------------------------------------------------------------------------
# Ergebnis und Belohnung
# ---------------------------------------------------------------------------

## Traegt das Kampfergebnis ein. ``enemy_pool`` sind die Ausruestungs-IDs der
## Gegner (BattleManager.enemy_equipment) -- daraus kommt die Beute.
func record_result(outcome: int, enemy_pool: Array) -> void:
	if phase != Phase.PREPARE:
		return
	var won := outcome == BattleManager.Outcome.VICTORY
	history.append({"round": round, "won": won})
	if not won:
		lives -= 1
		if lives <= 0:
			phase = Phase.LOST
			return
		_advance()
		return
	if round >= rounds_total():
		phase = Phase.WON
		return
	reward_options = roll_rewards(enemy_pool)
	phase = Phase.REWARD


func _advance() -> void:
	round += 1
	phase = Phase.PREPARE


## Drei Belohnungen. Meist Teile aus der Gegnerausruestung; in bestimmten
## Runden ein neuer DROME (solange Platz im Squad ist); selten ein Leben
## zurueck, wenn eines fehlt.
func roll_rewards(enemy_pool: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = battle_seed() ^ 0x5EED
	var count := int(cfg().get("reward_choices", 3))
	var options: Array = []

	var drome_rounds: Array = cfg().get("new_drome_rounds", [2, 5])
	if round in drome_rounds and squad.size() < int(cfg().get("squad_max", 4)):
		options.append(_drome_reward(rng))
	if lives < max_lives() and rng.randf() < float(cfg().get("life_chance", 0.35)):
		options.append({"kind": "life", "title": "Notstrom",
			"text": "Ein verlorenes Leben zurueck."})

	var pool: Array = enemy_pool.duplicate()
	if pool.size() < count:
		for part in PartDB.of_type(PartData.Type.EQUIPMENT):
			if not pool.has(part.id):
				pool.append(part.id)
	while options.size() < count and not pool.is_empty():
		var index := rng.randi() % pool.size()
		var part := PartDB.get_part(pool[index])
		pool.remove_at(index)
		if part == null:
			continue
		options.append({"kind": "part", "part_id": part.id,
			"title": part.display_name, "text": _part_text(part)})
	return options


## Ein neuer DROME kommt MIT einer passenden Waffe: ohne waere er im
## Autokampf nur ein Ziel -- er koennte nichts tun, und eine Belohnung, die
## erst eine zweite braucht, ist keine.
func _drome_reward(rng: RandomNumberGenerator) -> Dictionary:
	var bodies := PartDB.of_type(PartData.Type.BODY)
	var body: PartData = bodies[rng.randi() % bodies.size()]
	var probe := _frame("probe", body.id, &"scout_core")
	var weapons: Array = []
	for part in PartDB.of_type(PartData.Type.EQUIPMENT):
		if part.category == "weapon" and probe.slot_for(part) != "":
			weapons.append(part)
	var weapon: PartData = weapons[rng.randi() % weapons.size()] if not weapons.is_empty() else null
	return {"kind": "drome", "body_id": body.id,
		"weapon_id": weapon.id if weapon != null else &"",
		"title": "Neuer DROME: %s" % body.display_name.replace(" Chassis", ""),
		"text": "Chassis mit Kern und %s." % (weapon.display_name if weapon != null else "ohne Waffe")}


static func _part_text(part: PartData) -> String:
	var lines: Array[String] = []
	for action in part.actions:
		lines.append(action.display_name)
	var kind: String = {"weapon": "Waffe", "shield": "Schild", "support": "Unterstuetzung"} \
		.get(part.category, "Ausruestung")
	return "%s%s" % [kind, (": " + ", ".join(lines)) if not lines.is_empty() else ""]


## Wohin dieses Teil passt: je DROME die Halter, die es nehmen, mit der
## aktuellen Belegung. Fuer die Auswahl in der Oberflaeche.
func placements_for(part_id: StringName) -> Array:
	var part := PartDB.get_part(part_id)
	var out: Array = []
	if part == null:
		return out
	for index in squad.size():
		var build: DromeBuild = squad[index]
		var chassis := build.body()
		if chassis == null:
			continue
		for slot in build.equip_slots():
			if not chassis.accepts(part, slot):
				continue
			var current := build.part_in(slot)
			var trial := build.clone()
			trial.slots[slot] = part.id
			out.append({"drome": index, "slot": slot,
				"current": current.display_name if current != null else "",
				"valid": trial.is_valid()})
	return out


## Waehlt eine Belohnung. ``placement`` ist fuer Teile ein Eintrag aus
## placements_for(); fuer andere Arten leer. Gibt false zurueck, wenn die Wahl
## nicht geht -- der Lauf bleibt dann in der Belohnungsphase.
func choose_reward(index: int, placement: Dictionary = {}) -> bool:
	if phase != Phase.REWARD or index < 0 or index >= reward_options.size():
		return false
	var option: Dictionary = reward_options[index]
	match option["kind"]:
		"part":
			if placement.is_empty():
				return false
			var build: DromeBuild = squad[int(placement["drome"])]
			var trial := build.clone()
			trial.slots[placement["slot"]] = option["part_id"]
			if not trial.is_valid():
				return false
			build.slots[placement["slot"]] = option["part_id"]
		"drome":
			var body := PartDB.get_part(option["body_id"])
			var core := PartDB.frame_mate(body.set_id, PartData.Type.CORE)
			var fresh := _frame(body.display_name.replace(" Chassis", ""),
				body.id, core.id if core != null else &"scout_core")
			if StringName(option.get("weapon_id", &"")) != &"":
				_equip(fresh, option["weapon_id"])
			squad.append(fresh)
		"life":
			lives = mini(max_lives(), lives + 1)
	reward_options = []
	_advance()
	return true


## Belohnung ausschlagen -- weiter ohne Aenderung.
func skip_reward() -> void:
	if phase != Phase.REWARD:
		return
	reward_options = []
	_advance()
