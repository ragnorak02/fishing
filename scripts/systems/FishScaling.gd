class_name FishScaling
extends RefCounted

# Difficulty scales with day progression
const DIFFICULTY_PER_DAY := 0.06
const MAX_DIFFICULTY := 2.0

# Reward scales with total upgrade levels
const MAX_UPGRADE_LEVELS := 18  # 6 tracks * 3 max each
const MAX_REWARD_FACTOR := 1.5

static func get_difficulty_factor() -> float:
	var tm = Engine.get_singleton("TimeManager") if Engine.has_singleton("TimeManager") else null
	var day := 1
	if tm == null:
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			tm = tree.root.get_node_or_null("/root/TimeManager")
	if tm and "current_day" in tm:
		day = tm.current_day
	var factor := 1.0 + (day - 1) * DIFFICULTY_PER_DAY
	return minf(factor, MAX_DIFFICULTY)

static func get_reward_factor() -> float:
	var gm_node: Node = null
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		gm_node = tree.root.get_node_or_null("/root/GameManager")
	if gm_node == null:
		return 1.0
	var total_levels := 0
	total_levels += gm_node.boat_speed_level
	total_levels += gm_node.oxygen_tank_level
	total_levels += gm_node.harpoon_range_level
	total_levels += gm_node.hull_durability_level
	total_levels += gm_node.battery_capacity_level
	total_levels += gm_node.sonar_range_level
	var factor := 1.0 + (float(total_levels) / MAX_UPGRADE_LEVELS) * (MAX_REWARD_FACTOR - 1.0)
	return minf(factor, MAX_REWARD_FACTOR)

static func get_scaled_swim_speed(species: FishSpecies) -> float:
	return species.swim_speed * get_difficulty_factor()

static func get_scaled_flee_speed(species: FishSpecies) -> float:
	return species.flee_speed * get_difficulty_factor()

static func get_scaled_awareness(species: FishSpecies) -> float:
	return species.awareness_radius * get_difficulty_factor()

static func get_scaled_weight(species: FishSpecies) -> float:
	return species.get_random_weight() * get_reward_factor()

static func get_adjusted_rarity_weights() -> Dictionary:
	var factor := get_difficulty_factor()
	# As difficulty increases, common decreases and rare/legendary increase
	var shift := (factor - 1.0) * 10.0  # 0 at day 1, up to 10 at max
	return {
		FishSpecies.Rarity.COMMON: maxf(50.0 - shift * 3.0, 20.0),
		FishSpecies.Rarity.UNCOMMON: 30.0,
		FishSpecies.Rarity.RARE: minf(15.0 + shift * 2.0, 30.0),
		FishSpecies.Rarity.LEGENDARY: minf(5.0 + shift, 15.0),
	}
