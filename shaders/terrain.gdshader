shader_type spatial;
// Terrain : couleurs de zone (couleur de sommet) + détail de VRAIES textures photo CC0
// (herbe Ground037, roche Rock023 d'ambientCG). La photo est normalisée par sa couleur
// moyenne : elle module la couleur de zone sans l'assombrir (taches sèches, cailloux, fissures).
// Deux échelles d'herbe pour casser la répétition ; roche projetée sur les pentes.
render_mode cull_disabled;

uniform sampler2D tex_grass : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_rock : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 grass_mean = vec3(0.61, 0.589, 0.36);
uniform vec3 rock_mean = vec3(0.55, 0.546, 0.537);
uniform float grass_scale = 0.22;
uniform float rock_scale = 0.12;
uniform float strength = 0.85;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 g1 = texture(tex_grass, wpos.xz * grass_scale).rgb / grass_mean;
	vec3 g2 = texture(tex_grass, wpos.xz * grass_scale * 0.11 + vec2(0.37, 0.71)).rgb / grass_mean;
	vec3 grass = mix(g1, g1 * g2, 0.5);
	vec3 n = abs(wnrm);
	vec3 rx = texture(tex_rock, wpos.zy * rock_scale).rgb;
	vec3 rz = texture(tex_rock, wpos.xy * rock_scale).rgb;
	vec3 rock = mix(rx, rz, n.z / max(n.x + n.z, 0.001)) / rock_mean;
	float steep = 1.0 - smoothstep(0.62, 0.86, n.y);
	vec3 detail = mix(grass, rock, steep);
	ALBEDO = COLOR.rgb * mix(vec3(1.0), detail, strength);
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
