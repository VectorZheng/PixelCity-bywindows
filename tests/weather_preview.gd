extends SceneTree

# Round 5: procedural pixel city, pixel weather, aircraft, one-sided station
# with up/down escalators, uniform pillars and masked plates.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var preview = load("res://main.tscn").instantiate()
	root.add_child(preview)
	await process_frame
	# Generated background: crisp pixel city, many individually switched windows, no purple.
	var base: Image = preview.BASE.get_image()
	var windows: Image = preview.WINDOWS.get_image()
	assert(base.get_size() == Vector2i(2172, 724) and windows.get_size() == base.get_size())
	var ids := {}
	var purple := 0
	for y in range(40, 560, 3):
		for x in range(0, 2172, 3):
			var w := windows.get_pixel(x, y)
			if w.r > 0.1: ids[int(w.g * 255.0) * 256 + int(w.b * 255.0)] = true
			var c := base.get_pixel(x, y)
			if c.a > 0.5 and c.s > 0.25 and c.h > 0.70 and c.h < 0.92: purple += 1
	print("window ids sampled %d, purple px %d" % [ids.size(), purple])
	assert(ids.size() > 2000)
	assert(purple == 0)
	# Pixel weather layer replaces the smooth addon.
	var controls := root.find_children("*", "OptionButton", true, false)
	var weather_select: OptionButton
	for control in controls:
		if control.item_count == 6: weather_select = control
	assert(weather_select != null)
	weather_select.item_selected.emit(2)
	preview._blend_weather(INF)
	preview._sync_weather_effects()
	var material: ShaderMaterial = preview._weather.material
	assert(preview.weather_override == 63 and preview._weather.visible)
	assert(is_equal_approx(material.get_shader_parameter(&"rain"), 1.0) and is_zero_approx(material.get_shader_parameter(&"snow")))
	weather_select.item_selected.emit(3)
	preview._blend_weather(INF)
	preview._sync_weather_effects()
	assert(is_equal_approx(material.get_shader_parameter(&"snow"), 1.0) and is_zero_approx(material.get_shader_parameter(&"rain")))
	weather_select.item_selected.emit(0)
	assert(preview.weather_override == -1)
	# Aircraft: slow, leave contrails, describable.
	var Aircraft = load("res://scripts/aircraft.gd")
	var sky = Aircraft.new(7)
	var seen_jet := false
	for i in range(3000):
		sky.step(0.1, 2172.0, 12.0)
		for f in sky.flights:
			assert(f.speed < 40.0)
			var card: Dictionary = Aircraft.describe(f)
			assert(card.rows.size() >= 3 and not str(card.title).is_empty())
			if f.kind == "jet": seen_jet = true
	assert(seen_jet and sky.trails.size() > 0)
	# Crowd rides the escalators at the morning peak.
	var Crowd = load("res://scripts/crowd.gd")
	var c = Crowd.new(5)
	var riding := 0
	var platform := 0
	for i in range(3000):
		c.step(0.1, 8.5, 2172.0, [85.0, 1563.0], false, {"shift": 0.0, "far_x": 1563.0})
		if i > 600:
			riding += c.people.filter(func(p): return p.stage == "ride").size()
			platform += c.people.filter(func(p): return p.stage == "platform").size()
	print("escalator riders avg %.1f, platform avg %.1f" % [riding / 2400.0, platform / 2400.0])
	assert(riding / 2400.0 > 2.0 and platform > 0)
	# Plates mask their last character; uniform pillars between doors.
	var Traffic = load("res://scripts/traffic.gd")
	var t = Traffic.new(3)
	for i in range(1500): t.step(0.1, 8.3, 2172.0, [])
	for v in t.vehicles:
		if v.kind != "scooter": assert(str(v.plate).ends_with("x"))
	var Station = load("res://scripts/station.gd")
	var Transit = load("res://scripts/transit.gd")
	var doors: Array[float] = Station.door_centers(2172)
	for pillar in Station.PILLARS:
		assert(is_equal_approx(pillar.size.x, Station.PILLARS[0].size.x))
		for d in doors: assert(d + 9.0 <= pillar.position.x or d - 9.0 >= pillar.end.x)
	preview.queue_free()
	await process_frame
	print("WEATHER_PREVIEW_TEST_PASSED")
	quit(0)
