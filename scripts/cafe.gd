extends RefCounted

# 街角书房 · 书店兼咖啡馆，在对面海边步道、远侧公交站右边。
#
# 现代风格的小店：平屋顶、深灰门头、木格栅侧墙、整面落地玻璃；里面是
# 书架墙、吊灯和咖啡吧台；门口两把遮阳伞配小圆桌和小椅子，门边立一个
# 小灯牌。店长是 9 号居民罗安然（资料：咖啡店店长 · 海边的咖啡店）：
# 每天 08:00 开门、22:00 打烊时，她从店里走出来把灯牌翻成「营业中」/
# 「打烊中」，再走回店里；打烊后店内熄灯、遮阳伞收起。
#
# 全部是场景坐标（与 tools/gen_city.py 相同：远侧人行道 y 446–478）。

const X0 := 772.0           # building left edge
const X1 := 934.0           # building right edge
const TOP := 400.0          # roof top: a little higher than the bus shelter (417)
const FLOOR := 463.0        # shop floor / front step
const GLASS_X := 800.0      # storefront glass starts after the timber wall
const DOOR_X := 888.0       # glass door 888..904
const SIGN_X := 913.0       # A-frame light sign on the pavement
const UMBRELLAS := [793.0, 847.0]
const OWNER_ID := 9         # resident 罗安然, 咖啡店店长
const OPEN_HOUR := 8.0
const CLOSE_HOUR := 22.0
const SIGN_OFF_HOUR := 23.5 # the 打烊中 lightbox is switched off late at night

# Owner timeline (seconds after opening/closing time).
const WALK_OUT := 3.0
const FLIP_END := 9.0
const WALK_BACK := 12.0
const DONE := 13.0
const LIGHTS_OFF_DELAY := 20.0

static func is_open(clock: float) -> bool:
	var h := fposmod(clock, 86400.0) / 3600.0
	return h >= OPEN_HOUR and h < CLOSE_HOUR

# The sign reads 营业中 from the opening flip until the closing flip.
static func sign_open(clock: float) -> bool:
	var day := fposmod(clock, 86400.0)
	var opened := OPEN_HOUR * 3600.0 + (WALK_OUT + FLIP_END) / 2.0
	var closed := CLOSE_HOUR * 3600.0 + (WALK_OUT + FLIP_END) / 2.0
	return day >= opened and day < closed

static func lights_on(clock: float) -> bool:
	var day := fposmod(clock, 86400.0)
	return day >= OPEN_HOUR * 3600.0 - 900.0 and day < CLOSE_HOUR * 3600.0 + LIGHTS_OFF_DELAY

static func sign_lit(clock: float) -> bool:
	var h := fposmod(clock, 86400.0) / 3600.0
	return h >= OPEN_HOUR - 0.5 and h < SIGN_OFF_HOUR

# Seconds into the current flip event (opening or closing), or -1.
static func _event_t(clock: float) -> float:
	var day := fposmod(clock, 86400.0)
	for hour: float in [OPEN_HOUR, CLOSE_HOUR]:
		var t: float = day - hour * 3600.0
		if t >= 0.0 and t < DONE: return t
	return -1.0

# Where the owner is while she flips the sign; {} when she is not out.
static func owner_pose(clock: float) -> Dictionary:
	var t := _event_t(clock)
	if t < 0.0: return {}
	var door := DOOR_X + 8.0
	var at_sign := SIGN_X - 5.0
	if t < WALK_OUT:
		return {"x": lerpf(door, at_sign, t / WALK_OUT), "direction": 1, "moving": true, "alpha": clampf(t / 0.8, 0.0, 1.0), "doing": "出门翻灯牌"}
	if t < FLIP_END:
		return {"x": at_sign, "direction": 1, "moving": false, "alpha": 1.0, "doing": "把门口灯牌翻成「%s」" % ("打烊中" if _closing(clock) else "营业中"), "reach": true}
	var back := clampf((t - FLIP_END) / (WALK_BACK - FLIP_END), 0.0, 1.0)
	return {"x": lerpf(at_sign, door, back), "direction": -1, "moving": back < 1.0, "alpha": clampf((DONE - t) / 1.0, 0.0, 1.0), "doing": "回店里" + ("收拾打烊" if _closing(clock) else "准备开门")}

static func _closing(clock: float) -> bool:
	return fposmod(clock, 86400.0) >= 12.0 * 3600.0

# Width factor of the sign panel while it is being flipped (1 = facing us).
static func _flip_width(clock: float) -> float:
	var t := _event_t(clock)
	if t < WALK_OUT or t >= FLIP_END: return 1.0
	return maxf(0.12, absf(cos(PI * (t - WALK_OUT) / (FLIP_END - WALK_OUT))))

static func _hash(i: int) -> int:
	return (i * 2654435761) & 0xffff

const BOOKS := ["b8483c", "2f5d8a", "d9b64a", "3f7a52", "e8e2d2", "4a6b5a", "c86a3a", "24303a", "9fb7c4", "a33a4a"]

static func draw(canvas: Node2D, font: Font, clock: float, seconds: float) -> void:
	var lit := lights_on(clock)
	var open := is_open(clock)
	# --- building shell -------------------------------------------------
	canvas.draw_rect(Rect2(X0 - 2, TOP, X1 - X0 + 4, 5), Color("cfcbc2"))              # roof slab
	canvas.draw_rect(Rect2(X0 - 2, TOP + 5, X1 - X0 + 4, 1), Color("7c7a74"))
	for x in range(int(X0 + 4), int(X1 - 4), 3):                                    # rooftop planting
		canvas.draw_rect(Rect2(x, TOP - 2 - (x / 3 % 2), 2, 2 + (x / 3 % 2)), Color("4f7f46") if x % 2 else Color("6a9a58"))
	canvas.draw_rect(Rect2(X0, TOP + 6, X1 - X0, 9), Color("25292d"))                  # fascia
	canvas.draw_rect(Rect2(X0, TOP + 14, X1 - X0, 1), Color("3d4247"))
	# Logo: an open book in a warm square, then the name in brass letters.
	canvas.draw_rect(Rect2(GLASS_X + 4, TOP + 7, 7, 7), Color("d9a65a"))
	canvas.draw_rect(Rect2(GLASS_X + 5, TOP + 9, 2, 3), Color("fbf3e2"))
	canvas.draw_rect(Rect2(GLASS_X + 8, TOP + 9, 2, 3), Color("fbf3e2"))
	var brass := Color("f0cf8e") if lit else Color("b39a6c")
	canvas.draw_string(font, Vector2(GLASS_X + 14, TOP + 13.2), "街角书房", HORIZONTAL_ALIGNMENT_LEFT, 40, 7, brass)
	canvas.draw_string(font, Vector2(GLASS_X + 50, TOP + 12.6), "BOOKS · CAFÉ", HORIZONTAL_ALIGNMENT_LEFT, 60, 4.6, Color("d8d4ca"))
	# Timber-slat wall on the left.
	canvas.draw_rect(Rect2(X0, TOP + 15, GLASS_X - X0, FLOOR - TOP - 15), Color("8e623f"))
	for x in range(int(X0), int(GLASS_X), 3):
		canvas.draw_rect(Rect2(x, TOP + 15, 1, FLOOR - TOP - 15), Color("6f4a2f"))
	canvas.draw_rect(Rect2(X0 + 6, TOP + 24, 16, 22), Color("2c3034"))                # small menu board
	canvas.draw_rect(Rect2(X0 + 7, TOP + 25, 14, 20), Color("3a4044"))
	canvas.draw_string(font, Vector2(X0 + 8, TOP + 30), "MENU", HORIZONTAL_ALIGNMENT_LEFT, 14, 3.4, Color("e9e4d8"))
	for i in range(4):
		canvas.draw_rect(Rect2(X0 + 8, TOP + 33 + i * 3, 6 + (i % 2) * 4, 1), Color("bdb7aa"))
	# --- interior seen through the glass ----------------------------------
	var inner := Rect2(GLASS_X, TOP + 15, X1 - GLASS_X, FLOOR - TOP - 16)
	var wall := Color("efe3cc") if lit else Color("3a3d40")
	canvas.draw_rect(inner, wall)
	var dim := 1.0 if lit else 0.35
	# Floor-to-ceiling bookshelf wall (left two thirds).
	for row in range(4):
		var y := TOP + 18.0 + row * 10.0
		canvas.draw_rect(Rect2(GLASS_X + 2, y + 8, 80, 1.5), Color("6b4a30") * Color(dim, dim, dim))
		var x := GLASS_X + 3.0
		var i := row * 31
		while x < GLASS_X + 81.0:
			var w := 1.0 + float(_hash(i) % 2)
			var h := 5.0 + float(_hash(i + 7) % 3)
			var c := Color(BOOKS[_hash(i + 3) % BOOKS.size()])
			canvas.draw_rect(Rect2(x, y + 8 - h, w, h), Color(c.r * dim, c.g * dim, c.b * dim))
			x += w + (1.0 if _hash(i + 11) % 5 == 0 else 0.0)
			i += 1
	# Coffee bar on the right: counter, espresso machine, cups.
	var bar_x := GLASS_X + 86.0
	canvas.draw_rect(Rect2(bar_x, FLOOR - 15, X1 - bar_x - 1, 14), Color("3a3f44") * Color(dim, dim, dim))
	canvas.draw_rect(Rect2(bar_x, FLOOR - 16, X1 - bar_x - 1, 1.5), Color("c9ad80") * Color(dim, dim, dim))
	canvas.draw_rect(Rect2(bar_x + 4, FLOOR - 23, 9, 7), Color("9aa0a4") * Color(dim, dim, dim))
	canvas.draw_rect(Rect2(bar_x + 5, FLOOR - 22, 7, 2), Color("d3d7d9") * Color(dim, dim, dim))
	if lit: canvas.draw_rect(Rect2(bar_x + 11, FLOOR - 21, 1, 1), Color("ff5a3a"))
	for k in range(3):
		canvas.draw_rect(Rect2(bar_x + 18 + k * 3, FLOOR - 18, 2, 2), Color("f4f0e6") * Color(dim, dim, dim))
	# Pendant lamps.
	for px in [GLASS_X + 20.0, GLASS_X + 52.0, bar_x + 14.0]:
		canvas.draw_line(Vector2(px, TOP + 15), Vector2(px, TOP + 20), Color("2a2d30"), 0.6)
		canvas.draw_rect(Rect2(px - 2, TOP + 20, 4, 2), Color("ffd89a") if lit else Color("5a5650"))
	# Glass: a faint sky reflection and slim black mullions.
	canvas.draw_rect(inner, Color(0.78, 0.9, 0.95, 0.16 if lit else 0.24))
	for gx in [GLASS_X, GLASS_X + 30.0, GLASS_X + 60.0, DOOR_X, DOOR_X + 16.0, X1 - 1.0]:
		canvas.draw_rect(Rect2(gx, TOP + 15, 1, FLOOR - TOP - 15), Color("1d2124"))
	canvas.draw_rect(Rect2(GLASS_X, TOP + 15, X1 - GLASS_X, 1), Color("1d2124"))
	# Glass door with a long brass pull.
	canvas.draw_rect(Rect2(DOOR_X + 1, TOP + 18, 15, FLOOR - TOP - 19), Color(0.15, 0.2, 0.22, 0.18))
	canvas.draw_rect(Rect2(DOOR_X + 3, TOP + 34, 1, 14), Color("c9a05a"))
	canvas.draw_rect(Rect2(X0 - 2, FLOOR - 1, X1 - X0 + 4, 3), Color("55595c"))       # plinth / step
	canvas.draw_rect(Rect2(X0 - 2, FLOOR - 1, X1 - X0 + 4, 1), Color("a9a8a2"))
	# --- terrace ------------------------------------------------------------
	for cx in UMBRELLAS:
		_draw_table(canvas, cx, open, seconds)
	for cx in UMBRELLAS:
		_draw_umbrella(canvas, cx, open, seconds)
	_draw_sign(canvas, font, clock)

static func _draw_table(canvas: Node2D, cx: float, open: bool, seconds: float) -> void:
	var metal := Color("2b2e31")
	# Two bistro chairs facing the table.
	for side in [-1.0, 1.0]:
		var sx: float = cx + side * 10.0
		canvas.draw_rect(Rect2(sx - 3, 470, 6, 1.5), Color("9b6d45"))                     # seat
		canvas.draw_rect(Rect2(sx + side * 3.0 - 0.5, 462, 1, 9), metal)                  # back post
		canvas.draw_rect(Rect2(sx + side * 1.0 - (0.0 if side > 0 else 2.0), 462, 3, 1), metal)
		canvas.draw_rect(Rect2(sx - 2.5, 471, 1, 6), metal)
		canvas.draw_rect(Rect2(sx + 1.5, 471, 1, 6), metal)
	# Round table: marble top, single stem, cross foot.
	canvas.draw_rect(Rect2(cx - 6, 466, 12, 1.5), Color("ece8df"))
	canvas.draw_rect(Rect2(cx - 6, 467.5, 12, 0.6), Color("b9b4aa"))
	canvas.draw_rect(Rect2(cx - 0.5, 468, 1, 9), metal)
	canvas.draw_rect(Rect2(cx - 3.5, 476.5, 7, 1), metal)
	if open:
		canvas.draw_rect(Rect2(cx - 4, 464, 2, 2), Color("f6f2ea"))                       # cup
		canvas.draw_rect(Rect2(cx - 3.6, 463.4, 1.2, 0.6), Color(0.95, 0.95, 0.95, 0.35 + 0.25 * sin(seconds * 2.0 + cx)))
		canvas.draw_rect(Rect2(cx + 1, 465, 4, 1), Color("2f5d8a") if int(cx) % 2 else Color("b8483c"))   # a book

static func _draw_umbrella(canvas: Node2D, cx: float, open: bool, seconds: float) -> void:
	var pole := Color("3a3d40")
	canvas.draw_rect(Rect2(cx - 0.5, 437, 1, 30), pole)
	if open:
		# Square market parasol seen from the side: flat top, slight droop and a valance.
		var sway := sin(seconds * 0.9 + cx) * 0.3
		var canopy := PackedVector2Array([Vector2(cx - 3 + sway, 434), Vector2(cx + 3 + sway, 434), Vector2(cx + 18, 441), Vector2(cx - 18, 441)])
		canvas.draw_colored_polygon(canopy, Color("ece4d3"))
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(cx + sway, 434), Vector2(cx + 3 + sway, 434), Vector2(cx + 18, 441), Vector2(cx + 6, 441)]), Color("d5cab4"))
		canvas.draw_rect(Rect2(cx - 18, 441, 36, 2), Color("2f5f57"))                     # teal valance
		for k in range(6):
			canvas.draw_rect(Rect2(cx - 17 + k * 6, 443, 3, 1), Color("2f5f57"))
		canvas.draw_rect(Rect2(cx - 0.5, 432.5, 1, 1.5), pole)
	else:
		# Folded for the night: a slim bundle tied around the pole.
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(cx - 0.5, 433), Vector2(cx + 0.5, 433), Vector2(cx + 2.5, 455), Vector2(cx - 2.5, 455)]), Color("d9d0bd"))
		canvas.draw_rect(Rect2(cx - 2.5, 452, 5, 1), Color("2f5f57"))
	canvas.draw_rect(Rect2(cx - 4, 476, 8, 2), Color("44484c"))                            # weighted base

static func _draw_sign(canvas: Node2D, font: Font, clock: float) -> void:
	var open := sign_open(clock)
	var lit := sign_lit(clock)
	var w := 14.0 * _flip_width(clock)
	var x := SIGN_X + 7.0 - w / 2.0
	# A-frame legs, then the lightbox panel.
	canvas.draw_line(Vector2(SIGN_X + 2, 477), Vector2(SIGN_X + 5, 463), Color("2a2d30"), 1.0)
	canvas.draw_line(Vector2(SIGN_X + 12, 477), Vector2(SIGN_X + 9, 463), Color("2a2d30"), 1.0)
	var bg := Color("1f7a4d") if open else Color("9a2e27")
	if not lit: bg = Color("2e3236")
	canvas.draw_rect(Rect2(x - 0.8, 462.2, w + 1.6, 11.6), Color("1b1d20"))
	canvas.draw_rect(Rect2(x, 463, w, 10), bg)
	if w > 9.0:
		var text_col := Color("f4fbf0") if lit else Color("8a8f92")
		canvas.draw_string(font, Vector2(x + 0.6, 469.6), "营业中" if open else "打烊中", HORIZONTAL_ALIGNMENT_CENTER, w - 1.2, 4.2, text_col)
		canvas.draw_string(font, Vector2(x + 0.6, 472.6), "OPEN" if open else "CLOSED", HORIZONTAL_ALIGNMENT_CENTER, w - 1.2, 2.4, Color(text_col, 0.8))

# Additive night pass (city.gd _draw_night_lights): warm shop window, light
# spill on the terrace, and the coloured glow of the little lightbox.
static func draw_lights(canvas: CanvasItem, glow: Texture2D, clock: float, amount: float) -> void:
	if amount <= 0.002: return
	if lights_on(clock):
		canvas.draw_texture_rect(glow, Rect2(GLASS_X - 6, TOP + 8, X1 - GLASS_X + 12, FLOOR - TOP), false, Color(1.0, 0.76, 0.46, 0.30 * amount))
		canvas.draw_texture_rect(glow, Rect2(GLASS_X - 10, FLOOR - 6, X1 - GLASS_X + 20, 22), false, Color(1.0, 0.78, 0.5, 0.22 * amount))
	if sign_lit(clock):
		var col := Color(0.4, 1.0, 0.6) if sign_open(clock) else Color(1.0, 0.35, 0.28)
		canvas.draw_texture_rect(glow, Rect2(SIGN_X - 6, 456, 26, 24), false, Color(col, 0.30 * amount))
