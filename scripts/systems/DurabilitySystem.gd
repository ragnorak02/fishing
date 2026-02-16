class_name DurabilitySystem
extends Node
## Hull HP system with damage-on-collision and destroyed signal.

const BASE_MAX_DURABILITY := 100.0

var max_durability: float = BASE_MAX_DURABILITY
var current_durability: float = BASE_MAX_DURABILITY

signal durability_changed(current: float, maximum: float)
signal hull_destroyed

func _ready() -> void:
	max_durability = BASE_MAX_DURABILITY * GameManager.get_durability_multiplier()
	current_durability = max_durability

func take_damage(amount: float) -> void:
	current_durability = maxf(current_durability - amount, 0.0)
	durability_changed.emit(current_durability, max_durability)

	if current_durability <= 0.0:
		hull_destroyed.emit()

func repair(amount: float) -> void:
	current_durability = minf(current_durability + amount, max_durability)
	durability_changed.emit(current_durability, max_durability)

func repair_full() -> void:
	current_durability = max_durability
	durability_changed.emit(current_durability, max_durability)

func get_percentage() -> float:
	return current_durability / max_durability

func reset() -> void:
	max_durability = BASE_MAX_DURABILITY * GameManager.get_durability_multiplier()
	current_durability = max_durability
	durability_changed.emit(current_durability, max_durability)
