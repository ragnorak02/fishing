extends Node

const ACHIEVEMENTS_PATH := "res://achievements.json"

var achievements: Dictionary = {}  # id -> {name, description, points, icon, unlocked}
var _toast_queue: Array = []
var _toast_active: bool = false
var _toast_timer: Timer
var _toast_canvas: CanvasLayer
var _toast_panel: PanelContainer

signal achievement_unlocked(id: String)

func _ready() -> void:
	_load_manifest()
	_restore_state()
	_connect_signals()
	_create_toast_ui()

# --- Public API ---

func get_save_state() -> Dictionary:
	var state := {}
	for id in achievements:
		state[id] = achievements[id].unlocked
	return state

func notify_upgrade_purchased(type: int, new_level: int) -> void:
	_unlock("first_upgrade")
	if new_level >= UpgradeSystem.MAX_LEVEL:
		_unlock("max_upgrade_track")
	# Check all maxed
	var all_maxed := true
	for t in UpgradeSystem.UpgradeType.values():
		if UpgradeSystem.get_level(t) < UpgradeSystem.MAX_LEVEL:
			all_maxed = false
			break
	if all_maxed:
		_unlock("all_upgrades_max")

func notify_sonar_pulse() -> void:
	_unlock("sonar_pulse")

# --- Internal ---

func _load_manifest() -> void:
	if not FileAccess.file_exists(ACHIEVEMENTS_PATH):
		GameLog.warn("AchievementManager", "achievements.json not found")
		return
	var file := FileAccess.open(ACHIEVEMENTS_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var data = json.data
	if not data is Dictionary or not data.has("achievements"):
		return
	for entry in data["achievements"]:
		achievements[entry["id"]] = {
			"name": entry.get("name", ""),
			"description": entry.get("description", ""),
			"points": entry.get("points", 0),
			"icon": entry.get("icon", ""),
			"unlocked": false,
		}

func _restore_state() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm == null or not sm.has_method("get_saved_achievement_state"):
		return
	var saved: Dictionary = sm.get_saved_achievement_state()
	for id in saved:
		if id in achievements and saved[id] == true:
			achievements[id].unlocked = true

func _connect_signals() -> void:
	# Catch tracking (haul_changed fires when fish added to haul)
	if Inventory.has_signal("haul_changed"):
		Inventory.haul_changed.connect(_on_haul_changed)
	if Inventory.has_signal("fish_sold"):
		Inventory.fish_sold.connect(_on_fish_sold)
	# State tracking (dive, transform)
	if GameManager.has_signal("state_changed"):
		GameManager.state_changed.connect(_on_state_changed)
	if GameManager.has_signal("vehicle_mode_changed"):
		GameManager.vehicle_mode_changed.connect(_on_vehicle_mode_changed)

func _on_haul_changed() -> void:
	if Inventory.current_haul.is_empty():
		return
	var last_fish: Dictionary = Inventory.current_haul.back()
	# Record in SaveManager
	if last_fish.has("species_id"):
		SaveManager.record_catch(last_fish.species_id)

	# first_catch
	_unlock("first_catch")

	# Cumulative thresholds
	if SaveManager.total_catches >= 10:
		_unlock("catch_10")
	if SaveManager.total_catches >= 50:
		_unlock("catch_50")

	# Sushi grade
	if last_fish.get("sushi_grade", false):
		_unlock("sushi_grade")

	# Legendary
	if last_fish.get("rarity", 0) == FishSpecies.Rarity.LEGENDARY:
		_unlock("catch_legendary")

	# All species
	if SaveManager.species_caught.size() >= 10:
		_unlock("all_species")

func _on_fish_sold(gold_earned: int) -> void:
	SaveManager.record_gold_earned(gold_earned)
	_unlock("first_sale")
	if SaveManager.total_gold_earned >= 500:
		_unlock("earn_500_gold")
	if SaveManager.total_gold_earned >= 2000:
		_unlock("earn_2000_gold")

func _on_state_changed(new_state: int) -> void:
	# GameState.DIVING == 3
	if new_state == GameManager.GameState.DIVING:
		_unlock("first_dive")

func _on_vehicle_mode_changed(mode: int) -> void:
	# Any non-surface mode (0 = SURFACE)
	if mode != 0:
		_unlock("first_transform")

func _unlock(id: String) -> void:
	if id not in achievements:
		return
	if achievements[id].unlocked:
		return
	achievements[id].unlocked = true
	achievement_unlocked.emit(id)
	GameLog.achievements("Unlocked: %s" % id)
	_queue_toast(achievements[id].name, achievements[id].description)

# --- Toast UI ---

func _create_toast_ui() -> void:
	_toast_canvas = CanvasLayer.new()
	_toast_canvas.layer = 100
	add_child(_toast_canvas)

	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.anchor_top = 0.0
	_toast_panel.anchor_bottom = 0.0
	_toast_panel.offset_left = -160
	_toast_panel.offset_right = 160
	_toast_panel.offset_top = 20
	_toast_panel.offset_bottom = 80

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	style.border_color = Color(0.9, 0.7, 0.2)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_toast_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	_toast_panel.add_child(vbox)

	var title := Label.new()
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var desc := Label.new()
	desc.name = "Desc"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	desc.add_theme_font_size_override("font_size", 12)
	vbox.add_child(desc)

	_toast_canvas.add_child(_toast_panel)

	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.wait_time = 3.5
	_toast_timer.timeout.connect(_on_toast_timeout)
	add_child(_toast_timer)

func _queue_toast(title: String, description: String) -> void:
	_toast_queue.append({"title": title, "description": description})
	if not _toast_active:
		_show_next_toast()

func _show_next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_active = false
		return
	_toast_active = true
	var toast = _toast_queue.pop_front()
	var vbox = _toast_panel.get_node("VBox")
	vbox.get_node("Title").text = "Achievement Unlocked!"
	vbox.get_node("Desc").text = "%s — %s" % [toast.title, toast.description]

	_toast_panel.visible = true
	_toast_panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.3)
	_toast_timer.start()

func _on_toast_timeout() -> void:
	var tween := create_tween()
	tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		_toast_panel.visible = false
		_show_next_toast()
	)
