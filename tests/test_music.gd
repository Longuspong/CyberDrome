extends RefCounted

## Hintergrundmusik (24. Nov. 2026): Kampf dunkel, sonst hell; Loop ab Takt 5.


var t


func test_tracks_per_scene() -> void:
	var music = Music
	t.ok(music.track_for("res://scenes/battle.tscn") == "kampf", "Kampf: dunkles Stueck")
	t.ok(music.track_for("res://scenes/main.tscn") == "menue", "Home: helles Stueck")
	t.ok(music.track_for("res://scenes/hangar.tscn") == "menue", "Hangar: helles Stueck")


## Loop beginnt genau an Takt 5 (Intro 4 Takte), Ende = letzter Loop-Takt.
func test_loop_points() -> void:
	var kampf: AudioStreamOggVorbis = load("res://assets/music/kampf.ogg")
	t.ok(kampf.loop and is_equal_approx(kampf.loop_offset, 4 * 4 * 60.0 / 96.0), "kampf: Loop ab Takt 5")
	t.ok(absf(kampf.get_length() - 32 * 4 * 60.0 / 96.0) < 0.05, "kampf: endet nach Takt 32")
	var menue: AudioStreamOggVorbis = load("res://assets/music/menue.ogg")
	t.ok(menue.loop and is_equal_approx(menue.loop_offset, 4 * 4 * 60.0 / 128.0), "menue: Loop ab Takt 5")
	t.ok(absf(menue.get_length() - 48 * 4 * 60.0 / 128.0) < 0.05, "menue: endet nach Takt 48")


func test_switch() -> void:
	var music = Music
	var before: String = music.current_track()
	music.play("kampf")
	t.ok(music.current_track() == "kampf", "Wechsel auf kampf")
	music.play("menue")
	t.ok(music.current_track() == "menue", "Wechsel auf menue")
	if before != "":
		music.play(before)
