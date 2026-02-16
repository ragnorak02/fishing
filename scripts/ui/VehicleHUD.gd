extends CanvasLayer
## Vehicle HUD — mode label, throttle gauge, hull/battery/depth bars, button prompts.

var gold_label: Label
var location_label: Label
var mode_label: Label
var throttle_bar: ProgressBar
var hull_bar: ProgressBar
var battery_bar: ProgressBar
var depth_bar: ProgressBar
var battery_container: HBoxContainer
var depth_container: HBoxContainer
var interact_prompt: Label
var button_prompts: Label

var current_mode: int = 0  # VehicleStateMachine.Mode.SURFACE

func _ready() -> void:
	_build_ui()
	Inventory.gold_changed.connect(_on_gold_changed)
	_on_gold_changed(Inventory.gold)
	set_mode(VehicleStateMachine.Mode.SURFACE)

func _build_ui() -> void:
	layer = 5

	# --- Top Bar ---
	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.offset_left = 10.0
	top_bar.offset_right = 1270.0
	top_bar.offset_bottom = 35.0
	add_child(top_bar)

	var loc_label := Label.new()
	loc_label.name = "LocationLabel"
	loc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loc_label.add_theme_font_size_override("font_size", 16)
	loc_label.text = "Open Sea"
	top_bar.add_child(loc_label)
	location_label = loc_label

	var g_label := Label.new()
	g_label.name = "GoldLabel"
	g_label.add_theme_font_size_override("font_size", 16)
	g_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
	g_label.text = "0g"
	g_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_bar.add_child(g_label)
	gold_label = g_label

	# --- Mode Label (top center) ---
	var m_label := Label.new()
	m_label.name = "ModeLabel"
	m_label.anchor_left = 0.5
	m_label.anchor_right = 0.5
	m_label.offset_left = -80.0
	m_label.offset_right = 80.0
	m_label.offset_top = 45.0
	m_label.offset_bottom = 70.0
	m_label.add_theme_font_size_override("font_size", 18)
	m_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	m_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m_label.text = "-- SURFACE --"
	add_child(m_label)
	mode_label = m_label

	# --- Throttle Bar (left side) ---
	var t_bar := ProgressBar.new()
	t_bar.name = "ThrottleBar"
	t_bar.anchor_left = 0.0
	t_bar.anchor_top = 0.5
	t_bar.anchor_right = 0.0
	t_bar.anchor_bottom = 0.5
	t_bar.offset_left = 20.0
	t_bar.offset_top = -80.0
	t_bar.offset_right = 45.0
	t_bar.offset_bottom = 80.0
	t_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	t_bar.value = 0.0
	t_bar.show_percentage = false
	add_child(t_bar)
	throttle_bar = t_bar

	# Throttle label
	var t_label := Label.new()
	t_label.text = "THR"
	t_label.add_theme_font_size_override("font_size", 10)
	t_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	t_label.anchor_left = 0.0
	t_label.anchor_top = 0.5
	t_label.offset_left = 18.0
	t_label.offset_top = 85.0
	t_label.offset_right = 48.0
	t_label.offset_bottom = 100.0
	t_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(t_label)

	# --- Status Bars Container (right side) ---
	var status_vbox := VBoxContainer.new()
	status_vbox.name = "StatusBars"
	status_vbox.anchor_left = 1.0
	status_vbox.anchor_right = 1.0
	status_vbox.anchor_top = 0.5
	status_vbox.anchor_bottom = 0.5
	status_vbox.offset_left = -170.0
	status_vbox.offset_right = -20.0
	status_vbox.offset_top = -60.0
	status_vbox.offset_bottom = 60.0
	status_vbox.add_theme_constant_override("separation", 8)
	add_child(status_vbox)

	# Hull bar
	var hull_hbox := HBoxContainer.new()
	hull_hbox.add_theme_constant_override("separation", 6)
	status_vbox.add_child(hull_hbox)
	var hull_label := Label.new()
	hull_label.text = "HULL"
	hull_label.add_theme_font_size_override("font_size", 11)
	hull_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	hull_label.custom_minimum_size.x = 35
	hull_hbox.add_child(hull_label)
	var h_bar := ProgressBar.new()
	h_bar.name = "HullBar"
	h_bar.custom_minimum_size = Vector2(100, 14)
	h_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_bar.value = 100.0
	h_bar.show_percentage = false
	h_bar.modulate = Color(0.3, 1.0, 0.4)
	hull_hbox.add_child(h_bar)
	hull_bar = h_bar

	# Battery bar + container
	var batt_hbox := HBoxContainer.new()
	batt_hbox.name = "BatteryContainer"
	batt_hbox.add_theme_constant_override("separation", 6)
	status_vbox.add_child(batt_hbox)
	var batt_label := Label.new()
	batt_label.text = "BATT"
	batt_label.add_theme_font_size_override("font_size", 11)
	batt_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	batt_label.custom_minimum_size.x = 35
	batt_hbox.add_child(batt_label)
	var b_bar := ProgressBar.new()
	b_bar.name = "BatteryBar"
	b_bar.custom_minimum_size = Vector2(100, 14)
	b_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_bar.value = 100.0
	b_bar.show_percentage = false
	b_bar.modulate = Color(0.3, 0.7, 1.0)
	batt_hbox.add_child(b_bar)
	battery_bar = b_bar
	battery_container = batt_hbox

	# Depth bar + container
	var depth_hbox := HBoxContainer.new()
	depth_hbox.name = "DepthContainer"
	depth_hbox.add_theme_constant_override("separation", 6)
	status_vbox.add_child(depth_hbox)
	var depth_label := Label.new()
	depth_label.text = "DPTH"
	depth_label.add_theme_font_size_override("font_size", 11)
	depth_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	depth_label.custom_minimum_size.x = 35
	depth_hbox.add_child(depth_label)
	var d_bar := ProgressBar.new()
	d_bar.name = "DepthBar"
	d_bar.custom_minimum_size = Vector2(100, 14)
	d_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_bar.value = 0.0
	d_bar.show_percentage = false
	d_bar.modulate = Color(0.5, 0.3, 0.9)
	depth_hbox.add_child(d_bar)
	depth_bar = d_bar
	depth_container = depth_hbox

	# --- Button Prompts (bottom center) ---
	var bp_label := Label.new()
	bp_label.name = "ButtonPrompts"
	bp_label.anchor_left = 0.5
	bp_label.anchor_right = 0.5
	bp_label.anchor_top = 1.0
	bp_label.anchor_bottom = 1.0
	bp_label.offset_left = -250.0
	bp_label.offset_right = 250.0
	bp_label.offset_top = -55.0
	bp_label.offset_bottom = -35.0
	bp_label.add_theme_font_size_override("font_size", 13)
	bp_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	bp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(bp_label)
	button_prompts = bp_label

	# --- Interact Prompt (above button prompts) ---
	var ip_label := Label.new()
	ip_label.name = "InteractPrompt"
	ip_label.visible = false
	ip_label.anchor_left = 0.5
	ip_label.anchor_right = 0.5
	ip_label.anchor_top = 1.0
	ip_label.anchor_bottom = 1.0
	ip_label.offset_left = -200.0
	ip_label.offset_right = 200.0
	ip_label.offset_top = -80.0
	ip_label.offset_bottom = -60.0
	ip_label.add_theme_font_size_override("font_size", 16)
	ip_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	ip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ip_label.text = "[E] Interact"
	add_child(ip_label)
	interact_prompt = ip_label

func set_location(location_name: String) -> void:
	if location_label:
		location_label.text = location_name

func set_mode(mode: int) -> void:
	current_mode = mode
	match mode:
		VehicleStateMachine.Mode.SURFACE:
			mode_label.text = "-- SURFACE --"
			mode_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
			battery_container.visible = false
			depth_container.visible = false
			button_prompts.text = "[W/S] Throttle  [A/D] Steer  [R] Submerge  [E] Interact"
		VehicleStateMachine.Mode.SUBMERGED:
			mode_label.text = "-- SUBMERGED --"
			mode_label.add_theme_color_override("font_color", Color(0.2, 0.6, 1.0))
			battery_container.visible = true
			depth_container.visible = true
			button_prompts.text = "[W/S] Throttle  [A/D] Steer  [Q/E] Depth  [LMB] Harpoon  [Space] Sonar  [R] Surface"
		_:
			mode_label.text = "-- ??? --"

func update_throttle(value: float) -> void:
	if throttle_bar:
		throttle_bar.value = (value + 1.0) * 50.0  # Map -1..1 to 0..100

func update_hull(current: float, maximum: float) -> void:
	if hull_bar:
		hull_bar.value = (current / maximum) * 100.0
		# Color shift: green -> yellow -> red
		var pct := current / maximum
		if pct > 0.5:
			hull_bar.modulate = Color(0.3, 1.0, 0.4)
		elif pct > 0.25:
			hull_bar.modulate = Color(1.0, 0.8, 0.2)
		else:
			hull_bar.modulate = Color(1.0, 0.2, 0.2)

func update_battery(current: float, maximum: float) -> void:
	if battery_bar:
		battery_bar.value = (current / maximum) * 100.0

func update_depth(depth: float, max_depth: float) -> void:
	if depth_bar:
		depth_bar.value = (depth / max_depth) * 100.0

func _on_gold_changed(amount: int) -> void:
	if gold_label:
		gold_label.text = "%dg" % amount
