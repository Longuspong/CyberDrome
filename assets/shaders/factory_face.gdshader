// Flaechen der Fabrikstadt (28. Nov. 2026, docs/FACTORY_KONZEPT.md Abschnitt 14).
// Matte Platten wie die DROMEs: die Farbe steckt in der Vertexfarbe (oben
// heller als vorn, beim Bauen festgelegt), dazu die dunkle Kante je Flaeche.
// COLOR.a sagt, wo die Kante sitzt:
//   1.0  Quaderflaeche: Kante ringsum (UV 0..1)
//   0.75 Mantelstueck eines Zylinders: Kante nur oben/unten (UV.y)
//   0.5  Scheibe/Deckel als Faecher: Kante am Rand (UV.x = 1)
//   0.25 keine Kante (Leiterbahnen, Linien)
shader_type spatial;
render_mode unshaded, cull_disabled;

// Farben kommen wie im Entwurf (Hex) an: der Compatibility-Renderer gibt sie
// unveraendert aus, darum ohne source_color und ohne Umrechnung.
uniform vec4 c_line = vec4(0.039, 0.024, 0.094, 1.0);
uniform float edge_px = 1.0;

void fragment() {
	vec3 col = COLOR.rgb;
	float mode = COLOR.a;
	if (mode > 0.875) {
		vec2 d = min(UV, vec2(1.0) - UV) / max(fwidth(UV), vec2(1e-5));
		if (min(d.x, d.y) < edge_px) {
			col = c_line.rgb;
		}
	} else if (mode > 0.625) {
		float d = min(UV.y, 1.0 - UV.y) / max(fwidth(UV.y), 1e-5);
		if (d < edge_px) {
			col = c_line.rgb;
		}
	} else if (mode > 0.375) {
		float d = (1.0 - UV.x) / max(fwidth(UV.x), 1e-5);
		if (d < edge_px) {
			col = c_line.rgb;
		}
	}
	ALBEDO = col;
}
