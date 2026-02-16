extends CanvasLayer

@onready var gold_label: Label = $TopBar/GoldLabel
@onready var location_label: Label = $TopBar/LocationLabel

func _ready() -> void:
	Inventory.gold_changed.connect(_on_gold_changed)
	_on_gold_changed(Inventory.gold)

func set_location(location_name: String) -> void:
	location_label.text = location_name

func _on_gold_changed(amount: int) -> void:
	gold_label.text = "%dg" % amount
