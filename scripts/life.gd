extends RefCounted

# A resident's day: mood that reacts to what actually happens to them in the
# simulation (waiting for the bus, rain, meeting a friend, commuting, the
# weather), plus a short log of their day with real clock times.
#
# observe() is called every frame with the current residents; it only watches
# state changes, so the movement simulation stays untouched and testable.

const Profiles = preload("res://scripts/profiles.gd")

var people := {}      # id -> {score, base, reason, log: Array, last_state, wait_start}

func _entry(person: Dictionary) -> Dictionary:
	if not people.has(person.id):
		# Personality baseline: some residents are simply cheerier than others.
		var base: float = [0.25, 0.0, 0.1, 0.3, 0.05, 0.1, 0.35, 0.2, 0.0, 0.3, 0.1, 0.2, 0.4, 0.15, 0.05, 0.1, 0.0, 0.2][person.id % 18]
		people[person.id] = {"score": base, "base": base, "reason": "", "log": [], "last_state": "", "wait_start": -1.0, "last_place": "", "reason_clock": -1e9}
	return people[person.id]

static func clock_text(clock: float) -> String:
	return "%02d:%02d" % [int(clock / 3600.0) % 24, int(fposmod(clock, 3600.0) / 60.0)]

func _log(e: Dictionary, clock: float, text: String) -> void:
	var log: Array = e.log
	if not log.is_empty() and str(log[-1]).ends_with(text): return
	log.append("%s %s" % [clock_text(clock), text])
	while log.size() > 6: log.pop_front()

var _clock := 0.0

func _feel(e: Dictionary, delta: float, reason: String, minor: bool = false) -> void:
	# Ongoing influences (weather, waiting) never hide a recent real event.
	e.score = clampf(e.score + delta, -1.0, 1.0)
	if reason == "": return
	if minor and _clock - float(e.reason_clock) < 180.0 and e.reason != reason: return
	e.reason = reason
	if not minor: e.reason_clock = _clock

# world: {clock, raining, weather_code, today, hour}
func observe(all: Array, world: Dictionary, dt: float) -> void:
	var clock: float = world.clock
	_clock = clock
	for person in all:
		var e := _entry(person)
		var state: String = person.state
		var p := Profiles.profile(person.id)
		if state != e.last_state:
			_on_change(person, e, p, e.last_state, state, world)
			e.last_state = state
		# Continuous influences.
		if state == "wait_bus" or (person.platform and person.trip_mode == "metro" and state == "walk"):
			if e.wait_start < 0.0: e.wait_start = clock
			var waited := clock - float(e.wait_start)
			if waited > 240.0: _feel(e, -0.015 * dt, "等车等了 %d 分钟" % int(waited / 60.0), true)
		elif state not in ["boarding", "onboard"]:
			e.wait_start = -1.0
		if world.raining and not person.platform:
			if state == "shelter": _feel(e, -0.01 * dt, "没带伞，被雨困在站棚", true)
			elif state == "walk": _feel(e, -0.004 * dt, "下雨天出门有点烦", true)
		elif int(world.weather_code) in [0, 1] and int(world.hour) in range(8, 17) and not person.platform:
			_feel(e, 0.002 * dt, "天气晴朗，心情跟着变好", true)
		# Moods drift back towards the person's usual self.
		e.score = lerpf(e.score, e.base + (0.5 if Profiles.is_birthday(p, world.today) else 0.0), 1.0 - exp(-dt / 240.0))

func _on_change(person: Dictionary, e: Dictionary, p: Dictionary, before: String, state: String, world: Dictionary) -> void:
	var clock: float = world.clock
	match state:
		"wait_bus":
			_log(e, clock, "到%s等 3 路" % ("海边站" if person.promenade else "公交站"))
		"boarding":
			var waited := clock - float(e.wait_start) if e.wait_start >= 0.0 else 0.0
			if waited > 240.0: _feel(e, 0.15, "等了 %d 分钟，终于上车了" % int(waited / 60.0))
			_log(e, clock, "上车，去%s" % Profiles.trip_destination(person))
		"alighting":
			_log(e, clock, "在华新下车")
		"shelter":
			_feel(e, -0.15, "没带伞，被雨困在站棚")
			_log(e, clock, "下雨了，去站棚躲雨")
		"greet":
			var friend: int = Profiles.FRIENDS.get(person.id, -1)
			if friend >= 0:
				_feel(e, 0.35, "偶遇老同学%s" % Profiles.DATA[friend].name)
				_log(e, clock, "偶遇老同学%s，聊了两句" % Profiles.DATA[friend].name)
		"idle":
			var place: String = Profiles.local_place(person)
			match str(person.purpose):
				"购物": _feel(e, 0.12, "买到了想要的东西")
				"散步": _feel(e, 0.15, "散步很放松")
				"工作", "上班": _feel(e, -0.05, "又开始忙工作了")
				"回家": _feel(e, 0.2, "终于下班回家了")
			_log(e, clock, "到了%s" % place)
		"walk":
			if before in ["", "idle", "alighting", "exit_metro", "car_exit"]:
				if person.purpose == "上班" and int(world.hour) in range(6, 10): _feel(e, -0.08, "早高峰赶着上班")
				if person.purpose == "回家" and int(world.hour) >= 17: _feel(e, 0.1, "下班了，准备回家")
				_log(e, clock, Profiles.next_action(person, 0.0, []))
		"approach_metro":
			_log(e, clock, "去华新站坐 3 号线")
		"escalator_up":
			_log(e, clock, "坐 3 号线到华新，出站")
		"car_boarding":
			_feel(e, 0.15, "家人开车来接，很安心")
			_log(e, clock, "上了家里的绿色 SUV")

func mood_text(person: Dictionary, today: Dictionary) -> String:
	var e := _entry(person)
	var s: float = e.score
	var word := "很开心" if s > 0.55 else ("心情不错" if s > 0.2 else ("平静" if s > -0.2 else ("有点烦" if s > -0.5 else "很烦躁")))
	var reason: String = e.reason
	if Profiles.is_birthday(Profiles.profile(person.id), today) and s > 0.2: reason = "今天生日"
	return word + ("：" + reason if reason != "" else "")

func day_log(person: Dictionary) -> String:
	var log: Array = _entry(person).log
	if log.is_empty(): return "刚出门"
	return "\n".join(log.slice(maxi(0, log.size() - 4)))
