extends RefCounted

const SEVERITY_ORDER := { "error": 0, "warning": 1, "info": 2}

func check(state) -> Array:
	var out: Array = []
	if state == null: return out
	var objects: Array = state.data.get("objects", [])
	var extent: float = state.extent()
	out.append_array(_scene_rules(state, objects, extent))
	out.append_array(_object_rules(state, objects, extent))
	out.append_array(_mission_rules(state, objects))
	return out

func _issue(severity: String, code: String, message: String, object_id := "") -> Dictionary:
	return { "severity": severity, "code": code, "message": message, "object_id": object_id}

func _scene_rules(state, objects: Array, extent: float) -> Array:
	var out: Array = []
	if objects.is_empty(): out.append(_issue("warning", "empty_scene", "Scene is empty: add terrain features, buildings or actors."))
	if objects.size() > 150: out.append(_issue("warning", "object_budget", "%d objects is heavy for phones; keep under 150." % objects.size()))
	var hidden := 0
	for row: Dictionary in objects:
		if bool(row.get("hidden", false)): hidden += 1
	if hidden > 0: out.append(_issue("info", "hidden_objects", "%d hidden object(s) will still export." % hidden))
	return out

func _object_rules(state, objects: Array, extent: float) -> Array:
	var out: Array = []
	for row: Dictionary in objects:
		var id := str(row.get("id", ""))
		var label := str(row.get("name", id))
		var p := Vector2(float(row.get("x", 0)), float(row.get("z", 0)))
		var asset := str(row.get("asset", ""))
		if asset.is_empty(): out.append(_issue("error", "missing_asset", "%s has no asset." % label, id))
		elif not state.custom_assets.has(asset) and not _builtin(asset): out.append(_issue("error", "missing_asset", "%s uses a missing asset: %s." % [label, asset], id))
		if absf(p.x) > extent - 2.0 or absf(p.y) > extent - 2.0: out.append(_issue("warning", "at_edge", "%s sits on the terrain edge." % label, id))
		var route: Array = row.get("route", [])
		if route.size() == 1: out.append(_issue("warning", "short_route", "%s has a route with one waypoint." % label, id))
		if asset in ["road_path", "brick_wall"] and Array(row.get("path", [])).size() < 2: out.append(_issue("warning", "open_construction", "%s is a single point; drag it into a line." % label, id))
		var texture := str(row.get("texture", ""))
		if not texture.is_empty() and not state.custom_assets.has(texture): out.append(_issue("error", "missing_texture", "%s points at a missing texture." % label, id))
	return out

func _mission_rules(state, objects: Array) -> Array:
	var out: Array = []
	var target := str(state.data.get("recon_target", ""))
	if target.is_empty(): out.append(_issue("warning", "no_recon_target", "No recon target set, so the flight test cannot be completed."))
	elif state.find_object(target).is_empty(): out.append(_issue("error", "bad_recon_target", "The recon target object no longer exists."))
	if str(state.data.get("name", "")) in ["", "Untitled mission"]: out.append(_issue("info", "default_name", "Give the mission a real name before exporting."))
	if str(state.data.get("briefing", "")).strip_edges().is_empty(): out.append(_issue("info", "empty_briefing", "Briefing is empty."))
	var seen: Dictionary = {}
	for row: Dictionary in objects:
		var key := "%s@%d/%d" % [str(row.get("asset", "")), roundi(float(row.get("x", 0))), roundi(float(row.get("z", 0)))]
		if seen.has(key):
			out.append(_issue("warning", "overlap", "%s overlaps %s." % [str(row.get("name", "object")), str(seen[key])], str(row.get("id", ""))))
		else: seen[key] = str(row.get("name", "object"))
	return out

func _builtin(id: String) -> bool:
	for row: Dictionary in preload("res://scripts/asset_library.gd").BUILTINS:
		if str(row.get("id", "")) == id: return true
	return id in ["road_path", "brick_wall"]

func counts(issues: Array) -> Dictionary:
	var out := { "error": 0, "warning": 0, "info": 0}
	for row: Dictionary in issues:
		var key := str(row.get("severity", "info"))
		out[key] = int(out.get(key, 0)) +1
	return out

func summary(issues: Array) -> String:
	var c := counts(issues)
	if issues.is_empty(): return "No problems found"
	return "%d error(s), %d warning(s), %d note(s)" % [int(c.error), int(c.warning), int(c.info)]

func sorted(issues: Array) -> Array:
	var out := issues.duplicate()
	out.sort_custom(func (a, b):
		var sa := int(SEVERITY_ORDER.get(str(a.get("severity", "info")), 2))
		var sb := int(SEVERITY_ORDER.get(str(b.get("severity", "info")), 2))
		if sa != sb: return sa < sb
		return str(a.get("message", "")) < str(b.get("message", "")))
	return out
