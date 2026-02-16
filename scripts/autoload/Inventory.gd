extends Node

var gold: int = 50  # Starting gold
var current_haul: Array = []  # Fish caught this dive [{species, weight, value}]
var fish_storage: Array = []  # Fish kept across dives

signal gold_changed(new_amount: int)
signal haul_changed()
signal storage_changed()

func add_to_haul(species_id: String, weight: float) -> void:
	var species = FishDatabase.get_species(species_id)
	if species == null:
		return
	var value := int(species.base_value * (weight / species.weight_range.y))
	value = max(value, 1)
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

func sell_all_storage() -> void:
	var total := 0
	for fish in fish_storage:
		total += fish.value
	gold += total
	fish_storage.clear()
	gold_changed.emit(gold)
	storage_changed.emit()

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

func clear_haul() -> void:
	current_haul.clear()
	haul_changed.emit()
