class_name SubmergedState
extends VehicleState
## Submarine mode: heavier physics, depth input, battery drain.

const MAX_SPEED_FORWARD := 140.0
const MAX_SPEED_REVERSE := 50.0
const ACCELERATION := 200.0
const REVERSE_ACCELERATION := 100.0
const DRAG := 0.94
const DRIFT_DAMP := 0.88
const ROTATION_SPEED := 2.0
const BOUNCE_FACTOR := 0.3

func enter() -> void:
	# Disable wake particles
	var wake: GPUParticles2D = vehicle.get_node_or_null("WakeParticles")
	if wake:
		wake.emitting = false

	# Swap to submerged collision shape (wider, shorter)
	var col: CollisionShape2D = vehicle.get_node("CollisionShape2D")
	var capsule := CapsuleShape2D.new()
	capsule.radius = 12.0
	capsule.height = 26.0
	col.shape = capsule

	# Apply submerged placeholder visuals
	vehicle.apply_submerged_visuals()

	# Activate submerged systems
	var battery: BatterySystem = vehicle.get_node_or_null("BatterySystem")
	if battery:
		battery.activate()

	var depth: DepthSystem = vehicle.get_node_or_null("DepthSystem")
	if depth:
		depth.activate()

	var sonar: SonarSystem = vehicle.get_node_or_null("SonarSystem")
	if sonar:
		sonar.activate()

	var harpoon: MountedHarpoon = vehicle.get_node_or_null("MountedHarpoon")
	if harpoon:
		harpoon.activate()

func exit() -> void:
	# Deactivate submerged systems
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

func physics_process(delta: float) -> void:
	var speed_mult: float = GameManager.get_boat_speed_multiplier()
	var max_fwd := MAX_SPEED_FORWARD * speed_mult
	var max_rev := MAX_SPEED_REVERSE * speed_mult

	# Rotation (slower underwater)
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

	# Drag (heavier underwater)
	vehicle.velocity *= DRAG

	# Drift dampening
	var forward_component := forward * vehicle.velocity.dot(forward)
	var side_component := vehicle.velocity - forward_component
	vehicle.velocity = forward_component + side_component * DRIFT_DAMP

	# Clamp speed
	var current_max := max_fwd if vehicle.velocity.dot(forward) >= 0 else max_rev
	if vehicle.velocity.length() > current_max:
		vehicle.velocity = vehicle.velocity.normalized() * current_max

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

		var impact_speed := pre_velocity.length()
		if impact_speed > 30.0:
			var damage := impact_speed * 0.15  # More damage underwater
			var durability = vehicle.get_node_or_null("DurabilitySystem")
			if durability:
				durability.take_damage(damage)
		break
