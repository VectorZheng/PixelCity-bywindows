extends RefCounted

# Positions are in original artwork coordinates. The simulation remains independent
# of rendering and can be stepped deterministically in tests.
const FAR_SHELTER_X := 680.0
const FAR_DOOR_X := 780.0
const FAR_BUS_X := 724.0
var people: Array[Dictionary] = []

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
			"umbrella_open": 1.0, "stop_cooldown": 0.0})

func step(delta: float, seconds: float, raining: bool) -> void:
	# Substep long frames rather than discarding elapsed time. Use the matching
	# simulation timestamp for each substep so vehicle windows remain aligned.
	var remaining := maxf(delta, 0.0)
	while remaining > 0.000001:
		var dt := minf(remaining, 0.1)
		remaining -= dt
		_step_once(dt, seconds - remaining, raining)

func _step_once(dt: float, seconds: float, raining: bool) -> void:
	for p in people:
		var old_x: float = p.x
		_update_person(p, dt, seconds, raining)
		var distance: float = absf(p.x - old_x)
		# Teleports after a ride are scene transitions, not steps.
		if distance <= 30.0 * dt + 0.001:
			p.walk_distance += distance
			p.moving = distance > 0.00001
		else:
			p.moving = false
	_check_greetings()

func _update_person(p: Dictionary, dt: float, seconds: float, raining: bool) -> void:
	p.cooldown = maxf(0.0, p.cooldown - dt)
	p.wait_cooldown = maxf(0.0, p.wait_cooldown - dt)
	p.stop_cooldown = maxf(0.0, p.stop_cooldown - dt)
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
	if p.id == 4 and p.stop_cooldown <= 0.0 and pickup_phase >= 12.0 and pickup_phase < 31.0:
		p.state = "car_pickup"
		p.mood = "期待"
		if absf(p.x - 1340.0) > 0.5: p.direction = 1 if 1340.0 > p.x else -1
		p.x = move_toward(p.x, 1340.0, 15.0 * dt)
		if pickup_phase >= 26.0 and absf(p.x - 1340.0) < 1.0:
			p.state = "car_boarding"
			p.timer = 2.0
		return
	if p.state in ["greet", "boarding", "onboard", "idle"]:
		p.timer -= dt
		if p.state == "boarding":
			p.x = move_toward(p.x, FAR_DOOR_X if p.promenade else (1100.0 if not p.platform else 1040.0), 16.0 * dt)
		if p.timer <= 0.0:
			if p.state == "boarding":
				p.state = "onboard"
				p.timer = 6.0
			elif p.state == "onboard":
				p.state = "walk"
				p.x = 840.0 if p.promenade else (1110.0 if not p.platform else 1130.0)
				p.wait_cooldown = 30.0
			else:
				p.state = "walk"
		return
	var bus_phase := fposmod(seconds + 32.0, 70.0)
	var train_phase := fposmod(seconds, 100.0)
	var far_bus_phase := fposmod(seconds + 8.0, 70.0)
	var far_boarding: bool = p.wait_at_far_stop and p.wait_cooldown <= 0.0 and far_bus_phase >= 22.0 and far_bus_phase < 31.0
	if p.wait_at_far_stop and p.wait_cooldown <= 0.0:
		p.mood = "期待"
		var far_target := FAR_DOOR_X if far_boarding else 736.0
		if absf(p.x - far_target) > 0.5: p.direction = 1 if far_target > p.x else -1
		if far_boarding and p.sit > 0.0:
			p.state = "stand_up"
			p.sit = move_toward(p.sit, 0.0, 1.4 * dt)
			return
		p.state = "wait_bus"
		p.x = move_toward(p.x, far_target, 17.0 * dt)
		p.sit = move_toward(p.sit, 1.0 if not far_boarding and absf(p.x - far_target) < 0.5 else 0.0, 1.4 * dt)
		if far_boarding and far_bus_phase >= 26.0 and absf(p.x - far_target) < 1.0:
			p.state = "boarding"
			p.timer = 2.0
		return
	var should_board: bool = p.id == 0 and bus_phase >= 24.0 and bus_phase < 31.0
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
		var can_sit: bool = p.id in [3, 7, 9, 11, 13, 15]
		var seat_locations := {3: 1028.0, 7: 1068.0, 9: 711.0, 11: 758.0, 13: 780.0, 15: 1088.0}
		var shelter_x: float = float(seat_locations[p.id]) if can_sit else ((711.0 + (p.id % 4) * 18.0) if p.promenade else 1030.0 + (p.id % 6) * 20.0)
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
	p.idle_due -= dt
	if p.id >= 8 and p.idle_due <= 0.0:
		p.state = "idle"
		p.timer = 2.0 + (p.id % 3)
		p.idle_due = 22.0 + (p.id % 5) * 4.0
		p.mood = "休息"
		return
	var wants_bus: bool = p.id == 0 and bus_phase >= 14.0 and bus_phase < 33.0
	var wants_train: bool = p.id == 1 and train_phase >= 8.0 and train_phase < 42.0
	if wants_bus or wants_train:
		var door := 1100.0 if wants_bus else 1040.0
		if absf(p.x - door) > 0.001: p.direction = 1 if door > p.x else -1
		p.x = move_toward(p.x, door, 18.0 * dt)
		var stopped := (bus_phase >= 26.0 and bus_phase < 31.0) if wants_bus else (train_phase >= 21.0 and train_phase < 39.0)
		if stopped and absf(p.x - door) < 18.0:
			p.state = "boarding"
			p.timer = 2.0
			p.mood = "乘车"
	else:
		p.x += p.direction * (9.0 + float(p.id % 3) * 1.5) * dt
		if p.x < 440.0 or p.x > 1730.0:
			p.x = clampf(p.x, 440.0, 1730.0)
			p.direction = -p.direction

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
