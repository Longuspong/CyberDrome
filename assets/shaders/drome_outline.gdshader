// Kontur um den fertigen DROME (17. Nov. 2026): direkt am Rand ein dunkler
// Strich (die aeussere Haelfte des SVG-Strichs), darum die Signalfarbe.
// Arbeitet auf dem Bild der 3D-Ansicht, also nach der Verdeckung.
//
// Kontur je Teil: mit ``use_signal`` kommt die Farbe aus der Signalebene
// (jedes Teil einfarbig in seiner Signalfarbe, DromeModel.LAYER_SIGNAL) --
// genommen wird das Teil, das dem Randpunkt am naechsten liegt. So traegt
// z. B. der Neon-Blaster seinen magenta Rand, der Rumpf seinen eigenen.
shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(0.03, 0.04, 0.07, 1.0);
uniform vec4 rim_color : source_color = vec4(0.18, 0.89, 0.9, 1.0);
uniform float line_px = 1.0;
uniform float rim_px = 3.0;
uniform bool use_signal = false;
uniform sampler2D signal_tex : source_color, filter_nearest;

// Einfaerbung (modulate) aus dem Vertex -- im Fragment ist COLOR schon mit
// der Textur multipliziert.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a >= 0.99) {
		COLOR = c * tint;
	} else {
		vec2 texel = TEXTURE_PIXEL_SIZE;
		float near = 0.0;
		float far = 0.0;
		// Signalfarbe des naechstgelegenen Teils: Radien von innen nach aussen,
		// der erste Treffer zaehlt.
		vec4 ring_signal = rim_color;
		float best = 1e9;
		for (int i = 0; i < 16; i++) {
			float a = 6.2831853 * float(i) / 16.0;
			vec2 dir = vec2(cos(a), sin(a)) * texel;
			near = max(near, texture(TEXTURE, UV + dir * line_px).a);
			near = max(near, texture(TEXTURE, UV + dir * line_px * 0.5).a);
			far = max(far, texture(TEXTURE, UV + dir * rim_px).a);
			far = max(far, texture(TEXTURE, UV + dir * rim_px * 0.5).a);
			if (use_signal) {
				for (int k = 1; k <= 4; k++) {
					float r = rim_px * float(k) / 4.0;
					if (r < best) {
						vec4 s = texture(signal_tex, UV + dir * r);
						if (s.a > 0.5) {
							best = r;
							ring_signal = vec4(s.rgb, 1.0);
						}
					}
				}
			}
		}
		vec4 ring = near > 0.5 ? line_color : ring_signal;
		float ring_a = max(near, far);
		// Bild ueber den Ring legen (Kanten des Bildes sind halbtransparent).
		vec3 rgb = mix(ring.rgb, c.rgb / max(c.a, 1e-4), c.a);
		float a = c.a + ring_a * (1.0 - c.a);
		COLOR = vec4(rgb, a) * tint;
	}
}
