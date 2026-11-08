extends RefCounted

## Siehe module_bench.gd.

const DEFAULT_SETUPS := [
	"",
	"Vireo=mod_rapid_fire",
	"Vireo=mod_rapid_fire+mod_rapid_fire+mod_rapid_fire",
	"Vireo=mod_takt_chip",
	"Vireo=mod_takt_chip+mod_takt_chip",
	"Nimbus=mod_takt_chip",
	"Nimbus=mod_takt_chip+mod_takt_chip+mod_takt_chip",
	"Nimbus=mod_metronome",
	"Strix=mod_takt_chip",
	"Strix=mod_takt_chip+mod_takt_chip",
	"Molok=mod_brawler",
]


func run(count: int, setups: Array) -> void:
	if GameState.roster.entries.is_empty():
		GameState.load_roster()
	var builds: Array = GameState.battle_ready_builds()
	_describe(builds)
	if setups.is_empty():
		setups = DEFAULT_SETUPS
	for setup in setups:
		var ours := _apply(builds, String(setup))
		var wins := 0
		var fights := 0
		var seconds := 0.0
		for i in count:
			var seed_value := 9000 + i
			# Seiten tauschen, damit Aufstellung und Reihenfolge nichts verfaelschen.
			for swap in [false, true]:
				var r := _play(seed_value, ours, builds, swap)
				fights += 1
				seconds += float(r["seconds"])
				if r["ours_won"]:
					wins += 1
		print("%-60s %5.1f %%  (%d Kaempfe, %.1f s)" % [
			setup if setup != "" else "(ohne Module)",
			100.0 * wins / fights, fights, seconds / fights])


## Waffe, Takt und Lauftempo je DROME -- zum Nachrechnen.
func _describe(builds: Array) -> void:
	for b in builds:
		var unit := Unit.create(b, &"X", true)
		print("%s: SPD %d, Lauftempo %.2f Felder/s" % [b.display_name, int(b.stats()["spd"]), unit.move_speed()])
		unit.free()
		for slot in b.equip_slots():
			var part: PartData = b.part_in(slot)
			if part == null:
				continue
			var bits: Array[String] = []
			for a in part.actions:
				var action: ActionData = a
				if action.is_attack():
					bits.append("Angriff alle %.2f s, Rw %d" % [action.interval, action.range_tiles])
				else:
					bits.append("%s: %s %s" % [action.display_name, action.trigger_kind, action.trigger_every])
			print("%s [%s] %s: %s" % [b.display_name, slot, part.display_name, "; ".join(bits)])


func _apply(builds: Array, setup: String) -> Array:
	var out: Array = builds.map(func(b): return b.clone())
	if setup == "":
		return out
	for chunk in setup.split("/"):
		var pair := chunk.split("=")
		for b in out:
			if b.display_name == pair[0]:
				var slot: String = b.equip_slots()[0]
				b.modules[slot] = Array(pair[1].split("+"))
	return out


func _play(seed_value: int, ours: Array, theirs: Array, swap: bool) -> Dictionary:
	var battle := BattleManager.new()
	var a: Array = ours.map(func(b): return b.clone())
	var b: Array = theirs.map(func(x): return x.clone())
	if swap:
		battle.setup(seed_value, b, a)
	else:
		battle.setup(seed_value, a, b)
	var guard := 0
	while battle.outcome == BattleManager.Outcome.RUNNING and guard < 100000:
		battle.tick()
		guard += 1
	var player_won := battle.outcome == BattleManager.Outcome.VICTORY
	return {"ours_won": player_won != swap, "seconds": battle.time}
