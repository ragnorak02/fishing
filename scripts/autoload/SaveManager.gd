extends Node

const SAVE_PATH := "user://save_data.json"
const CURRENT_SAVE_VERSION := 4

signal species_discovered(species_id: String)

var total_catches: int = 0
var total_gold_earned: int = 0
var species_caught: Array = []

func _ready() -> void:
	# Defer load so all autoloads are initialized first
	call_deferred("load_game")

# --- Public API ---

func save_game() -> void:
	var data := _build_save_data()
	var json := JSON.new()
	var json_string := json.stringify(data, "  ")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		GameLog.achievements("Game saved")

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_apply_defaults()
		return
	# Guard: only apply to autoloads if they have proper scripts
	if not is_instance_valid(get_tree()):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_apply_defaults()
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		GameLog.warn("SaveManager", "Corrupt save file — starting fresh")
		_apply_defaults()
		return
	var data = json.data
	if not _validate_schema(data):
		GameLog.warn("SaveManager", "Invalid save schema — starting fresh")
		_apply_defaults()
		return
	# Migrate if needed
	var version: int = data.get("save_version", 0)
	if version < CURRENT_SAVE_VERSION:
		data = _migrate(data, version)
	_apply_save_data(data)

func get_saved_achievement_state() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var data = json.data
	if data is Dictionary and data.has("achievements"):
		return data["achievements"]
	return {}

func record_catch(species_id: String) -> void:
	total_catches += 1
	if species_id not in species_caught:
		species_caught.append(species_id)
		species_discovered.emit(species_id)

func is_species_discovered(species_id: String) -> bool:
	return species_id in species_caught

func get_discovery_count() -> int:
	return species_caught.size()

func record_gold_earned(amount: int) -> void:
	total_gold_earned += amount

# --- Internal ---

func _build_save_data() -> Dictionary:
	var upgrade_levels := {
		"boat_speed": GameManager.boat_speed_level,
		"oxygen_tank": GameManager.oxygen_tank_level,
		"harpoon_range": GameManager.harpoon_range_level,
		"hull_durability": GameManager.hull_durability_level,
		"battery_capacity": GameManager.battery_capacity_level,
		"sonar_range": GameManager.sonar_range_level,
	}
	var achievement_state := {}
	var am = get_node_or_null("/root/AchievementManager")
	if am and am.has_method("get_save_state"):
		achievement_state = am.get_save_state()
	var tm = get_node_or_null("/root/TimeManager")
	return {
		"save_version": CURRENT_SAVE_VERSION,
		"gold": Inventory.gold,
		"upgrade_levels": upgrade_levels,
		"fish_storage": Inventory.fish_storage.duplicate(true),
		"species_caught": species_caught.duplicate(),
		"achievements": achievement_state,
		"stats": {
			"total_catches": total_catches,
			"total_gold_earned": total_gold_earned,
		},
		"active_menu": Inventory.active_menu.duplicate(),
		"unlocked_recipes": Inventory.unlocked_recipes.duplicate(),
		"current_day": tm.current_day if tm else 1,
		"current_time": tm.current_time if tm else 0,
		"submerge_unlocked": GameManager.submerge_unlocked,
		"air_mode_unlocked": GameManager.air_mode_unlocked,
	}

func _apply_save_data(data: Dictionary) -> void:
	if not get_node_or_null("/root/Inventory"):
		return
	Inventory.gold = data.get("gold", 50)
	if Inventory.has_signal("gold_changed"):
		Inventory.gold_changed.emit(Inventory.gold)
	Inventory.fish_storage = data.get("fish_storage", [])

	var upgrades: Dictionary = data.get("upgrade_levels", {})
	GameManager.boat_speed_level = upgrades.get("boat_speed", 0)
	GameManager.oxygen_tank_level = upgrades.get("oxygen_tank", 0)
	GameManager.harpoon_range_level = upgrades.get("harpoon_range", 0)
	GameManager.hull_durability_level = upgrades.get("hull_durability", 0)
	GameManager.battery_capacity_level = upgrades.get("battery_capacity", 0)
	GameManager.sonar_range_level = upgrades.get("sonar_range", 0)

	species_caught = data.get("species_caught", [])
	var stats: Dictionary = data.get("stats", {})
	total_catches = stats.get("total_catches", 0)
	total_gold_earned = stats.get("total_gold_earned", 0)

	# v2 fields: recipes and time
	var menu_data = data.get("active_menu", [])
	Inventory.active_menu.clear()
	for item in menu_data:
		Inventory.active_menu.append(str(item))
	var recipe_data = data.get("unlocked_recipes", [])
	Inventory.unlocked_recipes.clear()
	for item in recipe_data:
		Inventory.unlocked_recipes.append(str(item))

	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		tm.current_day = data.get("current_day", 1)
		tm.current_time = data.get("current_time", 0) as TimeManager.TimeOfDay

	GameManager.submerge_unlocked = data.get("submerge_unlocked", true)
	GameManager.air_mode_unlocked = data.get("air_mode_unlocked", true)

func _apply_defaults() -> void:
	total_catches = 0
	total_gold_earned = 0
	species_caught = []

func _validate_schema(data) -> bool:
	if not data is Dictionary:
		return false
	if not data.has("save_version"):
		return false
	return true

func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	if from_version < 1:
		# v0 -> v1: ensure stats key exists
		if not data.has("stats"):
			data["stats"] = {"total_catches": 0, "total_gold_earned": 0}
		if not data.has("achievements"):
			data["achievements"] = {}
		if not data.has("species_caught"):
			data["species_caught"] = []
		data["save_version"] = 1
	if from_version < 2:
		# v1 -> v2: add recipe/menu/time fields
		if not data.has("active_menu"):
			data["active_menu"] = []
		if not data.has("unlocked_recipes"):
			data["unlocked_recipes"] = []
		if not data.has("current_day"):
			data["current_day"] = 1
		if not data.has("current_time"):
			data["current_time"] = 0
		data["save_version"] = 2
	if from_version < 3:
		# v2 -> v3: add vehicle mode unlock flags
		if not data.has("submerge_unlocked"):
			data["submerge_unlocked"] = true
		if not data.has("air_mode_unlocked"):
			data["air_mode_unlocked"] = true
		data["save_version"] = 3
	if from_version < 4:
		# v3 -> v4: fix saves migrated to v3 with modes locked
		data["submerge_unlocked"] = true
		data["air_mode_unlocked"] = true
		data["save_version"] = 4
	return data
