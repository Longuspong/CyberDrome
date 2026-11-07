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
##   * Start mit dem Squad, den man mitnimmt (vorgeschlagen: der Hangar-
##     Squad). Die DROMEs werden kopiert -- im Lauf baut man nur mit Beute um,
##     nicht mit dem Inventar von zuhause.
##   * Vor jedem Kampf waehlt man zwischen drei Gegnern: Leicht, Normal, Elite.
##     Region und die gegnerischen DROMEs sind vorher sichtbar.
##   * Die Gegnerstaerke folgt einer FESTEN Kurve (Startstaerke des Squads),
##     nicht dem eigenen Aufbau. Wuchse sie mit, waere jede Belohnung wertlos.
##   * Sieg: Belohnung nach Stufe, dazu Credits. Beute (Waffen) kommt ins
##     Lager. Niederlage: ein Leben weniger, weniger Credits, der Lauf geht
##     weiter.
##   * Nach jedem Kampf der Zwischenstopp (Phase STOP, NEUANFANG 7d): Waffen
##     aus dem Lager einbauen, ausbauen, verkaufen oder nach Hause schicken.
##     Umbauen ist frei -- der Druck kommt aus den wenigen Plaetzen.
##   * Ende des Laufs: Beute, die noch im Lauf ist (im Lager oder eingebaut),
##     geht nach Hause ins Inventar (NEUANFANG 7f: Ausruestung bleibt).
##
## Die Stellschrauben stehen in data/config.json, Abschnitt "run".

## STOP steht hinten, damit die alten Werte gleich bleiben.
enum Phase { PREPARE, REWARD, WON, LOST, STOP }

## Die drei Gegner, zwischen denen man vor jedem Kampf waehlt. Staerke und
## Beute je Stufe stehen in data/config.json -> run.tiers.
enum Tier { EASY, NORMAL, ELITE }
const TIER_KEYS := ["easy", "normal", "elite"]
const TIER_NAMES := ["Leicht", "Normal", "Elite"]

var run_seed: int = 0
var round: int = 1
var lives: int = 3
var squad: Array = []
var phase: Phase = Phase.PREPARE

## Die gewaehlte Gegnerstufe der aktuellen Runde.
var tier: int = Tier.NORMAL

## Kampfwert und Groesse des Squads beim Start. Daran haengt die feste Kurve
## der Gegner -- einmal festgehalten, damit Beute sie nicht mitzieht.
var base_power: float = 0.0
var start_size: int = 2

## Die Belohnungen, zwischen denen gerade gewaehlt wird (Phase REWARD).
var reward_options: Array = []

## Beute, die nach Hause geschickt wurde und noch ins Inventar muss.
## GameState.deliver_run_home() leert die Liste. Eintraege wie reward_options.
var home_queue: Array = []

## Credits: die Waehrung des Laufs (7f). Je Kampf und fuer verkaufte Waffen;
## ausgegeben werden sie spaeter im Laden.
var credits: int = 0

## Das Lager des Laufs: Waffen, die gerade niemand traegt (Teil-IDs).
## Hoechstens storage_size() Plaetze.
var storage: Array = []

## Wie oft jede Waffe beim Start im Squad steckte. Was am Ende darueber
## hinaus im Lauf ist, ist Beute und geht nach Hause.
var _start_counts: Dictionary = {}

## Ergebnisse der bisherigen Kaempfe, fuer die Abschlussanzeige.
var history: Array = []

## Gewuerfelte Gegner je Runde und Stufe -- einmal erzeugt, damit Vorschau und
## Kampf dieselben DROMEs zeigen.
var _enemy_cache: Dictionary = {}


static func cfg() -> Dictionary:
	return Config.section("run")


static func rounds_total() -> int:
	return int(cfg().get("rounds", 8))


static func max_lives() -> int:
	return int(cfg().get("lives", 3))


static func squad_max() -> int:
	return int(cfg().get("squad_max", 4))


static func storage_size() -> int:
	return int(cfg().get("storage_size", 8))


## Was eine Waffe beim Verkauf bringt -- nach Gewichtsklasse.
static func sell_value(part: PartData) -> int:
	if part == null:
		return 0
	var values: Dictionary = cfg().get("sell_value", {})
	return int(values.get(part.mount_class, 3))


static func tier_cfg(which: int) -> Dictionary:
	var tiers: Dictionary = cfg().get("tiers", {})
	return tiers.get(TIER_KEYS[clampi(which, 0, 2)], {})


## Startet einen Lauf mit dem mitgenommenen Squad. Die DROMEs werden KOPIERT:
## was im Lauf eingebaut wird, bleibt im Lauf -- der Hangar zuhause aendert
## sich nur durch Beute, die man ausdruecklich nach Hause schickt.
## Ohne Squad (Tests, Werkzeuge) kommen die vier Standard-DROMEs.
static func start(seed_value: int, chosen: Array = []) -> RunState:
	var run := RunState.new()
	run.run_seed = seed_value
	run.lives = max_lives()
	var source: Array = chosen if not chosen.is_empty() else standard_squad()
	for build in source.slice(0, squad_max()):
		run.squad.append(build.clone())
	run.start_size = run.squad.size()
	for build in run.squad:
		run._count_start(build)
	run.base_power = reference_power(run.start_size)
	return run


## Die Bezugsstaerke der Gegner (6g): NICHT die Staerke des mitgenommenen
## Squads, sondern der Durchschnitt der Standard-DROMEs mal der Zahl der
## mitgenommenen DROMEs. So bringen staerkere Aufbauten (und spaeter Level)
## wirklich weiter, statt dass die Gegner mitwachsen. Region und Runde
## stecken in der Kurve von enemy_power().
static func reference_power(size: int) -> float:
	var standard := standard_squad()
	if standard.is_empty():
		return 0.0
	return DromeBuild.squad_power(standard) / float(standard.size()) * float(maxi(1, size))


## Die vier Standard-DROMEs in voller Standardausstattung -- derselbe
## Startbestand wie in einem frischen Hangar (Roster.STARTER_CHASSIS).
static func standard_squad() -> Array:
	var roster := Roster.new()
	roster.seed_starter()
	var builds: Array = []
	for entry in roster.entries:
		builds.append(roster.build_for(entry))
	return builds


func _count_start(build: DromeBuild) -> void:
	for part in build.equipment():
		_start_counts[part.id] = int(_start_counts.get(part.id, 0)) + 1


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

## Der Seed des Kampfes dieser Runde und Stufe. Aus Lauf-Seed, Runde und
## Stufe, damit jede Wahl ein eigener Kampf ist und derselbe Lauf trotzdem
## dieselben Kaempfe hat.
func battle_seed(which: int = -1) -> int:
	if which < 0:
		which = tier
	return absi(hash([run_seed, round, which])) % 2000000000 + 1


## Wie viele Gegner: so viele, wie man mitgebracht hat, plus/minus der
## Verschiebung dieser Runde (run.enemy_offsets). Ein kleinerer Squad trifft
## also auf weniger Gegner -- er bekommt aber auch weniger Kampfwert.
func enemy_count(which: int = -1) -> int:
	if which < 0:
		which = tier
	var offsets: Array = cfg().get("enemy_offsets", [0])
	var offset := int(offsets[clampi(round - 1, 0, offsets.size() - 1)])
	offset += int(tier_cfg(which).get("count_offset", 0))
	return clampi(start_size + offset, 1, squad_max())


## Die Gegnerstaerke: ein fester Anteil der Bezugsstaerke (reference_power),
## der je Runde waechst, mal dem Faktor der Stufe. Bewusst unabhaengig davon,
## wie stark der mitgenommene Squad ist.
func enemy_power(which: int = -1) -> float:
	if which < 0:
		which = tier
	var start_factor := float(cfg().get("power_start", 0.85))
	var growth := float(cfg().get("power_growth", 0.2))
	var factor := float(tier_cfg(which).get("power", 1.0))
	return base_power * (start_factor + growth * float(round - 1)) * factor


## Die Gegner dieser Runde und Stufe -- dieselben in Vorschau und Kampf.
func enemies(which: int = -1) -> Array:
	if which < 0:
		which = tier
	var key := round * 10 + which
	if not _enemy_cache.has(key):
		_enemy_cache[key] = EnemyGenerator.new(battle_seed(which)) \
			.generate(enemy_count(which), enemy_power(which))
	return _enemy_cache[key]


## Alles, was man vor dem Kampf wissen muss. Die Region kommt aus
## demselben Seed und derselben Reihenfolge wie im echten Aufbau
## (BattleManager.preview_conditions), ist also keine Schaetzung.
func preview(which: int = -1) -> Dictionary:
	if which < 0:
		which = tier
	var conditions := BattleManager.preview_conditions(battle_seed(which))
	var foes := enemies(which)
	conditions["tier"] = which
	conditions["enemies"] = foes.size()
	conditions["enemy_builds"] = foes
	conditions["enemy_power"] = DromeBuild.squad_power(foes)
	conditions["own_power"] = DromeBuild.squad_power(squad)
	conditions["reward_text"] = str(tier_cfg(which).get("reward_text", ""))
	return conditions


func choose_tier(which: int) -> void:
	if phase == Phase.PREPARE:
		tier = clampi(which, 0, 2)


# ---------------------------------------------------------------------------
# Ergebnis und Belohnung
# ---------------------------------------------------------------------------

## Traegt das Kampfergebnis ein. ``enemy_pool`` sind die Ausruestungs-IDs der
## Gegner (BattleManager.enemy_equipment) -- daraus kommt die Beute.
func record_result(outcome: int, enemy_pool: Array) -> void:
	if phase != Phase.PREPARE:
		return
	var won := outcome == BattleManager.Outcome.VICTORY
	var gain := battle_credits(won)
	credits += gain
	history.append({"round": round, "won": won, "tier": tier, "credits": gain})
	if not won:
		lives -= 1
		if lives <= 0:
			_finish(Phase.LOST)
			return
		phase = Phase.STOP
		return
	if round >= rounds_total():
		_finish(Phase.WON)
		return
	reward_options = roll_rewards(enemy_pool)
	phase = Phase.REWARD


## Credits fuer den Kampf dieser Runde: nach Stufe bei einem Sieg, ein
## Trostgeld bei einer Niederlage.
func battle_credits(won: bool) -> int:
	if not won:
		return int(cfg().get("loss_credits", 4))
	return int(tier_cfg(tier).get("credits", 10))


## Lauf aufgeben: wie verloren, die Beute geht trotzdem nach Hause.
func abandon() -> void:
	if not is_over():
		_finish(Phase.LOST)


func _finish(final: Phase) -> void:
	phase = final
	reward_options = []
	_send_loot_home()


## Alles, was am Ende mehr im Lauf ist als beim Start -- im Lager oder
## eingebaut --, kommt in die home_queue. So wandert Beute auch dann nach
## Hause, wenn sie getragen wurde, und die mitgenommene Ausruestung wird
## nicht verdoppelt (sie liegt ja schon zuhause).
func _send_loot_home() -> void:
	var counts: Dictionary = {}
	for build in squad:
		for part in build.equipment():
			counts[part.id] = int(counts.get(part.id, 0)) + 1
	for id in storage:
		counts[id] = int(counts.get(id, 0)) + 1
	storage.clear()
	for id in counts:
		for _i in maxi(0, int(counts[id]) - int(_start_counts.get(id, 0))):
			var part := PartDB.get_part(id)
			if part != null:
				home_queue.append({"kind": "part", "part_id": part.id,
					"title": part.display_name, "text": _part_text(part)})


func _advance() -> void:
	round += 1
	tier = Tier.NORMAL
	phase = Phase.PREPARE


## Die Belohnungen haengen an der Stufe des besiegten Gegners:
##
##   Leicht  wenige Teile aus der Gegnerausruestung, dazu evtl. Notstrom
##   Normal  eine von drei, meist Teile; in bestimmten Runden ein DROME
##   Elite   garantiert etwas Seltenes: ein neuer DROME oder schwere/mittlere
##           Teile, auch aus dem ganzen Katalog
func roll_rewards(enemy_pool: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = battle_seed() ^ 0x5EED
	var settings := tier_cfg(tier)
	var count := int(settings.get("reward_choices", cfg().get("reward_choices", 3)))
	var options: Array = []

	if tier == Tier.ELITE:
		var drome := _drome_reward(rng)
		drome["rare"] = true
		options.append(drome)
	elif tier == Tier.NORMAL:
		var drome_rounds: Array = cfg().get("new_drome_rounds", [2, 5])
		if round in drome_rounds:
			options.append(_drome_reward(rng))
	if tier != Tier.ELITE and lives < max_lives() \
			and rng.randf() < float(settings.get("life_chance", cfg().get("life_chance", 0.35))):
		options.append({"kind": "life", "title": "Notstrom",
			"text": "Ein verlorenes Leben zurueck."})

	var pool: Array = enemy_pool.duplicate()
	if tier == Tier.ELITE:
		# Selten = mittlere und schwere Teile. Erst aus der Gegnerausruestung,
		# fehlt dort etwas, aus dem ganzen Katalog.
		pool = pool.filter(func(id): return _is_rare(PartDB.get_part(id)))
		for part in PartDB.of_type(PartData.Type.EQUIPMENT):
			if _is_rare(part) and not pool.has(part.id):
				pool.append(part.id)
	elif pool.size() < count:
		for part in PartDB.of_type(PartData.Type.EQUIPMENT):
			if not pool.has(part.id):
				pool.append(part.id)
	while options.size() < count and not pool.is_empty():
		var index := rng.randi() % pool.size()
		var part := PartDB.get_part(pool[index])
		pool.remove_at(index)
		if part == null:
			continue
		options.append({"kind": "part", "part_id": part.id, "rare": tier == Tier.ELITE,
			"title": part.display_name, "text": _part_text(part)})
	return options


static func _is_rare(part: PartData) -> bool:
	return part != null and part.mount_class != "light"


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


## Der Platz "nach Hause": die Beute wandert ins Inventar des Hangars statt
## in den Lauf.
static func home_placement() -> Dictionary:
	return {"home": true, "valid": true}


## Ob ein neuer DROME noch in den Lauf-Squad passt. Sonst bleibt nur "nach
## Hause".
func has_room() -> bool:
	return squad.size() < squad_max()


## Waehlt eine Belohnung. Waffen kommen ins Lager (ist es voll, gehen sie
## nach Hause); eingebaut wird danach im Zwischenstopp. Ein DROME kommt in
## den Lauf-Squad, mit ``placement`` = home_placement() nach Hause. Gibt
## false zurueck, wenn die Wahl nicht geht -- der Lauf bleibt dann in der
## Belohnungsphase.
func choose_reward(index: int, placement: Dictionary = {}) -> bool:
	if phase != Phase.REWARD or index < 0 or index >= reward_options.size():
		return false
	var option: Dictionary = reward_options[index]
	if bool(placement.get("home", false)):
		if option["kind"] == "life":
			return false
		home_queue.append(option.duplicate())
		reward_options = []
		phase = Phase.STOP
		return true
	match option["kind"]:
		"part":
			if storage_full():
				home_queue.append(option.duplicate())
			else:
				storage.append(StringName(option["part_id"]))
		"drome":
			if not has_room():
				return false
			var fresh := drome_from_reward(option)
			squad.append(fresh)
			# Seine Waffe gehoert zu ihm wie die Startausstattung.
			_count_start(fresh)
		"life":
			lives = mini(max_lives(), lives + 1)
	reward_options = []
	phase = Phase.STOP
	return true


## Baut aus einer DROME-Belohnung den Aufbau: Chassis, passender Kern, Waffe.
static func drome_from_reward(option: Dictionary) -> DromeBuild:
	var body := PartDB.get_part(option["body_id"])
	var core := PartDB.frame_mate(body.set_id, PartData.Type.CORE)
	var fresh := _frame(body.display_name.replace(" Chassis", ""),
		body.id, core.id if core != null else &"scout_core")
	if StringName(option.get("weapon_id", &"")) != &"":
		_equip(fresh, option["weapon_id"])
	return fresh


## Belohnung ausschlagen -- weiter zum Zwischenstopp ohne Aenderung.
func skip_reward() -> void:
	if phase != Phase.REWARD:
		return
	reward_options = []
	phase = Phase.STOP


# ---------------------------------------------------------------------------
# Zwischenstopp: Lager, Credits, Ausruesten (NEUANFANG 7d)
# ---------------------------------------------------------------------------

func storage_full() -> bool:
	return storage.size() >= storage_size()


## Weiter zum naechsten Kampf.
func continue_run() -> void:
	if phase == Phase.STOP:
		_advance()


## Wohin die Waffe aus Lagerplatz ``index`` passt: je DROME alle Halter, auch
## die, die sie nicht nehmen -- mit Grund (SlotRules). Eintraege:
## {drome, slot, label, detail, allowed}.
func equip_options(index: int) -> Array:
	var out: Array = []
	if index < 0 or index >= storage.size():
		return out
	var part := PartDB.get_part(storage[index])
	for drome in squad.size():
		for choice in SlotRules.slot_choices(squad[drome], part):
			var entry: Dictionary = choice.duplicate()
			entry["drome"] = drome
			if entry["allowed"]:
				var trial: DromeBuild = squad[drome].clone()
				trial.slots[entry["slot"]] = part.id
				if not trial.is_valid():
					entry["allowed"] = false
					entry["detail"] = "Aufbau waere ungueltig"
			out.append(entry)
	return out


## Baut die Waffe aus Lagerplatz ``index`` in ``slot`` von DROME ``drome``.
## Was dort steckte, kommt auf ihren Platz im Lager -- ein Tausch, geht also
## auch bei vollem Lager.
func equip_from_storage(index: int, drome: int, slot: String) -> bool:
	if phase != Phase.STOP or index < 0 or index >= storage.size() \
			or drome < 0 or drome >= squad.size():
		return false
	var build: DromeBuild = squad[drome]
	var part := PartDB.get_part(storage[index])
	var chassis := build.body()
	if part == null or chassis == null or slot not in build.equip_slots() \
			or not chassis.accepts(part, slot):
		return false
	var trial := build.clone()
	trial.slots[slot] = part.id
	if not trial.is_valid():
		return false
	var old := build.part_in(slot)
	build.slots[slot] = part.id
	if old != null:
		storage[index] = old.id
	else:
		storage.remove_at(index)
	return true


## Baut die Waffe aus ``slot`` aus und legt sie ins Lager.
func unequip(drome: int, slot: String) -> bool:
	if phase != Phase.STOP or storage_full() or drome < 0 or drome >= squad.size():
		return false
	var build: DromeBuild = squad[drome]
	var part := build.part_in(slot)
	if part == null or slot not in build.equip_slots():
		return false
	build.slots.erase(slot)
	storage.append(part.id)
	return true


## Verkauft die Waffe aus Lagerplatz ``index``. Gibt die Credits zurueck.
func sell(index: int) -> int:
	if phase != Phase.STOP or index < 0 or index >= storage.size():
		return 0
	var value := sell_value(PartDB.get_part(storage[index]))
	storage.remove_at(index)
	credits += value
	return value


## Schickt die Waffe aus Lagerplatz ``index`` jetzt schon nach Hause.
func send_home(index: int) -> bool:
	if phase != Phase.STOP or index < 0 or index >= storage.size():
		return false
	var part := PartDB.get_part(storage[index])
	storage.remove_at(index)
	if part == null:
		return false
	# Liegt danach weniger davon im Lauf als beim Start, war es mitgenommene
	# Ausruestung -- die ist zuhause schon da und wird nicht verdoppelt.
	var start := int(_start_counts.get(part.id, 0))
	if _count_in_run(part.id) < start:
		_start_counts[part.id] = start - 1
		return true
	home_queue.append({"kind": "part", "part_id": part.id,
		"title": part.display_name, "text": _part_text(part)})
	return true


func _count_in_run(id: StringName) -> int:
	var count := storage.count(id)
	for build in squad:
		for part in build.equipment():
			if part.id == id:
				count += 1
	return count
