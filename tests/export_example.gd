extends SceneTree
## Regenerates the sample .rmission from the included draft, without opening a UI.
const State = preload("res://scripts/mission_state.gd")
const Library = preload("res://scripts/asset_library.gd")
const Exporter = preload("res://scripts/scene_export.gd")
const Store = preload("res://scripts/draft_store.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var base := ProjectSettings.globalize_path("res://examples/")
	var loaded: Dictionary = Store.load_draft(base + "Operation_Sandglass.rmdraft")
	if not loaded.get("ok", false):
		printerr("DEMO: draft load failed: ", loaded.get("error", "")); quit(1); return
	var state = State.new()
	state.replace_loaded(loaded.mission, loaded.assets)
	var library = Library.new()
	var built: Dictionary = Exporter.build_combined(state, library)
	if not built.get("ok", false):
		printerr("DEMO: scene export failed: ", built.get("error", "")); quit(1); return
	var fidelity := {"ok": true, "objects": int(built.get("objects", 0)), "worst_placement_m": float(built.get("worst_placement_m", 0.0)), "glb_bytes": (built.bytes as PackedByteArray).size(), "checked_utc": Time.get_datetime_string_from_system(true)}
	var result: Dictionary = Store.save_mission_package(base + "Operation_Sandglass.rmission", state.data, state.custom_assets, built.bytes, Exporter.scene_block(state, fidelity))
	print("DEMO: export ok=", result.get("ok", false), " objects=", result.get("objects", 0), " bytes=", result.get("bytes", 0), " error=", result.get("error", ""))
	library.clear_templates()
	quit(0 if result.get("ok", false) else 1)
