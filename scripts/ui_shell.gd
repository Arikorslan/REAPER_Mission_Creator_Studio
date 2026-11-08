extends RefCounted
## Mission-first shell. The visual language and icon system come from the
## supplied REAPER Studio reference; commands remain connected to the original
## Mission Creator rather than to a mock interface.

const UI = preload("res://scripts/ui_kit.gd")
const StudioIcons = preload("res://scripts/studio_icons.gd")


func _action(icon: String, label: String, hint: String, callback: Callable,
		accent: bool = false, toggle: bool = false, active: bool = false) -> Button:
	var button := StudioIcons.button(icon, label, hint, "", label, 16, accent)
	button.name = "action_" + icon + "_" + label.replace(" ", "_")
	button.custom_minimum_size = Vector2(48, 42)
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", UI.TEXT)
	button.toggle_mode = toggle
	if toggle:
		button.set_pressed_no_signal(active)
		button.toggled.connect(func(value: bool):
			if callback.is_valid(): callback.call(value))
	else:
		button.pressed.connect(func():
			if callback.is_valid(): callback.call())
	return button


func _group(parent: HBoxContainer, label: String, buttons: Array) -> void:
	if parent.get_child_count() > 0:
		var sep := VSeparator.new()
		sep.custom_minimum_size.x = 4
		parent.add_child(sep)
	parent.add_child(StudioIcons.group(label, buttons))


func _menu(app, parent: Container, title: String, entries: Array) -> Button:
	var button := UI.button(title)
	button.name = "menu_button_" + title
	button.custom_minimum_size = Vector2(0, 30)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", UI.flat(Color.TRANSPARENT, Color.TRANSPARENT, 4, 0, 7, 3))
	button.add_theme_stylebox_override("hover", UI.flat(Color("1d2b2e"), UI.LINE, 5, 1, 7, 3))
	parent.add_child(button)
	var popup := PopupMenu.new()
	popup.name = "menu_" + title
	var callbacks: Array = []
	for item: Array in entries:
		if str(item[0]) == "-":
			popup.add_separator()
			continue
		popup.add_item(str(item[0]) + ("    " + str(item[1]) if not str(item[1]).is_empty() else ""), callbacks.size())
		callbacks.append(item[2])
	popup.id_pressed.connect(func(id: int):
		if id >= 0 and id < callbacks.size():
			var cb: Callable = callbacks[id]
			if cb.is_valid(): cb.call())
	app.add_child(popup)
	button.pressed.connect(func():
		var pos: Vector2 = button.get_screen_position()
		popup.reset_size()
		popup.position = Vector2i(int(pos.x), int(pos.y + button.size.y))
		popup.popup())
	return button


func _tab(text: String, icon: String) -> Button:
	var b := UI.button(text)
	b.name = "tab_" + text.to_lower()
	b.icon = StudioIcons.tex(icon, 16, UI.ACCENT)
	b.add_theme_constant_override("icon_max_width", 16)
	b.add_theme_font_size_override("font_size", 11)
	b.toggle_mode = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 32
	return b


func _slider(parent: VBoxContainer, title: String, low: float, high: float,
		step: float, value: float) -> Dictionary:
	var head := HBoxContainer.new()
	parent.add_child(head)
	var label := UI.label(title, 11, UI.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(label)
	var reading := UI.label("", 11, UI.TEXT)
	head.add_child(reading)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.custom_minimum_size.y = 20
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(slider)
	return {"slider": slider, "reading": reading}


func build(app) -> Dictionary:
	var slots := {}
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_" + edge, 8)
	app.add_child(outer)
	var shell := VBoxContainer.new()
	shell.name = "StudioShell"
	shell.add_theme_constant_override("separation", 6)
	outer.add_child(shell)

	# Branded top row and real command menus.
	var top := HBoxContainer.new()
	top.name = "Header"
	top.add_theme_constant_override("separation", 7)
	shell.add_child(top)
	var mark := TextureRect.new()
	mark.texture = StudioIcons.tex("mountain", 24, UI.ACCENT)
	mark.custom_minimum_size = Vector2(24, 24)
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(mark)
	var title := UI.label("REAPER", 17, UI.ACCENT)
	top.add_child(title)
	var edition := UI.badge("MISSION CREATOR", UI.ACCENT)
	top.add_child(edition)
	slots["brand_badge"] = edition
	app.crumb_label = UI.label("Untitled mission  /  Draft", 11, UI.MUTED)
	app.crumb_label.clip_text = true
	app.crumb_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(app.crumb_label)

	var menu_row := HBoxContainer.new()
	menu_row.name = "DesktopMenus"
	menu_row.add_theme_constant_override("separation", 0)
	top.add_child(menu_row)
	slots["desktop_menus"] = menu_row
	var file_entries := [
		["New mission", "Ctrl+N", func(): app._request_action("new")],
		["Open draft…", "Ctrl+O", func(): app._request_action("open")],
		["Save draft", "Ctrl+S", app._save_requested],
		["Save draft as…", "Ctrl+Shift+S", func(): app.save_dialog.popup_centered_ratio(0.7)],
		["-", "", Callable()],
		["Import model…", "", func(): app.add_dialog.popup_centered_ratio(0.7)],
		["Import animation…", "", func(): app.animation_dialog.popup_centered_ratio(0.7)],
		["Import texture…", "", func(): app.texture_dialog.popup_centered_ratio(0.7)],
		["Export mission…", "Ctrl+E", func(): app.export_dialog.popup_centered_ratio(0.7)],
		["Export 3D package…", "", app._export_pack_requested],
		["Export scene GLB…", "", app._export_glb_requested],
	]
	var edit_entries := [
		["Undo", "Ctrl+Z", app._undo], ["Redo", "Ctrl+Y", app._redo],
		["-", "", Callable()], ["Copy", "Ctrl+C", app._copy_selection],
		["Paste", "Ctrl+V", app._paste_selection], ["Duplicate", "Ctrl+D", app._duplicate_selection],
		["Delete selection", "Delete", app._delete_selection],
	]
	var view_entries := [
		["Tools / library panel", "", func(): app._toggle_panel("library")],
		["Inspector panel", "", func(): app._toggle_panel("inspector")],
		["Show / hide map", "M", app._toggle_map_visibility],
		["Enlarge map", "", app._toggle_map],
		["Recenter camera", "", app._quick_recentre],
	]
	var mission_entries := [
		["Mission details", "", func(): app._open_right_tab("MISSION")],
		["Scene hierarchy", "", func(): app._open_right_tab("SCENE")],
		["Run mission checks", "", app._open_checklist],
		["Check routes", "F8", app._open_route_check],
		["Scene report", "F9", app._open_scene_report],
		["Export mission…", "Ctrl+E", func(): app.export_dialog.popup_centered_ratio(0.7)],
	]
	var help_entries := [["Controls and shortcuts", "F1", app._show_help]]
	_menu(app, menu_row, "File", file_entries)
	_menu(app, menu_row, "Edit", edit_entries)
	_menu(app, menu_row, "View", view_entries)
	_menu(app, menu_row, "Mission", mission_entries)
	_menu(app, menu_row, "Help", help_entries)
	var compact := _menu(app, top, "Menu", file_entries + [["-", "", Callable()]] + edit_entries + [["-", "", Callable()]] + mission_entries + [["-", "", Callable()]] + view_entries + help_entries)
	compact.visible = false
	slots["compact_menu"] = compact

	app.library_button = UI.toggle("Tools")
	app.library_button.name = "toggle_tools_panel"
	app.library_button.tooltip_text = "Show or hide the terrain tools and content library"
	app.library_button.set_pressed_no_signal(true)
	app.library_button.pressed.connect(func(): app._toggle_panel("library"))
	top.add_child(app.library_button)
	app.inspector_button = UI.toggle("Inspector")
	app.inspector_button.name = "toggle_inspector_panel"
	app.inspector_button.tooltip_text = "Show or hide object, scene and mission properties"
	app.inspector_button.set_pressed_no_signal(true)
	app.inspector_button.pressed.connect(func(): app._toggle_panel("inspector"))
	top.add_child(app.inspector_button)
	app.export_button = UI.button("Export mission", true)
	app.export_button.name = "export_mission"
	app.export_button.icon = StudioIcons.tex("export", 16, UI.ACCENT)
	app.export_button.tooltip_text = "Export a verified .rmission package for REAPER Operations custom recon."
	app.export_button.pressed.connect(func(): app.export_dialog.popup_centered_ratio(0.7))
	top.add_child(app.export_button)

	# Horizontal, scrollable ribbon: all commands remain accessible at small sizes.
	var bar := UI.panel(3, UI.PANEL)
	bar.name = "CommandRibbon"
	shell.add_child(bar)
	var ribbon_scroll := ScrollContainer.new()
	ribbon_scroll.name = "RibbonScroll"
	ribbon_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	ribbon_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ribbon_scroll.get_h_scroll_bar().custom_minimum_size.y = 4
	ribbon_scroll.custom_minimum_size.y = 57
	bar.add_child(ribbon_scroll)
	var ribbon := HBoxContainer.new()
	ribbon.add_theme_constant_override("separation", 5)
	ribbon_scroll.add_child(ribbon)
	slots["ribbon_scroll"] = ribbon_scroll

	app.new_button = _action("new", "New", "Start a blank mission", func(): app._request_action("new"))
	var open := _action("open", "Open", "Open a saved draft", func(): app._request_action("open"))
	app.save_button = _action("save", "Save", "Save the editable draft", app._save_requested, true)
	var save_as := _action("save_as", "Save as", "Save a copy of the draft", func(): app.save_dialog.popup_centered_ratio(0.7))
	_group(ribbon, "File", [app.new_button, open, app.save_button, save_as])

	app.quick_undo = _action("undo", "Undo", "Undo the most recent edit", app._undo)
	app.quick_redo = _action("redo", "Redo", "Redo an edit", app._redo)
	var duplicate := _action("duplicate", "Copy", "Duplicate selected objects", app._duplicate_selection)
	var delete := _action("trash", "Delete", "Remove selected objects", app._delete_selection)
	_group(ribbon, "Edit", [app.quick_undo, app.quick_redo, duplicate, delete])

	var import_model := _action("import", "Model", "Import a GLB or FBX model", func(): app.add_dialog.popup_centered_ratio(0.7))
	var import_tex := _action("texture", "Texture", "Import a PNG or JPEG texture", func(): app.texture_dialog.popup_centered_ratio(0.7))
	var import_height := _action("mountain", "Height", "Import a heightmap", app._heightmap_import_requested)
	var export_glb := _action("cube", "3D pack", "Export a 3D scene package", app._export_pack_requested)
	_group(ribbon, "Import / export", [import_model, import_tex, import_height, export_glb])

	app.quick_grid = _action("grid", "Grid", "Show a grid in the scene and map", app._quick_grid, false, true)
	app.map_visibility_button = _action("eye", "Map", "Show or hide the editable map", func(_v): app._toggle_map_visibility(), false, true, true)
	app.map_button = _action("expand", "Map +", "Enlarge the editable map", app._toggle_map)
	app.quick_labels = _action("pin", "Labels", "Show object labels on the map", app._quick_labels, false, true, true)
	app.quick_recentre = _action("focus", "Reset", "Recentre the 3D camera", app._quick_recentre)
	app.quick_hide_ui = _action("eye_off", "Panels", "Hide both side panels", app._quick_hide_ui, false, true)
	_group(ribbon, "View", [app.quick_grid, app.map_visibility_button, app.map_button, app.quick_labels, app.quick_recentre, app.quick_hide_ui])

	app.quick_snap = _action("pattern", "Snap", "Snap placement and nudges to a 5 m grid", app._quick_snap, false, true)
	app.quick_multi = _action("layers", "Multi", "Select multiple objects", app._quick_multi, false, true)
	app.ruler_button = _action("target", "Measure", "Measure distance on the map", app._quick_ruler, false, true)
	_group(ribbon, "Precision", [app.quick_snap, app.quick_multi, app.ruler_button])

	app.flight_button = _action("world", "Flight", "Run the simplified recon flight test", app._flight_toggled, false, true)
	app.play_button = _action("play", "Preview", "Preview routes and animations", app._preview_toggled, false, true)
	app.issues_button = _action("check", "Checks", "Validate mission and routes", app._open_checklist)
	var help := _action("help", "Help", "Open controls and shortcuts", app._show_help)
	_group(ribbon, "Mission", [app.flight_button, app.play_button, app.issues_button, help])

	# Main studio layout: a tool browser, a live viewport and a tabbed inspector.
	var body := HBoxContainer.new()
	body.name = "MainWorkspace"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 7)
	shell.add_child(body)

	var browser := UI.panel(7)
	browser.name = "ToolsAndContent"
	browser.custom_minimum_size.x = 290
	body.add_child(browser)
	app.library_panel = browser
	var browser_box := VBoxContainer.new()
	browser_box.add_theme_constant_override("separation", 7)
	browser.add_child(browser_box)
	var browser_tabs := HBoxContainer.new()
	browser_tabs.add_theme_constant_override("separation", 4)
	browser_box.add_child(browser_tabs)
	var terrain_tab := _tab("Terrain", "mountain")
	var content_tab := _tab("Content", "cube")
	browser_tabs.add_child(terrain_tab)
	browser_tabs.add_child(content_tab)
	terrain_tab.set_pressed_no_signal(true)

	var terrain_scroll := ScrollContainer.new()
	terrain_scroll.name = "TerrainScroll"
	terrain_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	terrain_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	browser_box.add_child(terrain_scroll)
	var terrain_page := VBoxContainer.new()
	terrain_page.name = "TerrainPage"
	terrain_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	terrain_page.add_theme_constant_override("separation", 6)
	terrain_scroll.add_child(terrain_page)
	terrain_page.add_child(UI.section("Sculpt & paint", "sculpt"))
	var tools := VBoxContainer.new()
	tools.name = "SculptToolHost"
	tools.add_theme_constant_override("separation", 5)
	terrain_page.add_child(tools)
	slots["shelf_tools"] = tools
	var footer := VBoxContainer.new()
	terrain_page.add_child(footer)
	slots["shelf_footer"] = footer
	terrain_page.add_child(UI.separator())
	terrain_page.add_child(UI.section("Brush", "brush"))
	app.brush_tool_label = UI.label("BRUSH · SELECT", 10, UI.DIM)
	terrain_page.add_child(app.brush_tool_label)
	var radius := _slider(terrain_page, "Radius", 45.0, 500.0, 5.0, 90.0)
	app.brush_radius_slider = radius.slider
	app.brush_radius_slider.tooltip_text = "Brush radius in metres"
	radius.reading.text = "90 m"
	app.brush_radius_slider.value_changed.connect(func(value: float):
		radius.reading.text = "%d m" % int(value)
		app._brush_from_bar(value, app.brush_strength_slider.value if app.brush_strength_slider != null else 8.0))
	var strength := _slider(terrain_page, "Strength", 0.5, 40.0, 0.5, 8.0)
	app.brush_strength_slider = strength.slider
	app.brush_strength_slider.tooltip_text = "Sculpting brush strength"
	strength.reading.text = "8.0"
	app.brush_strength_slider.value_changed.connect(func(value: float):
		strength.reading.text = "%.1f" % value
		app._brush_from_bar(app.brush_radius_slider.value, value))
	terrain_page.add_child(UI.separator())
	var sun := _slider(terrain_page, "TIME OF DAY", 0.0, 24.0, 0.25, 10.0)
	app.sun_slider = sun.slider
	app.sun_label = sun.reading
	app.sun_label.text = "10:00"
	app.sun_slider.tooltip_text = "Preview and set the mission start time"
	app.sun_slider.value_changed.connect(app._sun_preview)
	app.sun_slider.drag_ended.connect(func(_changed): app._sun_commit())
	terrain_page.add_child(UI.separator())
	var terrain_details := VBoxContainer.new()
	terrain_details.add_theme_constant_override("separation", 5)
	terrain_page.add_child(terrain_details)
	slots["tab_terrain"] = terrain_details

	var library_host := VBoxContainer.new()
	library_host.name = "ContentPage"
	library_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library_host.visible = false
	browser_box.add_child(library_host)
	slots["library_host"] = library_host
	terrain_tab.pressed.connect(func():
		terrain_scroll.visible = true
		library_host.visible = false
		terrain_tab.set_pressed_no_signal(true)
		content_tab.set_pressed_no_signal(false))
	content_tab.pressed.connect(func():
		terrain_scroll.visible = false
		library_host.visible = true
		terrain_tab.set_pressed_no_signal(false)
		content_tab.set_pressed_no_signal(true))
	slots["terrain_tab_button"] = terrain_tab
	slots["content_tab_button"] = content_tab

	var work := VBoxContainer.new()
	work.name = "ViewportColumn"
	work.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	work.size_flags_vertical = Control.SIZE_EXPAND_FILL
	work.add_theme_constant_override("separation", 5)
	body.add_child(work)
	var view_host := VBoxContainer.new()
	view_host.name = "ViewHost"
	view_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	work.add_child(view_host)
	slots["view_host"] = view_host
	var lower_host := VBoxContainer.new()
	lower_host.name = "ViewportCommands"
	work.add_child(lower_host)
	slots["lower_host"] = lower_host

	var inspector := UI.panel(7)
	inspector.name = "InspectorPanel"
	inspector.custom_minimum_size.x = 315
	body.add_child(inspector)
	app.inspector_panel = inspector
	var inspector_box := VBoxContainer.new()
	inspector_box.add_theme_constant_override("separation", 6)
	inspector.add_child(inspector_box)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	inspector_box.add_child(tabs)
	var buttons := {}
	var pages := {}
	var names := ["OBJECT", "SCENE", "MISSION", "FILES"]
	var tab_icons := ["cube", "layers", "target", "folder"]
	for i in names.size():
		var key: String = names[i]
		var b := _tab(key.capitalize(), tab_icons[i])
		b.add_theme_font_size_override("font_size", 10)
		b.custom_minimum_size.x = 0
		b.pressed.connect(func(): app._set_inspector_tab(key))
		tabs.add_child(b)
		buttons[key] = b
		var scroller := ScrollContainer.new()
		scroller.name = key + "_scroll"
		scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroller.visible = false
		inspector_box.add_child(scroller)
		var page := VBoxContainer.new()
		page.name = key + "_page"
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 5)
		scroller.add_child(page)
		pages[key] = page
	app.inspector_tab_buttons = buttons
	app.inspector_tab_panels = pages
	slots["tab_object"] = pages["OBJECT"]
	slots["tab_mission"] = pages["MISSION"]
	slots["tab_files"] = pages["FILES"]
	slots["hierarchy_host"] = pages["SCENE"]
	var hierarchy_head := HBoxContainer.new()
	pages["SCENE"].add_child(hierarchy_head)
	var hierarchy_title := UI.label("SCENE HIERARCHY", 11, UI.ACCENT)
	hierarchy_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hierarchy_head.add_child(hierarchy_title)
	app.hierarchy_count_label = UI.label("0 objects", 10, UI.MUTED)
	hierarchy_head.add_child(app.hierarchy_count_label)

	var status_bar := HBoxContainer.new()
	status_bar.name = "StatusBar"
	status_bar.add_theme_constant_override("separation", 10)
	shell.add_child(status_bar)
	app.status = UI.label("Ready", 11, UI.MUTED)
	app.status.clip_text = true
	app.status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_bar.add_child(app.status)
	app.autosave_label = UI.label("", 10, UI.DIM)
	status_bar.add_child(app.autosave_label)
	app.issues_count_label = UI.label("0", 10, UI.WARN)
	app.issues_count_label.tooltip_text = "Mission validation notes"
	status_bar.add_child(app.issues_count_label)
	app.perf_label = UI.label("-- fps", 10, UI.DIM)
	status_bar.add_child(app.perf_label)
	slots["shell"] = shell
	return slots
