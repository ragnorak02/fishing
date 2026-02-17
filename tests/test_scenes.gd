extends RefCounted

# Tests for scene loading — verifies all 6 .tscn files load as PackedScene.

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

func run_tests() -> Dictionary:
	_test_scene_loading()
	return {"passed": _passed, "failed": _failed, "details": _details}

const SCENES := {
	"MainMenu": "res://scenes/main_menu/MainMenu.tscn",
	"HubTown": "res://scenes/hub_town/HubTown.tscn",
	"OceanSurface": "res://scenes/ocean_surface/OceanSurface.tscn",
	"DiveScene": "res://scenes/dive_scene/DiveScene.tscn",
	"HaulSummary": "res://scenes/haul_summary/HaulSummary.tscn",
	"SceneTransition": "res://scenes/transitions/SceneTransition.tscn",
}

func _test_scene_loading() -> void:
	for scene_name in SCENES:
		var path: String = SCENES[scene_name]

		# Test 1: file exists
		_assert_true("Scene.exists_%s" % scene_name,
			FileAccess.file_exists(path),
			"File not found: %s" % path)

		# Test 2: loads as PackedScene
		var start := Time.get_ticks_msec()
		var packed: PackedScene = load(path)
		var elapsed := Time.get_ticks_msec() - start

		_assert_true("Scene.load_%s" % scene_name,
			packed != null,
			"Failed to load: %s" % path)

		# Warn (not fail) if load time > 5000ms
		if elapsed > 5000:
			_details.append({
				"name": "Scene.perf_%s" % scene_name,
				"status": "warn",
				"message": "Load time %dms exceeds 5000ms" % elapsed,
			})
