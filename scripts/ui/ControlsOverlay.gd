extends CanvasLayer
## Always-visible on-screen controls display that highlights active inputs.

const COLOR_IDLE := Color(1, 1, 1, 0.35)
const COLOR_ACTIVE := Color(1, 0.9, 0.2, 1.0)
const FONT_SIZE := 13
const BADGE_FONT_SIZE := 11

var control_labels: Dictionary = {}  # action_name -> {label, badge}
var context: String = "hub"  # "hub", "ocean", "dive", "menu", "haul"

func _ready() -> void:
	layer = 90
	GameManager.state_changed.connect(_on_state_changed)
	_build_ui()

func _on_state_changed(new_state) -> void:
	match new_state:
		GameManager.GameState.MAIN_MENU:
			context = "menu"
		GameManager.GameState.HUB_TOWN:
			context = "hub"
		GameManager.GameState.OCEAN_SURFACE:
			context = "ocean"
		GameManager.GameState.DIVING:
			context = "dive"
		GameManager.GameState.HAUL_SUMMARY:
			context = "haul"
	_rebuild_controls()

func _build_ui() -> void:
	# Container in bottom-left
	var panel := PanelContainer.new()
	panel.name = "ControlsPanel"
	panel.anchors_preset = Control.PRESET_BOTTOM_LEFT
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 10.0
	panel.offset_top = -200.0
	panel.offset_right = 220.0
	panel.offset_bottom = -10.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Semi-transparent background
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.4)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	add_child(panel)
	_rebuild_controls()

func _rebuild_controls() -> void:
	var vbox: VBoxContainer = get_node_or_null("ControlsPanel/VBox")
	if vbox == null:
		return

	# Clear existing
	for child in vbox.get_children():
		child.queue_free()
	control_labels.clear()

	# Title
	var title := Label.new()
	title.text = "Controls"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	vbox.add_child(title)

	# Build control list based on context
	var controls: Array = _get_controls_for_context()
	for entry in controls:
		var action: String = entry[0]
		var kbd_label: String = entry[1]
		var pad_label: String = entry[2]
		var desc: String = entry[3]
		_add_control_row(vbox, action, kbd_label, pad_label, desc)

func _get_controls_for_context() -> Array:
	match context:
		"menu":
			return [
				["interact", "E", "A", "Confirm"],
				["move_up", "W/Up", "LS", "Navigate"],
			]
		"hub":
			return [
				["move_up", "WASD", "LS", "Move"],
				["interact", "E", "A", "Talk / Enter"],
			]
		"ocean":
			return [
				["move_up", "W/S", "LS", "Throttle"],
				["move_left", "A/D", "LS", "Steer"],
				["boost", "Shift", "B", "Boost"],
				["interact", "E", "A", "Dive / Dock"],
			]
		"dive":
			return [
				["move_up", "WASD", "LS", "Swim"],
				["fire_harpoon", "LMB", "X/RT", "Harpoon"],
				["interact", "E", "A", "Surface"],
			]
		"haul":
			return [
				["interact", "E", "A", "Confirm"],
			]
		_:
			return [
				["move_up", "WASD", "LS", "Move"],
				["interact", "E", "A", "Interact"],
			]

func _add_control_row(parent: VBoxContainer, action: String, kbd: String, pad: String, desc: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Keyboard badge
	var kbd_badge := Label.new()
	kbd_badge.text = " %s " % kbd
	kbd_badge.add_theme_font_size_override("font_size", BADGE_FONT_SIZE)
	kbd_badge.add_theme_color_override("font_color", COLOR_IDLE)
	hbox.add_child(kbd_badge)

	# Separator
	var sep := Label.new()
	sep.text = "/"
	sep.add_theme_font_size_override("font_size", BADGE_FONT_SIZE)
	sep.add_theme_color_override("font_color", Color(1, 1, 1, 0.25))
	hbox.add_child(sep)

	# Gamepad badge
	var pad_badge := Label.new()
	pad_badge.text = " %s " % pad
	pad_badge.add_theme_font_size_override("font_size", BADGE_FONT_SIZE)
	pad_badge.add_theme_color_override("font_color", COLOR_IDLE)
	hbox.add_child(pad_badge)

	# Description
	var desc_label := Label.new()
	desc_label.text = desc
	desc_label.add_theme_font_size_override("font_size", FONT_SIZE)
	desc_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(desc_label)

	parent.add_child(hbox)

	control_labels[action] = {
		"kbd": kbd_badge,
		"pad": pad_badge,
		"desc": desc_label,
	}

func _process(_delta: float) -> void:
	for action in control_labels:
		var data: Dictionary = control_labels[action]
		var active := Input.is_action_pressed(action)
		var color: Color = COLOR_ACTIVE if active else COLOR_IDLE
		data.kbd.add_theme_color_override("font_color", color)
		data.pad.add_theme_color_override("font_color", color)
		if active:
			data.desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		else:
			data.desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
