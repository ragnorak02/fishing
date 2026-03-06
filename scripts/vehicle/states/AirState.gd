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

var shadow: Sprite2D = null

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

	# Create shadow below vehicle to show altitude
	_create_shadow()

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
	if shadow and is_instance_valid(shadow):
		shadow.queue_free()
		shadow = null

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

	# Weather wind drift
	var ws = Engine.get_main_loop().root.get_node_or_null("/root/WeatherSystem")
	var drift_mult := 1.0
	if ws:
		drift_mult = ws.get_vehicle_drift_multiplier()
		# Storm adds random wind gusts in air
		if ws.current_weather == ws.Weather.STORM:
			vehicle.velocity += Vector2(randf_range(-15, 15), randf_range(-10, 10)) * delta

	# Drift dampening (high value = lots of drift)
	var forward_component := forward * vehicle.velocity.dot(forward)
	var side_component := vehicle.velocity - forward_component
	vehicle.velocity = forward_component + side_component * (DRIFT_DAMP * drift_mult)

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

func _create_shadow() -> void:
	if shadow and is_instance_valid(shadow):
		shadow.queue_free()
	# Elliptical shadow below the vehicle
	shadow = Sprite2D.new()
	shadow.z_index = -5
	shadow.modulate = Color(0, 0, 0, 0.2)
	shadow.position = Vector2(0, 50)
	shadow.scale = Vector2(2.0, 0.8)
	# Use the boat texture as shadow base
	var boat_sprite: Sprite2D = vehicle.get_node_or_null("Sprite2D")
	if boat_sprite and boat_sprite.texture:
		shadow.texture = boat_sprite.texture
	vehicle.add_child(shadow)
