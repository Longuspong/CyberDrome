// Kontur je Teil der Fabrikstadt (28. Nov. 2026): eine etwas groessere Huelle
// um jedes Teil in der Linienfarbe (Vertexfarbe). Gezeichnet werden nur ihre
// abgewandten Flaechen -- was neben dem Teil hervorschaut, ist sein farbiger
// Rand wie der Konturstrich im Entwurf (docs/design/fabrik_stadt).
shader_type spatial;
render_mode unshaded, cull_disabled;

varying vec3 view_normal;

void vertex() {
	view_normal = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	if (view_normal.z > 0.0) {
		discard;
	}
	ALBEDO = COLOR.rgb;
}
