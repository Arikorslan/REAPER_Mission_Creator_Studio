extends RefCounted




const Terrain = preload("res://scripts/terrain_model.gd")
const Routes = preload("res://scripts/route_check.gd")
const Weather = preload("res://scripts/environment.gd")
const Store = preload("res://scripts/draft_store.gd")

const OVERLAP_METRES := 1.5
const BURIED_HEIGHT := -0.5

static func build(state, version: String = "") -> Dictionary:
	if state == null or state.data == null:
		return { "ok": false, "text": "No scene is open.", "issues": 0}
	var terrain: Dictionary = state.data.get("terrain", {})
	var objects: Array = state.data.get("objects", [])
	var extent := float(terrain.get("extent", Terrain.EXTENT))
	var problems: Array = []
	var lines: Array = []

	var title := str(state.data.get("mission", {}).get("name", "Untitled"))
	lines.append("REAPER SCENE REPORT" + ("  •  creator %s" % version if not version.is_empty() else ""))
	lines.append(title)
	lines.append("")


	lines.append("GROUND")
	lines.append("  %.2f km across • %d × %d grid • cell %.1f m • height %d m to %d m" % [
		Terrain.width_m(terrain) / 1000.0, int(terrain.get("resolution", 65)), int(terrain.get("resolution", 65)),
		Terrain.cell_size(terrain), int(Terrain.MIN_HEIGHT), int(Terrain.MAX_HEIGHT)])
	var heights: Array = terrain.get("heights", [])
	if not heights.is_empty():
		var lowest := 1000000000.0
		var highest := -1000000000.0
		var total := 0.0
		for h in heights:
			var value := float(h)
			lowest = minf(lowest, value)
			highest = maxf(highest, value)
			total += value
		lines.append("  sculpted: lowest %.1f m, highest %.1f m, mean %.1f m" % [lowest, highest, total / float(heights.size())])
	lines.append("")


	var counts := {}
	var hidden := 0
	var outside := 0
	var buried := 0
	var no_route := 0
	var with_route := 0
	var air_starts := 0
	for row in objects:
		if not row is Dictionary:
			continue
		var asset := str(row.get("asset", ""))
		counts[asset] = int(counts.get(asset, 0)) +1
		if bool(row.get("hidden", false)):
			hidden += 1
		var x := float(row.get("x", 0.0))
		var z := float(row.get("z", 0.0))
		if absf(x) > extent or absf(z) > extent:
			outside += 1
		if asset == "drone_start":
			air_starts += 1
		elif float(row.get("height", 0.0)) < BURIED_HEIGHT:
			buried += 1
		var route: Array = row.get("route", [])
		if route.is_empty():
			if asset not in ["road_path", "brick_wall", "drone_start"] and float(row.get("speed_mps", 0.0)) > 0.0:
				no_route += 1
		else:
			with_route += 1

	lines.append("OBJECTS  (%d total)" % objects.size())
	var keys := counts.keys()
	keys.sort()
	for key in keys:
		lines.append("  %-18s %d" % [str(key), int(counts[key])])
	lines.append("")

	lines.append("PLACEMENT")
	lines.append("  %d hidden • %d outside the ground • %d sunk into the terrain • %d with a route" % [
		hidden, outside, buried, with_route])
	var overlaps := _overlaps(objects)
	if not overlaps.is_empty():
		for pair in overlaps.slice(0, 6):
			lines.append("  overlap: %s and %s" % [str(pair[0]), str(pair[1])])
		if overlaps.size() > 6:
			lines.append("  …and %d more close pair(s)" % (overlaps.size() -6))
	if outside > 0:
		problems.append("%d object(s) sit outside the ground." % outside)
	if buried > 0:
		problems.append("%d object(s) are sunk below the terrain." % buried)
	if not overlaps.is_empty():
		problems.append("%d pair(s) of objects are stacked on top of each other." % overlaps.size())
	if no_route > 0:
		problems.append("%d vehicle(s) or actor(s) have a speed but no route." % no_route)
	lines.append("")


	var route_result := Routes.check(state)
	lines.append("ROUTES")
	for line in Routes.report(route_result).split("\n"):
		lines.append("  " + line)
	var route_counts := Routes.counts(route_result)
	if int(route_counts.fail) > 0:
		problems.append("%d route(s) fail the ground check." % int(route_counts.fail))
	lines.append("")


	var recon := str(state.data.get("recon_target", ""))
	lines.append("MISSION")
	lines.append("  recon target: %s" % ("none — set one before exporting" if recon.is_empty() else _name_of(objects, recon)))
	lines.append("  air starts: %d" % air_starts)
	if recon.is_empty():
		problems.append("No recon target, so a playable mission cannot be exported.")
	elif _name_of(objects, recon) == recon:
		problems.append("The recon target no longer exists in the scene.")
	if air_starts == 0:
		lines.append("  no air start: the flight test begins from a default position")
	lines.append("")


	lines.append("LIGHT AND WEATHER")
	lines.append("  " + Weather.summary(state))
	lines.append("")


	var assets := 0
	var bytes := 0
	for key in state.custom_assets.keys():
		assets += 1
		bytes += (state.custom_assets[key].get("bytes", PackedByteArray()) as PackedByteArray).size()
	lines.append("IMPORTED ASSETS")
	lines.append("  %d of 24 slots • %.1f of %.0f MiB • largest model allowed 40 MiB" % [
		assets, float(bytes) / 1048576.0, float(Store.MAX_FILE - Store.MAX_META - 12) / 1048576.0])
	if assets >= 20:
		problems.append("Only %d asset slot(s) left." % (24 - assets))
	lines.append("")

	lines.append("SUMMARY")
	if problems.is_empty():
		lines.append("  Nothing to fix. The scene is ready to export.")
	else:
		lines.append("  %d thing(s) to look at:" % problems.size())
		for problem in problems:
			lines.append("   • " + str(problem))
	return { "ok": true, "text": "\n".join(lines), "issues": problems.size(),
		"routes": route_result, "counts": counts}

static func _name_of(objects: Array, id: String) -> String:
	for row in objects:
		if row is Dictionary and str(row.get("id", "")) == id:
			return str(row.get("name", id))
	return id

static func _overlaps(objects: Array) -> Array:
	var pairs: Array = []
	var placed: Array = []
	for row in objects:
		if not row is Dictionary:
			continue
		if str(row.get("asset", "")) in ["road_path", "brick_wall", "terrain_hill", "terrain_mountain", "terrain_pit", "drone_start"]:
			continue
		placed.append({ "name": str(row.get("name", row.get("asset", "object"))),
			"point": Vector2(float(row.get("x", 0.0)), float(row.get("z", 0.0)))})
	for i in placed.size():
		for j in range(i + 1, placed.size()):
			var a: Dictionary = placed[i]
			var b: Dictionary = placed[j]
			if (a.point as Vector2).distance_to(b.point) <= OVERLAP_METRES:
				pairs.append([str(a.name), str(b.name)])
	return pairs
