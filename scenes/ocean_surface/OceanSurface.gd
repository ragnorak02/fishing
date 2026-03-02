extends Node2D

@onready var vehicle: CharacterBody2D = $Vehicle
@onready var hud = $VehicleHUD

var near_dive_spot: Area2D = null
var near_hub_return: bool = false

const MAP_BOUNDS := Rect2(-1500, -1500, 3000, 3000)

# Sonar ring visual
var sonar_ring: Node2D = null

func _ready() -> void:
	AudioManager.play_music("ocean_surface")
	hud.set_location("Open Sea")
	hud.interact_prompt.visible = false

	# Time-of-day tinting
	var canvas_mod := CanvasModulate.new()
	canvas_mod.color = TimeManager.get_ambient_color()
	add_child(canvas_mod)

	# Fallback: set up island collision shapes if not baked in .tscn
	_setup_island($Island1, Vector2(55, 40))
	_setup_island($Island2, Vector2(45, 35))
	_setup_island($Island3, Vector2(40, 30))

	# Fallback: set up hub return zone if not baked in .tscn
	var hub_col: CollisionShape2D = $HubReturnZone/CollisionShape2D
	if hub_col.shape == null:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(120, 80)
		hub_col.shape = rect

	# Connect interaction signals directly (shapes are baked in .tscn now)
	_connect_interaction_signals()

	# After one physics frame, check for bodies already overlapping at spawn
	get_tree().physics_frame.connect(_check_initial_overlaps, CONNECT_ONE_SHOT)

	# Wire vehicle signals
	vehicle.mode_changed.connect(_on_vehicle_mode_changed)
	vehicle.throttle_changed.connect(_on_vehicle_throttle_changed)

	# Wire system signals
	var durability: DurabilitySystem = vehicle.get_node_or_null("DurabilitySystem")
	if durability:
		durability.durability_changed.connect(_on_durability_changed)
		durability.hull_destroyed.connect(_on_hull_destroyed)

	var battery: BatterySystem = vehicle.get_node_or_null("BatterySystem")
	if battery:
		battery.battery_changed.connect(_on_battery_changed)
		battery.battery_depleted.connect(_on_battery_depleted)

	var depth: DepthSystem = vehicle.get_node_or_null("DepthSystem")
	if depth:
		depth.depth_changed.connect(_on_depth_changed)

	var sonar: SonarSystem = vehicle.get_node_or_null("SonarSystem")
	if sonar:
		sonar.sonar_pulsed.connect(_on_sonar_pulsed)

	var harpoon: MountedHarpoon = vehicle.get_node_or_null("MountedHarpoon")
	if harpoon:
		harpoon.target_hit.connect(_on_harpoon_hit)

func _connect_interaction_signals() -> void:
	# Connect dive spot signals by direct node reference (group may be empty if
	# DiveSpot._ready hasn't fired yet) — fall back to group scan as well.
	var spots: Array[Area2D] = []
	for child in get_children():
		if child is Area2D and child.is_in_group("dive_spots"):
			spots.append(child)
	# Fallback: also try group in case spots were added dynamically
	if spots.is_empty():
		for spot in get_tree().get_nodes_in_group("dive_spots"):
			if spot is Area2D and spot not in spots:
				spots.append(spot)
	# Last resort: grab them by name
	if spots.is_empty():
		for name_str in ["DiveSpot1", "DiveSpot2", "DiveSpot3"]:
			var node = get_node_or_null(name_str)
			if node and node is Area2D:
				spots.append(node)

	GameLog.vehicle("Signal wiring: found %d dive spots" % spots.size())
	for spot in spots:
		var col_shape: CollisionShape2D = spot.get_node("CollisionShape2D")
		GameLog.vehicle("Spot: %s | pos=%s | monitoring=%s | shape=%s" % [
			spot.name, spot.global_position, spot.monitoring, col_shape.shape])
		var already_connected := spot.body_entered.is_connected(_on_dive_spot_entered)
		if not already_connected:
			spot.body_entered.connect(_on_dive_spot_entered.bind(spot))
			spot.body_exited.connect(_on_dive_spot_exited.bind(spot))

	var hub_zone: Area2D = $HubReturnZone
	hub_zone.body_entered.connect(_on_hub_return_entered)
	hub_zone.body_exited.connect(_on_hub_return_exited)

func _setup_island(island: StaticBody2D, half_size: Vector2) -> void:
	var col: CollisionShape2D = island.get_node("CollisionShape2D")
	if col.shape == null:
		var rect := RectangleShape2D.new()
		rect.size = half_size * 2.0
		col.shape = rect

func _check_initial_overlaps() -> void:
	for child in get_children():
		if child is Area2D and child.is_in_group("dive_spots"):
			if child.get_overlapping_bodies().has(vehicle):
				_on_dive_spot_entered(vehicle, child)
	if $HubReturnZone.get_overlapping_bodies().has(vehicle):
		_on_hub_return_entered(vehicle)

func _process(_delta: float) -> void:
	# Periodic diagnostic (every ~2s, gated by DEBUG_VEHICLE)
	if Engine.get_process_frames() % 120 == 0:
		GameLog.vehicle("pos=%s | near_dive=%s | near_hub=%s" % [
			vehicle.global_position, near_dive_spot != null, near_hub_return])

	var is_surface = vehicle.get_current_mode() == VehicleStateMachine.Mode.SURFACE

	# Interaction — only in surface mode
	if Input.is_action_just_pressed("interact"):
		GameLog.vehicle("E pressed | mode=%d is_surface=%s near_dive=%s near_hub=%s" % [
			vehicle.get_current_mode(), is_surface, near_dive_spot != null, near_hub_return])
		if is_surface:
			if near_dive_spot:
				_start_dive(near_dive_spot)
			elif near_hub_return:
				GameManager.transition_to("res://scenes/restaurant/Restaurant.tscn")

	# Submerge (R / RB) — requires unlock
	if Input.is_action_just_pressed("transform_vehicle") and not vehicle.is_transforming():
		if not GameManager.submerge_unlocked:
			hud.interact_prompt.visible = true
			hud.interact_prompt.text = "Submerge not unlocked yet!"
			get_tree().create_timer(1.5).timeout.connect(func():
				if not near_dive_spot and not near_hub_return:
					hud.interact_prompt.visible = false
			)
		else:
			var current_mode = vehicle.get_current_mode()
			if current_mode == VehicleStateMachine.Mode.SURFACE:
				vehicle.request_transform(VehicleStateMachine.Mode.SUBMERGED)
			elif current_mode == VehicleStateMachine.Mode.SUBMERGED:
				var depth_sys: DepthSystem = vehicle.get_node_or_null("DepthSystem")
				if depth_sys and not depth_sys.is_at_surface():
					hud.interact_prompt.visible = true
					hud.interact_prompt.text = "Ascend to surface first!"
					get_tree().create_timer(1.5).timeout.connect(func():
						if not near_dive_spot and not near_hub_return:
							hud.interact_prompt.visible = false
					)
				else:
					vehicle.request_transform(VehicleStateMachine.Mode.SURFACE)
			elif current_mode == VehicleStateMachine.Mode.AIR:
				vehicle.request_transform(VehicleStateMachine.Mode.SURFACE)

	# Fly (T / RT) — requires unlock
	if Input.is_action_just_pressed("transform_air") and not vehicle.is_transforming():
		if not GameManager.air_mode_unlocked:
			hud.interact_prompt.visible = true
			hud.interact_prompt.text = "Air mode not unlocked yet!"
			get_tree().create_timer(1.5).timeout.connect(func():
				if not near_dive_spot and not near_hub_return:
					hud.interact_prompt.visible = false
			)
		else:
			var current_mode = vehicle.get_current_mode()
			if current_mode == VehicleStateMachine.Mode.SURFACE:
				vehicle.request_transform(VehicleStateMachine.Mode.AIR)
			elif current_mode == VehicleStateMachine.Mode.AIR:
				vehicle.request_transform(VehicleStateMachine.Mode.SURFACE)

	# Boundary enforcement
	if not MAP_BOUNDS.has_point(vehicle.global_position):
		vehicle.global_position = vehicle.global_position.clamp(
			MAP_BOUNDS.position,
			MAP_BOUNDS.position + MAP_BOUNDS.size
		)
		vehicle.velocity *= -0.5

func _start_dive(spot: Area2D) -> void:
	if spot.has_meta("biome"):
		GameManager.current_dive_biome = spot.get_meta("biome")
	else:
		GameManager.current_dive_biome = "shallow"
	Inventory.clear_haul()
	GameManager.transition_to("res://scenes/dive_scene/DiveScene.tscn")

# --- Vehicle signal handlers ---

func _on_vehicle_mode_changed(mode: int) -> void:
	hud.set_mode(mode)
	# Hide/show interaction prompts based on mode
	var is_surface := (mode == VehicleStateMachine.Mode.SURFACE)
	if not is_surface:
		hud.interact_prompt.visible = false

func _on_vehicle_throttle_changed(throttle: float) -> void:
	hud.update_throttle(throttle)

func _on_durability_changed(current: float, maximum: float) -> void:
	hud.update_hull(current, maximum)

func _on_hull_destroyed() -> void:
	# Flash red and return to hub
	var tween := create_tween()
	tween.tween_property(vehicle, "modulate", Color(1, 0.2, 0.2), 0.15)
	tween.tween_property(vehicle, "modulate", Color(1, 1, 1), 0.15)
	tween.tween_callback(func():
		GameManager.transition_to("res://scenes/restaurant/Restaurant.tscn")
	)

func _on_battery_changed(current: float, maximum: float) -> void:
	hud.update_battery(current, maximum)

func _on_battery_depleted() -> void:
	# Emergency re-emerge — force back to surface with red flash
	var tween := create_tween()
	tween.tween_property(vehicle, "modulate", Color(1, 0.3, 0.3), 0.1)
	tween.tween_property(vehicle, "modulate", Color(1, 1, 1), 0.2)
	tween.tween_callback(func():
		vehicle.request_transform(VehicleStateMachine.Mode.SURFACE)
	)

func _on_depth_changed(depth: float, max_depth: float) -> void:
	hud.update_depth(depth, max_depth)

func _on_sonar_pulsed(origin: Vector2, pulse_range: float) -> void:
	AudioManager.play_sfx("sonar_pulse")
	_spawn_sonar_ring(origin, pulse_range)

func _on_harpoon_hit(fish: Node2D) -> void:
	# Catch the fish — same as dive scene pattern
	if fish.has_meta("species_id"):
		var species_id: String = fish.get_meta("species_id")
		var species := FishDatabase.get_species(species_id)
		if species:
			var weight := species.get_random_weight()
			Inventory.add_to_haul(species_id, weight)
	fish.queue_free()

# --- Sonar ring visual ---

func _spawn_sonar_ring(origin: Vector2, pulse_range: float) -> void:
	# Clean up previous ring
	if sonar_ring and is_instance_valid(sonar_ring):
		sonar_ring.queue_free()

	sonar_ring = Node2D.new()
	sonar_ring.global_position = origin
	add_child(sonar_ring)

	# Draw expanding ring using a simple circle approach
	var ring_visual := _create_ring_visual()
	sonar_ring.add_child(ring_visual)

	# Animate expansion and fade
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sonar_ring, "scale", Vector2.ONE * (pulse_range / 50.0), 1.5)
	tween.tween_property(sonar_ring, "modulate:a", 0.0, 1.5)
	tween.chain().tween_callback(func():
		if sonar_ring and is_instance_valid(sonar_ring):
			sonar_ring.queue_free()
	)

func _create_ring_visual() -> Node2D:
	# Create a simple ring using Line2D
	var ring := Line2D.new()
	ring.width = 2.0
	ring.default_color = Color(0.3, 0.8, 1.0, 0.6)
	ring.closed = true

	# Draw circle with 32 segments
	var points: PackedVector2Array = []
	for i in 33:
		var angle := (float(i) / 32.0) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * 50.0)
	ring.points = points

	return ring

# --- Dive/Hub interaction signals ---

func _on_dive_spot_entered(body: Node2D, spot: Area2D) -> void:
	GameLog.vehicle("body_entered on %s — body=%s" % [spot.name, body.name])
	if body == vehicle:
		near_dive_spot = spot
		if vehicle.get_current_mode() == VehicleStateMachine.Mode.SURFACE:
			hud.interact_prompt.visible = true
			var biome_name: String = spot.get_meta("biome", "shallow")
			hud.interact_prompt.text = "[E] Dive Here (%s)" % biome_name.capitalize()

func _on_dive_spot_exited(body: Node2D, spot: Area2D) -> void:
	if body == vehicle and near_dive_spot == spot:
		near_dive_spot = null
		if not near_hub_return:
			hud.interact_prompt.visible = false

func _on_hub_return_entered(body: Node2D) -> void:
	GameLog.vehicle("HubReturnZone body_entered — body=%s" % body.name)
	if body == vehicle:
		near_hub_return = true
		if vehicle.get_current_mode() == VehicleStateMachine.Mode.SURFACE:
			hud.interact_prompt.visible = true
			hud.interact_prompt.text = "[E] Return to Harbor"

func _on_hub_return_exited(body: Node2D) -> void:
	if body == vehicle:
		near_hub_return = false
		if near_dive_spot == null:
			hud.interact_prompt.visible = false
