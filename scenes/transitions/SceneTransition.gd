extends CanvasLayer

signal transition_finished

@onready var fade_rect: ColorRect = $FadeRect
@onready var anim: AnimationPlayer = $AnimationPlayer

const FADE_DURATION := 0.3

func _ready() -> void:
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func fade_to_scene(scene_path: String) -> void:
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	# Fade to black
	var tween := create_tween()
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 1), FADE_DURATION)
	await tween.finished

	# Change scene
	get_tree().change_scene_to_file(scene_path)

	# Wait one frame for scene to load
	await get_tree().process_frame

	# Fade from black
	var tween2 := create_tween()
	tween2.tween_property(fade_rect, "color", Color(0, 0, 0, 0), FADE_DURATION)
	await tween2.finished

	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_finished.emit()
