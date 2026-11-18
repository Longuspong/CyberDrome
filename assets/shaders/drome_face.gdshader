// Flaechen eines DROME in 3D (17. Nov. 2026). Dieselbe Beleuchtung wie der
// SVG-Generator (tools/build_sample_parts.py, _shade): drei feste Toene je
// Material -- Oberseite, linke und rechte Flanke -- nach der WELT-Normalen.
// Abgewandte Flaechen fallen weg wie im SVG; Quader- und Scheibenflaechen
// bekommen die dunkle Kante, die im SVG der Strich war.
//
// Weltachsen in Godot: X = px, Y = pz (oben), Z = -py (siehe DromeModel).
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 c_top : source_color;
uniform vec4 c_left : source_color;
uniform vec4 c_right : source_color;
uniform vec4 c_line : source_color;
// Kantenbreite in Bildpunkten (halbe Strichbreite des SVG).
uniform float edge_px = 1.0;
// Farbstich je DROME (Team, Trefferblende) in der gemeinsamen Kampfszene
// (Arena3D, 18. Nov. 2026). Multiplikativ wie modulate; 1 = unveraendert.
// Ein normaler Parameter auf eigenen Materialkopien je Einheit -- KEIN
// instance uniform: die liefern im Compatibility-Renderer bei vielen
// Instanzen falsche Werte (Bodenplatten kamen schwarz heraus).
uniform vec4 tint = vec4(1.0);
// Glanzkante (18. Nov. 2026, Waffen): helle Streifen schraeg ueber das Teil
// wie poliertes Metall; 0 = matt. Im Teil verankert (Modellkoordinaten in
// Entwurfseinheiten), laeuft also mit, wenn sich die Waffe bewegt.
uniform float shine = 0.0;
uniform float shine_period = 26.0;

varying vec3 world_normal;
varying vec3 local_pos;

void vertex() {
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	local_pos = VERTEX;
}

void fragment() {
	vec3 n = normalize(world_normal);
	float px = n.x;
	float py = -n.z;
	float pz = n.y;
	// Sichtbar, wenn die Normale zur Kamera zeigt (VIEW = (-1, -1, 1)).
	if (-px - py + pz <= 1e-4) {
		discard;
	}
	vec3 col = pz > 0.5 ? c_top.rgb : (px <= py ? c_left.rgb : c_right.rgb);
	// COLOR.a: 1 = Quaderflaeche (Kante ringsum), 0.5 = Scheibe (Kante am
	// Rand), 0 = Facette eines Drehkoerpers (keine Kante).
	float mode = COLOR.a;
	if (mode > 0.75) {
		vec2 d = min(UV, vec2(1.0) - UV) / max(fwidth(UV), vec2(1e-5));
		if (min(d.x, d.y) < edge_px) {
			col = c_line.rgb;
		}
	} else if (mode > 0.25) {
		float d = (1.0 - UV.x) / max(fwidth(UV.x), 1e-5);
		if (d < edge_px) {
			col = c_line.rgb;
		}
	}
	if (shine > 0.0) {
		float t = fract((local_pos.x + local_pos.y * 1.4 - local_pos.z) / shine_period);
		float band = smoothstep(0.0, 0.04, t) * (1.0 - smoothstep(0.10, 0.16, t));
		float thin = smoothstep(0.30, 0.32, t) * (1.0 - smoothstep(0.34, 0.36, t));
		float light = pz > 0.5 ? 1.0 : (px <= py ? 0.75 : 0.45);
		col = mix(col, vec3(1.0), shine * light * (band * 0.8 + thin * 0.5));
	}
	ALBEDO = col * tint.rgb;
}
