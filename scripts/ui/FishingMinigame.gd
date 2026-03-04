class_name FishingMinigame
extends Control
## Dredge-style timing-bar fishing minigame overlay.
## Cursor bounces left-right; press interact in the sweet spot to catch.

signal fishing_completed(species_id: String, weight: float)
signal fishing_failed()

const BAR_WIDTH := 400.0
const BAR_HEIGHT := 24.0
const CURSOR_WIDTH := 6.0
const SWEET_SPOT_PERCENT := 0.15  # 15% of bar
const PERFECT_PERCENT := 0.075  # 7.5% inner zone

var biome: String = "shallow"
var cursor_pos: float = 0.0  # 0.0 to 1.0
var cursor_direction: float = 1.0
var cursor_speed: float = 1.8
var sweet_spot_center: float = 0.5
var is_active: bool = true
var result_shown: bool = false

# UI refs
var bar_bg: ColorRect
var sweet_spot_rect: ColorRect
var perfect_rect: ColorRect
var cursor_rect: ColorRect
var title_label: Label
var prompt_label: Label
var result_label: Label
var panel: PanelContainer

func _init(p_biome: String = "shallow") -> void:
	biome = p_biome

func _ready() -> void:
	# Fullscreen overlay
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP

	# Randomize
	sweet_spot_center = randf_range(0.25, 0.75)
	cursor_speed = 1.8 * randf_range(0.8, 1.5)

	_build_ui()

func _build_ui() -> void:
	# Dim background
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.5)
	dim.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(dim)

	# Center panel
	panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -240.0
	panel.offset_right = 240.0
	panel.offset_top = -100.0
	panel.offset_bottom = 100.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	style.border_color = Color(0.9, 0.75, 0.2)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	title_label = Label.new()
	title_label.text = "FISHING"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.2))
	vbox.add_child(title_label)

	# Prompt
	prompt_label = Label.new()
	prompt_label.text = "Press [E] when the cursor is in the gold zone!"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 13)
	prompt_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.7))
	vbox.add_child(prompt_label)

	# Bar container (centered)
	var bar_center := CenterContainer.new()
	vbox.add_child(bar_center)

	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_center.add_child(bar_container)

	# Bar background
	bar_bg = ColorRect.new()
	bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_bg.color = Color(0.15, 0.18, 0.22)
	bar_container.add_child(bar_bg)

	# Sweet spot zone
	var spot_width: float = BAR_WIDTH * SWEET_SPOT_PERCENT
	var spot_x: float = (sweet_spot_center - SWEET_SPOT_PERCENT / 2.0) * BAR_WIDTH
	sweet_spot_rect = ColorRect.new()
	sweet_spot_rect.position = Vector2(spot_x, 0)
	sweet_spot_rect.size = Vector2(spot_width, BAR_HEIGHT)
	sweet_spot_rect.color = Color(0.9, 0.75, 0.2, 0.35)
	bar_container.add_child(sweet_spot_rect)

	# Perfect zone (inner)
	var perf_width: float = BAR_WIDTH * PERFECT_PERCENT
	var perf_x: float = (sweet_spot_center - PERFECT_PERCENT / 2.0) * BAR_WIDTH
	perfect_rect = ColorRect.new()
	perfect_rect.position = Vector2(perf_x, 0)
	perfect_rect.size = Vector2(perf_width, BAR_HEIGHT)
	perfect_rect.color = Color(1.0, 0.85, 0.2, 0.6)
	bar_container.add_child(perfect_rect)

	# Cursor
	cursor_rect = ColorRect.new()
	cursor_rect.size = Vector2(CURSOR_WIDTH, BAR_HEIGHT + 4)
	cursor_rect.position = Vector2(0, -2)
	cursor_rect.color = Color(1, 1, 1)
	bar_container.add_child(cursor_rect)

	# Result label
	result_label = Label.new()
	result_label.text = ""
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 18)
	result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	vbox.add_child(result_label)

func _process(delta: float) -> void:
	if not is_active or result_shown:
		return

	# Bounce cursor
	cursor_pos += cursor_direction * cursor_speed * delta
	if cursor_pos >= 1.0:
		cursor_pos = 1.0
		cursor_direction = -1.0
	elif cursor_pos <= 0.0:
		cursor_pos = 0.0
		cursor_direction = 1.0

	# Update cursor visual
	if cursor_rect:
		cursor_rect.position.x = cursor_pos * (BAR_WIDTH - CURSOR_WIDTH)

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	if result_shown:
		return

	if event.is_action_pressed("interact"):
		_attempt_catch()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()

func _attempt_catch() -> void:
	result_shown = true
	var distance := absf(cursor_pos - sweet_spot_center)

	if distance <= PERFECT_PERCENT / 2.0:
		_show_result_perfect()
	elif distance <= SWEET_SPOT_PERCENT / 2.0:
		_show_result_good()
	else:
		_show_result_miss()

func _show_result_perfect() -> void:
	var species := FishDatabase.get_random_species_for_biome(biome)
	if species == null:
		_show_result_miss()
		return
	var weight := FishScaling.get_scaled_weight(species)
	result_label.text = "PERFECT! Caught %s (%.1f kg)" % [species.display_name, weight]
	result_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	prompt_label.text = ""
	_close_after_delay(species.id, weight)

func _show_result_good() -> void:
	var species := FishDatabase.get_random_species_for_biome(biome)
	if species == null:
		_show_result_miss()
		return
	var weight := FishScaling.get_scaled_weight(species) * 0.75
	result_label.text = "GOOD! Caught %s (%.1f kg)" % [species.display_name, weight]
	result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	prompt_label.text = ""
	_close_after_delay(species.id, weight)

func _show_result_miss() -> void:
	result_label.text = "The fish got away!"
	result_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	prompt_label.text = ""
	get_tree().create_timer(1.5).timeout.connect(func():
		is_active = false
		fishing_failed.emit()
		queue_free()
	)

func _close_after_delay(species_id: String, weight: float) -> void:
	get_tree().create_timer(1.5).timeout.connect(func():
		is_active = false
		fishing_completed.emit(species_id, weight)
		queue_free()
	)

func _cancel() -> void:
	is_active = false
	fishing_failed.emit()
	queue_free()
