shader_type canvas_item;

// Unified pixel grid for the whole scene.
//
// The city is drawn at screen resolution, then every screen pixel is replaced by
// the average of the art-pixel cell it belongs to. Background, sprites, vector
// details, text and weather therefore share one grid. On non-integer scales a
// screen pixel that straddles two cells is blended by coverage ("sharp
// bilinear"), so the blocks look even instead of alternating 2 and 3 px wide.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform vec2 origin = vec2(0.0);   // screen position of the scene's (0, 0)
uniform float cell = 3.0;          // screen pixels per art pixel

vec3 cell_colour(vec2 c, vec2 pixel) {
	// Small cells: one bilinear tap at the centre already averages ~2x2 pixels,
	// about the whole cell. Larger cells take four taps (~4x4 box).
	if (cell < 4.0) {
		return texture(screen_tex, (origin + (c + 0.5) * cell) * pixel).rgb;
	}
	vec3 sum = vec3(0.0);
	for (int i = 0; i < 2; i++) {
		for (int j = 0; j < 2; j++) {
			vec2 q = origin + (c + (vec2(float(i), float(j)) + 0.5) * 0.5) * cell;
			sum += texture(screen_tex, q * pixel).rgb;
		}
	}
	return sum * 0.25;
}

void fragment() {
	vec2 pixel = SCREEN_PIXEL_SIZE;
	vec2 p = SCREEN_UV / pixel;
	vec2 g = (p - origin) / cell;
	vec2 c = floor(g);
	vec2 f = g - c;
	// Width of one screen pixel in cell units: the band where it overlaps the next cell.
	float w = 1.0 / cell;
	vec2 t = clamp((f - (1.0 - w)) / w, 0.0, 1.0);
	vec3 colour = cell_colour(c, pixel);
	if (t.x > 0.0 || t.y > 0.0) {
		vec3 right = cell_colour(c + vec2(1.0, 0.0), pixel);
		vec3 down = cell_colour(c + vec2(0.0, 1.0), pixel);
		vec3 diagonal = cell_colour(c + vec2(1.0, 1.0), pixel);
		colour = mix(mix(colour, right, t.x), mix(down, diagonal, t.x), t.y);
	}
	COLOR = vec4(colour, 1.0);
}
