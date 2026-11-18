// Leuchten der Neon-Teile am 3D-DROME (17. Nov. 2026). Die Leuchtebene
// (DromeModel.LAYER_NEON) zeigt nur die Roehren in ihrer Farbe, der Rest ist
// schwarz. Hier kommt ein Lichthof dazu (wie der breite Strich in glow_svg),
// additiv ueber das Bild. Die Staerke (Pulsieren, Flackern) kommt ueber
// self_modulate.a aus NeonGlow.
shader_type canvas_item;
render_mode blend_add;

uniform float halo_px = 3.0;
uniform float halo_strength = 0.55;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE;
	vec3 core = texture(TEXTURE, UV).rgb;
	vec3 halo = vec3(0.0);
	for (int i = 0; i < 12; i++) {
		float a = 6.2831853 * float(i) / 12.0;
		vec2 dir = vec2(cos(a), sin(a)) * texel;
		halo = max(halo, texture(TEXTURE, UV + dir * halo_px * 0.5).rgb * 0.8);
		halo = max(halo, texture(TEXTURE, UV + dir * halo_px).rgb * 0.45);
	}
	vec3 rgb = max(core * 0.6, halo * halo_strength);
	COLOR = vec4(rgb * tint.a * tint.rgb, 1.0);
}
