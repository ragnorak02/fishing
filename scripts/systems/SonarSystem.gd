class_name SonarSystem
extends Node
## Pulse cooldown sonar — detect nearby fish/resources in range.

const BASE_RANGE := 300.0
const COOLDOWN := 5.0  # seconds between pulses
const PULSE_DURATION := 2.0  # how long detected targets are highlighted

var sonar_range: float = BASE_RANGE
var cooldown_timer: float = 0.0
var pulse_timer: float = 0.0
var is_active: bool = false

signal sonar_pulsed(origin: Vector2, pulse_range: float)
signal sonar_ended

func activate() -> void:
	is_active = true
	cooldown_timer = 0.0
	pulse_timer = 0.0
	sonar_range = BASE_RANGE * GameManager.get_sonar_multiplier()

func deactivate() -> void:
	is_active = false
	cooldown_timer = 0.0
	pulse_timer = 0.0

func _process(delta: float) -> void:
	if not is_active:
		return

	if cooldown_timer > 0:
		cooldown_timer -= delta

	if pulse_timer > 0:
		pulse_timer -= delta
		if pulse_timer <= 0:
			sonar_ended.emit()

	if Input.is_action_just_pressed("sonar_pulse") and cooldown_timer <= 0:
		_fire_pulse()

func _fire_pulse() -> void:
	# Consume battery
	var battery: BatterySystem = get_parent().get_node_or_null("BatterySystem")
	if battery and not battery.consume(BatterySystem.SONAR_COST):
		return  # Not enough battery

	cooldown_timer = COOLDOWN
	pulse_timer = PULSE_DURATION
	sonar_range = BASE_RANGE * GameManager.get_sonar_multiplier()
	sonar_pulsed.emit(get_parent().global_position, sonar_range)

func can_pulse() -> bool:
	return is_active and cooldown_timer <= 0

func get_cooldown_percentage() -> float:
	if cooldown_timer <= 0:
		return 1.0
	return 1.0 - (cooldown_timer / COOLDOWN)
