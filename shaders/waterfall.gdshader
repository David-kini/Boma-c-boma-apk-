shader_type spatial;
// Cascade : bandes d'eau qui défilent vers le bas, plus opaque au centre, écume en bas.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec3 water = vec3(0.75, 0.88, 1.0);
uniform float speed = 1.6;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	float col = floor(UV.x * 24.0);
	float streak = 0.55 + 0.45 * sin(UV.y * 18.0 + TIME * speed * 6.0 + hash(col) * 30.0);
	float edge = smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x);
	float fade = smoothstep(0.0, 0.08, UV.y) * (1.0 - smoothstep(0.85, 1.0, UV.y) * 0.6);
	ALBEDO = water * (0.85 + 0.25 * streak);
	ALPHA = clamp(edge * fade * (0.45 + 0.4 * streak), 0.0, 0.9);
}
