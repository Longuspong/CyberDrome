extends Control

## Die Bit-Auswahl vor dem Chaos-Virus (§Chaos).
##
## Hier -- und NUR hier -- startet der Chaos-Virus. Der Spieler waehlt mit Plus
## und Minus, welche seiner DROMEs mitkommen (SquadPicker, dieselbe Ansicht wie
## vor einem Lauf). Den Gegner sieht man vorher nicht; er tritt mit der Staerke
## ALLER kampftauglichen eigenen DROMEs an, ein kleines bisschen abgeschwaecht
## (chaos.enemy_power_factor). Wer mit weniger antritt, macht es sich schwerer
## -- und genau das hebt die Beute-Chance.
##
## Die Auswahl schreibt in dieselbe ``in_squad``-Schicht wie die Garage; der
## Kampf liest sie ueber GameState.squad. Reine Auswahl -- gebaut und aufgeloest
## wird woanders.

var _picker: SquadPicker
var _summary: RichTextLabel
var _start: Button
var _seed_field: LineEdit


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh_summary()


## Mobile first: Einleitung, die Squad-Auswahl, die Zusammenfassung
## und der grosse Start-Knopf -- untereinander. Der Seed (ein
## Werkzeug fuers Playtesting) steht ganz unten.
func _build_ui() -> void:
	var content := UiKit.page(self, "Chaos-Virus", "res://scenes/main.tscn", -1, true,
		Ambience.Kind.CITY, 0.35)

	content.add_child(UiKit.label("Wer kommt mit? Die Gegner siehst du erst im Kampf -- "
		+ "sie sind etwas schwaecher als deine volle Mannschaft. Je weniger du "
		+ "mitnimmst, desto haerter, aber desto hoeher die Beute.", UiKit.SMALL, UiKit.MUTED))

	_picker = SquadPicker.new()
	content.add_child(_picker)
	_picker.setup(int(Config.section("run").get("squad_max", 4)))
	_picker.changed.connect(_refresh_summary)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.card_style())
	content.add_child(panel)
	_summary = RichTextLabel.new()
	_summary.bbcode_enabled = true
	_summary.fit_content = true
	_summary.add_theme_font_size_override("normal_font_size", UiKit.BODY)
	_summary.add_theme_font_size_override("bold_font_size", UiKit.BODY)
	panel.add_child(_summary)


	_start = UiKit.button("Chaos-Virus starten", true)
	_start.pressed.connect(_start_battle)
	content.add_child(_start)

	var seed_row := HBoxContainer.new()
	var seed_label := UiKit.label("Seed", UiKit.SMALL, UiKit.MUTED)
	# Ohne das bricht das Wort neben dem Eingabefeld zeichenweise um.
	seed_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	seed_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	seed_row.add_child(seed_label)
	_seed_field = LineEdit.new()
	_seed_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_field.custom_minimum_size = Vector2(0, 44)
	_seed_field.placeholder_text = "leer = zufaellig"
	if GameState.battle_seed != 0:
		_seed_field.text = str(GameState.battle_seed)
	seed_row.add_child(_seed_field)
	content.add_child(seed_row)


func _refresh_summary() -> void:
	var count := _picker.chosen_count()
	var enemy := _picker.all_builds().size()
	var mine := DromeBuild.squad_power(_picker.chosen_builds())
	var reference := DromeBuild.squad_power(_picker.all_builds())
	var handicap := 0.0
	if reference > 0.0:
		handicap = clampf(1.0 - mine / reference, 0.0, 1.0)
	var chance := ChaosLoot.drop_chance(handicap)

	var chance_color := "#75e58a" if handicap >= 0.5 else \
		("#f0b968" if handicap >= 0.2 else "#9aa0aa")
	_summary.text = "".join([
		"[b]Dein Einsatz[/b]\n",
		"Eigene DROMEs: [b]%d[/b] / %d\n" % [count, enemy],
		"Gegner: [b]%d[/b], unbekannt, etwas schwaecher\n" % enemy,
		"Handicap: [b]%d %%[/b]\n\n" % int(round(handicap * 100.0)),
		"[b]Beute[/b]\n",
		"Chance auf ein Teil: [color=%s][b]%d %%[/b][/color]\n" % [
			chance_color, int(round(chance * 100.0))],
		"Aus der Ausruestung der besiegten Gegner.\n",
		"Pity: %d bis zum garantierten Drop." % maxi(0,
			int(Config.section("chaos").get("loot_pity_threshold", 4))
			- GameState.chaos_pity),
	])

	var ready := count >= 1
	_start.disabled = not ready
	_start.tooltip_text = "" if ready else "Mindestens ein DROME muss mitkommen."


func _start_battle() -> void:
	if _picker.chosen_count() < 1:
		return

	# Der Gegner tritt mit so vielen DROMEs an wie man selbst STELLEN KOENNTE
	# (alle kampftauglichen), skaliert auf deren volle Staerke -- unabhaengig
	# davon, wie wenige man tatsaechlich mitnimmt.
	GameState.enemy_override = []
	GameState.configure_chaos_run(_picker.all_builds().size(),
		DromeBuild.squad_power(_picker.all_builds()))
	GameState.save_roster()

	var text := _seed_field.text.strip_edges()
	GameState.battle_seed = int(text) if text.is_valid_int() else 0
	if GameState.battle_seed == 0:
		GameState.new_seed()
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
