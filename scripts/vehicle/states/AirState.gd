class_name AirState
extends VehicleState
## Air mode: fastest speed, lightest drag, least maneuverable, most drift.
## No sub-systems active (no battery, harpoon, sonar in air).

const MAX_SPEED_FORWARD := 280.0
const MAX_SPEED_REVERSE := 60.0
const ACCELERATION := 350.0
const REVERSE_ACCELERATION := 120.0
const DRAG := 0.98
const DRIFT_DAMP := 0.95
const ROTATION_SPEED := 1.8
const BOUNCE_FACTOR := 0.2

func enter() -> void:
	# Disable wake particles (flying above water)
	var wake: GPUParticles2D = vehicle.get_node_or_null("WakeParticles")
	if wake:
		wake.emitting = false

	# Swap to air collision shape (narrower profile)
	var col: CollisionShape2D = vehicle.get_node("CollisionShape2D")
	if col.shape == null or not col.shape is CapsuleShape2D or col.shape.radius != 20.0 or col.shape.height != 60.0:
		var capsule := CapsuleShape2D.new()
		capsule.radius = 20.0
		capsule.height = 60.0
		col.shape = capsule

	# Apply air visuals
	vehicle.apply_air_visuals()

	# Deactivate all sub-systems (not available in air)
	var battery: BatterySystem = vehicle.get_node_or_null("BatterySystem")
	if battery:
		battery.deactivate()
	var depth: DepthSystem = vehicle.get_node_or_null("DepthSystem")
	if depth:
		depth.deactivate()
	var sonar: SonarSystem = vehicle.get_node_or_null("SonarSystem")
	if sonar:
		sonar.deactivate()
	var harpoon: MountedHarpoon = vehicle.get_node_or_null("MountedHarpoon")
	if harpoon:
		harpoon.deactivate()

func exit() -> void:
	pass

func physics_process(delta: float) -> void:
	var speed_mult: float = GameManager.get_boat_speed_multiplier()
	var max_fwd := MAX_SPEED_FORWARD * speed_mult
	var max_rev := MAX_SPEED_REVERSE * speed_mult

	# Rotation (sluggish in air)
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

	# Drag (very light — maintains speed)
	vehicle.velocity *= DRAG

	# Drift dampening (high value = lots of drift)
	var forward_component := forward * vehicle.velocity.dot(forward)
	var side_component := vehicle.velocity - forward_component
	vehicle.velocity = forward_component + side_component * DRIFT_DAMP

	# Clamp speed
	var current_max := max_fwd if vehicle.velocity.dot(forward) >= 0 else max_rev
	if vehicle.velocity.length() > current_max:
		vehicle.velocity = vehicle.velocity.normalized() * current_max

	# Move and handle bounce (still collides with islands)
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

		# Less damage in air (glancing impacts)
		var impact_speed := pre_velocity.length()
		if impact_speed > 30.0:
			var damage := impact_speed * 0.05
			var durability = vehicle.get_node_or_null("DurabilitySystem")
			if durability:
				durability.take_damage(damage)
		break
