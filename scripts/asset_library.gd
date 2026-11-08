extends RefCounted


const Codec = preload("res://scripts/glb_codec.gd")
const Terrain = preload("res://scripts/terrain_model.gd")
const BUILTINS = [
	{ "id": "brick_block", "name": "Brick block", "kind": "Individual wall block; use DRAW WALL for auto-laid bricks"},
	{ "id": "house", "name": "Desert house", "kind": "Placeholder"},
	{ "id": "compound", "name": "House compound", "kind": "Placeholder"},
	{ "id": "humvee", "name": "Humvee", "kind": "Placeholder"},
	{ "id": "technical", "name": "Technical truck", "kind": "Uploaded model"},
	{ "id": "civilian", "name": "Civilian", "kind": "Uploaded model · static"},
	{ "id": "soldier", "name": "Soldier", "kind": "Placeholder"},
	{ "id": "tb2", "name": "Bayraktar TB2", "kind": "Uploaded model"},
	{ "id": "drone_start", "name": "Drone air start", "kind": "Fly-test start point"},
	{ "id": "terrain_hill", "name": "Terrain: hill", "kind": "Movable terrain piece"},
	{ "id": "terrain_mountain", "name": "Terrain: mountain", "kind": "Movable terrain piece"},
	{ "id": "terrain_plateau", "name": "Terrain: plateau", "kind": "Movable terrain piece"},
]
const SOURCE = { "technical": "res://assets/technical.bin", "civilian": "res://assets/civilian.bin", "tb2": "res://assets/tb2.bin"}
const TARGET_EXTENT = { "technical": 5.4, "civilian": 1.8, "tb2": 12.0}
var templates: Dictionary = {}

func clear_templates() -> void:
	for template in templates.values():
		if is_instance_valid(template): template.free()
	templates.clear()

func entries(custom: Dictionary) -> Array:
	var out := BUILTINS.duplicate(true); var keys := custom.keys(); keys.sort()
	for key in keys:
		if str(custom[key].get("category", "model")) == "model": out.append({ "id": str(key), "name": str(custom[key].get("name", "Imported GLB")), "kind": "Imported model"})
	return out

func known(id: String, custom: Dictionary) -> bool:
	if id in ["road_path", "brick_wall"]: return true
	if custom.has(id) and str(custom[id].get("category", "model")) == "model": return true
	for row: Dictionary in BUILTINS:
		if row.id == id: return true
	return false

func label_for(id: String, custom: Dictionary) -> String:
	for row: Dictionary in entries(custom):
		if row.id == id: return str(row.name)
	return "Missing asset"



var last_error := ""



func create_visual(id: String, custom: Dictionary, strict := false) -> Node3D:
	if Terrain.is_feature(id): return _terrain_handle()
	if id == "drone_start": return _start_handle()
	if id in ["brick_block", "house", "compound", "humvee", "soldier"]: return _primitive(id)
	if templates.has(id): return templates[id].duplicate(0)
	var bytes := PackedByteArray()
	if SOURCE.has(id): bytes = FileAccess.get_file_as_bytes(str(SOURCE[id]))
	elif custom.has(id): bytes = custom[id].get("bytes", PackedByteArray())
	var imported: Dictionary = Codec.import_model(bytes)
	if not imported.ok:
		last_error = "%s: %s" % [label_for(id, custom), str(imported.get("error", ""))]
		push_warning("Could not display asset %s: %s" % [id, imported.get("error", "")])
		if strict: return null
		return _primitive("missing")
	var model := imported.model as Node3D
	for p: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false): p.stop(); p.active = false
	var root := Node3D.new(); root.name = "AssetVisual"; var pivot := Node3D.new(); root.add_child(pivot); pivot.add_child(model)
	var box := AABB(); var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null: continue
		var pose := Transform3D.IDENTITY; var current: Node = mesh
		while current != pivot and current != null:
			if current is Node3D: pose = (current as Node3D).transform * pose
			current = current.get_parent()
		var b: AABB = pose * mesh.get_aabb()
		if not b.position.is_finite() or not b.size.is_finite(): continue
		box = b if first else box.merge(b); first = false
	if not first and box.size.length() > 1e-05:
		var largest := maxf(box.size.x, maxf(box.size.y, box.size.z))
		var factor: float = clampf(float(TARGET_EXTENT[id]) / largest, 1e-05, 10000.0) if TARGET_EXTENT.has(id) else 1.0
		pivot.scale = Vector3.ONE * factor
		pivot.position = Vector3(- box.get_center().x, -box.position.y, -box.get_center().z) * factor
	templates[id] = root
	return root.duplicate(0)

func _start_handle() -> Node3D:
	var root := Node3D.new(); root.name = "AirStartHandle"
	var ring := MeshInstance3D.new(); var mesh := TorusMesh.new(); mesh.inner_radius = 5.0; mesh.outer_radius = 6.0; ring.mesh = mesh; ring.material_override = _mat(Color("77d5fb")); root.add_child(ring)
	_box(root, Vector3(1.0, 8.0, 1.0), Vector3(0, 4, 0), Color("77d5fb")); return root
func _terrain_handle() -> Node3D:
	var root := Node3D.new(); root.name = "TerrainMoveHandle"
	var ball := MeshInstance3D.new(); var sphere := SphereMesh.new(); sphere.radius = 2.5; sphere.height = 5.0; ball.mesh = sphere; ball.position.y = 3.0; ball.material_override = _mat(Color("f3b966")); root.add_child(ball)
	return root
func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = color; m.roughness = 0.9; return m
func _box(parent: Node3D, size_: Vector3, pos_: Vector3, color: Color) -> void:
	var m := BoxMesh.new(); m.size = size_; var part := MeshInstance3D.new(); part.mesh = m; part.material_override = _mat(color); part.position = pos_; parent.add_child(part)
func _primitive(id: String) -> Node3D:
	var root := Node3D.new(); root.name = "AssetVisual"
	var wall := Color("cdb899"); var roof := Color("9b8366"); var dark := Color("3a4344"); var glass := Color("415b63")
	if id == "brick_block":
		_box(root, Vector3(0.775, 0.238, 0.36), Vector3(0, 0.125, 0), Color("c4ab8a"))
	elif id == "house" or id == "compound":
		_box(root, Vector3(13, 5.6, 11), Vector3(0, 2.8, 0), wall); _box(root, Vector3(13.4, 0.5, 11.4), Vector3(0, 5.8, 0), roof)
		_box(root, Vector3(1.7, 2.8, 0.15), Vector3(0, 1.4, 5.56), dark)
		for x in [-3.8, 3.8]: _box(root, Vector3(1.5, 1.5, 0.16), Vector3(x, 3.3, 5.58), glass)
		if id == "compound":
			for x in [-12.0, 12.0]: _box(root, Vector3(0.35, 2.0, 23), Vector3(x, 1, 0), wall)
			for z in [-11.5, 11.5]: _box(root, Vector3(24, 2.0, 0.35), Vector3(0, 1, z), wall)
	elif id == "humvee":
		_box(root, Vector3(2.2, 1.3, 4.3), Vector3(0, 1.1, 0), Color("947e5d")); _box(root, Vector3(1.85, 1.0, 2.1), Vector3(0, 2, 0), Color("aa9470")); _box(root, Vector3(1.65, 0.55, 0.12), Vector3(0, 2.1, 1.08), glass)
		for x in [-1.1, 1.1]:
			for z in [-1.4, 1.4]: _box(root, Vector3(0.45, 0.75, 0.8), Vector3(x, 0.45, z), dark)
	elif id == "soldier":
		_box(root, Vector3(0.58, 1.1, 0.35), Vector3(0, 1.1, 0), Color("637453")); _box(root, Vector3(0.35, 0.35, 0.35), Vector3(0, 1.83, 0), Color("b69873")); _box(root, Vector3(0.22, 0.65, 0.25), Vector3(- 0.17, 0.35, 0), Color("596849")); _box(root, Vector3(0.22, 0.65, 0.25), Vector3(0.17, 0.35, 0), Color("596849"))
	else: _box(root, Vector3(2, 2, 2), Vector3(0, 1, 0), Color("d65f70"))
	return root
