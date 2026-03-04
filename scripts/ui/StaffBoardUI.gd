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

	var panel := PanelContainer.new()
	panel.anchors_preset = Control.PRESET_CENTER
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280.0
	panel.offset_top = -220.0
	panel.offset_right = 280.0
	panel.offset_bottom = 220.0
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
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Staff Board"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Staff role slots
	var roles := [
		{"name": "Chef", "desc": "Improves cook timing"},
		{"name": "Server", "desc": "Faster order delivery"},
		{"name": "Cleaner", "desc": "Higher customer satisfaction"},
		{"name": "Helper", "desc": "Reduces ingredient waste"},
	]

	for role in roles:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_lbl := Label.new()
		name_lbl.text = role.name
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
		info.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = role.desc
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		info.add_child(desc_lbl)

		row.add_child(info)

		var hire_btn := Button.new()
		hire_btn.text = "Hire"
		hire_btn.custom_minimum_size = Vector2(80, 35)
		hire_btn.disabled = true
		row.add_child(hire_btn)

		vbox.add_child(row)

	# Footer
	var footer := Label.new()
	footer.text = "Staff hiring coming soon!"
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(footer)

	# Close button
	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.custom_minimum_size = Vector2(100, 35)
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_btn.pressed.connect(_close)
	vbox.add_child(_close_btn)
	_close_btn.call_deferred("grab_focus")

func _close() -> void:
	closed.emit()
	get_parent().queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
