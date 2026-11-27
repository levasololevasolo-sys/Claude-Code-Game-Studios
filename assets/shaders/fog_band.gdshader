// Drifting fog band of the background (visual-upgrade-plan §2.1 L3). UV.x runs
// 0..1 across one parallax tile, so the wisps are periodic and tile seamlessly;
// UV.y runs 0..1 down the band. Visual only.
shader_type canvas_item;

uniform float drift = 0.012;

void fragment() {
	float u = UV.x;
	float t = TIME * drift * 6.2831853;
	float n = 0.55 + 0.22 * sin(6.2831853 * 3.0 * u + t)
		+ 0.15 * sin(6.2831853 * 7.0 * u - t * 1.7 + UV.y * 3.0)
		+ 0.08 * sin(6.2831853 * 17.0 * u + t * 2.3);
	float band = smoothstep(0.0, 0.45, UV.y) * (1.0 - smoothstep(0.55, 1.0, UV.y));
	COLOR = vec4(COLOR.rgb, COLOR.a * band * clamp(n, 0.0, 1.0));
}
