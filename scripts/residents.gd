extends RefCounted

# Positions are in original artwork coordinates. The simulation remains independent
# of rendering and can be stepped deterministically in tests.
const Planner = preload("res://scripts/citizen_planner.gd")
const Transit = preload("res://scripts/transit.gd")
const StationRoutes = preload("res://scripts/station_routes.gd")
const METRO_DOOR_X := 1057.56
const FAR_SHELTER_X := 600.0
const FAR_DOOR_X := 700.0
const FAR_BUS_X := 634.4
var people: Array[Dictionary] = []
var station_shift := 0.0

func _init() -> void:
	for i in range(18):
		var promenade := i >= 8 and i <= 13
		var platform := i in [1, 5, 14, 17]
		var x := (470.0 + (i - 8) * 220.0) if promenade else (990.0 if i < 2 else 480.0 + fposmod(i * 211.0, 1230.0))
		people.append({"id": i, "character_id": i, "platform": platform, "promenade": promenade, "x": x,
			"direction": 1 if i % 2 == 0 else -1, "state": "walk", "timer": 0.0,
			"cooldown": 0.0, "umbrella": i % 2 == 0, "mood": "开心",
			"walk_distance": 0.0, "moving": false, "idle_due": 8.0 + i * 3.7,
			"sit": 0.0, "wait_cooldown": 0.0, "wait_at_stop": i == 0, "wait_at_far_stop": i == 8,
			"umbrella_open": 1.0, "stop_cooldown": 0.0, "destination": -1.0, "trip_no": 0, "purpose": "出门", "place": "", "trip_mode": "walk", "vehicle": "", "ride_elapsed": 0.0})
		people[-1].station_due = 0.0 if i == 16 else 12.0
		people[-1].escalator_progress = 0.0
	people[16].x = 600.0

func step(delta: float, seconds: float, raining: bool, hour: int = 12) -> void:
	# Substep long frames rather than discarding elapsed time. Use the matching
	# simulation timestamp for each substep so vehicle windows remain aligned.
	var remaining := maxf(delta, 0.0)
	while remaining > 0.000001:
		var dt := minf(remaining, 0.1)
		remaining -= dt
		_step_once(dt, seconds - remaining, raining, hour)

func _step_once(dt: float, seconds: float, raining: bool, hour: int) -> void:
	for p in people:
		var old_x: float = p.x
		_update_person(p, dt, seconds, raining, hour)
		var distance: float = absf(p.x - old_x)
		# Teleports after a ride are scene transitions, not steps.
		if distance <= 30.0 * dt + 0.001:
			p.walk_distance += distance
			p.moving = distance > 0.00001
		else:
			p.moving = false
		if p.state in StationRoutes.ESCALATOR_STATES:
			p.moving = false
	_check_greetings()

func _update_person(p: Dictionary, dt: float, seconds: float, raining: bool, hour: int) -> void:
	p.cooldown = maxf(0.0, p.cooldown - dt)
	p.wait_cooldown = maxf(0.0, p.wait_cooldown - dt)
	p.stop_cooldown = maxf(0.0, p.stop_cooldown - dt)
	if _update_station_trip(p, dt, seconds, raining): return
	# A second commuter arrives with an umbrella, folds it, then reads the sign.
	if p.state in ["fold_umbrella", "look_board"]:
		p.timer -= dt
		if p.state == "fold_umbrella":
			p.umbrella_open = clampf(p.timer / 2.0, 0.0, 1.0)
			if p.timer <= 0.0:
				p.state = "look_board"
				p.timer = 5.0
		else:
			p.umbrella_open = 0.0
			if p.timer <= 0.0:
				p.state = "walk"
				p.stop_cooldown = 30.0
		return
	p.umbrella_open = move_toward(p.umbrella_open, 1.0, dt * 0.7)
	if raining and p.id == 2 and p.stop_cooldown <= 0.0:
		p.state = "approach_stop"
		p.mood = "期待"
		p.direction = 1
		p.x = move_toward(p.x, 1120.0, 12.0 * dt)
		if absf(p.x - 1120.0) < 0.5:
			p.state = "fold_umbrella"
			p.timer = 2.0
		return
	if p.state == "car_boarding":
		p.timer -= dt
		if p.timer <= 0.0:
			p.state = "car_onboard"
			p.timer = 20.0
		return
	if p.state == "car_onboard":
		p.timer -= dt
		if p.timer <= 0.0 and fposmod(seconds, 60.0) >= 25.0 and fposmod(seconds, 60.0) < 30.0:
			p.state = "car_exit"
			p.timer = 2.0
		return
	if p.state == "car_exit":
		p.timer -= dt
		if p.timer <= 0.0:
			p.state = "walk"
			p.stop_cooldown = 20.0
		return
	var pickup_phase := fposmod(seconds, 60.0)
	# Pickup belongs to the waterfront sidewalk beside the green car. Never
	# route a passenger diagonally across both traffic lanes or a station roof.
	if p.id == 10 and p.state not in ["onboard", "boarding", "alighting"] and p.stop_cooldown <= 0.0 and pickup_phase >= 12.0 and pickup_phase < 31.0:
		p.state = "car_pickup"
		p.mood = "期待"
		if absf(p.x - 1340.0) > 0.5: p.direction = 1 if 1340.0 > p.x else -1
		p.x = move_toward(p.x, 1340.0, 15.0 * dt)
		if pickup_phase >= 26.0 and absf(p.x - 1340.0) < 1.0:
			p.state = "car_boarding"
			p.timer = 2.0
		return
	if p.state == "onboard":
		# A passenger remains with the vehicle until the next actual open-door stop.
		p.ride_elapsed += dt
		var doors_open: bool = Transit.passenger_crossing_allowed(seconds, p.vehicle)
		if p.ride_elapsed > 20.0 and doors_open:
			p.state = "alighting"
			p.timer = Transit.PASSENGER_TRANSITION_SECONDS
			p.x = FAR_DOOR_X if p.vehicle == "far_bus" else (1100.0 if p.vehicle == "near_bus" else METRO_DOOR_X)
		return
	if p.state == "alighting":
		p.timer -= dt
		if p.timer <= 0.0:
			p.state = "walk"
			p.wait_cooldown = 30.0
			p.wait_at_stop = false
			p.wait_at_far_stop = false
			p.trip_mode = "walk"
			p.vehicle = ""
		return
	if p.state in ["greet", "boarding", "idle"]:
		p.timer -= dt
		if p.state == "boarding":
			p.x = move_toward(p.x, FAR_DOOR_X if p.promenade else (1100.0 if not p.platform else METRO_DOOR_X), 16.0 * dt)
		if p.timer <= 0.0:
			if p.state == "boarding":
				p.vehicle = "metro" if p.platform else ("far_bus" if p.promenade else "near_bus")
				p.ride_elapsed = 0.0
				p.state = "onboard"
			else:
				p.state = "walk"
		return

	var bus_phase := fposmod(seconds + 32.0, 70.0)
	var train_phase := fposmod(seconds, 100.0)
	var far_bus_phase := fposmod(seconds + 8.0, 70.0)
	var far_boarding: bool = p.wait_at_far_stop and p.wait_cooldown <= 0.0 and far_bus_phase >= 22.0 and far_bus_phase < 31.0
	if p.wait_at_far_stop and p.wait_cooldown <= 0.0:
		p.mood = "期待"
		var far_target := FAR_DOOR_X if far_boarding else 656.0
		if absf(p.x - far_target) > 0.5: p.direction = 1 if far_target > p.x else -1
		if far_boarding and p.sit > 0.0:
			p.state = "stand_up"
			p.sit = move_toward(p.sit, 0.0, 1.4 * dt)
			return
		p.state = "wait_bus"
		p.x = move_toward(p.x, far_target, 17.0 * dt)
		p.sit = move_toward(p.sit, 1.0 if not far_boarding and absf(p.x - far_target) < 0.5 else 0.0, 1.4 * dt)
		if far_boarding and Transit.passenger_crossing_allowed(seconds, "far_bus") and absf(p.x - far_target) < 1.0:
			p.state = "boarding"
			p.timer = Transit.PASSENGER_TRANSITION_SECONDS
		return
	var should_board: bool = p.wait_at_stop and p.wait_cooldown <= 0.0 and bus_phase >= 24.0 and bus_phase < 31.0
	# One commuter deliberately waits at the bus shelter; stand before boarding.
	if p.wait_at_stop and p.wait_cooldown <= 0.0 and not should_board:
		p.state = "wait_bus"
		p.mood = "期待"
		var seat_x := 1046.0
		if absf(p.x - seat_x) > 0.5:
			p.direction = 1 if seat_x > p.x else -1
			p.x = move_toward(p.x, seat_x, 14.0 * dt)
			p.sit = move_toward(p.sit, 0.0, 1.4 * dt)
		else:
			p.sit = move_toward(p.sit, 1.0, 1.4 * dt)
		return
	if raining and not p.platform and not p.umbrella:
		p.state = "shelter"
		p.mood = "避雨"
		# The near shelter has three seats, including the regular bus waiter.
		# Additional people stand under its roof instead of sharing a seat.
		var can_sit: bool = p.id in [3, 7, 9, 11, 13]
		var seat_locations := {3: 1028.0, 7: 1068.0, 9: 631.0, 11: 678.0, 13: 700.0, 15: 1088.0}
		var shelter_x: float = float(seat_locations[p.id]) if can_sit else ((631.0 + (p.id % 4) * 18.0) if p.promenade else 1030.0 + (p.id % 6) * 20.0)
		if absf(p.x - shelter_x) > 0.5: p.direction = 1 if shelter_x > p.x else -1
		p.x = move_toward(p.x, shelter_x, 15.0 * dt)
		p.sit = move_toward(p.sit, 1.0 if can_sit and absf(p.x - shelter_x) < 0.5 else 0.0, 1.4 * dt)
		return
	if p.sit > 0.0:
		p.state = "stand_up"
		p.sit = move_toward(p.sit, 0.0, 1.4 * dt)
		return
	p.state = "walk"
	p.mood = "下雨" if raining and not p.platform else ["开心", "悠闲", "期待", "放松"][p.id % 4]
	if p.destination < 0.0:
		var trip: Dictionary = Planner.next_trip(p, hour)
		p.trip_no += 1
		p.destination = trip.destination
		p.purpose = trip.purpose
		p.place = trip.place
		p.trip_mode = trip.mode
		if p.wait_cooldown <= 0.0 and trip.mode == "bus":
			p.wait_at_far_stop = p.promenade
			p.wait_at_stop = not p.promenade and not p.platform
			return
	var wants_bus: bool = p.wait_at_stop and p.wait_cooldown <= 0.0 and bus_phase >= 14.0 and bus_phase < 33.0
	var wants_train: bool = p.platform and p.wait_cooldown <= 0.0 and (p.id == 1 or p.trip_mode == "metro") and train_phase >= 8.0 and train_phase < 42.0
	if wants_bus or wants_train:
		var door := 1100.0 if wants_bus else METRO_DOOR_X
		if absf(p.x - door) > 0.001: p.direction = 1 if door > p.x else -1
		p.x = move_toward(p.x, door, 18.0 * dt)
		var stopped: bool = Transit.passenger_crossing_allowed(seconds, "near_bus" if wants_bus else "metro")
		if stopped and absf(p.x - door) < 18.0:
			p.state = "boarding"
			p.timer = Transit.PASSENGER_TRANSITION_SECONDS
			p.mood = "乘车"
		return
	if absf(p.x - p.destination) < 0.5:
		p.state = "idle"
		p.timer = 3.0 + float((p.id + p.trip_no) % 5)
		p.mood = "休息" if p.purpose == "散步" else "悠闲"
		p.destination = -1.0
		return
	p.direction = 1 if p.destination > p.x else -1
	p.x = move_toward(p.x, float(p.destination), (9.0 + float(p.id % 3) * 1.5) * dt)

func _update_station_trip(p: Dictionary, dt: float, seconds: float, raining: bool) -> bool:
	if p.id not in [5, 16]: return false
	if p.state not in StationRoutes.TRAVEL_STATES:
		if p.state not in ["walk", "idle"] or seconds < p.station_due: return false
		p.state = "approach_exit" if p.platform else "approach_metro"
		p.sit = 0.0
		p.wait_at_stop = false
		p.wait_at_far_stop = false
		p.mood = "出站" if p.platform else "乘车"
	if p.state in ["approach_metro", "enter_metro", "approach_exit", "exit_metro"]:
		var target: float
		match p.state:
			"approach_metro": target = StationRoutes.access_x(true, station_shift)
			"enter_metro": target = StationRoutes.escalator_position(0, true, station_shift).x
			"approach_exit": target = StationRoutes.escalator_position(0, false, station_shift).x
			_: target = StationRoutes.access_x(false, station_shift)
		if absf(target - p.x) > 0.01: p.direction = 1 if target > p.x else -1
		p.x = move_toward(p.x, target, 16.0 * dt)
		if absf(target - p.x) > 0.01: return true
		match p.state:
			"approach_metro":
				p.state = "metro_fold_umbrella" if raining and p.umbrella else "enter_metro"
				p.timer = 1.2
			"enter_metro":
				p.state = "escalator_down"
				p.escalator_progress = 0.0
				p.umbrella_open = 0.0
			"approach_exit":
				p.state = "escalator_up"
				p.escalator_progress = 0.0
			"exit_metro":
				p.state = "walk"
				p.destination = -1.0
				p.trip_mode = "walk"
				p.station_due = seconds + 90.0
		return true
	if p.state == "metro_fold_umbrella":
		p.timer -= dt
		p.umbrella_open = clampf(p.timer / 1.2, 0.0, 1.0)
		if p.timer <= 0: p.state = "enter_metro"
		return true
	if p.state in StationRoutes.ESCALATOR_STATES:
		var down: bool = p.state == "escalator_down"
		p.escalator_progress = minf(1.0, p.escalator_progress + dt / StationRoutes.RIDE_SECONDS)
		var point := StationRoutes.escalator_position(p.escalator_progress, down, station_shift)
		p.x = point.x
		p.direction = 1
		if p.escalator_progress >= 1.0:
			p.platform = down
			p.state = "walk" if down else "exit_metro"
			p.destination = METRO_DOOR_X if down else -1.0
			p.trip_mode = "metro" if down else "walk"
			p.wait_cooldown = 0.0
			p.station_due = seconds + 120.0
		return true
	return false

func _check_greetings() -> void:
	# March 7th and Kafka share the Star Rail setting. Do not trigger across levels.
	var a: Dictionary = people[6]
	var b: Dictionary = people[7]
	if a.state == "walk" and b.state == "walk" and a.platform == b.platform and a.cooldown <= 0.0 and b.cooldown <= 0.0 and absf(a.x - b.x) < 28.0:
		for p in [a, b]:
			p.state = "greet"
			p.timer = 2.5
			p.cooldown = 30.0
			p.mood = "你好"
