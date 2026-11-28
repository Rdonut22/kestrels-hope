class_name Cookbook
extends RefCounted

## The cooking data (cooking/data/*.tres): every ingredient and recipe, and
## matching a vessel's contents to the dish they make.

const DATA_DIR := "res://cooking/data/"

static var _ingredients := {}
static var _recipes: Array[CookRecipe] = []


static func _load() -> void:
	if not _ingredients.is_empty() or not _recipes.is_empty():
		return
	for file in ResourceLoader.list_directory(DATA_DIR):
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var r := load(DATA_DIR + file)
		if r is CookIngredient:
			_ingredients[(r as CookIngredient).id] = r
		elif r is CookRecipe:
			_recipes.append(r)


static func ingredient(id: String) -> CookIngredient:
	_load()
	return _ingredients.get(id)


static func ingredients() -> Array:
	_load()
	return _ingredients.values()


static func recipes() -> Array[CookRecipe]:
	_load()
	return _recipes


## The recipe a vessel's contents make, or null: every ingredient it needs
## is there (nothing else), it's the recipe's vessel, and each condition
## holds (`state` maps condition names to values, e.g. {"water_hot": true}).
static func match_recipe(vessel: String, contents: Array, state: Dictionary) -> CookRecipe:
	_load()
	var have := {}
	for c in contents:
		have[c] = true
	for r in _recipes:
		if r.vessel != vessel or r.ingredients.size() != have.size():
			continue
		var ok := true
		for need in r.ingredients:
			if not have.has(need):
				ok = false
				break
		for cond in r.conditions:
			if state.get(cond) != r.conditions[cond]:
				ok = false
		if ok:
			return r
	return null
