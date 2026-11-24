extends SceneTree

# Resident identities must agree with the behaviour the simulation produces.
func _initialize() -> void:
	var Profiles = load("res://scripts/profiles.gd")
	var Residents = load("res://scripts/residents.gd")
	var Planner = load("res://scripts/citizen_planner.gd")
	var sim = Residents.new()
	var names := {}
	for person in sim.people:
		var p: Dictionary = Profiles.profile(person.id)
		names[p.name] = true
		# Umbrella habit matches the simulated umbrella.
		assert(p.umbrella == person.umbrella)
		# Office workers are exactly the residents the planner sends to the office district in the morning.
		var trip: Dictionary = Planner.next_trip(person, 8)
		assert(p.office == (trip.purpose == "上班"))
		assert(p.age >= 18 and p.age <= 70)
		assert(p.month >= 1 and p.month <= 12 and p.day >= 1 and p.day <= 28)
	assert(names.size() == sim.people.size())
	# Birth year is consistent with age on either side of the birthday.
	var p0: Dictionary = Profiles.profile(0)
	assert(Profiles.birthday_text(p0, {"year": 2026, "month": 12, "day": 31}).begins_with("%d年" % (2026 - p0.age)))
	assert(Profiles.birthday_text(p0, {"year": 2026, "month": 1, "day": 1}).begins_with("%d年" % (2025 - p0.age)) or p0.month == 1 and p0.day == 1)
	assert(Profiles.birthday_text(p0, {"year": 2026, "month": p0.month, "day": p0.day}).contains("今天生日"))
	# Scripted roles: dedicated bus commuters, metro riders and the greeting pair.
	assert(Profiles.DATA[0].habit.contains("3 路") and Profiles.DATA[8].habit.contains("3 路"))
	assert(Profiles.DATA[10].habit.contains("SUV"))
	assert(Profiles.FRIENDS[6] == 7 and Profiles.FRIENDS[7] == 6)
	# Every visible state yields a filled, formatted description over a long run.
	var seen_states := {}
	for raining in [false, true]:
		sim = Residents.new()
		for tick in range(3000):
			var seconds := tick / 10.0
			sim.step(0.1, seconds, raining, [8, 13, 19][tick % 3])
			if tick % 5 != 0: continue
			for person in sim.people:
				if person.state in ["onboard", "car_onboard"]: continue
				var text: String = Profiles.next_action(person, seconds, sim.people)
				assert(not text.is_empty() and not text.contains("%"))
				seen_states[person.state] = true
				if person.state == "wait_bus": assert(text.contains("3 路"))
				if person.state == "shelter": assert(text.contains("没带伞"))
				if person.state == "greet": assert(text.contains("宋小满") or text.contains("顾清和"))
				var lines: Array = Profiles.card_lines(person, seconds, sim.people, {"year": 2026, "month": 11, "day": 19})
				assert(lines.size() == 8)
				for line in lines: assert(not str(line[1]).is_empty() and not str(line[1]).contains("%"))
	for state in ["walk", "wait_bus", "shelter", "boarding", "escalator_down"]:
		assert(seen_states.has(state))
	# The realistic cast covers every resident with an 8-frame sheet in the shared layout.
	var City = load("res://scripts/city.gd")
	assert(City.CASTS.real.frames == 8 and City.CASTS.anime.frames == 4)
	assert(City.REAL_SHEETS.size() * 4 >= Profiles.DATA.size())
	for sheet in City.REAL_SHEETS:
		assert(sheet.get_width() == 54 * 8 and sheet.get_height() == 72 * 4)
	print("PROFILE_TEST_PASSED ", seen_states.keys().size(), " states")
	quit(0)
