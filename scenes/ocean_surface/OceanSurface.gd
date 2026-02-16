extends Node2D

@onready var boat: CharacterBody2D = $Boat
@onready var hud = $HUD
@onready var interact_prompt: Label = $HUD/InteractPrompt

var near_dive_spot: Area2D = null
var near_hub_return: bool = false

const MAP_BOUNDS := Rect2(-1500, -1500, 3000, 3000)

func _ready() -> void:
	hud.set_location("Open Sea")
	interact_prompt.visible = false

	# Set up island collision shapes
	_setup_island($Island1, Vector2(55, 40))
	_setup_island($Island2, Vector2(45, 35))
	_setup_island($Island3, Vector2(40, 30))

	# Set up hub return zone
	var hub_col: CollisionShape2D = $HubReturnZone/CollisionShape2D
	if hub_col.shape == null:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(60, 40)
		hub_col.shape = rect

	# Connect dive spot signals
	for spot in get_tree().get_nodes_in_group("dive_spots"):
		spot.body_entered.connect(_on_dive_spot_entered.bind(spot))
		spot.body_exited.connect(_on_dive_spot_exited.bind(spot))

	$HubReturnZone.body_entered.connect(_on_hub_return_entered)
	$HubReturnZone.body_exited.connect(_on_hub_return_exited)

	# Update boost bar
	$HUD/BoostBar.visible = true

func _setup_island(island: StaticBody2D, half_size: Vector2) -> void:
	var col: CollisionShape2D = island.get_node("CollisionShape2D")
	if col.shape == null:
		var rect := RectangleShape2D.new()
		rect.size = half_size * 2.0
		col.shape = rect

func _process(_delta: float) -> void:
	# Interaction
	if Input.is_action_just_pressed("interact"):
		if near_dive_spot:
			_start_dive(near_dive_spot)
		elif near_hub_return:
			GameManager.transition_to("res://scenes/hub_town/HubTown.tscn")

	# Boundary enforcement
	if not MAP_BOUNDS.has_point(boat.global_position):
		boat.global_position = boat.global_position.clamp(
			MAP_BOUNDS.position,
			MAP_BOUNDS.position + MAP_BOUNDS.size
		)
		boat.velocity *= -0.5

	# Update boost bar UI
	var boost_bar: ProgressBar = $HUD/BoostBar
	if boat.is_boosting:
		boost_bar.value = (boat.boost_timer / boat.BOOST_DURATION) * 100.0
		boost_bar.modulate = Color(0.3, 0.8, 1.0)
	elif boat.boost_cooldown_timer > 0:
		boost_bar.value = (1.0 - boat.boost_cooldown_timer / boat.BOOST_COOLDOWN) * 100.0
		boost_bar.modulate = Color(0.5, 0.5, 0.5)
	else:
		boost_bar.value = 100.0
		boost_bar.modulate = Color(0.3, 1.0, 0.5)

func _start_dive(spot: Area2D) -> void:
	if spot.has_meta("biome"):
		GameManager.current_dive_biome = spot.get_meta("biome")
	else:
		GameManager.current_dive_biome = "shallow"
	Inventory.clear_haul()
	GameManager.transition_to("res://scenes/dive_scene/DiveScene.tscn")

func _on_dive_spot_entered(body: Node2D, spot: Area2D) -> void:
	if body == boat:
		near_dive_spot = spot
		interact_prompt.visible = true
		var biome_name: String = spot.get_meta("biome", "shallow")
		interact_prompt.text = "[E] Dive Here (%s)" % biome_name.capitalize()

func _on_dive_spot_exited(body: Node2D, spot: Area2D) -> void:
	if body == boat and near_dive_spot == spot:
		near_dive_spot = null
		if not near_hub_return:
			interact_prompt.visible = false

func _on_hub_return_entered(body: Node2D) -> void:
	if body == boat:
		near_hub_return = true
		interact_prompt.visible = true
		interact_prompt.text = "[E] Return to Harbor"

func _on_hub_return_exited(body: Node2D) -> void:
	if body == boat:
		near_hub_return = false
		if near_dive_spot == null:
			interact_prompt.visible = false
