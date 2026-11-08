extends RefCounted





const PRESETS := [
	{ "id": "clear", "label": "CLEAR DAY", "hour": 11.0, "fog": 0.0, "cloud": 0.1,
		"snow_cover": 0.0, "wet": 0.0, "wind": 3.0, "rain": 0.0, "dust": 0.0, "snow_fall": 0.0},
	{ "id": "golden", "label": "GOLDEN HOUR", "hour": 18.2, "fog": 0.3, "cloud": 0.25,
		"snow_cover": 0.0, "wet": 0.0, "wind": 4.0, "rain": 0.0, "dust": 0.0, "snow_fall": 0.0},
	{ "id": "night", "label": "NIGHT", "hour": 23.0, "fog": 0.35, "cloud": 0.45,
		"snow_cover": 0.0, "wet": 0.1, "wind": 2.0, "rain": 0.0, "dust": 0.0, "snow_fall": 0.0},
	{ "id": "overcast", "label": "OVERCAST", "hour": 10.0, "fog": 0.45, "cloud": 0.85,
		"snow_cover": 0.0, "wet": 0.25, "wind": 7.0, "rain": 0.0, "dust": 0.0, "snow_fall": 0.0},
	{ "id": "snow", "label": "SNOW", "hour": 9.5, "fog": 0.55, "cloud": 0.8,
		"snow_cover": 0.85, "wet": 0.1, "wind": 8.0, "rain": 0.0, "dust": 0.0, "snow_fall": 0.55},
	{ "id": "rain", "label": "RAIN", "hour": 13.0, "fog": 0.6, "cloud": 0.9,
		"snow_cover": 0.0, "wet": 0.85, "wind": 12.0, "rain": 0.8, "dust": 0.0, "snow_fall": 0.0},
	{ "id": "dust", "label": "DUST STORM", "hour": 15.0, "fog": 0.75, "cloud": 0.35,
		"snow_cover": 0.0, "wet": 0.0, "wind": 22.0, "rain": 0.0, "dust": 0.8, "snow_fall": 0.0},
]

const KEYS := ["preset", "hour", "fog", "cloud", "snow_cover", "wet", "wind", "wind_dir",
	"rain", "dust", "snow_fall", "snow_tint"]
const RANGES := {
	"hour": [0.0, 24.0], "fog": [0.0, 1.0], "cloud": [0.0, 1.0], "snow_cover": [0.0, 1.0],
	"wet": [0.0, 1.0], "wind": [0.0, 30.0], "wind_dir": [0.0, 360.0], "rain": [0.0, 1.0],
	"dust": [0.0, 1.0], "snow_fall": [0.0, 1.0],
}

static func defaults() -> Dictionary:
	var out := { "preset": "clear", "wind_dir": 120.0, "snow_tint": 0.0}
	for key in ["hour", "fog", "cloud", "snow_cover", "wet", "wind", "rain", "dust", "snow_fall"]:
		out[key] = float(_preset("clear").get(key, 0.0))
	return out

static func _preset(id: String) -> Dictionary:
	for row: Dictionary in PRESETS:
		if str(row.id) == id:
			return row
	return PRESETS[0]

static func preset_labels() -> Array:
	var out: Array = []
	for row: Dictionary in PRESETS:
		out.append(str(row.label))
	return out

static func preset_id_at(index: int) -> String:
	if index < 0 or index >= PRESETS.size():
		return "clear"
	return str(PRESETS[index].id)


static func read(state) -> Dictionary:
	var raw: Dictionary = state.data.get("environment", {}) if state != null else {}
	var out := defaults()
	for key in KEYS:
		if not raw.has(key):
			continue
		if key == "preset":
			out[key] = str(raw[key])
		else:
			out[key] = float(raw[key])
	for key in RANGES.keys():
		var limits: Array = RANGES[key]
		out[key] = clampf(float(out[key]), float(limits[0]), float(limits[1]))
	return out

static func preset(state, id: String) -> Dictionary:
	var chosen := _preset(id)
	var settings := read(state)
	settings["preset"] = str(id)
	for key in ["hour", "fog", "cloud", "snow_cover", "wet", "wind", "rain", "dust", "snow_fall"]:
		settings[key] = float(chosen.get(key, 0.0))
	return settings

static func write(state, settings: Dictionary) -> void:
	if state == null:
		return
	state.data["environment"] = settings
	state.dirty = true
	state.changed.emit("environment")

static func set_value(state, key: String, value: Variant) -> void:
	if state == null:
		return
	var settings := read(state)
	if key == "preset":
		settings = preset(state, str(value))
		write(state, settings)
		return
	if not RANGES.has(key):
		return
	var limits: Array = RANGES[key]
	settings[key] = clampf(float(value), float(limits[0]), float(limits[1]))

	settings["preset"] = "custom"
	write(state, settings)



static func sun_elevation(settings: Dictionary) -> float:
	var hour := clampf(float(settings.get("hour", 10.0)), 0.0, 24.0)
	var raw := sin((hour - 6.0) * PI / 12.0)
	var elevation := 68.0 * raw + 6.0
	elevation -= 18.0 * clampf(float(settings.get("cloud", 0.0)), 0.0, 1.0)
	return clampf(elevation, -12.0, 88.0)

static func sun_azimuth(settings: Dictionary) -> float:
	var hour := clampf(float(settings.get("hour", 10.0)), 0.0, 24.0)
	return fmod(90.0 + (hour - 6.0) * 15.0 + 360.0, 360.0)

static func daylight(settings: Dictionary) -> float:
	return clampf((sun_elevation(settings) +8.0) / 40.0, 0.0, 1.0)


static func cover_colour(settings: Dictionary) -> Color:
	var snow := clampf(float(settings.get("snow_cover", 0.0)), 0.0, 1.0)
	var wet := clampf(float(settings.get("wet", 0.0)), 0.0, 1.0)
	var base := Color("f2f6fa").lerp(Color("cdd8e4"), clampf(float(settings.get("snow_tint", 0.0)), 0.0, 1.0))
	base = base.darkened(0.35 * wet * (1.0 - snow))
	return base

static func wind_vector(settings: Dictionary) -> Vector3:
	var speed := float(settings.get("wind", 0.0))
	var degrees := float(settings.get("wind_dir", 120.0))
	return Vector3(sin(deg_to_rad(degrees)), 0.0, -cos(deg_to_rad(degrees))) * speed


static func summary(state) -> String:
	var s := read(state)
	var label := "CUSTOM"
	for row: Dictionary in PRESETS:
		if str(row.id) == str(s.preset):
			label = str(row.label)
	var parts: Array = [label, "%02d:%02d" % [int(floor(float(s.hour))), int(round((float(s.hour) -floor(float(s.hour))) * 60.0))]]
	parts.append("wind %d m/s" % int(round(float(s.wind))))
	if float(s.fog) > 0.02:
		parts.append("fog %d%%" % int(round(float(s.fog) * 100.0)))
	if float(s.snow_cover) > 0.02:
		parts.append("snow cover %d%%" % int(round(float(s.snow_cover) * 100.0)))
	if float(s.rain) > 0.02:
		parts.append("rain %d%%" % int(round(float(s.rain) * 100.0)))
	if float(s.snow_fall) > 0.02:
		parts.append("snowfall %d%%" % int(round(float(s.snow_fall) * 100.0)))
	if float(s.dust) > 0.02:
		parts.append("dust %d%%" % int(round(float(s.dust) * 100.0)))
	return " • ".join(parts)


static func validate(value: Variant) -> String:
	if value == null:
		return ""
	if not value is Dictionary:
		return "Invalid environment block."
	for key in value.keys():
		if not key in KEYS:
			return "Unknown environment field: %s." % str(key)
	var row := read_dictionary(value)
	for key in RANGES.keys():
		var limits: Array = RANGES[key]
		var number := float(row.get(key, 0.0))
		if not is_finite(number) or number < float(limits[0]) or number > float(limits[1]):
			return "Environment value out of range: %s." % str(key)
	return ""


static func read_dictionary(raw: Dictionary) -> Dictionary:
	var out := defaults()
	for key in KEYS:
		if raw.has(key):
			out[key] = str(raw[key]) if key == "preset" else float(raw[key])
	return out
