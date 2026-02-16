class_name AirState
extends VehicleState
## Stub — prints warning and bounces back to surface.

func enter() -> void:
	push_warning("AirState: Air mode not yet implemented")
	# Immediately transition back to surface
	state_machine.call_deferred("request_transform", VehicleStateMachine.Mode.SURFACE)

func exit() -> void:
	pass

func physics_process(_delta: float) -> void:
	pass
