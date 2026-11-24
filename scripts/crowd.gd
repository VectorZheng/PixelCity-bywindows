extends RefCounted

# Passers-by that follow the real clock. Peaks bring streams of office workers
# (many heading in and out of Huaxin station), school runs bring high-school
# students in the Shenzhen uniform, and the small hours leave only night-shift
# workers and delivery riders. Positions are scene coordinates.

const LOOKS_PATH := "res://assets/people-real/crowd.json"
const Routes = preload("res://scripts/station_routes.gd")
const MetroLine = preload("res://scripts/metro_line.gd")
const SURNAMES := "王李张刘陈杨黄赵吴周徐孙马朱胡郭何林罗梁宋郑谢韩唐冯于董萧程曹袁邓许傅沈曾彭吕苏卢蒋蔡贾丁魏薛叶阎余潘杜戴夏钟汪田任姜范方石姚谭廖邹熊金陆郝孔白崔康毛邱秦江史顾侯邵孟龙万段雷钱汤尹黎易常武乔贺赖龚文"
const GIVEN := ["子涵", "浩然", "一鸣", "思远", "雨桐", "佳怡", "梓萱", "俊杰", "欣怡", "宇航", "诗涵", "嘉豪", "晓彤", "明轩", "可馨", "博文", "静怡", "天佑", "若曦", "志强", "秀英", "建华", "海燕", "伟", "敏", "磊", "婷", "洋", "丽"]
const JOBS := ["互联网公司产品经理", "银行职员", "律所助理", "UI 设计师", "销售经理", "会计", "硬件工程师", "券商分析师", "人事专员", "外贸跟单"]
const SCHOOLS := ["红岭中学", "深圳高级中学", "福田中学", "深圳实验学校高中部"]

var people: Array = []
var looks: Array = []
var _rng := RandomNumberGenerator.new()
var _timer := 0.0
var _next_id := 0

func _init(seed_value: int = 77) -> void:
	_rng.seed = seed_value
	var text := FileAccess.get_file_as_string(LOOKS_PATH)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if parsed is Array: looks = parsed

# People per minute entering the scene, by hour.
static func density(hour: float) -> float:
	var keys := [[0.0, 1.2], [1.0, 0.5], [5.0, 0.4], [6.3, 4.0], [7.3, 26.0], [8.5, 30.0], [9.6, 6.0],
		[11.5, 9.0], [13.5, 5.0], [16.5, 8.0], [18.0, 30.0], [19.5, 14.0], [21.5, 6.0], [23.0, 2.5], [24.0, 1.2]]
	for i in range(keys.size() - 1):
		if hour >= keys[i][0] and hour < keys[i + 1][0]:
			return lerpf(keys[i][1], keys[i + 1][1], smoothstep(keys[i][0], keys[i + 1][0], hour))
	return 1.2

static func mix_for(hour: float) -> Dictionary:
	# Shares of each look group at a given hour.
	var school := (hour >= 6.8 and hour < 7.8) or (hour >= 16.8 and hour < 18.2) or (hour >= 21.5 and hour < 22.2)
	if hour < 5.5 or hour >= 23.5: return {"night": 0.75, "commuter": 0.15, "other": 0.1}
	if school: return {"student": 0.45, "commuter": 0.45, "other": 0.1}
	if (hour >= 7.2 and hour < 9.8) or (hour >= 17.3 and hour < 19.8): return {"commuter": 0.82, "student": 0.06, "other": 0.12}
	return {"commuter": 0.45, "other": 0.4, "night": 0.05, "student": 0.1}

func _look(kind: String) -> Dictionary:
	var options := looks.filter(func(l): return l.kind == kind)
	if options.is_empty(): options = looks
	return options[_rng.randi_range(0, options.size() - 1)] if not options.is_empty() else {"sheet": 0, "row": 0, "kind": "commuter", "desc": ""}

func _identity(kind: String, desc: String, hour: float) -> Dictionary:
	var name: String = SURNAMES[_rng.randi_range(0, SURNAMES.length() - 1)] + GIVEN[_rng.randi_range(0, GIVEN.size() - 1)]
	match kind:
		"student":
			return {"name": name, "age": _rng.randi_range(15, 18), "job": "高中生 · %s" % SCHOOLS[_rng.randi_range(0, SCHOOLS.size() - 1)]}
		"night":
			var rider := desc.contains("外卖")
			return {"name": name, "age": _rng.randi_range(21, 45), "job": "美团外卖骑手" if rider else "夜班保安"}
		"other":
			var old := desc.contains("老人")
			return {"name": name, "age": _rng.randi_range(64, 78) if old else _rng.randi_range(25, 40), "job": "退休" if old else "自由职业"}
	return {"name": name, "age": _rng.randi_range(23, 45), "job": JOBS[_rng.randi_range(0, JOBS.size() - 1)]}

# entrances: [x of the two metro entrances]; trips into or out of the station
# are what make the peaks feel like Huaxin rather than a random street.
# station: {"shift": entrance shift, "far_x": x of exit B across the road}.
# With it, near-side travellers really ride the escalators: down to the
# platform and along it, or up from a train and out into the street.
func step(dt: float, hour: float, width: float, entrances: Array, raining: bool, station: Dictionary = {}) -> void:
	_timer -= dt
	if _timer <= 0.0:
		_spawn(hour, width, entrances, raining, station)
		_timer = -log(maxf(_rng.randf(), 0.02)) / maxf(density(hour) / 60.0, 0.001)
	var shift: float = station.get("shift", 0.0)
	for p in people:
		var hurry := 1.35 if raining and not p.umbrella else 1.0
		var old_x: float = p.x
		var stage := str(p.get("stage", "walk"))
		if stage == "ride":
			p.progress = minf(1.0, p.progress + dt / Routes.RIDE_SECONDS)
			p.x = Routes.escalator_position(p.progress, p.down, shift).x
			if p.progress >= 1.0:
				p.dir = 1
				if p.down:
					p.stage = "platform"
					p.target = p.x + _rng.randf_range(60.0, 260.0)
				else:
					p.stage = "walk"
					p.target = -1.0
			continue
		if stage == "queue":
			# Wait at the landing until the step ahead is clear.
			if _lane_clear(p.down):
				p.stage = "ride"
				p.progress = 0.0
			continue
		p.x += p.speed * hurry * p.dir * dt
		p.walk_distance += absf(p.x - old_x)
		if p.target >= 0.0 and (p.x - p.target) * p.dir >= 0.0:
			if p.boards and stage == "walk":
				p.stage = "queue"
				p.down = true
				p.x = p.target
			elif stage == "platform" and p.trip == "from_metro":
				p.stage = "queue"
				p.down = false
				p.x = p.target
			else:
				p.gone = true
	people = people.filter(func(p): return not p.get("gone", false) and p.x > -60.0 and p.x < width + 60.0)

func _lane_clear(down: bool) -> bool:
	for other in people:
		if other.stage == "ride" and other.down == down and other.progress < 0.075: return false
	return true

func riders() -> Array:
	return people.filter(func(p): return p.stage == "ride" or p.stage == "queue")

func _spawn(hour: float, width: float, entrances: Array, raining: bool, station: Dictionary = {}) -> void:
	var mix := mix_for(hour)
	var r := _rng.randf()
	var kind := "commuter"
	var acc := 0.0
	for k in mix:
		acc += mix[k]
		if r <= acc:
			kind = k
			break
	var look := _look(kind)
	var promenade := _rng.randf() < 0.3
	var dir := 1 if _rng.randf() < 0.5 else -1
	var x := -30.0 if dir > 0 else width + 30.0
	var target := -1.0
	var trip := "local"
	var stage := "walk"
	var boards := false
	# In the peaks many people come out of, or head into, the station.
	if not station.is_empty() and kind != "night" and _rng.randf() < (0.7 if kind in ["commuter", "student"] else 0.3) \
			and (promenade or station.get("open", true)):
		var shift: float = station.get("shift", 0.0)
		if promenade:
			# Far side: the bookshop café beside the stop (only while it is open).
			var far_x: float = station.get("far_x", 896.0)
			if not station.get("cafe_open", true):
				pass
			elif _rng.randf() < 0.5:
				x = far_x
				trip = "from_cafe"
				dir = 1 if _rng.randf() < 0.5 else -1
			else:
				target = far_x
				dir = 1 if far_x > x else -1
				trip = "to_cafe"
		elif _rng.randf() < 0.5:
			# Off a train: walk along the platform to the up escalator.
			trip = "from_metro"
			stage = "platform"
			x = Routes.BOTTOM_X + shift + _rng.randf_range(90.0, 420.0)
			dir = -1
			target = Routes.BOTTOM_X + shift + Routes.UP_OFFSET.x
		else:
			trip = "to_metro"
			boards = true
			target = Routes.TOP_X + shift
			dir = 1 if target > x else -1
	elif station.is_empty() and not promenade and not entrances.is_empty() and kind in ["commuter", "student"] and _rng.randf() < 0.55:
		var entrance: float = entrances[_rng.randi_range(0, entrances.size() - 1)]
		if _rng.randf() < 0.5:
			x = entrance
			trip = "from_metro"
		else:
			target = entrance
			dir = 1 if entrance > x else -1
			trip = "to_metro"
	var speed := _rng.randf_range(16.0, 22.0) if kind in ["commuter", "student"] else _rng.randf_range(9.0, 15.0)
	if kind == "commuter" and ((hour >= 7.2 and hour < 9.8) or (hour >= 17.3 and hour < 19.8)): speed *= 1.15
	var identity := _identity(kind, str(look.get("desc", "")), hour)
	people.append({"id": _next_id, "kind": kind, "sheet": int(look.sheet), "row": int(look.row), "desc": str(look.get("desc", "")),
		"x": x, "spawn_x": x, "dir": dir, "speed": speed, "walk_distance": _rng.randf() * 20.0, "promenade": promenade,
		"lane": _rng.randi_range(0, 2), "target": target, "trip": trip, "umbrella": _rng.randf() < 0.75,
		"stage": stage, "boards": boards, "progress": 0.0, "down": true,
		"identity": identity, "seed": _rng.randi(), "hour": hour})
	_next_id += 1

static func _far(p: Dictionary) -> String:
	var places := ["车公庙", "南山科技园", "福田口岸", "老街", "布吉", "大运", "罗湖口岸", "深圳北站", "前海", "会展中心"]
	return places[int(p.seed) % places.size()]

func describe(p: Dictionary, raining: bool) -> Dictionary:
	var hour: float = p.hour
	var who: Dictionary = p.identity
	var going := ""
	var mood := ""
	match p.trip:
		"to_metro":
			going = "走去%s站坐 %s，去%s" % [MetroLine.station(), MetroLine.line(), "学校" if p.kind == "student" else _far(p)]
			mood = "赶时间，有点着急" if hour < 10.0 else "下班了，轻松一点"
		"from_metro":
			going = "刚坐地铁到%s，%s" % [MetroLine.station(), "去学校上课" if p.kind == "student" and hour < 12.0 else ("回家" if hour >= 17.0 else "去附近上班")]
			mood = "地铁太挤，刚喘口气" if hour < 10.0 or (hour >= 17.3 and hour < 19.8) else "平静"
		"to_cafe":
			going = "去海边的街角书房，%s" % ["买杯咖啡", "看会儿书", "约了朋友喝咖啡", "带本新书回家"][int(p.seed) % 4]
			mood = "悠闲"
		"from_cafe":
			going = "刚从街角书房出来，%s" % ["拿着咖啡去上班" if hour < 12.0 else "沿海边走走", "买了两本书"][int(p.seed) % 2]
			mood = "心情不错"
		_:
			# Local errands that fit the hour they are out.
			var local := ["附近便利店买早餐", "步行去附近公司上班", "华强北办事"]
			if hour >= 10.5 and hour < 14.0: local = ["去吃午饭", "华强北办事", "取快递"]
			elif hour >= 14.0 and hour < 17.0: local = ["华强北办事", "取快递", "去健身房", "去银行"]
			elif hour >= 17.0 and hour < 21.0: local = ["买菜回家", "去吃晚饭", "海边散步", "去健身房"]
			elif hour >= 21.0 or hour < 6.0: local = ["吃宵夜", "散步消食", "去便利店"]
			going = "在附近：%s" % local[int(p.seed) % local.size()]
			if p.kind == "night":
				var late := hour < 6.0 or hour >= 22.0
				if p.desc.contains("外卖"): going = "%s，赶时间" % ("送夜宵单" if late else "送外卖")
				else: going = "下夜班，走路回家" if hour < 9.0 else "去上夜班"
			mood = "悠闲" if p.kind == "other" else "平静"
	if p.kind == "student": mood = "和同学约好一起走，挺开心" if hour < 12.0 else "放学了，很开心"
	if raining and not p.umbrella: mood = "没带伞，小跑着避雨"
	return {"title": who.name, "subtitle": "路人 · %s" % p.desc, "rows": [["年龄", "%d 岁" % who.age], ["身份", who.job], ["心情", mood], ["接下来", going]]}
