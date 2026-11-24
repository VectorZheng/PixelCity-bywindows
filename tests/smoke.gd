extends SceneTree

func _initialize() -> void:
	var city = load("res://scripts/city.gd").new()
	assert(city._weather_name(0) == "晴")
	assert(city._weather_name(2) == "多云")
	assert(city._weather_name(63) == "雨")
	assert(city._weather_name(95) == "雷雨")
	assert(not city._is_raining())
	city.weather = {"code": 63}
	assert(city._is_raining())
	city.weather = {"code": 2}
	assert(not city._is_raining())
	city.weather_override = 63
	assert(city._is_raining())
	city.weather_override = 75
	assert(city._is_snowing() and not city._is_raining())
	city.weather_override = 45
	assert(city._visual_weather_code() == 45)
	city.weather_override = -1
	assert(city._visual_weather_code() == 2)
	# Both vehicle cutouts retain their own source rectangles and proportions.
	assert(city.SHENZHEN_BUS.get_width() >= city.BUS_SOURCE.end.x)
	assert(city.SHENZHEN_BUS.get_height() >= city.BUS_SOURCE.end.y)
	assert(city.SU7_YELLOW.get_width() >= city.SU7_SOURCE.end.x)
	assert(city.YU7_GREEN.get_width() >= city.YU7_SOURCE.end.x)
	assert(city.SU7_SOURCE.size.x / city.SU7_SOURCE.size.y > city.YU7_SOURCE.size.x / city.YU7_SOURCE.size.y)
	var view := Vector2(1920, 1080)
	var image_size := Vector2(2172, 724)
	var fit: Rect2 = city._display_rect(view, image_size, "fit")
	assert(is_equal_approx(fit.size.x, 1920.0) and is_equal_approx(fit.size.y, 640.0))
	var fill: Rect2 = city._display_rect(view, image_size, "fill")
	assert(is_equal_approx(fill.size.x, 3240.0) and is_equal_approx(fill.size.y, 1080.0))
	var sky: Rect2 = city._display_rect(Vector2(2880, 1800), image_size, "sky")
	assert(is_equal_approx(sky.size.x, 5749.411765) and is_equal_approx(sky.size.y, 1916.470588))
	assert(is_equal_approx(sky.position.x, -1434.705882) and is_equal_approx(sky.position.y, -116.470588))
	assert(is_equal_approx(sky.end.y, 1800.0))
	# Original aspect keeps the original two entrances; compact crop moves them.
	assert(is_zero_approx(city._station_shift(Vector2(1500, 500), image_size, "sky")))
	assert(is_zero_approx(city._station_shift(view, image_size, "fit")))
	assert(is_equal_approx(city._station_shift(Vector2(2880, 1800), image_size, "sky"), 526.0))
	# Areas beside and above each sloped entrance remain visible to traffic.
	var left: PackedVector2Array = city._entrance_outline(false)
	var right: PackedVector2Array = city._entrance_outline(true)
	assert(not Geometry2D.is_point_in_polygon(Vector2(420, 500), left))
	assert(not Geometry2D.is_point_in_polygon(Vector2(400, 480), left))
	assert(Geometry2D.is_point_in_polygon(Vector2(300, 520), left))
	assert(not Geometry2D.is_point_in_polygon(Vector2(1752, 500), right))
	assert(Geometry2D.is_point_in_polygon(Vector2(1872, 520), right))
	var shifted: PackedVector2Array = city._entrance_outline(false, 400.0)
	assert(not Geometry2D.is_point_in_polygon(Vector2(820, 500), shifted))
	assert(Geometry2D.is_point_in_polygon(Vector2(700, 520), shifted))
	var stretch: Rect2 = city._display_rect(view, image_size, "stretch")
	assert(stretch.position == Vector2.ZERO and stretch.size == view)
	assert(city._train_x(0.0, image_size.x) < 0.0)
	assert(is_equal_approx(city._train_x(19.0, image_size.x), 750.0))
	assert(is_equal_approx(city._train_x(30.0, image_size.x), 750.0))
	assert(city._train_x(50.0, image_size.x) > 750.0)
	assert(city._train_x(70.0, image_size.x) < 0.0)
	assert(is_equal_approx(city._bus_x(25.0, image_size.x, false), city._bus_x(32.0, image_size.x, false)))
	assert(city._bus_x(40.0, image_size.x, false) > city._bus_x(33.0, image_size.x, false))
	assert(city._bus_x(40.0, image_size.x, true) < city._bus_x(33.0, image_size.x, true))
	# Waterfront bus door lines up with its own shelter, not the other stop.
	assert(is_equal_approx(city._bus_x(28.0, image_size.x, false), 634.4))
	assert(is_equal_approx(city._bus_x(28.0, image_size.x, false) + 160.0 * 0.41, 700.0))
	assert(absf(city._bus_x(28.0, image_size.x, true) + 170.0 * 0.59 - 1100.0) < 0.1)
	# Buses remain at the stop while cars keep moving and use the passing lane.
	assert(is_equal_approx(city._bus_x(28.0, image_size.x, false), city._bus_x(29.0, image_size.x, false)))
	assert(city._car_x(21.0, image_size.x, false) > city._car_x(20.0, image_size.x, false))
	assert(city._car_x(67.0, image_size.x, true) < city._car_x(66.0, image_size.x, true))
	# A passing car changes lanes smoothly in either direction, and its speed varies.
	assert(city._passing_lane_amount(660.0, 750.0, false) > 0.9)
	assert(city._passing_lane_amount(1000.0, 750.0, false) == 0.0)
	assert(city._passing_lane_amount(880.0, 750.0, true) > 0.9)
	assert(city._passing_lane_amount(500.0, 750.0, true) == 0.0)
	var early_speed: float = city._car_x(11.0, image_size.x, false) - city._car_x(10.0, image_size.x, false)
	var later_speed: float = city._car_x(21.0, image_size.x, false) - city._car_x(20.0, image_size.x, false)
	assert(absf(early_speed - later_speed) > 5.0)
	assert(is_equal_approx(city._car_x(25.0, image_size.x, false), 1300.0))
	assert(is_equal_approx(city._car_x(32.0, image_size.x, false), 1300.0))
	assert(city._car_x(36.0, image_size.x, false) > 1300.0)
	var transit = load("res://scripts/transit.gd")
	var centers: Array[float] = transit.platform_door_centers()
	assert(centers.size() == 12)
	assert(absf(centers[5] - 1057.56) < 0.01)
	for center in centers:
		assert(is_zero_approx(transit.platform_door_opening(18.0, center)))
		assert(is_equal_approx(transit.platform_door_opening(25.0, center), 1.0))
		assert(is_zero_approx(transit.platform_door_opening(43.0, center)))
	assert(is_zero_approx(transit.platform_door_opening(25.0, 500.0)))
	assert(is_zero_approx(transit.train_doors(19.0)))
	assert(is_equal_approx(transit.train_doors(23.0), 1.0))
	assert(is_zero_approx(transit.train_doors(40.0)))
	assert(transit.bus_arrival_seconds(0.0) == 25)
	assert(transit.bus_arrival_seconds(24.1) == 1)
	assert(transit.bus_arrival_seconds(25.0) == 0)
	assert(transit.bus_arrival_seconds(32.9) == 0)
	assert(transit.bus_arrival_seconds(33.0) == 62)
	assert(transit.bus_arrival_seconds(70.0) == 25)
	assert(is_zero_approx(transit.bus_doors(25.0)))
	assert(is_equal_approx(transit.bus_doors(28.0), 1.0))
	assert(is_zero_approx(transit.bus_doors(33.0)))
	for tick in range(1000):
		var time := tick / 10.0
		if transit.train_doors(time) > 0.0:
			assert(is_equal_approx(transit.train_position(time, image_size.x), 750.0))
		if transit.bus_doors(time) > 0.0:
			assert(is_equal_approx(city._bus_x(time, image_size.x, false), city._bus_x(28.0, image_size.x, false)))
	# Live environment: real sun over Shenzhen, lights and ambient follow it.
	var Env = load("res://scripts/environment.gd")
	var nov := {"year": 2026, "month": 11, "day": 20, "weekday": 5}
	var at := func(h: int, m: int) -> Dictionary:
		var d := nov.duplicate()
		d.hour = h; d.minute = m; d.second = 0
		return d
	assert(Env.sun(at.call(12, 0)).elevation > 40.0)
	assert(Env.sun(at.call(0, 0)).elevation < -30.0)
	# November sunrise in Shenzhen is about 06:40, sunset about 17:40.
	assert(Env.sun(at.call(6, 25)).elevation < 0.0 and Env.sun(at.call(6, 55)).elevation > 0.0)
	assert(Env.sun(at.call(17, 30)).elevation > 0.0 and Env.sun(at.call(17, 55)).elevation < 0.0)
	assert(Env.sky_position(Env.sun(at.call(8, 0))).x < Env.sky_position(Env.sun(at.call(16, 0))).x)
	assert(Env.street_lights(-10.0) == 1.0 and Env.street_lights(20.0) == 0.0)
	assert(Env.window_occupancy(at.call(3, 0)) < 0.1 and Env.window_occupancy(at.call(20, 30)) > 0.7)
	assert(Env.light_show(at.call(20, 0)) == 1.0 and Env.light_show(at.call(23, 0)) == 0.0)
	var night_light: Color = Env.ambient(-20.0, 0.0, 0.0)
	var noon_light: Color = Env.ambient(50.0, 0.0, 0.0)
	assert(night_light.r < 0.4 and noon_light.g > 0.9)
	assert(Env.ambient(50.0, 1.0, 1.0).g < noon_light.g)
	var phase: float = Env.moon(at.call(0, 0)).phase
	assert(phase >= 0.0 and phase < 1.0)
	var portrait: Rect2 = city._display_rect(Vector2(1080, 1920), image_size, "fit")
	assert(is_equal_approx(portrait.size.x, 1080.0) and is_equal_approx(portrait.size.y, 360.0))
	city.settings_path = "user://smoke-display.cfg"
	city._on_display_mode_selected(1)
	var persisted := ConfigFile.new()
	assert(persisted.load(city.settings_path) == OK)
	assert(persisted.get_value("display", "mode") == "fit")
	city.display_mode = "fill"
	city._load_display_mode()
	assert(city.display_mode == "fit")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(city.settings_path))
	city.free()
	print("SMOKE_TEST_PASSED")
	quit(0)
