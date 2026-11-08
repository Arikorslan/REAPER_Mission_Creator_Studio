extends SceneTree
## Captures the actual UI while building a small sample mission with the real
## Mission Creator state and commands. Set REAPER_CAPTURE_DIR to an output dir.

const Store = preload("res://scripts/draft_store.gd")
var app
var state
var view
var out_dir := ""
var errors := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	out_dir = OS.get_environment("REAPER_CAPTURE_DIR")
	if out_dir.is_empty(): out_dir = ProjectSettings.globalize_path("user://premium_screenshots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_root().size = Vector2i(1600, 900)
	app = load("res://main.tscn").instantiate()
	get_root().add_child(app)
	await process_frame
	await create_timer(4.5).timeout
	state = app.state
	view = app.scene_view
	await shot("01_new_mission.png")

	# Build a real, editable sample; the road and the patrol route are data in
	# the mission, and the camera is merely positioned for the screenshot.
	state.set_mission("name", "Operation Sandglass")
	state.set_mission("briefing", "Locate the command post and observe hostile patrol movement. Keep the aircraft clear of the village.")
	state.set_mission("objectives", ["Identify the command post", "Observe the patrol", "Return to base"])
	app._apply_weather_preset("clear")
	var target: String = state.add_object("compound", Vector2(28, -30), "Command post")
	state.set_value(target, "faction", "Hostile")
	state.add_object("house", Vector2(-25, -28), "Village house")
	var truck: String = state.add_object("technical", Vector2(-15, 35), "Patrol truck")
	state.add_object("humvee", Vector2(45, 40), "Escort vehicle")
	state.add_object("drone_start", Vector2(-115, 75), "Drone air start")
	var road: String = state.add_construction("road_path", Vector2(-125, 65), 12.0)
	var road_points := 0
	for point in [Vector2(-75, 54), Vector2(-30, 40), Vector2(12, 25), Vector2(60, 3), Vector2(110, -12)]:
		if state.append_construction(road, point): road_points += 1
	for point in [Vector2(0, 28), Vector2(45, 15), Vector2(85, -2)]: state.add_waypoint(truck, point)
	state.select(target)
	app._set_recon_target()
	state.select(truck)
	app._open_right_tab("MISSION")
	app._status("Example mission: command post, patrol route and drawn road")
	camera(Vector3(0, 3, 3), 190.0, -40.0, 28.0)
	await create_timer(3.0).timeout
	await shot("02_mission_setup.png")

	app.shell_slots.content_tab_button.pressed.emit()
	app._open_right_tab("OBJECT")
	camera(Vector3(-8, 2, 26), 125.0, -37.0, 26.0)
	await create_timer(2.4).timeout
	await shot("03_content_and_object.png")

	# Select the Studio grass material through the real paint selector and
	# perform two actual paint strokes in the underlying mission state.
	app.shell_slots.terrain_tab_button.pressed.emit()
	var paint_index := -1
	for i in app.paint_texture.item_count:
		if app.paint_texture.get_item_text(i) == "Studio: Lush Grass": paint_index = i
	var paint_success := 0
	if paint_index > 0:
		app.paint_texture.select(paint_index)
		app.paint_texture.item_selected.emit(paint_index)
		var id: String = app.paint_texture_id
		var started: Dictionary = state.begin_paint_stroke(id)
		if started.get("ok", false):
			for p in [Vector2(-150, -80), Vector2(80, -120)]:
				if state.paint_terrain(p, 260.0, 30.0, id): paint_success += 1
			state.finish_paint_stroke()
	app._shelf_tool(7)
	app._status("Terrain paint: Studio Lush Grass • sample strokes")
	camera(Vector3(0, 0, -35), 470.0, -36.0, 33.0)
	await create_timer(3.0).timeout
	await shot("04_terrain_paint_and_routes.png")

	# Save the editable draft. The matching package is generated separately by
	# export_example.gd so the screenshot renderer does not duplicate GPU memory.
	state.select(target)
	state.set_mission("recon_target", target)
	state.finish_paint_stroke()
	state.commit_paint()
	var base := ProjectSettings.globalize_path("res://examples/")
	DirAccess.make_dir_recursive_absolute(base)
	var draft: Dictionary = Store.save_draft(base + "Operation_Sandglass.rmdraft", state.data, state.custom_assets)
	print("CAPTURE example draft=", draft.get("ok", false), " error=", draft.get("error", ""))
	print("CAPTURE road points=", road_points, " painted strokes=", paint_success)
	if not draft.get("ok", false) or road_points < 2 or paint_success < 2: errors += 1

	# Narrower window: responsive layout collapses the inspector but keeps all
	# controls accessible via the header buttons/scrollable command ribbon.
	get_root().size = Vector2i(1024, 768)
	await process_frame
	await process_frame
	app._apply_responsive()
	app.shell_slots.terrain_tab_button.pressed.emit()
	camera(Vector3(0, 0, -35), 300.0, -38.0, 28.0)
	await create_timer(2.5).timeout
	await shot("05_compact_1024.png")
	print("CAPTURE compact tools=", app.library_panel.visible, " inspector=", app.inspector_panel.visible, " viewport=", view.size)

	get_root().size = Vector2i(800, 600)
	await process_frame
	await process_frame
	app._apply_responsive()
	app._open_right_tab("MISSION")
	await create_timer(2.5).timeout
	await shot("06_compact_800_inspector.png")
	print("CAPTURE narrow tools=", app.library_panel.visible, " inspector=", app.inspector_panel.visible, " viewport=", view.size)
	print("CAPTURE RESULT errors=", errors)
	quit(0 if errors == 0 else 1)

func camera(target: Vector3, distance: float, yaw: float, pitch: float) -> void:
	view._target = target
	view._distance = distance
	view._yaw = deg_to_rad(yaw)
	view._pitch = deg_to_rad(pitch)
	view._update_camera()

func shot(name_: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var result := get_root().get_texture().get_image().save_png(out_dir.path_join(name_))
	print("CAPTURE ", name_, " result=", result, " window=", get_root().size)
	if result != OK: errors += 1
