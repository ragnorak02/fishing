extends CharacterBody2D

enum BossState { PATROL, ALERT, CHARGING, STUNNED, FLEEING }

var species: FishSpecies = null
var current_state: BossState = BossState.PATROL
var state_timer: float = 0.0
var health: int = 5
var max_health: int = 5
var patrol_direction: Vector2 = Vector2.RIGHT
var charge_target: Vector2 = Vector2.ZERO
var stun_duration: float = 2.0

var sprite: Sprite2D = null
var hitbox: Area2D = null
var bounds: Rect2 = Rect2(-800, -600, 1600, 1200)
var health_bar: Node2D = null

signal boss_defeated(species_id: String)
signal boss_hit(hits_remaining: int)

func _ready() -> void:
	add_to_group("fish")
	add_to_group("boss_fish")

	sprite = get_node_or_null("Sprite2D") as Sprite2D
	hitbox = get_node_or_null("Hitbox") as Area2D

	# Collision setup
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col and col.shape == null:
		var circle := CircleShape2D.new()
		circle.radius = 25.0
		col.shape = circle
	collision_layer = 4
	collision_mask = 0

	if hitbox:
		var hitbox_col: CollisionShape2D = hitbox.get_node_or_null("CollisionShape2D")
		if hitbox_col and hitbox_col.shape == null:
			var circle := CircleShape2D.new()
			circle.radius = 30.0
			hitbox_col.shape = circle
		hitbox.collision_layer = 4
		hitbox.collision_mask = 8

	if has_meta("species") and has_meta("spawn_bounds"):
		setup(get_meta("species"), get_meta("spawn_bounds"))

	_create_health_bar()
	_enter_state(BossState.PATROL)

func setup(fish_species: FishSpecies, spawn_bounds: Rect2) -> void:
	species = fish_species
	bounds = spawn_bounds
	_load_species_sprite()

func _load_species_sprite() -> void:
	if species == null or sprite == null:
		return
	var tex_path := "res://assets/sprites/fish/%s.svg" % species.id
	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)
	# Boss fish are large
	sprite.scale = Vector2(3.0, 3.0)
	sprite.modulate = Color(1.0, 0.3, 0.2).lerp(Color.WHITE, 0.3)

func _create_health_bar() -> void:
	health_bar = Node2D.new()
	health_bar.position = Vector2(0, -40)
	add_child(health_bar)
	_update_health_bar()

func _update_health_bar() -> void:
	if health_bar == null:
		return
	# Clear old children
	for child in health_bar.get_children():
		child.queue_free()

	var bar_width := 50.0
	var bar_height := 6.0

	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.2, 0.2, 0.8)
	bg.size = Vector2(bar_width, bar_height)
	bg.position = Vector2(-bar_width / 2.0, 0)
	health_bar.add_child(bg)

	# Health fill
	var fill := ColorRect.new()
	var ratio := float(health) / float(max_health)
	fill.color = Color(1.0, 0.2, 0.2) if ratio < 0.3 else Color(1.0, 0.6, 0.0) if ratio < 0.6 else Color(0.2, 1.0, 0.3)
	fill.size = Vector2(bar_width * ratio, bar_height)
	fill.position = Vector2(-bar_width / 2.0, 0)
	health_bar.add_child(fill)

func _physics_process(delta: float) -> void:
	state_timer -= delta

	match current_state:
		BossState.PATROL:
			_process_patrol(delta)
		BossState.ALERT:
			_process_alert(delta)
		BossState.CHARGING:
			_process_charging(delta)
		BossState.STUNNED:
			_process_stunned(delta)
		BossState.FLEEING:
			_process_fleeing(delta)

	_enforce_bounds()
	move_and_slide()

func _enter_state(new_state: BossState) -> void:
	current_state = new_state
	match new_state:
		BossState.PATROL:
			state_timer = randf_range(3.0, 6.0)
			patrol_direction = Vector2.RIGHT.rotated(randf() * TAU)
		BossState.ALERT:
			state_timer = 1.0
			velocity = Vector2.ZERO
		BossState.CHARGING:
			state_timer = 1.5
		BossState.STUNNED:
			state_timer = stun_duration
			velocity = Vector2.ZERO
			if sprite:
				sprite.modulate = Color(1.0, 1.0, 1.0, 0.5)
		BossState.FLEEING:
			state_timer = 3.0

func _process_patrol(delta: float) -> void:
	var speed := 60.0
	velocity = patrol_direction * speed

	# Gentle wobble
	patrol_direction = patrol_direction.rotated(randf_range(-0.3, 0.3) * delta)

	if sprite:
		sprite.flip_h = velocity.x < 0

	# Check for diver
	var divers := get_tree().get_nodes_in_group("diver")
	if not divers.is_empty():
		var diver: Node2D = divers[0]
		var dist := global_position.distance_to(diver.global_position)
		if dist < 300.0:
			charge_target = diver.global_position
			_enter_state(BossState.ALERT)
			return

	if state_timer <= 0:
		patrol_direction = Vector2.RIGHT.rotated(randf() * TAU)
		state_timer = randf_range(3.0, 6.0)

func _process_alert(delta: float) -> void:
	# Face the diver, telegraph the charge
	var divers := get_tree().get_nodes_in_group("diver")
	if not divers.is_empty():
		charge_target = divers[0].global_position

	if sprite:
		sprite.flip_h = (charge_target - global_position).x < 0
		# Red flash telegraph
		var flash := sin(Time.get_ticks_msec() * 0.02) * 0.5 + 0.5
		sprite.modulate = Color(1.0, flash, flash)

	if state_timer <= 0:
		_enter_state(BossState.CHARGING)

func _process_charging(_delta: float) -> void:
	var charge_dir := (charge_target - global_position).normalized()
	var charge_speed := 250.0
	velocity = charge_dir * charge_speed

	if sprite:
		sprite.flip_h = velocity.x < 0
		sprite.modulate = Color(1.0, 0.2, 0.2)

	if state_timer <= 0 or global_position.distance_to(charge_target) < 20.0:
		_enter_state(BossState.PATROL)
		if sprite:
			sprite.modulate = Color(1.0, 0.3, 0.2).lerp(Color.WHITE, 0.3)

func _process_stunned(_delta: float) -> void:
	# Wobble in place
	velocity = Vector2(sin(Time.get_ticks_msec() * 0.01) * 10.0, cos(Time.get_ticks_msec() * 0.008) * 5.0)

	if state_timer <= 0:
		if sprite:
			sprite.modulate = Color(1.0, 0.3, 0.2).lerp(Color.WHITE, 0.3)
		if health <= 0:
			_enter_state(BossState.FLEEING)
		else:
			_enter_state(BossState.PATROL)

func _process_fleeing(_delta: float) -> void:
	var divers := get_tree().get_nodes_in_group("diver")
	if not divers.is_empty():
		var flee_dir := (global_position - divers[0].global_position).normalized()
		velocity = flee_dir * 180.0
	if sprite:
		sprite.flip_h = velocity.x < 0
	if state_timer <= 0:
		# Boss is defeated
		boss_defeated.emit(species.id if species else "leviathan_king")
		queue_free()

func take_hit() -> void:
	if current_state == BossState.STUNNED:
		return
	health -= 1
	boss_hit.emit(health)
	_update_health_bar()

	# Flash white
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
		tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.2).lerp(Color.WHITE, 0.3), 0.15)

	_enter_state(BossState.STUNNED)

func _enforce_bounds() -> void:
	if not bounds.has_point(global_position):
		var center := bounds.get_center()
		patrol_direction = (center - global_position).normalized()
		if current_state == BossState.CHARGING:
			_enter_state(BossState.PATROL)
		global_position = global_position.clamp(bounds.position, bounds.position + bounds.size)
