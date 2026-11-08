extends RefCounted


const Terrain = preload("res://scripts/terrain_model.gd")
const MIN_H := -150.0
const MAX_H := 600.0
const MAX_EDGE := 257
const MIN_EDGE := 17

static func _crc_table() -> Array:
	var table: Array = []
	for n in 256:
		var c := n
		for k in 8:
			c = 3988292384 ^ (c >> 1) if (c & 1) != 0 else c >> 1
		table.append(c)
	return table
static var _CRC: Array = []

static func crc32(bytes: PackedByteArray) -> int:
	if _CRC.is_empty(): _CRC = _crc_table()
	var crc := -1
	for b in bytes:
		crc = int(_CRC[(crc ^ b) & 255]) ^ (crc >> 8)
	return (crc ^ -1) & 4294967295

static func _chunk(kind: String, payload: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(_u32(payload.size()))
	var head := kind.to_utf8_buffer()
	out.append_array(head); out.append_array(payload)
	var crc_body := PackedByteArray(); crc_body.append_array(head); crc_body.append_array(payload)
	out.append_array(_u32(crc32(crc_body)))
	return out
static func _u32(value: int) -> PackedByteArray:
	var out := PackedByteArray(); out.resize(4)
	out.encode_u32(0, value & 4294967295); return out

static func encode_png16(width: int, height: int, samples: Array) -> PackedByteArray:
	var png := PackedByteArray()
	png.append_array(PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]))
	var ihdr := PackedByteArray(); ihdr.append_array(_u32(width)); ihdr.append_array(_u32(height))
	ihdr.append_array(PackedByteArray([16, 0, 0, 0, 0]))
	png.append_array(_chunk("IHDR", ihdr))
	var raw := PackedByteArray(); raw.resize(height * (1 + width * 2))
	var offset := 0
	for j in height:
		raw[offset] = 0; offset += 1
		for i in width:
			var v := int(samples[j * width + i]) if j * width + i < samples.size() else 0
			v = clampi(v, 0, 65535)
			raw[offset] = (v >> 8) & 255; raw[offset + 1] = v & 255; offset += 2
	png.append_array(_chunk("IDAT", raw.compress(FileAccess.COMPRESSION_DEFLATE)))
	png.append_array(_chunk("IEND", PackedByteArray()))
	return png

static func decode_png(bytes: PackedByteArray) -> Dictionary:
	var fail := { "ok": false, "message": "Not a PNG file", "width": 0, "height": 0, "samples": []}
	if bytes.size() < 33 or bytes[0] != 137 or bytes[1] != 80: return fail
	var pos := 8
	var width := 0
	var height := 0
	var depth := 0
	var color := 0
	var data := PackedByteArray()
	while pos + 8 <= bytes.size():
		var length := bytes.decode_u32(pos)
		var kind := bytes.slice(pos + 4, pos + 8).get_string_from_utf8()
		var payload := bytes.slice(pos + 8, pos + 8 + length)
		pos += 12 + length
		if kind == "IHDR":
			width = int(payload.decode_u32(0)); height = int(payload.decode_u32(4)); depth = int(payload[8]); color = int(payload[9])
		elif kind == "IDAT": data.append_array(payload)
		elif kind == "IEND": break
	if width <= 0 or height <= 0: return fail
	if depth not in [8, 16]: return { "ok": false, "message": "Only 8-bit and 16-bit PNG heightmaps are supported", "width": width, "height": height, "samples": []}
	var channels := 1
	match color:
		0: channels = 1
		2: channels = 3
		4: channels = 2
		6: channels = 4
		3: return { "ok": false, "message": "Palette PNGs are not supported; save as grayscale", "width": width, "height": height, "samples": []}
		_: return { "ok": false, "message": "Unsupported PNG colour type", "width": width, "height": height, "samples": []}
	var bpp := channels * (depth / 8)
	var stride := width * bpp
	var raw := data.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)
	if raw.size() < height * (stride + 1): return { "ok": false, "message": "Truncated PNG data", "width": width, "height": height, "samples": []}
	var samples: Array = []; samples.resize(width * height)
	var prev := PackedByteArray(); prev.resize(stride)
	var at := 0
	for j in height:
		var filter := raw[at]; at += 1
		var line := raw.slice(at, at + stride); at += stride
		_unfilter(filter, line, prev, bpp, stride)
		for i in width:
			var base := i * bpp
			var value: int
			if depth == 16: value = (int(line[base]) << 8) | int(line[base + 1])
			else: value = int(line[base]) * 257
			samples[j * width + i] = value
		prev = line
	return { "ok": true, "message": "Loaded %dx%d heightmap" % [width, height], "width": width, "height": height, "samples": samples, "depth": depth, "color": color}

static func _unfilter(filter: int, line: PackedByteArray, prev: PackedByteArray, bpp: int, stride: int) -> void:
	for i in stride:
		var a := int(line[i - bpp]) if i >= bpp else 0
		var b := int(prev[i]) if prev.size() > i else 0
		var c := int(prev[i - bpp]) if (i >= bpp and prev.size() > i - bpp) else 0
		match filter:
			0: pass
			1: line[i] = (int(line[i]) +a) & 255
			2: line[i] = (int(line[i]) +b) & 255
			3: line[i] = (int(line[i]) +((a + b) >> 1)) & 255
			4:
				var p := a + b - c
				var pa := absi(p - a); var pb := absi(p - b); var pc := absi(p - c)
				var pred := a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
				line[i] = (int(line[i]) +pred) & 255
			_: pass

static func apply_to_state(state, decoded: Dictionary, min_height := MIN_H, max_height := MAX_H, additive := false) -> Dictionary:
	if state == null or not bool(decoded.get("ok", false)): return { "ok": false, "message": "No heightmap data"}
	var w := int(decoded.width); var h := int(decoded.height)
	var old: Dictionary = state.data.get("terrain", {})


	var keep_extent := float(old.get("extent", 0.0)) if Terrain.valid(old) else 0.0
	var n := clampi(maxi(w, h), Terrain.RESOLUTION, MAX_EDGE)
	if keep_extent > 0.0:
		var needed := int(ceil(2.0 * keep_extent / Terrain.MAX_CELL)) +1
		n = clampi(maxi(n, needed), Terrain.RESOLUTION, Terrain.MAX_RESOLUTION)
	var fresh := Terrain.empty(n, keep_extent)
	var heights: Array = fresh.heights
	var old_n := int(old.get("resolution", 0))
	var old_heights: Array = old.get("heights", [])
	var samples: Array = decoded.get("samples", [])
	var lowest := INF
	var highest := -INF
	for j in n:
		for i in n:
			var u := float(i) / float(n - 1); var v := float(j) / float(n - 1)
			var sx := clampi(int(round(u * float(w - 1))), 0, w - 1)
			var sy := clampi(int(round(v * float(h - 1))), 0, h - 1)
			var sample := float(samples[sy * w + sx]) / 65535.0
			var value := lerpf(min_height, max_height, sample)
			if additive and old_n > 1 and old_heights.size() == old_n * old_n:
				var ou := clampi(int(round(u * float(old_n - 1))), 0, old_n - 1)
				var ov := clampi(int(round(v * float(old_n - 1))), 0, old_n - 1)
				value += float(old_heights[ov * old_n + ou])
			value = clampf(value, Terrain.MIN_HEIGHT, Terrain.MAX_HEIGHT)
			heights[j * n + i] = value
			lowest = minf(lowest, value); highest = maxf(highest, value)
	fresh["heights"] = heights
	state.data["terrain"] = fresh
	state.bounded_objects()
	state.dirty = true
	state.changed.emit("terrain")
	return { "ok": true, "message": "Heightmap applied (%dx%d grid, %.0f m to %.0f m)" % [n, n, lowest, highest], "resolution": n, "lowest": lowest, "highest": highest}

static func export_png(state, resolution := 65) -> Dictionary:
	if state == null: return { "ok": false, "message": "No mission"}
	var n := clampi(resolution, MIN_EDGE, MAX_EDGE)
	var terrain: Dictionary = state.data.get("terrain", {})
	var src_n := int(terrain.get("resolution", 0))
	var heights: Array = terrain.get("heights", [])
	if src_n < 2 or heights.size() != src_n * src_n: return { "ok": false, "message": "No terrain to export"}
	var samples: Array = []; samples.resize(n * n)
	for j in n:
		for i in n:
			var u := float(i) / float(n - 1); var v := float(j) / float(n - 1)
			var sx := clampi(int(round(u * float(src_n - 1))), 0, src_n - 1)
			var sy := clampi(int(round(v * float(src_n - 1))), 0, src_n - 1)
			var value := clampf(float(heights[sy * src_n + sx]), MIN_H, MAX_H)
			samples[j * n + i] = clampi(int(round((value - MIN_H) / (MAX_H - MIN_H) * 65535.0)), 0, 65535)
	return { "ok": true, "message": "Exported %dx%d heightmap" % [n, n], "bytes": encode_png16(n, n, samples), "resolution": n, "filesize": n * n * 2}
