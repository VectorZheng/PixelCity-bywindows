extends RefCounted

# 地铁线路 / 车站预设。只改下面 CHOICE 这一个值就能换线换站：
# 站台屏、入口灯箱、站台门盖板、列车车头牌、公交电子站牌、信息卡和路人描述
# 都统一从这里取名字和线路色。线路、站名、方向都是真实深圳地铁；
# 发车时刻仍沿用同一份模拟时刻表（信息卡标注"模拟"）。
#
# 可选值："1号线·华强路"  "2号线·华强北"  "3号线·华新"  "4号线·市民中心"  "7号线·华新"
const CHOICE := "3号线·华新"

# 线路色避开紫色系（5 号线、11 号线这类紫/紫红线路不放进预设）。
const PRESETS := {
	"1号线·华强路": {"number": "1", "line": "1号线", "line_en": "Line 1", "colour": "00a54f",
		"station": "华强路", "station_en": "Huaqiang Rd", "toward": "机场东", "next": "岗厦",
		"places": ["机场东", "宝安中心", "前海湾", "车公庙", "购物公园", "罗湖"]},
	"2号线·华强北": {"number": "2", "line": "2号线", "line_en": "Line 2", "colour": "e8701e",
		"station": "华强北", "station_en": "Huaqiangbei", "toward": "莲塘", "next": "燕南",
		"places": ["莲塘", "黄贝岭", "湖贝", "燕南", "景田", "蛇口港"]},
	"3号线·华新": {"number": "3", "line": "3号线", "line_en": "Line 3", "colour": "00a2e2",
		"station": "华新", "station_en": "Huaxin", "toward": "坪地六联", "next": "通新岭",
		"places": ["老街", "布吉", "大运", "龙城广场", "双龙", "坪地六联"]},
	"4号线·市民中心": {"number": "4", "line": "4号线", "line_en": "Line 4", "colour": "dc2a1f",
		"station": "市民中心", "station_en": "Civic Center", "toward": "牛湖", "next": "少年宫",
		"places": ["福田口岸", "会展中心", "少年宫", "深圳北站", "红山", "牛湖"]},
	"7号线·华新": {"number": "7", "line": "7号线", "line_en": "Line 7", "colour": "1446b4",
		"station": "华新", "station_en": "Huaxin", "toward": "太安", "next": "黄木岗",
		"places": ["太安", "黄贝岭", "华强北", "车公庙", "西丽湖", "深云"]},
}

static func current() -> Dictionary:
	return PRESETS.get(CHOICE, PRESETS["3号线·华新"])

static func number() -> String: return str(current().number)
static func line() -> String: return str(current().line)
static func line_en() -> String: return str(current().line_en)
static func colour() -> Color: return Color(str(current().colour))
static func station() -> String: return str(current().station)
static func station_en() -> String: return str(current().station_en)
static func toward() -> String: return str(current().toward)
static func next_stop() -> String: return str(current().next)
static func places() -> Array: return current().places
# Cache key for baked roundels: one texture per line colour.
static func ring_key() -> String: return "line" + number()

# Resident profiles and day logs are written for the default line; the
# identity card passes its text through here so it follows CHOICE as well.
static func localize(text: String) -> String:
	if CHOICE == "3号线·华新": return text
	return text.replace("3 号线", line()).replace("3号线", line()).replace("华新站", station() + "站").replace("在华新下车", "在%s下车" % station()).replace("到华新", "到" + station()).replace("坪地六联", toward())
