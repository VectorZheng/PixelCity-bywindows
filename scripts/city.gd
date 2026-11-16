extends Node2D

const BACKDROP: Texture2D = preload("res://assets/city-clean.png")
const APPROVED_BACKGROUND: Texture2D = preload("res://assets/shenzhen-no-sun.png")
const METRO: Texture2D = preload("res://assets/metro.png")
const WALK: Texture2D = preload("res://assets/manga-walk.png")
const WALK_FOUR: Texture2D = preload("res://assets/character-walk-four.png")
const WALK_FIVE: Texture2D = preload("res://assets/character-walk-five.png")
const WALK_MORE: Texture2D = preload("res://assets/character-walk-more.png")
const WALK_EXTRA: Texture2D = preload("res://assets/kyoto-star-walk.png")
const SHENZHEN_BUS: Texture2D = preload("res://assets/shenzhen-bus.png")
const BUS_SOURCE := Rect2(40, 102, 2094, 563)
const SU7_YELLOW: Texture2D = preload("res://assets/su7-yellow.png")
const YU7_GREEN: Texture2D = preload("res://assets/yu7-green.png")
# The transparent generated canvases contain padding; these rectangles retain
# the complete opaque vehicles while excluding near-transparent edge noise.
const SU7_SOURCE := Rect2(33, 49, 2106, 654)
const YU7_SOURCE := Rect2(24, 64, 1941, 695)
const CLOUD: Texture2D = preload("res://assets/weather-cloud.png")
const UFO: Texture2D = preload("res://assets/ufo-cc0.png")
const Residents = preload("res://scripts/residents.gd")
const Transit = preload("res://scripts/transit.gd")
const WeatherEffects = preload("res://addons/weather_fx/weather_fx.gd")
const COMPACT_STATION_SHIFT := 400.0
const METRO_SOURCE := Rect2(9, 273, 2155, 216)
const WEATHER_URL := "https://api.open-meteo.com/v1/forecast?latitude=22.5431&longitude=114.0579&current=temperature_2m,weather_code,is_day&timezone=Asia%2FShanghai"
const CACHE_PATH := "user://weather.json"
const WEATHER_REFRESH_SECONDS := 1800.0
const HTTP_TIMEOUT_SECONDS := 20.0

var weather: Dictionary = {}
var weather_status := "天气尚未更新"
var weather_override := -1
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
var walk_sheets: Array[Texture2D] = [WALK, WALK_EXTRA, WALK_MORE, WALK_FOUR, WALK_FIVE]
var walk_sheets_reversed: Array[Texture2D] = []
var bus_reversed: Texture2D
var su7_reversed: Texture2D
var residents = Residents.new()
var rain_fx: WeatherFX
var snow_fx: WeatherFX
var fog_fx: WeatherFX
var window_lights: Array[Vector2] = []
var leaf_patches: Array[Rect2] = []

func _ready() -> void:
	Engine.max_fps = 60
	DisplayServer.window_set_title("深圳像素城市 · 桌面壁纸")
	get_window().min_size = Vector2i(600, 200)
	settings_path = OS.get_environment("APPDATA").path_join("PixelCity").path_join("preview-display.cfg")
	_load_display_mode()
	for sheet in walk_sheets:
		walk_sheets_reversed.append(_flip_texture(sheet))
	bus_reversed = _flip_texture(SHENZHEN_BUS)
	su7_reversed = _flip_texture(SU7_YELLOW)
	_http = HTTPRequest.new()
	_http.timeout = HTTP_TIMEOUT_SECONDS
	add_child(_http)
	_configure_proxy()
	_http.request_completed.connect(_on_weather_completed)
	_screen_font = SystemFont.new()
	_screen_font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "Arial"])
	_prepare_environment_details()
	_build_panel()
	_create_weather_effects()
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
	if OS.get_cmdline_user_args().has("--capture-entrance-left"):
		animation_time = 2.0
		capture_path = "user://preview-entrance-left.png"
	if OS.get_cmdline_user_args().has("--capture-entrance-right"):
		animation_time = 43.5
		capture_path = "user://preview-entrance-right.png"
	if OS.get_cmdline_user_args().has("--capture-cars"):
		animation_time = 23.4
		capture_path = "user://preview-cars.png"
	if OS.get_cmdline_user_args().has("--capture-pass"):
		animation_time = 20.0
		capture_path = "user://preview-pass.png"
	if OS.get_cmdline_user_args().has("--capture-pass-near"):
		animation_time = 66.0
		capture_path = "user://preview-pass-near.png"
	if OS.get_cmdline_user_args().has("--capture-rain"):
		weather = {"code": 63}
		_sync_weather_effects()
		residents.step(0.1, animation_time, true)
		capture_path = "user://preview-rain.png"
	if OS.get_cmdline_user_args().has("--capture-snow"):
		weather = {"code": 75}
		_sync_weather_effects()
		capture_path = "user://preview-snow.png"
	if OS.get_cmdline_user_args().has("--capture-fog"):
		weather = {"code": 45}
		_sync_weather_effects()
		capture_path = "user://preview-fog.png"
	if OS.get_cmdline_user_args().has("--capture-far-stop"):
		animation_time = 20.0
		for entry in [[8, 656.0], [9, 631.0]]:
			var far_person: Dictionary = residents.people[entry[0]]
			far_person.x = entry[1]
			far_person.state = "wait_bus" if entry[0] == 8 else "shelter"
			far_person.sit = 1.0
			far_person.moving = false
		capture_path = "user://preview-far-stop.png"
	if OS.get_cmdline_user_args().has("--capture-wait"):
		var person: Dictionary = residents.people[0]
		person.x = 1046.0
		person.state = "wait_bus"
		person.sit = 1.0
		person.moving = false
		animation_time = 30.0
		capture_path = "user://preview-wait.png"
	queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(capture_path)
	if error != OK:
		push_error("Preview capture failed: %s" % error)
	if OS.get_cmdline_user_args().has("--capture-motion"):
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://preview-motion-second.png")
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
	_mode_select.add_item("城市放大（两侧裁切）")
	_mode_select.select(_mode_index(display_mode))
	_mode_select.item_selected.connect(_on_display_mode_selected)
	column.add_child(_mode_select)
	var weather_select := OptionButton.new()
	weather_select.add_item("天气：实时数据", -1)
	weather_select.add_item("天气演示：晴", 0)
	weather_select.add_item("天气演示：雨", 63)
	weather_select.add_item("天气演示：雪", 75)
	weather_select.add_item("天气演示：雾", 45)
	weather_select.add_item("天气演示：雷雨", 95)
	weather_select.item_selected.connect(func(index: int) -> void:
		weather_override = [-1, 0, 63, 75, 45, 95][index]
		_sync_weather_effects()
		_update_panel()
		queue_redraw())
	column.add_child(weather_select)
	var help := Label.new()
	help.text = "F1 隐藏 / 显示信息   F11 全屏   Esc 退出"
	help.add_theme_color_override("font_color", Color(0.78, 0.8, 0.86))
	help.add_theme_font_size_override("font_size", 12)
	column.add_child(help)

func _process(delta: float) -> void:
	elapsed += delta
	animation_time += delta
	residents.step(delta, animation_time, _is_raining(), int(Time.get_datetime_dict_from_system().hour))
	_sync_weather_effects()
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
	_draw_environment_motion()
	# The old waterfront shelter is painted into the background. Cover its old
	# position with adjacent water, railings and pavement before moving the asset.
	for i in range(6):
		var width := minf(30.0, 155.0 - i * 30.0)
		if width > 0.0:
			draw_texture_rect_region(BACKDROP, Rect2(377 + i * 30, 407, width, 60), Rect2(545, 407, width, 60))
	# Replace the opaque, painted-in shelter with matching street before traffic.
	draw_texture_rect_region(BACKDROP, Rect2(990, 470, 190, 94), Rect2(700, 470, 190, 94))
	_draw_sun(Time.get_datetime_dict_from_system())
	_draw_weather_sky(image_size)
	_draw_ufo()
	var station_shift := _station_shift(get_viewport_rect().size, image_size, display_mode)
	if station_shift > 0.01:
		# The station artwork is baked into the background; clear both old
		# copies before drawing the relocated entrances and escalators.
		draw_texture_rect_region(BACKDROP, Rect2(0, 470, 420, 94), Rect2(500, 470, 420, 94))
		draw_texture_rect_region(BACKDROP, Rect2(1752, 470, 420, 94), Rect2(1250, 470, 420, 94))
		_draw_escalator_wall_patches()
	_draw_road_edges(image_size.x)
	if station_shift > 0.01:
		# Remove the old painted-on screens before placing the relocated ones.
		for old_x in [630, 1444]:
			draw_texture_rect_region(BACKDROP, Rect2(old_x, 601, 130, 33), Rect2(800, 601, 130, 33))
	_draw_compact_escalators()
	_draw_station_screens()
	_draw_promenade_people()
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
	_draw_lightning(size, target)

func _prepare_environment_details() -> void:
	# Pick existing lit windows and foliage pixels from the artwork. No windows
	# are placed over sky, and the small moving patches retain the original art.
	var skyline := APPROVED_BACKGROUND.get_image()
	for y in range(180, 330, 3):
		for x in range(150, 2050, 3):
			if (x * 17 + y * 31) % 37 != 0: continue
			var c := skyline.get_pixel(x, y)
			var neighbour := skyline.get_pixel(x + 2, y)
			if c.r > 0.51 and c.g > 0.27 and c.r - c.b > 0.04 and c.r + c.g + c.b - neighbour.r - neighbour.g - neighbour.b > 0.15 and maxf(neighbour.r, maxf(neighbour.g, neighbour.b)) < 0.67:
				window_lights.append(Vector2(x, y))
	var scene := BACKDROP.get_image()
	for center in [318, 635, 850, 1055, 1220, 1380, 1590, 1860]:
		for i in range(18):
			var x: int = center - 34 + ((i * 23 + center) % 68)
			var y: int = 371 + ((i * 13 + center) % 43)
			var c := scene.get_pixel(x, y)
			if maxf(c.r, maxf(c.g, c.b)) < 0.38:
				leaf_patches.append(Rect2(x, y, 4, 3))

func _draw_environment_motion() -> void:
	var now := Time.get_datetime_dict_from_system()
	var hour := float(now.hour) + float(now.minute) / 60.0
	var evening := smoothstep(16.0, 20.0, hour) if hour >= 6.0 else 1.0
	if hour >= 6.0 and hour < 8.0: evening = 1.0 - smoothstep(6.0, 8.0, hour)
	for i in range(window_lights.size()):
		var p := window_lights[i]
		var pulse := 0.5 + 0.5 * sin(animation_time * (0.35 + 0.09 * (i % 5)) + i * 2.4)
		var alpha := (0.04 + 0.43 * evening) * smoothstep(0.25, 0.85, pulse)
		draw_rect(Rect2(p, Vector2(2, 2)), Color(1.0, 0.76, 0.42, alpha))
	for i in range(leaf_patches.size()):
		var patch := leaf_patches[i]
		var sway := sin(animation_time * 1.1 + patch.position.x * 0.014) * 1.4
		draw_texture_rect_region(BACKDROP, Rect2(patch.position + Vector2(sway, 0), patch.size), patch)

func _draw_lightning(size: Vector2, target: Rect2) -> void:
	if _visual_weather_code() not in [95, 96, 99]: return
	var pulse := fposmod(animation_time, 19.0)
	if pulse >= 0.22: return
	var intensity := 0.12 * (1.0 - pulse / 0.22)
	var ground_y := clampf(target.position.y + target.size.y * 560.0 / 724.0, 0.0, size.y)
	draw_rect(Rect2(0, 0, size.x, ground_y), Color(0.75, 0.83, 1.0, intensity))
	var x := size.x * 0.68
	var top := maxf(0.0, target.position.y * 0.45)
	var bolt := PackedVector2Array([Vector2(x, top), Vector2(x - 12, top + 28), Vector2(x + 4, top + 29), Vector2(x - 15, top + 60), Vector2(x - 4, top + 61), Vector2(x - 25, top + 88)])
	draw_polyline(bolt, Color(0.86, 0.91, 1.0, 0.8), 2.0)

func _create_weather_effects() -> void:
	# Weather FX Free by heyheythere (CC BY 4.0); only Preview instantiates it.
	rain_fx = WeatherEffects.add(self, "rain", {"density": 0.48, "fall_speed": 0.65, "wind": 0.18, "ground": 0.98, "splashes": 0.7, "pixel_size": 2})
	snow_fx = WeatherEffects.add(self, "snow", {"density": 0.42, "fall_speed": 0.7, "pixel_size": 2})
	fog_fx = WeatherEffects.add(self, "fog", {"density": 0.42, "ground_fog": 0.75, "pixel_size": 2})
	_sync_weather_effects()

func _sync_weather_effects() -> void:
	if not rain_fx or not snow_fx or not fog_fx: return
	var size := get_viewport_rect().size
	var target := _display_rect(size, BACKDROP.get_size(), display_mode)
	# Street is the exposed surface; don't let precipitation fall into the subway.
	var ground_y := clampf(target.position.y + target.size.y * 560.0 / 724.0, 1.0, size.y)
	var weather_size := Vector2(size.x, ground_y)
	rain_fx.size = weather_size
	snow_fx.size = weather_size
	fog_fx.position = Vector2(0.0, ground_y * 0.45)
	fog_fx.size = Vector2(size.x, ground_y * 0.55)
	var code := _visual_weather_code()
	var rain_density := 0.24 if code in [51, 53, 55, 56, 57] else (0.38 if code in [61, 63, 80, 81] else 0.52)
	rain_fx.set_param(&"density", rain_density)
	var scene_scale := target.size / BACKDROP.get_size()
	var near_roof := Rect2(target.position + Vector2(990, 475) * scene_scale, Vector2(190, 82) * scene_scale)
	var far_roof := Rect2(target.position + Vector2(Residents.FAR_SHELTER_X, 412) * scene_scale, Vector2(155, 53) * scene_scale)
	rain_fx.set_param(&"entrance_offset", _station_shift(size, BACKDROP.get_size(), display_mode))
	rain_fx.set_param(&"scene_transform", Vector4(target.position.x, target.position.y, scene_scale.x, scene_scale.y))
	rain_fx.set_param(&"shelter_a", Vector4(near_roof.position.x, near_roof.position.y, near_roof.end.x, near_roof.end.y))
	rain_fx.set_param(&"shelter_b", Vector4(far_roof.position.x, far_roof.position.y, far_roof.end.x, far_roof.end.y))
	rain_fx.visible = _is_raining()
	snow_fx.visible = _is_snowing()
	fog_fx.visible = code in [45, 48]

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
	var cover := 0.45 if _is_raining() else (0.7 if _visual_weather_code() == 3 else 1.0)
	for radius in [43, 33, 25]:
		draw_circle(pos, radius, Color(1.0, 0.69, 0.38, fade * cover * 0.045))
	draw_circle(pos, 20.0, Color(1.0, 0.91, 0.71, fade * cover * 0.9))

func _draw_weather_sky(bounds: Vector2) -> void:
	var code := _visual_weather_code()
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
	for x in ([820, 1222] if _current_station_shift() > 0.01 else [630, 1444]):
		draw_rect(Rect2(x, 601, 130, 33), Color("111c32"))
		draw_rect(Rect2(x, 601, 130, 3), Color("f1a265"))
		draw_string(_screen_font, Vector2(x + 4, 614), "3号线 华新  " + clock, HORIZONTAL_ALIGNMENT_LEFT, 124, 11, Color("f9e9d1"))
		draw_string(_screen_font, Vector2(x + 4, 628), _train_status(animation_time), HORIZONTAL_ALIGNMENT_LEFT, 124, 11, Color("f6bb73"))

func _draw_promenade_people() -> void:
	# The waterfront shelter is drawn in front of the background and behind traffic.
	var x: float = Residents.FAR_SHELTER_X
	# Move the original painted shelter itself, including its lit glass and roof.
	var original := PackedVector2Array([Vector2(377, 418), Vector2(384, 410), Vector2(514, 410), Vector2(522, 418), Vector2(516, 422), Vector2(516, 465), Vector2(382, 465), Vector2(382, 422)])
	_draw_backdrop_shape(original, Vector2(x - 377.0, 0))
	var frame := Color("283047")
	draw_rect(Rect2(x + 25, 446, 85, 3), Color("b97759"))
	draw_rect(Rect2(x + 30, 449, 3, 10), frame)
	draw_rect(Rect2(x + 103, 449, 3, 10), frame)
	var arrival: int = Transit.bus_arrival_seconds(animation_time + 8.0)
	var arrival_text := "到站" if arrival == 0 else str(arrival) + "秒"
	draw_rect(Rect2(x + 102, 425, 40, 20), Color("142332"))
	draw_string(_screen_font, Vector2(x + 104, 433), "模拟3路", HORIZONTAL_ALIGNMENT_LEFT, 38, 7, Color("f6cf8a"))
	draw_string(_screen_font, Vector2(x + 104, 442), arrival_text, HORIZONTAL_ALIGNMENT_LEFT, 38, 7, Color("e9f2df"))
	for person in residents.people:
		if person.promenade and person.state not in ["onboard", "car_onboard"]:
			var y := 465.0
			if person.state == "boarding": y = lerpf(y, 478.0, 1.0 - clampf(person.timer / 2.0, 0.0, 1.0))
			if person.state == "alighting": y = lerpf(478.0, y, 1.0 - clampf(person.timer / 2.0, 0.0, 1.0))
			_draw_resident(person, y, 0.78)

func _draw_people(platform: bool, boarding_only: bool = false) -> void:
	for person in residents.people:
		if person.platform != platform or person.promenade or person.state in ["onboard", "car_onboard"]: continue
		if platform and ((person.state in ["boarding", "alighting"]) != boarding_only): continue
		var y: float = (692.0 + (person.id % 2) * 3.0) if platform else (555.0 + (person.id % 3) * 2.0)
		if person.state == "boarding": y = lerpf(y, 675.0 if platform else 515.0, 1.0 - clampf(person.timer / 2.0, 0.0, 1.0))
		if person.state == "alighting": y = lerpf(675.0 if platform else 515.0, y, 1.0 - clampf(person.timer / 2.0, 0.0, 1.0))
		if person.state == "car_boarding": y = lerpf(y, 480.0, 1.0 - clampf(person.timer / 2.0, 0.0, 1.0))
		if person.state == "car_exit": y = lerpf(480.0, y, 1.0 - clampf(person.timer / 2.0, 0.0, 1.0))
		_draw_resident(person, y, 1.0)

func _draw_resident(person: Dictionary, y: float, scale: float) -> void:
	var phase := int(floor(person.walk_distance / 2.6)) % 4
	var pos := Vector2(person.x, y)
	_draw_person(pos, phase, person, scale)
	if person.state == "greet":
		draw_line(pos + Vector2(person.direction * 4, -21) * scale, pos + Vector2(person.direction * 11, -29) * scale, Color("edb69a"), 2.0 * scale)
	if _is_raining() and not person.platform and person.umbrella and person.state not in ["wait_bus", "car_boarding", "car_exit", "alighting"] and person.sit < 0.05:
		if person.state == "look_board":
			# Closed umbrella hangs at the person's side.
			draw_line(pos + Vector2(-7, -18) * scale, pos + Vector2(-9, -2) * scale, Color("53697d"), 2.0 * scale)
		else:
			_draw_umbrella(pos + Vector2(0, -34 * scale), scale, person.id, person.umbrella_open)
	if person.state == "look_board":
		# A small gesture and periodic head tilt make reading the display legible.
		var reach := 1.5 * sin(animation_time * 1.8)
		draw_line(pos + Vector2(3, -22) * scale, pos + Vector2(8, -25 + reach) * scale, Color("d8a18c"), 1.5 * scale)
	if person.state == "greet" or fposmod(animation_time + person.id * 2.3, 24.0) < 2.0:
		_draw_mood(pos + Vector2(0, (-52.0 if _is_raining() and person.umbrella else -39.0) * scale), person.mood)

func _draw_person(pos: Vector2, phase: int, person: Dictionary, scale: float) -> void:
	var variant: int = person.character_id
	var walking: bool = person.moving and person.state in ["walk", "boarding", "car_boarding", "car_pickup", "shelter", "wait_bus", "approach_stop"]
	var sheet_index := floori(float(variant) / 4.0)
	var sheet: Texture2D = walk_sheets[sheet_index]
	var cell := Vector2(sheet.get_width() / 4.0, sheet.get_height() / 4.0)
	var frame := phase if walking else 0
	var source := Rect2(frame * cell.x, (variant % 4) * cell.y, cell.x, cell.y)
	var texture: Texture2D = sheet
	if person.direction < 0:
		texture = walk_sheets_reversed[sheet_index]
		source.position.x = sheet.get_width() - source.end.x
	var fade := clampf(person.timer / 2.0, 0.0, 1.0) if person.state in ["boarding", "car_boarding"] else 1.0
	if person.state in ["car_exit", "alighting"]: fade = 1.0 - clampf(person.timer / 2.0, 0.0, 1.0)
	# A small grounding shadow makes the walking layer sit on the pavement.
	draw_ellipse_shadow(pos, scale, fade)
	if walking and person.sit <= 0.01:
		# A short crossfade softens each frame change while preserving the pixel art.
		var fraction := fposmod(person.walk_distance / 2.6, 1.0)
		var blend := smoothstep(0.78, 1.0, fraction)
		var next_frame := (frame + 1) % 4
		var next_source := Rect2(next_frame * cell.x, (variant % 4) * cell.y, cell.x, cell.y)
		if person.direction < 0: next_source.position.x = sheet.get_width() - next_source.end.x
		var destination := Rect2(pos.x - 13 * scale, pos.y - 36 * scale, 27 * scale, 36 * scale)
		draw_texture_rect_region(texture, destination, source, Color(1, 1, 1, fade * (1.0 - blend)))
		if blend > 0.0: draw_texture_rect_region(texture, destination, next_source, Color(1, 1, 1, fade * blend))
		return
	if person.state in ["look_board", "fold_umbrella"] and not person.moving:
		_draw_back_waiter(pos, person, scale, 0.0, fade)
		return
	if person.sit < 0.99:
		draw_texture_rect_region(texture, Rect2(pos.x - 13 * scale, pos.y - 36 * scale, 27 * scale, 36 * scale), source, Color(1, 1, 1, fade * (1.0 - person.sit)))
	if person.sit > 0.01:
		_draw_back_waiter(pos, person, scale, person.sit, fade * person.sit, person.promenade)

func _draw_back_waiter(pos: Vector2, person: Dictionary, scale: float, seated: float, opacity: float, facing_front: bool = false) -> void:
	# Rear-facing waiting poses with filled trouser legs, knees and shoes.
	var hair_colors := ["e5ae3a", "25232b", "488bd0", "563829", "773b3b", "d1b380", "e9a9bc", "65596e", "503337", "d4a55c", "c5bac1", "302e38", "a36767", "312d38", "d4b987", "43333c", "c6a686", "44333d"]
	var coat_colors := ["e07e32", "bb4b3e", "3b82bd", "375887", "686e88", "604b6f", "ca9bad", "584765", "d9dfe2", "525572", "cfdbd5", "426768", "985e6b", "506c80", "a07c73", "697489", "987b8c", "4f556b"]
	var hair := Color(hair_colors[person.character_id])
	var coat := Color(coat_colors[person.character_id])
	var outline := Color("252831")
	var pants := Color("394456")
	var shoes := Color("242c39")
	hair.a = opacity; coat.a = opacity; outline.a = opacity; pants.a = opacity; shoes.a = opacity
	var top := pos.y - (36.0 - seated * 4.0) * scale + sin(animation_time * 1.5 + person.id) * 0.25 * scale
	var x := pos.x
	var head := PackedVector2Array([Vector2(x - 8 * scale, top + 4 * scale), Vector2(x - 5 * scale, top), Vector2(x + 5 * scale, top), Vector2(x + 8 * scale, top + 4 * scale), Vector2(x + 7 * scale, top + 13 * scale), Vector2(x + 3 * scale, top + 16 * scale), Vector2(x - 6 * scale, top + 15 * scale)])
	draw_colored_polygon(head, outline)
	draw_rect(Rect2(x - 6 * scale, top + 3 * scale, 12 * scale, 11 * scale), hair)
	draw_rect(Rect2(x - 4 * scale, top + 1 * scale, 7 * scale, 3 * scale), hair.lightened(0.18))
	# The hair silhouette and small accessory keep the rear pose identifiable.
	if person.character_id == 0:
		var spikes := PackedVector2Array([Vector2(x - 7 * scale, top + 4 * scale), Vector2(x - 8 * scale, top), Vector2(x - 4 * scale, top + scale), Vector2(x - 2 * scale, top - 3 * scale), Vector2(x + scale, top), Vector2(x + 5 * scale, top - 2 * scale), Vector2(x + 7 * scale, top + 4 * scale)])
		draw_colored_polygon(spikes, hair)
		draw_rect(Rect2(x - 6 * scale, top + 7 * scale, 12 * scale, 2 * scale), Color(0.18, 0.25, 0.38, opacity))
	else:
		draw_rect(Rect2(x - 6 * scale, top + 10 * scale, 12 * scale, 3 * scale), hair.darkened(0.18))
	if facing_front:
		# The far-side seat faces the road and the viewer. Shape the face, fringe,
		# eyes and collar in layers so it reads as a character, not a block.
		var skin := Color(0.94, 0.70, 0.57, opacity)
		var face := PackedVector2Array([Vector2(x - 5 * scale, top + 6 * scale), Vector2(x + 5 * scale, top + 6 * scale), Vector2(x + 5 * scale, top + 11 * scale), Vector2(x + 3 * scale, top + 14 * scale), Vector2(x - 3 * scale, top + 14 * scale), Vector2(x - 5 * scale, top + 11 * scale)])
		draw_colored_polygon(face, skin)
		draw_rect(Rect2(x - 5 * scale, top + 5 * scale, 10 * scale, 2 * scale), hair)
		draw_rect(Rect2(x - 4 * scale, top + 8 * scale, 2 * scale, 2 * scale), outline)
		draw_rect(Rect2(x + 2 * scale, top + 8 * scale, 2 * scale, 2 * scale), outline)
		draw_rect(Rect2(x - 0.5 * scale, top + 12 * scale, scale, scale), Color(0.65, 0.32, 0.31, opacity))
		if person.character_id == 8:
			draw_rect(Rect2(x - 8 * scale, top + 4 * scale, 3 * scale, 3 * scale), Color(0.94, 0.72, 0.25, opacity))

	var body_y := top + 14 * scale
	draw_rect(Rect2(x - 8 * scale, body_y + 2 * scale, 16 * scale, 12 * scale), outline)
	draw_rect(Rect2(x - 6 * scale, body_y + 3 * scale, 12 * scale, 10 * scale), coat)
	draw_rect(Rect2(x - 3 * scale, body_y + 4 * scale, 6 * scale, 2 * scale), coat.lightened(0.14))
	if facing_front:
		draw_rect(Rect2(x - scale, body_y + 4 * scale, 2 * scale, 4 * scale), Color(0.58, 0.20, 0.24, opacity))
	var hip_y := lerpf(pos.y - 13 * scale, pos.y - 10 * scale, seated)
	for side in [-1, 1]:
		var leg_x := x + (float(side) * 3.5 - 2.5) * scale
		draw_rect(Rect2(leg_x, hip_y, 5 * scale, 7 * scale), pants)
		draw_rect(Rect2(leg_x + scale, hip_y + scale, 3 * scale, 2 * scale), pants.lightened(0.18))
		draw_rect(Rect2(leg_x - scale * 0.5, hip_y + 6 * scale, 6 * scale, 3 * scale), shoes)
		draw_rect(Rect2(leg_x, hip_y + 8 * scale, 5 * scale, scale), Color(0.64, 0.64, 0.62, opacity))


func draw_ellipse_shadow(pos: Vector2, scale: float, opacity: float) -> void:
	var points := PackedVector2Array([pos + Vector2(-8, -1) * scale, pos + Vector2(-5, -3) * scale, pos + Vector2(5, -3) * scale, pos + Vector2(8, -1) * scale, pos + Vector2(5, 1) * scale, pos + Vector2(-5, 1) * scale])
	draw_colored_polygon(points, Color(0.03, 0.04, 0.08, 0.28 * opacity))

func _draw_umbrella(pos: Vector2, scale: float, id: int, openness: float = 1.0) -> void:
	# A rim, curved panels and ribs read better at the tiny on-screen scale.
	var colors := [Color("c86572"), Color("59879a"), Color("cf9a55"), Color("9d7cab")]
	var base: Color = colors[(id / 2) % colors.size()]
	var shadow := base.darkened(0.34)
	var edge := Color("493843")
	var outline := PackedVector2Array([Vector2(-16, 7), Vector2(-14, 2), Vector2(-10, -4), Vector2(-5, -7), Vector2(0, -8), Vector2(5, -7), Vector2(10, -4), Vector2(14, 2), Vector2(16, 7), Vector2(10, 6), Vector2(5, 8), Vector2(0, 6), Vector2(-5, 8), Vector2(-10, 6)])
	var fill := PackedVector2Array()
	for point in outline: fill.append(_umbrella_point(pos, point, scale, openness))
	draw_colored_polygon(fill, edge)
	var panel := PackedVector2Array([Vector2(-14, 5), Vector2(-11, 0), Vector2(-7, -4), Vector2(0, -6), Vector2(7, -4), Vector2(11, 0), Vector2(14, 5), Vector2(9, 4), Vector2(5, 6), Vector2(0, 4), Vector2(-5, 6), Vector2(-9, 4)])
	var panel_points := PackedVector2Array()
	for point in panel: panel_points.append(_umbrella_point(pos, point, scale, openness))
	draw_colored_polygon(panel_points, base)
	draw_line(_umbrella_point(pos, Vector2(0, -6), scale, openness), _umbrella_point(pos, Vector2(-5, 5), scale, openness), shadow, 1.1 * scale)
	draw_line(_umbrella_point(pos, Vector2(0, -6), scale, openness), _umbrella_point(pos, Vector2(5, 5), scale, openness), shadow, 1.1 * scale)
	draw_line(_umbrella_point(pos, Vector2(-7, -2), scale, openness), _umbrella_point(pos, Vector2(-10, 2), scale, openness), base.lightened(0.35), 1.2 * scale)
	draw_line(pos + Vector2(0, 5) * scale, pos + Vector2(0, 17) * scale, edge, 1.4 * scale)
	draw_arc(pos + Vector2(2, 17) * scale, 2.0 * scale, 0.0, PI, 5, edge, 1.1 * scale)
	draw_rect(Rect2(pos + Vector2(-1, -9) * scale, Vector2(2, 2) * scale), base.lightened(0.45))

func _umbrella_point(origin: Vector2, point: Vector2, scale: float, openness: float) -> Vector2:
	var width := lerpf(0.1, 1.0, openness)
	return origin + Vector2(point.x * width, point.y + (1.0 - openness) * 10.0) * scale

func _draw_mood(pos: Vector2, mood: String) -> void:
	# Draw a small coloured emoji so it remains visible without an emoji font.
	var bubble := Rect2(pos.x - 11, pos.y - 21, 22, 20)
	draw_rect(bubble.grow(1), Color("5e5365"))
	draw_rect(bubble, Color("fff8e9"))
	draw_colored_polygon(PackedVector2Array([Vector2(pos.x - 3, pos.y - 1), Vector2(pos.x + 3, pos.y - 1), Vector2(pos.x, pos.y + 3)]), Color("fff8e9"))
	var center := pos + Vector2(0, -11)
	draw_circle(center, 7.0, Color("ffd56b"))
	draw_circle(center + Vector2(-3, -1), 1.0, Color("5b3f3c"))
	draw_circle(center + Vector2(3, -1), 1.0, Color("5b3f3c"))
	if mood in ["下雨", "避雨"]:
		draw_line(center + Vector2(-3, 4), center + Vector2(3, 4), Color("76504b"), 1.0)
		draw_circle(center + Vector2(6, -4), 1.6, Color("76b5d2"))
	elif mood == "休息":
		draw_line(center + Vector2(-3, 3), center + Vector2(3, 3), Color("76504b"), 1.0)
	else:
		draw_line(center + Vector2(-3, 2), center + Vector2(-1, 4), Color("76504b"), 1.0)
		draw_line(center + Vector2(-1, 4), center + Vector2(2, 4), Color("76504b"), 1.0)
		draw_line(center + Vector2(2, 4), center + Vector2(3, 2), Color("76504b"), 1.0)
		if mood == "你好":
			draw_circle(center + Vector2(6, -5), 2.0, Color("e97887"))

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
		# Enlarge uniformly and anchor the city to the bottom of the screen.
		# The sides crop on normal displays, leaving less empty sky.
		factor = minf(factor * 1.65, view.y / artwork.y)
		output = artwork * factor
		return Rect2(Vector2((view.x - output.x) / 2.0, view.y - output.y), output)
	return Rect2((view - output) / 2.0, output)

func _station_shift(view: Vector2, artwork: Vector2, mode: String) -> float:
	if mode != "sky": return 0.0
	var target := _display_rect(view, artwork, mode)
	var visible_left := maxf(0.0, -target.position.x / (target.size.x / artwork.x))
	return clampf(visible_left - 16.0, 0.0, COMPACT_STATION_SHIFT)

func _current_station_shift() -> float:
	return _station_shift(get_viewport_rect().size, BACKDROP.get_size(), display_mode)

func _entrance_outline(right: bool, shift: float = 0.0) -> PackedVector2Array:
	# Scene-space outlines are shared by the painter and regression tests.
	var points := PackedVector2Array([
		Vector2(1756, 554), Vector2(1904, 473), Vector2(2120, 470),
		Vector2(2140, 484), Vector2(2126, 484), Vector2(2126, 554)]) if right else PackedVector2Array([
		Vector2(32, 484), Vector2(52, 470), Vector2(268, 473),
		Vector2(415, 554), Vector2(46, 554), Vector2(46, 484)])
	var result := PackedVector2Array()
	for point in points:
		result.append(point + Vector2(-shift if right else shift, 0))
	return result

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
		# Atmospheric layers occupy the extended sky and drift at different speeds.
		# The actual city stays at its original aspect ratio below them.
		var heavy := _is_raining() or _is_snowing() or _visual_weather_code() == 3
		var opacity := 0.32 if heavy else 0.20
		for i in range(8):
			var cloud_width := view.x * (0.30 + 0.08 * (i % 3))
			var travel := view.x + cloud_width
			var x := fposmod(view.x * (0.08 + 0.31 * i) + animation_time * (3.0 + i), travel) - cloud_width * 0.5
			var y := target.position.y * (0.05 + 0.22 * (i % 3))
			var height := minf(cloud_width / 3.0, target.position.y * 0.45)
			_draw_vehicle(CLOUD, Rect2(Vector2.ZERO, CLOUD.get_size()), Rect2(x, y, cloud_width, height), view, false, Color(1.0, 0.91, 0.94, opacity))

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
	# Only the canvas edge clips the sprite. Entrances are painted later as
	# actual foreground shapes, so empty space never erases passing vehicles.
	var clipped := target.intersection(Rect2(Vector2.ZERO, bounds))
	if not clipped.has_area(): return
	var source_x := float(texture.get_width()) - source.position.x - source.size.x if reversed else source.position.x
	var clipped_source := Rect2(
		source_x + (clipped.position.x - target.position.x) / target.size.x * source.size.x,
		source.position.y + (clipped.position.y - target.position.y) / target.size.y * source.size.y,
		clipped.size.x / target.size.x * source.size.x,
		clipped.size.y / target.size.y * source.size.y)
	draw_texture_rect_region(texture, clipped, clipped_source, modulate)

func _draw_road_edges(width: float) -> void:
	# Two opposite one-way lanes are separated by the existing central barrier.
	# Edge lines make each carriageway easier to read without covering that barrier.
	draw_line(Vector2(0, 466), Vector2(width, 466), Color(0.95, 0.72, 0.46, 0.52), 1.2)
	draw_line(Vector2(0, 535), Vector2(width, 535), Color(0.95, 0.72, 0.46, 0.52), 1.2)
	for x in range(0, int(width), 125):
		draw_line(Vector2(x, 469), Vector2(minf(x + 48, width), 469), Color(0.94, 0.83, 0.69, 0.48), 1.4)
		draw_line(Vector2(x + 55, 532), Vector2(minf(x + 103, width), 532), Color(0.94, 0.83, 0.69, 0.48), 1.4)

func _car_x(seconds: float, scene_width: float, reversed: bool) -> float:
	# The far car slows for a pickup, waits, and accelerates back into traffic.
	if not reversed:
		var phase := fposmod(seconds, 60.0)
		if phase < 25.0:
			var t := phase / 25.0
			return lerpf(-210.0, 1300.0, 1.0 - pow(1.0 - t, 1.35))
		if phase < 33.0: return 1300.0
		var t := (phase - 33.0) / 27.0
		return lerpf(1300.0, scene_width + 210.0, t * t)
	var ring := scene_width + 420.0
	var distance := seconds * 65.0 + 68.0 * sin(seconds * 0.16)
	return scene_width + 25.0 - fposmod(distance - 535.0, ring)

func _passing_lane_amount(car_x: float, bus_x: float, reversed: bool) -> float:
	# Shift into the further lane before reaching the bus, then smoothly return.
	var bus_width := 170.0 if reversed else 160.0
	var direction := -1.0 if reversed else 1.0
	var relative := (car_x + 40.0 - (bus_x + bus_width / 2.0)) * direction
	return smoothstep(-240.0, -130.0, relative) * (1.0 - smoothstep(125.0, 210.0, relative))

func _draw_bus(target: Rect2, bounds: Vector2, reversed: bool) -> void:
	var texture: Texture2D = bus_reversed if reversed else SHENZHEN_BUS
	# Suspension and rotating rims follow distance and stop when the bus stops.
	target.position.y += sin(target.position.x * 0.075) * 0.35
	_draw_vehicle(texture, BUS_SOURCE, target, bounds, reversed)
	var door_open: float = Transit.bus_doors(animation_time + (32.0 if reversed else 8.0))
	var door_x := target.position.x + target.size.x * (0.59 if reversed else 0.41)
	_draw_open_door(Rect2(door_x - 5.5 * door_open, target.position.y + target.size.y * 0.23, 11.0 * door_open, target.size.y * 0.68), bounds)
	# Replace the generated decorative route text with the simulated line number.
	var sign_x := target.position.x + target.size.x * (0.19 if reversed else 0.71)
	if sign_x >= 0.0 and sign_x + target.size.x * 0.10 <= bounds.x:
		draw_rect(Rect2(sign_x, target.position.y + target.size.y * 0.21, target.size.x * 0.10, target.size.y * 0.08), Color("13232b"))
		draw_string(_screen_font, Vector2(sign_x + 2.0, target.position.y + target.size.y * 0.28), "3", HORIZONTAL_ALIGNMENT_LEFT, target.size.x * 0.09, 6, Color("ffc875"))
	var radius := target.size.y * 0.12
	var angle := target.position.x / maxf(radius, 1.0)
	for fraction in [0.252, 0.76]:
		var fx: float = 1.0 - fraction if reversed else fraction
		var center := target.position + Vector2(target.size.x * fx, target.size.y * 0.85)
		if center.x < radius or center.x > bounds.x - radius: continue
		draw_circle(center, radius * 0.78, Color("59626d"))
		draw_circle(center, radius * 0.56, Color("a8adb0"))
		for i in range(4):
			var a := angle + i * PI / 2.0
			var offset := Vector2(cos(a), sin(a)) * radius * 0.48
			draw_line(center - offset, center + offset, Color("333e4b"), 0.9)
		draw_circle(center, radius * 0.16, Color("263340"))

func _draw_car(target: Rect2, bounds: Vector2, reversed: bool, signalling: bool) -> void:
	# Near lane: yellow SU7 sedan; waterfront lane: green YU7 crossover.
	var texture: Texture2D = su7_reversed if reversed else YU7_GREEN
	var source: Rect2 = SU7_SOURCE if reversed else YU7_SOURCE
	target.position.y += sin(target.position.x * 0.09) * 0.35
	_draw_vehicle(texture, source, target, bounds, reversed)
	# The rims are redrawn above the baked tyres and rotate with travelled distance.
	var radius := target.size.y * 0.16
	var angle := target.position.x / maxf(radius, 1.0)
	var wheel_positions: Array = [0.198, 0.815] if reversed else [0.212, 0.82]
	var wheel_y := 0.76 if reversed else 0.75
	for fraction in wheel_positions:
		var fx: float = 1.0 - fraction if reversed else fraction
		var center := target.position + Vector2(target.size.x * fx, target.size.y * wheel_y)
		if center.x < radius or center.x > bounds.x - radius: continue
		draw_circle(center, radius, Color("252d35"))
		draw_circle(center, radius * 0.79, Color("78858b"))
		draw_circle(center, radius * 0.63, Color("303b43"))
		for i in range(5):
			var a := angle + i * TAU / 5.0
			var tip := Vector2(cos(a), sin(a)) * radius * 0.72
			draw_line(center, center + tip, Color("c5cccb"), 0.8)
		draw_circle(center, radius * 0.17, Color("cbd1cb"))
	if signalling and fposmod(animation_time, 1.0) < 0.55:
		var light_x := target.position.x + target.size.x * (0.96 if reversed else 0.04)
		if light_x >= 0.0 and light_x <= bounds.x:
			draw_circle(Vector2(light_x, target.position.y + target.size.y * 0.57), 2.2, Color(1.0, 0.63, 0.18, 0.35))
			draw_rect(Rect2(light_x - 1.2, target.position.y + target.size.y * 0.57 - 0.7, 2.4, 1.4), Color("ffbe45"))

func _draw_traffic(bounds: Vector2) -> void:
	var far_bus_x := _bus_x(animation_time + 8.0, bounds.x, false)
	var near_bus_x := _bus_x(animation_time + 32.0, bounds.x, true)
	var far_car_x := _car_x(animation_time, bounds.x, false)
	var near_car_x := _car_x(animation_time, bounds.x, true)
	var far_offset := _passing_lane_amount(far_car_x, far_bus_x, false) * 10.0
	var near_offset := _passing_lane_amount(near_car_x, near_bus_x, true) * 10.0
	# The passing lane is farther away, so the car is drawn beneath its bus.
	_draw_car(Rect2(far_car_x, 458.5 - far_offset, 88, 31.5), bounds, false, far_offset > 1.0 or fposmod(animation_time, 60.0) >= 22.0 and fposmod(animation_time, 60.0) < 35.0)
	_draw_bus(Rect2(far_bus_x, 447, 160, 43), bounds, false)
	_draw_car(Rect2(near_car_x, 504.7 - near_offset, 91, 28.3), bounds, true, near_offset > 1.0)
	_draw_bus(Rect2(near_bus_x, 487.3, 170, 45.7), bounds, true)
	# Visual simulation: the train runs on the rails, not the walking surface.
	var train_target := Rect2(_train_x(animation_time, bounds.x), 658, 660, 51)
	_draw_vehicle(METRO, METRO_SOURCE, train_target, bounds)
	_draw_train_wheels(train_target, bounds)
	var doors: float = Transit.train_doors(animation_time)
	if doors > 0.0:
		for fraction in [0.075, 0.205, 0.307, 0.444, 0.550, 0.690, 0.790]:
			var x: float = train_target.position.x + train_target.size.x * fraction
			_draw_open_door(Rect2(x - 5.0 * doors, 668, 10.0 * doors, 29), bounds)

func _draw_train_wheels(target: Rect2, bounds: Vector2) -> void:
	# Four-car bogies share travel distance, so they turn during approach and stop at the platform.
	var angle := target.position.x / 3.0
	for fraction in [0.044, 0.084, 0.195, 0.234, 0.283, 0.324, 0.434, 0.473, 0.518, 0.559, 0.672, 0.711, 0.765, 0.804, 0.921, 0.958]:
		var center := target.position + Vector2(target.size.x * fraction, target.size.y * 0.88)
		if center.x < 2.0 or center.x > bounds.x - 2.0: continue
		draw_circle(center, 2.0, Color("3d4955"))
		var spoke := Vector2(cos(angle), sin(angle)) * 1.5
		draw_line(center - spoke, center + spoke, Color("a7abb0"), 0.8)

func _draw_open_door(rect: Rect2, bounds: Vector2) -> void:
	if rect.size.x < 0.2: return
	var clipped := rect.intersection(Rect2(Vector2.ZERO, bounds))
	if not clipped.has_area(): return
	draw_rect(clipped, Color("1d2b3a"))
	if rect.size.x > 3.0:
		draw_line(Vector2(clipped.position.x + 1.0, clipped.position.y + 2.0), Vector2(clipped.position.x + 1.0, clipped.end.y - 3.0), Color("788995"), 1.0)
		draw_line(Vector2(clipped.end.x - 1.0, clipped.position.y + 2.0), Vector2(clipped.end.x - 1.0, clipped.end.y - 3.0), Color("788995"), 1.0)
		draw_line(Vector2(clipped.position.x, clipped.end.y - 2.0), Vector2(clipped.end.x, clipped.end.y - 2.0), Color("d9ae74"), 1.0)

func _bus_x(seconds: float, scene_width: float, reversed: bool) -> float:
	# Each loop includes an approach, a short stop, and a departure.
	var cycle := fposmod(seconds, 70.0)
	var distance: float
	var stop_distance: float = scene_width * 0.5 - 90.0 if reversed else Residents.FAR_BUS_X
	if cycle < 25.0:
		var t := cycle / 25.0
		distance = lerpf(-210.0, stop_distance, 1.0 - pow(1.0 - t, 2.0))
	elif cycle < 33.0:
		distance = stop_distance
	else:
		var t := (cycle - 33.0) / 37.0
		distance = lerpf(stop_distance, scene_width + 210.0, t * t)
	return scene_width - distance - 176.3 if reversed else distance

func _draw_escalator_wall_patches() -> void:
	# Restore the old stairwell wall underneath the moved escalators.
	var left := PackedVector2Array([Vector2(132, 568), Vector2(199, 568), Vector2(299, 667), Vector2(311, 667), Vector2(317, 673), Vector2(317, 683), Vector2(311, 691), Vector2(260, 691)])
	var right := PackedVector2Array()
	for point in left: right.append(Vector2(2172.0 - point.x, point.y))
	_draw_wall_shape(left, Vector2(800, 0))
	_draw_wall_shape(right, Vector2(-800, 0))

func _draw_wall_shape(points: PackedVector2Array, source_offset: Vector2) -> void:
	var uvs := PackedVector2Array()
	for point in points: uvs.append((point + source_offset) / BACKDROP.get_size())
	draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, BACKDROP)

func _draw_compact_escalators() -> void:
	var shift := _current_station_shift()
	if shift <= 0.01: return
	# Move both complete staircases with the entrances into the cropped view.
	var left := PackedVector2Array([
		Vector2(132, 568), Vector2(199, 568), Vector2(299, 667),
		Vector2(311, 667), Vector2(317, 673), Vector2(317, 683),
		Vector2(311, 691), Vector2(260, 691)])
	var right := PackedVector2Array()
	for point in left: right.append(Vector2(2172.0 - point.x, point.y))
	_draw_backdrop_shape(left, Vector2(shift, 0))
	_draw_backdrop_shape(right, Vector2(-shift, 0))

func _draw_foreground() -> void:
	# Only redraw station silhouettes, so the road around them never clips cars.
	var shift := _current_station_shift()
	var left := _entrance_outline(false)
	_draw_backdrop_shape(left, Vector2(shift, 0))
	# The right-hand source has its own shape; its visible position mirrors the left.
	_draw_backdrop_shape(_entrance_outline(true), Vector2(-shift, 0))
	_draw_bus_shelter()

func _draw_backdrop_shape(source_points: PackedVector2Array, offset: Vector2) -> void:
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	for point in source_points:
		vertices.append(point + offset)
		uvs.append(point / BACKDROP.get_size())
	draw_polygon(vertices, PackedColorArray([Color.WHITE]), uvs, BACKDROP)

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
	draw_rect(Rect2(1018, 538, 82, 4), Color("b97759"))
	draw_rect(Rect2(1028, 542, 3, 10), frame)
	draw_rect(Rect2(1090, 542, 3, 10), frame)
	# A legible simulated route board, synced to the near-side bus stop.
	var board := Rect2(1074, 489, 91, 38)
	draw_rect(board.grow(2), Color("202b3c"))
	draw_rect(board, Color("111b26"))
	draw_rect(Rect2(board.position.x, board.position.y, board.size.x, 2), Color("d89456"))
	var arrival: int = Transit.bus_arrival_seconds(animation_time + 32.0)
	var arrival_text := "已到站" if arrival == 0 else str(arrival) + " 秒后到站"
	draw_string(_screen_font, Vector2(1080, 503), "模拟 3 路", HORIZONTAL_ALIGNMENT_LEFT, 80, 11, Color("f6cf8a"))
	draw_string(_screen_font, Vector2(1080, 519), arrival_text, HORIZONTAL_ALIGNMENT_LEFT, 80, 10, Color("e9f2df"))

func _train_x(seconds: float, scene_width: float) -> float:
	return Transit.train_position(seconds, scene_width)

func _visual_weather_code() -> int:
	return weather_override if weather_override >= 0 else int(weather.get("code", -1))

func _is_snowing() -> bool:
	return _visual_weather_code() in [71, 73, 75, 77, 85, 86]

func _is_raining() -> bool:
	return _visual_weather_code() in [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99]

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
	var demonstration := "\n画面天气：%s（演示）" % _weather_name(weather_override) if weather_override >= 0 else ""
	var walking := 0
	var waiting := 0
	var riding := 0
	for person in residents.people:
		if person.state in ["onboard", "car_onboard"]: riding += 1
		elif person.state == "wait_bus": waiting += 1
		elif person.moving: walking += 1
	_status_label.text = "深圳像素城市  ·  本机时间\n%s\n%s%s\n居民：%d 步行 · %d 候车 · %d 乘车\n车辆及班次为画面模拟" % [now, details, demonstration, walking, waiting, riding]
