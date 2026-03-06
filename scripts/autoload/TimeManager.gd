extends Node

enum TimeOfDay { MORNING, MIDDAY, AFTERNOON, EVENING, NIGHT }

var current_day: int = 1
var current_time: TimeOfDay = TimeOfDay.MORNING

signal time_changed(new_time: TimeOfDay)
signal day_changed(new_day: int)

func advance_to(time: TimeOfDay) -> void:
	if time == current_time:
		return
	current_time = time
	time_changed.emit(current_time)

func advance_time() -> void:
	# Advances one time step; wraps day at NIGHT
	match current_time:
		TimeOfDay.MORNING:
			current_time = TimeOfDay.MIDDAY
		TimeOfDay.MIDDAY:
			current_time = TimeOfDay.AFTERNOON
		TimeOfDay.AFTERNOON:
			current_time = TimeOfDay.EVENING
		TimeOfDay.EVENING:
			current_time = TimeOfDay.NIGHT
		TimeOfDay.NIGHT:
			advance_day()
			return
	time_changed.emit(current_time)

func advance_day() -> void:
	current_day += 1
	current_time = TimeOfDay.MORNING
	day_changed.emit(current_day)
	time_changed.emit(current_time)

func get_ambient_color() -> Color:
	match current_time:
		TimeOfDay.MORNING:
			return Color(1.0, 0.95, 0.85)
		TimeOfDay.MIDDAY:
			return Color(1.0, 1.0, 1.0)
		TimeOfDay.AFTERNOON:
			return Color(1.0, 0.9, 0.75)
		TimeOfDay.EVENING:
			return Color(0.7, 0.6, 0.85)
		TimeOfDay.NIGHT:
			return Color(0.3, 0.3, 0.5)
	return Color(1.0, 1.0, 1.0)

func get_time_name() -> String:
	match current_time:
		TimeOfDay.MORNING: return "Morning"
		TimeOfDay.MIDDAY: return "Midday"
		TimeOfDay.AFTERNOON: return "Afternoon"
		TimeOfDay.EVENING: return "Evening"
		TimeOfDay.NIGHT: return "Night"
	return "Unknown"

func get_underwater_tint() -> Color:
	# Underwater gets darker at night
	match current_time:
		TimeOfDay.MORNING:
			return Color(0.6, 0.75, 0.9)
		TimeOfDay.MIDDAY:
			return Color(0.5, 0.7, 0.95)
		TimeOfDay.AFTERNOON:
			return Color(0.55, 0.65, 0.85)
		TimeOfDay.EVENING:
			return Color(0.35, 0.35, 0.6)
		TimeOfDay.NIGHT:
			return Color(0.15, 0.15, 0.35)
	return Color(0.5, 0.7, 0.95)
