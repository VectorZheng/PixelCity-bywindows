shader_type canvas_item;
render_mode unshaded, blend_mul;

// Daylight on the ground: multiplies everything already drawn on the surface
// (buildings, road, vehicles, people) by the ambient light colour. The live sky
// is excluded via the sky mask, and the underground platform keeps its own light.

uniform sampler2D mask_tex : filter_nearest, repeat_disable;
uniform vec2 scene_origin;
uniform vec2 scene_scale;
uniform vec2 base_size = vec2(2172.0, 724.0);
uniform vec3 ambient : source_color = vec3(1.0);
uniform float surface_y = 564.0;
// 1 while Huaxin station is in service; 0 after closing, when only the dim
// green-grey emergency lighting is left underground.
uniform float station_light = 1.0;

varying vec2 screen_pos;

void vertex() {
	screen_pos = VERTEX;
}

void fragment() {
	vec2 p = (screen_pos - scene_origin) / scene_scale;
	float sky = 1.0;
	if (p.y >= 0.0 && p.x >= 0.0 && p.x < base_size.x) sky = texture(mask_tex, p / base_size).r;
	vec3 light = mix(ambient, vec3(1.0), sky);
	// Below the street the station is electrically lit while it is open.
	vec3 station = mix(vec3(0.11, 0.14, 0.14), vec3(1.0), station_light);
	light = mix(light, station, smoothstep(surface_y - 0.5, surface_y + 0.5, p.y));
	COLOR = vec4(light, 1.0);
}
