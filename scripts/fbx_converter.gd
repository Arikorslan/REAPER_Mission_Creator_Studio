extends RefCounted


const Codec = preload("res://scripts/glb_codec.gd")
# Input FBX and its converted GLB are each bounded by the same import budget.
const MAX_FBX_BYTES := Codec.MAX_GLB_BYTES
static func convert(bytes: PackedByteArray, animation_only := false, require_animation := false) -> Dictionary:
	if bytes.size() < 32 or bytes.size() > MAX_FBX_BYTES: return { "ok": false, "error": "FBX must be between 32 bytes and %d MiB." % int(MAX_FBX_BYTES / 1048576)}
	if not ClassDB.class_exists("FBXDocument"): return { "ok": false, "error": "This build does not contain the FBX importer."}
	var fbx := FBXDocument.new(); var fs := FBXState.new(); var err := fbx.append_from_buffer(bytes, "", fs)
	if err != OK: return { "ok": false, "error": "Could not read the FBX (error %s)." % err}
	var scene := fbx.generate_scene(fs, 30.0, false, false)
	if not scene is Node3D:
		if scene != null: scene.free()
		return { "ok": false, "error": "The FBX did not contain a readable 3D scene."}
	var gltf := GLTFDocument.new(); var gs := GLTFState.new(); err = gltf.append_from_scene(scene, gs)
	if err != OK: scene.free(); return { "ok": false, "error": "Could not convert FBX to GLB (error %s)." % err}
	var out := gltf.generate_buffer(gs); scene.free()
	var check := Codec.validate(out, animation_only)
	if not check.ok: return { "ok": false, "error": "Converted FBX cannot be used: " + str(check.error)}
	if require_animation and not bool(check.has_animation): return { "ok": false, "error": "No animation clips were found in this FBX."}
	return { "ok": true, "bytes": out, "sha256": check.sha256, "has_mesh": check.has_mesh, "has_animation": check.has_animation}
