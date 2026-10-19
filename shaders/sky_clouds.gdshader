shader_type sky;
// Ciel : dégradé bleu, soleil, gros nuages blancs qui défilent lentement.
// Si une image de ciel (panorama) est fournie (Assets/Textures/Photo/ciel.jpg), elle est
// utilisée à la place. Coût faible : 2 lectures de texture par pixel.

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D pano_tex : source_color, filter_linear;
uniform bool use_pano = false;
uniform vec3 top_color : source_color = vec3(0.16, 0.36, 0.78);
uniform vec3 horizon_color : source_color = vec3(0.68, 0.80, 0.94);
uniform float cloud_cover = 0.48;

void sky() {
	vec3 d = EYEDIR;
	if (use_pano) {
		vec2 uv = vec2(atan(d.x, -d.z) / 6.2831853 + 0.5, acos(clamp(d.y, -1.0, 1.0)) / 3.14159265);
		COLOR = texture(pano_tex, uv).rgb;
	} else {
		float h = clamp(d.y, 0.0, 1.0);
		vec3 col = mix(horizon_color, top_color, pow(h, 0.55));
		if (d.y < 0.0) {
			col = mix(horizon_color, horizon_color * 0.8, clamp(-d.y * 4.0, 0.0, 1.0));
		}
		// soleil
		float sd = dot(d, LIGHT0_DIRECTION);
		col += vec3(1.0, 0.92, 0.75) * (pow(max(sd, 0.0), 600.0) * 4.0 + pow(max(sd, 0.0), 12.0) * 0.35);
		// nuages projetés sur un plan haut
		if (d.y > 0.0) {
			vec2 p = d.xz / (d.y + 0.12) * 0.22;
			float n1 = texture(noise_tex, p + vec2(TIME * 0.003, 0.0)).r;
			float n2 = texture(noise_tex, p * 2.7 + vec2(0.0, TIME * 0.005)).r;
			float n = n1 * 0.7 + n2 * 0.3;
			float c = smoothstep(cloud_cover, cloud_cover + 0.22, n);
			float shade = smoothstep(cloud_cover, cloud_cover + 0.45, n2 * 0.5 + n1 * 0.5);
			vec3 cloud = mix(vec3(1.0, 1.0, 1.02), vec3(0.62, 0.68, 0.78), shade * 0.7);
			cloud += vec3(1.0, 0.9, 0.7) * pow(max(sd, 0.0), 6.0) * 0.4;
			float fade = smoothstep(0.0, 0.18, d.y);
			col = mix(col, cloud, c * fade * 0.95);
		}
		COLOR = col;
	}
}
