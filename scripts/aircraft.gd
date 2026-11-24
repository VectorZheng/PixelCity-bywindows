extends RefCounted

# Slow aircraft over the bay (replaces the old UFO). Airliners cross high up on
# their way to / from Shenzhen Bao'an (west, i.e. the right of the picture) and
# leave a contrail that drifts with the wind, spreads and slowly dissolves into
# the cloud layer; now and then a helicopter passes lower down. Everything is
# drawn as pixel rectangles on whole scene pixels. Identities are simulated.

const AIRLINES := [
	{"name": "中国南方航空", "code": "CZ", "tail": Color("2b6cb3"), "stripe": Color("2b6cb3")},
	{"name": "深圳航空", "code": "ZH", "tail": Color("c8342c"), "stripe": Color("c8342c")},
	{"name": "中国国际航空", "code": "CA", "tail": Color("c8342c"), "stripe": Color("d8d8d8")},
	{"name": "东方航空", "code": "MU", "tail": Color("1d3f7a"), "stripe": Color("b5263a")},
	{"name": "海南航空", "code": "HU", "tail": Color("c7362f"), "stripe": Color("e3a23a")},
	{"name": "国泰航空", "code": "CX", "tail": Color("1f6f66"), "stripe": Color("1f6f66")},
]
const TYPES := ["空客 A320neo", "波音 737-800", "空客 A330-300", "波音 787-9", "国产 C919"]
const ORIGINS := ["北京首都", "上海虹桥", "成都天府", "杭州萧山", "西安咸阳", "重庆江北", "昆明长水", "武汉天河"]
const HELI_JOBS := [["深圳交警直升机", "空中巡查深南大道交通"], ["深圳医疗救援直升机", "转运病人去市人民医院"], ["深圳海事巡逻直升机", "巡查深圳湾海面"]]

var flights: Array = []
var trails: Array = []          # contrail puffs
var _rng := RandomNumberGenerator.new()
var _timer := 5.0
var _next_id := 0
var _puff_timer := 0.0

func _init(seed_value: int = 3021) -> void:
	_rng.seed = seed_value

func step(dt: float, width: float, wind: float = 10.0) -> void:
	_timer -= dt
	if _timer <= 0.0:
		_spawn(width)
		_timer = _rng.randf_range(55.0, 120.0)
	_puff_timer -= dt
	var drop := _puff_timer <= 0.0
	if drop: _puff_timer = 0.2
	for f in flights:
		f.x += f.speed * f.dir * dt
		f.y += f.climb * dt
		f.age += dt
		if drop and f.kind == "jet" and f.contrail:
			# Two engines' trails start a few pixels behind the tail.
			trails.append({"x": f.x - f.dir * 4.0, "y": f.y + 4.0, "age": 0.0, "life": f.trail_life})
	var drift := wind * 0.06
	for t in trails:
		t.age += dt
		t.x += drift * dt
		t.y += 0.05 * dt
	trails = trails.filter(func(t): return t.age < t.life)
	flights = flights.filter(func(f): return f.x > -80.0 and f.x < width + 80.0)

func _spawn(width: float) -> void:
	var heli := _rng.randf() < 0.25
	var dir := 1 if _rng.randf() < 0.55 else -1
	var f := {"id": _next_id, "kind": "heli" if heli else "jet", "dir": dir, "age": 0.0,
		"x": -60.0 if dir > 0 else width + 60.0, "seed": _rng.randi()}
	_next_id += 1
	if heli:
		f.y = _rng.randf_range(170.0, 230.0)
		f.speed = _rng.randf_range(18.0, 26.0)
		f.climb = 0.0
		f.job = HELI_JOBS[_rng.randi_range(0, HELI_JOBS.size() - 1)]
		f.contrail = false
	else:
		f.y = _rng.randf_range(62.0, 150.0)
		f.speed = _rng.randf_range(22.0, 32.0)
		# Westbound (right) traffic is descending into Bao'an, eastbound climbing out.
		f.climb = _rng.randf_range(0.4, 0.9) * (1.0 if dir > 0 else -1.0)
		f.airline = AIRLINES[_rng.randi_range(0, AIRLINES.size() - 1)]
		f.type = TYPES[_rng.randi_range(0, TYPES.size() - 1)]
		f.number = "%s%d" % [f.airline.code, _rng.randi_range(3001, 9899)]
		f.origin = ORIGINS[_rng.randi_range(0, ORIGINS.size() - 1)]
		# Only cold, high air makes a persistent trail; lower jets leave a short wisp.
		f.contrail = true
		f.trail_life = 70.0 if f.y < 115.0 else 9.0
	flights.append(f)

static func altitude_m(f: Dictionary) -> int:
	return int(round((420.0 - f.y) * 26.0 / 100.0)) * 100

static func box(f: Dictionary) -> Rect2:
	return Rect2(floorf(f.x) - 14.0, floorf(f.y) - 6.0, 28.0, 13.0)

static func describe(f: Dictionary) -> Dictionary:
	if f.kind == "heli":
		return {"title": f.job[0], "subtitle": "直升机 · 模拟", "rows": [["任务", f.job[1]], ["高度", "约 %d 米" % (altitude_m(f) / 8)], ["速度", "约 %d km/h" % int(f.speed * 7.0)]]}
	var arriving: bool = f.dir > 0
	var route: String = ("%s → 深圳宝安" % f.origin) if arriving else ("深圳宝安 → %s" % f.origin)
	return {"title": "%s %s" % [f.airline.name, f.number], "subtitle": "%s · 航班信息为模拟" % f.type,
		"rows": [["航线", route], ["状态", "下降，准备降落宝安机场" if arriving else "起飞后爬升"],
			["高度", "约 %d 米" % altitude_m(f)], ["速度", "约 %d km/h" % int(f.speed * 16.0)],
			["尾迹", "高空冷空气中留下凝结尾迹" if f.trail_life > 20.0 else "高度较低，尾迹很快消散"]]}

# --- drawing (scene coordinates, whole pixels) ------------------------------

static func draw_trails(canvas: CanvasItem, trails_list: Array, lit: Color) -> void:
	for t in trails_list:
		var k: float = t.age / t.life
		# Fresh trails are thin and bright; old ones spread into soft cloud.
		var width := 1.0 + floorf(k * 4.0)
		var alpha := (0.75 if t.age < 2.0 else 0.6) * (1.0 - k) * (1.0 - k * 0.3)
		if alpha < 0.03: continue
		var x := floorf(t.x)
		var y := floorf(t.y - width * 0.5)
		canvas.draw_rect(Rect2(x, y, 3, width), Color(lit, alpha))
		canvas.draw_rect(Rect2(x, y + width + 1.0, 3, maxf(1.0, width - 1.0)), Color(lit, alpha * 0.85))

static func draw_flight(canvas: CanvasItem, f: Dictionary, light: Color, seconds: float, highlighted: bool) -> void:
	var o := Vector2(floorf(f.x), floorf(f.y))
	var d: int = f.dir
	var r := func(x: float, y: float, w: float, h: float, c: Color) -> void:
		# Local sprite rect, mirrored for leftbound traffic.
		var lx := x if d > 0 else -x - w
		canvas.draw_rect(Rect2(o.x + lx, o.y + y, w, h), c)
	var lit := func(c: Color) -> Color: return Color(c.r * light.r, c.g * light.g, c.b * light.b, c.a)
	if highlighted:
		canvas.draw_rect(Rect2(o.x - 16, o.y - 8, 32, 17), Color(1.0, 0.8, 0.5, 0.18))
	var blink := fposmod(seconds + float(f.seed % 100) * 0.01, 1.2) < 0.12
	if f.kind == "heli":
		var body: Color = lit.call(Color("d9d3c4") if f.job[0].contains("医疗") else Color("e1e4e6"))
		var band: Color = lit.call(Color("c63b31") if f.job[0].contains("医疗") else Color("2d63a8"))
		r.call(-5, 0, 10, 4, body)
		r.call(-5, 2, 10, 1, band)
		r.call(2, 1, 3, 2, lit.call(Color("33414c")))           # cockpit glass
		r.call(-14, 1, 9, 1, body)                               # tail boom
		r.call(-15, -1, 2, 3, body)
		r.call(-4, 5, 9, 1, lit.call(Color("4a5156")))           # skids
		r.call(-1, -1, 2, 1, lit.call(Color("4a5156")))          # mast
		var blade := 9.0 if int(seconds * 14.0) % 2 == 0 else 6.0
		r.call(-blade, -2, blade * 2.0, 1, lit.call(Color(0.25, 0.28, 0.3, 0.8)))
		r.call(-16 if int(seconds * 14.0) % 2 == 0 else -15, -1, 1, 3, lit.call(Color(0.25, 0.28, 0.3, 0.7)))
		if blink: r.call(-15, -2, 1, 1, Color(1.0, 0.25, 0.2))
		return
	var white: Color = lit.call(Color("e6e9ec"))
	var belly: Color = lit.call(Color("b9c0c6"))
	var tail: Color = lit.call(f.airline.tail)
	var stripe: Color = lit.call(f.airline.stripe)
	r.call(-12, 0, 23, 3, white)                 # fuselage
	r.call(-12, 2, 23, 1, belly)
	r.call(11, 1, 2, 2, white)                   # nose
	r.call(10, 0, 1, 1, lit.call(Color("2e3a44")))   # cockpit window
	r.call(-8, 1, 17, 1, stripe if f.airline.code != "CA" else white)
	for wx in range(-7, 9, 2): r.call(wx, 0, 1, 1, lit.call(Color("5c6b78")))
	r.call(-13, -5, 3, 5, tail)                  # tail fin
	r.call(-11, -3, 1, 3, tail)
	r.call(-14, 1, 4, 1, belly)                  # stabiliser
	r.call(-3, 3, 6, 1, belly)                   # wing (far side, below)
	r.call(-1, 4, 4, 1, belly)
	r.call(0, 3, 3, 2, lit.call(Color("8c959c")))    # engine
	# Anti-collision beacon and tail strobe.
	if blink:
		r.call(-1, -1, 1, 1, Color(1.0, 0.2, 0.15))
		r.call(-14, -5, 1, 1, Color(1.0, 1.0, 1.0))
	elif fposmod(seconds, 1.2) < 0.6:
		r.call(-1, 4, 1, 1, Color(1.0, 0.2, 0.15, 0.8))
