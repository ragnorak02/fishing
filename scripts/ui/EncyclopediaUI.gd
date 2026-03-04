extends Control

signal closed()

var fish_list: VBoxContainer
var _scroll_ref: ScrollContainer

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
	dimmer.color = Color(0, 0, 0, 0.6)
	add_child(dimmer)

	var panel := PanelContainer.new()
	panel.anchors_preset = Control.PRESET_CENTER
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -350.0
	panel.offset_top = -280.0
	panel.offset_right = 350.0
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

	# Title with discovery count
	var all_species := FishDatabase.get_all_species()
	var discovered := SaveManager.get_discovery_count()
	var title := Label.new()
	title.text = "Fish Encyclopedia  —  Discovered: %d/%d" % [discovered, all_species.size()]
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Scroll area
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	_scroll_ref = scroll
	vbox.add_child(scroll)

	fish_list = VBoxContainer.new()
	fish_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fish_list.add_theme_constant_override("separation", 6)
	scroll.add_child(fish_list)

	_populate_list(all_species)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 35)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_close)
	vbox.add_child(close_btn)
	close_btn.call_deferred("grab_focus")

func _populate_list(all_species: Array) -> void:
	# Sort by rarity then name for consistent order
	var sorted := all_species.duplicate()
	sorted.sort_custom(func(a, b):
		if a.rarity != b.rarity:
			return a.rarity < b.rarity
		return a.display_name < b.display_name
	)

	for species in sorted:
		var discovered := SaveManager.is_species_discovered(species.id)
		var card := _create_species_card(species, discovered)
		fish_list.add_child(card)

func _create_species_card(species: FishSpecies, discovered: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 65)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	# Rarity bar
	var rarity_bar := ColorRect.new()
	rarity_bar.custom_minimum_size = Vector2(6, 0)
	rarity_bar.color = species.get_rarity_color() if discovered else Color(0.4, 0.4, 0.4)
	hbox.add_child(rarity_bar)

	# Info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)

	if discovered:
		# Name + rarity
		var name_lbl := Label.new()
		name_lbl.text = "%s  [%s]" % [species.display_name, species.get_rarity_name()]
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", species.get_rarity_color())
		info.add_child(name_lbl)

		# Details line
		var detail_lbl := Label.new()
		var sushi_tag := "  |  Sushi Grade" if species.sushi_grade else ""
		var biome_text := ", ".join(Array(species.biomes))
		detail_lbl.text = "%.1f–%.1f kg  |  %dg base  |  %s%s" % [
			species.weight_range.x, species.weight_range.y,
			species.base_value, biome_text, sushi_tag
		]
		detail_lbl.add_theme_font_size_override("font_size", 11)
		detail_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		info.add_child(detail_lbl)

		# Description
		if species.description != "":
			var desc_lbl := Label.new()
			desc_lbl.text = species.description
			desc_lbl.add_theme_font_size_override("font_size", 11)
			desc_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info.add_child(desc_lbl)
	else:
		var unknown_lbl := Label.new()
		unknown_lbl.text = "???"
		unknown_lbl.add_theme_font_size_override("font_size", 16)
		unknown_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
		info.add_child(unknown_lbl)

		var hint_lbl := Label.new()
		hint_lbl.text = "Not yet discovered"
		hint_lbl.add_theme_font_size_override("font_size", 11)
		hint_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
		info.add_child(hint_lbl)

	hbox.add_child(info)
	return card

func _process(delta: float) -> void:
	if _scroll_ref:
		var v := Input.get_axis("move_up", "move_down")
		if v != 0.0:
			_scroll_ref.scroll_vertical += int(v * 300.0 * delta)

func _close() -> void:
	closed.emit()
	get_parent().queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
