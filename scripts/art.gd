extends RefCounted

# Rendering helpers shared by the scene painters.
#
# Most sprites are high-resolution generated artwork drawn 3–23× smaller than
# their source. Nearest sampling picks one arbitrary texel per screen pixel, so
# outlines break up and moving vehicles/people shimmer every frame. Wrapping them
# in a CanvasTexture with trilinear filtering (their imports generate mipmaps)
# averages the source properly while the rest of the canvas keeps its filter.

static var _cache := {}

static func smooth(texture: Texture2D, mipmaps := true) -> Texture2D:
	var key := texture.get_instance_id() * 2 + int(mipmaps)
	if _cache.has(key): return _cache[key]
	var wrapped := CanvasTexture.new()
	wrapped.diffuse_texture = texture
	wrapped.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if mipmaps else CanvasItem.TEXTURE_FILTER_LINEAR
	_cache[key] = wrapped
	return wrapped

static func flipped(texture: Texture2D) -> Texture2D:
	var image := texture.get_image()
	if image.is_compressed(): image.decompress()
	image.flip_x()
	image.generate_mipmaps()
	return smooth(ImageTexture.create_from_image(image))

# Soft radial falloff used for lamps, the sun and other light sources. One
# texture replaces stacked flat circles, which produced visible rings.
static func glow() -> Texture2D:
	if _cache.has("glow"): return _cache["glow"]
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.42, 0.7, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.62), Color(1, 1, 1, 0.24), Color(1, 1, 1, 0.06), Color(1, 1, 1, 0)])
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	_cache["glow"] = smooth(texture, false)
	return _cache["glow"]

static func vertical_gradient(top: Color, bottom: Color) -> Texture2D:
	var key := "v%s%s" % [top.to_html(), bottom.to_html()]
	if _cache.has(key): return _cache[key]
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([top, bottom])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = 256
	_cache[key] = smooth(texture, false)
	return _cache[key]

static func draw_glow(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	if color.a <= 0.001 or radius <= 0.0: return
	canvas.draw_texture_rect(glow(), Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)

# Concentric discs baked once into a small mipmapped texture: [radius 0..1,
# colour] from the outside in. Drawing antialiased circles every frame cost
# ~45 µs each (wheels, roundels); a textured quad costs almost nothing and
# looks the same at these sizes.
static func rings(key: String, layers: Array, size := 48) -> Texture2D:
	if _cache.has("rings" + key): return _cache["rings" + key]
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in range(size):
		for x in range(size):
			var d := Vector2(x - c, y - c).length() / (size / 2.0)
			var out := Color(0, 0, 0, 0)
			for layer in layers:
				var r: float = layer[0]
				var col: Color = layer[1]
				var cover := clampf((r - d) * size / 2.0 + 0.5, 0.0, 1.0)
				if cover <= 0.0: continue
				out = out.blend(Color(col, col.a * cover)) if out.a > 0.0 else Color(col, col.a * cover)
			image.set_pixel(x, y, out)
	image.generate_mipmaps()
	_cache["rings" + key] = smooth(ImageTexture.create_from_image(image))
	return _cache["rings" + key]

static func draw_rings(canvas: CanvasItem, key: String, layers: Array, center: Vector2, radius: float, modulate := Color.WHITE) -> void:
	canvas.draw_texture_rect(rings(key, layers), Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, modulate)

# Vehicles: the source paintings are 4–5× larger than they appear on screen.
# Resampling them every frame (even with mipmaps) lets thin window frames,
# lettering and edges land on different screen pixels from one frame to the
# next — the bus "flicker". Instead the sprite is downscaled ONCE, with a
# Lanczos filter, to the exact number of screen pixels it covers, and then
# drawn 1:1 at whole screen pixels: every frame is the identical image moved
# by an integer offset, so nothing can shimmer.
static var _baked_keys: Array = []

static func baked(texture: Texture2D, source: Rect2, px: Vector2i) -> Texture2D:
	var base: Texture2D = texture
	if base is CanvasTexture: base = (base as CanvasTexture).diffuse_texture
	var key := "bake%d|%d,%d,%d,%d|%d,%d" % [base.get_instance_id(), int(source.position.x), int(source.position.y), int(source.size.x), int(source.size.y), px.x, px.y]
	if _cache.has(key): return _cache[key]
	var image := base.get_image()
	if image.is_compressed(): image.decompress()
	image.clear_mipmaps()
	if image.get_format() != Image.FORMAT_RGBA8: image.convert(Image.FORMAT_RGBA8)
	var bounds := Rect2i(Vector2i.ZERO, image.get_size())
	var region := image.get_region(Rect2i(source).intersection(bounds))
	# Transparent padding keeps neighbouring colours, so edges do not fringe.
	region.fix_alpha_edges()
	region.resize(maxi(1, px.x), maxi(1, px.y), Image.INTERPOLATE_LANCZOS)
	var result := ImageTexture.create_from_image(region)
	_cache[key] = result
	_baked_keys.append(key)
	# Window resizes create new sizes; keep the cache bounded.
	while _baked_keys.size() > 160: _cache.erase(_baked_keys.pop_front())
	return result
