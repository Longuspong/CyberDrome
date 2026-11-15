extends RefCounted

## Kein Zeichen ohne Glyphe (seit 15. Nov. 2026).
##
## Bungee und Chakra Petch kennen viele Sonderzeichen nicht; Godot zeichnet
## dann einen Kasten mit dem Zeichencode (gesehen: "Umbau ▸" im Hangar). Was
## als Symbol gedacht ist, kommt als SVG aus assets/ui_icons ueber UiIcon.
## Dieser Test liest jeden Text in Skripten und Daten (ohne Kommentare) und
## meldet Zeichen, die eine der drei Schriften nicht hat.

var t

const FONTS := [
	"res://assets/fonts/Bungee-Regular.ttf",
	"res://assets/fonts/ChakraPetch-Bold.ttf",
	"res://assets/fonts/ChakraPetch-Medium.ttf",
]
const ROOTS := ["res://scripts", "res://autoload", "res://data", "res://assets/parts"]


func _files(dir: String, out: Array) -> void:
	for name in DirAccess.get_files_at(dir):
		if name.ends_with(".gd") or name.ends_with(".json"):
			out.append(dir.path_join(name))
	for sub in DirAccess.get_directories_at(dir):
		_files(dir.path_join(sub), out)


func test_every_text_character_exists_in_all_fonts() -> void:
	var fonts: Array = []
	for path in FONTS:
		fonts.append(load(path))
	var files: Array = []
	for root in ROOTS:
		if DirAccess.dir_exists_absolute(root):
			_files(root, files)
	t.ok(files.size() > 20, "Skripte und Daten gefunden (%d)" % files.size())
	var missing: Array = []
	for path in files:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for index in lines.size():
			var line: String = lines[index]
			if line.strip_edges().begins_with("#"):
				continue
			for i in line.length():
				var code := line.unicode_at(i)
				if code < 128:
					continue
				for font in fonts:
					if not (font as Font).has_char(code):
						missing.append("%s:%d '%s' U+%04X" % [path, index + 1, line[i], code])
						break
	t.ok(missing.is_empty(), "alle Zeichen in den Schriften -- sonst UiIcon: %s"
		% ", ".join(missing.slice(0, 8)))


func test_every_ui_icon_loads() -> void:
	var names: Array = []
	for name in DirAccess.get_files_at("res://assets/ui_icons"):
		if name.ends_with(".svg"):
			names.append(name.get_basename())
	t.ok(names.size() >= 82, "UI-Symbole vorhanden (%d)" % names.size())
	for name in names:
		var texture := UiIcon.texture(name)
		t.ok(texture != null and texture.get_width() >= 64,
			"%s laedt scharf (svg/scale=4)" % name)
