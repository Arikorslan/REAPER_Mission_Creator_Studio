extends RefCounted












const Platform = preload("res://scripts/platform_files.gd")

const SETTINGS_PATH := "user://creator_folders.json"
const MARKER := "REAPER_creator_folder.txt"
const MARKER_TEXT := "This folder was created by REAPER Mission Creator.\nDelete it from the creator's SAVE FOLDERS panel to remove this folder and the drafts inside it.\n"
const MAX_NAME := 48
const MAX_FOLDERS := 24
const RESERVED := [".", "..", "con", "prn", "aux", "nul", "com1", "com2", "com3", "com4", "com5", "com6", "com7", "com8", "com9", "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6", "lpt7", "lpt8", "lpt9"]

var root := ""
var folders: Array = []
var android := false
var last_error := ""

func _init():
	android = Platform.is_android()

func load_state() -> void:
	folders = []
	root = ""
	if not FileAccess.file_exists(SETTINGS_PATH): return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if not parsed is Dictionary: return
	root = str(parsed.get("root", ""))
	for entry in parsed.get("folders", []):
		var name := str(entry)
		if valid_name(name).ok and not folders.has(name): folders.append(name)

func save_state() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify({ "schema": 1, "root": root, "folders": folders}, "\t"))
	file.close()

func set_root(path: String) -> void:
	root = path.strip_edges()
	folders = []
	last_error = ""
	save_state()

func has_root() -> bool:
	return not root.is_empty()

func root_label() -> String:
	if root.is_empty(): return "No save folder chosen"
	if Platform.is_document_uri(root):
		var hash_index := root.find("#")
		if hash_index >= 0: return "Android folder: " + root.substr(hash_index + 1).uri_decode()
		var cut := root.rfind("/")
		return "Android folder: " + (root.substr(cut + 1).uri_decode() if cut >= 0 else root)
	return root

static func valid_name(candidate: String) -> Dictionary:
	var name := candidate.strip_edges()
	if name.is_empty(): return { "ok": false, "error": "Type a folder name first."}
	if name.length() > MAX_NAME: return { "ok": false, "error": "Folder names are limited to %d characters." % MAX_NAME}
	if name.begins_with("."): return { "ok": false, "error": "Folder names cannot start with a dot."}
	for forbidden in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", "\n", "\r", "\t"]:
		if name.contains(forbidden): return { "ok": false, "error": "Folder names cannot contain " + forbidden + "."}
	if RESERVED.has(name.to_lower()): return { "ok": false, "error": "That name is reserved by the system."}
	return { "ok": true, "error": "", "name": name}

func folder_target(name: String) -> String:

	if root.is_empty(): return ""
	if Platform.is_document_uri(root): return root + "#" + name
	return root.path_join(name)

func document_path(folder: String, file_name: String) -> String:
	var target := folder_target(folder)
	if target.is_empty(): return ""
	if Platform.is_document_uri(target): return target + "/" + file_name
	return target.path_join(file_name)

func marker_path(folder: String) -> String:
	return document_path(folder, MARKER)

func folder_exists(name: String) -> bool:
	if not valid_name(name).ok: return false
	var marker := marker_path(name)
	if marker.is_empty(): return false
	return FileAccess.file_exists(marker)

func known(name: String) -> bool:
	return folders.has(name)

func list_folders() -> Array:

	var rows: Array = []
	for name in folders:
		rows.append({ "name": name, "exists": folder_exists(name), "registered": true})
	return rows

func create_folder(candidate: String) -> Dictionary:
	last_error = ""
	if root.is_empty(): return _fail("Choose a save folder first: SAVE FOLDERS > CHOOSE FOLDER.")
	var checked := valid_name(candidate)
	if not checked.ok: return _fail(str(checked.error))
	var name: String = checked.name
	if folders.has(name):
		return _fail("A creator folder called \"" + name + "\" already exists here." if folder_exists(name) else "A creator folder called \"" + name + "\" is already in the list; delete it first to start again.")
	if folders.size() >= MAX_FOLDERS: return _fail("This creator keeps up to %d folders. Delete one first." % MAX_FOLDERS)
	var target := folder_target(name)
	if Platform.is_document_uri(target):
		var marker := document_path(name, MARKER)
		var file := FileAccess.open(marker, FileAccess.WRITE)
		if file == null: return _fail("The selected Android folder did not allow a new sub-folder. Some providers (for example a read-only cloud folder) refuse this.")
		file.store_string(MARKER_TEXT); file.flush()
		var io_error := file.get_error()
		file.close()
		if io_error != OK: return _fail("The Android provider refused to finish creating the folder.")
	else:
		var absolute := target
		if absolute.begins_with("user://"): absolute = ProjectSettings.globalize_path(absolute)
		var err := DirAccess.make_dir_recursive_absolute(absolute)
		if err != OK and err != ERR_ALREADY_EXISTS: return _fail("Could not create the folder here (error %d)." % err)
		var marker := document_path(name, MARKER)
		var file := FileAccess.open(marker, FileAccess.WRITE)
		if file == null: return _fail("The folder could not be marked; the device may be read-only.")
		file.store_string(MARKER_TEXT); file.flush()
		var io_error := file.get_error()
		file.close()
		if io_error != OK: return _fail("The folder marker could not be written.")
	if not folder_exists(name):
		return _fail("The folder was reported as created but could not be verified.")
	folders.append(name)
	save_state()
	return { "ok": true, "error": "", "name": name, "target": folder_target(name)}

func delete_folder(name: String) -> Dictionary:
	last_error = ""
	if not folders.has(name): return _fail("Only folders created here can be deleted from the creator.")
	if not folder_exists(name): return _fail("This folder no longer contains the creator marker, so it was left untouched. Remove it from the list only.")
	if Platform.is_document_uri(root):
		var java_result := _android_delete_folder(name)
		if not java_result.ok: return _fail(str(java_result.error))
	else:
		var absolute := folder_target(name)
		if absolute.begins_with("user://"): absolute = ProjectSettings.globalize_path(absolute)
		var err := _delete_local_tree(absolute)
		if err != OK: return _fail("Could not delete the folder (error %d)." % err)
	if folder_exists(name): return _fail("The folder could not be removed; it may contain files another app is using.")
	folders.erase(name)
	save_state()
	return { "ok": true, "error": "", "name": name}

func forget_folder(name: String) -> Dictionary:

	if not folders.has(name): return _fail("That folder is not in the list.")
	folders.erase(name)
	save_state()
	return { "ok": true, "error": ""}

func _fail(message: String) -> Dictionary:
	last_error = message
	return { "ok": false, "error": message}

func _delete_local_tree(absolute: String) -> int:

	if absolute.is_empty() or not absolute.is_absolute_path(): return ERR_INVALID_PARAMETER
	var directory := DirAccess.open(absolute)
	if directory == null: return ERR_CANT_OPEN
	for file_name in Array(directory.get_files()):
		var err := directory.remove(str(file_name))
		if err != OK: return err
	for folder_name in Array(directory.get_directories()):
		var child := absolute.path_join(str(folder_name))
		var err := _delete_local_tree(child)
		if err != OK: return err
		err = DirAccess.remove_absolute(child)
		if err != OK: return err
	return DirAccess.remove_absolute(absolute)

func _android_delete_folder(name: String) -> Dictionary:



	if not Engine.has_singleton("AndroidRuntime"):
		return { "ok": false, "error": "The Android runtime is unavailable, so the folder was left in place. Delete it from the Files app."}
	var runtime = Engine.get_singleton("AndroidRuntime")
	var activity = runtime.getActivity()
	if activity == null:
		return { "ok": false, "error": "The Android activity is unavailable, so the folder was left in place."}
	var uri_class = JavaClassWrapper.wrap("android.net.Uri")
	if uri_class == null: return { "ok": false, "error": "Android URI support is unavailable on this build."}
	var uri = uri_class.parse(root)
	if _document_file_delete(activity, uri, name): return { "ok": true, "error": ""}
	if _documents_contract_delete(activity, uri, name): return { "ok": true, "error": ""}
	var java_error := str(JavaClassWrapper.get_exception())
	return { "ok": false, "error": "Android refused to delete this folder" + (": " + java_error if not java_error.is_empty() and java_error != "<null>" else "") +". Delete it from the system Files app instead."}

func _document_file_delete(activity, uri, name: String) -> bool:
	var document_file = JavaClassWrapper.wrap("androidx.documentfile.provider.DocumentFile")
	if document_file == null: return false
	var tree = document_file.fromTreeUri(activity, uri)
	if tree == null: return false
	var child = tree.findFile(name)
	if child == null: return false
	if not bool(child.isDirectory()): return false
	var deleted = bool(child.delete())
	return deleted and not folder_exists(name)

func _documents_contract_delete(activity, uri, name: String) -> bool:
	var contract = JavaClassWrapper.wrap("android.provider.DocumentsContract")
	if contract == null: return false
	var tree_id = str(contract.getTreeDocumentId(uri))
	if tree_id.is_empty(): return false
	var document_uri = contract.buildDocumentUriUsingTree(uri, tree_id + "/" + name)
	if document_uri == null: return false
	var deleted = bool(contract.deleteDocument(activity.getContentResolver(), document_uri))
	return deleted and not folder_exists(name)

func take_persistable_grant() -> bool:



	if not Platform.is_document_uri(root): return false
	if not Engine.has_singleton("AndroidRuntime"): return false
	var runtime = Engine.get_singleton("AndroidRuntime")
	var activity = runtime.getActivity()
	if activity == null: return false
	var uri_class = JavaClassWrapper.wrap("android.net.Uri")
	if uri_class == null: return false
	activity.getContentResolver().takePersistableUriPermission(uri_class.parse(root), 3)
	var error = str(JavaClassWrapper.get_exception())
	return error.is_empty() or error == "<null>"
