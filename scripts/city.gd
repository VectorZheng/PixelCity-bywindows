extends Node2D

const BACKDROP: Texture2D = preload("res://assets/city-clean.png")
const APPROVED_BACKGROUND: Texture2D = preload("res://assets/shenzhen-no-sun.png")
# Pre-composited by tools/build_layers.py: skyline + street with feathered seams
# and without the painted-in shelters (compact also without the old entrances).
const BASE: Texture2D = preload("res://assets/layers/city-base.png")
const WINDOWS: Texture2D = preload("res://assets/layers/city-windows.png")
const ENTRANCE_ART: Texture2D = preload("res://assets/huaxin-entrances.png")
const SHELTER_ART: Texture2D = preload("res://assets/shenzhen-shelter.png")
const SHELTER_SOURCE := Rect2(37, 71, 1835, 722)
const METRO: Texture2D = preload("res://assets/shenzhen-metro3.png")
const WALK: Texture2D = preload("res://assets/manga-walk.png")
const WALK_FOUR: Texture2D = preload("res://assets/character-walk-four.png")
const WALK_FIVE: Texture2D = preload("res://assets/character-walk-five.png")
const WALK_MORE: Texture2D = preload("res://assets/character-walk-more.png")
const WALK_EXTRA: Texture2D = preload("res://assets/kyoto-star-walk.png")
# Procedural realistic citizens (tools/gen_real_people.py): 8 frames, 2 px per scene pixel.
const REAL_SHEETS: Array[Texture2D] = [preload("res://assets/people-real/real-walk-0.png"), preload("res://assets/people-real/real-walk-1.png"), preload("res://assets/people-real/real-walk-2.png"), preload("res://assets/people-real/real-walk-3.png"), preload("res://assets/people-real/real-walk-4.png")]
# Per cast: walk frames per row, scene pixels travelled per frame, hip line as a share of the cell.
const REAL_STAND: Array[Texture2D] = [preload("res://assets/people-real/real-stand-0.png"), preload("res://assets/people-real/real-stand-1.png"), preload("res://assets/people-real/real-stand-2.png"), preload("res://assets/people-real/real-stand-3.png"), preload("res://assets/people-real/real-stand-4.png")]
const CROWD_STAND: Array[Texture2D] = [preload("res://assets/people-real/crowd-stand-0.png"), preload("res://assets/people-real/crowd-stand-1.png"), preload("res://assets/people-real/crowd-stand-2.png"), preload("res://assets/people-real/crowd-stand-3.png")]
const CASTS := {"anime": {"frames": 4, "stride": 2.6, "hip": 0.62}, "real": {"frames": 8, "stride": 2.1, "hip": 0.53}}
const SHENZHEN_BUS: Texture2D = preload("res://assets/shenzhen-bus.png")
const BUS_SOURCE := Rect2(40, 102, 2094, 563)
const SU7_YELLOW: Texture2D = preload("res://assets/su7-yellow.png")
const YU7_GREEN: Texture2D = preload("res://assets/yu7-green.png")
# The transparent generated canvases contain padding; these rectangles retain
# the complete opaque vehicles while excluding near-transparent edge noise.
const SU7_SOURCE := Rect2(33, 49, 2106, 654)
const YU7_SOURCE := Rect2(24, 64, 1941, 695)
const Aircraft = preload("res://scripts/aircraft.gd")
const Residents = preload("res://scripts/residents.gd")
const Transit = preload("res://scripts/transit.gd")
const Schedule = preload("res://scripts/schedule.gd")
const Station = preload("res://scripts/station.gd")
const StationRoutes = preload("res://scripts/station_routes.gd")
const StreetDetails = preload("res://scripts/street_details.gd")
const MetroLine = preload("res://scripts/metro_line.gd")
const Cafe = preload("res://scripts/cafe.gd")
const Park = preload("res://scripts/park.gd")
const Art = preload("res://scripts/art.gd")
const Env = preload("res://scripts/environment.gd")
const MASKS: Texture2D = preload("res://assets/layers/city-masks.png")
const BACKDROP_SHADER := preload("res://shaders/backdrop.gdshader")
const AMBIENT_SHADER := preload("res://shaders/ambient.gdshader")
const EMISSIVE_SHADER := preload("res://shaders/emissive.gdshader")
const Profiles = preload("res://scripts/profiles.gd")
const Traffic = preload("res://scripts/traffic.gd")
const Crowd = preload("res://scripts/crowd.gd")
const Life = preload("res://scripts/life.gd")
const CROWD_SHEETS: Array[Texture2D] = [preload("res://assets/people-real/crowd-walk-0.png"), preload("res://assets/people-real/crowd-walk-1.png"), preload("res://assets/people-real/crowd-walk-2.png"), preload("res://assets/people-real/crowd-walk-3.png")]
# Generated recolours of the SU7 side view (tools/gen_vehicles.py) share SU7_SOURCE.
const CAR_SPRITES := {"blue": preload("res://assets/vehicles/taxi-blue.png"), "white": preload("res://assets/vehicles/car-white.png"), "black": preload("res://assets/vehicles/car-black.png"), "silver": preload("res://assets/vehicles/car-silver.png"), "yellow": preload("res://assets/su7-yellow.png")}
const SCOOTER: Texture2D = preload("res://assets/vehicles/delivery-scooter.png")
# Residents' usual hours awake (wake, sleep); sleep past midnight is < wake.
const AWAKE := [[6.0, 23.5], [7.0, 0.5], [6.5, 23.0], [8.0, 1.0], [6.5, 0.0], [6.8, 23.8], [7.5, 23.5], [9.0, 2.0], [6.2, 23.0],
	[6.0, 22.5], [6.6, 23.5], [7.2, 0.5], [5.5, 22.5], [7.0, 23.8], [6.0, 0.3], [0.0, 24.0], [6.8, 23.5], [6.0, 0.2]]
const WEATHER_SHADER := preload("res://shaders/weather_pixel.gdshader")
const COMPACT_STATION_SHIFT := 545.0
const METRO_SOURCE := Rect2(4, 277, 2164, 182)
const WEATHER_URL := "https://api.open-meteo.com/v1/forecast?latitude=22.5431&longitude=114.0579&current=temperature_2m,weather_code,is_day,cloud_cover,wind_speed_10m,precipitation&timezone=Asia%2FShanghai"
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
# Unified pixel grid: "off", "fine" (one scene pixel per cell) or "coarse" (two).
var pixel_grid := "off"
var _pixel_rect: ColorRect
var _pixel_select: OptionButton
const PIXEL_MODES := ["off", "fine", "coarse"]
var settings_path := ""
var panel_visible := true
var _http: HTTPRequest
var _panel: PanelContainer
var _status_label: Label
var _mode_select: OptionButton
var _screen_font: SystemFont
var walk_sheets: Array[Texture2D] = [WALK, WALK_EXTRA, WALK_MORE, WALK_FOUR, WALK_FIVE]
var walk_sheets_smooth: Array[Texture2D] = []
var walk_sheets_reversed: Array[Texture2D] = []
var cast := "anime"
var walk_frames := 4
var walk_stride := 2.6
var hip_ratio := 0.62
var _cast_cache := {}
var _cast_select: OptionButton
# Trouser and shoe colours of every character, sampled from its own sprite.
var leg_colors: Array[Color] = []
var shoe_colors: Array[Color] = []
var hair_colors: Array[Color] = []
var shirt_colors: Array[Color] = []
# Smoothed 0..1 weights so weather, clouds and the panel never pop in or out.
var weather_weights := {"rain": 0.0, "snow": 0.0, "fog": 0.0, "clouds": 0.0, "overcast": 0.0, "cover": 0.2}
var _panel_tween: Tween
# Hover identity card: person hit boxes are recorded in scene space while drawing.
var _hit_boxes: Array = []
var hovered_id := -1
var _card: PanelContainer
var _card_title: Label
var _card_subtitle: Label
var _card_values: Array[Label] = []
var _card_tween: Tween
var _card_refresh := 0.0
# Tests can pin the pointer; the physical cursor otherwise wins.
var pointer_override: Variant = null
# Additive light layer above the night tint, and the vehicles it lights this frame.
var _lights: Node2D
# Live background layers: sky/city art behind, ambient multiply and city lights above.
var _backdrop: Node2D
var _ambient: Node2D
var _emissive: Node2D
# Last computed environment (sun, night, ambient...) shared by the light passes.
var env := {"night": 0.0, "lamps": 0.0, "elevation": 30.0, "ambient": Color.WHITE}
# Demo clock in hours (-1 = real time); advances with animation time.
var clock_override := -1.0
var _clock_select: OptionButton
var _vehicle_lights: Array = []
var _phone_glows: Array[Vector2] = []
var bus_reversed: Texture2D
var su7_reversed: Texture2D
var residents = Residents.new()
var traffic = Traffic.new()
var crowd = Crowd.new()
var life = Life.new()
var aircraft = Aircraft.new()
var _flipped := {}
# Hover / pinned identity card: {kind, id} of the entity it describes.
var hovered := {}
var pinned := false
var _card_grid: GridContainer
var _card_hint: Label
var _card_keys := ""
# Pixel weather layer (rain, snow, fog) drawn above the city lights.
var _weather: Node2D
# Huaxin station lighting, 1 in service .. 0 after closing (emergency lights only).
var _station_light := 1.0
# Escalator treads only advance while the station is open.
var _escalator_time := 0.0

func _ready() -> void:
	Engine.max_fps = 60
	DisplayServer.window_set_title("深圳像素城市 · Preview")
	get_window().min_size = Vector2i(600, 200)
	settings_path = OS.get_environment("APPDATA").path_join("PixelCity").path_join("preview-display.cfg")
	_load_display_mode()
	_apply_cast(cast)
	bus_reversed = Art.flipped(SHENZHEN_BUS)
	su7_reversed = Art.flipped(SU7_YELLOW)
	_http = HTTPRequest.new()
	_http.timeout = HTTP_TIMEOUT_SECONDS
	add_child(_http)
	_configure_proxy()
	_http.request_completed.connect(_on_weather_completed)
	_screen_font = SystemFont.new()
	_screen_font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "Arial"])
	# Signs are drawn at 4–11 scene pixels and then scaled ~2.6× to the screen.
	# A distance-field font stays sharp at that scale instead of a blurred bitmap.
	_screen_font.multichannel_signed_distance_field = true
	_screen_font.msdf_size = 48
	_build_panel()
	_build_card()
	_backdrop = _pixel_layer(BACKDROP_SHADER, false)
	_backdrop.show_behind_parent = true
	_ambient = _shader_layer(AMBIENT_SHADER)
	_emissive = _pixel_layer(EMISSIVE_SHADER, true)
	Transit.scheduled = true
	_lights = Node2D.new()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_lights.material = additive
	_lights.draw.connect(_draw_night_lights)
	add_child(_lights)
	_weather = _shader_layer(WEATHER_SHADER)
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
	if OS.get_cmdline_user_args().has("--capture-train-entry"):
		animation_time = 15.0
		capture_path = "user://preview-train-entry.png"
	if OS.get_cmdline_user_args().has("--capture-train-leave"):
		animation_time = 52.0
		capture_path = "user://preview-train-leave.png"
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
	var grid_layer := CanvasLayer.new()
	grid_layer.layer = 2
	add_child(grid_layer)
	_pixel_rect = ColorRect.new()
	_pixel_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pixel_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grid_material := ShaderMaterial.new()
	grid_material.shader = load("res://shaders/pixel_grid.gdshader")
	_pixel_rect.material = grid_material
	_pixel_rect.hide()
	grid_layer.add_child(_pixel_rect)
	var layer := CanvasLayer.new()
	layer.layer = 4
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
	_panel.theme = _panel_theme()
	layer.add_child(_panel)
	var column := VBoxContainer.new()
	_panel.add_child(column)
	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.81))
	_status_label.add_theme_font_size_override("font_size", 16)
	column.add_child(_status_label)
	_cast_select = OptionButton.new()
	_cast_select.add_item("人物：动漫角色")
	_cast_select.add_item("人物：写实市民")
	_cast_select.select(CASTS.keys().find(cast))
	_cast_select.item_selected.connect(func(index: int) -> void:
		_apply_cast(CASTS.keys()[index])
		_save_display_settings())
	column.add_child(_cast_select)
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
	_clock_select = OptionButton.new()
	var clocks := [[-1.0, "时间：实时"], [5.5, "时间演示：黎明 05:30"], [8.0, "时间演示：早高峰 08:00"], [12.5, "时间演示：正午 12:30"],
		[17.6, "时间演示：日落 17:36"], [18.3, "时间演示：晚高峰 18:20"], [21.0, "时间演示：夜晚 21:00"], [2.5, "时间演示：深夜 02:30"]]
	for entry in clocks: _clock_select.add_item(entry[1])
	_clock_select.item_selected.connect(func(index: int) -> void:
		clock_override = clocks[index][0]
		animation_time = 0.0
		_update_panel()
		queue_redraw())
	column.add_child(_clock_select)
	_pixel_select = OptionButton.new()
	_pixel_select.add_item("像素网格：关闭（原画）")
	_pixel_select.add_item("像素网格：细")
	_pixel_select.add_item("像素网格：粗")
	_pixel_select.select(PIXEL_MODES.find(pixel_grid))
	_pixel_select.item_selected.connect(func(index: int) -> void:
		pixel_grid = PIXEL_MODES[index]
		_save_display_settings())
	column.add_child(_pixel_select)
	var help := Label.new()
	help.text = "F1 隐藏 / 显示信息   F11 全屏   Esc 退出"
	help.add_theme_color_override("font_color", Color(0.78, 0.8, 0.86))
	help.add_theme_font_size_override("font_size", 12)
	column.add_child(help)

func _build_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.custom_minimum_size = Vector2(300, 0)
	var style := _panel_box(Color(0.04, 0.06, 0.11, 0.93), Color(1.0, 0.82, 0.62, 0.28), 10)
	style.set_content_margin_all(14)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	_card.add_theme_stylebox_override("panel", style)
	layer.add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_card.add_child(column)
	_card_title = Label.new()
	_card_title.add_theme_font_size_override("font_size", 19)
	_card_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.78))
	column.add_child(_card_title)
	_card_subtitle = Label.new()
	_card_subtitle.add_theme_font_size_override("font_size", 12)
	_card_subtitle.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84))
	column.add_child(_card_subtitle)
	column.add_child(HSeparator.new())
	_card_grid = GridContainer.new()
	_card_grid.columns = 2
	_card_grid.add_theme_constant_override("h_separation", 12)
	_card_grid.add_theme_constant_override("v_separation", 5)
	column.add_child(_card_grid)
	_card_hint = Label.new()
	_card_hint.add_theme_font_size_override("font_size", 11)
	_card_hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
	column.add_child(_card_hint)
	_card.modulate.a = 0.0
	_card.hide()

func _update_hover(delta: float) -> void:
	if not _card or OS.get_cmdline_user_args().has("--wallpaper"): return
	var view := get_viewport_rect().size
	var target := _display_rect(view, BACKDROP.get_size(), display_mode)
	var scale := target.size / BACKDROP.get_size()
	var mouse: Vector2 = pointer_override if pointer_override != null else get_viewport().get_mouse_position()
	var found := _entity_at((mouse - target.position) / scale) if Rect2(Vector2.ZERO, view).has_point(mouse) else {}
	var box: Variant = _entity_box(hovered)
	if not hovered.is_empty() and box == null:
		# The person boarded, went home or the vehicle drove off.
		pinned = false
		_set_hovered({})
	elif not pinned:
		if not found.is_empty():
			if found != hovered: _set_hovered(found)
		elif not hovered.is_empty():
			# Grace zone: moving people stay readable while the pointer is near them.
			if not (box as Rect2).grow(16.0).has_point((mouse - target.position) / scale): _set_hovered({})
	if hovered.is_empty(): return
	box = _entity_box(hovered)
	_card_refresh -= delta
	if _card_refresh <= 0.0:
		_card_refresh = 0.25
		_fill_card_info(_describe(hovered))
	# The card follows the entity itself, not the pointer.
	var rect := Rect2(target.position + (box as Rect2).position * scale, (box as Rect2).size * scale)
	var card_size := _card.get_combined_minimum_size()
	var pos := Vector2(rect.end.x + 14.0, rect.position.y - 12.0)
	if pos.x + card_size.x > view.x - 8: pos.x = rect.position.x - card_size.x - 14.0
	if pos.y + card_size.y > view.y - 8: pos.y = view.y - card_size.y - 8.0
	pos = pos.clamp(Vector2(8, 8), (view - card_size - Vector2(8, 8)).max(Vector2(8, 8)))
	_card.position = _card.position.lerp(pos, 1.0 - exp(-delta * 14.0)) if _card.modulate.a > 0.05 else pos
	_card.size = card_size

func _entity_at(scene: Vector2) -> Dictionary:
	# The latest drawn entity is on top, so test in reverse draw order.
	for i in range(_hit_boxes.size() - 1, -1, -1):
		var b: Dictionary = _hit_boxes[i]
		if (b.rect as Rect2).grow(3.0).has_point(scene): return {"kind": b.kind, "id": b.id}
	return {}

func _entity_box(entity: Dictionary) -> Variant:
	if entity.is_empty(): return null
	for b in _hit_boxes:
		if b.kind == entity.kind and b.id == entity.id: return b.rect
	return null

func _is_hovered(kind: String, id: Variant) -> bool:
	return not hovered.is_empty() and hovered.kind == kind and hovered.id == id

func _set_hovered(entity: Dictionary) -> void:
	hovered = entity
	hovered_id = int(entity.id) if not entity.is_empty() and entity.kind == "resident" else -1
	_card_refresh = 0.0
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if not entity.is_empty() else Input.CURSOR_ARROW)
	if _card_tween: _card_tween.kill()
	_card_tween = create_tween()
	if not entity.is_empty():
		_card.show()
		_card_tween.tween_property(_card, "modulate:a", 1.0, 0.14)
	else:
		_card_tween.tween_property(_card, "modulate:a", 0.0, 0.18)
		_card_tween.tween_callback(_card.hide)

func _describe(entity: Dictionary) -> Dictionary:
	match str(entity.kind):
		"resident":
			var person: Dictionary = residents.people[entity.id]
			var profile := Profiles.profile(person.id)
			var lines: Array = Profiles.card_lines(person, animation_time, residents.people, now_dict(), life)
			if person.id == Cafe.OWNER_ID:
				var pose := Cafe.owner_pose(clock_seconds())
				if not pose.is_empty():
					lines = lines.filter(func(r): return str(r[0]) != "接下来")
					lines.append(["接下来", str(pose.doing)])
			return {"title": profile.name, "subtitle": "居民 · %s" % ("站台" if person.platform else ("海边" if person.promenade else "近侧街道")), "rows": lines}
		"cafe":
			var c := clock_seconds()
			var state := "营业中" if Cafe.sign_open(c) else "已打烊"
			return {"title": "街角书房 · 书店兼咖啡馆", "subtitle": "海边步道 · 远侧公交站旁",
				"rows": [["状态", state], ["营业时间", "08:00 – 22:00"], ["店长", Profiles.profile(Cafe.OWNER_ID).name], ["门口", "两把遮阳伞，四张小椅子，一块营业灯牌"]]}
		"crowd":
			for p in crowd.people:
				if p.id == entity.id: return crowd.describe(p, _is_raining())
		"traffic":
			for v in traffic.vehicles:
				if v.id == entity.id: return traffic.describe(v)
		"bus":
			return _describe_bus(str(entity.id))
		"metro":
			return _describe_metro()
		"plane":
			for f in aircraft.flights:
				if f.id == entity.id: return Aircraft.describe(f)
	return {"title": "", "subtitle": "", "rows": []}

func _describe_bus(vehicle: String) -> Dictionary:
	var phase := Transit.phase(vehicle, animation_time)
	var status := "进站中" if phase < 25.0 else ("停靠%s，开门上下客" % MetroLine.station() if phase < 33.0 else "驶离，前往下一站")
	var aboard := 0
	for person in residents.people:
		if person.state == "onboard" and person.vehicle == vehicle: aboard += 1
	var load := aboard + int(clampf(Traffic.density(_hour_float()) * 2.2, 4.0, 40.0))
	var headway := int(Schedule.headway(vehicle, Transit.clock) / 60.0)
	return {"title": "3 路公交 · 比亚迪纯电动", "subtitle": "开往%s" % ("华强北、东门方向" if vehicle == "near_bus" else "福田中心区、香蜜湖方向"),
		"rows": [["状态", status], ["车上", "约 %d 人%s" % [load, "，很挤" if load > 30 else ""]], ["发车间隔", "约 %d 分钟" % headway], ["车牌", "粤B·D%04dx" % (1234 if vehicle == "near_bus" else 6789)]]}

func _describe_metro() -> Dictionary:
	var peak := Schedule.is_peak(Transit.clock)
	return {"title": "地铁 %s" % MetroLine.line(), "subtitle": "往%s · 6 节编组 · 模拟时刻" % MetroLine.toward(),
		"rows": [["状态", _metro_status()], ["下一站", MetroLine.next_stop()], ["车厢", "早晚高峰，很挤" if peak else "有空座"], ["发车间隔", "约 %d 分钟" % int(Schedule.headway("metro", Transit.clock) / 60.0)]]}

func _fill_card_info(info: Dictionary) -> void:
	_card_title.text = MetroLine.localize(str(info.title))
	_card_subtitle.text = ("已固定 · " if pinned else "") + MetroLine.localize(str(info.subtitle))
	_card_hint.text = "点空白处取消固定" if pinned else "点击可固定信息卡"
	var rows: Array = info.rows
	var keys := "|".join(rows.map(func(r): return str(r[0])))
	if keys != _card_keys:
		_card_keys = keys
		for child in _card_grid.get_children(): child.queue_free()
		for row in rows:
			var name_label := Label.new()
			name_label.text = str(row[0])
			name_label.add_theme_font_size_override("font_size", 13)
			name_label.add_theme_color_override("font_color", Color(0.62, 0.68, 0.78))
			name_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			_card_grid.add_child(name_label)
			var value := Label.new()
			value.add_theme_font_size_override("font_size", 14)
			var highlight := str(row[0]) in ["接下来", "目的地", "任务"]
			value.add_theme_color_override("font_color", Color(1.0, 0.6, 0.42) if highlight else Color(0.94, 0.92, 0.88))
			value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			value.custom_minimum_size = Vector2(240, 0)
			_card_grid.add_child(value)
	var values := _card_grid.get_children().filter(func(c): return not c.is_queued_for_deletion())
	for i in range(rows.size()):
		if i * 2 + 1 < values.size(): values[i * 2 + 1].text = MetroLine.localize(str(rows[i][1]))
func _fill_card(person: Dictionary) -> void:
	_fill_card_info(_describe({"kind": "resident", "id": person.id}))
func _panel_box(fill: Color, border: Color, radius := 6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	box.anti_aliasing = true
	return box

func _panel_theme() -> Theme:
	# Match the dark translucent panel instead of Godot's stock grey widgets.
	var theme := Theme.new()
	var text := Color(0.93, 0.9, 0.86)
	var muted := Color(1, 1, 1, 0.07)
	for type in ["OptionButton", "Button"]:
		theme.set_stylebox("normal", type, _panel_box(muted, Color(1, 1, 1, 0.10)))
		theme.set_stylebox("hover", type, _panel_box(Color(1, 1, 1, 0.13), Color(1.0, 0.8, 0.6, 0.35)))
		theme.set_stylebox("pressed", type, _panel_box(Color(1, 1, 1, 0.18), Color(1.0, 0.8, 0.6, 0.5)))
		theme.set_stylebox("hover_pressed", type, _panel_box(Color(1, 1, 1, 0.18), Color(1.0, 0.8, 0.6, 0.5)))
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
		theme.set_color("font_color", type, text)
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_pressed_color", type, Color.WHITE)
		theme.set_color("font_focus_color", type, text)
		theme.set_font_size("font_size", type, 14)
	var popup := _panel_box(Color(0.05, 0.07, 0.12, 0.97), Color(1, 1, 1, 0.12), 8)
	popup.set_content_margin_all(6)
	theme.set_stylebox("panel", "PopupMenu", popup)
	theme.set_stylebox("hover", "PopupMenu", _panel_box(Color(1.0, 0.75, 0.55, 0.16), Color(0, 0, 0, 0), 4))
	theme.set_color("font_color", "PopupMenu", text)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	theme.set_font_size("font_size", "PopupMenu", 14)
	theme.set_constant("v_separation", "PopupMenu", 8)
	theme.set_constant("separation", "VBoxContainer", 8)
	return theme

func _set_panel_visible(shown: bool) -> void:
	panel_visible = shown
	if _panel_tween: _panel_tween.kill()
	_panel.visible = true
	_panel_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_panel_tween.tween_property(_panel, "modulate:a", 1.0 if shown else 0.0, 0.22)
	_panel_tween.parallel().tween_property(_panel, "position:y", 18.0 if shown else 8.0, 0.22)
	if not shown: _panel_tween.tween_callback(_panel.hide)

func _process(delta: float) -> void:
	elapsed += delta
	animation_time += delta
	_station_light = move_toward(_station_light, 1.0 if _station_open() else 0.0, delta / 4.0)
	_escalator_time += delta * _station_light
	residents.station_shift = _current_station_shift()
	var hour := _hour_float()
	residents.step(delta, animation_time, _is_raining(), int(hour))
	traffic.step(delta, hour, BACKDROP.get_width(), _traffic_obstacles())
	crowd.step(delta, hour, BACKDROP.get_width(), [StationRoutes.access_x(true, residents.station_shift)], _is_raining(),
		{"shift": residents.station_shift, "far_x": CAFE_DOOR_X, "cafe_open": Cafe.is_open(clock_seconds()), "open": _station_open()})
	aircraft.step(delta, BACKDROP.get_width(), float(env.get("wind", 10.0)))
	life.observe(residents.people, {"clock": clock_seconds(), "raining": _is_raining(), "weather_code": _visual_weather_code(), "today": now_dict(), "hour": int(hour)}, delta)
	_blend_weather(delta)
	_sync_weather_effects()
	_update_hover(delta)
	if _lights: _lights.queue_redraw()
	_sync_pixel_grid()
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

var draw_usec := 0   # CPU time of the last _draw (performance checks)

func _draw() -> void:
	var draw_start := Time.get_ticks_usec()
	_hit_boxes.clear()
	_phone_glows.clear()
	var size := get_viewport_rect().size
	var image_size := BACKDROP.get_size()
	var target := _display_rect(size, image_size, display_mode)
	# Sky, city art, sea and trees are drawn live by the backdrop layer behind
	# this node; ambient light and city lights are applied by layers above it.
	if _backdrop: _update_environment()
	draw_set_transform(target.position, 0.0, target.size / image_size)
	_px_scale = target.size.x / image_size.x
	_px_origin = target.position
	_draw_aircraft()
	_draw_road_edges(image_size.x)
	_draw_bus_bays()
	_draw_station_interior(image_size.x)
	_draw_station_screens()
	StreetDetails.draw_far_side(self, _screen_font, animation_time)
	# The far shore is a park now: lake, railing, lawn (court, tents, picnic),
	# promenade walkers. Drawn in front of the city, behind the near-side scene.
	var view := get_viewport_rect().size
	var shown := _display_rect(view, BACKDROP.get_size(), display_mode)
	var park_x0 := maxf(0.0, (-shown.position / (shown.size / BACKDROP.get_size())).x - 40.0)
	var park_x1 := minf(image_size.x, ((view - shown.position) / (shown.size / BACKDROP.get_size())).x + 40.0)
	Park.draw_park(self, _screen_font, animation_time, env.get("lamps", 0.0), park_x0, park_x1)
	_draw_promenade_people()
	_draw_traffic(image_size)
	_draw_platform_glass(image_size.x)
	_draw_foreground()
	_draw_compact_escalators()
	_draw_people(true, false)
	_draw_crowd_platform()
	_draw_people(true, true)
	_draw_crowd(false)
	_draw_people(false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_usec = Time.get_ticks_usec() - draw_start

# Thunderstorms: a strike every ~15 s at a pseudo-random moment and place in
# the visible sky. The bolt itself is drawn by backdrop.gdshader in sky pixels
# only, so it lands behind the skyline (and shows in the bay). The thunder
# follows 1.3 s later; some of the women out on the street jump at it.
const THUNDER_DELAY := 1.3
const STRIKE_PERIOD := 15.0
# Residents whose look is a woman (tools/gen_real_people.py LOOKS order).
const FEMALE_RESIDENTS := [2, 3, 5, 6, 9, 11, 13, 15]

static func _hash01(v: float) -> float:
	return fposmod(sin(v * 12.9898 + 4.1) * 43758.5453, 1.0)

func _lightning() -> Dictionary:
	if _visual_weather_code() not in [95, 96, 99] or weather_weights.rain < 0.05: return {}
	var k := floorf(animation_time / STRIKE_PERIOD)
	var start := k * STRIKE_PERIOD + _hash01(k) * 8.0
	if animation_time < start:
		k -= 1.0
		start = k * STRIKE_PERIOD + _hash01(k) * 8.0
	return {"k": k, "since": animation_time - start, "x": 640.0 + _hash01(k + 0.5) * 900.0, "end": 255.0 + _hash01(k + 0.25) * 75.0}

func _lightning_flash(bolt: Dictionary) -> float:
	if bolt.is_empty(): return 0.0
	var since: float = bolt.since
	if since > 0.6: return 0.0
	# Real strikes flicker: a bright flash, a brief dip, then a weaker return stroke.
	var flash := exp(-since * 22.0) + 0.55 * exp(-pow((since - 0.16) * 30.0, 2.0))
	return clampf(flash, 0.0, 1.0) * weather_weights.rain

# 0..1 jump of a startled person (key: resident id, or 1000 + crowd id).
func _startle(key: int) -> float:
	var bolt := _lightning()
	if bolt.is_empty(): return 0.0
	var t: float = float(bolt.since) - THUNDER_DELAY
	if t < 0.0 or t > 0.9: return 0.0
	if _hash01(float(key) * 1.37 + float(bolt.k) * 7.1) > 0.45: return 0.0
	return sin(PI * t / 0.9)

func _draw_startle(pos: Vector2, scale: float, amount: float) -> void:
	# Hands flung up and a yellow "!" above the head.
	if amount < 0.05: return
	var lift := 3.0 + 4.0 * amount
	for side in [-1.0, 1.0]:
		draw_line(pos + Vector2(side * 3.0, -23.0) * scale, pos + Vector2(side * 6.5, -23.0 - lift) * scale, Color("e2b296"), 1.4 * scale)
	var mark := pos + Vector2(7.0, -41.0 - 2.0 * amount) * scale
	draw_rect(Rect2(mark, Vector2(1.6, 4.0) * scale), Color(1.0, 0.82, 0.2, amount))
	draw_rect(Rect2(mark + Vector2(0, 5.0) * scale, Vector2(1.6, 1.4) * scale), Color(1.0, 0.82, 0.2, amount))

func _draw_lightning(canvas: CanvasItem, size: Vector2, target: Rect2) -> void:
	# Ground and street light up with the flash (the bolt is in the sky shader).
	var flash := _lightning_flash(_lightning())
	if flash <= 0.002: return
	var ground_y := clampf(target.position.y + target.size.y * 560.0 / 724.0, 0.0, size.y)
	canvas.draw_rect(Rect2(0, 0, size.x, ground_y), Color(0.75, 0.83, 1.0, 0.16 * flash))

func _sync_weather_effects() -> void:
	if not _weather: return
	if not is_processing(): _blend_weather(INF)
	var code := _visual_weather_code()
	var material := _weather.material as ShaderMaterial
	var target := _display_rect(get_viewport_rect().size, BACKDROP.get_size(), display_mode)
	material.set_shader_parameter(&"scene_origin", target.position)
	material.set_shader_parameter(&"scene_scale", target.size / BACKDROP.get_size())
	material.set_shader_parameter(&"time", animation_time)
	material.set_shader_parameter(&"rain", weather_weights.rain)
	material.set_shader_parameter(&"snow", weather_weights.snow)
	material.set_shader_parameter(&"fog", weather_weights.fog)
	material.set_shader_parameter(&"rain_density", 0.22 if code in [51, 53, 55, 56, 57] else (0.4 if code in [61, 63, 80, 81] else 0.6))
	var wind_kmh: float = float(weather.get("wind", 10.0)) if weather_override < 0 else 12.0
	material.set_shader_parameter(&"wind", clampf(wind_kmh / 60.0, 0.05, 0.45))
	# Nothing falls under the two shelter roofs.
	material.set_shader_parameter(&"shelter_a", Vector4(990, 476, 1180, 557))
	material.set_shader_parameter(&"shelter_b", Vector4(Residents.FAR_SHELTER_X, FAR_SHELTER_TOP + 2.0, Residents.FAR_SHELTER_X + 148.0, 481))
	_weather.visible = weather_weights.rain + weather_weights.snow + weather_weights.fog > 0.002
	_weather.queue_redraw()

func _weather_targets() -> Dictionary:
	var code := _visual_weather_code()
	return {
		"rain": 1.0 if _is_raining() else 0.0,
		"snow": 1.0 if _is_snowing() else 0.0,
		"fog": 1.0 if code in [45, 48] else 0.0,
		"clouds": 1.0 if code in [1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99] else 0.0,
		"overcast": 1.0 if _is_raining() or _is_snowing() or code in [3, 45, 48] else 0.0,
	}

func _blend_weather(delta: float) -> void:
	# About 2.5 s to settle: changes read as weather moving in, not a cut.
	var targets := _weather_targets()
	targets["cover"] = _cloud_target()
	var step := 1.0 - exp(-delta * 1.8) if is_finite(delta) else 1.0
	for key in targets:
		var value: float = lerpf(weather_weights[key], targets[key], step)
		weather_weights[key] = targets[key] if absf(value - targets[key]) < 0.002 else value

func _metro_status() -> String:
	# Platform display driven by the simulated timetable of the chosen line.
	if not Transit.in_service_now("metro"):
		var first := Schedule.first_arrival("metro")
		return "今日运营结束 首班 %02d:%02d" % [int(first / 3600.0), int(fposmod(first, 3600.0) / 60.0)]
	var phase := Transit.phase("metro", animation_time)
	if phase < 19.0: return "列车进站 往%s" % MetroLine.toward()
	if phase < 42.0: return "列车停站 请先下后上"
	if phase < 61.0: return "列车驶离"
	var wait := Transit.metro_arrival_now(animation_time)
	return "下一班 %d分%02d秒" % [wait / 60, wait % 60] if wait >= 60 else "下一班 %d秒" % wait

# Lights stay on from 15 min before the first train to 15 min after the last.
func _station_open() -> bool:
	if not Transit.scheduled: return true
	var c := clock_seconds()
	return Schedule.in_service("metro", c) or Schedule.in_service("metro", c - 900.0) or Schedule.in_service("metro", c + 900.0)

func _station_lights() -> float:
	return _station_light

func _draw_station_interior(width: float) -> void:
	Station.draw_interior(self, width)

func _draw_station_screens() -> void:
	var now := Time.get_datetime_dict_from_system()
	var clock := "%02d:%02d" % [now.hour, now.minute]
	for x in [828, 1190]:
		draw_rect(Rect2(x - 2, 578, 158, 31), Color("3b4c55"))
		draw_rect(Rect2(x, 580, 154, 27), Color("162b37"))
		draw_rect(Rect2(x, 580, 3, 27), MetroLine.colour())
		draw_string(_screen_font, Vector2(x + 8, 592), "%s  %s  %s" % [MetroLine.line(), MetroLine.station(), MetroLine.station_en()], HORIZONTAL_ALIGNMENT_LEFT, 142, 10, Color("f0f3ec"))
		draw_string(_screen_font, Vector2(x + 8, 603), clock + "  " + _metro_status(), HORIZONTAL_ALIGNMENT_LEFT, 142, 8, Color("e9d599"))

func _draw_platform_glass(width: float) -> void:
	Station.draw_glass(self, width, animation_time, _screen_font)

const FAR_SHELTER_TOP := 417.0
const FAR_WALK_Y := 479.0

func _draw_promenade_people() -> void:
	# The waterfront shelter: the same authored shelter as the near stop, a
	# little smaller with distance. Drawn behind traffic, in front of the city.
	var x: float = Residents.FAR_SHELTER_X
	draw_rect(Rect2(x + 14, FAR_SHELTER_TOP + 10, 118, 52), Color(0.26, 0.43, 0.48, 0.10))
	draw_texture_rect_region(Art.smooth(SHELTER_ART), Rect2(x, FAR_SHELTER_TOP, 148, 64), SHELTER_SOURCE)
	_draw_bus_screen(Rect2(x + 69, FAR_SHELTER_TOP + 13, 59, 20), Transit.bus_arrival_for("far_bus", animation_time), true)
	# The bookshop café right beside the stop (the far metro exit was removed).
	var clock := clock_seconds()
	Cafe.draw(self, _screen_font, clock, animation_time)
	_hit_boxes.append({"kind": "cafe", "id": 0, "rect": Rect2(Cafe.X0, Cafe.TOP, Cafe.X1 - Cafe.X0, Cafe.FLOOR - Cafe.TOP)})
	var owner_pose := Cafe.owner_pose(clock)
	for person in residents.people:
		if person.promenade and person.state not in ["onboard", "car_onboard"]:
			if person.id == Cafe.OWNER_ID and not owner_pose.is_empty():
				_draw_cafe_owner(person, owner_pose)
				continue
			var y := FAR_WALK_Y
			y = _crossing_y(person, y, 492.0)
			_draw_resident(person, y, 0.78)
	_draw_crowd(true)

func _draw_cafe_owner(person: Dictionary, pose: Dictionary) -> void:
	# The owner steps out of the door, flips the lightbox and goes back in.
	var actor := person.duplicate()
	actor.x = pose.x
	actor.direction = pose.direction
	actor.moving = pose.moving
	actor.state = "walk"
	actor.sit = 0.0
	actor.walk_distance = absf(float(pose.x) - Cafe.DOOR_X) * 1.0
	var y := FAR_WALK_Y - 4.0
	_draw_resident(actor, y, 0.78)
	if pose.get("reach", false):
		# Arm out to the sign while flipping it.
		var hand := Vector2(actor.x, y) + Vector2(4, -21) * 0.78
		draw_line(hand, Vector2(Cafe.SIGN_X + 4.0, 467.0 + sin(animation_time * 6.0)), Color("d8a18c"), 1.4)
	if pose.alpha < 1.0:
		# Fade at the doorway by overpainting the glass door.
		draw_rect(Rect2(Cafe.DOOR_X + 1, Cafe.TOP + 18, 15, Cafe.FLOOR - Cafe.TOP - 19), Color(0.18, 0.2, 0.22, 1.0 - float(pose.alpha)))


func _draw_people(platform: bool, boarding_only: bool = false) -> void:
	for person in residents.people:
		if person.platform != platform or person.promenade or person.state in ["onboard", "car_onboard"]: continue
		if person.state in StationRoutes.ESCALATOR_STATES: continue
		if platform and ((person.state in ["boarding", "alighting"]) != boarding_only): continue
		var y: float = (Station.WALK_Y + (person.id % 2) * 3.0) if platform else (555.0 + (person.id % 3) * 2.0)
		var door_y: float = 480.0 if person.state in ["car_boarding", "car_exit"] else (Station.BOARD_Y if platform else 515.0)
		y = _crossing_y(person, y, door_y)
		_draw_resident(person, y, 1.0)

const CROSSING_STATES := ["boarding", "alighting", "car_boarding", "car_exit"]

func _inside_amount(person: Dictionary) -> float:
	# 0 = standing outside, 1 = inside the vehicle. Boarding runs 0 -> 1 and
	# alighting 1 -> 0 over the same timer the simulation uses.
	if person.state not in CROSSING_STATES: return 0.0
	var duration: float = Transit.PASSENGER_TRANSITION_SECONDS if person.state in ["boarding", "alighting"] else 2.0
	var t := clampf(person.timer / duration, 0.0, 1.0)
	return 1.0 - t if person.state in ["boarding", "car_boarding"] else t

func _crossing_y(person: Dictionary, stand_y: float, door_y: float) -> float:
	# Walk up to the door, then a small step up onto the vehicle floor.
	var inside := _inside_amount(person)
	if inside <= 0.0: return stand_y
	return lerpf(stand_y, door_y, smoothstep(0.0, 0.5, inside)) - 2.5 * smoothstep(0.42, 0.62, inside)

func _hour_float() -> float:
	var now := now_dict()
	return float(now.hour) + float(now.minute) / 60.0 + float(now.second) / 3600.0

func _resident_awake(person: Dictionary) -> bool:
	# Residents go home to sleep; the night streets belong to a few night owls,
	# the station staff until closing and the 24-hour convenience store clerk.
	var span: Array = AWAKE[int(person.id) % AWAKE.size()]
	var h := _hour_float()
	var wake: float = span[0]
	var sleep: float = span[1]
	if sleep >= 24.0 and wake <= 0.0: return true
	return (h >= wake and h < sleep) if sleep > wake else (h >= wake or h < sleep)

func _draw_resident(person: Dictionary, y: float, scale: float) -> void:
	if not _resident_awake(person): return
	# Moving deeper into the carriage reads as a slight shrink before vanishing.
	scale *= 1.0 - 0.1 * smoothstep(0.55, 1.0, _inside_amount(person))
	var phase := int(floor(person.walk_distance / walk_stride)) % walk_frames
	var startle := _startle(person.id) if person.id in FEMALE_RESIDENTS and not person.platform else 0.0
	var pos := Vector2(person.x, y - 2.5 * startle * scale)
	_draw_hover_mark(person, pos, scale)
	_draw_person(pos, phase, person, scale)
	_draw_startle(pos, scale, startle)
	_hit_boxes.append({"kind": "resident", "id": person.id, "rect": Rect2(pos.x - 13 * scale, pos.y - 36 * scale, 27 * scale, 36 * scale)})
	if person.state == "greet":
		draw_line(pos + Vector2(person.direction * 4, -21) * scale, pos + Vector2(person.direction * 11, -29) * scale, Color("edb69a"), 2.0 * scale)
	if _is_raining() and not person.platform and person.umbrella and person.state not in ["wait_bus", "car_boarding", "car_exit", "alighting", "enter_metro", "exit_metro", "escalator_down", "escalator_up"] and person.sit < 0.05:
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
	var walking: bool = person.moving and person.state in ["walk", "boarding", "car_boarding", "car_pickup", "shelter", "wait_bus", "approach_stop", "approach_metro", "approach_exit", "enter_metro", "exit_metro"]
	var sheet_index := floori(float(variant) / 4.0)
	var sheet: Texture2D = walk_sheets[sheet_index]
	var cell := Vector2(sheet.get_width() / float(walk_frames), sheet.get_height() / 4.0)
	var frame := phase if walking else 0
	var source := Rect2(frame * cell.x, (variant % 4) * cell.y, cell.x, cell.y)
	var texture: Texture2D = walk_sheets_smooth[sheet_index] if sheet_index < walk_sheets_smooth.size() else sheet
	if person.direction < 0:
		texture = walk_sheets_reversed[sheet_index]
		source.position.x = sheet.get_width() - source.end.x
	# Visible until the passenger has stepped up into the doorway, then fades inside.
	var fade := 1.0 - smoothstep(0.55, 1.0, _inside_amount(person))
	if person.state in StationRoutes.INSIDE_STATES: fade *= 0.60
	if person.state in StationRoutes.ESCALATOR_STATES:
		fade *= lerpf(0.65, 1.0, smoothstep(StationRoutes.STREET_Y, StationRoutes.STREET_Y + 36.0, pos.y))
	# A small grounding shadow makes the walking layer sit on the pavement.
	draw_ellipse_shadow(pos, scale, fade)
	if walking and person.sit <= 0.01:
		# A short crossfade softens each frame change while preserving the pixel art.
		var fraction := fposmod(person.walk_distance / walk_stride, 1.0)
		var blend := smoothstep(0.93, 1.0, fraction)
		var next_frame := (frame + 1) % walk_frames
		var next_source := Rect2(next_frame * cell.x, (variant % 4) * cell.y, cell.x, cell.y)
		if person.direction < 0: next_source.position.x = sheet.get_width() - next_source.end.x
		var destination := Rect2(pos.x - 13 * scale, pos.y - 36 * scale, 27 * scale, 36 * scale)
		draw_texture_rect_region(texture, destination, source, Color(1, 1, 1, fade * (1.0 - blend)))
		if blend > 0.0: draw_texture_rect_region(texture, destination, next_source, Color(1, 1, 1, fade * blend))
		return
	_draw_posed(pos, person, scale, fade)

const SEAT_DROP := 7.0
const FAR_BUS_Y := 461.0
# Far-side trips end at the bookshop café door (the far metro exit B was removed).
const CAFE_DOOR_X := Cafe.DOOR_X + 8.0

# Performance (round 6): the sky/city and city-light shaders are evaluated
# once per SCENE pixel in an off-screen SubViewport, then shown with nearest
# upscaling. Both shaders already work on floor(scene position), so the image
# is identical, but at 2880x1800 (2.65 screen px per scene px) they cost ~7x
# less GPU time. Running them per screen pixel held the preview at ~11-14 fps,
# which made moving buses jump several pixels per frame.
var lowres_layers := false

func _pixel_layer(shader: Shader, additive: bool) -> Node2D:
	if not lowres_layers: return _shader_layer(shader)
	var vp := SubViewport.new()
	vp.disable_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.size = Vector2i(64, 64)
	var canvas := Node2D.new()
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"mask_tex", MASKS)
	material.set_shader_parameter(&"win_tex", WINDOWS)
	canvas.material = material
	canvas.draw.connect(func() -> void: canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(vp.size)), Color.WHITE))
	vp.add_child(canvas)
	add_child(vp)
	var layer := Node2D.new()
	if additive:
		var blend := CanvasItemMaterial.new()
		blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		layer.material = blend
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.set_meta("vp", vp)
	layer.set_meta("canvas", canvas)
	layer.set_meta("rect", Rect2())
	layer.draw.connect(func() -> void: layer.draw_texture_rect(vp.get_texture(), layer.get_meta("rect"), false))
	add_child(layer)
	return layer

func _layer_material(layer: Node2D) -> ShaderMaterial:
	if layer.has_meta("canvas"): return (layer.get_meta("canvas") as Node2D).material as ShaderMaterial
	return layer.material as ShaderMaterial

# Size the off-screen layer to the visible scene and return its own
# scene_origin / scene_scale (see _pixel_layer).
func _fit_pixel_layer(layer: Node2D, view: Vector2, target: Rect2, scale: Vector2) -> void:
	if not layer.has_meta("vp"):
		(layer.material as ShaderMaterial).set_shader_parameter(&"scene_origin", target.position)
		(layer.material as ShaderMaterial).set_shader_parameter(&"scene_scale", scale)
		return
	var k := maxf(scale.x, 1.0)
	var r0 := (-target.position / scale).floor()
	var r1 := ((view - target.position) / scale).ceil()
	var size := Vector2i(((r1 - r0) * scale / k).ceil())
	size = size.clamp(Vector2i(1, 1), Vector2i(8192, 8192))
	var origin := target.position + r0 * scale
	var vp: SubViewport = layer.get_meta("vp")
	if vp.size != size: vp.size = size
	layer.set_meta("rect", Rect2(origin, Vector2(size) * k))
	var material := _layer_material(layer)
	material.set_shader_parameter(&"scene_origin", -(origin - target.position) / k)
	material.set_shader_parameter(&"scene_scale", scale / k)
	(layer.get_meta("canvas") as Node2D).queue_redraw()

func _shader_layer(shader: Shader) -> Node2D:
	# A full-window rectangle whose shader does the work; drawn in child order.
	var layer := Node2D.new()
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"mask_tex", MASKS)
	material.set_shader_parameter(&"win_tex", WINDOWS)
	layer.material = material
	layer.draw.connect(func() -> void: layer.draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color.WHITE))
	add_child(layer)
	return layer

func now_dict() -> Dictionary:
	# Real local time, or the demo clock advancing with animation time.
	var now := Time.get_datetime_dict_from_system()
	if clock_override >= 0.0:
		var t := fposmod(clock_override * 3600.0 + animation_time, 86400.0)
		now.hour = int(t / 3600.0)
		now.minute = int(fposmod(t, 3600.0) / 60.0)
		now.second = int(fposmod(t, 60.0))
	return now

func clock_seconds() -> float:
	var now := now_dict()
	return float(now.hour) * 3600.0 + float(now.minute) * 60.0 + float(now.second) + fposmod(animation_time, 1.0)

func _cloud_target() -> float:
	var code := _visual_weather_code()
	if weather_override < 0 and weather.has("cloud_cover"): return clampf(float(weather.cloud_cover) / 100.0, 0.0, 1.0)
	if code == 0: return 0.05
	if code == 1: return 0.25
	if code == 2: return 0.5
	if code in [3, 45, 48]: return 0.9
	if code < 0: return 0.2
	return 0.95

func _update_environment() -> void:
	# Sun, moon, sky, ambient and city lights from the real (or demo) clock and
	# the live weather; pushed to the background, ambient and light layers.
	var now := now_dict()
	Transit.clock = clock_seconds()
	var sun := Env.sun(now)
	var moon := Env.moon(now)
	var elevation: float = sun.elevation
	var cloud: float = weather_weights.cover
	var rain: float = weather_weights.rain
	var daylight := Env.daylight(elevation)
	var colors := Env.sky_colors(elevation, cloud, rain)
	var view := get_viewport_rect().size
	var target := _display_rect(view, BACKDROP.get_size(), display_mode)
	var scale := target.size / BACKDROP.get_size()
	var golden := exp(-pow((elevation - 1.0) / 6.0, 2.0))
	var sun_color := Color(1.0, 0.9, 0.72).lerp(Color(1.0, 0.55, 0.3), golden)
	var lit := Color(1.0, 0.98, 0.96).lerp(Color(1.0, 0.68, 0.52), golden) * lerpf(1.0, 0.72, rain)
	var night_cloud := Color(0.13, 0.14, 0.16)
	var cloud_lit := night_cloud.lerp(lit, daylight)
	var wind_kmh: float = float(weather.get("wind", 10.0)) if weather_override < 0 else 12.0
	var ambient := Env.ambient(elevation, cloud, rain)
	# By day the real moon (faint, where it really is); at night the moon is
	# always present, inside the visible sky (Env.display_moon).
	var night_moon := 1.0 - smoothstep(0.15, 0.6, daylight)
	var real_moon := smoothstep(-1.0, 2.0, moon.elevation) * (1.0 - 0.75 * daylight)
	var moon_visible := maxf(night_moon, real_moon)
	var shown_moon := Env.display_moon(moon)
	if night_moon < 0.5: shown_moon = {"pos": Env.sky_position(moon), "phase": moon.phase}
	var bolt := _lightning()
	var backdrop := _layer_material(_backdrop)
	var params := {
		&"base_tex": BASE, &"horizon_y": Env.HORIZON_Y,
		&"view_top": -target.position.y / scale.y, &"time": animation_time,
		&"zenith": colors.zenith, &"horizon": colors.horizon,
		&"sun_pos": Env.sky_position(sun), &"sun_color": sun_color,
		&"sun_visible": smoothstep(-1.5, 0.5, elevation) * (1.0 - 0.7 * rain),
		&"moon_pos": shown_moon.pos, &"moon_phase": shown_moon.phase,
		&"moon_visible": moon_visible * (1.0 - 0.8 * rain),
		&"stars": (1.0 - daylight) * (1.0 - cloud * 0.85),
		&"lightning": _lightning_flash(bolt), &"bolt_x": float(bolt.get("x", -999.0)),
		&"bolt_end": float(bolt.get("end", 300.0)), &"bolt_seed": float(bolt.get("k", 0.0)),
		&"cloud_cover": cloud, &"rain": rain,
		&"cloud_lit": cloud_lit, &"cloud_shade": cloud_lit * Color(0.62, 0.64, 0.74),
		&"wind": 3.0 + wind_kmh * 0.5, &"day": daylight,
		&"fog": weather_weights.fog, &"snow": weather_weights.snow, &"overcast": weather_weights.overcast,
	}
	for key in params: backdrop.set_shader_parameter(key, params[key])
	_fit_pixel_layer(_backdrop, view, target, scale)
	_fit_pixel_layer(_emissive, view, target, scale)
	(_ambient.material as ShaderMaterial).set_shader_parameter(&"scene_origin", target.position)
	(_ambient.material as ShaderMaterial).set_shader_parameter(&"scene_scale", scale)
	(_ambient.material as ShaderMaterial).set_shader_parameter(&"ambient", ambient)
	(_ambient.material as ShaderMaterial).set_shader_parameter(&"station_light", _station_light)
	var emissive := _layer_material(_emissive)
	emissive.set_shader_parameter(&"night", 1.0 - daylight)
	emissive.set_shader_parameter(&"occupancy", Env.window_occupancy(now))
	emissive.set_shader_parameter(&"office", Env.office_occupancy(now))
	emissive.set_shader_parameter(&"clock", clock_seconds())
	emissive.set_shader_parameter(&"light_show", Env.light_show(now))
	emissive.set_shader_parameter(&"time", animation_time)
	for key in [&"rain", &"fog", &"overcast", &"wind"]: emissive.set_shader_parameter(key, params[key])
	# Precipitation and fog take the scene's light instead of glowing at night.
	if _weather:
		var weather_material := _weather.material as ShaderMaterial
		weather_material.set_shader_parameter(&"rain_color", Color(Color(0.74, 0.82, 0.96) * ambient.lerp(Color.WHITE, 0.25), 0.7))
		weather_material.set_shader_parameter(&"snow_color", Color(Color(1, 1, 1) * ambient.lerp(Color.WHITE, 0.3), 0.95))
		weather_material.set_shader_parameter(&"fog_color", Color(Color(0.87, 0.9, 0.97) * ambient, 0.85))
	env = {"night": 1.0 - daylight, "lamps": Env.street_lights(elevation), "elevation": elevation, "ambient": ambient, "sun": sun, "moon": moon, "cloud_lit": cloud_lit, "wind": wind_kmh}
	for layer in [_backdrop, _ambient, _emissive]: layer.queue_redraw()

func _apply_cast(cast_name: String) -> void:
	# Swap the whole set of character sheets. Each cast is prepared once and cached,
	# so switching back and forth never re-flips or re-samples the large sheets.
	cast = cast_name if cast_name in CASTS else "anime"
	var settings: Dictionary = CASTS[cast]
	walk_frames = settings.frames
	walk_stride = settings.stride
	hip_ratio = settings.hip
	if not _cast_cache.has(cast):
		var sheets: Array[Texture2D] = []
		if cast == "real": sheets.assign(REAL_SHEETS)
		else: sheets.assign([WALK, WALK_EXTRA, WALK_MORE, WALK_FOUR, WALK_FIVE])
		walk_sheets = sheets
		walk_sheets_smooth = []
		walk_sheets_reversed = []
		leg_colors = []
		shoe_colors = []
		hair_colors = []
		shirt_colors = []
		for sheet in sheets:
			walk_sheets_smooth.append(Art.smooth(sheet))
			walk_sheets_reversed.append(Art.flipped(sheet))
		_sample_leg_colors()
		_cast_cache[cast] = [walk_sheets, walk_sheets_smooth, walk_sheets_reversed, leg_colors, shoe_colors, hair_colors, shirt_colors]
	var cached: Array = _cast_cache[cast]
	walk_sheets = cached[0]
	walk_sheets_smooth = cached[1]
	walk_sheets_reversed = cached[2]
	leg_colors = cached[3]
	shoe_colors = cached[4]
	hair_colors = cached[5]
	shirt_colors = cached[6]
	# Pick each character's standing frame once, not on first appearance.
	for sheet in walk_sheets:
		for row in range(4): _idle_frame(sheet, walk_frames, row, sheet.get_height() / 4.0)
	if _cast_select: _cast_select.select(CASTS.keys().find(cast))
	queue_redraw()

func _sample_leg_colors() -> void:
	for sheet in walk_sheets:
		var image := sheet.get_image()
		if image.is_compressed(): image.decompress()
		var cell := Vector2i(image.get_width() / walk_frames, image.get_height() / 4)
		for row in range(4):
			var bands := [Vector2(0.70, 0.86), Vector2(0.88, 0.95), Vector2(0.03, 0.12), Vector2(0.36, 0.52)]
			var found: Array[Color] = []
			for band in bands:
				var sum := Color(0, 0, 0, 0)
				var count := 0
				for y in range(int(cell.y * band.x), int(cell.y * band.y), 3):
					for x in range(int(cell.x * 0.3), int(cell.x * 0.7), 3):
						var c := image.get_pixel(x, row * cell.y + y)
						if c.a < 0.7: continue
						sum += c
						count += 1
				found.append(Color(sum.r / count, sum.g / count, sum.b / count) if count > 0 else Color("394456"))
			leg_colors.append(found[0])
			shoe_colors.append(found[1])
			hair_colors.append(found[2])
			shirt_colors.append(found[3])

func _waiting_facing(person: Dictionary) -> int:
	# People waiting look towards where their vehicle comes from: the near bus
	# arrives from the right, the waterfront bus and the train from the left.
	if person.moving or person.state not in ["wait_bus", "shelter", "stand_up"]: return person.direction
	return -1 if person.promenade or person.platform else 1

func _draw_posed(pos: Vector2, person: Dictionary, scale: float, fade: float) -> void:
	# Standing still or seated, drawn from the character's own first walk frame so
	# every pose keeps that character's art. Sitting lowers the upper body onto
	# the bench and folds the legs forward, coloured from the sprite's trousers.
	var variant: int = person.character_id
	var sheet_index := floori(float(variant) / 4.0)
	var sheet: Texture2D = walk_sheets[sheet_index]
	var cell := Vector2(sheet.get_width() / float(walk_frames), sheet.get_height() / 4.0)
	var facing := _waiting_facing(person)
	# Standing still means upright with the feet together: the generated cast
	# has a dedicated standing sheet; the drawn cast uses its feet-closest frame.
	var texture: Texture2D = walk_sheets_smooth[sheet_index] if sheet_index < walk_sheets_smooth.size() else sheet
	var source := Rect2(_idle_frame(sheet, walk_frames, variant % 4, cell.y) * cell.x, (variant % 4) * cell.y, cell.x, cell.y)
	var source_width := float(sheet.get_width())
	if cast == "real" and sheet_index < REAL_STAND.size():
		texture = Art.smooth(REAL_STAND[sheet_index])
		source.position.x = 0.0
		source_width = cell.x
		if facing < 0: texture = _flip(REAL_STAND[sheet_index])
	elif facing < 0:
		texture = walk_sheets_reversed[sheet_index]
	if facing < 0: source.position.x = source_width - source.end.x
	var away := _faces_road(person)
	var full_fade := fade
	if away > 0.999:
		_draw_seated_back(pos, person, scale, fade)
		return
	fade *= 1.0 - away
	var sit: float = clampf(person.sit, 0.0, 1.0)
	var eased := sit * sit * (3.0 - 2.0 * sit)
	var drop := SEAT_DROP * eased * scale
	# Gentle breathing while still keeps waiting figures alive without walking.
	var breath := sin(animation_time * 1.6 + person.id) * 0.25 * scale
	var top := pos.y - 36.0 * scale
	var upper_src := Rect2(source.position, Vector2(source.size.x, source.size.y * hip_ratio))
	var lower_src := Rect2(source.position + Vector2(0, source.size.y * hip_ratio), Vector2(source.size.x, source.size.y * (1.0 - hip_ratio)))
	var upper := Rect2(pos.x - 13 * scale, top + drop + breath, 27 * scale, 36 * scale * hip_ratio)
	var tint := Color(1, 1, 1, fade)
	if eased < 0.999:
		# Standing legs compress as the figure lowers, then fade into the seated legs.
		# Drawn sprites without a true standing frame still have a slight
		# stride; squeeze the legs toward the centre so the feet stand together.
		var squeeze := 1.0 if cast == "real" else _leg_squeeze(sheet, variant % 4)
		var lower := Rect2(pos.x - 13 * scale * squeeze, upper.end.y, 27 * scale * squeeze, maxf(pos.y - upper.end.y, 0.5))
		draw_texture_rect_region(texture, lower, lower_src, Color(1, 1, 1, fade * (1.0 - eased)))
	if eased > 0.001:
		var pants: Color = leg_colors[variant] if variant < leg_colors.size() else Color("394456")
		var shoes: Color = shoe_colors[variant] if variant < shoe_colors.size() else Color("242c39")
		var outline := pants.darkened(0.5)
		pants.a = fade * eased; shoes.a = fade * eased; outline.a = fade * eased
		var hip_y := upper.end.y - 1.0 * scale
		var knee_x := pos.x + facing * 6.5 * scale
		var thigh := Rect2(minf(pos.x - facing * 2.0 * scale, knee_x), hip_y, absf(knee_x - (pos.x - facing * 2.0 * scale)), 4.0 * scale)
		var shin := Rect2(knee_x - (3.5 if facing > 0 else 0.0) * scale, hip_y + 2.0 * scale, 3.5 * scale, maxf(pos.y - 1.5 * scale - (hip_y + 2.0 * scale), scale))
		var shoe := Rect2(knee_x - (3.0 if facing > 0 else 1.5) * scale, pos.y - 2.5 * scale, 4.5 * scale, 2.0 * scale)
		for r in [thigh, shin, shoe]: draw_rect((r as Rect2).grow(0.6 * scale), outline)
		draw_rect(thigh, pants)
		draw_rect(shin, pants)
		draw_rect(Rect2(thigh.position, Vector2(thigh.size.x, 1.2 * scale)), pants.lightened(0.16))
		draw_rect(shoe, shoes)
	draw_texture_rect_region(texture, upper, upper_src, tint)
	_draw_waiting_idle(pos, person, scale, facing, drop + breath, fade)
	if away > 0.001: _draw_seated_back(pos, person, scale, full_fade * away)

func _faces_road(person: Dictionary) -> float:
	# On the metro-side shelter seats people sit facing the carriageway, so
	# from the street we see their backs (the shelter faces the road).
	if person.promenade or person.platform or person.state not in ["wait_bus", "shelter", "stand_up"]: return 0.0
	if person.x < 1000.0 or person.x > 1170.0: return 0.0
	return smoothstep(0.55, 0.95, clampf(person.sit, 0.0, 1.0))

func _draw_seated_back(pos: Vector2, person: Dictionary, scale: float, fade: float) -> void:
	# Seen from behind: hair, shoulders and back of the shirt above the seat.
	var v: int = person.character_id
	var hair: Color = hair_colors[v] if v < hair_colors.size() else Color("2b2623")
	var shirt: Color = shirt_colors[v] if v < shirt_colors.size() else Color("5c7088")
	var pants: Color = leg_colors[v] if v < leg_colors.size() else Color("394456")
	var skin := Color("d9a88c")
	var o := Vector2(floorf(pos.x), floorf(pos.y))
	var breath := 1.0 if sin(animation_time * 1.6 + person.id) > 0.6 else 0.0
	var r := func(x: float, y: float, w: float, h: float, c: Color) -> void:
		draw_rect(Rect2(o + Vector2(x, y - breath * (1.0 if y < -14.0 else 0.0)) * scale, Vector2(w, h) * scale), Color(c, fade))
	var dark := shirt.darkened(0.35)
	r.call(-4, -12, 8, 3, pants)                 # seat of the trousers on the bench
	r.call(-5, -22, 10, 10, shirt)                # back
	r.call(-6, -21, 1, 8, dark)                   # arms at the sides
	r.call(5, -21, 1, 8, dark)
	r.call(-1, -21, 1, 8, shirt.darkened(0.12))   # shirt seam
	r.call(-5, -22, 10, 1, shirt.lightened(0.12))
	r.call(-1, -24, 2, 2, skin.darkened(0.1))     # neck
	r.call(-3, -30, 6, 6, hair)                   # head from behind
	r.call(-2, -31, 4, 1, hair)
	r.call(-3, -27, 1, 2, skin)                   # ears
	r.call(2, -27, 1, 2, skin)
	r.call(-2, -30, 2, 1, hair.lightened(0.18))

func _waiting_idle_phone(person: Dictionary) -> bool:
	if person.moving or person.state not in ["wait_bus", "shelter"]: return false
	# Everyone checks their phone now and then, at their own rhythm...
	if fposmod(animation_time + person.id * 3.7, 15.0 + person.id % 4) > 7.0: return false
	# ...but puts it away to watch for the vehicle in its last few seconds.
	var arrival: int = Transit.bus_arrival_for("far_bus" if person.promenade else "near_bus", animation_time)
	return arrival > 6 or person.state == "shelter"

func _draw_waiting_idle(pos: Vector2, person: Dictionary, scale: float, facing: int, lowered: float, fade: float) -> void:
	if not _waiting_idle_phone(person): return
	var hand := Vector2(pos.x + facing * 4.0 * scale, pos.y - 36.0 * scale * (1.0 - hip_ratio * 0.62) + lowered)
	var screen := Color(0.62, 0.86, 1.0, 0.95 * fade)
	_phone_glows.append(hand)
	draw_rect(Rect2(hand - Vector2(1.2, 1.8) * scale, Vector2(2.4, 3.6) * scale), Color(0.12, 0.13, 0.16, fade))
	draw_rect(Rect2(hand - Vector2(0.7, 1.3) * scale, Vector2(1.4, 2.4) * scale), screen)

func _draw_hover_mark(person: Dictionary, pos: Vector2, scale: float) -> void:
	# A warm halo at the feet shows which resident the card belongs to.
	if not _is_hovered("resident", person.id): return
	_draw_mark(pos, scale)

func _draw_mark(pos: Vector2, scale: float) -> void:
	var pulse := 0.8 + 0.2 * sin(animation_time * 4.0)
	draw_texture_rect(Art.glow(), Rect2(pos + Vector2(-16, -5) * scale, Vector2(32, 9) * scale), false, Color(1.0, 0.72, 0.42, 0.75 * pulse))
	draw_texture_rect(Art.glow(), Rect2(pos + Vector2(-17, -40) * scale, Vector2(34, 44) * scale), false, Color(1.0, 0.86, 0.66, 0.16 * pulse))

func draw_ellipse_shadow(pos: Vector2, scale: float, opacity: float) -> void:
	# A baked disc squashed into an ellipse: far cheaper than a polygon per person.
	draw_texture_rect(Art.rings("shadow", [[1.0, Color(0.03, 0.04, 0.08, 1.0)]]), Rect2(pos + Vector2(-8, -3) * scale, Vector2(16, 4) * scale), false, Color(1, 1, 1, 0.28 * opacity))

func _draw_umbrella(pos: Vector2, scale: float, id: int, openness: float = 1.0) -> void:
	# Pixel-art umbrella built from rows of rectangles (cheap, and it matches the
	# pixel city): domed canopy, scalloped dark rim, ribs, handle and crook.
	var colors := [Color("c86572"), Color("59879a"), Color("cf9a55"), Color("5f8f6a")]
	var base: Color = colors[(id / 2) % colors.size()]
	var edge := Color("493843")
	var w := lerpf(0.12, 1.0, openness)
	var drop := (1.0 - openness) * 10.0
	var rows := [[-8, 2], [-7, 6], [-6, 9], [-5, 11], [-4, 13], [-3, 14], [-2, 15], [-1, 15], [0, 15]]
	for row in rows:
		var hw: float = float(row[1]) * w
		var y: float = float(row[0]) + drop
		draw_rect(Rect2(pos + Vector2(-hw, y) * scale, Vector2(hw * 2.0, 1.0) * scale), base)
		draw_rect(Rect2(pos + Vector2(-hw, y) * scale, Vector2(1.0, 1.0) * scale), edge)
		draw_rect(Rect2(pos + Vector2(hw - 1.0, y) * scale, Vector2(1.0, 1.0) * scale), edge)
	# Highlight on the upper left of the dome, darker panels between the ribs.
	draw_rect(Rect2(pos + Vector2(-8.0 * w, -6.0 + drop) * scale, Vector2(5.0 * w, 1.0) * scale), base.lightened(0.3))
	draw_rect(Rect2(pos + Vector2(-11.0 * w, -4.0 + drop) * scale, Vector2(3.0 * w, 1.0) * scale), base.lightened(0.2))
	for rib in [-5.0, 5.0]:
		draw_rect(Rect2(pos + Vector2(rib * w, -4.0 + drop) * scale, Vector2(1.0, 5.0) * scale), base.darkened(0.3))
	# Scalloped rim: dark points between the rib tips.
	for x in [-15.0, -10.0, -5.0, 0.0, 5.0, 10.0, 14.0]:
		draw_rect(Rect2(pos + Vector2(x * w, 1.0 + drop) * scale, Vector2(maxf(1.0, 2.0 * w), 1.0) * scale), edge)
	draw_rect(Rect2(pos + Vector2(-0.5, -9.0 + drop) * scale, Vector2(1.0, 1.0) * scale), base.lightened(0.45))
	draw_rect(Rect2(pos + Vector2(-0.5, 1.0) * scale, Vector2(1.0, 16.0) * scale), edge)
	draw_rect(Rect2(pos + Vector2(0.5, 16.0) * scale, Vector2(2.0, 1.0) * scale), edge)
	draw_rect(Rect2(pos + Vector2(2.5, 14.5) * scale, Vector2(1.0, 2.0) * scale), edge)

func _draw_mood(pos: Vector2, mood: String) -> void:
	# Draw a small coloured emoji so it remains visible without an emoji font.
	var bubble := Rect2(pos.x - 11, pos.y - 21, 22, 20)
	draw_rect(bubble.grow(1), Color("5e5365"))
	draw_rect(bubble, Color("fff8e9"))
	draw_colored_polygon(PackedVector2Array([Vector2(pos.x - 3, pos.y - 1), Vector2(pos.x + 3, pos.y - 1), Vector2(pos.x, pos.y + 3)]), Color("fff8e9"))
	var center := pos + Vector2(0, -11)
	Art.draw_rings(self, "face", [[1.0, Color("ffd56b")]], center, 7.0)
	draw_rect(Rect2(center + Vector2(-4, -2), Vector2(2, 2)), Color("5b3f3c"))
	draw_rect(Rect2(center + Vector2(2, -2), Vector2(2, 2)), Color("5b3f3c"))
	if mood in ["下雨", "避雨"]:
		draw_line(center + Vector2(-3, 4), center + Vector2(3, 4), Color("76504b"), 1.0, true)
		draw_rect(Rect2(center + Vector2(5, -5), Vector2(2, 3)), Color("76b5d2"))
	elif mood == "休息":
		draw_line(center + Vector2(-3, 3), center + Vector2(3, 3), Color("76504b"), 1.0, true)
	else:
		draw_line(center + Vector2(-3, 2), center + Vector2(-1, 4), Color("76504b"), 1.0, true)
		draw_line(center + Vector2(-1, 4), center + Vector2(2, 4), Color("76504b"), 1.0, true)
		draw_line(center + Vector2(2, 4), center + Vector2(3, 2), Color("76504b"), 1.0, true)
		if mood == "你好":
			draw_rect(Rect2(center + Vector2(5, -6), Vector2(3, 3)), Color("e97887"))

func _draw_aircraft() -> void:
	# Contrails first, so the aircraft sits at the head of its own trail.
	var trail_colour: Color = env.get("cloud_lit", Color.WHITE)
	# Contrails are far behind the skyline: a puff that would touch a tower is
	# dropped whole (round 8), so no white fragments cling to tower outlines.
	Aircraft.draw_trails(self, aircraft.trails.filter(_trail_in_sky), trail_colour.lerp(Color.WHITE, 0.25))
	var light: Color = env.get("ambient", Color.WHITE)
	for f in aircraft.flights:
		Aircraft.draw_flight(self, f, light, animation_time, _is_hovered("plane", f.id))
		_hit_boxes.append({"kind": "plane", "id": f.id, "rect": Aircraft.box(f)})

var _sky_mask: Image

func _trail_in_sky(t: Dictionary) -> bool:
	if _sky_mask == null: _sky_mask = MASKS.get_image()
	var width := 1.0 + floorf(t.age / t.life * 4.0)
	var x0 := int(floorf(t.x))
	var y0 := int(floorf(t.y - width * 0.5))
	var y1 := y0 + int(width * 2.0) + 1
	for p in [Vector2i(x0, y0), Vector2i(x0 + 2, y0), Vector2i(x0, y1), Vector2i(x0 + 2, y1)]:
		if p.x < 0 or p.y < 0 or p.x >= _sky_mask.get_width() or p.y >= _sky_mask.get_height(): continue
		if _sky_mask.get_pixel(p.x, p.y).r < 0.5: return false
	return true

func _draw_night_lights() -> void:
	# Additive pass above the night tint: lamps light the promenade, vehicles carry
	# headlights and lit interiors, shelters and signs glow. Daytime draws nothing.
	var view_size := get_viewport_rect().size
	_draw_lightning(_lights, view_size, _display_rect(view_size, BACKDROP.get_size(), display_mode))
	var amount: float = env.lamps
	var wet: float = weather_weights.rain
	# Rain darkens the street, so vehicles switch on their lights in the day too.
	var vehicle_amount := maxf(amount, 0.55 * wet)
	if amount <= 0.002 and vehicle_amount <= 0.002: return
	var view := get_viewport_rect().size
	var target := _display_rect(view, BACKDROP.get_size(), display_mode)
	var scene_scale := target.size / BACKDROP.get_size()
	var canvas := _lights
	canvas.draw_set_transform(target.position, 0.0, scene_scale)
	var glow := Art.glow()
	var warm := Color(1.0, 0.66, 0.32)
	if amount > 0.002:
		for x in [28, 236, 390, 549, 749, 1139, 1296, 1470, 1651, 1839, 2013, 2157]:
			canvas.draw_texture_rect(glow, Rect2(x - 28, 390, 56, 56), false, Color(warm, 0.28 * amount))
			# Light pool on the promenade below each lamp; brighter on wet paving.
			canvas.draw_texture_rect(glow, Rect2(x - 48, 467, 96, 18), false, Color(warm, (0.28 + 0.14 * wet) * amount))
		var shift := _current_station_shift()
		# Bus shelters: lit roof panel and the countdown screens.
		canvas.draw_texture_rect(glow, Rect2(1000, 520, 170, 40), false, Color(1.0, 0.82, 0.6, 0.18 * amount))
		canvas.draw_texture_rect(glow, Rect2(1066, 482, 100, 46), false, Color(0.55, 0.85, 1.0, 0.16 * amount))
		var far_x: float = Residents.FAR_SHELTER_X
		canvas.draw_texture_rect(glow, Rect2(far_x + 5, 452, 140, 32), false, Color(1.0, 0.82, 0.6, 0.15 * amount))
		canvas.draw_texture_rect(glow, Rect2(far_x + 62, 424, 72, 34), false, Color(0.55, 0.85, 1.0, 0.14 * amount))
		# The metro entrance sign and its green METRO totem go dark with the station.
		var metro_lit := _station_lights()
		canvas.draw_texture_rect(glow, Rect2(56 + shift, 478, 124, 40), false, Color(0.4, 0.8, 1.0, 0.16 * amount * metro_lit))
		canvas.draw_texture_rect(glow, Rect2(52.0 + shift - 18, 498, 38, 34), false, Color(0.35, 1.0, 0.6, 0.14 * amount * metro_lit))
		Cafe.draw_lights(canvas, glow, clock_seconds(), amount)
		Park.draw_park_lights(canvas, glow, animation_time, amount)
	for hand in _phone_glows:
		# Phone screens light the waiting faces a little at night.
		canvas.draw_texture_rect(glow, Rect2(hand - Vector2(6, 7), Vector2(12, 12)), false, Color(0.55, 0.8, 1.0, 0.22 * amount))
	for vehicle in _vehicle_lights:
		var body: Rect2 = vehicle.rect
		var forward: int = vehicle.dir
		var bus: bool = vehicle.kind == "bus"
		var front_x := body.end.x - 2.0 if forward > 0 else body.position.x + 2.0
		var rear_x := body.position.x + 2.0 if forward > 0 else body.end.x - 2.0
		var lamp_y := body.position.y + body.size.y * (0.72 if bus else 0.6)
		var bottom := body.end.y - 2.0
		# Headlight: bright source plus a beam spreading ahead on the road.
		canvas.draw_texture_rect(glow, Rect2(front_x - 5, lamp_y - 5, 10, 10), false, Color(1.0, 0.95, 0.8, 0.55 * vehicle_amount))
		var beam := Rect2(front_x + (0.0 if forward > 0 else -64.0), lamp_y - 6, 64, 14)
		canvas.draw_texture_rect(glow, beam, false, Color(1.0, 0.9, 0.7, 0.20 * vehicle_amount))
		canvas.draw_texture_rect(glow, Rect2(rear_x - 4, lamp_y - 4, 8, 8), false, Color(1.0, 0.18, 0.12, 0.5 * vehicle_amount))
		if bus:
			# Lit passenger windows along the body.
			canvas.draw_texture_rect(glow, Rect2(body.position.x + body.size.x * 0.06, body.position.y + body.size.y * 0.16, body.size.x * 0.88, body.size.y * 0.42), false, Color(1.0, 0.86, 0.62, 0.14 * vehicle_amount))
		if wet > 0.01:
			# Wet asphalt mirrors the lights in short vertical streaks.
			canvas.draw_texture_rect(glow, Rect2(front_x - 6, bottom - 1, 12, 16), false, Color(1.0, 0.9, 0.7, 0.22 * wet * vehicle_amount))
			canvas.draw_texture_rect(glow, Rect2(rear_x - 4, bottom - 1, 8, 12), false, Color(1.0, 0.25, 0.15, 0.20 * wet * vehicle_amount))

func _display_rect(view: Vector2, artwork: Vector2, mode: String) -> Rect2:
	if mode == "stretch":
		return Rect2(Vector2.ZERO, view)
	var factor := minf(view.x / artwork.x, view.y / artwork.y) if mode in ["fit", "sky"] else maxf(view.x / artwork.x, view.y / artwork.y)
	var output := artwork * factor
	if mode == "sky":
		# Keep original-aspect windows intact; taller displays crop the empty
		# upper sky and show a larger street and platform without distortion.
		if view.x / view.y < artwork.x / artwork.y:
			factor = maxf(factor, view.y / 680.0)
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

func _sync_pixel_grid() -> void:
	if not _pixel_rect: return
	var view := get_viewport_rect().size
	var target := _display_rect(view, BACKDROP.get_size(), display_mode)
	var scene_scale := target.size.y / BACKDROP.get_size().y
	var cell := scene_scale * (2.0 if pixel_grid == "coarse" else 1.0)
	# Below ~1.8 screen pixels per cell a grid only blurs; leave the image alone.
	_pixel_rect.visible = pixel_grid != "off" and cell >= 1.8
	if _pixel_rect.visible:
		var material := _pixel_rect.material as ShaderMaterial
		material.set_shader_parameter(&"origin", target.position)
		material.set_shader_parameter(&"cell", cell)

func _mode_index(mode: String) -> int:
	return ["fill", "fit", "stretch", "sky"].find(mode) if mode in ["fill", "fit", "stretch", "sky"] else 0

func _load_display_mode() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	var saved_cast := str(config.get_value("display", "cast", cast))
	if saved_cast in CASTS and saved_cast != cast and not walk_sheets_smooth.is_empty():
		_apply_cast(saved_cast)
	elif saved_cast in CASTS and walk_sheets_smooth.is_empty():
		cast = saved_cast
	var grid := str(config.get_value("display", "pixel2", pixel_grid))
	if grid in PIXEL_MODES and grid != pixel_grid:
		pixel_grid = grid
		if _pixel_select: _pixel_select.select(PIXEL_MODES.find(grid))
	var value := str(config.get_value("display", "mode", "sky"))
	if value in ["fill", "fit", "stretch", "sky"] and value != display_mode:
		display_mode = value
		if _mode_select:
			_mode_select.select(_mode_index(value))
		queue_redraw()

func _on_display_mode_selected(index: int) -> void:
	display_mode = ["fill", "fit", "stretch", "sky"][index]
	_save_display_settings()
	queue_redraw()

func _save_display_settings() -> void:
	DirAccess.make_dir_recursive_absolute(settings_path.get_base_dir())
	var config := ConfigFile.new()
	config.load(settings_path)
	config.set_value("display", "mode", display_mode)
	config.set_value("display", "pixel2", pixel_grid)
	config.set_value("display", "cast", cast)
	var error := config.save(settings_path)
	if error != OK:
		push_warning("Unable to save display settings: %s" % error)

func _draw_vehicle(texture: Texture2D, source: Rect2, target: Rect2, bounds: Vector2, reversed: bool = false, modulate: Color = Color.WHITE) -> void:
	# The sprite is pre-scaled to its exact on-screen pixel size (Art.baked) and
	# placed on whole screen pixels, so it is drawn 1:1 and never resampled.
	# Only the canvas edge clips it; entrances are painted later as foreground.
	var source_x := float(texture.get_width()) - source.position.x - source.size.x if reversed else source.position.x
	if legacy_vehicle_draw:
		var cut := target.intersection(Rect2(Vector2.ZERO, bounds))
		if not cut.has_area(): return
		draw_texture_rect_region(texture, cut, Rect2(source_x + (cut.position.x - target.position.x) / target.size.x * source.size.x,
			source.position.y + (cut.position.y - target.position.y) / target.size.y * source.size.y,
			cut.size.x / target.size.x * source.size.x, cut.size.y / target.size.y * source.size.y), modulate)
		return
	var px := Vector2i(maxi(1, roundi(target.size.x * _px_scale)), maxi(1, roundi(target.size.y * _px_scale)))
	var sprite := Art.baked(texture, Rect2(source_x, source.position.y, source.size.x, source.size.y), px)
	var rect := Rect2(_snap_rect(target).position, Vector2(px) / _px_scale)
	var clipped := rect.intersection(Rect2(Vector2.ZERO, bounds))
	if not clipped.has_area(): return
	var region := Rect2((clipped.position - rect.position) * _px_scale, clipped.size * _px_scale)
	draw_texture_rect_region(sprite, clipped, region, modulate)

func _draw_bus_bays() -> void:
	# Yellow bus-stop bays with the painted 公交车站 legend ahead of each stop.
	var yellow := Color(0.96, 0.78, 0.25, 0.62)
	for bay in [[990.0, 1180.0, 533.0], [600.0, 800.0, 483.5]]:
		var x: float = bay[0]
		while x < bay[1]:
			draw_line(Vector2(x, bay[2]), Vector2(minf(x + 6.0, bay[1]), bay[2]), yellow, 1.0)
			x += 10.0
	draw_string(_screen_font, Vector2(1188, 532), "公交车站", HORIZONTAL_ALIGNMENT_LEFT, 30, 5, yellow)
	draw_string(_screen_font, Vector2(806, 488), "公交车站", HORIZONTAL_ALIGNMENT_LEFT, 30, 5, yellow)

func _draw_road_edges(width: float) -> void:
	# Two opposite one-way lanes are separated by the existing central barrier.
	# Edge lines make each carriageway easier to read without covering that barrier.
	draw_line(Vector2(0, 482), Vector2(width, 482), Color(0.95, 0.72, 0.46, 0.52), 1.0)
	draw_line(Vector2(0, 535), Vector2(width, 535), Color(0.95, 0.72, 0.46, 0.52), 1.0)
	for x in range(0, int(width), 125):
		draw_rect(Rect2(x, 485, minf(48, width - x), 1), Color(0.94, 0.83, 0.69, 0.48))
		draw_rect(Rect2(x + 55, 531, minf(48, width - x - 55), 1), Color(0.94, 0.83, 0.69, 0.48))

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

var _px_scale := 1.0
var _px_origin := Vector2.ZERO
# Metrics only (.tools/verify_pass6.gd): render vehicles the round-5 way to
# measure the shimmer before/after under identical conditions.
var legacy_vehicle_draw := false

func _snap_axis(v: float, origin: float) -> float:
	# Absolute screen pixels: the scene origin itself is usually fractional
	# (2880x1800 puts it at x -1434.66), so round origin + v*scale, not v*scale.
	if _px_scale <= 0.0: return v
	if legacy_vehicle_draw: return roundf(v * _px_scale) / _px_scale
	return (roundf(origin + v * _px_scale) - origin) / _px_scale

func _snap(v: float) -> float:
	return _snap_axis(v, _px_origin.x)

func _snap_rect(r: Rect2) -> Rect2:
	return Rect2(Vector2(_snap_axis(r.position.x, _px_origin.x), _snap_axis(r.position.y, _px_origin.y)), r.size)

const CAR_WHEEL := [[1.0, Color("252d35")], [0.72, Color("8a959b")], [0.5, Color("3a454d")], [0.2, Color("c5cccb")]]
const BUS_WHEEL := [[0.78, Color("59626d")], [0.56, Color("a8adb0")], [0.3, Color("333e4b")]]
const TRAIN_WHEEL := [[1.0, Color("3d4955")], [0.4, Color("a7abb0")]]

func _draw_wheel(center: Vector2, radius: float) -> void:
	# Static tyre, rim and hub. Rotating spokes this small strobe and flicker
	# on screen (the old wagon-wheel effect), so the rims are not animated.
	Art.draw_rings(self, "car", CAR_WHEEL, center, radius)

func _draw_bus(target: Rect2, bounds: Vector2, reversed: bool) -> void:
	var texture: Texture2D = bus_reversed if reversed else Art.smooth(SHENZHEN_BUS)
	target = _snap_rect(target)
	_draw_vehicle(texture, BUS_SOURCE, target, bounds, reversed)
	var door_open: float = Transit.bus_doors_for("near_bus" if reversed else "far_bus", animation_time)
	var door_x := target.position.x + target.size.x * (0.59 if reversed else 0.41)
	_draw_open_door(Rect2(door_x - 5.5 * door_open, target.position.y + target.size.y * 0.23, 11.0 * door_open, target.size.y * 0.68), bounds)
	# Replace the generated decorative route text with the simulated line number.
	var sign_x := target.position.x + target.size.x * (0.19 if reversed else 0.71)
	if sign_x >= 0.0 and sign_x + target.size.x * 0.10 <= bounds.x:
		draw_rect(Rect2(sign_x, target.position.y + target.size.y * 0.21, target.size.x * 0.10, target.size.y * 0.08), Color("13232b"))
		draw_string(_screen_font, Vector2(sign_x + 2.0, target.position.y + target.size.y * 0.28), "3", HORIZONTAL_ALIGNMENT_LEFT, target.size.x * 0.09, 6, Color("ffc875"))
	var radius := target.size.y * 0.12
	for fraction in [0.252, 0.76]:
		var fx: float = 1.0 - fraction if reversed else fraction
		var center := target.position + Vector2(target.size.x * fx, target.size.y * 0.85)
		if center.x < radius or center.x > bounds.x - radius: continue
		Art.draw_rings(self, "bus", BUS_WHEEL, center, radius)

func _draw_car(target: Rect2, bounds: Vector2, reversed: bool, signalling: bool) -> void:
	# Near lane: yellow SU7 sedan; waterfront lane: green YU7 crossover.
	var texture: Texture2D = su7_reversed if reversed else Art.smooth(YU7_GREEN)
	var source: Rect2 = SU7_SOURCE if reversed else YU7_SOURCE
	target = _snap_rect(target)
	_draw_vehicle(texture, source, target, bounds, reversed)
	var radius := target.size.y * 0.16
	var wheel_positions: Array = [0.198, 0.815] if reversed else [0.212, 0.82]
	var wheel_y := 0.76 if reversed else 0.75
	for fraction in wheel_positions:
		var fx: float = 1.0 - fraction if reversed else fraction
		var center := target.position + Vector2(target.size.x * fx, target.size.y * wheel_y)
		if center.x < radius or center.x > bounds.x - radius: continue
		_draw_wheel(center, radius)
	if signalling and fposmod(animation_time, 1.0) < 0.55:
		var light_x := target.position.x + target.size.x * (0.96 if reversed else 0.04)
		if light_x >= 0.0 and light_x <= bounds.x:
			draw_circle(Vector2(light_x, target.position.y + target.size.y * 0.57), 2.2, Color(1.0, 0.63, 0.18, 0.35))
			draw_rect(Rect2(light_x - 1.2, target.position.y + target.size.y * 0.57 - 0.7, 2.4, 1.4), Color("ffbe45"))

func _note_vehicle(body: Rect2, forward: int, kind: String) -> void:
	_vehicle_lights.append({"rect": body, "dir": forward, "kind": kind})

func _flip(texture: Texture2D) -> Texture2D:
	if not _flipped.has(texture): _flipped[texture] = Art.flipped(texture)
	return _flipped[texture]

func _draw_crowd(promenade: bool) -> void:
	for p in crowd.people:
		if p.promenade != promenade or p.stage != "walk": continue
		var scale := 0.78 if promenade else 1.0
		var pos := Vector2(p.x, FAR_WALK_Y if promenade else 553.0 + p.lane * 2.0)
		# People fade into / out of exit B instead of popping; near-side
		# travellers use the escalators and stay visible all the way.
		var alpha := 1.0
		if p.trip in ["to_metro", "to_cafe"] and not p.boards: alpha = clampf(absf(p.x - p.target) / 14.0, 0.0, 1.0)
		if p.trip in ["from_metro", "from_cafe"] and promenade: alpha = clampf(absf(p.x - p.spawn_x) / 14.0, 0.0, 1.0)
		_draw_crowd_person(p, pos, scale, alpha, false)
		if _is_raining() and p.umbrella and alpha > 0.5: _draw_umbrella(pos + Vector2(0, -34 * scale), scale, p.id, 1.0)

func _draw_crowd_platform() -> void:
	for p in crowd.people:
		if p.stage != "platform": continue
		var pos := Vector2(p.x, Station.WALK_Y + float(p.lane % 2) * 3.0)
		var alpha := 1.0
		if p.trip == "to_metro": alpha = clampf(absf(p.x - p.target) / 14.0, 0.0, 1.0)
		else: alpha = clampf(absf(p.x - p.spawn_x) / 14.0, 0.0, 1.0)
		_draw_crowd_person(p, pos, 1.0, alpha, false)

func _draw_crowd_person(p: Dictionary, pos: Vector2, scale: float, alpha: float, standing: bool) -> void:
	var sheet: Texture2D = CROWD_SHEETS[p.sheet]
	var riding: bool = p.stage == "ride" or standing
	if riding: sheet = CROWD_STAND[p.sheet]   # upright, feet together on the steps
	var frame := 0 if riding else int(p.walk_distance / 2.1) % 8
	var src := Rect2(frame * 54, p.row * 72, 54, 72)
	var texture: Texture2D = Art.smooth(sheet)
	var facing: int = (1 if p.down else -1) if riding else p.dir
	if facing < 0:
		texture = _flip(sheet)
		src.position.x = sheet.get_width() - src.end.x
	draw_ellipse_shadow(pos, scale, alpha)
	if _is_hovered("crowd", p.id): _draw_mark(pos, scale)
	var startle := _startle(1000 + int(p.id)) if str(p.desc).contains("女") and p.stage == "walk" else 0.0
	pos.y -= 2.5 * startle * scale
	draw_texture_rect_region(texture, Rect2(pos.x - 13 * scale, pos.y - 36 * scale, 27 * scale, 36 * scale), src, Color(1, 1, 1, alpha))
	_draw_startle(pos, scale, startle * alpha)
	_hit_boxes.append({"kind": "crowd", "id": p.id, "rect": Rect2(pos.x - 13 * scale, pos.y - 36 * scale, 27 * scale, 36 * scale)})

var _idle_frames := {}

func _idle_frame(sheet: Texture2D, frames: int, row: int, cell_height: float) -> int:
	# The walk frame whose feet are closest together reads as standing still.
	var key := "%d:%d" % [sheet.get_instance_id(), row]
	if _idle_frames.has(key): return _idle_frames[key]
	var image := sheet.get_image()
	if image.is_compressed(): image.decompress()
	var cell := Vector2i(image.get_width() / frames, int(cell_height))
	var best := 0
	var best_spread := INF
	for f in range(frames):
		var low := cell.x
		var high := -1
		for y in range(int(cell.y * 0.86), int(cell.y * 0.98)):
			for x in range(cell.x):
				if image.get_pixel(f * cell.x + x, row * cell.y + y).a > 0.5:
					low = mini(low, x)
					high = maxi(high, x)
		var spread := float(high - low) if high >= 0 else INF
		if spread < best_spread:
			best_spread = spread
			best = f
	_idle_frames[key] = best
	_idle_spread[key] = best_spread / float(cell.x) if best_spread < INF else 0.2
	return best

var _idle_spread := {}

func _leg_squeeze(sheet: Texture2D, row: int) -> float:
	var key := "%d:%d" % [sheet.get_instance_id(), row]
	if not _idle_spread.has(key): return 1.0
	# Feet together span about a fifth of the cell; never squeeze below 45 %.
	return clampf(0.2 / maxf(float(_idle_spread[key]), 0.01), 0.45, 1.0)

func _traffic_obstacles() -> Array:
	var width := BACKDROP.get_width()
	var list := [
		{"lane": 0, "x": _bus_x(Transit.phase("far_bus", animation_time), width, false), "width": 160.0},
		{"lane": 1, "x": _bus_x(Transit.phase("near_bus", animation_time), width, true), "width": 170.0}]
	if _pickup_car_active(): list.append({"lane": 0, "x": _car_x(animation_time, width, false), "width": 88.0})
	return list

func _pickup_car_active() -> bool:
	# The family SUV that collects resident 11 only runs while they are up.
	return _resident_awake(residents.people[10])

func _draw_flow_vehicle(v: Dictionary, bounds: Vector2) -> void:
	var dir: int = Traffic.LANES[v.lane].dir
	if v.kind == "scooter":
		var base_y: float = 485.0 if v.lane == 0 else 531.0
		var rect := _snap_rect(Rect2(v.x, base_y - 25.0, 32.0, 26.0))
		var src := Rect2((int(absf(v.x) / 5.0) % 4) * 64, v.rider * 52, 64, 52)
		var texture: Texture2D = Art.smooth(SCOOTER)
		if dir < 0:
			texture = _flip(SCOOTER)
			src.position.x = SCOOTER.get_width() - src.end.x
		if _is_hovered("traffic", v.id): draw_texture_rect(Art.glow(), rect.grow(8.0), false, Color(1.0, 0.75, 0.45, 0.4))
		_draw_vehicle(texture, src, rect, bounds)
		_hit_boxes.append({"kind": "traffic", "id": v.id, "rect": rect})
		_note_vehicle(rect, dir, "scooter")
		return
	var sedan: bool = v.kind != "suv"
	var size := Vector2(91.0, 28.3) if sedan else Vector2(88.0, 31.5)
	var y: float = (475.7 if sedan else 472.5) if v.lane == 0 else (504.7 if sedan else 501.5)
	var target := _snap_rect(Rect2(v.x, y - v.pass * 10.0, size.x, size.y))
	var texture: Texture2D = CAR_SPRITES.get(v.colour, SU7_YELLOW) if sedan else YU7_GREEN
	if _is_hovered("traffic", v.id): draw_texture_rect(Art.glow(), target.grow(10.0), false, Color(1.0, 0.75, 0.45, 0.4))
	_draw_vehicle(Art.smooth(texture) if dir > 0 else _flip(texture), SU7_SOURCE if sedan else YU7_SOURCE, target, bounds, dir < 0)
	var radius := target.size.y * 0.16
	for fraction in ([0.198, 0.815] if sedan else [0.212, 0.82]):
		var fx: float = fraction if dir > 0 else 1.0 - fraction
		var center := target.position + Vector2(target.size.x * fx, target.size.y * (0.76 if sedan else 0.75))
		if center.x < radius or center.x > bounds.x - radius: continue
		_draw_wheel(center, radius)
	if v.kind == "taxi":
		# Roof sign: TAXI when hired, a red 空车 light when free.
		var sign_rect := Rect2(target.position.x + target.size.x * (0.47 if dir > 0 else 0.42), target.position.y - 2.2, 10.0, 3.4)
		var vacant: bool = v.passengers == 0
		draw_rect(sign_rect.grow(0.4), Color("3a4148"))
		draw_rect(sign_rect, Color("1b1f24") if vacant else Color("f3f5f2"))
		draw_string(_screen_font, sign_rect.position + Vector2(1.2, 2.9), "空车" if vacant else "TAXI", HORIZONTAL_ALIGNMENT_LEFT, 9, 2.8, Color("ff4a3a") if vacant else Color("1f6fb8"))
	if v.pass > 0.1 and fposmod(animation_time + v.id * 0.37, 1.0) < 0.55:
		var light_x := target.position.x + target.size.x * (0.04 if dir > 0 else 0.96)
		draw_rect(Rect2(light_x - 1.2, target.position.y + target.size.y * 0.57 - 0.7, 2.4, 1.4), Color("ffbe45"))
	_hit_boxes.append({"kind": "traffic", "id": v.id, "rect": target})
	_note_vehicle(target, dir, "car")

func _draw_traffic(bounds: Vector2) -> void:
	_vehicle_lights.clear()
	var far_bus_x := _bus_x(Transit.phase("far_bus", animation_time), bounds.x, false)
	var near_bus_x := _bus_x(Transit.phase("near_bus", animation_time), bounds.x, true)
	var far_car_x := _car_x(animation_time, bounds.x, false)
	var far_offset := _passing_lane_amount(far_car_x, far_bus_x, false) * 10.0
	# Flow traffic in the passing lane is farther away, so it is drawn beneath its bus.
	for v in traffic.vehicles:
		if v.lane == 0: _draw_flow_vehicle(v, bounds)
	if _pickup_car_active():
		_draw_car(Rect2(far_car_x, 472.5 - far_offset, 88, 31.5), bounds, false, far_offset > 1.0 or fposmod(animation_time, 60.0) >= 22.0 and fposmod(animation_time, 60.0) < 35.0)
		_note_vehicle(Rect2(far_car_x, 472.5 - far_offset, 88, 31.5), 1, "car")
	_draw_bus(Rect2(far_bus_x, FAR_BUS_Y, 160, 43), bounds, false)
	# The central guard fence stands between the carriageways: it hides the far
	# lane from the wheels down, while near-lane traffic passes in front of it.
	StreetDetails.draw_road_barrier(self, bounds.x)
	for v in traffic.vehicles:
		if v.lane == 1 and v.kind != "scooter": _draw_flow_vehicle(v, bounds)
	_draw_bus(Rect2(near_bus_x, 487.3, 170, 45.7), bounds, true)
	for v in traffic.vehicles:
		if v.lane == 1 and v.kind == "scooter": _draw_flow_vehicle(v, bounds)
	_note_vehicle(_snap_rect(Rect2(far_bus_x, FAR_BUS_Y, 160, 43)), 1, "bus")
	_note_vehicle(_snap_rect(Rect2(near_bus_x, 487.3, 170, 45.7)), -1, "bus")
	for bus in [["far_bus", Rect2(far_bus_x, FAR_BUS_Y, 160, 43)], ["near_bus", Rect2(near_bus_x, 487.3, 170, 45.7)]]:
		if (bus[1] as Rect2).end.x > 0.0 and (bus[1] as Rect2).position.x < bounds.x:
			if _is_hovered("bus", bus[0]): draw_texture_rect(Art.glow(), (bus[1] as Rect2).grow(10.0), false, Color(1.0, 0.75, 0.45, 0.25))
			_hit_boxes.append({"kind": "bus", "id": bus[0], "rect": bus[1]})
	# Visual simulation: the train runs on the rails, not the walking surface.
	var train_target := _snap_rect(Rect2(Transit.train_x_now(animation_time, bounds.x), Station.TRAIN_Y, 660, 55.5))
	_draw_vehicle(Art.smooth(METRO), METRO_SOURCE, train_target, bounds)
	_draw_train_wheels(train_target, bounds)
	_draw_train_signs(train_target, bounds)
	if train_target.end.x > 0.0 and train_target.position.x < bounds.x:
		_hit_boxes.append({"kind": "metro", "id": "metro", "rect": train_target.intersection(Rect2(0, 0, bounds.x, 724))})
	var doors: float = Transit.train_doors_now(animation_time)
	if doors > 0.0:
		for fraction in Transit.TRAIN_DOOR_FRACTIONS:
			var x: float = train_target.position.x + train_target.size.x * fraction
			_draw_open_door(Rect2(x - 5.0 * doors, Station.TRAIN_Y + 14, 10.0 * doors, 35), bounds)

func _draw_train_wheels(target: Rect2, bounds: Vector2) -> void:
	# Four-car bogies share travel distance, so they turn during approach and stop at the platform.
	for fraction in [0.045, 0.075, 0.157, 0.181, 0.225, 0.259, 0.302, 0.34, 0.376, 0.414, 0.454, 0.486, 0.529, 0.558, 0.605, 0.635, 0.68, 0.707, 0.755, 0.787, 0.829, 0.862, 0.904, 0.94]:
		var center := target.position + Vector2(target.size.x * fraction, target.size.y * 0.88)
		if center.x < 2.0 or center.x > bounds.x - 2.0: continue
		Art.draw_rings(self, "train", TRAIN_WHEEL, center, 2.0)

func _draw_open_door(rect: Rect2, bounds: Vector2) -> void:
	# The doorway shows a lit carriage: bright ceiling fading to the floor, a
	# grab pole, dark rubber door edges and a metal threshold.
	if rect.size.x < 0.2: return
	var clipped := rect.intersection(Rect2(Vector2.ZERO, bounds))
	if not clipped.has_area(): return
	var ceiling := Color("e4ebea")
	var floor_colour := Color("8e9a9e")
	draw_polygon(PackedVector2Array([clipped.position, Vector2(clipped.end.x, clipped.position.y), clipped.end, Vector2(clipped.position.x, clipped.end.y)]),
		PackedColorArray([ceiling, ceiling, floor_colour, floor_colour]))
	if rect.size.x > 3.0:
		var pole_x := rect.get_center().x
		if pole_x > clipped.position.x and pole_x < clipped.end.x:
			draw_line(Vector2(pole_x, clipped.position.y + 1.0), Vector2(pole_x, clipped.end.y - 2.0), Color("c9ced0"), 1.0)
		draw_line(Vector2(clipped.position.x + 0.5, clipped.position.y), Vector2(clipped.position.x + 0.5, clipped.end.y), Color("2a3238"), 1.0)
		draw_line(Vector2(clipped.end.x - 0.5, clipped.position.y), Vector2(clipped.end.x - 0.5, clipped.end.y), Color("2a3238"), 1.0)
		draw_line(Vector2(clipped.position.x, clipped.end.y - 1.0), Vector2(clipped.end.x, clipped.end.y - 1.0), Color("b9c0c2"), 1.5)

func _draw_train_signs(target: Rect2, bounds: Vector2) -> void:
	# One amber LED destination board per car, as on Shenzhen line 3 trains.
	for car in range(6):
		var x := target.position.x + target.size.x * (car / 6.0 + 0.035)
		var board := Rect2(x, target.position.y + 6.0, 30.0, 6.0)
		if board.end.x < 0.0 or board.position.x > bounds.x: continue
		draw_rect(board.grow(0.6), Color("3a4148"))
		draw_rect(board, Color("120f0c"))
		Art.draw_rings(self, MetroLine.ring_key(), [[1.0, MetroLine.colour()]], Vector2(board.position.x + 3.0, board.get_center().y), 2.2)
		draw_string(_screen_font, Vector2(board.position.x + 1.7, board.end.y - 1.4), MetroLine.number(), HORIZONTAL_ALIGNMENT_LEFT, 4, 4, Color.WHITE)
		draw_string(_screen_font, Vector2(board.position.x + 6.5, board.end.y - 1.3), "%s %s" % [MetroLine.line(), MetroLine.toward()], HORIZONTAL_ALIGNMENT_LEFT, 24, 4, Color("ffb23e"))

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

func _draw_compact_escalators() -> void:
	var shift := _current_station_shift()
	for right in [false]:
		var mouth_x: float = 132.0 + shift
		# The opening in the slab reads as depth, not a flat black block: a soft
		# shadow falls from the slab edge and fades into the lit platform below.
		var top_shadow := Color(0.08, 0.12, 0.15, 0.55)
		var clear := Color(0.08, 0.12, 0.15, 0.0)
		draw_polygon(PackedVector2Array([Vector2(mouth_x - 2, 553), Vector2(mouth_x + 81, 553), Vector2(mouth_x + 81, 575), Vector2(mouth_x - 2, 575)]),
			PackedColorArray([top_shadow, top_shadow, clear, clear]))
		# Slab lip: a lit concrete edge with a thin shadow line under it.
		draw_line(Vector2(mouth_x - 2, 553.5), Vector2(mouth_x + 81, 553.5), Color("a7b2b4"), 1.0)
		draw_line(Vector2(mouth_x - 2, 554.8), Vector2(mouth_x + 81, 554.8), Color(0.15, 0.2, 0.23, 0.6), 1.0)
		# Up escalator behind, its riders, then the down escalator and its riders.
		Station.draw_escalator(self, false, shift, _escalator_time, true)
		_draw_escalator_riders(false)
		Station.draw_escalator(self, false, shift, _escalator_time, false)
		_draw_escalator_riders(true)

func _draw_escalator_riders(down: bool) -> void:
	var shift := _current_station_shift()
	# Passers-by riding or queueing at a landing.
	for p in crowd.riders():
		if p.down != down: continue
		var pos := StationRoutes.escalator_position(p.progress if p.stage == "ride" else 0.0, down, shift)
		_draw_crowd_person(p, pos, 1.0, 1.0, p.stage == "queue")
	for person in residents.people:
		if person.state not in StationRoutes.ESCALATOR_STATES: continue
		if (person.state == "escalator_down") != down: continue
		if not _resident_awake(person): continue
		var pos := StationRoutes.escalator_position(person.escalator_progress, person.state == "escalator_down", shift)
		# Riders stand on the moving treads, keeping their feet on the slope.
		# The same upper landing is visible through the entrance glass.
		_draw_hover_mark(person, pos, 1.0)
		_draw_person(pos, 0, person, 1.0)
		_hit_boxes.append({"kind": "resident", "id": person.id, "rect": Rect2(pos.x - 13, pos.y - 36, 27, 36)})

func _draw_foreground() -> void:
	# Only redraw station silhouettes, so the road around them never clips cars.
	var shift := _current_station_shift()
	var left := _entrance_outline(false)
	_draw_backdrop_shape(left, Vector2(shift, 0), ENTRANCE_ART)
	# The second entrance now stands across the road (_draw_far_metro_entrance),
	# so only this side's escalator is shown.
	_draw_straight_entrance_frames(shift)
	_draw_entrance_signs(shift)
	_draw_bus_shelter()
	StreetDetails.draw_near_side(self, _screen_font, shift, animation_time)

func _draw_backdrop_shape(source_points: PackedVector2Array, offset: Vector2, texture: Texture2D = BACKDROP) -> void:
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	for point in source_points:
		vertices.append(point + offset)
		uvs.append(point / texture.get_size())
	draw_polygon(vertices, PackedColorArray([Color.WHITE]), uvs, texture)

func _draw_straight_entrance_frames(shift: float) -> void:
	for right in [false]:
		var outline := _entrance_outline(right, shift)
		outline.append(outline[0])
		draw_polyline(outline, Color("53616d"), 1.4)
		for local_x in [46.0, 104.0, 164.0, 224.0, 284.0, 344.0]:
			var x: float = 2172.0 - local_x - shift if right else local_x + shift
			var top: float = 486.0 if local_x <= 260.0 else 486.0 + (local_x - 260.0) * 68.0 / 155.0
			draw_line(Vector2(x, top), Vector2(x, 554), Color("47535f"), 1.4)
			draw_line(Vector2(x + 0.7, top), Vector2(x + 0.7, 554), Color("9fa7aa"), 0.5)

func _draw_entrance_signs(shift: float) -> void:
	for index in range(1):
		var x: float = 70.0 + shift
		draw_rect(Rect2(x, 489, 96, 18), Color("253840"))
		draw_rect(Rect2(x + 2, 492, 12, 12), MetroLine.colour())
		draw_string(_screen_font, Vector2(x + 5, 502), MetroLine.number(), HORIZONTAL_ALIGNMENT_LEFT, 9, 10, Color.WHITE)
		draw_string(_screen_font, Vector2(x + 18, 502), "%s %s" % [MetroLine.station(), MetroLine.station_en()], HORIZONTAL_ALIGNMENT_LEFT, 75, 10, Color("f3e6cc"))
		var tactile_x: float = 61.0 + shift if index == 0 else 2058.0 - shift
		for tile in range(6):
			draw_rect(Rect2(tactile_x + tile * 6, 553, 5, 4), Color("c9a566"))

func _bus_status(arrival: int) -> String:
	# Shenzhen e-stops report one of four states; the simulated 70 s cycle maps onto them.
	if arrival == 0: return "已到站"
	if arrival <= 12: return "即将进站"
	if arrival <= 38: return "距本站 1 站"
	return "距本站 2 站"

func _draw_bus_screen(r: Rect2, arrival: int, compact: bool) -> void:
	var now := Time.get_datetime_dict_from_system()
	draw_rect(r.grow(0.8), Color("4a565d"))
	draw_rect(r, Color("0b1317"))
	var header := Rect2(r.position, Vector2(r.size.x, 6.0 if compact else 7.0))
	draw_rect(header, Color("0b4f8a"))
	var small := 4.0 if compact else 5.0
	draw_string(_screen_font, header.position + Vector2(1.5, header.size.y - 1.4), MetroLine.station() + "站" if compact else MetroLine.station() + "站 电子站牌", HORIZONTAL_ALIGNMENT_LEFT, r.size.x * 0.7, small, Color.WHITE)
	draw_string(_screen_font, header.position + Vector2(r.size.x - (11.0 if compact else 14.0), header.size.y - 1.4), "%02d:%02d" % [now.hour, now.minute], HORIZONTAL_ALIGNMENT_LEFT, 14, small, Color("cfe3f2"))
	var row_y := header.end.y + 1.5
	var badge := Rect2(r.position.x + 1.5, row_y, 8.0 if compact else 10.0, 6.5 if compact else 8.0)
	draw_rect(badge, Color("f2c230"))
	draw_string(_screen_font, Vector2(badge.position.x + (2.4 if compact else 3.0), badge.end.y - 1.3), "3", HORIZONTAL_ALIGNMENT_LEFT, 8, 5.0 if compact else 6.5, Color("1b1b1b"))
	var status := _bus_status(arrival)
	var colour := Color("e9f2df")
	if arrival == 0: colour = Color("7be08a")
	elif arrival <= 12: colour = Color("ffb23e") if fposmod(animation_time, 1.0) < 0.7 else Color("ffb23e", 0.45)
	draw_string(_screen_font, Vector2(badge.end.x + 2.0, badge.end.y - 1.2), status, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - badge.size.x - 4.0, 4.5 if compact else 6.0, colour)
	if not compact:
		var detail := "模拟 · 约 %d 秒" % arrival if arrival > 0 else "模拟 · 请从前门上车"
		draw_string(_screen_font, Vector2(r.position.x + 1.5, r.end.y - 1.5), detail, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 3.0, 4.5, Color("8fa3ad"))

func _draw_stop_sign(x: float) -> void:
	# Standalone stop sign (站牌): blue name band, route chip and destination.
	draw_rect(Rect2(x - 0.8, 503, 1.6, 53), Color("9aa5a8"))
	draw_rect(Rect2(x - 0.8, 503, 0.6, 53), Color("d3d9da"))
	var panel := Rect2(x - 8, 486, 16, 24)
	draw_rect(panel.grow(0.6), Color("5b676d"))
	draw_rect(panel, Color("f3f5f2"))
	draw_rect(Rect2(panel.position, Vector2(panel.size.x, 7)), Color("0b4f8a"))
	draw_string(_screen_font, Vector2(panel.position.x + 1.5, panel.position.y + 5.4), MetroLine.station(), HORIZONTAL_ALIGNMENT_LEFT, 14, 5, Color.WHITE)
	draw_rect(Rect2(panel.position.x + 1.5, panel.position.y + 9, 6, 5), Color("f2c230"))
	draw_string(_screen_font, Vector2(panel.position.x + 3.2, panel.position.y + 13.2), "3", HORIZONTAL_ALIGNMENT_LEFT, 6, 4.5, Color("1b1b1b"))
	draw_string(_screen_font, Vector2(panel.position.x + 8.2, panel.position.y + 13.0), "路", HORIZONTAL_ALIGNMENT_LEFT, 6, 4, Color("27313a"))
	draw_string(_screen_font, Vector2(panel.position.x + 1.5, panel.position.y + 20.5), "→华强北", HORIZONTAL_ALIGNMENT_LEFT, 15, 3.5, Color("4a5560"))

func _draw_bus_shelter() -> void:
	# The glass is a runtime translucent layer: traffic remains visible through
	# it. Roof, posts, wooden bench and display bezel use the authored sprite.
	draw_rect(Rect2(1009, 487, 147, 65), Color(0.26, 0.43, 0.48, 0.10))
	draw_texture_rect_region(Art.smooth(SHELTER_ART), Rect2(990, 475, 190, 82), SHELTER_SOURCE)
	# Enlarge the screen within the frame so both route and countdown are readable.
	draw_texture_rect_region(Art.smooth(SHELTER_ART), Rect2(1073, 487, 87, 38), Rect2(1086, 211, 568, 247))
	_draw_bus_screen(Rect2(1078, 492, 77, 26), Transit.bus_arrival_for("near_bus", animation_time), false)
	_draw_stop_sign(988.0)

func _train_x(seconds: float, scene_width: float) -> float:
	return Transit.train_position(seconds, scene_width)

func _visual_weather_code() -> int:
	return weather_override if weather_override >= 0 else int(weather.get("code", -1))

func _is_snowing() -> bool:
	return _visual_weather_code() in [71, 73, 75, 77, 85, 86]

func _is_raining() -> bool:
	return _visual_weather_code() in [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target := _display_rect(get_viewport_rect().size, BACKDROP.get_size(), display_mode)
		var found := _entity_at((event.position - target.position) / (target.size / BACKDROP.get_size()))
		if found.is_empty():
			pinned = false
			_set_hovered({})
		else:
			pinned = true
			_set_hovered(found)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				_set_panel_visible(not panel_visible)
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
	weather = {"temperature": current.temperature_2m, "code": current.weather_code, "time": current.time,
		"cloud_cover": current.get("cloud_cover", 30), "wind": current.get("wind_speed_10m", 10.0), "precipitation": current.get("precipitation", 0.0)}
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
	var demo_now := now_dict()
	var now := "%04d-%02d-%02d %02d:%02d:%02d%s" % [demo_now.year, demo_now.month, demo_now.day, demo_now.hour, demo_now.minute, demo_now.second, "（演示时间）" if clock_override >= 0.0 else ""]
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
	_status_label.text = "深圳像素城市  ·  本机时间\n%s\n%s%s\n居民：%d 步行 · %d 候车 · %d 乘车\n路人 %d · 道路车辆 %d · 公交地铁按时刻表运行" % [now, details, demonstration, walking, waiting, riding, crowd.people.size(), traffic.vehicles.size()]
