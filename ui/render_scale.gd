extends Node

## 3D resolution cap (autoload "RenderScale"). On a big high-DPI screen (a
## Retina Mac: a 3840 px wide window) drawing the 3D world at every pixel
## costs the graphics chip four times what a 1080p screen does, for a
## difference that's hard to see at that pixel size. So the 3D world is
## drawn at most MAX_3D_WIDTH pixels across (never below half the window)
## and scaled up; menus, text and the HUD stay at full sharpness. Windows
## this wide or narrower are drawn at full resolution, as before.

const MAX_3D_WIDTH := 1920.0
const MIN_SCALE := 0.5


func _ready() -> void:
	get_tree().root.size_changed.connect(apply)
	apply()


## The 3D scale for the current window.
func auto_scale() -> float:
	var w := float(get_tree().root.size.x)
	return clampf(MAX_3D_WIDTH / maxf(w, 1.0), MIN_SCALE, 1.0)


func apply() -> void:
	get_tree().root.scaling_3d_scale = auto_scale()
