extends Control

## Der Shop (15. Nov. 2026, Wunsch des Spielers): der rechte Tab der Leiste,
## anstelle der Optionen (die sitzen jetzt am Zahnrad oben rechts). Drei
## Reiter:
##
##   Shop     Angebote fuer Platzhaltercoin -- Baukerne und Caches
##            (Roster.shop_offers, config hangar_shop)
##   Caches   die Lootcaches im Hangar; oeffnen kommt mit Bauschritt 4.
##            Caches und Bosse koennen spaeter Komponenten (Baukerne,
##            Fraktionskerne) oder gleich ganze DROMEs enthalten.
##   Bauen    Material (Baukerne, Fraktionskerne) und neue DROMEs daraus
##
## Kacheln wie ueberall: tippen waehlt, nochmal tippen zeigt Details
## (blaetterbar), Doppeltipp handelt (kaufen, bauen).

const TILE_COLUMNS := 4
const TILE_GAP := 10

static var _tab := "shop"

var _content: VBoxContainer
var _tabs: HBoxContainer


func _ready() -> void:
	_content = UiKit.page(self, "Shop", "", 2, true, Ambience.Kind.HANGAR)
	# Die Reiter fest ueber dem rollenden Inhalt (zwischen Kopf und Liste).
	var margin := _content.get_parent().get_parent() as Control
	var frame := margin.get_parent()
	var holder := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		holder.add_theme_constant_override(side, UiKit.PAD)
	holder.add_theme_constant_override("margin_top", 10)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	holder.add_child(_tabs)
	frame.add_child(holder)
	frame.move_child(holder, margin.get_index())
	_refresh()


func _refresh() -> void:
	for child in _tabs.get_children():
		child.queue_free()
	for spec in [["shop", "Shop"], ["caches", "Caches"], ["bauen", "Bauen"]]:
		var button := UiKit.button(spec[1])
		button.custom_minimum_size = Vector2(0, 48)
		if _tab == spec[0]:
			button.add_theme_stylebox_override("normal", UiKit.card_style(true))
			button.add_theme_color_override("font_color", UiKit.ACCENT)
		var which: String = spec[0]
		button.pressed.connect(func():
			_tab = which
			Tile.clear_choice()
			_refresh())
		_tabs.add_child(button)
	for child in _content.get_children():
		child.queue_free()
	_content.add_child(_wallet())
	match _tab:
		"shop": _shop_section()
		"caches": _caches_section()
		_: _build_section()


## Was man hat: Coins, Baukerne, Fraktionskerne, Caches -- eine Zeile Chips.
func _wallet() -> Control:
	var roster := GameState.roster
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	flow.add_child(_chip("◈ %d %s" % [roster.coins, RunState.coin_name()], UiKit.WARN))
	flow.add_child(_chip("⬢ %d %s" % [roster.kits(), Roster.kit_name()], UiKit.GOOD))
	for key in roster.materials:
		if str(key).begins_with("kern:"):
			flow.add_child(_chip("✦ %d %s" % [int(roster.materials[key]),
				Roster.core_name(str(key).substr(5))], UiKit.MAGENTA))
	var total := 0
	for key in roster.caches:
		total += int(roster.caches[key])
	flow.add_child(_chip("◆ %d Caches" % total, UiKit.MAGENTA))
	return flow


func _chip(text: String, color: Color) -> Control:
	var label := UiKit.label(text, 15, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var panel := PanelContainer.new()
	var box := Arcade.chamfer_box(Color(UiKit.BG, 0.85), 8, Color(color, 0.8), 2)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(label)
	return panel


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = TILE_COLUMNS
	grid.add_theme_constant_override("h_separation", TILE_GAP)
	grid.add_theme_constant_override("v_separation", TILE_GAP)
	_content.add_child(grid)
	return grid


func _changed() -> void:
	GameState.save_roster()
	_refresh()


# ---------------------------------------------------------------------------
# Shop
# ---------------------------------------------------------------------------

func _offer_name(offer: Dictionary) -> String:
	if str(offer.get("kind", "")) == "kit":
		return Roster.kit_name()
	return RunState.cache_name(StringName(str(offer.get("cache", "city"))))


func _offer_icon(offer: Dictionary) -> Control:
	if str(offer.get("kind", "")) == "kit":
		return UiKit.label("⬢", 30, UiKit.GOOD)
	return _cache_icon()


func _shop_section() -> void:
	_content.add_child(UiKit.heading("Angebote"))
	_content.add_child(UiKit.label("Doppeltipp kauft  ·  nochmal tippen: Details", UiKit.SMALL,
		UiKit.MUTED))
	var offers := Roster.shop_offers()
	var pages: Array = []
	for offer in offers:
		pages.append(func() -> Dictionary: return _offer_page(offer))
	var grid := _grid()
	for k in offers.size():
		var offer: Dictionary = offers[k]
		var blocker := GameState.roster.offer_blocker(offer)
		var tile := Tile.new("offer:%s" % offer.get("id", k), _offer_icon(offer), _offer_name(offer),
			Vector2(0, 96))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_caption("%d ◈" % int(offer.get("price", 0)), UiKit.WARN if blocker == "" else UiKit.MUTED, 12)
		tile.dimmed = blocker != ""
		var page: int = k
		tile.on_info = func(): InfoPopup.open_pages(self, pages, page)
		tile.on_action = func(): _buy(offer)
		grid.add_child(tile)
	_content.add_child(UiKit.label("Upgrades folgen mit dem Ausbau des Hangar-Shops.", UiKit.SMALL,
		UiKit.MUTED))


func _offer_page(offer: Dictionary) -> Dictionary:
	var blocker := GameState.roster.offer_blocker(offer)
	var text := "Ein %s für den Bau neuer DROMEs (%d = ein Standard-DROME)." % [Roster.kit_name(),
		Roster.kits_per_drome()] if str(offer.get("kind", "")) == "kit" \
		else "Ein Lootcache der Fraktion. Öffnen kommt mit dem nächsten Bauschritt."
	return {"title": _offer_name(offer), "subtitle": "%d %s" % [int(offer.get("price", 0)),
		RunState.coin_name()], "subtitle_color": UiKit.WARN, "picture": _offer_icon(offer),
		"lines": [text, ["Du hast %d %s." % [GameState.roster.coins, RunState.coin_name()],
			UiKit.MUTED, UiKit.SMALL]],
		"actions": [{"text": "Kaufen", "primary": true, "disabled": blocker != "", "why": blocker,
			"call": func(): _buy(offer)}]}


func _buy(offer: Dictionary) -> void:
	if GameState.roster.buy_offer(offer):
		Accessibility.vibrate(30, true)
		_changed()
	else:
		InfoPopup.open(self, "Geht nicht", {"lines": [GameState.roster.offer_blocker(offer)]})


# ---------------------------------------------------------------------------
# Caches
# ---------------------------------------------------------------------------

func _caches_section() -> void:
	var roster := GameState.roster
	_content.add_child(UiKit.heading("Deine Caches"))
	var keys: Array = roster.caches.keys().filter(func(k): return int(roster.caches[k]) > 0)
	keys.sort()
	if keys.is_empty():
		_content.add_child(UiKit.label("Noch keine Caches. Sie droppen im Einsatz oder kommen aus "
			+ "dem Shop.", UiKit.SMALL, UiKit.MUTED))
		return
	var pages: Array = []
	for key in keys:
		pages.append(func() -> Dictionary: return _cache_page(str(key)))
	var grid := _grid()
	for k in keys.size():
		var key: String = keys[k]
		var tile := Tile.new("cache:%s" % key, _cache_icon(), "%d× %s" % [int(roster.caches[key]),
			RunState.cache_name(StringName(key))], Vector2(0, 96))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.accent = UiKit.MAGENTA
		tile.glow = true
		var page: int = k
		tile.on_info = func(): InfoPopup.open_pages(self, pages, page)
		grid.add_child(tile)


func _cache_page(key: String) -> Dictionary:
	return {"title": RunState.cache_name(StringName(key)), "picture": _cache_icon(),
		"lines": ["%d Stück im Hangar." % int(GameState.roster.caches.get(key, 0)),
			["Caches enthalten Teile, Module, Komponenten (Baukerne, Fraktionskerne) oder "
			+ "gleich ganze DROMEs -- was genau, legst du im SPOT-Blatt Lootcaches fest.",
			UiKit.MUTED, UiKit.SMALL]],
		"actions": [{"text": "Öffnen", "primary": true, "disabled": true,
			"why": "kommt mit Bauschritt 4"}]}


# ---------------------------------------------------------------------------
# Bauen
# ---------------------------------------------------------------------------

## Neue DROMEs (15. Nov. 2026): aus Baukernen. Ein Standard-DROME kostet
## kits_per_drome Baukerne, ein Fraktions-DROME dazu einen Fraktionskern.
## Freie Chassis aus alter Beute lassen sich weiter ohne Kosten bauen.
## Kacheln wie ueberall: tippen waehlt, nochmal tippen zeigt, Doppeltipp baut.
func _build_section() -> void:
	var roster := GameState.roster
	var need := Roster.kits_per_drome()
	_content.add_child(UiKit.heading("Neuen DROME bauen"))
	_content.add_child(UiKit.label("%s: %d / %d  ·  Doppeltipp baut" % [Roster.kit_name(), roster.kits(),
		need], UiKit.SMALL, UiKit.GOOD if roster.kits() >= need else UiKit.MUTED))
	var grid := GridContainer.new()
	grid.columns = TILE_COLUMNS
	grid.add_theme_constant_override("h_separation", TILE_GAP)
	grid.add_theme_constant_override("v_separation", TILE_GAP)
	_content.add_child(grid)
	var specs := _build_specs()
	var pages: Array = []
	for spec in specs:
		pages.append(func() -> Dictionary: return _build_page(spec))
	for k in specs.size():
		var spec: Dictionary = specs[k]
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
		var page: int = k
		tile.on_info = func(): InfoPopup.open_pages(self, pages, page)
		tile.on_action = func(): _build_drome(spec)
		grid.add_child(tile)


## Was sich bauen laesst: freie Chassis (kostenlos), die vier Standard-DROMEs
## (Baukerne) und Fraktions-DROMEs, fuer deren Fraktion ein Kern da ist.
func _build_specs() -> Array:
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


func _build_page(spec: Dictionary) -> Dictionary:
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
		+ "Bald auch im Hangar-Shop.", UiKit.MUTED, UiKit.SMALL])
	var body := PartDB.get_part(spec["chassis"])
	return {"title": str(spec["name"]), "subtitle": str(spec["cost"]),
		"picture": UiKit.chassis_view(body, 64) if body != null else null, "lines": lines,
		"actions": [{"text": "Bauen", "primary": true, "disabled": not bool(spec["ready"]),
			"why": "%s fehlen" % Roster.kit_name(), "call": func(): _build_drome(spec)}]}


func _build_drome(spec: Dictionary) -> void:
	if not bool(spec["ready"]):
		InfoPopup.open(self, "Fehlt noch", {"lines": ["Dafür brauchst du %s." % spec["cost"]]})
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
	# Gleich in den Umbau des neuen DROME -- er hat noch keine Waffe.
	GameState.editing_index = GameState.roster.entries.size() - 1
	get_tree().change_scene_to_file("res://scenes/hangar.tscn")



## Ein Cache als Symbol: Kiste mit Neon-Rand (gezeichnet, bis es ein Bild gibt).
func _cache_icon() -> Control:
	var icon := Panel.new()
	icon.custom_minimum_size = Vector2(40, 34)
	var style := Arcade.chamfer_box(Color(UiKit.MAGENTA, 0.25), 8, UiKit.MAGENTA, 2)
	icon.add_theme_stylebox_override("panel", style)
	var mark := UiKit.label("◆", 18, UiKit.PRIMARY)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.add_child(mark)
	return icon


