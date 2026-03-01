extends CharacterBody2D

const SPEED := 150.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	var col: CollisionShape2D = $CollisionShape2D
	if col.shape == null:
		var capsule := CapsuleShape2D.new()
		capsule.radius = 6.0
		capsule.height = 14.0
		col.shape = capsule
	sprite.texture = preload("res://assets/sprites/npc/player_topdown.svg")

func _physics_process(_delta: float) -> void:
	var input_x := Input.get_axis("move_left", "move_right")

	if input_x != 0:
		sprite.flip_h = input_x < 0

	velocity = Vector2(input_x * SPEED, 0)
	move_and_slide()
