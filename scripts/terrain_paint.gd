extends RefCounted


const MASK_SIZE := 512
const MAX_LAYERS := 4
const MAX_MASK_BYTES := 1200000
const MAX_BASE64_CHARS := 1600000

static func blank() -> Image:
	var image := Image.create(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0)); return image

static func encode(image: Image) -> String:
	return _png_encode(image, MASK_SIZE)

static func _png_encode(image: Image, size: int) -> String:
	if image == null: return ""


	var copy := image
	if image.get_width() != size or image.get_height() != size:
		copy = image.duplicate()
		copy.resize(size, size, Image.INTERPOLATE_BILINEAR)
	return Marshalls.raw_to_base64(copy.save_png_to_buffer())

static func _be32(bytes: PackedByteArray, i: int) -> int:
	return (int(bytes[i]) << 24) | (int(bytes[i + 1]) << 16) | (int(bytes[i + 2]) << 8) | int(bytes[i + 3])

static func decode(value: Variant) -> Image:
	return _png_decode(value, MASK_SIZE)

static func _png_decode(value: Variant, size: int) -> Image:
	if not value is String or value.length() < 32 or value.length() > MAX_BASE64_CHARS: return null
	var bytes := Marshalls.base64_to_raw(value)
	if bytes.size() < 24 or bytes.size() > MAX_MASK_BYTES or Marshalls.raw_to_base64(bytes) != value: return null
	if bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]) or bytes.slice(12, 16).get_string_from_ascii() != "IHDR": return null
	if _be32(bytes, 16) != size or _be32(bytes, 20) != size: return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK or image.get_width() != size or image.get_height() != size: return null
	image.convert(Image.FORMAT_RGBA8); return image

static func validate(value: Variant, assets: Dictionary) -> Dictionary:
	if not value is Dictionary: return { "ok": false, "error": "Invalid terrain paint mask."}
	var resolution = value.get("resolution", 0)
	if typeof(resolution) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(resolution)) or float(resolution) != MASK_SIZE: return { "ok": false, "error": "Invalid terrain paint mask."}
	var layers = value.get("layers", [])
	if not layers is Array or layers.is_empty() or layers.size() > MAX_LAYERS: return { "ok": false, "error": "Terrain paint supports one to four texture layers."}
	var seen := {}
	for id in layers:
		if not id is String or id.is_empty() or seen.has(id) or not assets.has(id) or str(assets[id].get("category", "")) != "texture": return { "ok": false, "error": "A painted terrain texture is missing or repeated."}
		seen[id] = true
	if decode(value.get("mask", "")) == null: return { "ok": false, "error": "Invalid bounded terrain paint mask."}
	return { "ok": true, "error": ""}

static func stroke(image: Image, extent: float, point: Vector2, radius: float, strength: float, channel: int) -> bool:
	return stroke_segment(image, extent, point, point, radius, strength, channel)

static func stroke_segment(image: Image, extent: float, from: Vector2, to: Vector2, radius: float, strength: float, channel: int) -> bool:
	if image == null or extent <= 0 or not from.is_finite() or not to.is_finite() or channel < -1 or channel >= MAX_LAYERS: return false
	radius = clampf(radius, 1.0, 500.0); strength = clampf(strength, 0.1, 40.0)
	var scale := float(MASK_SIZE - 1) / (2.0 * extent); var a := (from + Vector2.ONE * extent) * scale; var b := (to + Vector2.ONE * extent) * scale; var r := maxf(0.5, radius * scale)
	var left := maxi(0, int(floor(minf(a.x, b.x) -r))); var right := mini(MASK_SIZE - 1, int(ceil(maxf(a.x, b.x) +r)))
	var top := maxi(0, int(floor(minf(a.y, b.y) -r))); var bottom := mini(MASK_SIZE - 1, int(ceil(maxf(a.y, b.y) +r)))
	var vector := b - a; var length_squared := vector.length_squared(); var changed := false
	for j in range(top, bottom + 1):
		for i in range(left, right + 1):
			var pixel := Vector2(float(i), float(j)); var t := clampf((pixel - a).dot(vector) / length_squared, 0.0, 1.0) if length_squared > 1e-05 else 0.0
			var distance := pixel.distance_to(a + vector * t) / r
			if distance >= 1.0: continue
			var falloff := 1.0 - smoothstep(0.1, 1.0, distance); var alpha := clampf(strength / 20.0 * falloff, 0.0, 1.0)
			var c := image.get_pixel(i, j); var v := [c.r, c.g, c.b, c.a]
			for k in MAX_LAYERS: v[k] = lerpf(float(v[k]), 1.0 if k == channel else 0.0, alpha)
			var next := Color(v[0], v[1], v[2], v[3])
			if not c.is_equal_approx(next): image.set_pixel(i, j, next); changed = true
	return changed

static func expanded(image: Image, old_extent: float, new_extent: float) -> Image:
	var out := blank()
	if image == null or old_extent <= 0 or new_extent <= old_extent: return out
	var size := clampi(int(round(float(MASK_SIZE) * old_extent / new_extent)), 1, MASK_SIZE)
	var smaller := image.duplicate(); smaller.resize(size, size, Image.INTERPOLATE_BILINEAR)
	var offset := (MASK_SIZE - size) / 2
	out.blit_rect(smaller, Rect2i(0, 0, size, size), Vector2i(offset, offset)); return out


static func without_layer(image: Image, layer: int) -> Image:
	if image == null or layer < 0 or layer >= MAX_LAYERS or image.get_format() != Image.FORMAT_RGBA8: return null
	var bytes := image.get_data()
	for i in range(0, bytes.size(), 4):
		if layer <= 0: bytes[i] = bytes[i + 1]
		if layer <= 1: bytes[i + 1] = bytes[i + 2]
		if layer <= 2: bytes[i + 2] = bytes[i + 3]
		bytes[i + 3] = 0
	return Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, bytes)





const SNOW_MIN_COVER := 0.02


const SNOW_SIZE := 256

static func snow_blank() -> Image:
	var image := Image.create(SNOW_SIZE, SNOW_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0)); return image


static func snow_stroke(image: Image, extent: float, from: Vector2, to: Vector2, radius: float, strength: float, erase := false) -> bool:
	if image == null or extent <= 0 or not from.is_finite() or not to.is_finite(): return false
	radius = clampf(radius, 1.0, 500.0); strength = clampf(strength, 0.1, 40.0)
	if image.get_width() != SNOW_SIZE or image.get_height() != SNOW_SIZE: return false
	var scale := float(SNOW_SIZE - 1) / (2.0 * extent); var a := (from + Vector2.ONE * extent) * scale; var b := (to + Vector2.ONE * extent) * scale; var r := maxf(0.5, radius * scale)
	var left := maxi(0, int(floor(minf(a.x, b.x) -r))); var right := mini(SNOW_SIZE - 1, int(ceil(maxf(a.x, b.x) +r)))
	var top := maxi(0, int(floor(minf(a.y, b.y) -r))); var bottom := mini(SNOW_SIZE - 1, int(ceil(maxf(a.y, b.y) +r)))
	var vector := b - a; var length_squared := vector.length_squared(); var changed := false
	for j in range(top, bottom + 1):
		for i in range(left, right + 1):
			var pixel := Vector2(float(i), float(j)); var t := clampf((pixel - a).dot(vector) / length_squared, 0.0, 1.0) if length_squared > 1e-05 else 0.0
			var distance := pixel.distance_to(a + vector * t) / r
			if distance >= 1.0: continue
			var falloff := 1.0 - smoothstep(0.1, 1.0, distance); var alpha := clampf(strength / 20.0 * falloff, 0.0, 1.0)
			var cover := clampf(image.get_pixel(i, j).r, 0.0, 1.0)
			var next := cover * (1.0 - alpha) if erase else maxf(cover, cover + alpha * (1.0 - cover))
			if absf(next - cover) < 0.002: continue
			image.set_pixel(i, j, Color(next, next, next, 1.0)); changed = true
	return changed

static func snow_encode(image: Image) -> String:
	return _png_encode(image, SNOW_SIZE)

static func snow_decode(value: Variant) -> Image:
	return _png_decode(value, SNOW_SIZE)


static func snow_present(value: Variant) -> bool:
	var image := snow_decode(value)
	if image == null: return false
	for j in SNOW_SIZE:
		for i in range(0, SNOW_SIZE, 2):
			if image.get_pixel(i, j).r > SNOW_MIN_COVER: return true
	return false

static func validate_snow(value: Variant) -> Dictionary:
	if not value is Dictionary: return { "ok": false, "error": "Invalid snow mask."}
	var resolution = value.get("resolution", 0)
	if typeof(resolution) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(resolution)) or float(resolution) != SNOW_SIZE: return { "ok": false, "error": "Invalid snow mask."}
	if snow_decode(value.get("mask", "")) == null: return { "ok": false, "error": "Invalid bounded snow mask."}
	return { "ok": true, "error": ""}
