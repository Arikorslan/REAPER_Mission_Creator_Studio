extends RefCounted


const MAX_TEXTURE_BYTES := 16 * 1024 * 1024
const MAX_DIMENSION := 4096
const MAX_PIXELS := 16 * 1024 * 1024
static func _be16(b: PackedByteArray, i: int) -> int: return (int(b[i]) << 8) | int(b[i + 1])
static func _be32(b: PackedByteArray, i: int) -> int: return (int(b[i]) << 24) | (int(b[i + 1]) << 16) | (int(b[i + 2]) << 8) | int(b[i + 3])
static func _size(b: PackedByteArray) -> Dictionary:
	if b.size() < 24 or b.size() > MAX_TEXTURE_BYTES: return { "ok": false, "error": "Texture must be between 24 bytes and 16 MiB."}
	if b.slice(0, 8) == PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		if b.slice(12, 16).get_string_from_ascii() != "IHDR": return { "ok": false, "error": "Invalid PNG header."}
		return { "ok": true, "format": "png", "width": _be32(b, 16), "height": _be32(b, 20)}
	if int(b[0]) == 255 and int(b[1]) == 216:
		var pos := 2
		while pos + 4 <= b.size():
			if int(b[pos]) != 255: pos += 1; continue
			while pos < b.size() and int(b[pos]) == 255: pos += 1
			if pos >= b.size(): break
			var marker := int(b[pos]); pos += 1
			if marker in [0, 216, 217] or (marker >= 208 and marker <= 215): continue
			if marker == 218 or pos + 2 > b.size(): break
			var length := _be16(b, pos)
			if length < 2 or pos + length > b.size(): break
			if marker in [192, 193, 194, 195, 197, 198, 199, 201, 202, 203, 205, 206, 207] and length >= 7:
				return { "ok": true, "format": "jpeg", "width": _be16(b, pos + 5), "height": _be16(b, pos + 3)}
			pos += length
	return { "ok": false, "error": "Choose a valid PNG or JPEG image."}
static func validate(b: PackedByteArray) -> Dictionary:
	var size := _size(b)
	if not size.ok: return size
	var w := int(size.width); var h := int(size.height)
	if w < 1 or h < 1 or w > MAX_DIMENSION or h > MAX_DIMENSION or w * h > MAX_PIXELS: return { "ok": false, "error": "Texture dimensions must be at most 4096 by 4096 and 16 megapixels."}
	var image := Image.new(); var error := image.load_png_from_buffer(b) if size.format == "png" else image.load_jpg_from_buffer(b)
	if error != OK or image.is_empty() or image.get_width() != w or image.get_height() != h: return { "ok": false, "error": "The image could not be decoded safely."}
	return { "ok": true, "format": size.format, "width": w, "height": h}
static func texture(b: PackedByteArray) -> ImageTexture:
	var valid := validate(b)
	if not valid.ok: return null
	var image := Image.new()
	var err := image.load_png_from_buffer(b) if valid.format == "png" else image.load_jpg_from_buffer(b)
	if err != OK: return null
	image.generate_mipmaps(); return ImageTexture.create_from_image(image)
static func apply_to_visual(visual: Node, texture: Texture2D) -> void:
	if texture == null: return
	for part: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null: continue
		if part.material_override != null:
			var material: BaseMaterial3D
			if part.material_override is BaseMaterial3D: material = part.material_override.duplicate(true)
			else: material = StandardMaterial3D.new()
			material.albedo_texture = texture; material.albedo_color = Color.WHITE; part.material_override = material
			continue
		for i in part.mesh.get_surface_count():
			var old := part.get_active_material(i); var material: BaseMaterial3D
			if old is BaseMaterial3D: material = old.duplicate(true)
			else: material = StandardMaterial3D.new()
			material.albedo_texture = texture; material.albedo_color = Color.WHITE; part.set_surface_override_material(i, material)
	for part: MultiMeshInstance3D in visual.find_children("*", "MultiMeshInstance3D", true, false):
		if part.multimesh == null or part.multimesh.mesh == null: continue
		var mesh: Mesh = part.multimesh.mesh.duplicate(true); part.multimesh.mesh = mesh
		for i in mesh.get_surface_count():
			var old := mesh.surface_get_material(i); var material: BaseMaterial3D
			if old is BaseMaterial3D: material = old.duplicate(true)
			else: material = StandardMaterial3D.new()
			material.albedo_texture = texture; material.albedo_color = Color.WHITE; mesh.surface_set_material(i, material)
