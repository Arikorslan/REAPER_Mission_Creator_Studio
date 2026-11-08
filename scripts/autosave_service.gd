extends RefCounted


const Store = preload("res://scripts/draft_store.gd")
const DIR := "user://autosave"
const VERSIONS := 4
const INTERVAL_MS := 20000
var interval_ms := INTERVAL_MS
var last_write_ms := 0
var last_result: Dictionary = {}
var dir := DIR

func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(dir): DirAccess.make_dir_recursive_absolute(dir)

func version_path(slot: int) -> String:
	return "%s/autosave_%d.rmdraft" % [dir, slot]

func should_write(now_ms: int, dirty: bool, canvas_empty := false) -> bool:
	if not dirty or canvas_empty: return false
	if last_write_ms == 0: return true
	return now_ms - last_write_ms >= interval_ms

func write(state, now_ms: int = 0) -> Dictionary:
	_ensure_dir()
	var slot := _oldest_slot()
	var path := version_path(slot)
	var result: Dictionary = Store.save_draft(path, state.data, state.custom_assets)
	last_write_ms = now_ms if now_ms > 0 else Time.get_ticks_msec()
	last_result = result
	return result

func _oldest_slot() -> int:
	var best := 0
	var best_time := 1 << 62
	for slot in VERSIONS:
		var path := version_path(slot)
		if not FileAccess.file_exists(path): return slot
		var stamp := FileAccess.get_modified_time(path)
		if stamp < best_time: best_time = stamp; best = slot
	return best

func list_versions() -> Array:
	var out: Array = []
	for slot in VERSIONS:
		var path := version_path(slot)
		if not FileAccess.file_exists(path): continue
		var handle := FileAccess.open(path, FileAccess.READ)
		var size := handle.get_length() if handle != null else 0
		if handle != null: handle.close()
		out.append({ "slot": slot, "path": path, "time": FileAccess.get_modified_time(path), "size": size})
	out.sort_custom(func (a, b): return int(a.time) > int(b.time))
	return out

func latest() -> Dictionary:
	var rows := list_versions()
	return {} if rows.is_empty() else rows[0]

func clear_versions() -> void:
	for row: Dictionary in list_versions():
		DirAccess.remove_absolute(str(row.path))
