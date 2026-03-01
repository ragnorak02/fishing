extends Node

var gold: int = 50  # Starting gold
var current_haul: Array = []  # Fish caught this dive [{species, weight, value}]
var fish_storage: Array = []  # Fish kept across dives

var active_menu: Array[String] = []  # Recipe IDs on tonight's menu (max 4)
var unlocked_recipes: Array[String] = []

signal gold_changed(new_amount: int)
signal haul_changed()
signal storage_changed()
signal fish_sold(gold_earned: int)
signal menu_changed()
signal recipes_changed()

func add_to_haul(species_id: String, weight: float) -> void:
	var species = FishDatabase.get_species(species_id)
	if species == null:
		return
	var value := int(species.base_value * (weight / species.weight_range.y))
	value = maxi(value, 1)
	current_haul.append({
		"species_id": species_id,
		"name": species.display_name,
		"weight": weight,
		"value": value,
		"rarity": species.rarity,
		"sushi_grade": species.sushi_grade,
	})
	haul_changed.emit()

func sell_fish_from_haul(index: int) -> void:
	if index < 0 or index >= current_haul.size():
		return
	var fish = current_haul[index]
	gold += fish.value
	current_haul.remove_at(index)
	gold_changed.emit(gold)
	haul_changed.emit()
	fish_sold.emit(fish.value)

func keep_fish_from_haul(index: int) -> void:
	if index < 0 or index >= current_haul.size():
		return
	var fish = current_haul[index]
	fish_storage.append(fish)
	current_haul.remove_at(index)
	haul_changed.emit()
	storage_changed.emit()

func sell_all_haul() -> void:
	var total := 0
	for fish in current_haul:
		total += fish.value
	gold += total
	current_haul.clear()
	gold_changed.emit(gold)
	haul_changed.emit()
	if total > 0:
		fish_sold.emit(total)

func keep_all_haul() -> void:
	fish_storage.append_array(current_haul)
	current_haul.clear()
	haul_changed.emit()
	storage_changed.emit()

func sell_from_storage(index: int) -> void:
	if index < 0 or index >= fish_storage.size():
		return
	var fish = fish_storage[index]
	gold += fish.value
	fish_storage.remove_at(index)
	gold_changed.emit(gold)
	storage_changed.emit()
	fish_sold.emit(fish.value)

func sell_all_storage() -> void:
	var total := 0
	for fish in fish_storage:
		total += fish.value
	gold += total
	fish_storage.clear()
	gold_changed.emit(gold)
	storage_changed.emit()
	if total > 0:
		fish_sold.emit(total)

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

func clear_haul() -> void:
	current_haul.clear()
	haul_changed.emit()

func get_fish_count_by_species(species_id: String) -> int:
	var count := 0
	for fish in fish_storage:
		if fish.species_id == species_id:
			count += 1
	return count

func toggle_recipe_on_menu(recipe_id: String) -> bool:
	if recipe_id in active_menu:
		active_menu.erase(recipe_id)
		menu_changed.emit()
		return false  # Removed
	if active_menu.size() >= 4:
		return false  # Full
	active_menu.append(recipe_id)
	menu_changed.emit()
	return true  # Added

func consume_ingredients_for_recipe(recipe_id: String) -> bool:
	var recipe := RecipeDatabase.get_recipe(recipe_id)
	if recipe == null:
		return false
	# Check availability first
	for ingredient in recipe.ingredients:
		if get_fish_count_by_species(ingredient.species_id) < ingredient.quantity:
			return false
	# Consume
	for ingredient in recipe.ingredients:
		var remaining := ingredient.quantity
		var i := fish_storage.size() - 1
		while i >= 0 and remaining > 0:
			if fish_storage[i].species_id == ingredient.species_id:
				fish_storage.remove_at(i)
				remaining -= 1
			i -= 1
	storage_changed.emit()
	return true

func unlock_recipe(recipe_id: String) -> void:
	if recipe_id not in unlocked_recipes:
		unlocked_recipes.append(recipe_id)
		recipes_changed.emit()
