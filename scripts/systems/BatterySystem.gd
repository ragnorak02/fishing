class_name BatterySystem
extends Node
## Countdown timer for submerged mode. Mirrors OxygenSystem pattern.

const BASE_MAX_BATTERY := 90.0  # seconds
const DRAIN_RATE := 1.0  # units per second
const SONAR_COST := 5.0  # battery cost per sonar pulse

var max_battery: float = BASE_MAX_BATTERY
var current_battery: float = BASE_MAX_BATTERY
var is_depleted: bool = false
var is_active: bool = false  # Only drains when active (submerged mode)

signal battery_changed(current: float, maximum: float)
signal battery_depleted

func _ready() -> void:
	max_battery = BASE_MAX_BATTERY * GameManager.get_battery_multiplier()
	current_battery = max_battery

func activate() -> void:
	is_active = true
	is_depleted = false

func deactivate() -> void:
	is_active = false

func _process(delta: float) -> void:
	if not is_active or is_depleted:
		return

	current_battery -= DRAIN_RATE * delta
	current_battery = maxf(current_battery, 0.0)
	battery_changed.emit(current_battery, max_battery)

	if current_battery <= 0.0:
		is_depleted = true
		battery_depleted.emit()

func consume(amount: float) -> bool:
	if current_battery < amount:
		return false
	current_battery -= amount
	current_battery = maxf(current_battery, 0.0)
	battery_changed.emit(current_battery, max_battery)

	if current_battery <= 0.0:
		is_depleted = true
		battery_depleted.emit()
	return true

func get_percentage() -> float:
	return current_battery / max_battery

func recharge_full() -> void:
	max_battery = BASE_MAX_BATTERY * GameManager.get_battery_multiplier()
	current_battery = max_battery
	is_depleted = false
	battery_changed.emit(current_battery, max_battery)

func reset() -> void:
	recharge_full()
