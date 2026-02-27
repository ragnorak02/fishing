extends RefCounted
## Ocean interaction regression tests — verifies collision shapes are baked,
## layers are correct, and required input actions exist.

func run_tests() -> Dictionary:
	var passed := 0
	var failed := 0
	var details := []

	# --- Test 1: DiveSpot.gd loads successfully ---
	var dive_script = load("res://scenes/ocean_surface/DiveSpot.gd")
	if dive_script != null:
		passed += 1
		details.append({"name": "DiveSpot script loads", "status": "pass"})
	else:
		failed += 1
		details.append({"name": "DiveSpot script loads", "status": "fail", "message": "Failed to load DiveSpot.gd"})

	# --- Test 2: OceanSurface.tscn exists ---
	var tscn_exists := FileAccess.file_exists("res://scenes/ocean_surface/OceanSurface.tscn")
	if tscn_exists:
		passed += 1
		details.append({"name": "OceanSurface.tscn exists", "status": "pass"})
	else:
		failed += 1
		details.append({"name": "OceanSurface.tscn exists", "status": "fail", "message": "File not found"})

	# --- Parse .tscn for structural checks ---
	var tscn_text := ""
	if tscn_exists:
		var file := FileAccess.open("res://scenes/ocean_surface/OceanSurface.tscn", FileAccess.READ)
		if file:
			tscn_text = file.get_as_text()
			file.close()

	# --- Test 3: CollisionShape2D nodes have baked shapes (SubResource references) ---
	var shape_nodes := [
		"parent=\"Vehicle\"]\nshape = SubResource",
		"parent=\"DiveSpot1\"]\nshape = SubResource",
		"parent=\"DiveSpot2\"]\nshape = SubResource",
		"parent=\"DiveSpot3\"]\nshape = SubResource",
		"parent=\"HubReturnZone\"]\nshape = SubResource",
		"parent=\"Island1\"]\nshape = SubResource",
		"parent=\"Island2\"]\nshape = SubResource",
		"parent=\"Island3\"]\nshape = SubResource",
	]
	var all_baked := true
	var missing_shapes := []
	for pattern in shape_nodes:
		if tscn_text.find(pattern) == -1:
			all_baked = false
			missing_shapes.append(pattern.get_slice("]", 0))
	if all_baked:
		passed += 1
		details.append({"name": "All CollisionShape2D have baked shapes", "status": "pass"})
	else:
		failed += 1
		details.append({"name": "All CollisionShape2D have baked shapes", "status": "fail",
			"message": "Missing shape on: %s" % str(missing_shapes)})

	# --- Test 4: DiveSpot collision_mask includes layer 2 ---
	var dive_mask_ok := tscn_text.find("\"DiveSpot1\"") != -1 and tscn_text.find("collision_mask = 2") != -1
	if dive_mask_ok:
		passed += 1
		details.append({"name": "DiveSpot collision_mask includes player layer", "status": "pass"})
	else:
		failed += 1
		details.append({"name": "DiveSpot collision_mask includes player layer", "status": "fail",
			"message": "DiveSpot missing collision_mask = 2"})

	# --- Test 5: Vehicle collision_layer = 2 ---
	var vehicle_layer_ok := tscn_text.find("collision_layer = 2") != -1
	if vehicle_layer_ok:
		passed += 1
		details.append({"name": "Vehicle collision_layer = 2", "status": "pass"})
	else:
		failed += 1
		details.append({"name": "Vehicle collision_layer = 2", "status": "fail",
			"message": "Vehicle missing collision_layer = 2"})

	# --- Test 6: 3 dive spots exist in scene ---
	var dive_count := 0
	for name_str in ["DiveSpot1", "DiveSpot2", "DiveSpot3"]:
		if tscn_text.find("name=\"%s\"" % name_str) != -1:
			dive_count += 1
	if dive_count == 3:
		passed += 1
		details.append({"name": "3 dive spots in scene", "status": "pass"})
	else:
		failed += 1
		details.append({"name": "3 dive spots in scene", "status": "fail",
			"message": "Found %d/3 dive spots" % dive_count})

	# --- Test 7: HubReturnZone exists in scene ---
	if tscn_text.find("name=\"HubReturnZone\"") != -1:
		passed += 1
		details.append({"name": "HubReturnZone in scene", "status": "pass"})
	else:
		failed += 1
		details.append({"name": "HubReturnZone in scene", "status": "fail",
			"message": "HubReturnZone node not found in .tscn"})

	# --- Test 8: interact input action exists ---
	if InputMap.has_action("interact"):
		passed += 1
		details.append({"name": "interact input action exists", "status": "pass"})
	else:
		failed += 1
		details.append({"name": "interact input action exists", "status": "fail",
			"message": "InputMap missing 'interact' action"})

	# --- Test 9: transform_vehicle input action exists ---
	if InputMap.has_action("transform_vehicle"):
		passed += 1
		details.append({"name": "transform_vehicle input action exists", "status": "pass"})
	else:
		failed += 1
		details.append({"name": "transform_vehicle input action exists", "status": "fail",
			"message": "InputMap missing 'transform_vehicle' action"})

	return {"passed": passed, "failed": failed, "details": details}
