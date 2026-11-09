extends SceneTree
## Compares worker-safe structural verification with the full Godot re-import
## on the included real mission, and checks that corruption is rejected.
const Store = preload("res://scripts/draft_store.gd")
const Codec = preload("res://scripts/glb_codec.gd")
const Fbx = preload("res://scripts/fbx_converter.gd")
const Check = preload("res://scripts/glb_scene_check.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + text)
func _initialize() -> void:
	var path := ProjectSettings.globalize_path("res://examples/Operation_Sandglass.rmission")
	check(Codec.MAX_GLB_BYTES == 150 * 1024 * 1024, "models and animations use the 150 MiB limit")
	check(Fbx.MAX_FBX_BYTES == Codec.MAX_GLB_BYTES, "FBX input uses the same 150 MiB limit")
	check(Store.MAX_SCENE_BYTES == 512 * 1024 * 1024, "scene limit remains 512 MiB")
	var loaded := Store.load_mission(path)
	check(bool(loaded.get("ok", false)), "example mission reads")
	if not bool(loaded.get("ok", false)): quit(1); return
	var block: Dictionary = loaded.mission.scene
	var record: String = str(block.scene_glb.glb_asset)
	var bytes: PackedByteArray = loaded.assets[record].bytes
	var expected: Array = block.nodes
	var quick := Check.verify(bytes, expected)
	check(bool(quick.get("ok", false)), "CPU scene structure and object-position check: " + str(quick.get("error", "")))
	var fast := Store.verify_package(path, true)
	var full := Store.verify_package(path)
	check(bool(fast.get("ok", false)), "worker-safe package verification: " + str(fast.get("error", "")))
	check(bool(full.get("ok", false)), "full Godot scene re-import verification: " + str(full.get("error", "")))
	check(int(fast.get("objects", -1)) == int(full.get("objects", -2)), "both verification paths count the same objects")
	var wrong := expected.duplicate(true)
	if not wrong.is_empty(): wrong[0].position[0] = float(wrong[0].position[0]) + 5.0
	check(not Check.verify(bytes, wrong).get("ok", true), "moved object is rejected")
	var missing := expected.duplicate(true)
	if not missing.is_empty(): missing[0].name = "definitely_missing_object"
	check(not Check.verify(bytes, missing).get("ok", true), "missing object is rejected")
	var bad := bytes.duplicate()
	bad.encode_u32(8, bad.size() - 4)
	check(not Check.verify(bad, expected).get("ok", true), "corrupt GLB length is rejected")
	print("RESULT export structure: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
