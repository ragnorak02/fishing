extends Control

signal closed()

var _close_btn: Button

func _ready() -> void:
	_build_ui()

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

	var panel := _create_upgrade_panel()
	add_child(panel)

func _create_upgrade_panel() -> PanelContainer:
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
	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.custom_minimum_size = Vector2(100, 35)
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_btn.pressed.connect(_close)
	vbox.add_child(_close_btn)
	_close_btn.call_deferred("grab_focus")

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
				AudioManager.play_sfx("upgrade")
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

func _close() -> void:
	closed.emit()
	get_parent().queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
