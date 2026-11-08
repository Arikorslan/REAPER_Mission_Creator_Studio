extends Button

var asset_id := ""
func _get_drag_data(_at: Vector2) -> Variant:
	if asset_id.is_empty(): return null
	if OS.has_environment("REAPER_TRACE_DRAG"): print("TRACE start drag ", asset_id)
	var preview := Label.new(); preview.text = "  " + text + "  "; preview.add_theme_color_override("font_color", Color("b5ffde")); set_drag_preview(preview)
	return { "type": "asset", "id": asset_id}
