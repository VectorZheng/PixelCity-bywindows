extends SceneTree

const Schedule = preload("res://scripts/schedule.gd")
const Transit = preload("res://scripts/transit.gd")

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("SCHEDULE_TEST_FAILED: " + message)

func hm(h: int, m: int, s: int = 0) -> float:
	return float(h * 3600 + m * 60 + s)

func _initialize() -> void:
	# First and last service.
	var metro := Schedule.arrivals("metro")
	var near := Schedule.arrivals("near_bus")
	var far := Schedule.arrivals("far_bus")
	check(metro[0] == hm(6, 32), "metro first 06:32")
	check(metro[metro.size() - 1] <= hm(23, 38), "metro last <= 23:38")
	check(metro[metro.size() - 1] == hm(23, 38), "metro last 23:38 (%s)" % metro[metro.size() - 1])
	check(near[0] == hm(6, 0), "bus first 06:00")
	check(near[near.size() - 1] <= hm(23, 0), "bus last <= 23:00")
	check(far.size() == near.size() and far[0] == near[0] + 150.0, "far bus offset +150")
	check(near[near.size() - 1] == hm(23, 0), "bus last 23:00")
	for i in range(1, metro.size() - 1):
		check(metro[i] - metro[i - 1] == Schedule.headway("metro", metro[i - 1]), "metro stepping")
	# No metro at 02:00 or 23:50.
	for c in [hm(2, 0), hm(23, 50)]:
		check(not Schedule.in_service("metro", c), "metro out of service at %s" % c)
		check(Schedule.phase("metro", c) == 80.0, "metro idle at %s" % c)
	check(Schedule.in_service("metro", hm(12, 0)), "metro in service at noon")
	check(not Schedule.in_service("near_bus", hm(5, 0)), "bus not in service 05:00")
	check(Schedule.in_service("near_bus", hm(5, 59, 40)), "bus entering before first arrival")
	# Peak versus off-peak headways.
	check(Schedule.is_peak(hm(8, 0)) and Schedule.is_peak(hm(18, 0)), "peaks")
	check(not Schedule.is_peak(hm(12, 0)) and not Schedule.is_peak(hm(9, 30)) and not Schedule.is_peak(hm(19, 30)), "off-peak")
	check(Schedule.headway("metro", hm(8, 0)) == 150.0, "metro peak 150")
	check(Schedule.headway("metro", hm(6, 40)) == 300.0, "metro early 300")
	check(Schedule.headway("metro", hm(12, 0)) == 300.0, "metro day 300")
	check(Schedule.headway("metro", hm(20, 0)) == 300.0, "metro evening 300")
	check(Schedule.headway("metro", hm(22, 0)) == 480.0, "metro late 480")
	check(Schedule.headway("near_bus", hm(8, 0)) == 300.0, "bus peak 300")
	check(Schedule.headway("near_bus", hm(12, 0)) == 600.0, "bus day 600")
	check(Schedule.headway("near_bus", hm(6, 30)) == 900.0, "bus early 900")
	check(Schedule.headway("near_bus", hm(21, 30)) == 900.0, "bus late 900")

	# Phase / doors / crossing / countdown around one metro arrival.
	var arrive: float = metro[10]
	var enter := arrive - 19.0
	check(Schedule.phase("metro", enter - 1.0) == 80.0, "metro idle before entering")
	check(absf(Schedule.phase("metro", enter) - 0.0) < 0.001, "metro phase 0 at entry")
	check(absf(Schedule.phase("metro", arrive) - 19.0) < 0.001, "metro phase 19 at arrival")
	check(absf(Schedule.phase("metro", enter + 60.5) - 60.5) < 0.001, "metro still leaving")
	check(Schedule.phase("metro", enter + 61.0) == 80.0, "metro idle after leaving")
	var last_eta := INF
	var t := enter - 30.0
	Transit.scheduled = true
	while t < arrive:
		Transit.clock = t
		var eta := Schedule.seconds_to_arrival("metro", t)
		check(eta < last_eta and eta > 0.0, "metro countdown decreasing")
		check(Transit.metro_arrival_now(0.0) == ceili(eta), "metro_arrival_now")
		last_eta = eta
		t += 0.5
	check(Schedule.seconds_to_arrival("metro", arrive) == 0.0, "metro eta 0 at stop")
	check(Schedule.seconds_to_arrival("metro", arrive + 22.0) == 0.0, "metro eta 0 while dwelling")
	t = enter - 5.0
	while t < enter + 70.0:
		Transit.clock = t
		var p: float = Schedule.phase("metro", t)
		var dwelling := t >= arrive and t < arrive + 23.0
		if Transit.train_doors_now(0.0) > 0.0 or Transit.passenger_crossing_allowed(0.0, "metro"):
			check(dwelling, "metro doors only while dwelling (phase %s)" % p)
		t += 0.25
	Transit.clock = arrive + 5.0
	check(Transit.train_doors_now(0.0) == 1.0 and Transit.passenger_crossing_allowed(0.0, "metro"), "metro doors open mid-dwell")
	check(Transit.train_x_now(0.0, 1920.0) == 750.0, "train at platform")
	Transit.clock = enter - 10.0
	check(Transit.train_x_now(0.0, 1920.0) == -680.0, "train off-screen when idle")

	# Same for one near_bus arrival.
	var bus_arrive: float = near[20]
	var bus_enter := bus_arrive - 25.0
	check(Schedule.phase("near_bus", bus_enter - 1.0) == 69.99, "bus idle before")
	check(absf(Schedule.phase("near_bus", bus_enter + 10.0) - 10.0) < 0.001, "bus approaching")
	check(Schedule.phase("near_bus", bus_enter + 70.0) == 69.99, "bus idle after")
	last_eta = INF
	t = bus_enter - 20.0
	while t < bus_arrive:
		var eta := Schedule.seconds_to_arrival("near_bus", t)
		check(eta < last_eta and eta > 0.0, "bus countdown decreasing")
		last_eta = eta
		t += 0.5
	check(Schedule.seconds_to_arrival("near_bus", bus_arrive + 4.0) == 0.0, "bus eta 0 dwelling")
	t = bus_enter - 5.0
	while t < bus_enter + 75.0:
		Transit.clock = t
		var dwelling := t >= bus_arrive and t < bus_arrive + 8.0
		if Transit.bus_doors_for("near_bus", 0.0) > 0.0 or Transit.passenger_crossing_allowed(0.0, "near_bus"):
			check(dwelling, "bus doors only while dwelling")
		t += 0.25
	Transit.clock = bus_arrive + 3.0
	check(Transit.passenger_crossing_allowed(0.0, "near_bus"), "bus crossing mid-dwell")
	check(Transit.bus_arrival_for("near_bus", 0.0) == 0, "bus_arrival_for 0 at stop")
	check(not Transit.passenger_crossing_allowed(0.0, "far_bus"), "far bus not at stop simultaneously")

	# Overnight wrap.
	check(absf(Schedule.seconds_to_arrival("metro", hm(23, 50)) - (86400.0 - hm(23, 50) + hm(6, 32))) < 0.001, "metro wraps to morning")
	check(absf(Schedule.seconds_to_arrival("near_bus", hm(2, 0)) - (hm(6, 0) - hm(2, 0))) < 0.001, "bus early morning eta")
	check(Schedule.phase("near_bus", 10.0) == 69.99, "bus idle just after midnight")
	Transit.clock = hm(23, 50)
	check(not Transit.in_service_now("metro"), "in_service_now false late")
	Transit.scheduled = false
	check(Transit.in_service_now("metro"), "legacy always in service")
	# Legacy compatibility.
	for s in [0.0, 13.7, 45.2, 99.0, 1234.5]:
		check(Transit.phase("near_bus", s) == fposmod(s + 32.0, 70.0), "legacy near")
		check(Transit.phase("far_bus", s) == fposmod(s + 8.0, 70.0), "legacy far")
		check(Transit.phase("metro", s) == fposmod(s, 100.0), "legacy metro")
		check(Transit.bus_arrival_for("near_bus", s) == Transit.bus_arrival_seconds(s + 32.0), "legacy eta")
		check(Transit.train_doors_now(s) == Transit.train_doors(s), "legacy train doors")

	# Scheduled residents simulation from 07:50 for 30 simulated minutes.
	Transit.scheduled = true
	var sim = load("res://scripts/residents.gd").new()
	var start := hm(7, 50)
	var dt := 0.1
	var boardings := 0
	var previous := {}
	var elapsed := 0.0
	while elapsed < 1800.0:
		elapsed += dt
		Transit.clock = start + elapsed
		sim.step(dt, 5000.0 + elapsed, false, 7 + int((50.0 + elapsed / 60.0) / 60.0))
		for p in sim.people:
			var vehicle: String = "metro" if p.platform else ("far_bus" if p.promenade else "near_bus")
			if p.state == "boarding":
				# Entering a crossing requires the crossing window; the 2 s
				# crossing itself must finish while the doors are fully open.
				if previous.get(p.id, "") != "boarding":
					boardings += 1
					check(Transit.passenger_crossing_allowed(0.0, vehicle), "boarding %s started outside crossing window at %s" % [vehicle, Transit.clock])
				var doors: float = Transit.train_doors_now(0.0) if vehicle == "metro" else Transit.bus_doors_for(vehicle, 0.0)
				check(doors >= 1.0, "boarding %s with doors not fully open at %s" % [vehicle, Transit.clock])
			previous[p.id] = p.state
	check(boardings > 0, "some resident boarded in scheduled mode")
	Transit.scheduled = false
	Transit.clock = 0.0

	if failures == 0:
		print("SCHEDULE_TEST_PASSED")
		quit(0)
	else:
		print("SCHEDULE_TEST_FAILED (%d)" % failures)
		quit(1)
