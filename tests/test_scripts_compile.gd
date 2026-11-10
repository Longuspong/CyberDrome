extends RefCounted

## Jedes Skript des Spiels muss sich laden lassen (10. Nov. 2026).
##
## Die uebrigen Suites pruefen die Logik und laden dabei nur, was sie
## brauchen. Ein Tippfehler in einem Bildschirm (battle_screen.gd,
## run_screen.gd ...) blieb so unbemerkt, bis das Spiel im Browser grau blieb.
## Hier wird jede .gd-Datei unter scripts/ und autoload/ einmal geladen und
## jede Szene unter scenes/ -- ein Syntaxfehler ist damit ein roter Test.

var t


func _files(dir_path: String, ending: String) -> Array:
	var found: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for name in dir.get_files():
		if name.ends_with(ending):
			found.append(dir_path.path_join(name))
	for sub in dir.get_directories():
		found.append_array(_files(dir_path.path_join(sub), ending))
	return found


func test_every_script_compiles() -> void:
	var scripts := _files("res://scripts", ".gd") + _files("res://autoload", ".gd")
	t.ok(scripts.size() > 30, "Skripte gefunden (%d)" % scripts.size())
	for path in scripts:
		var script = load(path)
		t.ok(script is GDScript and script.can_instantiate(), "%s laedt" % path)


func test_every_scene_loads() -> void:
	var scenes := _files("res://scenes", ".tscn")
	t.ok(not scenes.is_empty(), "Szenen gefunden (%d)" % scenes.size())
	for path in scenes:
		t.ok(load(path) is PackedScene, "%s laedt" % path)
