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

	# Apply world event modifiers
	var event := EventFishSystem.get_active_world_event()
	if event != EventFishSystem.WorldEvent.NONE:
		var mods := EventFishSystem.get_event_spawn_modifier(event)
		if mods.has("max_fish_bonus"):
			max_fish += mods["max_fish_bonus"]
		if mods.has("spawn_interval_mult"):
			spawn_interval *= mods["spawn_interval_mult"]
		initial_spawn_count = mini(initial_spawn_count + 2, max_fish)

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
	# Try event fish first
	var species := EventFishSystem.try_spawn_event_fish(biome)
	if species == null:
		species = _get_weather_adjusted_species()
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

	get_parent().add_child.call_deferred(fish)
	active_fish.append(fish)

func _create_fish_node(species: FishSpecies) -> CharacterBody2D:
	var fish := CharacterBody2D.new()
	fish.name = "Fish_" + species.id + "_" + str(randi())

	# Attach script BEFORE adding children so @onready vars resolve
	var script = load("res://scripts/entities/FishAI.gd")
	fish.set_script(script)

	# Set metadata before node enters tree (FishAI._ready() reads these)
	fish.set_meta("species_id", species.id)
	fish.set_meta("species", species)
	fish.set_meta("spawn_bounds", spawn_bounds)

	# Add children after script is set
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	fish.add_child(sprite)

	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	fish.add_child(col)

	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	var hitbox_col := CollisionShape2D.new()
	hitbox_col.name = "CollisionShape2D"
	hitbox.add_child(hitbox_col)
	fish.add_child(hitbox)

	return fish

func _get_weather_adjusted_species() -> FishSpecies:
	# Apply weather rarity bonuses to normal spawning
	var ws = Engine.get_main_loop().root.get_node_or_null("/root/WeatherSystem")
	if ws == null:
		return FishDatabase.get_random_species_for_biome(biome)

	var bonus: Dictionary = ws.get_rarity_bonus()
	if bonus.is_empty():
		return FishDatabase.get_random_species_for_biome(biome)

	# Get candidates for this biome
	FishDatabase._ensure_loaded()
	var adjusted_weights := FishScaling.get_adjusted_rarity_weights()
	var candidates: Array[FishSpecies] = []
	var weights: Array[float] = []
	for species: FishSpecies in FishDatabase.get_all_species():
		if biome in species.biomes and not species.is_event_fish:
			candidates.append(species)
			var w: float = adjusted_weights[species.rarity]
			if bonus.has(species.rarity):
				w += bonus[species.rarity]
			weights.append(w)

	if candidates.is_empty():
		return FishDatabase.get_random_species_for_biome(biome)

	var total_weight := 0.0
	for w in weights:
		total_weight += w
	var roll := randf() * total_weight
	var cumulative := 0.0
	for i in candidates.size():
		cumulative += weights[i]
		if roll <= cumulative:
			return candidates[i]
	return candidates[-1]

func _cleanup() -> void:
	for fish in active_fish:
		if is_instance_valid(fish):
			fish.queue_free()
	active_fish.clear()
