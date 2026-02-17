extends RefCounted

# Tests for Inventory gold, haul, and storage operations.

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
	_test_starting_gold()
	_test_spend_gold()
	_test_clear_haul()
	_test_sell_all_haul()
	_test_keep_all_haul()
	_test_sell_from_storage()
	_test_bounds_checking()
	_test_signals_exist()
	return {"passed": _passed, "failed": _failed, "details": _details}

func _make_inventory() -> Node:
	var script: GDScript = load("res://scripts/autoload/Inventory.gd")
	return script.new()

func _make_fish_entry(value: int) -> Dictionary:
	return {
		"species_id": "test",
		"name": "Test Fish",
		"weight": 1.5,
		"value": value,
		"rarity": 0,
		"sushi_grade": false,
	}

# --- Tests ---

func _test_starting_gold() -> void:
	var inv := _make_inventory()
	_assert_eq("Inventory.starting_gold", inv.gold, 50)
	inv.free()

func _test_spend_gold() -> void:
	var inv := _make_inventory()
	# Spend within budget
	var result: bool = inv.spend_gold(30)
	_assert_eq("Inventory.spend_30_success", result, true)
	_assert_eq("Inventory.gold_after_spend_30", inv.gold, 20)
	# Spend over budget
	var result2: bool = inv.spend_gold(200)
	_assert_eq("Inventory.spend_200_fail", result2, false)
	_assert_eq("Inventory.gold_unchanged", inv.gold, 20)
	inv.free()

func _test_clear_haul() -> void:
	var inv := _make_inventory()
	inv.current_haul.append(_make_fish_entry(10))
	inv.current_haul.append(_make_fish_entry(20))
	_assert_eq("Inventory.haul_before_clear", inv.current_haul.size(), 2)
	inv.clear_haul()
	_assert_eq("Inventory.haul_after_clear", inv.current_haul.size(), 0)
	inv.free()

func _test_sell_all_haul() -> void:
	var inv := _make_inventory()
	inv.current_haul.append(_make_fish_entry(10))
	inv.current_haul.append(_make_fish_entry(25))
	var gold_before: int = inv.gold
	inv.sell_all_haul()
	_assert_eq("Inventory.sell_all_gold", inv.gold, gold_before + 35)
	_assert_eq("Inventory.sell_all_haul_empty", inv.current_haul.size(), 0)
	inv.free()

func _test_keep_all_haul() -> void:
	var inv := _make_inventory()
	inv.current_haul.append(_make_fish_entry(10))
	inv.current_haul.append(_make_fish_entry(20))
	inv.keep_all_haul()
	_assert_eq("Inventory.keep_all_haul_empty", inv.current_haul.size(), 0)
	_assert_eq("Inventory.keep_all_storage_count", inv.fish_storage.size(), 2)
	inv.free()

func _test_sell_from_storage() -> void:
	var inv := _make_inventory()
	inv.fish_storage.append(_make_fish_entry(30))
	var gold_before: int = inv.gold
	inv.sell_from_storage(0)
	_assert_eq("Inventory.sell_storage_gold", inv.gold, gold_before + 30)
	_assert_eq("Inventory.sell_storage_removed", inv.fish_storage.size(), 0)
	inv.free()

func _test_bounds_checking() -> void:
	var inv := _make_inventory()
	var gold_before: int = inv.gold
	# sell from empty storage
	inv.sell_from_storage(0)
	_assert_eq("Inventory.sell_empty_noop", inv.gold, gold_before)
	# sell from haul with bad index
	inv.sell_fish_from_haul(-1)
	_assert_eq("Inventory.sell_haul_neg_noop", inv.gold, gold_before)
	# keep from haul with bad index
	inv.keep_fish_from_haul(99)
	_assert_eq("Inventory.keep_haul_bad_noop", inv.fish_storage.size(), 0)
	inv.free()

func _test_signals_exist() -> void:
	var inv := _make_inventory()
	_assert_true("Inventory.signal_gold_changed", inv.has_signal("gold_changed"), "Missing gold_changed signal")
	_assert_true("Inventory.signal_haul_changed", inv.has_signal("haul_changed"), "Missing haul_changed signal")
	_assert_true("Inventory.signal_storage_changed", inv.has_signal("storage_changed"), "Missing storage_changed signal")
	inv.free()
