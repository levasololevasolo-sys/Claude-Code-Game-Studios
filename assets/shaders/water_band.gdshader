// Swamp water plane behind the floor (visual-upgrade-plan §2.9 Топь): dark water
// with moving horizontal glints. UV.x periodic across the tile, UV.y 0..1 down.
shader_type canvas_item;

uniform vec4 glint : source_color = vec4(0.5, 0.6, 0.5, 1.0);

void fragment() {
	float u = UV.x * 6.2831853;
	float rows = sin(UV.y * 90.0 + sin(u * 11.0 + TIME * 0.7) * 2.0);
	float g = smoothstep(0.93, 1.0, rows) * (0.5 + 0.5 * sin(u * 23.0 - TIME * 0.9));
	g *= 1.0 - UV.y;
	COLOR = vec4(mix(COLOR.rgb, glint.rgb, g * 0.45), COLOR.a);
}
