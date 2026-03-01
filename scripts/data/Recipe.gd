class_name Recipe
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var ingredients: Array[RecipeIngredient] = []
@export var sell_price: int = 15
@export var cook_time: float = 1.0  # Timing bar speed multiplier (higher = faster/harder)
