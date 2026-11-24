extends RefCounted

# Real-time timetables at Huaxin station (华新站), Shenzhen.
#  metro    - Metro line 3 towards 坪地六联.
#  near_bus - Bus route 3, one direction; far_bus is the opposite direction,
#             arriving 150 s after near_bus.
# All clocks are seconds since local midnight (0 <= clock < 86400). Each
# vehicle maps the timetable onto its existing visible cycle: the bus enters
# 25 s before arriving and leaves the scene 70 s after entering; the metro
# enters 19 s before arriving and is gone 61 s after entering.

const DAY := 86400.0
const BUS_ENTER_LEAD := 25.0
const BUS_VISIBLE := 70.0
const BUS_DWELL := 8.0
const BUS_IDLE_PHASE := 69.99
const METRO_ENTER_LEAD := 19.0
const METRO_VISIBLE := 61.0
const METRO_DWELL := 23.0
const METRO_IDLE_PHASE := 80.0
const FAR_BUS_OFFSET := 150.0

static var _cache := {}

static func _hm(hours: int, minutes: int) -> float:
	return float(hours * 3600 + minutes * 60)

static func is_metro(vehicle: String) -> bool:
	return vehicle == "metro"

static func is_peak(clock: float) -> bool:
	var c := fposmod(clock, DAY)
	return (c >= _hm(7, 0) and c < _hm(9, 30)) or (c >= _hm(17, 30) and c < _hm(19, 30))

static func headway(vehicle: String, clock: float) -> float:
	var c := fposmod(clock, DAY)
	if is_peak(c): return 150.0 if is_metro(vehicle) else 300.0
	if is_metro(vehicle):
		return 480.0 if c >= _hm(21, 30) else 300.0
	if c < _hm(7, 0) or c >= _hm(21, 0): return 900.0
	return 600.0

static func first_arrival(vehicle: String) -> float:
	var a := arrivals(vehicle)
	return a[0] if a.size() > 0 else 0.0

static func last_arrival(vehicle: String) -> float:
	var a := arrivals(vehicle)
	return a[a.size() - 1] if a.size() > 0 else 0.0

static func arrivals(vehicle: String) -> PackedFloat64Array:
	if _cache.has(vehicle): return _cache[vehicle]
	var result := PackedFloat64Array()
	var first := _hm(6, 32) if is_metro(vehicle) else _hm(6, 0)
	var last := _hm(23, 38) if is_metro(vehicle) else _hm(23, 0)
	if is_metro(vehicle) or vehicle in ["near_bus", "far_bus"]:
		var t := first
		while t <= last:
			result.append(t)
			t += headway(vehicle, t)
		# The published last service always runs, even off the headway grid.
		if result.size() > 0 and result[result.size() - 1] < last: result.append(last)
		if vehicle == "far_bus":
			for i in result.size(): result[i] += FAR_BUS_OFFSET
	_cache[vehicle] = result
	return result

static func _lead(vehicle: String) -> float:
	return METRO_ENTER_LEAD if is_metro(vehicle) else BUS_ENTER_LEAD

static func _visible(vehicle: String) -> float:
	return METRO_VISIBLE if is_metro(vehicle) else BUS_VISIBLE

static func _dwell(vehicle: String) -> float:
	return METRO_DWELL if is_metro(vehicle) else BUS_DWELL

static func idle_phase(vehicle: String) -> float:
	return METRO_IDLE_PHASE if is_metro(vehicle) else BUS_IDLE_PHASE

# Index of the most recent arrival whose vehicle has entered by `clock`, or -1.
static func _recent_index(vehicle: String, clock: float) -> int:
	var a := arrivals(vehicle)
	return a.bsearch(clock + _lead(vehicle), false) - 1

static func phase(vehicle: String, clock: float) -> float:
	var a := arrivals(vehicle)
	var c := fposmod(clock, DAY)
	var i := _recent_index(vehicle, c)
	if i < 0: return idle_phase(vehicle)
	# A cycle that would straddle midnight is simply treated as idle.
	var local := c - (a[i] - _lead(vehicle))
	if local >= 0.0 and local < _visible(vehicle): return local
	return idle_phase(vehicle)

static func seconds_to_arrival(vehicle: String, clock: float) -> float:
	var a := arrivals(vehicle)
	if a.size() == 0: return INF
	var c := fposmod(clock, DAY)
	var i := a.bsearch(c, false) - 1
	if i >= 0 and c < a[i] + _dwell(vehicle): return 0.0
	if i + 1 < a.size(): return a[i + 1] - c
	return DAY - c + a[0]

static func in_service(vehicle: String, clock: float) -> bool:
	var a := arrivals(vehicle)
	if a.size() == 0: return false
	var c := fposmod(clock, DAY)
	return c >= a[0] - _lead(vehicle) and c <= a[a.size() - 1] + _dwell(vehicle)
