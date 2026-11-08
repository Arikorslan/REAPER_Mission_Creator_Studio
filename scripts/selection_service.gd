extends RefCounted



var ids: Array = []
var clipboard: Array = []
var clipboard_origin := Vector2.ZERO
var paste_step := 0

func clear() -> void: ids.clear()
func count() -> int: return ids.size()
func has(id: String) -> bool: return id in ids
func add(id: String) -> void:
	if id.is_empty() or has(id): return
	ids.append(id)
func toggle(id: String) -> void:
	if has(id): ids.erase(id)
	else: add(id)
func keep_only(id: String) -> void: ids.clear(); add(id)
func prune(state) -> void:
	var kept: Array = []
	for id in ids:
		if not state.find_object(str(id)).is_empty(): kept.append(id)
	ids = kept
func rows(state) -> Array:
	var out: Array = []
	for id in ids:
		var row: Dictionary = state.find_object(str(id))
		if not row.is_empty(): out.append(row)
	return out

func copy(state) -> int:
	clipboard.clear(); clipboard_origin = Vector2.ZERO; paste_step = 0
	var first := true
	for row: Dictionary in rows(state):
		var copy_row: Dictionary = row.duplicate(true)
		clipboard.append(copy_row)
		var p := Vector2(float(row.x), float(row.z))
		if first: clipboard_origin = p; first = false
	if clipboard.size() > 0: set_flags_in_clipboard()
	return clipboard.size()

func set_flags_in_clipboard() -> void:
	for row: Dictionary in clipboard:
		row["id"] = ""
		row["locked"] = false
		row["hidden"] = false

func paste(state, offset := Vector2(12, 12)) -> Array:
	var made: Array = []

	var step_offset := offset * (float(paste_step) +1.0)
	paste_step += 1
	for row: Dictionary in clipboard:
		var src := Vector2(float(row.get("x", 0)), float(row.get("z", 0)))
		var rel := src - clipboard_origin + step_offset
		var id: String = state.add_object(str(row.get("asset", "civilian")), Vector2(float(row.x), float(row.z)) +step_offset, str(row.get("name", "Copy")))
		if id.is_empty(): continue
		_apply_row(state, id, row, step_offset)
		made.append(id)
	return made

func duplicate(state, offset := Vector2(12, 12)) -> Array:
	var previous := clipboard.duplicate(true)
	var previous_origin := clipboard_origin
	var previous_step := paste_step
	copy(state)
	var made := paste(state, offset)
	clipboard = previous; clipboard_origin = previous_origin; paste_step = previous_step
	return made

func _apply_row(state, id: String, row: Dictionary, offset: Vector2) -> void:
	var target: Dictionary = state.find_object(id)
	if target.is_empty(): return
	for key in ["height", "yaw_deg", "pitch_deg", "roll_deg", "scale", "faction", "speed_mps", "route_face", "animation_source", "animation_clip", "animation_loop", "animation_speed", "animation_own", "texture"]:
		if row.has(key): target[key] = row[key]
	if row.has("path"):
		var path: Array = []
		for pt in row.path: path.append([float(pt[0]), float(pt[1])])
		target["path"] = path
		target["path_width"] = float(row.get("path_width", 8.0))
		target["wall_height"] = float(row.get("wall_height", 2.0))
	var route: Array = []
	for pt in row.get("route", []): route.append([float(pt[0]) +offset.x, float(pt[1]) +offset.y])
	target["route"] = route
	state.dirty = true
	state.changed.emit("objects")

func set_flag(state, key: String, value: bool) -> int:
	if key not in ["locked", "hidden"]: return 0
	var changed := 0
	for row: Dictionary in rows(state):
		row[key] = value; changed += 1
	if changed > 0:
		state.dirty = true; state.changed.emit("flags")
	return changed

func nudge(state, delta: Vector2) -> int:
	var moved := 0
	for row: Dictionary in rows(state):
		if bool(row.get("locked", false)): continue
		state.set_position(str(row.id), Vector2(float(row.x), float(row.z)) +delta); moved += 1
	return moved

static func snap_value(v: float, grid: float) -> float:
	if grid <= 0.0: return v
	return roundf(v / grid) * grid
func snap_all(state, grid: float) -> int:
	if grid <= 0.0: return 0
	var moved := 0
	for row: Dictionary in rows(state):
		if bool(row.get("locked", false)): continue
		state.set_position(str(row.id), Vector2(snap_value(float(row.x), grid), snap_value(float(row.z), grid))); moved += 1
	return moved

func bounds(state) -> Rect2:
	var rows_out := rows(state)
	if rows_out.is_empty(): return Rect2()
	var first: Dictionary = rows_out[0]
	var rect := Rect2(float(first.x), float(first.z), 0, 0)
	for row: Dictionary in rows_out: rect = rect.expand(Vector2(float(row.x), float(row.z)))
	return rect

func align(state, mode: String) -> int:
	var rows_out := rows(state)
	if rows_out.size() < 2: return 0
	var rect := bounds(state)
	for row: Dictionary in rows_out:
		if bool(row.get("locked", false)): continue
		var p := Vector2(float(row.x), float(row.z))
		match mode:
			"left": p.x = rect.position.x
			"right": p.x = rect.position.x + rect.size.x
			"back": p.y = rect.position.y
			"front": p.y = rect.position.y + rect.size.y
			"center_x": p.x = rect.position.x + rect.size.x * 0.5
			"center_z": p.y = rect.position.y + rect.size.y * 0.5
			_: return 0
		state.set_position(str(row.id), p)
	return rows_out.size()

func distribute(state, axis: String) -> int:
	var rows_out := rows(state)
	if rows_out.size() < 3: return 0
	var sorted := rows_out.duplicate()
	sorted.sort_custom(func (a, b): return float(a["x" if axis == "x" else "z"]) < float(b["x" if axis == "x" else "z"]))
	var first_v := float(sorted[0]["x" if axis == "x" else "z"])
	var last_v := float(sorted[-1]["x" if axis == "x" else "z"])
	var step := (last_v - first_v) / float(sorted.size() -1)
	for i in range(1, sorted.size() -1):
		var row: Dictionary = sorted[i]
		if bool(row.get("locked", false)): continue
		var p := Vector2(float(row.x), float(row.z))
		if axis == "x": p.x = first_v + step * float(i)
		else: p.y = first_v + step * float(i)
		state.set_position(str(row.id), p)
	return sorted.size()
