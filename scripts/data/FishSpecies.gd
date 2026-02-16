class_name FishSpecies
extends Resource

enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

@export var id: String = ""
@export var display_name: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var base_value: int = 10
@export var sushi_grade: bool = false
@export var weight_range: Vector2 = Vector2(0.5, 2.0)  # min, max kg
@export var swim_speed: float = 60.0
@export var awareness_radius: float = 100.0
@export var flee_speed: float = 120.0
@export var sprite: Texture2D = null
@export var description: String = ""
@export var biomes: PackedStringArray = ["shallow"]

func get_random_weight() -> float:
	return randf_range(weight_range.x, weight_range.y)

func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color(0.8, 0.8, 0.8)
		Rarity.UNCOMMON:
			return Color(0.3, 0.85, 0.4)
		Rarity.RARE:
			return Color(0.3, 0.5, 1.0)
		Rarity.LEGENDARY:
			return Color(1.0, 0.85, 0.0)
	return Color.WHITE

func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON:
			return "Common"
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
		Rarity.LEGENDARY:
			return "Legendary"
	return "Unknown"
