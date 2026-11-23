class_name Objectives
extends RefCounted

## Every objective definition (ObjectiveDef), loaded once from
## discoveries/objectives/*.tres and looked up by id.

const DIR := "res://discoveries/objectives/"
const CATEGORIES := ["mission", "task"]

static var _defs := {}
static var _loaded := false


static func all() -> Dictionary:
	if not _loaded:
		_loaded = true
		for f in DirAccess.get_files_at(DIR):
			# Exported builds list "x.tres.remap".
			var file := f.trim_suffix(".remap")
			if file.ends_with(".tres") or file.ends_with(".res"):
				var def := load(DIR + file) as ObjectiveDef
				if def and def.id != "":
					_defs[def.id] = def
				else:
					push_warning("Objectives: %s isn't an ObjectiveDef with an id" % file)
	return _defs


static func get_def(id: String) -> ObjectiveDef:
	return all().get(id)


## Add a definition from code (for tests, or objectives built at run time).
static func register(def: ObjectiveDef) -> void:
	all()[def.id] = def


static func unregister(id: String) -> void:
	all().erase(id)


## World position of an objective's destination in the current scene, or
## null when it has none (or it isn't in this scene).
static func waypoint(id: String, tree: SceneTree) -> Variant:
	var def := get_def(id)
	if def == null or def.waypoint_node.is_empty() or tree == null or tree.current_scene == null:
		return null
	var scene := tree.current_scene
	if def.waypoint_scene != "" and scene.scene_file_path != def.waypoint_scene:
		return null
	var n := scene.get_node_or_null(def.waypoint_node) as Node3D
	if n == null:
		return null
	return n.to_global(def.waypoint_offset)
