extends SceneTree

func _initialize() -> void:
	var Residents = load("res://scripts/residents.gd")
	var sim = Residents.new()
	var shelter: Dictionary = sim.people[3]
	var original_x: float = shelter.x
	sim.step(0.1, 10.0, true)
	assert(shelter.state == "shelter" and shelter.mood == "避雨")
	assert(absf(shelter.x - 1080.0) < absf(original_x - 1080.0))
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
	bus.x = 1060.0
	bus.state = "walk"
	sim.step(0.1, 64.0, false)
	assert(bus.state == "boarding")
	for i in range(22): sim.step(0.1, 64.0, false)
	assert(bus.state == "onboard")
	var train: Dictionary = sim.people[1]
	train.x = 1040.0
	train.state = "walk"
	sim.step(0.1, 20.0, false)
	assert(train.state == "boarding")
	print("RESIDENT_TEST_PASSED")
	quit(0)
