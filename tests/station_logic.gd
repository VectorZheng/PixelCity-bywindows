extends SceneTree

func _initialize() -> void:
	var Transit = load("res://scripts/transit.gd")
	var Station = load("res://scripts/station.gd")
	var Residents = load("res://scripts/residents.gd")
	var Routes = load("res://scripts/station_routes.gd")
	var city = load("res://scripts/city.gd").new()
	# Both entrances stay above their own stairs after resizing; the bottom
	# landing reaches the platform, rather than ending in the track or the wall.
	for size in [Vector2(1500, 500), Vector2(1920, 1080), Vector2(2880, 1800), Vector2(1600, 1000)]:
		for mode in ["fit", "sky"]:
			var shift: float = city._station_shift(size, Vector2(2172, 724), mode)
			for right in [false, true]:
				var stairs: PackedVector2Array = Station.escalator_points(right, shift)
				assert(is_equal_approx(stairs[0].y, Routes.STREET_Y))
				assert(is_equal_approx(stairs[-1].y, Station.WALK_Y))
				var canopy: PackedVector2Array = city._entrance_outline(right, shift)
				var under_roof := Vector2((stairs[0].x + stairs[1].x) / 2.0, 548)
				assert(Geometry2D.is_point_in_polygon(under_roof, canopy))
	assert(Station.WALK_Y > Station.THRESHOLD)
	assert(Station.TRAIN_Y + 55.5 <= Station.THRESHOLD)
	assert(Station.BOARD_Y < Station.THRESHOLD)
	var centers: Array[float] = Station.door_centers(2172)
	for center in Transit.platform_door_centers(): assert(centers.has(center))
	# Every allowed crossing remains stationary and fully open for its duration.
	for vehicle in ["metro", "near_bus", "far_bus"]:
		for tick in range(2000):
			var time := tick / 10.0
			if not Transit.passenger_crossing_allowed(time, vehicle): continue
			for elapsed in [0.0, 0.5, 1.0, 1.5, 2.0]:
				var door_time: float = time + elapsed
				if vehicle == "metro":
					assert(is_equal_approx(Transit.train_doors(door_time), 1.0))
					assert(is_equal_approx(Transit.train_position(door_time, 2172), 750.0))
				else:
					door_time += 32.0 if vehicle == "near_bus" else 8.0
					assert(is_equal_approx(Transit.bus_doors(door_time), 1.0))
	assert(not Transit.passenger_crossing_allowed(21.9, "metro"))
	assert(not Transit.passenger_crossing_allowed(36.0, "metro"))
	assert(not Transit.passenger_crossing_allowed(67.0, "near_bus"))
	assert(not Transit.passenger_crossing_allowed(21.0, "far_bus"))
	# Late arrival must wait for the next cycle, even when exactly at the doorway.
	var sim = Residents.new()
	var passenger: Dictionary = sim.people[1]
	passenger.x = Residents.METRO_DOOR_X
	passenger.state = "walk"
	sim.step(0.1, 38.9, false)
	assert(passenger.state != "boarding")
	sim.step(0.1, 122.5, false)
	assert(passenger.state == "boarding")
	# Check actual citizen states across complete cycles, not just helper values.
	sim = Residents.new()
	var crossings := 0
	for tick in range(4000):
		var time := tick / 10.0
		sim.step(0.1, time, false)
		for person in sim.people:
			if person.state not in ["boarding", "alighting"]: continue
			crossings += 1
			if person.platform:
				assert(is_equal_approx(Transit.train_doors(time), 1.0))
			else:
				assert(is_equal_approx(Transit.bus_doors(time + (8 if person.promenade else 32)), 1.0))
	assert(crossings > 0)
	# Follow a complete street -> entrance -> escalator -> platform trip, and
	# its reverse. The same geometry is used by the simulation and renderer.
	for shift in [0.0, 400.0, 526.0]:
		# Only this side's entrance remains: its down escalator follows the art,
		# and the up escalator runs right behind it, offset by UP_OFFSET.
		var upper: Vector2 = Station._escalator_vertex(Vector2(185, 149), false, shift)
		var lower: Vector2 = Station._escalator_vertex(Vector2(2040, 673), false, shift)
		assert(upper.is_equal_approx(Routes.escalator_position(0, true, shift)))
		assert(lower.is_equal_approx(Routes.escalator_position(1, true, shift)))
		assert((upper + Routes.UP_OFFSET).is_equal_approx(Routes.escalator_position(1, false, shift)))
		assert((lower + Routes.UP_OFFSET).is_equal_approx(Routes.escalator_position(0, false, shift)))
		assert(is_equal_approx(Routes.access_x(true, shift), Routes.access_x(false, shift)))
		var route_sim = Residents.new()
		route_sim.station_shift = shift
		var down: Dictionary = route_sim.people[16]
		down.x = Routes.access_x(true, shift)
		down.state = "walk"
		down.station_due = 0.0
		var up: Dictionary = route_sim.people[5]
		up.x = Routes.escalator_position(0, false, shift).x
		up.state = "walk"
		up.station_due = 0.0
		var states: Dictionary = {}
		var previous_progress := 0.0
		for tick in range(420):
			route_sim.step(0.1, tick / 10.0, true)
			states[down.state] = true
			states[up.state] = true
			if down.state == "escalator_down":
				assert(down.escalator_progress >= previous_progress)
				previous_progress = down.escalator_progress
				var position: Vector2 = Routes.escalator_position(down.escalator_progress, true, shift)
				assert(is_equal_approx(position.x, down.x))
				assert(position.y >= Routes.STREET_Y and position.y <= Routes.PLATFORM_Y)
				assert(is_zero_approx(down.umbrella_open) and not down.moving)
		assert(states.has("metro_fold_umbrella") and states.has("enter_metro"))
		assert(states.has("escalator_down") and states.has("escalator_up") and states.has("exit_metro"))
		assert(down.platform and not up.platform)
		assert(route_sim.people.size() == 18)
	city.free()
	print("STATION_LOGIC_TEST_PASSED")
	quit(0)
