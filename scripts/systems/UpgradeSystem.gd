class_name UpgradeSystem
extends RefCounted

enum UpgradeType { BOAT_SPEED, OXYGEN_TANK, HARPOON_RANGE, HULL_DURABILITY, BATTERY_CAPACITY, SONAR_RANGE }

const MAX_LEVEL := 3

const UPGRADE_DATA := {
	UpgradeType.BOAT_SPEED: {
		"name": "Boat Engine",
		"description": "Faster sailing speed",
		"costs": [100, 250, 500],
		"level_names": ["Stock Engine", "Tuned Engine", "Racing Engine", "Turbo Engine"],
	},
	UpgradeType.OXYGEN_TANK: {
		"name": "Oxygen Tank",
		"description": "Longer dive time",
		"costs": [80, 200, 450],
		"level_names": ["Basic Tank", "Standard Tank", "Pro Tank", "Deep Diver Tank"],
	},
	UpgradeType.HARPOON_RANGE: {
		"name": "Harpoon",
		"description": "Longer harpoon range",
		"costs": [80, 200, 450],
		"level_names": ["Short Spear", "Harpoon", "Long Harpoon", "Master Harpoon"],
	},
	UpgradeType.HULL_DURABILITY: {
		"name": "Hull Plating",
		"description": "Stronger vehicle hull",
		"costs": [120, 300, 600],
		"level_names": ["Wooden Hull", "Iron Hull", "Steel Hull", "Titanium Hull"],
	},
	UpgradeType.BATTERY_CAPACITY: {
		"name": "Battery",
		"description": "Longer submerged time",
		"costs": [100, 250, 500],
		"level_names": ["Basic Cell", "Standard Cell", "High-Cap Cell", "Fusion Core"],
	},
	UpgradeType.SONAR_RANGE: {
		"name": "Sonar",
		"description": "Wider sonar detection",
		"costs": [80, 200, 450],
		"level_names": ["Ping Sensor", "Echo Array", "Deep Scanner", "Omni Sonar"],
	},
}

static func get_level(type: UpgradeType) -> int:
	match type:
		UpgradeType.BOAT_SPEED:
			return GameManager.boat_speed_level
		UpgradeType.OXYGEN_TANK:
			return GameManager.oxygen_tank_level
		UpgradeType.HARPOON_RANGE:
			return GameManager.harpoon_range_level
		UpgradeType.HULL_DURABILITY:
			return GameManager.hull_durability_level
		UpgradeType.BATTERY_CAPACITY:
			return GameManager.battery_capacity_level
		UpgradeType.SONAR_RANGE:
			return GameManager.sonar_range_level
	return 0

static func get_cost(type: UpgradeType) -> int:
	var level := get_level(type)
	if level >= MAX_LEVEL:
		return -1  # Already maxed
	return UPGRADE_DATA[type]["costs"][level]

static func get_name(type: UpgradeType) -> String:
	return UPGRADE_DATA[type]["name"]

static func get_level_name(type: UpgradeType) -> String:
	var level := get_level(type)
	return UPGRADE_DATA[type]["level_names"][level]

static func get_next_level_name(type: UpgradeType) -> String:
	var level := get_level(type)
	if level >= MAX_LEVEL:
		return "MAX"
	return UPGRADE_DATA[type]["level_names"][level + 1]

static func can_upgrade(type: UpgradeType) -> bool:
	var level := get_level(type)
	if level >= MAX_LEVEL:
		return false
	return Inventory.gold >= get_cost(type)

static func purchase_upgrade(type: UpgradeType) -> bool:
	if not can_upgrade(type):
		return false
	var cost := get_cost(type)
	if not Inventory.spend_gold(cost):
		return false

	match type:
		UpgradeType.BOAT_SPEED:
			GameManager.boat_speed_level += 1
		UpgradeType.OXYGEN_TANK:
			GameManager.oxygen_tank_level += 1
		UpgradeType.HARPOON_RANGE:
			GameManager.harpoon_range_level += 1
		UpgradeType.HULL_DURABILITY:
			GameManager.hull_durability_level += 1
		UpgradeType.BATTERY_CAPACITY:
			GameManager.battery_capacity_level += 1
		UpgradeType.SONAR_RANGE:
			GameManager.sonar_range_level += 1

	return true

static func is_maxed(type: UpgradeType) -> bool:
	return get_level(type) >= MAX_LEVEL
