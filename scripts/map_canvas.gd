extends Control


signal asset_dropped(asset_id: String, position: Vector2)
signal edit_feedback(message: String)
const Terrain = preload("res://scripts/terrain_model.gd")
const TextureCodec = preload("res://scripts/texture_codec.gd")
var state
var flight_scene
var route_mode := false
var terrain_tool := "select"
var brush_radius := 90.0
var brush_strength := 8.0
var paint_texture_id := ""
var painting := false
var snowing := false
var last_snow_point := Vector2.ZERO
var last_paint_point := Vector2.ZERO
var _paint_colors: Dictionary = {}
var road_width := 8.0
var wall_height := 2.0
var sculpting := false
var drawing_route := false
var stroke_id := ""
var flatten_height := 0.0
var preview_positions: Dictionary = {}
var dragging_id := ""
var drag_offset := Vector2.ZERO
var map_panning := false
var zoom := 1.0
var pan_mode := false
var center_world := Vector2.ZERO
var _scale := 1.0
var _center := Vector2.ZERO
var _terrain_tex: ImageTexture
var _texture_dirty := true


var underlay: Texture2D
var underlay_alpha := 0.55
var underlay_name := ""
var show_grid := true
var show_labels := true
var ruler_mode := false
var ruler_a := Vector2.INF
var ruler_b := Vector2.INF
var cursor_world := Vector2.ZERO
var has_cursor := false
var highlight_ids: Array = []

func setup(shared) -> void:
	state = shared; state.changed.connect(_on_state); queue_redraw()
func _on_state(reason: String) -> void:
	if reason in ["terrain", "paint", "objects", "pose", "properties", "reset", "loaded"]: _texture_dirty = true
	if reason in ["reset", "loaded"]: zoom = 1.0; center_world = Vector2.ZERO; _paint_colors.clear()
	queue_redraw()
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP; clip_contents = true; tooltip_text = "Editable map: drag objects, routes or brush strokes. Wheel zooms; right-drag pans."
func _geometry() -> void:
	var extent: float = state.extent() if state != null else Terrain.EXTENT
	_scale = minf(maxf(1, size.x - 20), maxf(1, size.y - 30)) / (2.0 * extent) * zoom
	_center = Vector2(size.x * 0.5, (size.y + 20) * 0.5)
func world_to_screen(p: Vector2) -> Vector2:
	_geometry(); return _center + (p - center_world) * _scale
func screen_to_world(p: Vector2) -> Vector2:
	_geometry(); return center_world + (p - _center) / maxf(_scale, 0.0001)
func _average_texture_color(id: String) -> Color:
	if _paint_colors.has(id): return _paint_colors[id]
	var color := Color("a99775")
	if state.custom_assets.has(id):
		var bytes: PackedByteArray = state.custom_assets[id].get("bytes", PackedByteArray()); var info := TextureCodec._size(bytes)
		if info.ok:
			var image := Image.new(); var err := image.load_png_from_buffer(bytes) if info.format == "png" else image.load_jpg_from_buffer(bytes)
			if err == OK and not image.is_empty():
				image.resize(8, 8, Image.INTERPOLATE_BILINEAR); color = Color(0, 0, 0, 1)
				for j in 8:
					for i in 8:
						var pixel := image.get_pixel(i, j); color.r += pixel.r / 64.0; color.g += pixel.g / 64.0; color.b += pixel.b / 64.0
	_paint_colors[id] = color; return color
func _refresh_terrain_texture() -> void:
	if state == null: return
	var n := 65; var extent: float = state.extent(); var image := Image.create(n, n, false, Image.FORMAT_RGB8)
	var paint: Dictionary = state.data.get("terrain_paint", {}); var layers: Array = paint.get("layers", []); var mask: Image = state.paint_image() if not paint.is_empty() else null; var colors: Array = []
	for id in layers: colors.append(_average_texture_color(str(id)))
	for j in n:
		for i in n:
			var x := lerpf(- extent, extent, float(i) / (n - 1)); var z := lerpf(- extent, extent, float(j) / (n - 1))
			var h := Terrain.height_at(state.data.get("terrain", {}), state.data.get("objects", []), x, z)
			var base := Color("a99775")
			if h > 0: base = base.lerp(Color("e0caa1"), clampf(h / 500.0, 0.0, 0.75))
			elif h < 0: base = base.lerp(Color("617e81"), clampf(- h / 150.0, 0.0, 0.7))
			if mask != null:
				var coverage := mask.get_pixel(int(round(float(i) * (mask.get_width() -1) / (n - 1))), int(round(float(j) * (mask.get_height() -1) / (n - 1))))
				var weights := [coverage.r, coverage.g, coverage.b, coverage.a]
				for layer in colors.size(): base = base.lerp(colors[layer], float(weights[layer]))
			image.set_pixel(i, j, base)
	_terrain_tex = ImageTexture.create_from_image(image); _texture_dirty = false
func _draw() -> void:
	_geometry(); draw_rect(Rect2(Vector2.ZERO, size), Color("152628")); draw_rect(Rect2(Vector2.ZERO, size), Color("78a99c"), false, 1.0)
	if state == null: return
	if _texture_dirty or _terrain_tex == null: _refresh_terrain_texture()
	var extent: float = state.extent(); var corner := world_to_screen(Vector2(- extent, -extent)); var side := 2.0 * extent * _scale
	if _terrain_tex != null: draw_texture_rect(_terrain_tex, Rect2(corner, Vector2(side, side)), false)
	if underlay != null:
		draw_texture_rect(underlay, Rect2(corner, Vector2(side, side)), false, Color(1, 1, 1, underlay_alpha))
	if show_grid:
		var grid := extent / 4.0
		for k in range(-4, 5):
			draw_line(world_to_screen(Vector2(k * grid, -extent)), world_to_screen(Vector2(k * grid, extent)), Color(1, 1, 1, 0.12), 1)
			draw_line(world_to_screen(Vector2(- extent, k * grid)), world_to_screen(Vector2(extent, k * grid)), Color(1, 1, 1, 0.12), 1)
	for row: Dictionary in state.data.get("objects", []):
		if str(row.get("asset", "")) in ["road_path", "brick_wall"]:
			var origin := Vector2(float(row.x), float(row.z)); var path: Array = row.get("path", [])
			for i in path.size() -1:
				var a := origin + Vector2(float(path[i][0]), float(path[i][1])); var b := origin + Vector2(float(path[i + 1][0]), float(path[i + 1][1]))
				var c := Color("615c51") if str(row.asset) == "road_path" else Color("ece1b7")
				var w := maxf(2.0, float(row.get("path_width", 8)) * _scale) if str(row.asset) == "road_path" else 2.0
				draw_line(world_to_screen(a), world_to_screen(b), c, w, true)
	var selected: Dictionary = state.find_object(state.selected_id)
	if not selected.is_empty():
		var last := world_to_screen(Vector2(float(selected.x), float(selected.z))); var count := 0
		for entry in selected.get("route", []):
			var next := world_to_screen(Vector2(float(entry[0]), float(entry[1]))); draw_line(last, next, Color("65ffe0"), 2.2, true)
			var d: Vector2 = (next - last).normalized(); var mid: Vector2 = (last + next) * 0.5
			if last.distance_to(next) > 12.0:
				var normal := Vector2(- d.y, d.x); draw_line(mid, mid - d * 7 + normal * 3, Color("65ffe0"), 1.6); draw_line(mid, mid - d * 7 - normal * 3, Color("65ffe0"), 1.6)
			draw_circle(next, 3.5, Color("d4fff0")); last = next; count += 1
	for row: Dictionary in state.data.get("objects", []):
		var position: Vector2 = preview_positions.get(str(row.id), Vector2(float(row.x), float(row.z))); var p := world_to_screen(position)
		var color := Color("f7c46d") if Terrain.is_feature(str(row.asset)) else (Color("ffad77") if row.faction == "Hostile" else (Color("ffd987") if row.faction == "Civilian" else Color("85d7ff")))
		if bool(row.get("hidden", false)):
			draw_circle(p, 4.5, Color(color, 0.25)); draw_circle(p, 7.5, Color(1, 1, 1, 0.35), false, 1.0)
			continue
		if row.id == state.selected_id or highlight_ids.has(str(row.id)): draw_circle(p, 9, Color("9cffe2"))
		draw_circle(p, 4.5, color); draw_circle(p, 4.5, Color("213232"), false, 1.2)
	# At the default 2.4 km overview many objects occupy the same few pixels.
	# Prefer the selected object's label and suppress intersecting labels instead
	# of painting unreadable text on top of itself. Zooming in reveals more.
	if show_labels:
		var rows: Array = state.data.get("objects", [])
		var ordered: Array = []
		for row in rows:
			if row is Dictionary and str(row.get("id", "")) == state.selected_id: ordered.push_front(row)
		for row in rows:
			if row is Dictionary and str(row.get("id", "")) != state.selected_id: ordered.append(row)
		var occupied: Array[Rect2] = []
		for row in ordered:
			if bool(row.get("hidden", false)): continue
			var position: Vector2 = preview_positions.get(str(row.id), Vector2(float(row.x), float(row.z)))
			var p := world_to_screen(position)
			var text := str(row.get("name", row.id)).substr(0, 24)
			var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			var x := clampf(p.x + 7.0, 2.0, maxf(2.0, size.x - width - 4.0))
			var baseline := clampf(p.y - 7.0, 34.0, size.y - 5.0)
			var box := Rect2(x - 2.0, baseline - 10.0, width + 4.0, 13.0)
			var overlaps := false
			for previous in occupied:
				if box.grow(2.0).intersects(previous): overlaps = true; break
			if overlaps: continue
			occupied.append(box)
			draw_rect(box, Color(0.06, 0.13, 0.13, 0.82))
			draw_string(ThemeDB.fallback_font, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("c5ffeb") if str(row.id) == state.selected_id else Color("e8f4ee"))
	if flight_scene != null:
		var target: Vector3 = flight_scene._target; var view_at := world_to_screen(Vector2(target.x, target.z)); draw_circle(view_at, 5, Color("d4f8ff"), false, 1.3)
		if flight_scene.fly_active:
			var aircraft := world_to_screen(flight_scene.fly_position); draw_circle(aircraft, 6, Color("85eaff")); draw_circle(aircraft, 9, Color("85eaff"), false, 2.0)
	if ruler_a != Vector2.INF:
		var a := world_to_screen(ruler_a)
		var b := world_to_screen(ruler_b) if ruler_b != Vector2.INF else a
		draw_line(a, b, Color("ffd08a"), 2.0, true)
		draw_circle(a, 4, Color("ffd08a")); draw_circle(b, 4, Color("ffd08a"))
		if ruler_b != Vector2.INF:
			var metres := ruler_a.distance_to(ruler_b)
			draw_string(ThemeDB.fallback_font, (a + b) * 0.5 + Vector2(6, -6), "%d m" % int(round(metres)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ffe6b8"))
	if has_cursor:
		var cur := world_to_screen(cursor_world)
		draw_line(cur + Vector2(-6, 0), cur + Vector2(6, 0), Color(1, 1, 1, 0.55), 1)
		draw_line(cur + Vector2(0, -6), cur + Vector2(0, 6), Color(1, 1, 1, 0.55), 1)
		var ground := Terrain.height_at(state.data.get("terrain", {}), state.data.get("objects", []), cursor_world.x, cursor_world.y)
		draw_string(ThemeDB.fallback_font, Vector2(8, size.y - 24), "X %.0f  Z %.0f  ·  GROUND %.0f m" % [cursor_world.x, cursor_world.y, ground], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("cfe8de"))
	draw_rect(Rect2(0, 0, size.x, 23), Color(0.06, 0.13, 0.13, 0.9))
	var header := ("MAP • %.1f km • %.1fx" if size.x < 230.0 else "EDITABLE MAP  •  %.1f km  •  %.1fx") % [2.0 * extent / 1000.0, zoom]
	draw_string(ThemeDB.fallback_font, Vector2(8, 16), header, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d8f8e8"))
	if terrain_tool != "select": draw_string(ThemeDB.fallback_font, Vector2(8, size.y - 8), terrain_tool.to_upper() +" TOOL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f2c58d"))
	elif route_mode: draw_string(ThemeDB.fallback_font, Vector2(8, size.y - 8), "CLICK OR DRAG ROUTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("bdf8df"))
func _can_drop_data(_at: Vector2, value: Variant) -> bool:
	return (flight_scene == null or not flight_scene.fly_active) and value is Dictionary and value.get("type", "") == "asset" and not str(value.get("id", "")).is_empty()
func _drop_data(at: Vector2, value: Variant) -> void: asset_dropped.emit(str(value.id), screen_to_world(at))
func _pick(at: Vector2) -> String:
	var best := ""; var distance := 18.0
	for row: Dictionary in state.data.get("objects", []):
		var origin := Vector2(float(row.x), float(row.z)); var pos: Vector2 = preview_positions.get(str(row.id), origin); var d := world_to_screen(pos).distance_to(at)
		if str(row.get("asset", "")) in ["road_path", "brick_wall"]:
			var path: Array = row.get("path", [])
			for i in path.size() -1:
				var a := world_to_screen(origin + Vector2(float(path[i][0]), float(path[i][1]))); var b := world_to_screen(origin + Vector2(float(path[i + 1][0]), float(path[i + 1][1])))
				d = minf(d, Geometry2D.get_closest_point_to_segment(at, a, b).distance_to(at))
		if str(row.get("asset", "")) in ["civilian", "soldier"] and d <= 8: d -= 4
		if d < distance: distance = d; best = str(row.id)
	return best
func _end_stroke(p: Vector2) -> void:
	if stroke_id.is_empty(): return
	state.append_construction(stroke_id, p, true); var row: Dictionary = state.find_object(stroke_id)
	if not row.is_empty() and row.get("path", []).size() < 2:
		state.select(stroke_id); state.remove_selected(); edit_feedback.emit("Drag a longer stroke to build a road or wall.")
	else: edit_feedback.emit("Road or wall created. Select and drag it, or delete the selected stroke.")
	stroke_id = ""
func set_underlay(texture: Texture2D, label := "") -> void:
	underlay = texture; underlay_name = label; queue_redraw()
func clear_underlay() -> void:
	underlay = null; underlay_name = ""; queue_redraw()
func clear_ruler() -> void:
	ruler_a = Vector2.INF; ruler_b = Vector2.INF; queue_redraw()
func ruler_distance() -> float:
	if ruler_a == Vector2.INF or ruler_b == Vector2.INF: return 0.0
	return ruler_a.distance_to(ruler_b)
func set_highlight(ids: Array) -> void:
	highlight_ids = ids; queue_redraw()
func toggle_grid() -> bool:
	show_grid = not show_grid; queue_redraw(); return show_grid
func toggle_labels() -> bool:
	show_labels = not show_labels; queue_redraw(); return show_labels
func zoom_step(direction: int) -> void:

	zoom = clampf(zoom * (1.3 if direction > 0 else 1.0 / 1.3), 0.5, 10); _geometry(); queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if state == null or (flight_scene != null and flight_scene.fly_active): return
	if event is InputEventMouseMotion:
		has_cursor = true; cursor_world = screen_to_world(event.position); queue_redraw()
	elif event is InputEventScreenDrag:
		has_cursor = true; cursor_world = screen_to_world(event.position); queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and ruler_mode:
		var point := screen_to_world(event.position)
		if ruler_a == Vector2.INF or ruler_b != Vector2.INF: ruler_a = point; ruler_b = Vector2.INF
		else: ruler_b = point
		queue_redraw(); return
	elif event is InputEventScreenTouch and event.pressed and ruler_mode:
		var point := screen_to_world(event.position)
		if ruler_a == Vector2.INF or ruler_b != Vector2.INF: ruler_a = point; ruler_b = Vector2.INF
		else: ruler_b = point
		queue_redraw(); return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT: map_panning = event.pressed; accept_event(); return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var before := screen_to_world(event.position); zoom = clampf(zoom * (1.3 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.3), 0.5, 10); _geometry(); center_world = before - (event.position - _center) / _scale; center_world = state.bounded(center_world); queue_redraw(); accept_event(); return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if pan_mode: map_panning = true; accept_event(); return
				var p := screen_to_world(event.position)
				if terrain_tool in ["raise", "lower", "smooth", "flatten"]:
					sculpting = true; flatten_height = Terrain.base_height(state.data.terrain, p.x, p.y); state.remember_terrain_stroke(); state.sculpt_terrain(p, brush_radius, brush_strength, terrain_tool, flatten_height); accept_event(); return
				if terrain_tool in ["paint", "erase_paint"]:
					var start: Dictionary = state.begin_paint_stroke(paint_texture_id, terrain_tool == "erase_paint")
					if start.ok: painting = true; last_paint_point = p; state.paint_terrain(p, brush_radius, brush_strength, paint_texture_id, terrain_tool == "erase_paint")
					else: edit_feedback.emit(str(start.error))
					accept_event(); return
				if terrain_tool == "snow":
					var snow_start: Dictionary = state.begin_snow_stroke(false)
					if snow_start.ok: snowing = true; last_snow_point = p; state.paint_snow(p, brush_radius, brush_strength)
					else: edit_feedback.emit(str(snow_start.error))
					accept_event(); return
				if terrain_tool in ["road", "wall"]:
					stroke_id = state.add_construction("road_path" if terrain_tool == "road" else "brick_wall", p, road_width, wall_height); accept_event(); return
				if route_mode and not state.selected_id.is_empty(): drawing_route = true; state.add_waypoint(state.selected_id, p, 0.5); accept_event(); return
				var best := _pick(event.position); state.select(best); dragging_id = best
				if not best.is_empty(): var row: Dictionary = state.find_object(best); drag_offset = Vector2(float(row.x), float(row.z)) -p
				accept_event()
			else:
				if pan_mode: map_panning = false; accept_event(); return
				if painting: state.finish_paint_stroke(); painting = false
				if snowing: state.finish_snow_stroke(); snowing = false
				_end_stroke(screen_to_world(event.position)); dragging_id = ""; sculpting = false; drawing_route = false; accept_event()
	elif event is InputEventMouseMotion:
		if map_panning:
			center_world = state.bounded(center_world - event.relative / maxf(_scale, 0.0001)); queue_redraw(); accept_event()
		elif (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			var p := screen_to_world(event.position)
			if painting: state.paint_terrain_segment(last_paint_point, p, brush_radius, brush_strength, paint_texture_id, terrain_tool == "erase_paint"); last_paint_point = p
			elif snowing: state.paint_snow_segment(last_snow_point, p, brush_radius, brush_strength); last_snow_point = p
			elif sculpting: state.sculpt_terrain(p, brush_radius, brush_strength, terrain_tool, flatten_height)
			elif not stroke_id.is_empty(): state.append_construction(stroke_id, p)
			elif drawing_route: state.add_waypoint(state.selected_id, p, 15.0)
			elif not dragging_id.is_empty(): state.set_position(dragging_id, p + drag_offset)
			accept_event()
