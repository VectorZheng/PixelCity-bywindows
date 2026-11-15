extends Node2D

const BACKDROP: Texture2D = preload("res://assets/city-empty.png")
const APPROVED_BACKGROUND: Texture2D = preload("res://assets/shenzhen-reference.png")
const BUS: Texture2D = preload("res://assets/bus.png")
const CAR: Texture2D = preload("res://assets/car.png")
const METRO: Texture2D = preload("res://assets/metro.png")
const RIGHT_ENTRANCE: Texture2D = preload("res://assets/right-entrance.png")
const BUS_SOURCE := Rect2(59, 51, 2072, 626)
const CAR_SOURCE := Rect2(58, 36, 2064, 675)
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
var display_mode := "fill"
var settings_path := ""
var bus_reversed: Texture2D
var car_reversed: Texture2D
var panel_visible := true
var _http: HTTPRequest
var _panel: PanelContainer
var _status_label: Label
var _mode_select: OptionButton

func _ready() -> void:
	Engine.max_fps = 20
	DisplayServer.window_set_title("深圳像素城市 · 桌面壁纸")
	get_window().min_size = Vector2i(600, 200)
	settings_path = OS.get_environment("APPDATA").path_join("PixelCity").path_join("display.cfg")
	_load_display_mode()
	bus_reversed = _flip_texture(BUS)
	car_reversed = _flip_texture(CAR)
	_http = HTTPRequest.new()
	_http.timeout = HTTP_TIMEOUT_SECONDS
	add_child(_http)
	_configure_proxy()
	_http.request_completed.connect(_on_weather_completed)
	_build_panel()
	if OS.get_cmdline_user_args().has("--capture-fit"):
		display_mode = "fit"
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
	draw_texture_rect(BACKDROP, target, false)
	draw_set_transform(target.position, 0.0, target.size / image_size)
	# Keep the user's approved sky and skyline from the original image.
	var skyline := Rect2(0, 0, image_size.x, 429)
	draw_texture_rect_region(APPROVED_BACKGROUND, skyline, skyline)
	_draw_traffic(image_size)
	_draw_foreground()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The approved artwork depicts dusk. Tint gently for daytime and night;
	# sunset remains unchanged. The image itself stays intact.
	var hour: int = int(Time.get_datetime_dict_from_system().hour)
	var tint := Color.TRANSPARENT
	if hour >= 21 or hour < 5:
		tint = Color(0.025, 0.045, 0.16, 0.42)
	elif hour >= 19 or hour < 7:
		tint = Color(0.09, 0.07, 0.20, 0.20)
	elif hour >= 8 and hour < 17:
		tint = Color(0.90, 0.82, 0.73, 0.09)
	if tint.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), tint)
	if _is_raining():
		# A small deterministic set of streaks keeps rain cheap at desktop scale.
		var motion := float(Time.get_ticks_msec()) * 0.22
		for i in range(85):
			var x := fposmod(float(i * 173) + motion * 0.25, size.x)
			var y := fposmod(float(i * 97) + motion, size.y * 0.72)
			draw_line(Vector2(x, y), Vector2(x - 4.0, y + 10.0), Color(0.75, 0.83, 1.0, 0.32), 1.0)

func _display_rect(view: Vector2, artwork: Vector2, mode: String) -> Rect2:
	if mode == "stretch":
		return Rect2(Vector2.ZERO, view)
	var factor := minf(view.x / artwork.x, view.y / artwork.y) if mode == "fit" else maxf(view.x / artwork.x, view.y / artwork.y)
	var output := artwork * factor
	return Rect2((view - output) / 2.0, output)

func _mode_index(mode: String) -> int:
	return ["fill", "fit", "stretch"].find(mode) if mode in ["fill", "fit", "stretch"] else 0

func _load_display_mode() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	var value := str(config.get_value("display", "mode", "fill"))
	if value in ["fill", "fit", "stretch"] and value != display_mode:
		display_mode = value
		if _mode_select:
			_mode_select.select(_mode_index(value))
		queue_redraw()

func _on_display_mode_selected(index: int) -> void:
	display_mode = ["fill", "fit", "stretch"][index]
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

func _draw_vehicle(texture: Texture2D, source: Rect2, target: Rect2, bounds: Vector2, reversed: bool = false) -> void:
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
	draw_texture_rect_region(texture, clipped, clipped_source)

func _draw_traffic(bounds: Vector2) -> void:
	var far_bus_x := fposmod(animation_time * 48.0 + 620.0, bounds.x + 210.0) - 210.0
	var far_car_x := fposmod(animation_time * 48.0 + 1250.0, bounds.x + 210.0) - 210.0
	var near_bus_x := bounds.x - fposmod(animation_time * 41.0 + 700.0, bounds.x + 210.0)
	var near_car_x := bounds.x - fposmod(animation_time * 41.0 + 1320.0, bounds.x + 210.0)
	_draw_vehicle(BUS, BUS_SOURCE, Rect2(far_bus_x, 437, 185, 56), bounds)
	_draw_vehicle(CAR, CAR_SOURCE, Rect2(far_car_x, 457, 80, 27), bounds)
	_draw_vehicle(bus_reversed, BUS_SOURCE, Rect2(near_bus_x, 480, 170, 47), bounds, true)
	_draw_vehicle(car_reversed, CAR_SOURCE, Rect2(near_car_x, 495, 80, 26), bounds, true)
	# This is a visual simulation, not a live transit position or timetable.
	# The wheel baseline must coincide with the foreground rails, below the
	# platform floor rather than on the passenger walking surface.
	_draw_vehicle(METRO, METRO_SOURCE, Rect2(_train_x(animation_time, bounds.x), 658, 660, 51), bounds)

func _draw_foreground() -> void:
	# Draw the street-side structures in front of traffic; cars must not pass over
	# a station entrance or the back of the near-side bus shelter.
	for region in [Rect2(0, 470, 420, 94), Rect2(990, 470, 190, 94)]:
		draw_texture_rect_region(BACKDROP, region, region)
	# Only use the corrected right entrance patch; the approved skyline is unchanged.
	var right_region := Rect2(1755, 470, 417, 94)
	draw_texture_rect_region(RIGHT_ENTRANCE, right_region, right_region)

func _train_x(seconds: float, scene_width: float) -> float:
	var cycle := fposmod(seconds, 100.0)
	var train_x := -680.0
	if cycle < 19.0:
		train_x = lerpf(-680.0, 750.0, cycle / 19.0)
	elif cycle < 42.0:
		train_x = 750.0
	elif cycle < 61.0:
		train_x = lerpf(750.0, scene_width, (cycle - 42.0) / 19.0)
	return train_x

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
