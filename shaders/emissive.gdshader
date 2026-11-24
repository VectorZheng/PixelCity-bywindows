shader_type canvas_item;
render_mode unshaded, blend_add;

// City lights, added after the ambient pass. Lights switch per ROOM, not per
// pixel: five neighbouring office windows (one stretch of a floor) or the two
// windows of a flat share one switch, so a lit room reads as a warm block
// instead of scattered white specks. Each room keeps its state for 40-280 s,
// then re-rolls against the current occupancy. Distant towers are dimmer
// (haze), rain and fog soften every light, and rooms inside the low cloud
// deck disappear with it. Aviation beacons blink on the tallest roofs, and
// landmark facades run the evening light show.

uniform sampler2D win_tex : filter_nearest, repeat_disable;
uniform sampler2D mask_tex : filter_nearest, repeat_disable;   // B haze depth
uniform vec2 scene_origin;
uniform vec2 scene_scale;
uniform vec2 base_size = vec2(2172.0, 724.0);
uniform float night = 0.0;          // 0 day .. 1 night
uniform float occupancy = 0.5;      // share of homes lit
uniform float office = 0.3;         // share of office floors lit
uniform float light_show = 0.0;
uniform float time = 0.0;           // animation seconds (continuous)
uniform float clock = 0.0;          // local clock seconds
uniform float rain = 0.0;
uniform float fog = 0.0;
uniform float overcast = 0.0;
uniform float wind = 6.0;

varying vec2 screen_pos;

void vertex() {
	screen_pos = VERTEX;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

// Same cloud deck as backdrop.gdshader (without the dither).
float deck_at(vec2 cell) {
	float amount = clamp(max(rain * 0.8 + overcast * 0.2, fog), 0.0, 1.0);
	if (amount < 0.01) return 0.0;
	float base = mix(150.0, 215.0, max(fog, rain * 0.75));
	float ragged = 26.0 * fbm(vec2(cell.x * 0.006 + time * wind * 0.0004, 7.3)) - 13.0;
	return smoothstep(base + ragged + 10.0, base + ragged - 8.0, cell.y) * amount;
}

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	vec2 p = (screen_pos - scene_origin) / scene_scale;
	vec3 add = vec3(0.0);
	if (p.y >= 0.0 && p.x >= 0.0 && p.x < base_size.x && p.y < 370.0) {
		ivec2 ip = ivec2(floor(p));
		vec4 w = texelFetch(win_tex, ip, 0);
		float cls = floor(w.r * 255.0 / 40.0 + 0.5);
		float id = w.g * 255.0 * 256.0 + w.b * 255.0;
		float depth = texelFetch(mask_tex, ip, 0).b;
		// Haze and weather: far towers glow less; rain and fog blur everything.
		float seen = (1.0 - 0.72 * depth) * (1.0 - 0.35 * rain - 0.55 * fog) * (1.0 - 0.95 * deck_at(floor(p)));
		if (cls == 3.0) {
			// Aviation warning lights: slow red blink, visible by day too.
			vec2 key = vec2(id * 0.0137, id * 0.0071);
			float on = step(0.45, fract(time / 2.4 + hash(key) * 0.2));
			add += vec3(1.0, 0.16, 0.1) * on * mix(0.35, 1.1, night) * max(seen, 0.25);
		} else if (cls > 0.5 && night > 0.0) {
			if (w.a > 0.5 && light_show > 0.0) {
				// Landmark facade show: colour bands sweeping up, pattern changes every 20 s.
				float pattern = floor(time / 20.0);
				float band = fract(floor(p.y / 2.0) * 2.0 * (0.015 + 0.01 * hash(vec2(pattern))) - time * 0.12);
				// Hues stay in red..cyan..blue; the show never paints the city violet.
				vec3 col = hue(fract(band * 0.5 + pattern * 0.17 + floor(p.x / 6.0) * 0.02) * 0.64);
				float stripes = step(0.35, fract(p.y * 0.08 + time * 0.4 * (hash(vec2(pattern, 1.0)) - 0.5)));
				add += col * (0.35 + 0.5 * stripes) * light_show * night * 0.7 * seen;
			} else {
				// One switch per room: consecutive window ids run along a floor.
				float room = floor(id / (cls == 1.0 ? 5.0 : 2.0));
				vec2 key = vec2(room * 0.0137, room * 0.0071);
				float dwell = 40.0 + 240.0 * hash(key + 0.37);
				float epoch = floor((time + hash(key + 1.9) * dwell) / dwell);
				float roll = hash(vec2(room * 0.011 + epoch * 0.731, epoch * 0.173 + 0.5));
				float share = cls == 1.0 ? office : occupancy;
				if (roll < share) {
					// Homes: warm lamps behind curtains; offices: pale warm panels.
					vec3 warm = mix(vec3(1.0, 0.66, 0.34), vec3(1.0, 0.82, 0.58), hash(key + 7.0));
					vec3 panel = mix(vec3(1.0, 0.9, 0.7), vec3(0.86, 0.9, 0.86), hash(key + 5.0));
					vec3 col = cls == 1.0 ? panel : warm;
					float level = 0.7 + 0.3 * hash(key + 3.3);
					float tv = cls == 2.0 ? step(0.95, hash(key + 2.0)) : 0.0;
					vec3 tv_col = vec3(0.45, 0.65, 1.0) * (0.6 + 0.4 * step(0.0, sin(time * 5.0 + room) * sin(time * 1.7 + room * 0.3)));
					add += mix(col, tv_col, tv) * night * level * (cls == 1.0 ? 0.36 : 0.5) * seen;
				}
			}
		}
	}
	COLOR = vec4(add, 1.0);
}
