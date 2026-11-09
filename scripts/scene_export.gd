extends RefCounted














const Terrain = preload("res://scripts/terrain_model.gd")
const TerrainMesh = preload("res://scripts/terrain_mesh.gd")
const Construction = preload("res://scripts/construction.gd")
const GroundBake = preload("res://scripts/ground_bake.gd")
const Paint = preload("res://scripts/terrain_paint.gd")
const Codec = preload("res://scripts/glb_codec.gd")
const TextureCodec = preload("res://scripts/texture_codec.gd")

const EXPORT_FORMAT := "reaper.scene/2"





static func scene_nodes(state) -> Array:
	var terrain: Dictionary = state.data.get("terrain", {})
	var objects: Array = state.data.get("objects", [])
	var rows: Array = []
	# The terrain already occupies a direct child named Terrain. Reserve it,
	# and reserve the generated suffixes too ("A", "A", "A 2" must all differ).
	var used_names := {"Terrain": true}
	for row in objects:
		if not row is Dictionary: continue
		var asset := str(row.get("asset", ""))
		if not _is_placeable(asset): continue
		var x := float(row.get("x", 0)); var z := float(row.get("z", 0))
		var construction: bool = asset in ["road_path", "brick_wall"]
		var feature := Terrain.is_feature(asset)
		var extra := 0.0 if feature else float(row.get("height", 0.0))
		var y := 0.0 if construction else Terrain.height_at(terrain, objects, x, z) +extra
		var pitch := 0.0 if (feature or construction) else float(row.get("pitch_deg", 0.0))
		var yaw := 0.0 if construction else float(row.get("yaw_deg", 0.0))
		var roll := 0.0 if (feature or construction) else float(row.get("roll_deg", 0.0))
		var object_scale := 1.0 if (feature or construction) else float(row.get("scale", 1.0))
		if asset == "brick_block": object_scale *= clampf(float(row.get("brick_scale", 1.0)), 0.4, 3.0)
		var basis := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), deg_to_rad(roll)), EULER_ORDER_YXZ)
		var quat := basis.get_rotation_quaternion()
		var base_name := safe_name(str(row.get("name", asset)), str(row.get("id", "")))
		var name_ := base_name
		var suffix := 2
		while used_names.has(name_):
			name_ = "%s %d" % [base_name, suffix]
			suffix += 1
		used_names[name_] = true
		rows.append({
			"id": str(row.get("id", "")),
			"name": name_,
			"asset": asset,
			"faction": str(row.get("faction", "")),
			"position": [x, y, z],
			"quaternion": [quat.x, quat.y, quat.z, quat.w],
			"rotation_deg": [pitch, yaw, roll],
			"scale": object_scale,
			"feature": feature,
			"hidden": bool(row.get("hidden", false)),
			"route": (row.get("route", []) as Array).duplicate(),
			"animation_clip": str(row.get("animation_clip", "")),
			"animation_speed": float(row.get("animation_speed", 1.0)),
			"animation_loop": bool(row.get("animation_loop", true)),
		})
	return rows

static func _is_placeable(asset: String) -> bool:
	return asset in ["road_path", "brick_wall"] or asset != ""




static func build_scene(state, library, texture_for: Callable = Callable()) -> Dictionary:
	var shell := _scene_shell(state, texture_for)
	if not bool(shell.get("ok", false)): return shell
	var root: Node3D = shell.root
	var built := _place_objects(root, shell.nodes, state.data.get("objects", []), state.data.get("terrain", {}), library, state.custom_assets)
	if not bool(built.get("ok", false)):
		root.free()
		return built
	return { "ok": true, "root": root, "objects": int(built.get("placed", 0)), "nodes": shell.nodes,
		"ground_image": shell.baked, "bounds": world_bounds(root)}


static func _scene_shell(state, texture_for: Callable = Callable(), pre_baked: Image = null) -> Dictionary:
	var terrain: Dictionary = state.data.get("terrain", {})
	var objects: Array = state.data.get("objects", [])
	if terrain.is_empty(): return { "ok": false, "error": "There is no terrain to export."}
	var root := Node3D.new()
	root.name = "REAPER_Scene"
	var ground := MeshInstance3D.new()
	ground.name = "Terrain"
	ground.mesh = TerrainMesh.build(terrain, objects)
	var ground_material := StandardMaterial3D.new()
	ground_material.vertex_color_use_as_albedo = false
	ground_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ground_material.roughness = 0.9
	ground_material.metallic = 0.0
	var baked: Image = pre_baked
	if baked == null:
		baked = GroundBake.bake(state, texture_for if texture_for.is_valid() else _fallback_texture(state))
	if baked != null:
		ground_material.albedo_texture = ImageTexture.create_from_image(baked)
		ground_material.albedo_color = Color.WHITE
	else:
		ground_material.albedo_color = GroundBake.DEFAULT_BASE_COLOUR
	ground.material_override = ground_material
	root.add_child(ground)
	return { "ok": true, "root": root, "baked": baked, "nodes": scene_nodes(state)}



static func build_scene_stepped(state, library, tick: Callable, pre_baked: Image = null) -> Dictionary:
	var shell := _scene_shell(state, Callable(), pre_baked)
	if not bool(shell.get("ok", false)): return shell
	var root: Node3D = shell.root
	var objects: Array = state.data.get("objects", [])
	var terrain: Dictionary = state.data.get("terrain", {})
	var by_id := {}
	for row in shell.nodes: by_id[str(row.id)] = row
	if tick.is_valid(): await tick.call(0, objects.size())
	var placed := 0
	var index := 0
	for row in objects:
		index += 1
		if row is Dictionary:
			var id := str(row.get("id", ""))
			if by_id.has(id):
				# Construction follows the combined terrain, including every terrain
				# feature, even though this frame places only one object.
				var one := _place_objects(root, [by_id[id]], [row], terrain, library, state.custom_assets, objects)
				if not bool(one.get("ok", false)):
					root.free()
					return one
				placed += int(one.get("placed", 0))
		if tick.is_valid() and index % 2 == 0: await tick.call(index, objects.size())
	return { "ok": true, "root": root, "objects": placed, "nodes": shell.nodes,
		"ground_image": shell.baked, "bounds": world_bounds(root)}



static func _place_objects(root: Node3D, node_rows: Array, objects: Array, terrain: Dictionary, library, assets: Dictionary, terrain_objects: Array = []) -> Dictionary:
	var by_id := {}
	for row in node_rows: by_id[str(row.id)] = row
	var context := terrain_objects if not terrain_objects.is_empty() else objects
	var placed := 0
	for row in objects:
		if not row is Dictionary: continue
		var id := str(row.get("id", ""))
		if not by_id.has(id): continue
		var node := _object_node(row, by_id[id], terrain, context, library, assets, true)
		if node == null:
			var why := ""
			if library != null: why = str(library.last_error)
			return { "ok": false, "error": "A placed model could not be loaded, so the export was stopped: " + (why if not why.is_empty() else str(row.get("asset", "")))}
		root.add_child(node)
		placed += 1
	return { "ok": true, "placed": placed}


static func texture_lookup(assets: Dictionary) -> Callable:
	return func (id: String) -> Image:
		if not assets.has(id): return null
		var record: Dictionary = assets[id]
		if str(record.get("category", "model")) != "texture": return null
		var tex := TextureCodec.texture(record.get("bytes", PackedByteArray()))
		if tex == null: return null
		var image: Image = tex.get_image()
		if image == null: return null
		if image.get_format() != Image.FORMAT_RGB8:
			image = image.duplicate(); image.convert(Image.FORMAT_RGB8)
		return image

# Worker-safe texture lookup: decode a private CPU Image, without creating or
# reading an ImageTexture on the rendering server from the bake thread.
static func cpu_texture_lookup(assets: Dictionary) -> Callable:
	return func (id: String) -> Image:
		if not assets.has(id): return null
		var record: Dictionary = assets[id]
		if str(record.get("category", "model")) != "texture": return null
		var bytes: PackedByteArray = record.get("bytes", PackedByteArray())
		var valid := TextureCodec.validate(bytes)
		if not valid.ok: return null
		var image := Image.new()
		var error := image.load_png_from_buffer(bytes) if str(valid.format) == "png" else image.load_jpg_from_buffer(bytes)
		if error != OK or image.is_empty(): return null
		if image.get_format() != Image.FORMAT_RGB8: image.convert(Image.FORMAT_RGB8)
		return image

static func _fallback_texture(state) -> Callable:
	return texture_lookup(state.custom_assets)

static func _object_node(row: Dictionary, placed: Dictionary, terrain: Dictionary, objects: Array, library, assets: Dictionary, strict := false) -> Node3D:
	var asset := str(row.get("asset", ""))
	var node: Node3D = null
	if asset in ["road_path", "brick_wall"]:
		node = Construction.build(row, terrain, objects)
	else:
		node = library.create_visual(asset, assets, strict)
	if node == null: return null
	node.name = str(placed.name)
	node.set_meta("reaper_asset", asset)
	node.set_meta("reaper_id", str(row.get("id", "")))
	node.set_meta("reaper_faction", str(row.get("faction", "")))
	var p: Array = placed.position
	node.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	var q: Array = placed.quaternion
	node.quaternion = Quaternion(float(q[0]), float(q[1]), float(q[2]), float(q[3]))
	node.scale = Vector3.ONE * float(placed.scale)
	node.visible = not bool(placed.hidden)
	_name_parts(node)
	return node




static func _name_parts(node: Node) -> void:
	var index := 0
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var part := child as Node3D
		if part == null: continue
		index += 1
		var current := str(part.name)
		if current.begins_with("_") or current.begins_with("@") or current.is_empty():
			part.name = "Part %02d" % index

static func safe_name(label: String, fallback: String) -> String:
	var out := ""
	for i in label.length():
		var c := label[i]
		if c == "/" or c == "\\" or c == ":" or c == "@" or c == "%" or c == "\"": out += "-"
		else: out += c
	out = out.strip_edges()
	if out.is_empty(): out = fallback
	if out.is_empty(): out = "Object"
	return out.substr(0, 60)




static func local_to_root(node: Node3D) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current is Node3D:
		transform = (current as Node3D).transform * transform
		current = current.get_parent()
	return transform


static func world_bounds(node: Node3D) -> AABB:
	var box := AABB(); var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null: continue
		var b: AABB = local_to_root(mi) * mi.get_aabb()
		box = b if first else box.merge(b); first = false
	return box




static func build_combined(state, library) -> Dictionary:
	var built := build_scene(state, library)
	if not bool(built.ok): return built
	var root: Node3D = built.root
	var doc := GLTFDocument.new()
	var gltf_state := GLTFState.new()
	var error := doc.append_from_scene(root, gltf_state)
	if error != OK:
		root.free()
		return { "ok": false, "error": "The scene could not be converted to glTF (code %s)." % str(error)}
	var bytes := doc.generate_buffer(gltf_state)
	root.free()
	# The verification import is a second scene parse; release the export state
	# first so large meshes and temporary PNG buffers are not held twice.
	gltf_state = null
	doc = null
	if bytes.is_empty():
		return { "ok": false, "error": "The scene produced an empty GLB."}
	var check := verify_glb(bytes, built.nodes)
	if not bool(check.ok):
		return { "ok": false, "error": str(check.error), "bytes": bytes}
	return { "ok": true, "bytes": bytes, "objects": int(built.objects), "nodes": built.nodes,
		"warning": "", "worst_placement_m": float(check.worst_placement_m), "ground_image": built.ground_image}



static func build_combined_stepped(state, library, tick: Callable) -> Dictionary:
	var built: Dictionary = await build_scene_stepped(state, library, tick)
	if not bool(built.get("ok", false)): return built
	var root: Node3D = built.root
	if tick.is_valid(): await tick.call(int(built.get("objects", 0)), int(built.get("objects", 0)), "Converting the scene to glTF...")
	var doc := GLTFDocument.new()
	var gltf_state := GLTFState.new()
	var error := doc.append_from_scene(root, gltf_state)
	if error != OK:
		root.free()
		return { "ok": false, "error": "The scene could not be converted to glTF (code %s)." % str(error)}
	if tick.is_valid(): await tick.call(int(built.get("objects", 0)), int(built.get("objects", 0)), "Packing the scene file...")
	var bytes := doc.generate_buffer(gltf_state)
	root.free()
	# The verification import is a second scene parse; release the export state
	# first so large meshes and temporary PNG buffers are not held twice.
	gltf_state = null
	doc = null
	if bytes.is_empty():
		return { "ok": false, "error": "The scene produced an empty GLB."}
	if tick.is_valid(): await tick.call(int(built.get("objects", 0)), int(built.get("objects", 0)), "Checking the export...")
	var check := verify_glb(bytes, built.nodes)
	if not bool(check.ok):
		return { "ok": false, "error": str(check.error), "bytes": bytes}
	return { "ok": true, "bytes": bytes, "objects": int(built.objects), "nodes": built.nodes,
		"warning": "", "worst_placement_m": float(check.worst_placement_m), "ground_image": built.ground_image}





static func verify_glb(bytes: PackedByteArray, expected: Array) -> Dictionary:
	var doc := GLTFDocument.new(); var gs := GLTFState.new()
	# Check the round-tripped nodes and geometry without decompressing every
	# embedded image a second time. The original images remain in the GLB; the
	# final mission package hashes its bytes and verifies them on read.
	gs.handle_binary_image_mode = GLTFState.HANDLE_BINARY_IMAGE_MODE_DISCARD_TEXTURES
	var error := doc.append_from_buffer(bytes, "", gs)
	if error != OK: return { "ok": false, "error": "The exported .glb could not be read back (code %s)." % str(error)}
	var scene_root: Node3D = doc.generate_scene(gs, 30.0, false, false)
	if scene_root == null: return { "ok": false, "error": "The exported .glb produced no scene."}
	var found := {}
	for node in scene_root.find_children("*", "Node3D", true, false):
		var n3 := node as Node3D
		found[str(n3.name)] = n3
	var worst := 0.0
	var worst_name := ""
	var missing: Array = []
	for row in expected:
		var name_ := str(row.name)
		if not found.has(name_): missing.append(name_); continue
		var want := Vector3(float(row.position[0]), float(row.position[1]), float(row.position[2]))
		var got: Vector3 = (found[name_] as Node3D).position
		var d := (want - got).length()
		if d > worst: worst = d; worst_name = name_
	var scene_root_free := scene_root
	scene_root_free.free()
	if not missing.is_empty():
		return { "ok": false, "error": "The exported .glb is missing %d object(s): %s" % [missing.size(), ", ".join(missing.slice(0, 4))]}
	if worst > 0.001:
		return { "ok": false, "error": "An object moved during export (%s by %.3f m)." % [worst_name, worst], "worst_placement_m": worst}
	return { "ok": true, "error": "", "worst_placement_m": worst, "checked": expected.size()}



static func manifest_rows(state, serialized_nodes: Variant = null) -> Array:
	var rows: Array = []; var index := 1
	var source: Array = serialized_nodes if serialized_nodes is Array else scene_nodes(state)
	for row: Dictionary in source:
		rows.append({
			"index": index, "id": str(row.id), "name": str(row.name), "asset": str(row.asset),
			"x_m": round(float(row.position[0]) * 1000.0) / 1000.0,
			"y_m": round(float(row.position[1]) * 1000.0) / 1000.0,
			"z_m": round(float(row.position[2]) * 1000.0) / 1000.0,
			"yaw_deg": round(float(row.rotation_deg[1]) * 100.0) / 100.0,
			"pitch_deg": round(float(row.rotation_deg[0]) * 100.0) / 100.0,
			"roll_deg": round(float(row.rotation_deg[2]) * 100.0) / 100.0,
			"scale": round(float(row.scale) * 1000.0) / 1000.0,
			"faction": str(row.faction), "route_points": (row.route as Array).size(),
			"hidden": bool(row.hidden), "animation_clip": str(row.animation_clip),
		})
		index += 1
	return rows

static func manifest_csv(state, serialized_nodes: Variant = null) -> String:
	var cols := ["index", "id", "name", "asset", "x_m", "y_m", "z_m", "yaw_deg", "pitch_deg", "roll_deg", "scale", "faction", "route_points", "hidden", "animation_clip"]
	var lines: Array = [",".join(cols)]
	for row: Dictionary in manifest_rows(state, serialized_nodes):
		var cells: Array = []
		for c in cols:
			var value = str(row[c])
			if value.contains(",") or value.contains("\""):
				value = "\"" + value.replace("\"", "\"\"") +"\""
			cells.append(value)
		lines.append(",".join(cells))
	return "\n".join(lines) +"\n"





static func scene_block(state, fidelity: Dictionary = {}) -> Dictionary:
	var terrain: Dictionary = state.data.get("terrain", {})
	var heights: Array = terrain.get("heights", [])
	var map := GroundBake.settings(state)
	var layers: Array = []
	for id in map.layers: layers.append(str(id))
	var payload := {
		"format": EXPORT_FORMAT,
		"generator": "REAPER Mission Creator",
		"axes": "X east, Y up, Z south. Yaw degrees clockwise from -Z. Metres.",
		"terrain": {
			"resolution": int(terrain.get("resolution", 65)),
			"extent_m": round(float(terrain.get("extent", 0.0)) * 100.0) / 100.0,
			"width_m": round(Terrain.width_m(terrain) * 100.0) / 100.0,
			"cell_m": round(Terrain.cell_size(terrain) * 1000.0) / 1000.0,
			"heights": heights,
			"heights_sha256": Codec.heights_checksum(heights),
		},
		"ground": {
			"base_texture": str(map.get("base_id", "")),
			"tile_m": float(map.get("tile_m", 80.0)),
			"paint_layers": layers,
			"paint_mask": _mask_sha(state.paint_image() if map.get("mask", null) != null else null),
			"snow_mask": _mask_sha(map.get("snow_mask", null)),
			"snow_cover": float(map.get("snow_cover", 0.0)),
			"wet": float(map.get("wet", 0.0)),
			"default_base_colour": GroundBake.DEFAULT_BASE_COLOUR.to_html(false),
		},
		"environment": state.data.get("environment", {}),
		"mission": {
			"name": str(state.data.get("name", "")),
			"region": str(state.data.get("region", "")),
			"briefing": str(state.data.get("briefing", "")),
			"objectives": state.data.get("objectives", []),
			"recon_target": str(state.data.get("recon_target", "")),
			"start_hour": int(state.data.get("start_hour", 10)),
			"start_minute": int(state.data.get("start_minute", 0)),
		},
		"nodes": scene_nodes(state),
		"fidelity": fidelity,
	}
	return payload

static func _mask_sha(image: Image) -> String:
	if image == null: return ""
	return Codec.sha256(image.save_png_to_buffer())

static func manifest_json(state, fidelity: Dictionary = {}, serialized_nodes: Variant = null) -> String:
	var block: Dictionary = scene_block(state, fidelity)
	if serialized_nodes is Array: block["nodes"] = serialized_nodes
	var text := JSON.stringify(block, "  ", false)
	var heights: Array = block.get("terrain", {}).get("heights", [])
	if heights.size() > 0:
		var chunks := PackedStringArray()
		var line := PackedStringArray()
		for value in heights:
			line.append(str(value))
			if line.size() == 16:
				chunks.append("      " + ", ".join(line))
				line = PackedStringArray()
		if line.size() > 0: chunks.append("      " + ", ".join(line))
		text = text.replace(JSON.stringify(heights, "  ", false), "[" + "\n" + ",\n".join(chunks) +"\n    ]")
	return text







static func godot_project_godot(state) -> String:
	return "; Engine configuration file for the exported REAPER scene.\n; Open this folder in Godot 4, then press F5 (or F6 from main.tscn).\nconfig_version=5\n\n[application]\n\nconfig/name=\"%s\"\nrun/main_scene=\"res://main.tscn\"\nconfig/features=PackedStringArray(\"4.7\", \"Forward Plus\")\n\n[rendering]\n\nrenderer/rendering_method=\"forward_plus\"\nrenderer/rendering_method.mobile=\"mobile\"\nanti_aliasing/quality/msaa_3d=2\nenvironment/defaults/default_clear_color=Color(0.55, 0.66, 0.78, 1)\n" % safe_name(str(state.data.get("name", "REAPER Export")), "REAPER Export")
















static func godot_main_tscn(state) -> String:
	var hour := float(state.data.get("environment", {}).get("hour", 10.0))
	return "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"res://reaper_scene_loader.gd\" id=\"1_loader\"]\n\n[node name=\"REAPER_Scene\" type=\"Node3D\"]\nscript = ExtResource(\"1_loader\")\n\n[node name=\"Sun\" type=\"DirectionalLight3D\" parent=\".\"]\nrotation_degrees = Vector3(-52, 34, 0)\nlight_energy = 1.25\nshadow_enabled = true\n\n[node name=\"Camera3D\" type=\"Camera3D\" parent=\".\"]\nfov = 65.0\nnear = 0.5\nfar = 20000.0\n\n[node name=\"WorldEnvironment\" type=\"WorldEnvironment\" parent=\".\"]\n"





















static func godot_loader_gd(state) -> String:
	var hour := float(state.data.get("environment", {}).get("hour", 10.0))
	var fog := clampf(float(state.data.get("environment", {}).get("fog", 0.12)), 0.0, 1.0)
	var cloud := clampf(float(state.data.get("environment", {}).get("cloud", 0.1)), 0.0, 1.0)
	var text := "extends Node3D\n## REAPER scene loader — reads scene.glb at runtime, so the project opens and plays\n## even before Godot has imported the model. No scripts, assets or paths from the\n## mission are executed; only geometry, materials and textures are read.\nconst SCENE_PATH := \"res://scene.glb\"\nconst SUN_HOUR := __SUN_HOUR__\nconst FOG := __FOG__\nconst CLOUD := __CLOUD__\n\nfunc _ready() -> void:\n\tvar imported := _load_glb(SCENE_PATH)\n\tif imported == null:\n\t\tpush_error(\"REAPER: %s could not be read.\" % SCENE_PATH)\n\t\treturn\n\timported.name = \"ImportedScene\"\n\tadd_child(imported)\n\t_lighting()\n\t_frame_camera(imported)\n\nfunc _load_glb(path: String) -> Node3D:\n\tvar file := FileAccess.open(path, FileAccess.READ)\n\tif file == null:\n\t\treturn null\n\tvar bytes := file.get_buffer(file.get_length())\n\tfile.close()\n\tvar doc := GLTFDocument.new()\n\tvar state := GLTFState.new()\n\tif doc.append_from_buffer(bytes, \"\", state) != OK:\n\t\treturn null\n\treturn doc.generate_scene(state, 30.0, false, false)\n\nfunc _lighting() -> void:\n\tvar sun := get_node_or_null(\"Sun\") as DirectionalLight3D\n\t# The mission's own hour drives the sun angle, exactly as in the creator.\n\tvar elevation := clampf(sin((SUN_HOUR - 6.0) / 12.0 * PI), -1.0, 1.0) * 62.0\n\tif sun != null:\n\t\tsun.rotation_degrees = Vector3(-maxf(4.0, elevation), 34.0, 0.0)\n\t\tsun.light_energy = lerpf(0.25, 1.3, clampf((elevation + 10.0) / 70.0, 0.0, 1.0))\n\tvar world := get_node_or_null(\"WorldEnvironment\") as WorldEnvironment\n\tif world == null:\n\t\treturn\n\tvar env := Environment.new()\n\tenv.background_mode = Environment.BG_SKY\n\tvar sky := Sky.new()\n\tvar material := ProceduralSkyMaterial.new()\n\tmaterial.sky_top_color = Color(0.32, 0.48, 0.72).lerp(Color(0.05, 0.06, 0.12), 1.0 - clampf((elevation + 8.0) / 40.0, 0.0, 1.0))\n\tmaterial.sky_horizon_color = Color(0.72, 0.78, 0.86).lerp(Color(0.12, 0.14, 0.2), 1.0 - clampf((elevation + 8.0) / 40.0, 0.0, 1.0))\n\tsky.sky_material = material\n\tenv.sky = sky\n\tenv.ambient_light_source = Environment.AMBIENT_SOURCE_SKY\n\tenv.ambient_light_sky_contribution = 0.55\n\tenv.fog_enabled = FOG > 0.001\n\tenv.fog_light_color = Color(0.72, 0.76, 0.8)\n\tenv.fog_density = 0.00015 + 0.004 * FOG\n\tenv.fog_sky_affect = 0.35\n\tenv.volumetric_fog_enabled = false\n\tworld.environment = env\n\nfunc _frame_camera(root: Node3D) -> void:\n\tvar camera := get_node_or_null(\"Camera3D\") as Camera3D\n\tif camera == null:\n\t\treturn\n\tvar box := AABB()\n\tvar first := true\n\tfor mesh in root.find_children(\"*\", \"MeshInstance3D\", true, false):\n\t\tvar instance := mesh as MeshInstance3D\n\t\tif instance.mesh == null:\n\t\t\tcontinue\n\t\tvar b: AABB = instance.global_transform * instance.get_aabb()\n\t\tbox = b if first else box.merge(b)\n\t\tfirst = false\n\tif first:\n\t\tcamera.position = Vector3(0, 120, 240)\n\t\tcamera.look_at(Vector3.ZERO, Vector3.UP)\n\t\treturn\n\tvar centre := box.get_center()\n\tvar radius := maxf(20.0, box.size.length() * 0.5)\n\t# Keep the framed scene inside a 65 degree vertical field of view.\n\tvar distance := radius / tan(deg_to_rad(32.5)) * 0.9\n\tvar direction := Vector3(0.55, 0.62, 0.75).normalized()\n\tcamera.position = centre + direction * distance\n\tcamera.look_at(centre, Vector3.UP)\n\tcamera.far = maxf(2000.0, distance * 4.0)\n\tprint(\"REAPER scene: %d objects, ground %.1f x %.1f m, camera %.0f m out\" % [\n\t\troot.get_child_count(), box.size.x, box.size.z, distance])\n"





















































































	return text.replace("__SUN_HOUR__", "%.3f" % hour).replace("__FOG__", "%.4f" % fog).replace("__CLOUD__", "%.4f" % cloud)


static func unity_loader_cs() -> String:
	return "// REAPER scene loader for Unity.\n// 1. Install the free \"glTFast\" package (com.unity.cloud.gltfast) or UnityGLTF.\n// 2. Put scene.glb and manifest.json in Assets/ReaperExport/.\n// 3. Add this component to an empty GameObject and press Play.\n// The .glb already holds every object, so this loader only reads the mission\n// metadata for your own scripts.\nusing System.IO;\nusing UnityEngine;\n\npublic class ReaperSceneLoader : MonoBehaviour\n{\n    public string glbFileName = \"scene.glb\";\n    public string manifestFileName = \"manifest.json\";\n\n    [System.Serializable]\n    public class TerrainInfo { public float width_m; public float cell_m; public int resolution; }\n\n    [System.Serializable]\n    public class SceneManifest { public string format; public TerrainInfo terrain; }\n\n    public SceneManifest Manifest { get; private set; }\n\n    void Start()\n    {\n        string dir = Path.Combine(Application.dataPath, \"ReaperExport\");\n        LoadManifest(Path.Combine(dir, manifestFileName));\n    }\n\n    void LoadManifest(string path)\n    {\n        if (!File.Exists(path)) { Debug.LogWarning(\"REAPER: no manifest at \" + path); return; }\n        Manifest = JsonUtility.FromJson<SceneManifest>(File.ReadAllText(path));\n        Debug.Log(\"REAPER scene: \" + Manifest.terrain.width_m + \" m across, grid \" + Manifest.terrain.resolution);\n    }\n}\n"




































static func readme_text(state, fidelity: Dictionary = {}) -> String:
	var terrain: Dictionary = state.data.get("terrain", {})
	var width_km := Terrain.width_m(terrain) / 1000.0
	return "REAPER MISSION CREATOR - 3D EXPORT\n=================================\nScene: %s\nGround: %.2f km across, grid %d (%d cells of %.1f m)\nObjects: %d\nExport check: %s\n\nWHAT IS IN THIS FOLDER\n----------------------\nscene.glb                 the whole scene in one binary glTF 2.0 file: terrain mesh,\n                          ground colours baked in, every placed object as its own node\nmanifest.csv              every object: id, name, asset, position, yaw/pitch/roll, scale\nmanifest.json             the same data plus the terrain grid, ground surface, light and\n                          weather, and every object's resolved world transform\nproject.godot             a ready Godot 4 project\nmain.tscn                 opens the scene: sun, sky, camera framed on the ground\nreaper_scene_loader.gd    loads scene.glb at runtime, so the project plays immediately\n\nGODOT 4\n-------\nOpen this folder in Godot (Import), then press F5. main.tscn does not need the .glb\nto have been imported first: it reads the file at run time. If you prefer the model\nas an editor asset, drag scene.glb into the FileSystem dock and Godot imports it.\nEvery object arrives as its own node named exactly as in the manifest.\n\nBLENDER\n-------\nFile > Import > glTF 2.0, choose scene.glb. Objects arrive as separate nodes; the\nground is one mesh with its colours baked into a texture.\n\nUNITY\n-----\nUnity cannot read .glb on its own. Install the free glTFast or UnityGLTF package,\nthen either drop scene.glb into the scene or copy ReaperSceneLoader.cs into Assets.\n\nUNREAL / THREE.JS / WINDOWS 3D VIEWER\n-------------------------------------\nscene.glb is standard glTF 2.0 binary and opens directly.\n\nAXES\n----\nX is east, Z is south, Y is up - the same convention the creator uses. Yaw, pitch\nand roll are degrees, applied YXZ. All distances are metres.\n\nGROUND COLOURS\n--------------\nThe creator blends a tiled ground texture with up to four painted layers. A .glb\ncannot carry that blend, so the export bakes the exact same result into one colour\ntexture on the terrain mesh. The .rmission keeps the raw layers and mask, so the\ngame can reproduce it natively.\n\n%%\n" % [str(state.data.get("name", "Untitled")), width_km,



















































		int(terrain.get("resolution", 65)), int(terrain.get("resolution", 65)) -1,
		Terrain.cell_size(terrain), state.data.get("objects", []).size(),
		_verify_line(fidelity)]

static func _verify_line(fidelity: Dictionary) -> String:
	if fidelity.is_empty(): return "not run"
	if not bool(fidelity.get("ok", false)): return "FAILED: " + str(fidelity.get("error", "unknown"))
	return "%d objects placed to within %.4f m of the editor, ground colours baked" % [
		int(fidelity.get("objects", 0)), float(fidelity.get("worst_placement_m", 0.0))]

static func pack_summary(state) -> String:
	return "REAPER 3D export - %d object(s), ground %.2f km, grid %d.\nOpen README.txt first.\n" % [
		scene_nodes(state).size(), Terrain.width_m(state.data.get("terrain", {})) / 1000.0,
		int(state.data.get("terrain", {}).get("resolution", 65))]





static func build_pack_stepped(state, library, tick: Callable) -> Dictionary:
	var combined: Dictionary = await build_combined_stepped(state, library, tick)
	if not bool(combined.get("ok", false)): return combined
	if tick.is_valid(): await tick.call(int(combined.get("objects", 0)), int(combined.get("objects", 0)), "Writing the archive...")
	return _pack_from_combined(state, combined)

static func build_pack(state, library) -> Dictionary:
	var combined := build_combined(state, library)
	if not bool(combined.ok): return combined
	return _pack_from_combined(state, combined)



static func _pack_from_combined(state, combined: Dictionary) -> Dictionary:
	var fidelity := {
		"ok": true, "objects": int(combined.objects),
		"worst_placement_m": float(combined.get("worst_placement_m", 0.0)),
		"ground_baked": combined.get("ground_image", null) != null,
		"ground_texture_size": (combined.ground_image as Image).get_width() if combined.get("ground_image", null) != null else 0,
		"checked_utc": Time.get_datetime_string_from_system(true),
	}
	var files: Array = []
	var writer := ZIPPacker.new()
	var temp := "user://reaper_export_%d.zip" % Time.get_ticks_usec()
	if writer.open(temp) != OK: return { "ok": false, "error": "Could not start the export archive."}
	var entries := {
		"REAPER_3D_Export/scene.glb": combined.bytes,
		"REAPER_3D_Export/manifest.csv": manifest_csv(state, combined.get("nodes", null)).to_utf8_buffer(),
		"REAPER_3D_Export/manifest.json": manifest_json(state, fidelity, combined.get("nodes", null)).to_utf8_buffer(),
		"REAPER_3D_Export/README.txt": readme_text(state, fidelity).to_utf8_buffer(),
		"REAPER_3D_Export/project.godot": godot_project_godot(state).to_utf8_buffer(),
		"REAPER_3D_Export/main.tscn": godot_main_tscn(state).to_utf8_buffer(),
		"REAPER_3D_Export/reaper_scene_loader.gd": godot_loader_gd(state).to_utf8_buffer(),
		"REAPER_3D_Export/unity/ReaperSceneLoader.cs": unity_loader_cs().to_utf8_buffer(),
		"REAPER_3D_Export/manifest.txt": pack_summary(state).to_utf8_buffer(),
	}
	for name in entries.keys():
		var data: PackedByteArray = entries[name]
		if data.is_empty(): continue
		if writer.start_file(str(name)) != OK: continue
		writer.write_file(data)
		writer.close_file()
		files.append(str(name))
	writer.close()
	var bytes := FileAccess.get_file_as_bytes(temp)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
	if bytes.is_empty(): return { "ok": false, "error": "The export archive came back empty."}
	return { "ok": true, "bytes": bytes, "files": files, "objects": int(combined.objects), "fidelity": fidelity}
