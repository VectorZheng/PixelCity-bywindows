extends SceneTree

func _initialize() -> void:
	var Residents = load("res://scripts/residents.gd")
	var Planner = load("res://scripts/citizen_planner.gd")
	var sim = Residents.new()
	var morning: Dictionary = Planner.next_trip(sim.people[3], 8)
	var night: Dictionary = Planner.next_trip(sim.people[3], 22)
	assert(morning.purpose != night.purpose)
	assert(morning.destination != night.destination)
	var passenger: Dictionary = sim.people[0]
	passenger.state = "onboard"
	passenger.vehicle = "near_bus"
	passenger.ride_elapsed = 0.0
	# The vehicle has departed: the rider must not reappear after a fixed delay.
	for i in range(100): sim.step(0.1, 65.0 + i * 0.1, false, 12)
	assert(passenger.state == "onboard")
	var got_off := false
	var trips: Dictionary = {}
	var modes: Dictionary = {}
	var riders: Dictionary = {}
	for i in range(6000):
		var t := 75.0 + i * 0.1
		sim.step(0.1, t, false, 12)
		if passenger.state == "alighting":
			got_off = true
			var phase := fposmod(t + 32.0, 70.0)
			assert(phase >= 26.5 and phase < 32.0)
		for p in sim.people:
			# Station users can walk to the end entrances in the uncropped layout.
			assert(p.x >= (0.0 if p.id in [5, 16] else 440.0))
			assert(p.x <= (2172.0 if p.id in [5, 16] else 1730.0))
			if p.trip_no > 0: trips[p.id] = true
			if p.vehicle != "":
				modes[p.vehicle] = true
				riders[p.id] = true
	assert(got_off)
	assert(trips.size() == 18)
	assert(modes.has("near_bus") and modes.has("far_bus") and modes.has("metro"))
	assert(riders.size() > 3)
	var seen: Dictionary = {}
	for p in sim.people:
		assert(not seen.has(p.character_id))
		seen[p.character_id] = true
	print("CITIZEN_SIMULATION_TEST_PASSED")
	quit(0)
