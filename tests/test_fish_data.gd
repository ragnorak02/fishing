extends RefCounted

# Tests for FishDatabase loading and FishSpecies resource validation.

var _passed := 0
var _failed := 0
var _details := []

func _assert_true(name: String, condition: bool, message: String = "") -> void:
	if condition:
		_passed += 1
		_details.append({"name": name, "status": "pass", "message": ""})
	else:
		_failed += 1
		_details.append({"name": name, "status": "fail", "message": message})

func _assert_eq(name: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		_passed += 1
		_details.append({"name": name, "status": "pass", "message": ""})
	else:
		_failed += 1
		_details.append({"name": name, "status": "fail", "message": "Expected %s, got %s" % [str(expected), str(actual)]})

func run_tests() -> Dictionary:
	_test_tres_files_load()
	_test_species_validation()
	_test_rarity_distribution()
	_test_database_api()
	return {"passed": _passed, "failed": _failed, "details": _details}

# --- Individual .tres loading ---

const FISH_FILES := [
	"sardine", "mackerel", "sea_bream", "squid", "octopus",
	"yellowtail", "grouper", "bluefin_tuna", "manta_ray", "golden_koi",
]

func _test_tres_files_load() -> void:
	for fish_id in FISH_FILES:
		var path := "res://scripts/data/fish/%s.tres" % fish_id
		var res := load(path)
		_assert_true("FishSpecies.load_%s" % fish_id, res != null, "Failed to load %s" % path)
		_assert_true("FishSpecies.type_%s" % fish_id, res is FishSpecies, "%s is not FishSpecies" % fish_id)

# --- Property validation on each species ---

func _test_species_validation() -> void:
	for fish_id in FISH_FILES:
		var species: FishSpecies = load("res://scripts/data/fish/%s.tres" % fish_id)
		if species == null:
			continue
		var prefix := "FishSpecies.%s" % fish_id
		_assert_true("%s.id_nonempty" % prefix, species.id.length() > 0, "Empty id")
		_assert_true("%s.name_nonempty" % prefix, species.display_name.length() > 0, "Empty display_name")
		_assert_true("%s.base_value_positive" % prefix, species.base_value > 0, "base_value=%d" % species.base_value)
		_assert_true("%s.weight_range_valid" % prefix, species.weight_range.x < species.weight_range.y,
			"weight min=%s >= max=%s" % [str(species.weight_range.x), str(species.weight_range.y)])
		_assert_true("%s.has_biome" % prefix, species.biomes.size() > 0, "No biomes assigned")

# --- Rarity distribution: at least 1 of each ---

func _test_rarity_distribution() -> void:
	var rarity_counts := {0: 0, 1: 0, 2: 0, 3: 0}  # COMMON=0, UNCOMMON=1, RARE=2, LEGENDARY=3
	for fish_id in FISH_FILES:
		var species: FishSpecies = load("res://scripts/data/fish/%s.tres" % fish_id)
		if species == null:
			continue
		rarity_counts[species.rarity] += 1
	_assert_true("FishData.has_common", rarity_counts[0] > 0, "No COMMON fish")
	_assert_true("FishData.has_uncommon", rarity_counts[1] > 0, "No UNCOMMON fish")
	_assert_true("FishData.has_rare", rarity_counts[2] > 0, "No RARE fish")
	_assert_true("FishData.has_legendary", rarity_counts[3] > 0, "No LEGENDARY fish")

# --- FishDatabase API ---

func _test_database_api() -> void:
	var all_species: Array = FishDatabase.get_all_species()
	_assert_eq("FishDatabase.all_count", all_species.size(), 10)

	var sardine: FishSpecies = FishDatabase.get_species("sardine")
	_assert_true("FishDatabase.get_sardine", sardine != null, "get_species('sardine') returned null")
	if sardine != null:
		_assert_eq("FishDatabase.sardine_id", sardine.id, "sardine")

	var nonexistent := FishDatabase.get_species("does_not_exist")
	_assert_eq("FishDatabase.get_nonexistent", nonexistent, null)

	# RARITY_WEIGHTS has all 4 keys
	var weights: Dictionary = FishDatabase.RARITY_WEIGHTS
	_assert_eq("FishDatabase.rarity_weights_count", weights.size(), 4)
	_assert_true("FishDatabase.rw_common", weights.has(FishSpecies.Rarity.COMMON), "Missing COMMON weight")
	_assert_true("FishDatabase.rw_legendary", weights.has(FishSpecies.Rarity.LEGENDARY), "Missing LEGENDARY weight")

	# get_random_species_for_biome returns a valid species
	var random_fish: FishSpecies = FishDatabase.get_random_species_for_biome("shallow")
	_assert_true("FishDatabase.random_biome_valid", random_fish != null, "random_species returned null")
	if random_fish != null:
		_assert_true("FishDatabase.random_biome_type", random_fish is FishSpecies, "Not a FishSpecies")
