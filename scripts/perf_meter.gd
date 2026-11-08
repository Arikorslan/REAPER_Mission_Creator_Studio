extends RefCounted

const Terrain = preload("res://scripts/terrain_model.gd")
const PHONE_OBJECT_BUDGET := 150
const PHONE_TRIANGLE_BUDGET := 900000
var _fps_samples: Array = []
var last: Dictionary = {}

func sample(state) -> Dictionary:
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var draw := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var objects := 0
	if state != null: objects = Array(state.data.get("objects", [])).size()
	_fps_samples.append(fps)
	while _fps_samples.size() > 30: _fps_samples.pop_front()
	var average := 0.0
	for v in _fps_samples: average += float(v)
	if not _fps_samples.is_empty(): average /= float(_fps_samples.size())
	last = { "fps": fps, "average_fps": average, "draw_calls": draw, "primitives": prims, "objects": objects}
	return last

func label() -> String:
	return "%d fps · %d obj" % [int(last.get("fps", 0)), int(last.get("objects", 0))]

func budget_warning(state) -> String:
	var issues: Array = []
	if int(last.get("objects", 0)) > PHONE_OBJECT_BUDGET: issues.append("over %d objects" % PHONE_OBJECT_BUDGET)
	var prims := int(last.get("primitives", 0))
	if prims > PHONE_TRIANGLE_BUDGET: issues.append("over %dk primitives" % (PHONE_TRIANGLE_BUDGET / 1000))
	if state != null:
		var terrain: Dictionary = state.data.get("terrain", {})
		var cell := Terrain.cell_size(terrain)
		var km := Terrain.width_m(terrain) / 1000.0


		if km > 24.0: issues.append("ground is %.0f km across: long draw distances" % km)
		if cell > 420.0: issues.append("ground cells are %.0f m wide: sculpting this size only shapes broad landforms" % cell)
	return "" if issues.is_empty() else "Phone budget: " + ", ".join(issues)

func is_phone_safe() -> bool: return budget_warning(null).is_empty()
