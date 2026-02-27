extends CharacterBody2D
## Vehicle controller — state machine host and system owner.
## Replaces BoatController with a multi-mode vehicle system.

@onready var state_machine: VehicleStateMachine = $VehicleStateMachine

signal mode_changed(mode: int)
signal throttle_changed(throttle: float)

func _ready() -> void:
	# Ensure boat sprite is loaded (scene should set it, this is a fallback)
	if $Sprite2D.texture == null:
		$Sprite2D.texture = preload("res://assets/sprites/boat/boat.svg")
	if $Sprite2D.texture == null:
		push_warning("VehicleController: boat texture failed to load — creating placeholder")
		_create_placeholder_visual()

	# Set up collision shape (surface default — sized to match 2.5x sprite scale)
	var col: CollisionShape2D = $CollisionShape2D
	if col.shape == null:
		var capsule := CapsuleShape2D.new()
		capsule.radius = 25.0
		capsule.height = 75.0
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

func _physics_process(delta: float) -> void:
	if state_machine and not state_machine.is_transforming and state_machine.current_state:
		state_machine.current_state.physics_process(delta)

func _process(delta: float) -> void:
	if state_machine and not state_machine.is_transforming and state_machine.current_state:
		state_machine.current_state.process(delta)

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

# --- Fallback placeholder (if SVG fails to load) ---

func _create_placeholder_visual() -> void:
	var hull := ColorRect.new()
	hull.name = "HullRect"
	hull.size = Vector2(40, 80)
	hull.position = Vector2(-20, -40)
	hull.color = Color(0.55, 0.35, 0.2)
	add_child(hull)

	var deck := ColorRect.new()
	deck.name = "DeckRect"
	deck.size = Vector2(25, 50)
	deck.position = Vector2(-12.5, -25)
	deck.color = Color(0.75, 0.55, 0.35)
	add_child(deck)

	var bow := ColorRect.new()
	bow.name = "BowRect"
	bow.size = Vector2(15, 15)
	bow.position = Vector2(-7.5, -45)
	bow.color = Color(0.9, 0.9, 0.9)
	add_child(bow)
