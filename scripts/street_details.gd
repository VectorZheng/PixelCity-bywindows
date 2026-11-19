extends RefCounted

const FLOWERS: Texture2D = preload("res://assets/shenzhen-bougainvillea.png")

static func draw_far_side(canvas: Node2D, font: Font, seconds: float) -> void:
	_road_name(canvas, font, Vector2(789, 411), "红荔路", "HONGLI RD")
	_road_name(canvas, font, Vector2(1324, 411), "华强北路", "HUAQIANGBEI RD")
	for x in [942, 1460]:
		_planter(canvas, Rect2(x, 442, 65, 22), seconds)

static func draw_road_barrier(canvas: Node2D, width: float) -> void:
	# Straight structural rails, with small highlights rather than wavy baked
	# edges. They stay behind vehicles and never mask the adjoining sidewalk.
	canvas.draw_line(Vector2(0, 488), Vector2(width, 488), Color("78848c"), 1.5)
	canvas.draw_line(Vector2(0, 504), Vector2(width, 504), Color("4d5867"), 1.5)
	for x in range(0, int(width), 18):
		canvas.draw_line(Vector2(x, 489), Vector2(x, 503), Color("637382"), 1.0)
		canvas.draw_line(Vector2(x + 1, 489), Vector2(x + 1, 503), Color(0.75, 0.73, 0.70, 0.35), 0.5)

static func draw_near_side(canvas: Node2D, font: Font, shift: float, seconds: float) -> void:
	for x in [52.0 + shift, 2120.0 - shift]:
		canvas.draw_rect(Rect2(x - 1, 518, 3, 38), Color("9caaa8"))
		canvas.draw_rect(Rect2(x - 10, 506, 22, 19), Color("e2e9df"))
		canvas.draw_rect(Rect2(x - 9, 507, 20, 17), Color("187e58"))
		canvas.draw_string(font, Vector2(x - 7, 517), "地铁", HORIZONTAL_ALIGNMENT_LEFT, 18, 8, Color("f5f8eb"))
		canvas.draw_string(font, Vector2(x - 7, 523), "METRO", HORIZONTAL_ALIGNMENT_LEFT, 18, 4, Color("f5f8eb"))
		canvas.draw_rect(Rect2(x - 4, 554, 9, 2), Color("667a79"))
	for x in [945, 1187]:
		_planter(canvas, Rect2(x, 540, 40, 18), seconds)

static func _road_name(canvas: Node2D, font: Font, position: Vector2, chinese: String, english: String) -> void:
	canvas.draw_rect(Rect2(position.x + 47, position.y + 20, 2, 33), Color("849899"))
	canvas.draw_rect(Rect2(position.x + 43, 463, 10, 2), Color("536974"))
	canvas.draw_rect(Rect2(position, Vector2(98, 27)), Color("b4c7c8"))
	canvas.draw_rect(Rect2(position + Vector2(1, 1), Vector2(96, 25)), Color("23618c"))
	canvas.draw_string(font, position + Vector2(7, 13), chinese, HORIZONTAL_ALIGNMENT_LEFT, 87, 11, Color("f3f5ed"))
	canvas.draw_string(font, position + Vector2(7, 22), english, HORIZONTAL_ALIGNMENT_LEFT, 87, 7, Color("e2edf0"))

static func _planter(canvas: Node2D, target: Rect2, seconds: float) -> void:
	# Pivot foliage very slightly in the wind; keep its stone planter grounded.
	var image_size := FLOWERS.get_size()
	var top_height := target.size.y * 0.70
	var source_top := image_size.y * 0.70
	var sway := sin(seconds * 0.8 + target.position.x) * 0.35
	canvas.draw_texture_rect_region(FLOWERS, Rect2(target.position + Vector2(sway, 0), Vector2(target.size.x, top_height)), Rect2(0, 0, image_size.x, source_top))
	canvas.draw_texture_rect_region(FLOWERS, Rect2(target.position.x, target.position.y + top_height, target.size.x, target.size.y - top_height), Rect2(0, source_top, image_size.x, image_size.y - source_top))
