extends RefCounted

signal changed(reason: String)
const Terrain = preload("res://scripts/terrain_model.gd")
const Paint = preload("res://scripts/terrain_paint.gd")
const MAX_OBJECTS := 200
const MAX_ROUTE_POINTS := 200
const MAX_PATH_POINTS := 300
const WALL_MIN := 0.25
const WALL_MAX := 12.0
const BRICK_MIN := 0.4
const BRICK_MAX := 3.0
var data: Dictionary = {}
var custom_assets: Dictionary = {}
var selected_id: String = ""
var dirty := false
var _next_id := 1
var _terrain_undo: Array = []
var _paint_image: Image
var _paint_dirty := false
var _paint_undo: Array = []
var _paint_before: Variant = null
var _paint_stroke_active := false
var _paint_stroke_changed := false

func _init() -> void: reset_blank()

func reset_demo() -> void: reset_blank()
func reset_blank() -> void:
	data = { "schema": 1, "kind": "REAPER_MISSION_CREATOR_DRAFT", "name": "Untitled mission", "region": "Custom scene", "start_hour": 10, "start_minute": 0, "background": "blank", "terrain": Terrain.empty(), "briefing": "", "objectives": [], "objects": []}
	custom_assets = {}; selected_id = ""; _next_id = 1; _terrain_undo.clear(); _paint_undo.clear(); _paint_image = null; _paint_dirty = false; _paint_stroke_active = false; dirty = false; changed.emit("reset")
func extent() -> float: return float(data.get("terrain", {}).get("extent", Terrain.EXTENT))
func bounded(p: Vector2) -> Vector2:
	var e := extent() -0.5; return Vector2(clampf(p.x, -e, e), clampf(p.y, -e, e))
func find_object(id: String) -> Dictionary:
	for row: Dictionary in data.get("objects", []):
		if str(row.get("id", "")) == id: return row
	return {}
func select(id: String) -> void:
	selected_id = id if not find_object(id).is_empty() else ""; changed.emit("selection")
func add_object(asset_id: String, position: Vector2, title: String = "") -> String:
	if not position.is_finite() or data.objects.size() >= MAX_OBJECTS: return ""
	position = bounded(position)
	var id := "object_%04d" % _next_id; _next_id += 1
	var name_: String = title if not title.is_empty() else asset_id.capitalize().replace("_", " ") +" %02d" % (_next_id - 1)
	var default_faction := "Neutral" if Terrain.is_feature(asset_id) or asset_id in ["road_path", "brick_wall"] else ("Hostile" if asset_id == "technical" else ("Civilian" if asset_id == "civilian" else "Friendly"))
	data.objects.append({ "id": id, "asset": asset_id, "name": name_, "x": position.x, "z": position.y, "height": 120.0 if asset_id == "drone_start" else 0.0, "yaw_deg": 0.0, "pitch_deg": 0.0, "roll_deg": 0.0, "scale": 1.0, "faction": default_faction, "speed_mps": 4.0, "route": [], "route_face": true, "animation_source": "", "animation_clip": "", "animation_loop": true, "animation_speed": 1.0, "animation_own": false, "animation_displacement": 0.0, "animation_range": 12.0, "brick_scale": 1.0, "locked": false, "hidden": false})
	selected_id = id; dirty = true; changed.emit("objects"); return id
func add_construction(asset_id: String, p: Vector2, width: float = 8.0, wall_height: float = 2.0) -> String:
	if asset_id not in ["road_path", "brick_wall"]: return ""
	var id := add_object(asset_id, p, "Road" if asset_id == "road_path" else "Brick wall")
	var row := find_object(id)
	if row.is_empty(): return ""
	row["path"] = [[0.0, 0.0]]; row["path_width"] = clampf(width, 2.0, 25.0); row["wall_height"] = clampf(wall_height, WALL_MIN, WALL_MAX); row["brick_scale"] = clampf(float(row.get("brick_scale", 1.0)), BRICK_MIN, BRICK_MAX)
	changed.emit("construction"); return id
func append_construction(id: String, p: Vector2, force := false) -> bool:
	var row := find_object(id)
	if row.is_empty() or str(row.asset) not in ["road_path", "brick_wall"] or not p.is_finite(): return false
	var path: Array = row.get("path", [])
	if path.size() >= MAX_PATH_POINTS: return false
	p = bounded(p); var rel := p - Vector2(float(row.x), float(row.z)); var last := Vector2(float(path[-1][0]), float(path[-1][1]))
	var min_spacing := 10.0 if str(row.asset) == "road_path" else 2.0
	if rel.distance_to(last) < (0.5 if force else min_spacing): return false
	var distance := rel.distance_to(last)
	for i in range(path.size() -1): distance += Vector2(float(path[i][0]), float(path[i][1])).distance_to(Vector2(float(path[i + 1][0]), float(path[i + 1][1])))
	if distance > (5000.0 if str(row.asset) == "road_path" else 250.0): return false
	path.append([rel.x, rel.y]); row["path"] = path; dirty = true; changed.emit("construction"); return true
func remove_selected() -> void:
	if selected_id.is_empty(): return
	for i in data.objects.size():
		if str(data.objects[i].id) == selected_id:
			if str(data.get("recon_target", "")) == selected_id: data["recon_target"] = ""
			data.objects.remove_at(i); selected_id = ""; dirty = true; changed.emit("objects"); return
func set_position(id: String, p: Vector2) -> void:
	var row := find_object(id)
	if row.is_empty() or not p.is_finite(): return
	var e := extent() -0.5; var minx := 0.0; var maxx := 0.0; var minz := 0.0; var maxz := 0.0
	for pt in row.get("path", []):
		minx = minf(minx, float(pt[0])); maxx = maxf(maxx, float(pt[0])); minz = minf(minz, float(pt[1])); maxz = maxf(maxz, float(pt[1]))
	row.x = clampf(p.x, -e - minx, e - maxx); row.z = clampf(p.y, -e - minz, e - maxz)
	dirty = true; changed.emit("pose")
func set_value(id: String, key: String, value: Variant) -> void:
	var row := find_object(id)
	if row.is_empty() or key not in ["name", "height", "yaw_deg", "pitch_deg", "roll_deg", "scale", "faction", "speed_mps", "route_face", "animation_source", "animation_clip", "animation_loop", "animation_speed", "animation_own", "animation_displacement", "animation_range", "texture", "brick_scale", "wall_height", "path_width"]: return
	match key:
		"animation_displacement": value = clampf(float(value), 0.0, 20.0)
		"animation_range": value = clampf(float(value), 2.0, 400.0)
		"animation_own": value = bool(value)
		"brick_scale": value = clampf(float(value), BRICK_MIN, BRICK_MAX)
		"wall_height": value = clampf(float(value), WALL_MIN, WALL_MAX)
		"path_width": value = clampf(float(value), 2.0, 25.0)
	row[key] = value; dirty = true; changed.emit("properties")



func nudge_size(id: String, key: String, delta: float) -> float:
	var row := find_object(id)
	if row.is_empty(): return 0.0
	var limits: Dictionary = { "brick_scale": [BRICK_MIN, BRICK_MAX], "wall_height": [WALL_MIN, WALL_MAX], "path_width": [2.0, 25.0]}
	if not limits.has(key): return 0.0
	var current := float(row.get(key, 1.0))
	var next_value := clampf(current + delta, float(limits[key][0]), float(limits[key][1]))
	set_value(id, key, next_value)
	return next_value
func set_flag(id: String, key: String, value: bool) -> bool:
	if key not in ["locked", "hidden"]: return false
	var row := find_object(id)
	if row.is_empty(): return false
	row[key] = value; dirty = true; changed.emit("flags"); return true
func visible_objects() -> Array:
	var out: Array = []
	for row: Dictionary in data.get("objects", []):
		if not bool(row.get("hidden", false)): out.append(row)
	return out
func bounded_objects() -> void:
	var e := extent() -0.5
	for row: Dictionary in data.get("objects", []):
		row.x = clampf(float(row.x), -e, e); row.z = clampf(float(row.z), -e, e)
func restore_snapshot(snapshot: Dictionary, selected: String) -> void:
	if snapshot.is_empty(): return
	data = snapshot.duplicate(true)
	_paint_image = null; _paint_dirty = false; _paint_stroke_active = false; _paint_undo.clear()
	_terrain_undo.clear()
	selected_id = selected if not find_object(selected).is_empty() else ""
	dirty = true
	changed.emit("history")
func set_mission(key: String, value: Variant) -> void:
	if key not in ["name", "region", "start_hour", "start_minute", "briefing", "objectives", "recon_target", "terrain_texture", "terrain_tile_m"]: return
	data[key] = value; dirty = true; changed.emit("mission")
func add_waypoint(id: String, p: Vector2, minimum_distance := 0.0) -> bool:
	var row := find_object(id)
	if row.is_empty() or str(row.get("asset", "")) in ["road_path", "brick_wall"] or not p.is_finite() or row.route.size() >= MAX_ROUTE_POINTS: return false
	p = bounded(p); var last := Vector2(float(row.x), float(row.z))
	if not row.route.is_empty(): last = Vector2(float(row.route[-1][0]), float(row.route[-1][1]))
	if p.distance_to(last) < minimum_distance: return false
	row.route.append([p.x, p.y]); dirty = true; changed.emit("route"); return true
func undo_waypoint(id: String) -> void:
	var row := find_object(id)
	if row.is_empty() or row.route.is_empty(): return
	row.route.pop_back(); dirty = true; changed.emit("route")
func reverse_route(id: String) -> void:
	var row := find_object(id)
	if row.is_empty() or row.route.size() < 2: return
	row.route.reverse(); dirty = true; changed.emit("route")
func clear_route(id: String) -> void:
	var row := find_object(id)
	if row.is_empty(): return
	row.route = []; dirty = true; changed.emit("route")
func remember_terrain_stroke() -> void:
	if not data.has("terrain"): return
	_terrain_undo.append(data.terrain.duplicate(true))
	if _terrain_undo.size() > 12: _terrain_undo.pop_front()
func undo_terrain_stroke() -> bool:
	if _terrain_undo.is_empty() or not data.has("terrain"): return false
	data.terrain = _terrain_undo.pop_back(); dirty = true; changed.emit("terrain"); return true
func sculpt_terrain(p: Vector2, radius: float, strength: float, tool: String, flatten_to: float = NAN) -> bool:
	if not data.has("terrain") or not Terrain.sculpt(data.terrain, p, radius, strength, tool, flatten_to): return false
	dirty = true; changed.emit("terrain"); return true
func paint_image() -> Image:
	if _paint_image != null: return _paint_image
	var value: Dictionary = data.get("terrain_paint", {})
	if not value.is_empty(): _paint_image = Paint.decode(value.get("mask", ""))
	return _paint_image
func begin_paint_stroke(texture_id: String, erase := false) -> Dictionary:
	finish_paint_stroke()
	var existing: Dictionary = data.get("terrain_paint", {})
	if erase and existing.is_empty(): return { "ok": false, "error": "There is no terrain paint to erase."}
	if not erase:
		if texture_id.is_empty() or not custom_assets.has(texture_id) or str(custom_assets[texture_id].get("category", "")) != "texture": return { "ok": false, "error": "Import and choose a paint texture in the right panel first."}
		if not existing.is_empty() and texture_id not in existing.layers and existing.layers.size() >= Paint.MAX_LAYERS: return { "ok": false, "error": "Four paint textures are already in use. Clear paint to choose new layers."}
	_paint_before = null if existing.is_empty() else existing.duplicate(true)
	_paint_stroke_active = true; _paint_stroke_changed = false
	if existing.is_empty():
		_paint_image = Paint.blank(); data["terrain_paint"] = { "resolution": Paint.MASK_SIZE, "layers": [], "mask": Paint.encode(_paint_image)}
	elif paint_image() == null:
		_paint_stroke_active = false; return { "ok": false, "error": "The existing paint mask is invalid."}
	if not erase and texture_id not in data.terrain_paint.layers: data.terrain_paint.layers.append(texture_id)
	return { "ok": true, "error": ""}
func paint_terrain(p: Vector2, radius: float, strength: float, texture_id: String, erase := false) -> bool:
	return paint_terrain_segment(p, p, radius, strength, texture_id, erase)
func paint_terrain_segment(from: Vector2, to: Vector2, radius: float, strength: float, texture_id: String, erase := false) -> bool:
	if not _paint_stroke_active or not data.has("terrain_paint"): return false
	var layer: int = -1 if erase else data.terrain_paint.layers.find(texture_id)
	if not erase and layer < 0: return false
	var image := paint_image()
	if image == null or not Paint.stroke_segment(image, extent(), from, to, radius, strength, layer): return false
	_paint_stroke_changed = true; _paint_dirty = true; dirty = true; changed.emit("paint"); return true
func commit_paint() -> void:
	if _paint_dirty and _paint_image != null and data.has("terrain_paint"):
		data.terrain_paint.mask = Paint.encode(_paint_image); _paint_dirty = false
func finish_paint_stroke() -> void:
	if not _paint_stroke_active: return
	if _paint_stroke_changed:
		commit_paint(); _paint_undo.append(_paint_before)
		if _paint_undo.size() > 10: _paint_undo.pop_front()
	else:
		if _paint_before == null: data.erase("terrain_paint")
		else: data["terrain_paint"] = _paint_before
		_paint_image = null; _paint_dirty = false
	_paint_before = null; _paint_stroke_active = false; _paint_stroke_changed = false
	changed.emit("paint")
func undo_paint_stroke() -> bool:
	finish_paint_stroke()
	if _paint_undo.is_empty(): return false
	var previous = _paint_undo.pop_back()
	if previous == null: data.erase("terrain_paint")
	else: data["terrain_paint"] = previous
	_paint_image = null; _paint_dirty = false; dirty = true; changed.emit("paint"); return true
func remove_terrain_paint_layer(texture_id: String) -> bool:
	finish_paint_stroke()
	if not data.has("terrain_paint") or texture_id.is_empty(): return false
	var layers: Array = data.terrain_paint.layers; var index := layers.find(texture_id)
	if index < 0: return false
	var image := paint_image(); var shifted := Paint.without_layer(image, index)
	if shifted == null: return false
	_paint_undo.append(data.terrain_paint.duplicate(true))
	if _paint_undo.size() > 10: _paint_undo.pop_front()
	layers.remove_at(index)
	if layers.is_empty(): data.erase("terrain_paint"); _paint_image = null; _paint_dirty = false
	else: _paint_image = shifted; _paint_dirty = true; commit_paint()
	dirty = true; changed.emit("paint"); return true
func clear_terrain_paint() -> bool:
	finish_paint_stroke()
	if not data.has("terrain_paint"): return false
	_paint_undo.append(data.terrain_paint.duplicate(true))
	if _paint_undo.size() > 10: _paint_undo.pop_front()
	data.erase("terrain_paint"); _paint_image = null; _paint_dirty = false; dirty = true; changed.emit("paint"); return true
func grow_terrain() -> bool:
	finish_paint_stroke()
	var old_extent := extent(); var image := paint_image(); var expanded := Terrain.grow(data.get("terrain", {}))
	if expanded.is_empty(): return false

	if image != null:
		_paint_image = Paint.expanded(image, old_extent, float(expanded.extent)); _paint_dirty = true
	_terrain_undo.clear(); _paint_undo.clear(); data.terrain = expanded; commit_paint(); dirty = true; changed.emit("terrain"); return true


func set_terrain_size(target_extent: float) -> bool:
	finish_paint_stroke()
	var current: Dictionary = data.get("terrain", {})
	if not Terrain.valid(current): return false
	var old_extent := extent()
	if absf(old_extent - target_extent) < 0.5: return false
	var image := paint_image()
	var resized := Terrain.set_extent(current, target_extent)
	if resized.is_empty(): return false
	if image != null:
		_paint_image = Paint.expanded(image, old_extent, float(resized.extent)); _paint_dirty = true
	_terrain_undo.clear(); _paint_undo.clear()
	data.terrain = resized
	bounded_objects(); commit_paint(); dirty = true; changed.emit("terrain")
	return true


func grow_left() -> int:
	var now := extent()
	var remaining := 0
	for step: Dictionary in Terrain.SIZE_STEPS:
		if float(step.extent) > now + 0.5: remaining += 1
	return remaining

func replace_loaded(new_data: Dictionary, new_assets: Dictionary) -> void:
	data = new_data.duplicate(true); custom_assets = new_assets.duplicate(true); selected_id = ""; _next_id = 1; _terrain_undo.clear(); _paint_undo.clear(); _paint_image = null; _paint_dirty = false; _paint_stroke_active = false

	if not data.has("terrain"): data["terrain"] = Terrain.empty()
	data["background"] = "blank"
	for row: Dictionary in data.get("objects", []):
		var suffix := str(row.get("id", "")).trim_prefix("object_")
		if suffix.is_valid_int(): _next_id = maxi(_next_id, int(suffix) +1)
	if not data.objects.is_empty(): selected_id = str(data.objects[0].id)
	dirty = false; changed.emit("loaded")




var _snow_image: Image
var _snow_dirty := false
var _snow_stroke_active := false
var _snow_stroke_changed := false
var _snow_before: Variant = null
var _snow_undo: Array = []

func snow_image() -> Image:
	if _snow_image != null: return _snow_image
	var value: Dictionary = data.get("snow_paint", {})
	if not value.is_empty(): _snow_image = Paint.snow_decode(value.get("mask", ""))
	return _snow_image

var _snow_present_key := ""
var _snow_present_value := false



func snow_painted() -> bool:
	if not data.has("snow_paint"):
		_snow_present_key = ""; _snow_present_value = false; return false
	var mask := str(data.snow_paint.get("mask", ""))
	if mask == _snow_present_key: return _snow_present_value
	_snow_present_key = mask; _snow_present_value = Paint.snow_present(mask)
	return _snow_present_value

func begin_snow_stroke(erase := false) -> Dictionary:
	finish_snow_stroke()
	var existing: Dictionary = data.get("snow_paint", {})
	if erase and existing.is_empty(): return { "ok": false, "error": "There is no painted snow to erase."}
	_snow_before = null if existing.is_empty() else existing.duplicate(true)
	_snow_stroke_active = true; _snow_stroke_changed = false
	if existing.is_empty():
		_snow_image = Paint.snow_blank()
		data["snow_paint"] = { "resolution": Paint.SNOW_SIZE, "mask": Paint.snow_encode(_snow_image)}
	elif snow_image() == null:
		_snow_stroke_active = false; return { "ok": false, "error": "The existing snow mask is invalid."}
	return { "ok": true, "error": ""}

func paint_snow(p: Vector2, radius: float, strength: float, erase := false) -> bool:
	return paint_snow_segment(p, p, radius, strength, erase)
func paint_snow_segment(from: Vector2, to: Vector2, radius: float, strength: float, erase := false) -> bool:
	if not _snow_stroke_active or not data.has("snow_paint"): return false
	var image := snow_image()
	if image == null or not Paint.snow_stroke(image, extent(), from, to, radius, strength, erase): return false
	_snow_stroke_changed = true; _snow_dirty = true; dirty = true; changed.emit("snow"); return true

func commit_snow() -> void:
	if _snow_dirty and _snow_image != null and data.has("snow_paint"):
		data.snow_paint.mask = Paint.snow_encode(_snow_image); _snow_dirty = false

func finish_snow_stroke() -> void:
	if not _snow_stroke_active: return
	if _snow_stroke_changed:
		commit_snow(); _snow_undo.append(_snow_before)
		if _snow_undo.size() > 10: _snow_undo.pop_front()
	else:
		if _snow_before == null: data.erase("snow_paint")
		else: data["snow_paint"] = _snow_before
		_snow_image = null; _snow_dirty = false
	_snow_before = null; _snow_stroke_active = false; _snow_stroke_changed = false
	changed.emit("snow")

func undo_snow_stroke() -> bool:
	finish_snow_stroke()
	if _snow_undo.is_empty(): return false
	var previous = _snow_undo.pop_back()
	if previous == null: data.erase("snow_paint")
	else: data["snow_paint"] = previous
	_snow_image = null; _snow_dirty = false; dirty = true; changed.emit("snow"); return true

func clear_snow() -> bool:
	if not data.has("snow_paint"): return false
	_snow_undo.append(data.snow_paint.duplicate(true))
	if _snow_undo.size() > 10: _snow_undo.pop_front()
	data.erase("snow_paint"); _snow_image = null; _snow_dirty = false; dirty = true; changed.emit("snow"); return true
