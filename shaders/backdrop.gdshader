shader_type canvas_item;
render_mode unshaded;

// Live pixel-art background. The city (tools/gen_city.py) is sampled one texel
// per scene pixel with nearest filtering; the sky, sun, moon, stars, clouds and
// the bay are generated here on the same scene-pixel grid, with ordered
// dithering instead of smooth gradients, so everything reads as pixel art.
// The ground is lit later by the ambient multiply pass.

uniform sampler2D base_tex : filter_nearest, repeat_disable;
uniform sampler2D mask_tex : filter_nearest, repeat_disable;   // R sky, G water, B haze depth, A foliage
uniform sampler2D win_tex : filter_nearest, repeat_disable;    // R window class
uniform vec2 scene_origin;
uniform vec2 scene_scale;
uniform vec2 base_size = vec2(2172.0, 724.0);
uniform float view_top = 0.0;
uniform float horizon_y = 362.0;
uniform float time = 0.0;
uniform vec3 zenith : source_color = vec3(0.2, 0.45, 0.9);
uniform vec3 horizon : source_color = vec3(0.65, 0.8, 0.95);
uniform vec2 sun_pos = vec2(-999.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float sun_visible = 0.0;
uniform vec2 moon_pos = vec2(-999.0);
uniform float moon_phase = 0.5;
uniform float moon_visible = 0.0;
uniform float stars = 0.0;
uniform float cloud_cover = 0.2;
uniform float rain = 0.0;
uniform vec3 cloud_lit : source_color = vec3(1.0);
uniform vec3 cloud_shade : source_color = vec3(0.6, 0.62, 0.7);
uniform float wind = 6.0;
uniform float day = 1.0;
// Weather on the city itself (round 6): haze, low cloud deck, snow caps.
uniform float fog = 0.0;
uniform float snow = 0.0;
uniform float overcast = 0.0;
// Lightning: flash 0..1, bolt column, where it ends (behind the skyline) and a seed.
uniform float lightning = 0.0;
uniform float bolt_x = -999.0;
uniform float bolt_end = 300.0;
uniform float bolt_seed = 0.0;

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

// Integer hash for sparse features: hash() above is a fract() lattice whose
// rare tails line up (the round-7 "scattered" stars were one dotted row, every
// 50 px along y = 63). This one has no such alignment.
float hash_u(vec2 c) {
	uvec2 q = uvec2(ivec2(c) + ivec2(65536));
	uint h = q.x * 1597334677u ^ q.y * 3812015801u;
	h ^= h >> 16u;
	h *= 2246822519u;
	h ^= h >> 13u;
	h *= 3266489917u;
	h ^= h >> 16u;
	return float(h) * (1.0 / 4294967296.0);
}

// 4x4 ordered dither threshold in [0, 1).
float bayer(vec2 cell) {
	ivec2 c = ivec2(mod(cell, 4.0));
	int i = c.x + c.y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0;
}

float stepped(float v, float levels, vec2 cell) {
	return clamp(floor(v * levels + bayer(cell)) / levels, 0.0, 1.0);
}

float cloud_thr() {
	float cover = clamp(cloud_cover * 0.9 + rain * 0.25, 0.0, 1.0);
	return 1.0 - cover * 0.62 - 0.18;
}

// Banded tone (0, 0.5, 1) of the 2x2 cloud block at c2, or -1 for clear sky.
float cloud_tone(vec2 c2) {
	float span = max(horizon_y - view_top, 60.0);
	float h = clamp((horizon_y - c2.y) / span, 0.0, 1.0);
	vec2 q = vec2(c2.x * 0.0042 + time * wind * 0.00028, c2.y * 0.016);
	float n = fbm(q + vec2(0.0, 3.7));
	float body = n - cloud_thr() + 0.06 * smoothstep(0.1, 0.5, h);
	if (body < -0.012) return -1.0;
	float above = fbm(q + vec2(0.0, 3.7) - vec2(0.0, 0.05));
	return floor(clamp((above - n) * 9.0 + 0.55 + body * 2.0, 0.0, 1.0) * 2.0 + 0.5) / 2.0;
}

// Within 2 px of a tower (the outline ring)?
bool near_tower(vec2 cell) {
	ivec2 c = ivec2(cell);
	if (c.x < 2 || c.y < 2 || c.x >= int(base_size.x) - 2 || c.y >= int(base_size.y) - 2) return false;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			if (texelFetch(mask_tex, c + ivec2(i, j), 0).r < 0.5) return true;
		}
	}
	return false;
}

// Number of sky cells (0..4) in the 2x2 cloud block at c2.
int block_sky(vec2 c2) {
	ivec2 b = ivec2(c2);
	int n = 0;
	for (int k = 0; k < 4; k++) {
		ivec2 t = b + ivec2(k % 2, k / 2);
		if (t.x < 0 || t.y < 0 || t.x >= int(base_size.x) || t.y >= int(base_size.y)) { n++; continue; }
		if (texelFetch(mask_tex, t, 0).r > 0.5) n++;
	}
	return n;
}

bool is_sky(ivec2 t) {
	if (t.x < 0 || t.y < 0 || t.x >= int(base_size.x) || t.y >= int(base_size.y)) return true;
	return texelFetch(mask_tex, t, 0).r > 0.5;
}

// Do the blocks at c2 and c2 + d touch through open sky (a pair of facing
// sky cells), rather than across a tower column?
bool sky_link(vec2 c2, vec2 d) {
	ivec2 b = ivec2(c2);
	for (int k = 0; k < 2; k++) {
		ivec2 a; ivec2 n;
		if (d.x > 0.0) { a = b + ivec2(1, k); n = b + ivec2(2, k); }
		else if (d.x < 0.0) { a = b + ivec2(0, k); n = b + ivec2(-1, k); }
		else if (d.y > 0.0) { a = b + ivec2(k, 1); n = b + ivec2(k, 2); }
		else { a = b + ivec2(k, 0); n = b + ivec2(k, -1); }
		if (is_sky(a) && is_sky(n)) return true;
	}
	return false;
}

vec3 cloud_at(vec2 cell, vec3 col, float h) {
	// Chunky 2-pixel clouds with flat-ish bottoms and three tones.
	vec2 c2 = floor(cell / 2.0) * 2.0;
	vec2 q = vec2(c2.x * 0.0042 + time * wind * 0.00028, c2.y * 0.016);
	float n = fbm(q + vec2(0.0, 3.7));
	float thr = cloud_thr();
	float body = n - thr + 0.06 * smoothstep(0.1, 0.5, h);
	if (body < -0.012) return col;
	// Hard edges on the 2-px cloud grid and banded (undithered) tones: an
	// ordered dither here scattered lone white pixels along every tower outline.
	float above = fbm(q + vec2(0.0, 3.7) - vec2(0.0, 0.05));
	float tone = clamp((above - n) * 9.0 + 0.55 + body * 2.0, 0.0, 1.0);
	tone = floor(tone * 2.0 + 0.5) / 2.0;
	// Next to a tower, a block cut off from its own cloud reads as a white
	// speck. In the outline ring a block is drawn only when it touches, through
	// open sky, a FULLY visible cloud block; it keeps its tone if one of those
	// shares it, else takes theirs, and a block the tower half covers is never
	// brighter than mid tone. All tests are per 2x2 block (both pixels agree)
	// and only the thin ring pays for the extra noise.
	if (near_tower(c2) || near_tower(c2 + vec2(1.0))) {
		bool same = false;
		float other = -1.0;
		for (int k = 0; k < 4; k++) {
			vec2 d = k == 0 ? vec2(2.0, 0.0) : k == 1 ? vec2(-2.0, 0.0) : k == 2 ? vec2(0.0, 2.0) : vec2(0.0, -2.0);
			if (!sky_link(c2, d) || block_sky(c2 + d) < 4) continue;
			float t = cloud_tone(c2 + d);
			if (t < 0.0) continue;
			if (abs(t - tone) < 0.01) same = true;
			else if (other < 0.0) other = t;
		}
		if (!same) {
			if (other < 0.0) return col;
			tone = other;
		}
		if (block_sky(c2) < 4) tone = min(tone, 0.5);
	}
	vec3 cloud = mix(cloud_shade, cloud_lit, tone);
	return mix(col, cloud, 0.92);
}

vec3 sky_at(vec2 p) {
	vec2 cell = floor(p);
	float span = max(horizon_y - view_top, 60.0);
	float h = clamp((horizon_y - cell.y) / span, 0.0, 1.0);
	vec3 col = mix(horizon, zenith, stepped(pow(h, 0.6), 12.0, cell));
	// Sun: stepped glow rings around a hard pixel disc.
	float d = distance(cell + 0.5, sun_pos);
	float glow = exp(-d / 200.0) * 0.28 + exp(-d / 38.0) * 0.32;
	col += sun_color * stepped(glow, 10.0, cell) * sun_visible;
	if (d < 9.5) col = mix(col, vec3(1.0, 0.97, 0.86), sun_visible);
	else if (d < 11.0) col = mix(col, sun_color, 0.6 * sun_visible);
	// Stars: only a scattered few (city light pollution), high above the haze.
	// Round 8: one notch rarer, and only in open sky (mask R) at least 3 px from
	// any tower, so a star can never pass for a speck on a skyline outline.
	float s = hash_u(cell);
	bool open_sky = false;
	if (s > 0.99994 && stars > 0.0) {
		open_sky = cell.y < 0.0 || cell.x < 0.0 || cell.x >= base_size.x
			|| (texelFetch(mask_tex, ivec2(cell), 0).r > 0.5 && !near_tower(cell));
	}
	if (open_sky) {
		float tw = step(0.3, sin(time * (0.4 + hash(cell + 3.1) * 1.2) + s * 40.0));
		col = mix(col, vec3(1.0, 0.97, 0.9), stars * (0.5 + 0.35 * tw) * smoothstep(0.3, 0.6, h));
	}
	// Moon: a larger pixel disc with its phase terminator, the night's focal point.
	vec2 m = (cell + 0.5 - moon_pos) / 9.0;
	float r = length(m);
	if (r < 1.0 && moon_visible > 0.0) {
		float k = cos(moon_phase * 6.2831853);
		float x_term = k * sqrt(max(0.0, 1.0 - m.y * m.y));
		float lit = moon_phase < 0.5 ? step(x_term, m.x) : step(m.x, -x_term);
		vec3 moon_col = mix(vec3(0.17, 0.2, 0.26), vec3(0.95, 0.94, 0.86), lit);
		if (lit > 0.5 && hash(cell + 9.0) > 0.8) moon_col *= 0.88;  // maria
		col = mix(col, moon_col, moon_visible);
	} else {
		float halo = (exp(-distance(cell, moon_pos) / 30.0) * 0.17 + exp(-distance(cell, moon_pos) / 90.0) * 0.06) * moon_visible;
		col += vec3(0.7, 0.78, 0.9) * stepped(halo, 8.0, cell);
	}
	// Height for the cloud is taken per 2x2 cloud block, not per row: a per-row
	// threshold split blocks into 1-px white slivers along tower outlines.
	col = cloud_at(cell, col, clamp((horizon_y - floor(cell.y / 2.0) * 2.0) / span, 0.0, 1.0));
	if (lightning > 0.002) {
		// The whole cloud deck lights up from inside, brightest near the strike.
		float near = exp(-abs(cell.x - bolt_x) / 260.0);
		col += vec3(0.55, 0.6, 0.78) * lightning * (0.18 + 0.4 * near) * (0.6 + 0.4 * h);
		if (cell.y < bolt_end) {
			// Main channel: jagged by two noise octaves, plus one fork.
			float y = cell.y;
			float x = bolt_x + 22.0 * (noise(vec2(y * 0.045, bolt_seed * 3.7)) - 0.5) + 7.0 * (noise(vec2(y * 0.3, bolt_seed * 9.1)) - 0.5);
			float fork_y = mix(view_top + 30.0, bolt_end, 0.45);
			float fx = x + (y - fork_y) * 0.55 + 5.0 * (noise(vec2(y * 0.4, bolt_seed * 5.3)) - 0.5);
			float d = abs(cell.x - x);
			if (y > fork_y && y < fork_y + (bolt_end - fork_y) * 0.6) d = min(d, abs(cell.x - fx) + 0.3);
			float core = step(d, 0.6);
			float glow = exp(-d / 2.5);
			col = mix(col, vec3(0.93, 0.96, 1.0), core * lightning);
			col += vec3(0.5, 0.6, 1.0) * glow * 0.45 * lightning;
		}
	}
	return col;
}

// Low cloud deck in rain and fog: a ragged base drifting with the wind that
// swallows the tops of the tallest towers. 0 clear .. 1 inside the cloud.
float deck_at(vec2 cell) {
	float amount = clamp(max(rain * 0.8 + overcast * 0.2, fog), 0.0, 1.0);
	if (amount < 0.01) return 0.0;
	float base = mix(150.0, 215.0, max(fog, rain * 0.75));
	float ragged = 26.0 * fbm(vec2(cell.x * 0.006 + time * wind * 0.0004, 7.3)) - 13.0;
	float inside = smoothstep(base + ragged + 10.0, base + ragged - 8.0, cell.y);
	return stepped(inside, 4.0, cell) * amount;
}

// One texel = one scene pixel in every display mode. When the scene is shown
// smaller than 1:1 (fit mode, small windows) a screen pixel covers several
// texels: average exactly those whole texels (integer box filter), never a
// linear/mipmap tap, which smeared 1-px roof highlights into halo specks.
vec3 sample_base(vec2 p) {
	if (scene_scale.x >= 0.95) return texelFetch(base_tex, ivec2(clamp(p, vec2(0.0), base_size - 1.0)), 0).rgb;
	vec2 cell = floor(p * scene_scale);
	ivec2 t0 = ivec2(floor(cell / scene_scale));
	ivec2 t1 = max(ivec2(floor((cell + 1.0) / scene_scale)), t0 + 1);
	vec3 sum = vec3(0.0);
	float n = 0.0;
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 4; i++) {
			ivec2 t = t0 + ivec2(i, j);
			if (t.x >= t1.x || t.y >= t1.y) continue;
			sum += texelFetch(base_tex, clamp(t, ivec2(0), ivec2(base_size) - 1), 0).rgb;
			n += 1.0;
		}
	}
	return sum / max(n, 1.0);
}

void fragment() {
	vec2 p = (screen_pos - scene_origin) / scene_scale;
	if (p.y < 0.0 || p.x < 0.0 || p.x >= base_size.x) {
		COLOR = vec4(sky_at(p), 1.0);
	} else {
		ivec2 ip = ivec2(floor(p));
		vec4 m = texelFetch(mask_tex, ip, 0);
		if (m.r > 0.5) {
			COLOR = vec4(sky_at(p), 1.0);
		} else {
			vec2 sp = floor(p) + 0.5;
			// Tree crowns wobble by whole pixels in the wind.
			if (m.a > 0.5) sp.x += floor(sin(time * 1.1 + floor(p.x / 6.0) * 0.9 + p.y * 0.05) * (0.6 + wind * 0.04) + 0.5);
			vec3 base = sample_base(sp);
			if (texelFetch(mask_tex, ivec2(sp), 0).r > 0.5) base = sample_base(floor(p) + 0.5);
			// Glass reflects the live sky by day. The class map marks whole office
			// window blocks, so the tint covers a window evenly (never one pixel);
			// capped at 0.12 so pale glass next to the sky cannot flare white.
			float cls = texelFetch(win_tex, ip, 0).r * 255.0;
			if (cls > 20.0 && cls < 60.0) base = mix(base, mix(horizon, zenith, 0.4), 0.12 * day);
			// Aerial perspective: distant towers fade into the current horizon colour.
			base = mix(base, horizon, m.b * mix(0.25, 0.55, day));
			// Weather on the city: rain and fog wash it out, deeper with distance;
			// colours go grey and dull, and low cloud cuts off the tower tops.
			vec2 cell = floor(p);
			float wet = clamp(rain * 0.9 + overcast * 0.25, 0.0, 1.0);
			float luma = dot(base, vec3(0.299, 0.587, 0.114));
			base = mix(base, vec3(luma), 0.5 * max(wet, fog) + 0.25 * snow);
			base *= 1.0 - 0.12 * wet;
			float mist = (wet * 0.42 + fog * 0.8 + snow * 0.35) * (0.3 + 0.7 * m.b);
			vec3 mist_col = mix(horizon, vec3(0.62, 0.66, 0.68) * mix(0.25, 1.0, day), fog * 0.6);
			base = mix(base, mist_col, stepped(clamp(mist, 0.0, 0.92), 6.0, cell));
			if (p.y < horizon_y) base = mix(base, mix(cloud_shade, cloud_lit, 0.35), deck_at(cell) * 0.9);
			// Snow settles on every roof edge and on the trees.
			if (snow > 0.01 && p.y < 446.0) {
				float above = texelFetch(mask_tex, ip - ivec2(0, 1), 0).r + texelFetch(mask_tex, ip - ivec2(0, 2), 0).r;
				if (above > 0.5 && m.a < 0.5) base = mix(base, vec3(0.93, 0.95, 0.97) * mix(0.35, 1.0, day), snow * 0.9);
				if (m.a > 0.5) base = mix(base, vec3(0.88, 0.9, 0.92) * mix(0.35, 1.0, day), snow * 0.45 * step(0.45, hash(cell)));
			}
			if (m.g > 0.5) {
				// Bay: mirrored sky in pixel rows, sliding ripple highlights, glitter path.
				float row = cell.y - horizon_y;
				float wobble = floor(sin(cell.y * 1.7 + time * 1.3) * 1.5 + 0.5);
				vec3 mirror = sky_at(vec2(cell.x + wobble, horizon_y - 4.0 - row * 3.0));
				base = mix(base, mirror * 0.82, 0.55 * (1.0 - 0.4 * fog));
				base = mix(base, vec3(0.45, 0.5, 0.52) * mix(0.3, 1.0, day), 0.35 * max(rain, fog));
				float lane = floor((cell.x + time * (6.0 + mod(cell.y, 3.0) * 3.0) * (mod(cell.y, 2.0) * 2.0 - 1.0)) / 7.0);
				float crest = step(0.86, hash(vec2(lane, cell.y)));
				float glint = exp(-abs(cell.x - sun_pos.x) / 36.0) * sun_visible + exp(-abs(cell.x - moon_pos.x) / 16.0) * moon_visible * 0.7;
				base = mix(base, mirror * 1.15 + vec3(0.06), crest * 0.5);
				base += vec3(1.0, 0.92, 0.75) * crest * step(0.25, glint) * 0.6;
			}
			COLOR = vec4(base, 1.0);
		}
	}
}
