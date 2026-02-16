extends Node2D

@export var npc_name: String = "NPC"
@export var npc_type: String = "generic"  # "fishmonger", "upgrade", "generic"
@export var dialogue_lines: Array[String] = ["Hello there!"]

var upgrade_panel: Control = null

func _ready() -> void:
	var area: Area2D = $InteractArea
	if area.get_child_count() == 0 or area.get_child(0) is not CollisionShape2D:
		return
	var shape_node: CollisionShape2D = area.get_child(0)
	if shape_node.shape == null:
		var circle := CircleShape2D.new()
		circle.radius = 40.0
		shape_node.shape = circle

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	if $Sprite2D.texture == null:
		_create_placeholder_visual()

func _create_placeholder_visual() -> void:
	var color: Color
	match npc_type:
		"fishmonger":
			color = Color(0.2, 0.5, 0.9)
		"upgrade":
			color = Color(0.2, 0.8, 0.3)
		_:
			color = Color(0.8, 0.6, 0.3)

	var rect := ColorRect.new()
	rect.size = Vector2(16, 16)
	rect.position = Vector2(-8, -8)
	rect.color = color
	add_child(rect)

	var label := Label.new()
	label.text = npc_name
	label.position = Vector2(-30, -28)
	label.add_theme_font_size_override("font_size", 10)
	add_child(label)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		var hub = get_parent()
		if hub.has_method("_on_npc_area_entered"):
			hub._on_npc_area_entered(self)

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		var hub = get_parent()
		if hub.has_method("_on_npc_area_exited"):
			hub._on_npc_area_exited(self)

func get_dialogue() -> Array[String]:
	match npc_type:
		"fishmonger":
			if Inventory.fish_storage.is_empty():
				return ["Welcome to the fish market!", "Bring me your catch and I'll buy it."]
			else:
				var count := Inventory.fish_storage.size()
				var total := 0
				for fish in Inventory.fish_storage:
					total += fish.value
				return [
					"Welcome back!",
					"You have %d fish worth %dg total." % [count, total],
					"Selling them all for you!"
				]
		"upgrade":
			return [
				"Ahoy! I can upgrade your gear.",
				"Take a look at what I've got!"
			]
		_:
			return dialogue_lines

func on_interact() -> void:
	match npc_type:
		"fishmonger":
			if not Inventory.fish_storage.is_empty():
				Inventory.sell_all_storage()
		"upgrade":
			_show_upgrade_menu()

func _show_upgrade_menu() -> void:
	if upgrade_panel and is_instance_valid(upgrade_panel):
		upgrade_panel.queue_free()

	upgrade_panel = _create_upgrade_panel()
	# Add to a CanvasLayer so it's above everything
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	canvas.add_child(upgrade_panel)
	get_tree().current_scene.add_child(canvas)

func _create_upgrade_panel() -> Control:
	var panel := PanelContainer.new()
	panel.anchors_preset = Control.PRESET_CENTER
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -250.0
	panel.offset_top = -280.0
	panel.offset_right = 250.0
	panel.offset_bottom = 280.0

	var margin := MarginContainer.new()
	margin.layout_mode = 1
	margin.anchors_preset = Control.PRESET_FULL_RECT
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.layout_mode = 2
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Captain Higa's Upgrades"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Gold display
	var gold_lbl := Label.new()
	gold_lbl.text = "Your Gold: %dg" % Inventory.gold
	gold_lbl.name = "GoldDisplay"
	gold_lbl.add_theme_font_size_override("font_size", 14)
	gold_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(gold_lbl)

	# Upgrade rows
	for type in [
		UpgradeSystem.UpgradeType.BOAT_SPEED,
		UpgradeSystem.UpgradeType.OXYGEN_TANK,
		UpgradeSystem.UpgradeType.HARPOON_RANGE,
		UpgradeSystem.UpgradeType.HULL_DURABILITY,
		UpgradeSystem.UpgradeType.BATTERY_CAPACITY,
		UpgradeSystem.UpgradeType.SONAR_RANGE,
	]:
		var row := _create_upgrade_row(type, gold_lbl)
		vbox.add_child(row)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 35)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func():
		panel.get_parent().queue_free()  # Remove the CanvasLayer
	)
	vbox.add_child(close_btn)

	return panel

func _create_upgrade_row(type: UpgradeSystem.UpgradeType, gold_label: Label) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	# Info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	name_lbl.text = UpgradeSystem.get_name(type)
	name_lbl.add_theme_font_size_override("font_size", 16)
	info.add_child(name_lbl)

	var level_lbl := Label.new()
	level_lbl.name = "LevelLabel"
	level_lbl.text = "Current: %s" % UpgradeSystem.get_level_name(type)
	level_lbl.add_theme_font_size_override("font_size", 12)
	level_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info.add_child(level_lbl)

	row.add_child(info)

	# Buy button
	var btn := Button.new()
	btn.name = "BuyBtn"
	if UpgradeSystem.is_maxed(type):
		btn.text = "MAXED"
		btn.disabled = true
	else:
		var cost := UpgradeSystem.get_cost(type)
		btn.text = "Upgrade (%dg)" % cost
		btn.disabled = not UpgradeSystem.can_upgrade(type)
		btn.pressed.connect(func():
			if UpgradeSystem.purchase_upgrade(type):
				# Refresh the row
				level_lbl.text = "Current: %s" % UpgradeSystem.get_level_name(type)
				gold_label.text = "Your Gold: %dg" % Inventory.gold
				if UpgradeSystem.is_maxed(type):
					btn.text = "MAXED"
					btn.disabled = true
				else:
					var new_cost := UpgradeSystem.get_cost(type)
					btn.text = "Upgrade (%dg)" % new_cost
					btn.disabled = not UpgradeSystem.can_upgrade(type)
		)
	btn.custom_minimum_size = Vector2(140, 35)
	row.add_child(btn)

	return row
