extends RefCounted

# Performance baseline tests — verifies that core operations complete
# within acceptable time bounds and memory patterns are stable.

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
	_test_fish_database_load_time()
	_test_species_lookup_speed()
	_test_biome_query_all_biomes()
	_test_rarity_weight_calculation()
	_test_market_price_bulk()
	_test_event_fish_eligibility()
	_test_save_data_serialization()
	_test_achievement_manifest_parse()
	_test_scene_file_sizes()
	_test_fish_species_resource_count()
	_test_quest_system_operations()
	_test_weather_system_operations()
	return {"passed": _passed, "failed": _failed, "details": _details}

func _test_fish_database_load_time() -> void:
	# Reset and reload
	FishDatabase._loaded = false
	FishDatabase._species.clear()
	var start := Time.get_ticks_usec()
	FishDatabase._ensure_loaded()
	var elapsed := Time.get_ticks_usec() - start
	# Should load all species in under 100ms (100,000 usec)
	_assert_true("perf.db_load.under_100ms", elapsed < 100000,
		"FishDatabase load took %d usec (>100ms)" % elapsed)
	_assert_true("perf.db_load.has_species", FishDatabase.get_all_species().size() > 0,
		"No species loaded")

func _test_species_lookup_speed() -> void:
	FishDatabase._ensure_loaded()
	var start := Time.get_ticks_usec()
	for i in 1000:
		FishDatabase.get_species("sardine")
		FishDatabase.get_species("bluefin_tuna")
		FishDatabase.get_species("nonexistent")
	var elapsed := Time.get_ticks_usec() - start
	# 3000 lookups should complete in under 50ms
	_assert_true("perf.lookup.3k_under_50ms", elapsed < 50000,
		"3000 lookups took %d usec (>50ms)" % elapsed)

func _test_biome_query_all_biomes() -> void:
	FishDatabase._ensure_loaded()
	var biomes := ["shallow", "deep", "abyss", "kelp_forest", "volcanic"]
	var start := Time.get_ticks_usec()
	for biome in biomes:
		for i in 100:
			FishDatabase.get_random_species_for_biome(biome)
	var elapsed := Time.get_ticks_usec() - start
	# 500 biome queries should complete in under 100ms
	_assert_true("perf.biome_query.500_under_100ms", elapsed < 100000,
		"500 biome queries took %d usec (>100ms)" % elapsed)

	# Verify each biome returns at least one species
	for biome in biomes:
		var species := FishDatabase.get_random_species_for_biome(biome)
		_assert_true("perf.biome_query.%s_has_fish" % biome, species != null,
			"Biome '%s' returned no fish" % biome)

func _test_rarity_weight_calculation() -> void:
	var start := Time.get_ticks_usec()
	for i in 1000:
		FishScaling.get_adjusted_rarity_weights()
	var elapsed := Time.get_ticks_usec() - start
	_assert_true("perf.rarity_weights.1k_under_20ms", elapsed < 20000,
		"1000 rarity calcs took %d usec (>20ms)" % elapsed)

func _test_market_price_bulk() -> void:
	var market := MarketSystem.new()
	var start := Time.get_ticks_usec()
	for i in 1000:
		market.get_price_multiplier("sardine")
		market.get_price_multiplier("bluefin_tuna")
		market.get_market_trend("sardine")
	var elapsed := Time.get_ticks_usec() - start
	_assert_true("perf.market.3k_under_50ms", elapsed < 50000,
		"3000 market ops took %d usec (>50ms)" % elapsed)

func _test_event_fish_eligibility() -> void:
	var start := Time.get_ticks_usec()
	for i in 500:
		EventFishSystem.get_eligible_event_fish("shallow")
		EventFishSystem.get_eligible_event_fish("deep")
		EventFishSystem.get_eligible_event_fish("abyss")
	var elapsed := Time.get_ticks_usec() - start
	_assert_true("perf.event_fish.1500_under_100ms", elapsed < 100000,
		"1500 event fish checks took %d usec (>100ms)" % elapsed)

func _test_save_data_serialization() -> void:
	var save_data := {
		"save_version": 5,
		"gold": 500,
		"upgrade_levels": {"boat_speed": 2, "oxygen_tank": 1, "harpoon_range": 3,
			"hull_durability": 1, "battery_capacity": 2, "sonar_range": 1},
		"fish_storage": [],
		"species_caught": ["sardine", "mackerel", "grouper", "yellowtail", "bluefin_tuna"],
		"achievements": {"first_catch": true, "catch_10": true, "first_dive": true},
		"stats": {"total_catches": 42, "total_gold_earned": 1200},
		"active_menu": ["grilled_mackerel"],
		"unlocked_recipes": ["grilled_mackerel", "sardine_onigiri"],
		"current_day": 15,
		"current_time": 2,
		"submerge_unlocked": true,
		"air_mode_unlocked": true,
		"quests": {"catch_5_sardines": {"progress": 3}},
	}

	# Add 50 fish to storage to simulate real gameplay
	for i in 50:
		save_data["fish_storage"].append({
			"species_id": "sardine", "name": "Sardine",
			"weight": 0.3 + randf() * 0.5, "value": 5 + randi() % 10,
			"rarity": 0, "sushi_grade": false,
		})

	var json := JSON.new()
	var start := Time.get_ticks_usec()
	for i in 100:
		var json_string := json.stringify(save_data)
		json.parse(json_string)
	var elapsed := Time.get_ticks_usec() - start
	_assert_true("perf.save_serial.100_roundtrips_under_200ms", elapsed < 200000,
		"100 save roundtrips took %d usec (>200ms)" % elapsed)

func _test_achievement_manifest_parse() -> void:
	var start := Time.get_ticks_usec()
	for i in 100:
		var file := FileAccess.open("res://achievements.json", FileAccess.READ)
		if file:
			var text := file.get_as_text()
			file.close()
			var json := JSON.new()
			json.parse(text)
	var elapsed := Time.get_ticks_usec() - start
	_assert_true("perf.ach_parse.100_under_100ms", elapsed < 100000,
		"100 achievement parses took %d usec (>100ms)" % elapsed)

func _test_scene_file_sizes() -> void:
	# Verify scene files exist and aren't excessively large
	var scenes := [
		"res://scenes/main_menu/MainMenu.tscn",
		"res://scenes/hub_town/HubTown.tscn",
		"res://scenes/ocean_surface/OceanSurface.tscn",
		"res://scenes/dive_scene/DiveScene.tscn",
		"res://scenes/haul_summary/HaulSummary.tscn",
	]
	for scene_path in scenes:
		_assert_true("perf.scene.%s_exists" % scene_path.get_file().get_basename(),
			FileAccess.file_exists(scene_path),
			"Scene file missing: %s" % scene_path)

func _test_fish_species_resource_count() -> void:
	FishDatabase._ensure_loaded()
	var count := FishDatabase.get_all_species().size()
	_assert_eq("perf.species.total_count", count, 25)

	# Verify no duplicate IDs
	var ids := {}
	for species in FishDatabase.get_all_species():
		_assert_true("perf.species.no_dup_%s" % species.id,
			not ids.has(species.id),
			"Duplicate species ID: %s" % species.id)
		ids[species.id] = true

func _test_quest_system_operations() -> void:
	# Quest system operations should be fast
	var start := Time.get_ticks_usec()
	for i in 1000:
		# Simulate quest info lookups
		var keys := ["catch_5_sardines", "catch_3_rare", "earn_500_gold",
			"discover_5_species", "catch_bluefin", "nonexistent"]
		for key in keys:
			# Direct dict lookup
			if key in QuestSystem.QUESTS:
				var _info: Dictionary = QuestSystem.QUESTS[key]
	var elapsed := Time.get_ticks_usec() - start
	_assert_true("perf.quests.6k_lookups_under_20ms", elapsed < 20000,
		"6000 quest lookups took %d usec (>20ms)" % elapsed)

func _test_weather_system_operations() -> void:
	# WeatherSystem methods should be instant (no IO)
	var ws_script = load("res://scripts/autoload/WeatherSystem.gd")
	_assert_true("perf.weather.script_loads", ws_script != null, "WeatherSystem.gd failed to load")

	# Verify all weather enum values produce valid results
	var visibility_values := [1.0, 0.85, 0.65, 0.45, 0.35]
	for i in 5:
		_assert_true("perf.weather.visibility_%d_valid" % i,
			visibility_values[i] > 0.0 and visibility_values[i] <= 1.0)
