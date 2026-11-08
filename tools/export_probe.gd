extends SceneTree



const Draft = preload("res://scripts/draft_store.gd")
const State = preload("res://scripts/mission_state.gd")
const Library = preload("res://scripts/asset_library.gd")
const Export = preload("res://scripts/scene_export.gd")
const Terrain = preload("res://scripts/terrain_model.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var sample := "/home/user/_creator/REAPER_Android_Creator_Work/sample/Desert_Recon_Sample.rmission"
	var loaded: Dictionary = Draft.load_mission(sample)
	print("LOAD ok=", loaded.get("ok"), " err=", loaded.get("error"))
	if not bool(loaded.get("ok", false)): quit(1); return
	var state = State.new()
	state.replace_loaded(loaded.mission, loaded.assets)
	print("STATE objects=", state.data.get("objects", []).size(), " assets=", state.custom_assets.size(),
		" texture=", state.data.get("terrain_texture", "<none>"),
		" tile=", state.data.get("terrain_tile_m", "<none>"),
		" paint=", not (state.data.get("terrain_paint", {}) as Dictionary).is_empty())
	var library = Library.new()


	var expected := {}
	var objects: Array = state.data.get("objects", [])
	for row in objects:
		var x := float(row.get("x", 0)); var z := float(row.get("z", 0))
		var extra := 0.0 if Terrain.is_feature(str(row.get("asset", ""))) else float(row.get("height", 0.0))
		expected[str(row.get("name", row.get("id", "")))] = Vector3(x, Terrain.height_at(state.data.get("terrain", {}), objects, x, z) +extra, z)


	var built: Dictionary = Export.build_scene(state, library)
	var root: Node3D = built.root
	var in_tree := {}
	for child in root.get_children():
		if child is Node3D:
			in_tree[str(child.name)] = (child as Node3D).position
	print("SCENE objects=", built.objects, " children=", root.get_child_count())
	var worst := 0.0
	var worst_name := ""
	for name in expected:
		if not in_tree.has(name):
			print("MISSING ", name); continue
		var d: float = (Vector3(in_tree[name]) -Vector3(expected[name])).length()
		if d > worst: worst = d; worst_name = str(name)
	print("SCENE worst placement error=", worst, " at ", worst_name)


	var ground: MeshInstance3D = null
	for child in root.get_children():
		if child is MeshInstance3D: ground = child; break
	if ground != null:
		var mat = ground.material_override
		if mat is StandardMaterial3D:
			var tex: Texture2D = (mat as StandardMaterial3D).albedo_texture
			print("GROUND material=Standard albedo=", (mat as StandardMaterial3D).albedo_color,
				" texture=", tex.get_size() if tex != null else "none")
			if tex != null:
				var img: Image = tex.get_image()
				print("GROUND texture mean rgb=", mean(img), " has_alpha_varies=", alpha_varies(img))
		else:
			print("GROUND material=", mat)


	var combined: Dictionary = Export.build_combined(state, library)
	print("GLB ok=", combined.get("ok"), " err=", combined.get("error", ""), " bytes=", (combined.get("bytes", PackedByteArray()) as PackedByteArray).size())
	if bool(combined.get("ok", false)):
		var path := "/tmp/export_probe/scene_glb_roundtrip.glb"
		DirAccess.make_dir_recursive_absolute("/tmp/export_probe")
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(combined.bytes); f.close()
		var doc := GLTFDocument.new(); var gs := GLTFState.new()
		var err := doc.append_from_buffer(combined.bytes, "", gs)
		print("GLB reimport err=", err)
		if err == OK:
			var scene_root: Node3D = doc.generate_scene(gs, 30.0, false, false)
			var found := {}
			for node in scene_root.find_children("*", "Node3D", true, false):
				var n3 := node as Node3D
				var key := str(n3.name)
				if not found.has(key): found[key] = n3.global_position
			print("GLB nodes=", found.size())
			var glb_worst := 0.0; var glb_worst_name := ""
			var missing := 0
			for name in expected:
				if not found.has(name):
					missing += 1; continue
				var d: float = (Vector3(found[name]) -Vector3(expected[name])).length()
				if d > glb_worst: glb_worst = d; glb_worst_name = str(name)
			print("GLB missing=", missing, " worst placement error=", glb_worst, " at ", glb_worst_name)
			var gm: MeshInstance3D = null
			for node in scene_root.find_children("*", "MeshInstance3D", true, false):
				if str(node.name) == "Terrain": gm = node; break
			if gm != null and gm.mesh != null:
				print("GLB terrain surfaces=", gm.mesh.get_surface_count(), " has_uv=", gm.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV != 0)
				var mm = gm.get_active_material(0)
				if mm is BaseMaterial3D:
					print("GLB terrain material albedo_tex=", (mm as BaseMaterial3D).albedo_texture != null, " albedo=", (mm as BaseMaterial3D).albedo_color)
			scene_root.free()
	quit(0)

func mean(img: Image) -> Vector3:
	var total := Vector3.ZERO
	var n := 0
	for y in range(0, img.get_height(), 16):
		for x in range(0, img.get_width(), 16):
			var c := img.get_pixel(x, y)
			total += Vector3(c.r, c.g, c.b)
			n += 1
	return total / float(maxi(n, 1))

func alpha_varies(img: Image) -> bool:
	var first := img.get_pixel(0, 0).a
	for y in range(0, img.get_height(), 16):
		for x in range(0, img.get_width(), 16):
			if absf(img.get_pixel(x, y).a - first) > 0.01: return true
	return false
