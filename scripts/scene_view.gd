extends SubViewportContainer


const Terrain = preload("res://scripts/terrain_model.gd")
const TerrainMesh = preload("res://scripts/terrain_mesh.gd")
const Construction = preload("res://scripts/construction.gd")
const AnimationSupport = preload("res://scripts/animation_support.gd")
const TextureCodec = preload("res://scripts/texture_codec.gd")
const Paint = preload("res://scripts/terrain_paint.gd")
const CollisionBuilder = preload("res://scripts/collision_builder.gd")
const Walk = preload("res://scripts/walk_math.gd")
const Weather = preload("res://scripts/environment.gd")
signal asset_dropped(asset_id: String, position: Vector2)
signal preview_frame
signal flight_status(message: String)
signal walk_status(message: String)
signal walk_mode_changed(active: bool)
signal edit_feedback(message: String)
var fly_active := false
var touch_orbit := false
var flight
var fly_drone: Node3D
var fly_position := Vector2.ZERO
var aircraft_scale := 1.0


var walk_active := false
var walker: CharacterBody3D
var walk_look_yaw := 0.0
var walk_look_pitch := 0.0
var walk_on_ground := false
var walk_coyote := 0.0
var walk_vertical := 0.0
var walk_jump_queued := false
var walk_external: Dictionary = {}
var _walk_looking := false
var _camera_saved: Transform3D
var collision_root: Node3D
var solid_nodes: Dictionary = {}
var external_controls: Dictionary = {}
var preview_playing := false
var preview_positions: Dictionary = {}

var own_players: Dictionary = {}
var preview_elapsed := 0.0
var state
var library
var route_mode := false
var terrain_tool := "select"
var brush_radius := 90.0
var brush_strength := 8.0
var paint_texture_id := ""
var _painting := false
var _last_paint_point := Vector2.ZERO
var _sculpting := false
var _panning := false
var _left_pan := false
var _vertical_pan := false
var _drawing_route := false
var _stroke_id := ""
var _flatten_height := 0.0
var road_width := 8.0
var wall_height := 2.0
var _terrain_revision := 0
var animation_players: Dictionary = {}
var animation_results: Dictionary = {}
var texture_cache: Dictionary = {}
var paint_mask_texture: ImageTexture
var snow_mask_texture: ImageTexture
var white_texture: ImageTexture
var black_texture: ImageTexture
var _feature_signature := ""
var terrain_mesh: MeshInstance3D
var terrain_shape: CollisionShape3D
var background_root: Node3D
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var environment: Environment
var sun: DirectionalLight3D
var objects_root: Node3D
var route_visual: MeshInstance3D
var selection_ring: MeshInstance3D
var object_nodes: Dictionary = {}
var _drag_id := ""
var _drag_offset := Vector2.ZERO
var _orbiting := false
var _yaw: float = deg_to_rad(-35.0)
var _pitch: float = deg_to_rad(31.0)
var _distance := 570.0
var _target := Vector3(0, 0, 0)

func setup(shared, asset_library) -> void:
	state = shared; library = asset_library
	if is_inside_tree(): _connect_state()
func _connect_state() -> void:
	if state != null and not state.changed.is_connected(_state_changed): state.changed.connect(_state_changed)
func _ready() -> void:
	stretch = true; mouse_filter = Control.MOUSE_FILTER_STOP; tooltip_text = "Left-drag empty ground to pan; Shift+left-drag pans vertically. Drag objects to move. Right-drag orbits; wheel zooms."
	_make_world(); _connect_state(); _sync_objects()

func _mat(color: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = color; m.roughness = 0.9
	if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m
func _box(parent: Node3D, size_: Vector3, pos_: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new(); mesh.size = size_; var part := MeshInstance3D.new(); part.mesh = mesh; part.material_override = _mat(color); part.position = pos_; parent.add_child(part)

func _make_world() -> void:
	viewport = SubViewport.new(); viewport.name = "WorldViewport"; viewport.own_world_3d = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; viewport.size = Vector2i(1000, 640); add_child(viewport)
	world = Node3D.new(); world.name = "PreviewWorld"; viewport.add_child(world)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color("b7c9cf"); env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("d4d7c8"); env.ambient_light_energy = 0.38; env.tonemap_mode = Environment.TONE_MAPPER_LINEAR; env.tonemap_exposure = 0.55
	environment = env; var env_node := WorldEnvironment.new(); env_node.environment = env; world.add_child(env_node)
	sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-48, -35, 0); sun.light_energy = 0.75; sun.shadow_enabled = true; world.add_child(sun)
	weather_root = Node3D.new(); weather_root.name = "Weather"; world.add_child(weather_root)
	_make_weather_particles()
	_apply_time()
	_make_terrain()
	background_root = Node3D.new(); background_root.name = "LegacyDemoBackground"; world.add_child(background_root); _refresh_background()
	objects_root = Node3D.new(); objects_root.name = "MissionObjects"; world.add_child(objects_root)
	collision_root = Node3D.new(); collision_root.name = "SolidCollision"; world.add_child(collision_root)
	route_visual = MeshInstance3D.new(); route_visual.name = "SelectedRoute"; world.add_child(route_visual)
	var ring := TorusMesh.new(); ring.inner_radius = 4.8; ring.outer_radius = 5.25; ring.rings = 32; ring.ring_segments = 8
	selection_ring = MeshInstance3D.new(); selection_ring.mesh = ring; selection_ring.material_override = _mat(Color("7affd0"), true); selection_ring.visible = false; world.add_child(selection_ring)
	camera = Camera3D.new(); camera.fov = 43; camera.far = maxf(25000.0, state.extent() * 3.0); camera.near = 0.1; world.add_child(camera); camera.current = true; _update_camera()

func _height(x: float, z: float) -> float:
	if state == null: return 0.0
	return Terrain.height_at(state.data.get("terrain", {}), state.data.get("objects", []), x, z)
func _make_terrain() -> void:
	terrain_mesh = MeshInstance3D.new(); terrain_mesh.name = "EditableTerrain"
	var terrain_material := _mat(Color("baa986")); terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED; terrain_mesh.material_override = terrain_material; world.add_child(terrain_mesh)
	var terrain_body := StaticBody3D.new(); terrain_body.name = "EditableTerrainCollision"; world.add_child(terrain_body)
	terrain_shape = CollisionShape3D.new(); terrain_body.add_child(terrain_shape); _rebuild_terrain()
func _rebuild_terrain() -> void:
	if terrain_mesh == null or state == null: return
	var mesh := TerrainMesh.build(state.data.get("terrain", {}), state.data.get("objects", [])); terrain_mesh.mesh = mesh
	var collider := mesh.create_trimesh_shape(); collider.backface_collision = true; terrain_shape.shape = collider; _apply_terrain_texture()
func _texture(id: String) -> Texture2D:
	if id.is_empty() or not state.custom_assets.has(id): return null
	if not texture_cache.has(id): texture_cache[id] = TextureCodec.texture(state.custom_assets[id].get("bytes", PackedByteArray()))
	return texture_cache.get(id)
func _white_texture() -> ImageTexture:
	if white_texture == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8); image.fill(Color.WHITE); white_texture = ImageTexture.create_from_image(image)
	return white_texture



func refresh_terrain_texture() -> void: _apply_terrain_texture()

func _snow_mask_texture() -> ImageTexture:
	if state == null: return _black_texture()
	var image: Image = state.snow_image()
	if image == null: return _black_texture()
	if snow_mask_texture == null: snow_mask_texture = ImageTexture.create_from_image(image)
	else: snow_mask_texture.update(image)
	return snow_mask_texture

func _black_texture() -> ImageTexture:
	if black_texture == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8); image.fill(Color.BLACK); black_texture = ImageTexture.create_from_image(image)
	return black_texture

func _new_paint_material() -> ShaderMaterial:
	var shader := Shader.new(); shader.code = "\nshader_type spatial;\nrender_mode cull_disabled;\nuniform sampler2D base_tex : source_color, filter_linear_mipmap, repeat_enable;\nuniform sampler2D paint_mask : filter_linear, repeat_disable;\nuniform sampler2D snow_mask : filter_linear, repeat_disable;\nuniform sampler2D layer_0 : source_color, filter_linear_mipmap, repeat_enable;\nuniform sampler2D layer_1 : source_color, filter_linear_mipmap, repeat_enable;\nuniform sampler2D layer_2 : source_color, filter_linear_mipmap, repeat_enable;\nuniform sampler2D layer_3 : source_color, filter_linear_mipmap, repeat_enable;\nuniform vec4 base_color : source_color = vec4(1.0);\nuniform float texture_repeat = 1.0;\nuniform int layer_count = 0;\nuniform float snow_cover = 0.0;\nuniform vec4 snow_color : source_color = vec4(0.95,0.97,0.99,1.0);\nuniform float wetness = 0.0;\nvoid fragment() {\n vec2 tile_uv = UV * texture_repeat;\n vec4 mask = texture(paint_mask, UV);\n vec3 color = texture(base_tex, tile_uv).rgb * base_color.rgb;\n if (layer_count > 0) { color = mix(color, texture(layer_0, tile_uv).rgb, mask.r); }\n if (layer_count > 1) { color = mix(color, texture(layer_1, tile_uv).rgb, mask.g); }\n if (layer_count > 2) { color = mix(color, texture(layer_2, tile_uv).rgb, mask.b); }\n if (layer_count > 3) { color = mix(color, texture(layer_3, tile_uv).rgb, mask.a); }\n // Snow settles on flat ground first, so steep rock and walls stay bare.\n float flatness = clamp(NORMAL.y, 0.0, 1.0);\n float painted = texture(snow_mask, UV).r;\n float settle = max(smoothstep(0.45, 0.95, flatness) * snow_cover, painted * smoothstep(0.2, 0.62, flatness));\n color = mix(color, snow_color.rgb, settle);\n color *= 1.0 - 0.35 * wetness * (1.0 - settle);\n ALBEDO = color;\n ROUGHNESS = mix(0.9, 0.42, wetness * (1.0 - settle));\n}\n"

































	var material := ShaderMaterial.new(); material.shader = shader; return material
func _apply_terrain_texture() -> void:
	if terrain_mesh == null or state == null: return
	var base := _texture(str(state.data.get("terrain_texture", ""))); var tile := clampf(float(state.data.get("terrain_tile_m", 80)), 5, 500); var repeat: float = 2.0 * state.extent() / tile
	var paint: Dictionary = state.data.get("terrain_paint", {}); var layers: Array = paint.get("layers", []); var image: Image = state.paint_image() if not paint.is_empty() else null
	var snow_painted: bool = state.snow_painted()
	if (image == null or layers.is_empty()) and not snow_painted:
		if not terrain_mesh.material_override is StandardMaterial3D:
			var plain := _mat(Color("baa986")); plain.cull_mode = BaseMaterial3D.CULL_DISABLED; terrain_mesh.material_override = plain
		var normal := terrain_mesh.material_override as StandardMaterial3D
		var s := weather_settings()
		var cover := clampf(float(s.get("snow_cover", 0.0)), 0.0, 1.0)
		var wet := clampf(float(s.get("wet", 0.0)), 0.0, 1.0)
		var base_color := Color.WHITE if base != null else Color("baa986")
		normal.albedo_texture = base
		normal.albedo_color = base_color.lerp(Weather.cover_colour(s), cover * 0.92)
		normal.roughness = lerpf(0.9, 0.42, wet * (1.0 - cover))
		normal.uv1_scale = Vector3(repeat, repeat, 1)
		paint_mask_texture = null; return
	if not terrain_mesh.material_override is ShaderMaterial: terrain_mesh.material_override = _new_paint_material()
	var material := terrain_mesh.material_override as ShaderMaterial
	if paint_mask_texture == null: paint_mask_texture = ImageTexture.create_from_image(image)
	else: paint_mask_texture.update(image)
	material.set_shader_parameter("base_tex", base if base != null else _white_texture())
	material.set_shader_parameter("base_color", Color.WHITE if base != null else Color("baa986"))
	var settings := weather_settings()
	var cover := clampf(float(settings.get("snow_cover", 0.0)), 0.0, 1.0)
	var wet := clampf(float(settings.get("wet", 0.0)), 0.0, 1.0)
	material.set_shader_parameter("snow_cover", cover)
	material.set_shader_parameter("snow_color", Weather.cover_colour(settings))
	material.set_shader_parameter("wetness", wet)
	material.set_shader_parameter("snow_mask", _snow_mask_texture())
	material.set_shader_parameter("paint_mask", paint_mask_texture); material.set_shader_parameter("texture_repeat", repeat); material.set_shader_parameter("layer_count", layers.size())
	for i in Paint.MAX_LAYERS:
		var layer: Texture2D = _texture(str(layers[i])) if i < layers.size() else null
		material.set_shader_parameter("layer_" + str(i), layer if layer != null else _white_texture())

func _refresh_background() -> void:

	if background_root == null: return
	for child in background_root.get_children(): child.queue_free()

func _update_camera() -> void:
	if camera == null: return
	if walk_active: return
	var d := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	camera.position = _target + d; camera.look_at(_target, Vector3.UP)

var _time_override := -1.0
var weather_root: Node3D
var rain_particles: CPUParticles3D
var snow_particles: CPUParticles3D
var dust_particles: CPUParticles3D
var weather_clock := 0.0
var walk_height_scale := 1.0
var walk_capsule: CollisionShape3D
var _rotate_drag := false
var _snowing := false
var _last_snow_point := Vector2.ZERO
var _rotate_last := 0.0
var _sway_nodes: Array = []
var ground_grid: MeshInstance3D
var show_ground_grid := false
var multi_selected: Array = []
var multi_ring_nodes: Dictionary = {}



func preview_time(hours: float) -> void:
	_time_override = clampf(hours, 0.0, 24.0); _apply_time()
func commit_time(hours: float) -> void:
	_time_override = -1.0
	var hour := clampi(int(floor(hours)), 0, 23)
	var minute := clampi(int(round((hours - float(hour)) * 60.0)), 0, 59)
	state.data["start_hour"] = hour; state.data["start_minute"] = minute


	if state.data.has("environment"):
		state.data.environment["hour"] = clampf(hours, 0.0, 24.0)
	state.dirty = true; state.changed.emit("mission")
	apply_weather()
func set_multi_selection(ids: Array) -> void:
	multi_selected = ids
	_sync_objects()
func set_ground_grid(enabled: bool) -> void:
	show_ground_grid = enabled
	if ground_grid != null: ground_grid.queue_free(); ground_grid = null
	if not enabled or state == null or world == null: return
	var mesh := ImmediateMesh.new(); var material := _mat(Color("f2a33c"), true)
	var n := int(state.data.get("terrain", {}).get("resolution", 65)); var step := maxi(1, int(n / 8)); var extent: float = state.extent()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for j in range(0, n, step):
		var previous := Vector3.ZERO; var has_previous := false
		for i in n:
			var wx := lerpf(- extent, extent, float(i) / float(n - 1)); var wz := lerpf(- extent, extent, float(j) / float(n - 1))
			var point := Vector3(wx, _height(wx, wz) +0.5, wz)
			if has_previous: mesh.surface_add_vertex(previous); mesh.surface_add_vertex(point)
			previous = point; has_previous = true
	for i in range(0, n, step):
		var previous := Vector3.ZERO; var has_previous := false
		for j in n:
			var wx := lerpf(- extent, extent, float(i) / float(n - 1)); var wz := lerpf(- extent, extent, float(j) / float(n - 1))
			var point := Vector3(wx, _height(wx, wz) +0.5, wz)
			if has_previous: mesh.surface_add_vertex(previous); mesh.surface_add_vertex(point)
			previous = point; has_previous = true
	mesh.surface_end()
	ground_grid = MeshInstance3D.new(); ground_grid.name = "GroundGrid"; ground_grid.mesh = mesh; world.add_child(ground_grid)

func weather_settings() -> Dictionary:
	var settings := Weather.read(state)


	if state != null and not state.data.has("environment"):
		settings["hour"] = float(state.data.get("start_hour", 10)) +float(state.data.get("start_minute", 0)) / 60.0
	if _time_override >= 0.0: settings["hour"] = _time_override
	return settings

func _apply_time() -> void: apply_weather()


func apply_weather() -> void:
	if environment == null or sun == null or state == null: return
	var s := weather_settings()
	var daylight := Weather.daylight(s)
	var elevation := Weather.sun_elevation(s)
	var azimuth := Weather.sun_azimuth(s)
	var cloud := clampf(float(s.get("cloud", 0.0)), 0.0, 1.0)
	var fog := clampf(float(s.get("fog", 0.0)), 0.0, 1.0)
	var dust := clampf(float(s.get("dust", 0.0)), 0.0, 1.0)
	var snow := clampf(float(s.get("snow_cover", 0.0)), 0.0, 1.0)
	var golden := clampf(1.0 - absf(elevation - 8.0) / 14.0, 0.0, 1.0) * daylight
	var sky := Color("141d26").lerp(Color("b7c9cf"), daylight)
	sky = sky.lerp(Color("cfd6d0"), cloud * 0.45)
	if golden > 0.0: sky = sky.lerp(Color("e8b081"), golden * 0.5)
	if snow > 0.0: sky = sky.lerp(Color("dfe8f0"), snow * 0.35)
	if dust > 0.0: sky = sky.lerp(Color("c2a271"), dust * 0.7)
	environment.background_color = sky
	environment.ambient_light_color = Color("809db0").lerp(Color("d4d7c8"), daylight).lerp(sky, 0.3)
	environment.ambient_light_energy = 0.16 + 0.42 * daylight + 0.12 * cloud
	environment.fog_enabled = fog > 0.01
	environment.fog_light_color = sky
	environment.fog_light_energy = 0.9
	environment.fog_density = clampf(0.0009 + fog * 0.02, 0.0, 0.05)
	environment.fog_height = 2.0
	environment.fog_height_density = fog * 0.06
	sun.light_color = Color("e0b695").lerp(Color.WHITE, daylight)
	if golden > 0.0: sun.light_color = sun.light_color.lerp(Color("ffb066"), golden * 0.7)
	if dust > 0.0: sun.light_color = sun.light_color.lerp(Color("d8b57a"), dust * 0.6)
	sun.light_energy = clampf(0.1 + 0.85 * daylight - 0.18 * cloud, 0.0, 1.4)
	sun.rotation_degrees = Vector3(- maxf(6.0, elevation), azimuth, 0)
	sun.shadow_enabled = elevation > 3.0
	_update_weather_particles(s)
	_apply_terrain_texture()

func focus_selected() -> void:
	if state == null: return
	var row: Dictionary = state.find_object(state.selected_id)
	if row.is_empty(): return
	var x := float(row.x); var z := float(row.z); var asset := str(row.asset); var extra := 0.0 if Terrain.is_feature(asset) else float(row.height)
	var focus_height := 1.0 if asset in ["civilian", "soldier", "brick_block"] else 3.0
	_target = Vector3(x, _height(x, z) +extra + focus_height, z)
	_distance = 10.0 if asset in ["civilian", "soldier", "brick_block"] else (220.0 if Terrain.is_feature(asset) else 50.0)
	_distance *= maxf(1.0, float(row.get("scale", 1))); _update_camera()
func reset_camera() -> void:
	_target = Vector3.ZERO; _distance = 570.0; _yaw = deg_to_rad(-35.0); _pitch = deg_to_rad(31.0); _update_camera()

func _feature_key() -> String:
	var parts := PackedStringArray()
	for row: Dictionary in state.data.get("objects", []):
		if Terrain.is_feature(str(row.asset)): parts.append("%s|%s|%s|%s|%s|%s" % [row.id, row.asset, row.x, row.z, row.height, row.scale])
	return ";".join(parts)
func _state_changed(why: String) -> void:
	if why == "paint": _apply_terrain_texture(); return
	if why == "history" and show_ground_grid: set_ground_grid(true)
	if why in ["mission", "reset", "loaded"]: _apply_time(); _apply_terrain_texture()
	if why in ["reset", "loaded"]: _refresh_background(); reset_camera()
	var next_key := _feature_key()
	if why in ["terrain", "reset", "loaded"] or next_key != _feature_signature:
		_feature_signature = next_key; _terrain_revision += 1; _rebuild_terrain()
		if camera != null: camera.far = maxf(25000.0, state.extent() * 3.0)
	if why != "mission": _sync_objects()
func _sync_objects() -> void:
	if state == null or objects_root == null: return
	var keep := {}
	for row: Dictionary in state.data.get("objects", []):
		var id := str(row.id); var asset := str(row.asset); keep[id] = true
		if not object_nodes.has(id):
			var fresh := Node3D.new(); fresh.name = id; objects_root.add_child(fresh); object_nodes[id] = fresh
		var node: Node3D = object_nodes[id]; node.set_meta("asset_id", asset); var is_path := asset in ["road_path", "brick_wall"]
		var sig := ""
		if is_path: sig = JSON.stringify([asset, row.get("x", 0), row.get("z", 0), row.get("path", []), row.get("path_width", 8), row.get("wall_height", 2), row.get("texture", ""), _terrain_revision])
		else: sig = JSON.stringify([asset, row.get("animation_source", ""), row.get("animation_clip", ""), row.get("animation_loop", true), row.get("animation_speed", 1), row.get("animation_own", false), row.get("texture", "")])
		if str(node.get_meta("visual_signature", "")) != sig:
			for child in node.get_children(): node.remove_child(child); child.queue_free()
			animation_players.erase(id); own_players.erase(id); animation_results.erase(id)
			if is_path:
				var visual: Node3D = Construction.build(row, state.data.get("terrain", {}), state.data.get("objects", [])); node.add_child(visual)
				TextureCodec.apply_to_visual(visual, _texture(str(row.get("texture", ""))))
				_sync_collision(id, row, visual)
			else:
				var visual: Node3D = library.create_visual(asset, state.custom_assets); node.add_child(visual)
				TextureCodec.apply_to_visual(visual, _texture(str(row.get("texture", ""))))
				_sync_collision(id, row, visual)
				if bool(row.get("animation_own", false)):


					var own := AnimationSupport.own_clip(visual, row)
					animation_results[id] = own
					if bool(own.get("ok", false)): own_players[id] = own.player
				elif not str(row.get("animation_source", "")).is_empty() and not str(row.get("animation_clip", "")).is_empty():
					var result := AnimationSupport.attach(visual, row, state.custom_assets); animation_results[id] = result
					if result.ok:
						animation_players[id] = result.player
						if not preview_playing: result.player.pause()
			node.set_meta("visual_signature", sig)
		node.visible = not bool(row.get("hidden", false))
		if is_path:
			node.position = Vector3(float(row.x), 0, float(row.z)); node.rotation = Vector3.ZERO; node.scale = Vector3.ONE
		else:
			var extra := 0.0 if Terrain.is_feature(asset) else float(row.height)
			node.position = Vector3(float(row.x), _height(float(row.x), float(row.z)) +extra, float(row.z))
			node.rotation_degrees = Vector3(float(row.get("pitch_deg", 0)), float(row.yaw_deg), float(row.get("roll_deg", 0)))
			var object_scale := 1.0 if Terrain.is_feature(asset) else float(row.scale)
			if asset == "brick_block": object_scale *= clampf(float(row.get("brick_scale", 1.0)), 0.4, 3.0)
			node.scale = Vector3.ONE * object_scale
	for id in object_nodes.keys():
		if not keep.has(id):
			object_nodes[id].queue_free(); object_nodes.erase(id); animation_players.erase(id); own_players.erase(id); animation_results.erase(id)
			_drop_collision(str(id))
	var selected: Dictionary = state.find_object(state.selected_id)
	selection_ring.visible = not selected.is_empty()
	if not selected.is_empty(): selection_ring.position = Vector3(float(selected.x), _height(float(selected.x), float(selected.z)) +0.35, float(selected.z))
	for id in multi_ring_nodes.keys():
		if not multi_selected.has(str(id)) or str(id) == state.selected_id:
			multi_ring_nodes[id].queue_free(); multi_ring_nodes.erase(id)
	for id in multi_selected:
		if str(id) == state.selected_id: continue
		var row: Dictionary = state.find_object(str(id))
		if row.is_empty(): continue
		if not multi_ring_nodes.has(str(id)):
			var ring := TorusMesh.new(); ring.inner_radius = 3.2; ring.outer_radius = 3.6; ring.rings = 24; ring.ring_segments = 6
			var marker := MeshInstance3D.new(); marker.mesh = ring; marker.material_override = _mat(Color("ffd08a"), true); world.add_child(marker); multi_ring_nodes[str(id)] = marker
		var marker: MeshInstance3D = multi_ring_nodes[str(id)]
		marker.position = Vector3(float(row.x), _height(float(row.x), float(row.z)) +0.3, float(row.z))
	_update_route(selected)






func _sync_collision(id: String, row: Dictionary, visual: Node3D) -> void:
	_drop_collision(id)
	if state == null or collision_root == null: return
	var asset := str(row.get("asset", ""))
	if not CollisionBuilder.is_solid(asset): return
	var body := StaticBody3D.new(); body.name = "Solid_" + id
	if asset == "brick_wall":
		var boxes: Array = CollisionBuilder.wall_boxes(row, state.data.get("terrain", {}), state.data.get("objects", []))
		if boxes.is_empty(): body.queue_free(); return
		collision_root.add_child(body)
		for box: Dictionary in boxes:
			var shape := CollisionShape3D.new(); var cube := BoxShape3D.new(); cube.size = box.size; shape.shape = cube
			shape.position = box.position
			if box.has("rotation"): shape.rotation = box.rotation
			body.add_child(shape)
	else:
		var object_node: Node3D = object_nodes.get(id, null)
		if object_node == null: body.queue_free(); return
		var boxes: Array = CollisionBuilder.object_boxes(row, visual)
		if boxes.is_empty(): body.queue_free(); return
		object_node.add_child(body)
		for box: Dictionary in boxes:
			var shape := CollisionShape3D.new(); var cube := BoxShape3D.new(); cube.size = box.size; shape.shape = cube; shape.position = box.position
			body.add_child(shape)
	solid_nodes[id] = body

func _drop_collision(id: String) -> void:
	if solid_nodes.has(id):
		var node: Node = solid_nodes[id]
		if is_instance_valid(node): node.queue_free()
		solid_nodes.erase(id)
func solid_count() -> int: return solid_nodes.size()
func _clear_collisions() -> void:
	for id in solid_nodes.keys(): _drop_collision(str(id))

func _update_route(row: Dictionary) -> void:
	if route_visual == null: return
	var immediate := ImmediateMesh.new(); var material := _mat(Color("6cf4c7"), true)
	if not row.is_empty() and not row.get("route", []).is_empty():
		immediate.surface_begin(Mesh.PRIMITIVE_LINES, material); var previous := Vector3(float(row.x), _height(float(row.x), float(row.z)) +1.0, float(row.z))
		for p in row.route:
			var next := Vector3(float(p[0]), _height(float(p[0]), float(p[1])) +1.0, float(p[1])); immediate.surface_add_vertex(previous); immediate.surface_add_vertex(next); previous = next
		immediate.surface_end()
	route_visual.mesh = immediate

func zoom_step(direction: int) -> void:

	if state == null or camera == null: return
	var factor := 0.8 if direction > 0 else 1.25
	_distance = clampf(_distance * factor, 3, maxf(10000.0, state.extent() * 2.5)); _update_camera()

func busy() -> bool: return fly_active or walk_active



func apply_ground_size() -> void:
	if camera != null: camera.far = maxf(25000.0, state.extent() * 3.0)
	_distance = clampf(_distance, 3.0, maxf(10000.0, state.extent() * 2.5))
	_target.x = clampf(_target.x, -state.extent(), state.extent())
	_target.z = clampf(_target.z, -state.extent(), state.extent())
	_update_camera()

func start_flight_test() -> void:
	if fly_active: return
	if walk_active: exit_fpv()
	flight = preload("res://scripts/test_flight.gd").new(); flight.start(state.data); fly_active = true
	fly_drone = Node3D.new(); fly_drone.name = "TestAircraft"; world.add_child(fly_drone)
	fly_drone.add_child(library.create_visual("tb2", state.custom_assets)); fly_position = Vector2(flight.position.x, flight.position.z)
	set_route_preview(true); _update_flight_visual(); flight_status.emit(flight.telemetry())



func enter_fpv() -> bool:
	if walk_active: return true
	if state == null or camera == null or fly_active: return false
	walker = CharacterBody3D.new(); walker.name = "FirstPersonWalker"


	walker.floor_max_angle = deg_to_rad(60.0)
	walker.floor_snap_length = 0.6
	walker.floor_stop_on_slope = true
	walker.slide_on_ceiling = false
	var capsule := CollisionShape3D.new(); var shape := CapsuleShape3D.new()
	var eye := walk_eye_height()
	shape.radius = 0.42 * walk_height_scale; shape.height = eye + 0.35
	capsule.shape = shape; capsule.position = Vector3(0, (eye + 0.35) * 0.5, 0)
	walker.add_child(capsule); walk_capsule = capsule
	world.add_child(walker)

	var ground_target := _target
	var spawn := Vector2(ground_target.x, ground_target.z)
	walker.position = Vector3(spawn.x, _height(spawn.x, spawn.y) +2.0, spawn.y)
	walk_vertical = 0.0; walk_on_ground = false; walk_coyote = 0.0; walk_jump_queued = false
	walk_look_yaw = atan2(- (camera.position.x - spawn.x), -(camera.position.z - spawn.y))
	walk_look_pitch = deg_to_rad(-8.0)
	_camera_saved = camera.global_transform
	walk_active = true
	_update_walk_camera()
	walk_mode_changed.emit(true)
	walk_status.emit(_walk_telemetry())
	return true

func exit_fpv() -> void:
	if not walk_active: return
	walk_active = false
	if is_instance_valid(walker): walker.queue_free()
	walker = null; walk_capsule = null; walk_external.clear(); _walk_looking = false
	camera.global_transform = _camera_saved
	walk_mode_changed.emit(false)
	walk_status.emit("")

func _update_walk_camera() -> void:
	if not walk_active or not is_instance_valid(walker) or camera == null: return
	camera.global_position = walker.global_position + Vector3(0, walk_eye_height(), 0)
	camera.rotation = Vector3(walk_look_pitch, walk_look_yaw, 0)

func walk_look(delta_yaw: float, delta_pitch: float) -> void:
	walk_look_yaw -= delta_yaw
	walk_look_pitch = Walk.clamp_pitch(walk_look_pitch - delta_pitch)
	_update_walk_camera()

func _walk_telemetry() -> String:
	if not walk_active or not is_instance_valid(walker): return ""
	var p := walker.global_position
	var ground := _height(p.x, p.z)
	return "FIRST PERSON  |  x %d  z %d  |  %d m above ground  |  %s" % [int(p.x), int(p.z), int(p.y - ground), "on ground" if walk_on_ground else "in the air"]

func _walk_axis(negative_forward: bool) -> Dictionary:
	var forward := float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) -float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
	var strafe := float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) -float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	forward += float(walk_external.get("forward", 0.0))
	strafe += float(walk_external.get("strafe", 0.0))
	var jumping := Input.is_key_pressed(KEY_SPACE) or bool(walk_external.get("jump", false)) or walk_jump_queued
	return { "forward": clampf(forward, -1, 1), "strafe": clampf(strafe, -1, 1), "jump": jumping}

func _process_walk(delta: float) -> void:
	if not is_instance_valid(walker): return
	var axes := _walk_axis(false)
	var wish := Walk.target_velocity(walk_look_yaw, axes.forward, axes.strafe, Input.is_key_pressed(KEY_SHIFT))
	var control := Walk.air_control(walk_on_ground)
	var horizontal := Vector3(walker.velocity.x, 0, walker.velocity.z)
	horizontal = horizontal.lerp(wish, clampf(12.0 * delta * control, 0.0, 1.0))
	walk_vertical = walker.velocity.y
	var vertical := Walk.vertical_velocity(walk_vertical, walk_on_ground, walk_coyote, axes.jump, delta)
	walk_jump_queued = false
	walker.velocity = Vector3(horizontal.x, float(vertical.velocity), horizontal.z)
	walker.move_and_slide()
	walk_on_ground = walker.is_on_floor()
	if not walk_on_ground and walker.velocity.y <= 0.05:


		var probe := _height(walker.global_position.x, walker.global_position.z)
		if walker.global_position.y - probe < 0.35: walk_on_ground = true
	if walk_on_ground:
		walk_coyote = Walk.COYOTE_TIME
		if walk_vertical < 0.0: walk_vertical = 0.0
	else:
		walk_coyote = maxf(0.0, walk_coyote - delta)

	var floor_y := _height(walker.global_position.x, walker.global_position.z)
	if walker.global_position.y < floor_y - 1.0:
		walker.global_position.y = floor_y + 0.15
		walker.velocity.y = 0.0
	_update_walk_camera()
	walk_status.emit(_walk_telemetry())

func stop_flight_test() -> void:
	if not fly_active: return
	fly_active = false
	if is_instance_valid(fly_drone): fly_drone.queue_free()
	fly_drone = null; flight = null; set_route_preview(false); _update_camera(); flight_status.emit("")
func set_aircraft_scale(value: float) -> void:
	aircraft_scale = clampf(value, 0.15, 6.0)
	if is_instance_valid(fly_drone): fly_drone.scale = Vector3.ONE * aircraft_scale
	flight_status.emit(flight.telemetry() if flight != null else "")

func _update_flight_visual() -> void:
	if not fly_active or not is_instance_valid(fly_drone): return
	fly_drone.position = flight.position
	fly_drone.scale = Vector3.ONE * aircraft_scale



	fly_drone.rotation = Vector3(flight.attitude().x, flight.heading + PI, flight.attitude().z)
	var forward := Vector3(- sin(flight.heading), 0, -cos(flight.heading))
	camera.position = flight.position - forward * 60.0 + Vector3.UP * 27.0
	camera.look_at(flight.position + forward * 35.0, Vector3.UP)
	fly_position = Vector2(flight.position.x, flight.position.z)

func set_route_preview(active: bool) -> void:
	preview_playing = active; preview_elapsed = 0.0; preview_positions.clear()
	for id in animation_players:
		var player: AnimationPlayer = animation_players[id]
		if not is_instance_valid(player): continue
		if active: player.play("reaper_preview/clip")
		else: player.seek(0.0, true); player.pause()
	if not active: _sync_objects()
	preview_frame.emit()


func _pace_point(row: Dictionary, distance: float) -> Dictionary:
	var span := maxf(2.0, float(row.get("animation_range", 12.0)))
	var cycle := fposmod(distance, span * 2.0)
	var forward := cycle <= span
	var offset := cycle if forward else span * 2.0 - cycle
	var yaw := deg_to_rad(float(row.get("yaw_deg", 0.0)))
	var facing := Vector2(- sin(yaw), -cos(yaw))
	return { "point": Vector2(float(row.get("x", 0.0)), float(row.get("z", 0.0))) +facing * (offset - span * 0.5), "forward": forward}

func _preview_position(row: Dictionary, distance: float) -> Vector2:
	var points: Array = [Vector2(float(row.x), float(row.z))]
	for p in row.get("route", []): points.append(Vector2(float(p[0]), float(p[1])))
	if points.size() < 2: return points[0]
	points.append(points[0]); var total := 0.0
	for i in points.size() -1: total += points[i].distance_to(points[i + 1])
	if total < 0.001: return points[0]
	var remaining := fposmod(distance, total)
	for i in points.size() -1:
		var length: float = points[i].distance_to(points[i + 1])
		if length < 0.001: continue
		if remaining <= length: return points[i].lerp(points[i + 1], remaining / length)
		remaining -= length
	return points[0]

func _process(delta: float) -> void:
	tick_weather(delta)
	if walk_active:
		_process_walk(delta)
		return
	if fly_active:
		var commands := { "throttle": clampf(float(Input.is_key_pressed(KEY_W)) -float(Input.is_key_pressed(KEY_S)) +float(external_controls.get("throttle", 0)), -1, 1), "turn": clampf(float(Input.is_key_pressed(KEY_D)) -float(Input.is_key_pressed(KEY_A)) +float(external_controls.get("turn", 0)), -1, 1), "climb": clampf(float(Input.is_key_pressed(KEY_UP)) -float(Input.is_key_pressed(KEY_DOWN)) +float(external_controls.get("climb", 0)), -1, 1)}
		flight.step(delta, commands, preview_positions); _update_flight_visual(); flight_status.emit(flight.telemetry())
	if not preview_playing or state == null: return
	preview_elapsed += minf(maxf(delta, 0.0), 0.25); preview_positions.clear()
	for row: Dictionary in state.data.get("objects", []):
		var displacement := float(row.get("animation_displacement", 0.0))
		if row.get("route", []).is_empty():


			if displacement <= 0.0: continue


			if str(row.get("animation_clip", "")).is_empty() and not bool(row.get("animation_own", false)): continue
			var travel := _pace_point(row, preview_elapsed * displacement)
			preview_positions[str(row.id)] = travel.point
			if object_nodes.has(str(row.id)):
				var walker_node: Node3D = object_nodes[str(row.id)]
				walker_node.position = Vector3(travel.point.x, _height(travel.point.x, travel.point.y) +float(row.height), travel.point.y)
				walker_node.rotation.y = deg_to_rad(float(row.get("yaw_deg", 0.0))) +(0.0 if bool(travel.forward) else PI)
			continue
		var p := _preview_position(row, preview_elapsed * (float(row.speed_mps) +displacement)); preview_positions[str(row.id)] = p
		if object_nodes.has(str(row.id)):
			var node: Node3D = object_nodes[str(row.id)]; node.position = Vector3(p.x, _height(p.x, p.y) +float(row.height), p.y)
			if bool(row.get("route_face", true)):
				var travel_speed := float(row.speed_mps) +displacement
				var ahead := _preview_position(row, preview_elapsed * travel_speed + 1.0); var dir := ahead - p
				if dir.length_squared() > 1e-05: node.rotation.y = atan2(- dir.x, -dir.y) +deg_to_rad(float(row.get("yaw_deg", 0)))
			if str(row.id) == state.selected_id: selection_ring.position = Vector3(p.x, _height(p.x, p.y) +0.35, p.y)
	preview_frame.emit()

func ground_at(at: Vector2) -> Variant:
	if camera == null or viewport == null: return null
	var local := Vector2(at.x * float(viewport.size.x) / maxf(1.0, size.x), at.y * float(viewport.size.y) / maxf(1.0, size.y))
	var origin := camera.project_ray_origin(local); var direction := camera.project_ray_normal(local)
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + direction * maxf(25000.0, state.extent() * 3.0))
	var physics_world := viewport.find_world_3d()
	if physics_world == null: return null
	var hit := physics_world.direct_space_state.intersect_ray(ray)
	if hit.is_empty(): return null
	var point: Vector3 = hit.position
	return Vector2(point.x, point.z)

func screen_for_object(row: Dictionary) -> Vector2:
	if camera == null: return Vector2.INF
	var extra := 0.0 if Terrain.is_feature(str(row.asset)) else float(row.height)
	var p := Vector3(float(row.x), _height(float(row.x), float(row.z)) +extra + 1.0, float(row.z))
	if camera.is_position_behind(p): return Vector2.INF
	var q := camera.unproject_position(p)
	return Vector2(q.x * size.x / maxf(1.0, float(viewport.size.x)), q.y * size.y / maxf(1.0, float(viewport.size.y)))

func _can_drop_data(_at: Vector2, value: Variant) -> bool:
	if OS.has_environment("REAPER_TRACE_DRAG"): print("TRACE scene can drop at=", _at, " data=", value)
	return not busy() and value is Dictionary and value.get("type", "") == "asset" and not str(value.get("id", "")).is_empty()
func _drop_data(at: Vector2, value: Variant) -> void:
	var p = ground_at(at)
	if OS.has_environment("REAPER_TRACE_DRAG"): print("TRACE scene drop at=", at, " ground=", p)
	if p is Vector2: asset_dropped.emit(str(value.id), p)

func _screen_bounds_for_object(id: String) -> Rect2:
	if not object_nodes.has(id): return Rect2()
	var first := true; var bounds := Rect2(); var node: Node3D = object_nodes[id]
	for part: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null or not part.visible: continue
		var aabb := part.get_aabb()
		for i in 8:
			var world_point: Vector3 = part.global_transform * aabb.get_endpoint(i)
			if camera.is_position_behind(world_point): continue
			var point := camera.unproject_position(world_point); point = Vector2(point.x * size.x / maxf(1.0, float(viewport.size.x)), point.y * size.y / maxf(1.0, float(viewport.size.y)))
			if not point.is_finite(): continue
			if first: bounds = Rect2(point, Vector2.ZERO); first = false
			else: bounds = bounds.expand(point)
	return bounds if not first else Rect2()
func _point_rect_distance(point: Vector2, rect: Rect2) -> float:
	var nearest := Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))
	return point.distance_to(nearest)
func _pick_object(at: Vector2) -> String:
	var best := ""; var best_score := 33.0
	for row: Dictionary in state.data.get("objects", []):
		var asset := str(row.get("asset", "")); var anchor := screen_for_object(row); var d := anchor.distance_to(at)
		if asset in ["road_path", "brick_wall"]:
			var path: Array = row.get("path", [])
			for i in path.size() -1:
				var a := row.duplicate(); a.x = float(row.x) +float(path[i][0]); a.z = float(row.z) +float(path[i][1])
				var b := row.duplicate(); b.x = float(row.x) +float(path[i + 1][0]); b.z = float(row.z) +float(path[i + 1][1])
				var pa := screen_for_object(a); var pb := screen_for_object(b)
				if pa.is_finite() and pb.is_finite(): d = minf(d, Geometry2D.get_closest_point_to_segment(at, pa, pb).distance_to(at))
		else:
			var bounds := _screen_bounds_for_object(str(row.id))
			if bounds.size.x > 0 and bounds.size.y > 0 and bounds.size.x < size.x * 2 and bounds.size.y < size.y * 2:
				var edge := _point_rect_distance(at, bounds); d = minf(d, edge)



				if asset in ["civilian", "soldier"] and edge <= 8: d -= 10.0
		if d < best_score: best_score = d; best = str(row.id)
	return best
func _end_construction(p: Variant) -> void:
	if _stroke_id.is_empty(): return
	if p is Vector2: state.append_construction(_stroke_id, p, true)
	var row: Dictionary = state.find_object(_stroke_id)
	if not row.is_empty() and row.get("path", []).size() < 2:
		state.select(_stroke_id); state.remove_selected(); edit_feedback.emit("Drag a longer stroke to build a road or wall.")
	else: edit_feedback.emit("Road or wall created. Select and drag it, or delete the selected stroke.")
	_stroke_id = ""
func _gui_input(event: InputEvent) -> void:
	if state == null or camera == null or fly_active: return
	if walk_active:
		if event is InputEventMouseButton:
			if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]: _walk_looking = event.pressed; accept_event()
			return
		if event is InputEventMouseMotion and _walk_looking:
			walk_look(event.relative.x * 0.004, event.relative.y * 0.004); accept_event()
			return
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT: _orbiting = event.pressed; accept_event(); return
		if event.button_index == MOUSE_BUTTON_MIDDLE: _panning = event.pressed; accept_event(); return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_distance = clampf(_distance * (0.88 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.14), 3, maxf(10000.0, state.extent() * 2.5)); _update_camera(); accept_event(); return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if touch_orbit:
					_orbiting = true; accept_event(); return
				var ground = ground_at(event.position)
				if terrain_tool in ["raise", "lower", "smooth", "flatten"]:
					_sculpting = true; state.remember_terrain_stroke()
					if ground is Vector2:
						_flatten_height = Terrain.base_height(state.data.terrain, ground.x, ground.y)
						state.sculpt_terrain(ground, brush_radius, brush_strength, terrain_tool, _flatten_height)
					accept_event(); return
				if terrain_tool in ["paint", "erase_paint"]:
					if ground is Vector2:
						var start: Dictionary = state.begin_paint_stroke(paint_texture_id, terrain_tool == "erase_paint")
						if start.ok: _painting = true; _last_paint_point = ground; state.paint_terrain(ground, brush_radius, brush_strength, paint_texture_id, terrain_tool == "erase_paint")
						else: edit_feedback.emit(str(start.error))
					accept_event(); return
				if terrain_tool == "snow":
					if ground is Vector2:
						var snow_start: Dictionary = state.begin_snow_stroke(false)
						if snow_start.ok: _snowing = true; _last_snow_point = ground; state.paint_snow(ground, brush_radius, brush_strength)
						else: edit_feedback.emit(str(snow_start.error))
					accept_event(); return
				if terrain_tool in ["road", "wall"]:
					if ground is Vector2: _stroke_id = state.add_construction("road_path" if terrain_tool == "road" else "brick_wall", ground, road_width, wall_height)
					accept_event(); return
				if route_mode and not state.selected_id.is_empty() and ground is Vector2:
					_drawing_route = true; state.add_waypoint(state.selected_id, ground, 0.5); accept_event(); return
				var best := _pick_object(event.position); state.select(best); _drag_id = best
				if not best.is_empty() and ground is Vector2:
					var row: Dictionary = state.find_object(best); _drag_offset = Vector2(float(row.x), float(row.z)) -ground
				elif best.is_empty():
					_left_pan = true; _vertical_pan = event.shift_pressed
				accept_event()
			else:
				if touch_orbit:
					_orbiting = false; accept_event(); return
				if _painting: state.finish_paint_stroke(); _painting = false
				if _snowing: state.finish_snow_stroke(); _snowing = false; apply_weather()
				_end_construction(ground_at(event.position)); _drag_id = ""; _sculpting = false; _drawing_route = false; _left_pan = false; _vertical_pan = false; accept_event()
	elif event is InputEventMouseMotion:
		if _panning or _left_pan:
			if _vertical_pan:
				_target.y += event.relative.y * _distance * 0.002
			else:
				var right := Vector3(camera.global_basis.x.x, 0, camera.global_basis.x.z).normalized(); var back := Vector3(camera.global_basis.z.x, 0, camera.global_basis.z.z).normalized()
				_target += (- right * event.relative.x + back * event.relative.y) * _distance * 0.0018
				_target.x = clampf(_target.x, -state.extent(), state.extent()); _target.z = clampf(_target.z, -state.extent(), state.extent())
			_update_camera(); accept_event()
		elif _painting and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			var ground = ground_at(event.position)
			if ground is Vector2: state.paint_terrain_segment(_last_paint_point, ground, brush_radius, brush_strength, paint_texture_id, terrain_tool == "erase_paint"); _last_paint_point = ground
			accept_event()
		elif _snowing and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			var ground = ground_at(event.position)
			if ground is Vector2: state.paint_snow_segment(_last_snow_point, ground, brush_radius, brush_strength); _last_snow_point = ground; apply_weather()
			accept_event()
		elif _sculpting and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			var ground = ground_at(event.position)
			if ground is Vector2: state.sculpt_terrain(ground, brush_radius, brush_strength, terrain_tool, _flatten_height)
			accept_event()
		elif not _stroke_id.is_empty() and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			var ground = ground_at(event.position)
			if ground is Vector2: state.append_construction(_stroke_id, ground)
			accept_event()
		elif _drawing_route and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			var ground = ground_at(event.position)
			if ground is Vector2: state.add_waypoint(state.selected_id, ground, 15.0)
			accept_event()
		elif _orbiting:
			_yaw -= event.relative.x * 0.006; _pitch = clampf(_pitch + event.relative.y * 0.005, deg_to_rad(15), deg_to_rad(82)); _update_camera(); accept_event()
		elif not _drag_id.is_empty() and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if Input.is_key_pressed(KEY_R):
				rotate_drag_yaw(- event.relative.x * 0.5)
				accept_event()
			else:
				var p = ground_at(event.position)
				if p is Vector2: state.set_position(_drag_id, p + _drag_offset)
				accept_event()





func _make_weather_particles() -> void:
	if weather_root == null: return
	rain_particles = _make_particle_layer("Rain", Color("bcd2e0"), 6, 40, 70)
	snow_particles = _make_particle_layer("Snowfall", Color("ffffff"), 4, 260, 30)
	dust_particles = _make_particle_layer("Dust", Color("d8bd8f"), -1, 420, 18)
	for layer in [rain_particles, snow_particles, dust_particles]:
		if layer != null: layer.emitting = false

func _make_particle_layer(layer_name: String, colour: Color, amount_unused: int, life: float, speed: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = layer_name
	particles.emitting = false
	particles.amount = 180
	particles.lifetime = life / 10.0
	particles.explosiveness = 0.0
	particles.randomness = 0.6
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(70, 22, 70)
	particles.direction = Vector3(0, -1, 0)
	particles.spread = 8.0
	particles.initial_velocity_min = speed * 0.6
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -9.8, 0) if layer_name != "Dust" else Vector3(0, 0.4, 0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.4
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.5, 0.5) if layer_name != "Rain" else Vector2(0.09, 1.6)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = false
	material.albedo_color = Color(colour.r, colour.g, colour.b, 0.55)
	mesh.material = material
	particles.mesh = mesh
	particles.visible = false
	weather_root.add_child(particles)
	return particles

func _update_weather_particles(s: Dictionary) -> void:
	if weather_root == null: return
	var wind := Weather.wind_vector(s)
	var rain := clampf(float(s.get("rain", 0.0)), 0.0, 1.0)
	var snow_fall := clampf(float(s.get("snow_fall", 0.0)), 0.0, 1.0)
	var dust := clampf(float(s.get("dust", 0.0)), 0.0, 1.0)
	_configure_layer(rain_particles, rain, 620, Vector3(0, -1, 0) +wind * 0.05, 26.0)
	_configure_layer(snow_particles, snow_fall, 420, Vector3(0, -1, 0) +wind * 0.09, 5.0)
	_configure_layer(dust_particles, dust, 320, Vector3(wind.x, 0.35, wind.z).normalized(), wind.length() * 1.1 + 2.0)
	weather_root.visible = rain > 0.01 or snow_fall > 0.01 or dust > 0.01

func _configure_layer(layer: CPUParticles3D, intensity: float, max_amount: int, direction: Vector3, speed: float) -> void:
	if layer == null: return
	layer.emitting = intensity > 0.01
	layer.visible = intensity > 0.01
	if not layer.emitting: return
	layer.amount = maxi(12, int(round(float(max_amount) * intensity)))
	layer.direction = direction.normalized()
	layer.initial_velocity_min = maxf(1.0, speed * 0.55)
	layer.initial_velocity_max = maxf(2.0, speed)
	var wind_speed := direction.length()
	layer.spread = clampf(6.0 + wind_speed * 0.8, 4.0, 40.0)



func tick_weather(delta: float) -> void:
	weather_clock += delta
	if weather_root == null or camera == null: return
	if weather_root.visible:
		weather_root.global_position = Vector3(camera.global_position.x, camera.global_position.y + 6.0, camera.global_position.z)
	var s := weather_settings()
	var wind := Weather.wind_vector(s)
	var strength := clampf(wind.length() / 22.0, 0.0, 1.0)
	var sway := sin(weather_clock * 1.7) * 0.012 * strength + sin(weather_clock * 2.9) * 0.006 * strength


	for id in object_nodes.keys():
		var node: Node3D = object_nodes[id]
		if not is_instance_valid(node): continue
		var row: Dictionary = state.find_object(str(id))
		if row.is_empty(): continue
		var base := float(row.get("roll_deg", 0.0))
		var leans := not (str(row.get("asset", "")) in ["road_path", "brick_wall"]) and not _windproof(str(row.get("asset", "")))
		node.rotation_degrees.z = base + (rad_to_deg(sway) if leans else 0.0)


func _windproof(asset: String) -> bool:
	return asset in ["terrain_hill", "terrain_mountain", "terrain_plateau", "drone_start"]




func set_walk_height_scale(scale: float) -> void:
	walk_height_scale = clampf(scale, 0.25, 8.0)
	if not walk_active or not is_instance_valid(walker): return
	var eye := Walk.EYE_HEIGHT * walk_height_scale
	if is_instance_valid(walk_capsule) and walk_capsule.shape is CapsuleShape3D:
		var shape := walk_capsule.shape as CapsuleShape3D
		shape.height = eye + 0.35
		shape.radius = 0.42 * walk_height_scale
		walk_capsule.position = Vector3(0, (eye + 0.35) * 0.5, 0)
	_update_walk_camera()
	walk_status.emit(_walk_telemetry())

func walk_eye_height() -> float:
	return Walk.EYE_HEIGHT * walk_height_scale




func rotate_dragging() -> bool: return _rotate_drag

func begin_rotate_drag() -> void:
	_rotate_drag = true
	var row: Dictionary = state.find_object(state.selected_id) if state != null else {}
	_rotate_last = float(row.get("yaw_deg", 0.0)) if not row.is_empty() else 0.0

func rotate_drag_yaw(degrees: float) -> void:
	if state == null or state.selected_id.is_empty(): return
	state.set_value(state.selected_id, "yaw_deg", wrapf(float(state.find_object(state.selected_id).get("yaw_deg", 0.0)) +degrees, -360.0, 360.0))

func end_rotate_drag() -> void: _rotate_drag = false





func animation_own(id: String) -> bool:
	var row: Dictionary = state.find_object(id) if state != null else {}
	return bool(row.get("animation_own", false))
func own_animation_clip(id: String) -> String:
	var result: Dictionary = animation_results.get(id, {})
	return str(result.get("clip", "")) if bool(result.get("own", false)) else ""
func animation_displacement(id: String) -> float:
	if state == null: return 0.0
	var row: Dictionary = state.find_object(id)
	if row.is_empty(): return 0.0
	return clampf(float(row.get("animation_displacement", 0.0)), 0.0, 20.0)
