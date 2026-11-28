// Underground back wall of a graph level (src/world/level_backdrop.gd). Drawn
// on one rect covering the whole level in world space; `rooms` is the level's
// module grid (RGBA float: r = depth band, g = room top y, b = room id, a = 1 in
// a room). Pixels in surface rooms (band 0) are transparent, so the sky backdrop
// shows; pixels in underground rooms get a layered cave: a far wall with
// parallax, rock pillars, stalactites hanging from the room top, glowing dots
// (fungi, embers or ice by location) and, in the deep band, Navi cracks.
// Optional `cave_tex` replaces the procedural far wall (seamless art).
shader_type canvas_item;

uniform sampler2D rooms : filter_nearest;
uniform vec2 grid_size = vec2(1.0);
uniform vec2 module_px = vec2(640.0, 360.0);
uniform vec2 cam = vec2(0.0);
uniform vec4 cave_back : source_color = vec4(0.08, 0.1, 0.08, 1.0);
uniform vec4 cave_rock : source_color = vec4(0.15, 0.19, 0.16, 1.0);
uniform vec4 cave_far : source_color = vec4(0.05, 0.07, 0.05, 1.0);
uniform vec4 glow : source_color = vec4(0.56, 0.89, 0.42, 1.0);
uniform float glow_density = 0.1;
uniform vec4 crack : source_color = vec4(0.69, 0.3, 1.0, 1.0);
uniform vec4 roots : source_color = vec4(0.23, 0.2, 0.13, 1.0);
uniform bool use_tex = false;
uniform sampler2D cave_tex : repeat_enable, filter_linear_mipmap;
uniform float tex_scale = 1.0;

varying vec2 wpos;

void vertex() {
	wpos = VERTEX;
}

float h1(float n) { return fract(sin(n * 127.1) * 43758.5453); }
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
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return s;
}

void fragment() {
	vec2 m = floor(wpos / module_px);
	vec4 info = vec4(0.0);
	if (m.x >= 0.0 && m.y >= 0.0 && m.x < grid_size.x && m.y < grid_size.y) {
		info = texture(rooms, (m + 0.5) / grid_size);
	}
	if (info.a < 0.5 || info.r < 0.5) {
		discard;
	}
	float band = info.r;
	float top_y = info.g;
	float rid = info.b;
	// far wall, parallax 0.35
	vec2 qf = wpos - cam * 0.65;
	vec3 col;
	if (use_tex) {
		col = texture(cave_tex, qf / (vec2(textureSize(cave_tex, 0)) * tex_scale)).rgb;
	} else {
		float n = fbm(qf * 0.0035);
		float strata = smoothstep(0.42, 0.5, fract(qf.y * 0.006 + n * 1.6)) * 0.25;
		col = mix(cave_far.rgb, cave_back.rgb, n) * (1.0 - strata);
		// far pillars
		float pc = floor(qf.x / 420.0);
		float px = (pc + 0.25 + 0.5 * h1(pc + 3.1)) * 420.0;
		float pw = 40.0 + 60.0 * h1(pc + 7.7);
		float wob = (vnoise(vec2(qf.y * 0.01, pc)) - 0.5) * 30.0;
		if (abs(qf.x - px + wob) < pw && h1(pc + 1.3) < 0.6) {
			col = mix(col, cave_far.rgb * 0.7, 0.8);
		}
	}
	// mid rock texture at parallax 0.7: blocky stones
	vec2 qm = wpos - cam * 0.3;
	float rn = fbm(qm * 0.012);
	// soft boulders: smooth noise with a lit upper edge, no hard blocks
	float stone = smoothstep(0.35, 0.75, vnoise(qm / vec2(90.0, 60.0)));
	float lit = clamp(stone - smoothstep(0.35, 0.75, vnoise((qm + vec2(0.0, 8.0)) / vec2(90.0, 60.0))), 0.0, 1.0);
	col += cave_rock.rgb * lit * 0.8;
	col = mix(col, mix(cave_back.rgb, cave_rock.rgb, stone), 0.5 * smoothstep(0.3, 0.6, rn));
	// stalactites hanging from the room top (world space)
	float sx = floor(wpos.x / 36.0);
	float sl = (40.0 + 140.0 * h1(sx * 1.7 + rid)) * step(0.45, h1(sx * 3.3 + rid));
	float sd = wpos.y - top_y;
	float sw = 14.0 * (1.0 - clamp(sd / max(sl, 1.0), 0.0, 1.0));
	if (sd > 0.0 && sd < sl && abs(fract(wpos.x / 36.0) - 0.5) * 36.0 < sw) {
		col = mix(col, cave_rock.rgb * 0.8, 0.85);
	}
	// roots dangling in the roots band
	if (band < 1.5) {
		float rx = floor(wpos.x / 22.0);
		float rl = 60.0 + 260.0 * h1(rx * 5.1 + rid);
		float on = step(0.7, h1(rx * 2.9 + rid));
		float rw = sin(sd * 0.03 + rx) * 4.0;
		if (on > 0.5 && sd > 0.0 && sd < rl && abs(fract(wpos.x / 22.0) * 22.0 - 11.0 + rw) < 1.6) {
			col = mix(col, roots.rgb, 0.9);
		}
	}
	// glowing dots (fungi / embers / ice), slow pulse
	vec2 gc = floor(qm / 90.0);
	float gh = h2(gc + 11.0);
	if (gh < glow_density) {
		vec2 gp = (gc + 0.2 + 0.6 * vec2(h2(gc + 3.0), h2(gc + 5.0))) * 90.0;
		float d = length(qm - gp);
		float pulse = 0.65 + 0.35 * sin(TIME * (1.0 + gh * 9.0) + gh * 40.0);
		col += glow.rgb * (smoothstep(5.0, 1.5, d) * 0.9 + smoothstep(40.0, 0.0, d) * 0.18) * pulse;
	}
	// Navi cracks in the deep band: thin, in patches, slowly breathing
	if (band > 1.5) {
		float cn = fbm(wpos * 0.003 + 3.0);
		float patch = smoothstep(0.55, 0.7, fbm(wpos * 0.0011 + 40.0));
		float line = smoothstep(0.006, 0.0, abs(cn - 0.5)) * patch;
		float breath = 0.45 + 0.25 * sin(TIME * 1.3 + cn * 20.0);
		col = mix(col, crack.rgb, line * breath);
		col += crack.rgb * smoothstep(0.05, 0.0, abs(cn - 0.5)) * patch * 0.07;
	}
	// depth: darker toward the room's top (vault in shadow), faint bounce light low
	float vy = clamp((wpos.y - top_y) / (module_px.y * 1.2), 0.0, 1.0);
	col *= mix(0.75, 1.15, smoothstep(0.0, 0.8, vy));
	COLOR = vec4(col, 1.0);
}
