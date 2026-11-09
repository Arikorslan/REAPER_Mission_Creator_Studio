extends SceneTree
## Actual export to an unwritable location, input/back guards and a clean retry.
const Store = preload("res://scripts/draft_store.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)
func _initialize() -> void: call_deferred("run")
func wait_export(app) -> void:
	var start := Time.get_ticks_msec()
	while app._export_running and Time.get_ticks_msec() - start < 120000:
		await process_frame
func run() -> void:
	get_root().size = Vector2i(1280, 720)
	var app = load("res://main.tscn").instantiate()
	get_root().add_child(app)
	await process_frame
	var target: String = app.state.add_object("house", Vector2(0, 0), "Guard target")
	app.state.set_mission("name", "Keep this draft")
	app.state.set_mission("recon_target", target)
	app.inspector_tab_buttons["MISSION"].pressed.emit()
	await process_frame
	app.mission_name.grab_focus()
	await process_frame
	var had_focus: bool = app.mission_name.has_focus()
	var before_text: String = app.mission_name.text
	var before_name: String = app.state.data.name
	var before_count: int = app.state.data.objects.size()
	var before_autosaves: int = app.autosave.list_versions().size()
	app._export_mission_to("/proc/reaper-export-forbidden/mission.rmission")
	check(app._export_running and app.export_progress_layer.visible, "export begins with visible modal progress")
	check(not auto_accept_quit and not quit_on_go_back, "automatic close and Android back are disabled")
	var letter := InputEventKey.new()
	letter.pressed = true; letter.keycode = KEY_X; letter.unicode = 120
	get_root().push_input(letter)
	var shortcut := InputEventKey.new()
	shortcut.pressed = true; shortcut.ctrl_pressed = true; shortcut.keycode = KEY_N
	get_root().push_input(shortcut)
	app.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	app._autosave_tick()
	await process_frame
	check(had_focus and app.mission_name.text == before_text and app.state.data.name == before_name, "focused text input is blocked during export")
	check(app._export_running and app.pending_action.is_empty() and app.state.data.objects.size() == before_count, "new, close and back actions cannot interrupt export")
	check(app.autosave.list_versions().size() == before_autosaves, "autosave is paused while export is running")
	await wait_export(app)
	check(not app._export_running and app._active_export_thread == null, "failed write finishes and worker is joined")
	check(not app.export_progress_layer.visible and not app.export_button.disabled, "controls and editor return after write error")
	check(app.information.dialog_text.contains("Could not export"), "write error is reported to the user")
	check(app.state.data.name == before_name and app.state.data.objects.size() == before_count, "failed write preserves the draft")
	app.information.hide()
	var path := ProjectSettings.globalize_path("user://recovery_retry.rmission")
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	app._export_mission_to(path)
	await wait_export(app)
	check(not app._export_running and FileAccess.file_exists(path), "retry to a writable destination succeeds")
	var full := Store.verify_package(path) if FileAccess.file_exists(path) else {"ok": false}
	check(bool(full.get("ok", false)), "retried mission passes full engine verification")
	print("RESULT export recovery: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
