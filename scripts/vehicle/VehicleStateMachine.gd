class_name VehicleStateMachine
extends Node
## Manages vehicle states, transitions, and transform animations.

enum Mode { SURFACE, SUBMERGED, AIR }

var states: Dictionary = {}  # Mode -> VehicleState
var current_mode: Mode = Mode.SURFACE
var current_state: VehicleState = null
var is_transforming: bool = false

var vehicle: CharacterBody2D

signal mode_changed(mode: Mode)
signal transform_started
signal transform_finished

func _ready() -> void:
	vehicle = get_parent()

func register_state(mode: Mode, state: VehicleState) -> void:
	states[mode] = state

func start(initial_mode: Mode = Mode.SURFACE) -> void:
	current_mode = initial_mode
	current_state = states[initial_mode]
	current_state.enter()

func request_transform(target_mode: Mode) -> void:
	if is_transforming:
		return
	if target_mode == current_mode:
		return
	if not states.has(target_mode):
		push_warning("VehicleStateMachine: No state registered for mode %d" % target_mode)
		return

	_run_transform(target_mode)

func _run_transform(target_mode: Mode) -> void:
	is_transforming = true
	transform_started.emit()

	# Exit current state
	current_state.exit()

	# Animate transform (~0.5s)
	await _play_transform_animation(target_mode)

	# Enter new state
	current_mode = target_mode
	current_state = states[target_mode]
	current_state.enter()

	is_transforming = false
	mode_changed.emit(current_mode)
	transform_finished.emit()

func _play_transform_animation(target_mode: Mode) -> void:
	var tween := create_tween()
	tween.set_parallel(true)

	# Scale pulse: 1 -> 0.8 -> 1.1 -> 1
	var scale_tween := create_tween()
	scale_tween.tween_property(vehicle, "scale", Vector2(0.8, 0.8), 0.15)
	scale_tween.tween_property(vehicle, "scale", Vector2(1.1, 1.1), 0.15)
	scale_tween.tween_property(vehicle, "scale", Vector2(1.0, 1.0), 0.2)

	# Camera zoom shift
	var camera: Camera2D = vehicle.get_node_or_null("Camera2D")
	if camera:
		var target_zoom: Vector2
		match target_mode:
			Mode.SURFACE:
				target_zoom = Vector2(1.5, 1.5)
			Mode.SUBMERGED:
				target_zoom = Vector2(1.8, 1.8)
			_:
				target_zoom = Vector2(1.5, 1.5)
		tween.tween_property(camera, "zoom", target_zoom, 0.5)

	await scale_tween.finished

func _physics_process(delta: float) -> void:
	if is_transforming:
		return
	if current_state:
		current_state.physics_process(delta)

func _process(delta: float) -> void:
	if is_transforming:
		return
	if current_state:
		current_state.process(delta)
