extends Control

@onready var fish_container: VBoxContainer = $Panel/MarginContainer/VBox/ScrollContainer/FishList
@onready var stats_label: Label = $Panel/MarginContainer/VBox/StatsBar/StatsLabel
@onready var gold_label: Label = $Panel/MarginContainer/VBox/StatsBar/GoldLabel
@onready var title_label: Label = $Panel/MarginContainer/VBox/TitleLabel
@onready var no_catch_label: Label = $Panel/MarginContainer/VBox/NoCatchLabel
@onready var button_bar: HBoxContainer = $Panel/MarginContainer/VBox/ButtonBar

var fish_cards: Array = []

func _ready() -> void:
	_update_gold_display()
	Inventory.gold_changed.connect(func(_g): _update_gold_display())

	# Dive stats
	var dive_time: float = GameManager.get_meta("last_dive_time") if GameManager.has_meta("last_dive_time") else 0.0
	var catch_count := Inventory.current_haul.size()
	var total_value := 0
	for fish in Inventory.current_haul:
		total_value += fish.value

	stats_label.text = "Time: %ds | Caught: %d | Value: %dg" % [int(dive_time), catch_count, total_value]

	if Inventory.current_haul.is_empty():
		no_catch_label.visible = true
		no_catch_label.text = "No catch this dive... Better luck next time!"
		$Panel/MarginContainer/VBox/ScrollContainer.visible = false
	else:
		no_catch_label.visible = false
		_populate_fish_cards()

	# Connect buttons
	$Panel/MarginContainer/VBox/ButtonBar/SellAllBtn.pressed.connect(_on_sell_all)
	$Panel/MarginContainer/VBox/ButtonBar/KeepAllBtn.pressed.connect(_on_keep_all)
	$Panel/MarginContainer/VBox/BottomButtons/ReturnSeaBtn.pressed.connect(_on_return_sea)
	$Panel/MarginContainer/VBox/BottomButtons/ReturnTownBtn.pressed.connect(_on_return_town)

func _populate_fish_cards() -> void:
	# Clear existing
	for child in fish_container.get_children():
		child.queue_free()
	fish_cards.clear()

	for i in Inventory.current_haul.size():
		var fish = Inventory.current_haul[i]
		var card := _create_fish_card(fish, i)
		fish_container.add_child(card)
		fish_cards.append(card)

func _create_fish_card(fish: Dictionary, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 60)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	# Rarity color indicator
	var rarity_bar := ColorRect.new()
	rarity_bar.custom_minimum_size = Vector2(6, 0)
	var species := FishDatabase.get_species(fish.species_id)
	rarity_bar.color = species.get_rarity_color() if species else Color.WHITE
	hbox.add_child(rarity_bar)

	# Fish info
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = "%s  [%s]" % [fish.name, species.get_rarity_name() if species else "?"]
	name_label.add_theme_font_size_override("font_size", 16)
	if species:
		name_label.add_theme_color_override("font_color", species.get_rarity_color())
	info_vbox.add_child(name_label)

	var detail_label := Label.new()
	var sushi_text := " | Sushi Grade" if fish.sushi_grade else ""
	detail_label.text = "%.1f kg | %dg%s" % [fish.weight, fish.value, sushi_text]
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_vbox.add_child(detail_label)

	hbox.add_child(info_vbox)

	# Sell button
	var sell_btn := Button.new()
	sell_btn.text = "Sell (%dg)" % fish.value
	sell_btn.custom_minimum_size = Vector2(100, 0)
	sell_btn.pressed.connect(_on_sell_fish.bind(index))
	hbox.add_child(sell_btn)

	# Keep button
	var keep_btn := Button.new()
	keep_btn.text = "Keep"
	keep_btn.custom_minimum_size = Vector2(70, 0)
	keep_btn.pressed.connect(_on_keep_fish.bind(index))
	hbox.add_child(keep_btn)

	return card

func _on_sell_fish(index: int) -> void:
	Inventory.sell_fish_from_haul(index)
	_populate_fish_cards()
	_check_empty()

func _on_keep_fish(index: int) -> void:
	Inventory.keep_fish_from_haul(index)
	_populate_fish_cards()
	_check_empty()

func _on_sell_all() -> void:
	Inventory.sell_all_haul()
	_populate_fish_cards()
	_check_empty()

func _on_keep_all() -> void:
	Inventory.keep_all_haul()
	_populate_fish_cards()
	_check_empty()

func _check_empty() -> void:
	if Inventory.current_haul.is_empty():
		no_catch_label.visible = true
		no_catch_label.text = "All fish sorted!"
		$Panel/MarginContainer/VBox/ScrollContainer.visible = false
		$Panel/MarginContainer/VBox/ButtonBar.visible = false

func _on_return_sea() -> void:
	# Clear remaining haul (discard unsorted fish)
	Inventory.clear_haul()
	GameManager.transition_to("res://scenes/ocean_surface/OceanSurface.tscn")

func _on_return_town() -> void:
	Inventory.clear_haul()
	GameManager.transition_to("res://scenes/hub_town/HubTown.tscn")

func _update_gold_display() -> void:
	gold_label.text = "%dg" % Inventory.gold
