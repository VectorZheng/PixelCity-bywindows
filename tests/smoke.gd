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
	city.free()
	print("SMOKE_TEST_PASSED")
	quit(0)
