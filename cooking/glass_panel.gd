class_name GlassPanel
extends PanelContainer

## A frosted-glass panel for the cooking HUD (cooking/glass.gdshader): lay
## out children in it like any PanelContainer. The glass is the panel's own
## style box, drawn through the shader (its children keep their own look).
## States: set_glow (amber when selected), set_rim (brighter on hover),
## set_hatch (unavailable).

const SHADER := preload("res://cooking/glass.gdshader")
const MARGIN := 18.0

@export var radius := 16.0
@export var padding := 12.0

var _mat: ShaderMaterial


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	resized.connect(_fit)


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_expand_margin_all(MARGIN)
	sb.set_content_margin_all(padding)
	add_theme_stylebox_override("panel", sb)
	_mat.set_shader_parameter("radius", radius)
	_mat.set_shader_parameter("margin", MARGIN)
	_fit()


func _fit() -> void:
	_mat.set_shader_parameter("size", size)


func set_param(p: String, v: Variant) -> void:
	_mat.set_shader_parameter(p, v)


func set_glow(c: Color) -> void:
	_mat.set_shader_parameter("glow", c)


func set_rim(c: Color) -> void:
	_mat.set_shader_parameter("rim", c)


func set_hatch(on: bool) -> void:
	_mat.set_shader_parameter("hatch", 1.0 if on else 0.0)
