extends SceneTree
## GUI export smoke test. Uses the application export callback and checks that
## the success message does not resize the status bar. Requires a display.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	get_root().size = Vector2i(1600, 900)
	var app = load("res://main.tscn").instantiate()
	get_root().add_child(app)
	await process_frame
	await create_timer(4.0).timeout
	var target: String = app.state.add_object("house", Vector2(0, 0), "Test compound")
	app.state.set_mission("name", "GUI export check")
	app.state.set_mission("recon_target", target)
	app._open_right_tab("MISSION")
	app.export_dialog.popup_centered_ratio(0.7)
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("/tmp/premium_themed_dialog.png")
	app.export_dialog.hide()
	var output := "/tmp/reaper_final_gui_export.rmission"
	app._export_mission_to(output)
	for i in 600:
		await create_timer(0.1).timeout
		if not app._export_running: break
	await create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("/tmp/premium_themed_success.png")
	var okay: bool = FileAccess.file_exists(output) and app.information.visible and not app.status.text.contains("\n") and app.information.dialog_text.contains("ground surface included")
	print("GUI EXPORT output=", FileAccess.file_exists(output), " popup=", app.information.visible, " one_line=", not app.status.text.contains("\n"), " textured=", app.information.dialog_text.contains("ground surface included"), " viewport=", app.scene_view.size)
	quit(0 if okay else 1)
