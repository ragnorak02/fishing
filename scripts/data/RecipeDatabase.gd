class_name RecipeDatabase
extends Node

static var _recipes: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	var dir := DirAccess.open("res://scripts/data/recipes/")
	if dir == null:
		push_error("[RecipeDatabase] Cannot open recipes directory")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var recipe: Recipe = load("res://scripts/data/recipes/" + file_name)
			if recipe:
				_recipes[recipe.id] = recipe
		file_name = dir.get_next()
	dir.list_dir_end()
	_loaded = true

static func get_recipe(id: String) -> Recipe:
	_ensure_loaded()
	return _recipes.get(id)

static func get_all_recipes() -> Array:
	_ensure_loaded()
	return _recipes.values()
