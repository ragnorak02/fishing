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
	var glow := ColorRect.new()
	glow.size = Vector2(50, 50)
	glow.position = Vector2(-25, -25)
	glow.color = Color(0, 0.9, 0.9, 0.3)
	add_child(glow)

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
