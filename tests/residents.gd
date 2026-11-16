extends SceneTree

func _initialize() -> void:
	var Residents = load("res://scripts/residents.gd")
	var sim = Residents.new()
	assert(sim.people.size() == 18)
	var ids: Dictionary = {}
	for person in sim.people:
		assert(not ids.has(person.character_id))
		ids[person.character_id] = true
	assert(ids.size() == 18)
	var city = load("res://scripts/city.gd").new()
	var slots: Dictionary = {}
	for person in sim.people:
		var sheet_index := floori(float(person.character_id) / 4.0)
		var row: int = person.character_id % 4
		assert(sheet_index < city.walk_sheets.size())
		var slot := Vector2i(sheet_index, row)
		assert(not slots.has(slot))
		slots[slot] = true
	city.free()
	var wallpaper_sim = load("res://wallpaper/scripts/residents.gd").new()
	assert(not wallpaper_sim.people[0].has("character_id"))
	assert(sim.people.filter(func(p): return p.promenade).size() == 6)
	assert(sim.people.filter(func(p): return p.platform).size() == 4)
	var shelter: Dictionary = sim.people[3]
	var original_x: float = shelter.x
	sim.step(0.1, 10.0, true)
	assert(shelter.state == "shelter" and shelter.mood == "避雨")
	assert(absf(shelter.x - 1028.0) < absf(original_x - 1028.0))
	assert(sim.people[2].state == "walk" and sim.people[2].mood == "下雨")
	sim.step(0.1, 11.0, false)
	assert(shelter.state == "walk")
	var march: Dictionary = sim.people[6]
	var kafka: Dictionary = sim.people[7]
	march.x = 800.0
	kafka.x = 810.0
	sim.step(0.1, 12.0, false)
	assert(march.state == "greet" and kafka.state == "greet")
	assert(march.mood == "你好" and kafka.cooldown > 0.0)
	var bus: Dictionary = sim.people[0]
	bus.x = 1100.0
	bus.state = "walk"
	sim.step(0.1, 64.0, false)
	assert(bus.state == "boarding")
	for i in range(22): sim.step(0.1, 64.0, false)
	assert(bus.state == "onboard")
	var train: Dictionary = sim.people[1]
	train.x = 1040.0
	train.state = "walk"
	sim.step(0.1, 22.0, false)
	assert(train.state == "boarding")
	# A delayed frame must advance the same walking distance as smaller steps.
	var slow = Residents.new()
	var smooth = Residents.new()
	slow.step(0.5, 4.5, false)
	for i in range(5): smooth.step(0.1, 4.1 + i * 0.1, false)
	assert(is_equal_approx(slow.people[2].x, smooth.people[2].x))
	assert(is_equal_approx(slow.people[2].walk_distance, smooth.people[2].walk_distance))
	var sheltered: Dictionary = slow.people[3]
	sheltered.x = 1028.0
	slow.step(0.1, 5.0, true)
	assert(not sheltered.moving)
	var edge: Dictionary = slow.people[2]
	edge.x = 1729.9
	edge.direction = 1
	slow.step(0.1, 6.0, false)
	assert(edge.direction == -1)
	slow.step(0.1, 6.1, false)
	assert(edge.x < 1730.0)
	var shore: Dictionary = sim.people[9]
	shore.x = 900.0
	shore.state = "walk"
	sim.step(0.1, 25.0, true)
	assert(shore.state == "shelter" and shore.x < 900.0)
	shore.x = 425.0
	for i in range(10): sim.step(0.1, 25.1 + i * 0.1, true)
	assert(shore.sit > 0.99)
	# The commuter sits while waiting, stands and reaches the door when it opens.
	var waiter_sim = Residents.new()
	var waiter: Dictionary = waiter_sim.people[0]
	waiter.x = 1046.0
	for i in range(15): waiter_sim.step(0.1, 55.0 + i * 0.1, false)
	assert(waiter.state == "wait_bus" and waiter.sit > 0.99)
	var boarded := false
	for i in range(150):
		waiter_sim.step(0.1, 56.5 + i * 0.1, false)
		if waiter.state == "boarding" or waiter.state == "onboard": boarded = true
	assert(boarded)
	# A passenger without an umbrella sits under the shelter and gets up after rain.
	var rain_sim = Residents.new()
	var rain_waiter: Dictionary = rain_sim.people[3]
	rain_waiter.x = 1028.0
	for i in range(10): rain_sim.step(0.1, 5.0 + i * 0.1, true)
	assert(rain_waiter.state == "shelter" and rain_waiter.sit > 0.99)
	for i in range(10): rain_sim.step(0.1, 7.0 + i * 0.1, false)
	assert(is_zero_approx(rain_waiter.sit) and rain_waiter.state == "walk")
	print("RESIDENT_TEST_PASSED")
	quit(0)
