shader_type canvas_item;
render_mode unshaded;

// Pixel-art weather on the scene-pixel grid (replaces the smooth Weather FX
// addon): rain is short 1-pixel streaks that move whole pixels, with little
// 3-pixel splashes on the pavement and road; snow is 1-2 pixel flakes; fog is a
// dithered, banded haze that thickens towards the street. Nothing falls under
// the two bus-shelter roofs or below the street into the station.

uniform vec2 scene_origin;
uniform vec2 scene_scale;
uniform float time = 0.0;
uniform float rain = 0.0;          // 0..1 weight (blended in by the city)
uniform float rain_density = 0.4;
uniform float snow = 0.0;
uniform float fog = 0.0;
uniform float wind = 0.2;          // slant: pixels sideways per pixel down
uniform vec4 rain_color : source_color = vec4(0.74, 0.82, 0.96, 0.7);
uniform vec4 snow_color : source_color = vec4(1.0, 1.0, 1.0, 0.95);
uniform vec4 fog_color : source_color = vec4(0.87, 0.9, 0.97, 0.85);
uniform vec4 shelter_a = vec4(990.0, 475.0, 1180.0, 557.0);   // scene rects x0 y0 x1 y1
uniform vec4 shelter_b = vec4(600.0, 426.0, 750.0, 481.0);
uniform float ground_y = 556.0;

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

float bayer(vec2 cell) {
	ivec2 c = ivec2(mod(cell, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[c.x + c.y * 4]) + 0.5) / 16.0;
}

bool sheltered(vec2 c) {
	return (c.x >= shelter_a.x && c.x < shelter_a.z && c.y >= shelter_a.y && c.y < shelter_a.w)
		|| (c.x >= shelter_b.x && c.x < shelter_b.z && c.y >= shelter_b.y && c.y < shelter_b.w);
}

// One layer of falling streaks; returns 0..1 coverage of this pixel.
float streaks(vec2 c, float speed, float spacing, float len, float columns, float seed, float density) {
	float slant = floor(c.y * wind);
	float x = c.x + slant;
	if (mod(x, columns) > 0.5) return 0.0;
	float col = floor(x / columns);
	float v = speed * (0.85 + 0.3 * hash(vec2(col, seed)));
	float y = c.y - floor(time * v) - floor(hash(vec2(col, seed + 1.0)) * spacing);
	float k = floor(y / spacing);
	float inside = mod(y, spacing);
	if (inside >= len) return 0.0;
	return step(hash(vec2(col * 0.37 + k, seed + 2.0)), density) * (inside < 1.0 ? 1.0 : 0.75);
}

float flakes(vec2 c, float cell_size, float speed, float seed, float size) {
	float y = c.y - floor(time * speed);
	vec2 cell = floor(vec2(c.x, y) / cell_size);
	float h = hash(cell + seed);
	if (h > 0.55) return 0.0;
	vec2 local = vec2(c.x, y) - cell * cell_size;
	float drift = floor(sin(time * 0.7 + h * 30.0) * 2.5 + 0.5);
	vec2 at = floor(vec2(hash(cell + seed + 4.0), hash(cell + seed + 8.0)) * (cell_size - size)) + vec2(drift, 0.0);
	vec2 d = local - at;
	return (d.x >= 0.0 && d.x < size && d.y >= 0.0 && d.y < size) ? 1.0 : 0.0;
}

void fragment() {
	vec2 p = (screen_pos - scene_origin) / scene_scale;
	vec2 c = floor(p);
	vec4 col = vec4(0.0);
	bool open = c.y < ground_y && !sheltered(c);
	if (rain > 0.001 && open) {
		float far = streaks(c, 150.0, 20.0, 3.0, 4.0, 11.0, rain_density);
		float near = streaks(c + vec2(2.0, 0.0), 260.0, 26.0, 5.0, 6.0, 29.0, rain_density * 0.85);
		float a = max(far * 0.55, near) * rain;
		col = vec4(rain_color.rgb, rain_color.a * a);
	}
	if (rain > 0.001 && c.y >= 446.0 && c.y < ground_y && !sheltered(c) && !sheltered(c + vec2(0.0, 2.0))) {
		// Splashes: a pixel bounces up, then two droplets spread sideways.
		vec2 cell = floor(c / vec2(9.0, 4.0));
		float rate = 1.7 + hash(cell + 3.0);
		float t = time * rate + hash(cell);
		float phase = fract(t);
		if (hash(cell + floor(t) * 0.13) < rain_density * 0.9 && phase < 0.16) {
			vec2 origin = cell * vec2(9.0, 4.0) + vec2(floor(hash(cell + 6.0) * 6.0) + 1.0, 3.0);
			vec2 d = c - origin;
			bool hit = phase < 0.07 ? (d.x == 0.0 && d.y == -1.0) : ((abs(d.x) == 1.0 && d.y == -1.0) || (abs(d.x) == 2.0 && d.y == 0.0));
			if (hit) col = vec4(rain_color.rgb * 1.1, rain_color.a * 0.9 * rain);
		}
	}
	if (snow > 0.001 && open) {
		float f = max(flakes(c, 11.0, 14.0, 3.0, 1.0) * 0.7, flakes(c + vec2(5.0, 0.0), 17.0, 24.0, 17.0, 2.0));
		if (f > 0.0) col = vec4(snow_color.rgb, snow_color.a * f * snow);
	}
	if (fog > 0.001 && c.y < ground_y + 2.0) {
		vec2 b = floor(c / 2.0);
		float n = noise(vec2(b.x * 0.025 + time * 0.25, b.y * 0.12)) * 0.6 + noise(vec2(b.x * 0.07 - time * 0.4, b.y * 0.3)) * 0.4;
		float amount = fog * (0.18 + 0.6 * smoothstep(240.0, 520.0, c.y)) * (0.55 + 0.6 * n);
		amount = floor(amount * 5.0 + bayer(b)) / 5.0;
		float a = clamp(amount, 0.0, 0.9) * fog_color.a;
		col = vec4(mix(col.rgb, fog_color.rgb, a / max(col.a + a, 0.001)), max(col.a, a));
	}
	COLOR = col;
}
