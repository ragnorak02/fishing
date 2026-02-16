class_name FishDatabase
extends Node

static var _species: Dictionary = {}
static var _loaded: bool = false

const RARITY_WEIGHTS := {
	FishSpecies.Rarity.COMMON: 50.0,
	FishSpecies.Rarity.UNCOMMON: 30.0,
	FishSpecies.Rarity.RARE: 15.0,
	FishSpecies.Rarity.LEGENDARY: 5.0,
}

static func _ensure_loaded() -> void:
	if _loaded:
		return
	var dir := DirAccess.open("res://scripts/data/fish/")
	if dir == null:
		push_error("FishDatabase: Cannot open fish data directory")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var species: FishSpecies = load("res://scripts/data/fish/" + file_name)
			if species:
				_species[species.id] = species
		file_name = dir.get_next()
	dir.list_dir_end()
	_loaded = true

static func get_species(id: String) -> FishSpecies:
	_ensure_loaded()
	return _species.get(id)

static func get_all_species() -> Array:
	_ensure_loaded()
	return _species.values()

static func get_random_species_for_biome(biome: String) -> FishSpecies:
	_ensure_loaded()
	# Filter species by biome
	var candidates: Array[FishSpecies] = []
	var weights: Array[float] = []
	for species: FishSpecies in _species.values():
		if biome in species.biomes:
			candidates.append(species)
			weights.append(RARITY_WEIGHTS[species.rarity])

	if candidates.is_empty():
		# Fallback: return any species
		var all := _species.values()
		if all.is_empty():
			return null
		return all[randi() % all.size()]

	# Weighted random selection
	var total_weight := 0.0
	for w in weights:
		total_weight += w
	var roll := randf() * total_weight
	var cumulative := 0.0
	for i in candidates.size():
		cumulative += weights[i]
		if roll <= cumulative:
			return candidates[i]

	return candidates[-1]
