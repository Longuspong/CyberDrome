extends Control

## Der Shop (15. Nov. 2026, Wunsch des Spielers): der rechte Tab der Leiste,
## anstelle der Optionen (die sitzen jetzt am Zahnrad oben rechts). Drei
## Reiter:
##
##   Shop     Angebote fuer Platzhaltercoin -- Baukerne und Caches
##            (Roster.shop_offers, config hangar_shop)
##   Caches   die Lootcaches im Hangar; seit 20. Nov. 2026 zu oeffnen (vier Wuerfe).
##            Caches und Bosse koennen spaeter Komponenten (Baukerne,
##            Fraktionskerne) oder gleich ganze DROMEs enthalten.
##   Bauen    Charger-Crafter (Rohling + Energy Phases, 20. Nov. 2026), dann
##            Material (Baukerne, Fraktionskerne) und neue DROMEs daraus
##
## Kacheln wie ueberall: tippen waehlt, nochmal tippen zeigt Details
## (blaetterbar), Doppeltipp handelt (kaufen, bauen).

const TILE_COLUMNS := 4
const TILE_GAP := 10

static var _tab := "shop"
## Gewaehlter Cache im Reiter Caches (Entwurf: antippen waehlt, Knopf oeffnet).
static var _cache_pick := "city"

## Die vier Caches im Entwurf; "hip" (Hipstar, Dachterrassen) gibt es im Spiel
## noch nicht und steht gesperrt da.
const CACHE_KINDS := ["city", "green", "plant7", "hip"]

var _content: VBoxContainer
var _tabs: HBoxContainer


## Oeffnet den Shop beim naechsten Aufbau in diesem Reiter.
static func open_tab(tab: String) -> void:
	_tab = tab


func _ready() -> void:
	_content = UiKit.page(self, "Shop", "", 2, true)
	# Die Reiter als Segmentknopf oben rechts in der Kopfzeile (Entwurf 15. Nov.).
	_tabs = UiKit.header_slot(self)
	_refresh()


func _refresh() -> void:
	UiKit.clear(_tabs)
	_tabs.add_child(UiKit.segmented([["shop", "Shop"], ["caches", "Caches"], ["bauen", "Bauen"]],
		_tab, func(id):
			_tab = id
			Tile.clear_choice()
			_refresh()))
	UiKit.clear(_content)
	if _tab == "bauen":
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
	flow.add_child(_chip("%d %s" % [roster.coins, RunState.coin_name()], UiKit.WARN, "coin"))
	flow.add_child(_chip("%d %s" % [roster.kits(), Roster.kit_name()], UiKit.GOOD, "kit"))
	for key in roster.materials:
		if str(key).begins_with("kern:"):
			flow.add_child(_chip("%d %s" % [int(roster.materials[key]),
				Roster.core_name(str(key).substr(5))], UiKit.MAGENTA, "material"))
	var total := 0
	for key in roster.caches:
		total += int(roster.caches[key])
	flow.add_child(_chip("%d Caches" % total, UiKit.MAGENTA, "cache"))
	return flow


func _chip(text: String, color: Color, icon: String = "") -> Control:
	var label := UiKit.label(text, 15, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var panel := PanelContainer.new()
	var box := Arcade.chamfer_box(Color(UiKit.BG, 0.85), 8, Color(color, 0.8), 2)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", box)
	if icon == "":
		panel.add_child(label)
		return panel
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(UiIcon.rect(icon, 16, color))
	row.add_child(label)
	panel.add_child(row)
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
		return UiIcon.rect("kit", 30, UiKit.GOOD)
	return _cache_icon()


func _shop_section() -> void:
	# Entwurf 15. Nov. 2026: Bestand oben, Caches als Karten mit KAUFEN,
	# darunter Baukerne und die Upgrades (folgen).
	_content.add_child(_stock_card())
	var head := HBoxContainer.new()
	var title := Arcade.label("CACHES", 15, Arcade.CYAN, "bold", 0.2)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var link := Button.new()
	link.flat = true
	link.text = "ZUM CACHE-LAGER ›"
	link.custom_minimum_size = Vector2(0, 34)
	link.add_theme_font_override("font", Arcade.font("bold", 12, 0.12))
	link.add_theme_font_size_override("font_size", 12)
	link.add_theme_color_override("font_color", Arcade.YELLOW)
	link.pressed.connect(func():
		_tab = "caches"
		_refresh())
	head.add_child(link)
	_content.add_child(head)
	var offers := Roster.shop_offers()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", TILE_GAP)
	grid.add_theme_constant_override("v_separation", TILE_GAP)
	_content.add_child(grid)
	var shown := {}
	for offer in offers:
		if str(offer.get("kind", "")) == "cache":
			shown[str(offer.get("cache", ""))] = true
			grid.add_child(_cache_offer_card(offer))
	for kind in CACHE_KINDS:
		if not shown.has(kind):
			grid.add_child(_locked_card(kind))
	for offer in offers:
		if str(offer.get("kind", "")) == "kit":
			_content.add_child(_kit_offer(offer))
	var upgrades := HBoxContainer.new()
	var up_title := Arcade.label("UPGRADES", 15, Arcade.CYAN, "bold", 0.2)
	up_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrades.add_child(up_title)
	upgrades.add_child(Arcade.label("INHALTE FOLGEN", 12, Arcade.MUTED, "bold", 0.16))
	_content.add_child(upgrades)
	var soon := Arcade.Card.new(Arcade.EMPTY_LINE, Color.TRANSPARENT, true)
	soon.add_child(UiKit.label("Upgrades kommen mit dem Ausbau des Hangar-Shops (Bauschritt 5).",
		14, UiKit.MUTED))
	_content.add_child(soon)


## Der Bestand an Platzhaltercoin (Entwurf: Sechseck-Coin, grosse Zahl).
func _stock_card() -> Control:
	var panel := PanelContainer.new()
	var style := UiKit.card_style(true)
	style.border_color = Arcade.YELLOW
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	row.add_child(CoinIcon.new(52.0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	row.add_child(column)
	column.add_child(Arcade.label("BESTAND", 11, Arcade.MUTED, "bold", 0.2))
	column.add_child(Arcade.label(str(GameState.roster.coins), 28, Arcade.YELLOW, "display"))
	column.add_child(Arcade.label("%s (Arbeitsname)" % RunState.coin_name(), 13, Arcade.MUTED))
	return panel


## Eine Karte mit Rahmen in ``line``; ``on_tap`` beim Antippen.
func _framed(line: Color, chosen: bool, on_tap: Callable = Callable()) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Arcade.VIOLET, 0.94)
	style.border_color = Arcade.YELLOW if chosen else line
	style.set_border_width_all(3 if chosen else 2)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	if on_tap.is_valid():
		panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				Accessibility.tap()
				on_tap.call())
	return panel


## Kleines Etikett oben links ("IM LAGER ×3").
func _badge(text: String, color: Color) -> Control:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_left = 5
	box.content_margin_right = 5
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(Arcade.label(text, 10, Arcade.NIGHT, "bold", 0.1))
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return panel


func _region_name(kind: String) -> String:
	if kind == "hip":
		return "Dachterrassen"
	var region := TerrainDB.get_region(StringName(kind))
	return region.display_name if region != null else ""


func _cache_offer_card(offer: Dictionary) -> Control:
	var kind := str(offer.get("cache", "city"))
	var blocker := GameState.roster.offer_blocker(offer)
	var panel := _framed(CacheArt.color(kind), false)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var have := int(GameState.roster.caches.get(kind, 0))
	box.add_child(_badge("IM LAGER ×%d" % have, CacheArt.color(kind)) if have > 0 else Control.new())
	var art := CacheArt.new(kind, 64.0)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(art)
	box.add_child(_centered(Arcade.label(RunState.cache_name(StringName(kind)).to_upper(), 14,
		Arcade.WHITE, "display")))
	box.add_child(_centered(Arcade.label(_region_name(kind), 13, Arcade.MUTED)))
	var price := UiIcon.text("kit", "%d" % int(offer.get("price", 0)), 15, Arcade.YELLOW, "display")
	price.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(price)
	var buy := UiKit.button("Kaufen", true)
	buy.custom_minimum_size = Vector2(0, 44)
	buy.disabled = blocker != ""
	buy.tooltip_text = blocker
	buy.pressed.connect(func(): _buy(offer))
	box.add_child(buy)
	return panel


func _locked_card(kind: String) -> Control:
	var card := Arcade.Card.new(Arcade.EMPTY_LINE, Color.TRANSPARENT, true)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var art := CacheArt.new(kind, 56.0)
	art.locked = true
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(art)
	box.add_child(_centered(Arcade.label(RunState.cache_name(StringName(kind)).to_upper()
		if kind != "hip" else "HIPSTAR CACHE", 13, Arcade.MUTED, "display")))
	box.add_child(_centered(Arcade.label("%s erreichen" % _region_name(kind), 12, Arcade.MUTED)))
	box.add_child(_centered(Arcade.label("GESPERRT", 12, Arcade.MUTED, "bold", 0.2)))
	return card


func _kit_offer(offer: Dictionary) -> Control:
	var blocker := GameState.roster.offer_blocker(offer)
	var panel := _framed(UiKit.GOOD, false)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	row.add_child(UiIcon.rect("kit", 30, UiKit.GOOD))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 0)
	row.add_child(column)
	column.add_child(Arcade.label(Roster.kit_name().to_upper(), 14, Arcade.WHITE, "display"))
	var kit_text := Arcade.label("%d bauen einen Standard-DROME · du hast %d" % [Roster.kits_per_drome(),
		GameState.roster.kits()], 12, Arcade.MUTED)
	kit_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(kit_text)
	var buy := UiKit.button("%d" % int(offer.get("price", 0)), true)
	UiIcon.on_button(buy, "kit", 18, UiKit.ON_PRIMARY)
	buy.custom_minimum_size = Vector2(96, 44)
	buy.size_flags_horizontal = Control.SIZE_SHRINK_END
	buy.disabled = blocker != ""
	buy.tooltip_text = blocker
	buy.pressed.connect(func(): _buy(offer))
	row.add_child(buy)
	return panel


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	return label


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
	# Entwurf 15. Nov. 2026: alle vier Sorten als Karten (leere gestrichelt),
	# antippen waehlt, der Knopf unten oeffnet.
	var roster := GameState.roster
	var total := 0
	for key in roster.caches:
		total += int(roster.caches[key])
	var head := HBoxContainer.new()
	var title := Arcade.label("LOOTCACHES", 15, Arcade.CYAN, "bold", 0.2)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(Arcade.label("%d UNGEÖFFNET" % total, 12, Arcade.MUTED, "bold", 0.16))
	_content.add_child(head)
	_content.add_child(UiKit.label("Im Einsatz gesammelt, hier geöffnet. Je Fraktion eine eigene Sorte.",
		14, UiKit.MUTED))
	if int(roster.caches.get(_cache_pick, 0)) <= 0:
		for kind in CACHE_KINDS:
			if int(roster.caches.get(kind, 0)) > 0:
				_cache_pick = kind
				break
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", TILE_GAP)
	grid.add_theme_constant_override("v_separation", TILE_GAP)
	_content.add_child(grid)
	for kind in CACHE_KINDS:
		var count := int(roster.caches.get(kind, 0))
		var panel: Control
		if count > 0:
			var chosen: bool = kind == _cache_pick
			var pick: String = kind
			var framed := _framed(CacheArt.color(kind), chosen, func():
				if _cache_pick == pick:
					InfoPopup.open(self, RunState.cache_name(StringName(pick)), _cache_page(pick))
				_cache_pick = pick
				_refresh())
			panel = framed
		else:
			panel = Arcade.Card.new(Arcade.EMPTY_LINE, Color.TRANSPARENT, true)
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(box)
		var count_label := Arcade.label("×%d" % count, 14, Arcade.YELLOW if count > 0 else Arcade.MUTED,
			"display")
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		box.add_child(count_label)
		var art := CacheArt.new(kind, 80.0)
		art.locked = count <= 0
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(art)
		var name := RunState.cache_name(StringName(kind)) if kind != "hip" else "Hipstar Cache"
		box.add_child(_centered(Arcade.label(name.to_upper(), 14,
			Arcade.WHITE if count > 0 else Arcade.MUTED, "display")))
		box.add_child(_centered(Arcade.label(_region_name(kind) if count > 0 else "Noch keiner", 13,
			Arcade.MUTED)))
		grid.add_child(panel)
	var note := Arcade.Card.new(Color("#3a1a6e"), Color.TRANSPARENT, true)
	note.add_child(UiKit.label("Caches findest du im Einsatz -- jeder Kampf hat eine Chance auf den "
		+ "Cache seiner Fraktion. Oder du kaufst sie im Shop.", 14, UiKit.TEXT))
	_content.add_child(note)
	var have := int(roster.caches.get(_cache_pick, 0))
	if have > 0:
		var open := UiKit.button("%s öffnen" % RunState.cache_name(StringName(_cache_pick)), true)
		UiIcon.on_button(open, "play", 18, UiKit.ON_PRIMARY, "right")
		open.pressed.connect(func():
			var opener := CacheOpener.show_over(self, _cache_pick)
			opener.finished.connect(_refresh))
		_content.add_child(open)


func _cache_page(key: String) -> Dictionary:
	return {"title": RunState.cache_name(StringName(key)), "picture": _cache_icon(),
		"lines": ["%d Stück im Hangar." % int(GameState.roster.caches.get(key, 0)),
			["Vier Würfe je Cache: Energy Phases, Charger-Rohlinge, Baukerne, selten ein "
			+ "Fraktionskern oder ein ganzer Fraktions-DROME, sonst Coins.",
			UiKit.MUTED, UiKit.SMALL]],
		"actions": [{"text": "Öffnen", "primary": true, "call": func():
			var opener := CacheOpener.show_over(self, key)
			opener.finished.connect(_refresh)}]}


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
	# Charger-Crafter (20. Nov. 2026, Design-Canvas Ue3) zuerst.
	var crafter := ChargerCrafter.new()
	crafter.built.connect(_charger_built)
	_content.add_child(crafter)
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
	Fader.go("res://scenes/hangar.tscn")



## Nach dem Bauen: der neue Charger, dazu der Weg in den Hangar (Upgrade).
func _charger_built(charger: Dictionary) -> void:
	_refresh()
	var phases: Array = charger.get("phases", [])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for e in phases:
		if str(e) != "":
			row.add_child(PhaseGem.new(str(e), 40))
	var dom := Charger.dominant(phases)
	var lines: Array = [row]
	lines.append("Die Phasen sind verbraucht. Einsetzen im Hangar unter Upgrade.")
	if dom != "":
		lines.append(["Die Fähigkeit legt %s-Stapel an." % Charger.element_name(dom), UiKit.HEADING])
	InfoPopup.open(self, Charger.display_name(phases).to_upper(), {"subtitle": "NEU IM LAGER",
		"lines": lines, "actions": [{"text": "Zum Hangar", "primary": true, "call": func():
			HangarScreen.open_tab("upgrade")
			Fader.go("res://scenes/hangar.tscn")}]})


## Ein Cache als Symbol: Kiste mit Neon-Rand (gezeichnet, bis es ein Bild gibt).
func _cache_icon() -> Control:
	var icon := Panel.new()
	icon.custom_minimum_size = Vector2(40, 34)
	var style := Arcade.chamfer_box(Color(UiKit.MAGENTA, 0.25), 8, UiKit.MAGENTA, 2)
	icon.add_theme_stylebox_override("panel", style)
	var mark := UiIcon.rect("cache", 20, UiKit.PRIMARY)
	mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.add_child(mark)
	return icon




## Sechseck-Coin (Platzhaltercoin) in Gelb.
class CoinIcon extends Control:
	func _init(edge: float) -> void:
		custom_minimum_size = Vector2(edge, edge)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.48
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in 6:
			var a := TAU * float(i) / 6.0
			outer.append(c + Vector2(cos(a), sin(a)) * r)
			inner.append(c + Vector2(cos(a), sin(a)) * r * 0.62)
		draw_colored_polygon(outer, Arcade.YELLOW)
		draw_colored_polygon(inner, Arcade.NIGHT)
		draw_rect(Rect2(c - Vector2(r * 0.14, r * 0.34), Vector2(r * 0.28, r * 0.68)), Arcade.YELLOW)
