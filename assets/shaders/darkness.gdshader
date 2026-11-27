// Darkness of Navь (GDD amulet-and-flare §3.9, F4, F5). One rectangle in world
// space covers the room; alpha = dk × (1 − hero light) × Π(1 − spot_i).
// Plain canvas_item shader: uniform arrays and a bounded loop only, so it runs on
// Forward+, Mobile and gl_compatibility alike (no 2D lights, no screen texture).
// Visual upgrade (visual-upgrade-plan §2.4, §2.9): the darkness multiplies the
// scene toward dark_color (the location's night tint, CanvasModulate-like) instead
// of covering it with flat black, so depth, hue and contrast survive in the dark.
// The amount is still dk × keep (F4, F5 unchanged).
shader_type canvas_item;
render_mode blend_mul;

const int MAX_SPOTS = 64;

uniform vec4 dark_color : source_color = vec4(0.02, 0.03, 0.04, 1.0);
uniform float dk = 0.78;
uniform vec2 hero_pos = vec2(0.0);
uniform float light_r = 360.0;
uniform float full_frac = 0.15;
uniform float mid_frac = 0.6;
uniform float mid_level = 0.7;
// Self-lit things: xy = world position, z = radius, w = strength 0..1.
uniform vec4 spots[64];
uniform int spot_count = 0;

varying vec2 world_pos;

void vertex() {
	world_pos = VERTEX;
}

float hero_light(float d) {
	float x = d / max(light_r, 1.0);
	if (x >= 1.0) return 0.0;
	if (x <= full_frac) return 1.0;
	if (x <= mid_frac) return mix(1.0, mid_level, (x - full_frac) / max(mid_frac - full_frac, 0.0001));
	return mix(mid_level, 0.0, (x - mid_frac) / max(1.0 - mid_frac, 0.0001));
}

void fragment() {
	float keep = 1.0 - hero_light(distance(world_pos, hero_pos));
	for (int i = 0; i < MAX_SPOTS; i++) {
		if (i >= spot_count) break;
		vec4 s = spots[i];
		float d = distance(world_pos, s.xy);
		// Flat core to half the radius, then linear to the edge.
		float f = s.w * clamp((s.z - d) / max(s.z * 0.5, 0.001), 0.0, 1.0);
		keep *= 1.0 - f;
	}
	COLOR = vec4(mix(vec3(1.0), dark_color.rgb, clamp(dk * keep, 0.0, 1.0)), 1.0);
}
