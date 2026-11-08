extends RefCounted









const Paint = preload("res://scripts/terrain_paint.gd")
const Terrain = preload("res://scripts/terrain_model.gd")



const BAKE_SIZE := 1024

const NORMAL_GRID := 96
const DEFAULT_BASE_COLOUR := Color("baa986")



static func settings(state) -> Dictionary:
	var data: Dictionary = state.data
	var terrain: Dictionary = data.get("terrain", {})
	var paint: Dictionary = data.get("terrain_paint", {})
	var environment: Dictionary = data.get("environment", {})
	var mask: Image = state.paint_image() if not paint.is_empty() else null
	var snow: Image = state.snow_image() if data.has("snow_paint") else null
	return {
		"extent": float(terrain.get("extent", Terrain.EXTENT)),
		"tile_m": clampf(float(data.get("terrain_tile_m", 80.0)), 5.0, 500.0),
		"base_id": str(data.get("terrain_texture", "")),
		"layers": (paint.get("layers", []) as Array).duplicate(),
		"mask": mask,
		"snow_mask": snow,
		"snow_cover": clampf(float(environment.get("snow_cover", 0.0)), 0.0, 1.0),
		"snow_colour": _snow_colour(environment),
		"wet": clampf(float(environment.get("wet", 0.0)), 0.0, 1.0),
	}

static func _snow_colour(environment: Dictionary) -> Color:

	var tint := clampf(float(environment.get("snow_tint", 0.0)), 0.0, 1.0)
	return Color(0.95, 0.97, 0.99).lerp(Color(0.82, 0.87, 0.95), tint)


static func has_surface(settings_map: Dictionary) -> bool:
	return not str(settings_map.get("base_id", "")).is_empty() or not (settings_map.get("layers", []) as Array).is_empty() or settings_map.get("mask", null) != null or settings_map.get("snow_mask", null) != null or float(settings_map.get("snow_cover", 0.0)) > 0.001



static func bake(state, texture_for: Callable, size: int = BAKE_SIZE) -> Image:
	var map := settings(state)
	var out := Image.create(size, size, false, Image.FORMAT_RGB8)
	var base: Image = _rgb(map.get("base_id", ""), texture_for)
	var base_colour := Color.WHITE if base != null else DEFAULT_BASE_COLOUR
	var repeat := maxf(1.0, (2.0 * float(map.extent)) / float(map.tile_m))
	var layer_images: Array = []
	for id in map.layers:
		layer_images.append(_rgb(str(id), texture_for))



	base = _minified(base, repeat, size)
	for i in layer_images.size():
		layer_images[i] = _minified(layer_images[i], repeat, size)
	var mask: Image = map.mask
	var snow: Image = map.snow_mask
	var snow_cover := float(map.snow_cover)
	var snow_colour: Color = map.snow_colour
	var wet := float(map.wet)
	if base == null and layer_images.is_empty() and snow == null and snow_cover <= 0.001:

		out.fill(base_colour)
		return out
	var flat := _flatness(state)
	var base_bytes := base.get_data() if base != null else PackedByteArray()
	var base_w := base.get_width() if base != null else 1
	var base_h := base.get_height() if base != null else 1
	var layer_data: Array = []
	for image in layer_images:
		var img: Image = image
		layer_data.append({ "bytes": img.get_data() if img != null else PackedByteArray(),
			"w": img.get_width() if img != null else 1, "h": img.get_height() if img != null else 1})
	var mask_bytes := mask.get_data() if mask != null else PackedByteArray()
	var mask_w := mask.get_width() if mask != null else 1
	var snow_bytes := snow.get_data() if snow != null else PackedByteArray()
	var snow_w := snow.get_width() if snow != null else 1
	var snow_stride := snow.get_data().size() / maxi(1, snow_w * snow_w) if snow != null else 4
	var out_bytes := out.get_data()
	var stride := size * 3
	for py in size:
		var v: float = float(py) / float(maxi(1, size - 1))
		var row := py * stride
		for px in size:
			var u: float = float(px) / float(maxi(1, size - 1))
			var r := base_colour.r; var g := base_colour.g; var b := base_colour.b
			if not base_bytes.is_empty():
				var sample: Vector3 = _sample(base_bytes, base_w, base_h, u * repeat, v * repeat)
				var s := sample
				r = s.x * base_colour.r; g = s.y * base_colour.g; b = s.z * base_colour.b
			if not mask_bytes.is_empty():
				var m: Array = _sample_rgba(mask_bytes, mask_w, u, v)
				for i in mini(layer_data.size(), Paint.MAX_LAYERS):
					var channel: float = float(m[i])
					if channel <= 0.002: continue
					var entry: Dictionary = layer_data[i]
					if (entry["bytes"] as PackedByteArray).is_empty(): continue
					var t: Vector3 = _sample(entry["bytes"], int(entry["w"]), int(entry["h"]), u * repeat, v * repeat)
					r = lerpf(r, t.x, channel); g = lerpf(g, t.y, channel); b = lerpf(b, t.z, channel)
			var settle := 0.0
			var normal_y: float = _flatness_at(flat, u, v)
			settle = smoothstep(0.45, 0.95, normal_y) * snow_cover
			if not snow_bytes.is_empty():
				var painted: float = _sample_gray(snow_bytes, snow_w, snow_stride, u, v)
				settle = maxf(settle, painted * smoothstep(0.2, 0.62, normal_y))
			if settle > 0.001:
				r = lerpf(r, snow_colour.r, settle); g = lerpf(g, snow_colour.g, settle); b = lerpf(b, snow_colour.b, settle)
			if wet > 0.001:
				var shade: float = 1.0 - 0.35 * wet * (1.0 - settle)
				r *= shade; g *= shade; b *= shade
			var o := row + px * 3
			out_bytes[o] = clampi(int(r * 255.0), 0, 255)
			out_bytes[o + 1] = clampi(int(g * 255.0), 0, 255)
			out_bytes[o + 2] = clampi(int(b * 255.0), 0, 255)
	out.set_data(size, size, false, Image.FORMAT_RGB8, out_bytes)
	return out

static func _rgb(id: Variant, texture_for: Callable) -> Image:
	var key := str(id)
	if key.is_empty(): return null
	var image: Image = texture_for.call(key)
	if image == null: return null
	if image.get_format() != Image.FORMAT_RGB8:
		image = image.duplicate()
		image.convert(Image.FORMAT_RGB8)
	return image

static func _minified(image: Image, repeat: float, size: int) -> Image:
	if image == null: return null
	var texels_per_pixel := repeat * float(image.get_width()) / float(maxi(1, size))
	var factor := int(minf(16.0, maxf(1.0, floor(texels_per_pixel))))
	if factor < 2: return image
	var copy := image.duplicate()
	var w := maxi(1, image.get_width() / factor)
	var h := maxi(1, image.get_height() / factor)
	copy.resize(w, h, Image.INTERPOLATE_LANCZOS)
	return copy



static func _sample(bytes: PackedByteArray, w: int, h: int, u: float, v: float) -> Vector3:
	if bytes.is_empty(): return Vector3.ONE
	var fx := u * float(w) -0.5
	var fy := v * float(h) -0.5
	var x0 := int(floor(fx)); var y0 := int(floor(fy))
	var tx := fx - float(x0); var ty := fy - float(y0)
	var x1 := x0 + 1; var y1 := y0 + 1
	x0 = ((x0 % w) +w) % w; x1 = ((x1 % w) +w) % w
	y0 = ((y0 % h) +h) % h; y1 = ((y1 % h) +h) % h
	var o00 := (y0 * w + x0) * 3; var o10 := (y0 * w + x1) * 3
	var o01 := (y1 * w + x0) * 3; var o11 := (y1 * w + x1) * 3
	if o11 + 2 >= bytes.size(): return Vector3.ONE
	var top := Vector3(bytes[o00], bytes[o00 + 1], bytes[o00 + 2]).lerp(
		Vector3(bytes[o10], bytes[o10 + 1], bytes[o10 + 2]), tx)
	var bottom := Vector3(bytes[o01], bytes[o01 + 1], bytes[o01 + 2]).lerp(
		Vector3(bytes[o11], bytes[o11 + 1], bytes[o11 + 2]), tx)
	return top.lerp(bottom, ty) / 255.0


static func _sample_rgba(bytes: PackedByteArray, size: int, u: float, v: float) -> Array:
	var x := clampi(int(u * float(size - 1)), 0, size - 1)
	var y := clampi(int(v * float(size - 1)), 0, size - 1)
	var o := (y * size + x) * 4
	if o + 3 >= bytes.size(): return [0.0, 0.0, 0.0, 0.0]
	return [float(bytes[o]) / 255.0, float(bytes[o + 1]) / 255.0, float(bytes[o + 2]) / 255.0, float(bytes[o + 3]) / 255.0]


static func _sample_gray(bytes: PackedByteArray, size: int, stride: int, u: float, v: float) -> float:
	var x := clampi(int(u * float(size - 1)), 0, size - 1)
	var y := clampi(int(v * float(size - 1)), 0, size - 1)
	var o := (y * size + x) * maxi(1, stride)
	if o >= bytes.size(): return 0.0
	return float(bytes[o]) / 255.0


static func _flatness(state) -> Dictionary:
	var terrain: Dictionary = state.data.get("terrain", {})
	var extent := float(terrain.get("extent", Terrain.EXTENT))
	var cell := maxf(1.0, Terrain.cell_size(terrain))
	var grid := PackedFloat32Array(); grid.resize(NORMAL_GRID * NORMAL_GRID)
	for j in NORMAL_GRID:
		for i in NORMAL_GRID:
			var x := lerpf(- extent, extent, float(i) / float(NORMAL_GRID - 1))
			var z := lerpf(- extent, extent, float(j) / float(NORMAL_GRID - 1))
			var l := Terrain.height_at(terrain, [], x - cell, z)
			var r := Terrain.height_at(terrain, [], x + cell, z)
			var up := Terrain.height_at(terrain, [], x, z - cell)
			var down := Terrain.height_at(terrain, [], x, z + cell)
			var normal := Vector3(l - r, 2.0 * cell, up - down).normalized()
			grid[j * NORMAL_GRID + i] = clampf(normal.y, 0.0, 1.0)
	return { "grid": grid}

static func _flatness_at(flat: Dictionary, u: float, v: float) -> float:
	var grid: PackedFloat32Array = flat.grid
	var x := clampi(int(u * float(NORMAL_GRID - 1)), 0, NORMAL_GRID - 1)
	var y := clampi(int(v * float(NORMAL_GRID - 1)), 0, NORMAL_GRID - 1)
	return grid[y * NORMAL_GRID + x]
