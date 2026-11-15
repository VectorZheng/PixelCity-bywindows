extends RefCounted

# Positions are in original artwork coordinates. The simulation remains independent
# of rendering and can be stepped deterministically in tests.
var people: Array[Dictionary] = []

func _init() -> void:
	for i in range(8):
		people.append({"id": i, "platform": i == 1 or i == 5, "x": 990.0 if i < 2 else 550.0 + i * 140.0,
			"direction": 1 if i % 2 == 0 else -1, "state": "walk", "timer": 0.0,
			"cooldown": 0.0, "umbrella": i % 2 == 0, "mood": "开心"})

func step(delta: float, seconds: float, raining: bool) -> void:
	var dt := minf(delta, 0.1)
	for p in people:
		p.cooldown = maxf(0.0, p.cooldown - dt)
		if p.state in ["greet", "boarding", "onboard"]:
			p.timer -= dt
			if p.state == "boarding":
				p.x = move_toward(p.x, 1060.0 if not p.platform else 1040.0, 24.0 * dt)
			if p.timer <= 0.0:
				if p.state == "boarding":
					p.state = "onboard"
					p.timer = 6.0
				elif p.state == "onboard":
					p.state = "walk"
					p.x = 1110.0 if not p.platform else 1130.0
				else:
					p.state = "walk"
			continue
		if raining and not p.platform and not p.umbrella:
			p.state = "shelter"
			p.mood = "避雨"
			p.x = move_toward(p.x, 1080.0 + (p.id % 3) * 18.0, 22.0 * dt)
			continue
		p.state = "walk"
		p.mood = "下雨" if raining and not p.platform else "开心"
		var bus_phase := fposmod(seconds + 32.0, 70.0)
		var train_phase := fposmod(seconds, 100.0)
		var wants_bus: bool = p.id == 0 and bus_phase >= 14.0 and bus_phase < 33.0
		var wants_train: bool = p.id == 1 and train_phase >= 8.0 and train_phase < 42.0
		if wants_bus or wants_train:
			var door := 1060.0 if wants_bus else 1040.0
			p.x = move_toward(p.x, door, 25.0 * dt)
			var stopped := (bus_phase >= 25.0 and bus_phase < 31.0) if wants_bus else (train_phase >= 19.0 and train_phase < 40.0)
			if stopped and absf(p.x - door) < 18.0:
				p.state = "boarding"
				p.timer = 2.0
				p.mood = "乘车"
		else:
			p.x += p.direction * (13.0 + float(p.id % 3) * 2.0) * dt
			if p.x < 440.0 or p.x > 1730.0:
				p.x = clampf(p.x, 440.0, 1730.0)
				p.direction = -p.direction
	# March 7th and Kafka share the Star Rail setting. Do not trigger across levels.
	var a: Dictionary = people[6]
	var b: Dictionary = people[7]
	if a.state == "walk" and b.state == "walk" and a.platform == b.platform and a.cooldown <= 0.0 and b.cooldown <= 0.0 and absf(a.x - b.x) < 28.0:
		for p in [a, b]:
			p.state = "greet"
			p.timer = 2.5
			p.cooldown = 30.0
			p.mood = "你好"
