extends Control

const SERVICE_DURATION := 60.0
const ORDER_INTERVAL_MIN := 3.0
const ORDER_INTERVAL_MAX := 6.0
const CURSOR_BASE_SPEED := 2.0
const SWEET_SPOT_SIZE := 0.15  # Fraction of bar width

enum ServiceState { WAITING, COOKING, RESULTS }

var service_state: ServiceState = ServiceState.WAITING
var time_remaining: float = SERVICE_DURATION
var total_revenue: int = 0
var dishes_served: int = 0
var dishes_failed: int = 0

# Order queue
var pending_orders: Array[String] = []  # recipe IDs
var selected_order_index: int = 0
var order_timer: float = 0.0

# Cooking mini-game
var cursor_position: float = 0.0  # 0.0 to 1.0
var cursor_direction: float = 1.0
var cursor_speed: float = CURSOR_BASE_SPEED
var sweet_spot_center: float = 0.5
var cooking_recipe_id: String = ""

# UI references
var timer_bar: ProgressBar
var revenue_label: Label
var order_container: VBoxContainer
var cooking_panel: Control
var cursor_bar: ColorRect
var sweet_spot_rect: ColorRect
var cooking_bg: ColorRect
var cooking_label: Label
var result_panel: Control

func _ready() -> void:
	_build_ui()
	_start_service()

func _process(delta: float) -> void:
	match service_state:
		ServiceState.WAITING:
			_process_waiting(delta)
		ServiceState.COOKING:
			_process_cooking(delta)

func _process_waiting(delta: float) -> void:
	time_remaining -= delta
	timer_bar.value = time_remaining / SERVICE_DURATION * 100.0

	if time_remaining <= 0:
		_end_service()
		return

	# Spawn orders periodically
	order_timer -= delta
	if order_timer <= 0 and pending_orders.size() < 5:
		_spawn_order()
		order_timer = randf_range(ORDER_INTERVAL_MIN, ORDER_INTERVAL_MAX)

	# Navigate orders
	if Input.is_action_just_pressed("move_up") and selected_order_index > 0:
		selected_order_index -= 1
		_highlight_selected_order()
	elif Input.is_action_just_pressed("move_down") and selected_order_index < pending_orders.size() - 1:
		selected_order_index += 1
		_highlight_selected_order()

	# Start cooking
	if Input.is_action_just_pressed("interact") and not pending_orders.is_empty():
		var recipe_id := pending_orders[selected_order_index]
		# Check ingredients
		var recipe := RecipeDatabase.get_recipe(recipe_id)
		if recipe:
			var can_cook := true
			for ingredient in recipe.ingredients:
				if Inventory.get_fish_count_by_species(ingredient.species_id) < ingredient.quantity:
					can_cook = false
					break
			if can_cook:
				_begin_cooking(recipe_id)

func _process_cooking(delta: float) -> void:
	time_remaining -= delta
	timer_bar.value = time_remaining / SERVICE_DURATION * 100.0

	if time_remaining <= 0:
		_end_service()
		return

	# Move cursor back and forth
	cursor_position += cursor_direction * cursor_speed * delta
	if cursor_position >= 1.0:
		cursor_position = 1.0
		cursor_direction = -1.0
	elif cursor_position <= 0.0:
		cursor_position = 0.0
		cursor_direction = 1.0

	# Update cursor visual
	if cooking_bg and cursor_bar:
		cursor_bar.position.x = cursor_position * (cooking_bg.size.x - cursor_bar.size.x)

	# Player presses A to attempt cook
	if Input.is_action_just_pressed("interact"):
		_resolve_cook()

func _begin_cooking(recipe_id: String) -> void:
	cooking_recipe_id = recipe_id
	service_state = ServiceState.COOKING

	var recipe := RecipeDatabase.get_recipe(recipe_id)
	# Speed scales with recipe difficulty and day
	var day_factor := 1.0 + (TimeManager.current_day - 1) * 0.05
	cursor_speed = CURSOR_BASE_SPEED * recipe.cook_time * day_factor

	# Randomize sweet spot
	sweet_spot_center = randf_range(0.25, 0.75)

	cursor_position = 0.0
	cursor_direction = 1.0

	# Show cooking panel
	cooking_panel.visible = true
	cooking_label.text = "Cooking: %s" % recipe.display_name

	# Position sweet spot
	var bar_width := cooking_bg.size.x
	var spot_width := bar_width * SWEET_SPOT_SIZE
	sweet_spot_rect.size.x = spot_width
	sweet_spot_rect.position.x = sweet_spot_center * bar_width - spot_width / 2.0

func _resolve_cook() -> void:
	var distance := absf(cursor_position - sweet_spot_center)
	var recipe := RecipeDatabase.get_recipe(cooking_recipe_id)
	if recipe == null:
		service_state = ServiceState.WAITING
		cooking_panel.visible = false
		return

	var half_sweet := SWEET_SPOT_SIZE / 2.0
	var earned := 0

	if distance <= half_sweet:
		# Perfect
		earned = recipe.sell_price
		Inventory.consume_ingredients_for_recipe(cooking_recipe_id)
		dishes_served += 1
	elif distance <= half_sweet * 2.0:
		# Good
		earned = int(recipe.sell_price * 0.75)
		Inventory.consume_ingredients_for_recipe(cooking_recipe_id)
		dishes_served += 1
	else:
		# Miss — ingredients wasted
		Inventory.consume_ingredients_for_recipe(cooking_recipe_id)
		dishes_failed += 1

	total_revenue += earned
	Inventory.gold += earned
	Inventory.gold_changed.emit(Inventory.gold)
	revenue_label.text = "Revenue: %dg" % total_revenue

	# Remove order
	if selected_order_index < pending_orders.size():
		pending_orders.remove_at(selected_order_index)
		if selected_order_index >= pending_orders.size() and selected_order_index > 0:
			selected_order_index -= 1

	_refresh_orders()
	cooking_panel.visible = false
	service_state = ServiceState.WAITING

func _spawn_order() -> void:
	if Inventory.active_menu.is_empty():
		return
	# Pick random recipe from active menu
	var idx := randi() % Inventory.active_menu.size()
	pending_orders.append(Inventory.active_menu[idx])
	_refresh_orders()

func _refresh_orders() -> void:
	for child in order_container.get_children():
		child.queue_free()

	if pending_orders.is_empty():
		var empty := Label.new()
		empty.text = "Waiting for customers..."
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		order_container.add_child(empty)
		return

	for i in pending_orders.size():
		var recipe_id := pending_orders[i]
		var recipe := RecipeDatabase.get_recipe(recipe_id)
		if recipe == null:
			continue

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		# Selection indicator
		var indicator := Label.new()
		indicator.text = ">" if i == selected_order_index else " "
		indicator.add_theme_font_size_override("font_size", 14)
		indicator.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
		indicator.custom_minimum_size = Vector2(15, 0)
		row.add_child(indicator)

		var name_lbl := Label.new()
		name_lbl.text = recipe.display_name

		# Check if cookable (have ingredients)
		var can_cook := true
		for ingredient in recipe.ingredients:
			if Inventory.get_fish_count_by_species(ingredient.species_id) < ingredient.quantity:
				can_cook = false
				break

		name_lbl.add_theme_font_size_override("font_size", 14)
		if can_cook:
			name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		else:
			name_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		row.add_child(name_lbl)

		var price_lbl := Label.new()
		price_lbl.text = "%dg" % recipe.sell_price
		price_lbl.add_theme_font_size_override("font_size", 13)
		price_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
		price_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(price_lbl)

		order_container.add_child(row)

func _highlight_selected_order() -> void:
	_refresh_orders()

func _start_service() -> void:
	order_timer = 1.0  # First order after 1s
	_refresh_orders()

func _end_service() -> void:
	service_state = ServiceState.RESULTS
	cooking_panel.visible = false

	# Show results
	result_panel.visible = true
	var results_vbox: VBoxContainer = result_panel.get_node("VBox")
	for child in results_vbox.get_children():
		child.queue_free()

	var title := Label.new()
	title.text = "Service Complete!"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_vbox.add_child(title)

	var rev := Label.new()
	rev.text = "Revenue: %dg" % total_revenue
	rev.add_theme_font_size_override("font_size", 18)
	rev.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	rev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_vbox.add_child(rev)

	var served := Label.new()
	served.text = "Dishes Served: %d" % dishes_served
	served.add_theme_font_size_override("font_size", 14)
	served.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_vbox.add_child(served)

	if dishes_failed > 0:
		var failed := Label.new()
		failed.text = "Dishes Failed: %d" % dishes_failed
		failed.add_theme_font_size_override("font_size", 14)
		failed.add_theme_color_override("font_color", Color(1, 0.4, 0.3))
		failed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		results_vbox.add_child(failed)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	results_vbox.add_child(spacer)

	var continue_btn := Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(120, 40)
	continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_btn.pressed.connect(_on_continue)
	results_vbox.add_child(continue_btn)
	continue_btn.grab_focus()

func _on_continue() -> void:
	SaveManager.save_game()
	TimeManager.advance_day()
	GameManager.transition_to("res://scenes/restaurant/Restaurant.tscn")

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.12, 0.1, 0.08, 1)
	add_child(bg)

	# Timer bar at top
	timer_bar = ProgressBar.new()
	timer_bar.anchors_preset = Control.PRESET_TOP_WIDE
	timer_bar.anchor_right = 1.0
	timer_bar.offset_left = 20.0
	timer_bar.offset_top = 15.0
	timer_bar.offset_right = -20.0
	timer_bar.offset_bottom = 40.0
	timer_bar.value = 100.0
	timer_bar.show_percentage = false
	add_child(timer_bar)

	# Timer label
	var timer_lbl := Label.new()
	timer_lbl.text = "Dinner Service"
	timer_lbl.anchors_preset = Control.PRESET_TOP_WIDE
	timer_lbl.offset_top = 42.0
	timer_lbl.offset_bottom = 60.0
	timer_lbl.add_theme_font_size_override("font_size", 13)
	timer_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(timer_lbl)

	# Revenue label
	revenue_label = Label.new()
	revenue_label.text = "Revenue: 0g"
	revenue_label.anchors_preset = Control.PRESET_TOP_RIGHT
	revenue_label.anchor_left = 1.0
	revenue_label.anchor_right = 1.0
	revenue_label.offset_left = -180.0
	revenue_label.offset_top = 42.0
	revenue_label.offset_right = -20.0
	revenue_label.offset_bottom = 60.0
	revenue_label.add_theme_font_size_override("font_size", 16)
	revenue_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	revenue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(revenue_label)

	# Orders panel (left side)
	var orders_panel := PanelContainer.new()
	orders_panel.anchor_left = 0.02
	orders_panel.anchor_top = 0.12
	orders_panel.anchor_right = 0.45
	orders_panel.anchor_bottom = 0.75
	add_child(orders_panel)

	var orders_margin := MarginContainer.new()
	orders_margin.anchors_preset = Control.PRESET_FULL_RECT
	orders_margin.anchor_right = 1.0
	orders_margin.anchor_bottom = 1.0
	orders_margin.add_theme_constant_override("margin_left", 10)
	orders_margin.add_theme_constant_override("margin_top", 10)
	orders_margin.add_theme_constant_override("margin_right", 10)
	orders_margin.add_theme_constant_override("margin_bottom", 10)
	orders_panel.add_child(orders_margin)

	var orders_vbox := VBoxContainer.new()
	orders_vbox.add_theme_constant_override("separation", 6)
	orders_margin.add_child(orders_vbox)

	var orders_title := Label.new()
	orders_title.text = "Orders"
	orders_title.add_theme_font_size_override("font_size", 18)
	orders_title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	orders_vbox.add_child(orders_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	orders_vbox.add_child(scroll)

	order_container = VBoxContainer.new()
	order_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	order_container.add_theme_constant_override("separation", 4)
	scroll.add_child(order_container)

	# Cooking mini-game panel (right side)
	cooking_panel = Control.new()
	cooking_panel.anchor_left = 0.5
	cooking_panel.anchor_top = 0.12
	cooking_panel.anchor_right = 0.98
	cooking_panel.anchor_bottom = 0.75
	cooking_panel.visible = false
	add_child(cooking_panel)

	var cook_bg_panel := PanelContainer.new()
	cook_bg_panel.anchors_preset = Control.PRESET_FULL_RECT
	cook_bg_panel.anchor_right = 1.0
	cook_bg_panel.anchor_bottom = 1.0
	cooking_panel.add_child(cook_bg_panel)

	var cook_margin := MarginContainer.new()
	cook_margin.anchors_preset = Control.PRESET_FULL_RECT
	cook_margin.anchor_right = 1.0
	cook_margin.anchor_bottom = 1.0
	cook_margin.add_theme_constant_override("margin_left", 15)
	cook_margin.add_theme_constant_override("margin_top", 15)
	cook_margin.add_theme_constant_override("margin_right", 15)
	cook_margin.add_theme_constant_override("margin_bottom", 15)
	cook_bg_panel.add_child(cook_margin)

	var cook_vbox := VBoxContainer.new()
	cook_vbox.add_theme_constant_override("separation", 20)
	cook_margin.add_child(cook_vbox)

	cooking_label = Label.new()
	cooking_label.text = "Cooking: ..."
	cooking_label.add_theme_font_size_override("font_size", 18)
	cooking_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	cooking_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cook_vbox.add_child(cooking_label)

	var bar_label := Label.new()
	bar_label.text = "Press [E/A] when the cursor hits the sweet spot!"
	bar_label.add_theme_font_size_override("font_size", 13)
	bar_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cook_vbox.add_child(bar_label)

	# Timing bar container
	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(0, 40)
	cook_vbox.add_child(bar_container)

	# Bar background
	cooking_bg = ColorRect.new()
	cooking_bg.anchors_preset = Control.PRESET_FULL_RECT
	cooking_bg.anchor_right = 1.0
	cooking_bg.anchor_bottom = 1.0
	cooking_bg.color = Color(0.2, 0.2, 0.2)
	bar_container.add_child(cooking_bg)

	# Sweet spot
	sweet_spot_rect = ColorRect.new()
	sweet_spot_rect.position = Vector2(0, 0)
	sweet_spot_rect.size = Vector2(50, 40)
	sweet_spot_rect.color = Color(0.2, 0.7, 0.3, 0.5)
	bar_container.add_child(sweet_spot_rect)

	# Cursor
	cursor_bar = ColorRect.new()
	cursor_bar.position = Vector2(0, 0)
	cursor_bar.size = Vector2(4, 40)
	cursor_bar.color = Color(1, 0.9, 0.2)
	bar_container.add_child(cursor_bar)

	# Results panel (centered, hidden initially)
	result_panel = PanelContainer.new()
	result_panel.anchors_preset = Control.PRESET_CENTER
	result_panel.anchor_left = 0.5
	result_panel.anchor_top = 0.5
	result_panel.anchor_right = 0.5
	result_panel.anchor_bottom = 0.5
	result_panel.offset_left = -200.0
	result_panel.offset_top = -180.0
	result_panel.offset_right = 200.0
	result_panel.offset_bottom = 180.0
	result_panel.visible = false
	add_child(result_panel)

	var result_vbox := VBoxContainer.new()
	result_vbox.name = "VBox"
	result_vbox.add_theme_constant_override("separation", 10)
	result_panel.add_child(result_vbox)
