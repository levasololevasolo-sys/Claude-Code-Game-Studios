// canvas_fx_hit_flash -- technical-artist, 2026-11-27. ADR-0005.
// Hit flash for a whole character: set on the CanvasGroup "Body" of a rig, so all
// slot sprites flash as ONE shape (no seams at the joints). The CanvasGroup hands
// the shader its own back buffer as the screen texture.
// Target: Forward+ and Compatibility (gl_compatibility); 1 texture sample, no loops.
// Budget: one extra CanvasGroup pass per character (hero only; regular enemies use
// modulate on their Skeleton2D, ADR-0005 Risks).
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

group_uniforms flash;
/** 0 = normal, 1 = the whole figure is flash_color (alpha kept). */
uniform float flash : hint_range(0.0, 1.0) = 0.0;
/** Colour of the flash: white for damage (art bible §5.5). */
uniform vec4 flash_color : source_color = vec4(1.0);
group_uniforms;

/** Guards the un-premultiply divide on fully transparent pixels. */
const float MIN_ALPHA = 0.0001;

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	// The group buffer is premultiplied: divide by alpha back to straight colour.
	c.rgb /= max(c.a, MIN_ALPHA);
	COLOR *= c;
	COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, flash);
}
