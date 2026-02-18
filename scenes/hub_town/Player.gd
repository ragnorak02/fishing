extends CharacterBody2D

const SPEED := 150.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Set up collision shape if not assigned
	var col: CollisionShape2D = $CollisionShape2D
	if col.shape == null:
		var capsule := CapsuleShape2D.new()
		capsule.radius = 6.0
		capsule.height = 14.0
		col.shape = capsule

	# Load player sprite
	sprite.texture = preload("res://assets/sprites/npc/player_topdown.svg")

func _physics_process(_delta: float) -> void:
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	if input_dir.length() > 0:
		input_dir = input_dir.normalized()
		if input_dir.x != 0:
			sprite.flip_h = input_dir.x < 0

	velocity = input_dir * SPEED
	move_and_slide()
