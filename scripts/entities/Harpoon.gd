extends Area2D

const BASE_SPEED := 400.0
const BASE_MAX_RANGE := 250.0
const RETURN_SPEED := 500.0
const RETURN_ARRIVE_DIST := 15.0

enum State { TRAVELING, RETURNING }

var direction: Vector2 = Vector2.RIGHT
var speed: float = BASE_SPEED
var max_range: float = BASE_MAX_RANGE
var traveled: float = 0.0
var active: bool = true
var state: State = State.TRAVELING
var diver_ref: Node2D = null

signal fish_hit(fish: Node2D)
signal missed
signal returned

func _ready() -> void:
	z_index = 10
	max_range = BASE_MAX_RANGE * GameManager.get_harpoon_range_multiplier()

	# Collision — reuse scene child or create dynamically
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null:
		col = CollisionShape2D.new()
		col.name = "CollisionShape2D"
		add_child(col)
	if col.shape == null:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(20, 4)
		col.shape = rect

	collision_layer = 8
	collision_mask = 4

	# Visual — reuse scene child or create dynamically
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture = preload("res://assets/sprites/ui/harpoon.svg")
		sprite.scale = Vector2(0.5, 0.5)
		add_child(sprite)

	# Bubble trail — reuse scene child or create dynamically
	var trail := get_node_or_null("BubbleTrail") as CPUParticles2D
	if trail == null:
		trail = CPUParticles2D.new()
		trail.name = "BubbleTrail"
		trail.amount = 6
		trail.lifetime = 0.3
		trail.explosiveness = 0.0
		trail.direction = Vector2(-1, 0)
		trail.spread = 20.0
		trail.initial_velocity_min = 10.0
		trail.initial_velocity_max = 30.0
		trail.scale_amount_min = 0.5
		trail.scale_amount_max = 1.5
		trail.color = Color(0.6, 0.85, 1.0, 0.4)
		trail.gravity = Vector2.ZERO
		add_child(trail)
	trail.emitting = true

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	match state:
		State.TRAVELING:
			if not active:
				return
			var move := direction * speed * delta
			position += move
			traveled += move.length()
			if traveled >= max_range:
				active = false
				missed.emit()
				begin_return()

		State.RETURNING:
			if diver_ref and is_instance_valid(diver_ref):
				var to_diver := diver_ref.global_position - global_position
				var dist := to_diver.length()
				if dist <= RETURN_ARRIVE_DIST:
					returned.emit()
					queue_free()
					return
				var move_dir := to_diver.normalized()
				position += move_dir * RETURN_SPEED * delta
				rotation = move_dir.angle()
			else:
				# No valid diver ref (e.g. MountedHarpoon) — just free
				returned.emit()
				queue_free()

func begin_return() -> void:
	state = State.RETURNING
	active = false
	# Disable collision so it doesn't re-hit fish on the way back
	collision_layer = 0
	collision_mask = 0
	modulate.a = 0.6
	# Reverse bubble trail direction
	var trail := get_node_or_null("BubbleTrail") as CPUParticles2D
	if trail:
		trail.direction = Vector2(1, 0)

func _on_body_entered(body: Node2D) -> void:
	if not active:
		return
	if body.is_in_group("fish"):
		active = false
		fish_hit.emit(body)
		begin_return()

func _on_area_entered(area: Area2D) -> void:
	if not active:
		return
	# Check if the area's parent is a fish
	var parent = area.get_parent()
	if parent and parent.is_in_group("fish"):
		active = false
		fish_hit.emit(parent)
		begin_return()
