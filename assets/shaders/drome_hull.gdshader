// Aussenkontur der Drehkoerper (17. Nov. 2026): eine nach aussen geschobene
// Huelle, von der nur die ABGEWANDTEN Flaechen gezeichnet werden. Was davon
// neben dem Koerper hervorschaut, ist sein dunkler Rand -- wie der
// Konturstrich im SVG.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 c_line : source_color;

varying vec3 world_normal;

void vertex() {
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 n = normalize(world_normal);
	if (-n.x + n.z + n.y > 0.0) {
		discard;
	}
	ALBEDO = c_line.rgb;
}
