extends RefCounted

const FLOWERS: Texture2D = preload("res://assets/shenzhen-bougainvillea.png")
const Art = preload("res://scripts/art.gd")

static func draw_far_side(canvas: Node2D, _font: Font, seconds: float) -> void:
	# The two road-name signs were removed; the café now stands at x 772–934.
	for x in [946, 1620]:
		_planter(canvas, Rect2(x, 456, 65, 22), seconds)

const BARRIER_TOP := 493
const BARRIER_HEIGHT := 18
static var _barrier: Texture2D

# Shenzhen-style central guard fence: light steel top and bottom rails, slim
# balusters every 3 px (the gaps let the far lane show through) and a main
# post with an amber reflector every 24 px, on a low concrete median kerb.
# Baked once into a texture; city.gd draws it between the far and near lanes,
# so far-lane vehicles disappear behind it from the wheels down.
static func _bake_barrier(width: int) -> Texture2D:
	var image := Image.create(width, BARRIER_HEIGHT, false, Image.FORMAT_RGBA8)
	var rail := Color("dfe4e4")
	var rail_shadow := Color("7f8b90")
	var baluster := Color("c3cacc")
	var baluster_shade := Color("8d989c")
	var post := Color("eef1f0")
	var kerb := Color("8f9391")
	for x in range(width):
		# Concrete median kerb (scene y 507..510).
		for y in range(14, 18): image.set_pixel(x, y, kerb if y > 14 else Color("b5b8b4"))
		# Rails: top y 494..495, bottom y 505.
		image.set_pixel(x, 1, rail)
		image.set_pixel(x, 2, rail_shadow)
		image.set_pixel(x, 12, Color("aab3b6"))
		image.set_pixel(x, 13, rail_shadow)
		if x % 3 == 0:
			for y in range(3, 12): image.set_pixel(x, y, baluster if x % 6 == 0 else baluster_shade)
		if x % 24 == 0 or x % 24 == 1:
			for y in range(0, 14): image.set_pixel(x, y, post if x % 24 == 0 else rail_shadow)
		if x % 48 == 0:
			image.set_pixel(x, 5, Color("f2b233"))
			image.set_pixel(x, 6, Color("f2b233"))
	var texture := ImageTexture.create_from_image(image)
	return texture

static func draw_road_barrier(canvas: Node2D, width: float) -> void:
	if _barrier == null or _barrier.get_width() != int(width): _barrier = _bake_barrier(int(width))
	canvas.draw_texture(_barrier, Vector2(0, BARRIER_TOP))

static func draw_near_side(canvas: Node2D, font: Font, shift: float, seconds: float) -> void:
	for x in [52.0 + shift]:
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
	canvas.draw_rect(Rect2(position.x + 43, 477, 10, 2), Color("536974"))
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
	canvas.draw_texture_rect_region(Art.smooth(FLOWERS), Rect2(target.position + Vector2(sway, 0), Vector2(target.size.x, top_height)), Rect2(0, 0, image_size.x, source_top))
	canvas.draw_texture_rect_region(Art.smooth(FLOWERS), Rect2(target.position.x, target.position.y + top_height, target.size.x, target.size.y - top_height), Rect2(0, source_top, image_size.x, image_size.y - source_top))
