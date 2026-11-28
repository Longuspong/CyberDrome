class_name BattleSfx
extends Node

## Toene im Kampf (28. Nov. 2026, Wunsch des Spielers): ein Ton je Waffe bei
## jedem Angriff. Die Dateien baut ``tools/build_sfx.py`` (eigener
## Synthesizer, kein BeepBox). Abschaltbar in den Optionen (Ton -> Effekte).
##
## Der Ton kommt mit action_used, also wenn der Treffer sitzt (nach dem
## Ausholen). Faehigkeiten spielen denselben Ton tiefer und lauter. Gegen
## Gewusel: wenige Stimmen, derselbe Ton hoechstens alle MIN_GAP_MS, Gegner
## etwas leiser als das eigene Squad.

const WEAPON_SOUNDS := {
	&"eq_pulse_blaster": preload("res://assets/sfx/blaster.wav"),
	&"eq_rail_lance": preload("res://assets/sfx/rail_lance.wav"),
	&"eq_rune_staff": preload("res://assets/sfx/rune_staff.wav"),
	&"eq_repair_kit": preload("res://assets/sfx/repair_kit.wav"),
	&"eq_hammer": preload("res://assets/sfx/hammer.wav"),
	&"eq_plasma_blade": preload("res://assets/sfx/plasma_blade.wav"),
	&"eq_deflector": preload("res://assets/sfx/deflector.wav"),
}
## Ohne eigenen Ton: nach Reichweite.
const FALLBACK := {"ranged": &"eq_pulse_blaster", "melee": &"eq_plasma_blade"}

const VOICES := 8
const MIN_GAP_MS := 45
const VOLUME_DB := -8.0
const FOE_DB := -4.0
const ABILITY_DB := 2.0
const ABILITY_PITCH := 0.85
const PITCH_JITTER := 0.05

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_ms := {}


func _ready() -> void:
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "Ton%d" % i
		add_child(player)
		_players.append(player)


## Ein Angriff oder eine Faehigkeit von ``unit``.
func on_action(unit: Unit, action: ActionData) -> void:
	if not Accessibility.sounds or unit == null or action == null or action.is_move():
		return
	var part := part_for(unit, action)
	if part == null:
		return
	var stream: AudioStream = WEAPON_SOUNDS.get(part.id,
		WEAPON_SOUNDS.get(FALLBACK.get(part.reach_kind(), &"eq_pulse_blaster")))
	var ability := not action.is_attack()
	var db := VOLUME_DB + (0.0 if unit.is_player else FOE_DB) + (ABILITY_DB if ability else 0.0)
	var pitch := (ABILITY_PITCH if ability else 1.0) * randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)
	# action_used kommt, wenn der Treffer sitzt (nach dem Ausholen).
	play(stream, db, pitch)


func play(stream: AudioStream, db: float, pitch: float) -> void:
	if stream == null or _players.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(stream, -100000)) < MIN_GAP_MS:
		return
	_last_ms[stream] = now
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = db
	player.pitch_scale = pitch
	player.play()


## Das Teil, dessen Aktion ``action`` ist (Halter oder Gadget).
static func part_for(unit: Unit, action: ActionData) -> PartData:
	for mount in unit.mounts:
		for key in ["attack", "ability"]:
			var own = mount.get(key)
			if own != null and (own as ActionData).id == action.id:
				return mount["part"]
	for gadget in unit.gadgets:
		var own = gadget.get("ability")
		if own != null and (own as ActionData).id == action.id:
			return gadget["part"]
	return null
