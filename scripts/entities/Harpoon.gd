extends Area2D

const BASE_SPEED := 400.0
const BASE_MAX_RANGE := 250.0

var direction: Vector2 = Vector2.RIGHT
var speed: float = BASE_SPEED
var max_range: float = BASE_MAX_RANGE
var traveled: float = 0.0
var active: bool = true

signal fish_hit(fish: Node2D)
signal missed

func _ready() -> void:
	max_range = BASE_MAX_RANGE * GameManager.get_harpoon_range_multiplier()

	# Set up collision
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 4)
	col.shape = rect
	add_child(col)

	collision_layer = 8  # Harpoon layer
	collision_mask = 4   # Fish layer

	# Visual
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/sprites/ui/harpoon.svg")
	add_child(sprite)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if not active:
		return

	var move := direction * speed * delta
	position += move
	traveled += move.length()

	if traveled >= max_range:
		active = false
		missed.emit()
		_fade_and_remove()

func _on_body_entered(body: Node2D) -> void:
	if not active:
		return
	if body.is_in_group("fish"):
		active = false
		fish_hit.emit(body)
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if not active:
		return
	# Check if the area's parent is a fish
	var parent = area.get_parent()
	if parent and parent.is_in_group("fish"):
		active = false
		fish_hit.emit(parent)
		queue_free()

func _fade_and_remove() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
