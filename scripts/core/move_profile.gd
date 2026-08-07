class_name MoveProfile
extends RefCounted

## Alles, was das Gitter ueber eine Einheit wissen muss, um ihre Bewegung zu
## rechnen -- und nicht mehr.
##
## Der Zweck ist die Trennlinie: grid.gd kennt keine Unit, keinen Node2D und
## keine Szene. Es bekommt ein Profil und gibt Felder zurueck. Damit ist die
## gesamte Bewegungslogik ohne laufendes Spiel testbar, und der Test aus dem
## Entwurf (200 Karten x 6 Antriebe) laeuft in Sekunden statt in Minuten.

var unit_id                              ## beliebiger Schluessel, nur Identitaet
var tile: Vector2i = Vector2i.ZERO

var can_pass_units: bool = false
var can_enter_steps: bool = false
var can_pass_blocks: bool = false        ## Post-MVP. Im MVP ueberall false.
var ignores_drift: bool = false
var drift_modifier: int = 0
var step_cost_reduced: bool = false


## Ein Antrieb ganz ohne Flags. Die Kartenvalidierung prueft gegen genau
## dieses Profil: was der einfachste Antrieb nicht erreicht, ist keine Karte.
static func plain() -> MoveProfile:
	return MoveProfile.new()


static func from_stats(stats: Dictionary, unit_id = null,
		tile: Vector2i = Vector2i.ZERO) -> MoveProfile:
	var profile := MoveProfile.new()
	profile.unit_id = unit_id
	profile.tile = tile
	profile.can_pass_units = stats.get("can_pass_units", false)
	profile.can_enter_steps = stats.get("can_enter_steps", false)
	profile.can_pass_blocks = stats.get("can_pass_blocks", false)
	profile.ignores_drift = stats.get("ignores_drift", false)
	profile.drift_modifier = stats.get("drift_modifier", 0)
	profile.step_cost_reduced = stats.get("step_cost_reduced", false)
	return profile


static func from_build(build: DromeBuild, unit_id = null,
		tile: Vector2i = Vector2i.ZERO) -> MoveProfile:
	return from_stats(build.stats(), unit_id, tile)


func duplicate_profile() -> MoveProfile:
	var copy := MoveProfile.new()
	copy.unit_id = unit_id
	copy.tile = tile
	copy.can_pass_units = can_pass_units
	copy.can_enter_steps = can_enter_steps
	copy.can_pass_blocks = can_pass_blocks
	copy.ignores_drift = ignores_drift
	copy.drift_modifier = drift_modifier
	copy.step_cost_reduced = step_cost_reduced
	return copy


func _to_string() -> String:
	var flags: Array[String] = []
	if can_pass_units: flags.append("pass_units")
	if can_enter_steps: flags.append("steps")
	if ignores_drift: flags.append("no_drift")
	if drift_modifier != 0: flags.append("drift%+d" % drift_modifier)
	if step_cost_reduced: flags.append("cheap_steps")
	return "MoveProfile(%s %s)" % [tile, "/".join(flags) if flags else "plain"]
