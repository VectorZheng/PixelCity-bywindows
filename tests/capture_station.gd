extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var preview = load("res://main.tscn").instantiate()
	root.size = Vector2i(2172, 724)
	root.add_child(preview)
	preview._http.cancel_request()
	preview.set_process(false)
	preview._panel.hide()
	preview.weather_override = 0
	preview._sync_weather_effects()
	preview.display_mode = "fit"
	if OS.get_cmdline_user_args().has("--record-route"):
		await _record_route(preview)
		quit(0)
		return
	var prefix := "after" if OS.get_cmdline_user_args().has("--after") else "before"
	for sample in [["empty", 75.0], ["arrival", 15.0], ["stopped", 27.0], ["departure", 52.0]]:
		preview.animation_time = sample[1]
		preview.residents = preview.Residents.new()
		preview.residents.station_shift = preview._current_station_shift()
		for tick in range(int(sample[1] * 10)):
			preview.residents.step(0.1, tick / 10.0, false, 12)
		preview.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		assert(frame.save_png("res://.tools/station-%s-%s-full.png" % [prefix, sample[0]]) == OK)
		assert(frame.get_region(Rect2i(0, 564, 2172, 160)).save_png("res://.tools/station-%s-%s.png" % [prefix, sample[0]]) == OK)
	root.size = Vector2i(1600, 1000)
	preview.display_mode = "sky"
	preview.animation_time = 27.0
	preview.residents = preview.Residents.new()
	preview.residents.station_shift = preview._current_station_shift()
	for tick in range(270): preview.residents.step(0.1, tick / 10.0, false, 12)
	preview._sync_weather_effects()
	preview.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://.tools/station-%s-compact.png" % prefix) == OK)
	preview.weather_override = 63
	preview.residents = preview.Residents.new()
	preview.residents.station_shift = preview._current_station_shift()
	for tick in range(600): preview.residents.step(0.1, tick / 10.0, true, 12)
	preview.animation_time = 60.0
	preview._sync_weather_effects()
	preview.queue_redraw()
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://.tools/station-%s-rain.png" % prefix) == OK)
	print("STATION_CAPTURE_PASSED: ", prefix)
	quit(0)

func _record_route(preview: Node2D) -> void:
	root.size = Vector2i(1600, 1000)
	preview.display_mode = "sky"
	preview.residents = preview.Residents.new()
	preview.residents.station_shift = preview._current_station_shift()
	preview._sync_weather_effects()
	DirAccess.make_dir_recursive_absolute("res://.tools/route-frames")
	for frame in range(1020):
		preview.animation_time = frame / 30.0
		preview.residents.step(1.0 / 30.0, preview.animation_time, false, 12)
		preview.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image().get_region(Rect2i(0, 620, 800, 380))
		assert(image.save_png("res://.tools/route-frames/%04d.png" % frame) == OK)
		if frame % 150 == 0: print("ROUTE_FRAME ", frame)
	print("ROUTE_CAPTURE_PASSED")
