extends RefCounted

# Tests for asset file existence (SVG, tres, shaders) and achievements.json schema.

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
	_test_svg_files()
	_test_tres_files()
	_test_shader_files()
	_test_core_files()
	_test_achievements_json()
	return {"passed": _passed, "failed": _failed, "details": _details}

# --- SVG assets (23 files) ---

const SVG_FILES := [
	"res://icon.svg",
	"res://assets/sprites/boat/boat.svg",
	"res://assets/sprites/diver/diver.svg",
	"res://assets/sprites/fish/sardine.svg",
	"res://assets/sprites/fish/mackerel.svg",
	"res://assets/sprites/fish/sea_bream.svg",
	"res://assets/sprites/fish/squid.svg",
	"res://assets/sprites/fish/octopus.svg",
	"res://assets/sprites/fish/yellowtail.svg",
	"res://assets/sprites/fish/grouper.svg",
	"res://assets/sprites/fish/bluefin_tuna.svg",
	"res://assets/sprites/fish/manta_ray.svg",
	"res://assets/sprites/fish/golden_koi.svg",
	"res://assets/sprites/npc/fishmonger.svg",
	"res://assets/sprites/npc/upgrade_npc.svg",
	"res://assets/sprites/npc/player_topdown.svg",
	"res://assets/sprites/ui/harpoon.svg",
	"res://assets/sprites/environment/hub_town/dock_tile.svg",
	"res://assets/sprites/environment/hub_town/ground_tile.svg",
	"res://assets/sprites/environment/hub_town/building.svg",
	"res://assets/sprites/environment/ocean/island.svg",
	"res://assets/sprites/environment/ocean/dive_spot.svg",
	"res://assets/sprites/effects/bubble.svg",
]

func _test_svg_files() -> void:
	for path in SVG_FILES:
		var name := path.get_file()
		_assert_true("Asset.svg_%s" % name,
			FileAccess.file_exists(path),
			"Missing: %s" % path)

# --- Fish .tres files (10) ---

const TRES_FILES := [
	"res://scripts/data/fish/sardine.tres",
	"res://scripts/data/fish/mackerel.tres",
	"res://scripts/data/fish/sea_bream.tres",
	"res://scripts/data/fish/squid.tres",
	"res://scripts/data/fish/octopus.tres",
	"res://scripts/data/fish/yellowtail.tres",
	"res://scripts/data/fish/grouper.tres",
	"res://scripts/data/fish/bluefin_tuna.tres",
	"res://scripts/data/fish/manta_ray.tres",
	"res://scripts/data/fish/golden_koi.tres",
]

func _test_tres_files() -> void:
	for path in TRES_FILES:
		var name := path.get_file()
		_assert_true("Asset.tres_%s" % name,
			FileAccess.file_exists(path),
			"Missing: %s" % path)

# --- Shader files (2) ---

func _test_shader_files() -> void:
	_assert_true("Asset.shader_ocean",
		FileAccess.file_exists("res://assets/shaders/ocean_surface.gdshader"),
		"Missing ocean_surface.gdshader")
	_assert_true("Asset.shader_underwater",
		FileAccess.file_exists("res://assets/shaders/underwater.gdshader"),
		"Missing underwater.gdshader")

# --- Core files ---

func _test_core_files() -> void:
	_assert_true("Asset.icon_svg",
		FileAccess.file_exists("res://icon.svg"),
		"Missing icon.svg")
	_assert_true("Asset.project_godot",
		FileAccess.file_exists("res://project.godot"),
		"Missing project.godot")

# --- achievements.json validation ---

func _test_achievements_json() -> void:
	var path := "res://achievements.json"
	_assert_true("Achievements.file_exists",
		FileAccess.file_exists(path), "Missing achievements.json")

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failed += 1
		_details.append({"name": "Achievements.readable", "status": "fail", "message": "Cannot open file"})
		return

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	_assert_eq("Achievements.valid_json", err, OK)
	if err != OK:
		return

	var data: Dictionary = json.data

	# gameId
	_assert_eq("Achievements.gameId", data.get("gameId"), "fishing")

	# achievements array
	var achievements: Array = data.get("achievements", [])
	_assert_eq("Achievements.count", achievements.size(), 15)

	# Required fields on each achievement
	var required_fields := ["id", "name", "description", "points", "unlocked"]
	var ids := {}
	var total_points := 0
	for achievement in achievements:
		var aid: String = achievement.get("id", "")
		for field in required_fields:
			_assert_true("Achievements.%s.has_%s" % [aid, field],
				achievement.has(field),
				"Missing field '%s' on achievement '%s'" % [field, aid])

		# No duplicate IDs
		_assert_true("Achievements.%s.unique_id" % aid,
			not ids.has(aid),
			"Duplicate ID: %s" % aid)
		ids[aid] = true
		total_points += achievement.get("points", 0)

		# Icon path exists
		var icon_path: String = achievement.get("icon", "")
		if icon_path.length() > 0:
			# Convert relative path to res:// path
			var res_path := "res://%s" % icon_path
			_assert_true("Achievements.%s.icon_exists" % aid,
				FileAccess.file_exists(res_path),
				"Missing icon: %s" % res_path)

	# meta validation
	var meta: Dictionary = data.get("meta", {})
	_assert_eq("Achievements.meta.totalPointsPossible", meta.get("totalPointsPossible"), 490)
	_assert_eq("Achievements.points_sum_matches", total_points, 490)
