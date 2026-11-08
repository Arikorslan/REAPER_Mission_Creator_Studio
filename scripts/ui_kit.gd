extends RefCounted
## Central design system: palette, typography, spacing and control factories.
## Every panel in the studio is built from these helpers so the look stays
## consistent and a future re-skin is a single-file change.

# ---------------------------------------------------------------- palette ---
const BG := Color("0b1113")            # app background
const PANEL := Color("141d1f")         # panel body
const PANEL_ALT := Color("1a2528")     # raised rows, inputs
const PANEL_HI := Color("22303445")    # translucent overlay
const LINE := Color("27383b")          # hairline borders
const LINE_HI := Color("3b565a")
const TEXT := Color("e6f1ec")
const MUTED := Color("8fa8a2")
const DIM := Color("63807b")
const ACCENT := Color("5ee0b0")        # primary accent (selection, active tool)
const ACCENT_DIM := Color("2f7d64")
const WARN := Color("f2c46d")
const DANGER := Color("ef7a7a")
const INFO := Color("7fc7ff")

const FONT_S := 11
const FONT_M := 13
const FONT_L := 15
const FONT_XL := 19

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = FONT_M
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_color", "TextEdit", TEXT)
	t.set_color("font_color", "SpinBox", TEXT)
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_color", "Tree", TEXT)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_shadow_color", "TooltipLabel", Color(0, 0, 0, 0.6))
	t.set_stylebox("panel", "TooltipPanel", flat(Color("0a1012f2"), LINE_HI, 6, 1, 8, 8, 6, 6))
	t.set_stylebox("panel", "PopupMenu", flat(PANEL_ALT, LINE_HI, 7, 1, 4, 4, 4, 4))
	t.set_stylebox("hover", "PopupMenu", flat(Color("24363a")))
	t.set_font_size("font_size", "TooltipLabel", FONT_S + 1)
	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("separation", "HBoxContainer", 6)
	t.set_constant("outline_size", "Label", 0)
	t.set_stylebox("normal", "Tree", flat(PANEL_ALT, LINE, 5, 1, 4, 4, 4, 4))
	t.set_stylebox("focus", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("selected", "Tree", flat(Color("1f4a3f"), ACCENT_DIM, 0, 1, 0, 0, 2, 2))
	t.set_stylebox("selected_focus", "Tree", flat(Color("255a4b"), ACCENT, 0, 1, 0, 0, 2, 2))
	t.set_stylebox("title_button_normal", "Tree", flat(Color("1b272a")))
	t.set_color("font_selected_color", "Tree", Color("ffffff"))
	_theme = t
	return t


## Rounded flat style used everywhere.
static func flat(bg: Color, border: Color = LINE, radius: int = 5, border_width: int = 1,
		pad_x: int = 9, pad_y: int = 5, margin_x: int = -1, margin_y: int = -1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	if border_width > 0:
		s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_x if margin_x < 0 else margin_x
	s.content_margin_right = pad_x if margin_x < 0 else margin_x
	s.content_margin_top = pad_y if margin_y < 0 else margin_y
	s.content_margin_bottom = pad_y if margin_y < 0 else margin_y
	s.anti_aliasing = true
	return s


# --------------------------------------------------------------- factories --
static func label(text: String, size: int = FONT_M, color: Color = TEXT) -> Label:
	var n := Label.new()
	n.text = text
	n.add_theme_font_size_override("font_size", size)
	n.add_theme_color_override("font_color", color)
	return n


static func section(title: String, icon_name: String = "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	if not icon_name.is_empty():
		var icon := TextureRect.new()
		icon.texture = preload("res://scripts/studio_icons.gd").tex(icon_name, 14, ACCENT)
		icon.custom_minimum_size = Vector2(14, 14)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
	var l := label(title.to_upper(), FONT_S + 1, ACCENT)
	l.add_theme_constant_override("outline_size", 0)
	row.add_child(l)
	row.add_theme_constant_override("separation", 6)
	return row


static func hint(text: String) -> Label:
	var n := label(text, FONT_S, MUTED)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return n


static func panel(pad: int = 10, bg: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(bg, LINE, 8, 1, pad, pad, pad, pad))
	return p


static func button(text: String = "", accent: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 28
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := Color("1f2f31") if not accent else Color("1d4438")
	var hover := Color("2b4245") if not accent else Color("2a6650")
	b.add_theme_stylebox_override("normal", flat(normal, LINE, 5, 1, 10, 5))
	b.add_theme_stylebox_override("hover", flat(hover, LINE_HI, 5, 1, 10, 5))
	b.add_theme_stylebox_override("pressed", flat(Color("17473a"), ACCENT, 5, 1, 10, 5))
	b.add_theme_stylebox_override("disabled", flat(Color("1a2325"), LINE, 5, 1, 10, 5))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_disabled_color", DIM)
	b.add_theme_font_size_override("font_size", FONT_M)
	return b


static func toggle(text: String, accent: bool = false) -> Button:
	var b := button(text, accent)
	b.toggle_mode = true
	b.add_theme_stylebox_override("pressed", flat(Color("1d5342"), ACCENT, 5, 1, 10, 5))
	return b


static func spin(lo: float, hi: float, step: float, value: float = 0.0, suffix: String = "") -> SpinBox:
	var b := SpinBox.new()
	b.min_value = lo
	b.max_value = hi
	b.step = step
	b.value = clampf(value, lo, hi)
	b.allow_greater = false
	b.allow_lesser = false
	b.custom_minimum_size.y = 28
	b.suffix = suffix
	b.select_all_on_focus = true
	b.add_theme_font_size_override("font_size", FONT_M)
	var line := flat(PANEL_ALT, LINE, 5, 1, 8, 4)
	b.get_line_edit().add_theme_stylebox_override("normal", line)
	b.get_line_edit().add_theme_stylebox_override("focus", flat(PANEL_ALT, ACCENT_DIM, 5, 1, 8, 4))
	return b


static func line_edit(placeholder: String = "") -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.custom_minimum_size.y = 28
	e.add_theme_stylebox_override("normal", flat(PANEL_ALT, LINE, 5, 1, 8, 4))
	e.add_theme_stylebox_override("focus", flat(PANEL_ALT, ACCENT_DIM, 5, 1, 8, 4))
	return e


static func option(items: Array = []) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.custom_minimum_size.y = 28
	o.add_theme_stylebox_override("normal", flat(PANEL_ALT, LINE, 5, 1, 8, 4))
	o.add_theme_stylebox_override("hover", flat(Color("26373a"), LINE_HI, 5, 1, 8, 4))
	o.add_theme_stylebox_override("pressed", flat(Color("26373a"), ACCENT_DIM, 5, 1, 8, 4))
	o.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for item in items:
		o.add_item(str(item))
	return o


static func check(text: String) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", FONT_M)
	c.add_theme_color_override("font_color", TEXT)
	return c


static func field(parent: Container, title: String, control: Control, hint_text: String = "") -> void:
	var lbl := label(title, FONT_S, MUTED)
	if not hint_text.is_empty():
		lbl.tooltip_text = hint_text
	parent.add_child(lbl)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(control)


static func spacer(w: int = 0, h: int = 0) -> Control:
	var c := Control.new()
	if w > 0:
		c.custom_minimum_size.x = w
		c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if h > 0:
		c.custom_minimum_size.y = h
	if w == 0 and h == 0:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func separator() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_stylebox_override("separator", flat(LINE, Color(0, 0, 0, 0), 0, 0, 0, 0, 0, 4))
	s.add_theme_constant_override("separation", 8)
	return s


static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


static func badge(text: String, color: Color = ACCENT) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(Color(color.r, color.g, color.b, 0.14), Color(color.r, color.g, color.b, 0.5), 4, 1, 6, 1))
	var l := label(text, FONT_S, color)
	p.add_child(l)
	return p
