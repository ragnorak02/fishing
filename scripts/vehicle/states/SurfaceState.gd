class_name SurfaceState
extends VehicleState
## Surface mode: throttle physics, wake particles, collision bounce.
## Ports existing BoatController physics exactly.

const MAX_SPEED_FORWARD := 200.0
const MAX_SPEED_REVERSE := 80.0
const ACCELERATION := 300.0
const REVERSE_ACCELERATION := 150.0
const DRAG := 0.97
const DRIFT_DAMP := 0.92
const ROTATION_SPEED := 3.0
const BOUNCE_FACTOR := 0.4

func enter() -> void:
	# Enable wake particles
	var wake: GPUParticles2D = vehicle.get_node_or_null("WakeParticles")
	if wake:
		wake.emitting = false  # Will be controlled by physics

	# Swap to surface collision shape
	var col: CollisionShape2D = vehicle.get_node("CollisionShape2D")
	var capsule := CapsuleShape2D.new()
	capsule.radius = 10.0
	capsule.height = 30.0
	col.shape = capsule

	# Apply surface placeholder visuals
	vehicle.apply_surface_visuals()

func exit() -> void:
	var wake: GPUParticles2D = vehicle.get_node_or_null("WakeParticles")
	if wake:
		wake.emitting = false

func physics_process(delta: float) -> void:
	var speed_mult: float = GameManager.get_boat_speed_multiplier()
	var max_fwd := MAX_SPEED_FORWARD * speed_mult
	var max_rev := MAX_SPEED_REVERSE * speed_mult

	# Rotation
	var turn_input := Input.get_axis("move_left", "move_right")
	vehicle.rotation += turn_input * ROTATION_SPEED * delta

	# Thrust
	var thrust_input := Input.get_axis("move_down", "move_up")
	var forward := Vector2.UP.rotated(vehicle.rotation)

	if thrust_input > 0:
		vehicle.velocity += forward * ACCELERATION * thrust_input * delta
	elif thrust_input < 0:
		vehicle.velocity += forward * REVERSE_ACCELERATION * thrust_input * delta

	# Emit throttle signal
	var throttle_pct: float = 0.0
	if thrust_input > 0:
		throttle_pct = vehicle.velocity.dot(forward) / max_fwd
	elif thrust_input < 0:
		throttle_pct = -vehicle.velocity.dot(-forward) / max_rev
	vehicle.throttle_changed.emit(clampf(throttle_pct, -1.0, 1.0))

	# Drag
	vehicle.velocity *= DRAG

	# Drift dampening — reduce sideways velocity
	var forward_component := forward * vehicle.velocity.dot(forward)
	var side_component := vehicle.velocity - forward_component
	vehicle.velocity = forward_component + side_component * DRIFT_DAMP

	# Clamp speed
	var current_max := max_fwd if vehicle.velocity.dot(forward) >= 0 else max_rev
	if vehicle.velocity.length() > current_max:
		vehicle.velocity = vehicle.velocity.normalized() * current_max

	# Update wake particles
	var wake: GPUParticles2D = vehicle.get_node_or_null("WakeParticles")
	if wake:
		wake.emitting = vehicle.velocity.length() > 20.0
		var particle_mat = wake.process_material
		if particle_mat and particle_mat is ParticleProcessMaterial:
			particle_mat.initial_velocity_min = vehicle.velocity.length() * 0.3
			particle_mat.initial_velocity_max = vehicle.velocity.length() * 0.5

	# Move and handle bounce
	var pre_velocity := vehicle.velocity
	vehicle.move_and_slide()

	if vehicle.get_slide_collision_count() > 0:
		_apply_bounce(pre_velocity)

func _apply_bounce(pre_velocity: Vector2) -> void:
	for i in vehicle.get_slide_collision_count():
		var collision := vehicle.get_slide_collision(i)
		var normal := collision.get_normal()
		var reflect := pre_velocity.bounce(normal) * BOUNCE_FACTOR
		vehicle.velocity = reflect

		# Damage durability proportional to impact speed
		var impact_speed := pre_velocity.length()
		if impact_speed > 30.0:
			var damage := impact_speed * 0.1
			var durability = vehicle.get_node_or_null("DurabilitySystem")
			if durability:
				durability.take_damage(damage)
		break  # Only process first collision
