extends SceneTree


const State = preload("res://scripts/mission_state.gd")
const Library = preload("res://scripts/asset_library.gd")
const Export = preload("res://scripts/scene_export.gd")
const Paint = preload("res://scripts/terrain_paint.gd")
const Terrain = preload("res://scripts/terrain_model.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var state = State.new()
	state.reset_blank()

	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			img.set_pixel(x, y, Color(0.82, 0.68, 0.26) if ((x / 16) +(y / 16)) % 2 == 0 else Color(0.26, 0.42, 0.18))
	var png := img.save_png_to_buffer()
	var tex := "tex_" + preload("res://scripts/glb_codec.gd").sha256(png)
	state.custom_assets[tex] = { "name": "checker", "bytes": png, "category": "texture"}
	state.data["terrain_texture"] = tex
	state.data["terrain_tile_m"] = 50.0
	var mask := Paint.blank()
	for y in Paint.MASK_SIZE:
		for x in Paint.MASK_SIZE:
			if x < Paint.MASK_SIZE / 2: mask.set_pixel(x, y, Color(1, 0, 0, 0))
	state.data["terrain_paint"] = { "resolution": Paint.MASK_SIZE, "layers": [tex], "mask": Paint.encode(mask)}

	state.add_object("house", Vector2(-40, 20))
	state.add_object("compound", Vector2(15, -25))
	state.add_object("humvee", Vector2(60, 60))
	state.add_object("technical", Vector2(-70, -50))
	state.add_object("civilian", Vector2(90, -80))
	state.add_object("technical", Vector2(-120, 30))
	state.add_object("drone_start", Vector2(0, 120))
	state.add_object("terrain_hill", Vector2(150, 150))
	state.add_object("terrain_mountain", Vector2(-160, 160))
	var rows: Array = state.data["objects"]
	rows[0]["yaw_deg"] = 35.0; rows[0]["scale"] = 1.8
	rows[1]["pitch_deg"] = 12.0; rows[1]["roll_deg"] = -7.0; rows[1]["yaw_deg"] = 120.0
	rows[3]["yaw_deg"] = -60.0; rows[3]["scale"] = 2.5
	state.data["name"] = "Probe Mission"
	state.data["recon_target"] = str(rows[2]["id"])
	DirAccess.make_dir_recursive_absolute("/tmp/pack_probe")
	var pack: Dictionary = Export.build_pack(state, Library.new())
	print("PACK ok=", pack.get("ok"), " err=", pack.get("error", ""), " bytes=", (pack.get("bytes", PackedByteArray()) as PackedByteArray).size(), " files=", pack.get("files", []))
	if bool(pack.get("ok", false)):
		var f := FileAccess.open("/tmp/pack_probe/REAPER_3D_Export.zip", FileAccess.WRITE)
		f.store_buffer(pack.bytes); f.close()
	quit(0)
