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
##   * Sieg: Credits nach Stufe, dazu gewuerfelte Beute OHNE Auswahl (6i):
##     Credits oder ein Teil, in bestimmten Runden ein DROME, mit Glueck
##     Notstrom. Teile kommen ins Lager. Niederlage: ein Leben weniger,
##     weniger Credits, der Lauf geht weiter.
##   * Nach jedem Kampf der Zwischenstopp (Phase STOP, NEUANFANG 7d): Waffen
##     aus dem Lager einbauen, ausbauen, verkaufen oder nach Hause schicken.
##     Umbauen ist frei -- der Druck kommt aus den wenigen Plaetzen.
##   * Module (NEUANFANG 6g) gibt es nur im Lauf: aus dem Laden im
##     Zwischenstopp (6i, fuer Credits), im Lager, in den Waffenhaltern
##     (DromeBuild.modules). Im Lager lassen sich Rezepte zusammenfuegen. Am
##     Ende verfallen sie.
##   * Ende des Laufs: Beute, die noch im Lauf ist (im Lager oder eingebaut),
##     geht nach Hause ins Inventar (NEUANFANG 7f: Ausruestung bleibt).
##
## Die Stellschrauben stehen in data/config.json, Abschnitt "run".

## STOP steht hinten, damit die alten Werte gleich bleiben. REWARD wird seit
## der gewuerfelten Beute (6i) nicht mehr betreten.
enum Phase { PREPARE, REWARD, WON, LOST, STOP }

## Die drei Gegner, zwischen denen man vor jedem Kampf waehlt. Staerke und
## Beute je Stufe stehen in data/config.json -> run.tiers.
enum Tier { EASY, NORMAL, ELITE }
const TIER_KEYS := ["easy", "normal", "elite"]
const TIER_NAMES := ["Leicht", "Normal", "Elite"]

var run_seed: int = 0
## Das Gebiet des Laufs (data/regions.json, config run.region). Alle Kaempfe
## des Laufs finden dort statt.
var region_id: StringName = &"city"
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

## Die Beute des letzten Kampfes, schon verteilt -- fuer die Anzeige im
## Zwischenstopp. Eintraege {kind, title, text, rare, where}; where sagt, wo
## sie gelandet ist ("lager", "squad", "home", "" fuer Credits/Leben).
var last_loot: Array = []

## EP des letzten Kampfes (collect_xp), fuer die Anzeige im Zwischenstopp:
## [{kind ("drome"/"weapon"), uid, name, gain}].
var last_growth: Array = []

## Gesammelte EP dieses Laufs (Leveling): uid -> EP, getrennt nach DROMEs
## (Chassis-uid) und Waffen (Exemplar-uid). Gutgeschrieben wird erst am Ende
## zuhause (GameState.credit_run_xp); im Lauf bleiben die Level, wie sie sind.
var pending_xp: Dictionary = {"dromes": {}, "weapons": {}}
var xp_credited: bool = false
## Was am Ende gutgeschrieben wurde (GameState.credit_run_xp), fuer die
## Abschlussanzeige.
var final_growth: Array = []

## Beute, die nach Hause geschickt wurde und noch ins Inventar muss.
## GameState.deliver_run_home() leert die Liste. Eintraege wie last_loot.
var home_queue: Array = []

## Credits: die Waehrung des Laufs (7f). Je Kampf und fuer Verkaeufe;
## ausgegeben im Laden.
var credits: int = 0

## Der Laden des aktuellen Zwischenstopps (6i): je Angebot {module_id, sold}.
## Gewuerfelt beim Betreten des Zwischenstopps, geleert beim Weitergehen.
var shop_offers: Array = []
## Wie oft im aktuellen Zwischenstopp neu gewuerfelt wurde (Preis steigt).
var rerolls: int = 0
## Ziel-Rezept (MODULE_KONZEPT.md 7): nur dessen fehlende Zutaten bekommen das
## volle Mitleid im Laden. Leer = keins, dann gilt das schwaechere Mitleid fuer
## alle angefangenen Rezepte.
var target_recipe: StringName = &""

## Das Lager des Laufs: nur Module (seit 9. Nov. 2026, NEUANFANG 6h), die
## gerade in keinem Halter stecken -- storage_size() Plaetze.
var storage: Array = []

## Die Tasche (6h): Beute-Teile (Waffen) dieses Laufs. Waffen sind im Lauf
## fest (MODULE_KONZEPT.md) -- die Teile werden nicht eingebaut, belegen keinen
## Lagerplatz und gehen am Ende nach Hause.
var bag: Array = []

## Matrix-BIOS zur Wahl nach einem Elite-Sieg (MODULE_KONZEPT.md 6.2): BIOS-IDs,
## eines davon kommt ins Lager. Verfaellt beim Weitergehen.
var bios_offers: Array = []

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
	run.region_id = StringName(str(cfg().get("region", "city")))
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
		var generator := EnemyGenerator.new(battle_seed(which))
		generator.profile = faction()
		var foes := generator.generate(enemy_count(which), enemy_power(which))
		_arm_enemies(foes, which)
		_enemy_cache[key] = foes
	return _enemy_cache[key]


## Wie viele Module jeder Gegner dieser Runde und Stufe traegt (6i):
## run.enemy_modules.by_round plus tier_offset, hoechstens so viele, wie der
## Halter fasst.
func enemy_module_count(which: int = -1) -> int:
	if which < 0:
		which = tier
	var settings: Dictionary = cfg().get("enemy_modules", {})
	var by_round: Array = settings.get("by_round", [0])
	if by_round.is_empty():
		return 0
	var count := int(by_round[clampi(round - 1, 0, by_round.size() - 1)])
	count += int((settings.get("tier_offset", {}) as Dictionary).get(TIER_KEYS[which], 0))
	return maxi(0, count)


## DROME- und Waffenlevel der Gegner dieser Runde und Stufe
## (run.enemy_levels): {drome, weapon}.
func enemy_levels(which: int = -1) -> Dictionary:
	if which < 0:
		which = tier
	var settings: Dictionary = cfg().get("enemy_levels", {})
	var offset: Dictionary = (settings.get("tier_offset", {}) as Dictionary).get(TIER_KEYS[which], {})
	var out := {}
	for kind in ["drome", "weapon"]:
		var table: Array = settings.get(kind, [0])
		var value := int(table[clampi(round - 1, 0, table.size() - 1)]) if not table.is_empty() else 0
		value += int(offset.get(kind, 0))
		var top := Leveling.drome_max() if kind == "drome" else Leveling.weapon_max()
		out[kind] = clampi(value, 0, top)
	return out


## Gegner tragen Module (6i) -- dieselben wie der Spieler, aber handverlesen:
## nur was zur Waffe passt (keine ruhenden Module), keines doppelt. Ab
## enemy_modules.recipe_from_round und mindestens zwei Plaetzen ist das erste
## ein passendes Rezept. Alles in den Halter der ersten Waffe, am Seed des
## Kampfes.
func _arm_enemies(foes: Array, which: int) -> void:
	var levels := enemy_levels(which)
	for build in foes:
		build.drome_level = levels["drome"]
		for slot in build.equip_slots():
			if build.part_in(slot) != null and levels["weapon"] > 0:
				build.weapon_levels[slot] = levels["weapon"]
	var count := enemy_module_count(which)
	if count <= 0:
		return
	var settings: Dictionary = cfg().get("enemy_modules", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = battle_seed(which) ^ 0x30D
	# Profil der Fraktion: bevorzugte Module und Rezepte zaehlen mehr.
	var profile := faction()
	var favoured: Array = profile.get("modules", [])
	var favoured_recipes: Array = profile.get("recipes", [])
	var boost := float(profile.get("module_weight", 1.0))
	for build in foes:
		var slot := ""
		for candidate in build.equip_slots():
			if build.part_in(candidate) != null:
				slot = candidate
				break
		if slot == "":
			continue
		var weapon: PartData = build.part_in(slot)
		var room := mini(count, ModuleData.slots_for(build))
		var picked: Array = []
		if room >= 2 and round >= int(settings.get("recipe_from_round", 5)):
			var recipes := ModuleData.recipes().filter(func(m): return m.fits(weapon))
			if not recipes.is_empty():
				picked.append(recipes[_weighted_index(rng, recipes, favoured_recipes, boost)].id)
		var pool := ModuleData.base_modules().filter(func(m): return m.fits(weapon))
		while picked.size() < room and not pool.is_empty():
			var index := _weighted_index(rng, pool, favoured, boost)
			picked.append(pool[index].id)
			pool.remove_at(index)
		if not picked.is_empty():
			build.modules[slot] = picked


## Die Fraktion des Gebiets mit ihrem Profil (data/regions.json -> faction),
## dazu die Gewichte aus der Datei. Leer, wenn das Gebiet keine hat.
func faction() -> Dictionary:
	var region := TerrainDB.get_region(region_id)
	if region == null or region.faction.is_empty():
		return {}
	var out := region.faction.duplicate(true)
	out["weapon_weight"] = TerrainDB.weight("weapon_weight", 4.0)
	out["module_weight"] = TerrainDB.weight("module_weight", 4.0)
	return out


## Ein Index aus ``pool`` (Module), bevorzugte IDs ``boost``-mal so schwer.
## Ohne Bevorzugung genau wie frueher (ein randi-Aufruf).
static func _weighted_index(rng: RandomNumberGenerator, pool: Array, favoured: Array, boost: float) -> int:
	if favoured.is_empty() or boost <= 1.0:
		return rng.randi() % pool.size()
	var total := 0.0
	for module in pool:
		total += boost if favoured.has(str(module.id)) else 1.0
	var roll := rng.randf() * total
	for i in pool.size():
		roll -= boost if favoured.has(str(pool[i].id)) else 1.0
		if roll < 0.0:
			return i
	return pool.size() - 1


## Alles, was man vor dem Kampf wissen muss. Die Region kommt aus
## demselben Seed und derselben Reihenfolge wie im echten Aufbau
## (BattleManager.preview_conditions), ist also keine Schaetzung.
func preview(which: int = -1) -> Dictionary:
	if which < 0:
		which = tier
	var conditions := BattleManager.preview_conditions(battle_seed(which), region_id)
	var foes := enemies(which)
	conditions["tier"] = which
	conditions["enemies"] = foes.size()
	conditions["enemy_builds"] = foes
	conditions["enemy_power"] = DromeBuild.squad_power(foes)
	conditions["own_power"] = DromeBuild.squad_power(squad)
	conditions["reward_text"] = str(tier_cfg(which).get("reward_text", ""))
	var own_faction := faction()
	conditions["faction"] = str(own_faction.get("name", ""))
	conditions["profile"] = str(own_faction.get("profile", ""))
	conditions["faction_text"] = str(own_faction.get("text", ""))
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
	last_loot = []
	if not won:
		lives -= 1
		if lives <= 0:
			_finish(Phase.LOST)
			return
		_enter_stop()
		return
	last_loot = roll_loot(enemy_pool)
	for item in last_loot:
		_apply_loot(item)
	if round >= rounds_total():
		_finish(Phase.WON)
		return
	_enter_stop()


## Sammelt die EP eines Kampfes, BEVOR record_result ihn eintraegt (Runde und
## Stufe stimmen dann noch). ``fighters``: je Squad-DROME {source_uid,
## weapons: {slot: {damage, kills}}} aus dem Kampf. DROMEs bekommen EP nur
## fuer einen Sieg, Waffen fuer Schaden und Abschuesse in jedem Kampf -- aber
## nur Waffen aus dem Hangar (Exemplar-uid), die im Halter stecken.
func collect_xp(fighters: Array, won: bool) -> void:
	last_growth = []
	var records := {}
	for row in fighters:
		records[str(row.get("source_uid", ""))] = row.get("weapons", {})
	for build in squad:
		if build.source_uid == "":
			continue
		if won:
			var gain := Leveling.drome_win_xp(TIER_KEYS[tier], round)
			_add_pending("dromes", build.source_uid, gain)
			last_growth.append({"kind": "drome", "uid": build.source_uid,
				"name": build.display_name, "gain": gain})
		var weapons: Dictionary = records.get(build.source_uid, {})
		for slot in build.instance_uids:
			var part: PartData = build.part_in(slot)
			if part == null:
				continue
			var rec: Dictionary = weapons.get(slot, {})
			var gain := Leveling.weapon_fight_xp(int(rec.get("damage", 0)), int(rec.get("kills", 0)))
			if gain <= 0:
				continue
			var uid := str(build.instance_uids[slot])
			_add_pending("weapons", uid, gain)
			last_growth.append({"kind": "weapon", "uid": uid, "name": part.display_name,
				"gain": gain})


func _add_pending(kind: String, uid: String, gain: int) -> void:
	var table: Dictionary = pending_xp[kind]
	table[uid] = int(table.get(uid, 0)) + gain


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
	for id in bag:
		counts[id] = int(counts.get(id, 0)) + 1
	bag.clear()
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
	shop_offers = []
	bios_offers = []
	rerolls = 0
	phase = Phase.PREPARE


## Weiter in den Zwischenstopp -- dabei wird der Laden gewuerfelt.
func _enter_stop() -> void:
	phase = Phase.STOP
	rerolls = 0
	shop_offers = roll_shop()


## Die Beute haengt an der Stufe des besiegten Gegners und wird gewuerfelt
## (6i, keine Auswahl). Ein Hauptwurf:
##
##   DROME   Normal in run.new_drome_rounds, Elite mit tiers.elite.drome_chance
##   Teil    mit tiers.<stufe>.part_chance -- aus der Gegnerausruestung, bei
##           Elite mittel/schwer (fehlt dort etwas, aus dem ganzen Katalog)
##   sonst   Credits (tiers.<stufe>.loot_credits)
##
## Dazu, wenn ein Leben fehlt, mit life_chance Notstrom (nicht bei Elite).
## Am Seed des Kampfes: derselbe Lauf, dieselbe Beute.
func roll_loot(enemy_pool: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = battle_seed() ^ 0x5EED
	var settings := tier_cfg(tier)
	var out: Array = []
	# JSON liefert Gleitkommazahlen -- 2.0 ist fuer "in" nicht 2.
	var drome_rounds: Array = (cfg().get("new_drome_rounds", [2, 5]) as Array).map(func(r): return int(r))
	var drome := (tier == Tier.NORMAL and round in drome_rounds) \
		or (tier == Tier.ELITE and rng.randf() < float(settings.get("drome_chance", 0.0)))
	if drome:
		var entry := _drome_reward(rng)
		entry["rare"] = tier == Tier.ELITE
		out.append(entry)
	elif tier == Tier.ELITE and round < rounds_total() and not roll_bios_offers().is_empty():
		# Elite: ein Matrix-BIOS zur Wahl statt des Teils -- nie nach dem
		# letzten Kampf, dort waere es wertlos (Module verfallen).
		out.append({"kind": "bios", "rare": true, "title": "Matrix-BIOS",
			"text": "Waehle eines von %d -- es kommt ins Lager." % int(ModuleData.rule("bios_offers", 3))})
	elif rng.randf() < float(settings.get("part_chance", 0.5)):
		var part := _loot_part(rng, enemy_pool)
		if part != null:
			out.append({"kind": "part", "part_id": part.id, "rare": tier == Tier.ELITE,
				"title": part.display_name, "text": _part_text(part)})
	if out.is_empty():
		var amount := int(settings.get("loot_credits", 5))
		out.append({"kind": "credits", "amount": amount,
			"title": "%d Credits" % amount, "text": "Gefundene Credits"})
	if tier != Tier.ELITE and lives < max_lives() \
			and rng.randf() < float(settings.get("life_chance", cfg().get("life_chance", 0.35))):
		out.append({"kind": "life", "title": "Notstrom",
			"text": "Ein verlorenes Leben zurueck."})
	return out


## Ein Teil als Beute: aus der Gegnerausruestung; Elite nur mittel/schwer,
## ergaenzt aus dem ganzen Katalog. Leerer Gegnerpool: der ganze Katalog.
func _loot_part(rng: RandomNumberGenerator, enemy_pool: Array) -> PartData:
	var pool: Array = enemy_pool.duplicate()
	if tier == Tier.ELITE:
		pool = pool.filter(func(id): return _is_rare(PartDB.get_part(id)))
		for part in PartDB.of_type(PartData.Type.EQUIPMENT):
			if _is_rare(part) and not pool.has(part.id):
				pool.append(part.id)
	elif pool.is_empty():
		for part in PartDB.of_type(PartData.Type.EQUIPMENT):
			pool.append(part.id)
	while not pool.is_empty():
		var index := rng.randi() % pool.size()
		var part := PartDB.get_part(pool[index])
		if part != null:
			return part
		pool.remove_at(index)
	return null


## Verteilt einen Beute-Eintrag und schreibt hinein, wo er gelandet ist:
## Teile in die Tasche (gehen am Ende nach Hause), ein DROME in den Squad
## (voll: nach Hause), Credits und Notstrom sofort.
func _apply_loot(item: Dictionary) -> void:
	item["where"] = ""
	match item["kind"]:
		"part":
			item["where"] = "tasche"
			bag.append(StringName(item["part_id"]))
		"drome":
			if has_room():
				item["where"] = "squad"
				var fresh := drome_from_reward(item)
				squad.append(fresh)
				# Seine Waffe gehoert zu ihm wie die Startausstattung.
				_count_start(fresh)
			else:
				item["where"] = "home"
				home_queue.append(item.duplicate())
		"bios":
			item["where"] = "wahl"
			bios_offers = roll_bios_offers()
		"credits":
			credits += int(item.get("amount", 0))
		"life":
			lives = mini(max_lives(), lives + 1)


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


## Ob ein neuer DROME noch in den Lauf-Squad passt. Sonst bleibt nur "nach
## Hause".
func has_room() -> bool:
	return squad.size() < squad_max()


## Baut aus einer DROME-Belohnung den Aufbau: Chassis, passender Kern, Waffe.
static func drome_from_reward(option: Dictionary) -> DromeBuild:
	var body := PartDB.get_part(option["body_id"])
	var core := PartDB.frame_mate(body.set_id, PartData.Type.CORE)
	var fresh := _frame(body.display_name.replace(" Chassis", ""),
		body.id, core.id if core != null else &"scout_core")
	if StringName(option.get("weapon_id", &"")) != &"":
		_equip(fresh, option["weapon_id"])
	return fresh


# ---------------------------------------------------------------------------
# Zwischenstopp: Lager, Credits, Ausruesten (NEUANFANG 7d)
# ---------------------------------------------------------------------------

func storage_full() -> bool:
	return storage.size() >= storage_size()


## Weiter zum naechsten Kampf.
func continue_run() -> void:
	if phase == Phase.STOP:
		_advance()


## Verkauft das Modul aus Lagerplatz ``index``. Gibt die Credits zurueck.
func sell(index: int) -> int:
	if phase != Phase.STOP or index < 0 or index >= storage.size():
		return 0
	var value := ModuleData.sell_value(ModuleData.get_module(storage[index])) \
		if ModuleData.is_module(storage[index]) else sell_value(PartDB.get_part(storage[index]))
	storage.remove_at(index)
	credits += value
	return value


# ---------------------------------------------------------------------------
# Module und Rezepte (NEUANFANG 6g)
# ---------------------------------------------------------------------------

## Liegt auf Lagerplatz ``index`` ein Modul?
func is_module_at(index: int) -> bool:
	return index >= 0 and index < storage.size() and ModuleData.is_module(storage[index])


## Wohin das Modul aus Lagerplatz ``index`` passt: je DROME und Waffenhalter
## ein Eintrag {drome, slot, allowed, active, detail}. ``allowed``: es ist
## Platz; ``active``: es wirkt an der Waffe, die gerade drinsteckt (sonst
## ruht es, ``detail`` sagt warum).
func module_options(index: int) -> Array:
	var out: Array = []
	if not is_module_at(index):
		return out
	var module := ModuleData.get_module(storage[index])
	for drome in squad.size():
		var build: DromeBuild = squad[drome]
		for slot in build.equip_slots():
			var room := ModuleData.slots_for(build, slot)
			var used := build.module_count(slot)
			var weapon := build.part_in(slot)
			var twice := _recipe_twice(build, slot, module)
			var second_bios := module.is_bios_result and has_bios_recipe(build)
			var entry := {"drome": drome, "slot": slot,
				"allowed": used < room and not twice and not second_bios and not module.is_bios_item(),
				"active": module.fits(weapon), "detail": ""}
			if module.is_bios_item():
				entry["detail"] = "ein BIOS steckt nicht im Halter"
			elif second_bios:
				entry["detail"] = "hoechstens ein BIOS-Rezept je DROME"
			elif twice:
				entry["detail"] = "%s steckt hier schon drin (Rezepte einmal je Halter)" % module.display_name
			elif used >= room:
				entry["detail"] = "Modulplaetze voll (%d/%d)" % [used, room]
			elif weapon == null:
				entry["detail"] = "Halter leer -- ruht, bis eine Waffe drin ist"
			elif not entry["active"]:
				entry["detail"] = "ruht: %s" % module.blocker(weapon)
			else:
				entry["detail"] = "wirkt an %s (%d/%d)" % [weapon.display_name, used + 1, room]
			out.append(entry)
	return out


## Setzt das Modul aus Lagerplatz ``index`` in den Waffenhalter ``slot`` von
## DROME ``drome``.
func install_module(index: int, drome: int, slot: String) -> bool:
	if phase != Phase.STOP or not is_module_at(index) or drome < 0 or drome >= squad.size():
		return false
	var build: DromeBuild = squad[drome]
	if slot not in build.equip_slots() or build.module_count(slot) >= ModuleData.slots_for(build, slot):
		return false
	var module := ModuleData.get_module(storage[index])
	if module.is_bios_item() or (module.is_bios_result and has_bios_recipe(build)):
		return false
	if _recipe_twice(build, slot, module):
		return false
	var list: Array = build.modules.get(slot, [])
	list.append(storage[index])
	build.modules[slot] = list
	storage.remove_at(index)
	return true


## Steckt dieses Rezept schon in diesem Halter -- selbst oder als Teil eines
## anderen Rezepts (Taktchip neben Taktgeber)? Rezepte gibt es nur einmal je
## Halter (6i: sonst drei Taktgeber an einer Waffe). Grundmodule stapeln.
func _recipe_twice(build: DromeBuild, slot: String, module: ModuleData) -> bool:
	if module == null or not module.is_recipe():
		return false
	var mine := module.parts()
	for other_id in build.modules.get(slot, []):
		var other := ModuleData.get_module(other_id)
		if other == null or not other.is_recipe():
			continue
		if other.parts().has(module.id) or mine.has(other.id):
			return true
	return false


## Nimmt das ``position``-te Modul aus dem Halter zurueck ins Lager.
func remove_module(drome: int, slot: String, position: int) -> bool:
	if phase != Phase.STOP or storage_full() or drome < 0 or drome >= squad.size():
		return false
	var build: DromeBuild = squad[drome]
	var list: Array = build.modules.get(slot, [])
	if position < 0 or position >= list.size():
		return false
	storage.append(list[position])
	list.remove_at(position)
	if list.is_empty():
		build.modules.erase(slot)
	else:
		build.modules[slot] = list
	return true


## Das Rezeptbuch: je Rezept {module, have: [bool je Zutat], ready}. Gezaehlt
## wird nur, was im LAGER liegt -- zusammengefuegt wird dort.
func recipe_book() -> Array:
	var out: Array = []
	# BIOS-Rezepte erscheinen, sobald ihr BIOS im Lager liegt: Rezept + BIOS
	# oder Zutat + Zutat + BIOS.
	for item in ModuleData.bios_items():
		if item.bios_kind != "recipe" or not storage.has(item.id):
			continue
		var result := ModuleData.get_module(item.bios_result)
		if result == null:
			continue
		out.append({"module": result, "bios": item.id, "have": _bios_have(item),
			"ready": _bios_ingredients(item) != []})
	for recipe in ModuleData.recipes():
		var pool := storage.duplicate()
		var have: Array = []
		for ingredient in recipe.from:
			var found := pool.find(ingredient)
			have.append(found >= 0)
			if found >= 0:
				pool.remove_at(found)
		out.append({"module": recipe, "have": have, "ready": not have.has(false)})
	return out


## Fuegt ein Rezept zusammen: die Zutaten verschwinden aus dem Lager, das
## Ergebnis nimmt einen Platz ein.
func craft(recipe_id: StringName) -> bool:
	if phase != Phase.STOP:
		return false
	var recipe := ModuleData.get_module(recipe_id)
	if recipe == null or not recipe.is_recipe():
		return false
	if recipe.is_bios_result:
		return _craft_bios(recipe)
	var pool := storage.duplicate()
	for ingredient in recipe.from:
		var found := pool.find(ingredient)
		if found < 0:
			return false
		pool.remove_at(found)
	pool.append(recipe.id)
	storage = pool
	return true


# ---------------------------------------------------------------------------
# Matrix-BIOS (MODULE_KONZEPT.md 6)
# ---------------------------------------------------------------------------

## Was der Lauf an Modulen hat, um ``item`` (Rezept-BIOS) zu verschmelzen:
## [Grundrezept] oder [Zutat, Zutat] aus dem Lager -- leer, wenn es fehlt.
func _bios_ingredients(item: ModuleData) -> Array:
	var recipe := ModuleData.get_module(item.bios_recipe)
	if recipe == null:
		return []
	if storage.has(recipe.id):
		return [recipe.id]
	var pool := storage.duplicate()
	for ingredient in recipe.from:
		var found := pool.find(ingredient)
		if found < 0:
			return []
		pool.remove_at(found)
	return recipe.from.duplicate()


## Fuer die Anzeige im Rezeptbuch: [Rezept da?] bzw. je Zutat.
func _bios_have(item: ModuleData) -> Array:
	var recipe := ModuleData.get_module(item.bios_recipe)
	if recipe == null:
		return [false]
	if storage.has(recipe.id):
		return [true]
	var pool := storage.duplicate()
	var have: Array = []
	for ingredient in recipe.from:
		var found := pool.find(ingredient)
		have.append(found >= 0)
		if found >= 0:
			pool.remove_at(found)
	return [have.count(true) == have.size()]


func _craft_bios(result: ModuleData) -> bool:
	var item: ModuleData = null
	for candidate in ModuleData.bios_items():
		if candidate.bios_result == result.id and storage.has(candidate.id):
			item = candidate
	if item == null:
		return false
	var used := _bios_ingredients(item)
	if used.is_empty():
		return false
	var pool := storage.duplicate()
	pool.erase(item.id)
	for id in used:
		pool.erase(id)
	pool.append(result.id)
	storage = pool
	return true


## Die BIOS-Wahl nach einem Elite-Sieg (6.2): rules.bios_offers Angebote, jedes
## nutzbar. Rangfolge: SOFORT (Rezept steckt im Lauf, oder Chassis-BIOS fuer
## einen DROME im Squad ohne BIOS), BALD (beide Zutaten im Lauf), ANGEFANGEN
## (eine Zutat) nur als Lueckenfueller. Mindestens eines ist sofort nutzbar --
## sonst gibt es keine Wahl (dann die normale Beute). Nie fuer DROMEs ausser-
## halb des Squads oder Rezepte ohne vorhandene Zutat.
func roll_bios_offers() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash([run_seed, round, "bios"]))
	var owned := _owned_modules()
	var ranks := [[], [], []]
	for item in ModuleData.bios_items():
		if item.bios_kind == "chassis":
			for build in squad:
				if build.body() != null and build.body().id == item.bios_chassis \
						and not build.chassis_bios and not ranks[0].has(item.id):
					ranks[0].append(item.id)
			continue
		var recipe := ModuleData.get_module(item.bios_recipe)
		if recipe == null:
			continue
		if owned.has(recipe.id):
			ranks[0].append(item.id)
			continue
		var have := 0
		var pool := owned.duplicate()
		for ingredient in recipe.from:
			var found := pool.find(ingredient)
			if found >= 0:
				have += 1
				pool.remove_at(found)
		if have >= recipe.from.size():
			ranks[1].append(item.id)
		elif have > 0:
			ranks[2].append(item.id)
	if ranks[0].is_empty():
		return []
	var out: Array = []
	var want := int(ModuleData.rule("bios_offers", 3))
	for rank in ranks:
		var list: Array = rank.duplicate()
		while not list.is_empty() and out.size() < want:
			var pick := rng.randi() % list.size()
			out.append(list[pick])
			list.remove_at(pick)
	return out


func bios_blocker() -> String:
	if phase != Phase.STOP or bios_offers.is_empty():
		return "keine Wahl"
	if storage_full():
		return "Lager voll -- erst verkaufen"
	return ""


## Nimmt BIOS-Angebot ``index`` ins Lager; die anderen verfallen.
func choose_bios(index: int) -> bool:
	if bios_blocker() != "" or index < 0 or index >= bios_offers.size():
		return false
	storage.append(StringName(bios_offers[index]))
	bios_offers = []
	return true


func is_bios_at(index: int) -> bool:
	if index < 0 or index >= storage.size():
		return false
	var item := ModuleData.get_module(storage[index])
	return item != null and item.is_bios_item()


## Wohin das Chassis-BIOS aus Lagerplatz ``index`` passt: je DROME und Halter
## {drome, slot, allowed, detail}.
func bios_options(index: int) -> Array:
	var out: Array = []
	if not is_bios_at(index):
		return out
	var item := ModuleData.get_module(storage[index])
	for drome in squad.size():
		var build: DromeBuild = squad[drome]
		for slot in build.equip_slots():
			var entry := {"drome": drome, "slot": slot, "allowed": false, "detail": ""}
			if item.bios_kind != "chassis":
				entry["detail"] = "im Rezeptbuch verschmelzen"
			elif build.body() == null or build.body().id != item.bios_chassis:
				entry["detail"] = "nur fuer %s" % item.display_name.trim_suffix("-BIOS")
			elif build.chassis_bios:
				entry["detail"] = "hat schon ein BIOS"
			else:
				entry["allowed"] = true
				entry["detail"] = "+1 Modulplatz hier, Passive verstaerkt"
			out.append(entry)
	return out


## Baut das Chassis-BIOS aus Lagerplatz ``index`` in DROME ``drome`` ein; der
## Extraplatz gehoert zu ``slot`` (wichtig beim Molok mit zwei Haltern).
func install_bios(index: int, drome: int, slot: String) -> bool:
	if phase != Phase.STOP:
		return false
	for entry in bios_options(index):
		if int(entry["drome"]) == drome and entry["slot"] == slot and entry["allowed"]:
			var build: DromeBuild = squad[drome]
			build.chassis_bios = true
			build.bios_slot = slot if build.equip_slots().size() > 1 else ""
			storage.remove_at(index)
			return true
	return false


## Steckt in diesem DROME schon ein BIOS-Rezept? Hoechstens eines je DROME.
static func has_bios_recipe(build: DromeBuild) -> bool:
	for slot in build.modules:
		for id in build.modules[slot]:
			var module := ModuleData.get_module(id)
			if module != null and module.is_bios_result:
				return true
	return false


# ---------------------------------------------------------------------------
# Der Laden (NEUANFANG 6i)
# ---------------------------------------------------------------------------

## Was ein Modul im Laden kostet (modules.json -> shop.price).
static func shop_price(module: ModuleData) -> int:
	if module == null:
		return 0
	var prices: Dictionary = (ModuleData.data().get("shop", {}) as Dictionary).get("price", {})
	return int(prices.get("recipe" if module.is_recipe() else "base", 6))


## Wuerfelt die Angebote dieses Zwischenstopps: shop.offers Grundmodule,
## keines doppelt. Unsichtbares Mitleid (6i, MODULE_KONZEPT.md 7): mit
## Ziel-Rezept zaehlen nur dessen fehlende Zutaten shop.recipe_weight-mal so
## viel, ohne Ziel jede Zutat, die einem angefangenen Rezept fehlt,
## shop.recipe_weight_open-mal. Ab shop.recipe_from_round ist mit
## shop.recipe_chance das letzte Angebot ein fertiges Rezept.
## Am Seed von Lauf, Runde und Wurf -- derselbe Lauf hat denselben Laden.
func roll_shop() -> Array:
	var settings: Dictionary = ModuleData.data().get("shop", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash([run_seed, round, rerolls, "laden"]))
	var pool: Array = ModuleData.base_modules().duplicate()
	var wanted := target_missing() if target_recipe != &"" else recipe_missing()
	var boost := float(settings.get("recipe_weight", 3.0)) if target_recipe != &"" \
		else float(settings.get("recipe_weight_open", 2.0))
	# Ein Rezept-BIOS im Lager: dessen fehlende Zutaten kommen voll gewichtet.
	var bios_wanted := _bios_missing()
	var full := float(settings.get("recipe_weight", 3.0))
	var count := int(settings.get("offers", 3))
	var out: Array = []
	var with_recipe := round >= int(settings.get("recipe_from_round", 5)) \
		and rng.randf() < float(settings.get("recipe_chance", 0.25))
	if with_recipe:
		count -= 1
	for _i in count:
		if pool.is_empty():
			break
		var weights: Array = []
		var total := 0.0
		for module in pool:
			var weight := full if bios_wanted.has(module.id) \
				else (boost if wanted.has(module.id) else 1.0)
			weights.append(weight)
			total += weight
		var roll := rng.randf() * total
		var pick := pool.size() - 1
		for i in pool.size():
			roll -= float(weights[i])
			if roll < 0.0:
				pick = i
				break
		out.append({"module_id": pool[pick].id, "sold": false})
		pool.remove_at(pick)
	if with_recipe:
		var recipes := ModuleData.recipes()
		out.append({"module_id": recipes[rng.randi() % recipes.size()].id, "sold": false})
	return out


## Was das naechste Neuwuerfeln kostet: shop.reroll.price, je weiterem Wurf im
## selben Zwischenstopp +shop.reroll.step.
func reroll_price() -> int:
	var settings: Dictionary = (ModuleData.data().get("shop", {}) as Dictionary).get("reroll", {})
	return int(settings.get("price", 2)) + rerolls * int(settings.get("step", 1))


func reroll_blocker() -> String:
	if phase != Phase.STOP:
		return "kein Laden"
	if credits < reroll_price():
		return "zu wenig Credits"
	return ""


## Neue Angebote fuer Credits. Auch gekaufte Plaetze werden neu besetzt.
func reroll_shop() -> bool:
	if reroll_blocker() != "":
		return false
	credits -= reroll_price()
	rerolls += 1
	shop_offers = roll_shop()
	return true


## Markiert ein Rezept als Ziel (noch einmal: Ziel weg). Gilt ab dem naechsten
## Wurf des Ladens.
func set_target_recipe(recipe_id: StringName) -> void:
	var recipe := ModuleData.get_module(recipe_id)
	if recipe == null or not recipe.is_recipe() or target_recipe == recipe_id:
		target_recipe = &""
	else:
		target_recipe = recipe_id


## Die Zutaten des Ziel-Rezepts, die im Lauf (Lager oder Halter) fehlen.
func target_missing() -> Array:
	var recipe := ModuleData.get_module(target_recipe)
	if recipe == null:
		return []
	var pool := _owned_modules()
	var out: Array = []
	for ingredient in recipe.from:
		var found := pool.find(ingredient)
		if found >= 0:
			pool.remove_at(found)
		elif not out.has(ingredient):
			out.append(ingredient)
	return out


## Zutaten, die den Rezepten der Rezept-BIOS im Lager fehlen.
func _bios_missing() -> Array:
	var out: Array = []
	var owned := _owned_modules()
	for id in storage:
		var item := ModuleData.get_module(id)
		if item == null or item.bios_kind != "recipe":
			continue
		var recipe := ModuleData.get_module(item.bios_recipe)
		if recipe == null or owned.has(recipe.id):
			continue
		var pool := owned.duplicate()
		for ingredient in recipe.from:
			var found := pool.find(ingredient)
			if found >= 0:
				pool.remove_at(found)
			elif not out.has(ingredient):
				out.append(ingredient)
	return out


func _owned_modules() -> Array:
	var owned: Array = storage.filter(func(id): return ModuleData.is_module(id))
	for build in squad:
		for slot in build.modules:
			owned.append_array(build.modules[slot])
	return owned


## Grundmodule, die einem angefangenen Rezept fehlen: von dem Rezept liegt
## mindestens eine Zutat im Lauf (Lager oder Halter), diese aber nicht.
func recipe_missing() -> Array:
	var owned := _owned_modules()
	var out: Array = []
	for recipe in ModuleData.recipes():
		var pool := owned.duplicate()
		var have := 0
		var missing: Array = []
		for ingredient in recipe.from:
			var found := pool.find(ingredient)
			if found >= 0:
				have += 1
				pool.remove_at(found)
			else:
				missing.append(ingredient)
		if have == 0:
			continue
		for id in missing:
			var module := ModuleData.get_module(id)
			if module != null and not module.is_recipe() and not out.has(module.id):
				out.append(module.id)
	return out


## Warum Angebot ``index`` gerade nicht zu kaufen ist -- leer, wenn es geht.
func shop_blocker(index: int) -> String:
	if phase != Phase.STOP or index < 0 or index >= shop_offers.size():
		return "kein Angebot"
	var offer: Dictionary = shop_offers[index]
	if offer["sold"]:
		return "verkauft"
	if credits < shop_price(ModuleData.get_module(offer["module_id"])):
		return "zu wenig Credits"
	if storage_full():
		return "Lager voll"
	return ""


## Kauft Angebot ``index``: Credits weg, Modul ins Lager.
func buy(index: int) -> bool:
	if shop_blocker(index) != "":
		return false
	var offer: Dictionary = shop_offers[index]
	credits -= shop_price(ModuleData.get_module(offer["module_id"]))
	storage.append(StringName(offer["module_id"]))
	offer["sold"] = true
	return true
