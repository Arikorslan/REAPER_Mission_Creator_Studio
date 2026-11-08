extends SceneTree
## Smoke test: open and export the included painted six-object draft using the
## normal asynchronous UI export path. Requires a GUI display.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	get_root().size = Vector2i(1280, 720)
	var app = load("res://main.tscn").instantiate()
	get_root().add_child(app)
	await process_frame
	await create_timer(4.0).timeout
	app._open_from(ProjectSettings.globalize_path("res://examples/Operation_Sandglass.rmdraft"))
	await create_timer(2.0).timeout
	var output := ProjectSettings.globalize_path("user://Operation_Sandglass_GUI_Test_%d.rmission" % Time.get_ticks_msec())
	app._export_mission_to(output)
	var previous := ""
	for i in 600:
		await create_timer(0.1).timeout
		if app.status.text != previous:
			previous = app.status.text
			print("EXAMPLE GUI: ", previous)
		if not app._export_running: break
	var ok: bool = FileAccess.file_exists(output) and app.information.dialog_text.contains("exported and verified")
	print("EXAMPLE GUI EXPORT: ", "PASS" if ok else "FAIL", " — ", output)
	quit(0 if ok else 1)
