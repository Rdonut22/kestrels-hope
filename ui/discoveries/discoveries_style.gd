class_name DiscoveriesStyle
extends RefCounted

## Shared look for Discoveries, the HUD objective notifications and the
## compass markers, from the approved design: ivory text and linework,
## amber for Tasks, green for Missions (one colour per category, never per
## objective). Text is Barlow Condensed (ui/fonts, OFL), as in the design.

const IVORY := Color("#EFE6D6")
const IVORY_DIM := Color("#D6C3A3")
const LINE := Color("#8C7F6B")
const AMBER := Color("#F7A92B")
const GREEN := Color("#79B85A")

static var _ui_fonts := {}
static var _plates := {}


## Barlow Condensed at a weight (400, 500, 600), with extra letter spacing
## in pixels (the design's caps are spaced out).
static func ui_font(weight := 500, spacing := 0) -> Font:
	var key := "%d/%d" % [weight, spacing]
	if not _ui_fonts.has(key):
		var base: Font = load("res://ui/fonts/barlow-condensed-latin-%d-normal.woff2" % weight)
		if spacing == 0:
			_ui_fonts[key] = base
		else:
			var v := FontVariation.new()
			v.base_font = base
			v.spacing_glyph = spacing
			_ui_fonts[key] = v
	return _ui_fonts[key]


## A texture as a nine-patch style box (corner margin in its pixels), to
## stretch the design's buttons and badges to any width.
static func plate(tex: Texture2D, margin: float, margin_right := -1.0) -> StyleBoxTexture:
	var key := "%s/%s/%s" % [tex.resource_path, margin, margin_right]
	if not _plates.has(key):
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.texture_margin_left = margin
		sb.texture_margin_top = minf(margin, tex.get_height() * 0.5 - 1)
		sb.texture_margin_bottom = minf(margin, tex.get_height() * 0.5 - 1)
		sb.texture_margin_right = margin if margin_right < 0.0 else margin_right
		_plates[key] = sb
	return _plates[key]


static func color(category: String) -> Color:
	return GREEN if category == "mission" else AMBER


static func noun(category: String) -> String:
	return "MISSION" if category == "mission" else "TASK"


## Text cut to fit `width`, with an ellipsis.
static func fit(text: String, f: Font, size: int, width: float) -> String:
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
		return text
	var t := text
	while t.length() > 1 and f.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		t = t.left(t.length() - 1)
	return t.strip_edges() + "…"
