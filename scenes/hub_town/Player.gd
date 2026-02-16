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

	# Create placeholder visual if no sprite texture
	if sprite.texture == null:
		_create_placeholder_visual()

func _create_placeholder_visual() -> void:
	var rect := ColorRect.new()
	rect.size = Vector2(12, 16)
	rect.position = Vector2(-6, -8)
	rect.color = Color(0.3, 0.5, 0.9)
	add_child(rect)

	# Head
	var head := ColorRect.new()
	head.size = Vector2(8, 8)
	head.position = Vector2(-4, -14)
	head.color = Color(0.9, 0.75, 0.6)
	add_child(head)

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
