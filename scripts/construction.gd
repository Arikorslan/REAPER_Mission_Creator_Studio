extends RefCounted

const Terrain = preload("res://scripts/terrain_model.gd")
const MAX_BRICKS := 8000
static func _point(v: Array) -> Vector2: return Vector2(float(v[0]), float(v[1]))
static func _height(terrain: Dictionary, objects: Array, origin: Vector2, p: Vector2) -> float:
	return Terrain.height_at(terrain, objects, origin.x + p.x, origin.y + p.y)
static func _mat(color: Color, vertex_color := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = color; m.roughness = 0.95; m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.vertex_color_use_as_albedo = vertex_color; return m
static func build(row: Dictionary, terrain: Dictionary, objects: Array) -> Node3D:
	var root := Node3D.new(); root.name = "DrawnConstruction"
	var path: Array = row.get("path", [])
	if path.size() < 2: return root
	var origin := Vector2(float(row.x), float(row.z))
	if str(row.asset) == "road_path": _make_road(root, path, origin, terrain, objects, clampf(float(row.get("path_width", 8.0)), 2, 25))
	elif str(row.asset) == "brick_wall": _make_wall(root, path, origin, terrain, objects, clampf(float(row.get("wall_height", 2.0)), 0.25, 12.0), clampf(float(row.get("brick_scale", 1.0)), 0.4, 3.0))
	return root
static func _make_road(root: Node3D, path: Array, origin: Vector2, terrain: Dictionary, objects: Array, width: float) -> void:
	var samples: Array = []
	for i in path.size() -1:
		var a := _point(path[i]); var b := _point(path[i + 1]); var d := a.distance_to(b)
		if d < 0.001: continue
		var steps := maxi(1, int(ceil(d / 12.0)))
		for j in steps: samples.append(a.lerp(b, float(j) / steps))
	samples.append(_point(path[-1]))
	if samples.size() < 2: return
	var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var uvs := PackedVector2Array(); var indices := PackedInt32Array()
	for i in samples.size():
		var previous: Vector2 = samples[maxi(0, i - 1)]; var next: Vector2 = samples[mini(samples.size() -1, i + 1)]; var direction: Vector2 = (next - previous).normalized()
		if direction.length_squared() < 0.001: direction = Vector2.RIGHT
		var across := Vector2(- direction.y, direction.x) * width * 0.5; var p: Vector2 = samples[i]
		for side in [-1, 1]:
			var q: Vector2 = p + across * float(side); vertices.append(Vector3(q.x, _height(terrain, objects, origin, q) +0.18, q.y)); normals.append(Vector3.UP); uvs.append(Vector2(float(side + 1) * 0.5, float(i)))
	for i in samples.size() -1:
		var a := i * 2; var b := a + 1; var c := a + 2; var d := a + 3
		indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_TEX_UV] = uvs; arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new(); instance.name = "TerrainFollowingRoad"; instance.mesh = mesh; instance.material_override = _mat(Color("716e65")); root.add_child(instance)


static func _make_wall(root: Node3D, path: Array, origin: Vector2, terrain: Dictionary, objects: Array, wall_height: float, brick_scale := 1.0) -> void:
	var block_length := 0.8 * brick_scale; var block_height := 0.25 * brick_scale; var thickness := 0.36 * brick_scale
	var courses := clampi(int(ceil(wall_height / block_height)), 2, 80)
	var placements: Array = []
	for i in path.size() -1:
		var a := _point(path[i]); var b := _point(path[i + 1]); var d := a.distance_to(b)
		if d < 0.001: continue
		var direction: Vector2 = (b - a) / d; var angle := atan2(- direction.y, direction.x)
		for course in courses:
			var distance := block_length * (0.5 if course % 2 == 0 else 1.0)
			while distance < d and placements.size() < MAX_BRICKS:
				var p := a + direction * distance; var h := _height(terrain, objects, origin, p) +course * block_height + block_height * 0.5
				placements.append({ "transform": Transform3D(Basis(Vector3.UP, angle), Vector3(p.x, h, p.y)), "shade": float((i * 7 + course * 13 + int(distance / block_length)) % 5)})
				distance += block_length
	var brick := BoxMesh.new(); brick.size = Vector3(block_length - 0.025 * minf(brick_scale, 1.0), block_height - 0.012 * minf(brick_scale, 1.0), thickness); brick.material = _mat(Color.WHITE, true)
	var multi := MultiMesh.new(); multi.transform_format = MultiMesh.TRANSFORM_3D; multi.use_colors = true; multi.mesh = brick; multi.instance_count = placements.size()
	for i in placements.size():
		multi.set_instance_transform(i, placements[i].transform)
		var shade: float = placements[i].shade * 0.016; multi.set_instance_color(i, Color(0.72 + shade, 0.65 + shade, 0.54 + shade, 1))
	var instance := MultiMeshInstance3D.new(); instance.name = "AutoLaidBricks"; instance.multimesh = multi; root.add_child(instance)
