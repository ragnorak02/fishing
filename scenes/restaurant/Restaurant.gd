extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var interact_prompt: Label = $HUD/InteractPrompt
@onready var canvas_modulate: CanvasModulate = $CanvasModulate

var near_storage: bool = false
var near_menu: bool = false
var near_upgrade: bool = false
var near_door: bool = false
var near_dinner: bool = false

var ui_open: bool = false

func _ready() -> void:
	AudioManager.play_music("hub_town")
	interact_prompt.visible = false

	# Set up collision shapes for interaction zones
	_setup_area_shape($StoragePC, Vector2(60, 60))
	_setup_area_shape($MenuBoard, Vector2(60, 60))
	_setup_area_shape($UpgradeStation, Vector2(60, 60))
	_setup_area_shape($DoorExit, Vector2(60, 60))
	_setup_area_shape($DinnerPrompt, Vector2(60, 60))
	_create_boundaries()

	# Set up station visuals
	_setup_station_sprite($StoragePC, Color(0.3, 0.5, 0.7))
	_setup_station_sprite($MenuBoard, Color(0.6, 0.5, 0.3))
	_setup_station_sprite($UpgradeStation, Color(0.5, 0.6, 0.3))
	_setup_station_sprite($DoorExit, Color(0.7, 0.4, 0.3))
	_setup_station_sprite($DinnerPrompt, Color(0.8, 0.6, 0.2))

	# Update gold display
	_update_gold_display()
	Inventory.gold_changed.connect(func(_g): _update_gold_display())

	# Wire interaction zones
	$StoragePC.body_entered.connect(_on_storage_entered)
	$StoragePC.body_exited.connect(_on_storage_exited)
	$MenuBoard.body_entered.connect(_on_menu_entered)
	$MenuBoard.body_exited.connect(_on_menu_exited)
	$UpgradeStation.body_entered.connect(_on_upgrade_entered)
	$UpgradeStation.body_exited.connect(_on_upgrade_exited)
	$DoorExit.body_entered.connect(_on_door_entered)
	$DoorExit.body_exited.connect(_on_door_exited)
	$DinnerPrompt.body_entered.connect(_on_dinner_entered)
	$DinnerPrompt.body_exited.connect(_on_dinner_exited)

	# Time-of-day tint
	_apply_time_tint()
	TimeManager.time_changed.connect(func(_t): _apply_time_tint())

	# Update dinner prompt visibility
	_update_dinner_visibility()
	TimeManager.time_changed.connect(func(_t): _update_dinner_visibility())
	Inventory.menu_changed.connect(_update_dinner_visibility)

	# Day title card on morning
	if TimeManager.current_time == TimeManager.TimeOfDay.MORNING:
		_show_day_title()
		_check_recipe_unlocks()

func _process(_delta: float) -> void:
	if ui_open:
		return
	if Input.is_action_just_pressed("interact"):
		if near_storage:
			_open_storage()
		elif near_menu:
			_open_menu_board()
		elif near_upgrade:
			_open_upgrade()
		elif near_dinner:
			_start_dinner()
		elif near_door:
			TimeManager.advance_to(TimeManager.TimeOfDay.MIDDAY)
			GameManager.transition_to("res://scenes/ocean_surface/OceanSurface.tscn")

func _apply_time_tint() -> void:
	var target := TimeManager.get_ambient_color()
	var tween := create_tween()
	tween.tween_property(canvas_modulate, "color", target, 0.5)

func _update_dinner_visibility() -> void:
	var dinner_area: Area2D = $DinnerPrompt
	var is_afternoon := TimeManager.current_time == TimeManager.TimeOfDay.AFTERNOON
	var has_menu := not Inventory.active_menu.is_empty()
	dinner_area.visible = is_afternoon and has_menu
	# Also update the dinner label
	var dinner_label: Label = $DinnerPrompt/Label
	if dinner_label:
		dinner_label.visible = is_afternoon and has_menu

func _show_day_title() -> void:
	var title := Label.new()
	title.text = "Day %d" % TimeManager.current_day
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.anchors_preset = Control.PRESET_CENTER
	title.modulate.a = 0.0
	$HUD.add_child(title)

	var tween := create_tween()
	tween.tween_property(title, "modulate:a", 1.0, 0.5)
	tween.tween_interval(1.0)
	tween.tween_property(title, "modulate:a", 0.0, 0.5)
	tween.tween_callback(title.queue_free)

func _check_recipe_unlocks() -> void:
	# Unlock starter recipes on day 1
	var day_recipes := {
		1: ["sardine_onigiri", "grilled_mackerel"],
		2: ["squid_yakitori", "sea_bream_sashimi"],
		3: ["octopus_takoyaki", "yellowtail_nigiri"],
		5: ["grouper_hot_pot"],
		7: ["bluefin_toro_platter"],
	}
	for day in day_recipes:
		if TimeManager.current_day >= day:
			for recipe_id in day_recipes[day]:
				Inventory.unlock_recipe(recipe_id)

# --- Storage UI ---

func _open_storage() -> void:
	ui_open = true
	var ui = preload("res://scripts/ui/FishStorageUI.gd").new()
	ui.closed.connect(func(): ui_open = false)
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	canvas.add_child(ui)
	add_child(canvas)

# --- Menu Board UI ---

func _open_menu_board() -> void:
	ui_open = true
	var ui = preload("res://scripts/ui/MenuBoardUI.gd").new()
	ui.closed.connect(func(): ui_open = false)
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	canvas.add_child(ui)
	add_child(canvas)

# --- Upgrade UI ---

func _open_upgrade() -> void:
	ui_open = true
	var ui = preload("res://scripts/ui/UpgradeUI.gd").new()
	ui.closed.connect(func(): ui_open = false)
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	canvas.add_child(ui)
	add_child(canvas)

# --- Dinner Service ---

func _start_dinner() -> void:
	TimeManager.advance_to(TimeManager.TimeOfDay.EVENING)
	GameManager.transition_to("res://scenes/dinner_service/DinnerService.tscn")

# --- Interaction zone handlers ---

func _on_storage_entered(body: Node2D) -> void:
	if body == player:
		near_storage = true
		interact_prompt.visible = true
		interact_prompt.text = "[E] Fish Storage"

func _on_storage_exited(body: Node2D) -> void:
	if body == player:
		near_storage = false
		_hide_prompt_if_clear()

func _on_menu_entered(body: Node2D) -> void:
	if body == player:
		near_menu = true
		interact_prompt.visible = true
		interact_prompt.text = "[E] Menu Board"

func _on_menu_exited(body: Node2D) -> void:
	if body == player:
		near_menu = false
		_hide_prompt_if_clear()

func _on_upgrade_entered(body: Node2D) -> void:
	if body == player:
		near_upgrade = true
		interact_prompt.visible = true
		interact_prompt.text = "[E] Upgrades"

func _on_upgrade_exited(body: Node2D) -> void:
	if body == player:
		near_upgrade = false
		_hide_prompt_if_clear()

func _on_door_entered(body: Node2D) -> void:
	if body == player:
		near_door = true
		interact_prompt.visible = true
		interact_prompt.text = "[E] Set Sail"

func _on_door_exited(body: Node2D) -> void:
	if body == player:
		near_door = false
		_hide_prompt_if_clear()

func _on_dinner_entered(body: Node2D) -> void:
	if body == player:
		near_dinner = true
		interact_prompt.visible = true
		interact_prompt.text = "[E] Start Dinner Service"

func _on_dinner_exited(body: Node2D) -> void:
	if body == player:
		near_dinner = false
		_hide_prompt_if_clear()

func _hide_prompt_if_clear() -> void:
	if not near_storage and not near_menu and not near_upgrade and not near_door and not near_dinner:
		interact_prompt.visible = false

func _setup_area_shape(area: Area2D, size: Vector2) -> void:
	var col: CollisionShape2D = area.get_node("CollisionShape2D")
	if col.shape == null:
		var rect := RectangleShape2D.new()
		rect.size = size
		col.shape = rect

func _setup_station_sprite(area: Area2D, color: Color) -> void:
	var spr: Sprite2D = area.get_node_or_null("Sprite2D")
	if spr and spr.texture == null:
		# Create a simple colored rectangle as placeholder
		var img := Image.create(32, 40, false, Image.FORMAT_RGBA8)
		img.fill(color)
		spr.texture = ImageTexture.create_from_image(img)

func _create_boundaries() -> void:
	var bounds := $Boundaries
	# Clear existing shapes and recreate
	for child in bounds.get_children():
		if child is CollisionShape2D and child.shape == null:
			child.queue_free()
	var walls := [
		[Vector2(-550, 200), Vector2(20, 200)],  # Left
		[Vector2(550, 200), Vector2(20, 200)],    # Right
		[Vector2(0, 130), Vector2(1200, 20)],     # Top
		[Vector2(0, 280), Vector2(1200, 20)],     # Bottom
	]
	for wall_data in walls:
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = wall_data[1]
		col.shape = rect
		col.position = wall_data[0]
		bounds.add_child(col)

func _update_gold_display() -> void:
	$HUD/GoldLabel.text = "Gold: %dg" % Inventory.gold
