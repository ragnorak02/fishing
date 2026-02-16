extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var name_label: Label = $Panel/VBox/NameLabel
@onready var text_label: Label = $Panel/VBox/TextLabel
@onready var continue_label: Label = $Panel/VBox/ContinueLabel

var dialogue_queue: Array[String] = []
var speaker_name: String = ""
var is_active: bool = false

signal dialogue_finished

func _ready() -> void:
	panel.visible = false

func _input(event: InputEvent) -> void:
	if not is_active:
		return
	if event.is_action_pressed("interact"):
		advance()
		get_viewport().set_input_as_handled()

func show_dialogue(npc_name: String, lines: Array[String]) -> void:
	if lines.is_empty():
		return
	speaker_name = npc_name
	dialogue_queue = lines.duplicate()
	is_active = true
	panel.visible = true
	name_label.text = speaker_name
	_show_next_line()

func _show_next_line() -> void:
	if dialogue_queue.is_empty():
		close()
		return
	text_label.text = dialogue_queue.pop_front()
	if dialogue_queue.is_empty():
		continue_label.text = "[E] Close"
	else:
		continue_label.text = "[E] Continue"

func advance() -> void:
	if dialogue_queue.is_empty():
		close()
	else:
		_show_next_line()

func close() -> void:
	panel.visible = false
	is_active = false
	dialogue_finished.emit()
