// Solid ground of a graph level (LevelArt "fill"): world-space earth instead of
// flat colour. The vertex colour (depth darkening from LevelArt) is kept as the
// base; on it: soft mottling, layer lines, pebbles and root threads near the
// surface. Optional `earth_tex` (seamless art) replaces the procedural pattern.
shader_type canvas_item;

uniform vec4 stone : source_color = vec4(0.27, 0.33, 0.29, 1.0);
uniform vec4 strata : source_color = vec4(0.11, 0.15, 0.13, 1.0);
uniform vec4 roots : source_color = vec4(0.29, 0.24, 0.15, 1.0);
uniform bool use_tex = false;
uniform sampler2D earth_tex : repeat_enable, filter_linear_mipmap;
uniform float tex_scale = 1.0;

varying vec2 wpos;

void vertex() {
	wpos = VERTEX;
}

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.07 + vec2(5.0, 13.0);
		a *= 0.5;
	}
	return s;
}

void fragment() {
	vec3 base = COLOR.rgb;
	if (use_tex) {
		vec3 t = texture(earth_tex, wpos / (vec2(textureSize(earth_tex, 0)) * tex_scale)).rgb;
		COLOR = vec4(t * (base / max(max(base.r, base.g), 0.05)) * 0.9, COLOR.a);
	} else {
		float n = fbm(wpos * 0.008);
		vec3 col = base * (0.8 + 0.45 * n);
		float s = fract(wpos.y * 0.012 + fbm(wpos * 0.002) * 2.5);
		col = mix(col, strata.rgb, smoothstep(0.9, 0.97, s) * 0.55);
		// pebbles: jittered cells, a soft round stone in some
		vec2 c = floor(wpos / 28.0);
		vec2 p = (c + 0.25 + 0.5 * vec2(h2(c), h2(c + 7.0))) * 28.0;
		float r = 3.0 + 7.0 * h2(c + 3.0);
		float d = length((wpos - p) * vec2(1.0, 1.4));
		if (h2(c + 11.0) < 0.22) {
			col = mix(col, stone.rgb * (0.7 + 0.5 * n), smoothstep(r, r - 1.5, d));
			col *= 1.0 - 0.25 * smoothstep(r - 2.0, r, d) * smoothstep(r + 1.0, r, d);
		}
		// root threads
		float rt = abs(vnoise(vec2(wpos.x * 0.02, wpos.y * 0.004)) - 0.5);
		col = mix(col, roots.rgb, smoothstep(0.02, 0.0, rt) * 0.5 * smoothstep(0.35, 0.8, n));
		COLOR = vec4(col, COLOR.a);
	}
}
