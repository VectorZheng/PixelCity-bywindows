extends RefCounted

# Positions are in original artwork coordinates. The simulation remains independent
# of rendering and can be stepped deterministically in tests.
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
			"sit": 0.0, "wait_cooldown": 0.0, "wait_at_stop": i == 0})

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
	if p.state in ["greet", "boarding", "onboard", "idle"]:
		p.timer -= dt
		if p.state == "boarding":
			p.x = move_toward(p.x, 1100.0 if not p.platform else 1040.0, 16.0 * dt)
		if p.timer <= 0.0:
			if p.state == "boarding":
				p.state = "onboard"
				p.timer = 6.0
			elif p.state == "onboard":
				p.state = "walk"
				p.x = 1110.0 if not p.platform else 1130.0
				p.wait_cooldown = 30.0
			else:
				p.state = "walk"
		return
	var bus_phase := fposmod(seconds + 32.0, 70.0)
	var train_phase := fposmod(seconds, 100.0)
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
		var seat_locations := {3: 1028.0, 7: 1068.0, 9: 425.0, 11: 443.0, 13: 461.0, 15: 1088.0}
		var shelter_x: float = float(seat_locations[p.id]) if can_sit else ((425.0 + (p.id % 4) * 18.0) if p.promenade else 1030.0 + (p.id % 6) * 20.0)
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
