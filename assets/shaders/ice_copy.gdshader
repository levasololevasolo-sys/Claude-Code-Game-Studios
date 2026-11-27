// Ice copy of Мара (bestiary §3.4): turns any drawn enemy frame into a pale ice
// statue. The luminance of the painted frame is remapped onto an ice ramp
// (deep #2C4A6A -> ice #8FD3F5 -> frost white), the ink outline stays dark
// navy so the copy still reads on snow, a thin white frost rim lines the
// silhouette's inner edge and a few glints sweep over it. The sprite's
// modulate (hit flash) still multiplies on top. Unshaded; 5 taps per pixel;
// works on Forward+, Mobile and gl_compatibility (no screen texture).
shader_type canvas_item;
render_mode unshaded;

uniform vec4 deep : source_color = vec4(0.17, 0.29, 0.42, 1.0);
uniform vec4 ice : source_color = vec4(0.56, 0.83, 0.96, 1.0);
uniform vec4 frost : source_color = vec4(0.93, 0.97, 1.0, 1.0);
uniform vec4 ink : source_color = vec4(0.10, 0.14, 0.24, 1.0);
// Inner frost rim width in sheet texels.
uniform float rim_width = 2.5;
uniform float rim_alpha = 0.75;
uniform float glint_speed = 0.35;
uniform float alpha_mult = 0.92;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	// lift the mid tones: copies are pale
	float k = clamp(pow(l, 0.6) * 1.15, 0.0, 1.0);
	vec3 col = k < 0.5 ? mix(deep.rgb, ice.rgb, k * 2.0) : mix(ice.rgb, frost.rgb, (k - 0.5) * 2.0);
	col = mix(ink.rgb, col, smoothstep(0.06, 0.16, l));
	vec2 px = TEXTURE_PIXEL_SIZE * rim_width;
	float n = min(min(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
		min(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	float rim = clamp(c.a - n, 0.0, 1.0);
	col = mix(col, frost.rgb, rim * rim_alpha);
	// diagonal glint band sweeping over the body
	float g = fract((UV.x * 3.0 - UV.y * 2.0) * 1.5 - TIME * glint_speed);
	col += vec3(0.35) * smoothstep(0.0, 0.03, g) * (1.0 - smoothstep(0.03, 0.07, g)) * step(0.16, l);
	COLOR = vec4(col, c.a * alpha_mult) * COLOR;
}
