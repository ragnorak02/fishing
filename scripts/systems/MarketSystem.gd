class_name MarketSystem
extends RefCounted

# Deterministic daily price multipliers per species, seeded from day number.
# Range: 0.5x to 2.0x

const MIN_MULTIPLIER := 0.5
const MAX_MULTIPLIER := 2.0

static func get_price_multiplier(species_id: String) -> float:
	var day := _get_current_day()
	# Deterministic hash from day + species_id
	var seed_val := hash(str(day) + species_id)
	# Map hash to 0.0–1.0 range using modulo
	var normalized := absf(float(seed_val % 10000)) / 10000.0
	return MIN_MULTIPLIER + normalized * (MAX_MULTIPLIER - MIN_MULTIPLIER)

static func get_sell_price(fish: Dictionary) -> int:
	var base_value: int = fish.get("value", 1)
	var species_id: String = fish.get("species_id", "")
	var multiplier := get_price_multiplier(species_id)
	return maxi(int(base_value * multiplier), 1)

static func get_market_trend(species_id: String) -> String:
	var mult := get_price_multiplier(species_id)
	if mult >= 1.7:
		return "HIGH"
	elif mult >= 1.3:
		return "UP"
	elif mult >= 0.8:
		return "NORMAL"
	elif mult >= 0.6:
		return "DOWN"
	else:
		return "LOW"

static func get_trend_color(species_id: String) -> Color:
	var trend := get_market_trend(species_id)
	match trend:
		"HIGH":
			return Color(0.2, 0.9, 0.3)    # Green
		"UP":
			return Color(0.8, 0.9, 0.2)    # Yellow-green
		"NORMAL":
			return Color(0.6, 0.6, 0.6)    # Grey
		"DOWN":
			return Color(0.9, 0.6, 0.2)    # Orange
		"LOW":
			return Color(0.9, 0.3, 0.3)    # Red
	return Color.WHITE

static func _get_current_day() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		var tm = tree.root.get_node_or_null("/root/TimeManager")
		if tm and "current_day" in tm:
			return tm.current_day
	return 1
