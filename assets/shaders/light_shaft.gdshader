// Additive light shafts (visual-upgrade-plan §2.1): each shaft is a quad whose UV.x
// is (index + 0..1 across) and UV.y 0..1 along; soft edges, fade with length,
// and a slow "breath" of 6-9 s with a per-shaft phase. Visual only.
shader_type canvas_item;
render_mode blend_add;

void fragment() {
	float idx = floor(UV.x);
	float u = fract(UV.x);
	float edge = pow(sin(3.14159 * u), 2.0);
	float along = pow(1.0 - UV.y, 1.3) * smoothstep(0.0, 0.08, UV.y);
	float period = 6.0 + mod(idx * 1.7, 3.0);
	float breathe = 0.65 + 0.35 * sin(TIME * 6.2831853 / period + idx * 2.1);
	COLOR = vec4(COLOR.rgb * COLOR.a * edge * along * breathe, 1.0);
}
