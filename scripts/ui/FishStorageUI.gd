extends Control

signal closed()

var fish_list: VBoxContainer
var gold_label: Label

func _ready() -> void:
	_build_ui()
	Inventory.storage_changed.connect(_refresh_list)
	Inventory.gold_changed.connect(func(_g): _update_gold())

func _build_ui() -> void:
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
	panel.offset_left = -300.0
	panel.offset_top = -250.0
	panel.offset_right = 300.0
	panel.offset_bottom = 250.0
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
	title.text = "Fish Storage"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Gold
	gold_label = Label.new()
	_update_gold()
	gold_label.add_theme_font_size_override("font_size", 14)
	gold_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(gold_label)

	# Scroll area
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	fish_list = VBoxContainer.new()
	fish_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fish_list.add_theme_constant_override("separation", 6)
	scroll.add_child(fish_list)

	_populate_list()

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 35)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_close)
	vbox.add_child(close_btn)

func _populate_list() -> void:
	for child in fish_list.get_children():
		child.queue_free()

	if Inventory.fish_storage.is_empty():
		var empty := Label.new()
		empty.text = "No fish in storage."
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fish_list.add_child(empty)
		return

	# Group by species
	var groups: Dictionary = {}
	for fish in Inventory.fish_storage:
		var sid: String = fish.species_id
		if not groups.has(sid):
			groups[sid] = {"fish_list": [], "total_value": 0}
		groups[sid].fish_list.append(fish)
		groups[sid].total_value += fish.value

	for sid in groups:
		var group = groups[sid]
		var species := FishDatabase.get_species(sid)
		var display := species.display_name if species else sid
		var color := species.get_rarity_color() if species else Color.WHITE

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		# Rarity bar
		var rarity_bar := ColorRect.new()
		rarity_bar.custom_minimum_size = Vector2(6, 0)
		rarity_bar.color = color
		row.add_child(rarity_bar)

		# Info
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_lbl := Label.new()
		name_lbl.text = "%s  x%d" % [display, group.fish_list.size()]
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", color)
		info.add_child(name_lbl)
		var val_lbl := Label.new()
		val_lbl.text = "Total: %dg" % group.total_value
		val_lbl.add_theme_font_size_override("font_size", 12)
		val_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		info.add_child(val_lbl)
		row.add_child(info)

		# Sell button
		var sell_btn := Button.new()
		sell_btn.text = "Sell All (%dg)" % group.total_value
		sell_btn.custom_minimum_size = Vector2(130, 35)
		var species_id := sid
		sell_btn.pressed.connect(func():
			_sell_species(species_id)
		)
		row.add_child(sell_btn)

		fish_list.add_child(row)

func _sell_species(species_id: String) -> void:
	var i := Inventory.fish_storage.size() - 1
	var total := 0
	while i >= 0:
		if Inventory.fish_storage[i].species_id == species_id:
			total += Inventory.fish_storage[i].value
			Inventory.fish_storage.remove_at(i)
		i -= 1
	if total > 0:
		Inventory.gold += total
		Inventory.gold_changed.emit(Inventory.gold)
		Inventory.storage_changed.emit()
		Inventory.fish_sold.emit(total)

func _refresh_list() -> void:
	_populate_list()

func _update_gold() -> void:
	if gold_label:
		gold_label.text = "Gold: %dg" % Inventory.gold

func _close() -> void:
	closed.emit()
	get_parent().queue_free()  # Remove CanvasLayer

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()
