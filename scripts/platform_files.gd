extends RefCounted









const RECOVERY_DIR := "user://recovery"
const MAX_RECOVERY_COPIES := 8

static func is_android() -> bool:
	return OS.get_name() == "Android"

static func is_document_uri(path: String) -> bool:
	return path.begins_with("content://")

static func is_local_path(path: String) -> bool:
	return not is_document_uri(path) and (path.begins_with("/") or path.begins_with("user://") or path.begins_with("res://") or path.contains(":/"))

static func ensure_extension(path: String, extension: String) -> String:


	if is_document_uri(path) or path.is_empty(): return path
	var plain := extension.trim_prefix(".").to_lower()
	if plain.is_empty(): return path
	if path.get_extension().to_lower() == plain: return path
	return path + "." + plain

static func display_label(path: String) -> String:

	if path.is_empty(): return "no file selected"
	if is_document_uri(path):
		var cut := path.rfind("/")
		var tail := path.substr(cut + 1) if cut >= 0 else path
		tail = tail.uri_decode().strip_edges()
		return tail if not tail.is_empty() else "selected document"
	return path.get_file()

static func display_location(path: String) -> String:
	if path.is_empty(): return "no location selected"
	if is_document_uri(path):
		var hash_index := path.find("#")
		if hash_index >= 0: return "Android folder: " + path.substr(hash_index + 1).uri_decode()
		return "Android document: " + display_label(path)
	return path

static func _safe_recovery_name(path: String) -> String:
	var label := display_label(path).validate_filename()
	if label.is_empty(): label = "document"
	return str(Time.get_unix_time_from_system()).replace(".", "_") +"_" + label.left(60)

static func keep_recovery_copy(path: String, bytes: PackedByteArray) -> String:

	if bytes.is_empty(): return ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RECOVERY_DIR))
	var destination := RECOVERY_DIR.path_join(_safe_recovery_name(path))
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null: return ""
	file.store_buffer(bytes); file.flush()
	var failed := file.get_error() != OK
	file.close()
	if failed: return ""
	_prune_recovery_copies()
	return destination

static func _prune_recovery_copies() -> void:
	var directory := DirAccess.open(RECOVERY_DIR)
	if directory == null: return
	var names: Array = Array(directory.get_files())
	if names.size() <= MAX_RECOVERY_COPIES: return
	names.sort()
	for index in names.size() -MAX_RECOVERY_COPIES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RECOVERY_DIR.path_join(str(names[index]))))

static func write_document(path: String, bytes: PackedByteArray) -> Dictionary:

	if path.is_empty(): return { "ok": false, "error": "No destination selected.", "recovery": ""}
	if bytes.is_empty(): return { "ok": false, "error": "Nothing to write.", "recovery": ""}
	if is_document_uri(path): return _write_selected_document(path, bytes)
	return _write_local_path(path, bytes)

static func _write_selected_document(path: String, bytes: PackedByteArray) -> Dictionary:

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var kept_early := keep_recovery_copy(path, bytes)
		return { "ok": false, "error": "The selected document could not be opened for writing." + (" A recovery copy is in " + display_label(kept_early) +"." if not kept_early.is_empty() else ""), "recovery": kept_early}
	file.store_buffer(bytes); file.flush()
	var io_error := file.get_error()
	file.close()
	if io_error != OK:
		var kept := keep_recovery_copy(path, bytes)
		return { "ok": false, "error": "The document provider refused part of the write." + (" A recovery copy is in " + display_label(kept) +"." if not kept.is_empty() else ""), "recovery": kept}
	var check := FileAccess.open(path, FileAccess.READ)
	if check != null:
		var written := check.get_length()
		check.close()
		if written != bytes.size():
			var kept := keep_recovery_copy(path, bytes)
			return { "ok": false, "error": "The document is incomplete (%d of %d bytes)." % [written, bytes.size()] +(" A recovery copy is in " + display_label(kept) +"." if not kept.is_empty() else ""), "recovery": kept}
	return { "ok": true, "error": "", "recovery": "", "path": path}

static func _write_local_path(path: String, bytes: PackedByteArray) -> Dictionary:


	var parent := path.get_base_dir()
	if not parent.is_empty():
		if parent.begins_with("user://") or parent.begins_with("res://"):
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(parent))
		elif parent.begins_with("/"):
			DirAccess.make_dir_recursive_absolute(parent)
	var nonce := str(Time.get_ticks_usec()) +"_" + str(randi())
	var temp := path + ".reaper-tmp-" + nonce
	var backup := path + ".reaper-bak-" + nonce
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return { "ok": false, "error": "Cannot write the selected location.", "recovery": ""}
	file.store_buffer(bytes); file.flush()
	var io_error := file.get_error()
	file.close()
	if io_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
		return { "ok": false, "error": "Could not finish writing the file.", "recovery": ""}
	var dst := ProjectSettings.globalize_path(path)
	var src := ProjectSettings.globalize_path(temp)
	var bak := ProjectSettings.globalize_path(backup)
	var had_old := FileAccess.file_exists(path)
	if had_old and DirAccess.rename_absolute(dst, bak) != OK:
		DirAccess.remove_absolute(src)
		return { "ok": false, "error": "Cannot replace the existing file.", "recovery": ""}
	if DirAccess.rename_absolute(src, dst) != OK:
		var restored := true
		if had_old: restored = DirAccess.rename_absolute(bak, dst) == OK
		DirAccess.remove_absolute(src)
		return { "ok": false, "error": "Could not commit the file." + ("" if restored else " The previous version is at " + display_label(backup) +"."), "recovery": ""}
	if had_old: DirAccess.remove_absolute(bak)
	return { "ok": true, "error": "", "recovery": "", "path": path}

# Write large mission containers without joining all segments into another
# package-sized PackedByteArray. Local files retain the original atomic
# temporary-file/backup behavior. Android document providers get the same
# completeness check and an app-private recovery copy on failure.
static func write_document_parts(path: String, parts: Array, progress: Callable = Callable()) -> Dictionary:
	if path.is_empty(): return { "ok": false, "error": "No destination selected.", "recovery": ""}
	var expected := 0
	for part in parts:
		if not part is PackedByteArray: return { "ok": false, "error": "Invalid data segment.", "recovery": ""}
		expected += part.size()
	if expected <= 0: return { "ok": false, "error": "Nothing to write.", "recovery": ""}
	if is_document_uri(path): return _write_selected_parts(path, parts, expected, progress)
	return _write_local_parts(path, parts, expected, progress)

# Chunked writes make byte progress observable without constructing another
# package-sized buffer. A small slice exists only for the current 4 MiB chunk.
static func _store_parts(file: FileAccess, parts: Array, progress: Callable = Callable(), expected: int = 0) -> int:
	var written := 0
	if progress.is_valid(): progress.call(0, expected)
	for part: PackedByteArray in parts:
		if not progress.is_valid():
			file.store_buffer(part)
			var error := file.get_error()
			if error != OK: return error
			continue
		var offset := 0
		while offset < part.size():
			var end := mini(offset + 4 * 1024 * 1024, part.size())
			file.store_buffer(part.slice(offset, end))
			var error := file.get_error()
			if error != OK: return error
			written += end - offset
			offset = end
			progress.call(written, expected)
	file.flush()
	return file.get_error()

static func _keep_recovery_parts(path: String, parts: Array) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RECOVERY_DIR))
	var destination := RECOVERY_DIR.path_join(_safe_recovery_name(path))
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null: return ""
	var error := _store_parts(file, parts)
	file.close()
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destination))
		return ""
	_prune_recovery_copies()
	return destination

static func _write_selected_parts(path: String, parts: Array, expected: int, progress: Callable = Callable()) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var saved := _keep_recovery_parts(path, parts)
		return { "ok": false, "error": "The selected document could not be opened for writing." + (" A recovery copy is in " + display_label(saved) + "." if not saved.is_empty() else ""), "recovery": saved}
	var io_error := _store_parts(file, parts, progress, expected)
	file.close()
	if io_error != OK:
		var saved := _keep_recovery_parts(path, parts)
		return { "ok": false, "error": "The document provider refused part of the write." + (" A recovery copy is in " + display_label(saved) + "." if not saved.is_empty() else ""), "recovery": saved}
	var check := FileAccess.open(path, FileAccess.READ)
	if check != null:
		var written := check.get_length()
		check.close()
		if written != expected:
			var saved := _keep_recovery_parts(path, parts)
			return { "ok": false, "error": "The document is incomplete (%d of %d bytes)." % [written, expected] + (" A recovery copy is in " + display_label(saved) + "." if not saved.is_empty() else ""), "recovery": saved}
	return { "ok": true, "error": "", "recovery": "", "path": path}

static func _write_local_parts(path: String, parts: Array, expected: int, progress: Callable = Callable()) -> Dictionary:
	var parent := path.get_base_dir()
	if not parent.is_empty():
		if parent.begins_with("user://") or parent.begins_with("res://"):
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(parent))
		elif parent.begins_with("/"):
			DirAccess.make_dir_recursive_absolute(parent)
	var nonce := str(Time.get_ticks_usec()) + "_" + str(randi())
	var temp := path + ".reaper-tmp-" + nonce
	var backup := path + ".reaper-bak-" + nonce
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return { "ok": false, "error": "Cannot write the selected location.", "recovery": ""}
	var io_error := _store_parts(file, parts, progress, expected)
	file.close()
	if io_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
		return { "ok": false, "error": "Could not finish writing the file.", "recovery": ""}
	var dst := ProjectSettings.globalize_path(path)
	var src := ProjectSettings.globalize_path(temp)
	var bak := ProjectSettings.globalize_path(backup)
	var had_old := FileAccess.file_exists(path)
	if had_old and DirAccess.rename_absolute(dst, bak) != OK:
		DirAccess.remove_absolute(src)
		return { "ok": false, "error": "Cannot replace the existing file.", "recovery": ""}
	if DirAccess.rename_absolute(src, dst) != OK:
		var restored := true
		if had_old: restored = DirAccess.rename_absolute(bak, dst) == OK
		DirAccess.remove_absolute(src)
		return { "ok": false, "error": "Could not commit the file." + ("" if restored else " The previous version is at " + display_label(backup) + "."), "recovery": ""}
	if had_old: DirAccess.remove_absolute(bak)
	return { "ok": true, "error": "", "recovery": "", "path": path}

static func read_document(path: String, maximum: int) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return { "ok": false, "error": "Could not open the selected file."}
	if file.get_length() > maximum:
		file.close()
		return { "ok": false, "error": "Selected file is larger than the supported limit."}
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return { "ok": true, "bytes": bytes}

static func path_exists(path: String) -> bool:
	if path.is_empty(): return false
	return FileAccess.file_exists(path)
