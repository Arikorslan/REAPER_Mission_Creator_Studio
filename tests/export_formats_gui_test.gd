extends SceneTree
## Exercises the same progress pipeline for the optional GLB and 3D ZIP exports.
const SceneCheck = preload("res://scripts/glb_scene_check.gd")
const Exporter = preload("res://scripts/scene_export.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + text)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	get_root().size = Vector2i(1280, 720)
	var app = load("res://main.tscn").instantiate()
	get_root().add_child(app)
	await process_frame
	await create_timer(2.0).timeout
	app._open_from(ProjectSettings.globalize_path("res://examples/Operation_Sandglass.rmdraft"))
	await create_timer(1.0).timeout
	for kind in ["glb", "pack"]:
		var path := ProjectSettings.globalize_path("user://progress_test_scene.glb" if kind == "glb" else "user://progress_test_scene.zip")
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		if kind == "glb": app._export_glb_to(path)
		else: app._export_pack_to(path)
		var start := Time.get_ticks_msec()
		var visible_frames := 0
		while app._export_running and Time.get_ticks_msec() - start < 120000:
			await process_frame
			if app.export_progress_layer.visible: visible_frames += 1
		check(not app._export_running and visible_frames >= 10, "%s export completed with live progress (%d frames)" % [kind, visible_frames])
		check(FileAccess.file_exists(path), "%s export produced its file" % kind)
		if not FileAccess.file_exists(path): continue
		if kind == "glb":
			var bytes := FileAccess.get_file_as_bytes(path)
			var verified := SceneCheck.verify(bytes, Exporter.scene_nodes(app.state))
			check(bool(verified.get("ok", false)), "exported GLB structure and positions: " + str(verified.get("error", "")))
		else:
			var zip := ZIPReader.new()
			var opened := zip.open(path) == OK
			var files := zip.get_files() if opened else PackedStringArray()
			check(opened and files.has("REAPER_3D_Export/scene.glb") and files.has("REAPER_3D_Export/manifest.json"), "3D archive contains scene and manifest")
			if opened: zip.close()
		print("FORMAT_OUTPUT ", kind, " ", path)
	print("RESULT export formats: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
