extends SceneTree



const State = preload("res://scripts/mission_state.gd")
const Library = preload("res://scripts/asset_library.gd")
const Export = preload("res://scripts/scene_export.gd")
const Terrain = preload("res://scripts/terrain_model.gd")
const Paint = preload("res://scripts/terrain_paint.gd")
const TextureCodec = preload("res://scripts/texture_codec.gd")

func _initialize() -> void: run.call_deferred()

func aabb_of(node: Node3D, holder: Node) -> Array:
	var box := AABB(); var first := true
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		if mi.mesh == null: continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b); first = false
	return [box, first]

func run() -> void:
	var state = State.new()
	state.reset_blank()

	var tex_img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			tex_img.set_pixel(x, y, Color(0.85, 0.72, 0.3) if ((x / 8) +(y / 8)) % 2 == 0 else Color(0.3, 0.45, 0.2))
	var png := tex_img.save_png_to_buffer()
	var TexCodec = TextureCodec
	var tex_id := "tex_" + preload("res://scripts/glb_codec.gd").sha256(png)
	state.custom_assets[tex_id] = { "name": "checker", "bytes": png, "category": "texture"}
	state.data["terrain_texture"] = tex_id
	state.data["terrain_tile_m"] = 40.0

	var mask := Paint.blank()
	for y in Paint.MASK_SIZE:
		for x in Paint.MASK_SIZE:
			if y < Paint.MASK_SIZE / 2: mask.set_pixel(x, y, Color(1, 0, 0, 0))
	state.data["terrain_paint"] = { "resolution": Paint.MASK_SIZE, "layers": [tex_id], "mask": Paint.encode(mask)}

	state.add_object("house", Vector2(-40, 20))
	state.add_object("compound", Vector2(15, -25))
	state.add_object("humvee", Vector2(60, 60))
	state.add_object("technical", Vector2(-70, -50))
	state.add_object("civilian", Vector2(90, -80))
	state.add_object("tb2", Vector2(-120, 30))
	state.add_object("drone_start", Vector2(0, 120))
	state.add_object("terrain_hill", Vector2(150, 150))
	state.add_object("terrain_mountain", Vector2(-160, 160))

	var rows: Array = state.data["objects"]
	rows[0]["yaw_deg"] = 35.0
	rows[0]["scale"] = 1.8
	rows[1]["pitch_deg"] = 12.0; rows[1]["roll_deg"] = -7.0; rows[1]["yaw_deg"] = 120.0
	rows[3]["yaw_deg"] = -60.0; rows[3]["scale"] = 2.5
	print("BUILD objects=", rows.size(), " assets=", state.custom_assets.size())

	var library = Library.new()
	var built: Dictionary = Export.build_scene(state, library)
	var root: Node3D = built.root
	var editor := {}
	var editor_names: Array = []
	for child in root.get_children():
		if not child is Node3D: continue
		var res := aabb_of(child, root)
		editor[str(child.name)] = res[0]
		editor_names.append(str(child.name))

	var combined: Dictionary = Export.build_combined(state, library)
	print("GLB ok=", combined.get("ok"), " bytes=", (combined.get("bytes", PackedByteArray()) as PackedByteArray).size(), " err=", combined.get("error", ""))
	DirAccess.make_dir_recursive_absolute("/tmp/export_probe2")
	var f := FileAccess.open("/tmp/export_probe2/scene.glb", FileAccess.WRITE)
	f.store_buffer(combined.bytes); f.close()

	var doc := GLTFDocument.new(); var gs := GLTFState.new()
	var err := doc.append_from_buffer(combined.bytes, "", gs)
	print("REIMPORT err=", err)
	if err != OK: quit(1); return
	var scene_root: Node3D = doc.generate_scene(gs, 30.0, false, false)
	root.get_parent() if false else null
	var rows_out: Array = []
	for node in scene_root.find_children("*", "Node3D", true, false):
		var n3 := node as Node3D
		if not editor.has(str(n3.name)): continue
		var res := aabb_of(n3, scene_root)
		if not bool(res[1]): continue
		var a: AABB = editor[str(n3.name)]
		var b: AABB = res[0]
		var dpos := (a.get_center() -b.get_center()).length()
		var dsize := absf(a.size.length() -b.size.length())
		rows_out.append([str(n3.name), dpos, dsize])
	rows_out.sort_custom(func (x, y): return float(x[1]) > float(y[1]))
	print("EDITOR names: ", editor_names)
	var glb_names: Array = []
	for node in scene_root.find_children("*", "Node3D", true, false):
		if editor.has(str((node as Node3D).name)): glb_names.append(str((node as Node3D).name))
	print("GLB matched names: ", glb_names)
	print("COMPARE name | centre error (m) | size error (m)")
	for r in rows_out:
		print("COMPARE %-18s centre=%8.3f size=%8.3f" % [r[0], r[1], r[2]])
	if rows_out.is_empty(): print("COMPARE no matching nodes found")
	quit(0)
