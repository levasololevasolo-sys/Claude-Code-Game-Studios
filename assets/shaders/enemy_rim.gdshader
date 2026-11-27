// Readability rim for pre-rendered enemies (visual-upgrade-plan §2.9, art-bible
// readability rule): drawn by a copy of the enemy sprite ABOVE the darkness, it
// shows only (a) a thin outline just outside the silhouette and (b) a back light
// on the silhouette's top edge, so a dark enemy reads against a dark swamp at any
// darkness. Everything else is transparent. Unshaded; 9 taps per pixel; works on
// Forward+, Mobile and gl_compatibility (no screen texture).
shader_type canvas_item;
render_mode unshaded;

uniform vec4 rim_col : source_color = vec4(0.72, 0.88, 0.77, 1.0);
uniform float rim_alpha = 0.5;
// Outline width in sheet texels (the sheets are 2x of the screen size).
uniform float width = 5.0;
uniform vec4 back_col : source_color = vec4(0.91, 0.96, 0.78, 1.0);
uniform float back_alpha = 0.55;
// Hit flash / fade, multiplied in (CrawlerSprite).
uniform float fade = 1.0;
// Emissive pass-through (drawn enemies, visuals.json enemy_rim.emit): bright,
// saturated texels (glowing eyes, sparks, the tip glow) are shown above the
// darkness too, so the eyes read in the unlit forest. 0 = off.
uniform float emit = 0.0;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * width;
	float a = texture(TEXTURE, UV).a;
	float n = 0.0;
	n = max(n, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	n = max(n, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	n = max(n, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	n = max(n, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	n = max(n, texture(TEXTURE, UV + px * 0.7).a);
	n = max(n, texture(TEXTURE, UV - px * 0.7).a);
	n = max(n, texture(TEXTURE, UV + vec2(px.x, -px.y) * 0.7).a);
	n = max(n, texture(TEXTURE, UV + vec2(-px.x, px.y) * 0.7).a);
	// (a) outside the silhouette, near it.
	float outline = clamp(n - a, 0.0, 1.0) * rim_alpha;
	// (b) inside, where the texel above is empty: light from above and behind.
	float above = texture(TEXTURE, UV - vec2(0.0, px.y * 1.4)).a;
	float back = clamp(a - above, 0.0, 1.0) * back_alpha;
	vec3 c = mix(rim_col.rgb, back_col.rgb, back / max(back + outline, 0.001));
	vec4 t = texture(TEXTURE, UV);
	float mx = max(t.r, max(t.g, t.b));
	float sat = (mx - min(t.r, min(t.g, t.b))) / max(mx, 0.001);
	float glow = emit * smoothstep(0.72, 0.95, mx) * smoothstep(0.38, 0.62, sat) * t.a;
	float rim = max(outline, back);
	COLOR = vec4(mix(c, t.rgb, glow / max(glow + rim, 0.001)), max(rim, glow) * fade);
}
