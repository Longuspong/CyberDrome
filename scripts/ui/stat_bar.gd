class_name StatBar
extends Control

## Ein Wert als kleiner Balken statt nackter Zahl (10. Nov. 2026, Wunsch des
## Spielers). Links der Name, rechts die Zahl, dazwischen der Balken.
##
## Mit ``compare`` (>= 0) zeigt der Balken einen Vergleich, z. B. vorher ->
## nachher beim Waffentausch: der gemeinsame Teil in der Grundfarbe, ein
## Zuwachs gruen, ein Verlust als roter, leerer Rest. Die Skala je Wert steht
## in SCALE -- ungefaehr das Hoechste, was ein voll ausgebauter DROME erreicht,
## damit die Balken zwischen DROMEs vergleichbar bleiben.

const SCALE := {
	"hp_max": 320.0, "shield_max": 130.0, "shield_pulse": 15.0, "spd": 16.0,
	"def": 24.0, "power": 20.0, "power_score": 600.0,
}

const LABEL := {
	"hp_max": "Integritaet", "shield_max": "Schild", "shield_pulse": "Schildpuls",
	"spd": "Speed", "def": "Ruestung", "power": "Power", "power_score": "Kampfwert",
}

const BAR_COLOR := {
	"hp_max": Color(0.46, 0.86, 0.52), "shield_max": Color(0.38, 0.7, 1.0),
	"shield_pulse": Color(0.5, 0.82, 1.0), "spd": Color(1.0, 0.82, 0.35),
	"def": Color(0.75, 0.75, 0.8), "power": Color(1.0, 0.5, 0.46),
	"power_score": Color(0.38, 0.8, 0.98),
}

var key: String = ""
var value: float = 0.0
## Vergleichswert (vorher), -1 = kein Vergleich.
var compare: float = -1.0

var _name: Label
var _number: Label
var _bar: Control


static func make(stat_key: String, stat_value: float, compare_value: float = -1.0) -> StatBar:
	var bar := StatBar.new()
	bar.key = stat_key
	bar.value = stat_value
	bar.compare = compare_value
	return bar


func _ready() -> void:
	custom_minimum_size = Vector2(0, 26)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_name = UiKit.label(str(LABEL.get(key, key)), UiKit.SMALL, UiKit.MUTED)
	_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_name.custom_minimum_size = Vector2(96, 0)
	row.add_child(_name)
	_bar = Control.new()
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	row.add_child(_bar)
	_number = UiKit.label(_number_text(), UiKit.SMALL, _number_color())
	_number.autowrap_mode = TextServer.AUTOWRAP_OFF
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_number.custom_minimum_size = Vector2(64 if compare >= 0.0 else 40, 0)
	row.add_child(_number)


func _number_text() -> String:
	if compare < 0.0 or is_equal_approx(compare, value):
		return str(int(round(value)))
	return "%d (%+d)" % [int(round(value)), int(round(value - compare))]


func _number_color() -> Color:
	if compare < 0.0 or is_equal_approx(compare, value):
		return Color.WHITE
	return UiKit.GOOD if value > compare else UiKit.BAD


## Anteil am Balken, 0..1.
func _share(amount: float) -> float:
	return clampf(amount / maxf(1.0, float(SCALE.get(key, 100.0))), 0.0, 1.0)


func _draw_bar() -> void:
	var rect := Rect2(Vector2(0, _bar.size.y * 0.3), Vector2(_bar.size.x, _bar.size.y * 0.4))
	_bar.draw_rect(rect, Color(1, 1, 1, 0.08), true)
	var base: Color = BAR_COLOR.get(key, UiKit.ACCENT)
	var now := _share(value) * rect.size.x
	if compare < 0.0:
		_bar.draw_rect(Rect2(rect.position, Vector2(now, rect.size.y)), base, true)
		return
	var was := _share(compare) * rect.size.x
	var common := minf(now, was)
	_bar.draw_rect(Rect2(rect.position, Vector2(common, rect.size.y)), base, true)
	if now > was:
		_bar.draw_rect(Rect2(rect.position + Vector2(was, 0), Vector2(now - was, rect.size.y)),
			UiKit.GOOD, true)
	elif was > now:
		# Verlust: der wegfallende Teil als roter Rahmen.
		_bar.draw_rect(Rect2(rect.position + Vector2(now, 0), Vector2(was - now, rect.size.y)),
			UiKit.BAD, false, 1.5)
