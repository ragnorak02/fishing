extends Node

enum GameState { MAIN_MENU, HUB_TOWN, OCEAN_SURFACE, DIVING, HAUL_SUMMARY }

var current_state: GameState = GameState.MAIN_MENU
var is_transitioning: bool = false

# Upgrade levels (0 = base, max 3)
var boat_speed_level: int = 0
var oxygen_tank_level: int = 0
var harpoon_range_level: int = 0
var hull_durability_level: int = 0
var battery_capacity_level: int = 0
var sonar_range_level: int = 0

# Vehicle mode (0=SURFACE, 1=SUBMERGED, 2=AIR)
var vehicle_mode: int = 0

# Current dive spot info
var current_dive_biome: String = "shallow"

signal state_changed(new_state: GameState)
signal vehicle_mode_changed(mode: int)

func transition_to(scene_path: String, new_state: GameState = GameState.MAIN_MENU) -> void:
	if is_transitioning:
		return
	is_transitioning = true

	# Auto-detect state from scene path
	if new_state == GameState.MAIN_MENU and scene_path != "res://scenes/main_menu/MainMenu.tscn":
		new_state = _detect_state(scene_path)

	SceneTransition.fade_to_scene(scene_path)
	await SceneTransition.transition_finished

	current_state = new_state
	state_changed.emit(current_state)
	is_transitioning = false

func _detect_state(path: String) -> GameState:
	if "hub_town" in path:
		return GameState.HUB_TOWN
	elif "ocean_surface" in path:
		return GameState.OCEAN_SURFACE
	elif "dive_scene" in path:
		return GameState.DIVING
	elif "haul_summary" in path:
		return GameState.HAUL_SUMMARY
	elif "main_menu" in path:
		return GameState.MAIN_MENU
	return GameState.MAIN_MENU

func get_boat_speed_multiplier() -> float:
	return 1.0 + boat_speed_level * 0.25

func get_oxygen_multiplier() -> float:
	return 1.0 + oxygen_tank_level * 0.3

func get_harpoon_range_multiplier() -> float:
	return 1.0 + harpoon_range_level * 0.25

func get_durability_multiplier() -> float:
	return 1.0 + hull_durability_level * 0.25

func get_battery_multiplier() -> float:
	return 1.0 + battery_capacity_level * 0.3

func get_sonar_multiplier() -> float:
	return 1.0 + sonar_range_level * 0.25

func set_vehicle_mode(mode: int) -> void:
	vehicle_mode = mode
	vehicle_mode_changed.emit(mode)
