class_name DromeForge
extends RefCounted

## Neue DROMEs bauen (15. Nov. 2026 im Shop, seit 22. Nov. 2026 im Tab DROMEs,
## Design-Canvas "Fuenf Tabs"): aus Baukernen. Ein Standard-DROME kostet
## kits_per_drome Baukerne, ein Fraktions-DROME dazu einen Fraktionskern.
## Freie Chassis aus alter Beute lassen sich weiter ohne Kosten bauen.
## Kacheln wie ueberall: tippen waehlt, nochmal tippen zeigt, Doppeltipp baut.

const TILE_COLUMNS := 4
const TILE_GAP := 10


## Ueberschrift, Bestand und die Kacheln -- in ``parent``; Popups ueber ``host``.
static func add_to(parent: Control, host: Control) -> void:
	var roster := GameState.roster
	var need := Roster.kits_per_drome()
	parent.add_child(UiKit.heading("Neuen DROME bauen"))
	parent.add_child(UiKit.label("%s: %d / %d  ·  Doppeltipp baut" % [Roster.kit_name(), roster.kits(),
		need], UiKit.SMALL, UiKit.GOOD if roster.kits() >= need else UiKit.MUTED))
	var grid := GridContainer.new()
	grid.columns = TILE_COLUMNS
	grid.add_theme_constant_override("h_separation", TILE_GAP)
	grid.add_theme_constant_override("v_separation", TILE_GAP)
	parent.add_child(grid)
	var list := specs()
	var pages: Array = []
	for spec in list:
		pages.append(func() -> Dictionary: return page(host, spec))
	for k in list.size():
		var spec: Dictionary = list[k]
		var body := PartDB.get_part(spec["chassis"])
		if body == null:
			continue
		var tile := Tile.new("build:%s" % spec["id"], UiKit.chassis_view(body, 64), str(spec["name"]),
			Vector2(0, 104))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.glow = bool(spec["ready"])
		tile.accent = UiKit.GOOD if spec["ready"] else UiKit.ACCENT
		tile.dimmed = not bool(spec["ready"])
		tile.add_caption(str(spec["cost"]), UiKit.WARN if spec["ready"] else UiKit.MUTED, 11)
		var at: int = k
		tile.on_info = func(): InfoPopup.open_pages(host, pages, at)
		tile.on_action = func(): build(host, spec)
		grid.add_child(tile)


## Was sich bauen laesst: freie Chassis (kostenlos), die vier Standard-DROMEs
## (Baukerne) und Fraktions-DROMEs, fuer deren Fraktion ein Kern da ist.
static func specs() -> Array:
	var roster := GameState.roster
	var need := Roster.kits_per_drome()
	var out: Array = []
	for chassis_id in roster.free_chassis_types():
		var body := PartDB.get_part(chassis_id)
		out.append({"id": "free:%s" % chassis_id, "kind": "free", "chassis": chassis_id,
			"name": body.display_name.replace(" Chassis", ""), "cost": "freies Chassis", "ready": true})
	for row in Roster.STARTER_CHASSIS:
		var body := PartDB.get_part(row["body"])
		if body == null:
			continue
		out.append({"id": "std:%s" % row["body"], "kind": "standard", "chassis": row["body"],
			"name": body.display_name.replace(" Chassis", ""), "cost": "%d %s" % [need, Roster.kit_name()],
			"ready": roster.kits() >= need})
	for variant in Roster.faction_variants():
		var spec: Dictionary = Formations.data()["dromes"][variant]
		var faction := str(spec.get("faction", ""))
		if roster.faction_cores(faction) <= 0:
			continue
		out.append({"id": "fac:%s" % variant, "kind": "faction", "variant": variant,
			"chassis": StringName(str(spec["chassis"])), "name": str(spec["name"]),
			"cost": "%s + %d" % [Roster.core_name(faction), need],
			"ready": roster.kits() >= need})
	return out


static func page(host: Control, spec: Dictionary) -> Dictionary:
	var roster := GameState.roster
	var lines: Array = []
	match str(spec["kind"]):
		"free":
			lines.append("Ein freies Chassis aus der Beute -- baut sich ohne Kosten.")
		"standard":
			lines.append("Standard-DROME aus %d %s (du hast %d). Chassis und Kern, ohne Waffe."
				% [Roster.kits_per_drome(), Roster.kit_name(), roster.kits()])
		"faction":
			var data: Dictionary = Formations.data()["dromes"][spec["variant"]]
			var st: Dictionary = data.get("stats", {})
			lines.append("Fraktions-DROME: %s + %d %s. Feste Werte, ohne Waffe."
				% [Roster.core_name(str(data["faction"])), Roster.kits_per_drome(), Roster.kit_name()])
			lines.append(["Integrität %d · Schild %d · Speed %d · Rüstung %d · Power %d" % [
				int(st.get("hp_max", 0)), int(st.get("shield", 0)), int(st.get("spd", 0)),
				int(st.get("def", 0)), int(st.get("power", 0))], UiKit.HEADING])
	lines.append(["Verwertete DROMEs geben Baukerne, Fraktions-DROMEs dazu ihren Kern. "
		+ "Baukerne gibt es auch im Shop.", UiKit.MUTED, UiKit.SMALL])
	var body := PartDB.get_part(spec["chassis"])
	return {"title": str(spec["name"]), "subtitle": str(spec["cost"]),
		"picture": UiKit.chassis_view(body, 64) if body != null else null, "lines": lines,
		"actions": [{"text": "Bauen", "primary": true, "disabled": not bool(spec["ready"]),
			"why": "%s fehlen" % Roster.kit_name(), "call": func(): build(host, spec)}]}


static func build(host: Control, spec: Dictionary) -> void:
	if not bool(spec["ready"]):
		InfoPopup.open(host, "Fehlt noch", {"lines": ["Dafür brauchst du %s." % spec["cost"]]})
		return
	var roster := GameState.roster
	var entry: RosterEntry = null
	match str(spec["kind"]):
		"free": entry = roster.new_drome(spec["chassis"])
		"standard": entry = roster.craft_drome(spec["chassis"])
		"faction": entry = roster.craft_faction_drome(str(spec["variant"]))
	if entry == null:
		return
	Accessibility.vibrate(40, true)
	GameState.save_roster()
	GameState.refresh_squad()
	# Gleich in die Ausruestung des neuen DROME -- er hat noch keine Waffe.
	GameState.editing_index = GameState.roster.entries.size() - 1
	Fader.go("res://scenes/hangar.tscn")
