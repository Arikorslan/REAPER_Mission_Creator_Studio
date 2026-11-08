extends SceneTree


const State = preload("res://scripts/mission_state.gd")
const Paint = preload("res://scripts/terrain_paint.gd")
const Bake = preload("res://scripts/ground_bake.gd")
const Export = preload("res://scripts/scene_export.gd")
const Codec = preload("res://scripts/glb_codec.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var state = State.new()
	state.reset_blank()
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			img.set_pixel(x, y, Color(0.82, 0.68, 0.26) if ((x / 32) +(y / 32)) % 2 == 0 else Color(0.26, 0.42, 0.18))
	var png := img.save_png_to_buffer()
	var tex := "tex_" + Codec.sha256(png)
	state.custom_assets[tex] = { "name": "checker", "bytes": png, "category": "texture"}
	state.data["terrain_texture"] = tex
	state.data["terrain_tile_m"] = 100.0
	var layer := Image.create(256, 256, false, Image.FORMAT_RGB8)
	layer.fill(Color(0.16, 0.36, 0.72))
	var lpng := layer.save_png_to_buffer()
	var ltex := "tex_" + Codec.sha256(lpng)
	state.custom_assets[ltex] = { "name": "blue", "bytes": lpng, "category": "texture"}
	var mask := Paint.blank()
	for y in Paint.MASK_SIZE:
		for x in Paint.MASK_SIZE:
			mask.set_pixel(x, y, Color(1, 0, 0, 0) if x < Paint.MASK_SIZE / 2 else Color(0, 0, 0, 0))
	state.data["terrain_paint"] = { "resolution": Paint.MASK_SIZE, "layers": [ltex], "mask": Paint.encode(mask)}
	var snow := Image.create(Paint.SNOW_SIZE, Paint.SNOW_SIZE, false, Image.FORMAT_RGBA8)
	for y in Paint.SNOW_SIZE:
		for x in Paint.SNOW_SIZE:
			snow.set_pixel(x, y, Color(1, 1, 1, 1) if y < Paint.SNOW_SIZE / 2 else Color(0, 0, 0, 0))
	state.data["snow_paint"] = { "resolution": Paint.SNOW_SIZE, "mask": Paint.snow_encode(snow)}
	state.data["snow_cover"] = 0.8
	state.data["wetness"] = 0.35
	var out: Image = Bake.bake(state, Export.texture_lookup(state.custom_assets), 1024)
	DirAccess.make_dir_recursive_absolute("/tmp/ground_probe")
	var path := "/tmp/ground_probe/ground_bake_preview.png"
	out.save_png(path)
	print("GROUND saved ", path, " ", out.get_width(), "x", out.get_height(),
		" west=", out.get_pixel(64, 256).to_html(false),
		" east=", out.get_pixel(448, 256).to_html(false),
		" corner=", out.get_pixel(8, 8).to_html(false),
		" north=", out.get_pixel(256, 64).to_html(false), " south=", out.get_pixel(256, 448).to_html(false))
	quit(0)
