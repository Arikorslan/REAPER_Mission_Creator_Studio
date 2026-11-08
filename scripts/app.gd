extends Control

const State = preload("res://scripts/mission_state.gd")
const Store = preload("res://scripts/draft_store.gd")
const Library = preload("res://scripts/asset_library.gd")
const Codec = preload("res://scripts/glb_codec.gd")
const Exporter = preload("res://scripts/scene_export.gd")
const MapCanvas = preload("res://scripts/map_canvas.gd")
const SceneView = preload("res://scripts/scene_view.gd")
const SceneInteraction = preload("res://scripts/scene_interaction.gd")
const AssetCard = preload("res://scripts/asset_card.gd")
const Fbx = preload("res://scripts/fbx_converter.gd")
const TextureCodec = preload("res://scripts/texture_codec.gd")
const TerrainPresets = preload("res://scripts/terrain_presets.gd")
const Terrain = preload("res://scripts/terrain_model.gd")
const AnimationSupport = preload("res://scripts/animation_support.gd")
const Platform = preload("res://scripts/platform_files.gd")
const Folders = preload("res://scripts/folder_service.gd")
const History = preload("res://scripts/history_service.gd")
const Selection = preload("res://scripts/selection_service.gd")
const Validation = preload("res://scripts/validation_service.gd")
const Heightmap = preload("res://scripts/heightmap_service.gd")
const Icons = preload("res://scripts/icons.gd")
const LibraryIndex = preload("res://scripts/library_index.gd")
const Perf = preload("res://scripts/perf_meter.gd")
const Version = preload("res://scripts/version.gd")
const Weather = preload("res://scripts/environment.gd")
const Routes = preload("res://scripts/route_check.gd")
const SceneReport = preload("res://scripts/scene_report.gd")
const Splash = preload("res://scripts/splash.gd")
const Thumbs = preload("res://scripts/thumbnail_service.gd")
const Autosave = preload("res://scripts/autosave_service.gd")
const Shell = preload("res://scripts/ui_shell.gd")
const UI = preload("res://scripts/ui_kit.gd")
const StudioIcons = preload("res://scripts/studio_icons.gd")

var state = State.new()
var library = Library.new()
var map_view
var scene_view
var asset_list: BoxContainer
var mission_name: LineEdit
var hour: SpinBox
var minute: SpinBox
var briefing: TextEdit
var objectives: TextEdit
var recon_label: Label
var obj_name: LineEdit
var pos_x: SpinBox
var pos_z: SpinBox
var height: SpinBox
var yaw: SpinBox
var pitch: SpinBox
var roll: SpinBox
var route_face: CheckBox
var animation_source: OptionButton
var animation_clip: OptionButton
var animation_loop: CheckBox
var animation_speed: SpinBox
var animation_status: Label
var animation_own: CheckBox
var scene_tree: Tree
var _scene_tree_items: Dictionary = {}
var _scene_tree_groups: Dictionary = {}
var _scene_tree_signature := ""
var paint_texture: OptionButton
var paint_texture_id := ""
var _preset_icons: Dictionary = {}
var terrain_texture: OptionButton
var terrain_tile: SpinBox
var object_texture: OptionButton
var animation_cache: Dictionary = {}
var conversion_bytes: PackedByteArray = PackedByteArray()
var scale_box: SpinBox
var speed: SpinBox
var faction: OptionButton
var object_title: Label
var status: Label
var route_button: Button
var new_button: Button
var undo_point_button: Button
var reverse_route_button: Button
var clear_route_button: Button
var issues_count_label: Label
var terrain_mode: OptionButton
var terrain_radius: SpinBox
var terrain_strength: SpinBox
var road_width: SpinBox
var wall_height: SpinBox
var terrain_size_label: Label
var ground_size_picker: OptionButton
var grow_ground_button: Button
var play_button: Button
var flight_button: Button
var flight_info: Label
var map_button: Button
var map_visibility_button: Button
var export_button: Button
var add_dialog: FileDialog
var animation_dialog: FileDialog
var texture_dialog: FileDialog
var convert_dialog: FileDialog
var convert_save_dialog: FileDialog
var save_dialog: FileDialog
var export_dialog: FileDialog
var open_dialog: FileDialog
var glb_dialog: FileDialog
var pack_dialog: FileDialog
var export3d_button: Button
var exportglb_button: Button
var folder_dialog: FileDialog
var confirm: ConfirmationDialog
var information: AcceptDialog
var current_path := ""
var pending_action := ""
var map_expanded := false
var _refreshing := false
var android := false
var touch_ui := false
var folders
var folder_list: VBoxContainer
var folder_name_edit: LineEdit
var folder_status: Label
var folder_buttons: Array = []
var library_panel: PanelContainer
var inspector_panel: PanelContainer
var library_button: Button
var inspector_button: Button
var flight_pad: HFlowContainer
var walk_pad: HFlowContainer
var fpv_button: Button
var aircraft_scale_box: SpinBox
var brick_scale_box: SpinBox
var wall_height_box: SpinBox
var aircraft_scale_value := 1.0
var orbit_button: Button
var save_here_button: Button
var export_here_button: Button
var confirm_delete: ConfirmationDialog
var pending_folder_delete := ""
var current_folder := ""

var history
var selection
var validator
var library_index
var perf
var autosave
var shell_slots: Dictionary = {}
var crumb_label: Label
var save_button: Button
var quick_labels: Button
var quick_grid: Button
var quick_hide_ui: Button
var quick_recentre: Button
var quick_undo: Button
var quick_redo: Button
var quick_snap: Button
var quick_multi: Button
var ruler_button: Button
var sun_slider: HSlider
var sun_label: Label
var env_sliders: Dictionary = {}
var env_summary_label: Label
var eye_height_slider: HSlider
var rotation_snap := 0.0
var anim_displacement_spin: SpinBox
var anim_range_spin: SpinBox
var report_dialog: AcceptDialog
var route_dialog: AcceptDialog
var report_text: TextEdit
var route_text: TextEdit
var brush_radius_slider: HSlider
var brush_strength_slider: HSlider
var brush_tool_label: Label
var perf_label: Label
var issues_button: Button
var autosave_label: Label
var hierarchy_count_label: Label
var inspector_tab_buttons: Dictionary = {}
var inspector_tab_panels: Dictionary = {}
var object_empty_state: VBoxContainer
var object_detail_container: VBoxContainer
var active_tab := "OBJECT"
var _shelf_buttons: Array = []
var heightmap_additive := false
var underlay_slider: HSlider
var checklist_summary: Label
var autosave_status: Label
var autosave_list: VBoxContainer
var heightmap_dialog: FileDialog
var heightmap_save_dialog: FileDialog
var underlay_dialog: FileDialog
var help_overlay: PanelContainer
var library_search: LineEdit
var library_category: OptionButton
var recents_label: Label
var checklist_panel: PanelContainer
var checklist_list: VBoxContainer
var checklist_issues: Array = []
var help_panel: PanelContainer
var snap_enabled := false
var multi_select_mode := false
var ui_hidden := false
var _last_doc: Dictionary = {}
var _last_selected := ""
var _restoring := false
var _group_active := false
var _group_pushed := false
var _sun_timer: Timer
var _autosave_timer: Timer
var _perf_timer: Timer
var view_frame: Control
var _compact_layout := false
var _narrow_layout := false
var _responsive_initialized := false
var _last_checklist := 0
const HISTORY_LABELS := { "objects": "Place or delete object", "terrain": "Sculpt terrain", "paint": "Paint texture", "route": "Edit route", "construction": "Edit road or wall", "properties": "Change properties", "pose": "Move object", "mission": "Edit mission", "flags": "Lock or hide objects", "environment": "Change light and weather"}

const BG := Color("0b1113")
const PANEL := Color("141d1f")
const TEXT := Color("e6f1ec")
const BUSY_TEXT := "Leave the flight test or first-person walk first."
const MUTED := Color("96ada9")
const ACCENT := Color("5ee0b0")

func _ready() -> void:


	android = OS.get_name() == "Android" or OS.has_environment("REAPER_FORCE_MOBILE_LAYOUT")
	touch_ui = android or DisplayServer.is_touchscreen_available()
	folders = Folders.new(); folders.load_state()
	get_tree().auto_accept_quit = false
	if DisplayServer.get_name() != "headless" and not android: DisplayServer.window_set_min_size(Vector2i(640, 520))
	state.reset_blank()
	_seed_default_ground()
	history = History.new(); selection = Selection.new(); validator = Validation.new()
	library_index = LibraryIndex.new(); library_index.load_state()
	perf = Perf.new(); autosave = Autosave.new()
	_build_theme(); _build_ui(); _make_dialogs(); _make_extra_dialogs(); _build_help_overlay()
	if android: _apply_android_dialog_defaults()
	_apply_dialog_titles()
	state.changed.connect(_state_changed)
	_last_doc = state.data.duplicate(true); _last_selected = state.selected_id
	_sun_timer = Timer.new(); _sun_timer.one_shot = true; _sun_timer.wait_time = 0.45; _sun_timer.timeout.connect(_sun_commit); add_child(_sun_timer)
	_perf_timer = Timer.new(); _perf_timer.wait_time = 0.8; _perf_timer.timeout.connect(_refresh_perf); add_child(_perf_timer); _perf_timer.start()
	_autosave_timer = Timer.new(); _autosave_timer.wait_time = 5.0; _autosave_timer.timeout.connect(_autosave_tick); add_child(_autosave_timer); _autosave_timer.start()
	if not android: get_window().files_dropped.connect(_files_dropped)
	_refresh_library(); _refresh_inspector(); _refresh_environment()
	_status("Blank scene ready • left-drag empty ground to pan • choose terrain, road or wall tools")
	if DisplayServer.get_name() != "headless": _show_splash()

func _seed_default_ground() -> void:
	# A clear, editable terrain surface gives new missions a useful visual start.
	# Embed the actual colour texture so the draft and mission are self-contained.
	for preset: Dictionary in TerrainPresets.PRESETS:
		if str(preset.get("name", "")) != "Studio: Desert Sand": continue
		var bytes := TerrainPresets.read(preset)
		var id := str(preset.id)
		if bytes.is_empty() or "tex_" + Codec.sha256(bytes) != id: return
		state.custom_assets[id] = {"name": str(preset.name), "bytes": bytes, "category": "texture"}
		state.data["terrain_texture"] = id
		state.data["terrain_tile_m"] = float(preset.get("tile_m", 24.0))
		state.dirty = false
		if scene_view != null: scene_view.refresh_terrain_texture()
		if mission_name != null: _refresh_inspector()
		_last_doc = state.data.duplicate(true)
		return

func _build_theme() -> void:
	var t := UI.theme()
	t.default_font_size = 17 if android else 13
	var normal := UI.flat(UI.PANEL_ALT, UI.LINE, 5, 1, 8, 5)
	var focus := UI.flat(UI.PANEL_ALT, UI.ACCENT_DIM, 5, 1, 8, 5)
	for kind in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", kind, normal)
		t.set_stylebox("focus", kind, focus)
		t.set_color("font_color", kind, UI.TEXT)
		t.set_color("font_placeholder_color", kind, UI.DIM)
	t.set_stylebox("normal", "OptionButton", UI.flat(UI.PANEL_ALT, UI.LINE, 5, 1, 8, 5))
	t.set_stylebox("hover", "OptionButton", UI.flat(Color("26373a"), UI.LINE_HI, 5, 1, 8, 5))
	t.set_stylebox("pressed", "OptionButton", UI.flat(Color("1d4438"), UI.ACCENT_DIM, 5, 1, 8, 5))
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_color("font_color", "OptionButton", UI.TEXT)
	t.set_color("font_color", "CheckBox", UI.TEXT)
	# Native Godot dialogs and their controls should use the same Studio palette
	# as the surrounding workspace, not the engine's default gray buttons.
	t.set_stylebox("normal", "Button", UI.flat(Color("1f2f31"), UI.LINE, 5, 1, 10, 5))
	t.set_stylebox("hover", "Button", UI.flat(Color("2b4245"), UI.LINE_HI, 5, 1, 10, 5))
	t.set_stylebox("pressed", "Button", UI.flat(Color("17473a"), UI.ACCENT, 5, 1, 10, 5))
	t.set_stylebox("disabled", "Button", UI.flat(Color("1a2325"), UI.LINE, 5, 1, 10, 5))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "AcceptDialog", UI.flat(UI.PANEL, UI.LINE_HI, 7, 1, 8, 8))
	# Embedded Window title bars are drawn outside the content rectangle.
	# Preserve the engine's expansion margins so the dark frame covers them.
	for border_name in ["embedded_border", "embedded_unfocused_border"]:
		var frame := UI.flat(UI.PANEL, UI.LINE_HI if border_name == "embedded_border" else UI.LINE, 7, 1, 8, 8)
		frame.content_margin_left = 10; frame.content_margin_top = 28
		frame.content_margin_right = 10; frame.content_margin_bottom = 8
		frame.expand_margin_left = 8; frame.expand_margin_top = 32
		frame.expand_margin_right = 8; frame.expand_margin_bottom = 6
		t.set_stylebox(border_name, "Window", frame)
	t.set_color("title_color", "Window", UI.TEXT)
	t.set_color("font_disabled_color", "Button", UI.DIM)
	theme = t

func _panel_style(color: Color, border := Color("27383b"), radius := 6) -> StyleBoxFlat:
	return UI.flat(color, border, radius, 1, 9, 6)

func _panel() -> PanelContainer:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", _panel_style(PANEL)); return p
func _label(text: String, size := 14, col := TEXT) -> Label:
	var n := Label.new(); n.text = text; n.add_theme_font_size_override("font_size", size); n.add_theme_color_override("font_color", col); return n
func _button(text: String, accent := false) -> Button:
	var b := UI.button(text, accent)
	b.custom_minimum_size.y = 46 if android else 30
	b.add_theme_font_size_override("font_size", 16 if android else 12)
	b.focus_mode = Control.FOCUS_ALL
	return b

func _icon(name: String, color := TEXT) -> Texture2D:
	var aliases := {"move": "select", "paint": "brush", "centre": "target", "library": "pattern", "props": "layers", "flight": "world", "checks": "check", "hide": "eye_off", "route_preview": "route", "grow": "plus", "report": "stats", "height_up": "raise", "height_down": "lower", "orbit": "rotate"}
	var modern := str(aliases.get(name, name))
	if StudioIcons.PATHS.has(modern): return StudioIcons.tex(modern, 18, color)
	return Icons.icon(name, color)

func _icon_button(icon_name: String, tooltip: String, size := Vector2(38, 32), accent := false) -> Button:
	var b := _button("", accent)
	b.icon = _icon(icon_name)
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", 20 if not android else 24)
	b.text = ""
	b.tooltip_text = tooltip
	b.custom_minimum_size = size
	return b

func _spacer() -> Control:
	var c := Control.new(); c.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return c

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	shell_slots = Shell.new().build(self)
	_build_shelf_tools(shell_slots.shelf_tools)
	_build_library(shell_slots.library_host)
	_build_workspace(shell_slots.view_host, shell_slots.lower_host)
	_build_inspector(shell_slots)
	_set_inspector_tab("OBJECT")
	resized.connect(_apply_responsive)
	call_deferred("_apply_responsive")

func _apply_responsive() -> void:
	if library_panel == null or inspector_panel == null: return
	var width := size.x
	if width < 1.0: return
	var compact := width < 1160.0 or android
	var narrow := width < 900.0 or android
	var changed := not _responsive_initialized or compact != _compact_layout or narrow != _narrow_layout
	_compact_layout = compact
	_narrow_layout = narrow
	_responsive_initialized = true
	library_panel.custom_minimum_size.x = 255.0 if compact else 290.0
	inspector_panel.custom_minimum_size.x = 270.0 if compact else 315.0
	if shell_slots.has("desktop_menus"): shell_slots.desktop_menus.visible = not compact
	if shell_slots.has("compact_menu"): shell_slots.compact_menu.visible = compact
	if shell_slots.has("brand_badge"): shell_slots.brand_badge.visible = width >= 760.0
	if changed and not ui_hidden:
		library_panel.visible = not narrow
		inspector_panel.visible = not compact
	if library_button != null: library_button.set_pressed_no_signal(library_panel.visible)
	if inspector_button != null: inspector_button.set_pressed_no_signal(inspector_panel.visible)
	_layout_map()

func _open_right_tab(tab: String) -> void:
	if inspector_panel == null: return
	inspector_panel.visible = true
	if _compact_layout and library_panel != null:
		library_panel.visible = false
		if library_button != null: library_button.set_pressed_no_signal(false)
	if inspector_button != null: inspector_button.set_pressed_no_signal(true)
	if quick_hide_ui != null: quick_hide_ui.set_pressed_no_signal(false)
	ui_hidden = false
	_set_inspector_tab(tab)

func _build_shelf_tools(host: VBoxContainer) -> void:
	var tools := [
		{"index": 0, "icon": "select", "text": "Select", "tip": "Select and move objects"},
		{"index": 1, "icon": "raise", "text": "Raise", "tip": "Raise terrain"},
		{"index": 2, "icon": "lower", "text": "Lower", "tip": "Lower terrain"},
		{"index": 3, "icon": "smooth", "text": "Smooth", "tip": "Smooth terrain"},
		{"index": 4, "icon": "flatten", "text": "Flatten", "tip": "Flatten terrain"},
		{"index": 7, "icon": "brush", "text": "Paint", "tip": "Paint a selected ground texture"},
		{"index": 8, "icon": "erase", "text": "Erase", "tip": "Erase painted texture"},
		{"index": 9, "icon": "wave", "text": "Snow", "tip": "Paint snow on the ground"},
		{"index": 5, "icon": "road", "text": "Road", "tip": "Draw a terrain-following road"},
		{"index": 6, "icon": "wall", "text": "Wall", "tip": "Draw a brick wall"},
	]
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	host.add_child(grid)
	_shelf_buttons = []
	var group := ButtonGroup.new()
	for row: Dictionary in tools:
		var button := StudioIcons.toggle(str(row.icon), str(row.text), str(row.tip), "", str(row.text), 16)
		button.name = "tool_" + str(row.text).to_lower()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 48 if not android else 58)
		button.add_theme_font_size_override("font_size", 10 if not android else 13)
		button.add_theme_color_override("font_color", TEXT)
		button.button_group = group
		button.pressed.connect(_shelf_tool.bind(int(row.index)))
		grid.add_child(button)
		_shelf_buttons.append({"button": button, "index": int(row.index)})
		if int(row.index) == 0: button.set_pressed_no_signal(true)
	route_button = StudioIcons.toggle("route", "Route", "Click or drag to create waypoints for the selected object", "", "Route", 16)
	route_button.name = "tool_route"
	route_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	route_button.custom_minimum_size.y = 48 if not android else 58
	route_button.add_theme_color_override("font_color", TEXT)
	route_button.toggled.connect(_route_toggled)
	grid.add_child(route_button)
	fpv_button = StudioIcons.toggle("walk", "Walk", "Explore the scene on foot", "", "Walk", 16)
	fpv_button.name = "tool_walk"
	fpv_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fpv_button.custom_minimum_size.y = 48 if not android else 58
	fpv_button.add_theme_color_override("font_color", TEXT)
	fpv_button.toggled.connect(func(_pressed): _toggle_fpv())
	grid.add_child(fpv_button)
	var footer: VBoxContainer = shell_slots.shelf_footer
	terrain_mode = OptionButton.new()
	terrain_mode.tooltip_text = "Select a terrain or build tool"
	for item in ["Select / Move", "Raise", "Lower", "Smooth", "Flatten", "Draw Road", "Draw Brick Wall", "Paint Texture", "Erase Texture Paint", "Paint Snow"]: terrain_mode.add_item(item)
	terrain_mode.item_selected.connect(_terrain_mode_changed)
	terrain_mode.visible = false
	footer.add_child(terrain_mode)

func tool_button(index: int) -> Button:
	for row: Dictionary in _shelf_buttons:
		if int(row.index) == index: return row.button
	return null

func _shelf_buttons_set(index: int) -> void:
	for entry: Dictionary in _shelf_buttons:
		var button: Button = entry.button
		button.button_pressed = int(entry.index) == index

func _shelf_tool(index: int) -> void:
	_shelf_buttons_set(index)
	if terrain_mode != null and terrain_mode.selected != index: terrain_mode.select(index)
	_terrain_mode_changed(index)

func _build_library(host: VBoxContainer) -> void:
	host.add_theme_constant_override("separation", 6)
	host.add_child(UI.section("Content library", "cube"))
	var intro := _label("Click an asset to place it, or drag it onto the scene.", 11, MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.add_child(intro)
	library_search = UI.line_edit("Search assets…")
	library_search.name = "library_search"
	library_search.clear_button_enabled = true
	library_search.text_changed.connect(func(_text): _refresh_library())
	host.add_child(library_search)
	library_category = UI.option(library_index.categories())
	library_category.name = "library_category"
	library_category.item_selected.connect(func(_i): _refresh_library())
	host.add_child(library_category)
	var adds := GridContainer.new()
	adds.columns = 2
	adds.add_theme_constant_override("h_separation", 4)
	adds.add_theme_constant_override("v_separation", 4)
	host.add_child(adds)
	var model := _button("+ Model")
	model.tooltip_text = "Import a GLB or FBX model"
	model.pressed.connect(func(): add_dialog.popup_centered_ratio(0.7))
	model.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adds.add_child(model)
	var anim := _button("+ Animation")
	anim.tooltip_text = "Import a separate GLB or FBX animation"
	anim.pressed.connect(func(): animation_dialog.popup_centered_ratio(0.7))
	anim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adds.add_child(anim)
	var tex := _button("+ Texture")
	tex.tooltip_text = "Import a PNG or JPEG texture"
	tex.pressed.connect(func(): texture_dialog.popup_centered_ratio(0.7))
	tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adds.add_child(tex)
	var convert := _button("FBX → GLB")
	convert.tooltip_text = "Convert a local FBX file to GLB"
	convert.pressed.connect(func(): convert_dialog.popup_centered_ratio(0.7))
	convert.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adds.add_child(convert)
	recents_label = _label("RECENT: —", 10, MUTED)
	recents_label.clip_text = true
	host.add_child(recents_label)
	var scroll := ScrollContainer.new()
	scroll.name = "AssetListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.add_child(scroll)
	asset_list = VBoxContainer.new()
	asset_list.name = "AssetList"
	asset_list.add_theme_constant_override("separation", 4)
	asset_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(asset_list)

func _build_workspace(view_host: VBoxContainer, lower_host: VBoxContainer) -> void:
	var frame := Control.new()
	frame.name = "SceneViewportFrame"
	view_frame = frame
	frame.resized.connect(_layout_map)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.clip_contents = true
	view_host.add_child(frame)
	scene_view = SceneView.new(); scene_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); scene_view.setup(state, library); scene_view.asset_dropped.connect(_place_asset); scene_view.edit_feedback.connect(_status); frame.add_child(scene_view)
	var input_overlay = SceneInteraction.new(); input_overlay.scene = scene_view; input_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); frame.add_child(input_overlay)
	map_view = MapCanvas.new(); map_view.anchor_left = 1; map_view.anchor_right = 1; map_view.offset_left = -350; map_view.offset_right = -10; map_view.offset_top = 10; map_view.offset_bottom = 238; map_view.setup(state); map_view.flight_scene = scene_view; map_view.preview_positions = scene_view.preview_positions; scene_view.preview_frame.connect(map_view.queue_redraw); map_view.asset_dropped.connect(_place_asset); map_view.edit_feedback.connect(_status); frame.add_child(map_view)
	call_deferred("_layout_map")
	var controls := HFlowContainer.new()
	controls.add_theme_constant_override("h_separation", 4); controls.add_theme_constant_override("v_separation", 3)
	lower_host.add_child(controls)
	controls.add_child(_label("VIEW / ROUTE", 10, MUTED))
	undo_point_button = _icon_button("undo", "Undo the last route waypoint"); undo_point_button.pressed.connect(func (): state.undo_waypoint(state.selected_id)); controls.add_child(undo_point_button)
	reverse_route_button = _icon_button("route_preview", "Reverse the route order"); reverse_route_button.pressed.connect(func (): state.reverse_route(state.selected_id); _status("Route order reversed.")); controls.add_child(reverse_route_button)
	clear_route_button = _icon_button("trash", "Clear every waypoint on the route"); clear_route_button.pressed.connect(func (): state.clear_route(state.selected_id)); controls.add_child(clear_route_button)
	var focus_button := _icon_button("focus", "Focus the camera on the selected object"); focus_button.pressed.connect(func (): if scene_view != null: scene_view.focus_selected()); controls.add_child(focus_button)
	quick_recentre_tooltip(focus_button)
	var zoom_in := _icon_button("zoom_in", "Zoom the 3D camera in"); zoom_in.pressed.connect(func (): if scene_view != null: scene_view.zoom_step(1)); controls.add_child(zoom_in)
	var zoom_out := _icon_button("zoom_out", "Zoom the 3D camera out"); zoom_out.pressed.connect(func (): if scene_view != null: scene_view.zoom_step(-1)); controls.add_child(zoom_out)
	orbit_button = _icon_button("orbit", "Orbit look: drag with one finger to look around instead of drawing"); orbit_button.toggle_mode = true; orbit_button.toggled.connect(_orbit_toggled); controls.add_child(orbit_button)
	var map_in := _icon_button("zoom_in", "Zoom the editable map in"); map_in.pressed.connect(func (): if map_view != null: map_view.zoom_step(1)); controls.add_child(map_in)
	var map_out := _icon_button("zoom_out", "Zoom the editable map out"); map_out.pressed.connect(func (): if map_view != null: map_view.zoom_step(-1)); controls.add_child(map_out)
	flight_info = _label("", 11, Color("a8e8ef")); flight_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; flight_info.visible = false; lower_host.add_child(flight_info)
	flight_pad = HFlowContainer.new(); flight_pad.add_theme_constant_override("h_separation", 4); flight_pad.add_theme_constant_override("v_separation", 3); flight_pad.visible = false; lower_host.add_child(flight_pad)
	_build_flight_pad()
	walk_pad = HFlowContainer.new(); walk_pad.add_theme_constant_override("h_separation", 4); walk_pad.add_theme_constant_override("v_separation", 3); walk_pad.visible = false; lower_host.add_child(walk_pad)
	_build_walk_pad()
	scene_view.flight_status.connect(func (text): if flight_info != null: flight_info.text = text + "\nW/S speed • A/D bank and turn • UP/DOWN climb • drag the SIZE slider to scale the aircraft • press STOP FLIGHT to return")
	scene_view.walk_status.connect(func (text):
		if flight_info == null: return
		flight_info.text = text if text.is_empty() else text + "\nArrows or W/A/S/D walk • SPACE jumps • drag to look • press EXIT FIRST PERSON to return")
	scene_view.walk_mode_changed.connect(_walk_mode_changed)

func _build_walk_pad() -> void:
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4); grid.add_theme_constant_override("v_separation", 4)
	walk_pad.add_child(grid)
	_pad_spacer(grid)
	_add_walk_key(grid, "arrow_up", "Walk forward", "forward", 1.0)
	_pad_spacer(grid)
	_add_walk_key(grid, "arrow_left", "Step left", "strafe", -1.0)
	var jump := _pad_button("jump", "Jump. Same as the space bar.")
	jump.button_down.connect(func (): scene_view.walk_external["jump"] = true)
	jump.button_up.connect(func (): scene_view.walk_external["jump"] = false)
	jump.pressed.connect(func (): scene_view.walk_jump_queued = true)
	grid.add_child(jump)
	_add_walk_key(grid, "arrow_right", "Step right", "strafe", 1.0)
	_pad_spacer(grid)
	_add_walk_key(grid, "arrow_down", "Walk backward", "forward", -1.0)
	_pad_spacer(grid)
	var exit_walk := _button("EXIT FIRST PERSON"); exit_walk.tooltip_text = "Return to the map and 3D editing camera."
	exit_walk.pressed.connect(_exit_fpv); walk_pad.add_child(exit_walk)
	var height_cell := VBoxContainer.new(); height_cell.custom_minimum_size.x = 170
	height_cell.add_child(_label("EYE HEIGHT: 1.72 m", 10, MUTED))
	var eye_label: Label = height_cell.get_child(0)
	eye_height_slider = HSlider.new(); eye_height_slider.min_value = 0.4; eye_height_slider.max_value = 14.0; eye_height_slider.step = 0.05; eye_height_slider.value = 1.72
	eye_height_slider.tooltip_text = "How tall you are on foot: 0.4 m is a dog's eye view, 1.72 m is a person, 14 m is a rooftop scan. The body and its collision capsule grow with it."
	eye_height_slider.value_changed.connect(func (v):
		eye_label.text = "EYE HEIGHT: %.2f m" % v
		if scene_view != null: scene_view.set_walk_height_scale(v / 1.72))
	height_cell.add_child(eye_height_slider)
	walk_pad.add_child(height_cell)

func _pad_spacer(grid: GridContainer) -> void:
	var side := 78.0 if android else 48.0
	var blank := Control.new(); blank.custom_minimum_size = Vector2(side, side); grid.add_child(blank)

func _add_walk_key(parent: Control, icon: String, tip: String, axis: String, value: float) -> void:
	var button := _pad_button(icon, tip)
	button.button_down.connect(func (): scene_view.walk_external[axis] = value)
	button.button_up.connect(func (): scene_view.walk_external.erase(axis))
	parent.add_child(button)



func _build_flight_pad() -> void:
	var grid := GridContainer.new(); grid.columns = 3; grid.add_theme_constant_override("h_separation", 4); grid.add_theme_constant_override("v_separation", 4)
	flight_pad.add_child(grid)
	var climb := _pad_button("arrow_up", "Climb"); _hold(climb, "climb", 1.0); grid.add_child(climb)
	var faster := _pad_button("speed_up", "More throttle"); _hold(faster, "throttle", 1.0); grid.add_child(faster)
	var descend := _pad_button("arrow_down", "Descend"); _hold(descend, "climb", -1.0); grid.add_child(descend)
	var left := _pad_button("arrow_left", "Bank and turn left"); _hold(left, "turn", -1.0); grid.add_child(left)
	var slower := _pad_button("speed_down", "Less throttle"); _hold(slower, "throttle", -1.0); grid.add_child(slower)
	var right := _pad_button("arrow_right", "Bank and turn right"); _hold(right, "turn", 1.0); grid.add_child(right)
	aircraft_scale_box = _spin(0.25, 4, 0.05); aircraft_scale_box.value = aircraft_scale_value; aircraft_scale_box.step = 0.05
	aircraft_scale_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aircraft_scale_box.tooltip_text = "Size of the aircraft in the flight test. 1 is the model's normal size."
	aircraft_scale_box.value_changed.connect(func (v): _set_aircraft_scale(v))
	var size_cell := VBoxContainer.new(); size_cell.custom_minimum_size.x = 150
	size_cell.add_child(_label("AIRCRAFT SIZE (×)", 10, MUTED)); size_cell.add_child(aircraft_scale_box)
	flight_pad.add_child(size_cell)

func _set_aircraft_scale(value: float) -> void:
	aircraft_scale_value = clampf(value, 0.25, 4.0)
	if scene_view != null: scene_view.set_aircraft_scale(aircraft_scale_value)
	if aircraft_scale_box != null and not is_equal_approx(aircraft_scale_box.value, aircraft_scale_value):
		aircraft_scale_box.set_value_no_signal(aircraft_scale_value)



func _pad_button(icon_name: String, tooltip: String) -> Button:
	var side := 78.0 if android else 48.0
	var button := _icon_button(icon_name, tooltip, Vector2(side, side))
	button.add_theme_constant_override("icon_max_width", 44 if android else 26)
	return button

func _hold(button: Button, axis: String, value: float) -> void:
	button.button_down.connect(func (): scene_view.external_controls[axis] = value)
	button.button_up.connect(func (): scene_view.external_controls.erase(axis))

func _walk_mode_changed(active: bool) -> void:
	if walk_pad != null: walk_pad.visible = active
	if flight_pad != null: flight_pad.visible = false if active else flight_pad.visible
	if flight_info != null: flight_info.visible = active or scene_view.fly_active
	if fpv_button != null:
		if active: fpv_button.set_pressed_no_signal(true)
		else: fpv_button.set_pressed_no_signal(false)

func _toggle_fpv() -> void:
	if scene_view == null: return
	if scene_view.walk_active: _exit_fpv(); return
	if scene_view.fly_active: _status(BUSY_TEXT); return
	if scene_view.enter_fpv():
		flight_info.visible = true
		if map_button != null: map_button.set_pressed_no_signal(false)
		_status("First person: walk with the arrows or W/A/S/D, SPACE jumps, drag to look.")
	else: _status("First person view could not start.")

func _exit_fpv() -> void:
	if scene_view != null and scene_view.walk_active: scene_view.exit_fpv()
	if flight_info != null and not (scene_view != null and scene_view.fly_active): flight_info.visible = false

func quick_recentre_tooltip(_button: Button) -> void: pass

func _field(parent: VBoxContainer, title: String, control: Control) -> void:
	parent.add_child(_label(title.to_upper(), 11, MUTED)); control.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(control)
func _spin(lo: float, hi: float, step: float) -> SpinBox:
	var b := SpinBox.new(); b.min_value = lo; b.max_value = hi; b.step = step; b.allow_greater = false; b.allow_lesser = false; b.custom_minimum_size.y = 46 if android else 30; return b

func _build_inspector(slots: Dictionary) -> void:
	var tree_help := _label("Select any object; double-click to focus it in 3D. MULTI picks several.", 10, MUTED)
	tree_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slots.hierarchy_host.add_child(tree_help)
	scene_tree = Tree.new()
	scene_tree.custom_minimum_size.y = 220
	scene_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene_tree.hide_root = false
	scene_tree.select_mode = Tree.SELECT_SINGLE
	scene_tree.item_selected.connect(_scene_tree_selected)
	scene_tree.item_activated.connect(_scene_tree_activated)
	slots.hierarchy_host.add_child(scene_tree)
	_fill_object_tab(slots.tab_object)
	_fill_terrain_tab(slots.tab_terrain)
	_fill_mission_tab(slots.tab_mission)
	_build_folder_panel(slots.tab_files)
	_fill_files_tab(slots.tab_files)

func _fill_object_tab(page: VBoxContainer) -> void:
	object_empty_state = VBoxContainer.new()
	object_empty_state.add_theme_constant_override("separation", 8)
	page.add_child(object_empty_state)
	object_empty_state.add_child(UI.section("Object inspector", "cube"))
	var empty_title := _label("Nothing selected", 16, TEXT)
	object_empty_state.add_child(empty_title)
	var empty_hint := _label("Select an object in the scene or on the map to edit its position, appearance, route and animation.", 12, MUTED)
	empty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	object_empty_state.add_child(empty_hint)
	var browse := _button("Browse assets", true)
	browse.pressed.connect(_open_content_browser)
	object_empty_state.add_child(browse)
	object_detail_container = VBoxContainer.new()
	object_detail_container.add_theme_constant_override("separation", 5)
	page.add_child(object_detail_container)
	_fill_object_properties(object_detail_container)

func _open_content_browser() -> void:
	if library_panel == null: return
	library_panel.visible = true
	if _compact_layout and inspector_panel != null: inspector_panel.visible = false
	if library_button != null: library_button.set_pressed_no_signal(true)
	if inspector_button != null: inspector_button.set_pressed_no_signal(inspector_panel.visible)
	if shell_slots.has("content_tab_button"): shell_slots.content_tab_button.pressed.emit()
	ui_hidden = false
	if quick_hide_ui != null: quick_hide_ui.set_pressed_no_signal(false)

func _fill_object_properties(page: VBoxContainer) -> void:
	page.add_child(_label("SELECTED OBJECT", 11, ACCENT))
	var select_row := HFlowContainer.new(); select_row.add_theme_constant_override("h_separation", 4); page.add_child(select_row)
	var copy := _icon_button("copy", "Copy the selection"); copy.pressed.connect(_copy_selection); select_row.add_child(copy)
	var paste := _icon_button("paste", "Paste at an offset"); paste.pressed.connect(_paste_selection); select_row.add_child(paste)
	var dup := _icon_button("duplicate", "Duplicate the selection"); dup.pressed.connect(_duplicate_selection); select_row.add_child(dup)
	var lock := _icon_button("lock", "Lock: stop the selected objects from being dragged or nudged"); lock.toggle_mode = true; lock.toggled.connect(func (v): _flag_selection("locked", v)); select_row.add_child(lock)
	var hide := _icon_button("hide", "Hide: keep the objects in the file but out of both views"); hide.toggle_mode = true; hide.toggled.connect(func (v): _flag_selection("hidden", v)); select_row.add_child(hide)
	var del := _icon_button("trash", "Delete the selection"); del.pressed.connect(_delete_selection); select_row.add_child(del)
	var align_row := HFlowContainer.new(); align_row.add_theme_constant_override("h_separation", 4); page.add_child(align_row)
	align_row.add_child(_label("ALIGN", 10, MUTED))
	var align_icons := { "left": "align_left", "center_x": "align_centre", "right": "align_right", "back": "align_back", "center_z": "align_centre", "front": "align_front"}
	for mode in ["left", "center_x", "right", "back", "center_z", "front"]:
		var button := _icon_button(str(align_icons[mode]), "Align %s" % mode.replace("_", " "))
		button.pressed.connect(func (): _align_selection(mode)); align_row.add_child(button)
	var spread := _icon_button("spread", "Spread: space three or more objects evenly along X"); spread.pressed.connect(func (): _distribute_selection("x")); align_row.add_child(spread)
	var spread_z := _icon_button("spread", "Spread: space three or more objects evenly along Z"); spread_z.pressed.connect(func (): _distribute_selection("z")); align_row.add_child(spread_z)
	object_title = _label("NO OBJECT SELECTED", 12, ACCENT); page.add_child(object_title)
	obj_name = LineEdit.new(); obj_name.text_changed.connect(func (v): if not _refreshing: state.set_value(state.selected_id, "name", v)); _field(page, "Object name", obj_name)
	var coordinates := HBoxContainer.new(); page.add_child(_label("POSITION X / Z (m)", 10, MUTED)); page.add_child(coordinates)
	pos_x = _spin(- state.extent(), state.extent(), maxf(1.0, state.extent() / 1000.0)); pos_z = _spin(- state.extent(), state.extent(), maxf(1.0, state.extent() / 1000.0)); pos_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pos_z.size_flags_horizontal = Control.SIZE_EXPAND_FILL; coordinates.add_child(pos_x); coordinates.add_child(pos_z)
	pos_x.value_changed.connect(func (v): if not _refreshing: _change_position(v, pos_z.value))
	pos_z.value_changed.connect(func (v): if not _refreshing: _change_position(pos_x.value, v))
	height = _spin(-5, 500, 1); height.value_changed.connect(func (v): if not _refreshing: state.set_value(state.selected_id, "height", v)); _field(page, "Height above ground (m)", height)
	yaw = _spin(-360, 360, 1); yaw.value_changed.connect(func (v): if not _refreshing: state.set_value(state.selected_id, "yaw_deg", v)); _field(page, "Yaw / route facing offset (degrees)", yaw)
	pitch = _spin(-360, 360, 1); pitch.value_changed.connect(func (v): if not _refreshing: state.set_value(state.selected_id, "pitch_deg", v)); _field(page, "Tilt / pitch (degrees)", pitch)
	roll = _spin(-360, 360, 1); roll.value_changed.connect(func (v): if not _refreshing: state.set_value(state.selected_id, "roll_deg", v)); _field(page, "Tilt / roll (degrees)", roll)
	var flip := _button("FLIP MODEL FACING 180°"); flip.pressed.connect(_flip_facing); page.add_child(flip)
	scale_box = _spin(0.05, 30, 0.05); scale_box.value_changed.connect(func (v): if not _refreshing: state.set_value(state.selected_id, "scale", v)); _field(page, "Scale", scale_box)
	faction = OptionButton.new(); for item in ["Friendly", "Hostile", "Civilian", "Neutral"]: faction.add_item(item)
	faction.item_selected.connect(func (i): if not _refreshing: state.set_value(state.selected_id, "faction", faction.get_item_text(i))); _field(page, "Side", faction)
	speed = _spin(0, 100, 0.5); speed.value_changed.connect(func (v): if not _refreshing: state.set_value(state.selected_id, "speed_mps", v)); _field(page, "Route speed (m/s)", speed)
	route_face = CheckBox.new(); route_face.text = "Face along route"; route_face.toggled.connect(func (v): if not _refreshing: state.set_value(state.selected_id, "route_face", v)); page.add_child(route_face)
	object_texture = OptionButton.new(); object_texture.item_selected.connect(_object_texture_selected); _field(page, "Selected object texture", object_texture)
	animation_own = CheckBox.new(); animation_own.text = "Play the model's own animation"
	animation_own.tooltip_text = "Leave the animation inside the model file alone: it plays as it was made, with its own clip, timing and looping, and route preview never pauses or restarts it. Untick it to drive the model with the clip, loop and speed controls below."
	animation_own.toggled.connect(func (v): if not _refreshing: state.set_value(state.selected_id, "animation_own", v))
	page.add_child(animation_own)
	animation_source = OptionButton.new(); animation_source.item_selected.connect(_animation_source_selected); _field(page, "Animation source", animation_source)
	animation_clip = OptionButton.new(); animation_clip.item_selected.connect(_animation_clip_selected); _field(page, "Animation clip", animation_clip)
	animation_loop = CheckBox.new(); animation_loop.text = "Loop animation"; animation_loop.toggled.connect(func (v): if not _refreshing: state.set_value(state.selected_id, "animation_loop", v)); page.add_child(animation_loop)
	animation_speed = _spin(0.1, 5, 0.1); animation_speed.value_changed.connect(func (v): if not _refreshing: state.set_value(state.selected_id, "animation_speed", v)); _field(page, "Animation speed", animation_speed)
	anim_displacement_spin = _spin(0, 20, 0.1)
	anim_displacement_spin.tooltip_text = "How fast the animated character travels, in metres per second. 0 animates in place. With a route it adds to the route speed; without one the character paces back and forth."
	anim_displacement_spin.value_changed.connect(func (v): if not _refreshing: state.set_value(state.selected_id, "animation_displacement", v))
	_field(page, "Animation travel speed (m/s)", anim_displacement_spin)
	anim_range_spin = _spin(2, 400, 1)
	anim_range_spin.tooltip_text = "How far the character walks before turning around, when it has no route of its own."
	anim_range_spin.value_changed.connect(func (v): if not _refreshing: state.set_value(state.selected_id, "animation_range", v))
	_field(page, "Walk back and forth over (m)", anim_range_spin)
	_fill_rotation_section(page)
	animation_status = _label("Select a model and an animation.", 10, MUTED); animation_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; page.add_child(animation_status)

func _fill_terrain_tab(page: VBoxContainer) -> void:
	page.add_child(_label("GROUND AND PAINT", 11, ACCENT))
	terrain_texture = OptionButton.new(); terrain_texture.tooltip_text = "Choose a built-in or imported surface for the whole ground."; terrain_texture.item_selected.connect(_terrain_texture_selected); _field(page, "Ground texture", terrain_texture)
	terrain_tile = _spin(5, 500, 1); terrain_tile.value_changed.connect(func (v): if not _refreshing: state.set_mission("terrain_tile_m", v)); _field(page, "Ground and paint tile size (m)", terrain_tile)
	paint_texture = OptionButton.new(); paint_texture.tooltip_text = "Choose the image used by Paint Texture mode. Up to four painted layers are supported."; paint_texture.item_selected.connect(_paint_texture_selected); _field(page, "Paint brush texture", paint_texture)
	var paint_row := HFlowContainer.new(); paint_row.add_theme_constant_override("h_separation", 4); page.add_child(paint_row)
	var remove_layer := _button("REMOVE PAINT LAYER"); remove_layer.pressed.connect(_remove_paint_layer); paint_row.add_child(remove_layer)
	var undo_paint := _button("UNDO PAINT"); undo_paint.pressed.connect(_undo_paint); paint_row.add_child(undo_paint)
	var clear_paint := _button("CLEAR PAINT"); clear_paint.pressed.connect(_clear_paint); paint_row.add_child(clear_paint)
	page.add_child(_label("SNOW", 11, ACCENT))
	var snow_hint := _label("The SNOW brush (left shelf) paints snow onto the ground. It is separate from the four texture layers, so snow never costs a paint slot.", 10, MUTED)
	snow_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; page.add_child(snow_hint)
	var snow_row := HFlowContainer.new(); snow_row.add_theme_constant_override("h_separation", 4); page.add_child(snow_row)
	var snow_tool := _button("SNOW BRUSH"); snow_tool.tooltip_text = "Switch to the snow brush, then drag on the ground in either view."; snow_tool.pressed.connect(func (): _shelf_tool(9)); snow_row.add_child(snow_tool)
	var snow_undo := _button("UNDO SNOW"); snow_undo.tooltip_text = "Undo the last painted snow stroke."; snow_undo.pressed.connect(_undo_snow); snow_row.add_child(snow_undo)
	var snow_clear := _button("CLEAR SNOW"); snow_clear.tooltip_text = "Remove every painted patch of snow. The weather snow cover slider is untouched."; snow_clear.pressed.connect(_clear_snow); snow_row.add_child(snow_clear)
	var sculpt_row := HFlowContainer.new(); sculpt_row.add_theme_constant_override("h_separation", 4); page.add_child(sculpt_row)
	var undo_sculpt := _button("UNDO SCULPT")
	undo_sculpt.pressed.connect(func ():
		if not scene_view.busy() and state.undo_terrain_stroke(): _status("Undid the last terrain stroke.")
		else: _status("No terrain stroke to undo, or a flight test is running."))
	sculpt_row.add_child(undo_sculpt)
	var grow := _button("+ GROUND"); grow.tooltip_text = "Add flat terrain around the edges without stretching existing terrain. Steps up to 200 km."; grow.pressed.connect(_grow_terrain); sculpt_row.add_child(grow)
	grow_ground_button = grow
	terrain_size_label = _label("", 10, MUTED); sculpt_row.add_child(terrain_size_label)
	ground_size_picker = OptionButton.new()
	ground_size_picker.tooltip_text = "Ground size, edge to edge. Up to 200 km. Choosing a size keeps every object, route and road where it is."
	for label in Terrain.size_labels():
		ground_size_picker.add_item(str(label) +" GROUND")
	ground_size_picker.item_selected.connect(_pick_ground_size)
	_field(page, "Ground size", ground_size_picker)
	var build_row := GridContainer.new(); build_row.columns = 2; page.add_child(build_row)
	var road_col := VBoxContainer.new(); road_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; build_row.add_child(road_col)
	road_col.add_child(_label("ROAD WIDTH (m)", 10, MUTED))
	road_width = _spin(2, 25, 0.5); road_width.value = 8; road_width.size_flags_horizontal = Control.SIZE_EXPAND_FILL; road_col.add_child(road_width)
	var wall_col := VBoxContainer.new(); wall_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; build_row.add_child(wall_col)
	wall_col.add_child(_label("WALL HEIGHT (m)", 10, MUTED))
	wall_height = _spin(state.WALL_MIN, state.WALL_MAX, 0.25); wall_height.value = 2; wall_height.size_flags_horizontal = Control.SIZE_EXPAND_FILL; wall_height.tooltip_text = "Height of the next wall you draw, and of the selected wall. 0.25 m to 12 m."
	wall_col.add_child(wall_height)
	road_width.value_changed.connect(_construction_changed); wall_height.value_changed.connect(_construction_changed)
	var size_row := HFlowContainer.new(); size_row.add_theme_constant_override("h_separation", 4); page.add_child(size_row)
	var smaller := _icon_button("zoom_out", "Shorter wall: change the selected wall, or the height used for the next one")
	smaller.tooltip_text = "Shorter wall. Changes the selected wall, or the height of the next wall you draw."
	smaller.pressed.connect(func (): _nudge_wall(- 0.25)); size_row.add_child(smaller)
	var taller := _icon_button("zoom_in", "Taller wall: change the selected wall, or the height used for the next one")
	taller.tooltip_text = "Taller wall. Changes the selected wall, or the height of the next wall you draw."
	taller.pressed.connect(func (): _nudge_wall(0.25)); size_row.add_child(taller)
	size_row.add_child(_label("BRICK / BLOCK SIZE", 10, MUTED))
	var brick_small := _icon_button("zoom_out", "Smaller bricks or blocks")
	brick_small.tooltip_text = "Smaller bricks. Applies to the selected wall or loose block."
	brick_small.pressed.connect(func (): _nudge_brick(- 0.1)); size_row.add_child(brick_small)
	brick_scale_box = _spin(state.BRICK_MIN, state.BRICK_MAX, 0.05); brick_scale_box.value = 1.0; brick_scale_box.step = 0.05
	brick_scale_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brick_scale_box.tooltip_text = "Brick and block size. Larger values mean bigger bricks, fewer courses and chunkier blocks."
	brick_scale_box.value_changed.connect(func (v):
		if _refreshing: return
		_apply_brick_scale(v))
	size_row.add_child(brick_scale_box)
	var brick_big := _icon_button("zoom_in", "Bigger bricks or blocks")
	brick_big.tooltip_text = "Bigger bricks. Applies to the selected wall or loose block."
	brick_big.pressed.connect(func (): _nudge_brick(0.1)); size_row.add_child(brick_big)
	page.add_child(HSeparator.new())
	page.add_child(_label("HEIGHTMAP AND REFERENCE", 11, ACCENT))
	var height_row := HFlowContainer.new(); height_row.add_theme_constant_override("h_separation", 4); page.add_child(height_row)
	var height_in := _button("IMPORT HEIGHTMAP"); height_in.tooltip_text = "16-bit grayscale PNG becomes the terrain surface."; height_in.pressed.connect(_heightmap_import_requested); height_row.add_child(height_in)
	var height_out := _button("EXPORT HEIGHTMAP"); height_out.tooltip_text = "Write the current terrain as a 16-bit PNG heightmap."; height_out.pressed.connect(_heightmap_export_requested); height_row.add_child(height_out)
	var additive := CheckBox.new(); additive.text = "Add to current ground"; additive.toggled.connect(func (v): heightmap_additive = v); page.add_child(additive)
	var ref_row := HFlowContainer.new(); ref_row.add_theme_constant_override("h_separation", 4); page.add_child(ref_row)
	var ref := _button("LOAD REF IMAGE"); ref.tooltip_text = "Show a reference picture under the editable map."; ref.pressed.connect(_underlay_requested); ref_row.add_child(ref)
	var ref_clear := _button("CLEAR REF"); ref_clear.pressed.connect(_clear_underlay); ref_row.add_child(ref_clear)
	page.add_child(_label("REFERENCE OPACITY", 10, MUTED))
	underlay_slider = HSlider.new(); underlay_slider.min_value = 0.0; underlay_slider.max_value = 1.0; underlay_slider.step = 0.05; underlay_slider.value = 0.55
	underlay_slider.value_changed.connect(func (v): if map_view != null: map_view.underlay_alpha = v; map_view.queue_redraw())
	page.add_child(underlay_slider)
	var ruler_row := HFlowContainer.new(); ruler_row.add_theme_constant_override("h_separation", 4); page.add_child(ruler_row)
	var ruler := _button("RULER MODE"); ruler.toggle_mode = true; ruler.tooltip_text = "Click two points on the map to measure the distance between them."; ruler.toggled.connect(_quick_ruler); ruler_row.add_child(ruler)
	var clear_ruler := _button("CLEAR RULER"); clear_ruler.pressed.connect(func (): if map_view != null: map_view.clear_ruler()); ruler_row.add_child(clear_ruler)

func _fill_mission_tab(page: VBoxContainer) -> void:
	page.add_child(_label("MISSION DETAILS", 11, ACCENT))
	mission_name = LineEdit.new(); mission_name.text_changed.connect(func (v): if not _refreshing: state.set_mission("name", v)); _field(page, "Mission name", mission_name)
	var clock := HBoxContainer.new(); page.add_child(_label("START TIME", 10, MUTED)); page.add_child(clock)
	hour = _spin(0, 23, 1); minute = _spin(0, 59, 1)
	hour.size_flags_horizontal = Control.SIZE_EXPAND_FILL; minute.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock.add_child(hour); clock.add_child(_label(":")); clock.add_child(minute)
	hour.value_changed.connect(func (v): if not _refreshing: state.set_mission("start_hour", int(v)))
	minute.value_changed.connect(func (v): if not _refreshing: state.set_mission("start_minute", int(v)))
	briefing = TextEdit.new(); briefing.custom_minimum_size.y = 64; briefing.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	briefing.text_changed.connect(func (): if not _refreshing: state.set_mission("briefing", briefing.text)); _field(page, "Briefing", briefing)
	objectives = TextEdit.new(); objectives.custom_minimum_size.y = 78; objectives.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	objectives.text_changed.connect(_objectives_changed); _field(page, "Objective notes (one per line)", objectives)
	recon_label = _label("RECON TARGET: none", 10, MUTED); recon_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; page.add_child(recon_label)
	var recon := _button("USE SELECTED AS RECON TARGET"); recon.tooltip_text = "For the fly-test, get within 150 metres of this object."; recon.pressed.connect(_set_recon_target); page.add_child(recon)
	page.add_child(HSeparator.new())
	page.add_child(_label("VALIDATION", 11, ACCENT))
	checklist_summary = _label("Not run yet.", 10, MUTED); checklist_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; page.add_child(checklist_summary)
	var run_checks := _button("RUN CHECKS"); run_checks.pressed.connect(_open_checklist); page.add_child(run_checks)
	checklist_list = VBoxContainer.new(); checklist_list.add_theme_constant_override("separation", 2); page.add_child(checklist_list)
	_fill_environment_section(page)

func _fill_files_tab(page: VBoxContainer) -> void:
	page.add_child(_label("AUTOSAVE", 11, ACCENT))
	autosave_status = _label("No autosave yet.", 10, MUTED); autosave_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; page.add_child(autosave_status)
	var row := HFlowContainer.new(); row.add_theme_constant_override("h_separation", 4); page.add_child(row)
	var restore := _button("RESTORE LATEST"); restore.tooltip_text = "Load the newest automatic draft."; restore.pressed.connect(_restore_latest_autosave); row.add_child(restore)
	var list := _button("REFRESH LIST"); list.pressed.connect(_refresh_autosave_list); row.add_child(list)
	autosave_list = VBoxContainer.new(); autosave_list.add_theme_constant_override("separation", 2); page.add_child(autosave_list)
	var disclaimer := _label("New scenes start empty. Exported missions use the game's simplified recon mode; existing campaign missions are unchanged.", 10, MUTED)
	disclaimer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; page.add_child(disclaimer)

func _add_flight_key(parent: Container, text: String, axis: String, value: float) -> void:
	var button := _button(text); parent.add_child(button)
	button.button_down.connect(func ():
		if scene_view != null: scene_view.external_controls[axis] = value)
	button.button_up.connect(func ():
		if scene_view != null: scene_view.external_controls.erase(axis))

func _orbit_toggled(active: bool) -> void:
	if scene_view != null: scene_view.touch_orbit = active
	_status("Orbit look on: drag in the 3D view to look around." if active else "Orbit look off: dragging pans, sculpts, paints or moves objects again.")

func _toggle_panel(which: String) -> void:
	ui_hidden = false
	if quick_hide_ui != null: quick_hide_ui.set_pressed_no_signal(false)
	if which == "library" and library_panel != null:
		library_panel.visible = not library_panel.visible
		if _compact_layout and library_panel.visible and inspector_panel != null: inspector_panel.visible = false
	elif which == "inspector" and inspector_panel != null:
		inspector_panel.visible = not inspector_panel.visible
		if _compact_layout and inspector_panel.visible and library_panel != null: library_panel.visible = false
	if library_button != null: library_button.set_pressed_no_signal(library_panel.visible)
	if inspector_button != null: inspector_button.set_pressed_no_signal(inspector_panel.visible)

func _build_folder_panel(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())
	parent.add_child(_label("SAVE FOLDERS", 15, ACCENT))
	var hint := _label("Choose one folder with the system picker. The creator makes its own sub-folders there and only deletes folders it created.", 11, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; parent.add_child(hint)
	folder_status = _label("", 12, MUTED); folder_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; parent.add_child(folder_status)
	var choose := _button("CHOOSE FOLDER"); choose.tooltip_text = "Android: system folder picker. Windows: folder browser. The creator only writes inside the folder you choose."; choose.pressed.connect(_choose_folder); parent.add_child(choose)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6); parent.add_child(row)
	folder_name_edit = LineEdit.new(); folder_name_edit.placeholder_text = "New folder name"; folder_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL; folder_name_edit.text_submitted.connect(func (_t): _create_folder_from_edit()); row.add_child(folder_name_edit)
	var create := _button("CREATE"); create.pressed.connect(_create_folder_from_edit); row.add_child(create)
	folder_list = VBoxContainer.new(); folder_list.add_theme_constant_override("separation", 4); parent.add_child(folder_list)
	save_here_button = _button("SAVE DRAFT IN FOLDER", true); save_here_button.tooltip_text = "Save the editable draft straight into the highlighted folder."; save_here_button.pressed.connect(_save_in_folder); parent.add_child(save_here_button)
	export_here_button = _button("EXPORT .RMISSION IN FOLDER"); export_here_button.tooltip_text = "Write the data-only recon mission into the highlighted folder."; export_here_button.pressed.connect(_export_in_folder); parent.add_child(export_here_button)
	var pack_row := VBoxContainer.new(); pack_row.add_theme_constant_override("separation", 6); parent.add_child(pack_row)
	export3d_button = _button("EXPORT 3D PACK"); export3d_button.tooltip_text = "Write a zip holding one scene.glb of the whole scene, a ready Godot 4 project, a Unity loader, and the object manifest in CSV and JSON. Keep the .rmission for the game itself."; export3d_button.pressed.connect(func (): _export_pack_requested()); export3d_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pack_row.add_child(export3d_button)
	exportglb_button = _button("EXPORT .GLB"); exportglb_button.tooltip_text = "Write just the whole scene as one binary glTF file for Blender, Godot, Unity (glTFast) or Unreal."; exportglb_button.pressed.connect(func (): _export_glb_requested()); exportglb_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pack_row.add_child(exportglb_button)
	_refresh_folders()

func _refresh_folders() -> void:
	if folder_status == null: return
	folder_status.text = "Location: " + folders.root_label() if folders.has_root() else "Location: none chosen yet"
	if save_here_button != null:
		save_here_button.disabled = current_folder.is_empty()
		export_here_button.disabled = current_folder.is_empty()
	if folder_list != null:
		for child in folder_list.get_children(): child.queue_free()
	if not folders.has_root() or folder_list == null: return
	var rows: Array = folders.list_folders()
	if rows.is_empty():
		var empty := _label("No creator folders yet. Type a name above and press CREATE.", 11, MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; folder_list.add_child(empty)
	else:
		for row: Dictionary in rows:
			var name := str(row.name)
			var line := HBoxContainer.new(); line.add_theme_constant_override("separation", 6); folder_list.add_child(line)
			var pick := _button(("• " + name) if name == current_folder else name)
			pick.toggle_mode = true; pick.button_pressed = name == current_folder; pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pick.alignment = HORIZONTAL_ALIGNMENT_LEFT; pick.clip_text = true
			pick.pressed.connect(_select_folder.bind(name)); line.add_child(pick)
			var remove := _button("FORGET" if not bool(row.exists) else "DELETE")
			remove.tooltip_text = "Remove this folder from the list without deleting it." if not bool(row.exists) else "Delete this creator folder and the files inside it."
			remove.pressed.connect(_request_delete_folder.bind(name)); line.add_child(remove)
	if not current_folder.is_empty() and not folders.known(current_folder): current_folder = ""
	if current_folder.is_empty() and not rows.is_empty(): current_folder = str(rows[rows.size() -1].name)
	if save_here_button != null:
		save_here_button.disabled = current_folder.is_empty()
		export_here_button.disabled = current_folder.is_empty()

func _select_folder(name: String) -> void:
	current_folder = name
	_refresh_folders()
	_status("Folder selected: " + name)

func _choose_folder() -> void:
	if folder_dialog == null: return
	folder_dialog.popup_centered_ratio(0.8 if android else 0.7)

func _folder_picked(path: String) -> void:
	if path.strip_edges().is_empty(): return
	if folders.has_root() and path.strip_edges() == folders.root:
		_refresh_folders(); return
	if android and not Platform.is_document_uri(path):
		_message("Android returned a path instead of a document folder. Please choose the folder again with the system picker.")
		return
	if not android and not DirAccess.dir_exists_absolute(path):
		_message("That folder cannot be opened.")
		return
	folders.set_root(path)
	current_folder = ""
	var persisted := true
	if android: persisted = folders.take_persistable_grant()
	_refresh_folders()
	var extra := "" if persisted else " Android may ask you to choose the folder again after the app is restarted."
	_status("Save folder set: " + folders.root_label() +"." + extra)

func _create_folder_from_edit() -> void:
	if folder_name_edit == null: return
	var result: Dictionary = folders.create_folder(folder_name_edit.text)
	if not result.ok: _message(str(result.error)); _refresh_folders(); return
	folder_name_edit.text = ""
	current_folder = str(result.name)
	_refresh_folders()
	_status("Folder created: " + str(result.name) +". Drafts and exports can be saved into it.")
	_save_here_button_state()

func _save_here_button_state() -> void:
	if save_here_button != null:
		save_here_button.disabled = current_folder.is_empty()
		export_here_button.disabled = current_folder.is_empty()

func _request_delete_folder(name: String) -> void:
	if confirm_delete == null: return
	pending_folder_delete = name
	if information != null: information.hide()
	confirm_delete.dialog_text = "Delete the creator folder \"" + name + "\" and every draft or mission inside it?\n\nThis cannot be undone."
	confirm_delete.popup_centered(Vector2i(520, 220))
	_status("Delete requested for " + name + ".")

func _delete_folder_confirmed() -> void:
	var name := pending_folder_delete; pending_folder_delete = ""
	if name.is_empty(): return
	if confirm_delete != null: confirm_delete.hide()
	if not folders.known(name):
		var forget: Dictionary = folders.forget_folder(name)
		_refresh_folders(); _status("Removed from the list: " + name + "." if forget.ok else str(forget.error)); return
	var result: Dictionary = folders.delete_folder(name)
	if not result.ok:
		_refresh_folders(); _message(str(result.error)); return
	if current_folder == name: current_folder = ""
	_refresh_folders(); _status("Deleted creator folder: " + name + ".")

func _save_in_folder() -> void:
	if current_folder.is_empty(): _message("Choose or create a folder first."); return
	var target: String = folders.document_path(current_folder, "Untitled_Mission.rmdraft")
	_save_to(target)

func _export_in_folder() -> void:
	if current_folder.is_empty(): _message("Choose or create a folder first."); return
	var target: String = folders.document_path(current_folder, "Custom_Mission.rmission")
	_export_mission_to(target)

func _apply_android_dialog_defaults() -> void:




	for dialog in [add_dialog, animation_dialog, texture_dialog, convert_dialog, convert_save_dialog, save_dialog, export_dialog, open_dialog, heightmap_dialog, heightmap_save_dialog, underlay_dialog]:
		if dialog == null: continue
		dialog.use_native_dialog = true
		dialog.filters = PackedStringArray()
		dialog.add_filter("*.*", "All files")



func _apply_dialog_titles() -> void:
	var titles := {
		add_dialog: "Import trusted GLB or FBX model",
		animation_dialog: "Import a trusted FBX or GLB animation",
		texture_dialog: "Import a trusted PNG or JPEG texture",
		convert_dialog: "Select a trusted FBX to convert",
		convert_save_dialog: "Save converted GLB",
		save_dialog: "Save editor draft (not game playable)",
		export_dialog: "Export data-only custom recon mission",
		glb_dialog: "Export the scene as one GLB",
		pack_dialog: "Export a 3D pack (Godot + Unity + manifest)",
		open_dialog: "Open mission creator draft",
		folder_dialog: "Choose the folder the creator may save into",
		heightmap_dialog: "Import 16-bit heightmap",
		heightmap_save_dialog: "Export terrain heightmap",
		underlay_dialog: "Reference image for the map"
	}
	for key in titles.keys():
		if key != null: key.title = str(titles[key])

func _make_dialogs() -> void:
	add_dialog = FileDialog.new(); add_dialog.title = "Import trusted GLB or FBX model"; add_dialog.access = FileDialog.ACCESS_FILESYSTEM; add_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE; add_dialog.add_filter("*.glb,*.glb.png,*.gltf,*.gltf.png,*.zip,*.fbx,*.fbx.png", "3D model (GLB, glTF, zip, FBX)")
	add_dialog.add_filter("*.glb,*.gltf", "glTF models")
	add_dialog.add_filter("*.*", "All files"); add_child(add_dialog); add_dialog.file_selected.connect(_import_model)
	animation_dialog = FileDialog.new(); animation_dialog.title = "Import a trusted FBX or GLB animation"; animation_dialog.access = FileDialog.ACCESS_FILESYSTEM; animation_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE; animation_dialog.add_filter("*.glb,*.glb.png,*.gltf,*.zip,*.fbx,*.fbx.png", "3D animation (GLB, glTF, zip, FBX)"); add_child(animation_dialog); animation_dialog.file_selected.connect(_import_animation)
	texture_dialog = FileDialog.new(); texture_dialog.title = "Import a trusted PNG or JPEG texture"; texture_dialog.access = FileDialog.ACCESS_FILESYSTEM; texture_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE; texture_dialog.add_filter("*.png,*.jpg,*.jpeg", "Texture image"); add_child(texture_dialog); texture_dialog.file_selected.connect(_import_texture)
	convert_dialog = FileDialog.new(); convert_dialog.title = "Select a trusted FBX to convert"; convert_dialog.access = FileDialog.ACCESS_FILESYSTEM; convert_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE; convert_dialog.add_filter("*.fbx,*.fbx.png", "FBX file"); add_child(convert_dialog); convert_dialog.file_selected.connect(_convert_fbx)
	convert_save_dialog = FileDialog.new(); convert_save_dialog.title = "Save converted GLB"; convert_save_dialog.access = FileDialog.ACCESS_FILESYSTEM; convert_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE; convert_save_dialog.add_filter("*.glb", "GLB model or animation"); add_child(convert_save_dialog); convert_save_dialog.file_selected.connect(_save_converted_glb)
	save_dialog = FileDialog.new(); save_dialog.title = "Save editor draft (not game playable)"; save_dialog.access = FileDialog.ACCESS_FILESYSTEM; save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE; save_dialog.add_filter("*.rmdraft", "Mission creator draft"); save_dialog.current_file = "Untitled_Mission.rmdraft"; add_child(save_dialog); save_dialog.file_selected.connect(_save_to)
	export_dialog = FileDialog.new(); export_dialog.title = "Export data-only custom recon mission"; export_dialog.access = FileDialog.ACCESS_FILESYSTEM; export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE; export_dialog.add_filter("*.rmission", "REAPER custom mission"); export_dialog.current_file = "Custom_Mission.rmission"; add_child(export_dialog); export_dialog.file_selected.connect(_export_mission_to)
	glb_dialog = FileDialog.new(); glb_dialog.title = "Export the scene as one GLB"; glb_dialog.access = FileDialog.ACCESS_FILESYSTEM; glb_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE; glb_dialog.add_filter("*.glb", "Binary glTF scene"); glb_dialog.current_file = "REAPER_Scene.glb"; add_child(glb_dialog); glb_dialog.file_selected.connect(_export_glb_to)
	pack_dialog = FileDialog.new(); pack_dialog.title = "Export a 3D pack (Godot + Unity + manifest)"; pack_dialog.access = FileDialog.ACCESS_FILESYSTEM; pack_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE; pack_dialog.add_filter("*.zip", "3D export archive"); pack_dialog.current_file = "REAPER_3D_Export.zip"; add_child(pack_dialog); pack_dialog.file_selected.connect(_export_pack_to)
	open_dialog = FileDialog.new(); open_dialog.title = "Open mission creator draft"; open_dialog.access = FileDialog.ACCESS_FILESYSTEM; open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE; open_dialog.add_filter("*.rmdraft", "Mission creator draft"); add_child(open_dialog); open_dialog.file_selected.connect(_open_from)
	folder_dialog = FileDialog.new(); folder_dialog.title = "Choose the folder the creator may save into"; folder_dialog.access = FileDialog.ACCESS_FILESYSTEM; folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	folder_dialog.use_native_dialog = true if android else folder_dialog.use_native_dialog
	add_child(folder_dialog)
	folder_dialog.dir_selected.connect(_folder_picked)
	folder_dialog.file_selected.connect(_folder_picked)
	confirm_delete = ConfirmationDialog.new(); confirm_delete.title = "Delete creator folder"; add_child(confirm_delete); confirm_delete.confirmed.connect(_delete_folder_confirmed)
	confirm = ConfirmationDialog.new(); confirm.title = "Unsaved changes"; confirm.dialog_text = "Discard unsaved changes?"; add_child(confirm); confirm.confirmed.connect(_run_pending)
	information = AcceptDialog.new(); information.title = "Mission Creator"; add_child(information)

func _status(message: String) -> void:
	if status == null: return
	# The workspace reserves one line for status. Long dialog messages must not
	# expand the footer and steal height from the viewport. Keep details in the
	# dialog and tooltip; show only the first line in the footer.
	status.text = message.replace("\r", "").get_slice("\n", 0).strip_edges()
	status.tooltip_text = message
func _message(message: String) -> void:
	information.dialog_text = message; information.popup_centered(Vector2i(520, 190)); _status(message)
func _state_changed(reason: String) -> void:
	if reason in ["selection", "objects", "pose", "properties", "mission", "terrain", "reset", "loaded", "flags", "history"]: _refresh_inspector()
	if reason in ["environment", "reset", "loaded"]:
		_refresh_environment()
		if scene_view != null: scene_view.apply_weather()
	if reason in ["snow", "paint"] and scene_view != null: scene_view.refresh_terrain_texture()
	if reason == "loaded" or reason == "reset":
		animation_cache.clear(); paint_texture_id = ""
		if scene_view != null: scene_view.paint_texture_id = ""
		if map_view != null: map_view.paint_texture_id = ""
		_refresh_library(); _refresh_inspector()
	_record_history(reason)
	if reason in ["objects", "flags", "history", "loaded", "reset"]:
		selection.prune(state)
		if not _restoring and not state.selected_id.is_empty() and not selection.has(state.selected_id): selection.keep_only(state.selected_id)
		_sync_multi_selection()
	if reason in ["objects", "flags", "history", "loaded", "reset", "selection"]: _refresh_scene_tree()
	_refresh_history_buttons(); _refresh_issues_button(); _refresh_sun_controls(); _refresh_crumb()

func _begin_group() -> void:
	_group_active = true; _group_pushed = false

func _end_group() -> void:
	_group_active = false; _group_pushed = false

func _record_history(reason: String) -> void:
	if _restoring or reason == "history": _last_doc = state.data.duplicate(true); _last_selected = state.selected_id; return
	if _group_active:
		if _group_pushed: _last_doc = state.data.duplicate(true); _last_selected = state.selected_id; return
		_group_pushed = true
	if not HISTORY_LABELS.has(reason) or _last_doc.is_empty():
		_last_doc = state.data.duplicate(true); _last_selected = state.selected_id; return
	if _last_doc == state.data: return
	var merge := reason in ["pose", "properties", "mission", "terrain", "paint"]
	history.push_document(_last_doc, _last_selected, str(HISTORY_LABELS[reason]), merge)
	_last_doc = state.data.duplicate(true); _last_selected = state.selected_id

func _refresh_crumb() -> void:
	if crumb_label == null: return
	var name_ := str(state.data.get("name", "Untitled mission"))
	var marked := "Draft · not saved" if current_path.is_empty() else current_path.get_file()
	if state.dirty: marked += " · modified"
	crumb_label.text = "%s  ›  %s" % [name_, marked]
	if not android and get_window() != null: get_window().title = Version.window_title()

func _refresh_sun_controls() -> void:
	var hours := float(state.data.get("start_hour", 10)) +float(state.data.get("start_minute", 0)) / 60.0
	if sun_slider != null and not sun_slider.has_focus(): sun_slider.set_value_no_signal(hours)
	if sun_label != null: sun_label.text = "%02d:%02d" % [int(floor(hours)), int(round((hours - floor(hours)) * 60.0)) % 60]
	if terrain_radius != null and brush_radius_slider != null: brush_radius_slider.set_value_no_signal(terrain_radius.value)
	if terrain_strength != null and brush_strength_slider != null: brush_strength_slider.set_value_no_signal(terrain_strength.value)
	if hierarchy_count_label != null: hierarchy_count_label.text = "%d objects" % Array(state.data.get("objects", [])).size()

func _refresh_library() -> void:
	_refresh_library_filtered()

func _scene_tree_selected() -> void:
	if _refreshing or scene_tree == null: return
	var item := scene_tree.get_selected()
	if item == null: return
	var id := str(item.get_metadata(0))
	if id.is_empty(): return
	if multi_select_mode:
		selection.toggle(id)
		if selection.ids.is_empty(): selection.add(id)
		state.select(str(selection.ids[selection.ids.size() -1]))
		_sync_multi_selection()
		_status("%d object(s) selected." % selection.count())
	else:
		selection.keep_only(id)
		state.select(id)
		_sync_multi_selection()
func _scene_tree_activated() -> void:
	var item := scene_tree.get_selected()
	if item == null or str(item.get_metadata(0)).is_empty(): return
	_scene_tree_selected()
	if not state.selected_id.is_empty(): scene_view.focus_selected()
func _refresh_scene_tree() -> void:
	if scene_tree == null: return
	var parts := PackedStringArray()
	for row: Dictionary in state.data.get("objects", []): parts.append("%s|%s|%s" % [row.id, row.asset, row.name])
	var signature := "\n".join(parts)
	if signature != _scene_tree_signature or scene_tree.get_root() == null:
		var collapsed := {}
		for key in _scene_tree_groups:
			var old: TreeItem = _scene_tree_groups[key]
			if is_instance_valid(old): collapsed[key] = old.collapsed
		scene_tree.clear(); _scene_tree_items.clear(); _scene_tree_groups.clear(); _scene_tree_signature = signature
		var root := scene_tree.create_item(); root.set_text(0, "Terrain / scene (%d objects)" % state.data.get("objects", []).size()); root.set_metadata(0, ""); root.collapsed = false
		for row: Dictionary in state.data.get("objects", []):
			var asset := str(row.asset)
			if not _scene_tree_groups.has(asset):
				var group := scene_tree.create_item(root)
				var title := "Road" if asset == "road_path" else ("Brick wall" if asset == "brick_wall" else library.label_for(asset, state.custom_assets))
				group.set_text(0, title); group.set_metadata(0, ""); group.collapsed = bool(collapsed.get(asset, false)); _scene_tree_groups[asset] = group
			var item := scene_tree.create_item(_scene_tree_groups[asset]); item.set_text(0, str(row.name)); item.set_metadata(0, str(row.id)); item.set_tooltip_text(0, "Select " + str(row.name) +" • double-click to focus")
			_scene_tree_items[str(row.id)] = item
	if _scene_tree_items.has(state.selected_id):
		var selected: TreeItem = _scene_tree_items[state.selected_id]
		if scene_tree.get_selected() != selected:
			selected.get_parent().collapsed = false; selected.select(0); scene_tree.scroll_to_item(selected)
	else:
		var selected := scene_tree.get_selected()
		if selected != null and not str(selected.get_metadata(0)).is_empty(): scene_tree.deselect_all()
func _preset_icon(preset: Dictionary) -> Texture2D:
	var id := str(preset.id)
	if _preset_icons.has(id): return _preset_icons[id]
	var image := Image.new(); var bytes := TerrainPresets.read(preset)
	if bytes.is_empty() or image.load_jpg_from_buffer(bytes) != OK: return null
	image.resize(20, 20, Image.INTERPOLATE_BILINEAR)
	var icon := ImageTexture.create_from_image(image); _preset_icons[id] = icon; return icon
func _fill_texture_options(option: OptionButton, chosen: String, include_presets := true, empty_label := "None / original") -> void:
	option.clear(); option.add_item(empty_label); option.set_item_metadata(0, "")
	var selected := 0; var builtin_ids := {}
	for preset: Dictionary in TerrainPresets.PRESETS:
		builtin_ids[str(preset.id)] = true
		if include_presets:
			option.add_icon_item(_preset_icon(preset), str(preset.name)); var index := option.item_count - 1; option.set_item_metadata(index, str(preset.id))
			if str(preset.id) == chosen: selected = index
	var keys: Array = state.custom_assets.keys(); keys.sort()
	for key in keys:
		if str(state.custom_assets[key].get("category", "model")) != "texture" or (include_presets and builtin_ids.has(str(key))): continue
		option.add_item(str(state.custom_assets[key].get("name", "Texture"))); var i := option.item_count - 1; option.set_item_metadata(i, key)
		if str(key) == chosen: selected = i
	option.select(selected)
func _ensure_texture_asset(id: String) -> bool:
	if id.is_empty(): return true
	if state.custom_assets.has(id): return str(state.custom_assets[id].get("category", "")) == "texture"
	var preset: Dictionary = TerrainPresets.find(id)
	if preset.is_empty(): _message("The selected texture is unavailable."); return false
	if state.custom_assets.size() >= Store.MAX_ASSETS: _message("A draft can hold up to 24 embedded assets. This built-in texture needs one asset slot."); return false
	var bytes := TerrainPresets.read(preset)
	if bytes.is_empty() or "tex_" + Codec.sha256(bytes) != id or not TextureCodec.validate(bytes).ok: _message("The built-in terrain texture is missing or damaged."); return false
	if not _asset_fits(id, bytes): _message("Combined embedded assets would exceed the %d MiB draft budget." % int((Store.MAX_FILE - Store.MAX_META - 12) / 1048576)); return false


	state.custom_assets[id] = { "name": str(preset.name), "bytes": bytes, "category": "texture"}; state.dirty = true
	return true
func _animation_clips_for(row: Dictionary, source: String) -> PackedStringArray:
	if row.is_empty() or source.is_empty(): return PackedStringArray()
	var key := str(row.get("asset", "")) +"/embedded" if source == "embedded" else source
	if animation_cache.has(key): return animation_cache[key]
	var clips := PackedStringArray()
	if source == "embedded":
		var visual: Node3D = library.create_visual(str(row.asset), state.custom_assets); clips = AnimationSupport.clips_from_node(visual); visual.free()
	elif state.custom_assets.has(source): clips = AnimationSupport.clips_from_bytes(state.custom_assets[source].get("bytes", PackedByteArray()))
	animation_cache[key] = clips; return clips


func _target_construction() -> Dictionary:
	if state == null or state.selected_id.is_empty(): return {}
	var row: Dictionary = state.find_object(state.selected_id)
	if row.is_empty(): return {}
	return row if str(row.get("asset", "")) in ["brick_wall", "brick_block"] else {}

func _nudge_wall(delta: float) -> void:
	var row = _target_construction()
	if row.is_empty():
		wall_height.value = clampf(wall_height.value + delta, state.WALL_MIN, state.WALL_MAX)
		_construction_changed(wall_height.value)
		_status("Next wall will be %s m tall." % str(snappedf(wall_height.value, 0.25)))
		return
	var value := state.nudge_size(str(row.id), "wall_height", delta)
	scene_view.wall_height = value
	_status("Wall height %s m." % str(snappedf(value, 0.25)))

func _apply_brick_scale(value: float) -> void:
	var row = _target_construction()
	if row.is_empty():
		_status("Brick size %.2f× will be used for the next wall or block." % value)
		return
	state.set_value(str(row.id), "brick_scale", value)
	_refresh_inspector()
	_status("Brick size %.2f×." % value)

func _nudge_brick(delta: float) -> void:
	var row = _target_construction()
	var current := brick_scale_box.value if brick_scale_box != null else 1.0
	if not row.is_empty(): current = float(row.get("brick_scale", 1.0))
	var value := clampf(snappedf(current + delta, 0.05), state.BRICK_MIN, state.BRICK_MAX)
	if brick_scale_box != null: brick_scale_box.set_value_no_signal(value)
	_apply_brick_scale(value)

func _refresh_inspector() -> void:
	_refresh_crumb(); _refresh_sun_controls()
	if mission_name == null: return
	_refreshing = true
	if not mission_name.has_focus(): mission_name.text = str(state.data.get("name", ""))
	hour.set_value_no_signal(int(state.data.get("start_hour", 6))); minute.set_value_no_signal(int(state.data.get("start_minute", 0)))
	if not briefing.has_focus(): briefing.text = str(state.data.get("briefing", ""))
	if not objectives.has_focus(): objectives.text = "\n".join(state.data.get("objectives", []))
	_fill_texture_options(terrain_texture, str(state.data.get("terrain_texture", "")), true, "Desert (original)"); _fill_texture_options(paint_texture, paint_texture_id, true, "Choose a paint texture"); terrain_tile.set_value_no_signal(float(state.data.get("terrain_tile_m", 80)))
	_refresh_scene_tree()
	_refresh_terrain_size_label()
	var target_row: Dictionary = state.find_object(str(state.data.get("recon_target", ""))); recon_label.text = "RECON TARGET: " + str(target_row.get("name", "none"))
	var row: Dictionary = state.find_object(state.selected_id); var active := not row.is_empty(); var path := active and str(row.get("asset", "")) in ["road_path", "brick_wall"]
	if object_empty_state != null: object_empty_state.visible = not active
	if object_detail_container != null: object_detail_container.visible = active
	object_title.text = "SELECTED: " + str(row.get("name", "")) if active else "SELECT AN OBJECT"
	for c in [obj_name, pos_x, pos_z, height, yaw, pitch, roll, scale_box, speed, animation_speed, anim_displacement_spin, anim_range_spin]: c.editable = active
	if path:
		for c in [height, yaw, pitch, roll, scale_box, speed, animation_speed, anim_displacement_spin, anim_range_spin]: c.editable = false
	var own := bool(row.get("animation_own", false)) if active else false
	faction.disabled = not active; route_face.disabled = not active or path; object_texture.disabled = not active; animation_source.disabled = not active or path or own; animation_clip.disabled = not active or path; animation_loop.disabled = not active or path or own
	animation_own.disabled = not active or path
	animation_own.set_pressed_no_signal(own)
	pos_x.min_value = -state.extent(); pos_x.max_value = state.extent(); pos_z.min_value = -state.extent(); pos_z.max_value = state.extent()
	_fill_texture_options(object_texture, str(row.get("texture", "")) if active else "", false, "From model")
	animation_source.clear(); animation_source.add_item("None"); animation_source.set_item_metadata(0, ""); animation_source.add_item("Embedded in model"); animation_source.set_item_metadata(1, "embedded")
	var selected_source := str(row.get("animation_source", "")) if active else ""; var source_index := 1 if selected_source == "embedded" else 0
	var keys: Array = state.custom_assets.keys(); keys.sort()
	for key in keys:
		if str(state.custom_assets[key].get("category", "model")) != "animation": continue
		animation_source.add_item(str(state.custom_assets[key].get("name", "Animation"))); var i := animation_source.item_count - 1; animation_source.set_item_metadata(i, key)
		if str(key) == selected_source: source_index = i
	animation_source.select(source_index)
	animation_clip.clear(); animation_clip.add_item("None"); animation_clip.set_item_metadata(0, "")
	var selected_clip := str(row.get("animation_clip", "")) if active else ""; var clip_index := 0
	if active:
		for clip in _animation_clips_for(row, "embedded" if own else selected_source):
			animation_clip.add_item(clip); var i := animation_clip.item_count - 1; animation_clip.set_item_metadata(i, clip)
			if str(clip) == selected_clip: clip_index = i
	animation_clip.select(clip_index)
	if active:
		if not obj_name.has_focus(): obj_name.text = str(row.name)
		pos_x.set_value_no_signal(float(row.x)); pos_z.set_value_no_signal(float(row.z)); height.set_value_no_signal(float(row.height)); yaw.set_value_no_signal(float(row.yaw_deg)); pitch.set_value_no_signal(float(row.get("pitch_deg", 0))); roll.set_value_no_signal(float(row.get("roll_deg", 0))); scale_box.set_value_no_signal(float(row.scale)); speed.set_value_no_signal(float(row.speed_mps)); route_face.set_pressed_no_signal(bool(row.get("route_face", true))); animation_loop.set_pressed_no_signal(bool(row.get("animation_loop", true))); animation_speed.set_value_no_signal(float(row.get("animation_speed", 1))); anim_displacement_spin.set_value_no_signal(float(row.get("animation_displacement", 0.0))); anim_range_spin.set_value_no_signal(float(row.get("animation_range", 12.0)))
		for i in faction.item_count:
			if faction.get_item_text(i) == str(row.faction): faction.select(i); break
		var result: Dictionary = scene_view.animation_results.get(str(row.id), {})
		if own and not result.is_empty() and bool(result.get("ok", false)):
			animation_status.text = "Own animation playing: %s (%s tracks, %s). Its own timing and looping are kept." % [str(result.get("clip", "")), int(result.get("tracks", 0)), "looping" if bool(result.get("looping", false)) else "one-shot"]
		elif not result.is_empty(): animation_status.text = ("Animation ready: %s tracks. Press PLAY ROUTES / ANIMATIONS." % result.get("matched_tracks", 0)) if result.get("ok", false) else str(result.get("error", "Animation could not be applied."))
		elif selected_source.is_empty(): animation_status.text = "Choose an embedded clip or import an FBX/GLB animation."
		else: animation_status.text = "Choose a clip. Separate animations require compatible named skeletons."
	else: obj_name.text = ""; animation_status.text = "Select a model and an animation."
	_refreshing = false
func _terrain_texture_selected(index: int) -> void:
	if _refreshing: return
	var id := str(terrain_texture.get_item_metadata(index))
	if not _ensure_texture_asset(id): _refresh_inspector(); return
	state.set_mission("terrain_texture", id)
	var preset: Dictionary = TerrainPresets.find(id)
	if preset.has("tile_m"): state.set_mission("terrain_tile_m", float(preset.tile_m))
func _paint_texture_selected(index: int) -> void:
	if _refreshing: return
	var id := str(paint_texture.get_item_metadata(index))
	if not _ensure_texture_asset(id): _refresh_inspector(); return
	paint_texture_id = id
	if scene_view != null: scene_view.paint_texture_id = paint_texture_id
	if map_view != null: map_view.paint_texture_id = paint_texture_id
func _object_texture_selected(index: int) -> void:
	if not _refreshing: state.set_value(state.selected_id, "texture", str(object_texture.get_item_metadata(index)))
func _animation_source_selected(index: int) -> void:
	if _refreshing: return
	var row: Dictionary = state.find_object(state.selected_id)
	if row.is_empty(): return
	var source := str(animation_source.get_item_metadata(index)); var clips := _animation_clips_for(row, source)
	row["animation_source"] = source; row["animation_clip"] = str(clips[0]) if not clips.is_empty() else ""; state.dirty = true; state.changed.emit("properties")
func _animation_clip_selected(index: int) -> void:
	if not _refreshing: state.set_value(state.selected_id, "animation_clip", str(animation_clip.get_item_metadata(index)))
func _flip_facing() -> void:
	var row: Dictionary = state.find_object(state.selected_id)
	if row.is_empty() or str(row.get("asset", "")) in ["road_path", "brick_wall"]: return
	var value := wrapf(float(row.yaw_deg) +180.0, -180.0, 180.0); state.set_value(state.selected_id, "yaw_deg", value)
func _change_position(x: float, z: float) -> void:
	if not state.selected_id.is_empty(): state.set_position(state.selected_id, Vector2(x, z))
func _set_recon_target() -> void:
	var row: Dictionary = state.find_object(state.selected_id)
	if row.is_empty() or preload("res://scripts/terrain_model.gd").is_feature(str(row.get("asset", ""))) or str(row.get("asset", "")) == "drone_start":
		_message("Select a placed vehicle, building or person first, then set it as the recon target."); return
	state.set_mission("recon_target", str(row.id)); _status("Recon target set: " + str(row.name))
func _objectives_changed() -> void:
	if _refreshing: return
	var values: Array = []
	for line in objectives.text.split("\n"):
		var clean := line.strip_edges()
		if not clean.is_empty(): values.append(clean)
	state.set_mission("objectives", values)
func _place_at_center(id: String) -> void: _place_asset(id, Vector2.ZERO)
func _place_asset(id: String, pos: Vector2) -> void:
	if scene_view.busy(): _status(BUSY_TEXT); return
	if not library.known(id, state.custom_assets): _message("Unknown asset; choose an item from the library."); return
	var name_: String = library.label_for(id, state.custom_assets)
	if snap_enabled: pos = Vector2(Selection.snap_value(pos.x, 5.0), Selection.snap_value(pos.y, 5.0))
	var made: String = state.add_object(id, pos, name_ + " %02d" % (state.data.objects.size() +1))
	if made.is_empty(): _status("Could not place that asset."); return
	selection.keep_only(made)
	library_index.note_used(id); library_index.save_state()
	_sync_multi_selection()
	_refresh_library()
	_status("Placed %s. Drag it in either view or adjust its properties." % name_)
func _terrain_mode_changed(index: int) -> void:
	var tools := ["select", "raise", "lower", "smooth", "flatten", "road", "wall", "paint", "erase_paint", "snow"]; var mode: String = tools[clampi(index, 0, tools.size() -1)]
	state.finish_paint_stroke()
	if scene_view != null: scene_view._painting = false
	if map_view != null: map_view.painting = false
	if mode != "select" and route_button != null: route_button.button_pressed = false
	if scene_view != null: scene_view.terrain_tool = mode
	if map_view != null: map_view.terrain_tool = mode; map_view.queue_redraw()
	_shelf_buttons_set(clampi(index, 0, 9))
	_refresh_brush_label()
	if mode == "paint": _status("Choose PAINT BRUSH TEXTURE in Terrain, then drag across terrain in either view.")
	elif mode == "erase_paint": _status("Drag to erase paint back to the whole-ground texture. Undo Paint restores a stroke.")
	elif mode == "snow": _status("Drag on the ground to paint snow. UNDO SNOW or CLEAR SNOW in the terrain tab removes it.")
	else: _status("Drag on ground in either view to use: " + mode + "." if mode != "select" else "Select objects in 3D, the map or the right-hand scene hierarchy.")
func _terrain_brush_changed(_value: float) -> void:
	if scene_view == null or map_view == null: return
	var radius := brush_radius_slider.value if brush_radius_slider != null else (terrain_radius.value if terrain_radius != null else 90.0)
	var strength := brush_strength_slider.value if brush_strength_slider != null else (terrain_strength.value if terrain_strength != null else 8.0)
	scene_view.brush_radius = radius; map_view.brush_radius = radius
	scene_view.brush_strength = strength; map_view.brush_strength = strength
func _construction_changed(_value: float) -> void:
	if scene_view == null or map_view == null: return
	scene_view.road_width = road_width.value; map_view.road_width = road_width.value; scene_view.wall_height = wall_height.value; map_view.wall_height = wall_height.value
func _undo_paint() -> void:
	if scene_view.busy(): _status(BUSY_TEXT); return
	_status("Undid the last texture-paint stroke." if state.undo_paint_stroke() else "There is no texture-paint stroke to undo.")
func _remove_paint_layer() -> void:
	if scene_view.busy(): _status(BUSY_TEXT); return
	_status("Removed the selected brush layer; Undo Paint restores it." if state.remove_terrain_paint_layer(paint_texture_id) else "Choose a brush texture that has been painted first.")
func _clear_paint() -> void:
	if scene_view.busy(): _status(BUSY_TEXT); return
	_status("Cleared painted layers; Undo Paint restores them." if state.clear_terrain_paint() else "There is no terrain paint to clear.")
func _grow_terrain() -> void:
	if scene_view.busy(): _status(BUSY_TEXT); return
	if state.grow_terrain():
		_after_ground_resize()
		_status("Ground is now %s across. Existing ground and objects were not stretched." % _ground_size_text())
	else: _status("Ground is already at the 200 km maximum.")


func _pick_ground_size(index: int) -> void:
	if scene_view.busy(): _status(BUSY_TEXT); return
	if index < 0 or index >= Terrain.SIZE_STEPS.size(): return
	var target := float(Terrain.SIZE_STEPS[index].extent)
	if state.set_terrain_size(target):
		_after_ground_resize()
		_status("Ground is now %s across." % _ground_size_text())
	else:
		_sync_ground_size_picker()
		_status("Ground is already %s across." % _ground_size_text())

func _ground_size_text() -> String:
	var km := state.extent() * 2.0 / 1000.0
	return ("%.1f km" % km) if km < 10.0 else ("%d km" % int(round(km)))



func _after_ground_resize() -> void:
	if scene_view != null: scene_view.apply_ground_size()
	if map_view != null: map_view.queue_redraw()
	_sync_ground_size_picker()
	_sync_brush_range()
	if pos_x != null and pos_z != null:
		var step_pos := maxf(1.0, state.extent() / 1000.0)
		for spin in [pos_x, pos_z]:
			spin.min_value = -state.extent(); spin.max_value = state.extent(); spin.step = step_pos
	_refresh_terrain_size_label()

func _sync_ground_size_picker() -> void:
	if ground_size_picker == null: return
	var index := Terrain.step_index(state.extent())
	ground_size_picker.select(index)
	if grow_ground_button != null:
		grow_ground_button.disabled = state.grow_left() <= 0
		grow_ground_button.tooltip_text = "Add flat ground around the edges. Steps up to 200 km." if state.grow_left() > 0 else "Ground is at the 200 km maximum."


func _sync_brush_range() -> void:
	if brush_radius_slider == null: return
	var cell := Terrain.cell_size(state.data.get("terrain", {}))
	var top := maxf(500.0, cell * 8.0)
	brush_radius_slider.max_value = top
	if terrain_radius != null: terrain_radius.max_value = top
	if brush_radius_slider.value > top: brush_radius_slider.set_value_no_signal(top)

func _refresh_terrain_size_label() -> void:
	if terrain_size_label == null: return
	terrain_size_label.text = "%s across%s" % [_ground_size_text(), "" if state.grow_left() > 0 else " (maximum)"]
func _route_toggled(active: bool) -> void:
	if active and terrain_mode != null: terrain_mode.select(0); _terrain_mode_changed(0)
	map_view.route_mode = active; map_view.queue_redraw(); scene_view.route_mode = active
	_status("Click for waypoints or drag to draw a route; use REVERSE ROUTE or model facing to change direction." if active else "Route drawing off.")
func _flight_toggled(active: bool) -> void:
	if active:
		if route_button != null: route_button.button_pressed = false
		if play_button != null: play_button.button_pressed = false
		terrain_mode.select(0); _terrain_mode_changed(0); terrain_mode.disabled = true
		scene_view.start_flight_test(); flight_button.text = "Stop"; flight_info.visible = true
		if flight_pad != null: flight_pad.visible = true
		_status("Simplified recon flight test. Exported missions require the updated game.")
	else:
		scene_view.stop_flight_test(); terrain_mode.disabled = false; flight_button.text = "Flight"; flight_info.visible = false
		if flight_pad != null: flight_pad.visible = false; scene_view.external_controls.clear()
		_status("Flight test ended. The saved scene was not changed.")
func _preview_toggled(active: bool) -> void:
	if scene_view.busy(): return
	scene_view.set_route_preview(active); play_button.text = "Stop" if active else "Preview"
	_status("Previewing routes and selected animation clips; this is not full game AI." if active else "Preview stopped; objects returned to their saved positions.")
func _toggle_map() -> void:
	if map_view == null: return
	if not map_view.visible:
		map_view.visible = true
		if map_visibility_button != null: map_visibility_button.set_pressed_no_signal(true)
	map_expanded = not map_expanded
	if map_expanded:
		map_view.anchor_left = 0; map_view.anchor_top = 0; map_view.anchor_right = 1; map_view.anchor_bottom = 1
		map_view.offset_left = 12; map_view.offset_right = -12; map_view.offset_top = 12; map_view.offset_bottom = -12
		map_button.text = "Map −"
	else:
		map_view.anchor_left = 1; map_view.anchor_top = 0; map_view.anchor_right = 1; map_view.anchor_bottom = 0
		map_button.text = "Map +"
		_layout_map()
	map_view.queue_redraw()

func _layout_map() -> void:
	if map_view == null or view_frame == null or map_expanded: return
	var w := clampf(view_frame.size.x * 0.34, 155.0, 320.0)
	var h := clampf(w * 0.67, 105.0, 218.0)
	map_view.offset_left = -w - 10.0
	map_view.offset_right = -10.0
	map_view.offset_top = 10.0
	map_view.offset_bottom = h + 10.0

func _toggle_map_visibility() -> void:
	if map_view == null: return
	map_view.visible = not map_view.visible
	if map_visibility_button != null:
		map_visibility_button.text = "Map"
		map_visibility_button.set_pressed_no_signal(map_view.visible)
	_status("Editable map shown." if map_view.visible else "Editable map hidden; use SHOW MAP to restore it.")
func _files_dropped(paths: PackedStringArray) -> void:
	for path in paths:
		var lower := path.to_lower()
		if lower.ends_with(".glb") or lower.ends_with(".glb.png") or lower.ends_with(".fbx") or lower.ends_with(".fbx.png") or lower.ends_with(".gltf") or lower.ends_with(".gltf.png") or lower.ends_with(".zip"): _import_model(path)
		elif lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg"): _import_texture(path)
		else: _status("Choose a GLB/FBX model or PNG/JPEG texture. Use the animation import button for a separate clip.")
func _read_bounded(path: String, max_bytes: int) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return { "ok": false, "error": "Could not open the selected file."}
	if file.get_length() > max_bytes: return { "ok": false, "error": "Selected file is larger than the supported limit."}
	return { "ok": true, "bytes": file.get_buffer(file.get_length())}
func _display_name(path: String) -> String:
	var name_ := Platform.display_label(path)
	if name_.to_lower().ends_with(".glb.png") or name_.to_lower().ends_with(".fbx.png"): name_ = name_.left(-4)
	var label := name_.get_basename().strip_edges().substr(0, 90)
	return "Imported asset" if label.is_empty() else label
func _asset_fits(id: String, bytes: PackedByteArray) -> bool:
	var total := bytes.size()
	for key in state.custom_assets:
		if str(key) != id: total += state.custom_assets[key].get("bytes", PackedByteArray()).size()
	return total <= Store.MAX_FILE - Store.MAX_META - 12
func _import_model(path: String) -> void: _import_asset(path, "model")
func _import_glb(path: String) -> void: _import_model(path)
func _import_animation(path: String) -> void: _import_asset(path, "animation")
func _explain(result: Dictionary) -> String:
	var text := str(result.get("error", "Import failed."))
	var hint := str(result.get("hint", ""))
	return text + ("\n\n" + hint if not hint.is_empty() else "")
func _import_asset(path: String, category: String) -> void:
	if state.custom_assets.size() >= 24: _message("A draft can hold up to 24 imported assets."); return
	var bytes := PackedByteArray(); var notes: Array = []; var lower := path.to_lower()
	if lower.ends_with(".fbx") or lower.ends_with(".fbx.png"):
		var raw := _read_bounded(path, Fbx.MAX_FBX_BYTES)
		if not raw.ok: _message(str(raw.error)); return
		_status("Converting FBX locally; this can take a moment...")
		var converted := Fbx.convert(raw.bytes, category == "animation", category == "animation")
		if not converted.ok: _message(str(converted.error)); return
		bytes = converted.bytes
	else:


		var prepared := Codec.prepare(path)
		if not bool(prepared.ok): _message(_explain(prepared)); return
		bytes = prepared.bytes
		notes = prepared.get("notes", [])
	var checked := Codec.import_model(bytes, category == "animation")
	if not checked.ok: _message(_explain(checked)); return
	var model: Node = checked.model; var clips := AnimationSupport.clips_from_node(model); model.free()
	if category == "animation" and clips.is_empty(): _message("No usable animation clips were found. Import a compatible animated FBX or GLB."); return
	var id := ("anim_" if category == "animation" else "glb_") +str(checked.sha256); var label := _display_name(path)
	if not _asset_fits(id, bytes): _message("Combined imported assets would exceed the %d MiB draft budget. Imported models stay inside the draft so it plays anywhere - drop one you no longer use." % int((Store.MAX_FILE - Store.MAX_META - 12) / 1048576)); return
	state.custom_assets[id] = { "name": label, "bytes": bytes, "category": category}; state.dirty = true; animation_cache.clear(); _refresh_library(); _refresh_inspector()
	var note := " ".join(notes)

	if category == "model" and bytes.size() > Codec.LARGE_MODEL_BYTES:
		note = (" ".join([note, "This model is %.1f MB: it imports and exports, but it loads slowly on a phone and takes a large share of the draft." % [float(bytes.size()) / 1048576.0]])).strip_edges()
	_status("Imported %s%s.%s" % [label, "; select an object and choose it under Animation source" if category == "animation" else "; drag it from the library into your scene", (" " + note) if not note.is_empty() else ""])
func _import_texture(path: String) -> void:
	if state.custom_assets.size() >= 24: _message("A draft can hold up to 24 imported assets."); return
	var raw := _read_bounded(path, TextureCodec.MAX_TEXTURE_BYTES)
	if not raw.ok: _message(str(raw.error)); return
	var checked := TextureCodec.validate(raw.bytes)
	if not checked.ok: _message(str(checked.error)); return
	var id := "tex_" + Codec.sha256(raw.bytes); var label := _display_name(path)
	if not _asset_fits(id, raw.bytes): _message("Combined imported assets would exceed the %d MiB draft budget." % int((Store.MAX_FILE - Store.MAX_META - 12) / 1048576)); return
	state.custom_assets[id] = { "name": label, "bytes": raw.bytes, "category": "texture"}; state.dirty = true; _refresh_inspector(); _status("Texture %s imported. Choose it for whole ground, paint brush, or a selected object on the right." % label)
func _convert_fbx(path: String) -> void:
	var raw := _read_bounded(path, Fbx.MAX_FBX_BYTES)
	if not raw.ok: _message(str(raw.error)); return
	var result := Fbx.convert(raw.bytes, true)
	if not result.ok: _message(str(result.error)); return
	conversion_bytes = result.bytes; convert_save_dialog.current_file = _display_name(path) +".glb"; convert_save_dialog.popup_centered_ratio(0.7)
func _save_converted_glb(path: String) -> void:
	if conversion_bytes.is_empty(): _message("No converted FBX is waiting to be saved."); return
	path = Platform.ensure_extension(path, "glb")
	var written := Platform.write_document(path, conversion_bytes)
	if not written.ok: _message("Could not save the converted GLB: " + str(written.error)); return
	conversion_bytes = PackedByteArray(); _status("Converted FBX saved as " + Platform.display_label(path) +" • " + Platform.display_location(path))
func _export_pack_requested() -> void:
	pack_dialog.popup_centered_ratio(0.7)

func _export_glb_requested() -> void:
	glb_dialog.popup_centered_ratio(0.7)

func _export_pack_to(path: String) -> void:
	if _export_running: _export_busy_message(); return
	state.finish_paint_stroke(); state.commit_paint()
	path = Platform.ensure_extension(path, "zip")
	if _report_oversized(): return
	_set_export_controls(false)
	_status("Building the 3D export; a big scene takes a few seconds...")
	await get_tree().process_frame
	var built: Dictionary = await Exporter.build_pack_stepped(state, library, _export_progress_tick)
	if not bool(built.ok):
		_set_export_controls(true); _message(_explain(built)); return
	_status("Writing the 3D package...")
	await get_tree().process_frame
	var write := Platform.write_document(path, built.bytes)
	_set_export_controls(true)
	if not bool(write.get("ok", false)): _message("Could not write the export: " + str(write.get("error", "unknown error"))); return
	_status("3D pack exported: " + Platform.display_label(path) +" • %d objects • " + Platform.display_location(path))

func _export_glb_to(path: String) -> void:
	if _export_running: _export_busy_message(); return
	state.finish_paint_stroke(); state.commit_paint()
	path = Platform.ensure_extension(path, "glb")
	if _report_oversized(): return
	_set_export_controls(false)
	_status("Building the scene .glb...")
	await get_tree().process_frame
	var built: Dictionary = await Exporter.build_combined_stepped(state, library, _export_progress_tick)
	if not bool(built.get("ok", false)):
		_set_export_controls(true); _message(_explain(built)); return
	_status("Writing the .glb...")
	await get_tree().process_frame
	var write := Platform.write_document(path, built.get("bytes", PackedByteArray()))
	_set_export_controls(true)
	if not bool(write.get("ok", false)): _message("Could not write the GLB: " + str(write.get("error", "unknown error"))); return
	_status("Scene GLB exported: " + Platform.display_label(path) +" • %d objects • " + Platform.display_location(path))

func _validate() -> void:
	state.finish_paint_stroke(); state.commit_paint()
	var result := Store.check_document(state.data, state.custom_assets)
	if not result.ok: _message("Draft validation: " + str(result.error)); return
	var warning := "Draft structure and embedded models passed basic checks.\n\nCustom missions use the updated game's simplified recon flight mode; notes are not additional triggers. This does not certify safety. Use trusted models only."
	if str(state.data.get("recon_target", "")).is_empty(): warning += "\n\nSet a recon target before exporting a mission."
	_message(warning)
func _save_requested() -> void:
	if not current_path.is_empty(): _save_to(current_path); return
	if not current_folder.is_empty(): _save_in_folder(); return
	save_dialog.popup_centered_ratio(0.7)
func _save_to(path: String) -> void:
	state.finish_paint_stroke(); state.commit_paint()
	path = Platform.ensure_extension(path, "rmdraft")
	var result := Store.save_draft(path, state.data, state.custom_assets)
	if not result.ok: _message("Could not save: " + str(result.error)); return
	current_path = path; state.dirty = false
	_refresh_crumb()
	_status("Draft saved: " + Platform.display_label(path) +" • " + Platform.display_location(path) +" • This file cannot yet be imported into the game.")



var _export_running := false

func _export_busy_message() -> void:
	_status("An export is already running. Give it a moment.")
	_message("An export is already running. The window stays live; wait for it to finish.")


func _report_oversized() -> bool:
	var too_big := Store.oversized_assets(state.custom_assets)
	if too_big.is_empty(): return false
	var lines: Array = []
	for row in too_big:
		if str(row.get("category", "")) == "total":
			lines.append("• all imported assets together are %.1f MB (limit %.0f MB)" % [float(row.mb), float(row.limit_mb)])
		else:
			lines.append("• %s — %.1f MB (limit %.0f MB)" % [str(row.get("name", "")).strip_edges(), float(row.mb), float(row.limit_mb)])
	_message("This mission cannot be exported yet:\n\n" + "\n".join(lines) +
		"\n\nRe-export the model with 2K instead of 4K textures, or split it into parts and place them together. Nothing was written.")
	return true

func _set_export_controls(enabled: bool) -> void:
	_export_running = not enabled
	for button in [export3d_button, exportglb_button]:
		if button != null: button.disabled = not enabled

func _export_progress(done: int, total: int, note: String = "") -> void:
	if not note.is_empty():
		_status(note)
	else:
		_status("Exporting: %d of %d objects placed..." % [done, total])

func _export_mission_to(path: String) -> void:
	if _export_running: _export_busy_message(); return
	state.finish_paint_stroke(); state.commit_paint()
	path = Platform.ensure_extension(path, "rmission")
	if _report_oversized(): return
	_set_export_controls(false)
	var started := Time.get_ticks_msec()
	_status("Exporting the complete mission package: scene, ground, objects and models...")
	await get_tree().process_frame
	var result: Dictionary = await _write_mission_package_async(path)
	_set_export_controls(true)
	var seconds := float(Time.get_ticks_msec() -started) / 1000.0
	if not bool(result.get("ok", false)):
		_message("Could not export mission: " + str(result.get("error", "")))
		return
	var fidelity: Dictionary = result.get("fidelity", {})
	_message("Mission package exported and verified: " + Platform.display_label(path) +"\n" + Platform.display_location(path) +"\n\n" +
		"%d object%s, %d terrain height samples, ground surface %s.\nEmbedded scene: %.1f MB. File: %.1f MB. Took %.1f s.\n\nEvery object sits within %.4f m of where this editor shows it, and the file checks itself when it is opened.\n\nThe package holds the exact ground, colours, light, objects and models, so the scene can be reproduced from the file alone." % [
			int(result.get("objects", 0)), "" if int(result.get("objects", 0)) == 1 else "s", int(fidelity.get("terrain_cells", 0)),
			"included" if not str(state.data.get("terrain_texture", "")).is_empty() or bool(fidelity.get("has_paint", false)) or bool(fidelity.get("has_snow", false)) or bool(fidelity.get("has_environment", false)) else "default",
			float(result.get("scene_bytes", 0)) / 1048576.0, float(result.get("bytes", 0)) / 1048576.0, seconds,
			float(fidelity.get("worst_placement_m", 0.0))])


func _write_mission_package_async(path: String) -> Dictionary:
	var built: Dictionary = await Exporter.build_combined_stepped(state, library, _export_progress_tick)
	if not bool(built.get("ok", false)): _message(_explain(built)); return { "ok": false, "error": str(built.get("error", "the scene could not be built"))}
	var fidelity_block := {
		"ok": true,
		"objects": int(built.get("objects", 0)),
		"worst_placement_m": float(built.get("worst_placement_m", 0.0)),
		"glb_bytes": (built.get("bytes", PackedByteArray()) as PackedByteArray).size(),
		"checked_utc": Time.get_datetime_string_from_system(true),
	}
	var block := Exporter.scene_block(state, fidelity_block)
	_status("Writing and checking the mission file...")
	await get_tree().process_frame
	var result: Dictionary = Store.save_mission_package(path, state.data, state.custom_assets, built.bytes, block)
	return result


func _export_progress_tick(done: int, total: int, note: String = "") -> void:
	_export_progress(done, total, note)
	await get_tree().process_frame


func _write_mission_package(path: String) -> Dictionary:
	var built := Exporter.build_combined(state, library)
	if not bool(built.get("ok", false)): _message(_explain(built)); return { "ok": false, "error": str(built.get("error", "the scene could not be built"))}
	var fidelity_block := {
		"ok": true,
		"objects": int(built.get("objects", 0)),
		"worst_placement_m": float(built.get("worst_placement_m", 0.0)),
		"glb_bytes": (built.get("bytes", PackedByteArray()) as PackedByteArray).size(),
		"checked_utc": Time.get_datetime_string_from_system(true),
	}
	var block := Exporter.scene_block(state, fidelity_block)
	return Store.save_mission_package(path, state.data, state.custom_assets, built.bytes, block)
func _open_from(path: String) -> void:
	if flight_button != null: flight_button.button_pressed = false
	var result := Store.load_draft(path)
	if not result.ok: _message("Could not open: " + str(result.error)); return
	state.replace_loaded(result.mission, result.assets); current_path = path
	_refresh_crumb()
	_status("Draft opened: " + Platform.display_label(path) +" • " + Platform.display_location(path))
func _request_action(action: String) -> void:
	pending_action = action
	if state.dirty: confirm.popup_centered(Vector2i(420, 150))
	else: _run_pending()
func _run_pending() -> void:
	var action := pending_action; pending_action = ""
	if action == "new":
		flight_button.button_pressed = false
		route_button.button_pressed = false; play_button.button_pressed = false; terrain_mode.select(0); _terrain_mode_changed(0)
		state.reset_blank(); current_path = ""; _seed_default_ground(); _status("New mission: textured flat terrain and no objects. Shape the ground or add assets.")
	elif action == "open": open_dialog.popup_centered_ratio(0.7)
	elif action == "quit": get_tree().quit()
func _exit_tree() -> void:
	library.clear_templates()
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: _request_action("quit")
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST: _android_back()

func _android_back() -> void:

	if flight_button != null and flight_button.button_pressed: flight_button.button_pressed = false; return
	if map_expanded: _toggle_map(); return
	if inspector_panel != null and inspector_panel.visible: _toggle_panel("inspector"); return
	if library_panel != null and library_panel.visible: _toggle_panel("library"); return
	_request_action("quit")
func _make_extra_dialogs() -> void:
	heightmap_dialog = FileDialog.new(); heightmap_dialog.title = "Import 16-bit heightmap"
	heightmap_dialog.access = FileDialog.ACCESS_FILESYSTEM; heightmap_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	heightmap_dialog.add_filter("*.png", "PNG heightmap"); heightmap_dialog.add_filter("*.*", "All files")
	heightmap_dialog.file_selected.connect(_heightmap_picked); add_child(heightmap_dialog)
	heightmap_save_dialog = FileDialog.new(); heightmap_save_dialog.title = "Export terrain heightmap"
	heightmap_save_dialog.access = FileDialog.ACCESS_FILESYSTEM; heightmap_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	heightmap_save_dialog.add_filter("*.png", "PNG heightmap"); heightmap_save_dialog.current_file = "terrain_heightmap.png"
	heightmap_save_dialog.file_selected.connect(_heightmap_saved); add_child(heightmap_save_dialog)
	underlay_dialog = FileDialog.new(); underlay_dialog.title = "Reference image for the map"
	underlay_dialog.access = FileDialog.ACCESS_FILESYSTEM; underlay_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	underlay_dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp", "Images"); underlay_dialog.add_filter("*.*", "All files")
	underlay_dialog.file_selected.connect(_underlay_picked); add_child(underlay_dialog)


func _quick_labels(active: bool) -> void:
	if map_view != null: map_view.show_labels = active; map_view.queue_redraw()
	_status("Map labels on." if active else "Map labels off.")

func _quick_grid(active: bool) -> void:
	if map_view != null: map_view.show_grid = active; map_view.queue_redraw()
	if scene_view != null: scene_view.set_ground_grid(active)
	_status("Terrain grid on." if active else "Terrain grid off.")

func _quick_hide_ui(active: bool) -> void:
	ui_hidden = active
	if active:
		library_panel.visible = false
		inspector_panel.visible = false
	else:
		library_panel.visible = not _narrow_layout
		inspector_panel.visible = not _compact_layout
	if library_button != null: library_button.set_pressed_no_signal(library_panel.visible)
	if inspector_button != null: inspector_button.set_pressed_no_signal(inspector_panel.visible)
	_status("Side panels hidden; use Panels or the header buttons to restore them." if active else "Side panels restored.")

func _quick_recentre() -> void:
	if scene_view != null: scene_view.reset_camera()
	if map_view != null: map_view.queue_redraw()
	_status("Camera recentred on the whole scene.")

func _quick_snap(active: bool) -> void:
	snap_enabled = active
	_status("Snapping to a 5 m grid." if active else "Free placement.")

func _quick_multi(active: bool) -> void:
	multi_select_mode = active
	selection.clear()
	if not state.selected_id.is_empty(): selection.add(state.selected_id)
	_sync_multi_selection()
	_status("Multi-select on: click several objects in the hierarchy or the 3D view." if active else "Single selection.")

func _quick_ruler(active: bool) -> void:
	if map_view != null: map_view.ruler_mode = active; map_view.queue_redraw()
	if active and map_view != null: map_view.clear_ruler()
	_status("Ruler mode: click two points on the map." if active else "Ruler mode off.")

func _undo() -> void:
	if scene_view != null and scene_view.busy(): _status(BUSY_TEXT); return
	var label = history.undo(state) if history != null else ""
	if label == "": _status("Nothing to undo."); return
	_after_history("Undid: " + label)

func _redo() -> void:
	if scene_view != null and scene_view.busy(): _status(BUSY_TEXT); return
	var label = history.redo(state) if history != null else ""
	if label == "": _status("Nothing to redo."); return
	_after_history("Redid: " + label)

func _after_history(message: String) -> void:
	selection.prune(state)
	_last_doc = state.data.duplicate(true); _last_selected = state.selected_id
	_refresh_inspector(); _refresh_scene_tree(); _refresh_history_buttons(); _sync_multi_selection()
	_status(message)

func _refresh_history_buttons() -> void:
	if quick_undo != null: quick_undo.disabled = not (history != null and history.can_undo())
	if quick_redo != null: quick_redo.disabled = not (history != null and history.can_redo())

func _sun_preview(value: float) -> void:
	if scene_view != null: scene_view.preview_time(value)
	if sun_label != null: sun_label.text = "%02d:%02d" % [int(floor(value)), int(round((value - floor(value)) * 60.0)) % 60]
	if _sun_timer != null: _sun_timer.start()

func _sun_commit() -> void:
	if scene_view == null: return
	scene_view.commit_time(sun_slider.value if sun_slider != null else 10.0)

func _brush_from_bar(radius: float, strength: float) -> void:
	if terrain_radius != null: terrain_radius.set_value_no_signal(radius)
	if terrain_strength != null: terrain_strength.set_value_no_signal(strength)
	if scene_view != null: scene_view.brush_radius = radius; scene_view.brush_strength = strength
	if map_view != null: map_view.brush_radius = radius; map_view.brush_strength = strength
	_refresh_brush_label()

func _refresh_brush_label() -> void:
	if brush_tool_label == null or scene_view == null: return
	var tool := str(scene_view.terrain_tool)
	var shown := { "select": "SELECT", "raise": "RAISE", "lower": "LOWER", "smooth": "SMOOTH", "flatten": "FLATTEN", "paint": "PAINT", "erase_paint": "ERASE PAINT", "road": "ROAD", "wall": "WALL", "route": "ROUTE"}
	brush_tool_label.text = "BRUSH · " + str(shown.get(tool, tool.to_upper()))

func _refresh_perf() -> void:
	if perf == null: return
	var sample = perf.sample(state)
	if perf_label != null: perf_label.text = perf.label()
	var warning = perf.budget_warning(state)
	if perf_label != null: perf_label.add_theme_color_override("font_color", Color("ffc46b") if warning != "" else Color("8ce0a0"))
	if warning != "" and perf_label != null: perf_label.tooltip_text = warning
	_refresh_issues_button()

func _refresh_issues_button() -> void:
	if issues_button == null or validator == null: return
	var issues = validator.check(state)
	var counts = validator.counts(issues)
	var total: int = issues.size()
	issues_button.tooltip_text = "Checks: %s" % validator.summary(issues)
	if issues_count_label != null:
		issues_count_label.text = str(total)
		var colour := Color("8ce0a0")
		if int(counts.error) > 0: colour = Color("ff9c7a")
		elif total > 0: colour = Color("ffc46b")
		issues_count_label.add_theme_color_override("font_color", colour)
	issues_button.icon = Icons.icon("checks", Color("ff9c7a") if int(counts.error) > 0 else (Color("ffc46b") if total > 0 else Color("8ce0a0")))


func _open_checklist() -> void:
	checklist_issues = validator.sorted(validator.check(state))
	if checklist_list != null:
		for child in checklist_list.get_children(): child.queue_free()
		if checklist_issues.is_empty():
			checklist_list.add_child(_label("No problems found.", 11, Color("8ce0a0")))
		for issue: Dictionary in checklist_issues:
			var name := str(issue.code)
			if not str(issue.object_id).is_empty():
				var row: Dictionary = state.find_object(str(issue.object_id))
				if not row.is_empty(): name = str(row.name)
			var color := Color("ff9c7a") if str(issue.severity) == "error" else (Color("ffc46b") if str(issue.severity) == "warning" else Color("a6adb6"))
			var button := _button("%s · %s" % [str(issue.severity).to_upper(), str(issue.message)])
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.add_theme_color_override("font_color", color)
			button.pressed.connect(_select_issue.bind(str(issue.object_id)))
			checklist_list.add_child(button)


	var route_result := Routes.check(state)
	var route_counts := Routes.counts(route_result)
	for issue: Dictionary in route_result.get("issues", []):
		if str(issue.get("severity", "")) == "note": continue
		var colour := Color("ff9c7a") if str(issue.severity) == "fail" else Color("ffc46b")
		var route_button := _button("ROUTE · %s — %s" % [str(issue.get("object_name", "")), str(issue.get("message", ""))])
		route_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		route_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		route_button.add_theme_color_override("font_color", colour)
		route_button.pressed.connect(_select_issue.bind(str(issue.get("object_id", ""))))
		if checklist_list != null: checklist_list.add_child(route_button)
	if checklist_summary != null:
		checklist_summary.text = validator.summary(checklist_issues) +(" • routes: %d fail, %d warn" % [int(route_counts.fail), int(route_counts.warn)] if int(route_counts.fail) +int(route_counts.warn) > 0 else " • routes: all walkable")
	_set_inspector_tab("MISSION")
	_status("Checks: " + validator.summary(checklist_issues))
	if inspector_panel != null: _open_right_tab("MISSION")

func _select_issue(object_id: String) -> void:
	if object_id.is_empty(): return
	state.select(object_id)
	selection.keep_only(object_id)
	_sync_multi_selection()
	if scene_view != null: scene_view.focus_selected()
	_status("Selected the object for that check.")


func _sync_multi_selection() -> void:
	if scene_view != null: scene_view.set_multi_selection(selection.ids)
	if map_view != null: map_view.set_highlight(selection.ids)

func _current_ids() -> Array:
	if selection.ids.is_empty() and not state.selected_id.is_empty(): selection.keep_only(state.selected_id)
	return selection.ids



func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo: return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit: return
	if key.ctrl_pressed or key.meta_pressed:
		match key.keycode:
			KEY_N: _request_action("new")
			KEY_O: _request_action("open")
			KEY_S:
				if key.shift_pressed: save_dialog.popup_centered_ratio(0.7)
				else: _save_requested()
			KEY_E: export_dialog.popup_centered_ratio(0.7)
			KEY_Z:
				if key.shift_pressed: _redo()
				else: _undo()
			KEY_Y: _redo()
			KEY_C: _copy_selection()
			KEY_V: _paste_selection()
			KEY_D: _duplicate_selection()
			_: return
		get_viewport().set_input_as_handled()
		return
	match key.keycode:
		KEY_F1: _show_help()
		KEY_F8: _open_route_check()
		KEY_F9: _open_scene_report()
		KEY_DELETE: _delete_selection()
		KEY_M: _toggle_map_visibility()
		KEY_G:
			quick_grid.set_pressed_no_signal(not quick_grid.button_pressed)
			_quick_grid(quick_grid.button_pressed)
		KEY_BRACKETLEFT: _rotate_selection(-_rotation_step())
		KEY_BRACKETRIGHT: _rotate_selection(_rotation_step())
		KEY_R:
			if scene_view != null and not state.selected_id.is_empty(): _status("Hold R and drag in the 3D view or map to spin the selection.")
			return
		_: return
	get_viewport().set_input_as_handled()

func _copy_selection() -> void:
	var count = selection.copy(state)
	_status("Copied %d object(s)." % count if count > 0 else "Select something to copy.")

func _paste_selection() -> void:
	_begin_group()
	var made = selection.paste(state, Vector2(12, 12))
	_end_group()
	if made.is_empty(): _status("Nothing to paste."); return
	selection.keep_only(str(made[0]))
	state.select(str(made[0]))
	_sync_multi_selection()
	_status("Pasted %d object(s)." % made.size())

func _duplicate_selection() -> void:
	_begin_group()
	var made = selection.duplicate(state, Vector2(12, 12))
	_end_group()
	if made.is_empty(): _status("Select something to duplicate."); return
	selection.keep_only(str(made[0]))
	state.select(str(made[0]))
	_sync_multi_selection()
	_status("Duplicated %d object(s)." % made.size())

func _delete_selection() -> void:
	var ids = _current_ids().duplicate()
	if ids.is_empty(): _status("Select something to delete."); return
	_begin_group()
	for id in ids:
		state.select(str(id))
		state.remove_selected()
	_end_group()
	selection.clear()
	_sync_multi_selection()
	_status("Deleted %d object(s)." % ids.size())

func _flag_selection(key: String, value: bool) -> void:
	var ids = _current_ids().duplicate()
	if ids.is_empty(): _status("Select something first."); return
	var changed = 0
	for id in ids:
		if state.set_flag(str(id), key, value): changed += 1
	_status("%s %d object(s)." % [("Locked" if key == "locked" else "Hid"), changed])

func _align_selection(mode: String) -> void:
	_current_ids()
	var moved = selection.align(state, mode)
	_status("Aligned %d object(s)." % moved if moved > 0 else "Select two or more objects to align.")

func _distribute_selection(axis: String) -> void:
	_current_ids()
	var moved = selection.distribute(state, axis)
	_status("Spread %d object(s) evenly." % moved if moved > 0 else "Select three or more objects to spread.")


func _set_inspector_tab(name: String) -> void:
	active_tab = name
	for key in inspector_tab_buttons.keys():
		var button: Button = inspector_tab_buttons[key]
		button.button_pressed = str(key) == name
	for key in inspector_tab_panels.keys():
		var panel: Node = inspector_tab_panels[key]
		panel.get_parent().visible = str(key) == name
	if name == "FILES": _refresh_autosave_list()
	if name == "MISSION": _refresh_issues_button()


func _heightmap_import_requested() -> void:
	if scene_view != null and scene_view.busy(): _status(BUSY_TEXT); return
	heightmap_dialog.popup_centered_ratio(0.7)

func _heightmap_export_requested() -> void:
	heightmap_save_dialog.popup_centered_ratio(0.7)

func _heightmap_picked(path: String) -> void:
	var read := _read_bounded(path, 64 * 1024 * 1024)
	if not bool(read.ok): _status("Could not read that file: " + str(read.error)); return
	var decoded = Heightmap.decode_png(read.bytes)
	if not bool(decoded.ok): _status("Heightmap rejected: " + str(decoded.message)); return
	var applied = Heightmap.apply_to_state(state, decoded, Heightmap.MIN_H, Heightmap.MAX_H, heightmap_additive)
	if not bool(applied.ok): _status("Heightmap not applied: " + str(applied.message)); return
	_status(str(applied.message))
	_refresh_inspector(); _refresh_scene_tree()

func _heightmap_saved(path: String) -> void:
	var export = Heightmap.export_png(state, int(state.data.get("terrain", {}).get("resolution", 65)))
	if not bool(export.ok): _status("Nothing to export: " + str(export.message)); return
	var write := Platform.write_document(path, PackedByteArray(export.bytes))
	if bool(write.get("ok", false)): _status("Heightmap exported: " + str(export.message))
	else: _status("Heightmap export failed: " + str(write.get("error", "unknown error")))

func _underlay_requested() -> void:
	underlay_dialog.popup_centered_ratio(0.7)

func _underlay_picked(path: String) -> void:
	var read := _read_bounded(path, 32 * 1024 * 1024)
	if not bool(read.ok): _status("Could not read that image: " + str(read.error)); return
	var image := Image.new()
	if image.load_png_from_buffer(read.bytes) != OK and image.load_jpg_from_buffer(read.bytes) != OK and image.load_webp_from_buffer(read.bytes) != OK:
		_status("That image could not be decoded; use PNG, JPG or WebP."); return
	var texture := ImageTexture.create_from_image(image)
	if map_view != null: map_view.set_underlay(texture, _display_name(path))
	_status("Reference image under the map: " + _display_name(path))

func _clear_underlay() -> void:
	if map_view != null: map_view.clear_underlay()
	_status("Reference image removed.")


func _autosave_tick() -> void:
	if autosave == null or state == null: return
	var now := Time.get_ticks_msec()
	if not autosave.should_write(now, state.data.get("objects", []).size() > 0 or state.dirty): return
	var result = autosave.write(state, now)
	if bool(result.get("ok", false)):
		if autosave_label != null: autosave_label.text = "Autosaved"
		if autosave_status != null: autosave_status.text = "Last autosave: " + Time.get_time_string_from_system()
		if autosave_list != null: _refresh_autosave_list()
	else:
		if autosave_label != null: autosave_label.text = "Autosave blocked"

func _refresh_autosave_list() -> void:
	if autosave_list == null or autosave == null: return
	for child in autosave_list.get_children(): child.queue_free()
	var rows = autosave.list_versions()
	if rows.is_empty():
		autosave_list.add_child(_label("No autosave versions yet.", 10, MUTED))
		return
	for row: Dictionary in rows:
		var stamp := Time.get_datetime_string_from_unix_time(int(row.time))
		var button := _button("RESTORE %s  (%d KB)" % [stamp, int(row.size) / 1024])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_restore_autosave_path.bind(str(row.path)))
		autosave_list.add_child(button)

func _restore_latest_autosave() -> void:
	if autosave == null: _status("Autosave is unavailable."); return
	var latest = autosave.latest()
	if latest.is_empty(): _status("No autosave to restore."); return
	_restore_autosave_path(str(latest.path))

func _restore_autosave_path(path: String) -> void:
	var loaded = Store.load_draft(path)
	if not bool(loaded.get("ok", false)): _status("Autosave could not be read: " + str(loaded.get("error", "unknown"))); return
	state.replace_loaded(loaded.mission, loaded.assets)
	current_path = ""
	_last_doc = state.data.duplicate(true); _last_selected = state.selected_id
	_refresh_library(); _refresh_inspector(); _refresh_scene_tree()
	_status("Restored the autosaved draft from " + path.get_file())


func _qw_help() -> Button:
	var button := _button("HELP")
	button.tooltip_text = "Keyboard shortcuts and touch controls."
	button.pressed.connect(_show_help)
	return button

func _build_help_overlay() -> void:
	help_overlay = PanelContainer.new()
	help_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	help_overlay.add_theme_stylebox_override("panel", _panel_style(Color("1b1f24"), ACCENT, 6))
	help_overlay.visible = false
	add_child(help_overlay)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 4); help_overlay.add_child(box)
	box.add_child(_label("SHORTCUTS AND CONTROLS", 13, ACCENT))
	var text := "MOUSE  •  Left-drag empty ground pans  •  Right-drag orbits  •  Wheel zooms\n"
	text += "HIERARCHY  •  Click selects, double-click focuses, MULTI adds to the selection\n"
	text += "OBJECTS  •  Drag in 3D or on the map  •  Arrow keys nudge  •  Delete removes\n"
	text += "COPY  •  OBJECT tab DUPLICATE copies the selection  •  Ctrl+C, Ctrl+V, Ctrl+D\n"
	text += "TOOLS  •  Shelf on the left  •  Radius and Strength sliders in the top bar\n"
	text += "TERRAIN  •  Raise / Lower / Smooth / Flatten  •  Paint and Erase need a brush texture\n"
	text += "ROUTES  •  ROUTE button then click waypoints, or drag to draw\n"
	text += "MAP  •  MAP hides it, EXPAND enlarges it, RULER measures, REF IMAGE loads a picture\n"
	text += "FILES  •  HEIGHT ↑/↓ import and export 16-bit PNG heightmaps\n"
	text += "RECOVERY  •  Autosave keeps four drafts under the FILES tab\n"
	text += "TOUCH  •  One finger pans or draws  •  ORBIT LOOK switches to looking around"
	var body := _label(text, 11, TEXT); body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(body)
	var close := _button("CLOSE"); close.pressed.connect(func (): help_overlay.visible = false); box.add_child(close)

func _show_help() -> void:
	if help_overlay != null: help_overlay.visible = not help_overlay.visible


func _category_icon(category: String) -> Texture2D:
	var size := 24
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var tint := Color("8ce0a0")
	match category:
		"Buildings": tint = Color("f0c48a")
		"Vehicles": tint = Color("a9d6ef")
		"People": tint = Color("d4b8ff")
		"Nature": tint = Color("9fd8a0")
		"Aircraft": tint = Color("f2a33c")
		"Textures": tint = Color("c9b48a")
		_: tint = Color("a6adb6")
	for y in size:
		for x in size:
			var draw := false
			match category:
				"Buildings":
					draw = (y >= 10 and x >= 5 and x <= 18) or (y >= 4 and y < 10 and absi(x - 11) <= int((y - 2) * 1.4))
				"Vehicles":
					draw = (y >= 9 and y <= 15 and x >= 3 and x <= 20) or ((x <= 6 or x >= 16) and y >= 16 and y <= 19)
				"People":
					draw = (x - 12) * (x - 12) +(y - 7) * (y - 7) <= 9 or (y >= 13 and y <= 21 and absi(x - 12) <= 5)
				"Nature":
					draw = (y >= 14 and y <= 20 and x >= 3 and x <= 20) or (y >= 6 and y < 14 and absi(x - 12) <= int((14 - y) * 1.1))
				"Aircraft":
					draw = (absf(x - 12) <= 2 and y >= 3 and y <= 20) or (y >= 10 and y <= 14 and x >= 2 and x <= 21)
				"Textures":
					draw = ((int(x / 4) +int(y / 4)) % 2) == 0
				_:
					draw = (y >= 6 and y <= 18 and x >= 6 and x <= 18)
			if draw: image.set_pixel(x, y, tint)
	return ImageTexture.create_from_image(image)

func _refresh_library_filtered() -> void:
	if asset_list == null: return
	for child in asset_list.get_children(): child.queue_free()
	var query := library_search.text if library_search != null else ""
	var category := "All"
	if library_category != null and library_category.selected >= 0: category = library_category.get_item_text(library_category.selected)
	var entries = library_index.index(library, state.custom_assets)
	entries = library_index.filter(entries, query, category)
	entries = library_index.recents_first(entries)
	var counts = library_index.placed_counts(Array(state.data.get("objects", [])))
	if recents_label != null:
		var recent: Array = library_index.recents
		var names: PackedStringArray = []
		for id in recent.slice(0, 4): names.append(str(library.label_for(str(id), state.custom_assets)))
		recents_label.text = "RECENT: " + (", ".join(names) if not names.is_empty() else "nothing placed yet")
	if entries.is_empty():
		asset_list.add_child(_label("No assets match that search.", 11, MUTED))
		return
	for item: Dictionary in entries:
		var card = AssetCard.new()
		card.asset_id = str(item.id)
		var placed := int(counts.get(str(item.id), 0))
		card.text = str(item.name) +(" ×%d" % placed if placed > 0 else "")
		var thumbnail: Texture2D = Thumbs.cached(str(item.id)) if state.custom_assets.has(str(item.id)) else null
		card.icon = thumbnail if thumbnail != null else _category_icon(str(item.category))
		card.expand_icon = false
		card.tooltip_text = str(item.name) + " · " + str(item.category) + " · " + str(item.get("kind", "")) + _model_stats_tip(str(item.id), "model")
		if thumbnail == null and state.custom_assets.has(str(item.id)): card.tooltip_text += " · preview renders on first use"
		card.custom_minimum_size = Vector2(0, 54) if android else Vector2(0, 42)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.clip_text = true
		card.add_theme_font_size_override("font_size", 14 if android else 11)
		card.add_theme_stylebox_override("normal", _panel_style(Color("1a292a"), Color("2d4240"), 5))
		card.add_theme_stylebox_override("hover", _panel_style(Color("245145"), ACCENT, 5))
		card.pressed.connect(_place_at_center.bind(str(item.id)))
		asset_list.add_child(card)
	if not state.custom_assets.is_empty():
		Thumbs.request(self, state.custom_assets)
		var missing := 0
		for key in state.custom_assets.keys():
			if str(state.custom_assets[key].get("category", "")) == "model" and Thumbs.cached(str(key)) == null: missing += 1
		if missing > 0:

			var token := Thumbs.cache_size()
			get_tree().create_timer(0.8).timeout.connect(func ():
				if is_instance_valid(asset_list) and Thumbs.cache_size() != token: _refresh_library())


func _show_splash() -> void:
	var splash := Control.new()
	splash.set_script(Splash)
	add_child(splash)
	if splash.has_method("setup"): splash.setup(2.4)
	splash.visible = true


func _fill_environment_section(page: VBoxContainer) -> void:
	page.add_child(HSeparator.new())
	page.add_child(_label("LIGHT AND WEATHER", 11, ACCENT))
	var hint := _label("Sun, fog, wind, rain, dust and snow are stored in the scene and travel with the exported mission, so what you light here is what the mission starts with.", 10, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; page.add_child(hint)
	var preset_row := HFlowContainer.new(); preset_row.add_theme_constant_override("h_separation", 4); page.add_child(preset_row)
	for row: Dictionary in Weather.PRESETS:
		var preset_button := _button(str(row.label))
		preset_button.tooltip_text = "Apply the %s starting point. Every slider below still works afterwards." % str(row.label).to_lower()
		preset_button.pressed.connect(_apply_weather_preset.bind(str(row.id)))
		preset_row.add_child(preset_button)
	env_summary_label = _label("", 10, MUTED); env_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; page.add_child(env_summary_label)
	env_sliders = {}
	_env_slider(page, "Time of day", "hour", 0, 24, 0.25, "Clock time the mission starts at. The sun follows it.")
	_env_slider(page, "Fog", "fog", 0, 1, 0.05, "Distance haze, thickening towards the ground.")
	_env_slider(page, "Cloud", "cloud", 0, 1, 0.05, "Soft light and a dimmer sun.")
	_env_slider(page, "Rain", "rain", 0, 1, 0.05, "Falling rain and wet, darker ground.")
	_env_slider(page, "Snowfall", "snow_fall", 0, 1, 0.05, "Snow falling from the sky.")
	_env_slider(page, "Snow cover", "snow_cover", 0, 1, 0.05, "Snow lying on the ground everywhere. The SNOW brush paints it in patches instead.")
	_env_slider(page, "Dust", "dust", 0, 1, 0.05, "Blowing dust; thick enough and it hides the horizon.")
	_env_slider(page, "Wind speed (m/s)", "wind", 0, 30, 1, "Wind strength. Objects lean in the wind and the falling weather drifts sideways.")
	_env_slider(page, "Wind direction", "wind_dir", 0, 360, 5, "0 blows towards the north, 90 towards the east.")
	var action_row := HFlowContainer.new(); action_row.add_theme_constant_override("h_separation", 4); page.add_child(action_row)
	var report_button := _button("SCENE REPORT"); report_button.tooltip_text = "Everything worth knowing before exporting: object counts, ground size, buried or overlapping objects, route problems, weather and asset budget."
	report_button.pressed.connect(_open_scene_report); action_row.add_child(report_button)
	var routes_button := _button("CHECK ROUTES"); routes_button.tooltip_text = "Walk every route against the sculpted ground and report impossible grades, waypoints off the map and objects in the way."
	routes_button.pressed.connect(_open_route_check); action_row.add_child(routes_button)

func _env_slider(page: VBoxContainer, title: String, key: String, lo: float, hi: float, step: float, tip: String) -> void:
	var head := HBoxContainer.new(); page.add_child(head)
	var name_label := _label(title.to_upper(), 10, MUTED); name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(name_label)
	var value_label := _label("", 10, TEXT); head.add_child(value_label)
	var slider := HSlider.new(); slider.min_value = lo; slider.max_value = hi; slider.step = step
	slider.tooltip_text = tip
	slider.value_changed.connect(func (v):
		value_label.text = _env_value_text(key, v)
		_set_environment(key, v))
	page.add_child(slider)
	env_sliders[key] = { "slider": slider, "label": value_label}

func _env_value_text(key: String, value: float) -> String:
	if key == "hour": return "%02d:%02d" % [int(floor(value)), int(round((value - floor(value)) * 60.0)) % 60]
	if key == "wind": return "%d m/s" % int(round(value))
	if key == "wind_dir": return "%d°" % int(round(value))
	return "%d%%" % int(round(value * 100.0))

func _set_environment(key: String, value: float) -> void:
	if _refreshing: return
	Weather.set_value(state, key, value)
	if scene_view != null: scene_view.apply_weather()
	_refresh_environment()

func _apply_weather_preset(id: String) -> void:
	if scene_view != null and scene_view.busy(): _status(BUSY_TEXT); return
	Weather.write(state, Weather.preset(state, id))
	state.dirty = true
	if scene_view != null: scene_view.apply_weather()
	_refresh_environment()
	_refresh_inspector()
	_status("Light and weather: " + Weather.summary(state))

func _refresh_environment() -> void:
	if env_summary_label == null: return
	var settings := Weather.read(state)
	_refreshing = true
	for key in env_sliders.keys():
		var entry: Dictionary = env_sliders[key]
		var slider: HSlider = entry.slider
		if not slider.has_focus(): slider.set_value_no_signal(float(settings.get(key, 0.0)))
		var value_label: Label = entry.label
		value_label.text = _env_value_text(str(key), float(settings.get(key, 0.0)))
	_refreshing = false
	env_summary_label.text = Weather.summary(state)

func _undo_snow() -> void:
	if scene_view != null and scene_view.busy(): _status(BUSY_TEXT); return
	var done := state.undo_snow_stroke()
	if done:
		scene_view.refresh_terrain_texture()
		state.changed.emit("paint")
	_status("Undid the last snow stroke." if done else "There is no snow stroke to undo.")

func _clear_snow() -> void:
	if scene_view != null and scene_view.busy(): _status(BUSY_TEXT); return
	var done := state.clear_snow()
	if done:
		scene_view.refresh_terrain_texture()
		state.changed.emit("paint")
	_status("Cleared every painted patch of snow." if done else "No painted snow to clear.")


func _rotation_step() -> float:
	return rotation_snap if rotation_snap > 0.0 else 0.1

func _fill_rotation_section(page: VBoxContainer) -> void:
	page.add_child(HSeparator.new())
	page.add_child(_label("FINE CONTROL AND ROTATION", 11, ACCENT))
	var hint := _label("Hold R and drag in the 3D view or the map to spin the selection. The [ and ] keys nudge it by the step below.", 10, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; page.add_child(hint)
	var nudge_row := HFlowContainer.new(); nudge_row.add_theme_constant_override("h_separation", 4); page.add_child(nudge_row)
	var left := _icon_button("undo", "Rotate 0.1° to the left (or [ )")
	left.tooltip_text = "Turn the selection left by the current step. Same as the [ key."
	left.pressed.connect(func (): _rotate_selection(- _rotation_step())); nudge_row.add_child(left)
	var right := _icon_button("redo", "Rotate 0.1° to the right (or ] )")
	right.tooltip_text = "Turn the selection right by the current step. Same as the ] key."
	right.pressed.connect(func (): _rotate_selection(_rotation_step())); nudge_row.add_child(right)
	nudge_row.add_child(_label("STEP", 10, MUTED))
	for step in [0.1, 1.0, 15.0, 45.0, 90.0]:
		var snap_button := _button("%s°" % str(step))
		snap_button.tooltip_text = "Set the rotation step to %s degrees." % str(step)
		snap_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		snap_button.pressed.connect(func (): _set_rotation_step(step)); nudge_row.add_child(snap_button)
	var whole_row := HFlowContainer.new(); whole_row.add_theme_constant_override("h_separation", 4); page.add_child(whole_row)
	var whole := _button("ROTATE WHOLE SELECTION")
	whole.tooltip_text = "Turn everything selected by the current step, keeping the group's spacing."
	whole.pressed.connect(func (): _rotate_selection(_rotation_step())); whole_row.add_child(whole)
	var snap_here := _button("SNAP TO STEP")
	snap_here.tooltip_text = "Round the selected objects onto the nearest multiple of the rotation step."
	snap_here.pressed.connect(_snap_rotation); whole_row.add_child(snap_here)

func _set_rotation_step(step: float) -> void:
	rotation_snap = step
	_status("Rotation step: %s°." % ("0.1" if step <= 0.1 else str(int(step))))

func _rotate_selection(degrees: float) -> void:
	var ids = _current_ids().duplicate()
	if ids.is_empty(): _status("Select something to rotate."); return
	if scene_view != null and scene_view.busy(): _status(BUSY_TEXT); return
	_begin_group()
	var turned := 0
	for id in ids:
		var row: Dictionary = state.find_object(str(id))
		if row.is_empty() or bool(row.get("locked", false)): continue

		if str(row.get("asset", "")) in ["road_path", "brick_wall"]: continue
		var current := float(row.get("yaw_deg", 0.0))
		state.set_value(str(id), "yaw_deg", wrapf(current + degrees, -360.0, 360.0))
		turned += 1
	_end_group()
	_status("Turned %d object(s) by %s°." % [turned, "%.1f" % degrees])

func _snap_rotation() -> void:
	var ids = _current_ids().duplicate()
	if ids.is_empty(): _status("Select something to snap."); return
	var step := maxf(0.1, _rotation_step())
	_begin_group()
	var snapped := 0
	for id in ids:
		var row: Dictionary = state.find_object(str(id))
		if row.is_empty() or bool(row.get("locked", false)): continue
		var current := float(row.get("yaw_deg", 0.0))
		state.set_value(str(id), "yaw_deg", roundf(current / step) * step)
		snapped += 1
	_end_group()
	_status("Snapped %d object(s) onto %s° steps." % [snapped, ("%.1f" % step)])


func _open_scene_report() -> void:
	if report_dialog == null:
		report_dialog = AcceptDialog.new(); report_dialog.title = "Scene report"; add_child(report_dialog)
		report_dialog.ok_button_text = "CLOSE"
		report_text = TextEdit.new(); report_text.editable = false; report_text.custom_minimum_size = Vector2(560, 420)
		report_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		report_dialog.add_child(report_text)
		var copy := _button("COPY REPORT"); copy.pressed.connect(func (): DisplayServer.clipboard_set(report_text.text); _status("Scene report copied."))
		report_dialog.add_child(copy)
	var report := SceneReport.build(state, Version.VERSION)
	report_text.text = str(report.get("text", ""))
	report_dialog.popup_centered(Vector2i(640, 520))
	_status("Scene report: %d thing(s) to look at." % int(report.get("issues", 0)))

func _open_route_check() -> void:
	if route_dialog == null:
		route_dialog = AcceptDialog.new(); route_dialog.title = "Route check against the ground"; add_child(route_dialog)
		route_dialog.ok_button_text = "CLOSE"
		route_text = TextEdit.new(); route_text.editable = false; route_text.custom_minimum_size = Vector2(520, 340)
		route_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		route_dialog.add_child(route_text)
	var result := Routes.check(state)
	route_text.text = Routes.report(result)
	route_dialog.popup_centered(Vector2i(600, 440))
	var counts := Routes.counts(result)
	_status("Routes: %d fail, %d warn, %d note." % [int(counts.fail), int(counts.warn), int(counts.note)])


func _model_stats_tip(id: String, category: String) -> String:
	if category != "model" or not state.custom_assets.has(id): return " · drag into either view or click to add at the center."
	var entry: Dictionary = state.custom_assets[id]
	var bytes: PackedByteArray = entry.get("bytes", PackedByteArray())
	var codec_stats := Codec.stats(bytes)
	if not bool(codec_stats.get("ok", false)):
		return " · %.1f MB · drag into either view or click to add at the center." % [float(bytes.size()) / 1048576.0]
	var parts: Array = ["%.1f MB" % [float(bytes.size()) / 1048576.0]]
	parts.append("%d triangle(s)" % int(codec_stats.triangles))
	if int(codec_stats.textures) > 0: parts.append("%d texture(s)" % int(codec_stats.textures))
	if int(codec_stats.materials) > 0: parts.append("%d material(s)" % int(codec_stats.materials))
	if int(codec_stats.animations) > 0: parts.append("%d animation(s)" % int(codec_stats.animations))
	if bool(codec_stats.skinned): parts.append("skinned")
	return " · " + " · ".join(parts)
