extends RefCounted
## Vehicle controls diagnostic tests — verifies InputMap bindings, unlock flags,
## VehicleStateMachine enum values, and OceanSurface.gd action name references.

func run_tests() -> Dictionary:
	var passed := 0
	var failed := 0
	var details := []

	# --- Test 1: mode_down action exists ---
	if InputMap.has_action("mode_down"):
		passed += 1
		details.append({"name": "mode_down action exists", "status": "pass"})
	else:
		failed += 1
		details.append({"name": "mode_down action exists", "status": "fail",
			"message": "InputMap missing 'mode_down' action"})

	# --- Test 2: mode_down has Q key (physical_keycode 81) ---
	var mode_down_has_q := false
	if InputMap.has_action("mode_down"):
		for event in InputMap.action_get_events("mode_down"):
			if event is InputEventKey and event.physical_keycode == 81:
				mode_down_has_q = true
				break
	if mode_down_has_q:
		passed += 1
		details.append({"name": "mode_down has Q key (keycode 81)", "status": "pass"})
	else:
		failed += 1
		details.append({"name": "mode_down has Q key (keycode 81)", "status": "fail",
			"message": "No InputEventKey with physical_keycode=81 found on mode_down"})

	# --- Test 3: mode_down has LT (JoypadMotion axis 4, value 1.0) ---
	var mode_down_has_lt := false
	if InputMap.has_action("mode_down"):
		for event in InputMap.action_get_events("mode_down"):
			if event is InputEventJoypadMotion and event.axis == 4 and event.axis_value == 1.0:
				mode_down_has_lt = true
				break
	if mode_down_has_lt:
		passed += 1
		details.append({"name": "mode_down has LT (axis 4, value 1.0)", "status": "pass"})
	else:
		failed += 1
		details.append({"name": "mode_down has LT (axis 4, value 1.0)", "status": "fail",
			"message": "No InputEventJoypadMotion axis=4 value=1.0 found on mode_down"})

	# --- Test 4: mode_up action exists ---
	if InputMap.has_action("mode_up"):
		passed += 1
		details.append({"name": "mode_up action exists", "status": "pass"})
	else:
		failed += 1
		details.append({"name": "mode_up action exists", "status": "fail",
			"message": "InputMap missing 'mode_up' action"})

	# --- Test 5: mode_up has E key (physical_keycode 69) ---
	var mode_up_has_e := false
	if InputMap.has_action("mode_up"):
		for event in InputMap.action_get_events("mode_up"):
			if event is InputEventKey and event.physical_keycode == 69:
				mode_up_has_e = true
				break
	if mode_up_has_e:
		passed += 1
		details.append({"name": "mode_up has E key (keycode 69)", "status": "pass"})
	else:
		failed += 1
		details.append({"name": "mode_up has E key (keycode 69)", "status": "fail",
			"message": "No InputEventKey with physical_keycode=69 found on mode_up"})

	# --- Test 6: mode_up has RT (JoypadMotion axis 5, value 1.0) ---
	var mode_up_has_rt := false
	if InputMap.has_action("mode_up"):
		for event in InputMap.action_get_events("mode_up"):
			if event is InputEventJoypadMotion and event.axis == 5 and event.axis_value == 1.0:
				mode_up_has_rt = true
				break
	if mode_up_has_rt:
		passed += 1
		details.append({"name": "mode_up has RT (axis 5, value 1.0)", "status": "pass"})
	else:
		failed += 1
		details.append({"name": "mode_up has RT (axis 5, value 1.0)", "status": "fail",
			"message": "No InputEventJoypadMotion axis=5 value=1.0 found on mode_up"})

	# --- Test 7: interact has E key (69) and A button (button_index 0) ---
	var interact_has_e := false
	var interact_has_a := false
	if InputMap.has_action("interact"):
		for event in InputMap.action_get_events("interact"):
			if event is InputEventKey and event.physical_keycode == 69:
				interact_has_e = true
			if event is InputEventJoypadButton and event.button_index == 0:
				interact_has_a = true
	if interact_has_e and interact_has_a:
		passed += 1
		details.append({"name": "interact has E key and A button", "status": "pass"})
	else:
		failed += 1
		var missing := []
		if not interact_has_e:
			missing.append("E key (69)")
		if not interact_has_a:
			missing.append("A button (index 0)")
		details.append({"name": "interact has E key and A button", "status": "fail",
			"message": "Missing: %s" % str(missing)})

	# --- Test 8: sonar_pulse has Space (32) and LB (button_index 4) ---
	var sonar_has_space := false
	var sonar_has_lb := false
	if InputMap.has_action("sonar_pulse"):
		for event in InputMap.action_get_events("sonar_pulse"):
			if event is InputEventKey and event.physical_keycode == 32:
				sonar_has_space = true
			if event is InputEventJoypadButton and event.button_index == 4:
				sonar_has_lb = true
	if sonar_has_space and sonar_has_lb:
		passed += 1
		details.append({"name": "sonar_pulse has Space and LB button", "status": "pass"})
	else:
		failed += 1
		var missing := []
		if not sonar_has_space:
			missing.append("Space (32)")
		if not sonar_has_lb:
			missing.append("LB button (index 4)")
		details.append({"name": "sonar_pulse has Space and LB button", "status": "fail",
			"message": "Missing: %s" % str(missing)})

	# --- Test 9: GameManager.submerge_unlocked is true ---
	var gm = Engine.get_singleton("GameManager") if Engine.has_singleton("GameManager") else null
	# GameManager is an autoload — access via scene tree path isn't available in headless
	# Use script load + check default value instead
	var gm_script = load("res://scripts/autoload/GameManager.gd")
	var submerge_default_ok := false
	if gm_script:
		# Scan source for "submerge_unlocked: bool = true"
		var src_file := FileAccess.open("res://scripts/autoload/GameManager.gd", FileAccess.READ)
		if src_file:
			var src := src_file.get_as_text()
			src_file.close()
			submerge_default_ok = src.find("submerge_unlocked: bool = true") != -1
	if submerge_default_ok:
		passed += 1
		details.append({"name": "GameManager.submerge_unlocked default is true", "status": "pass"})
	else:
		failed += 1
		details.append({"name": "GameManager.submerge_unlocked default is true", "status": "fail",
			"message": "submerge_unlocked not defaulting to true in GameManager.gd"})

	# --- Test 10: GameManager.air_mode_unlocked is true ---
	var air_default_ok := false
	var gm_src_file := FileAccess.open("res://scripts/autoload/GameManager.gd", FileAccess.READ)
	if gm_src_file:
		var src := gm_src_file.get_as_text()
		gm_src_file.close()
		air_default_ok = src.find("air_mode_unlocked: bool = true") != -1
	if air_default_ok:
		passed += 1
		details.append({"name": "GameManager.air_mode_unlocked default is true", "status": "pass"})
	else:
		failed += 1
		details.append({"name": "GameManager.air_mode_unlocked default is true", "status": "fail",
			"message": "air_mode_unlocked not defaulting to true in GameManager.gd"})

	# --- Test 11: VehicleStateMachine.Mode enum order (SURFACE=0, SUBMERGED=1, AIR=2) ---
	var vsm_script = load("res://scripts/vehicle/VehicleStateMachine.gd")
	var vsm_enum_ok := false
	if vsm_script:
		var vsm_src := FileAccess.open("res://scripts/vehicle/VehicleStateMachine.gd", FileAccess.READ)
		if vsm_src:
			var src := vsm_src.get_as_text()
			vsm_src.close()
			# Expect enum Mode { SURFACE, SUBMERGED, AIR } in that order
			var surface_pos := src.find("SURFACE")
			var submerged_pos := src.find("SUBMERGED")
			var air_pos := src.find("AIR")
			vsm_enum_ok = (surface_pos != -1 and submerged_pos != -1 and air_pos != -1
				and surface_pos < submerged_pos and submerged_pos < air_pos)
	if vsm_enum_ok:
		passed += 1
		details.append({"name": "VehicleStateMachine.Mode enum order SURFACE<SUBMERGED<AIR", "status": "pass"})
	else:
		failed += 1
		details.append({"name": "VehicleStateMachine.Mode enum order SURFACE<SUBMERGED<AIR", "status": "fail",
			"message": "Enum order wrong or VehicleStateMachine.gd not found"})

	# --- Test 12: OceanSurface.gd references mode_down ---
	var ocean_src := ""
	var ocean_src_file := FileAccess.open("res://scenes/ocean_surface/OceanSurface.gd", FileAccess.READ)
	if ocean_src_file:
		ocean_src = ocean_src_file.get_as_text()
		ocean_src_file.close()
	if ocean_src.find("\"mode_down\"") != -1:
		passed += 1
		details.append({"name": "OceanSurface.gd references mode_down", "status": "pass"})
	else:
		failed += 1
		details.append({"name": "OceanSurface.gd references mode_down", "status": "fail",
			"message": "String \"mode_down\" not found in OceanSurface.gd"})

	# --- Test 13: OceanSurface.gd references mode_up ---
	if ocean_src.find("\"mode_up\"") != -1:
		passed += 1
		details.append({"name": "OceanSurface.gd references mode_up", "status": "pass"})
	else:
		failed += 1
		details.append({"name": "OceanSurface.gd references mode_up", "status": "fail",
			"message": "String \"mode_up\" not found in OceanSurface.gd"})

	# --- Test 14: No stale transform_vehicle/transform_air action names in OceanSurface.gd ---
	var no_stale_names := (ocean_src.find("transform_vehicle") == -1
		and ocean_src.find("transform_air") == -1)
	if no_stale_names:
		passed += 1
		details.append({"name": "No stale transform_vehicle/transform_air in OceanSurface.gd", "status": "pass"})
	else:
		failed += 1
		var stale := []
		if ocean_src.find("transform_vehicle") != -1:
			stale.append("transform_vehicle")
		if ocean_src.find("transform_air") != -1:
			stale.append("transform_air")
		details.append({"name": "No stale transform_vehicle/transform_air in OceanSurface.gd", "status": "fail",
			"message": "Stale action names found: %s" % str(stale)})

	return {"passed": passed, "failed": failed, "details": details}
