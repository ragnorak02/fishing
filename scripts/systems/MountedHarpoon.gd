class_name MountedHarpoon
extends Node
## Fires existing Harpoon.gd from vehicle's forward direction.

const COOLDOWN := 0.8  # seconds
const HARPOON_SPEED := 350.0
const BASE_RANGE := 300.0

var cooldown_timer: float = 0.0
var is_active: bool = false

signal target_hit(fish: Node2D)

var HarpoonScene: PackedScene = null

func activate() -> void:
	is_active = true
	cooldown_timer = 0.0

func deactivate() -> void:
	is_active = false

func _process(delta: float) -> void:
	if not is_active:
		return

	if cooldown_timer > 0:
		cooldown_timer -= delta

	if Input.is_action_just_pressed("fire_harpoon") and cooldown_timer <= 0:
		_fire()

func _fire() -> void:
	cooldown_timer = COOLDOWN

	var vehicle: CharacterBody2D = get_parent()
	var forward := Vector2.UP.rotated(vehicle.rotation)

	# Create harpoon instance
	var harpoon = _create_harpoon()
	harpoon.global_position = vehicle.global_position + forward * 20.0
	harpoon.rotation = vehicle.rotation
	harpoon.direction = forward
	harpoon.speed = HARPOON_SPEED
	harpoon.max_range = BASE_RANGE * GameManager.get_harpoon_range_multiplier()

	harpoon.fish_hit.connect(_on_harpoon_hit)

	# Add to scene tree (parent of vehicle)
	vehicle.get_parent().add_child(harpoon)

func _create_harpoon() -> Area2D:
	# Instantiate the existing Harpoon script directly
	var harpoon := Area2D.new()
	harpoon.set_script(load("res://scripts/entities/Harpoon.gd"))
	return harpoon

func _on_harpoon_hit(fish: Node2D) -> void:
	target_hit.emit(fish)
