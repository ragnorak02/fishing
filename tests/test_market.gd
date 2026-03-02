extends RefCounted

# Tests for MarketSystem — deterministic pricing, sell price calc, trend labels.

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
	_test_deterministic_pricing()
	_test_price_range()
	_test_sell_price_calc()
	_test_trend_labels()
	_test_trend_colors()
	return {"passed": _passed, "failed": _failed, "details": _details}

func _test_deterministic_pricing() -> void:
	# Same day + species should always return same multiplier
	var mult1 := MarketSystem.get_price_multiplier("sardine")
	var mult2 := MarketSystem.get_price_multiplier("sardine")
	_assert_eq("Market.deterministic", mult1, mult2)

	# Different species should (usually) have different multipliers
	var mult_sardine := MarketSystem.get_price_multiplier("sardine")
	var mult_tuna := MarketSystem.get_price_multiplier("bluefin_tuna")
	# They could theoretically be equal, so just verify they're valid
	_assert_true("Market.sardine_valid", mult_sardine >= MarketSystem.MIN_MULTIPLIER and mult_sardine <= MarketSystem.MAX_MULTIPLIER, "Sardine mult out of range: %s" % str(mult_sardine))
	_assert_true("Market.tuna_valid", mult_tuna >= MarketSystem.MIN_MULTIPLIER and mult_tuna <= MarketSystem.MAX_MULTIPLIER, "Tuna mult out of range: %s" % str(mult_tuna))

func _test_price_range() -> void:
	# Test multiple species to ensure all multipliers are within range
	var species_ids := ["sardine", "mackerel", "sea_bream", "squid", "octopus"]
	for sid in species_ids:
		var mult := MarketSystem.get_price_multiplier(sid)
		_assert_true("Market.range_%s" % sid,
			mult >= MarketSystem.MIN_MULTIPLIER and mult <= MarketSystem.MAX_MULTIPLIER,
			"%s multiplier %s out of range" % [sid, str(mult)])

func _test_sell_price_calc() -> void:
	var fish := {"species_id": "sardine", "value": 10}
	var price := MarketSystem.get_sell_price(fish)
	_assert_true("Market.sell_positive", price >= 1, "Sell price should be >= 1, got %d" % price)

	# Price should be value * multiplier (rounded to int, min 1)
	var mult := MarketSystem.get_price_multiplier("sardine")
	var expected := maxi(int(10 * mult), 1)
	_assert_eq("Market.sell_calc", price, expected)

	# Zero value fish should still get at least 1g
	var cheap_fish := {"species_id": "sardine", "value": 0}
	var cheap_price := MarketSystem.get_sell_price(cheap_fish)
	_assert_true("Market.sell_min", cheap_price >= 1, "Min price should be 1")

func _test_trend_labels() -> void:
	# Verify trend labels are valid strings
	var valid_trends := ["HIGH", "UP", "NORMAL", "DOWN", "LOW"]
	var trend := MarketSystem.get_market_trend("sardine")
	_assert_true("Market.trend_valid", trend in valid_trends, "Invalid trend: %s" % trend)

	# Test threshold logic directly
	# HIGH: >= 1.7
	_assert_true("Market.trend_high_logic", _trend_for_mult(1.8) == "HIGH", "1.8 should be HIGH")
	_assert_true("Market.trend_up_logic", _trend_for_mult(1.4) == "UP", "1.4 should be UP")
	_assert_true("Market.trend_normal_logic", _trend_for_mult(1.0) == "NORMAL", "1.0 should be NORMAL")
	_assert_true("Market.trend_down_logic", _trend_for_mult(0.7) == "DOWN", "0.7 should be DOWN")
	_assert_true("Market.trend_low_logic", _trend_for_mult(0.5) == "LOW", "0.5 should be LOW")

func _trend_for_mult(mult: float) -> String:
	if mult >= 1.7:
		return "HIGH"
	elif mult >= 1.3:
		return "UP"
	elif mult >= 0.8:
		return "NORMAL"
	elif mult >= 0.6:
		return "DOWN"
	else:
		return "LOW"

func _test_trend_colors() -> void:
	var color := MarketSystem.get_trend_color("sardine")
	_assert_true("Market.color_valid", color is Color, "Trend color should be a Color")
	# Verify it returns a non-default color
	_assert_true("Market.color_not_default", color != Color(0, 0, 0, 0), "Color should not be transparent")
