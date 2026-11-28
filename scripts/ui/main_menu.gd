extends Control

## Die Startseite -- mobile first, Hochformat (neu 9. Nov. 2026).
##
##   oben     der Name des Spiels als Neonschrift, darunter der Ort
##   Mitte    die Boss-Karte (Platzhalter seit 16. Nov. 2026; vorher die
##            Arena mit dem Squad, HomeStage)
##   darunter eine Karte: naechstes Gebiet und dein Squad in einer Zeile
##   unten    die Hauptaktion "Neon City" (der Lauf), darunter der
##            Endlos-Modus (frei nach dem ersten Sieg in Neon City)
##   Leiste   Spielen · Hangar · Shop (UiKit.tab_bar); Optionen am Zahnrad oben rechts
##
## Der Daumen erreicht unten alles, was man hier tut; oben steht nur, was man
## ansieht.

var _status: Label
var _endless: Button



func _ready() -> void:
	var content := UiKit.page(self, "", "", UiKit.TAB_HOME, false, Ambience.Kind.PLAIN)
	content.add_theme_constant_override("separation", 14)
	var running: bool = GameState.run != null and not GameState.run.is_over()
	var endless_running: bool = running and GameState.run.is_endless()
	var region_id: StringName = GameState.run.region_id if running else &"city"
	var region := TerrainDB.get_region(region_id)
	var region_name: String = region.display_name if region != null else "Neon City"

	# Kopf (Entwurf 15. Nov. 2026): Glitch-Logo links, Ort als gelbes
	# Etikett rechts, daneben Platz fuer das Zahnrad.
	var head := HBoxContainer.new()
	head.custom_minimum_size = Vector2(0, 44)
	content.add_child(head)
	var logo := Arcade.GlitchLogo.new("CYBERDROME", 22, 4.0, [
		[0.0, Vector2(-1.5, 0), Vector2(1.5, 0)],
		[0.91, Vector2(-5, 2), Vector2(5, -2)],
		[0.93, Vector2(4, -1), Vector2(-4, 1)]], 1.5)
	var title := Arcade.tilt(logo, -4.0)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	var push := Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(push)
	var place := Arcade.tilt(Arcade.tag(region_name.to_upper(), 12, 0.0, "location"), 2.0)
	place.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(place)
	var gear_room := Control.new()
	gear_room.custom_minimum_size = Vector2(46, 0)
	head.add_child(gear_room)

	content.add_child(_boss_card())
	content.add_child(_info_card(running, region_name, region))

	_status = UiKit.label("", UiKit.SMALL)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_status)

	# Ein laufender Lauf geht vor: er wird fortgesetzt, ein zweiter beginnt
	# erst, wenn er zu Ende ist.
	var story_text := "Einsatz starten"
	if running and not endless_running:
		story_text = "Einsatz fortsetzen · Kampf %d/%d" % [GameState.run.next_fight(), RunState.rounds_total()]
	var story := UiKit.button(story_text, not endless_running)
	story.custom_minimum_size = Vector2(0, 60)
	if story_text == "Einsatz starten":
		UiIcon.on_button(story, "play", 18, UiKit.ON_PRIMARY, "right")
	story.disabled = endless_running
	story.pressed.connect(func(): _open_run("story"))
	content.add_child(story)

	# Infinity-Einsatz: frei nach dem ersten Sieg in Neon City (NEUANFANG 6h).
	# Gesperrt als gestrichelter Kasten mit Schloss (Entwurf).
	var unlocked := GameState.endless_unlocked()
	if unlocked:
		_endless = UiKit.button("Infinity-Einsatz fortsetzen" if endless_running else "Infinity-Einsatz",
			endless_running)
		_endless.disabled = running and not endless_running
		_endless.pressed.connect(func(): _open_run("endless"))
		content.add_child(_endless)
	else:
		content.add_child(_locked_endless())

	_refresh_status()
	story.grab_focus.call_deferred()


## Die Boss-Karte (16. Nov. 2026, Wunsch des Spielers: die Arena mit dem
## Squad kam weg). Das Bild des Spielers fuellt die Karte (links die Figur),
## rechts auf der dunklen Flaeche Name, Fraktion und ein Satz. Inhalt noch
## Platzhalter, bis Story und Bosse entschieden sind (VORSCHLAG_STORY.md).
const BOSS_ART := "res://assets/story/boss_shogun_kage.jpg"


func _boss_card() -> Control:
	var wrap := Control.new()
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.custom_minimum_size = Vector2(0, 230)
	var panel := PanelContainer.new()
	var box := UiKit.card_style(true)
	box.set_content_margin_all(2)
	panel.add_theme_stylebox_override("panel", box)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_top = 12
	panel.offset_right = -6
	panel.clip_contents = true
	wrap.add_child(panel)
	# Das Bild fuellt die Karte (Wunsch des Spielers, 16. Nov. 2026: so
	# besser als Bild oben und Text darunter); der Text liegt unten rechts
	# auf der dunklen Flaeche, ein Verlauf unten haelt ihn lesbar.
	var stage := Control.new()
	stage.clip_contents = true
	panel.add_child(stage)
	var art := TextureRect.new()
	art.texture = load(BOSS_ART)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(art)
	# Fuellt die Karte, aber links buendig: abgeschnitten wird rechts (dort
	# ist das Bild leer und dunkel), nie die Figur links.
	var place := func():
		var ratio: float = art.texture.get_width() / float(art.texture.get_height()) \
			if art.texture != null else 1.6
		var height := maxf(stage.size.y, stage.size.x / ratio)
		art.size = Vector2(height * ratio, height)
		art.position = Vector2(0, (stage.size.y - height) * 0.5)
	stage.resized.connect(place)
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(Arcade.NIGHT, 0.0))
	gradient.set_color(1, Color(Arcade.NIGHT, 0.9))
	var fade := GradientTexture2D.new()
	fade.gradient = gradient
	fade.fill_from = Vector2(0.5, 0.45)
	fade.fill_to = Vector2(0.5, 1.0)
	shade.texture = fade
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(shade)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.alignment = BoxContainer.ALIGNMENT_END
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.anchor_left = 0.46
	text.offset_right = -12
	text.offset_bottom = -12
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(text)
	var name := Arcade.label("SHOGUN KAGE", 20, Arcade.WHITE, "display")
	name.add_theme_color_override("font_shadow_color", Arcade.NIGHT)
	name.add_theme_constant_override("shadow_offset_y", 3)
	text.add_child(name)
	# Umbrechen statt abschneiden ("Neon Ninja'" am Rand, 16. Nov. 2026).
	var faction := Arcade.label("Anführer der Neon Ninja's", 13, Arcade.ROSE, "bold", 0.04)
	faction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	faction.add_theme_color_override("font_shadow_color", Arcade.NIGHT)
	faction.add_theme_constant_override("shadow_offset_y", 2)
	text.add_child(faction)
	var tag := Arcade.tag("BOSS · NEON CITY", 12, -3.0)
	tag.position = Vector2(12, 0)
	wrap.add_child(tag)
	return wrap


## Die Gebietskarte: naechstes Gebiet oder laufender Einsatz, Fortschritt,
## Squad und Waehrungen (Credits nur im Einsatz, Wunsch des Spielers).
func _info_card(running: bool, region_name: String, region) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.card_style(true))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 2)
	top.add_child(left)
	left.add_child(UiIcon.text("bullet_square" if running else "location",
		"LAUFENDER EINSATZ" if running else "NÄCHSTES GEBIET", 12, Arcade.CYAN, "bold", 0.2))
	left.add_child(Arcade.label(region_name.to_upper(), 22, Arcade.WHITE, "display"))
	var faction_name: String = str(region.faction.get("name", "")) if region != null else ""
	var line := RichTextLabel.new()
	line.bbcode_enabled = true
	line.fit_content = true
	line.scroll_active = false
	line.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.add_theme_font_size_override("normal_font_size", 14)
	var count := ("Kampf %d/%d" % [GameState.run.next_fight(), RunState.rounds_total()]) if running \
		else ("%d Kämpfe" % RunState.rounds_total())
	line.text = "[color=#ff2bd6]%s[/color][color=#c3b3e6] · %s[/color]" \
		% [faction_name, count]
	left.add_child(line)
	var hex := HexBadge.new()
	hex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(hex)
	if running:
		var progress := RunProgress.new(GameState.run)
		box.add_child(progress)
	var rule := ColorRect.new()
	rule.color = Color("#3a1a6e")
	rule.custom_minimum_size = Vector2(0, 1)
	box.add_child(rule)

	var squad: Array = GameState.battle_ready_builds()
	var squad_row := HBoxContainer.new()
	squad_row.add_theme_constant_override("separation", 10)
	box.add_child(squad_row)
	squad_row.add_child(Arcade.label("SQUAD", 13, Arcade.MUTED, "bold", 0.2))
	var summary := "Noch kein kampfbereiter Squad"
	if not squad.is_empty():
		var levels := 0
		for build in squad:
			levels += build.drome_level
		# Anzahl zeigen die Kaestchen rechts daneben.
		summary = "Ø Level %s" % ("%.1f" % (float(levels) / squad.size())).replace(".", ",")
	var summary_label := Arcade.label(summary, 14, Arcade.TEXT)
	summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	squad_row.add_child(summary_label)
	squad_row.add_child(Pips.new(squad.size(), RunState.squad_max()))

	var wallet := HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 8)
	box.add_child(wallet)
	if running:
		wallet.add_child(_money("Credits", "%d" % GameState.run.credits, Arcade.CYAN, "credits"))
	wallet.add_child(_money(RunState.coin_name(), _thousands(GameState.roster.coins),
		Arcade.YELLOW, "coin"))
	return panel


func _money(title: String, value: String, color: Color, icon: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#12082a")
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	# Seit 28. Nov. 2026 ohne Beschriftung: das Symbol sagt, welche Waehrung.
	panel.tooltip_text = title
	column.add_child(UiIcon.text(icon, value, 20, color, "display"))
	return panel


static func _thousands(value: int) -> String:
	var text := str(absi(value))
	var out := ""
	while text.length() > 3:
		out = "." + text.substr(text.length() - 3) + out
		text = text.substr(0, text.length() - 3)
	return ("-" if value < 0 else "") + text + out


## Infinity-Einsatz gesperrt: gestrichelter Kasten mit Schloss (Entwurf).
func _locked_endless() -> Control:
	var card := Arcade.Card.new(Arcade.EMPTY_LINE, Color.TRANSPARENT, true)
	card.custom_minimum_size = Vector2(0, 48)
	card.tooltip_text = "Gesperrt: erst Neon City bezwingen."
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	row.add_child(LockIcon.new())
	row.add_child(Arcade.label("INFINITY-EINSATZ", 14, Arcade.MUTED, "bold", 0.16))
	var push := Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(push)
	row.add_child(Arcade.label("Neon City bezwingen", 13, Arcade.MUTED))
	return card


## Kleines Schloss (gesperrt).
class LockIcon extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(16, 20)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_arc(Vector2(8, 8), 4.5, PI, TAU, 8, Arcade.MUTED, 2.0)
		draw_line(Vector2(3.5, 8), Vector2(3.5, 10), Arcade.MUTED, 2.0)
		draw_line(Vector2(12.5, 8), Vector2(12.5, 10), Arcade.MUTED, 2.0)
		draw_rect(Rect2(2, 10, 12, 9), Arcade.MUTED, false, 2.0)


## Sechseck in Magenta mit Stern (Gebietsabzeichen der Karte).
class HexBadge extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(60, 60)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var pts := PackedVector2Array()
		for i in 6:
			var a := TAU * float(i) / 6.0
			pts.append(c + Vector2(cos(a), sin(a)) * 28.0)
		draw_colored_polygon(pts, Arcade.MAGENTA)
		var star := PackedVector2Array()
		for i in 8:
			var a := TAU * float(i) / 8.0 - PI * 0.5
			star.append(c + Vector2(cos(a), sin(a)) * (12.0 if i % 2 == 0 else 4.0))
		draw_colored_polygon(star, Arcade.NIGHT)


## Fortschritt des Einsatzes: ein Balken je Kampf -- geschafft cyan, aktuell
## gelb, offen gestrichelt, der letzte (Elite) magenta gestrichelt.
class RunProgress extends Control:
	var _run: RunState

	func _init(run: RunState) -> void:
		_run = run
		custom_minimum_size = Vector2(0, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var total := RunState.rounds_total()
		var gap := 4.0
		var w := (size.x - gap * (total - 1)) / total
		for i in total:
			var r := Rect2(i * (w + gap), 2, w, size.y - 4)
			var number := i + 1
			if number < _run.round:
				draw_rect(r, Arcade.CYAN)
			elif number == _run.round:
				draw_rect(r, Arcade.YELLOW)
			else:
				var color := Arcade.MAGENTA if number == total else Arcade.EMPTY_LINE
				var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
				for k in 4:
					draw_dashed_line(c[k], c[(k + 1) % 4], color, 1.5, 4.0)


## Kleine Kaestchen: belegt cyan, frei dunkel.
class Pips extends Control:
	var _have := 0
	var _max := 4

	func _init(have: int, most: int) -> void:
		_have = have
		_max = most
		custom_minimum_size = Vector2(most * 13, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in _max:
			draw_rect(Rect2(i * 13, 3, 9, 10), Arcade.CYAN if i < _have else Color("#3a1a6e"))


func _open_run(mode: String) -> void:
	GameState.next_run_mode = mode
	Fader.go("res://scenes/run.tscn")


func _refresh_status() -> void:
	# Ein Lauf braucht kampftaugliche eigene DROMEs; die Aufstellung im Lauf
	# sagt es selbst, hier steht es vorab.
	var ready := not GameState.battle_ready_builds().is_empty()
	_status.visible = not ready
	if not ready:
		_status.text = "Noch kein kampftauglicher DROME."
		_status.modulate = UiKit.BAD
