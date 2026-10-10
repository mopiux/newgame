class_name UITheme
## Builds the shared UI Theme: crisp pixel fonts and brass-and-wax panels.

const FONT_BODY_PATH := "res://assets/fonts/PixelifySans.ttf"
const FONT_TITLE_PATH := "res://assets/fonts/Jersey10.ttf"
const FONT_SMALL_PATH := "res://assets/fonts/Silkscreen.ttf"

const INK := Color("0b0a12")
const NIGHT := Color("161427")
const PANEL := Color("231f3a")
const PANEL_LIGHT := Color("34304f")
const BRASS := Color("b8893e")
const BRASS_LIGHT := Color("e8c170")
const BRASS_DARK := Color("4a3320")
const TEXT := Color("f2eee6")
const TEXT_DIM := Color("9493a8")
const FLAME := Color("ffc85a")
const FLAME_DEEP := Color("d9622b")
const SPECTRAL := Color("9fe0e6")
const CURSE := Color("d46aa6")

static var _theme: Theme
static var _fonts := {}


static func _font(path: String) -> FontFile:
	if _fonts.has(path):
		return _fonts[path]
	var f: FontFile = load(path)
	if f:
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		f.generate_mipmaps = false
	_fonts[path] = f
	return f


static func font_body() -> FontFile:
	return _font(FONT_BODY_PATH)


static func font_title() -> FontFile:
	return _font(FONT_TITLE_PATH)


static func font_small() -> FontFile:
	return _font(FONT_SMALL_PATH)


static func box(bg: Color, border: Color, width: int = 1, margin: int = 4, shadow: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	sb.content_margin_left = margin + 1
	sb.content_margin_right = margin + 1
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	if shadow:
		sb.shadow_color = Color(INK, 0.8)
		sb.shadow_size = 0
		sb.shadow_offset = Vector2(2, 2)
	return sb


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font_body()
	t.default_font_size = 12
	# Panels
	t.set_stylebox("panel", "PanelContainer", box(Color(PANEL, 0.96), BRASS, 1, 6, true))
	t.set_stylebox("panel", "Panel", box(Color(PANEL, 0.96), BRASS, 1, 6, true))
	# Labels
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", 0)
	t.set_constant("line_spacing", "Label", 1)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("normal_font", "RichTextLabel", font_body())
	t.set_font_size("normal_font_size", "RichTextLabel", 12)
	# Buttons
	t.set_stylebox("normal", "Button", box(PANEL_LIGHT, BRASS_DARK, 1, 3))
	t.set_stylebox("hover", "Button", box(Color("4a4766"), BRASS, 1, 3))
	t.set_stylebox("pressed", "Button", box(BRASS_DARK, BRASS_LIGHT, 1, 3))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), FLAME, 1, 3))
	t.set_stylebox("disabled", "Button", box(NIGHT, PANEL_LIGHT, 1, 3))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", BRASS_LIGHT)
	t.set_color("font_focus_color", "Button", FLAME)
	t.set_color("font_pressed_color", "Button", FLAME)
	t.set_color("font_disabled_color", "Button", TEXT_DIM)
	t.set_font_size("font_size", "Button", 12)
	# Sliders and checkboxes
	t.set_stylebox("slider", "HSlider", box(NIGHT, BRASS_DARK, 1, 2))
	t.set_stylebox("grabber_area", "HSlider", box(FLAME_DEEP, FLAME_DEEP, 0, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(FLAME, FLAME, 0, 2))
	var grabber := _pixel_texture(6, 10, BRASS_LIGHT, BRASS_DARK)
	t.set_icon("grabber", "HSlider", grabber)
	t.set_icon("grabber_highlight", "HSlider", _pixel_texture(6, 10, Color.WHITE, BRASS))
	t.set_icon("checked", "CheckBox", _check_texture(true))
	t.set_icon("unchecked", "CheckBox", _check_texture(false))
	t.set_stylebox("normal", "CheckBox", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("hover", "CheckBox", box(Color(PANEL_LIGHT, 0.6), Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("focus", "CheckBox", box(Color(0, 0, 0, 0), FLAME, 1, 2))
	t.set_stylebox("pressed", "CheckBox", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 2))
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", BRASS_LIGHT)
	t.set_color("font_focus_color", "CheckBox", FLAME)
	t.set_color("font_pressed_color", "CheckBox", TEXT)
	t.set_font_size("font_size", "CheckBox", 12)
	# LineEdit
	t.set_stylebox("normal", "LineEdit", box(NIGHT, BRASS_DARK, 1, 3))
	t.set_stylebox("focus", "LineEdit", box(NIGHT, FLAME, 1, 3))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", FLAME)
	t.set_font_size("font_size", "LineEdit", 12)
	# Scroll
	t.set_stylebox("scroll", "VScrollBar", box(NIGHT, NIGHT, 0, 1))
	t.set_stylebox("grabber", "VScrollBar", box(BRASS_DARK, BRASS_DARK, 0, 1))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(BRASS, BRASS, 0, 1))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(BRASS_LIGHT, BRASS_LIGHT, 0, 1))
	t.set_stylebox("panel", "TooltipPanel", box(NIGHT, BRASS, 1, 3))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 12)
	_theme = t
	return t


static func _pixel_texture(w: int, h: int, fill: Color, border: Color) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	for x in w:
		img.set_pixel(x, 0, border)
		img.set_pixel(x, h - 1, border)
	for y in h:
		img.set_pixel(0, y, border)
		img.set_pixel(w - 1, y, border)
	return ImageTexture.create_from_image(img)


static func _check_texture(on: bool) -> ImageTexture:
	var img := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.fill(NIGHT)
	for i in 10:
		img.set_pixel(i, 0, BRASS)
		img.set_pixel(i, 9, BRASS)
		img.set_pixel(0, i, BRASS)
		img.set_pixel(9, i, BRASS)
	if on:
		for x in range(3, 7):
			for y in range(3, 7):
				img.set_pixel(x, y, FLAME)
	return ImageTexture.create_from_image(img)


static func title_label(text: String, size: int = 20, color: Color = FLAME) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_title())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 2)
	return l


static func label(text: String, size: int = 12, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
