class_name GlassPanel
extends PanelContainer

## A frosted-glass panel for the cooking HUD (cooking/glass.gdshader): lay
## out children in it like any PanelContainer. States: set `glow` (amber
## when selected), `rim` (brighter on hover), `hatch` (unavailable).

const SHADER := preload("res://cooking/glass.gdshader")
const MARGIN := 18.0

@export var radius := 16.0
@export var padding := 12.0

var _glass: ColorRect
var _mat: ShaderMaterial


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_glass = ColorRect.new()
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass.material = _mat
	# Internal: drawn behind the content and not laid out with it.
	add_child(_glass, false, Node.INTERNAL_MODE_FRONT)
	resized.connect(_fit)


func _ready() -> void:
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(padding)
	add_theme_stylebox_override("panel", sb)
	_mat.set_shader_parameter("radius", radius)
	_mat.set_shader_parameter("margin", MARGIN)
	_fit()


func _fit() -> void:
	_glass.position = -Vector2.ONE * MARGIN
	_glass.size = size + Vector2.ONE * MARGIN * 2.0
	_mat.set_shader_parameter("size", size)


func set_param(p: String, v: Variant) -> void:
	_mat.set_shader_parameter(p, v)


func set_glow(c: Color) -> void:
	_mat.set_shader_parameter("glow", c)


func set_rim(c: Color) -> void:
	_mat.set_shader_parameter("rim", c)


func set_hatch(on: bool) -> void:
	_mat.set_shader_parameter("hatch", 1.0 if on else 0.0)
