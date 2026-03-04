extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var interact_prompt: Label = $HUD/InteractPrompt
@onready var canvas_modulate: CanvasModulate = $CanvasModulate

var near_storage: bool = false
var near_menu: bool = false
var near_staff: bool = false
var near_upgrade: bool = false
var near_door: bool = false
var near_dinner: bool = false
var near_encyclopedia: bool = false

var ui_open: bool = false

func _set_ui_open(value: bool) -> void:
	ui_open = value
	player.set_physics_process(!value)
	if value:
		player.velocity = Vector2.ZERO

# Floating indicator reference
var _active_indicator: Node2D = null
var _indicator_tween: Tween = null

func _ready() -> void:
	AudioManager.play_music("hub_town")
	interact_prompt.visible = false

	# Set up collision shapes for interaction zones (sized for ~160px station spacing)
	_setup_area_shape($StoragePC, Vector2(70, 60))
	_setup_area_shape($MenuBoard, Vector2(70, 60))
	_setup_area_shape($StaffBoard, Vector2(70, 60))
	_setup_area_shape($UpgradeStation, Vector2(70, 60))
	_setup_area_shape($DoorExit, Vector2(70, 60))
	_setup_area_shape($DinnerPrompt, Vector2(70, 60))
	_setup_area_shape($EncyclopediaBoard, Vector2(70, 60))
	_create_boundaries()

	# Build environment decorations
	_build_environment()

	# Build station visuals (replaces old _setup_station_sprite)
	_build_station_visual($StoragePC, "storage")
	_build_station_visual($MenuBoard, "menu")
	_build_station_visual($StaffBoard, "staff")
	_build_station_visual($UpgradeStation, "upgrade")
	_build_station_visual($DoorExit, "exit")
	_build_station_visual($DinnerPrompt, "dinner")
	_build_station_visual($EncyclopediaBoard, "encyclopedia")

	# Update gold display
	_update_gold_display()
	Inventory.gold_changed.connect(func(_g): _update_gold_display())

	# Wire interaction zones
	$StoragePC.body_entered.connect(_on_storage_entered)
	$StoragePC.body_exited.connect(_on_storage_exited)
	$MenuBoard.body_entered.connect(_on_menu_entered)
	$MenuBoard.body_exited.connect(_on_menu_exited)
	$StaffBoard.body_entered.connect(_on_staff_entered)
	$StaffBoard.body_exited.connect(_on_staff_exited)
	$UpgradeStation.body_entered.connect(_on_upgrade_entered)
	$UpgradeStation.body_exited.connect(_on_upgrade_exited)
	$DoorExit.body_entered.connect(_on_door_entered)
	$DoorExit.body_exited.connect(_on_door_exited)
	$DinnerPrompt.body_entered.connect(_on_dinner_entered)
	$DinnerPrompt.body_exited.connect(_on_dinner_exited)
	$EncyclopediaBoard.body_entered.connect(_on_encyclopedia_entered)
	$EncyclopediaBoard.body_exited.connect(_on_encyclopedia_exited)

	# Time-of-day tint
	_apply_time_tint()
	TimeManager.time_changed.connect(func(_t): _apply_time_tint())

	# Update dinner prompt visibility
	_update_dinner_visibility()
	TimeManager.time_changed.connect(func(_t): _update_dinner_visibility())
	Inventory.menu_changed.connect(_update_dinner_visibility)

	# Day title card on morning
	if TimeManager.current_time == TimeManager.TimeOfDay.MORNING:
		_show_day_title()
		_check_recipe_unlocks()

func _process(_delta: float) -> void:
	if ui_open:
		return
	if Input.is_action_just_pressed("interact"):
		if near_storage:
			_open_storage()
		elif near_menu:
			_open_menu_board()
		elif near_staff:
			_open_staff_board()
		elif near_upgrade:
			_open_upgrade()
		elif near_encyclopedia:
			_open_encyclopedia()
		elif near_dinner:
			_start_dinner()
		elif near_door:
			TimeManager.advance_to(TimeManager.TimeOfDay.MIDDAY)
			GameManager.transition_to("res://scenes/ocean_surface/OceanSurface.tscn")

func _apply_time_tint() -> void:
	var target := TimeManager.get_ambient_color()
	var tween := create_tween()
	tween.tween_property(canvas_modulate, "color", target, 0.5)

func _update_dinner_visibility() -> void:
	var dinner_area: Area2D = $DinnerPrompt
	var is_afternoon := TimeManager.current_time == TimeManager.TimeOfDay.AFTERNOON
	var has_menu := not Inventory.active_menu.is_empty()
	dinner_area.visible = is_afternoon and has_menu
	var dinner_label: Label = $DinnerPrompt/Label
	if dinner_label:
		dinner_label.visible = is_afternoon and has_menu

func _show_day_title() -> void:
	var title := Label.new()
	title.text = "Day %d" % TimeManager.current_day
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.anchors_preset = Control.PRESET_CENTER
	title.modulate.a = 0.0
	$HUD.add_child(title)

	var tween := create_tween()
	tween.tween_property(title, "modulate:a", 1.0, 0.5)
	tween.tween_interval(1.0)
	tween.tween_property(title, "modulate:a", 0.0, 0.5)
	tween.tween_callback(title.queue_free)

func _check_recipe_unlocks() -> void:
	var day_recipes := {
		1: ["sardine_onigiri", "grilled_mackerel"],
		2: ["squid_yakitori", "sea_bream_sashimi"],
		3: ["octopus_takoyaki", "yellowtail_nigiri"],
		5: ["grouper_hot_pot"],
		7: ["bluefin_toro_platter"],
	}
	for day in day_recipes:
		if TimeManager.current_day >= day:
			for recipe_id in day_recipes[day]:
				Inventory.unlock_recipe(recipe_id)

# =============================================================================
# ENVIRONMENT DECORATIONS
# =============================================================================

func _build_environment() -> void:
	var env := Node2D.new()
	env.name = "EnvironmentDecor"
	env.z_index = -5
	add_child(env)

	# Baseboard strip (darker strip along bottom of wall)
	var baseboard := ColorRect.new()
	baseboard.position = Vector2(-600, 50)
	baseboard.size = Vector2(1200, 30)
	baseboard.color = Color(0.25, 0.18, 0.14, 1)
	env.add_child(baseboard)

	# Sushi bar counter body (860px centered)
	var counter_body := ColorRect.new()
	counter_body.position = Vector2(-430, 30)
	counter_body.size = Vector2(860, 60)
	counter_body.color = Color(0.4, 0.28, 0.18, 1)
	env.add_child(counter_body)

	# Counter surface top strip (lighter)
	var counter_top := ColorRect.new()
	counter_top.position = Vector2(-430, 25)
	counter_top.size = Vector2(860, 10)
	counter_top.color = Color(0.55, 0.42, 0.3, 1)
	env.add_child(counter_top)

	# Counter front edge (thin highlight)
	var counter_edge := ColorRect.new()
	counter_edge.position = Vector2(-430, 88)
	counter_edge.size = Vector2(860, 4)
	counter_edge.color = Color(0.5, 0.38, 0.25, 1)
	env.add_child(counter_edge)

	# Sushi prep mats on counter surface
	var mat_xs := [-200.0, -20.0, 160.0]
	for mx in mat_xs:
		var mat := ColorRect.new()
		mat.position = Vector2(mx, 35)
		mat.size = Vector2(100, 18)
		mat.color = Color(0.3, 0.45, 0.25, 0.6)
		env.add_child(mat)

	# Customer stools with legs (6 along counter front)
	var stool_xs := [-350.0, -210.0, -70.0, 70.0, 210.0, 350.0]
	for sx in stool_xs:
		# Stool seat
		var stool := ColorRect.new()
		stool.position = Vector2(sx - 12, 95)
		stool.size = Vector2(24, 10)
		stool.color = Color(0.5, 0.35, 0.2, 1)
		env.add_child(stool)
		# Stool leg
		var leg := ColorRect.new()
		leg.position = Vector2(sx - 3, 105)
		leg.size = Vector2(6, 14)
		leg.color = Color(0.4, 0.28, 0.18, 1)
		env.add_child(leg)

	# Bottle shelves (2 sections behind counter on wall)
	var shelf_positions := [-300.0, 100.0]
	for shelf_x in shelf_positions:
		_build_bottle_shelf(env, shelf_x)

	# Hanging lanterns (4 across ceiling)
	var lantern_xs := [-400.0, -120.0, 160.0, 420.0]
	for lx in lantern_xs:
		_build_lantern(env, lx)

	# Noren curtain above kitchen doorway (indigo panels)
	var noren_y := -280.0
	var noren_x := -580.0
	for i in range(3):
		var panel := ColorRect.new()
		panel.position = Vector2(noren_x + i * 22, noren_y)
		panel.size = Vector2(18, 50)
		panel.color = Color(0.15, 0.12, 0.35, 0.9)
		env.add_child(panel)

	# Kitchen doorway (far left)
	var door_frame := ColorRect.new()
	door_frame.position = Vector2(-580, -200)
	door_frame.size = Vector2(70, 260)
	door_frame.color = Color(0.15, 0.1, 0.08, 1)
	env.add_child(door_frame)
	var door_inner := ColorRect.new()
	door_inner.position = Vector2(-574, -194)
	door_inner.size = Vector2(58, 248)
	door_inner.color = Color(0.1, 0.07, 0.05, 1)
	env.add_child(door_inner)

	# Fish tank (right wall area)
	var tank_outer := ColorRect.new()
	tank_outer.position = Vector2(430, -150)
	tank_outer.size = Vector2(100, 70)
	tank_outer.color = Color(0.3, 0.5, 0.6, 0.8)
	env.add_child(tank_outer)
	var tank_inner := ColorRect.new()
	tank_inner.position = Vector2(436, -144)
	tank_inner.size = Vector2(88, 58)
	tank_inner.color = Color(0.25, 0.45, 0.6, 0.5)
	env.add_child(tank_inner)
	# Fish accent
	var fish_accent := ColorRect.new()
	fish_accent.position = Vector2(460, -125)
	fish_accent.size = Vector2(16, 8)
	fish_accent.color = Color(0.9, 0.5, 0.2, 0.7)
	env.add_child(fish_accent)

	# Fish posters on wall (izakaya style)
	var poster_data := [
		Vector2(-100, -260),
		Vector2(60, -260),
	]
	for ppos in poster_data:
		# Wood frame
		var frame := ColorRect.new()
		frame.position = ppos
		frame.size = Vector2(80, 60)
		frame.color = Color(0.45, 0.32, 0.2, 1)
		env.add_child(frame)
		# Cream inner
		var inner := ColorRect.new()
		inner.position = ppos + Vector2(4, 4)
		inner.size = Vector2(72, 52)
		inner.color = Color(0.9, 0.85, 0.7, 1)
		env.add_child(inner)
		# Fish silhouette
		var fish_sil := ColorRect.new()
		fish_sil.position = ppos + Vector2(20, 18)
		fish_sil.size = Vector2(40, 14)
		fish_sil.color = Color(0.3, 0.4, 0.5, 0.5)
		env.add_child(fish_sil)

	# Wooden beam trim at ceiling
	var beam := ColorRect.new()
	beam.position = Vector2(-600, -355)
	beam.size = Vector2(1200, 12)
	beam.color = Color(0.35, 0.25, 0.18, 1)
	env.add_child(beam)

	# Floor planks — alternating shades
	var plank_y := 80.0
	var plank_dark := true
	while plank_y < 340:
		var plank := ColorRect.new()
		plank.position = Vector2(-600, plank_y)
		plank.size = Vector2(1200, 26)
		plank.color = Color(0.24, 0.18, 0.13) if plank_dark else Color(0.2, 0.14, 0.1)
		plank.z_index = -6
		env.add_child(plank)
		plank_y += 26
		plank_dark = not plank_dark

func _build_bottle_shelf(parent: Node2D, shelf_x: float) -> void:
	# Shelf background
	var shelf_bg := ColorRect.new()
	shelf_bg.position = Vector2(shelf_x, -100)
	shelf_bg.size = Vector2(200, 120)
	shelf_bg.color = Color(0.3, 0.22, 0.16, 0.6)
	parent.add_child(shelf_bg)

	# Shelf lines (3 shelves)
	for i in range(3):
		var shelf_line := ColorRect.new()
		shelf_line.position = Vector2(shelf_x, -100 + i * 40 + 35)
		shelf_line.size = Vector2(200, 3)
		shelf_line.color = Color(0.45, 0.35, 0.25, 1)
		parent.add_child(shelf_line)

	# Bottles on each shelf
	var bottle_colors := [
		Color(0.7, 0.2, 0.15), Color(0.2, 0.5, 0.3), Color(0.6, 0.4, 0.1),
		Color(0.8, 0.6, 0.2), Color(0.5, 0.2, 0.4), Color(0.3, 0.3, 0.6),
		Color(0.7, 0.5, 0.3), Color(0.4, 0.6, 0.5), Color(0.6, 0.3, 0.2),
		Color(0.8, 0.7, 0.3), Color(0.5, 0.4, 0.6), Color(0.3, 0.5, 0.4),
	]
	var bottle_idx := 0
	for row in range(3):
		var row_y := -100 + row * 40 + 8
		var bx := shelf_x + 10
		while bx < shelf_x + 190 and bottle_idx < bottle_colors.size():
			var bottle := ColorRect.new()
			bottle.position = Vector2(bx, row_y)
			bottle.size = Vector2(8, 24)
			bottle.color = bottle_colors[bottle_idx]
			parent.add_child(bottle)
			bx += 16
			bottle_idx += 1

func _build_lantern(parent: Node2D, lx: float) -> void:
	# Cord
	var cord := ColorRect.new()
	cord.position = Vector2(lx + 8, -350)
	cord.size = Vector2(2, 40)
	cord.color = Color(0.3, 0.3, 0.3, 1)
	parent.add_child(cord)
	# Lantern body (circular approximation with square)
	var lantern := ColorRect.new()
	lantern.position = Vector2(lx, -310)
	lantern.size = Vector2(18, 22)
	lantern.color = Color(0.9, 0.6, 0.2, 0.85)
	parent.add_child(lantern)
	# Glow (larger, fainter)
	var glow := ColorRect.new()
	glow.position = Vector2(lx - 8, -318)
	glow.size = Vector2(34, 38)
	glow.color = Color(1.0, 0.8, 0.3, 0.15)
	parent.add_child(glow)

# =============================================================================
# STATION VISUALS
# =============================================================================

func _build_station_visual(area: Area2D, station_type: String) -> void:
	# Remove the placeholder Sprite2D if it has no texture
	var spr: Sprite2D = area.get_node_or_null("Sprite2D")
	if spr and spr.texture == null:
		spr.queue_free()

	var visual := Node2D.new()
	visual.name = "StationVisual"
	visual.z_index = -1
	area.add_child(visual)

	match station_type:
		"storage":
			_build_storage_visual(visual)
		"menu":
			_build_menu_visual(visual)
		"staff":
			_build_staff_visual(visual)
		"upgrade":
			_build_upgrade_visual(visual)
		"exit":
			_build_exit_visual(visual)
		"dinner":
			_build_dinner_visual(visual)
		"encyclopedia":
			_build_encyclopedia_visual(visual)

	# Update label style
	var label: Label = area.get_node_or_null("Label")
	if label:
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
		label.position = Vector2(-50, -90)
		label.size = Vector2(100, 25)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_storage_visual(parent: Node2D) -> void:
	# Tall blue cabinet
	var body := ColorRect.new()
	body.position = Vector2(-30, -55)
	body.size = Vector2(60, 90)
	body.color = Color(0.25, 0.4, 0.6)
	parent.add_child(body)
	# Door panel
	var door := ColorRect.new()
	door.position = Vector2(-22, -48)
	door.size = Vector2(44, 70)
	door.color = Color(0.35, 0.5, 0.7)
	parent.add_child(door)
	# Handle
	var handle := ColorRect.new()
	handle.position = Vector2(14, -18)
	handle.size = Vector2(4, 12)
	handle.color = Color(0.7, 0.65, 0.55)
	parent.add_child(handle)

func _build_menu_visual(parent: Node2D) -> void:
	# Wooden board frame
	var frame := ColorRect.new()
	frame.position = Vector2(-35, -50)
	frame.size = Vector2(70, 80)
	frame.color = Color(0.5, 0.38, 0.25)
	parent.add_child(frame)
	# Cream inner ("chalkboard")
	var inner := ColorRect.new()
	inner.position = Vector2(-28, -44)
	inner.size = Vector2(56, 66)
	inner.color = Color(0.85, 0.82, 0.7)
	parent.add_child(inner)
	# Chalk lines
	for i in range(4):
		var line := ColorRect.new()
		line.position = Vector2(-22, -36 + i * 14)
		line.size = Vector2(44, 2)
		line.color = Color(0.5, 0.5, 0.5, 0.4)
		parent.add_child(line)

func _build_staff_visual(parent: Node2D) -> void:
	# Cork board
	var board := ColorRect.new()
	board.position = Vector2(-35, -50)
	board.size = Vector2(70, 80)
	board.color = Color(0.6, 0.48, 0.3)
	parent.add_child(board)
	# Pinned note rectangles
	var note_data := [
		[Vector2(-24, -40), Vector2(20, 16), Color(0.9, 0.85, 0.5)],
		[Vector2(6, -38), Vector2(22, 14), Color(0.5, 0.8, 0.6)],
		[Vector2(-20, -16), Vector2(18, 18), Color(0.8, 0.5, 0.5)],
		[Vector2(8, -12), Vector2(20, 16), Color(0.6, 0.7, 0.9)],
		[Vector2(-10, 8), Vector2(24, 14), Color(0.9, 0.7, 0.4)],
	]
	for nd in note_data:
		var note := ColorRect.new()
		note.position = nd[0]
		note.size = nd[1]
		note.color = nd[2]
		parent.add_child(note)

func _build_upgrade_visual(parent: Node2D) -> void:
	# Desk pedestal
	var desk := ColorRect.new()
	desk.position = Vector2(-35, 0)
	desk.size = Vector2(70, 35)
	desk.color = Color(0.4, 0.32, 0.22)
	parent.add_child(desk)
	# Terminal/phone body
	var terminal := ColorRect.new()
	terminal.position = Vector2(-20, -50)
	terminal.size = Vector2(40, 55)
	terminal.color = Color(0.35, 0.55, 0.3)
	parent.add_child(terminal)
	# Screen
	var screen := ColorRect.new()
	screen.position = Vector2(-14, -44)
	screen.size = Vector2(28, 30)
	screen.color = Color(0.5, 0.75, 0.45)
	parent.add_child(screen)

func _build_exit_visual(parent: Node2D) -> void:
	# Door frame
	var frame := ColorRect.new()
	frame.position = Vector2(-28, -65)
	frame.size = Vector2(56, 100)
	frame.color = Color(0.55, 0.35, 0.25)
	parent.add_child(frame)
	# Door panel
	var door := ColorRect.new()
	door.position = Vector2(-22, -58)
	door.size = Vector2(44, 86)
	door.color = Color(0.65, 0.42, 0.3)
	parent.add_child(door)
	# Handle
	var handle := ColorRect.new()
	handle.position = Vector2(14, -20)
	handle.size = Vector2(4, 10)
	handle.color = Color(0.8, 0.7, 0.5)
	parent.add_child(handle)

func _build_dinner_visual(parent: Node2D) -> void:
	# Serving counter
	var counter := ColorRect.new()
	counter.position = Vector2(-35, -10)
	counter.size = Vector2(70, 45)
	counter.color = Color(0.7, 0.55, 0.25)
	parent.add_child(counter)
	# Counter top surface
	var surface := ColorRect.new()
	surface.position = Vector2(-38, -15)
	surface.size = Vector2(76, 8)
	surface.color = Color(0.85, 0.7, 0.35)
	parent.add_child(surface)
	# Bell shape (base + dome)
	var bell_base := ColorRect.new()
	bell_base.position = Vector2(-8, -28)
	bell_base.size = Vector2(16, 4)
	bell_base.color = Color(0.9, 0.8, 0.3)
	parent.add_child(bell_base)
	var bell_dome := ColorRect.new()
	bell_dome.position = Vector2(-5, -38)
	bell_dome.size = Vector2(10, 12)
	bell_dome.color = Color(0.95, 0.85, 0.4)
	parent.add_child(bell_dome)

func _build_encyclopedia_visual(parent: Node2D) -> void:
	# Bookshelf frame
	var shelf := ColorRect.new()
	shelf.position = Vector2(-35, -55)
	shelf.size = Vector2(70, 90)
	shelf.color = Color(0.42, 0.32, 0.22)
	parent.add_child(shelf)
	# Book spines (rows of colored rectangles)
	var book_colors := [
		Color(0.7, 0.25, 0.2), Color(0.2, 0.5, 0.6), Color(0.6, 0.5, 0.2),
		Color(0.4, 0.3, 0.6), Color(0.3, 0.6, 0.35), Color(0.7, 0.4, 0.3),
		Color(0.5, 0.5, 0.7), Color(0.6, 0.6, 0.3), Color(0.4, 0.55, 0.5),
	]
	var bi := 0
	for row in range(3):
		var by := -50 + row * 30
		var bx := -30
		while bx < 30 and bi < book_colors.size():
			var book := ColorRect.new()
			book.position = Vector2(bx, by)
			book.size = Vector2(8, 24)
			book.color = book_colors[bi]
			parent.add_child(book)
			bx += 12
			bi += 1

# =============================================================================
# FLOATING INTERACTION INDICATORS
# =============================================================================

func _show_floating_indicator(station: Area2D, action_text: String) -> void:
	_hide_floating_indicator()

	var indicator := Node2D.new()
	indicator.name = "FloatingIndicator"
	indicator.position = station.position + Vector2(0, -75)
	indicator.z_index = 10

	# Background panel
	var bg := ColorRect.new()
	bg.position = Vector2(-80, -14)
	bg.size = Vector2(160, 28)
	bg.color = Color(0, 0, 0, 0.6)
	indicator.add_child(bg)

	# Text label
	var lbl := Label.new()
	lbl.text = "[E] / (A)  " + action_text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-78, -12)
	lbl.size = Vector2(156, 24)
	indicator.add_child(lbl)

	add_child(indicator)
	_active_indicator = indicator

	# Small bounce tween
	if _indicator_tween and _indicator_tween.is_valid():
		_indicator_tween.kill()
	_indicator_tween = create_tween().set_loops()
	var base_y := indicator.position.y
	_indicator_tween.tween_property(indicator, "position:y", base_y - 3, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_indicator_tween.tween_property(indicator, "position:y", base_y + 3, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _hide_floating_indicator() -> void:
	if _active_indicator and is_instance_valid(_active_indicator):
		_active_indicator.queue_free()
		_active_indicator = null
	if _indicator_tween and _indicator_tween.is_valid():
		_indicator_tween.kill()
		_indicator_tween = null

# =============================================================================
# UI OPENERS
# =============================================================================

func _open_storage() -> void:
	_set_ui_open(true)
	var ui = preload("res://scripts/ui/FishStorageUI.gd").new()
	ui.closed.connect(func(): _set_ui_open(false))
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	canvas.add_child(ui)
	add_child(canvas)

func _open_menu_board() -> void:
	_set_ui_open(true)
	var ui = preload("res://scripts/ui/MenuBoardUI.gd").new()
	ui.closed.connect(func(): _set_ui_open(false))
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	canvas.add_child(ui)
	add_child(canvas)

func _open_staff_board() -> void:
	_set_ui_open(true)
	var ui = preload("res://scripts/ui/StaffBoardUI.gd").new()
	ui.closed.connect(func(): _set_ui_open(false))
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	canvas.add_child(ui)
	add_child(canvas)

func _open_upgrade() -> void:
	_set_ui_open(true)
	var ui = preload("res://scripts/ui/UpgradeUI.gd").new()
	ui.closed.connect(func(): _set_ui_open(false))
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	canvas.add_child(ui)
	add_child(canvas)

func _open_encyclopedia() -> void:
	_set_ui_open(true)
	var ui = preload("res://scripts/ui/EncyclopediaUI.gd").new()
	ui.closed.connect(func(): _set_ui_open(false))
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	canvas.add_child(ui)
	add_child(canvas)

func _start_dinner() -> void:
	TimeManager.advance_to(TimeManager.TimeOfDay.EVENING)
	GameManager.transition_to("res://scenes/dinner_service/DinnerService.tscn")

# =============================================================================
# INTERACTION ZONE HANDLERS
# =============================================================================

func _on_storage_entered(body: Node2D) -> void:
	if body == player:
		near_storage = true
		_show_floating_indicator($StoragePC, "Fish Storage")

func _on_storage_exited(body: Node2D) -> void:
	if body == player:
		near_storage = false
		_hide_prompt_if_clear()

func _on_menu_entered(body: Node2D) -> void:
	if body == player:
		near_menu = true
		_show_floating_indicator($MenuBoard, "Menu Board")

func _on_menu_exited(body: Node2D) -> void:
	if body == player:
		near_menu = false
		_hide_prompt_if_clear()

func _on_staff_entered(body: Node2D) -> void:
	if body == player:
		near_staff = true
		_show_floating_indicator($StaffBoard, "Staff Board")

func _on_staff_exited(body: Node2D) -> void:
	if body == player:
		near_staff = false
		_hide_prompt_if_clear()

func _on_upgrade_entered(body: Node2D) -> void:
	if body == player:
		near_upgrade = true
		_show_floating_indicator($UpgradeStation, "Upgrades")

func _on_upgrade_exited(body: Node2D) -> void:
	if body == player:
		near_upgrade = false
		_hide_prompt_if_clear()

func _on_door_entered(body: Node2D) -> void:
	if body == player:
		near_door = true
		_show_floating_indicator($DoorExit, "Set Sail")

func _on_door_exited(body: Node2D) -> void:
	if body == player:
		near_door = false
		_hide_prompt_if_clear()

func _on_dinner_entered(body: Node2D) -> void:
	if body == player:
		near_dinner = true
		_show_floating_indicator($DinnerPrompt, "Start Dinner")

func _on_dinner_exited(body: Node2D) -> void:
	if body == player:
		near_dinner = false
		_hide_prompt_if_clear()

func _on_encyclopedia_entered(body: Node2D) -> void:
	if body == player:
		near_encyclopedia = true
		_show_floating_indicator($EncyclopediaBoard, "Encyclopedia")

func _on_encyclopedia_exited(body: Node2D) -> void:
	if body == player:
		near_encyclopedia = false
		_hide_prompt_if_clear()

func _hide_prompt_if_clear() -> void:
	if not near_storage and not near_menu and not near_staff and not near_upgrade and not near_door and not near_dinner and not near_encyclopedia:
		_hide_floating_indicator()
		interact_prompt.visible = false

# =============================================================================
# SETUP HELPERS
# =============================================================================

func _setup_area_shape(area: Area2D, size: Vector2) -> void:
	var col: CollisionShape2D = area.get_node("CollisionShape2D")
	if col.shape == null:
		var rect := RectangleShape2D.new()
		rect.size = size
		col.shape = rect

func _create_boundaries() -> void:
	var bounds := $Boundaries
	for child in bounds.get_children():
		if child is CollisionShape2D and child.shape == null:
			child.queue_free()
	var walls := [
		[Vector2(-570, 220), Vector2(20, 200)],     # Left
		[Vector2(570, 220), Vector2(20, 200)],      # Right
		[Vector2(0, 150), Vector2(1200, 20)],       # Top
		[Vector2(0, 290), Vector2(1200, 20)],       # Bottom
	]
	for wall_data in walls:
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = wall_data[1]
		col.shape = rect
		col.position = wall_data[0]
		bounds.add_child(col)

func _update_gold_display() -> void:
	$HUD/GoldLabel.text = "Gold: %dg" % Inventory.gold
