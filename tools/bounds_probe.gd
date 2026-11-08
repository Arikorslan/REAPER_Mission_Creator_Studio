extends SceneTree


const Library = preload("res://scripts/asset_library.gd")
const Codec = preload("res://scripts/glb_codec.gd")

func _initialize() -> void: run.call_deferred()


func true_bounds(root: Node3D) -> Dictionary:
	var box := AABB(); var first := true
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null: continue
		var skeleton: Skeleton3D = null
		if mi.skin != null:
			var parent := mi.get_parent()
			while parent != null and not (parent is Skeleton3D): parent = parent.get_parent()
			if parent is Skeleton3D: skeleton = parent
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
			var skinned := mi.skin != null and skeleton != null and bones.size() > 0 and weights.size() > 0
			var bone_xforms: Array = []
			if skinned:
				for b in mi.skin.get_bind_count():
					var name := mi.skin.get_bind_name(b)
					var bone := skeleton.find_bone(name)
					var bind := mi.skin.get_bind_pose(b)
					if bone >= 0:
						bone_xforms.append(skeleton.global_transform * skeleton.get_bone_global_pose(bone) * bind)
					else:
						bone_xforms.append(mi.global_transform)
			var step: int = maxi(1, int(verts.size() / 4000))
			for i in range(0, verts.size(), step):
				var v := verts[i]
				if skinned and bones.size() >= (i + 1) * 4 and weights.size() >= (i + 1) * 4:
					var idx := i * 4
					var acc := Vector3.ZERO
					for k in 4:
						var w: float = weights[idx + k]
						if w <= 0.0: continue
						var bone_index: int = bones[idx + k]
						if bone_index < 0 or bone_index >= bone_xforms.size(): continue
						acc += ((bone_xforms[bone_index] as Transform3D) * v) * w
					var p := acc
					box = AABB(p, Vector3.ZERO) if first else box.expand(p); first = false
				else:
					var p2: Vector3 = mi.global_transform * v
					box = AABB(p2, Vector3.ZERO) if first else box.expand(p2); first = false
	return { "box": box, "ok": not first}

func run() -> void:
	var library = Library.new()
	for id in ["technical", "civilian", "tb2"]:
		var visual: Node3D = library.create_visual(id, {})
		var holder := Node3D.new()
		holder.add_child(visual)
		root.add_child(holder)
		await process_frame
		var exact := true_bounds(visual)
		var aabb := AABB(); var first := true
		for m in visual.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null: continue
			var b: AABB = mi.global_transform * mi.get_aabb()
			aabb = b if first else aabb.merge(b); first = false
		var e: AABB = exact.box
		print("%-9s exact size=%s | aabb size=%s | exact longest=%.2f m  aabb longest=%.2f m" % [
			id, str(e.size), str(aabb.size), maxf(e.size.x, maxf(e.size.y, e.size.z)), maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))])
		print("          exact centre=%s  min_y=%.2f" % [str(e.get_center()), e.position.y])
		holder.queue_free()
		await process_frame
	quit()
