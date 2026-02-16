extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var dialogue_box = $DialogueBox
@onready var hud = $HUD
@onready var interact_prompt: Label = $InteractPrompt

var nearby_npc: Node2D = null
var nearby_exit: bool = false

func _ready() -> void:
	hud.set_location("Umi-no-Machi Harbor")
	interact_prompt.visible = false

	# Set up dock exit area
	var dock_exit: Area2D = $DockExit
	var dock_shape: CollisionShape2D = dock_exit.get_node("CollisionShape2D")
	if dock_shape.shape == null:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(60, 40)
		dock_shape.shape = rect
	dock_exit.body_entered.connect(_on_dock_exit_entered)
	dock_exit.body_exited.connect(_on_dock_exit_exited)

	# Set up boundary walls
	_create_boundaries()

func _create_boundaries() -> void:
	var bounds = $Boundaries
	var walls := [
		[Vector2(0, -300), Vector2(1200, 20)],   # Top
		[Vector2(0, 400), Vector2(1200, 20)],     # Bottom
		[Vector2(-550, 0), Vector2(20, 800)],     # Left
		[Vector2(550, 0), Vector2(20, 800)],      # Right
	]
	for wall_data in walls:
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = wall_data[1]
		col.shape = rect
		col.position = wall_data[0]
		bounds.add_child(col)

func _process(_delta: float) -> void:
	if dialogue_box.is_active:
		return
	if nearby_npc and Input.is_action_just_pressed("interact"):
		_interact_with_npc(nearby_npc)
	elif nearby_exit and Input.is_action_just_pressed("interact"):
		GameManager.transition_to("res://scenes/ocean_surface/OceanSurface.tscn")

	# Prompt follows player in world space
	if interact_prompt.visible:
		interact_prompt.position = Vector2(
			player.position.x - 80,
			player.position.y + 30
		)

func _interact_with_npc(npc: Node2D) -> void:
	if npc.has_method("get_dialogue"):
		var lines: Array[String] = npc.get_dialogue()
		dialogue_box.show_dialogue(npc.npc_name, lines)
	if npc.has_method("on_interact"):
		await dialogue_box.dialogue_finished
		npc.on_interact()

func _on_npc_area_entered(npc: Node2D) -> void:
	nearby_npc = npc
	interact_prompt.visible = true
	interact_prompt.text = "[E] Talk to %s" % npc.npc_name

func _on_npc_area_exited(_npc: Node2D) -> void:
	nearby_npc = null
	if not nearby_exit:
		interact_prompt.visible = false

func _on_dock_exit_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		nearby_exit = true
		interact_prompt.visible = true
		interact_prompt.text = "[E] Set Sail"

func _on_dock_exit_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		nearby_exit = false
		if nearby_npc == null:
			interact_prompt.visible = false
