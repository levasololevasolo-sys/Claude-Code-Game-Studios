// Screen post-processing (visual-upgrade-plan §2.4, §2.6): cheap bloom from the
// screen texture, split-tone grading, saturation, tinted vignette and film grain.
// Pure canvas_item + hint_screen_texture, so Forward+ and gl_compatibility look the
// same (no WorldEnvironment glow, no hdr_2d). Chromatic aberration is off by design.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float glow_thr = 0.65;
uniform float glow = 0.7;
uniform float glow_radius = 14.0;
uniform vec4 shadow_tint : source_color = vec4(0.1, 0.16, 0.3, 1.0);
uniform vec4 light_tint : source_color = vec4(1.0, 0.85, 0.65, 1.0);
uniform float tone = 0.18;
uniform float sat = 0.95;
uniform float vignette = 0.3;
uniform float vignette_soft = 0.45;
uniform vec4 vignette_col : source_color = vec4(0.03, 0.04, 0.08, 1.0);
uniform float grain = 0.035;

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

vec3 bright(vec2 uv) {
	vec3 c = texture(screen_tex, uv).rgb;
	return max(c - vec3(glow_thr), vec3(0.0)) / max(1.0 - glow_thr, 0.05);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	// Bloom: two rings of 8 taps; only what is above the threshold spreads.
	vec3 b = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = 6.2831853 * float(i) / 8.0;
		vec2 d = vec2(cos(a), sin(a)) * SCREEN_PIXEL_SIZE * glow_radius;
		b += bright(uv + d * 0.5) * 0.6;
		b += bright(uv + d * 1.4 + vec2(d.y, -d.x) * 0.3) * 0.4;
	}
	c += b / 8.0 * glow;
	// Split toning: shadows toward shadow_tint, lights toward light_tint.
	float l = luma(c);
	c = mix(c, c * 0.6 + shadow_tint.rgb * 0.4, tone * (1.0 - smoothstep(0.0, 0.45, l)));
	c = mix(c, c * light_tint.rgb, tone * smoothstep(0.45, 1.0, l));
	c = mix(vec3(luma(c)), c, sat);
	// Vignette in the location's shadow colour, not black.
	vec2 q = (uv - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float v = smoothstep(0.75 - vignette_soft, 0.95, length(q) * 1.25);
	c = mix(c, vignette_col.rgb, v * vignette);
	// Grain, stronger in the dark.
	float n = fract(sin(dot(FRAGCOORD.xy + fract(TIME * 7.13) * 97.0, vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * grain * (1.0 - l);
	COLOR = vec4(c, 1.0);
}
