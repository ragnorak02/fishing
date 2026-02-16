class_name EconomySystem
extends RefCounted

# Sushi grade bonus multiplier
const SUSHI_BONUS := 1.5

static func calculate_fish_value(species: FishSpecies, weight: float) -> int:
	var base := species.base_value
	var weight_factor := weight / species.weight_range.y
	var value := int(base * weight_factor)
	if species.sushi_grade:
		value = int(value * SUSHI_BONUS)
	return max(value, 1)
