extends Node2D

@export var biome: String = "shallow"
@export var max_fish: int = 12
@export var spawn_interval: float = 3.0
@export var spawn_bounds: Rect2 = Rect2(-700, -400, 1400, 800)

var fish_scene_template: PackedScene = null
var active_fish: Array[Node2D] = []
var spawn_timer: float = 0.0
var initial_spawn_count: int = 8

func _ready() -> void:
	tree_exiting.connect(_cleanup)

	# Spawn initial fish
	for i in initial_spawn_count:
		_spawn_fish()

func _process(delta: float) -> void:
	# Clean up dead fish references
	active_fish = active_fish.filter(func(f): return is_instance_valid(f))

	# Respawn
	spawn_timer -= delta
	if spawn_timer <= 0 and active_fish.size() < max_fish:
		_spawn_fish()
		spawn_timer = spawn_interval

func _spawn_fish() -> void:
	var species := FishDatabase.get_random_species_for_biome(biome)
	if species == null:
		return

	var fish := _create_fish_node(species)
	if fish == null:
		return

	# Random position within bounds
	fish.global_position = Vector2(
		randf_range(spawn_bounds.position.x, spawn_bounds.position.x + spawn_bounds.size.x),
		randf_range(spawn_bounds.position.y, spawn_bounds.position.y + spawn_bounds.size.y)
	)

	get_parent().add_child(fish)
	active_fish.append(fish)

func _create_fish_node(species: FishSpecies) -> CharacterBody2D:
	# Create fish programmatically
	var fish := CharacterBody2D.new()
	fish.name = "Fish_" + species.id + "_" + str(randi())

	# Add sprite
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	fish.add_child(sprite)

	# Add collision shape
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	fish.add_child(col)

	# Add hitbox area
	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	var hitbox_col := CollisionShape2D.new()
	hitbox_col.name = "CollisionShape2D"
	hitbox.add_child(hitbox_col)
	fish.add_child(hitbox)

	# Attach FishAI script
	var script = load("res://scripts/entities/FishAI.gd")
	fish.set_script(script)

	# Store species data for later setup
	fish.set_meta("species_id", species.id)
	fish.set_meta("species", species)
	fish.set_meta("spawn_bounds", spawn_bounds)

	return fish

func _cleanup() -> void:
	for fish in active_fish:
		if is_instance_valid(fish):
			fish.queue_free()
	active_fish.clear()
