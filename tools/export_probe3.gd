extends SceneTree


const State = preload("res://scripts/mission_state.gd")
const Library = preload("res://scripts/asset_library.gd")
const Export = preload("res://scripts/scene_export.gd")
const Paint = preload("res://scripts/terrain_paint.gd")

func _initialize() -> void: run.call_deferred()

func collect(node: Node, into: Array) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null: into.append(mi)
	for child in node.get_children(): collect(child, into)

func world_box(node: Node) -> Array:
	var all: Array = []
	collect(node, all)
	var box := AABB(); var first := true
	for m in all:
		var mi := m as MeshInstance3D
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b); first = false
	return [box, first, all.size()]

func run() -> void:
	var state = State.new()
	state.reset_blank()
	var tex_img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			tex_img.set_pixel(x, y, Color(0.85, 0.72, 0.3) if ((x / 8) +(y / 8)) % 2 == 0 else Color(0.3, 0.45, 0.2))
	var png := tex_img.save_png_to_buffer()
	var tex_id := "tex_" + preload("res://scripts/glb_codec.gd").sha256(png)
	state.custom_assets[tex_id] = { "name": "checker", "bytes": png, "category": "texture"}
	state.data["terrain_texture"] = tex_id
	state.data["terrain_tile_m"] = 40.0
	state.add_object("house", Vector2(-40, 20))
	state.add_object("technical", Vector2(-70, -50))
	state.add_object("civilian", Vector2(90, -80))
	state.add_object("terrain_hill", Vector2(150, 150))
	var rows: Array = state.data["objects"]
	rows[0]["yaw_deg"] = 35.0; rows[0]["scale"] = 1.8
	rows[1]["yaw_deg"] = -60.0; rows[1]["scale"] = 2.5
	rows[2]["pitch_deg"] = 12.0; rows[2]["roll_deg"] = -7.0; rows[2]["yaw_deg"] = 120.0
	print("BUILD objects=", rows.size())

	var library = Library.new()
	var built: Dictionary = Export.build_scene(state, library)
	var root: Node3D = built.root
	var editor := {}
	for child in root.get_children():
		var res := world_box(child)
		editor[str(child.name)] = res
		print("EDITOR %-16s meshes=%3d box=%s" % [str(child.name), res[2], str(res[0])])

	var combined: Dictionary = Export.build_combined(state, library)
	print("GLB bytes=", (combined.get("bytes", PackedByteArray()) as PackedByteArray).size())
	DirAccess.make_dir_recursive_absolute("/tmp/export_probe3")
	var f := FileAccess.open("/tmp/export_probe3/scene.glb", FileAccess.WRITE)
	f.store_buffer(combined.bytes); f.close()

	var doc := GLTFDocument.new(); var gs := GLTFState.new()
	print("REIMPORT err=", doc.append_from_buffer(combined.bytes, "", gs))
	var scene_root: Node3D = doc.generate_scene(gs, 30.0, false, false)
	print("WORST-FIRST")
	var rows_out: Array = []
	for child in scene_root.get_children():
		var name := str(child.name)
		var res := world_box(child)
		print("GLB    %-16s meshes=%3d box=%s" % [name, res[2], str(res[0])])
		if editor.has(name):
			var a: AABB = editor[name][0]
			var b: AABB = res[0]
			rows_out.append([name, (a.get_center() -b.get_center()).length(), absf(a.size.length() -b.size.length())])
	rows_out.sort_custom(func (x, y): return float(x[1]) > float(y[1]))
	for r in rows_out:
		print("DELTA  %-16s centre=%9.3f m  size=%9.3f m" % [r[0], r[1], r[2]])
	quit(0)
