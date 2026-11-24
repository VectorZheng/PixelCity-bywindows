extends RefCounted

# Generated identities for the 18 preview residents.
#
# Every fact is chosen to match how residents.gd actually drives that person,
# so the card never contradicts what the viewer sees:
#   * id % 3 != 0 heads to the office district in the morning (planner) -> office job
#   * id % 3 == 0 goes "出门" to the shops instead -> student / shop / freelance
#   * umbrella == (id % 2 == 0); the others shelter at a stop when it rains
#   * 0 always waits at the near stop, 8 at the waterfront stop -> bus commuters
#   * 1, 5 and 16 take line 3; 14 never leaves the platform -> station staff
#   * 6 and 7 greet each other -> old classmates; 10 is picked up by the green SUV
# Names, birthdays and homes are fictional and deterministic, not real people.

const Transit = preload("res://scripts/transit.gd")
const StationRoutes = preload("res://scripts/station_routes.gd")

const DATA := [
	{"name": "林一诺", "age": 20, "job": "大学生（深大计算机系）", "home": "园岭新村", "work": "深圳大学", "habit": "每天在近侧站坐 3 路上学"},
	{"name": "陈子墨", "age": 29, "job": "后端程序员", "home": "莲花村", "work": "车公庙的软件公司", "habit": "坐 3 号线通勤，站台上总在刷手机"},
	{"name": "周以安", "age": 34, "job": "会计", "home": "华新村", "work": "华强北的写字楼", "habit": "平时步行上班，下雨就改坐公交"},
	{"name": "许知夏", "age": 26, "job": "自由插画师", "home": "上步南", "work": "街角咖啡馆", "habit": "喜欢在咖啡馆画稿"},
	{"name": "郑可言", "age": 31, "job": "硬件工程师", "home": "通新岭", "work": "华强北电子市场", "habit": "午休时去电子市场淘元件"},
	{"name": "何以宁", "age": 28, "job": "产品经理", "home": "红岭", "work": "购物公园附近的公司", "habit": "坐 3 号线进出华新站"},
	{"name": "宋小满", "age": 22, "job": "摄影专业研究生", "home": "华新村", "work": "学校工作室", "habit": "常和老同学偶遇聊两句"},
	{"name": "顾清和", "age": 27, "job": "游戏策划", "home": "园岭新村", "work": "华强北的游戏工作室", "habit": "和宋小满是高中同学"},
	{"name": "梁书言", "age": 33, "job": "银行柜员", "home": "滨海花园", "work": "福田的银行网点", "habit": "每天在海边站坐 3 路"},
	{"name": "罗安然", "age": 30, "job": "咖啡店店长", "home": "红荔西", "work": "海边的咖啡店", "habit": "开店前沿海边走一走"},
	{"name": "唐景行", "age": 32, "job": "律所助理", "home": "滨海花园", "work": "福田中心区的律所", "habit": "家人每天开绿色 SUV 来接"},
	{"name": "沈若溪", "age": 25, "job": "平面设计师", "home": "红荔西", "work": "设计工作室", "habit": "海边散步找灵感"},
	{"name": "韩一舟", "age": 27, "job": "健身教练", "home": "华富村", "work": "公园旁的健身房", "habit": "每天在海边慢跑热身"},
	{"name": "苏念", "age": 24, "job": "市场专员", "home": "华富村", "work": "华强北的品牌公司", "habit": "下班后在海边吹吹风"},
	{"name": "江未来", "age": 35, "job": "华新站站务员", "home": "老街", "work": "华新站", "habit": "在站台上来回巡视"},
	{"name": "白露", "age": 23, "job": "便利店店员", "home": "上步南", "work": "路口便利店", "habit": "轮班前在附近买早餐"},
	{"name": "陆嘉树", "age": 30, "job": "电子元件采购", "home": "布吉", "work": "华强北电子市场", "habit": "坐 3 号线来华强北谈货"},
	{"name": "叶星河", "age": 26, "job": "列车调度实习生", "home": "石厦", "work": "华新站", "habit": "在站台记录列车到发时间"},
]

const FRIENDS := {6: 7, 7: 6}

# Riders go far: bus route 3 and line 3 connect to the whole city.
const FAR_PLACES := ["深圳北站", "宝安机场", "福田口岸", "罗湖口岸", "南山科技园", "前海", "蛇口", "大梅沙",
	"世界之窗", "欢乐谷", "深圳湾公园", "龙华", "坂田", "西丽大学城", "东门老街", "华侨城", "会展中心",
	"莲花山", "盐田", "车公庙", "购物公园", "香蜜湖", "光明", "坪山"]
# Line 3 at Huaxin heads east; further trips change lines.
const METRO_PLACES := ["老街", "布吉", "大运", "龙城广场", "双龙", "坪地六联", "红岭",
	"晒布", "草埔", "横岗", "老街换1号线去罗湖口岸", "布吉换5号线去深圳北站"]
# People on foot stay local.
const LOCAL_PLACES := {
	"购物": ["街角便利店", "华强北商场", "菜市场", "奶茶店", "楼下水果店"],
	"办事": ["银行网点", "华强北电子市场", "快递驿站", "社区服务中心", "手机维修店"],
	"散步": ["红荔路", "海边步道", "荔枝公园", "街心花园"],
}

static func _pick(list: Array, person: Dictionary) -> String:
	return str(list[(int(person.id) * 7 + int(person.trip_no) * 13) % list.size()])

static func local_place(person: Dictionary) -> String:
	var p := profile(person.id)
	match str(person.purpose):
		"回家": return "%s的家" % p.home
		"上班", "工作": return str(p.work)
	if LOCAL_PLACES.has(str(person.purpose)): return _pick(LOCAL_PLACES[str(person.purpose)], person)
	return "附近"

# Where a trip that uses the bus or metro is heading.
static func trip_destination(person: Dictionary) -> String:
	var p := profile(person.id)
	if person.purpose in ["上班", "工作"]: return str(p.work)
	if person.purpose == "回家": return str(p.home)
	if person.platform or person.trip_mode == "metro" or person.state in ["approach_metro", "escalator_down"]: return _pick(METRO_PLACES, person)
	return _pick(FAR_PLACES, person)

const MOODS := {
	"开心": "开心", "悠闲": "悠闲", "期待": "有点期待", "放松": "放松",
	"下雨": "撑着伞，嫌雨有点大", "避雨": "在躲雨，盼着雨停", "休息": "走累了，歇一歇",
	"你好": "遇到熟人，很高兴", "乘车": "赶车中", "出站": "刚下车，精神不错",
}

static func profile(id: int) -> Dictionary:
	var base: Dictionary = DATA[id].duplicate()
	base.id = id
	base.month = (id * 7 + 3) % 12 + 1
	base.day = (id * 11 + 5) % 28 + 1
	base.umbrella = id % 2 == 0
	base.office = id % 3 != 0
	return base

static func birthday_text(p: Dictionary, today: Dictionary) -> String:
	var year := int(today.get("year", 2026)) - int(p.age)
	# Age is "as of today": anyone whose birthday is still ahead was born a year earlier.
	if int(today.get("month", 1)) < p.month or (int(today.get("month", 1)) == p.month and int(today.get("day", 1)) < p.day):
		year -= 1
	var text := "%d年%d月%d日" % [year, p.month, p.day]
	if is_birthday(p, today): text += "（今天生日）"
	return text

static func is_birthday(p: Dictionary, today: Dictionary) -> bool:
	return int(today.get("month", 0)) == p.month and int(today.get("day", 0)) == p.day

static func mood_text(person: Dictionary, p: Dictionary, today: Dictionary) -> String:
	var text: String = MOODS.get(person.mood, str(person.mood))
	if is_birthday(p, today) and person.mood not in ["下雨", "避雨"]: text = "今天生日，心情特别好"
	return text

static func _place(person: Dictionary, p: Dictionary) -> String:
	match str(person.place):
		"住宅": return "%s的家" % p.home if person.purpose == "回家" else "住宅区"
		"办公区": return str(p.work) if person.purpose in ["上班", "工作"] else "办公区"
		"商店": return "商店街"
		"车站": return "车站附近"
		"公园": return "海边公园" if person.promenade else "公园"
	return "附近"

# A short, live description of what the resident is about to do, derived from
# the current simulation state so it changes as the behaviour changes.
static func next_action(person: Dictionary, seconds: float, people: Array) -> String:
	var p := profile(person.id)
	match str(person.state):
		"wait_bus", "approach_stop":
			var far: bool = person.promenade
			var arrival := Transit.bus_arrival_for("far_bus" if far else "near_bus", seconds)
			var where := "海边站" if far else "近侧公交站"
			if person.state == "approach_stop": return "下雨了，改去%s坐公交" % where
			var dest := trip_destination(person)
			if arrival == 0: return "3 路到站了，上车去%s" % dest
			return "在%s等 3 路去%s，%s" % [where, dest, "约 %d 秒后到" % arrival if arrival < 120 else "还要等 %d 分钟" % ceili(arrival / 60.0)]
		"stand_up":
			if person.wait_at_stop or person.wait_at_far_stop: return "车来了，起身准备上车"
			return "雨小了，起身继续赶路"
		"boarding": return "登上 3 号线列车，去%s" % trip_destination(person) if person.platform else "上公交，去%s" % trip_destination(person)
		"alighting": return "刚到华新，下车后%s" % ("回家" if person.purpose == "回家" else "去附近%s" % local_place(person))
		"shelter":
			return "没带伞，坐在站棚里等雨停" if person.sit > 0.5 else "没带伞，在站棚下躲雨"
		"fold_umbrella": return "到站了，先把伞收起来"
		"look_board": return "看站牌上的到站时间"
		"car_pickup": return "等家人开绿色 SUV 来接"
		"car_boarding": return "上车回家" if person.purpose == "回家" else "上车，去%s" % p.work
		"car_exit": return "下车，步行去目的地"
		"greet":
			var friend: int = FRIENDS.get(person.id, -1)
			return "和老同学%s打招呼" % DATA[friend].name if friend >= 0 else "和熟人打招呼"
		"idle":
			return "在%s歇一会儿" % _place(person, p) if person.purpose == "散步" else "到了%s，停下来看看" % _place(person, p)
		"approach_metro": return "去华新站坐 3 号线，到%s" % trip_destination(person)
		"metro_fold_umbrella": return "进站前收伞"
		"enter_metro": return "走进华新站入口"
		"escalator_down": return "乘扶梯下到站台"
		"approach_exit": return "下了车，走向出站扶梯"
		"escalator_up": return "乘扶梯回到地面"
		"exit_metro": return "走出地铁口"
	# Walking: describe the current trip from the planner's purpose and mode.
	if person.platform:
		if person.id == 14: return "在站台来回巡视"
		if person.id == 17: return "在站台记录列车到发"
		if person.id == 1 or person.trip_mode == "metro": return "在站台等 3 号线，去%s" % trip_destination(person)
		return "在站台上走动，等下一班车"
	if person.trip_mode == "bus" or person.wait_at_stop or person.wait_at_far_stop:
		return "走去公交站，准备坐 3 路去%s" % trip_destination(person)
	var purpose := str(person.purpose)
	if purpose == "出门" or person.destination < 0.0: return "出门走走，在附近逛逛"
	match purpose:
		"购物": return "去附近的%s买东西" % local_place(person)
		"办事": return "去附近的%s办事" % local_place(person)
		"散步": return "在%s一带散步" % local_place(person)
		"回家": return "步行回家（%s）" % p.home
	return "%s：步行去%s" % [purpose, local_place(person)]

static func card_lines(person: Dictionary, seconds: float, people: Array, today: Dictionary, life = null) -> Array:
	var p := profile(person.id)
	return [
		["年龄", "%d 岁" % p.age],
		["生日", birthday_text(p, today)],
		["工作", "%s · %s" % [p.job, p.work]],
		["家", str(p.home)],
		["心情", life.mood_text(person, today) if life else mood_text(person, p, today)],
		["接下来", next_action(person, seconds, people)],
		["今天", life.day_log(person) if life else "刚出门"],
		["习惯", ("出门总带伞" if p.umbrella else "常忘带伞，下雨就去站棚躲") + "；" + str(p.habit)],
	]
