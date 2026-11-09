extends SceneTree
## End-to-end mission export using one exact-150-MiB padded model or animation.
## Usage: -- model|animation fixture.glb output.rmission
const Store = preload("res://scripts/draft_store.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3 or args[0] not in ["model", "animation"]: quit(2); return
	var mode := args[0]
	var app = load("res://main.tscn").instantiate()
	get_root().add_child(app)
	await process_frame
	app._import_asset(args[1], mode)
	var asset_id := ""
	for key in app.state.custom_assets:
		if str(app.state.custom_assets[key].get("category", "")) == mode: asset_id = str(key); break
	check(not asset_id.is_empty(), "150 MiB " + mode + " imported into Creator")
	if asset_id.is_empty(): print("IMPORT_ERROR ", app.information.dialog_text); quit(1); return
	var target: String = app.state.add_object(asset_id if mode == "model" else "house", Vector2(0, 0), "Target")
	app.state.set_mission("name", "Large asset " + mode + " test")
	app.state.set_mission("recon_target", target)
	if FileAccess.file_exists(args[2]): DirAccess.remove_absolute(args[2])
	app._export_mission_to(args[2])
	var started := Time.get_ticks_msec()
	var frames := 0
	var max_gap := 0
	var prev := started
	var saw_write := false
	while app._export_running and Time.get_ticks_msec() - started < 120000:
		await process_frame
		var now := Time.get_ticks_msec()
		max_gap = maxi(max_gap, now - prev); prev = now; frames += 1
		if app._export_channel != null and str(app._export_channel.snapshot().note).begins_with("Writing package"):
			saw_write = true
	check(not app._export_running, "large-asset mission export finished")
	check(frames > 10, "main loop kept drawing during export (%d frames)" % frames)
	check(saw_write, "live byte-count progress appeared during package writing")
	check(FileAccess.file_exists(args[2]), "large-asset mission file exists")
	if not FileAccess.file_exists(args[2]): print("EXPORT_ERROR ", app.information.dialog_text)
	if FileAccess.file_exists(args[2]):
		var read := Store.load_mission(args[2])
		check(bool(read.get("ok", false)) and read.assets.has(asset_id), "exported mission reloads with the original %s" % mode)
		if bool(read.get("ok", false)) and read.assets.has(asset_id):
			check((read.assets[asset_id].bytes as PackedByteArray).size() == 150 * 1024 * 1024, "export preserves the full 150 MiB asset")
	print("LARGE_ASSET_METRICS mode=", mode, " frames=", frames, " max_frame_gap_ms=", max_gap, " elapsed_ms=", Time.get_ticks_msec() - started)
	print("RESULT large asset ", mode, ": ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
