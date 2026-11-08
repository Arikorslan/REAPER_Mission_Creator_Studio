extends RefCounted






const Codec = preload("res://scripts/glb_codec.gd")

const SIZE := 72
const PER_REFRESH := 4
static var _cache: Dictionary = {}
static var _pending: Array = []
static var _busy := false

static func cached(id: String) -> Texture2D:
	return _cache.get(id, null)


static func cache_size() -> int:
	return _cache.size()

static func clear() -> void:
	_cache.clear()
	_pending.clear()


static func request(host: Node, assets: Dictionary) -> void:
	if host == null or not host.is_inside_tree():
		return
	if DisplayServer.get_name() == "headless":
		return
	for key in assets.keys():
		var id := str(key)
		if _cache.has(id) or _pending.has(id):
			continue
		if str(assets[key].get("category", "model")) != "model":
			continue
		_pending.append(id)
	if not _busy and not _pending.is_empty():
		_pump.call_deferred(host, assets)

static func _pump(host: Node, assets: Dictionary) -> void:
	if _busy or not is_instance_valid(host):
		return
	_busy = true
	var made := 0
	while made < PER_REFRESH and not _pending.is_empty():
		var id: String = str(_pending.pop_front())
		if not assets.has(id):
			continue
		var texture := await render(host, assets[id].get("bytes", PackedByteArray()))
		if texture != null:
			_cache[id] = texture
			made += 1
	_busy = false
	if not _pending.is_empty():
		_pump.call_deferred(host, assets)


static func render(host: Node, bytes: PackedByteArray) -> Texture2D:
	if host == null or bytes.is_empty():
		return null
	var imported := Codec.import_model(bytes)
	if not bool(imported.ok):
		return null
	var model: Node3D = imported.model
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.own_world_3d = true
	host.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	stage.add_child(model)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, -38, 0)
	light.light_energy = 1.15
	stage.add_child(light)
	var fill := OmniLight3D.new()
	fill.light_energy = 0.7
	fill.position = Vector3(2, 3, 2)
	stage.add_child(fill)
	var camera := Camera3D.new()
	camera.fov = 40
	stage.add_child(camera)
	camera.current = true
	var box := _bounds(model)
	var radius := maxf(box.size.length(), 0.5)
	var centre := box.get_center()
	camera.position = centre + Vector3(radius * 1.1, radius * 0.75, radius * 1.5)
	camera.look_at(centre, Vector3.UP)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	if image == null or image.is_empty():
		return null
	image.resize(SIZE, SIZE, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(image)

static func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var world := mesh.global_transform
		var local := mesh.get_aabb()
		var scaled := AABB(world * local.position, local.size * world.basis.get_scale())
		box = scaled if first else box.merge(scaled)
		first = false
	if first or box.size.length() <= 0.0001:
		return AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))
	return box
