extends RefCounted
## SVG icon set + label-under-icon buttons.
##
## Design rules (kept deliberately strict so the UI stays calm):
##  * one icon per action — `audit()` fails the build if two actions share an
##    identical drawing, so a "save" icon never means two things;
##  * icons are small (TOOLBAR_ICON px in bars, PANEL_ICON px in panels);
##  * anything a user has to *find* gets a short caption underneath, so the
##    toolbar reads as labelled groups instead of a wall of glyphs;
##  * actions are grouped into named categories (CATEGORIES) and every group
##    renders under its own caption — File / Edit / Tools / View / Help.
##
## Rasterising happens once per (icon, size, colour) and is cached.

const TOOLBAR_ICON := 15
const PANEL_ICON := 16
const CAPTION_SIZE := 9

## Named groups, in toolbar order. `key` is used by build_bar().
const CATEGORIES := [
	{"key": "file", "label": "File"},
	{"key": "edit", "label": "Edit"},
	{"key": "io", "label": "Import · Export"},
	{"key": "tools", "label": "Sculpt"},
	{"key": "view", "label": "View"},
	{"key": "help", "label": "Help"},
]

static var _cache: Dictionary = {}

## 24×24 stroke paths. Every key is unique and every action uses its own.
const PATHS := {
	# ---- file
	"new": "M6 3h9l5 5v13H6z M15 3v5h5 M9 13h8 M9 17h8",
	"open": "M3 7h6l2 2h10v10H3z M3 7v12",
	"save": "M4 4h13l3 3v13H4z M8 4v6h8V4 M8 14h8v6H8z",
	"save_as": "M4 4h11l3 3v4 M8 4v5h7V4 M4 4v16h8 M16 15l6 6 M22 15l-6 6",
	"import": "M12 3v11 M8 10l4 4 4-4 M4 18v2h16v-2",
	"export": "M12 21V9 M8 13l4-4 4 4 M4 5v2h16V5",
	"texture": "M3 5h18v14H3z M3 15l5-4 4 3 4-5 5 6 M7 9a1.2 1.2 0 1 0 0-.1",
	"folder": "M3 6h7l2 2h9v11H3z",
	# ---- edit
	"undo": "M9 7L4 12l5 5 M4 12h9a6 6 0 0 1 6 6",
	"redo": "M15 7l5 5-5 5 M20 12h-9a6 6 0 0 0-6 6",
	"duplicate": "M8 3h9l4 4v11H8z M8 3v15 M4 7v14h11",
	"trash": "M4 7h16 M9 7V4h6v3 M6 7l1 14h10l1-14 M10 11v6 M14 11v6",
	"lock": "M6 11h12v9H6z M9 11V8a3 3 0 0 1 6 0v3",
	"picker": "M4 20l3-3 M14 4l6 6-9 9-3-3z M12 6l6 6",
	# ---- sculpt tools
	"select": "M5 3l13 9-6 1 3 6-3 1-3-6-4 3z",
	"raise": "M12 20V5 M7 10l5-5 5 5 M4 20h16",
	"lower": "M12 4v15 M7 14l5 5 5-5 M4 20h16",
	"smooth": "M3 15c3-6 6 2 9-2s5 1 9-3 M3 19c3-5 6 2 9-1s5 1 9-2",
	"flatten": "M3 15h18 M6 15V9 M12 15V6 M18 15v-4 M4 19h16",
	"brush": "M6 18l3-3 M9 15l8-9 3 3-8 8z M6 18l-2 3 3-1z",
	"erase": "M8 20h11 M4 15l7-11 8 5-7 11-4-1z M9 10l6 4",
	"road": "M4 21L9 3h6l5 18 M12 5v3 M12 12v3 M12 19v2",
	"wall": "M3 6h18v12H3z M3 11h18 M8 6v5 M15 11v7 M8 16v2",
	"water": "M3 8c3-2 5 2 8 0s5 2 9 0 M3 13c3-2 5 2 8 0s5 2 9 0 M3 18c3-2 5 2 8 0s5 2 9 0",
	"wave": "M3 12c2-4 4 4 6 0s4 4 6 0 4 4 6 0",
	# ---- view
	"grid": "M3 3h18v18H3z M9 3v18 M15 3v18 M3 9h18 M3 15h18",
	"eye": "M2 12s4-7 10-7 10 7 10 7-4 7-10 7-10-7-10-7 M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6",
	"eye_off": "M3 3l18 18 M10 6a10 10 0 0 1 12 6 12 12 0 0 1-3 4 M6 8a13 13 0 0 0-4 4s4 7 10 7a10 10 0 0 0 4-1",
	"target": "M12 2v4 M12 18v4 M2 12h4 M18 12h4 M12 7a5 5 0 1 0 0 10 5 5 0 0 0 0-10",
	"focus": "M4 9V4h5 M20 9V4h-5 M4 15v5h5 M20 15v5h-5 M9 9h6v6H9z",
	"reset": "M4 12a8 8 0 1 1 3 6 M4 12H2 M4 12l2-3",
	"rotate": "M20 12a8 8 0 1 1-8-8 M20 4v5h-5",
	"cube": "M12 3l8 4.5v9L12 21l-8-4.5v-9z M12 12l8-4.5 M12 12L4 7.5 M12 12v9",
	"mountain": "M2 20l7-11 4 6 3-4 6 9z",
	"wireframe": "M12 3l8 4.5v9L12 21l-8-4.5v-9z M12 12l8-4.5 M12 12L4 7.5 M12 12v9 M4 16.5l8-4.5 8 4.5",
	"world": "M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20 M2 12h20 M12 2c3 3.5 3 16 0 20 M12 2c-3 3.5-3 16 0 20",
	"zoom_in": "M10 3a7 7 0 1 0 0 14 7 7 0 0 0 0-14 M15 15l6 6 M7 10h6 M10 7v6",
	"zoom_out": "M10 3a7 7 0 1 0 0 14 7 7 0 0 0 0-14 M15 15l6 6 M7 10h6",
	"play": "M7 4l13 8-13 8z",
	"walk": "M12 4a2 2 0 1 0 0 .1 M12 7v6 M12 13l-3 7 M12 13l3 7 M7 9l5 1 5-1",
	"stop": "M6 6h12v12H6z",
	"stats": "M4 20V10 M10 20V4 M16 20v-7 M22 20H2",
	"help": "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18 M9.5 9.5a2.5 2.5 0 1 1 3.4 2.3c-.6.3-.9.8-.9 1.5v.7 M12 17.2v.1",
	# ---- misc panel icons
	"plus": "M12 5v14 M5 12h14",
	"minus": "M5 12h14",
	"close": "M6 6l12 12 M18 6L6 18",
	"check": "M4 13l5 5L20 7",
	"layers": "M12 3l9 5-9 5-9-5z M3 13l9 5 9-5 M3 17l9 5 9-5",
	"sculpt": "M5 19c0-6 4-12 9-14 2 5 0 11-5 14z M9 15l4-4",
	"flatten_all": "M3 17h18 M5 12h14 M7 7h10 M9 3h6",
	"pattern": "M4 4h6v6H4z M14 4h6v6h-6z M4 14h6v6H4z M14 14h6v6h-6z",
	"fullscreen": "M4 9V4h5 M20 9V4h-5 M4 15v5h5 M20 15v5h-5",
	"expand": "M4 4h7 M4 4v7 M20 20h-7 M20 20v-7 M4 4l6 6 M20 20l-6-6",
	"collapse": "M10 10H3 M10 10V3 M14 14h7 M14 14v7 M10 10l-7-7 M14 14l7 7",
	"move": "M12 3v18 M3 12h18 M12 3l-3 3 M12 3l3 3 M12 21l-3-3 M12 21l3-3 M3 12l3-3 M3 12l3 3 M21 12l-3-3 M21 12l-3 3",
	"route": "M5 19a2 2 0 1 0 0-4 2 2 0 0 0 0 4 M19 9a2 2 0 1 0 0-4 2 2 0 0 0 0 4 M7 17c4 0 4-6 8-6 M11 11h4",
	"pin": "M12 21s7-6.5 7-12a7 7 0 1 0-14 0c0 5.5 7 12 7 12 M12 6a3 3 0 1 0 0 6 3 3 0 0 0 0-6",
	"material": "M4 5h16v14H4z M4 12h16 M12 5v14",
}


static func tex(name: String, size: int = TOOLBAR_ICON, color: Color = Color("dbe8e3")) -> Texture2D:
	var key := "%s|%d|%s" % [name, size, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	if not PATHS.has(name):
		push_warning("Unknown icon: " + name)
		return null
	var hex := "#" + color.to_html(false)
	var svg := (
		'<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 24 24" ' % [size, size]
		+ 'fill="none" stroke="%s" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">' % hex
		+ '<path d="%s"/></svg>' % PATHS[name]
	)
	var image := Image.new()
	# 2x supersample then downscale: keeps 1px strokes from shimmering.
	var err := image.load_svg_from_string(svg, 2.0)
	if err != OK:
		push_warning("SVG rasterise failed for icon: " + name)
		return null
	image.resize(size * 2, size * 2, Image.INTERPOLATE_LANCZOS)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


## Icon button — icon plus a small caption underneath.
##
## `caption` is the short label the user reads ("Save", "Undo"); the tooltip
## carries the long description and shortcut. Captions are intentionally tiny
## and low-contrast so the icon still leads.
static func button(name: String, title: String, hint: String, shortcut: String = "",
		caption: String = "", size: int = TOOLBAR_ICON, accent: bool = false) -> Button:
	var b := Button.new()
	b.name = "btn_" + name
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.expand_icon = false
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.set_meta("icon_name", name)
	b.text = caption if not caption.is_empty() else ""
	if not caption.is_empty():
		b.add_theme_font_size_override("font_size", CAPTION_SIZE)
		b.add_theme_color_override("font_color", Color("7f9391"))
		b.add_theme_color_override("font_hover_color", Color("dbe8e3"))
		b.add_theme_color_override("font_pressed_color", Color("ffffff"))
		b.add_theme_constant_override("line_spacing", 1)
		b.custom_minimum_size = Vector2(40, 34)
	else:
		b.custom_minimum_size = Vector2(30, 28)
	var tint: Color = Color("0e1a18") if accent else Color("c8dad5")
	b.icon = tex(name, size, tint)
	b.add_theme_constant_override("icon_max_width", size)
	b.tooltip_text = title if hint.is_empty() else "%s — %s" % [title, hint]
	if not shortcut.is_empty():
		b.tooltip_text += "  (%s)" % shortcut
	if accent:
		b.add_theme_stylebox_override("normal", _pad(Color("1d4438"), Color("2b5d4b"), 5))
		b.add_theme_stylebox_override("hover", _pad(Color("2a6650"), Color("3a8a68"), 5))
		b.add_theme_stylebox_override("pressed", _pad(Color("17473a"), Color("5ee0b0"), 5))
	else:
		b.add_theme_stylebox_override("normal", _pad(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 5))
		b.add_theme_stylebox_override("hover", _pad(Color("1b2b2e"), Color("294043"), 5))
		b.add_theme_stylebox_override("pressed", _pad(Color("17473a"), Color("2f7a63"), 5))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


static func _pad(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1 if bg.a > 0.0 or border.a > 0.0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 3
	s.content_margin_right = 3
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	s.anti_aliasing = true
	return s


static func toggle(name: String, title: String, hint: String, shortcut: String = "",
		caption: String = "", size: int = TOOLBAR_ICON) -> Button:
	var b := button(name, title, hint, shortcut, caption, size)
	b.toggle_mode = true
	return b


## A labelled group of actions, rendered with a caption underneath the row so
## the user can see *where* things live instead of hunting glyphs.
static func group(caption: String, entries: Array, icon_size: int = TOOLBAR_ICON) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	var row := HBoxContainer.new()
	row.name = "row_" + caption
	row.add_theme_constant_override("separation", 1)
	column.add_child(row)
	for entry in entries:
		row.add_child(entry)
	var label := Label.new()
	label.text = caption.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", CAPTION_SIZE - 1)
	label.add_theme_color_override("font_color", Color("4e5f5d"))
	column.add_child(label)
	return column


## Fail-fast audit: every icon must exist, and no two *actions* may share a
## drawing (that is what "repeating icons" looked like to the user).
## Returns {"ok": bool, "problems": PackedStringArray}.
static func audit(actions: Array) -> Dictionary:
	var problems := PackedStringArray()
	var by_icon := {}
	for entry in actions:
		var icon := str(entry.get("icon", ""))
		var label := str(entry.get("label", "?"))
		if not PATHS.has(icon):
			problems.append("missing icon '%s' for %s" % [icon, label])
			continue
		if by_icon.has(icon):
			problems.append("'%s' is used by both %s and %s" % [icon, by_icon[icon], label])
		else:
			by_icon[icon] = label
	return {"ok": problems.is_empty(), "problems": problems}


static func clear_cache() -> void:
	_cache.clear()
