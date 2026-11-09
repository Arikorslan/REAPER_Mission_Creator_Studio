extends SceneTree
## Protects terrain-following construction and name collisions through the
## stepped, threaded exporter. All assets are small real Creator geometry.
const State = preload("res://scripts/mission_state.gd")
const Library = preload("res://scripts/asset_library.gd")
const Exporter = preload("res://scripts/scene_export.gd")
const Tasks = preload("res://scripts/export_tasks.gd")
const Progress = preload("res://scripts/export_progress.gd")
const Check = preload("res://scripts/glb_scene_check.gd")
const Store = preload("res://scripts/draft_store.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)
func _initialize() -> void: call_deferred("run")
func tick(_done: int, _total: int, _note: String = "") -> void:
	await process_frame
func run() -> void:
	var state = State.new()
	state.add_object("terrain_hill", Vector2.ZERO, "Hill")
	var road_id: String = state.add_construction("road_path", Vector2.ZERO)
	state.append_construction(road_id, Vector2(36, 0), true)
	var lib1 = Library.new()
	var lib2 = Library.new()
	var normal := Exporter.build_scene(state, lib1)
	var image := Image.create(4, 4, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)
	var stepped: Dictionary = await Exporter.build_scene_stepped(state, lib2, Callable(self, "tick"), image)
	check(bool(normal.get("ok", false)) and bool(stepped.get("ok", false)), "both construction paths built")
	if bool(normal.get("ok", false)) and bool(stepped.get("ok", false)):
		var mesh1: MeshInstance3D = normal.root.get_node("Road/TerrainFollowingRoad")
		var mesh2: MeshInstance3D = stepped.root.get_node("Road/TerrainFollowingRoad")
		var verts1: PackedVector3Array = mesh1.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var verts2: PackedVector3Array = mesh2.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		check(not verts1.is_empty() and verts1[0].y > 10.0, "road is visibly elevated by nearby hill")
		check(verts1 == verts2, "stepped export preserves terrain-following road vertices")
		normal.root.free(); stepped.root.free()
	lib1.clear_templates(); lib2.clear_templates()

	state = State.new()
	var target: String = state.add_object("house", Vector2(10, 20), "Home")
	state.set_mission("recon_target", target)
	state.add_object("house", Vector2(40, 60), "Part 01") # clashes with first house's mesh
	state.add_object("house", Vector2(70, 80), "Terrain") # clashes with ground child
	state.add_object("house", Vector2(100, 120), "Home")
	var hidden: String = state.add_object("house", Vector2(130, 140), "Home 2") # clashes with generated suffix
	state.set_flag(hidden, "hidden", true)
	var rows := Exporter.scene_nodes(state)
	var names := {}
	for row in rows: names[str(row.name)] = true
	check(names.size() == rows.size() and not names.has("Terrain"), "placed object names are unique and avoid the terrain child")
	var lib3 = Library.new()
	var built: Dictionary = await Exporter.build_scene_stepped(state, lib3, Callable(self, "tick"), image)
	check(bool(built.get("ok", false)), "collision fixture scene built")
	if bool(built.get("ok", false)):
		var encoded := Tasks.encode_detached(built.root, built.nodes, Progress.new())
		check(bool(encoded.get("ok", false)), "name collisions serialize and verify: " + str(encoded.get("error", "")))
		if bool(encoded.get("ok", false)):
			var reconciled: Array = encoded.get("nodes", built.nodes)
			var validated := Check.verify(encoded.bytes, reconciled)
			check(bool(validated.get("ok", false)), "serialized names and positions match the exported GLB")
			var repeated := reconciled.duplicate(true)
			repeated[1].name = repeated[0].name
			check(not bool(Check.verify(encoded.bytes, repeated).get("ok", true)), "duplicate expected object names are rejected")
			var combined := {"bytes": encoded.bytes, "nodes": reconciled, "objects": reconciled.size(), "ground_image": image, "worst_placement_m": encoded.worst_placement_m}
			var mission_path := ProjectSettings.globalize_path("user://collision_test.rmission")
			var saved := Tasks.save("mission", mission_path, state, combined, Progress.new())
			check(bool(saved.get("ok", false)), "collision mission exports: " + str(saved.get("error", "")))
			if bool(saved.get("ok", false)):
				var full := Store.verify_package(mission_path)
				var reread := Store.load_mission(mission_path)
				check(bool(full.get("ok", false)), "collision mission passes full engine reimport: " + str(full.get("error", "")))
				check(bool(reread.get("ok", false)) and reread.mission.scene.nodes == reconciled, "mission metadata records actual GLB names")
				print("COLLISION_MISSION ", mission_path)
			var zip_path := ProjectSettings.globalize_path("user://collision_test.zip")
			var packed := Tasks.save("pack", zip_path, state, combined, Progress.new())
			check(bool(packed.get("ok", false)), "collision 3D archive exports")
			if bool(packed.get("ok", false)):
				var zip := ZIPReader.new()
				var opened := zip.open(zip_path) == OK
				var doc = JSON.parse_string(zip.read_file("REAPER_3D_Export/manifest.json").get_string_from_utf8()) if opened else null
				var csv := zip.read_file("REAPER_3D_Export/manifest.csv").get_string_from_utf8() if opened else ""
				check(doc is Dictionary and doc.get("nodes", []) == reconciled and csv.contains(str(reconciled[1].name)), "ZIP JSON and CSV record actual GLB names")
				if opened: zip.close()
		built.root.free()
	lib3.clear_templates()
	print("RESULT scene regressions: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
