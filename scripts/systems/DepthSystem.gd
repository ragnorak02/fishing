class_name DepthSystem
extends Node
## Numerical depth tracking with ascend/descend input.

const MAX_DEPTH := 100.0
const DEPTH_SPEED := 20.0  # units per second
const BUOYANCY_DRIFT := 2.0  # passive upward drift (units/sec)

var current_depth: float = 0.0
var is_active: bool = false

signal depth_changed(depth: float, max_depth: float)

func activate() -> void:
	is_active = true
	current_depth = 0.0
	depth_changed.emit(current_depth, MAX_DEPTH)

func deactivate() -> void:
	is_active = false
	current_depth = 0.0

func _process(delta: float) -> void:
	if not is_active:
		return

	var depth_input := Input.get_axis("ascend", "descend")

	# Apply depth movement
	if abs(depth_input) > 0.1:
		current_depth += depth_input * DEPTH_SPEED * delta
	else:
		# Passive buoyancy — slight upward drift
		current_depth -= BUOYANCY_DRIFT * delta

	current_depth = clampf(current_depth, 0.0, MAX_DEPTH)
	depth_changed.emit(current_depth, MAX_DEPTH)

func is_at_surface() -> bool:
	return current_depth <= 1.0

func get_percentage() -> float:
	return current_depth / MAX_DEPTH
