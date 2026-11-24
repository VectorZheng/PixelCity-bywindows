extends RefCounted

# Architecture and live objects share scene coordinates. The generated image is
# only used below the street; its sky and roads never replace the approved city.
const ART: Texture2D = preload("res://assets/huaxin-platform.png")
const ESCALATOR: Texture2D = preload("res://assets/metro-escalator.png")
const Art = preload("res://scripts/art.gd")
const Transit = preload("res://scripts/transit.gd")
const StationRoutes = preload("res://scripts/station_routes.gd")
const MetroLine = preload("res://scripts/metro_line.gd")
const TOP := 564.0
const GLASS_TOP := 624.0
const THRESHOLD := 694.0
const WALK_Y := StationRoutes.PLATFORM_Y
const BOARD_Y := 687.0
const TRAIN_Y := 638.0
const PANE_SOURCE := Rect2(656, 629, 71, 57)
const POST_SOURCE := Rect2(640, 625, 3, 67)
# Three identical columns, each centred in the gap between two platform doors
# and cut from the same strip of the authored floral pillar (no rescaling).
const PILLAR_SOURCE := Rect2(440, 564, 24, 150)
const PILLAR_CENTERS := [431.8, 1082.6, 1677.6]
const PILLARS := [Rect2(419.8, 564, 24, 150), Rect2(1070.6, 564, 24, 150), Rect2(1665.6, 564, 24, 150)]

static func door_centers(width: float) -> Array[float]:
	var active := Transit.platform_door_centers()
	var centers: Array[float] = []
	var count := ceili(width / 50.0)
	for i in range(count, 0, -1): centers.append(active[0] - i * 50.0)
	centers.append_array(active)
	for i in range(1, count + 1): centers.append(active[-1] + i * 50.0)
	return centers

static func draw_interior(canvas: Node2D, width: float) -> void:
	var ceiling := Rect2(0, TOP, width, GLASS_TOP - TOP)
	canvas.draw_texture_rect_region(ART, ceiling, ceiling)
	# Reuse the authored tunnel material, without the baked door mullions. Live
	# door positions below correspond to the actual train, including its end cars.
	for x in range(0, ceili(width), 71):
		var tile_width := minf(71.0, width - x)
		canvas.draw_texture_rect_region(ART, Rect2(x, GLASS_TOP, tile_width, THRESHOLD - GLASS_TOP), Rect2(PANE_SOURCE.position, Vector2(tile_width, PANE_SOURCE.size.y)), Color(0.63, 0.69, 0.72))
	var floor_area := Rect2(0, THRESHOLD, width, 724.0 - THRESHOLD)
	canvas.draw_texture_rect_region(ART, floor_area, floor_area)
	# The authored art paints two wide pillars of different widths into the
	# ceiling and floor bands; cover them with the plain strip right beside.
	_cover_old_pillars(canvas, TOP, GLASS_TOP - TOP)
	_cover_old_pillars(canvas, THRESHOLD, 724.0 - THRESHOLD)
	canvas.draw_line(Vector2(0, 691), Vector2(width, 691), Color("52616a"), 1.0)
	canvas.draw_line(Vector2(0, 693), Vector2(width, 693), Color("b4bcba"), 1.0)

static func _cover_old_pillars(canvas: Node2D, y: float, h: float) -> void:
	for span in [Vector2(418, 68), Vector2(1664, 69)]:
		canvas.draw_texture_rect_region(ART, Rect2(span.x, y, span.y, h), Rect2(span.x + span.y + 2.0, y, span.y, h))

static func draw_glass(canvas: Node2D, width: float, seconds: float, font: Font = null) -> void:
	var centers := door_centers(width)
	var active := Transit.platform_door_centers()
	var opening := Transit.train_doors_now(seconds)
	for i in range(centers.size() - 1):
		var center := centers[i]
		if center < -50.0 or center > width + 50.0: continue
		var is_active := center >= active[0] and center <= active[-1]
		var gap := 5.0 * opening if is_active else 0.0
		# Fixed glass and the two sliding leaves have textured reflections. The
		# opening itself is left clear; the train's doorway remains visible there.
		_glass_pane(canvas, Rect2(center - 9, GLASS_TOP + 2, 9 - gap, 66), width)
		_glass_pane(canvas, Rect2(center + gap, GLASS_TOP + 2, 9 - gap, 66), width)
		_glass_pane(canvas, Rect2(center + 9, GLASS_TOP + 2, centers[i + 1] - center - 18, 66), width)
		for x in [center - 9, center + 9, center - gap, center + gap]:
			if x < 0 or x >= width: continue
			canvas.draw_texture_rect_region(ART, Rect2(x - 0.5, GLASS_TOP + 1, 1, 68), POST_SOURCE)
		for side in [-1.0, 1.0]:
			var sticker_x: float = center + side * (3.0 + gap)
			if sticker_x < 0 or sticker_x + 3 >= width: continue
			canvas.draw_texture_rect_region(ART, Rect2(sticker_x, 658, 3, 3), Rect2(569, 652, 14, 11))
		if center >= 0 and center <= width:
			var warning := is_active and opening > 0.0 and opening < 1.0
			var lamp := Color("e4b35c") if warning and fposmod(seconds, 0.6) < 0.3 else Color("708f72")
			canvas.draw_rect(Rect2(center - 1.5, 626, 3, 1.5), lamp)
	canvas.draw_texture_rect_region(ART, Rect2(0, 621, width, 4), Rect2(0, 621, width, 4))
	_cover_old_pillars(canvas, 621, 4)
	if font: draw_header(canvas, width, seconds, font)
	# The front edge of the platform covers the bogies, and provides a tactile
	# boarding strip. Passengers are drawn later, standing on this floor.
	var edge := Rect2(0, THRESHOLD, width, 8)
	canvas.draw_texture_rect_region(ART, edge, edge)
	_cover_old_pillars(canvas, THRESHOLD, 8)
	for pillar in PILLARS:
		canvas.draw_texture_rect_region(ART, pillar, PILLAR_SOURCE)

static func _glass_pane(canvas: Node2D, pane: Rect2, width: float) -> void:
	var clipped := pane.intersection(Rect2(0, GLASS_TOP, width, THRESHOLD - GLASS_TOP))
	if not clipped.has_area(): return
	canvas.draw_texture_rect_region(ART, clipped, PANE_SOURCE, Color(0.91, 0.97, 1.0, 0.20))
	canvas.draw_line(Vector2(clipped.position.x, 676), Vector2(clipped.end.x, 676), Color(0.63, 0.76, 0.78, 0.24), 1)

static func escalator_points(right: bool, shift: float) -> PackedVector2Array:
	var points := PackedVector2Array([
		Vector2(132, 556), Vector2(199, 556), Vector2(473, WALK_Y), Vector2(410, WALK_Y)])
	for i in range(points.size()):
		points[i].x = 2172.0 - points[i].x - shift if right else points[i].x + shift
	return points

static func _escalator_vertex(source: Vector2, right: bool, shift: float) -> Vector2:
	# Preserve metal thickness while adapting the authored ramp to the real
	# route. Shear only its slope, keeping both end landings horizontal.
	const SCALE := 270.0 / 1855.0
	var ramp := clampf((source.x - 185.0) / 1855.0, 0, 1)
	var extra_rise := 156.0 - 524.0 * SCALE
	var x := 165.0 + (source.x - 185.0) * SCALE
	var y := StationRoutes.STREET_Y + (source.y - 149.0) * SCALE + extra_rise * ramp
	return Vector2(2172.0 - x - shift if right else x + shift, y)

static func draw_escalator(canvas: Node2D, _right: bool, shift: float, seconds: float, upward: bool = false) -> void:
	# Only the brushed-metal body comes from the raster asset. Glass edges,
	# posts and handrails are exact geometry, with round returns only at ends.
	# The up escalator sits just behind the down one and is drawn first.
	var offset: Vector2 = StationRoutes.UP_OFFSET if upward else Vector2.ZERO
	var tint := Color(0.8, 0.84, 0.86) if upward else Color.WHITE
	var size := ESCALATOR.get_size()
	var sections := [
		PackedVector2Array([Vector2(0, 100), Vector2(185, 100), Vector2(185, 215), Vector2(0, 215)]),
		PackedVector2Array([Vector2(185, 149), Vector2(2040, 673), Vector2(2040, 724), Vector2(185, 215)]),
		PackedVector2Array([Vector2(2040, 630), Vector2(size.x, 630), Vector2(size.x, 724), Vector2(2040, 724)])]
	for source in sections:
		var vertices := PackedVector2Array()
		var uv := PackedVector2Array()
		for point in source:
			vertices.append(_escalator_vertex(point, false, shift) + offset)
			uv.append(point / size)
		canvas.draw_polygon(vertices, PackedColorArray([tint]), uv, Art.smooth(ESCALATOR))
	var upper := StationRoutes.escalator_position(1.0 if upward else 0.0, not upward, shift)
	var lower := StationRoutes.escalator_position(0.0 if upward else 1.0, not upward, shift)
	var panel := PackedVector2Array([upper + Vector2(0, -20), lower + Vector2(0, -20), lower, upper])
	var a := 0.55 if upward else 0.78
	canvas.draw_polygon(panel, PackedColorArray([Color(0.78, 0.90, 0.89, a), Color(0.78, 0.90, 0.89, a), Color(0.37, 0.59, 0.62, a - 0.08), Color(0.37, 0.59, 0.62, a - 0.08)]))
	for t in [0.15, 0.30, 0.45, 0.60, 0.75, 0.90]:
		var post := upper.lerp(lower, t)
		canvas.draw_line(post + Vector2(0, -19), post, Color("829c9f"), 1.2)
		canvas.draw_line(post + Vector2(0.8, -19), post + Vector2(0.8, 0), Color("c2cfcb"), 0.5)
	for end in [upper, lower]:
		var center: Vector2 = end + Vector2(0, -10)
		var left_return: bool = end == upper
		var start := PI / 2.0 if left_return else -PI / 2.0
		var points := PackedVector2Array([center])
		for i in range(17):
			var angle := start + PI * i / 16.0
			points.append(center + Vector2(cos(angle), sin(angle)) * 10.0)
		canvas.draw_colored_polygon(points, Color(0.64, 0.81, 0.82, a))
		canvas.draw_arc(center, 10, start, start + PI, 17, Color("283c43"), 2.3)
		canvas.draw_arc(center, 8.5, start, start + PI, 17, Color("b7c6c4"), 0.8)
	canvas.draw_line(upper + Vector2(0, -20), lower + Vector2(0, -20), Color("283c43"), 2.3)
	canvas.draw_line(upper + Vector2(0, -21), lower + Vector2(0, -21), Color("b7c6c4"), 0.8)
	canvas.draw_line(upper, lower, Color("6f878d"), 1.3)
	canvas.draw_line(upper + Vector2(0, 8), lower + Vector2(0, 8), Color("5b6b73"), 0.8)
	# Treads and riders use one duration and route, with no sliding feet.
	for i in range(27):
		var t := fposmod(float(i) / 27.0 + seconds / StationRoutes.RIDE_SECONDS, 1.0)
		var point := StationRoutes.escalator_position(t, not upward, shift)
		canvas.draw_line(point + Vector2(-3, -1), point + Vector2(3, -1), Color("c9cbba"), 1.0)

# Shenzhen Metro line 3 sky blue, and the blue-on-white platform door cover
# (屏蔽门盖板) used on lines 1-4: station name, line and direction above the doors.
const LINE_BLUE := Color("00a2e2")
const COVER_BLUE := Color("1a5aa6")

static func draw_header(canvas: Node2D, width: float, seconds: float, font: Font) -> void:
	var top := 610.0
	var height := 11.0
	canvas.draw_rect(Rect2(0, top - 1, width, 1), Color("c9d1d4"))
	canvas.draw_rect(Rect2(0, top, width, height), COVER_BLUE)
	canvas.draw_rect(Rect2(0, top + height, width, 1), Color("8a979c"))
	var centers := door_centers(width)
	var active := Transit.platform_door_centers()
	var opening := Transit.train_doors_now(seconds)
	for i in range(centers.size()):
		var center: float = centers[i]
		if center < -40.0 or center > width + 40.0: continue
		var is_active := center >= active[0] - 1.0 and center <= active[-1] + 1.0
		# Door plate: line roundel and door number, lit green while the door is open.
		var lit := is_active and opening > 0.05
		canvas.draw_rect(Rect2(center - 9, top + 1.5, 18, 8), Color("0e3f7a") if not lit else Color("1f7a52"))
		Art.draw_rings(canvas, MetroLine.ring_key(), [[1.0, MetroLine.colour()]], Vector2(center - 5, top + 5.5), 3.0)
		canvas.draw_string(font, Vector2(center - 6.6, top + 7.6), MetroLine.number(), HORIZONTAL_ALIGNMENT_LEFT, 6, 5, Color.WHITE)
		canvas.draw_string(font, Vector2(center - 1.2, top + 7.6), "%02d" % (i % 24 + 1), HORIZONTAL_ALIGNMENT_LEFT, 10, 5, Color("e8f1f6"))
		# Between doors the cover alternates station name and line direction.
		if i + 1 < centers.size():
			var mid := (center + centers[i + 1]) / 2.0
			var label: String = ["%s %s" % [MetroLine.station(), MetroLine.station_en()], "%s %s" % [MetroLine.line(), MetroLine.line_en()], "往 %s" % MetroLine.toward()][i % 3]
			canvas.draw_string(font, Vector2(mid - 14.5, top + 7.8), label, HORIZONTAL_ALIGNMENT_CENTER, 29, 4.5, Color("f4f7f8"))
