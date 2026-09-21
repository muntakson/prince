class_name TextStyle
extends RefCounted
## Shared look for text drawn over game backdrops (level hints, cutscene
## captions, station name prompts, HUD title/flash cards): light text with a
## dark outline on a dark translucent rounded panel, so it stays readable on
## bright backgrounds such as the Chapter 4 cytoplasm.

const PANEL_BG := Color(0.03, 0.05, 0.12, 0.8)
const PANEL_BORDER := Color(0.45, 0.65, 0.95, 0.55)

static func panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

## Style `l`. With `hug` the label shrinks to its text and stays centred on
## the x-centre it had before (for one-line prompts whose text is set once).
static func apply(l: Label, size: int, color: Color, hug := false) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_stylebox_override("normal", panel())
	if hug:
		var cx := l.position.x + l.size.x * 0.5
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.size = Vector2.ZERO
		l.reset_size()
		l.position.x = cx - l.size.x * 0.5
