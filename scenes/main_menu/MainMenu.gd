extends Control

@onready var wave_overlay: ColorRect = $WaveOverlay

func _ready() -> void:
	$VBox/StartButton.pressed.connect(_on_start_pressed)
	$VBox/QuitButton.pressed.connect(_on_quit_pressed)
	$VBox/StartButton.grab_focus()

	# Animate wave overlay
	_start_wave_animation()

func _start_wave_animation() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(wave_overlay, "color:a", 0.15, 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(wave_overlay, "color:a", 0.35, 2.0).set_trans(Tween.TRANS_SINE)

func _on_start_pressed() -> void:
	GameManager.transition_to("res://scenes/hub_town/HubTown.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
