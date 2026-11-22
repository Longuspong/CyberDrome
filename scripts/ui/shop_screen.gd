extends Control

## Shop und Inventar (seit 22. Nov. 2026, Design-Canvas "Fuenf Tabs",
## Entscheidung des Spielers: Shop und Crafting nie im selben Reiter). Ein
## Skript fuer zwei Tabs, ``mode`` waehlt:
##
##   shop       nur kaufen: Angebote fuer Platzhaltercoin -- Baukerne und Caches
##              (Roster.shop_offers, config hangar_shop)
##   inventory  Reiter Inventar (Bestand: Coins, Baukerne, Kerne, Energy Phases,
##              Rohlinge; Lootcaches oeffnen) und Charger (Charger-Crafter)
##
## Neue DROMEs bauen liegt seit 22. Nov. im Tab DROMEs (DromeForge).
## Kacheln wie ueberall: tippen waehlt, nochmal tippen zeigt Details
## (blaetterbar), Doppeltipp handelt (kaufen, bauen).

const TILE_COLUMNS := 4
const TILE_GAP := 10

## "shop" oder "inventory" (scenes/inventory.tscn setzt es).
@export var mode := "shop"
## Reiter im Inventar: "inventar" oder "charger".
static var _tab := "inventar"
## Gewaehlter Cache im Reiter Caches (Entwurf: antippen waehlt, Knopf oeffnet).
static var _cache_pick := "city"

## Die vier Caches im Entwurf; "hip" (Hipstar, Dachterrassen) gibt es im Spiel
## noch nicht und steht gesperrt da.
const CACHE_KINDS := ["city", "green", "plant7", "hip"]

var _content: VBoxContainer
var _tabs: HBoxContainer


## Oeffnet das Inventar beim naechsten Aufbau in diesem Reiter ("inventar",
## "charger").
static func open_tab(tab: String) -> void:
	_tab = tab


func _ready() -> void:
	if mode == "inventory":
		_content = UiKit.page(self, "Inventar", "", UiKit.TAB_INVENTORY, true)
	else:
		_content = UiKit.page(self, "Shop", "", UiKit.TAB_SHOP, true)
	# Die Reiter als Segmentknopf oben rechts in der Kopfzeile (Entwurf 15. Nov.).
	_tabs = UiKit.header_slot(self)
	_refresh()


func _refresh() -> void:
	UiKit.clear(_content)
	if mode != "inventory":
		_shop_section()
		return
	if _tab not in ["inventar", "charger"]:
		_tab = "inventar"
	# Der Schalter als erste Zeile: neben dem Titel INVENTAR und dem Zahnrad
	# waere er auf dem Handy zu breit.
	var switch := UiKit.segmented([["inventar", "Inventar"], ["charger", "Charger"]],
		_tab, func(id):
			_tab = id
			Tile.clear_choice()
			_refresh())
	switch.size_flags_horizontal = Control.SIZE_SHRINK_END
	_content.add_child(switch)
	if _tab == "charger":
		_charger_section()
	else:
		_content.add_child(_wallet())
		_phase_section()
		_caches_section()


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
		_tab = "inventar"
		Fader.go("res://scenes/inventory.tscn"))
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
# Inventar: Energy Phases, Charger
# ---------------------------------------------------------------------------

## Energy Phases und Rohlinge im Bestand (Entwurf: je Element eine Kachel).
func _phase_section() -> void:
	var roster := GameState.roster
	var head := HBoxContainer.new()
	var title := Arcade.label("ENERGY PHASES", 15, Arcade.CYAN, "bold", 0.2)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(Arcade.label("%d ROHLINGE" % roster.blanks(), 12, Arcade.MUTED, "bold", 0.16))
	_content.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	for element in Charger.element_ids():
		var count := roster.phases(str(element))
		var panel := _framed(Charger.element_color(str(element)) if count > 0 else Arcade.EMPTY_LINE,
			false)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(row)
		row.add_child(PhaseGem.new(str(element), 30))
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 0)
		row.add_child(column)
		column.add_child(Arcade.label(Charger.element_name(str(element)).to_upper(), 10,
			Charger.element_color(str(element)), "bold", 0.1))
		column.add_child(Arcade.label("×%d" % count, 14, Arcade.WHITE if count > 0 else Arcade.MUTED,
			"display"))
		grid.add_child(panel)


## Charger bauen (Charger-Crafter, 20. Nov. 2026); eingesetzt wird im Tab
## DROMEs unter Waffen › Charger.
func _charger_section() -> void:
	var crafter := ChargerCrafter.new()
	crafter.built.connect(_charger_built)
	_content.add_child(crafter)


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
	lines.append("Die Phasen sind verbraucht. Einsetzen im Tab DROMEs unter Waffen › Charger.")
	if dom != "":
		lines.append(["Die Fähigkeit legt %s-Stapel an." % Charger.element_name(dom), UiKit.HEADING])
	InfoPopup.open(self, Charger.display_name(phases).to_upper(), {"subtitle": "NEU IM LAGER",
		"lines": lines, "actions": [{"text": "Einsetzen", "primary": true, "call": func():
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
