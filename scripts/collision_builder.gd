extends RefCounted








const Terrain = preload("res://scripts/terrain_model.gd")


const NOT_SOLID := ["drone_start", "terrain_hill", "terrain_mountain", "terrain_plateau", "road_path"]

static func is_solid(asset: String) -> bool:
	return not (asset in NOT_SOLID)



static func boxes_from_visual(root: Node3D) -> Array:
	if root == null: return []
	var boxes: Array = []
	_collect(root, Transform3D.IDENTITY, boxes)
	return boxes

static func _collect(node: Node, transform: Transform3D, boxes: Array) -> void:
	if boxes.size() >= 8: return
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var box: AABB = transform * mesh_instance.get_aabb()
			if box.position.is_finite() and box.size.is_finite() and box.size.length() >= 0.02:
				boxes.append({ "size": box.size, "position": box.get_center()})
	for child in node.get_children():
		if child is Node3D: _collect(child, transform * (child as Node3D).transform, boxes)



static func merged_box(boxes: Array) -> Dictionary:
	if boxes.is_empty(): return {}
	var merged := AABB(boxes[0].position - boxes[0].size * 0.5, boxes[0].size)
	for i in range(1, boxes.size()):
		merged = merged.merge(AABB(boxes[i].position - boxes[i].size * 0.5, boxes[i].size))
	return { "size": merged.size, "position": merged.get_center()}




static func object_boxes(row: Dictionary, visual: Node3D) -> Array:
	var asset := str(row.get("asset", ""))
	if not is_solid(asset): return []
	if asset in ["road_path", "brick_wall"]: return []
	if visual == null: return []
	var boxes := boxes_from_visual(visual)
	if boxes.is_empty(): return [{ "size": Vector3(3, 3, 3), "position": Vector3(0, 1.5, 0)}]
	return boxes



static func wall_boxes(row: Dictionary, terrain: Dictionary, objects: Array) -> Array:
	var path: Array = row.get("path", [])
	if path.size() < 2: return []
	var origin := Vector2(float(row.get("x", 0)), float(row.get("z", 0)))
	var brick := clampf(float(row.get("brick_scale", 1.0)), 0.4, 3.0)
	var height := clampf(float(row.get("wall_height", 2.0)), 0.25, 12.0)
	var thickness := 0.36 * brick
	var out: Array = []
	for i in path.size() -1:
		var a := Vector2(float(path[i][0]), float(path[i][1]))
		var b := Vector2(float(path[i + 1][0]), float(path[i + 1][1]))
		var length := a.distance_to(b)
		if length < 0.01: continue
		var middle: Vector2 = (a + b) * 0.5
		var ground := Terrain.height_at(terrain, objects, origin.x + middle.x, origin.y + middle.y)
		var angle := atan2(- (b - a).y, (b - a).x)
		out.append({
			"size": Vector3(length + thickness, height, thickness),
			"position": Vector3(origin.x + middle.x, ground + height * 0.5, origin.y + middle.y),
			"rotation": Vector3(0, angle, 0)
		})
	return out


static func scene_boxes(data: Dictionary) -> Array:
	var terrain: Dictionary = data.get("terrain", {})
	var objects: Array = data.get("objects", [])
	var out: Array = []
	for row: Dictionary in objects:
		var asset := str(row.get("asset", ""))
		if asset == "brick_wall":
			out.append_array(wall_boxes(row, terrain, objects))
	return out




static func solid_height_at(data: Dictionary, x: float, z: float) -> float:
	var terrain: Dictionary = data.get("terrain", {})
	var objects: Array = data.get("objects", [])
	return Terrain.height_at(terrain, objects, x, z)
