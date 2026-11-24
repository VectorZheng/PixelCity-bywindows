extends SceneTree

# The street follows the real clock: busy peaks, near-empty small hours, and
# residents whose moods and day logs follow what happens to them.
func _initialize() -> void:
	var Traffic = load("res://scripts/traffic.gd")
	var Crowd = load("res://scripts/crowd.gd")
	var Life = load("res://scripts/life.gd")
	var Residents = load("res://scripts/residents.gd")
	var Profiles = load("res://scripts/profiles.gd")
	var obstacles := [{"lane": 0, "x": -999.0, "width": 160.0}, {"lane": 1, "x": -999.0, "width": 170.0}]
	var averages := {}
	for hour in [3.0, 8.3, 14.0]:
		var t = Traffic.new(5)
		var total := 0
		for i in range(6000):
			t.step(0.1, hour, 2172.0, obstacles)
			if i >= 1200: total += t.vehicles.size()
		averages[hour] = total / 4800.0
		for v in t.vehicles:
			if v.kind != "scooter": assert(str(v.plate).begins_with("粤B·"))
			if v.kind == "taxi" and v.passengers == 0: assert(v.destination.contains("空车"))
			var card: Dictionary = t.describe(v)
			assert(card.rows.size() >= 3)
		# Vehicles in one lane never overlap.
		for a in t.vehicles:
			for b in t.vehicles:
				if a != b and a.lane == b.lane and (a.kind == "scooter") == (b.kind == "scooter"):
					assert(absf(a.x - b.x) > 20.0)
	print("traffic on screen: 03:00 %.1f  08:18 %.1f  14:00 %.1f" % [averages[3.0], averages[8.3], averages[14.0]])
	assert(averages[3.0] < 2.0 and averages[8.3] > averages[14.0] and averages[8.3] > 6.0)
	# Crowd: peaks are dense and mostly office workers; school runs bring students; nights are empty.
	var counts := {}
	for hour in [2.5, 7.3, 8.5, 15.0]:
		var c = Crowd.new(9)
		assert(not c.looks.is_empty())
		var total := 0
		var kinds := {}
		for i in range(6000):
			c.step(0.1, hour, 2172.0, [611.0, 1561.0], false)
			if i >= 1200:
				total += c.people.size()
				for p in c.people: kinds[p.kind] = kinds.get(p.kind, 0) + 1
		counts[hour] = [total / 4800.0, kinds]
		for p in c.people:
			var card: Dictionary = c.describe(p, false)
			assert(card.rows.size() == 4 and not str(card.title).is_empty())
	print("crowd on screen: 02:30 %.1f  07:18 %.1f  08:30 %.1f  15:00 %.1f" % [counts[2.5][0], counts[7.3][0], counts[8.5][0], counts[15.0][0]])
	assert(counts[2.5][0] < 2.0 and counts[8.5][0] > 3.0 * counts[15.0][0] / 2.0)
	assert(counts[8.5][1].get("commuter", 0) > counts[8.5][1].get("student", 0) * 3)
	assert(counts[7.3][1].get("student", 0) > 0)
	assert(counts[2.5][1].get("night", 0) >= counts[2.5][1].get("commuter", 0))
	# Life: rain without an umbrella and long waits sour moods; greetings lift them.
	var sim = Residents.new()
	var life = Life.new()
	var today := {"year": 2026, "month": 11, "day": 20}
	for i in range(3000):
		var seconds := i / 10.0
		sim.step(0.1, seconds, true, 8)
		life.observe(sim.people, {"clock": 8 * 3600.0 + seconds, "raining": true, "weather_code": 63, "today": today, "hour": 8}, 0.1)
	var sheltered := 0
	for person in sim.people:
		var mood: String = life.mood_text(person, today)
		assert(not mood.is_empty())
		if not person.umbrella and not person.platform and mood.contains("雨"): sheltered += 1
		assert(not life.day_log(person).is_empty())
	assert(sheltered >= 2)
	var march: Dictionary = sim.people[6]
	var kafka: Dictionary = sim.people[7]
	# The simulation's greeting (covered by tests/residents.gd) switches both to "greet".
	march.state = "greet"; kafka.state = "greet"
	life.observe(sim.people, {"clock": 14 * 3600.0, "raining": false, "weather_code": 0, "today": today, "hour": 14}, 0.1)
	assert(life.mood_text(march, today).contains("老同学"))
	assert(life.day_log(march).contains("老同学"))
	# Waiting riders head across the city; walkers stay local.
	var rider: Dictionary = sim.people[0]
	rider.purpose = "购物"; rider.trip_mode = "bus"
	assert(Profiles.trip_destination(rider) in Profiles.FAR_PLACES)
	var walker: Dictionary = sim.people[3]
	walker.purpose = "购物"
	assert(Profiles.local_place(walker) in Profiles.LOCAL_PLACES["购物"])
	print("WORLD_TEST_PASSED")
	quit(0)
