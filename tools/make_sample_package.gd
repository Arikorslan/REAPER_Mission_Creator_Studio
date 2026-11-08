extends SceneTree


const State = preload("res://scripts/mission_state.gd")
const Library = preload("res://scripts/asset_library.gd")
const Export = preload("res://scripts/scene_export.gd")
const Paint = preload("res://scripts/terrain_paint.gd")
const Store = preload("res://scripts/draft_store.gd")
const Codec = preload("res://scripts/glb_codec.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var state = State.new()
	state.reset_blank()
	state.data["name"] = "Desert Recon (export sample)"
	state.data["region"] = "Wadi Hajar"
	state.data["briefing"] = "Photograph the command post east of the ridge, then recover over the ridge line."
	state.data["environment"] = { "hour": 16.5, "preset": "clear", "fog": 0.22, "cloud": 0.35,
		"rain": 0.0, "snow_fall": 0.0, "snow_cover": 0.0, "snow_tint": 0.0, "wet": 0.0,
		"wind": 7.0, "wind_dir": 110.0, "dust": 0.1}

	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			img.set_pixel(x, y, Color(0.82, 0.68, 0.26) if ((x / 32) +(y / 32)) % 2 == 0 else Color(0.55, 0.5, 0.28))
	var png := img.save_png_to_buffer()
	var tex := "tex_" + Codec.sha256(png)
	state.custom_assets[tex] = { "name": "Desert checker", "bytes": png, "category": "texture"}
	state.data["terrain_texture"] = tex
	state.data["terrain_tile_m"] = 80.0

	var layer := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			layer.set_pixel(x, y, Color(0.45, 0.36, 0.24).lerp(Color(0.62, 0.55, 0.4), float((x + y) % 32) / 32.0))
	var lpng := layer.save_png_to_buffer()
	var ltex := "tex_" + Codec.sha256(lpng)
	state.custom_assets[ltex] = { "name": "Riverbed sand", "bytes": lpng, "category": "texture"}
	var mask := Paint.blank()
	for y in Paint.MASK_SIZE:
		for x in Paint.MASK_SIZE:
			var centre := 0.3 + 0.05 * sin(float(y) / float(Paint.MASK_SIZE) * TAU)
			var distance := absf(float(x) / float(Paint.MASK_SIZE) -centre)
			mask.set_pixel(x, y, Color(clampf(1.0 - distance * 14.0, 0.0, 1.0), 0, 0, 0))
	state.data["terrain_paint"] = { "resolution": Paint.MASK_SIZE, "layers": [ltex], "mask": Paint.encode(mask)}

	var terrain: Dictionary = state.data["terrain"]
	for j in terrain.resolution:
		for i in terrain.resolution:
			var u := float(i) / float(terrain.resolution - 1)
			var v := float(j) / float(terrain.resolution - 1)
			terrain.heights[j * terrain.resolution + i] = 42.0 * exp(- pow((u - 0.68) / 0.16, 2.0)) * (0.7 + 0.3 * sin(v * PI))

	var house: String = state.add_object("house", Vector2(120, -160), "Command post")
	state.add_object("compound", Vector2(210, -240), "Depot")
	state.add_object("technical", Vector2(-140, 60), "Escort")
	state.add_object("civilian", Vector2(-260, 210), "Shepherd")
	state.add_object("drone_start", Vector2(-420, 420), "Air start")
	var hill: String = state.add_object("terrain_hill", Vector2(430, 330), "East ridge")
	var rows: Array = state.data["objects"]
	for row in rows:
		if str(row.id) == house:
			row["yaw_deg"] = 118.0
		if str(row.id) == hill:
			row["scale"] = 1.6
	state.set_mission("recon_target", house)
	state.set_mission("objectives", ["Photograph the command post", "Leave the area to the south"])
	var library = Library.new()
	var combined: Dictionary = Export.build_combined(state, library)
	if not bool(combined.get("ok", false)):
		print("SAMPLE failed: ", combined.get("error", ""))
		quit(1)
		return
	if not bool(combined.get("ok", false)):
		quit(1)
		return
	var fidelity := { "ok": true, "objects": int(combined.get("objects", 0)),
		"worst_placement_m": float(combined.get("worst_placement_m", 0.0))}
	var path := "/home/user/_creator/REAPER_Android_Creator_Work/sample/Desert_Recon_Sample_v4.rmission"
	var written: Dictionary = Store.save_mission_package(path, state.data, state.custom_assets,
		combined.bytes, Export.scene_block(state, fidelity))
	print("SAMPLE ok=", written.get("ok"), " err=", written.get("error", ""),
		" bytes=", written.get("bytes", 0), " objects=", written.get("objects", 0),
		" fidelity=", written.get("fidelity", {}))
	quit(0 if bool(written.get("ok", false)) else 1)
