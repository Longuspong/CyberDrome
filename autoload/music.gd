extends Node

## Hintergrundmusik (24. Nov. 2026): zwei BeepBox-Stuecke des Spielers.
##
## * ``kampf`` (dunkel, D-Moll, 96 BPM) laeuft im Kampf (battle.tscn),
## * ``menue`` (heller, A-Moll, 128 BPM) auf allen anderen Bildschirmen.
##
## Jedes Stueck spielt sein Intro einmal und loopt danach ab einer Taktgrenze
## (``loop_offset`` in der .import-Datei, Ende = Dateiende):
## kampf Intro Takt 1-4 (10 s), Schleife Takt 5-32; menue Intro Takt 1-4
## (7,5 s), Schleife Takt 5-48. Herleitung und Austausch: docs/musik/LIESMICH.md.
##
## Welches Stueck laeuft, folgt der aktuellen Szene -- so braucht kein
## Bildschirm selbst an Musik zu denken. Beim Wechsel wird uebergeblendet;
## ein Stueck, das schon laeuft, laeuft weiter (Menue -> Hangar startet nicht neu).

const TRACKS := {
	"kampf": preload("res://assets/music/kampf.ogg"),
	"menue": preload("res://assets/music/menue.ogg"),
}
## Szenen mit eigenem Stueck; alle anderen bekommen ``DEFAULT_TRACK``.
const SCENE_TRACKS := {
	"res://scenes/battle.tscn": "kampf",
}
const DEFAULT_TRACK := "menue"

const VOLUME_DB := -6.0
const SILENT_DB := -60.0
const FADE_OUT_SECONDS := 0.6
const FADE_IN_SECONDS := 1.0

var _players := {}
var _tweens := {}
var _current := ""
var _last_scene: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_players()
	Accessibility.settings_changed.connect(_apply_enabled)


## Legt die Player an -- auch vor _ready (Testlauf ruft ``play`` frueh).
func _ensure_players() -> void:
	if not _players.is_empty():
		return
	for id in TRACKS:
		var player := AudioStreamPlayer.new()
		player.name = "Musik_" + id
		player.stream = TRACKS[id]
		player.volume_db = SILENT_DB
		add_child(player)
		_players[id] = player


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == _last_scene:
		return
	_last_scene = scene
	if scene != null:
		play(track_for(scene.scene_file_path))


## Welches Stueck zu einer Szene gehoert.
static func track_for(scene_path: String) -> String:
	return SCENE_TRACKS.get(scene_path, DEFAULT_TRACK)


func current_track() -> String:
	return _current


## Blendet auf ``id`` ueber. Laeuft es schon, passiert nichts.
func play(id: String) -> void:
	_ensure_players()
	if id == _current or not _players.has(id):
		return
	var old := _current
	_current = id
	if old != "":
		_fade(_players[old], SILENT_DB, FADE_OUT_SECONDS, true)
	if Accessibility.music:
		_start(_players[id])


func _start(player: AudioStreamPlayer) -> void:
	# Immer von vorn: das Intro gehoert zum Stueck, die Schleife folgt von selbst.
	player.volume_db = SILENT_DB
	player.play()
	_fade(player, VOLUME_DB, FADE_IN_SECONDS, false)


func _fade(player: AudioStreamPlayer, target_db: float, seconds: float, stop_after: bool) -> void:
	var running: Tween = _tweens.get(player)
	if running != null and running.is_valid():
		running.kill()
	var tween := create_tween()
	_tweens[player] = tween
	tween.tween_property(player, "volume_db", target_db, seconds)
	if stop_after:
		tween.tween_callback(func():
			# Nur anhalten, wenn es inzwischen nicht wieder gewuenscht ist.
			if _players.get(_current) != player or not Accessibility.music:
				player.stop())


func _apply_enabled() -> void:
	if _current == "":
		return
	var player: AudioStreamPlayer = _players[_current]
	if Accessibility.music and not player.playing:
		_start(player)
	elif not Accessibility.music and player.playing:
		_fade(player, SILENT_DB, FADE_OUT_SECONDS, true)
