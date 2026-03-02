extends Node2D

@onready var diver: CharacterBody2D = $Diver
@onready var oxygen_system: Node = $OxygenSystem
@onready var fish_spawner: Node2D = $FishSpawner
@onready var oxygen_bar: ProgressBar = $DiveHUD/OxygenBar
@onready var oxygen_label: Label = $DiveHUD/OxygenLabel
@onready var catch_label: Label = $DiveHUD/CatchLabel
@onready var depth_label: Label = $DiveHUD/DepthLabel
@onready var surface_prompt: Label = $DiveHUD/SurfacePrompt

var near_surface: bool = false
var dive_start_time: float = 0.0

const DIVE_BOUNDS := Rect2(-800, -100, 1600, 1200)
const AIM_DEADZONE := 0.2
const HARPOON_BASE_RANGE := 250.0

var _harpoon_scene: PackedScene = preload("res://scenes/entities/harpoon.tscn")

# Hold-aim-release state
var is_aiming: bool = false
var aim_direction: Vector2 = Vector2.RIGHT
var aim_indicator: Line2D = null
var active_harpoon: Area2D = null
var harpoon_rope: Line2D = null

func _ready() -> void:
	AudioManager.play_music("dive")
	dive_start_time = Time.get_ticks_msec() / 1000.0
	surface_prompt.visible = false

	# Configure spawner biome
	fish_spawner.biome = GameManager.current_dive_biome

	# Connect oxygen signals
	oxygen_system.oxygen_changed.connect(_on_oxygen_changed)
	oxygen_system.oxygen_depleted.connect(_on_oxygen_depleted)

	# Connect surface zone
	$SurfaceZone.body_entered.connect(_on_surface_entered)
	$SurfaceZone.body_exited.connect(_on_surface_exited)

	# Set up surface zone collision
	var surface_col: CollisionShape2D = $SurfaceZone/CollisionShape2D
	if surface_col.shape == null:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(1600, 60)
		surface_col.shape = rect

	# Create boundaries
	_create_boundaries()

	# Create terrain colliders so diver can't clip through floor/rocks/coral
	_create_terrain_colliders()

	# Add diver to group
	diver.add_to_group("diver")

	_update_catch_label()

	# Ambient underwater bubbles
	_create_ambient_bubbles()

	print("[DiveScene] Ready — diver at ", diver.global_position, " | fish_spawner biome: ", fish_spawner.biome)

func _create_boundaries() -> void:
	var bounds := $Boundaries as StaticBody2D
	var walls := [
		[Vector2(0, DIVE_BOUNDS.position.y - 10), Vector2(DIVE_BOUNDS.size.x + 100, 20)],  # Top (above surface)
		[Vector2(0, DIVE_BOUNDS.position.y + DIVE_BOUNDS.size.y + 10), Vector2(DIVE_BOUNDS.size.x + 100, 20)],  # Bottom
		[Vector2(DIVE_BOUNDS.position.x - 10, DIVE_BOUNDS.get_center().y), Vector2(20, DIVE_BOUNDS.size.y + 100)],  # Left
		[Vector2(DIVE_BOUNDS.position.x + DIVE_BOUNDS.size.x + 10, DIVE_BOUNDS.get_center().y), Vector2(20, DIVE_BOUNDS.size.y + 100)],  # Right
	]
	for wall_data in walls:
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = wall_data[1]
		col.shape = rect
		col.position = wall_data[0]
		bounds.add_child(col)

func _create_terrain_colliders() -> void:
	var terrain_nodes := ["SeaFloor", "CoralLeft", "CoralCenter", "CoralRight", "RockLeft", "RockRight"]
	for node_name in terrain_nodes:
		var rect_node := get_node_or_null(node_name) as ColorRect
		if rect_node == null:
			continue
		var left := rect_node.offset_left
		var top := rect_node.offset_top
		var right := rect_node.offset_right
		var bottom := rect_node.offset_bottom
		var size := Vector2(right - left, bottom - top)
		var center := Vector2((left + right) / 2.0, (top + bottom) / 2.0)

		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
		body.position = center
		rect_node.add_child(body)

func _process(delta: float) -> void:
	# --- Aim / Fire flow ---
	if Input.is_action_just_pressed("fire_harpoon") and not is_aiming and active_harpoon == null:
		_begin_aim()
	elif is_aiming:
		_update_aim()
		if Input.is_action_just_released("fire_harpoon"):
			_release_fire()

	# Update rope while harpoon is in flight
	if active_harpoon and is_instance_valid(active_harpoon) and harpoon_rope:
		harpoon_rope.set_point_position(0, diver.global_position)
		harpoon_rope.set_point_position(1, active_harpoon.global_position)

	# Surface interaction
	if near_surface and Input.is_action_just_pressed("interact"):
		_end_dive()

	# Update depth display (positive Y = deeper)
	if is_instance_valid(diver):
		var depth := maxf(0.0, diver.global_position.y / 10.0)
		depth_label.text = "Depth: %.1fm" % depth

func _begin_aim() -> void:
	is_aiming = true
	diver.movement_locked = true
	aim_direction = Vector2.RIGHT

	# Create aim indicator line
	aim_indicator = Line2D.new()
	aim_indicator.width = 2.0
	aim_indicator.z_index = 15
	aim_indicator.default_color = Color(1.0, 0.85, 0.2, 0.7)
	# Gradient fading to transparent
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.2, 0.7))
	grad.set_color(1, Color(1.0, 0.85, 0.2, 0.0))
	aim_indicator.gradient = grad
	aim_indicator.add_point(Vector2.ZERO)
	aim_indicator.add_point(Vector2.ZERO)
	add_child(aim_indicator)

	# Light haptic pulse
	Input.start_joy_vibration(0, 0.15, 0.0, 0.1)

func _update_aim() -> void:
	# Right stick input
	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	if stick.length() > AIM_DEADZONE:
		aim_direction = stick.normalized()
	else:
		# Fall back to mouse position relative to diver
		var mouse_pos := diver.get_global_mouse_position()
		var to_mouse := mouse_pos - diver.global_position
		if to_mouse.length() > 5.0:
			aim_direction = to_mouse.normalized()

	# Update aim indicator
	if aim_indicator:
		var start := diver.global_position
		var max_range: float = HARPOON_BASE_RANGE * GameManager.get_harpoon_range_multiplier()
		var end := start + aim_direction * max_range
		aim_indicator.set_point_position(0, start)
		aim_indicator.set_point_position(1, end)

func _release_fire() -> void:
	is_aiming = false
	diver.movement_locked = false

	# Remove aim indicator
	if aim_indicator:
		aim_indicator.queue_free()
		aim_indicator = null

	_fire_harpoon()

func _fire_harpoon() -> void:
	var harpoon := _harpoon_scene.instantiate() as Area2D

	harpoon.direction = aim_direction
	harpoon.rotation = aim_direction.angle()
	harpoon.diver_ref = diver

	harpoon.fish_hit.connect(_on_harpoon_hit)
	harpoon.missed.connect(_on_harpoon_missed.bind(harpoon))
	harpoon.returned.connect(_on_harpoon_returned)

	harpoon.position = diver.global_position + aim_direction * 15.0
	add_child(harpoon)
	active_harpoon = harpoon

	# Create rope line
	harpoon_rope = Line2D.new()
	harpoon_rope.width = 1.5
	harpoon_rope.z_index = 9
	harpoon_rope.default_color = Color(0.6, 0.6, 0.6, 0.4)
	harpoon_rope.add_point(diver.global_position)
	harpoon_rope.add_point(harpoon.global_position)
	add_child(harpoon_rope)

func _on_harpoon_hit(fish: Node2D) -> void:
	if fish.has_meta("species_id"):
		var species_id: String = fish.get_meta("species_id")
		var species := FishDatabase.get_species(species_id)
		if species:
			var is_new := not SaveManager.is_species_discovered(species_id)
			var weight := FishScaling.get_scaled_weight(species)
			Inventory.add_to_haul(species_id, weight)
			_update_catch_label()

			# Catch effect
			_spawn_catch_effect(fish.global_position)

			# New species discovery label
			if is_new:
				_spawn_discovery_label(fish.global_position)

	fish.queue_free()

func _on_harpoon_missed(harpoon_node: Node2D) -> void:
	var pos := harpoon_node.global_position if is_instance_valid(harpoon_node) else diver.global_position

	# Splash particles
	var splash := CPUParticles2D.new()
	splash.emitting = true
	splash.one_shot = true
	splash.amount = 8
	splash.lifetime = 0.5
	splash.explosiveness = 0.9
	splash.direction = Vector2(0, -1)
	splash.spread = 120.0
	splash.gravity = Vector2(0, -15)
	splash.initial_velocity_min = 20.0
	splash.initial_velocity_max = 45.0
	splash.scale_amount_min = 0.8
	splash.scale_amount_max = 2.0
	splash.color = Color(0.3, 0.7, 0.8, 0.5)
	add_child(splash)
	splash.global_position = pos
	get_tree().create_timer(1.0).timeout.connect(splash.queue_free)

	# SFX
	AudioManager.play_sfx("harpoon_miss")

	# Brief rumble
	Input.start_joy_vibration(0, 0.3, 0.1, 0.15)

	# Red flash on diver
	var tween := create_tween()
	tween.tween_property(diver, "modulate", Color(1, 0.4, 0.4), 0.1)
	tween.tween_property(diver, "modulate", Color(1, 1, 1), 0.2)

func _on_harpoon_returned() -> void:
	# Clean up rope
	if harpoon_rope:
		harpoon_rope.queue_free()
		harpoon_rope = null
	active_harpoon = null

func _spawn_catch_effect(pos: Vector2) -> void:
	# Floating text
	var effect := Label.new()
	effect.text = "Caught!"
	effect.add_theme_color_override("font_color", Color(1, 1, 0.3))
	effect.add_theme_font_size_override("font_size", 14)
	add_child(effect)
	effect.global_position = pos + Vector2(-20, -20)

	var tween := create_tween()
	tween.tween_property(effect, "global_position:y", pos.y - 50, 0.8)
	tween.parallel().tween_property(effect, "modulate:a", 0.0, 0.8)
	tween.tween_callback(effect.queue_free)

	# Bubble burst particles
	var burst := CPUParticles2D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.amount = 12
	burst.lifetime = 0.6
	burst.explosiveness = 0.9
	burst.direction = Vector2(0, -1)
	burst.spread = 180.0
	burst.gravity = Vector2(0, -20)
	burst.initial_velocity_min = 30.0
	burst.initial_velocity_max = 60.0
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 3.0
	burst.color = Color(0.7, 0.9, 1.0, 0.6)
	add_child(burst)
	burst.global_position = pos
	get_tree().create_timer(1.0).timeout.connect(burst.queue_free)

func _spawn_discovery_label(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "NEW SPECIES!"
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)
	label.global_position = pos + Vector2(-45, -45)
	label.z_index = 20

	var tween := create_tween()
	tween.tween_property(label, "global_position:y", pos.y - 80, 1.2)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2).set_delay(0.5)
	tween.tween_callback(label.queue_free)

func _create_ambient_bubbles() -> void:
	var bubbles := CPUParticles2D.new()
	bubbles.name = "AmbientBubbles"
	bubbles.amount = 20
	bubbles.lifetime = 4.0
	bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bubbles.emission_rect_extents = Vector2(800, 50)
	bubbles.position = Vector2(0, 500)
	bubbles.direction = Vector2(0, -1)
	bubbles.gravity = Vector2(0, -10)
	bubbles.initial_velocity_min = 15.0
	bubbles.initial_velocity_max = 40.0
	bubbles.scale_amount_min = 0.5
	bubbles.scale_amount_max = 2.0
	bubbles.color = Color(0.66, 0.85, 0.94, 0.35)
	var bubble_tex = load("res://assets/sprites/effects/bubble.svg")
	if bubble_tex:
		bubbles.texture = bubble_tex
	add_child(bubbles)

func _update_catch_label() -> void:
	catch_label.text = "Catch: %d fish" % Inventory.current_haul.size()

func _on_oxygen_changed(current: float, maximum: float) -> void:
	oxygen_bar.value = (current / maximum) * 100.0
	oxygen_label.text = "O2: %ds" % int(current)

	# Warning flash when low
	if current / maximum < 0.2:
		oxygen_bar.modulate = Color(1, 0.3, 0.3) if fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.25 else Color(1, 0.6, 0.3)
	else:
		oxygen_bar.modulate = Color(0.3, 0.8, 1.0)

func _on_oxygen_depleted() -> void:
	# Forced surface — end dive
	_end_dive()

func _on_surface_entered(body: Node2D) -> void:
	if body == diver:
		near_surface = true
		surface_prompt.visible = true

func _on_surface_exited(body: Node2D) -> void:
	if body == diver:
		near_surface = false
		surface_prompt.visible = false

func _end_dive() -> void:
	# Cancel aim state if active
	if is_aiming:
		is_aiming = false
		diver.movement_locked = false
		if aim_indicator:
			aim_indicator.queue_free()
			aim_indicator = null

	# Free active harpoon and rope if in flight
	if active_harpoon and is_instance_valid(active_harpoon):
		active_harpoon.queue_free()
		active_harpoon = null
	if harpoon_rope:
		harpoon_rope.queue_free()
		harpoon_rope = null

	var dive_time := Time.get_ticks_msec() / 1000.0 - dive_start_time
	# Store dive stats for haul summary
	GameManager.set_meta("last_dive_time", dive_time)
	GameManager.set_meta("last_dive_count", Inventory.current_haul.size())
	GameManager.transition_to("res://scenes/haul_summary/HaulSummary.tscn")
