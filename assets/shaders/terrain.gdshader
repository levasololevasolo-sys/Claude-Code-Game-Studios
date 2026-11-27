// Ground and platform surface (visual-upgrade-plan §2.2, art-bible §6): world-space
// value-noise grain over the vertex gradient so the body is not flat plastic, with
// optional vertical streaks (bark, roots). Visual only.
shader_type canvas_item;

uniform float grain = 0.22;
uniform float streak = 0.5;

varying vec2 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float s = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { s += vnoise(p) * a; p *= 2.03; a *= 0.5; }
	return s;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float n = fbm(wp * 0.035);
	float s = fbm(vec2(wp.x * 0.09, wp.y * 0.008));
	float k = mix(n, s, streak) - 0.5;
	COLOR.rgb *= 1.0 + k * grain * 2.0;
}
