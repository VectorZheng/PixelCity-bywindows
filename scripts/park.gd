extends RefCounted

# 海边公园（第七轮）。整条海岸带当公园用：
#   湖面 362–404（旧的海湾改成湖，有岸边芦苇和游的鸭子）
#   石砌护岸 404–412 + 精细铁艺栏杆（横杆、立柱、栏板条、柱帽）
#   草坪 412–446：篮球场、贩卖机、帐篷、野餐垫、踢飞碟的小孩
#   步道 446–478：散步、遛狗、倚栏杆吹风、看鸭子、钓鱼、喂鱼
# 所有内容都是确定性的：位置固定，动作只随本地时钟变化，不参与交通仿真。

const Art = preload("res://scripts/art.gd")
const SURNAME := "王李张刘陈杨黄赵吴周徐孙马朱胡郭何林罗梁宋郑谢韩唐冯于董萧"

const SHORE := 404.0        # 湖岸线
const WALK_TOP := 412.0     # 栏杆底座下沿
const LAWN_TOP := 412.0
const LAWN_BOTTOM := 446.0
const PROMENADE := 479.0    # 步道行人脚底（与远侧站棚一致）

# 岸线：在 404 附近轻微起伏，湖不是一条直尺。
static func shore_y(x: float) -> float:
	return SHORE + 2.2 * sin(x / 130.0) + 1.1 * sin(x / 47.0 + 1.7)

static func _hash(i: int) -> int:
	return (i * 2654435761) & 0xffff

# ---------------------------------------------------------------- railing
# 深圳海边那种铁艺栏杆：圆管扶手 + 立柱 + 密集栏板条 + 柱帽。
# 用户要求“不能只是简单的线”，所以扶手有高光和暗面两条，栏板条两种灰交替。
static func draw_railing(canvas: Node2D, x0: float, x1: float, lit: float) -> void:
	var rail := Color("dfe6e6").lerp(Color("8f9a9c"), 0.35)
	var rail_dark := Color("5c6a70")
	var post := Color("eef2f1")
	var bar_a := Color("c6cfd1")
	var bar_b := Color("9aa6a9")
	var x := x0
	while x < x1:
		var y := shore_y(x) + 2.0
		# 栏板条（每 3 px 一根），上端接扶手、下端接底杆。
		var xb := x
		var i := int(x)
		while xb < minf(x + 12.0, x1):
			var shade := bar_a if (int(xb) % 6) < 3 else bar_b
			canvas.draw_rect(Rect2(xb, y + 3.0, 1.0, 5.0), shade)
			xb += 3.0
		# 扶手：亮面 + 暗面 + 每 8 px 一个高光点。
		canvas.draw_rect(Rect2(x, y + 1.6, minf(12.0, x1 - x), 1.0), rail)
		canvas.draw_rect(Rect2(x, y + 2.6, minf(12.0, x1 - x), 0.8), rail_dark)
		if i % 8 < 2:
			canvas.draw_rect(Rect2(x + 1.0, y + 1.2, 2.0, 0.6), Color("f6faf9"))
		# 底杆
		canvas.draw_rect(Rect2(x, y + 8.0, minf(12.0, x1 - x), 0.8), Color("7e8b8e"))
		x += 12.0
	# 立柱 + 柱帽 + 柱脚（每 36 px）
	var px := x0 + 6.0
	while px < x1:
		var y := shore_y(px) + 1.0
		canvas.draw_rect(Rect2(px - 1.0, y, 2.0, 9.0), post)
		canvas.draw_rect(Rect2(px + 1.0, y, 0.8, 9.0), rail_dark)
		canvas.draw_rect(Rect2(px - 1.8, y - 1.0, 3.6, 1.4), post)      # 柱帽
		canvas.draw_rect(Rect2(px - 1.4, y + 9.0, 2.8, 0.8), rail_dark) # 柱脚
		px += 36.0
	if lit > 0.01:
		# 夜里栏杆顶着一层暖光。
		canvas.draw_rect(Rect2(x0, shore_y(x0) + 1.0, x1 - x0, 1.2), Color(1.0, 0.86, 0.62, 0.20 * lit))

# 石砌护岸：三层错缝的石块 + 一条压顶石。
static func draw_embankment(canvas: Node2D, x0: float, x1: float) -> void:
	var x := x0
	while x < x1:
		var y := shore_y(x)
		canvas.draw_rect(Rect2(x, y, minf(4.0, x1 - x), 1.4), Color("cfc9bc"))       # 压顶石
		canvas.draw_rect(Rect2(x, y + 1.4, minf(4.0, x1 - x), 6.6), Color("a8a49a"))
		if int(x) % 8 < 4:
			canvas.draw_rect(Rect2(x, y + 3.0, minf(4.0, x1 - x), 0.8), Color("918d84"))
		else:
			canvas.draw_rect(Rect2(x + 2.0, y + 5.0, 1.0, 2.4), Color("918d84"))
		x += 4.0

# ---------------------------------------------------------------- lake life
# 鸭子：几只在水面慢慢游，头颈是绿/褐色，身后一条细水纹。
static func draw_ducks(canvas: Node2D, x0: float, x1: float, seconds: float) -> void:
	var count := 5
	for i in range(count):
		var base := x0 + (x1 - x0) * (0.12 + 0.18 * i) + 26.0 * sin(seconds * 0.13 + i * 1.7)
		var y := 372.0 + 7.0 * sin(seconds * 0.2 + i * 2.1) + float(_hash(i) % 4)
		if base < x0 - 10.0 or base > x1 + 10.0: continue
		var drake := i % 3 != 1
		canvas.draw_rect(Rect2(base, y, 4.0, 2.0), Color("6d6257") if not drake else Color("7a7266"))   # 身体
		canvas.draw_rect(Rect2(base - 1.0, y + 0.6, 1.4, 1.2), Color("e8e2d4"))                        # 尾羽
		canvas.draw_rect(Rect2(base + 3.4, y - 0.6, 1.6, 1.6), Color("2f6b45") if drake else Color("6b5b4a"))  # 头
		canvas.draw_rect(Rect2(base + 5.0, y + 0.2, 1.0, 0.6), Color("e0b552"))                        # 嘴
		canvas.draw_rect(Rect2(base - 3.0, y + 2.0, 7.0, 0.5), Color(0.9, 0.95, 1.0, 0.30))            # 水纹

# 湖岸边飘着的几点浮萍和芦苇。
static func draw_shore_plants(canvas: Node2D, x0: float, x1: float, seconds: float) -> void:
	var x := x0
	while x < x1:
		var y := shore_y(x)
		var h := 2.0 + float(_hash(int(x)) % 4)
		var sway := sin(seconds * 0.9 + x * 0.11) * 0.5
		canvas.draw_rect(Rect2(x + sway, y - h, 0.7, h), Color("5b7a4e"))
		if _hash(int(x) + 5) % 3 == 0:
			canvas.draw_rect(Rect2(x + sway - 0.4, y - h - 0.8, 1.4, 1.0), Color("8aa86a"))
		x += 9.0 + float(_hash(int(x) + 1) % 7)
	# 水面浮萍
	x = x0 + 20.0
	while x < x1:
		if _hash(int(x) + 11) % 4 == 0:
			canvas.draw_rect(Rect2(x, 376.0 + float(_hash(int(x)) % 8), 2.0, 0.8), Color(0.35, 0.55, 0.32, 0.75))
		x += 34.0

# ---------------------------------------------------------------- grass life
static func draw_tent(canvas: Node2D, x: float, ground: float, colour: Color, seconds: float) -> void:
	var w := 27.0
	var h := 15.0
	var flap := sin(seconds * 1.4) * 0.6
	# 帐篷主体（侧面三角）+ 门帘
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(x, ground), Vector2(x + w * 0.5, ground - h), Vector2(x + w, ground)]), colour)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(x + w * 0.5, ground - h), Vector2(x + w * 0.62, ground), Vector2(x + w, ground)]), colour.darkened(0.18))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(x + w * 0.5, ground - h + 1.0), Vector2(x + w * 0.38 + flap, ground), Vector2(x + w * 0.60 + flap, ground)]), colour.darkened(0.42))
	canvas.draw_rect(Rect2(x + w * 0.5 - 0.5, ground - h - 1.0, 1.0, 1.0), Color("d8d2c4"))       # 顶杆
	canvas.draw_line(Vector2(x, ground), Vector2(x - 3.0, ground + 1.0), Color(0.85, 0.85, 0.8, 0.5), 0.6)  # 地钉绳
	canvas.draw_line(Vector2(x + w, ground), Vector2(x + w + 3.0, ground + 1.0), Color(0.85, 0.85, 0.8, 0.5), 0.6)

static func draw_picnic(canvas: Node2D, x: float, ground: float, seconds: float) -> void:
	var w := 34.0
	# 格子野餐垫
	for i in range(int(w)):
		var c := Color("cf5f52") if ((i / 4) % 2 == 0) else Color("efe6d6")
		canvas.draw_rect(Rect2(x + i, ground - 3.0, 1.0, 3.0), c)
	# 篮子 + 两个坐着的人
	canvas.draw_rect(Rect2(x + 6.0, ground - 6.0, 6.0, 3.4), Color("a97a48"))
	canvas.draw_rect(Rect2(x + 6.0, ground - 6.0, 6.0, 0.8), Color("c08a52"))
	canvas.draw_rect(Rect2(x + 8.0, ground - 7.2, 2.0, 1.4), Color("8a6238"))
	for k in range(2):
		var px := x + 16.0 + k * 11.0
		var bob := 0.4 * sin(seconds * 1.1 + k * 2.0)
		canvas.draw_rect(Rect2(px, ground - 4.4 + bob, 4.0, 3.2), Color("4f6b8a") if k == 0 else Color("c98d7a"))  # 上身
		canvas.draw_rect(Rect2(px + 0.6, ground - 7.0 + bob, 3.0, 2.8), Color("e8c8a8"))                          # 头
		canvas.draw_rect(Rect2(px + 0.4, ground - 5.4 + bob, 3.2, 1.2), Color("2f2a26"))                          # 头发
		canvas.draw_rect(Rect2(px + 4.2, ground - 3.4, 2.6, 1.4), Color("3a4a5c"))                                # 腿

static func draw_frisbee_kids(canvas: Node2D, x: float, ground: float, seconds: float) -> void:
	# 两个孩子跑来跑去，飞碟按抛物线在他们之间飞。
	var a := x + 8.0 * sin(seconds * 0.55)
	var b := x + 40.0 - 8.0 * sin(seconds * 0.55 + 1.2)
	var hop := absf(sin(seconds * 2.6))
	for k in range(2):
		var px := a if k == 0 else b
		var face := 1.0 if k == 0 else -1.0
		canvas.draw_rect(Rect2(px, ground - 3.0 - 2.0 * hop, 3.4, 3.0), Color("e8933f") if k == 0 else Color("4fa2c8"))
		canvas.draw_rect(Rect2(px + 0.5, ground - 6.4 - 2.0 * hop, 2.6, 2.6), Color("ecd0b4"))
		canvas.draw_rect(Rect2(px - 0.2 + (0.6 if face > 0 else 0.0), ground - 7.2 - 2.0 * hop, 3.0, 1.4), Color("3a2f2a"))
		canvas.draw_rect(Rect2(px + 0.6, ground - 1.6, 1.0, 1.6), Color("2e3440"))
		canvas.draw_rect(Rect2(px + 2.0, ground - 1.6, 1.0, 1.6), Color("2e3440"))
	var t := fposmod(seconds * 0.55, PI)
	var fx := lerpf(a, b, t / PI)
	var fy := ground - 10.0 - 7.0 * sin(t)
	canvas.draw_rect(Rect2(fx, fy, 3.0, 1.2), Color("f0e8c8"))
	canvas.draw_rect(Rect2(fx + 0.6, fy + 1.2, 1.8, 0.6), Color(0, 0, 0, 0.15))

# ---------------------------------------------------------------- basketball
const COURT_X := 952.0
const COURT_W := 168.0
const COURT_GROUND := 444.0

static func draw_court(canvas: Node2D, seconds: float, lit: float) -> void:
	var g := COURT_GROUND
	# 场地：一块略微抬起的塑胶地坪，带白线（侧视有透视感）。
	canvas.draw_rect(Rect2(COURT_X, g - 21.0, COURT_W, 20.0), Color("3f6f8a"))
	canvas.draw_rect(Rect2(COURT_X, g - 21.0, COURT_W, 1.4), Color("7fb2c8"))
	canvas.draw_rect(Rect2(COURT_X, g - 13.0, COURT_W, 0.8), Color(1, 1, 1, 0.55))       # 中线
	canvas.draw_rect(Rect2(COURT_X + COURT_W * 0.5 - 0.4, g - 21.0, 0.8, 20.0), Color(1, 1, 1, 0.45))
	# 两端禁区弧线
	for edge in [COURT_X + 13.0, COURT_X + COURT_W - 13.0]:
		for i in range(11):
			var a := -PI / 2.0 + PI * i / 10.0
			canvas.draw_rect(Rect2(edge + cos(a) * 11.0, g - 11.0 + sin(a) * 6.0, 0.9, 0.9), Color(1, 1, 1, 0.4))
	# 篮球架（左侧，篮板朝向场地）+ 篮筐、网、底座配重。
	var bx := COURT_X + 3.0
	canvas.draw_rect(Rect2(bx, g - 27.0, 1.6, 27.0), Color("8d979c"))                   # 立柱
	canvas.draw_rect(Rect2(bx + 1.6, g - 27.0, 0.6, 27.0), Color("5f6a70"))
	canvas.draw_rect(Rect2(bx + 2.0, g - 34.0, 13.0, 0.8), Color("8d979c"))             # 悬臂
	canvas.draw_rect(Rect2(bx + 13.0, g - 36.0, 1.2, 7.0), Color("8d979c"))
	canvas.draw_rect(Rect2(bx + 14.0, g - 36.5, 9.0, 7.0), Color(0.95, 0.97, 0.98, 0.85))   # 篮板
	canvas.draw_rect(Rect2(bx + 14.0, g - 36.5, 9.0, 0.8), Color("d8dee0"))
	canvas.draw_rect(Rect2(bx + 17.0, g - 33.4, 4.0, 2.6), Color(0.85, 0.9, 0.92, 0.6))     # 篮板方框
	canvas.draw_rect(Rect2(bx + 22.0, g - 33.0, 1.4, 0.8), Color("e8622e"))                  # 篮圈
	for k in range(4):
		canvas.draw_rect(Rect2(bx + 22.2 + k * 0.4, g - 32.2, 0.4, 2.2 - k * 0.4), Color(0.92, 0.94, 0.94, 0.5))  # 网
	canvas.draw_rect(Rect2(bx - 2.0, g - 2.2, 7.0, 2.2), Color("545c60"))                   # 底座
	# 三名球员：运球、投篮、防守，球在地面与手之间跳。
	var players := [COURT_X + 46.0, COURT_X + 92.0, COURT_X + 128.0]
	for i in range(players.size()):
		var px: float = players[i] + 5.0 * sin(seconds * (0.7 + i * 0.13) + i)
		var bob := absf(sin(seconds * (2.4 + i * 0.2))) * 1.4
		var shirt: Color = [Color("c8463e"), Color("e9e4d6"), Color("2f5d8a")][i]
		canvas.draw_rect(Rect2(px, g - 9.5 - bob, 4.2, 4.0), shirt)                        # 躯干
		canvas.draw_rect(Rect2(px + 0.6, g - 13.0 - bob, 3.0, 3.0), Color("e8c8a8"))       # 头
		canvas.draw_rect(Rect2(px + 0.4, g - 13.8 - bob, 3.2, 1.4), Color("2f2a26"))       # 头发
		canvas.draw_rect(Rect2(px + 0.8, g - 5.5, 1.2, 5.5), Color("2e3440"))             # 腿
		canvas.draw_rect(Rect2(px + 2.4, g - 5.5, 1.2, 5.5), Color("2e3440"))
		canvas.draw_rect(Rect2(px + 0.4, g - 1.0, 2.0, 1.0), Color("f0ece4"))             # 鞋
		canvas.draw_rect(Rect2(px + 2.6, g - 1.0, 2.0, 1.0), Color("f0ece4"))
		# 手臂：向球的方向伸。
		canvas.draw_rect(Rect2(px + 4.0, g - 9.0 - bob, 3.0, 1.2), Color("e8c8a8"))
	var ball_y := g - 2.0 - absf(sin(seconds * 2.4)) * 9.0
	var ball_x: float = players[0] + 6.0 + 5.0 * sin(seconds * 0.7)
	canvas.draw_rect(Rect2(ball_x, ball_y, 2.6, 2.6), Color("d9622c"))
	canvas.draw_rect(Rect2(ball_x + 0.8, ball_y + 0.4, 0.5, 1.8), Color("8f3a18"))
	if lit > 0.01:
		# 夜里的球场灯：两盏灯柱 + 光斑。
		for lx in [COURT_X + 26.0, COURT_X + COURT_W - 26.0]:
			canvas.draw_rect(Rect2(lx, g - 34.0, 1.4, 34.0), Color("6d777c"))
			canvas.draw_rect(Rect2(lx - 2.0, g - 36.0, 5.4, 2.0), Color("e8e2c4"))
			canvas.draw_rect(Rect2(lx - 2.0, g - 34.0, 5.4, 1.2), Color(1.0, 0.95, 0.78, 0.55 * lit))
		canvas.draw_rect(Rect2(COURT_X, g - 21.0, COURT_W, 20.0), Color(1.0, 0.93, 0.75, 0.10 * lit))

# 贩卖机：灯箱常亮，出货口在下方。
static func draw_vending(canvas: Node2D, x: float, ground: float, seconds: float, lit: float) -> void:
	canvas.draw_rect(Rect2(x - 0.6, ground - 25.4, 13.2, 25.4), Color("4a5257"))
	canvas.draw_rect(Rect2(x, ground - 25.0, 12.0, 25.0), Color("d8dcda"))
	canvas.draw_rect(Rect2(x + 1.0, ground - 23.6, 10.0, 13.0), Color("274a63") if lit > 0.3 else Color("1d384a"))
	# 货道里的饮料罐
	for row in range(3):
		for col in range(4):
			var c: Color = [Color("d9a83a"), Color("c8463e"), Color("3f8a5a"), Color("2f5d8a")][(row + col) % 4]
			canvas.draw_rect(Rect2(x + 1.8 + col * 2.4, ground - 22.4 + row * 4.0, 1.6, 2.6), c)
	canvas.draw_rect(Rect2(x + 1.0, ground - 9.6, 10.0, 3.2), Color("22303a"))     # 按钮/投币区
	canvas.draw_rect(Rect2(x + 2.0, ground - 8.8, 4.0, 1.4), Color(0.9, 0.95, 1.0, 0.5 + 0.3 * absf(sin(seconds))))
	canvas.draw_rect(Rect2(x + 2.0, ground - 5.0, 8.0, 3.6), Color("2a3238"))       # 出货口
	canvas.draw_rect(Rect2(x + 2.6, ground - 4.4, 6.8, 2.4), Color("151b1f"))

# ---------------------------------------------------------------- promenade
# 牵狗散步：狗是 8 px 的小侧影，绳子从手到项圈。
static func draw_dog_walker(canvas: Node2D, x: float, ground: float, seconds: float, flip: bool) -> void:
	var dir := -1.0 if flip else 1.0
	var dog_x := x + dir * 12.0
	var dog_y := ground
	var bounce := absf(sin(seconds * 3.2)) * 0.8
	canvas.draw_line(Vector2(x + dir * 3.0, ground - 12.0), Vector2(dog_x - dir * 3.0, dog_y - 6.0), Color(0.9, 0.9, 0.86, 0.65), 0.5)
	# 狗：身体、头、耳朵、四条腿、翘尾。
	canvas.draw_rect(Rect2(dog_x - 3.0, dog_y - 6.0 - bounce, 6.0, 3.0), Color("c8a06a"))
	canvas.draw_rect(Rect2(dog_x + dir * 3.0 - 1.0, dog_y - 7.6 - bounce, 2.4, 2.4), Color("c8a06a"))
	canvas.draw_rect(Rect2(dog_x + dir * 3.0 - 1.0, dog_y - 8.4 - bounce, 1.0, 1.2), Color("8a6a44"))
	canvas.draw_rect(Rect2(dog_x - dir * 3.0 - 0.4, dog_y - 7.0 - bounce, 1.2, 1.2), Color("8a6a44"))
	for k in range(4):
		canvas.draw_rect(Rect2(dog_x - 2.4 + k * 1.6, dog_y - 3.0 + (0.6 if k % 2 else 0.0), 0.8, 3.0), Color("a8825a"))

# 倚着栏杆吹风：人向水面探身，手臂搭在扶手上。
static func draw_leaner(canvas: Node2D, x: float, seconds: float) -> void:
	var y := shore_y(x) + 2.0
	var sway := 0.25 * sin(seconds * 0.8 + x)
	canvas.draw_rect(Rect2(x - 1.6, y - 5.0, 3.2, 5.0), Color("3b4a5e"))            # 腿
	canvas.draw_rect(Rect2(x - 1.8 + sway, y - 9.6, 3.6, 4.8), Color("b8544a"))     # 上身
	canvas.draw_rect(Rect2(x - 1.0 + sway, y - 12.4, 2.6, 2.8), Color("e8c8a8"))    # 头
	canvas.draw_rect(Rect2(x - 1.2 + sway, y - 13.2, 3.0, 1.2), Color("2f2a26"))
	canvas.draw_rect(Rect2(x + 0.6, y - 9.0, 3.4, 1.0), Color("e8c8a8"))            # 搭在栏杆上的手

# 钓鱼：鱼竿从手伸出斜向水面，鱼线垂到湖里，浮标一起一伏。
static func draw_fisher(canvas: Node2D, x: float, seconds: float) -> void:
	var y := shore_y(x) + 2.0
	canvas.draw_rect(Rect2(x - 1.8, y - 5.4, 3.6, 5.4), Color("3f4a52"))
	canvas.draw_rect(Rect2(x - 1.8, y - 10.2, 3.6, 5.0), Color("4f6d52"))
	canvas.draw_rect(Rect2(x - 1.0, y - 13.0, 2.6, 2.8), Color("e8c8a8"))
	canvas.draw_rect(Rect2(x - 1.4, y - 13.8, 3.4, 1.4), Color("6b6257"))            # 帽子
	var tip := Vector2(x + 13.0, y - 16.0)
	canvas.draw_line(Vector2(x + 1.0, y - 9.0), tip, Color("6b5a44"), 0.8)            # 竿
	var bob := 1.2 * sin(seconds * 1.6 + x * 0.1)
	canvas.draw_line(tip, Vector2(tip.x + 3.0, y - 22.0 + bob), Color(0.9, 0.9, 0.86, 0.5), 0.4)  # 线
	canvas.draw_rect(Rect2(tip.x + 2.6, y - 22.4 + bob, 1.4, 1.6), Color("e8e2d4"))   # 浮标
	canvas.draw_rect(Rect2(tip.x + 2.6, y - 22.4 + bob, 1.4, 0.6), Color("c8463e"))
	# 水面的涟漪
	for i in range(2):
		var r := 2.0 + i * 2.4 + fposmod(seconds * 3.0, 3.0)
		canvas.draw_rect(Rect2(tip.x + 3.0 - r, y - 20.6 + bob + 0.3 * i, r * 2.0, 0.4), Color(0.85, 0.93, 1.0, 0.22))

# 喂鱼：手一扬，几粒饲料落进水里，水花一圈圈散开。
static func draw_feeder(canvas: Node2D, x: float, seconds: float) -> void:
	var y := shore_y(x) + 2.0
	canvas.draw_rect(Rect2(x - 1.8, y - 5.4, 3.6, 5.4), Color("4a4a52"))
	canvas.draw_rect(Rect2(x - 1.8, y - 10.4, 3.6, 5.0), Color("d9a83a"))
	canvas.draw_rect(Rect2(x - 1.0, y - 13.2, 2.6, 2.8), Color("e8c8a8"))
	canvas.draw_rect(Rect2(x - 1.4, y - 14.0, 3.4, 1.2), Color("2f2a26"))
	var phase := fposmod(seconds, 2.6) / 2.6
	canvas.draw_rect(Rect2(x + 2.0, y - 11.6 - 2.0 * sin(phase * PI), 2.4, 1.0), Color("e8c8a8"))
	if phase > 0.45:
		var f := (phase - 0.45) / 0.55
		for k in range(4):
			var fx := x + 6.0 + k * 1.4
			var fy := y - 9.0 + f * 12.0 + k * 0.6
			canvas.draw_rect(Rect2(fx, fy, 0.8, 0.8), Color("d9c58a"))
		var r := 1.0 + f * 5.0
		canvas.draw_rect(Rect2(x + 6.0 - r, y + 3.4, r * 2.0, 0.4), Color(0.9, 0.96, 1.0, 0.35 * (1.0 - f)))

# ---------------------------------------------------------------- park ambience
# 草地上的人：坐着聊天、看书、拉伸，位置固定、微动。
static func draw_lawn_folk(canvas: Node2D, seconds: float) -> void:
	var folk := [
		[1200.0, Color("6b8f5a"), "sit"], [1226.0, Color("8a5f7a"), "sit"],
		[1352.0, Color("4f6d8a"), "lie"], [1452.0, Color("c98d7a"), "stretch"],
		[1468.0, Color("5f7a8a"), "read"], [1128.0, Color("7a6a52"), "tent"],
	]
	for i in range(folk.size()):
		var x: float = folk[i][0]
		var shirt: Color = folk[i][1]
		var pose: String = folk[i][2]
		var bob := 0.5 * sin(seconds * 1.2 + i)
		var ground := LAWN_BOTTOM - 2.0
		match pose:
			"sit":
				canvas.draw_rect(Rect2(x, ground - 4.6 + bob, 4.0, 4.4), shirt)
				canvas.draw_rect(Rect2(x + 0.6, ground - 7.6 + bob, 3.0, 3.0), Color("e8c8a8"))
				canvas.draw_rect(Rect2(x + 0.4, ground - 8.4 + bob, 3.2, 1.4), Color("2f2a26"))
			"lie":
				canvas.draw_rect(Rect2(x, ground - 2.6, 8.0, 2.4), shirt)
				canvas.draw_rect(Rect2(x + 7.6, ground - 4.0, 2.6, 2.4), Color("e8c8a8"))
			"stretch":
				canvas.draw_rect(Rect2(x, ground - 8.0 + bob, 3.6, 8.0), shirt)
				canvas.draw_rect(Rect2(x + 0.5, ground - 11.0 + bob, 2.8, 2.8), Color("e8c8a8"))
				canvas.draw_rect(Rect2(x + 3.2, ground - 10.4, 3.4, 1.0), Color("e8c8a8"))
			"read":
				canvas.draw_rect(Rect2(x, ground - 4.4, 3.6, 4.2), shirt)
				canvas.draw_rect(Rect2(x + 0.5, ground - 7.4, 2.8, 2.8), Color("e8c8a8"))
				canvas.draw_rect(Rect2(x + 3.2, ground - 5.6, 3.6, 2.6), Color("f0ece0"))   # 摊开的书
			"tent":
				canvas.draw_rect(Rect2(x, ground - 10.0, 3.0, 10.0), Color("556070"))       # 正在搭帐篷
				canvas.draw_rect(Rect2(x + 0.4, ground - 13.0, 2.4, 2.8), Color("e8c8a8"))
				canvas.draw_line(Vector2(x + 3.0, ground - 9.0), Vector2(x + 9.0, ground - 13.0), Color("b9b3a4"), 0.7)

# 公园里的长椅和路灯，顺带给草坪一点秩序感。
static func draw_benches(canvas: Node2D, seconds: float) -> void:
	for x in [1180.0, 1330.0, 1500.0]:
		var g := LAWN_BOTTOM - 2.0
		canvas.draw_rect(Rect2(x, g - 5.4, 16.0, 1.4), Color("9a6f45"))       # 座板
		canvas.draw_rect(Rect2(x, g - 8.4, 16.0, 1.2), Color("8a613c"))       # 靠背
		canvas.draw_rect(Rect2(x + 1.4, g - 5.4, 1.0, 5.4), Color("4e565a"))  # 腿
		canvas.draw_rect(Rect2(x + 13.4, g - 5.4, 1.0, 5.4), Color("4e565a"))
		for k in range(4):
			canvas.draw_rect(Rect2(x + 1.0 + k * 4.0, g - 9.0, 0.8, 5.0), Color("5b6367"))

# ---------------------------------------------------------------- entry points
static func draw_park(canvas: Node2D, font: Font, seconds: float, lit: float, x0: float, x1: float) -> void:
	# 由远到近：湖岸植物、栏杆、草坪设施、球场、步道行人。
	draw_shore_plants(canvas, x0, x1, seconds)
	draw_ducks(canvas, x0, x1, seconds)
	draw_embankment(canvas, x0, x1)
	draw_railing(canvas, x0, x1, lit)
	draw_benches(canvas, seconds)
	draw_tent(canvas, 1156.0, LAWN_BOTTOM - 1.0, Color("d9a83a"), seconds)
	draw_tent(canvas, 1204.0, LAWN_BOTTOM - 1.0, Color("4f7f8a"), seconds)
	draw_picnic(canvas, 1288.0, LAWN_BOTTOM - 1.0, seconds)
	draw_lawn_folk(canvas, seconds)
	draw_frisbee_kids(canvas, 1360.0, LAWN_BOTTOM - 1.0, seconds)
	draw_court(canvas, seconds, lit)
	draw_vending(canvas, COURT_X + COURT_W + 8.0, LAWN_BOTTOM - 1.0, seconds, lit)
	# 栏杆边的人（背对镜头看湖）
	draw_leaner(canvas, 1268.0, seconds)
	draw_leaner(canvas, 1300.0, seconds)
	draw_leaner(canvas, 1436.0, seconds)
	draw_fisher(canvas, 1372.0, seconds)
	draw_feeder(canvas, 1470.0, seconds)
	# 步道上的散步和遛狗
	draw_dog_walker(canvas, 1032.0 + 26.0 * sin(seconds * 0.09), PROMENADE, seconds, false)
	draw_dog_walker(canvas, 1408.0 - 22.0 * sin(seconds * 0.08 + 1.0), PROMENADE, seconds, true)

# 夜间加光：球场灯、贩卖机、湖面反光的暖边。
static func draw_park_lights(canvas: CanvasItem, glow: Texture2D, seconds: float, amount: float) -> void:
	if amount <= 0.002: return
	canvas.draw_texture_rect(glow, Rect2(COURT_X + 6.0, COURT_GROUND - 22.0, COURT_W, 26.0), false, Color(1.0, 0.92, 0.7, 0.16 * amount))
	for lx in [COURT_X + 26.0, COURT_X + COURT_W - 26.0]:
		canvas.draw_texture_rect(glow, Rect2(lx - 12.0, COURT_GROUND - 46.0, 24.0, 20.0), false, Color(1.0, 0.95, 0.8, 0.30 * amount))
	canvas.draw_texture_rect(glow, Rect2(COURT_X + COURT_W + 2.0, LAWN_BOTTOM - 32.0, 22.0, 26.0), false, Color(0.6, 0.85, 1.0, 0.24 * amount))
	# 岸边的暖光串
	for x in [1210.0, 1290.0, 1370.0, 1450.0, 1530.0]:
		canvas.draw_texture_rect(glow, Rect2(x - 6.0, shore_y(x) - 4.0, 12.0, 10.0), false, Color(1.0, 0.86, 0.6, 0.20 * amount))
