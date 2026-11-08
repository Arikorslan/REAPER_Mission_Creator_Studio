extends RefCounted



const Codec = preload("res://scripts/glb_codec.gd")

static func clips_from_node(node: Node) -> PackedStringArray:
	var names := PackedStringArray()
	for p: AnimationPlayer in node.find_children("*", "AnimationPlayer", true, false):
		for name in p.get_animation_list():
			var a := p.get_animation(name)
			if a != null and a.get_track_count() > 0 and not names.has(str(name)): names.append(str(name))
	names.sort(); return names
static func clips_from_bytes(bytes: PackedByteArray) -> PackedStringArray:
	var result := Codec.import_model(bytes, true)
	if not result.ok: return PackedStringArray()
	var scene: Node = result.model; var clips := clips_from_node(scene); scene.free(); return clips
static func _canonical(bone: String) -> String:
	var s := bone.to_lower().replace(":", "_").replace(" ", "")

	var at := s.rfind("_")
	if at >= 0:
		var suffix := s.substr(at + 1)
		if suffix.length() > 1 and suffix.begins_with("0") and suffix.is_valid_int(): s = s.left(at)
	return s
static func _player_with_clip(scene: Node, clip: String) -> AnimationPlayer:
	for p: AnimationPlayer in scene.find_children("*", "AnimationPlayer", true, false):
		if p.has_animation(clip): return p
	return null
static func _install(player: AnimationPlayer, clip: Animation, looping: bool, speed: float) -> void:
	var copy := clip.duplicate(true) as Animation; copy.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	if player.has_animation_library("reaper_preview"): player.remove_animation_library("reaper_preview")
	var lib := AnimationLibrary.new(); lib.add_animation("clip", copy); player.add_animation_library("reaper_preview", lib)
	player.active = true; player.speed_scale = clampf(speed, 0.1, 5.0); player.play("reaper_preview/clip")
static func attach(visual: Node3D, row: Dictionary, assets: Dictionary) -> Dictionary:
	var source := str(row.get("animation_source", "")); var clip_name := str(row.get("animation_clip", ""))
	if source.is_empty() or clip_name.is_empty(): return { "ok": false, "error": "No animation selected."}
	var looping := bool(row.get("animation_loop", true)); var speed := float(row.get("animation_speed", 1.0))
	if source == "embedded":
		var p := _player_with_clip(visual, clip_name)
		if p == null: return { "ok": false, "error": "This model does not contain the selected animation."}
		var anim := p.get_animation(clip_name); _install(p, anim, looping, speed)
		return { "ok": true, "player": p, "matched_tracks": anim.get_track_count()}
	if not assets.has(source): return { "ok": false, "error": "Animation file is missing."}
	var parsed := Codec.import_model(assets[source].get("bytes", PackedByteArray()), true)
	if not parsed.ok: return { "ok": false, "error": str(parsed.error)}
	var src: Node = parsed.model; var source_player := _player_with_clip(src, clip_name)
	if source_player == null: src.free(); return { "ok": false, "error": "The imported file has no matching animation clip."}
	var targets := visual.find_children("*", "Skeleton3D", true, false)
	var sources := src.find_children("*", "Skeleton3D", true, false)
	if targets.is_empty() or sources.is_empty(): src.free(); return { "ok": false, "error": "Separate animations need a compatible named skeleton in both files."}
	var source_skeleton: Skeleton3D = sources[0]; var target: Skeleton3D = targets[0]; var target_lookup := {}
	for j in target.get_bone_count(): target_lookup[_canonical(str(target.get_bone_name(j)))] = j
	var anim := source_player.get_animation(clip_name).duplicate(true) as Animation; var matched := 0
	for i in range(anim.get_track_count() -1, -1, -1):
		var path := anim.track_get_path(i)
		if anim.track_get_type(i) != Animation.TYPE_ROTATION_3D or path.get_subname_count() != 1:
			anim.remove_track(i); continue
		var bone := str(path.get_subname(0)); var src_index := source_skeleton.find_bone(bone); var key := _canonical(bone)
		if src_index < 0 or not target_lookup.has(key): anim.remove_track(i); continue
		var dst_index: int = target_lookup[key]; var dst_bone := str(target.get_bone_name(dst_index))
		var src_rest := source_skeleton.get_bone_rest(src_index).basis.get_rotation_quaternion()
		var dst_rest := target.get_bone_rest(dst_index).basis.get_rotation_quaternion()
		for k in anim.track_get_key_count(i):
			var value = anim.track_get_key_value(i, k)
			if value is Quaternion: anim.track_set_key_value(i, k, (dst_rest * src_rest.inverse() * value).normalized())
		anim.track_set_path(i, NodePath(str(visual.get_path_to(target)) +":" + dst_bone)); matched += 1
	if matched == 0: src.free(); return { "ok": false, "error": "No compatible named bones were found; use a matching rig or retarget externally."}
	var player := AnimationPlayer.new(); player.name = "ReaperExternalAnimation"; visual.add_child(player); player.root_node = NodePath("..")
	_install(player, anim, looping, speed); src.free()
	return { "ok": true, "player": player, "matched_tracks": matched}



static func own_clip(visual: Node3D, row: Dictionary) -> Dictionary:
	var wanted := str(row.get("animation_clip", ""))
	for p: AnimationPlayer in visual.find_children("*", "AnimationPlayer", true, false):
		var list := p.get_animation_list()
		if list.is_empty(): continue
		var clip := wanted
		if clip.is_empty() or not p.has_animation(clip):
			clip = str(list[0])
			var autoplay := str(p.autoplay)
			if not autoplay.is_empty() and p.has_animation(autoplay): clip = autoplay
		var anim := p.get_animation(clip)
		if anim == null or anim.get_track_count() == 0: continue
		p.active = true
		p.speed_scale = clampf(float(row.get("animation_speed", 1.0)), 0.1, 5.0)
		p.play(clip)
		return { "ok": true, "player": p, "clip": clip, "tracks": anim.get_track_count(),
			"looping": anim.loop_mode != Animation.LOOP_NONE, "own": true}
	return { "ok": false, "error": "This model has no animation of its own."}
