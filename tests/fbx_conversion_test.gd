extends SceneTree
## Run with a user-provided FBX to test the real converter: -- <input.fbx>
const Fbx = preload("res://scripts/fbx_converter.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1: print("Expected one FBX path"); quit(2); return
	var data := FileAccess.get_file_as_bytes(args[0])
	var result := Fbx.convert(data, true, true)
	print("FBX_INPUT_BYTES ", data.size())
	print("FBX_CONVERSION ", "PASS" if bool(result.get("ok", false)) else "FAIL", " ", str(result.get("error", "")))
	if bool(result.get("ok", false)): print("FBX_OUTPUT_GLB_BYTES ", (result.bytes as PackedByteArray).size())
	quit(0 if bool(result.get("ok", false)) else 1)
