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
var harpoon_cooldown: float = 0.0
const HARPOON_COOLDOWN_TIME := 0.5

const DIVE_BOUNDS := Rect2(-800, -100, 1600, 1200)

func _ready() -> void:
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

	# Add diver to group
	diver.add_to_group("diver")

	_update_catch_label()

	# Ambient underwater bubbles
	_create_ambient_bubbles()

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

func _process(delta: float) -> void:
	# Harpoon firing
	harpoon_cooldown -= delta
	if Input.is_action_just_pressed("fire_harpoon") and harpoon_cooldown <= 0:
		_fire_harpoon()
		harpoon_cooldown = HARPOON_COOLDOWN_TIME

	# Surface interaction
	if near_surface and Input.is_action_just_pressed("interact"):
		_end_dive()

	# Update depth display
	var depth := max(0, diver.global_position.y / 10.0)
	depth_label.text = "Depth: %.1fm" % depth

func _fire_harpoon() -> void:
	var harpoon_script = load("res://scripts/entities/Harpoon.gd")
	var harpoon := Area2D.new()
	harpoon.set_script(harpoon_script)

	var mouse_pos := diver.get_global_mouse_position()
	var direction := (mouse_pos - diver.global_position).normalized()

	harpoon.direction = direction
	harpoon.rotation = direction.angle()

	harpoon.fish_hit.connect(_on_harpoon_hit)
	harpoon.missed.connect(_on_harpoon_missed)

	add_child(harpoon)
	harpoon.global_position = diver.global_position + direction * 15.0

func _on_harpoon_hit(fish: Node2D) -> void:
	if fish.has_meta("species_id"):
		var species_id: String = fish.get_meta("species_id")
		var species := FishDatabase.get_species(species_id)
		if species:
			var weight := species.get_random_weight()
			Inventory.add_to_haul(species_id, weight)
			_update_catch_label()

			# Catch effect
			_spawn_catch_effect(fish.global_position)

	fish.queue_free()

func _on_harpoon_missed() -> void:
	pass  # Could add miss feedback

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
	var dive_time := Time.get_ticks_msec() / 1000.0 - dive_start_time
	# Store dive stats for haul summary
	GameManager.set_meta("last_dive_time", dive_time)
	GameManager.set_meta("last_dive_count", Inventory.current_haul.size())
	GameManager.transition_to("res://scenes/haul_summary/HaulSummary.tscn")
