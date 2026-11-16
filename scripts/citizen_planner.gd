extends RefCounted

# Small deterministic itinerary planner for the existing two sidewalks and platform.
# Destinations are scene landmarks, not claims about actual Shenzhen buildings.
const LANDMARKS := [
	{"name": "住宅", "x": 510.0}, {"name": "商店", "x": 820.0},
	{"name": "车站", "x": 1100.0}, {"name": "办公区", "x": 1450.0},
	{"name": "公园", "x": 1660.0}
]

static func next_trip(person: Dictionary, hour: int) -> Dictionary:
	var id: int = person.id
	var trip: int = person.trip_no
	var purpose: String
	var slot: int
	if hour >= 6 and hour < 10:
		purpose = "上班" if id % 3 != 0 else "出门"
		slot = 3 if id % 3 != 0 else 1
	elif hour >= 17 or hour < 6:
		purpose = "回家" if (trip + id) % 3 != 0 else "散步"
		slot = 0 if purpose == "回家" else 4
	else:
		purpose = ["工作", "购物", "散步", "办事"][(id + trip) % 4]
		slot = [3, 1, 4, 2][(id + trip) % 4]
	# Distinct destinations within each district keep people from stacking.
	var destination: float = clampf(float(LANDMARKS[slot].x) + float((id % 5) - 2) * 18.0, 450.0, 1710.0)
	if absf(destination - float(person.x)) < 100.0:
		slot = (slot + 2 + id % 2) % LANDMARKS.size()
		destination = float(LANDMARKS[slot].x) + float((id % 5) - 2) * 18.0
	var distance := absf(destination - float(person.x))
	var mode := "walk"
	if distance > 400.0 and (id + trip) % 4 == 0:
		mode = "metro" if person.platform else "bus"
	return {"destination": destination, "purpose": purpose, "place": LANDMARKS[slot].name, "mode": mode}
