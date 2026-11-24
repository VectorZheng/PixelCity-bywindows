extends RefCounted

# Street traffic that follows the real clock: almost empty in the small hours,
# dense and slower in the morning and evening peaks. Every vehicle carries a
# small identity (type, Shenzhen plate, destination anywhere in the city,
# passengers) for the hover card. Positions are in scene coordinates.

const Profiles = preload("res://scripts/profiles.gd")

# Lane 0: waterfront side, travelling right. Lane 1: near side, travelling left.
const LANES := [{"y": 472.5, "dir": 1}, {"y": 504.7, "dir": -1}]
const KINDS := {
	"taxi": {"name": "比亚迪纯电出租车", "length": 90.0, "height": 28.5, "speed": 66.0},
	"car": {"name": "私家车", "length": 90.0, "height": 28.5, "speed": 62.0},
	"suv": {"name": "私家 SUV", "length": 88.0, "height": 31.5, "speed": 58.0},
	"scooter": {"name": "外卖电动车", "length": 32.0, "height": 26.0, "speed": 38.0},
}
const CAR_COLOURS := ["white", "black", "silver", "yellow", "white", "silver", "black"]
const SURNAMES := "王李张刘陈杨黄赵吴周徐孙马朱胡郭何林罗梁"

var vehicles: Array = []
var _spawn_timers := [0.0, 2.5]
var _next_id := 0
var _rng := RandomNumberGenerator.new()

func _init(seed_value: int = 20261120) -> void:
	_rng.seed = seed_value

# Vehicles per minute per lane, by hour of day.
static func density(hour: float) -> float:
	var keys := [[0.0, 1.6], [1.0, 0.6], [4.5, 0.45], [6.0, 2.6], [7.2, 11.0], [8.3, 14.0], [9.6, 8.0],
		[12.0, 9.0], [16.5, 9.0], [18.0, 14.0], [19.5, 10.0], [21.5, 6.0], [23.0, 3.2], [24.0, 1.6]]
	for i in range(keys.size() - 1):
		if hour >= keys[i][0] and hour < keys[i + 1][0]:
			return lerpf(keys[i][1], keys[i + 1][1], smoothstep(keys[i][0], keys[i + 1][0], hour))
	return 1.6

static func congestion(hour: float) -> float:
	# Peak traffic crawls; free flow at night.
	return clampf((density(hour) - 8.0) / 6.0, 0.0, 1.0)

func _pick_kind(hour: float) -> String:
	var meal := (hour >= 10.8 and hour < 13.2) or (hour >= 17.0 and hour < 20.5)
	var night := hour < 5.5 or hour >= 23.0
	var r := _rng.randf()
	var scooter := 0.28 if meal else (0.22 if night else 0.12)
	var taxi := 0.55 if night else 0.3
	if r < scooter: return "scooter"
	if r < scooter + taxi: return "taxi"
	return "suv" if _rng.randf() < 0.3 else "car"

func _plate(kind: String) -> String:
	# Shenzhen plates start 粤B; new-energy plates carry a D (pure electric) after it.
	# The last character is always masked as "x" so no real plate is shown.
	var letters := "ABCDEFGHJKLMNPQRSTUVWXYZ"
	var digits := "%04dx" % _rng.randi_range(0, 9999)
	if kind == "taxi": return "粤B·D%s" % digits
	if _rng.randf() < 0.55: return "粤B·%s%s" % ["D" if _rng.randf() < 0.8 else "F", digits]
	return "粤B·%s%s" % [letters[_rng.randi_range(0, letters.length() - 1)], digits.substr(1)]

func _spawn(lane: int, hour: float, width: float) -> void:
	var kind := _pick_kind(hour)
	var spec: Dictionary = KINDS[kind]
	var dir: int = LANES[lane].dir
	var x: float = -float(spec.length) - 20.0 if dir > 0 else width + 20.0
	# Keep a gap behind the last vehicle that entered this lane.
	for v in vehicles:
		if v.lane == lane and absf(v.x - x) < spec.length + 40.0: return
	var passengers := 0
	var destination := ""
	match kind:
		"taxi":
			var hired := _rng.randf() < (0.75 if hour >= 7.0 and hour < 23.0 else 0.5)
			passengers = _rng.randi_range(1, 3) if hired else 0
			destination = Profiles.FAR_PLACES[_rng.randi_range(0, Profiles.FAR_PLACES.size() - 1)] if hired else "空车，路边找客"
		"scooter":
			passengers = 1
			destination = "送外卖到%s" % ["华强北写字楼", "园岭新村", "上步南小区", "华新村", "红荔路公寓", "通新岭"][_rng.randi_range(0, 5)]
		_:
			passengers = _rng.randi_range(1, 4)
			destination = Profiles.FAR_PLACES[_rng.randi_range(0, Profiles.FAR_PLACES.size() - 1)]
	vehicles.append({
		"id": _next_id, "kind": kind, "lane": lane, "x": x, "speed": spec.speed * 0.8,
		"cruise": spec.speed * _rng.randf_range(0.85, 1.15), "length": spec.length, "height": spec.height,
		"colour": "blue" if kind == "taxi" else CAR_COLOURS[_rng.randi_range(0, CAR_COLOURS.size() - 1)],
		"rider": _rng.randi_range(0, 1), "plate": "" if kind == "scooter" else _plate(kind),
		"destination": destination, "passengers": passengers, "pass": 0.0,
		"driver": "%s师傅" % SURNAMES[_rng.randi_range(0, SURNAMES.length() - 1)],
	})
	_next_id += 1

# obstacles: [{lane, x, width}] — stopped buses and the scripted pickup car,
# which flow traffic passes by swinging into the neighbouring lane.
func step(dt: float, hour: float, width: float, obstacles: Array) -> void:
	var rate := density(hour) / 60.0
	for lane in range(2):
		_spawn_timers[lane] -= dt
		if _spawn_timers[lane] <= 0.0:
			_spawn(lane, hour, width)
			_spawn_timers[lane] = -log(maxf(_rng.randf(), 0.02)) / maxf(rate, 0.001) + 1.2
	var slow := 1.0 - 0.45 * congestion(hour)
	for v in vehicles:
		var dir: int = LANES[v.lane].dir
		var desired: float = v.cruise * slow
		# Follow the vehicle ahead in the same lane (scooters ride at the kerb).
		var gap := INF
		var ahead_speed := desired
		for other in vehicles:
			if other == v or other.lane != v.lane or (other.kind == "scooter") != (v.kind == "scooter"): continue
			var d: float = (other.x - v.x) * dir
			if d > 0.0:
				var g: float = d - (other.length if dir > 0 else v.length)
				if g < gap:
					gap = g
					ahead_speed = other.speed
		if gap < 70.0: desired = minf(desired, ahead_speed * clampf((gap - 12.0) / 58.0, 0.0, 1.0) + 2.0)
		v.speed = move_toward(v.speed, desired, (60.0 if desired < v.speed else 25.0) * dt)
		v.x += v.speed * dir * dt
		# Pass stopped buses / the pickup car smoothly, like the scripted cars do.
		var swing := 0.0
		if v.kind != "scooter":
			for o in obstacles:
				if o.lane != v.lane: continue
				var relative: float = (v.x + v.length * 0.5 - (o.x + o.width * 0.5)) * dir
				swing = maxf(swing, smoothstep(-o.width * 0.5 - 150.0, -o.width * 0.5 - 40.0, relative) * (1.0 - smoothstep(o.width * 0.5 + 20.0, o.width * 0.5 + 110.0, relative)))
		v.pass = swing
	vehicles = vehicles.filter(func(v): return v.x > -260.0 and v.x < width + 260.0)

func describe(v: Dictionary) -> Dictionary:
	var spec: Dictionary = KINDS[v.kind]
	var rows := []
	if v.plate != "": rows.append(["车牌", v.plate])
	match v.kind:
		"taxi":
			rows.append(["司机", v.driver])
			rows.append(["状态", "载客 %d 人" % v.passengers if v.passengers > 0 else "空车"])
			rows.append(["目的地", v.destination])
		"scooter":
			rows.append(["平台", "美团" if v.rider == 0 else "饿了么"])
			rows.append(["任务", v.destination])
		_:
			rows.append(["车上", "%d 人" % v.passengers])
			rows.append(["目的地", v.destination])
	rows.append(["车速", "%d km/h" % int(v.speed * 0.9)])
	return {"title": spec.name, "subtitle": "往%s方向" % ("福田中心区" if LANES[v.lane].dir > 0 else "罗湖"), "rows": rows}
