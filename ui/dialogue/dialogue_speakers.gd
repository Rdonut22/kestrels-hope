class_name DialogueSpeakers
extends RefCounted

## The one place speakers are defined: the name shown on the label, the
## colour of that name, and the portrait (or none). Every dialogue in the
## game goes through ui/dialogue/dialogue_box.gd with a speaker id from
## here; nothing assigns portraits scene by scene.
##
## Portraits are the approved references (ui/dialogue/portraits/). Each
## has a `region`: the bounds of its visible artwork in the image (alpha
## above 60, plus a small margin), so it fits the frame by what you see.
## Hale only ever gets mentioned: he has no entry and no portrait.

const DIR := "res://ui/dialogue/portraits/"
const GREEN := Color(0.62, 1.0, 0.66)
const AMBER := Color(1.0, 0.82, 0.5)

const SPEAKERS := {
	"ganna": {"name": "Gana", "portrait": "portrait_ganna.png", "region": Rect2(81, 27, 1064, 1214), "color": AMBER},
	"ganna_thoughts": {"name": "Gana · Thoughts", "portrait": "portrait_ganna.png", "region": Rect2(81, 27, 1064, 1214), "color": AMBER},
	"ganna_recording": {"name": "Gana · Recording", "portrait": "portrait_ganna.png", "region": Rect2(81, 27, 1064, 1214), "color": AMBER},
	"ship_computer": {"name": "Ship Computer", "portrait": "portrait_ship_computer.png", "region": Rect2(183, 194, 876, 881), "color": GREEN},
	"meki": {"name": "Meki", "portrait": "portrait_meki.png", "region": Rect2(67, 62, 1119, 1116), "color": GREEN},
	"farm_droid": {"name": "Farm Droid", "portrait": "portrait_farm_droid.png", "region": Rect2(1, 8, 1253, 1246), "color": GREEN},
}

static var _cache := {}


## {name, color, portrait (Texture2D or null)} for an id. An unknown id is
## shown by itself as the name, with no portrait.
static func lookup(id: String) -> Dictionary:
	if not SPEAKERS.has(id):
		return {"name": id, "color": GREEN, "portrait": null}
	var s: Dictionary = SPEAKERS[id]
	return {"name": s["name"], "color": s["color"], "portrait": portrait(id)}


static func portrait(id: String) -> Texture2D:
	if not SPEAKERS.has(id) or not SPEAKERS[id].has("portrait"):
		return null
	if not _cache.has(id):
		var s: Dictionary = SPEAKERS[id]
		var at := AtlasTexture.new()
		at.atlas = load(DIR + s["portrait"])
		at.region = s["region"]
		_cache[id] = at
	return _cache[id]
