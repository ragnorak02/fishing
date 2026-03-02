class_name EventFishSystem
extends RefCounted

const SPAWN_CHANCE := 0.10  # 10% chance per spawn cycle

static func get_eligible_event_fish(biome: String) -> Array[FishSpecies]:
	var eligible: Array[FishSpecies] = []
	var day := _get_current_day()
	var time := _get_current_time()

	for species in FishDatabase.get_all_species():
		if not species.is_event_fish:
			continue
		# Check minimum day
		if day < species.event_min_day:
			continue
		# Check biome (empty means any biome)
		if species.event_biome != "" and species.event_biome != biome:
			continue
		# Check time-of-day (empty means any time)
		if species.event_times.size() > 0 and time not in species.event_times:
			continue
		# Check day divisor (0 means any day)
		if species.event_day_divisor > 0 and day % species.event_day_divisor != 0:
			continue
		eligible.append(species)

	return eligible

static func try_spawn_event_fish(biome: String) -> FishSpecies:
	if randf() > SPAWN_CHANCE:
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
