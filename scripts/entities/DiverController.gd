extends CharacterBody2D

const SWIM_SPEED := 120.0
const WATER_DRAG := 0.92
const GRAVITY_DRIFT := 15.0  # Slight downward pull

var speed_boost: float = 0.0  # From upgrades

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

	if sprite.texture == null:
		_create_placeholder_visual()

func _create_placeholder_visual() -> void:
	# Body
	var body := ColorRect.new()
	body.size = Vector2(12, 20)
	body.position = Vector2(-6, -10)
	body.color = Color(0.15, 0.15, 0.15)
	add_child(body)

	# Mask/goggles
	var goggles := ColorRect.new()
	goggles.size = Vector2(10, 4)
	goggles.position = Vector2(-5, -12)
	goggles.color = Color(0.3, 0.7, 0.9)
	add_child(goggles)

	# Fins
	var fins := ColorRect.new()
	fins.size = Vector2(14, 4)
	fins.position = Vector2(-7, 10)
	fins.color = Color(0.2, 0.2, 0.2)
	add_child(fins)

func _physics_process(delta: float) -> void:
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

	# Apply movement
	velocity += input_dir * SWIM_SPEED * delta * 10.0

	# Gravity drift (slight sinking)
	velocity.y += GRAVITY_DRIFT * delta

	# Water drag
	velocity *= WATER_DRAG

	# Aim harpoon toward mouse
	if harpoon_pivot:
		var mouse_pos := get_global_mouse_position()
		harpoon_pivot.look_at(mouse_pos)

	move_and_slide()
