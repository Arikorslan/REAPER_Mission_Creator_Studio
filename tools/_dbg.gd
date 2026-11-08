extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var bytes := FileAccess.get_file_as_bytes("/tmp/export_probe2/scene.glb")
	var doc := GLTFDocument.new(); var gs := GLTFState.new()
	print("err=", doc.append_from_buffer(bytes, "", gs))
	var r: Node3D = doc.generate_scene(gs, 30.0, false, false)
	for child in r.get_children():
		var n3 := child as Node3D
		var meshes := n3.find_children("*", "MeshInstance3D", true, false)
		print("TOP ", n3.name, " meshes=", meshes.size(), " pos=", n3.position, " owner=", child.owner)
		var owned_meshes := n3.find_children("*", "MeshInstance3D", true, true)
		print("    owned-only meshes=", owned_meshes.size())
	quit()
