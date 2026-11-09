extends SceneTree
## GUI integration test: observe live export progress, input lock, worker
## heartbeats and full-engine verification of the resulting mission.
const Store = preload("res://scripts/draft_store.gd")
const Bake = preload("res://scripts/ground_bake.gd")
const Exporter = preload("res://scripts/scene_export.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + text)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	get_root().size = Vector2i(1280, 720)
	var app = load("res://main.tscn").instantiate()
	get_root().add_child(app)
	await process_frame
	await create_timer(2.0).timeout
	app._open_from(ProjectSettings.globalize_path("res://examples/Operation_Sandglass.rmdraft"))
	await create_timer(1.0).timeout
	# A small CPU vs existing GPU texture path comparison guards ground colour.
	var old_image: Image = Bake.bake(app.state, Exporter.texture_lookup(app.state.custom_assets), 96)
	var new_image: Image = Bake.bake(app.state, Exporter.cpu_texture_lookup(app.state.custom_assets), 96)
	check(old_image != null and new_image != null and old_image.get_data() == new_image.get_data(), "background CPU ground bake matches the original pixels")
	var output := ProjectSettings.globalize_path("user://progress_gui_test.rmission")
	if FileAccess.file_exists(output): DirAccess.remove_absolute(output)
	var original_name := str(app.state.data.name)
	var original_count: int = app.state.data.objects.size()
	app._export_mission_to(output)
	var start := Time.get_ticks_msec()
	var previous := start
	var last_value := -1.0
	var monotonic := true
	var saw_overlay := false
	var tried_input := false
	var screenshot := false
	var frames := 0
	var bake_frames := 0
	var max_gap := 0
	var unique := {}
	var notes := {}
	while Time.get_ticks_msec() - start < 120000:
		await process_frame
		var now := Time.get_ticks_msec()
		if not app._export_running: break
		frames += 1
		max_gap = maxi(max_gap, now - previous)
		previous = now
		if app.export_progress_layer.visible: saw_overlay = true
		if app._export_channel != null:
			var snapshot: Dictionary = app._export_channel.snapshot()
			var value := float(snapshot.percent)
			var note := str(snapshot.note)
			if value + 0.01 < last_value: monotonic = false
			last_value = maxf(last_value, value)
			unique[int(value)] = true
			notes[note] = true
			if note.begins_with("Baking ground"):
				bake_frames += 1
				if not tried_input:
					tried_input = true
					var key := InputEventKey.new()
					key.pressed = true
					key.ctrl_pressed = true
					key.keycode = KEY_N
					Input.parse_input_event(key)
				if value > 5.0 and not screenshot:
					screenshot = true
					await RenderingServer.frame_post_draw
					get_root().get_texture().get_image().save_png("user://progress_overlay.png")
	check(not app._export_running, "export completed without a blocked worker")
	check(saw_overlay and screenshot, "visible modal progress bar rendered")
	check(frames >= 20 and bake_frames >= 10, "UI frames continued during the long ground-bake worker (%d total, %d bake)" % [frames, bake_frames])
	check(unique.size() >= 8 and monotonic, "stage progress advanced monotonically through at least 8 percentages (%d)" % unique.size())
	check(tried_input and str(app.state.data.name) == original_name and app.state.data.objects.size() == original_count, "editing shortcut was blocked while exporting")
	check(FileAccess.file_exists(output), "mission file exists")
	var full := Store.verify_package(output) if FileAccess.file_exists(output) else {"ok": false, "error": "missing file"}
	check(bool(full.get("ok", false)), "output also passes full Godot re-import: " + str(full.get("error", "")))
	print("PROGRESS_METRICS frames=", frames, " bake_frames=", bake_frames, " distinct_percentages=", unique.size(), " max_frame_gap_ms=", max_gap, " elapsed_ms=", Time.get_ticks_msec() - start)
	print("PROGRESS_SCREENSHOT ", ProjectSettings.globalize_path("user://progress_overlay.png"))
	print("PROGRESS_OUTPUT ", output)
	print("RESULT progress GUI: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
