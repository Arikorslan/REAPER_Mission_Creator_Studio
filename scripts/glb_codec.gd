extends RefCounted















const MAX_GLB_BYTES := 96 * 1024 * 1024


const LARGE_MODEL_BYTES := 40 * 1024 * 1024
const MAX_JSON_BYTES := 8 * 1024 * 1024
const MAX_SOURCE_BYTES := 220 * 1024 * 1024
const SAFETY_MARGIN_MB := 1



const READABLE_EXTENSIONS := [
	"KHR_materials_unlit", "KHR_materials_emissive_strength", "KHR_materials_clearcoat",
	"KHR_materials_specular", "KHR_materials_ior", "KHR_materials_transmission",
	"KHR_materials_volume", "KHR_materials_sheen", "KHR_materials_iridescence",
	"KHR_materials_anisotropy", "KHR_materials_dispersion", "KHR_texture_transform",
	"KHR_lights_punctual", "KHR_mesh_quantization", "KHR_materials_pbrSpecularGlossiness",
]

const BLOCKING_EXTENSIONS := {
	"KHR_draco_mesh_compression": "Draco-compressed mesh data cannot be read. Re-export the model with compression turned off.",
	"EXT_meshopt_compression": "meshopt-compressed data cannot be read. Re-export without meshopt compression.",
	"KHR_texture_basisu": "KTX2 / Basis textures cannot be read. Re-export the textures as PNG or JPEG.",
	"EXT_texture_webp": "WebP textures inside the model cannot be read. Re-export them as PNG or JPEG.",
	"EXT_texture_avif": "AVIF textures inside the model cannot be read. Re-export them as PNG or JPEG.",
	"MSFT_texture_dds": "DDS textures cannot be read. Re-export them as PNG.",
	"EXT_mesh_gpu_instancing": "GPU-instanced nodes cannot be read. Export the copies as normal nodes.",
	"KHR_materials_variants": "Material variants cannot be read. Export one material per surface.",
}

static func sha256(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new(); ctx.start(HashingContext.HASH_SHA256); ctx.update(bytes); return ctx.finish().hex_encode()





static func prepare(path: String) -> Dictionary:
	var lower := path.to_lower()
	if lower.ends_with(".fbx") or lower.ends_with(".fbx.png"):
		return { "ok": false, "error": "FBX goes through the FBX to GLB converter, not this reader.", "hint": "Use the FBX > GLB button on the FILES tab."}


	var ceiling := MAX_GLB_BYTES if lower.ends_with(".glb") or lower.ends_with(".glb.png") else MAX_SOURCE_BYTES
	var read := _read_file(path, ceiling)
	if not bool(read.ok): return read
	var bytes: PackedByteArray = read.bytes
	if bytes.size() < 12: return { "ok": false, "error": "That file is empty or too small to be a model.", "hint": ""}
	var notes: Array = []
	var magic := bytes.slice(0, 4).get_string_from_ascii()

	if bytes.slice(0, 2).get_string_from_ascii() == "PK":
		var extracted := _from_zip(path)
		if not bool(extracted.ok): return extracted
		bytes = extracted.bytes
		notes.append("Unpacked %s from the zip archive." % str(extracted.get("name", "the model")))
		magic = bytes.slice(0, 4).get_string_from_ascii()

	if magic != "glTF":
		var head := bytes.slice(0, mini(bytes.size(), 512)).get_string_from_utf8().strip_edges()
		if head.begins_with("{") or lower.ends_with(".gltf") or lower.ends_with(".gltf.png"):
			var packed := pack_gltf(bytes, path.get_base_dir())
			if not bool(packed.ok): return packed
			bytes = packed.bytes
			notes.append_array(packed.get("notes", []))
			notes.append("Packed the .gltf, its buffer and textures into one GLB.")
			magic = bytes.slice(0, 4).get_string_from_ascii()
		else:
			return { "ok": false, "error": "That file is not a GLB, glTF, FBX or zip archive.", "hint": "Pick a .glb or .gltf file, or convert the model to GLB first."}
	var checked := validate(bytes, true)
	if not bool(checked.ok):
		if str(checked.get("needs_pack", "")) == "external":
			var resolved := pack_glb_externals(bytes, path.get_base_dir())
			if not bool(resolved.ok): return resolved
			bytes = resolved.bytes
			notes.append_array(resolved.get("notes", []))
			checked = validate(bytes, true)
	if not bool(checked.ok): return checked
	var out := checked.duplicate()
	out["bytes"] = bytes
	out["notes"] = notes
	return out






static func validate(bytes: PackedByteArray, allow_animation_only: bool = false) -> Dictionary:
	if bytes.size() < 28: return { "ok": false, "error": "The file is too small to be a GLB.", "hint": "Download it again; the copy looks truncated."}
	if bytes.size() > MAX_GLB_BYTES:
		return { "ok": false,
			"error": "This model is %.1f MB; the limit is %.0f MB per model." % [float(bytes.size()) / 1048576.0, float(MAX_GLB_BYTES) / 1048576.0],
			"hint": "Re-export it with 2K instead of 4K textures, or split it into parts and place them together."}
	if bytes.slice(0, 4).get_string_from_ascii() != "glTF":
		return { "ok": false, "error": "The file does not start with the glTF header.", "hint": "It may be a .gltf text file, a zip, or a renamed FBX."}
	var version := int(bytes.decode_u32(4))
	if version != 2: return { "ok": false, "error": "This is glTF version %d; only version 2 GLB files are supported." % version, "hint": "Re-export as glTF 2.0 binary (.glb)."}
	var declared := int(bytes.decode_u32(8))
	if declared > bytes.size():
		return { "ok": false, "error": "The model file is truncated: it declares %.1f MB but only %.1f MB arrived." % [float(declared) / 1048576.0, float(bytes.size()) / 1048576.0], "hint": "Copy the file again from the source."}
	if declared < 20 + 1: return { "ok": false, "error": "The model header is damaged.", "hint": ""}
	if declared < bytes.size(): bytes = bytes.slice(0, declared)
	var chunk := _json_chunk(bytes)
	if not bool(chunk.ok): return chunk
	var text: String = chunk.text
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary: return { "ok": false, "error": "The GLB scene description is not valid JSON.", "hint": "Re-export the model."}
	var unsupported := _blocking_extensions(parsed)
	if not unsupported.is_empty():
		var names := unsupported.keys()
		return { "ok": false, "error": "This model uses %s, which this build cannot read." % ", ".join(names), "hint": str(unsupported.values()[0])}
	var externals := _external_uris(parsed)
	if not externals.is_empty():
		return { "ok": false, "error": "The model points at %d separate file(s) instead of carrying its own data." % externals.size(), "hint": "Put those files in the same folder and import again: the creator packs them automatically.", "needs_pack": "external", "external": externals}
	var has_mesh: bool = parsed.get("meshes", []) is Array and not (parsed.get("meshes", []) as Array).is_empty()
	var has_animation: bool = parsed.get("animations", []) is Array and not (parsed.get("animations", []) as Array).is_empty()
	if not has_mesh and not (allow_animation_only and has_animation):
		if has_animation: return { "ok": false, "error": "This GLB carries animation but no mesh.", "hint": "Import it with + ANIM, not + MODEL."}
		return { "ok": false, "error": "The GLB contains no mesh.", "hint": "Export the geometry, not just a camera, light or empty node."}
	return { "ok": true, "sha256": sha256(bytes), "bytes": bytes.size(), "has_mesh": has_mesh, "has_animation": has_animation, "bytes_data": bytes}

static func _json_chunk(bytes: PackedByteArray) -> Dictionary:

	var offset := 12
	while offset + 8 <= bytes.size():
		var length := int(bytes.decode_u32(offset))
		var kind := int(bytes.decode_u32(offset + 4))
		if length < 0 or offset + 8 + length > bytes.size(): return { "ok": false, "error": "The model's data chunks are damaged.", "hint": "Re-export the model."}
		if kind == 1313821514:
			if length < 2 or length > MAX_JSON_BYTES: return { "ok": false, "error": "The GLB scene description is unusually large (%.1f MB, limit %.0f MB)." % [float(length) / 1048576.0, float(MAX_JSON_BYTES) / 1048576.0], "hint": "Re-export with fewer materials or without embedded names."}
			return { "ok": true, "text": bytes.slice(offset + 8, offset + 8 + length).get_string_from_utf8()}
		offset += 8 + length
	return { "ok": false, "error": "The GLB has no scene description chunk.", "hint": "Re-export the model."}

static func _blocking_extensions(parsed: Dictionary) -> Dictionary:
	var found := {}
	for key in ["extensionsRequired", "extensionsUsed"]:
		var list = parsed.get(key, [])
		if not list is Array: continue
		for name in list:
			var id := str(name)
			if id in READABLE_EXTENSIONS: continue
			if BLOCKING_EXTENSIONS.has(id):
				found[id] = str(BLOCKING_EXTENSIONS[id])
		if key == "extensionsRequired" and not found.is_empty(): return found
	return found

static func _external_uris(parsed: Dictionary) -> Array:
	var out: Array = []
	for group in ["buffers", "images"]:
		var values = parsed.get(group, [])
		if not values is Array: continue
		for item in values:
			if not item is Dictionary: continue
			var uri := str(item.get("uri", ""))
			if uri.is_empty() or uri.begins_with("data:"): continue
			if not out.has(uri): out.append(uri)
	return out




static func pack_gltf(source: PackedByteArray, base_dir: String) -> Dictionary:
	var text := source.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary: return { "ok": false, "error": "That .gltf file is not valid JSON.", "hint": "Re-export the model."}
	return _pack_document(parsed, base_dir, PackedByteArray())


static func pack_glb_externals(bytes: PackedByteArray, base_dir: String) -> Dictionary:
	var chunk := _json_chunk(bytes)
	if not bool(chunk.ok): return chunk
	var parsed = JSON.parse_string(str(chunk.text))
	if not parsed is Dictionary: return { "ok": false, "error": "The GLB scene description is not valid JSON.", "hint": ""}
	var bin := PackedByteArray()
	var offset := 12
	while offset + 8 <= bytes.size():
		var length := int(bytes.decode_u32(offset))
		var kind := int(bytes.decode_u32(offset + 4))
		if kind == 5130562: bin = bytes.slice(offset + 8, offset + 8 + length); break
		offset += 8 + length
	return _pack_document(parsed, base_dir, bin)

static func _pack_document(parsed: Dictionary, base_dir: String, existing_bin: PackedByteArray) -> Dictionary:
	var notes: Array = []
	var buffers: Array = parsed.get("buffers", [])
	var images: Array = parsed.get("images", [])
	var views: Array = parsed.get("bufferViews", [])

	var pieces: Array = []; var offsets: Array = []; var combined := PackedByteArray()
	var total := 0
	for i in buffers.size():
		var piece := PackedByteArray()
		var uri := str((buffers[i] as Dictionary).get("uri", ""))
		if uri.is_empty() and i == 0:
			piece = existing_bin
		elif uri.begins_with("data:"):
			piece = _decode_data_uri(uri)
			if piece.is_empty(): return { "ok": false, "error": "A data URI inside the model could not be decoded.", "hint": ""}
			notes.append("Decoded an embedded data URI.")
		elif not uri.is_empty():
			var read := _read_file(base_dir.path_join(uri.get_file()), MAX_SOURCE_BYTES)
			if not bool(read.ok):
				return { "ok": false, "error": "The model needs '%s' and it was not found next to it." % uri.get_file(), "hint": "Copy the .bin and texture files into the same folder as the model, then import again."}
			piece = read.bytes
			notes.append("Packed %s." % uri.get_file())
		pieces.append(piece); offsets.append(total)
		total += piece.size()
		total = (total + 3) & ~3

	combined.resize(total)
	for i in pieces.size():
		var piece: PackedByteArray = pieces[i]
		if piece.is_empty(): continue
		var start: int = offsets[i]
		for b in piece.size(): combined[start + b] = piece[b]
	for view in views:
		if not view is Dictionary: continue
		var source_buffer := int(view.get("buffer", 0))
		if source_buffer < 0 or source_buffer >= offsets.size(): return { "ok": false, "error": "The model has a damaged buffer view table.", "hint": ""}
		view["byteOffset"] = int(view.get("byteOffset", 0)) +int(offsets[source_buffer])
		view["buffer"] = 0

	for image in images:
		if not image is Dictionary: continue
		var uri := str(image.get("uri", ""))
		if uri.is_empty(): continue
		var data := PackedByteArray()
		if uri.begins_with("data:"):
			data = _decode_data_uri(uri)
		else:
			var read := _read_file(base_dir.path_join(uri.get_file()), MAX_SOURCE_BYTES)
			if not bool(read.ok):
				return { "ok": false, "error": "The model needs the texture '%s' and it was not found next to it." % uri.get_file(), "hint": "Copy the texture into the same folder as the model, then import again."}
			data = read.bytes
			notes.append("Packed texture %s." % uri.get_file())
		if data.is_empty(): return { "ok": false, "error": "A texture inside the model could not be read.", "hint": ""}
		var start := combined.size()
		combined.append_array(data)
		while combined.size() % 4 != 0: combined.append(0)
		views.append({ "buffer": 0, "byteOffset": start, "byteLength": data.size()})
		image["bufferView"] = views.size() -1
		image.erase("uri")
	parsed["bufferViews"] = views
	if combined.size() > 0:
		parsed["buffers"] = [{ "byteLength": combined.size()}]
	else:
		parsed["buffers"] = []
	parsed.erase("uri")
	var built := build_glb_ex(parsed, combined)
	if not bool(built.get("ok", false)):
		return { "ok": false, "error": str(built.get("error", "")), "hint": str(built.get("hint", ""))}
	return { "ok": true, "bytes": built.get("bytes", PackedByteArray()), "notes": notes}

static func _decode_data_uri(uri: String) -> PackedByteArray:
	var comma := uri.find(",")
	if comma < 0: return PackedByteArray()
	if uri.substr(0, comma).find("base64") >= 0: return Marshalls.base64_to_raw(uri.substr(comma + 1))
	var text := uri.substr(comma + 1).uri_decode()
	var out := PackedByteArray(); out.resize(text.length())
	for i in text.length(): out[i] = text.unicode_at(i) & 255
	return out





static func build_glb(parsed: Dictionary, bin: PackedByteArray) -> PackedByteArray:
	var built := build_glb_ex(parsed, bin)
	return built.get("bytes", PackedByteArray())


static func build_glb_ex(parsed: Dictionary, bin: PackedByteArray) -> Dictionary:
	var json := JSON.stringify(parsed).to_utf8_buffer()
	while json.size() % 4 != 0: json.append(32)
	var bin_padded := bin
	while bin_padded.size() % 4 != 0: bin_padded.append(0)
	var total := 12 + 8 + json.size()
	if bin_padded.size() > 0: total += 8 + bin_padded.size()
	if total > MAX_GLB_BYTES:
		return { "ok": false, "bytes": PackedByteArray(),
			"error": "This model packs to %.1f MB, over the %.0f MB per-model limit." % [float(total) / 1048576.0, float(MAX_GLB_BYTES) / 1048576.0],
			"hint": "Its textures and mesh no longer fit in one file. Re-export with 2K textures or split it into parts."}
	var out := PackedByteArray(); out.resize(total)
	out.encode_u32(0, 1179937895)
	out.encode_u32(4, 2)
	out.encode_u32(8, total)
	out.encode_u32(12, json.size())
	out.encode_u32(16, 1313821514)
	for i in json.size(): out[20 + i] = json[i]
	if bin_padded.size() > 0:
		var at := 20 + json.size()
		out.encode_u32(at, bin_padded.size())
		out.encode_u32(at + 4, 5130562)
		for i in bin_padded.size(): out[at + 8 + i] = bin_padded[i]
	return { "ok": true, "bytes": out, "error": ""}

static func _from_zip(path: String) -> Dictionary:
	var reader := ZIPReader.new()
	if reader.open(path) != OK: return { "ok": false, "error": "That zip archive could not be opened.", "hint": "Unzip it yourself and import the .glb inside."}
	var names := reader.get_files()
	reader.close()
	var best := ""
	for name in names:
		var lower := name.to_lower()
		if lower.ends_with(".glb"): best = name; break
		if lower.ends_with(".gltf") and best.is_empty(): best = name
	if best.is_empty(): return { "ok": false, "error": "That zip archive has no .glb or .gltf inside.", "hint": "Unzip it and import the model file directly."}
	var reader2 := ZIPReader.new()
	if reader2.open(path) != OK: return { "ok": false, "error": "That zip archive could not be opened again.", "hint": ""}
	var bytes := reader2.read_file(best)
	reader2.close()
	if bytes.is_empty(): return { "ok": false, "error": "'%s' inside the zip could not be read." % best, "hint": ""}
	return { "ok": true, "bytes": bytes, "name": best.get_file()}

static func _read_file(path: String, max_bytes: int) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return { "ok": false, "error": "Could not open the selected file.", "hint": ""}
	var length := file.get_length()
	if length <= 0: return { "ok": false, "error": "The selected file is empty.", "hint": ""}
	if length > max_bytes:
		var hint := "Re-export it with 2K instead of 4K textures, or split it into parts." if max_bytes == MAX_GLB_BYTES else "Unzip it and import the model inside instead."
		return { "ok": false, "error": "The selected file is %.1f MB; the limit is %.0f MB." % [float(length) / 1048576.0, float(max_bytes) / 1048576.0], "hint": hint}
	var bytes := file.get_buffer(length)
	file.close()
	return { "ok": true, "bytes": bytes}





static func heights_checksum(heights: Array) -> String:
	var text := PackedStringArray()
	text.resize(heights.size())
	for i in heights.size():
		text[i] = "%.4f" % float(heights[i])
	return sha256("\n".join(text).to_utf8_buffer())

static func import_model(bytes: PackedByteArray, allow_animation_only: bool = false) -> Dictionary:
	var check := validate(bytes, allow_animation_only)
	if not bool(check.ok): return check
	var trimmed: PackedByteArray = check.get("bytes_data", bytes)
	var doc := GLTFDocument.new(); var state := GLTFState.new()
	var result := doc.append_from_buffer(trimmed, "", state)
	if result != OK:
		return { "ok": false, "error": "The glTF reader rejected this model (code %s)." % str(result), "hint": "Re-export it as glTF 2.0 binary with embedded textures and no compression."}
	var model := doc.generate_scene(state, 30.0, false, false)
	if not model is Node3D:
		if model != null: model.free()
		return { "ok": false, "error": "The GLB produced no 3D scene.", "hint": "Check that the model has a mesh inside a node."}
	return { "ok": true, "model": model, "sha256": str(check.sha256)}



static func stats(bytes: PackedByteArray) -> Dictionary:
	var out := { "ok": false, "meshes": 0, "triangles": 0, "materials": 0, "textures": 0,
		"animations": 0, "nodes": 0, "bytes": bytes.size(), "skinned": false}
	if bytes.is_empty(): return out
	var chunk := _json_chunk(bytes)
	if not bool(chunk.ok): return out
	var parsed = JSON.parse_string(str(chunk.text))
	if not parsed is Dictionary: return out
	var accessors: Array = parsed.get("accessors", []) if parsed.get("accessors", []) is Array else []
	var meshes: Array = parsed.get("meshes", []) if parsed.get("meshes", []) is Array else []
	var triangles := 0
	for mesh in meshes:
		if not mesh is Dictionary: continue
		var primitives: Array = mesh.get("primitives", []) if mesh.get("primitives", []) is Array else []
		for primitive in primitives:
			if not primitive is Dictionary: continue
			var attributes: Dictionary = primitive.get("attributes", {}) if primitive.get("attributes", {}) is Dictionary else {}
			var count := 0
			if primitive.has("indices"):
				var index := int(primitive.indices)
				if index >= 0 and index < accessors.size() and accessors[index] is Dictionary: count = int((accessors[index] as Dictionary).get("count", 0))
				triangles += int(count / 3)
			elif attributes.has("POSITION"):
				var position := int(attributes.POSITION)
				if position >= 0 and position < accessors.size() and accessors[position] is Dictionary: count = int((accessors[position] as Dictionary).get("count", 0))
				triangles += int(count / 3)
	out["ok"] = true
	out["meshes"] = meshes.size()
	out["triangles"] = triangles
	out["materials"] = (parsed.get("materials", []) as Array).size() if parsed.get("materials", []) is Array else 0
	out["textures"] = (parsed.get("textures", []) as Array).size() if parsed.get("textures", []) is Array else 0
	out["animations"] = (parsed.get("animations", []) as Array).size() if parsed.get("animations", []) is Array else 0
	out["nodes"] = (parsed.get("nodes", []) as Array).size() if parsed.get("nodes", []) is Array else 0
	for mesh in meshes:
		if mesh is Dictionary and mesh.get("primitives", []) is Array:
			for primitive in mesh.primitives:
				if primitive is Dictionary and (primitive.get("attributes", {}) is Dictionary) and (primitive.attributes as Dictionary).has("JOINTS_0"): out["skinned"] = true
	return out
