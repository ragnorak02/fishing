extends Area2D

@export var biome: String = "shallow"
@export var spot_name: String = "Dive Spot"

func _ready() -> void:
	add_to_group("dive_spots")
	set_meta("biome", biome)

	# Set up collision shape
	var col: CollisionShape2D = $CollisionShape2D
	if col.shape == null:
		var circle := CircleShape2D.new()
		circle.radius = 40.0
		col.shape = circle

	# Animated glow effect
	_create_glow()

func _create_glow() -> void:
	# Dive spot sprite
	var spot_sprite := Sprite2D.new()
	spot_sprite.texture = preload("res://assets/sprites/environment/ocean/dive_spot.svg")
	spot_sprite.scale = Vector2(2.0, 2.0)
	add_child(spot_sprite)

	# Particle glow effect
	var particles := CPUParticles2D.new()
	particles.amount = 8
	particles.lifetime = 2.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 20.0
	particles.direction = Vector2(0, -1)
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 5.0
	particles.initial_velocity_max = 15.0
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.8
	particles.color = Color(0, 0.9, 0.9, 0.4)
	add_child(particles)

	# Label
	var label := Label.new()
	label.text = spot_name
	label.position = Vector2(-30, -40)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.8, 1.0, 1.0))
	add_child(label)

func _process(_delta: float) -> void:
	# Pulse effect
	var alpha := 0.2 + sin(Time.get_ticks_msec() * 0.003) * 0.15
	modulate.a = alpha + 0.5
