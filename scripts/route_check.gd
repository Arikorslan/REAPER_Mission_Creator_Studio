extends RefCounted





const Terrain = preload("res://scripts/terrain_model.gd")

const GRADE_WARN := 0.35
const GRADE_FAIL := 0.75
const SAMPLE_STEP := 8.0
const OBSTACLE_CLEARANCE := 1.6



static func check(state) -> Dictionary:
	var result := { "ok": true, "issues": [], "checked": 0, "longest": 0.0, "grounded": 0, "flying": 0}
	if state == null or state.data == null:
		result["ok"] = false
		return result
	var terrain: Dictionary = state.data.get("terrain", {})
	var objects: Array = state.data.get("objects", [])
	var extent := float(terrain.get("extent", Terrain.EXTENT))
	for row in objects:
		if not row is Dictionary:
			continue
		var points: Array = row.get("route", [])
		if points.is_empty():
			continue
		result["checked"] = int(result.checked) +1
		var legs := _legs(row, points)
		var name_ := str(row.get("name", row.get("asset", "object")))
		var id := str(row.get("id", ""))

		for leg in legs:
			for p in leg:
				var point: Vector2 = p
				if absf(point.x) > extent or absf(point.y) > extent:
					result.issues.append({ "severity": "fail", "object_id": id, "object_name": name_,
						"message": "Waypoint %.0f, %.0f m is outside the ground (limit ±%.0f m)." % [point.x, point.y, extent]})
					break

		var longest := _length(legs)
		if float(longest) > float(result.longest):
			result.longest = longest
		var steepest := 0.0
		for leg in legs:
			var pairs: Array = _samples(leg, terrain, objects)
			for i in maxi(0, pairs.size() -1):
				var a: Dictionary = pairs[i]
				var b: Dictionary = pairs[i + 1]
				if a.point == b.point:
					continue
				var run := (a.point as Vector2).distance_to(b.point)
				if run < 0.5:
					continue
				var rise := float(b.height) -float(a.height)
				steepest = maxf(steepest, absf(rise) / run)
		if steepest >= GRADE_FAIL:
			result.issues.append({ "severity": "fail", "object_id": id, "object_name": name_,
				"message": "Route climbs %.0f%% grade (%.1f m rise per 10 m). Nothing ground-based can follow it." % [steepest * 100.0, steepest * 10.0]})
		elif steepest >= GRADE_WARN:
			result.issues.append({ "severity": "warn", "object_id": id, "object_name": name_,
				"message": "Route reaches %.0f%% grade. Slow vehicles will struggle; smooth it or add a switchback." % [steepest * 100.0]})

		var asset := str(row.get("asset", ""))
		if not Terrain.is_feature(asset) and asset not in ["drone_start", "road_path", "brick_wall"]:
			var hits := _obstacles(objects, legs, str(id))
			if not hits.is_empty():
				result.issues.append({ "severity": "warn", "object_id": id, "object_name": name_,
					"message": "Route passes within %.0f m of %s. Wings and mirrors have to fit." % [OBSTACLE_CLEARANCE + 1.0, ", ".join(hits.slice(0, 4))]})

		if float(longest) < 10.0:
			result.issues.append({ "severity": "note", "object_id": id, "object_name": name_,
				"message": "Route is only %.1f m long; the object will barely move." % float(longest)})

		if asset == "drone_start":
			result["flying"] = int(result.flying) +1
		else:
			result["grounded"] = int(result.grounded) +1
	result["ok"] = _count(result.issues, "fail") == 0
	return result

static func _legs(row: Dictionary, points: Array) -> Array:
	var out: Array = []
	var closed := bool(row.get("route_face", true))
	var loop: Array = []
	loop.append(Vector2(float(row.get("x", 0.0)), float(row.get("z", 0.0))))
	for p in points:
		if p is Array and p.size() >= 2:
			loop.append(Vector2(float(p[0]), float(p[1])))
	if loop.size() < 2:
		return out
	out.append(loop)
	if closed:
		out.append([loop[loop.size() -1], loop[0]])
	return out



static func _samples(leg: Array, terrain: Dictionary, objects: Array) -> Array:
	var out: Array = []
	for i in leg.size() -1:
		var a: Vector2 = leg[i]
		var b: Vector2 = leg[i + 1]
		var steps := maxi(1, int(ceil(a.distance_to(b) / SAMPLE_STEP)))
		for s in steps + 1:
			var t := float(s) / float(steps)
			var point := a.lerp(b, t)
			out.append({ "point": point, "height": Terrain.height_at(terrain, objects, point.x, point.y)})
	return out

static func _length(legs: Array) -> float:
	var total := 0.0
	for leg in legs:
		for i in leg.size() -1:
			total += (leg[i] as Vector2).distance_to(leg[i + 1])
	return total

static func _obstacles(objects: Array, legs: Array, skip_id: String) -> Array:
	var hits: Array = []
	for row in objects:
		if not row is Dictionary or str(row.get("id", "")) == skip_id:
			continue
		var asset := str(row.get("asset", ""))
		if asset in ["road_path", "brick_wall", "drone_start", "crate"]:
			continue
		var point := Vector2(float(row.get("x", 0.0)), float(row.get("z", 0.0)))
		for leg in legs:
			for i in leg.size() -1:
				var closest := Geometry2D.get_closest_point_to_segment(point, leg[i], leg[i + 1])
				if point.distance_to(closest) <= OBSTACLE_CLEARANCE:
					var name_ := str(row.get("name", asset))
					if not hits.has(name_):
						hits.append(name_)
					break
	return hits

static func _count(issues: Array, severity: String) -> int:
	var total := 0
	for issue in issues:
		if str((issue as Dictionary).get("severity", "")) == severity:
			total += 1
	return total

static func counts(result: Dictionary) -> Dictionary:
	var out := { "fail": 0, "warn": 0, "note": 0}
	for issue in result.get("issues", []):
		var severity := str((issue as Dictionary).get("severity", "note"))
		out[severity] = int(out.get(severity, 0)) +1
	return out


static func report(result: Dictionary) -> String:
	var c := counts(result)
	if int(result.get("checked", 0)) == 0:
		return "No routes to check. Draw a route with the ROUTE tool, or select an object and add waypoints."
	var lines: Array = []
	lines.append("%d route(s) checked • %d problem(s): %d fail, %d warn, %d note" % [
		int(result.checked), int(c.fail) +int(c.warn) +int(c.note), int(c.fail), int(c.warn), int(c.note)])
	lines.append("Longest route %.0f m • %d ground object(s) • %d air start(s)" % [
		float(result.get("longest", 0.0)), int(result.get("grounded", 0)), int(result.get("flying", 0))])
	if int(c.fail) +int(c.warn) +int(c.note) == 0:
		lines.append("Every route stays on the ground, inside the map, with a walkable grade.")
	for issue in result.get("issues", []):
		var row: Dictionary = issue
		var tag: String = str({ "fail": "FAIL", "warn": "WARN", "note": "NOTE"}.get(str(row.severity), "NOTE"))
		lines.append("%s  %s — %s" % [tag, str(row.object_name), str(row.message)])
	return "\n".join(lines)
