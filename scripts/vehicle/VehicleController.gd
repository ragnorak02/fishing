extends CharacterBody2D
## Vehicle controller — state machine host and system owner.
## Replaces BoatController with a multi-mode vehicle system.

@onready var state_machine: VehicleStateMachine = $VehicleStateMachine

signal mode_changed(mode: int)
signal throttle_changed(throttle: float)

func _ready() -> void:
	# Load boat sprite
	$Sprite2D.texture = preload("res://assets/sprites/boat/boat.svg")

	# Set up collision shape (surface default)
	var col: CollisionShape2D = $CollisionShape2D
	if col.shape == null:
		var capsule := CapsuleShape2D.new()
		capsule.radius = 10.0
		capsule.height = 30.0
		col.shape = capsule

	# Init systems (children added in scene or created here)
	_init_systems()

	# Init state machine
	_init_state_machine()

func _init_systems() -> void:
	# DurabilitySystem — always active
	if not get_node_or_null("DurabilitySystem"):
		var durability := DurabilitySystem.new()
		durability.name = "DurabilitySystem"
		add_child(durability)

	# BatterySystem — managed by states
	if not get_node_or_null("BatterySystem"):
		var battery := BatterySystem.new()
		battery.name = "BatterySystem"
		add_child(battery)

	# DepthSystem — managed by states
	if not get_node_or_null("DepthSystem"):
		var depth := DepthSystem.new()
		depth.name = "DepthSystem"
		add_child(depth)

	# SonarSystem — managed by states
	if not get_node_or_null("SonarSystem"):
		var sonar := SonarSystem.new()
		sonar.name = "SonarSystem"
		add_child(sonar)

	# MountedHarpoon — managed by states
	if not get_node_or_null("MountedHarpoon"):
		var harpoon := MountedHarpoon.new()
		harpoon.name = "MountedHarpoon"
		add_child(harpoon)

func _init_state_machine() -> void:
	if not state_machine:
		state_machine = VehicleStateMachine.new()
		state_machine.name = "VehicleStateMachine"
		add_child(state_machine)

	# Create states
	var surface_state := SurfaceState.new(self, state_machine)
	var submerged_state := SubmergedState.new(self, state_machine)
	var air_state := AirState.new(self, state_machine)

	state_machine.register_state(VehicleStateMachine.Mode.SURFACE, surface_state)
	state_machine.register_state(VehicleStateMachine.Mode.SUBMERGED, submerged_state)
	state_machine.register_state(VehicleStateMachine.Mode.AIR, air_state)

	# Relay mode_changed
	state_machine.mode_changed.connect(_on_mode_changed)

	# Start in surface mode
	state_machine.start(VehicleStateMachine.Mode.SURFACE)

func _on_mode_changed(mode: VehicleStateMachine.Mode) -> void:
	mode_changed.emit(mode)
	GameManager.set_vehicle_mode(mode)

func get_current_mode() -> VehicleStateMachine.Mode:
	return state_machine.current_mode

func request_transform(target_mode: VehicleStateMachine.Mode) -> void:
	state_machine.request_transform(target_mode)

func is_transforming() -> bool:
	return state_machine.is_transforming

# --- Vehicle mode visuals ---

func apply_surface_visuals() -> void:
	$Sprite2D.modulate = Color(1.0, 1.0, 1.0)

func apply_submerged_visuals() -> void:
	$Sprite2D.modulate = Color(0.5, 0.6, 0.8)
