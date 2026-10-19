shader_type spatial;
// Sol de la grande arène : dalles de pierre sombre polie (aspect mouillé / brillant),
// détail photo CC0 (Rock023), joints, et incrustations d'or : cercles concentriques,
// rayons, bande de runes et étoile centrale. Tout est calculé en coordonnées monde
// (aucune image dessinée), donc net de près comme de loin.

uniform sampler2D tex_rock : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tile_color = vec3(0.20, 0.215, 0.25);
uniform vec3 gold_color = vec3(1.0, 0.80, 0.42);
uniform vec3 sky_tint = vec3(0.55, 0.70, 0.95);
uniform float tile_size = 2.2;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 1 sur une bande centrée sur r0, de demi-largeur w (bords adoucis)
float band(float r, float r0, float w, float aa) {
	return 1.0 - smoothstep(w - aa, w + aa, abs(r - r0));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float aa = max(fwidth(r), 0.004) * 1.2;

	// --- dalles (rangées décalées), variation par dalle, joints sombres
	vec2 t = p / tile_size;
	t.x += step(1.0, mod(floor(t.y), 2.0)) * 0.5;
	vec2 cell = floor(t);
	vec2 f = fract(t);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float joint = (1.0 - smoothstep(0.008, 0.022 + fwidth(t.x), edge)) * 0.8;
	float v = hash(cell);
	vec3 photo = texture(tex_rock, p * 0.21 + vec2(v * 7.0, v * 3.0)).rgb;
	float lum = dot(photo, vec3(0.333)) / 0.545;
	vec3 stone = tile_color * (0.82 + 0.36 * v) * mix(1.0, lum, 0.55);
	stone = mix(stone, vec3(0.05, 0.05, 0.06), joint);

	// --- incrustations d'or
	float g = 0.0;
	g = max(g, band(r, 3.4, 0.06, aa));
	g = max(g, band(r, 7.5, 0.11, aa));
	g = max(g, band(r, 8.1, 0.035, aa));
	g = max(g, band(r, 14.0, 0.06, aa));
	g = max(g, band(r, 20.0, 0.14, aa));
	g = max(g, band(r, 20.7, 0.04, aa));
	g = max(g, band(r, 31.5, 0.08, aa));
	g = max(g, band(r, 39.5, 0.16, aa));
	g = max(g, band(r, 40.3, 0.04, aa));
	g = max(g, band(r, 45.8, 0.1, aa));
	// rayons entre 8 et 20 m (16) et entre 20,7 et 31,5 m (32, décalés)
	float s16 = abs(fract(ang / TAU * 16.0) - 0.5) * r * TAU / 16.0;
	g = max(g, (1.0 - smoothstep(0.03, 0.03 + aa * 2.0, s16)) * step(8.1, r) * step(r, 20.0));
	float s32 = abs(fract(ang / TAU * 32.0) - 0.5) * r * TAU / 32.0;
	g = max(g, (1.0 - smoothstep(0.022, 0.022 + aa * 2.0, s32)) * step(20.7, r) * step(r, 31.5) * 0.9);
	// bande de « runes » entre 40,6 et 45,4 m : traits et losanges alternés
	if (r > 40.6 && r < 45.4) {
		float u = fract(ang / TAU * 72.0);
		float w = (r - 40.6) / 4.8;
		float rune = step(abs(u - 0.5), 0.035) * step(0.15, w) * step(w, 0.85);
		float diamond = step(abs(u - 0.5) * 2.0 + abs(w - 0.5) * 1.4, 0.35) * step(0.5, fract(ang / TAU * 36.0));
		g = max(g, max(rune, diamond * 0.85));
	}
	// étoile centrale à 8 branches
	float star = 2.8 * (0.45 + 0.55 * pow(abs(cos(ang * 4.0)), 6.0));
	g = max(g, (1.0 - smoothstep(star - aa, star + aa, r)) * smoothstep(star - 0.25 - aa, star - 0.25 + aa, r));
	g = max(g, (1.0 - smoothstep(0.55 - aa, 0.55 + aa, r)));

	// --- reflet du ciel (effet sol mouillé) selon l'angle de vue
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(stone, gold_color, g);
	METALLIC = mix(0.0, 0.85, g);
	ROUGHNESS = mix(0.22, 0.25, g);
	SPECULAR = 0.75;
	EMISSION = sky_tint * fres * (1.0 - g) * 0.55 + gold_color * g * 0.55;
}
