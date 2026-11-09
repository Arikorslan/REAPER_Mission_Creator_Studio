extends RefCounted
## CPU-only structural and placement check for a freshly exported GLB.
## It runs on the export worker; it does not instantiate render nodes or touch
## the active scene tree. The normal Store.verify_package() still supports a
## full Godot GLTFDocument re-import when called without fast verification.

const MAX_JSON_BYTES := 8 * 1024 * 1024
const JSON_KIND := 1313821514
const BIN_KIND := 5130562

static func verify(bytes: PackedByteArray, expected: Array, reconcile_names: bool = false) -> Dictionary:
	if bytes.size() < 28 or bytes.slice(0, 4).get_string_from_ascii() != "glTF":
		return {"ok": false, "error": "The exported scene has no valid GLB header."}
	if bytes.decode_u32(4) != 2 or int(bytes.decode_u32(8)) != bytes.size():
		return {"ok": false, "error": "The exported GLB version or length is invalid."}
	var at := 12
	var json_data := PackedByteArray()
	var bin_size := -1
	while at + 8 <= bytes.size():
		var length := int(bytes.decode_u32(at))
		var kind := int(bytes.decode_u32(at + 4))
		if length < 0 or length % 4 != 0 or at + 8 + length > bytes.size():
			return {"ok": false, "error": "An exported GLB chunk is truncated or misaligned (offset %d, length %d, file %d)." % [at, length, bytes.size()]}
		if kind == JSON_KIND:
			if not json_data.is_empty() or length < 2 or length > MAX_JSON_BYTES:
				return {"ok": false, "error": "The exported GLB scene description is invalid."}
			json_data = bytes.slice(at + 8, at + 8 + length)
		elif kind == BIN_KIND:
			if bin_size >= 0: return {"ok": false, "error": "The exported GLB has multiple binary chunks."}
			bin_size = length
		at += 8 + length
	if at != bytes.size() or json_data.is_empty():
		return {"ok": false, "error": "The exported GLB chunk table is incomplete."}
	var doc = JSON.parse_string(json_data.get_string_from_utf8())
	if not doc is Dictionary or not doc.get("asset", {}) is Dictionary:
		return {"ok": false, "error": "The exported GLB scene description is unreadable."}
	if str(doc.asset.get("version", "")) != "2.0":
		return {"ok": false, "error": "The exported scene is not glTF 2.0."}
	var buffers = doc.get("buffers", [])
	var views = doc.get("bufferViews", [])
	if not buffers is Array or buffers.size() != 1 or not buffers[0] is Dictionary:
		return {"ok": false, "error": "The scene has an unsupported binary buffer."}
	var declared := int(buffers[0].get("byteLength", -1))
	if buffers[0].has("uri") or declared < 0 or bin_size < 0 or declared > bin_size:
		return {"ok": false, "error": "The scene's binary buffer is incomplete or external."}
	if not views is Array: return {"ok": false, "error": "The scene's buffer view list is invalid."}
	for view in views:
		if not view is Dictionary or int(view.get("buffer", 0)) != 0:
			return {"ok": false, "error": "The scene references an invalid buffer."}
		var offset := int(view.get("byteOffset", 0))
		var count := int(view.get("byteLength", -1))
		if offset < 0 or count < 0 or offset + count > declared:
			return {"ok": false, "error": "The scene references data outside its binary buffer."}
	var nodes = doc.get("nodes", [])
	var scenes = doc.get("scenes", [])
	if not nodes is Array or not scenes is Array or scenes.is_empty():
		return {"ok": false, "error": "The scene has no valid node tree."}
	var scene_index := int(doc.get("scene", 0))
	if scene_index < 0 or scene_index >= scenes.size() or not scenes[scene_index] is Dictionary:
		return {"ok": false, "error": "The exported scene index is invalid."}
	var roots = scenes[scene_index].get("nodes", [])
	if not roots is Array: return {"ok": false, "error": "The exported root nodes are invalid."}
	var pending: Array = roots.duplicate()
	var visited := {}
	var named := {}
	while not pending.is_empty():
		var index := int(pending.pop_back())
		if index < 0 or index >= nodes.size() or not nodes[index] is Dictionary:
			return {"ok": false, "error": "The scene contains an invalid node reference."}
		if visited.has(index): continue
		visited[index] = true
		var node: Dictionary = nodes[index]
		var label := str(node.get("name", ""))
		if not label.is_empty() and not named.has(label): named[label] = node
		var children = node.get("children", [])
		if not children is Array: return {"ok": false, "error": "A scene node has invalid children."}
		for child in children: pending.append(child)
	# The Creator writes Terrain first and authored objects afterward, in order.
	# glTF may globally rename a direct child if an earlier nested mesh used the
	# same name. During the first check, reconcile names by this known order and
	# return the actual GLB names for the mission/ZIP manifests. Later rechecks
	# are strict by direct-child name, never by a matching nested mesh.
	var direct_nodes: Array = []
	var found_root := false
	for root_index in roots:
		var ri := int(root_index)
		if ri < 0 or ri >= nodes.size() or not nodes[ri] is Dictionary: continue
		var root_node: Dictionary = nodes[ri]
		if str(root_node.get("name", "")) != "REAPER_Scene": continue
		found_root = true
		for child_index in root_node.get("children", []):
			var ci := int(child_index)
			if ci < 0 or ci >= nodes.size() or not nodes[ci] is Dictionary:
				return {"ok": false, "error": "The exported root has an invalid child."}
			direct_nodes.append(nodes[ci])
		break
	if not found_root or direct_nodes.is_empty() or str(direct_nodes[0].get("name", "")) != "Terrain":
		return {"ok": false, "error": "The exported scene has no recognized terrain root."}
	direct_nodes.remove_at(0)
	if direct_nodes.size() != expected.size():
		return {"ok": false, "error": "The exported scene has a different number of placed objects."}
	var direct := {}
	for node in direct_nodes:
		var label := str(node.get("name", ""))
		if label.is_empty() or label == "Terrain" or direct.has(label):
			return {"ok": false, "error": "The exported scene contains ambiguous object names."}
		direct[label] = node
	var missing: Array = []
	var resolved: Array = []
	var matched := {}
	var worst := 0.0
	var worst_name := ""
	for i in expected.size():
		var row = expected[i]
		if not row is Dictionary or not row.get("position", []) is Array or row.position.size() != 3:
			return {"ok": false, "error": "The expected placement data is invalid."}
		var name_ := str(direct_nodes[i].get("name", "")) if reconcile_names else str(row.get("name", ""))
		if not direct.has(name_): missing.append(name_); continue
		if matched.has(name_):
			return {"ok": false, "error": "The expected scene has duplicate object names."}
		matched[name_] = true
		var updated: Dictionary = row.duplicate(true)
		updated["name"] = name_
		resolved.append(updated)
		var node: Dictionary = direct[name_]
		var translation = node.get("translation", [0.0, 0.0, 0.0])
		if node.has("matrix"):
			var matrix = node.matrix
			if not matrix is Array or matrix.size() != 16:
				return {"ok": false, "error": "A scene node has an invalid matrix."}
			translation = [matrix[12], matrix[13], matrix[14]]
		if not translation is Array or translation.size() != 3:
			return {"ok": false, "error": "A scene node has an invalid translation."}
		var got := Vector3(float(translation[0]), float(translation[1]), float(translation[2]))
		var want := Vector3(float(row.position[0]), float(row.position[1]), float(row.position[2]))
		if not got.is_finite() or not want.is_finite():
			return {"ok": false, "error": "A scene node has a non-finite position."}
		var delta := (want - got).length()
		if delta > worst: worst = delta; worst_name = name_
	if not missing.is_empty():
		return {"ok": false, "error": "The exported scene is missing %d object(s): %s" % [missing.size(), ", ".join(missing.slice(0, 4))]}
	if worst > 0.001:
		return {"ok": false, "error": "An object moved during export (%s by %.3f m)." % [worst_name, worst]}
	return {"ok": true, "error": "", "checked": expected.size(), "worst_placement_m": worst, "nodes": resolved}
