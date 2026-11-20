shader_type canvas_item;

// Der Neon Cache als 3D-Szene (Design-Canvas 20. Nov. 2026, "Neon Cache ·
// Shader-Studie", vom Spieler abgesegnet): Hex-Container aus dunklem Metall
// mit Neon-Roehren (weisser Kern, roter Schein), Neon-Ring auf nassem Boden,
// schwebender Deckel. open (0..1): Schloss springt auf, Blitz, Ringwelle,
// Deckel fliegt hoch, Lichtsaeule, Kristall steigt, vier Energiekugeln kreisen.
// Raymarching in einem Durchgang; res = Groesse des Rechtecks in Pixeln.

uniform vec2 res = vec2(400.0, 340.0);
uniform float open : hint_range(0.0, 1.0) = 0.0;
uniform float still = 0.0;

// Farben linear (sRGB-Werte hoch 2,2), am Ende kommt die Gammakurve.
const vec3 RED = vec3(1.0, 0.03, 0.09);
const vec3 ORA = vec3(1.0, 0.32, 0.05);
const vec3 CY = vec3(0.027, 0.77, 0.83);
const vec3 MAG = vec3(1.0, 0.024, 0.67);

float t_now() { return still > 0.5 ? 2.0 : TIME; }

mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }
float hash(float n) { return fract(sin(n) * 43758.5453); }

float sd_hex(vec3 p, vec2 h) {
	vec3 k = vec3(-0.8660254, 0.5, 0.57735);
	p = abs(p);
	p.xy -= 2.0 * min(dot(k.xy, p.xy), 0.0) * k.xy;
	vec2 d = vec2(length(p.xy - vec2(clamp(p.x, -k.z * h.x, k.z * h.x), h.x)) * sign(p.y - h.x), p.z - h.y);
	return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float sd_hex2(vec2 p, float r) {
	vec3 k = vec3(-0.8660254, 0.5, 0.57735);
	p = abs(p);
	p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
	p -= vec2(clamp(p.x, -k.z * r, k.z * r), r);
	return length(p) * sign(p.y);
}

float o_lid() { return smoothstep(0.06, 0.6, open); }

float lid_y() {
	float t = t_now();
	float shake = 0.012 * sin(t * 38.0) * step(fract(t * 0.45), 0.1) * (1.0 - open);
	return mix(1.24, 2.6, o_lid()) + 0.07 * sin(t * 1.6) * o_lid() + shake;
}

vec3 lid_local(vec3 p) {
	float t = t_now();
	vec3 l = p - vec3(0.0, lid_y(), 0.0);
	l.xz = rot(open * 1.8 + 0.15 * sin(t * 0.7) * open) * l.xz;
	l.yz = rot(-0.75 * smoothstep(0.2, 0.75, open)) * l.yz;
	return l;
}

float gem_y() { return mix(0.85, 2.0, smoothstep(0.25, 0.8, open)) + 0.06 * sin(t_now() * 2.3); }

vec3 gem_local(vec3 p) {
	vec3 g = p - vec3(0.0, gem_y(), 0.0);
	g.xz = rot(t_now() * (1.3 + open * 2.0)) * g.xz;
	return g;
}

vec3 orb_c(float i) {
	float a = i * PI * 0.5 + t_now() * 1.4;
	float r = 1.05 * smoothstep(0.45, 0.95, open);
	return vec3(cos(a) * r, gem_y() + 0.22 * sin(a * 2.0 + t_now()), sin(a) * r);
}

float orb_r() { return 0.1 * smoothstep(0.4, 0.6, open); }

vec2 map(vec3 p) {
	vec2 r = vec2(p.y, 3.0);
	vec3 q = p - vec3(0.0, 0.55, 0.0);
	float body = sd_hex(q.xzy, vec2(1.0, 0.55)) - 0.025;
	float cav = sd_hex((p - vec3(0.0, 0.9, 0.0)).xzy, vec2(0.84, 0.62));
	body = max(body, -cav);
	if (body < r.x) { r = vec2(body, 1.0); }
	vec3 l = lid_local(p);
	float lid = sd_hex(l.xzy, vec2(1.03, 0.09)) - 0.025;
	if (lid < r.x) { r = vec2(lid, 2.0); }
	vec3 g = gem_local(p);
	float gs = 1.0 + 0.45 * smoothstep(0.3, 0.8, open);
	float gem = (abs(g.x) * 0.9 + abs(g.y) * 0.62 + abs(g.z) * 0.9 - 0.24 * gs) * 0.62;
	if (gem < r.x) { r = vec2(gem, 4.0); }
	if (open > 0.4) {
		for (int i = 0; i < 4; i++) {
			float fi = float(i);
			float d = length(p - orb_c(fi)) - orb_r();
			if (d < r.x) { r = vec2(d, 5.0 + fi); }
		}
	}
	return r;
}

float neon_d(vec3 p) {
	float seg = PI / 3.0;
	float a = atan(p.z, p.x);
	float ai = floor(a / seg + 0.5) * seg;
	vec2 c = vec2(cos(ai), sin(ai)) * 1.19;
	float dy = max(max(0.08 - p.y, p.y - 1.05), 0.0);
	float d = length(vec2(length(p.xz - c), dy));
	d = min(d, length(vec2(sd_hex2(p.xz, 1.035), p.y - 0.37)));
	d = min(d, length(vec2(sd_hex2(p.xz, 1.035), p.y - 1.1)));
	d = min(d, length(vec2(sd_hex2(p.xz, 1.75), p.y - 0.01)));
	vec3 l = lid_local(p);
	d = min(d, length(vec2(sd_hex2(l.xz, 1.065), l.y + 0.09)));
	d = min(d, length(vec2(sd_hex2(l.xz, 0.72), l.y - 0.118)));
	return d;
}

vec3 orb_col(float i) {
	if (i < 0.5) { return vec3(1.0, 0.42, 0.16); }
	if (i < 1.5) { return vec3(0.36, 0.53, 1.0); }
	if (i < 2.5) { return vec3(1.0, 0.88, 0.3); }
	return vec3(1.0, 0.96, 1.0);
}

vec3 nrm(vec3 p) {
	vec2 e = vec2(0.0015, 0.0);
	return normalize(vec3(map(p + e.xyy).x - map(p - e.xyy).x,
		map(p + e.yxy).x - map(p - e.yxy).x, map(p + e.yyx).x - map(p - e.yyx).x));
}

vec2 march(vec3 ro, vec3 rd, int n) {
	float t = 0.02;
	float m = -1.0;
	for (int i = 0; i < 90; i++) {
		if (i >= n) { break; }
		vec2 h = map(ro + rd * t);
		if (h.x < 0.0008 * t) { m = h.y; break; }
		t += h.x * 0.9;
		if (t > 22.0) { break; }
	}
	return vec2(t, m);
}

float hex_edge(vec2 p) {
	vec2 s = vec2(1.0, 1.7320508);
	vec4 hc = floor(vec4(p, p - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
	vec4 h = vec4(p - hc.xy * s, p - (hc.zw + 0.5) * s);
	vec2 hp = dot(h.xy, h.xy) < dot(h.zw, h.zw) ? h.xy : h.zw;
	hp = abs(hp);
	return 0.5 - max(dot(hp, normalize(vec2(1.0, 1.7320508))), hp.x);
}

float flick() {
	float t = t_now();
	return 0.88 + 0.12 * step(0.08, hash(floor(t * 17.0))) - 0.5 * step(0.985, hash(floor(t * 9.0)));
}

float flash() { return smoothstep(0.0, 0.07, open) * (1.0 - smoothstep(0.12, 0.35, open)); }

vec3 tube(float nd) {
	float core = smoothstep(0.016, 0.0, nd);
	float body = smoothstep(0.038, 0.0, nd);
	return (RED * body * 3.2 + vec3(1.0, 0.86, 0.92) * core * 2.6) * flick() + vec3(1.0) * body * flash() * 5.0;
}

vec3 sky(vec3 rd) {
	vec3 c = vec3(0.003, 0.0018, 0.009);
	c += MAG * 0.035 * exp(-abs(rd.y + 0.05) * 9.0);
	c += RED * 0.02 * exp(-abs(rd.y) * 3.0);
	return c;
}

vec3 shade(vec3 p, vec3 rd, float m, out float refl) {
	float t = t_now();
	vec3 n = nrm(p);
	refl = 0.0;
	vec3 k_l = normalize(vec3(-0.6, 0.8, 0.45));
	vec3 r_l = normalize(vec3(0.75, 0.35, -0.55));
	vec3 d_i = vec3(0.0, 1.15, 0.0) - p;
	float opened = smoothstep(0.08, 0.4, open);
	float li = (0.35 + 1.4 * opened) / (1.0 + dot(d_i, d_i) * 2.2);
	vec3 i_l = normalize(d_i);
	float ao = clamp(map(p + n * 0.14).x / 0.14, 0.0, 1.0);
	float nd = neon_d(p);
	vec3 col = vec3(0.0);
	if (m < 2.5) {
		vec3 base = vec3(0.012, 0.01, 0.02);
		vec3 q = m < 1.5 ? p - vec3(0.0, 0.55, 0.0) : lid_local(p);
		base *= 1.0 + step(0.5, fract(q.y * 9.0)) * 0.06;
		float dif = max(dot(n, k_l), 0.0);
		float rim = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);
		vec3 hv = normalize(k_l - rd);
		float sp = pow(max(dot(n, hv), 0.0), 64.0);
		col = base * (0.2 + dif * vec3(0.8, 0.5, 0.9)) * ao + sp * vec3(0.9, 0.6, 1.0) * 0.45;
		col += CY * rim * 0.3 * max(dot(n, r_l), 0.0) + MAG * rim * 0.1;
		col += RED * li * max(dot(n, i_l), 0.0) * 1.4;
		col += RED * 0.45 * exp(-nd * 9.0) * ao;
		col += tube(nd);
		bool outer = m < 1.5 ? abs(sd_hex(q.xzy, vec2(1.0, 0.55)) - 0.025) < 0.012 : true;
		if (m < 1.5 && outer) {
			float a = atan(q.z, q.x);
			float dash = step(0.4, fract(a * 12.0 / PI + t * 0.8));
			col += ORA * 2.6 * smoothstep(0.014, 0.0, abs(q.y - 0.12)) * dash * flick();
			col += MAG * 2.0 * smoothstep(0.01, 0.0, abs(q.y + 0.36)) * step(0.5, fract(a * 24.0 / PI - t * 1.3));
			float led = step(length(vec2(fract(a * 18.0 / PI) - 0.5, (q.y - 0.36) * 7.0)), 0.22);
			col += mix(CY, RED, step(0.5, hash(floor(a * 18.0 / PI) + floor(t * 3.0)))) * led * 2.2;
		} else if (m < 1.5) {
			col += RED * (0.3 + 2.2 * opened) * smoothstep(0.1, 1.0, p.y) * (0.7 + 0.3 * sin(t * 5.0));
		}
		if (m > 1.5) {
			float lk = step(abs(q.x), 0.17) * step(abs(q.z), 0.12) * step(0.1, q.y);
			float lk2 = step(abs(q.x), 0.11) * step(abs(q.z), 0.06) * step(0.1, q.y);
			vec3 lock_c = mix(RED, vec3(0.36, 1.0, 0.62), smoothstep(0.02, 0.1, open));
			col += lock_c * 3.0 * (lk - lk2) * flick();
			col += RED * (0.4 + 2.4 * opened) * step(n.y, -0.6);
		}
	} else if (m < 3.5) {
		float d = length(p.xz);
		vec3 base = vec3(0.002, 0.001, 0.004);
		float line = smoothstep(0.035, 0.0, hex_edge(p.xz * 1.4)) * exp(-d * 0.22);
		col = base + CY * line * 0.4 + MAG * line * 0.18 * smoothstep(4.0, 9.0, d);
		col += RED * (0.7 + 0.9 * opened) * exp(-d * 1.4) + ORA * 0.25 * exp(-d * 3.5);
		col += RED * 0.55 * exp(-nd * 7.0);
		col += tube(nd);
		float sw = 1.75 + smoothstep(0.08, 0.6, open) * 7.0;
		float swa = smoothstep(0.08, 0.14, open) * (1.0 - smoothstep(0.3, 0.7, open));
		col += (MAG * 2.2 + vec3(0.8)) * swa * smoothstep(0.08, 0.0, abs(sd_hex2(p.xz, sw)));
		float pud = smoothstep(0.3, 0.7, sin(p.x * 1.7 + cos(p.z * 1.3) * 2.0) * 0.5 + 0.5);
		refl = mix(0.3, 0.8, pud);
	} else if (m < 4.5) {
		float fr = pow(1.0 - max(dot(n, -rd), 0.0), 2.0);
		col = mix(vec3(1.0, 0.25, 0.45) * 2.4, vec3(3.5), fr) + MAG * 0.7;
	} else {
		vec3 oc = orb_col(m - 5.0);
		float fr = pow(1.0 - max(dot(n, -rd), 0.0), 2.0);
		col = oc * 2.5 + vec3(2.0) * (1.0 - fr);
	}
	return col;
}

vec3 render_ray(vec3 ro, vec3 rd, out float t_hit) {
	vec2 h = march(ro, rd, 90);
	t_hit = h.x;
	if (h.y < 0.0) { return sky(rd); }
	vec3 p = ro + rd * h.x;
	float rf;
	vec3 col = shade(p, rd, h.y, rf);
	if (rf > 0.0) {
		vec3 n = vec3(0.0, 1.0, 0.0);
		vec3 r = reflect(rd, n);
		vec2 h2 = march(p + n * 0.02, r, 50);
		vec3 rc;
		if (h2.y < 0.0) {
			rc = sky(r);
		} else {
			float d2;
			rc = shade(p + n * 0.02 + r * h2.x, r, h2.y, d2);
		}
		float fres = 0.25 + 0.75 * pow(1.0 - max(dot(n, -rd), 0.0), 4.0);
		col += rc * rf * fres;
	}
	col = mix(col, sky(rd), 1.0 - exp(-0.0025 * h.x * h.x));
	return col;
}

void fragment() {
	float t = t_now();
	vec2 fc = vec2(UV.x, 1.0 - UV.y) * res;
	float g_t = floor(t * 7.0);
	float g_on = max(step(0.9, hash(g_t * 1.7)), flash());
	float band = floor(fc.y / (res.y / 22.0));
	float sh = (hash(band + g_t * 13.0) - 0.5) * 0.07 * g_on * step(0.55, hash(band * 3.1 + g_t));
	vec2 uv = (fc * 2.0 - res) / res.y;
	uv.x += sh;
	float ang = t * 0.16 + 0.55;
	vec3 ro = vec3(4.6 * sin(ang), 2.7 + 0.4 * open, 4.6 * cos(ang));
	vec3 ta = vec3(0.0, 0.95 + 0.55 * smoothstep(0.2, 0.8, open), 0.0);
	vec3 fw = normalize(ta - ro);
	vec3 rt = normalize(cross(fw, vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(rt, fw);
	float fl = 2.1 - 0.25 * smoothstep(0.2, 0.8, open);
	uv.y += 0.12;
	vec3 rd = normalize(uv.x * rt + uv.y * up + fl * fw);
	float t_hit;
	vec3 col = render_ray(ro, rd, t_hit);
	float g = 0.0;
	float gn = 0.0;
	vec3 go = vec3(0.0);
	float tm = min(t_hit, 12.0);
	float dt = tm / 40.0;
	float opened = smoothstep(0.08, 0.45, open);
	for (int i = 0; i < 40; i++) {
		float tt = tm * (float(i) + 0.5) / 40.0;
		vec3 p = ro + rd * tt;
		float r = length(p.xz);
		float fk = 0.8 + 0.2 * sin(p.y * 7.0 - t * 6.0);
		g += exp(-r * r * (5.0 - 2.5 * opened)) * smoothstep(5.5, 1.15, p.y) * step(1.12, p.y) * fk * dt;
		gn += exp(-neon_d(p) * 16.0) * dt;
		if (open > 0.4) {
			for (int j = 0; j < 4; j++) {
				float fj = float(j);
				go += orb_col(fj) * exp(-length(p - orb_c(fj)) * 9.0) * dt;
			}
		}
	}
	col += mix(RED, ORA, 0.35) * g * (0.12 + 1.3 * opened);
	col += RED * gn * 0.8 * flick() + vec3(1.0) * gn * flash() * 3.0;
	col += go * 3.0;
	for (int i = 0; i < 16; i++) {
		float fi = float(i);
		float life = fract(t * (0.22 + 0.3 * opened) + hash(fi * 7.13));
		vec3 e = vec3((hash(fi * 1.31) - 0.5) * 1.1 * (0.4 + life), 1.15 + life * (2.6 + 1.5 * opened),
			(hash(fi * 2.17) - 0.5) * 1.1 * (0.4 + life));
		e.x += 0.15 * sin(t * 2.0 + fi);
		vec3 d = e - ro;
		float z = dot(d, fw);
		if (z < 0.1 || z > t_hit + 0.5) { continue; }
		vec2 sp = vec2(dot(d, rt), dot(d, up)) / z * fl;
		sp.y -= 0.12;
		float dd = length(uv - sp);
		col += mix(ORA, RED, life) * exp(-dd * dd * 9000.0) * (1.0 - life) * 3.0 * (0.1 + 0.9 * opened);
	}
	col = col / (1.0 + col * 0.45);
	col = pow(col, vec3(0.4545));
	col = mix(col, col * vec3(1.2, 0.8, 1.25), g_on * step(0.55, hash(band * 3.1 + g_t)));
	col *= 0.86 + 0.14 * step(1.0, mod(fc.y, 3.0));
	vec2 vu = fc / res;
	col *= 0.55 + 0.45 * pow(16.0 * vu.x * vu.y * (1.0 - vu.x) * (1.0 - vu.y), 0.25);
	col += (hash(fc.x * 0.37 + fc.y * 1.13 + t) - 0.5) * 0.025;
	// Weiche Raender: die Szene geht in den Bildschirm ueber, kein Kasten.
	float edge = smoothstep(0.0, 0.14, vu.x) * smoothstep(1.0, 0.86, vu.x)
		* smoothstep(0.0, 0.16, vu.y) * smoothstep(1.0, 0.9, vu.y);
	COLOR = vec4(col, edge);
}
