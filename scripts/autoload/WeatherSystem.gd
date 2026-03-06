extends Node

enum Weather { CLEAR, CLOUDY, RAIN, STORM, FOG }

var current_weather: Weather = Weather.CLEAR

signal weather_changed(new_weather: Weather)

# Weather affects gameplay:
# CLEAR    — normal conditions
# CLOUDY   — slight visibility reduction, uncommon fish +10%
# RAIN     — reduced visibility, fish more active (speed +20%)
# STORM    — heavy visibility loss, rare fish +25%, vehicle drift +30%
# FOG      — severe visibility loss, legendary fish +15%, sonar range halved

const WEATHER_WEIGHTS := {
	Weather.CLEAR: 35.0,
	Weather.CLOUDY: 25.0,
	Weather.RAIN: 20.0,
	Weather.STORM: 10.0,
	Weather.FOG: 10.0,
}

func _ready() -> void:
	TimeManager.time_changed.connect(_on_time_changed)

func _on_time_changed(_new_time) -> void:
	_roll_weather()

func _roll_weather() -> void:
	var total := 0.0
	for w in WEATHER_WEIGHTS.values():
		total += w
	var roll := randf() * total
	var cumulative := 0.0
	for weather_type in WEATHER_WEIGHTS:
		cumulative += WEATHER_WEIGHTS[weather_type]
		if roll <= cumulative:
			if weather_type != current_weather:
				current_weather = weather_type
				weather_changed.emit(current_weather)
			return

func get_weather_name() -> String:
	match current_weather:
		Weather.CLEAR: return "Clear"
		Weather.CLOUDY: return "Cloudy"
		Weather.RAIN: return "Rain"
		Weather.STORM: return "Storm"
		Weather.FOG: return "Fog"
	return "Clear"

func get_visibility_multiplier() -> float:
	match current_weather:
		Weather.CLEAR: return 1.0
		Weather.CLOUDY: return 0.85
		Weather.RAIN: return 0.65
		Weather.STORM: return 0.45
		Weather.FOG: return 0.35
	return 1.0

func get_fish_speed_multiplier() -> float:
	match current_weather:
		Weather.RAIN: return 1.2
		Weather.STORM: return 1.3
	return 1.0

func get_rarity_bonus() -> Dictionary:
	# Returns additive bonus weights per rarity
	match current_weather:
		Weather.CLOUDY:
			return {FishSpecies.Rarity.UNCOMMON: 10.0}
		Weather.STORM:
			return {FishSpecies.Rarity.RARE: 25.0}
		Weather.FOG:
			return {FishSpecies.Rarity.LEGENDARY: 15.0}
	return {}

func get_vehicle_drift_multiplier() -> float:
	match current_weather:
		Weather.STORM: return 1.3
		Weather.RAIN: return 1.1
	return 1.0

func get_sonar_multiplier() -> float:
	match current_weather:
		Weather.FOG: return 0.5
		Weather.STORM: return 0.7
	return 1.0

func get_overlay_color() -> Color:
	match current_weather:
		Weather.CLEAR: return Color(1, 1, 1, 0)
		Weather.CLOUDY: return Color(0.5, 0.5, 0.6, 0.15)
		Weather.RAIN: return Color(0.3, 0.35, 0.5, 0.25)
		Weather.STORM: return Color(0.2, 0.2, 0.35, 0.35)
		Weather.FOG: return Color(0.6, 0.6, 0.65, 0.4)
	return Color(1, 1, 1, 0)
