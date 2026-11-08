extends RefCounted


const RESOLUTION := 65
const EXTENT := 1200.0
const CELL_SIZE := 37.5
const MAX_RESOLUTION := 257





const SIZE_STEPS := [
	{ "extent": 1200.0, "resolution": 65},
	{ "extent": 2400.0, "resolution": 129},
	{ "extent": 3600.0, "resolution": 193},
	{ "extent": 4800.0, "resolution": 257},
	{ "extent": 8000.0, "resolution": 257},
	{ "extent": 12000.0, "resolution": 257},
	{ "extent": 20000.0, "resolution": 257},
	{ "extent": 30000.0, "resolution": 257},
	{ "extent": 40000.0, "resolution": 257},
	{ "extent": 60000.0, "resolution": 257},
	{ "extent": 80000.0, "resolution": 257},
	{ "extent": 100000.0, "resolution": 257},
]
const MAX_EXTENT := 100000.0
const MIN_EXTENT := 1200.0
const MIN_CELL := 20.0
const MAX_CELL := 2000.0
const MIN_HEIGHT := -150.0
const MAX_HEIGHT := 600.0
const FEATURE_IDS := ["terrain_hill", "terrain_mountain", "terrain_plateau"]

static func is_feature(id: String) -> bool: return id in FEATURE_IDS
static func empty(n: int = RESOLUTION, extent_override := 0.0) -> Dictionary:
	var heights: Array = []; heights.resize(n * n); heights.fill(0.0)
	var e := extent_override if extent_override > 0.0 else CELL_SIZE * float(n - 1) * 0.5
	return { "resolution": n, "extent": e, "heights": heights}


static func cell_size(terrain: Dictionary) -> float:
	var n := int(terrain.get("resolution", RESOLUTION))
	var e := float(terrain.get("extent", EXTENT))
	return 2.0 * e / maxf(1.0, float(n - 1))


static func width_m(terrain: Dictionary) -> float: return 2.0 * float(terrain.get("extent", EXTENT))



static func step_index(extent: float) -> int:
	var index := 0
	for i in SIZE_STEPS.size():
		if float(SIZE_STEPS[i].extent) <= extent + 0.5: index = i
	return index

static func size_for(extent: float) -> Dictionary: return SIZE_STEPS[step_index(extent)]


static func next_size(terrain: Dictionary) -> Dictionary:
	var index := step_index(float(terrain.get("extent", EXTENT)))
	return {} if index >= SIZE_STEPS.size() -1 else SIZE_STEPS[index + 1]


static func size_labels() -> Array:
	var out: Array = []
	for step: Dictionary in SIZE_STEPS:
		var km := float(step.extent) * 2.0 / 1000.0
		out.append(("%.1f km" % km) if km < 10.0 else ("%d km" % int(round(km))))
	return out
static func legacy_height(x: float, z: float) -> float:
	var r := maxf(absf(x) / 360.0, absf(z) / 260.0); var edge := smoothstep(0.72, 1.65, r)
	var pattern := 0.5 + 0.25 * sin(x * 0.009 + z * 0.003) +0.2 * cos(z * 0.011 - x * 0.004) +0.13 * sin((x + z) * 0.017)
	return maxf(0, edge * (70 + 170 * pattern))
static func legacy() -> Dictionary:
	var result := empty(); var a: Array = result.heights
	for j in RESOLUTION:
		for i in RESOLUTION:
			var x := lerpf(- EXTENT, EXTENT, float(i) / (RESOLUTION - 1)); var z := lerpf(- EXTENT, EXTENT, float(j) / (RESOLUTION - 1))
			a[j * RESOLUTION + i] = legacy_height(x, z)
	return result
static func valid(v: Variant) -> bool:
	if not v is Dictionary: return false
	var n = v.get("resolution"); var e = v.get("extent")
	if typeof(n) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(n)) or int(n) != float(n): return false
	var count := int(n)
	if count < RESOLUTION or count > MAX_RESOLUTION: return false
	if typeof(e) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(e)): return false
	var extent_value := float(e)
	if extent_value < MIN_EXTENT - 0.5 or extent_value > MAX_EXTENT + 0.5: return false
	var cell := 2.0 * extent_value / float(count - 1)
	if cell < MIN_CELL or cell > MAX_CELL: return false
	var a = v.get("heights")
	if not a is Array or a.size() != count * count: return false
	for h in a:
		if typeof(h) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(h)) or float(h) < MIN_HEIGHT or float(h) > MAX_HEIGHT: return false
	return true


static func resample(terrain: Dictionary, n: int, extent: float) -> Dictionary:
	if not valid(terrain): return {}
	var old_n := int(terrain.resolution); var old_e := float(terrain.extent); var src: Array = terrain.heights
	var result := empty(n, extent); var dst: Array = result.heights
	for j in n:
		for i in n:
			var x := lerpf(- extent, extent, float(i) / float(n - 1))
			var z := lerpf(- extent, extent, float(j) / float(n - 1))
			dst[j * n + i] = base_height(terrain, x, z)
	return result



static func grow(terrain: Dictionary) -> Dictionary:
	if not valid(terrain): return {}
	var next := next_size(terrain)
	if next.is_empty(): return {}
	return resample(terrain, int(next.resolution), float(next.extent))


static func set_extent(terrain: Dictionary, extent: float) -> Dictionary:
	if not valid(terrain): return {}
	var target := size_for(extent)
	var wanted := clampf(extent, MIN_EXTENT, MAX_EXTENT)
	if absf(float(target.extent) -wanted) > 0.5:

		return resample(terrain, int(terrain.resolution), wanted)
	return resample(terrain, int(target.resolution), wanted)
static func base_height(terrain: Dictionary, x: float, z: float) -> float:
	var n := int(terrain.get("resolution", RESOLUTION)); var extent := float(terrain.get("extent", EXTENT)); var a: Array = terrain.get("heights", [])
	if n < 2 or a.size() != n * n or extent <= 0: return 0.0
	var fx := clampf((x + extent) / (2.0 * extent) * (n - 1), 0, n - 1)
	var fz := clampf((z + extent) / (2.0 * extent) * (n - 1), 0, n - 1)
	var i := mini(int(floor(fx)), n - 2); var j := mini(int(floor(fz)), n - 2)
	var u := fx - i; var v := fz - j
	return lerpf(lerpf(float(a[j * n + i]), float(a[j * n + i + 1]), u), lerpf(float(a[(j + 1) * n + i]), float(a[(j + 1) * n + i + 1]), u), v)
static func feature_height(row: Dictionary, x: float, z: float) -> float:
	var kind := str(row.get("asset", ""))
	if not is_feature(kind): return 0.0
	var scale_: float = clampf(float(row.get("scale", 1.0)), 0.05, 30.0)
	var radius_base := 150.0 if kind == "terrain_hill" else (240.0 if kind == "terrain_mountain" else 140.0)
	var peak_base := 55.0 if kind == "terrain_hill" else (180.0 if kind == "terrain_mountain" else 45.0)
	var radius := clampf(radius_base * scale_, 30.0, 8000.0)
	var peak := clampf((peak_base + float(row.get("height", 0.0))) * sqrt(scale_), 1.0, 500.0)
	var q := Vector2(x - float(row.get("x", 0)), z - float(row.get("z", 0))).length() / radius
	if q >= 1.0: return 0.0
	if kind == "terrain_mountain": return peak * pow(1.0 - q, 1.45)
	if kind == "terrain_plateau": return peak * (1.0 - smoothstep(0.66, 1.0, q))
	var s := cos(q * PI * 0.5); return peak * s * s
static func height_at(terrain: Dictionary, objects: Array, x: float, z: float) -> float:
	var h := base_height(terrain, x, z)
	for row in objects:
		if row is Dictionary and is_feature(str(row.get("asset", ""))): h += feature_height(row, x, z)
	return clampf(h, MIN_HEIGHT, MAX_HEIGHT)
static func sculpt(terrain: Dictionary, point: Vector2, radius: float, strength: float, tool: String, flatten_to: float = NAN) -> bool:
	if not valid(terrain) or not point.is_finite() or tool not in ["raise", "lower", "smooth", "flatten"]: return false


	radius = clampf(radius, 20.0, maxf(500.0, cell_size(terrain) * 8.0)); strength = clampf(strength, 0.1, 40.0)
	var n := int(terrain.resolution); var extent := float(terrain.extent)
	if not is_finite(flatten_to): flatten_to = base_height(terrain, point.x, point.y)
	flatten_to = clampf(flatten_to, MIN_HEIGHT, MAX_HEIGHT)
	var a: Array = terrain.heights; var old := a.duplicate(); var changed := false; var step := 2.0 * extent / (n - 1)
	var min_x := maxi(0, int(floor((point.x - radius + extent) / step))); var max_x := mini(n - 1, int(ceil((point.x + radius + extent) / step)))
	var min_z := maxi(0, int(floor((point.y - radius + extent) / step))); var max_z := mini(n - 1, int(ceil((point.y + radius + extent) / step)))
	for j in range(min_z, max_z + 1):
		for i in range(min_x, max_x + 1):
			var dist := Vector2(- extent + i * step, -extent + j * step).distance_to(point)
			if dist > radius: continue
			var w := pow(1.0 - dist / radius, 2); var index := j * n + i; var before := float(old[index]); var after := before
			if tool == "smooth":
				var sum := 0.0; var count := 0
				for dz in range(-1, 2):
					for dx in range(-1, 2):
						var nx := clampi(i + dx, 0, n - 1); var nz := clampi(j + dz, 0, n - 1)
						sum += float(old[nz * n + nx]); count += 1
				after = lerpf(before, sum / count, clampf(strength / 15.0 * w, 0.0, 1.0))
			elif tool == "flatten": after = lerpf(before, flatten_to, clampf(strength / 15.0 * w, 0.0, 1.0))
			else: after = before + strength * w * (1.0 if tool == "raise" else -1.0)
			after = clampf(after, MIN_HEIGHT, MAX_HEIGHT)
			if absf(after - before) > 1e-05: a[index] = after; changed = true
	return changed
