extends Control

signal closed()

var recipe_list: VBoxContainer
var summary_label: Label
var _scroll_ref: ScrollContainer
var _close_btn: Button

func _ready() -> void:
	_build_ui()
	Inventory.menu_changed.connect(_refresh)
	Inventory.storage_changed.connect(_refresh)

func _build_ui() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0

	# Full-screen dimmer
	var dimmer := ColorRect.new()
	dimmer.anchors_preset = Control.PRESET_FULL_RECT
	dimmer.anchor_right = 1.0
	dimmer.anchor_bottom = 1.0
	dimmer.color = Color(0, 0, 0, 0.5)
	add_child(dimmer)

	var panel := PanelContainer.new()
	panel.anchors_preset = Control.PRESET_CENTER
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -320.0
	panel.offset_top = -280.0
	panel.offset_right = 320.0
	panel.offset_bottom = 280.0
	add_child(panel)

	var margin := MarginContainer.new()
	margin.anchors_preset = Control.PRESET_FULL_RECT
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Tonight's Menu"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Scroll area
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	_scroll_ref = scroll
	vbox.add_child(scroll)

	recipe_list = VBoxContainer.new()
	recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_list.add_theme_constant_override("separation", 6)
	scroll.add_child(recipe_list)

	_populate_recipes()

	# Active menu summary
	summary_label = Label.new()
	_update_summary()
	summary_label.add_theme_font_size_override("font_size", 13)
	summary_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.5))
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(summary_label)

	# Close button
	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.custom_minimum_size = Vector2(100, 35)
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_btn.pressed.connect(_close)
	vbox.add_child(_close_btn)
	_close_btn.call_deferred("grab_focus")

func _populate_recipes() -> void:
	for child in recipe_list.get_children():
		child.queue_free()

	if Inventory.unlocked_recipes.is_empty():
		var empty := Label.new()
		empty.text = "No recipes unlocked yet."
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		recipe_list.add_child(empty)
		return

	for recipe_id in Inventory.unlocked_recipes:
		var recipe := RecipeDatabase.get_recipe(recipe_id)
		if recipe == null:
			continue

		var row := PanelContainer.new()
		var is_active := recipe_id in Inventory.active_menu

		# Gold border for active recipes
		if is_active:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.15, 0.13, 0.1, 0.9)
			style.border_color = Color(1, 0.85, 0.3)
			style.set_border_width_all(2)
			style.set_corner_radius_all(4)
			style.content_margin_left = 8
			style.content_margin_right = 8
			style.content_margin_top = 6
			style.content_margin_bottom = 6
			row.add_theme_stylebox_override("panel", style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		row.add_child(hbox)

		# Recipe info
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_lbl := Label.new()
		name_lbl.text = "%s  — %dg" % [recipe.display_name, recipe.sell_price]
		name_lbl.add_theme_font_size_override("font_size", 15)
		info.add_child(name_lbl)

		# Ingredient list with availability coloring
		var ing_text := ""
		for ingredient in recipe.ingredients:
			var species := FishDatabase.get_species(ingredient.species_id)
			var name_str := species.display_name if species else ingredient.species_id
			var have := Inventory.get_fish_count_by_species(ingredient.species_id)
			var need := ingredient.quantity
			var color_tag := "[color=green]" if have >= need else "[color=red]"
			if ing_text != "":
				ing_text += ", "
			ing_text += "%s%s x%d (%d)[/color]" % [color_tag, name_str, need, have]

		var ing_lbl := RichTextLabel.new()
		ing_lbl.bbcode_enabled = true
		ing_lbl.text = ing_text
		ing_lbl.fit_content = true
		ing_lbl.custom_minimum_size = Vector2(0, 20)
		ing_lbl.add_theme_font_size_override("normal_font_size", 12)
		info.add_child(ing_lbl)

		hbox.add_child(info)

		# Toggle button
		var toggle_btn := Button.new()
		toggle_btn.text = "Remove" if is_active else "Add"
		toggle_btn.custom_minimum_size = Vector2(80, 35)
		var rid := recipe_id
		toggle_btn.pressed.connect(func():
			Inventory.toggle_recipe_on_menu(rid)
		)
		# Disable add if menu full and not active
		if not is_active and Inventory.active_menu.size() >= 4:
			toggle_btn.disabled = true
			toggle_btn.text = "Full"
		hbox.add_child(toggle_btn)

		recipe_list.add_child(row)

func _update_summary() -> void:
	if summary_label:
		summary_label.text = "Active Menu: %d/4 dishes" % Inventory.active_menu.size()

func _process(delta: float) -> void:
	if _scroll_ref:
		var v := Input.get_axis("move_up", "move_down")
		if v != 0.0:
			_scroll_ref.scroll_vertical += int(v * 300.0 * delta)

func _refresh() -> void:
	_populate_recipes()
	_update_summary()
	if _close_btn:
		_close_btn.call_deferred("grab_focus")

func _close() -> void:
	closed.emit()
	get_parent().queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
