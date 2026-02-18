extends CharacterBody2D

enum State { IDLE, SWIMMING, FLEEING }

var species: FishSpecies = null
var current_state: State = State.IDLE
var swim_direction: Vector2 = Vector2.RIGHT
var state_timer: float = 0.0
var awareness_radius: float = 100.0
var flee_target: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox

# Boundary for fish movement
var bounds: Rect2 = Rect2(-800, -600, 1600, 1200)

func _ready() -> void:
	add_to_group("fish")

	# Set up collision (for harpoon detection)
	var col := $CollisionShape2D as CollisionShape2D
	if col.shape == null:
		var circle := CircleShape2D.new()
		circle.radius = 10.0
		col.shape = circle
	collision_layer = 4  # Fish layer
	collision_mask = 0   # Don't collide with anything

	# Set up hitbox area
	if hitbox:
		var hitbox_col: CollisionShape2D = hitbox.get_node_or_null("CollisionShape2D")
		if hitbox_col and hitbox_col.shape == null:
			var circle := CircleShape2D.new()
			circle.radius = 12.0
			hitbox_col.shape = circle
		hitbox.collision_layer = 4
		hitbox.collision_mask = 8  # Detect harpoon

	# Auto-setup from metadata (set by FishSpawner)
	if has_meta("species") and has_meta("spawn_bounds"):
		setup(get_meta("species"), get_meta("spawn_bounds"))

	_enter_state(State.IDLE)

func setup(fish_species: FishSpecies, spawn_bounds: Rect2) -> void:
	species = fish_species
	bounds = spawn_bounds
	awareness_radius = species.awareness_radius

	_load_species_sprite()

func _load_species_sprite() -> void:
	if species == null or sprite == null:
		return
	var tex_path := "res://assets/sprites/fish/%s.svg" % species.id
	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)
		# Scale by species value — small common fish stay small, legendary fish are large
		var size_factor := clamp(species.base_value / 50.0, 0.5, 2.5)
		sprite.scale = Vector2(size_factor, size_factor)
	# Tint slightly toward rarity color
	sprite.modulate = species.get_rarity_color().lerp(Color.WHITE, 0.7)

func _physics_process(delta: float) -> void:
	state_timer -= delta

	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.SWIMMING:
			_process_swimming(delta)
		State.FLEEING:
			_process_fleeing(delta)

	# Check for nearby player (diver)
	if current_state != State.FLEEING:
		_check_for_threats()

	# Boundary wrapping
	_enforce_bounds()

	move_and_slide()

func _enter_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.IDLE:
			state_timer = randf_range(1.0, 3.0)
			velocity = Vector2.ZERO
		State.SWIMMING:
			state_timer = randf_range(2.0, 5.0)
			swim_direction = Vector2.RIGHT.rotated(randf() * TAU)
			if sprite:
				sprite.flip_h = swim_direction.x < 0
		State.FLEEING:
			state_timer = randf_range(1.5, 3.0)

func _process_idle(_delta: float) -> void:
	# Gentle bob
	velocity = Vector2(0, sin(Time.get_ticks_msec() * 0.002) * 5.0)
	if state_timer <= 0:
		_enter_state(State.SWIMMING)

func _process_swimming(delta: float) -> void:
	var speed := species.swim_speed if species else 60.0
	velocity = swim_direction * speed

	# Slight random wobble
	swim_direction = swim_direction.rotated(randf_range(-0.5, 0.5) * delta)

	if sprite:
		sprite.flip_h = velocity.x < 0

	if state_timer <= 0:
		_enter_state(State.IDLE)

func _process_fleeing(delta: float) -> void:
	var speed := species.flee_speed if species else 120.0
	var flee_dir := (global_position - flee_target).normalized()
	velocity = flee_dir * speed

	if sprite:
		sprite.flip_h = velocity.x < 0

	if state_timer <= 0:
		_enter_state(State.SWIMMING)

func _check_for_threats() -> void:
	# Find the diver
	var divers := get_tree().get_nodes_in_group("diver")
	if divers.is_empty():
		return
	var diver: Node2D = divers[0]
	var dist := global_position.distance_to(diver.global_position)
	if dist < awareness_radius:
		flee_target = diver.global_position
		_enter_state(State.FLEEING)

func _enforce_bounds() -> void:
	if not bounds.has_point(global_position):
		# Steer back toward center
		var center := bounds.get_center()
		var to_center := (center - global_position).normalized()
		swim_direction = to_center
		if current_state == State.FLEEING:
			_enter_state(State.SWIMMING)
		global_position = global_position.clamp(bounds.position, bounds.position + bounds.size)
