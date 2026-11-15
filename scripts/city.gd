extends Node2D

const BACKDROP: Texture2D = preload("res://assets/city-clean.png")
const APPROVED_BACKGROUND: Texture2D = preload("res://assets/shenzhen-no-sun.png")
const METRO: Texture2D = preload("res://assets/metro.png")
const WALK: Texture2D = preload("res://assets/manga-walk.png")
const WALK_EXTRA: Texture2D = preload("res://assets/kyoto-star-walk.png")
const VEHICLES: Texture2D = preload("res://assets/city-vehicles.png")
const CLOUD: Texture2D = preload("res://assets/weather-cloud.png")
const UFO: Texture2D = preload("res://assets/ufo-cc0.png")
const Residents = preload("res://scripts/residents.gd")
const METRO_SOURCE := Rect2(9, 273, 2155, 216)
const WEATHER_URL := "https://api.open-meteo.com/v1/forecast?latitude=22.5431&longitude=114.0579&current=temperature_2m,weather_code,is_day&timezone=Asia%2FShanghai"
const CACHE_PATH := "user://weather.json"
const WEATHER_REFRESH_SECONDS := 1800.0
const HTTP_TIMEOUT_SECONDS := 20.0

var weather: Dictionary = {}
var weather_status := "天气尚未更新"
var request_in_flight := false
var time_until_refresh := 0.0
var elapsed := 0.0
var animation_time := 0.0
var settings_timer := 0.0
var display_mode := "sky"
var settings_path := ""
var panel_visible := true
var _http: HTTPRequest
var _panel: PanelContainer
var _status_label: Label
var _mode_select: OptionButton
var _screen_font: SystemFont
var walk_reversed: Texture2D
var walk_extra_reversed: Texture2D
var vehicles_reversed: Texture2D
var residents = Residents.new()

func _ready() -> void:
	Engine.max_fps = 60
	DisplayServer.window_set_title("深圳像素城市 · 桌面壁纸")
	get_window().min_size = Vector2i(600, 200)
	settings_path = OS.get_environment("APPDATA").path_join("PixelCity").path_join("display.cfg")
	_load_display_mode()
	walk_reversed = _flip_texture(WALK)
	walk_extra_reversed = _flip_texture(WALK_EXTRA)
	vehicles_reversed = _flip_texture(VEHICLES)
	_http = HTTPRequest.new()
	_http.timeout = HTTP_TIMEOUT_SECONDS
	add_child(_http)
	_configure_proxy()
	_http.request_completed.connect(_on_weather_completed)
	_screen_font = SystemFont.new()
	_screen_font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "Arial"])
	_build_panel()
	if OS.get_cmdline_user_args().has("--capture-fit"):
		display_mode = "fit"
		_mode_select.select(_mode_index(display_mode))
	if OS.get_cmdline_user_args().has("--capture-sky"):
		display_mode = "sky"
		_mode_select.select(_mode_index(display_mode))
	if OS.get_cmdline_user_args().has("--wallpaper"):
		panel_visible = false
		_panel.visible = false
	_load_cache()
	_request_weather()
	_update_panel()
	queue_redraw()
	if OS.get_cmdline_user_args().has("--capture-test"):
		_capture_test.call_deferred()

func _capture_test() -> void:
	var capture_path := "user://preview-test.png"
	if OS.get_cmdline_user_args().has("--capture-start"):
		animation_time = 2.0
		capture_path = "user://preview-start.png"
	else:
		animation_time = 18.0
	if OS.get_cmdline_user_args().has("--capture-rain"):
		weather = {"code": 63}
		residents.step(0.1, animation_time, true)
		capture_path = "user://preview-rain.png"
	queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(capture_path)
	if error != OK:
		push_error("Preview capture failed: %s" % error)
	get_tree().quit()

func _configure_proxy() -> void:
	# Honour a simple HTTPS_PROXY when one is explicitly configured.
	# Proxies with credentials or IPv6 addresses are intentionally left alone.
	var proxy := OS.get_environment("HTTPS_PROXY")
	if proxy.is_empty():
		proxy = OS.get_environment("https_proxy")
	var matcher := RegEx.new()
	matcher.compile("^https?://([^/@:]+):([0-9]+)/*$")
	var found := matcher.search(proxy)
	if found:
		_http.set_https_proxy(found.get_string(1), int(found.get_string(2)))

func _build_panel() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.position = Vector2(18, 18)
	_panel.custom_minimum_size = Vector2(320, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.1, 0.88)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)
	layer.add_child(_panel)
	var column := VBoxContainer.new()
	_panel.add_child(column)
	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.81))
	_status_label.add_theme_font_size_override("font_size", 16)
	column.add_child(_status_label)
	_mode_select = OptionButton.new()
	_mode_select.add_item("填充屏幕（保持比例，可能裁切）")
	_mode_select.add_item("完整显示（保持比例，可能留边）")
	_mode_select.add_item("拉伸铺满（可能变形）")
	_mode_select.add_item("完整画面＋天空延展（推荐）")
	_mode_select.select(_mode_index(display_mode))
	_mode_select.item_selected.connect(_on_display_mode_selected)
	column.add_child(_mode_select)
	var help := Label.new()
	help.text = "F1 隐藏 / 显示信息   F11 全屏   Esc 退出"
	help.add_theme_color_override("font_color", Color(0.78, 0.8, 0.86))
	help.add_theme_font_size_override("font_size", 12)
	column.add_child(help)

func _process(delta: float) -> void:
	elapsed += delta
	animation_time += delta
	residents.step(delta, animation_time, _is_raining())
	settings_timer += delta
	time_until_refresh -= delta
	queue_redraw()
	if settings_timer >= 2.0:
		settings_timer = 0.0
		_load_display_mode()
	if time_until_refresh <= 0.0 and not request_in_flight:
		_request_weather()
	if elapsed >= 1.0:
		elapsed = 0.0
		_update_panel()
		queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	var image_size := BACKDROP.get_size()
	var target := _display_rect(size, image_size, display_mode)
	if display_mode == "sky":
		_draw_extended_sky(size, target)
	draw_texture_rect(BACKDROP, target, false)
	draw_set_transform(target.position, 0.0, target.size / image_size)
	# Keep the user's approved sky and skyline from the original image.
	var skyline := Rect2(0, 0, image_size.x, 429)
	draw_texture_rect_region(APPROVED_BACKGROUND, skyline, skyline)
	# Replace the opaque, painted-in shelter with matching street before traffic.
	draw_texture_rect_region(BACKDROP, Rect2(990, 470, 190, 94), Rect2(700, 470, 190, 94))
	_draw_sun(Time.get_datetime_dict_from_system())
	_draw_weather_sky(image_size)
	_draw_ufo()
	_draw_station_screens()
	_draw_people(true, false)
	_draw_traffic(image_size)
	_draw_people(true, true)
	_draw_foreground()
	_draw_people(false)
	_draw_street_lights(Time.get_datetime_dict_from_system())
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The approved artwork depicts dusk. Tint gently for daytime and night;
	# sunset remains unchanged. The image itself stays intact.
	var tint := _environment_tint(Time.get_datetime_dict_from_system())
	if tint.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), tint)
	if _is_snowing():
		var motion := float(Time.get_ticks_msec()) * 0.035
		for i in range(65):
			var x := fposmod(float(i * 173) + sin(motion * 0.02 + i) * 12.0, size.x)
			var y := fposmod(float(i * 97) + motion, size.y * 0.78)
			draw_circle(Vector2(x, y), 1.5, Color(0.92, 0.95, 1.0, 0.65))
	if _is_raining():
		# A small deterministic set of streaks keeps rain cheap at desktop scale.
		var motion := float(Time.get_ticks_msec()) * 0.22
		for i in range(85):
			var x := fposmod(float(i * 173) + motion * 0.25, size.x)
			var y := fposmod(float(i * 97) + motion, size.y * 0.72)
			draw_line(Vector2(x, y), Vector2(x - 4.0, y + 10.0), Color(0.75, 0.83, 1.0, 0.32), 1.0)

func _environment_tint(now: Dictionary) -> Color:
	var hour := float(now.hour) + float(now.minute) / 60.0 + float(now.second) / 3600.0
	var night := Color(0.025, 0.045, 0.16, 0.42)
	var day := Color(0.90, 0.82, 0.73, 0.09)
	var clear := Color(0.0, 0.0, 0.0, 0.0)
	if hour < 5.0 or hour >= 21.0: return night
	if hour < 7.0: return night.lerp(day, smoothstep(5.0, 7.0, hour))
	if hour < 16.0: return day
	if hour < 18.0: return day.lerp(clear, smoothstep(16.0, 18.0, hour))
	return clear.lerp(night, smoothstep(18.0, 21.0, hour))

func _sun_position(now: Dictionary) -> Vector2:
	var hour := float(now.hour) + float(now.minute) / 60.0 + float(now.second) / 3600.0
	if hour < 6.0 or hour >= 18.0: return Vector2(-100.0, -100.0)
	var progress := (hour - 6.0) / 12.0
	return Vector2(280.0 + progress * 1500.0, 132.0 - sin(progress * PI) * 78.0)

func _draw_sun(now: Dictionary) -> void:
	var pos := _sun_position(now)
	if pos.x < 0.0: return
	var hour := float(now.hour) + float(now.minute) / 60.0 + float(now.second) / 3600.0
	var fade := minf(smoothstep(6.0, 6.5, hour), 1.0 - smoothstep(17.5, 18.0, hour))
	var cover := 0.45 if _is_raining() else (0.7 if int(weather.get("code", -1)) == 3 else 1.0)
	for radius in [43, 33, 25]:
		draw_circle(pos, radius, Color(1.0, 0.69, 0.38, fade * cover * 0.045))
	draw_circle(pos, 20.0, Color(1.0, 0.91, 0.71, fade * cover * 0.9))

func _draw_weather_sky(bounds: Vector2) -> void:
	var code := int(weather.get("code", -1))
	if code not in [1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99]: return
	var heavy := _is_raining() or _is_snowing() or code in [3, 45, 48]
	var color := Color(0.72, 0.72, 0.78, 0.54) if heavy else Color(1.0, 0.93, 0.95, 0.38)
	for i in range(5):
		var x := fposmod(float(i * 515) + animation_time * (2.0 + float(i % 3)), bounds.x + 480.0) - 480.0
		var y := 5.0 + float((i * 31) % 95)
		_draw_vehicle(CLOUD, Rect2(Vector2.ZERO, CLOUD.get_size()), Rect2(x, y, 480, 160), bounds, false, color)

func _train_status(seconds: float) -> String:
	var cycle := fposmod(seconds, 100.0)
	if cycle < 19.0: return "模拟 列车进站"
	if cycle < 42.0: return "模拟 列车停站"
	if cycle < 61.0: return "模拟 列车驶离"
	return "模拟 %d秒后进站" % int(ceil(100.0 - cycle))

func _draw_station_screens() -> void:
	var now := Time.get_datetime_dict_from_system()
	var clock := "%02d:%02d" % [now.hour, now.minute]
	for x in [630, 1444]:
		draw_rect(Rect2(x, 601, 130, 33), Color("111c32"))
		draw_rect(Rect2(x, 601, 130, 3), Color("f1a265"))
		draw_string(_screen_font, Vector2(x + 4, 614), "3号线 华新  " + clock, HORIZONTAL_ALIGNMENT_LEFT, 124, 11, Color("f9e9d1"))
		draw_string(_screen_font, Vector2(x + 4, 628), _train_status(animation_time), HORIZONTAL_ALIGNMENT_LEFT, 124, 11, Color("f6bb73"))

func _draw_people(platform: bool, boarding_only: bool = false) -> void:
	for person in residents.people:
		if person.platform != platform or person.state == "onboard": continue
		if platform and ((person.state == "boarding") != boarding_only): continue
		var y := 694.0 if platform else 559.0
		if person.state == "boarding": y = lerpf(y, 675.0 if platform else 515.0, 1.0 - clampf(person.timer / 2.0, 0.0, 1.0))
		var phase := int(floor(person.walk_distance / 3.0)) % 4
		_draw_person(Vector2(person.x, y), phase, person.direction, person.id, person.state)
		if person.state == "greet":
			draw_line(Vector2(person.x + person.direction * 4, y - 21), Vector2(person.x + person.direction * 11, y - 29), Color("edb69a"), 2.0)
		if _is_raining() and not platform and person.umbrella:
			_draw_umbrella(Vector2(person.x, y - 34))
		if person.state == "greet" or fposmod(animation_time + person.id * 2.3, 18.0) < 2.5:
			_draw_mood(Vector2(person.x, y - (52 if _is_raining() and person.umbrella else 39)), person.mood)

func _draw_person(pos: Vector2, phase: int, direction: int, variant: int, state: String) -> void:
	var walking: bool = residents.people[variant].moving and (state == "walk" or state == "boarding" or state == "shelter")
	var sheet: Texture2D = WALK_EXTRA if variant >= 4 else WALK
	var cell := Vector2(sheet.get_width() / 4.0, sheet.get_height() / 4.0)
	var frame := phase if walking else 0
	var source := Rect2(frame * cell.x, (variant % 4) * cell.y, cell.x, cell.y)
	var texture: Texture2D = sheet
	if direction < 0:
		texture = walk_extra_reversed if variant >= 4 else walk_reversed
		source.position.x = sheet.get_width() - source.end.x
	var fade := clampf(residents.people[variant].timer / 2.0, 0.0, 1.0) if state == "boarding" else 1.0
	draw_texture_rect_region(texture, Rect2(pos.x - 13, pos.y - 36, 27, 36), source, Color(1, 1, 1, fade))

func _draw_umbrella(pos: Vector2) -> void:
	draw_line(pos + Vector2(0, 5), pos + Vector2(0, 18), Color("44334a"), 1.5)
	draw_colored_polygon(PackedVector2Array([pos + Vector2(-14, 6), pos + Vector2(-10, -1), pos + Vector2(-4, -5), pos + Vector2(4, -5), pos + Vector2(10, -1), pos + Vector2(14, 6)]), Color("cc6c77"))
	draw_line(pos + Vector2(-13, 6), pos + Vector2(13, 6), Color("f1bdab"), 1.0)

func _draw_mood(pos: Vector2, mood: String) -> void:
	draw_rect(Rect2(pos.x - 15, pos.y - 16, 31, 15), Color("f9ead4"))
	draw_rect(Rect2(pos.x - 14, pos.y - 15, 29, 13), Color("fff8e9"))
	draw_string(_screen_font, Vector2(pos.x - 11, pos.y - 4), mood, HORIZONTAL_ALIGNMENT_LEFT, 25, 10, Color("694651"))

func _draw_ufo() -> void:
	var cycle := fposmod(animation_time, 240.0)
	if cycle >= 16.0: return
	var x := lerpf(-50.0, 2200.0, cycle / 16.0)
	var frame := int(animation_time * 6.0) % 4
	draw_texture_rect_region(UFO, Rect2(x, 95 + sin(animation_time * 2.0) * 5.0, 38, 24), Rect2(frame * 32, 0, 32, 32))

func _light_strength(now: Dictionary) -> float:
	var seconds := int(now.hour) * 3600 + int(now.minute) * 60 + int(now.second)
	if seconds >= 18 * 3600: return clampf(float(seconds - 18 * 3600) / 300.0, 0.0, 1.0)
	if seconds < 6 * 3600: return 1.0
	if seconds < 6 * 3600 + 300: return 1.0 - float(seconds - 6 * 3600) / 300.0
	return 0.0

func _draw_street_lights(now: Dictionary) -> void:
	var strength := _light_strength(now)
	if strength <= 0.0: return
	for x in [28, 236, 390, 549, 749, 918, 1139, 1296, 1470, 1651, 1839, 2013, 2157]:
		for radius in [22, 15, 8]:
			draw_circle(Vector2(x, 404), radius, Color(1.0, 0.69, 0.35, strength * 0.025))
		draw_circle(Vector2(x, 404), 3, Color(1.0, 0.82, 0.52, strength * 0.6))

func _display_rect(view: Vector2, artwork: Vector2, mode: String) -> Rect2:
	if mode == "stretch":
		return Rect2(Vector2.ZERO, view)
	var factor := minf(view.x / artwork.x, view.y / artwork.y) if mode in ["fit", "sky"] else maxf(view.x / artwork.x, view.y / artwork.y)
	var output := artwork * factor
	if mode == "sky":
		return Rect2(Vector2((view.x - output.x) / 2.0, view.y - output.y), output)
	return Rect2((view - output) / 2.0, output)

func _draw_extended_sky(view: Vector2, target: Rect2) -> void:
	# Extend the original top-edge colour upwards, leaving the artwork undistorted.
	var top := Color("5c4a88")
	var seam := Color("b188da")
	var gradient_height := maxf(target.position.y, 1.0)
	var bands := 96
	for i in range(bands):
		var y0 := view.y * i / bands
		var y1 := view.y * (i + 1) / bands
		var t := clampf(y0 / gradient_height, 0.0, 1.0)
		draw_rect(Rect2(0, y0, view.x, y1 - y0 + 1.0), top.lerp(seam, t))
	if target.position.y > 60.0:
		for i in range(45):
			var x := fposmod(float(i * 193 + 51), view.x)
			var y := fposmod(float(i * 107 + 21), maxf(target.position.y - 20.0, 1.0))
			draw_circle(Vector2(x, y), 0.8, Color(1.0, 0.9, 0.86, 0.4))

func _mode_index(mode: String) -> int:
	return ["fill", "fit", "stretch", "sky"].find(mode) if mode in ["fill", "fit", "stretch", "sky"] else 0

func _load_display_mode() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	var value := str(config.get_value("display", "mode", "sky"))
	if value in ["fill", "fit", "stretch", "sky"] and value != display_mode:
		display_mode = value
		if _mode_select:
			_mode_select.select(_mode_index(value))
		queue_redraw()

func _on_display_mode_selected(index: int) -> void:
	display_mode = ["fill", "fit", "stretch", "sky"][index]
	DirAccess.make_dir_recursive_absolute(settings_path.get_base_dir())
	var config := ConfigFile.new()
	config.set_value("display", "mode", display_mode)
	var error := config.save(settings_path)
	if error != OK:
		push_warning("Unable to save display settings: %s" % error)
	queue_redraw()

func _flip_texture(texture: Texture2D) -> Texture2D:
	var image := texture.get_image()
	image.flip_x()
	return ImageTexture.create_from_image(image)

func _draw_vehicle(texture: Texture2D, source: Rect2, target: Rect2, bounds: Vector2, reversed: bool = false, modulate: Color = Color.WHITE) -> void:
	# Clip at the scene edges so vehicles enter and leave instead of drawing into letterboxing.
	var clipped := target.intersection(Rect2(Vector2.ZERO, bounds))
	if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
		return
	var source_x := float(texture.get_width()) - source.position.x - source.size.x if reversed else source.position.x
	var clipped_source := Rect2(
		source_x + (clipped.position.x - target.position.x) / target.size.x * source.size.x,
		source.position.y + (clipped.position.y - target.position.y) / target.size.y * source.size.y,
		clipped.size.x / target.size.x * source.size.x,
		clipped.size.y / target.size.y * source.size.y)
	draw_texture_rect_region(texture, clipped, clipped_source, modulate)

func _draw_traffic(bounds: Vector2) -> void:
	var far_bus_x := _bus_x(animation_time + 8.0, bounds.x, false)
	var far_car_x := fposmod(animation_time * 48.0 + 1250.0, bounds.x + 210.0) - 210.0
	var near_bus_x := _bus_x(animation_time + 32.0, bounds.x, true)
	var near_car_x := bounds.x - fposmod(animation_time * 41.0 + 1320.0, bounds.x + 210.0)
	# Paint by wheel baseline: a nearer vehicle occludes a farther one.
	_draw_vehicle(VEHICLES, Rect2(1285, 320, 875, 320), Rect2(far_car_x, 457, 80, 27), bounds)
	_draw_vehicle(VEHICLES, Rect2(10, 140, 1235, 495), Rect2(far_bus_x, 437, 185, 56), bounds)
	_draw_vehicle(vehicles_reversed, Rect2(1285, 320, 875, 320), Rect2(near_car_x, 495, 80, 26), bounds, true)
	_draw_vehicle(vehicles_reversed, Rect2(10, 140, 1235, 495), Rect2(near_bus_x, 480, 170, 47), bounds, true)
	# This is a visual simulation, not a live transit position or timetable.
	# The wheel baseline must coincide with the foreground rails, below the
	# platform floor rather than on the passenger walking surface.
	_draw_vehicle(METRO, METRO_SOURCE, Rect2(_train_x(animation_time, bounds.x), 658, 660, 51), bounds)

func _bus_x(seconds: float, scene_width: float, reversed: bool) -> float:
	# Each loop includes an approach, a short stop, and a departure.
	var cycle := fposmod(seconds, 70.0)
	var distance: float
	if cycle < 25.0:
		var t := cycle / 25.0
		distance = lerpf(-210.0, scene_width * 0.5 - 90.0, 1.0 - pow(1.0 - t, 2.0))
	elif cycle < 33.0:
		distance = scene_width * 0.5 - 90.0
	else:
		var t := (cycle - 33.0) / 37.0
		distance = lerpf(scene_width * 0.5 - 90.0, scene_width + 210.0, t * t)
	return scene_width - distance - 185.0 if reversed else distance

func _draw_foreground() -> void:
	# Draw the street-side structures in front of traffic; cars must not pass over
	# a station entrance or the back of the near-side bus shelter.
	for region in [Rect2(0, 470, 420, 94)]:
		draw_texture_rect_region(BACKDROP, region, region)
	# Only use the corrected right entrance patch; the approved skyline is unchanged.
	var right_region := Rect2(1755, 470, 417, 94)
	draw_texture_rect_region(BACKDROP, right_region, right_region)
	_draw_bus_shelter()

func _draw_bus_shelter() -> void:
	# The panes are transparent so the road remains visible through the shelter.
	var frame := Color("283047")
	var edge := Color("596073")
	draw_rect(Rect2(1000, 485, 170, 68), Color(0.15, 0.23, 0.34, 0.28))
	draw_colored_polygon(PackedVector2Array([Vector2(990, 485), Vector2(1000, 475), Vector2(1170, 475), Vector2(1180, 485)]), frame)
	draw_rect(Rect2(994, 483, 182, 4), edge)
	for x in [1000, 1056, 1112, 1168]:
		draw_rect(Rect2(x, 486, 4, 70), frame)
	draw_rect(Rect2(998, 553, 174, 4), frame)
	draw_rect(Rect2(1024, 538, 52, 4), Color("b97759"))
	draw_rect(Rect2(1030, 542, 3, 10), frame)
	draw_rect(Rect2(1068, 542, 3, 10), frame)
	draw_rect(Rect2(1134, 492, 21, 16), frame)
	draw_rect(Rect2(1137, 495, 15, 2), Color("e2a779"))
	draw_rect(Rect2(1137, 500, 11, 2), Color("b5b8b7"))

func _train_x(seconds: float, scene_width: float) -> float:
	var cycle := fposmod(seconds, 100.0)
	var train_x := -680.0
	if cycle < 19.0:
		var progress := cycle / 19.0
		train_x = lerpf(-680.0, 750.0, 1.0 - pow(1.0 - progress, 2.0))
	elif cycle < 42.0:
		train_x = 750.0
	elif cycle < 61.0:
		var progress := (cycle - 42.0) / 19.0
		train_x = lerpf(750.0, scene_width, progress * progress)
	return train_x

func _is_snowing() -> bool:
	return not weather.is_empty() and int(weather.code) in [71, 73, 75, 77, 85, 86]

func _is_raining() -> bool:
	if weather.is_empty():
		return false
	return int(weather.code) in [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				panel_visible = not panel_visible
				_panel.visible = panel_visible
			KEY_F11:
				var mode := DisplayServer.window_get_mode()
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_ESCAPE:
				get_tree().quit()

func _request_weather() -> void:
	time_until_refresh = WEATHER_REFRESH_SECONDS
	request_in_flight = true
	var error := _http.request(WEATHER_URL)
	if error != OK:
		request_in_flight = false
		weather_status = "天气连接失败" if weather.is_empty() else "天气更新失败，使用上次缓存"
		time_until_refresh = 300.0
		_update_panel()

func _on_weather_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	request_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		weather_status = "天气连接失败" if weather.is_empty() else "天气更新失败，使用上次缓存"
		time_until_refresh = 300.0
		_update_panel()
		return
	var payload: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not payload is Dictionary or not payload.has("current") or not payload.current is Dictionary:
		weather_status = "天气数据无效" if weather.is_empty() else "天气数据无效，使用上次缓存"
		time_until_refresh = 300.0
		_update_panel()
		return
	var current: Dictionary = payload.current
	if not current.has("temperature_2m") or not current.has("weather_code") or not current.has("time"):
		weather_status = "天气数据不完整" if weather.is_empty() else "天气数据不完整，使用上次缓存"
		time_until_refresh = 300.0
		_update_panel()
		return
	weather = {"temperature": current.temperature_2m, "code": current.weather_code, "time": current.time}
	weather_status = "Open-Meteo 模型数据"
	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(weather))
	_update_panel()

func _load_cache() -> void:
	if not FileAccess.file_exists(CACHE_PATH):
		return
	var file := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if not file:
		return
	var cached: Variant = JSON.parse_string(file.get_as_text())
	if cached is Dictionary and cached.has("temperature") and cached.has("code") and cached.has("time"):
		weather = cached
		weather_status = "上次缓存，正在更新"

func _weather_name(code: int) -> String:
	if code == 0: return "晴"
	if code in [1, 2, 3]: return "多云"
	if code in [45, 48]: return "雾"
	if code in [51, 53, 55, 56, 57]: return "毛毛雨"
	if code in [61, 63, 65, 66, 67, 80, 81, 82]: return "雨"
	if code in [71, 73, 75, 77, 85, 86]: return "雪"
	if code in [95, 96, 99]: return "雷雨"
	return "天气代码 %d" % code

func _update_panel() -> void:
	if not _status_label:
		return
	var now := Time.get_datetime_string_from_system().replace("T", " ")
	var details := weather_status
	if not weather.is_empty():
		details = "%s  %.1f°C  ·  %s\n数据时间：%s（深圳）" % [_weather_name(int(weather.code)), float(weather.temperature), weather_status, str(weather.time).replace("T", " ")]
	_status_label.text = "深圳像素城市  ·  本机时间\n%s\n%s\n车辆及班次为画面模拟" % [now, details]
