class_name VehicleState
extends RefCounted
## Abstract base class for all vehicle states.

var vehicle: CharacterBody2D
var state_machine  # VehicleStateMachine — avoid cyclic reference

func _init(p_vehicle: CharacterBody2D, p_state_machine) -> void:
	vehicle = p_vehicle
	state_machine = p_state_machine

func enter() -> void:
	pass

func exit() -> void:
	pass

func physics_process(delta: float) -> void:
	pass

func process(delta: float) -> void:
	pass
