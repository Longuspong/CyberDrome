class_name NeonGlow
extends Sprite2D

## Das Leuchten der Neon-Teile (Markenzeichen von Neon City).
##
## Eine eigene Ebene nur mit den Roehren (beim Backen erzeugt, mit breitem
## Strich als Lichthof), additiv ueber das Teil gelegt. Sie pulsiert leicht und
## flackert ab und zu wie eine echte Roehre. "Animationen reduzieren" laesst
## das Leuchten stehen, schaltet aber Pulsieren und Flackern ab.

const BASE := 0.75
const PULSE := 0.18
const PULSE_SPEED := 2.4
## Mittlerer Abstand zwischen zwei Flackern in Sekunden.
const FLICKER_EVERY := 4.0

var _time := 0.0
var _flicker_left := 0.0
var _next_flicker := 0.0
var _rng := RandomNumberGenerator.new()


## Ein Leuchten fuer ein Teil. Das Teil-Sprite ist auf den Entwurfsraum
## zurueckgerechnet; die Leuchtebene hat dieselbe Rasterung und sitzt deshalb
## ohne eigene Skalierung genau darauf.
static func create(texture_glow: Texture2D, part_texture: Texture2D) -> NeonGlow:
	var glow := NeonGlow.new()
	glow.name = "Neon"
	glow.texture = texture_glow
	glow.centered = false
	if part_texture != null and texture_glow != null and texture_glow.get_width() > 0:
		var ratio := float(part_texture.get_width()) / float(texture_glow.get_width())
		glow.scale = Vector2(ratio, ratio)
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = material
	glow.z_index = 1
	glow._rng.randomize()
	glow._time = glow._rng.randf() * TAU
	glow._next_flicker = glow._rng.randf_range(1.0, FLICKER_EVERY * 2.0)
	glow.self_modulate = Color(1, 1, 1, BASE)
	return glow


func _process(delta: float) -> void:
	if Accessibility.reduce_motion:
		self_modulate.a = BASE
		return
	_time += delta
	var alpha := BASE + PULSE * sin(_time * PULSE_SPEED)
	_next_flicker -= delta
	if _next_flicker <= 0.0:
		_flicker_left = _rng.randf_range(0.06, 0.16)
		_next_flicker = _rng.randf_range(1.0, FLICKER_EVERY * 2.0)
	if _flicker_left > 0.0:
		_flicker_left -= delta
		alpha *= 0.35
	self_modulate.a = clampf(alpha, 0.0, 1.0)
