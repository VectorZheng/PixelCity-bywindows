extends Node2D

const BACKDROP: Texture2D = preload("res://assets/shenzhen-reference.png")
const WEATHER_URL := "https://api.open-meteo.com/v1/forecast?latitude=22.5431&longitude=114.0579&current=temperature_2m,weather_code,is_day&timezone=Asia%2FShanghai"
const CACHE_PATH := "user://weather.json"
const WEATHER_REFRESH_SECONDS := 1800.0
const HTTP_TIMEOUT_SECONDS := 20.0

var weather: Dictionary = {}
var weather_status := "天气尚未更新"
var request_in_flight := false
var time_until_refresh := 0.0
var elapsed := 0.0
var panel_visible := true
var _http: HTTPRequest
var _panel: PanelContainer
var _status_label: Label

func _ready() -> void:
	Engine.max_fps = 20
	DisplayServer.window_set_title("深圳像素城市 · 桌面壁纸")
	get_window().min_size = Vector2i(600, 200)
	_http = HTTPRequest.new()
	_http.timeout = HTTP_TIMEOUT_SECONDS
	add_child(_http)
	_configure_proxy()
	_http.request_completed.connect(_on_weather_completed)
	_build_panel()
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
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png("user://preview-test.png")
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
	var help := Label.new()
	help.text = "F1 隐藏 / 显示信息   F11 全屏   Esc 退出"
	help.add_theme_color_override("font_color", Color(0.78, 0.8, 0.86))
	help.add_theme_font_size_override("font_size", 12)
	column.add_child(help)

func _process(delta: float) -> void:
	elapsed += delta
	time_until_refresh -= delta
	if _is_raining():
		queue_redraw()
	if time_until_refresh <= 0.0 and not request_in_flight:
		_request_weather()
	if elapsed >= 1.0:
		elapsed = 0.0
		_update_panel()
		queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	var image_size := BACKDROP.get_size()
	var scale_factor: float = maxf(size.x / image_size.x, size.y / image_size.y)
	var target_size := image_size * scale_factor
	var target := Rect2((size - target_size) / 2.0, target_size)
	draw_texture_rect(BACKDROP, target, false)
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
	_status_label.text = "深圳像素城市  ·  本机时间\n%s\n%s\n画面中的人物与车辆为静态示意" % [now, details]
