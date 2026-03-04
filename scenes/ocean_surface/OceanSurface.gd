extends Node2D

const FishingMinigameScene = preload("res://scripts/ui/FishingMinigame.gd")

@onready var vehicle: CharacterBody2D = $Vehicle
@onready var hud = $VehicleHUD

var near_dive_spot: Area2D = null
var near_hub_return: bool = false

const MAP_BOUNDS := Rect2(-1500, -1500, 3000, 3000)

# Sonar ring visual
var sonar_ring: Node2D = null

# Fish spot markers (sonar-detected)
var fish_markers: Dictionary = {}  # Area2D -> Node2D (marker)

# Surface fishing state
var is_fishing: bool = false
var active_minigame: Control = null

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

	# Track whether interact consumed this frame (prevents mode_up double-firing on E)
	var interaction_handled: bool = false

	# Interaction — dive spot / hub return (E / A)
	if Input.is_action_just_pressed("interact") and not is_fishing:
		GameLog.vehicle("interact pressed | mode=%d is_surface=%s near_dive=%s near_hub=%s" % [
			vehicle.get_current_mode(), is_surface, near_dive_spot != null, near_hub_return])
		if is_surface:
			if near_dive_spot and _spot_has_marker(near_dive_spot):
				_start_fishing_minigame(near_dive_spot)
				interaction_handled = true
			elif near_dive_spot:
				_start_dive(near_dive_spot)
				interaction_handled = true
			elif near_hub_return:
				GameManager.transition_to("res://scenes/restaurant/Restaurant.tscn")
				interaction_handled = true

	# Cast line (F/X) — always dives at any dive spot
	if Input.is_action_just_pressed("cast_line") and not is_fishing:
		if is_surface and near_dive_spot:
			_start_dive(near_dive_spot)

	# Mode Down (Q / LT) — go down one level: AIR→SURFACE, SURFACE→SUBMERGED
	# Illegal: SUBMERGED→ (already at lowest — silently ignored)
	if Input.is_action_just_pressed("mode_down"):
		print("[OCEAN_CTRL] mode_down detected | is_transforming=%s | mode=%d | submerge_unlocked=%s" % [
			vehicle.is_transforming(), vehicle.get_current_mode(), GameManager.submerge_unlocked])
	if Input.is_action_just_pressed("mode_down") and not vehicle.is_transforming():
		var current_mode = vehicle.get_current_mode()
		if current_mode == VehicleStateMachine.Mode.AIR:
			vehicle.request_transform(VehicleStateMachine.Mode.SURFACE)
		elif current_mode == VehicleStateMachine.Mode.SURFACE:
			if not GameManager.submerge_unlocked:
				hud.interact_prompt.visible = true
				hud.interact_prompt.text = "Submerge not unlocked yet!"
				get_tree().create_timer(1.5).timeout.connect(func():
					if not near_dive_spot and not near_hub_return:
						hud.interact_prompt.visible = false
				)
			else:
				vehicle.request_transform(VehicleStateMachine.Mode.SUBMERGED)
		# SUBMERGED + mode_down = already at lowest level — blocked

	# Mode Up (E / RT) — go up one level: SUBMERGED→SURFACE, SURFACE→AIR
	# Illegal: AIR→ (already at highest — silently ignored)
	# Guarded by interaction_handled so E doesn't rise while also diving
	if Input.is_action_just_pressed("mode_up"):
		print("[OCEAN_CTRL] mode_up detected | is_transforming=%s | mode=%d | air_unlocked=%s | interaction_handled=%s" % [
			vehicle.is_transforming(), vehicle.get_current_mode(), GameManager.air_mode_unlocked, interaction_handled])
	if Input.is_action_just_pressed("mode_up") and not vehicle.is_transforming() and not interaction_handled:
		var current_mode = vehicle.get_current_mode()
		if current_mode == VehicleStateMachine.Mode.SUBMERGED:
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
		elif current_mode == VehicleStateMachine.Mode.SURFACE:
			if not GameManager.air_mode_unlocked:
				hud.interact_prompt.visible = true
				hud.interact_prompt.text = "Air mode not unlocked yet!"
				get_tree().create_timer(1.5).timeout.connect(func():
					if not near_dive_spot and not near_hub_return:
						hud.interact_prompt.visible = false
				)
			else:
				vehicle.request_transform(VehicleStateMachine.Mode.AIR)
		# AIR + mode_up = already at highest level — blocked

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
	_detect_fish_spots(origin, pulse_range)

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

# --- Fish spot detection & markers ---

func _detect_fish_spots(origin: Vector2, pulse_range: float) -> void:
	for child in get_children():
		if child is Area2D and child.is_in_group("dive_spots"):
			if origin.distance_to(child.global_position) <= pulse_range:
				_spawn_fish_marker(child)

func _spawn_fish_marker(spot: Area2D) -> void:
	# Free existing marker for this spot
	if fish_markers.has(spot) and is_instance_valid(fish_markers[spot]):
		fish_markers[spot].queue_free()

	var marker := Node2D.new()
	marker.global_position = spot.global_position
	add_child(marker)
	fish_markers[spot] = marker

	# Gold diamond shape
	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([
		Vector2(0, -12), Vector2(10, 0), Vector2(0, 12), Vector2(-10, 0)
	])
	diamond.color = Color(1.0, 0.85, 0.2, 0.9)
	marker.add_child(diamond)

	# Pulsing scale tween on diamond
	var pulse_tween := create_tween().set_loops(10)
	pulse_tween.tween_property(diamond, "scale", Vector2(1.3, 1.3), 0.6)
	pulse_tween.tween_property(diamond, "scale", Vector2.ONE, 0.6)

	# Gold ring outline
	var ring := Line2D.new()
	ring.width = 2.0
	ring.default_color = Color(1.0, 0.85, 0.2, 0.5)
	ring.closed = true
	var points: PackedVector2Array = []
	for i in 25:
		var angle := (float(i) / 24.0) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * 25.0)
	ring.points = points
	marker.add_child(ring)

	# "FISH" label
	var label := Label.new()
	label.text = "FISH"
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-16, -28)
	marker.add_child(label)

	# Hold 8s, then fade 2s, then free
	get_tree().create_timer(8.0).timeout.connect(func():
		if is_instance_valid(marker):
			var fade := create_tween()
			fade.tween_property(marker, "modulate:a", 0.0, 2.0)
			fade.tween_callback(func():
				if is_instance_valid(marker):
					marker.queue_free()
				fish_markers.erase(spot)
			)
	)

	# Update prompt if player is near this spot
	if near_dive_spot == spot and vehicle.get_current_mode() == VehicleStateMachine.Mode.SURFACE:
		_update_dive_spot_prompt(spot)

func _spot_has_marker(spot: Area2D) -> bool:
	return fish_markers.has(spot) and is_instance_valid(fish_markers[spot])

func _update_dive_spot_prompt(spot: Area2D) -> void:
	var biome_name: String = spot.get_meta("biome", "shallow").capitalize()
	if _spot_has_marker(spot):
		hud.interact_prompt.text = "[E] Fish Here  |  [F] Dive (%s)" % biome_name
	else:
		hud.interact_prompt.text = "[E] Dive Here (%s)" % biome_name

# --- Surface fishing minigame ---

func _start_fishing_minigame(spot: Area2D) -> void:
	is_fishing = true
	vehicle.movement_locked = true
	var biome_str: String = spot.get_meta("biome", "shallow")
	active_minigame = FishingMinigameScene.new(biome_str)
	hud.add_child(active_minigame)
	active_minigame.fishing_completed.connect(_on_fishing_completed)
	active_minigame.fishing_failed.connect(_on_fishing_ended)

func _on_fishing_completed(species_id: String, weight: float) -> void:
	# Build fish entry directly into storage (not haul)
	var species = FishDatabase.get_species(species_id)
	if species:
		var value := int(species.base_value * (weight / species.weight_range.y))
		value = maxi(value, 1)
		Inventory.fish_storage.append({
			"species_id": species_id,
			"name": species.display_name,
			"weight": weight,
			"value": value,
			"rarity": species.rarity,
			"sushi_grade": species.sushi_grade,
		})
		Inventory.storage_changed.emit()

		# Track species discovery + catch stats
		SaveManager.record_catch(species_id)

		# Play catch SFX
		AudioManager.play_sfx("catch")

	_on_fishing_ended()

func _on_fishing_ended() -> void:
	is_fishing = false
	vehicle.movement_locked = false
	active_minigame = null

# --- Dive/Hub interaction signals ---

func _on_dive_spot_entered(body: Node2D, spot: Area2D) -> void:
	GameLog.vehicle("body_entered on %s — body=%s" % [spot.name, body.name])
	if body == vehicle:
		near_dive_spot = spot
		if vehicle.get_current_mode() == VehicleStateMachine.Mode.SURFACE:
			hud.interact_prompt.visible = true
			_update_dive_spot_prompt(spot)

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
