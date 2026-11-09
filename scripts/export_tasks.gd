extends RefCounted
## Background export operations. UI and the active scene tree are never touched
## here. The detached export tree is handed exclusively to encode_detached;
## the main thread waits for the worker before freeing or using it again.
const GroundBake = preload("res://scripts/ground_bake.gd")
const Exporter = preload("res://scripts/scene_export.gd")
const Store = preload("res://scripts/draft_store.gd")
const Platform = preload("res://scripts/platform_files.gd")
const SceneCheck = preload("res://scripts/glb_scene_check.gd")

static func bake(snapshot, channel) -> Dictionary:
	channel.report(3.0, "Preparing the ground texture")
	var image: Image = GroundBake.bake(snapshot, Exporter.cpu_texture_lookup(snapshot.custom_assets), GroundBake.BAKE_SIZE, Callable(channel, "bake_tick"))
	if image == null or image.is_empty(): return {"ok": false, "error": "The ground texture could not be baked."}
	channel.report(22.0, "Ground texture ready")
	return {"ok": true, "image": image}

static func encode_detached(root: Node3D, nodes: Array, channel) -> Dictionary:
	if root == null or root.is_inside_tree():
		return {"ok": false, "error": "The export scene is not safely detached."}
	channel.report(45.0, "Converting scene to glTF · this stage may take a while")
	var doc := GLTFDocument.new()
	var gs := GLTFState.new()
	var error := doc.append_from_scene(root, gs)
	if error != OK: return {"ok": false, "error": "The scene could not be converted to glTF (code %s)." % str(error)}
	channel.report(54.0, "Packing the scene GLB · this stage may take a while")
	var bytes := doc.generate_buffer(gs)
	gs = null
	doc = null
	if bytes.is_empty(): return {"ok": false, "error": "The scene produced an empty GLB."}
	# Godot can emit a final BIN chunk whose length is not four-byte aligned
	# (for example, a triangle with 16-bit indices). Pad that final chunk as
	# required by glTF 2.0, preserving the JSON buffer's original byteLength.
	var aligned := _align_final_bin(bytes)
	if not bool(aligned.get("ok", false)): return aligned
	bytes = aligned.bytes
	channel.report(62.0, "Checking scene structure and object positions")
	var checked := SceneCheck.verify(bytes, nodes, true)
	if not bool(checked.get("ok", false)): return checked
	channel.report(66.0, "Scene verified")
	return {"ok": true, "bytes": bytes, "nodes": checked.nodes, "worst_placement_m": float(checked.get("worst_placement_m", 0.0))}

static func _align_final_bin(bytes: PackedByteArray) -> Dictionary:
	var padding := (4 - bytes.size() % 4) % 4
	if padding == 0: return {"ok": true, "bytes": bytes}
	if bytes.size() < 20 or bytes.slice(0, 4).get_string_from_ascii() != "glTF":
		return {"ok": false, "error": "The scene GLB header is invalid."}
	var at := 12
	while at + 8 <= bytes.size():
		var length := int(bytes.decode_u32(at))
		var end := at + 8 + length
		if length < 0 or end > bytes.size(): break
		if end == bytes.size() and bytes.decode_u32(at + 4) == 5130562:
			var previous := bytes.size()
			bytes.resize(previous + padding)
			for i in range(previous, bytes.size()): bytes[i] = 0
			bytes.encode_u32(8, bytes.size())
			bytes.encode_u32(at, length + padding)
			return {"ok": true, "bytes": bytes}
		at = end
	return {"ok": false, "error": "The scene GLB has an incomplete final binary chunk."}

static func save(kind: String, path: String, snapshot, combined: Dictionary, channel) -> Dictionary:
	if kind == "mission":
		channel.report(67.0, "Preparing mission metadata")
		var fidelity := {
			"ok": true,
			"objects": int(combined.get("objects", 0)),
			"worst_placement_m": float(combined.get("worst_placement_m", 0.0)),
			"glb_bytes": (combined.get("bytes", PackedByteArray()) as PackedByteArray).size(),
			"checked_utc": Time.get_datetime_string_from_system(true),
		}
		var block := Exporter.scene_block(snapshot, fidelity)
		# Names are the serialized direct-child names, including any glTF rename.
		block["nodes"] = combined.nodes
		return Store.save_mission_package(path, snapshot.data, snapshot.custom_assets,
			combined.bytes, block, true, Callable(channel, "store_tick"))
	if kind == "pack":
		channel.report(68.0, "Compressing the 3D archive · this stage may take a while")
		var packed := Exporter._pack_from_combined(snapshot, combined)
		if not bool(packed.get("ok", false)): return packed
		channel.report(75.0, "Writing the 3D archive")
		var written := Platform.write_document_parts(path, [packed.bytes], Callable(channel, "write_tick"))
		if not bool(written.get("ok", false)): return written
		return {"ok": true, "path": path, "objects": int(combined.objects), "bytes": (packed.bytes as PackedByteArray).size()}
	if kind == "glb":
		channel.report(75.0, "Writing the scene GLB")
		var written := Platform.write_document_parts(path, [combined.bytes], Callable(channel, "write_tick"))
		if not bool(written.get("ok", false)): return written
		return {"ok": true, "path": path, "objects": int(combined.objects), "bytes": (combined.bytes as PackedByteArray).size()}
	return {"ok": false, "error": "Unknown export format."}
