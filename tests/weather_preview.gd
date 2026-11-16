extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var preview = load("res://main.tscn").instantiate()
	root.add_child(preview)
	await process_frame
	assert(preview.window_lights.size() > 0 and preview.leaf_patches.size() > 0)
	preview.display_mode = "sky"
	preview._sync_weather_effects()
	assert(is_equal_approx(preview.rain_fx.get_param(&"entrance_offset"), 400.0))
	preview.display_mode = "fit"
	preview._sync_weather_effects()
	assert(is_zero_approx(preview.rain_fx.get_param(&"entrance_offset")))
	var controls := root.find_children("*", "OptionButton", true, false)
	var weather_select: OptionButton
	for control in controls:
		if control.item_count == 6: weather_select = control
	assert(weather_select != null)
	weather_select.item_selected.emit(2)
	assert(preview.weather_override == 63 and preview.rain_fx.visible)
	assert(not preview.snow_fx.visible and not preview.fog_fx.visible)
	weather_select.item_selected.emit(3)
	assert(preview.weather_override == 75 and preview.snow_fx.visible and not preview.rain_fx.visible)
	weather_select.item_selected.emit(4)
	assert(preview.weather_override == 45 and preview.fog_fx.visible and not preview.snow_fx.visible)
	weather_select.item_selected.emit(0)
	assert(preview.weather_override == -1)
	preview.queue_free()
	await process_frame
	print("WEATHER_PREVIEW_TEST_PASSED")
	quit(0)
