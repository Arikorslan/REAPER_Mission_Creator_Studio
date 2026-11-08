extends RefCounted



const Codec = preload("res://scripts/glb_codec.gd")
const Platform = preload("res://scripts/platform_files.gd")
const Library = preload("res://scripts/asset_library.gd")
const TextureCodec = preload("res://scripts/texture_codec.gd")
const Terrain = preload("res://scripts/terrain_model.gd")
const Paint = preload("res://scripts/terrain_paint.gd")
const Weather = preload("res://scripts/environment.gd")
const MAGIC := "RMDRAFT2"
const LEGACY_MAGIC := "RMDRAFT1"
const PAINT_MAGIC := "RMDRAFT3"
const MISSION_MAGIC := "RMISSN02"
const LEGACY_MISSION_MAGIC := "RMISSN01"
const PAINT_MISSION_MAGIC := "RMISSN03"



const SCENE_MISSION_MAGIC := "RMISSN04"
const SCENE_PREFIX := "scn_"
const MAX_SCENE_BYTES := 96 * 1024 * 1024
const SCENE_FORMAT := "reaper.scene/2"
const MAX_FILE := 200 * 1024 * 1024
const MAX_META := 4 * 1024 * 1024
const MAX_OBJECTS := 200
const MAX_ASSETS := 24
const Version = preload("res://scripts/version.gd")

static func _num(v, lo: float, hi: float) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)) and float(v) >= lo and float(v) <= hi
static func _str(v, n: int, empty_ok := false) -> bool:
	if not v is String or (not empty_ok and v.is_empty()) or v.length() > n: return false
	for byte in v.to_utf8_buffer():
		if byte == 0: return false
	return true
static func _simple_id(v) -> bool:
	if not _str(v, 80): return false
	for c in v.to_utf8_buffer():
		if not ((c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95): return false
	return true

static func check_document(data: Variant, assets: Variant) -> Dictionary:
	if not data is Dictionary or not assets is Dictionary: return { "ok": false, "error": "Invalid draft structure."}
	if int(data.get("schema", 0)) != 1 or data.get("kind", "") != "REAPER_MISSION_CREATOR_DRAFT": return { "ok": false, "error": "This is not a supported creator draft."}
	if not _str(data.get("name"), 100) or not _str(data.get("region"), 120) or not _str(data.get("briefing", ""), 4000, true): return { "ok": false, "error": "Check mission name, region and briefing."}
	if not _num(data.get("start_hour"), 0, 23) or not _num(data.get("start_minute"), 0, 59): return { "ok": false, "error": "Invalid mission start time."}
	if data.has("terrain") and not Terrain.valid(data.terrain): return { "ok": false, "error": "Invalid or out-of-range terrain heightfield."}
	if data.has("background") and str(data.background) not in ["blank", "demo"]: return { "ok": false, "error": "Invalid scene background."}
	var goals = data.get("objectives", []); var objects = data.get("objects", [])
	if not goals is Array or goals.size() > 20 or not objects is Array or objects.size() > MAX_OBJECTS: return { "ok": false, "error": "Too many objects or objectives."}
	for goal in goals:
		if not _str(goal, 200): return { "ok": false, "error": "Objective text is invalid."}
	if assets.size() > MAX_ASSETS: return { "ok": false, "error": "Too many imported assets (maximum 24)."}
	var asset_bytes := 0
	var scene_records := 0
	for key in assets:
		if not _simple_id(key) or not assets[key] is Dictionary: return { "ok": false, "error": "Invalid asset record."}
		var item: Dictionary = assets[key]; var b = item.get("bytes")
		if not _str(item.get("name"), 100) or not b is PackedByteArray: return { "ok": false, "error": "Invalid model data."}
		var category := str(item.get("category", "model"))
		if category not in ["model", "animation", "texture", "scene"]: return { "ok": false, "error": "Invalid asset category."}
		if category == "scene":
			scene_records += 1
			if scene_records > 1: return { "ok": false, "error": "Only one exported scene can travel with a mission."}
			if not str(key).begins_with(SCENE_PREFIX) or b.size() < 20 or b.size() > MAX_SCENE_BYTES: return { "ok": false, "error": "Invalid embedded scene."}
			var scene_check: Dictionary = Codec.validate(b, false)
			if not scene_check.ok: return { "ok": false, "error": "The embedded scene is not a readable GLB: " + str(scene_check.error)}
			asset_bytes += b.size()
			continue
		var checked: Dictionary = TextureCodec.validate(b) if category == "texture" else Codec.validate(b, category == "animation")
		if not checked.ok: return { "ok": false, "error": "Invalid asset %s: %s" % [key, checked.error]}
		if category == "animation" and not bool(checked.get("has_animation", false)): return { "ok": false, "error": "The imported animation has no clips."}
		var expected_prefix := "tex_" if category == "texture" else ("anim_" if category == "animation" else "glb_")
		if key != expected_prefix + Codec.sha256(b): return { "ok": false, "error": "Asset ID does not match its content hash."}
		asset_bytes += b.size()
	if asset_bytes > MAX_FILE - MAX_META - 12: return { "ok": false, "error": "Combined imported assets exceed the %d MiB budget." % int((MAX_FILE - MAX_META - 12) / 1048576)}
	var terrain_texture = data.get("terrain_texture", "")
	if not _str(terrain_texture, 80, true) or (not terrain_texture.is_empty() and (not assets.has(terrain_texture) or str(assets[terrain_texture].get("category", "")) != "texture")) or not _num(data.get("terrain_tile_m", 80), 5, 500): return { "ok": false, "error": "Invalid terrain texture."}
	if data.has("terrain_paint"):
		var paint := Paint.validate(data.terrain_paint, assets)
		if not paint.ok: return paint
	if data.has("snow_paint"):
		var snow := Paint.validate_snow(data.snow_paint)
		if not snow.ok: return snow
	if data.has("environment"):

		var weather_error := Weather.validate(data.environment)
		if not weather_error.is_empty(): return { "ok": false, "error": weather_error}
	var lib := Library.new(); var ids := {}
	for row in objects:
		if not row is Dictionary or not _simple_id(row.get("id")) or ids.has(row.get("id")): return { "ok": false, "error": "Invalid or repeated object ID."}
		ids[row.id] = true
		if not _str(row.get("asset"), 80) or not lib.known(str(row.asset), assets) or not _str(row.get("name"), 100): return { "ok": false, "error": "An object references an unknown asset or has no name."}
		var extent := float(data.get("terrain", {}).get("extent", Terrain.EXTENT))
		if not _num(row.get("x"), -extent, extent) or not _num(row.get("z"), -extent, extent) or not _num(row.get("height"), -5, 500) or not _num(row.get("yaw_deg"), -360, 360) or not _num(row.get("pitch_deg", 0), -360, 360) or not _num(row.get("roll_deg", 0), -360, 360) or not _num(row.get("scale"), 0.05, 30) or not _num(row.get("speed_mps"), 0, 100): return { "ok": false, "error": "An object property is outside supported limits."}
		if str(row.get("faction", "")) not in ["Friendly", "Hostile", "Civilian", "Neutral"]: return { "ok": false, "error": "Invalid object side."}
		if typeof(row.get("route_face", true)) != TYPE_BOOL or typeof(row.get("animation_loop", true)) != TYPE_BOOL or not _num(row.get("animation_speed", 1), 0.1, 5): return { "ok": false, "error": "Invalid animation or route setting."}
		if not _num(row.get("brick_scale", 1), 0.4, 3): return { "ok": false, "error": "Invalid brick or block size."}
		if row.has("animation_own") and typeof(row.animation_own) != TYPE_BOOL: return { "ok": false, "error": "Invalid own-animation switch."}
		if row.has("animation_displacement") and not _num(row.animation_displacement, 0, 20): return { "ok": false, "error": "Invalid animation travel speed."}
		if row.has("animation_range") and not _num(row.animation_range, 2, 400): return { "ok": false, "error": "Invalid walk back and forth distance."}
		var object_texture = row.get("texture", "")
		if not _str(object_texture, 80, true) or (not object_texture.is_empty() and (not assets.has(object_texture) or str(assets[object_texture].get("category", "")) != "texture")): return { "ok": false, "error": "Invalid object texture."}
		var source = row.get("animation_source", ""); var clip = row.get("animation_clip", "")
		if not _str(source, 80, true) or not _str(clip, 140, true): return { "ok": false, "error": "Invalid animation selection."}
		if not source.is_empty() and source != "embedded" and (not assets.has(source) or str(assets[source].get("category", "model")) != "animation"): return { "ok": false, "error": "The selected animation file is missing."}
		var route = row.get("route", [])
		if not route is Array or route.size() > 200: return { "ok": false, "error": "A route has too many points."}
		for p in route:
			if not p is Array or p.size() != 2 or not _num(p[0], -extent, extent) or not _num(p[1], -extent, extent): return { "ok": false, "error": "Invalid route point."}
		if str(row.asset) in ["road_path", "brick_wall"]:
			var path = row.get("path", [])
			if not path is Array or path.size() < 2 or path.size() > 300 or not _num(row.get("path_width", 8), 2, 25) or not _num(row.get("wall_height", 2), 0.25, 12) or not _num(row.get("brick_scale", 1), 0.4, 3): return { "ok": false, "error": "Invalid road or wall."}
			var length := 0.0; var last := Vector2.ZERO
			for k in path.size():
				var p = path[k]
				if not p is Array or p.size() != 2 or not _num(p[0], -2 * extent, 2 * extent) or not _num(p[1], -2 * extent, 2 * extent) or not _num(float(row.x) +float(p[0]), -extent, extent) or not _num(float(row.z) +float(p[1]), -extent, extent): return { "ok": false, "error": "A road or wall goes outside the terrain."}
				var point := Vector2(float(p[0]), float(p[1]))
				if k > 0: length += point.distance_to(last)
				last = point
			if length < 0.5 or length > (5000.0 if str(row.asset) == "road_path" else 250.0): return { "ok": false, "error": "Road or wall length is outside supported limits."}
	var target = data.get("recon_target", "")
	if not target is String or (not target.is_empty() and not ids.has(target)): return { "ok": false, "error": "The reconnaissance target is missing."}
	if not target.is_empty():
		for row in objects:
			if row.id == target and (Terrain.is_feature(str(row.asset)) or str(row.asset) == "drone_start"): return { "ok": false, "error": "Choose an object, not terrain or the air start, as the recon target."}
	return { "ok": true, "error": ""}




static func oversized_assets(assets: Dictionary) -> Array:
	var out: Array = []
	var total := 0
	for key in assets:
		var item: Dictionary = assets[key]
		var b = item.get("bytes")
		if not b is PackedByteArray: continue
		total += b.size()
		var category := str(item.get("category", "model"))
		var ceiling := TextureCodec.MAX_TEXTURE_BYTES if category == "texture" else (MAX_SCENE_BYTES if category == "scene" else Codec.MAX_GLB_BYTES)
		if b.size() > ceiling:
			out.append({ "name": str(item.get("name", "(unnamed)")), "category": category,
				"mb": float(b.size()) / 1048576.0, "limit_mb": float(ceiling) / 1048576.0})
	var budget := MAX_FILE - MAX_META - 12
	if total > budget:
		out.append({ "name": "all imported assets together", "category": "total",
			"mb": float(total) / 1048576.0, "limit_mb": float(budget) / 1048576.0})
	return out

static func needs_paint_format(data: Dictionary, assets: Dictionary) -> bool:
	if data.has("terrain_paint"): return true
	for item in assets.values():
		if item is Dictionary and str(item.get("category", "model")) == "texture" and item.get("bytes", PackedByteArray()).size() > 8 * 1024 * 1024: return true
	return false

static func save_draft(path: String, data: Dictionary, assets: Dictionary, signature: String = MAGIC) -> Dictionary:
	if signature not in [MAGIC, PAINT_MAGIC, MISSION_MAGIC, PAINT_MISSION_MAGIC, SCENE_MISSION_MAGIC]: return { "ok": false, "error": "Unsupported file signature."}
	var mission_export := signature in [MISSION_MAGIC, PAINT_MISSION_MAGIC, SCENE_MISSION_MAGIC]
	if signature == SCENE_MISSION_MAGIC:
		signature = SCENE_MISSION_MAGIC
	elif needs_paint_format(data, assets):
		signature = PAINT_MISSION_MAGIC if mission_export else PAINT_MAGIC
	var valid := check_document(data, assets)
	if not valid.ok: return valid
	if path.is_empty(): return { "ok": false, "error": "No destination selected."}
	var records: Array = []; var keys := assets.keys(); keys.sort()
	for id in keys:
		var b: PackedByteArray = assets[id].bytes
		records.append({ "id": id, "name": assets[id].name, "category": str(assets[id].get("category", "model")), "length": b.size(), "sha256": Codec.sha256(b)})
	var manifest: Dictionary = { "schema": 1, "kind": "REAPER_MISSION_CREATOR_DRAFT_CONTAINER", "mission": data, "assets": records}
	if mission_export:
		manifest["format"] = "reaper.mission/%d" % ([4, 3, 2][[SCENE_MISSION_MAGIC, PAINT_MISSION_MAGIC, MISSION_MAGIC].find(signature)])
		manifest["creator"] = "REAPER Mission Creator " + str(Version.VERSION)
		manifest["axes"] = "X east, Y up, Z south. Yaw, pitch and roll are degrees, applied YXZ. Distances are metres."
		if data.has("scene"): manifest["scene_format"] = SCENE_FORMAT
	var json := JSON.stringify(manifest, "", true, true).to_utf8_buffer()
	if json.size() > MAX_META: return { "ok": false, "error": "Draft metadata is too large."}
	var payload := PackedByteArray()
	payload.append_array(signature.to_ascii_buffer()); payload.append_array(_bytes_u32(json.size())); payload.append_array(json)
	for id in keys: payload.append_array(assets[id].bytes)
	var written := Platform.write_document(path, payload)
	if not written.ok: return { "ok": false, "error": str(written.error), "recovery": str(written.get("recovery", ""))}
	return { "ok": true, "error": "", "path": path, "recovery": ""}

static func _bytes_u32(value: int) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new(); buffer.big_endian = false; buffer.put_u32(value); return buffer.data_array

static func load_draft(path: String, signature: String = MAGIC) -> Dictionary:
	if signature not in [MAGIC, PAINT_MAGIC, MISSION_MAGIC, PAINT_MISSION_MAGIC, SCENE_MISSION_MAGIC]: return { "ok": false, "error": "Unsupported file signature."}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return { "ok": false, "error": "Cannot open selected draft."}
	var total := f.get_length()
	if total < 12 or total > MAX_FILE: return { "ok": false, "error": "Not a supported bounded REAPER file."}
	var actual := f.get_buffer(8).get_string_from_ascii()
	var allowed := [MAGIC, LEGACY_MAGIC, PAINT_MAGIC] if signature in [MAGIC, PAINT_MAGIC] else [MISSION_MAGIC, LEGACY_MISSION_MAGIC, PAINT_MISSION_MAGIC, SCENE_MISSION_MAGIC]
	if actual not in allowed: return { "ok": false, "error": "Not a supported bounded REAPER file."}
	var n := f.get_32()
	if n < 2 or n > MAX_META or 12 + n > total: return { "ok": false, "error": "Invalid draft metadata length."}
	var manifest = JSON.parse_string(f.get_buffer(n).get_string_from_utf8())
	if not manifest is Dictionary or int(manifest.get("schema", 0)) != 1 or manifest.get("kind", "") != "REAPER_MISSION_CREATOR_DRAFT_CONTAINER" or not manifest.get("assets", []) is Array: return { "ok": false, "error": "Invalid draft manifest."}
	var records: Array = manifest.assets
	if records.size() > MAX_ASSETS: return { "ok": false, "error": "Too many embedded models."}
	var assets := {}; var expected_bytes := 12 + n
	for r in records:
		if not r is Dictionary or not _simple_id(r.get("id")) or not _str(r.get("name"), 100) or not _str(r.get("sha256"), 64) or not _num(r.get("length"), 28, maxi(Codec.MAX_GLB_BYTES, MAX_SCENE_BYTES)) or assets.has(r.get("id")): return { "ok": false, "error": "Invalid embedded-model record."}
		var length := int(r.length); expected_bytes += length
		if expected_bytes > total: return { "ok": false, "error": "Truncated embedded model."}
		var bytes := f.get_buffer(length)
		var category := str(r.get("category", "model"))
		var prefix := "tex_" if category == "texture" else ("anim_" if category == "animation" else ("scn_" if category == "scene" else "glb_"))
		if category not in ["model", "animation", "texture", "scene"] or Codec.sha256(bytes) != str(r.sha256) or str(r.id) != prefix + str(r.sha256): return { "ok": false, "error": "Embedded-asset integrity check failed."}
		assets[r.id] = { "name": r.name, "bytes": bytes, "category": category}
	if expected_bytes != total: return { "ok": false, "error": "Unexpected trailing draft data."}
	var mission = manifest.get("mission", {})
	var valid := check_document(mission, assets)
	if not valid.ok: return valid
	if needs_paint_format(mission, assets) and actual not in [PAINT_MAGIC, PAINT_MISSION_MAGIC, SCENE_MISSION_MAGIC]: return { "ok": false, "error": "Painted terrain or large textures require the v3 mission format."}

	mission["schema"] = int(mission.schema); mission["start_hour"] = int(mission.start_hour); mission["start_minute"] = int(mission.start_minute)
	if mission.has("terrain"): mission.terrain["resolution"] = int(mission.terrain.resolution)
	return { "ok": true, "error": "", "mission": mission, "assets": assets}

static func save_mission(path: String, data: Dictionary, assets: Dictionary) -> Dictionary:
	if str(data.get("recon_target", "")).is_empty(): return { "ok": false, "error": "Select a placed object and use SET RECON TARGET before exporting a playable mission."}
	return save_draft(path, data, assets, MISSION_MAGIC)
static func load_mission(path: String) -> Dictionary:
	var result := load_draft(path, MISSION_MAGIC)
	if result.ok and str(result.mission.get("recon_target", "")).is_empty(): return { "ok": false, "error": "Mission package has no reconnaissance target."}
	return result









static func save_mission_package(path: String, data: Dictionary, assets: Dictionary,
		scene_glb: PackedByteArray, scene_block: Dictionary) -> Dictionary:
	if str(data.get("recon_target", "")).is_empty():
		return { "ok": false, "error": "Select a placed object and use SET RECON TARGET before exporting a playable mission."}
	var packed_data: Dictionary = data.duplicate(true)
	var packed_assets: Dictionary = {}
	for key in assets:
		var item: Dictionary = assets[key]
		if str(item.get("category", "model")) != "scene": packed_assets[key] = item
	var info: Dictionary = {}
	if scene_glb.size() >= 20:
		if scene_glb.size() > MAX_SCENE_BYTES:
			return { "ok": false, "error": "The exported scene is %.1f MB; the package limit is %d MB." % [
				float(scene_glb.size()) / 1048576.0, int(MAX_SCENE_BYTES / 1048576)]}
		var sha := Codec.sha256(scene_glb)
		var record_id := SCENE_PREFIX + sha
		packed_assets[record_id] = { "name": "Exported scene", "bytes": scene_glb, "category": "scene"}
		info = { "glb_asset": record_id, "glb_sha256": sha, "glb_bytes": scene_glb.size()}
		var block: Dictionary = scene_block.duplicate(true)
		block["scene_glb"] = info
		packed_data["scene"] = block
	else:
		return { "ok": false, "error": "The scene could not be exported, so the mission package was not written."}
	var written := save_draft(path, packed_data, packed_assets, SCENE_MISSION_MAGIC)
	if not bool(written.get("ok", false)): return written
	var verified := verify_package(path)
	if not bool(verified.get("ok", false)):
		return { "ok": false, "error": "The mission file was written but its own check failed: " + str(verified.get("error", "")), "path": path}
	return { "ok": true, "error": "", "path": path, "fidelity": verified,
		"bytes": int(verified.get("file_bytes", 0)), "scene_bytes": int(info.glb_bytes),
		"objects": int(verified.get("objects", 0))}



static func verify_package(path: String) -> Dictionary:
	var loaded := load_draft(path, SCENE_MISSION_MAGIC)
	if not bool(loaded.get("ok", false)): return loaded
	var mission: Dictionary = loaded.mission
	var assets: Dictionary = loaded.assets
	var block: Dictionary = mission.get("scene", {})
	if block.is_empty(): return { "ok": false, "error": "This package carries no scene description."}
	if str(block.get("format", "")) != SCENE_FORMAT: return { "ok": false, "error": "Unknown scene description format."}
	var glb_record: Dictionary = block.get("scene_glb", {})
	var record_id := str(glb_record.get("glb_asset", ""))
	if record_id.is_empty() or not assets.has(record_id): return { "ok": false, "error": "The embedded scene is missing from the package."}
	var glb_bytes: PackedByteArray = assets[record_id].get("bytes", PackedByteArray())
	if Codec.sha256(glb_bytes) != str(glb_record.get("glb_sha256", "")): return { "ok": false, "error": "The embedded scene failed its checksum."}
	var terrain: Dictionary = block.get("terrain", {})
	var heights: Array = terrain.get("heights", [])
	if Codec.heights_checksum(heights) != str(terrain.get("heights_sha256", "")):
		return { "ok": false, "error": "The terrain in the scene block does not match its checksum."}
	var source_heights: Array = mission.get("terrain", {}).get("heights", [])
	if source_heights.size() != heights.size(): return { "ok": false, "error": "The scene block terrain differs from the mission terrain."}
	var nodes: Array = block.get("nodes", [])
	var doc := GLTFDocument.new(); var gs := GLTFState.new()
	if doc.append_from_buffer(glb_bytes, "", gs) != OK: return { "ok": false, "error": "The embedded scene is not readable."}
	var scene_root: Node3D = doc.generate_scene(gs, 30.0, false, false)
	if scene_root == null: return { "ok": false, "error": "The embedded scene produced no scene."}
	var worst := 0.0; var worst_name := ""; var missing: Array = []
	for row in nodes:
		var wanted := Vector3(float(row.position[0]), float(row.position[1]), float(row.position[2]))
		var found: Node3D = null
		for candidate in scene_root.find_children("*", "Node3D", true, false):
			if str((candidate as Node3D).name) == str(row.name): found = candidate; break
		if found == null: missing.append(str(row.name)); continue
		var d := (wanted - found.position).length()
		if d > worst: worst = d; worst_name = str(row.name)
	scene_root.free()
	if not missing.is_empty(): return { "ok": false, "error": "The embedded scene is missing %d object(s)." % missing.size()}
	if worst > 0.001: return { "ok": false, "error": "An object moved when the package was re-read (%s by %.3f m)." % [worst_name, worst]}
	var missing_keys: Array = []
	for key in ["terrain", "objects", "name", "recon_target"]:
		if not mission.has(key): missing_keys.append(key)
	if not missing_keys.is_empty(): return { "ok": false, "error": "The package is missing %s." % ", ".join(missing_keys)}
	var file := FileAccess.open(path, FileAccess.READ)
	var size := 0 if file == null else file.get_length()
	if file != null: file.close()
	return { "ok": true, "error": "", "objects": nodes.size(), "worst_placement_m": worst,
		"terrain_cells": heights.size(), "scene_bytes": glb_bytes.size(), "file_bytes": size,
		"has_paint": mission.has("terrain_paint"), "has_snow": mission.has("snow_paint"),
		"has_environment": mission.has("environment"), "assets": assets.size()}



static func scene_from_package(path: String) -> Dictionary:
	var loaded := load_draft(path, SCENE_MISSION_MAGIC)
	if not bool(loaded.get("ok", false)): return loaded
	var block: Dictionary = loaded.mission.get("scene", {})
	if block.is_empty(): return { "ok": false, "error": "This package carries no scene description."}
	var record_id := str(block.get("scene_glb", {}).get("glb_asset", ""))
	return { "ok": true, "error": "", "scene": block, "data": loaded.mission, "assets": loaded.assets,
		"glb": loaded.assets.get(record_id, {}).get("bytes", PackedByteArray())}
