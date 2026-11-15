class_name UiIcon
extends RefCounted

## UI-Symbole aus assets/ui_icons/ (seit 15. Nov. 2026, Set des Spielers).
##
## Die Schriften (Bungee, Chakra Petch) kennen viele Zeichen nicht
## (▸ ◈ ⬢ ✦ ✕ ✓ ◉ ▮ ↻ ◎ ○ ❚ ☰ ⏩ ...) -- Godot zeichnet dann einen Kasten mit
## dem Zeichencode. Deshalb Symbole als SVG: alle weiss, eingefaerbt wird
## hier ueber ``modulate`` bzw. die ``icon_*_color`` eines Knopfs, die Farben
## bleiben in UiKit/Arcade. Import mit svg/scale=4, damit sie bis ~50 px
## scharf bleiben. Welche Datei was ersetzt: assets/ui_icons/README.md.

const DIR := "res://assets/ui_icons/%s.svg"

static var _cache: Dictionary = {}


## Die Textur zu ``name`` (Dateiname ohne .svg), null wenn es sie nicht gibt.
static func texture(name: String) -> Texture2D:
	if not _cache.has(name):
		var path := DIR % name
		_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[name]


static func exists(name: String) -> bool:
	return texture(name) != null


## Ein Symbol als feste Flaeche ``size`` x ``size`` in ``color``.
static func rect(name: String, size: float, color: Color = Color.WHITE) -> TextureRect:
	var result := TextureRect.new()
	result.texture = texture(name)
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.custom_minimum_size = Vector2(size, size)
	result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.modulate = color
	return result


## Symbol und Text nebeneinander (statt "◆ 12" als ein Text). ``kind`` und
## ``spacing_em`` wie bei Arcade.label; das Symbol ist so hoch wie die Schrift.
## Das Label liegt als letztes Kind, ``row.get_child(1)``.
static func text(name: String, value: String, size: int, color: Color,
		kind: String = "medium", spacing_em: float = 0.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", maxi(3, int(size * 0.3)))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rect(name, round(size * 1.05), color))
	var label := Arcade.label(value, size, color, kind, spacing_em)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	return row


## Setzt ein Symbol in einen Knopf, eingefaerbt in ``color`` (alle Zustaende).
## ``where``: "left", "right", "center" (nur Symbol) oder "top" (ueber dem Text).
static func on_button(button: Button, name: String, size: int, color: Color,
		where: String = "left") -> Button:
	button.icon = texture(name)
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", size)
	match where:
		"right":
			button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		"center":
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		"top":
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		_:
			button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
			"icon_focus_color", "icon_hover_pressed_color"]:
		button.add_theme_color_override(state, color)
	button.add_theme_color_override("icon_disabled_color", Color(color, 0.45))
	return button
