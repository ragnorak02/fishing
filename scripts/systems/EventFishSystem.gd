class_name EventFishSystem
extends RefCounted

const SPAWN_CHANCE := 0.10  # 10% chance per spawn cycle

# World events that affect spawning globally
enum WorldEvent { NONE, FISH_MIGRATION, RED_TIDE, FULL_MOON, CORAL_BLOOM }

static func get_active_world_event() -> WorldEvent:
	var day := _get_current_day()
	var time := _get_current_time()

	# Full Moon: every 7th night
	if day % 7 == 0 and time == 4:  # NIGHT
		return WorldEvent.FULL_MOON

	# Fish Migration: days 10, 20, 30...
	if day % 10 == 0:
		return WorldEvent.FISH_MIGRATION

	# Red Tide: days 5, 15, 25... during afternoon/evening
	if day % 10 == 5 and time >= 2:  # AFTERNOON or later
		return WorldEvent.RED_TIDE

	# Coral Bloom: days 3, 13, 23... during morning
	if day % 10 == 3 and time == 0:  # MORNING
		return WorldEvent.CORAL_BLOOM

	return WorldEvent.NONE

static func get_world_event_name(event: WorldEvent) -> String:
	match event:
		WorldEvent.NONE: return ""
		WorldEvent.FISH_MIGRATION: return "Fish Migration"
		WorldEvent.RED_TIDE: return "Red Tide"
		WorldEvent.FULL_MOON: return "Full Moon"
		WorldEvent.CORAL_BLOOM: return "Coral Bloom"
	return ""

static func get_event_spawn_modifier(event: WorldEvent) -> Dictionary:
	# Returns modifiers for the event
	match event:
		WorldEvent.FISH_MIGRATION:
			return {"max_fish_bonus": 6, "spawn_interval_mult": 0.5}
		WorldEvent.RED_TIDE:
			return {"common_weight_mult": 0.3, "rare_weight_mult": 2.0}
		WorldEvent.FULL_MOON:
			return {"legendary_weight_mult": 3.0}
		WorldEvent.CORAL_BLOOM:
			return {"uncommon_weight_mult": 2.0, "max_fish_bonus": 3}
	return {}

static func get_eligible_event_fish(biome: String) -> Array[FishSpecies]:
	var eligible: Array[FishSpecies] = []
	var day := _get_current_day()
	var time := _get_current_time()

	for species in FishDatabase.get_all_species():
		if not species.is_event_fish:
			continue
		if day < species.event_min_day:
			continue
		if species.event_biome != "" and species.event_biome != biome:
			continue
		if species.event_times.size() > 0 and time not in species.event_times:
			continue
		if species.event_day_divisor > 0 and day % species.event_day_divisor != 0:
			continue
		eligible.append(species)

	return eligible

static func try_spawn_event_fish(biome: String) -> FishSpecies:
	var chance := SPAWN_CHANCE
	# World events can boost event fish spawn chance
	var event := get_active_world_event()
	if event == WorldEvent.FULL_MOON:
		chance = 0.25
	elif event == WorldEvent.FISH_MIGRATION:
		chance = 0.20

	if randf() > chance:
		return null
	var eligible := get_eligible_event_fish(biome)
	if eligible.is_empty():
		return null
	return eligible[randi() % eligible.size()]

static func _get_current_day() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		var tm = tree.root.get_node_or_null("/root/TimeManager")
		if tm and "current_day" in tm:
			return tm.current_day
	return 1

static func _get_current_time() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		var tm = tree.root.get_node_or_null("/root/TimeManager")
		if tm and "current_time" in tm:
			return tm.current_time
	return 0
