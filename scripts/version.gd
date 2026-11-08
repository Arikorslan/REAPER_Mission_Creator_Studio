extends RefCounted


const VERSION := "2.0.1"
const BUILD := "2026-11-07"
const NAME := "REAPER MISSION CREATOR"
const EDITION := "Studio Interface"

static func label() -> String:
	return "v%s (%s)" % [VERSION, BUILD]

static func short_label() -> String:
	return "v" + VERSION

static func window_title() -> String:
	return "%s %s — %s" % [NAME, short_label(), EDITION]

static func splash_subtitle() -> String:
	return "%s • %s • build %s" % [EDITION, short_label(), BUILD]


static func highlights() -> Array:
	return [
		"Big models export again: a single model may now be 96 MB, not 40 MB",
		"Export runs in steps and shows progress, so the window no longer freezes",
		"An over-size model is named before the export starts; a model that will not load stops it instead of becoming a placeholder",
		"Time of day, fog, snow cover and weather: clear, golden hour, night, overcast, snow, rain, dust storm",
		"Paint snow straight onto the ground, with a live snow-cover blend",
		"Wind, rain, snowfall and dust particles that follow the camera",
		"Editor pack: 0.1° rotation, snap buttons, rotate whole selection, scene report, model thumbnails",
		"Animated character models that travel as well as animate",
		"First-person eye height adjustable from 0.4 m to 14 m",
		"Route validation against the ground, before anything is exported",
	]
