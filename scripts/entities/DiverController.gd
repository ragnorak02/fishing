extends CharacterBody2D

const SWIM_SPEED := 120.0
const WATER_DRAG := 0.92
const GRAVITY_DRIFT := 15.0  # Slight downward pull

var speed_boost: float = 0.0  # From upgrades
var boost_multiplier: float = 1.0  # Temporary swim boost item
var movement_locked: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var harpoon_pivot: Marker2D = $HarpoonPivot

func _ready() -> void:
	# Set up collision shape
	var col: CollisionShape2D = $CollisionShape2D
	if col.shape == null:
		var capsule := CapsuleShape2D.new()
		capsule.radius = 8.0
		capsule.height = 20.0
		col.shape = capsule

	# Load diver sprite
	sprite.texture = preload("res://assets/sprites/diver/diver.svg")

func _physics_process(delta: float) -> void:
	if not movement_locked:
		# 8-directional swim input
		var input_dir := Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up", "move_down")
		)

		if input_dir.length() > 0:
			input_dir = input_dir.normalized()
			# Flip sprite
			if input_dir.x != 0:
				sprite.flip_h = input_dir.x < 0

		# Apply movement with boost multiplier
		velocity += input_dir * SWIM_SPEED * boost_multiplier * delta * 10.0

		# Aim harpoon toward mouse
		if harpoon_pivot:
			var mouse_pos := get_global_mouse_position()
			harpoon_pivot.look_at(mouse_pos)

	# Gravity drift (slight sinking) — always applies
	velocity.y += GRAVITY_DRIFT * delta

	# Water drag — always applies (decelerates when locked)
	velocity *= WATER_DRAG

	move_and_slide()
