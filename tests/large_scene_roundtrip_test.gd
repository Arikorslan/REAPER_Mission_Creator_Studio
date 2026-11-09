extends SceneTree
## Exercises the new scene budget with a padded, real >150 MiB scene and a small
## Creator-produced .rmission. Run after make_padded_scene_fixture.py:
## godot --headless --path . --script res://tests/large_scene_roundtrip_test.gd -- small.rmission padded.glb output.rmission
const Store = preload("res://scripts/draft_store.gd")
const Codec = preload("res://scripts/glb_codec.gd")
const Platform = preload("res://scripts/platform_files.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3: print("Expected small mission, padded scene, output mission"); quit(2); return
	check(Store.MAX_SCENE_BYTES == 512 * 1024 * 1024, "exported scene budget is 512 MiB")
	check(Codec.MAX_GLB_BYTES == 150 * 1024 * 1024, "imported-model budget remains 150 MiB")
	check(Store.MAX_FILE == 1024 * 1024 * 1024, "combined container budget is 1024 MiB")
	var src: Dictionary = Store.load_mission(args[0])
	check(src.get("ok", false), "small original mission loads")
	if not src.get("ok", false): quit(1); return
	var big := FileAccess.get_file_as_bytes(args[1])
	check(big.size() > Codec.MAX_GLB_BYTES and big.size() < Store.MAX_SCENE_BYTES, "fixture scene exceeds 150 MiB per-model limit")
	var blocked := Codec.validate(big, false)
	check(not blocked.get("ok", false) and str(blocked.get("error", "")).contains("limit"), "large imported model still fails its independent budget")
	var allowed := Codec.validate(big, false, Store.MAX_SCENE_BYTES)
	check(allowed.get("ok", false), "same GLB validates under the scene budget")
	# Ensure the destination exists, so the segmented writer must safely replace it.
	var old := FileAccess.open(args[2], FileAccess.WRITE)
	old.store_string("OLD SENTINEL"); old.close()
	var saved: Dictionary = Store.save_mission_package(args[2], src.mission, src.assets, big, src.mission.scene)
	check(saved.get("ok", false), "mission with >150 MiB scene saves and rechecks: " + str(saved.get("error", "")))
	if saved.get("ok", false):
		check(int(saved.get("scene_bytes", 0)) == big.size(), "saved scene size matches source")
		var result_file := FileAccess.open(args[2], FileAccess.READ)
		var magic := "" if result_file == null else result_file.get_buffer(8).get_string_from_ascii()
		if result_file != null: result_file.close()
		check(magic == Store.SCENE_MISSION_MAGIC, "existing file was replaced by a mission container")
		var loaded: Dictionary = Store.load_mission(args[2])
		check(loaded.get("ok", false) and loaded.mission.name == src.mission.name, "large package reloads with its mission metadata")
	var invalid := Platform.write_document_parts("", [PackedByteArray([1])])
	check(not invalid.ok, "segmented writer rejects an empty destination")
	print("RESULT large scene: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
