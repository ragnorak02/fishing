extends Node

const BASE_MAX_OXYGEN := 60.0  # seconds

var max_oxygen: float = BASE_MAX_OXYGEN
var current_oxygen: float = BASE_MAX_OXYGEN
var is_depleted: bool = false

signal oxygen_changed(current: float, maximum: float)
signal oxygen_depleted

func _ready() -> void:
	max_oxygen = BASE_MAX_OXYGEN * GameManager.get_oxygen_multiplier()
	current_oxygen = max_oxygen

func _process(delta: float) -> void:
	if is_depleted:
		return

	current_oxygen -= delta
	current_oxygen = max(current_oxygen, 0.0)
	oxygen_changed.emit(current_oxygen, max_oxygen)

	if current_oxygen <= 0.0:
		is_depleted = true
		oxygen_depleted.emit()

func get_percentage() -> float:
	return current_oxygen / max_oxygen

func reset() -> void:
	max_oxygen = BASE_MAX_OXYGEN * GameManager.get_oxygen_multiplier()
	current_oxygen = max_oxygen
	is_depleted = false
