extends SceneTree
## Automated integration check for the Studio-styled Mission Creator.
## Runs the real main scene and its connected UI commands; no mock UI.
## godot --headless --path . --script tests/test_ui_integration.gd

const Store = preload("res://scripts/draft_store.gd")
const Presets = preload("res://scripts/terrain_presets.gd")
const Codec = preload("res://scripts/glb_codec.gd")
const TextureCodec = preload("res://scripts/texture_codec.gd")
const Terrain = preload("res://scripts/terrain_model.gd")

var checks := 0
var failures := 0

func check(title: String, ok: bool, detail := "") -> void:
	checks += 1
	if ok:
		print("PASS  ", title, "  ", detail)
	else:
		failures += 1
		printerr("FAIL  ", title, "  ", detail)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(1600, 900)
	var app = load("res://main.tscn").instantiate()
	get_root().add_child(app)
	await process_frame
	await process_frame
	app._apply_responsive()
	check("main scene and 3D viewport load", app.scene_view != null and app.scene_view.camera != null)
	check("desktop has both side panels", app.library_panel.visible and app.inspector_panel.visible)
	app._status("Export succeeded\nAdditional details")
	check("multiline messages keep the status bar to one line", app.status.text == "Export succeeded" and app.status.tooltip_text.contains("Additional details"))
	check("empty selection shows contextual help", app.object_empty_state.visible and not app.object_detail_container.visible)
	check("a new draft is identified as not saved", app.crumb_label.text.contains("not saved"))
	check("default terrain surface is embedded", not str(app.state.data.get("terrain_texture", "")).is_empty() and app.state.custom_assets.has(str(app.state.data.terrain_texture)))
	var all_presets_ok := true
	for preset: Dictionary in Presets.PRESETS:
		var bytes := Presets.read(preset)
		if bytes.is_empty() or "tex_" + Codec.sha256(bytes) != str(preset.id) or not TextureCodec.validate(bytes).ok:
			all_presets_ok = false
	check("all original and Studio surface presets validate", all_presets_ok and Presets.PRESETS.size() == 23, str(Presets.PRESETS.size()))

	var menu: Button = app.find_child("menu_button_File", true, false)
	var popup: PopupMenu = app.find_child("menu_File", true, false)
	check("File menu exists", menu != null and popup != null)
	menu.pressed.emit()
	await process_frame
	check("File menu opens with commands", popup.visible and popup.item_count >= 10)
	popup.hide()

	app.shell_slots.content_tab_button.pressed.emit()
	await process_frame
	check("content tab opens", app.shell_slots.library_host.visible)
	app.library_search.text = "desert house"
	app.library_search.text_changed.emit(app.library_search.text)
	await process_frame
	await process_frame
	var house_card: Button = null
	for candidate in app.asset_list.get_children():
		if candidate is Button and candidate.text.to_lower().contains("desert house"): house_card = candidate
	check("search finds Desert house", house_card != null)
	if house_card != null: house_card.pressed.emit()
	await process_frame
	check("asset card places object", app.state.data.objects.size() == 1)
	var target: String = app.state.selected_id
	check("selection reveals real object properties", not app.object_empty_state.visible and app.object_detail_container.visible and not target.is_empty())
	app.state.set_position(target, Vector2(120.0, -80.0))
	app.obj_name.text = "Recon compound"
	app.obj_name.text_changed.emit("Recon compound")
	check("object inspector edits state", str(app.state.find_object(target).name) == "Recon compound")

	app.inspector_tab_buttons["MISSION"].pressed.emit()
	check("Mission tab switches", app.active_tab == "MISSION" and app.inspector_tab_panels["MISSION"].get_parent().visible)
	app.mission_name.text = "Desert Recon Test"
	app.mission_name.text_changed.emit("Desert Recon Test")
	app.briefing.text = "Locate and photograph the compound."
	app.briefing.text_changed.emit()
	app.objectives.text = "Locate the compound\nReturn to base"
	app.objectives.text_changed.emit()
	app._set_recon_target()
	check("mission fields and recon target update", app.state.data.name == "Desert Recon Test" and app.state.data.recon_target == target and app.state.data.objectives.size() == 2)

	app.tool_button(1).pressed.emit()
	check("sculpt tool button is wired", app.scene_view.terrain_tool == "raise" and app.map_view.terrain_tool == "raise")
	app.brush_radius_slider.value = 160.0
	app.brush_strength_slider.value = 12.0
	check("brush sliders control both views", is_equal_approx(app.scene_view.brush_radius, 160.0) and is_equal_approx(app.map_view.brush_strength, 12.0))
	var h0: float = Terrain.height_at(app.state.data.terrain, app.state.data.objects, -400.0, -400.0)
	var sculpted: bool = app.state.sculpt_terrain(Vector2(-400.0, -400.0), 200.0, 20.0, "raise")
	var h1: float = Terrain.height_at(app.state.data.terrain, app.state.data.objects, -400.0, -400.0)
	check("terrain sculpt changes height", sculpted and h1 > h0, "%.2f -> %.2f" % [h0, h1])

	var preset_index := -1
	for i in app.terrain_texture.item_count:
		if app.terrain_texture.get_item_text(i) == "Studio: Lush Grass": preset_index = i
	check("Studio surface appears in ground selector", preset_index > 0)
	if preset_index > 0:
		app.terrain_texture.select(preset_index)
		app.terrain_texture.item_selected.emit(preset_index)
	check("Studio surface applies and embeds", str(app.state.data.terrain_texture) == str(app.terrain_texture.get_item_metadata(preset_index)) and app.state.custom_assets.has(str(app.state.data.terrain_texture)) and is_equal_approx(float(app.state.data.terrain_tile_m), 18.0))
	app.state.add_waypoint(target, Vector2(160, -80))
	app.state.add_waypoint(target, Vector2(220, -20))
	check("route waypoints added", app.state.find_object(target).route.size() == 2)

	var count_before: int = app.state.data.objects.size()
	app._duplicate_selection()
	var after_copy: int = app.state.data.objects.size()
	app._undo()
	var after_undo: int = app.state.data.objects.size()
	app._redo()
	check("duplicate, undo and redo work", after_copy == count_before + 1 and after_undo == count_before and app.state.data.objects.size() == after_copy, "%d → %d → %d → %d" % [count_before, after_copy, after_undo, app.state.data.objects.size()])
	app.state.select(target)
	app._open_checklist()
	check("mission checks open the mission inspector", app.active_tab == "MISSION" and app.checklist_issues is Array)

	var draft_path := "/tmp/reaper_premium_ui_test.rmdraft"
	app.state.finish_paint_stroke()
	app.state.commit_paint()
	var save: Dictionary = Store.save_draft(draft_path, app.state.data, app.state.custom_assets)
	var loaded: Dictionary = Store.load_draft(draft_path)
	check("editable draft save / load", save.ok and loaded.ok and loaded.mission.name == "Desert Recon Test" and loaded.mission.recon_target == target)
	app._open_from(draft_path)
	check("opened draft breadcrumb reflects its filename", app.crumb_label.text.contains("reaper_premium_ui_test.rmdraft") and not app.crumb_label.text.contains("not saved"))
	var missing_target_data: Dictionary = app.state.data.duplicate(true)
	missing_target_data["recon_target"] = ""
	var rejected: Dictionary = Store.save_mission("/tmp/reaper_missing_target.rmission", missing_target_data, app.state.custom_assets)
	check("export rejects a missing recon target", not rejected.ok and str(rejected.error).contains("RECON TARGET"))
	var mission_path := "/tmp/reaper_premium_ui_test.rmission"
	var exported: Dictionary = app._write_mission_package(mission_path)
	check("self-contained .rmission export", exported.get("ok", false), str(exported.get("error", "")))
	if exported.get("ok", false):
		var verified: Dictionary = Store.verify_package(mission_path)
		var mission: Dictionary = Store.load_mission(mission_path)
		check("mission integrity and metadata round-trip", verified.get("ok", false) and mission.get("ok", false) and mission.mission.name == "Desert Recon Test" and mission.mission.recon_target == target)

	get_root().size = Vector2i(1024, 768)
	await process_frame
	await process_frame
	app._apply_responsive()
	check("medium layout keeps tools and collapses inspector", app.library_panel.visible and not app.inspector_panel.visible and app.shell_slots.compact_menu.visible)
	get_root().size = Vector2i(800, 600)
	await process_frame
	await process_frame
	app._apply_responsive()
	check("narrow layout prioritizes viewport", not app.library_panel.visible and not app.inspector_panel.visible and app.scene_view.size.x >= 500, "viewport=%s" % str(app.scene_view.size))
	app._toggle_panel("inspector")
	check("narrow inspector can open", app.inspector_panel.visible and not app.library_panel.visible)
	app._toggle_panel("library")
	check("narrow drawers remain mutually exclusive", app.library_panel.visible and not app.inspector_panel.visible)
	app._open_right_tab("MISSION")
	check("opening mission checks on narrow screens reveals inspector", app.inspector_panel.visible and not app.library_panel.visible and app.active_tab == "MISSION")
	get_root().size = Vector2i(1600, 900)
	await process_frame
	await process_frame
	app._apply_responsive()
	check("panels return at desktop width", app.library_panel.visible and app.inspector_panel.visible)

	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
