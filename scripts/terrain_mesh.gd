extends RefCounted

const Terrain = preload("res://scripts/terrain_model.gd")
static func build(terrain: Dictionary, objects: Array) -> ArrayMesh:
	var n := int(terrain.get("resolution", Terrain.RESOLUTION)); var extent := float(terrain.get("extent", Terrain.EXTENT)); var step := 2.0 * extent / (n - 1)
	var features: Array = []
	for row in objects:
		if row is Dictionary and Terrain.is_feature(str(row.get("asset", ""))): features.append(row)
	var vertices := PackedVector3Array(); vertices.resize(n * n)
	var normals := PackedVector3Array(); normals.resize(n * n)
	var uvs := PackedVector2Array(); uvs.resize(n * n)
	for j in n:
		for i in n:
			var x: float = -extent + i * step; var z: float = -extent + j * step; var k := j * n + i
			vertices[k] = Vector3(x, Terrain.height_at(terrain, features, x, z), z); uvs[k] = Vector2(float(i) / (n - 1), float(j) / (n - 1))
	for j in n:
		for i in n:
			var left: float = vertices[j * n + maxi(i - 1, 0)].y; var right: float = vertices[j * n + mini(i + 1, n - 1)].y
			var up: float = vertices[maxi(j - 1, 0) * n + i].y; var down: float = vertices[mini(j + 1, n - 1) * n + i].y
			normals[j * n + i] = Vector3(left - right, 2.0 * step, up - down).normalized()
	var indices := PackedInt32Array(); indices.resize((n - 1) * (n - 1) * 6); var offset := 0
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i; var b := a + 1; var c := a + n; var d := c + 1

			indices[offset] = a; indices[offset + 1] = b; indices[offset + 2] = c; indices[offset + 3] = b; indices[offset + 4] = d; indices[offset + 5] = c; offset += 6
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_TEX_UV] = uvs; arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays); return mesh
