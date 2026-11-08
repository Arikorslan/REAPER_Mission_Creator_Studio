extends Control



const Version = preload("res://scripts/version.gd")

var _age := 0.0
var _lifetime := 2.4
var _closing := false
var _panel: PanelContainer
var _art: Control
var _phase := 0.0

func setup(lifetime: float = 2.4) -> void:
	_lifetime = maxf(0.6, lifetime)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build()
	modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.28)

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("0d1116")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	_art = Control.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.draw.connect(_draw_art)
	add_child(_art)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.1, 0.92)
	style.border_color = Color("3ad4a4")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 18
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = Vector2(560, 0)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)

	var title := Label.new()
	title.text = Version.NAME
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("eaf7f1"))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = Version.splash_subtitle()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color("3ad4a4"))
	column.add_child(subtitle)

	var rule := HSeparator.new()
	column.add_child(rule)

	for line in Version.highlights():
		var row := Label.new()
		row.text = "• " + str(line)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_theme_font_size_override("font_size", 13)
		row.add_theme_color_override("font_color", Color("b7c4c0"))
		column.add_child(row)

	var hint := Label.new()
	hint.text = "Tap, click or press a key to begin"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color("6d7b78"))
	column.add_child(hint)

func _draw_art() -> void:
	if _art == null:
		return
	var area := _art.size
	var centre := area * 0.5

	var bands := 7
	for i in bands:
		var t := float(i) / float(bands)
		var y := area.y * (0.62 + 0.055 * t)
		var colour := Color("111a1f").lerp(Color("0a0e11"), t)
		_art.draw_rect(Rect2(0, y, area.x, area.y * 0.06 + 2.0), colour)

	var radius := minf(area.x, area.y) * 0.42
	_art.draw_arc(centre, radius, 0.0, TAU, 96, Color(0.23, 0.83, 0.64, 0.3), 2.0, true)
	_art.draw_arc(centre, radius * 0.66, 0.0, TAU, 96, Color(0.23, 0.83, 0.64, 0.2), 1.5, true)
	_art.draw_arc(centre, radius * 0.33, 0.0, TAU, 96, Color(0.23, 0.83, 0.64, 0.14), 1.0, true)
	for i in 4:
		var angle := _phase + float(i) * TAU / 4.0
		var point := centre + Vector2(cos(angle), sin(angle)) * radius
		_art.draw_circle(point, 3.5, Color(0.35, 0.95, 0.75, 0.85))
	var sweep := centre + Vector2(cos(_phase), sin(_phase)) * radius
	_art.draw_line(centre, sweep, Color(0.35, 0.95, 0.75, 0.45), 2.0, true)

func _process(delta: float) -> void:
	_age += delta
	_phase += delta * 0.9
	if _art != null:
		_art.queue_redraw()
	if _closing:
		return
	if _age >= _lifetime:
		dismiss()

func _input(event: InputEvent) -> void:
	if _closing:
		return
	if event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch:
		dismiss()

func dismiss() -> void:
	if _closing:
		return
	_closing = true
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.25)
	tween.tween_callback(queue_free)
