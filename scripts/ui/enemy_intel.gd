class_name EnemyIntel
extends PanelContainer

## Aufklaerung vor dem Einsatz (Uebergabe Ue2, Design-Canvas 20. Nov. 2026):
## welche Gegner zu erwarten sind -- Fraktion, ihre Formationen mit
## Gegner-DROMEs (Sechseck) und Sentinels (Quadrat), je mit Rollensymbol,
## dazu eine Bilanz nach Rolle und ein Hinweis, was dagegen hilft. Damit wird
## der Squad auf die Gegner abgestimmt. Kommt mit wechselnden Inhalten zurecht
## (1-2 DROMEs + Sentinels je Formation, beliebig viele Formationen).

const NEON_RED := Color("#ff2a55")
const NEON_ORANGE := Color("#ff9a3d")
const MAX_ROWS := 4

## Rolle -> [Symbol, Bilanz-Spalte]
const ROLE := {
	"vanguard": ["role_vanguard", "VORN"],
	"skirmisher": ["role_skirmisher", "FLANKE"],
	"sniper": ["role_sniper", "FERN"],
	"controller": ["role_controller", "SUPPORT"],
	"support": ["heal", "SUPPORT"],
}
const SENTINEL_ROLE := {"assault": "skirmisher", "sniper": "sniper", "support": "support"}


func _init(region_id: StringName = &"city", level: int = 3) -> void:
	var style := UiKit.card_style(false)
	style.border_color = NEON_RED
	add_theme_stylebox_override("panel", style)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	var region := TerrainDB.get_region(region_id)
	var faction := str(region.faction.get("name", "")) if region != null else ""
	box.add_child(Arcade.label("AUFKLÄRUNG · GEGNER", 11, Arcade.CYAN, "bold", 0.14))
	var head := HBoxContainer.new()
	var title := Arcade.label((region.display_name if region != null else "?").to_upper(), 19, NEON_RED, "display")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if faction != "":
		head.add_child(Arcade.label(faction.to_upper(), 11, NEON_ORANGE, "bold", 0.1))
	box.add_child(head)

	var counts := {"VORN": 0, "FLANKE": 0, "FERN": 0, "SUPPORT": 0}
	var shown := 0
	for entry in Formations.of_region(region_id):
		if bool(entry.get("intro", false)) or shown >= MAX_ROWS:
			continue
		shown += 1
		var plan := Formations.composition(entry, level, "normal")
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var name := Arcade.label(str(entry.get("name", "")), 13, Arcade.WHITE, "bold")
		name.custom_minimum_size = Vector2(110, 0)
		name.clip_text = true
		row.add_child(name)
		var units := HFlowContainer.new()
		units.add_theme_constant_override("h_separation", 4)
		units.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(units)
		for drome_id in plan.get("dromes", []):
			var build := Formations.build_drome(str(drome_id))
			var role := HangarScreen.role_key(build) if build != null else ""
			units.add_child(_Unit.new(true, role))
			counts[_column(role)] = int(counts[_column(role)]) + 1
		for pair in plan.get("sentinels", []):
			var spec: Dictionary = (Formations.data().get("sentinels", {}) as Dictionary).get(str(pair[0]), {})
			var role: String = SENTINEL_ROLE.get(str(spec.get("archetype", "")), "skirmisher")
			units.add_child(_Unit.new(false, role))
			counts[_column(role)] = int(counts[_column(role)]) + 1
		row.add_child(Arcade.label("%d + %d" % [(plan.get("dromes", []) as Array).size(),
			(plan.get("sentinels", []) as Array).size()], 11, Arcade.MUTED, "bold"))

	var bars := GridContainer.new()
	bars.columns = 4
	bars.add_theme_constant_override("h_separation", 6)
	box.add_child(bars)
	var top := 1
	for key in counts:
		top = maxi(top, int(counts[key]))
	for key in counts:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 2)
		var line := HBoxContainer.new()
		var k := Arcade.label(str(key), 10, Arcade.MUTED, "bold", 0.08)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(k)
		line.add_child(Arcade.label(str(counts[key]), 10, Arcade.WHITE, "bold"))
		cell.add_child(line)
		cell.add_child(ChargerCrafter._Bar.new(float(counts[key]) / float(top), NEON_RED))
		bars.add_child(cell)

	var hint := HBoxContainer.new()
	hint.add_theme_constant_override("separation", 8)
	hint.add_child(UiIcon.rect("warn" if UiIcon.texture("warn") != null else "plus", 16, Arcade.YELLOW))
	var text := UiKit.label(_advice(counts), 13, UiKit.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size.x = 120
	hint.add_child(text)
	box.add_child(hint)


static func _column(role: String) -> String:
	return str((ROLE.get(role, ROLE["skirmisher"]) as Array)[1])


## Ein Satz, was gegen diese Mischung hilft (nur Optik, keine Regel).
static func _advice(counts: Dictionary) -> String:
	var best := ""
	var n := -1
	for key in counts:
		if int(counts[key]) > n:
			best = str(key)
			n = int(counts[key])
	match best:
		"VORN":
			return "Viel Nahkampf vorn: Schützen hinten und Kontrolle lohnen sich."
		"FLANKE":
			return "Schnelle Plänkler von der Seite: ein Tank vorn hält sie auf."
		"FERN":
			return "Viele Schützen: schnelle Plänkler kommen an sie heran."
	return "Heiler und Unterstützer hinten: Fernkampf erreicht sie zuerst."


## Ein Gegner als Marke: DROME Sechseck in Rot, Sentinel Quadrat, Rollensymbol.
class _Unit extends Control:
	var drome := false
	var role := ""

	func _init(is_drome: bool, unit_role: String) -> void:
		drome = is_drome
		role = unit_role
		custom_minimum_size = Vector2(30, 26) if drome else Vector2(22, 22)
		tooltip_text = ("DROME " if drome else "Sentinel ") + str((EnemyIntel.ROLE.get(role, ["", "?"]) as Array)[1])
		var icon := UiIcon.rect(str((EnemyIntel.ROLE.get(role, EnemyIntel.ROLE["skirmisher"]) as Array)[0]),
			14 if drome else 12, Arcade.NIGHT if drome else EnemyIntel.NEON_ORANGE)
		icon.position = (custom_minimum_size - icon.custom_minimum_size) * 0.5
		add_child(icon)

	func _draw() -> void:
		if drome:
			draw_colored_polygon(PhaseGem.hex(size * 0.5, size.x, size.y), EnemyIntel.NEON_RED)
		else:
			draw_rect(Rect2(Vector2.ZERO, size), Color("#2a1046"))
