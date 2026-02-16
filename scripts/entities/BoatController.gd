extends CharacterBody2D

const BASE_MAX_SPEED := 200.0
const ACCELERATION := 300.0
const DRAG := 0.97
const DRIFT_DAMP := 0.92
const ROTATION_SPEED := 3.0
const BOOST_MULTIPLIER := 1.8
const BOOST_DURATION := 1.5
const BOOST_COOLDOWN := 4.0

var speed_multiplier: float = 1.0
var boost_timer: float = 0.0
var boost_cooldown_timer: float = 0.0
var is_boosting: bool = false

@onready var wake_particles: GPUParticles2D = $WakeParticles

func _ready() -> void:
	speed_multiplier = GameManager.get_boat_speed_multiplier()

	# Create placeholder visual if no sprite
	if $Sprite2D.texture == null:
		_create_placeholder_visual()

	# Set up collision shape
	var col: CollisionShape2D = $CollisionShape2D
	if col.shape == null:
		var capsule := CapsuleShape2D.new()
		capsule.radius = 10.0
		capsule.height = 30.0
		col.shape = capsule

func _create_placeholder_visual() -> void:
	# Boat body
	var body := ColorRect.new()
	body.size = Vector2(16, 32)
	body.position = Vector2(-8, -16)
	body.color = Color(0.55, 0.35, 0.2)
	add_child(body)

	# Boat deck
	var deck := ColorRect.new()
	deck.size = Vector2(10, 20)
	deck.position = Vector2(-5, -10)
	deck.color = Color(0.75, 0.55, 0.35)
	add_child(deck)

	# Bow indicator
	var bow := ColorRect.new()
	bow.size = Vector2(6, 6)
	bow.position = Vector2(-3, -18)
	bow.color = Color(0.9, 0.9, 0.9)
	add_child(bow)

func _physics_process(delta: float) -> void:
	var max_speed := BASE_MAX_SPEED * speed_multiplier

	# Boost handling
	if boost_cooldown_timer > 0:
		boost_cooldown_timer -= delta
	if boost_timer > 0:
		boost_timer -= delta
		if boost_timer <= 0:
			is_boosting = false

	if Input.is_action_just_pressed("boost") and boost_cooldown_timer <= 0 and not is_boosting:
		is_boosting = true
		boost_timer = BOOST_DURATION
		boost_cooldown_timer = BOOST_COOLDOWN

	var current_max := max_speed * (BOOST_MULTIPLIER if is_boosting else 1.0)

	# Rotation
	var turn_input := Input.get_axis("move_left", "move_right")
	rotation += turn_input * ROTATION_SPEED * delta

	# Thrust
	var thrust_input := Input.get_axis("move_down", "move_up")
	var forward := Vector2.UP.rotated(rotation)

	if thrust_input > 0:
		velocity += forward * ACCELERATION * thrust_input * delta
	elif thrust_input < 0:
		velocity += forward * ACCELERATION * thrust_input * 0.5 * delta

	# Drag
	velocity *= DRAG

	# Drift dampening — reduce sideways velocity
	var forward_component := forward * velocity.dot(forward)
	var side_component := velocity - forward_component
	velocity = forward_component + side_component * DRIFT_DAMP

	# Clamp speed
	if velocity.length() > current_max:
		velocity = velocity.normalized() * current_max

	# Update wake particles
	if wake_particles:
		wake_particles.emitting = velocity.length() > 20.0
		var particle_mat = wake_particles.process_material
		if particle_mat and particle_mat is ParticleProcessMaterial:
			particle_mat.initial_velocity_min = velocity.length() * 0.3
			particle_mat.initial_velocity_max = velocity.length() * 0.5

	move_and_slide()
