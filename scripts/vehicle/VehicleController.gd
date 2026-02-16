extends CharacterBody2D
## Vehicle controller — state machine host and system owner.
## Replaces BoatController with a multi-mode vehicle system.

@onready var state_machine: VehicleStateMachine = $VehicleStateMachine

# Placeholder visual nodes (created in _ready)
var hull_rect: ColorRect
var deck_rect: ColorRect
var bow_rect: ColorRect

signal mode_changed(mode: int)
signal throttle_changed(throttle: float)

func _ready() -> void:
	# Create placeholder visual if no sprite texture
	if $Sprite2D.texture == null:
		_create_placeholder_visual()

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

func _create_placeholder_visual() -> void:
	# Vehicle body (hull)
	hull_rect = ColorRect.new()
	hull_rect.name = "HullRect"
	hull_rect.size = Vector2(16, 32)
	hull_rect.position = Vector2(-8, -16)
	hull_rect.color = Color(0.55, 0.35, 0.2)  # Surface: brown
	add_child(hull_rect)

	# Vehicle deck
	deck_rect = ColorRect.new()
	deck_rect.name = "DeckRect"
	deck_rect.size = Vector2(10, 20)
	deck_rect.position = Vector2(-5, -10)
	deck_rect.color = Color(0.75, 0.55, 0.35)  # Surface: tan
	add_child(deck_rect)

	# Bow indicator
	bow_rect = ColorRect.new()
	bow_rect.name = "BowRect"
	bow_rect.size = Vector2(6, 6)
	bow_rect.position = Vector2(-3, -18)
	bow_rect.color = Color(0.9, 0.9, 0.9)  # Surface: white
	add_child(bow_rect)

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

# --- Placeholder visual swaps ---

func apply_surface_visuals() -> void:
	if hull_rect:
		hull_rect.color = Color(0.55, 0.35, 0.2)  # Brown hull
	if deck_rect:
		deck_rect.color = Color(0.75, 0.55, 0.35)  # Tan deck
	if bow_rect:
		bow_rect.color = Color(0.9, 0.9, 0.9)  # White bow

func apply_submerged_visuals() -> void:
	if hull_rect:
		hull_rect.color = Color(0.3, 0.3, 0.35)  # Dark grey hull
	if deck_rect:
		deck_rect.color = Color(0.5, 0.5, 0.55)  # Steel deck
	if bow_rect:
		bow_rect.color = Color(0.3, 0.5, 0.8)  # Blue bow
