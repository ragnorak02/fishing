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

	print("=== OCEAN SURFACE DIAGNOSTIC — SIGNAL WIRING ===")
	print("[DIAG] Found %d dive spots" % spots.size())
	for spot in spots:
		var col_shape: CollisionShape2D = spot.get_node("CollisionShape2D")
		print("[DIAG] Spot: %s | pos=%s | monitoring=%s | monitorable=%s | layer=%d | mask=%d | shape=%s | shape_disabled=%s" % [
			spot.name, spot.global_position, spot.monitoring, spot.monitorable,
			spot.collision_layer, spot.collision_mask,
			col_shape.shape, col_shape.disabled])
		# Check signal connections before wiring
		var already_connected := spot.body_entered.is_connected(_on_dive_spot_entered)
		print("[DIAG]   body_entered already connected: %s" % already_connected)
		if not already_connected:
			spot.body_entered.connect(_on_dive_spot_entered.bind(spot))
			spot.body_exited.connect(_on_dive_spot_exited.bind(spot))
		print("[DIAG]   body_entered connections after wiring: %d" % spot.body_entered.get_connections().size())

	var hub_zone: Area2D = $HubReturnZone
	var hub_col: CollisionShape2D = hub_zone.get_node("CollisionShape2D")
	print("[DIAG] HubReturnZone | pos=%s | monitoring=%s | monitorable=%s | layer=%d | mask=%d | shape=%s | shape_disabled=%s" % [
		hub_zone.global_position, hub_zone.monitoring, hub_zone.monitorable,
		hub_zone.collision_layer, hub_zone.collision_mask,
		hub_col.shape, hub_col.disabled])
	hub_zone.body_entered.connect(_on_hub_return_entered)
	hub_zone.body_exited.connect(_on_hub_return_exited)

	var veh_col: CollisionShape2D = vehicle.get_node("CollisionShape2D")
	print("[DIAG] Vehicle | pos=%s | layer=%d | mask=%d | shape=%s | shape_disabled=%s" % [
		vehicle.global_position, vehicle.collision_layer, vehicle.collision_mask,
		veh_col.shape, veh_col.disabled])
	print("=== END SIGNAL WIRING DIAGNOSTIC ===")

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
	# === ALWAYS-ON DIAGNOSTIC (every ~2s = 120 frames) ===
	if Engine.get_process_frames() % 120 == 0:
		var veh_col: CollisionShape2D = vehicle.get_node("CollisionShape2D")
		print("[DIAG-TICK] Vehicle pos=%s | layer=%d | mask=%d | shape_disabled=%s | near_dive=%s | near_hub=%s" % [
			vehicle.global_position, vehicle.collision_layer, vehicle.collision_mask,
			veh_col.disabled, near_dive_spot != null, near_hub_return])
		# Check each dive spot overlap status
		for child in get_children():
			if child is Area2D and child.is_in_group("dive_spots"):
				var dist = vehicle.global_position.distance_to(child.global_position)
				var overlapping = child.get_overlapping_bodies()
				var spot_col: CollisionShape2D = child.get_node("CollisionShape2D")
				print("[DIAG-TICK]   %s | dist=%.0f | overlapping=%s | monitoring=%s | shape_disabled=%s" % [
					child.name, dist, overlapping, child.monitoring, spot_col.disabled])
		# Check hub return zone
		var hub: Area2D = $HubReturnZone
		var hub_dist := vehicle.global_position.distance_to(hub.global_position)
		var hub_overlapping = hub.get_overlapping_bodies()
		var hub_col_node: CollisionShape2D = hub.get_node("CollisionShape2D")
		print("[DIAG-TICK]   HubReturnZone | dist=%.0f | overlapping=%s | monitoring=%s | shape_disabled=%s" % [
			hub_dist, hub_overlapping, hub.monitoring, hub_col_node.disabled])

	var is_surface = vehicle.get_current_mode() == VehicleStateMachine.Mode.SURFACE

	# Interaction — only in surface mode
	if Input.is_action_just_pressed("interact"):
		print("[DIAG-INPUT] E pressed! mode=%d is_surface=%s near_dive=%s near_hub=%s" % [
			vehicle.get_current_mode(), is_surface, near_dive_spot != null, near_hub_return])
		if is_surface:
			if near_dive_spot:
				_start_dive(near_dive_spot)
			elif near_hub_return:
				GameManager.transition_to("res://scenes/restaurant/Restaurant.tscn")

	# Transform vehicle
	if Input.is_action_just_pressed("transform_vehicle") and not vehicle.is_transforming():
		var current_mode = vehicle.get_current_mode()
		if current_mode == VehicleStateMachine.Mode.SURFACE:
			vehicle.request_transform(VehicleStateMachine.Mode.SUBMERGED)
		elif current_mode == VehicleStateMachine.Mode.SUBMERGED:
			var depth_sys: DepthSystem = vehicle.get_node_or_null("DepthSystem")
			if depth_sys and not depth_sys.is_at_surface():
				# Show "ascend first" message
				hud.interact_prompt.visible = true
				hud.interact_prompt.text = "Ascend to surface first!"
				# Auto-hide after 1.5s
				get_tree().create_timer(1.5).timeout.connect(func():
					if not near_dive_spot and not near_hub_return:
						hud.interact_prompt.visible = false
				)
			else:
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
	print("[OceanSurface] body_entered on %s — body=%s (is vehicle: %s)" % [spot.name, body.name, body == vehicle])
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
	print("[OceanSurface] HubReturnZone body_entered — body=%s (is vehicle: %s)" % [body.name, body == vehicle])
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
