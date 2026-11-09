extends SceneTree
## Run separately for each fixture to avoid keeping multiple 150 MiB files in
## memory. Usage: --script res://tests/asset_limit_test.gd -- model|animation|over fixture.glb
const Store = preload("res://scripts/draft_store.gd")
const Codec = preload("res://scripts/glb_codec.gd")
const Fbx = preload("res://scripts/fbx_converter.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: print("Expected mode and fixture path"); quit(2); return
	var mode := args[0]
	var path := args[1]
	check(Codec.MAX_GLB_BYTES == 150 * 1024 * 1024, "GLB budget is 150 MiB")
	check(Fbx.MAX_FBX_BYTES == 150 * 1024 * 1024, "FBX input budget is 150 MiB")
	if mode == "over":
		var prepared := Codec.prepare(path)
		check(not bool(prepared.get("ok", true)) and str(prepared.get("error", "")).contains("limit"), "a GLB just above 150 MiB is rejected before reading")
		var too_big := PackedByteArray()
		too_big.resize(Fbx.MAX_FBX_BYTES + 1)
		var fbx := Fbx.convert(too_big, true, true)
		check(not bool(fbx.get("ok", true)) and str(fbx.get("error", "")).contains("150 MiB"), "an FBX above 150 MiB is rejected before conversion")
		print("RESULT ", mode, ": ", checks, " checks, ", failures, " failures")
		quit(0 if failures == 0 else 1); return
	if mode not in ["model", "animation"]: quit(2); return
	var app = load("res://main.tscn").instantiate()
	get_root().add_child(app)
	await process_frame
	app._import_asset(path, mode)
	var found := ""
	for key in app.state.custom_assets:
		if str(app.state.custom_assets[key].get("category", "")) == mode: found = str(key); break
	check(not found.is_empty(), "the Creator's actual %s import path accepted the file" % mode)
	if found.is_empty():
		print("IMPORT_ERROR ", app.information.dialog_text)
		quit(1); return
	var record: Dictionary = app.state.custom_assets[found]
	var bytes: PackedByteArray = record.bytes
	check(bytes.size() == 150 * 1024 * 1024, "the imported %s is exactly 150 MiB" % mode)
	var validated := Codec.validate(bytes, mode == "animation")
	check(bool(validated.get("ok", false)), "the imported %s validates" % mode)
	if mode == "animation":
		check(bool(validated.get("has_animation", false)), "the 150 MiB animation contains a usable clip")
	else:
		check(bool(validated.get("has_mesh", false)), "the 150 MiB model contains a mesh")
	var output := ProjectSettings.globalize_path("user://limit_" + mode + "_test.rmdraft")
	var saved := Store.save_draft(output, app.state.data, app.state.custom_assets)
	check(bool(saved.get("ok", false)), "the imported %s saves in a draft: %s" % [mode, str(saved.get("error", ""))])
	if bool(saved.get("ok", false)):
		var loaded := Store.load_draft(output)
		check(bool(loaded.get("ok", false)) and loaded.assets.has(found), "the 150 MiB %s survives draft reload" % mode)
	DirAccess.remove_absolute(output)
	print("RESULT ", mode, ": ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
